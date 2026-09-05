import 'dart:io';

import 'package:path/path.dart' as path;

/// A generated image found below a directory named `failures`.
final class FailureArtifactFile {
  /// Creates immutable metadata for one generated failure image.
  const FailureArtifactFile({
    required this.relativePath,
    required this.byteSize,
    required this.modifiedMicroseconds,
  });

  /// Path relative to the configured cleanup input, using `/` separators.
  final String relativePath;

  /// File size captured during the scan.
  final int byteSize;

  /// Last modification time captured during the scan.
  final int modifiedMicroseconds;
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
    for (final artifact in files) {
      if (!dryRun) {
        await File(_absolutePath(artifact.relativePath)).delete();
      }
    }

    return FailureArtifactCleanupResult(
      fileCount: files.length,
      totalBytes: files.fold(0, (sum, file) => sum + file.byteSize),
    );
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
