import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

import 'git_image_review.dart';

const _maxDifferencePixels = 16 * 1000 * 1000;

enum GitImageDifferenceStatus { pending, ready, unavailable }

/// Pixel difference calculated outside the server isolate.
final class GitImageDifference {
  const GitImageDifference.pending()
      : status = GitImageDifferenceStatus.pending,
        changedPixels = null,
        totalPixels = null,
        error = null;

  const GitImageDifference.ready({
    required this.changedPixels,
    required this.totalPixels,
  })  : status = GitImageDifferenceStatus.ready,
        error = null;

  const GitImageDifference.unavailable(this.error)
      : status = GitImageDifferenceStatus.unavailable,
        changedPixels = null,
        totalPixels = null;

  final GitImageDifferenceStatus status;
  final int? changedPixels;
  final int? totalPixels;
  final String? error;

  double? get percent => status != GitImageDifferenceStatus.ready
      ? null
      : totalPixels == 0
          ? 0
          : changedPixels! * 100 / totalPixels!;

  Map<String, Object?> toJson() => {
        'status': status.name,
        if (changedPixels != null) 'changedPixels': changedPixels,
        if (totalPixels != null) 'totalPixels': totalPixels,
        if (percent != null) 'percent': percent,
        if (error != null) 'error': error,
      };
}

/// Keeps image decoding and pixel comparison off the HTTP server isolate.
///
/// Work is deliberately sequential to bound memory while large golden suites
/// are being reviewed. New snapshots invalidate queued results by revision.
final class GitImageDifferenceQueue {
  GitImageDifferenceQueue(this.repository);

  final GitImageRepository repository;
  final Queue<GitImageChange> _queue = ListQueue();
  final Set<String> _queuedRevisions = {};
  final Map<String, GitImageDifference> _states = {};
  Set<String> _activeRevisions = {};
  Future<void>? _worker;
  bool _closed = false;

  GitImageDifference stateFor(GitImageChange change) =>
      _states[change.revision] ?? const GitImageDifference.pending();

  void schedule(GitImageSnapshot snapshot) {
    if (_closed) return;
    _activeRevisions =
        snapshot.changes.map((change) => change.revision).toSet();
    _states.removeWhere((revision, _) => !_activeRevisions.contains(revision));
    for (final change in snapshot.changes) {
      if (_states.containsKey(change.revision) ||
          !_queuedRevisions.add(change.revision)) {
        continue;
      }
      _states[change.revision] = const GitImageDifference.pending();
      _queue.add(change);
    }
    _startWorker();
  }

  Future<void> close() async {
    _closed = true;
    _queue.clear();
    _queuedRevisions.clear();
    await _worker;
  }

  void _startWorker() {
    if (_closed || _worker != null || _queue.isEmpty) return;
    _worker = _drain();
  }

  Future<void> _drain() async {
    try {
      while (!_closed && _queue.isNotEmpty) {
        final change = _queue.removeFirst();
        _queuedRevisions.remove(change.revision);
        if (!_activeRevisions.contains(change.revision)) continue;
        try {
          final difference = await _calculate(change);
          if (_activeRevisions.contains(change.revision)) {
            _states[change.revision] = difference;
          }
        } on Object catch (error) {
          if (_activeRevisions.contains(change.revision)) {
            _states[change.revision] = GitImageDifference.unavailable(
              error is GitReviewException
                  ? error.message
                  : 'Unable to decode this image for pixel comparison.',
            );
          }
        }
      }
    } finally {
      _worker = null;
      _startWorker();
    }
  }

  Future<GitImageDifference> _calculate(GitImageChange change) async {
    final before = change.hasBefore
        ? TransferableTypedData.fromList([
            Uint8List.fromList(
              await repository.readImage(change, before: true),
            ),
          ])
        : null;
    final after = change.hasAfter
        ? TransferableTypedData.fromList([
            Uint8List.fromList(
              await repository.readImage(change, before: false),
            ),
          ])
        : null;
    final result = await Isolate.run(
      () => calculateGitImageDifference(
        before?.materialize().asUint8List(),
        after?.materialize().asUint8List(),
      ),
    );
    return GitImageDifference.ready(
      changedPixels: result.changedPixels,
      totalPixels: result.totalPixels,
    );
  }
}

/// Decodes two image versions and compares their top-left-aligned RGBA pixels.
({int changedPixels, int totalPixels}) calculateGitImageDifference(
  Uint8List? beforeBytes,
  Uint8List? afterBytes,
) {
  final before = _decode(beforeBytes);
  final after = _decode(afterBytes);
  if (before == null && after == null) {
    return (changedPixels: 0, totalPixels: 0);
  }
  final width = max(before?.width ?? 0, after?.width ?? 0);
  final height = max(before?.height ?? 0, after?.height ?? 0);
  if (width * height > _maxDifferencePixels) {
    throw const GitReviewException(
      'Pixel difference exceeds the 16 megapixel limit.',
    );
  }
  final beforePixels = before?.getBytes(order: image.ChannelOrder.rgba);
  final afterPixels = after?.getBytes(order: image.ChannelOrder.rgba);
  var changedPixels = 0;
  var totalPixels = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final beforePresent =
          before != null && x < before.width && y < before.height;
      final afterPresent = after != null && x < after.width && y < after.height;
      if (!beforePresent && !afterPresent) continue;
      totalPixels++;
      if (beforePresent != afterPresent ||
          !_samePixel(
            beforePixels!,
            (y * before!.width + x) * 4,
            afterPixels!,
            (y * after!.width + x) * 4,
          )) {
        changedPixels++;
      }
    }
  }
  return (changedPixels: changedPixels, totalPixels: totalPixels);
}

image.Image? _decode(Uint8List? bytes) {
  if (bytes == null) return null;
  image.Image? decoded;
  try {
    decoded = image.decodeImage(bytes);
  } on Object {
    throw const GitReviewException(
      'Unable to decode this image for pixel comparison.',
    );
  }
  if (decoded == null) {
    throw const GitReviewException(
      'Unable to decode this image for pixel comparison.',
    );
  }
  return image.bakeOrientation(decoded);
}

bool _samePixel(
    Uint8List left, int leftOffset, Uint8List right, int rightOffset) {
  return left[leftOffset] == right[rightOffset] &&
      left[leftOffset + 1] == right[rightOffset + 1] &&
      left[leftOffset + 2] == right[rightOffset + 2] &&
      left[leftOffset + 3] == right[rightOffset + 3];
}
