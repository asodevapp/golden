import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

/// A fixed, verified set of files awaiting explicit cleanup confirmation.
final class FailureArtifactCleanupPlan {
  FailureArtifactCleanupPlan._(this.files, this._hashes);
  final List<FailureArtifactFile> files;
  final Map<String, String> _hashes;
  int get totalBytes => files.fold(0, (sum, file) => sum + file.byteSize);
}

/// Includes partial completion when a file becomes unavailable during cleanup.
final class FailureArtifactCleanupException implements Exception {
  const FailureArtifactCleanupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A generated image found below a directory named `failures`.
final class FailureArtifactFile {
  /// Creates immutable metadata for one generated failure image.
  const FailureArtifactFile({
    required this.relativePath,
    required this.byteSize,
    required this.modifiedMicroseconds,
    this.changedMicroseconds,
  });

  /// Path relative to the configured cleanup input, using `/` separators.
  final String relativePath;

  /// File size captured during the scan.
  final int byteSize;

  /// Last modification time captured during the scan.
  final int modifiedMicroseconds;

  /// Metadata change time also detects rewrites that preserve modification time.
  final int? changedMicroseconds;
}

/// The result of scanning for or deleting golden comparison failure images.
final class FailureArtifactCleanupResult {
  /// Creates a cleanup summary.
  const FailureArtifactCleanupResult({
    required this.fileCount,
    required this.totalBytes,
  });

  /// Number of matching failure images.
  final int fileCount;

  /// Combined byte size of the matching images.
  final int totalBytes;
}

/// Deletes generated images below directories named `failures`.
///
/// Flutter's local golden comparator writes diagnostic images such as
/// `masterImage.png`, `testImage.png`, `isolatedDiff.png`, and
/// `maskedDiff.png` into these directories. Symlinks are never followed.
final class FailureArtifactCleaner {
  /// Creates a guarded cleaner rooted at [inputDirectory].
  FailureArtifactCleaner({
    required Directory inputDirectory,
    Set<String> extensions = const {'png'},
  })  : inputDirectory = Directory(
          path.normalize(path.absolute(inputDirectory.path)),
        ),
        extensions = Set.unmodifiable(
          extensions
              .map((extension) => extension.replaceFirst('.', '').toLowerCase())
              .where((extension) => extension.isNotEmpty),
        );

  /// Normalized root searched for `failures` directories.
  final Directory inputDirectory;

  /// Lowercase image extensions eligible for deletion.
  final Set<String> extensions;

  /// Finds failure images and deletes them unless [dryRun] is true.
  Future<FailureArtifactCleanupResult> clean({bool dryRun = false}) async {
    final files = await scan();
    if (dryRun) {
      return FailureArtifactCleanupResult(
        fileCount: files.length,
        totalBytes: files.fold(0, (sum, file) => sum + file.byteSize),
      );
    }
    return cleanPrepared(await prepare(files));
  }

  /// Hash streams instead of decoding images or retaining their bytes.
  Future<FailureArtifactCleanupPlan> prepare(
      Iterable<FailureArtifactFile> files) async {
    await _validateInput();
    final selected = {for (final file in files) file.relativePath: file}
        .values
        .toList()
      ..sort((a, b) => a.relativePath.compareTo(b.relativePath));
    final hashes = <String, String>{};
    for (final file in selected) {
      hashes[file.relativePath] = await _fingerprint(file);
    }
    return FailureArtifactCleanupPlan._(
        List.unmodifiable(selected), Map.unmodifiable(hashes));
  }

  /// Never rescans or expands a confirmed selection. Check every file before any delete.
  Future<FailureArtifactCleanupResult> cleanPrepared(
      FailureArtifactCleanupPlan plan) async {
    for (final file in plan.files) {
      if (await _fingerprint(file) != plan._hashes[file.relativePath]) {
        throw FailureArtifactCleanupException(
            'Failure image changed: ${file.relativePath}. Nothing was deleted; review and confirm again.');
      }
    }
    var removed = 0, bytes = 0;
    try {
      for (final artifact in plan.files) {
        final file = await _validateFile(artifact);
        await file.delete();
        removed++;
        bytes += artifact.byteSize;
      }
    } on Object catch (error) {
      throw FailureArtifactCleanupException(
          'Deleted $removed/${plan.files.length} failure images. $error');
    }
    return FailureArtifactCleanupResult(fileCount: removed, totalBytes: bytes);
  }

  Future<String> _fingerprint(FailureArtifactFile artifact) async {
    final file = await _validateFile(artifact);
    final hash = (await sha256.bind(file.openRead()).first).toString();
    await _validateFile(artifact);
    return hash;
  }

  Future<File> _validateFile(FailureArtifactFile artifact) async {
    final absolute = _absolutePath(artifact.relativePath);
    if (!path.isWithin(inputDirectory.path, absolute) ||
        !_isFailureImage(absolute)) {
      throw const FailureArtifactCleanupException(
          'Invalid failure image path.');
    }
    // Check all parents without following links, including a replaced input root.
    var parent = path.dirname(absolute);
    while (true) {
      if (await FileSystemEntity.type(parent, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const FailureArtifactCleanupException(
            'Failure image directory changed. Review and confirm again.');
      }
      if (path.equals(parent, inputDirectory.path)) break;
      parent = path.dirname(parent);
    }
    if (await FileSystemEntity.type(absolute, followLinks: false) !=
        FileSystemEntityType.file) {
      throw FailureArtifactCleanupException(
          'Failure image changed: ${artifact.relativePath}. Review and confirm again.');
    }
    final file = File(absolute), stat = await File(absolute).stat();
    if (stat.size != artifact.byteSize ||
        stat.modified.microsecondsSinceEpoch != artifact.modifiedMicroseconds ||
        artifact.changedMicroseconds != null &&
            stat.changed.microsecondsSinceEpoch !=
                artifact.changedMicroseconds) {
      throw FailureArtifactCleanupException(
          'Failure image changed: ${artifact.relativePath}. Review and confirm again.');
    }
    return file;
  }

  /// Lists generated failure images without following symbolic links.
  Future<List<FailureArtifactFile>> scan() async {
    await _validateInput();
    if (extensions.isEmpty) {
      throw const FormatException(
          'Failure image extensions must not be empty.');
    }

    final files = <FailureArtifactFile>[];
    await for (final entity in inputDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !_isFailureImage(entity.path)) continue;
      final stat = await entity.stat();
      files.add(FailureArtifactFile(
        relativePath: path
            .relative(entity.path, from: inputDirectory.path)
            .split(path.separator)
            .join('/'),
        byteSize: stat.size,
        modifiedMicroseconds: stat.modified.microsecondsSinceEpoch,
        changedMicroseconds: stat.changed.microsecondsSinceEpoch,
      ));
    }
    files
        .sort((left, right) => left.relativePath.compareTo(right.relativePath));
    return files;
  }

  String _absolutePath(String relativePath) => path.normalize(
        path.joinAll([inputDirectory.path, ...relativePath.split('/')]),
      );

  bool _isFailureImage(String filePath) {
    final relativePath = path.relative(filePath, from: inputDirectory.path);
    final segments = path.split(relativePath);
    final inputIsFailureDirectory =
        path.basename(inputDirectory.path) == 'failures';
    if (!inputIsFailureDirectory && !segments.contains('failures')) {
      return false;
    }
    final extension =
        path.extension(filePath).replaceFirst('.', '').toLowerCase();
    return extensions.contains(extension);
  }

  Future<void> _validateInput() async {
    final inputPath = inputDirectory.path;
    final rootPath = path.normalize(path.rootPrefix(inputPath));
    if (path.equals(inputPath, rootPath)) {
      throw FormatException(
        'Refusing to clean failure images from filesystem root: $inputPath',
      );
    }

    final homePath = _homeDirectoryPath;
    if (homePath != null && path.equals(inputPath, homePath)) {
      throw FormatException(
        'Refusing to clean failure images from the home directory: $inputPath',
      );
    }

    if (!await inputDirectory.exists()) {
      throw FileSystemException(
        'Input directory does not exist',
        inputDirectory.path,
      );
    }
  }

  String? get _homeDirectoryPath {
    final environment = Platform.environment;
    final home = environment['HOME'] ?? environment['USERPROFILE'];
    if (home == null || home.isEmpty) return null;
    return path.normalize(path.absolute(home));
  }
}
