import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import 'failure_artifact_cleaner.dart';
import 'git_image_difference.dart';
import 'git_image_review.dart';

enum FailureArtifactKind { expected, actual, isolatedDiff, maskedDiff }

final class FailureImageArtifact {
  const FailureImageArtifact({
    required this.relativePath,
    required this.byteSize,
    required this.modifiedMicroseconds,
  });

  final String relativePath;
  final int byteSize;
  final int modifiedMicroseconds;

  String get revisionPart =>
      '$relativePath\u0000$byteSize\u0000$modifiedMicroseconds';
}

/// One Flutter golden failure, grouping its expected, actual and diff images.
final class FailureImageChange {
  FailureImageChange({
    required this.path,
    required Map<FailureArtifactKind, FailureImageArtifact> artifacts,
  }) : artifacts = Map.unmodifiable(artifacts);

  final String path;
  final Map<FailureArtifactKind, FailureImageArtifact> artifacts;

  String get id => base64Url.encode(utf8.encode('failure\u0000$path'));
  String get revision => sha256
      .convert(utf8.encode([
        id,
        for (final entry in artifacts.entries)
          '${entry.key.name}\u0000${entry.value.revisionPart}',
      ].join('\u0000')))
      .toString();
  bool get hasBefore => artifacts.containsKey(FailureArtifactKind.expected);
  bool get hasAfter => artifacts.containsKey(FailureArtifactKind.actual);

  Map<String, Object?> toJson() => {
        'id': id,
        'path': path,
        'revision': revision,
        'hasBefore': hasBefore,
        'hasAfter': hasAfter,
        'failure': true,
        'artifactCount': artifacts.length,
        'hasIsolatedDiff':
            artifacts.containsKey(FailureArtifactKind.isolatedDiff),
        'hasMaskedDiff': artifacts.containsKey(FailureArtifactKind.maskedDiff),
      };
}

final class FailureImageSnapshot {
  const FailureImageSnapshot({
    required this.changes,
    required this.fileCount,
    required this.totalBytes,
    this.warnings = const [],
  });

  const FailureImageSnapshot.empty()
      : changes = const [],
        fileCount = 0,
        totalBytes = 0,
        warnings = const [];

  final List<FailureImageChange> changes;
  final int fileCount;
  final int totalBytes;
  final List<String> warnings;
}

/// Scans Flutter's generated `failures` directories independently of Git.
final class FailureImageRepository {
  FailureImageRepository({
    required Directory inputDirectory,
    this.repositoryPathPrefix = '',
  })  : inputDirectory = Directory(
          path.normalize(path.absolute(inputDirectory.path)),
        ),
        cleaner = FailureArtifactCleaner(inputDirectory: inputDirectory);

  final Directory inputDirectory;
  final String repositoryPathPrefix;
  final FailureArtifactCleaner cleaner;

  static final _artifactPattern = RegExp(
    r'^(.*)_(masterImage|testImage|isolatedDiff|maskedDiff)\.png$',
    caseSensitive: false,
  );

  Future<FailureImageSnapshot> scan() async {
    final files = await cleaner.scan();
    final groups = <String, Map<FailureArtifactKind, FailureImageArtifact>>{};
    var unmatched = 0;
    for (final file in files) {
      final match = _artifactPattern.firstMatch(file.relativePath);
      if (match == null || match.group(1)!.isEmpty) {
        unmatched++;
        continue;
      }
      final relativeLogicalPath = '${match.group(1)}.png';
      final logicalPath = repositoryPathPrefix.isEmpty
          ? relativeLogicalPath
          : path.posix.join(repositoryPathPrefix, relativeLogicalPath);
      groups.putIfAbsent(logicalPath, () => {})[_kind(match.group(2)!)] =
          FailureImageArtifact(
        relativePath: file.relativePath,
        byteSize: file.byteSize,
        modifiedMicroseconds: file.modifiedMicroseconds,
      );
    }
    final changes = [
      for (final entry in groups.entries)
        FailureImageChange(path: entry.key, artifacts: entry.value),
    ]..sort((left, right) => left.path.compareTo(right.path));
    return FailureImageSnapshot(
      changes: changes,
      fileCount: files.length,
      totalBytes: files.fold(0, (sum, file) => sum + file.byteSize),
      warnings: unmatched == 0
          ? const []
          : [
              '$unmatched image(s) in failures directories do not use Flutter golden artifact names. They can still be deleted with Delete all.',
            ],
    );
  }

  Future<List<int>> readImage(
    FailureImageChange change, {
    required bool before,
  }) async {
    final artifact = change.artifacts[
        before ? FailureArtifactKind.expected : FailureArtifactKind.actual];
    if (artifact == null) {
      throw const GitReviewException('This side of the image does not exist.');
    }
    final file = File(_absolutePath(artifact.relativePath));
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const GitReviewException(
        'Failure image changed. Refresh the comparison.',
        conflict: true,
      );
    }
    final stat = await file.stat();
    if (stat.size != artifact.byteSize ||
        stat.modified.microsecondsSinceEpoch != artifact.modifiedMicroseconds) {
      throw const GitReviewException(
        'Failure image changed. Refresh the comparison.',
        conflict: true,
      );
    }
    if (stat.size > reviewMaxImageBytes) {
      throw const GitReviewException('Image exceeds the 32 MiB preview limit.');
    }
    return file.readAsBytes();
  }

  String _absolutePath(String relativePath) {
    final result = path.normalize(
      path.joinAll([inputDirectory.path, ...relativePath.split('/')]),
    );
    if (!path.isWithin(inputDirectory.path, result)) {
      throw const GitReviewException('Failure image is outside the review.');
    }
    return result;
  }

  static FailureArtifactKind _kind(String suffix) =>
      switch (suffix.toLowerCase()) {
        'masterimage' => FailureArtifactKind.expected,
        'testimage' => FailureArtifactKind.actual,
        'isolateddiff' => FailureArtifactKind.isolatedDiff,
        _ => FailureArtifactKind.maskedDiff,
      };
}

/// Calculates failure percentages sequentially outside the server isolate.
final class FailureImageDifferenceQueue {
  FailureImageDifferenceQueue(this.repository);

  final FailureImageRepository repository;
  final Queue<FailureImageChange> _queue = ListQueue();
  final Set<String> _queuedRevisions = {};
  final Map<String, GitImageDifference> _states = {};
  Set<String> _activeRevisions = {};
  Future<void>? _worker;
  bool _closed = false;

  GitImageDifference stateFor(FailureImageChange change) =>
      _states[change.revision] ?? const GitImageDifference.pending();

  void schedule(FailureImageSnapshot snapshot) {
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
          if (_activeRevisions.contains(change.revision)) {
            _states[change.revision] = GitImageDifference.ready(
              changedPixels: result.changedPixels,
              totalPixels: result.totalPixels,
            );
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
}
