import 'dart:io';

import 'package:ff_golden_presenter/ff_golden_presenter.dart';
import 'package:ff_golden_presenter/src/command_runner.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('auto selects pngquant and keeps only a smaller result', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'ff_golden_presenter_optimize_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final image = File(path.join(temporaryDirectory.path, 'example.png'));
    await image.writeAsBytes(List.filled(20, 1));
    final runner = _OptimizingRunner();

    final result = await ImageOptimizer(
      inputDirectory: temporaryDirectory,
      runner: runner,
    ).optimize(
      profile: ImageOptimizationProfile.balanced,
      requestedBackend: ImageOptimizerBackend.auto,
      jobs: 2,
      installTools: false,
    );

    expect(result.backend, ImageOptimizerBackend.pngquant);
    expect(result.optimizedFileCount, 1);
    expect(result.savedBytes, 16);
    expect(await image.readAsBytes(), [1, 2, 3, 4]);
    expect(
      await File('${image.path}.ff-golden-presenter.tmp.png').exists(),
      isFalse,
    );
  });

  test('rejects a lossy backend for the lossless profile', () async {
    final toolchain = OptimizerToolchain(runner: _UnavailableRunner());

    expect(
      () => toolchain.diagnose(
        ImageOptimizationProfile.lossless,
        ImageOptimizerBackend.pngquant,
      ),
      throwsFormatException,
    );
  });

  test('offers winget ImageMagick fallback on Windows', () async {
    final toolchain = OptimizerToolchain(
      runner: _WingetRunner(),
      operatingSystem: HostOperatingSystem.windows,
    );

    final diagnostics = await toolchain.diagnose(
      ImageOptimizationProfile.balanced,
      ImageOptimizerBackend.auto,
    );

    final imageMagick = diagnostics.singleWhere(
      (diagnostic) => diagnostic.backend == ImageOptimizerBackend.imagemagick,
    );
    expect(imageMagick.available, isFalse);
    expect(imageMagick.installCommand?.executable, 'winget');
    expect(
      imageMagick.installCommand?.arguments,
      contains('ImageMagick.Q16-HDRI'),
    );
  });

  test('installs the Windows ImageMagick fallback only when requested',
      () async {
    final runner = _InstallingWingetRunner();
    final toolchain = OptimizerToolchain(
      runner: runner,
      operatingSystem: HostOperatingSystem.windows,
    );

    final backend = await toolchain.resolve(
      ImageOptimizationProfile.balanced,
      ImageOptimizerBackend.auto,
      installTools: true,
    );

    expect(backend, ImageOptimizerBackend.imagemagick);
    expect(runner.installed, isTrue);
  });
}

final class _OptimizingRunner implements CommandRunner {
  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments,
  ) async {
    if (arguments.length == 1 && arguments.single == '--version') {
      return CommandResult(
        exitCode: executable == 'pngquant' ? 0 : 127,
        stdout: '',
        stderr: '',
      );
    }
    final outputIndex = arguments.indexOf('--output');
    await File(arguments[outputIndex + 1]).writeAsBytes([1, 2, 3, 4]);
    return const CommandResult(exitCode: 0, stdout: '', stderr: '');
  }
}

final class _UnavailableRunner implements CommandRunner {
  @override
  Future<CommandResult> run(String executable, List<String> arguments) async {
    return const CommandResult(exitCode: 127, stdout: '', stderr: '');
  }
}

final class _WingetRunner implements CommandRunner {
  @override
  Future<CommandResult> run(String executable, List<String> arguments) async {
    return CommandResult(
      exitCode: executable == 'winget' ? 0 : 127,
      stdout: '',
      stderr: '',
    );
  }
}

final class _InstallingWingetRunner implements CommandRunner {
  bool installed = false;

  @override
  Future<CommandResult> run(String executable, List<String> arguments) async {
    if (executable == 'winget' && arguments.length == 1) {
      return const CommandResult(exitCode: 0, stdout: '', stderr: '');
    }
    if (executable == 'winget' && arguments.first == 'install') {
      installed = true;
      return const CommandResult(exitCode: 0, stdout: '', stderr: '');
    }
    if (executable == 'magick' && installed) {
      return const CommandResult(exitCode: 0, stdout: '', stderr: '');
    }
    return const CommandResult(exitCode: 127, stdout: '', stderr: '');
  }
}
