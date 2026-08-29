import 'dart:io';

import 'package:path/path.dart' as path;

import 'command_runner.dart';
import 'optimizer_toolchain.dart';
import 'publication_model.dart';

/// Optimizes PNG files in place inside a publication staging directory.
final class ImageOptimizer {
  ImageOptimizer({
    required Directory inputDirectory,
    CommandRunner runner = const SystemCommandRunner(),
    OptimizerToolchain? toolchain,
  })  : _inputDirectory = inputDirectory,
        _runner = runner,
        _toolchain = toolchain ?? OptimizerToolchain(runner: runner);

  final Directory _inputDirectory;
  final CommandRunner _runner;
  final OptimizerToolchain _toolchain;

  Future<ImageOptimizationResult> optimize({
    required ImageOptimizationProfile profile,
    required ImageOptimizerBackend requestedBackend,
    required int jobs,
    required bool installTools,
    bool dryRun = false,
    void Function(String message)? onMessage,
  }) async {
    if (jobs < 1) {
      throw const FormatException('--jobs must be at least 1.');
    }
    if (!await _inputDirectory.exists()) {
      throw FileSystemException(
        'Optimization input directory does not exist',
        _inputDirectory.path,
      );
    }

    final files = await _findPngFiles();
    var bytesBefore = 0;
    for (final file in files) {
      bytesBefore += await file.length();
    }
    if (profile == ImageOptimizationProfile.none || files.isEmpty || dryRun) {
      return ImageOptimizationResult(
        fileCount: files.length,
        optimizedFileCount: 0,
        bytesBefore: bytesBefore,
        bytesAfter: bytesBefore,
        backend: null,
      );
    }

    final backend = await _toolchain.resolve(
      profile,
      requestedBackend,
      installTools: installTools,
      onMessage: onMessage,
    );
    var nextIndex = 0;
    var optimizedCount = 0;
    var completedCount = 0;
    final workerCount = jobs < files.length ? jobs : files.length;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= files.length) {
          return;
        }
        if (await _optimizeFile(files[index], profile, backend)) {
          optimizedCount++;
        }
        completedCount++;
        if (completedCount % 25 == 0 || completedCount == files.length) {
          onMessage?.call(
            'Optimized $completedCount/${files.length} PNG files...',
          );
        }
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));

    var bytesAfter = 0;
    for (final file in files) {
      bytesAfter += await file.length();
    }
    return ImageOptimizationResult(
      fileCount: files.length,
      optimizedFileCount: optimizedCount,
      bytesBefore: bytesBefore,
      bytesAfter: bytesAfter,
      backend: backend,
    );
  }

  Future<List<File>> _findPngFiles() async {
    final files = <File>[];
    await for (final entity in _inputDirectory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File &&
          path.extension(entity.path).toLowerCase() == '.png') {
        files.add(entity);
      }
    }
    files.sort((left, right) => left.path.compareTo(right.path));
    return files;
  }

  Future<bool> _optimizeFile(
    File file,
    ImageOptimizationProfile profile,
    ImageOptimizerBackend backend,
  ) async {
    final originalSize = await file.length();
    final temporaryFile = File('${file.path}.ff-golden-presenter.tmp.png');
    if (await temporaryFile.exists()) {
      await temporaryFile.delete();
    }

    final result = await _runner.run(
      _toolchain.executableFor(backend),
      _argumentsFor(
        backend: backend,
        profile: profile,
        inputPath: file.path,
        outputPath: temporaryFile.path,
      ),
    );
    if (backend == ImageOptimizerBackend.pngquant && result.exitCode == 98) {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      return false;
    }
    if (result.exitCode != 0) {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      final details = result.stderr.trim();
      throw OptimizerToolException(
        '${backend.cliName} failed for ${file.path} '
        '(exit ${result.exitCode})${details.isEmpty ? '.' : ': $details'}',
      );
    }
    if (!await temporaryFile.exists()) {
      throw OptimizerToolException(
        '${backend.cliName} did not create output for ${file.path}.',
      );
    }

    final optimizedSize = await temporaryFile.length();
    if (optimizedSize >= originalSize) {
      await temporaryFile.delete();
      return false;
    }
    await temporaryFile.copy(file.path);
    await temporaryFile.delete();
    return true;
  }

  List<String> _argumentsFor({
    required ImageOptimizerBackend backend,
    required ImageOptimizationProfile profile,
    required String inputPath,
    required String outputPath,
  }) {
    return switch (backend) {
      ImageOptimizerBackend.pngquant => [
          '--force',
          '--skip-if-larger',
          '--quality',
          profile == ImageOptimizationProfile.small ? '55-80' : '75-95',
          '--speed',
          profile == ImageOptimizationProfile.small ? '1' : '4',
          '--output',
          outputPath,
          inputPath,
        ],
      ImageOptimizerBackend.oxipng => [
          '-o',
          '4',
          '--strip',
          'safe',
          '--alpha',
          '--out',
          outputPath,
          inputPath,
        ],
      ImageOptimizerBackend.imagemagick => [
          inputPath,
          '-strip',
          if (profile != ImageOptimizationProfile.lossless) ...[
            if (profile == ImageOptimizationProfile.small) ...[
              '-dither',
              'FloydSteinberg',
            ],
            '-colors',
            profile == ImageOptimizationProfile.small ? '128' : '256',
          ],
          '-define',
          'png:compression-level=9',
          outputPath,
        ],
      ImageOptimizerBackend.auto => throw const OptimizerToolException(
          'The auto backend must be resolved before execution.',
        ),
    };
  }
}
