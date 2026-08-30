import 'dart:io';

import 'package:path/path.dart' as path;

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
    await _validateInput();
    if (extensions.isEmpty) {
      throw const FormatException(
          'Failure image extensions must not be empty.');
    }

    final files = <File>[];
    await for (final entity in inputDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !_isFailureImage(entity.path)) continue;
      files.add(entity);
    }
    files.sort((left, right) => left.path.compareTo(right.path));

    var totalBytes = 0;
    for (final file in files) {
      totalBytes += await file.length();
      if (!dryRun) await file.delete();
    }

    return FailureArtifactCleanupResult(
      fileCount: files.length,
      totalBytes: totalBytes,
    );
  }

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
