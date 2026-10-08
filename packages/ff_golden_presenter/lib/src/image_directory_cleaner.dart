import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

/// A fixed, verified set of files awaiting explicit cleanup confirmation.
final class ImageCleanupPlan {
  ImageCleanupPlan._(this.files, this._hashes);
  final List<ImageCleanupFile> files;
  final Map<String, String> _hashes;
  int get totalBytes => files.fold(0, (sum, file) => sum + file.byteSize);
}

/// Includes partial completion when a file becomes unavailable during cleanup.
final class ImageCleanupException implements Exception {
  const ImageCleanupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// An image found below a configured directory marker.
final class ImageCleanupFile {
  /// Creates immutable metadata for one matching image.
  const ImageCleanupFile({
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

/// The result of scanning for or deleting images in marked directories.
final class ImageCleanupResult {
  /// Creates a cleanup summary.
  const ImageCleanupResult({
    required this.fileCount,
    required this.totalBytes,
  });

  /// Number of matching images.
  final int fileCount;

  /// Combined byte size of the matching images.
  final int totalBytes;
}

/// Shared scan and verified deletion for images in exact directory markers.
/// Symlinks below the input are never followed.
class ImageDirectoryCleaner {
  /// Creates a guarded cleaner rooted at [inputDirectory].
  ImageDirectoryCleaner({
    required Directory inputDirectory,
    required this.directoryName,
    required this.imageLabel,
    this.excludedDirectories = const {},
    Set<String> extensions = const {'png'},
  })  : inputDirectory = Directory(
          path.normalize(path.absolute(inputDirectory.path)),
        ),
        extensions = Set.unmodifiable(
          extensions
              .map((extension) => extension.replaceFirst('.', '').toLowerCase())
              .where((extension) => extension.isNotEmpty),
        );

  /// Exact directory marker required in each image's ancestry.
  final String directoryName;

  /// Description used in errors, such as `failure` or `golden`.
  final String imageLabel;

  /// Exact directory names whose contents are excluded.
  final Set<String> excludedDirectories;

  /// Normalized scan root.
  final Directory inputDirectory;

  /// Lowercase image extensions eligible for deletion.
  final Set<String> extensions;

  /// Finds matching images and deletes them unless [dryRun] is true.
  Future<ImageCleanupResult> clean({bool dryRun = false}) async {
    final files = await scan();
    if (dryRun) {
      return ImageCleanupResult(
        fileCount: files.length,
        totalBytes: files.fold(0, (sum, file) => sum + file.byteSize),
      );
    }
    return cleanPrepared(await prepare(files));
  }

  /// Hash streams instead of decoding images or retaining their bytes.
  Future<ImageCleanupPlan> prepare(Iterable<ImageCleanupFile> files) async {
    await _validateInput();
    final selected = {for (final file in files) file.relativePath: file}
        .values
        .toList()
      ..sort((a, b) => a.relativePath.compareTo(b.relativePath));
    final hashes = <String, String>{};
    for (final file in selected) {
      hashes[file.relativePath] = await _fingerprint(file);
    }
    return ImageCleanupPlan._(
        List.unmodifiable(selected), Map.unmodifiable(hashes));
  }

  /// Never rescans or expands a confirmed selection. Check every file before any delete.
  Future<ImageCleanupResult> cleanPrepared(ImageCleanupPlan plan) async {
    for (final file in plan.files) {
      if (await _fingerprint(file) != plan._hashes[file.relativePath]) {
        throw ImageCleanupException(
            '$imageLabel image changed: ${file.relativePath}. Nothing was deleted; review and confirm again.');
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
      throw ImageCleanupException(
          'Deleted $removed/${plan.files.length} $imageLabel images. $error');
    }
    return ImageCleanupResult(fileCount: removed, totalBytes: bytes);
  }

  Future<String> _fingerprint(ImageCleanupFile artifact) async {
    final file = await _validateFile(artifact);
    final hash = (await sha256.bind(file.openRead()).first).toString();
    await _validateFile(artifact);
    return hash;
  }

  Future<File> _validateFile(ImageCleanupFile artifact) async {
    final absolute = _absolutePath(artifact.relativePath);
    if (!path.isWithin(inputDirectory.path, absolute) ||
        !_isTargetImage(absolute)) {
      throw ImageCleanupException('Invalid $imageLabel image path.');
    }
    // Check all parents without following links, including a replaced input root.
    var parent = path.dirname(absolute);
    while (true) {
      if (await FileSystemEntity.type(parent, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw ImageCleanupException(
            '$imageLabel image directory changed. Review and confirm again.');
      }
      if (path.equals(parent, inputDirectory.path)) break;
      parent = path.dirname(parent);
    }
    if (await FileSystemEntity.type(absolute, followLinks: false) !=
        FileSystemEntityType.file) {
      throw ImageCleanupException(
          '$imageLabel image changed: ${artifact.relativePath}. Review and confirm again.');
    }
    final file = File(absolute), stat = await File(absolute).stat();
    if (stat.size != artifact.byteSize ||
        stat.modified.microsecondsSinceEpoch != artifact.modifiedMicroseconds ||
        artifact.changedMicroseconds != null &&
            stat.changed.microsecondsSinceEpoch !=
                artifact.changedMicroseconds) {
      throw ImageCleanupException(
          '$imageLabel image changed: ${artifact.relativePath}. Review and confirm again.');
    }
    return file;
  }

  /// Lists matching images without following symbolic links.
  Future<List<ImageCleanupFile>> scan() async {
    await _validateInput();
    if (extensions.isEmpty) {
      throw FormatException('$imageLabel image extensions must not be empty.');
    }

    final files = <ImageCleanupFile>[];
    await for (final entity in inputDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !_isTargetImage(entity.path)) continue;
      final stat = await entity.stat();
      files.add(ImageCleanupFile(
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

  bool _isTargetImage(String filePath) {
    final relativePath = path.relative(filePath, from: inputDirectory.path);
    final segments = path.split(relativePath);
    final directories = [
      path.basename(inputDirectory.path),
      ...segments.take(segments.length - 1)
    ];
    if (!directories.contains(directoryName) ||
        path.split(path.dirname(filePath)).any(excludedDirectories.contains)) {
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
        'Refusing to clean $imageLabel images from filesystem root: $inputPath',
      );
    }

    final resolved =
        path.normalize(await inputDirectory.resolveSymbolicLinks());
    if (path.equals(resolved, rootPath)) {
      throw FormatException(
          'Refusing to clean $imageLabel images from filesystem root: $inputPath');
    }
    final homePath = _homeDirectoryPath;
    if (homePath != null &&
        path.equals(resolved,
            path.normalize(await Directory(homePath).resolveSymbolicLinks()))) {
      throw FormatException(
        'Refusing to clean $imageLabel images from the home directory: $inputPath',
      );
    }

    if (await FileSystemEntity.type(inputPath, followLinks: false) ==
        FileSystemEntityType.link) {
      throw FormatException(
          'Refusing to clean through a symbolic-link input: $inputPath');
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
