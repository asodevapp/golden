import 'dart:io';
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

/// A sequential calculation queue shared by Git and failure artifact reviews.
/// Only current work is queued; completed inactive results have a bounded LRU.
final class ImageDifferenceQueue<T> {
  ImageDifferenceQueue(this.calculate, {this.maxInactiveResults = 256})
      : assert(maxInactiveResults >= 0);

  final Future<GitImageDifference> Function(T value) calculate;
  final int maxInactiveResults;
  final Map<String, T> _queued = {};
  final Map<String, GitImageDifference> _results = {};
  final Map<String, Null> _inactive = {};
  final Set<String> _retry = {};
  Set<String> _active = {};
  String? _running;
  Future<void>? _worker;
  bool _closed = false;

  GitImageDifference stateFor(String key) =>
      _results[key] ?? const GitImageDifference.pending();

  void schedule(Map<String, T> values) {
    if (_closed) return;
    final nextActive = values.keys.toSet();
    for (final key in _active.difference(nextActive)) {
      if (_results.containsKey(key)) _inactive[key] = null;
    }
    _active = nextActive;
    _queued.removeWhere((key, _) => !_active.contains(key));
    for (final entry in values.entries) {
      _inactive.remove(entry.key);
      if (_retry.remove(entry.key)) _results.remove(entry.key);
      if (!_results.containsKey(entry.key) && _running != entry.key) {
        _queued[entry.key] = entry.value;
      }
    }
    _trim();
    if (_worker == null && _queued.isNotEmpty) _worker = _drain();
  }

  void _trim() {
    while (_inactive.length > maxInactiveResults) {
      final key = _inactive.keys.first;
      _inactive.remove(key);
      _results.remove(key);
      _retry.remove(key);
    }
  }

  /// Completes when currently scheduled calculations finish.
  Future<void> get idle async => await _worker;

  Future<void> close() async {
    _closed = true;
    _queued.clear();
    await _worker;
    _results.clear();
    _inactive.clear();
    _retry.clear();
  }

  Future<void> _drain() async {
    try {
      while (!_closed && _queued.isNotEmpty) {
        final key = _queued.keys.first;
        final value = _queued.remove(key) as T;
        _running = key;
        GitImageDifference result;
        try {
          result =
              await Future<GitImageDifference>.sync(() => calculate(value));
        } on Object catch (error) {
          if (error is FileSystemException ||
              (error is GitReviewException && error.conflict)) {
            _retry.add(key);
          }
          result = GitImageDifference.unavailable(
            error is GitReviewException
                ? error.message
                : 'Unable to decode this image for pixel comparison.',
          );
        }
        _results[key] = result;
        if (!_active.contains(key)) _inactive[key] = null;
        _running = null;
        _trim();
      }
    } finally {
      _running = null;
      _worker = null;
    }
  }
}

/// Keeps image decoding and pixel comparison off the HTTP server isolate.
final class GitImageDifferenceQueue {
  GitImageDifferenceQueue(this.repository) {
    _queue = ImageDifferenceQueue((change) => readImageDifference(
          hasBefore: change.hasBefore,
          hasAfter: change.hasAfter,
          read: (before) => repository.readImage(change, before: before),
        ));
  }

  final GitImageRepository repository;
  late final ImageDifferenceQueue<GitImageChange> _queue;

  GitImageDifference stateFor(GitImageChange change) =>
      _queue.stateFor(change.differenceKey);

  void schedule(GitImageSnapshot snapshot) => _queue.schedule({
        for (final change in snapshot.changes) change.differenceKey: change,
      });

  Future<void> get idle => _queue.idle;
  Future<void> close() => _queue.close();
}

/// Reads one comparison at a time and transfers encoded bytes to its isolate.
Future<GitImageDifference> readImageDifference({
  required bool hasBefore,
  required bool hasAfter,
  required Future<List<int>> Function(bool before) read,
}) async {
  Future<TransferableTypedData> transfer(bool before) async {
    final bytes = await read(before);
    return TransferableTypedData.fromList([
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    ]);
  }

  final before = hasBefore ? await transfer(true) : null;
  final after = hasAfter ? await transfer(false) : null;
  return _compareTransferred(before, after);
}

// Keep the isolate closure out of the reader's scope: it must not capture a
// repository, HTTP server, or the queue's pending futures along with the bytes.
Future<GitImageDifference> _compareTransferred(
  TransferableTypedData? before,
  TransferableTypedData? after,
) async {
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
  if (before == null || after == null) {
    final total = width * height;
    return (changedPixels: total, totalPixels: total);
  }
  final beforePixels = before.getBytes(order: image.ChannelOrder.rgba);
  final afterPixels = after.getBytes(order: image.ChannelOrder.rgba);
  var changedPixels = 0;
  var totalPixels = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final beforePresent = x < before.width && y < before.height;
      final afterPresent = x < after.width && y < after.height;
      if (!beforePresent && !afterPresent) continue;
      totalPixels++;
      if (beforePresent != afterPresent ||
          !_samePixel(
            beforePixels,
            (y * before.width + x) * 4,
            afterPixels,
            (y * after.width + x) * 4,
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
