import 'dart:io';

import 'package:path/path.dart' as path;

import 'publication_model.dart';

/// Copies project screenshots to a publication directory while preserving paths.
final class ScreenshotCollector {
  ScreenshotCollector({
    required Directory inputDirectory,
    required Directory outputDirectory,
    required Set<String> extensions,
  })  : _inputDirectory = inputDirectory,
        _outputDirectory = outputDirectory,
        _extensions = extensions
            .map((extension) => extension.replaceFirst('.', '').toLowerCase())
            .toSet();

  final Directory _inputDirectory;
  final Directory _outputDirectory;
  final Set<String> _extensions;

  Future<ScreenshotCollectionResult> collect({
    required bool clean,
    bool dryRun = false,
  }) async {
    final inputPath = path.normalize(path.absolute(_inputDirectory.path));
    final outputPath = path.normalize(path.absolute(_outputDirectory.path));
    if (!await Directory(inputPath).exists()) {
      throw FileSystemException('Input directory does not exist', inputPath);
    }
    if (path.equals(inputPath, outputPath)) {
      throw const FormatException(
        'Collection input and output directories must be different.',
      );
    }

    final files = await _findImages(inputPath, outputPath);
    var totalBytes = 0;
    for (final file in files) {
      totalBytes += await file.length();
    }

    if (dryRun) {
      return ScreenshotCollectionResult(
        fileCount: files.length,
        totalBytes: totalBytes,
      );
    }

    if (clean && await Directory(outputPath).exists()) {
      _validateCleanTarget(inputPath, outputPath);
      await Directory(outputPath).delete(recursive: true);
    }

    await Directory(outputPath).create(recursive: true);
    for (final file in files) {
      final relativePath = path.relative(file.path, from: inputPath);
      final destination = File(path.join(outputPath, relativePath));
      await destination.parent.create(recursive: true);
      await file.copy(destination.path);
    }

    return ScreenshotCollectionResult(
      fileCount: files.length,
      totalBytes: totalBytes,
    );
  }

  Future<List<File>> _findImages(String inputPath, String outputPath) async {
    final files = <File>[];
    await for (final entity in Directory(inputPath).list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final absolutePath = path.normalize(path.absolute(entity.path));
      if (path.equals(absolutePath, outputPath) ||
          path.isWithin(outputPath, absolutePath)) {
        continue;
      }
      final extension = path.extension(entity.path).replaceFirst('.', '');
      if (_extensions.contains(extension.toLowerCase())) {
        files.add(entity);
      }
    }
    files.sort((left, right) => left.path.compareTo(right.path));
    return files;
  }

  void _validateCleanTarget(String inputPath, String outputPath) {
    final root = path.rootPrefix(outputPath);
    final home = Platform.environment['HOME'];
    final current = path.normalize(path.absolute(Directory.current.path));
    final isHome = home != null &&
        path.equals(outputPath, path.normalize(path.absolute(home)));
    if (path.equals(outputPath, root) ||
        path.equals(outputPath, current) ||
        path.equals(outputPath, inputPath) ||
        path.isWithin(outputPath, inputPath) ||
        isHome) {
      throw FormatException(
        'Refusing to clean unsafe output directory: $outputPath',
      );
    }
  }
}
