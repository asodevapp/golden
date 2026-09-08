import 'dart:convert';
import 'dart:io';

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
    this.changedMicroseconds,
  });

  final String relativePath;
  final int byteSize;
  final int modifiedMicroseconds;

  /// Metadata change time also detects rewrites that preserve modification time.
  final int? changedMicroseconds;

  String get revisionPart =>
      '$relativePath\u0000$byteSize\u0000$modifiedMicroseconds\u0000$changedMicroseconds';
}

/// One Flutter golden failure, grouping its expected, actual and diff images.
final class FailureImageChange {
  FailureImageChange({
    required this.path,
    required Map<FailureArtifactKind, FailureImageArtifact> artifacts,
  }) : artifacts = Map.unmodifiable(artifacts);

  final String path;
  final Map<FailureArtifactKind, FailureImageArtifact> artifacts;

  late final String id = base64Url.encode(utf8.encode('failure\u0000$path'));
  late final String revision = sha256
      .convert(utf8.encode([
        id,
        for (final kind in FailureArtifactKind.values)
          if (artifacts[kind] != null)
            '${kind.name}\u0000${artifacts[kind]!.revisionPart}',
      ].join('\u0000')))
      .toString();
  // Generated masks/diffs do not affect the expected-versus-actual percentage.
  late final String differenceKey =
      '${artifacts[FailureArtifactKind.expected]?.revisionPart}\u0000'
      '${artifacts[FailureArtifactKind.actual]?.revisionPart}';
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
        changedMicroseconds: file.changedMicroseconds,
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
        stat.modified.microsecondsSinceEpoch != artifact.modifiedMicroseconds ||
        (artifact.changedMicroseconds != null &&
            stat.changed.microsecondsSinceEpoch !=
                artifact.changedMicroseconds)) {
      throw const GitReviewException(
        'Failure image changed. Refresh the comparison.',
        conflict: true,
      );
    }
    if (stat.size > reviewMaxImageBytes) {
      throw const GitReviewException('Image exceeds the 32 MiB preview limit.');
    }
    final bytes = await file.readAsBytes();
    final after = await file.stat();
    if (bytes.length != stat.size ||
        after.size != stat.size ||
        after.modified != stat.modified ||
        after.changed != stat.changed) {
      throw const GitReviewException(
        'Failure image changed. Refresh the comparison.',
        conflict: true,
      );
    }
    return bytes;
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
  FailureImageDifferenceQueue(this.repository) {
    _queue = ImageDifferenceQueue((change) => readImageDifference(
          hasBefore: change.hasBefore,
          hasAfter: change.hasAfter,
          read: (before) => repository.readImage(change, before: before),
        ));
  }

  final FailureImageRepository repository;
  late final ImageDifferenceQueue<FailureImageChange> _queue;

  GitImageDifference stateFor(FailureImageChange change) =>
      _queue.stateFor(change.differenceKey);

  void schedule(FailureImageSnapshot snapshot) => _queue.schedule({
        for (final change in snapshot.changes) change.differenceKey: change,
      });

  Future<void> get idle => _queue.idle;
  Future<void> close() => _queue.close();
}
