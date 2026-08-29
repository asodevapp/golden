import 'dart:io';

import 'command_runner.dart';
import 'publication_model.dart';

enum HostOperatingSystem {
  macos,
  linux,
  windows,
  unsupported;

  static HostOperatingSystem get current {
    if (Platform.isMacOS) {
      return macos;
    }
    if (Platform.isLinux) {
      return linux;
    }
    if (Platform.isWindows) {
      return windows;
    }
    return unsupported;
  }
}

/// One package-manager command that can be shown or run explicitly.
final class ToolInstallCommand {
  const ToolInstallCommand({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;

  String get display => <String>[executable, ...arguments]
      .map((part) => part.contains(' ') ? '"$part"' : part)
      .join(' ');
}

/// Availability and installation guidance for one optimizer.
final class OptimizerToolDiagnostic {
  const OptimizerToolDiagnostic({
    required this.backend,
    required this.available,
    required this.installCommand,
    required this.manualInstallUrl,
  });

  final ImageOptimizerBackend backend;
  final bool available;
  final ToolInstallCommand? installCommand;
  final String manualInstallUrl;
}

/// Error raised when no compatible image optimizer can be used.
final class OptimizerToolException implements Exception {
  const OptimizerToolException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Detects, explains, and optionally installs external image optimizers.
final class OptimizerToolchain {
  OptimizerToolchain({
    CommandRunner runner = const SystemCommandRunner(),
    HostOperatingSystem? operatingSystem,
  })  : _runner = runner,
        _operatingSystem = operatingSystem ?? HostOperatingSystem.current;

  final CommandRunner _runner;
  final HostOperatingSystem _operatingSystem;

  HostOperatingSystem get operatingSystem => _operatingSystem;

  List<ImageOptimizerBackend> candidates(
    ImageOptimizationProfile profile,
    ImageOptimizerBackend requested,
  ) {
    if (profile == ImageOptimizationProfile.none) {
      return const [];
    }
    if (requested != ImageOptimizerBackend.auto) {
      _validateCompatibility(profile, requested);
      return [requested];
    }
    return switch (profile) {
      ImageOptimizationProfile.lossless => const [
          ImageOptimizerBackend.oxipng,
          ImageOptimizerBackend.imagemagick,
        ],
      ImageOptimizationProfile.balanced ||
      ImageOptimizationProfile.small =>
        const [
          ImageOptimizerBackend.pngquant,
          ImageOptimizerBackend.imagemagick,
        ],
      ImageOptimizationProfile.none => const [],
    };
  }

  Future<List<OptimizerToolDiagnostic>> diagnose(
    ImageOptimizationProfile profile,
    ImageOptimizerBackend requested,
  ) async {
    final diagnostics = <OptimizerToolDiagnostic>[];
    for (final backend in candidates(profile, requested)) {
      diagnostics.add(
        OptimizerToolDiagnostic(
          backend: backend,
          available: await isAvailable(backend),
          installCommand: await installCommand(backend),
          manualInstallUrl: manualInstallUrl(backend),
        ),
      );
    }
    return diagnostics;
  }

  Future<ImageOptimizerBackend> resolve(
    ImageOptimizationProfile profile,
    ImageOptimizerBackend requested, {
    required bool installTools,
    void Function(String message)? onMessage,
  }) async {
    final availableCandidates = candidates(profile, requested);
    if (availableCandidates.isEmpty) {
      throw const OptimizerToolException(
        'The "none" profile does not use an optimizer backend.',
      );
    }
    for (final backend in availableCandidates) {
      if (await isAvailable(backend)) {
        return backend;
      }
    }

    if (installTools) {
      ImageOptimizerBackend? installCandidate;
      ToolInstallCommand? command;
      final orderedCandidates = [
        if (_operatingSystem == HostOperatingSystem.windows &&
            availableCandidates.contains(ImageOptimizerBackend.imagemagick))
          ImageOptimizerBackend.imagemagick,
        ...availableCandidates.where(
          (backend) =>
              _operatingSystem != HostOperatingSystem.windows ||
              backend != ImageOptimizerBackend.imagemagick,
        ),
      ];
      for (final candidate in orderedCandidates) {
        final candidateCommand = await installCommand(candidate);
        if (candidateCommand != null) {
          installCandidate = candidate;
          command = candidateCommand;
          break;
        }
      }
      if (command != null) {
        final backendToInstall = installCandidate!;
        onMessage?.call(
          'Installing ${backendToInstall.cliName}: ${command.display}',
        );
        final result = await _runner.run(
          command.executable,
          command.arguments,
        );
        if (result.exitCode != 0) {
          final details = result.stderr.trim();
          throw OptimizerToolException(
            'Could not install ${backendToInstall.cliName} '
            '(exit ${result.exitCode})${details.isEmpty ? '.' : ': $details'}',
          );
        }
        if (await isAvailable(backendToInstall)) {
          return backendToInstall;
        }
        throw OptimizerToolException(
          '${backendToInstall.cliName} was installed but is not available '
          'on PATH. Restart the terminal and run doctor again.',
        );
      }
    }

    final diagnostics = await diagnose(profile, requested);
    final guidance = diagnostics.map((diagnostic) {
      final command = diagnostic.installCommand;
      if (command != null) {
        return '${diagnostic.backend.cliName}: ${command.display}';
      }
      return '${diagnostic.backend.cliName}: '
          '${diagnostic.manualInstallUrl}';
    }).join('\n');
    throw OptimizerToolException(
      'No compatible optimizer was found on PATH.\n$guidance\n'
      'Install one manually or pass --install-tools.',
    );
  }

  Future<bool> isAvailable(ImageOptimizerBackend backend) async {
    if (backend == ImageOptimizerBackend.auto) {
      return false;
    }
    final result = await _runner.run(
      executableFor(backend),
      const ['--version'],
    );
    return result.exitCode == 0;
  }

  String executableFor(ImageOptimizerBackend backend) => switch (backend) {
        ImageOptimizerBackend.pngquant => 'pngquant',
        ImageOptimizerBackend.oxipng => 'oxipng',
        ImageOptimizerBackend.imagemagick => 'magick',
        ImageOptimizerBackend.auto => throw const OptimizerToolException(
            'The auto backend must be resolved before execution.',
          ),
      };

  String manualInstallUrl(ImageOptimizerBackend backend) => switch (backend) {
        ImageOptimizerBackend.pngquant => 'https://pngquant.org/install.html',
        ImageOptimizerBackend.oxipng =>
          'https://github.com/oxipng/oxipng/releases',
        ImageOptimizerBackend.imagemagick =>
          'https://imagemagick.org/download/',
        ImageOptimizerBackend.auto => '',
      };

  Future<ToolInstallCommand?> installCommand(
    ImageOptimizerBackend backend,
  ) async {
    return switch (_operatingSystem) {
      HostOperatingSystem.macos => _macosInstallCommand(backend),
      HostOperatingSystem.linux => _linuxInstallCommand(backend),
      HostOperatingSystem.windows => _windowsInstallCommand(backend),
      HostOperatingSystem.unsupported => null,
    };
  }

  Future<ToolInstallCommand?> _macosInstallCommand(
    ImageOptimizerBackend backend,
  ) async {
    if (!await _commandExists('brew')) {
      return backend == ImageOptimizerBackend.oxipng
          ? _cargoInstallCommand()
          : null;
    }
    final package = switch (backend) {
      ImageOptimizerBackend.pngquant => 'pngquant',
      ImageOptimizerBackend.oxipng => 'oxipng',
      ImageOptimizerBackend.imagemagick => 'imagemagick',
      ImageOptimizerBackend.auto => null,
    };
    if (package == null) {
      return null;
    }
    return ToolInstallCommand(
      executable: 'brew',
      arguments: ['install', package],
    );
  }

  Future<ToolInstallCommand?> _linuxInstallCommand(
    ImageOptimizerBackend backend,
  ) async {
    if (backend == ImageOptimizerBackend.oxipng) {
      return _cargoInstallCommand();
    }
    final package =
        backend == ImageOptimizerBackend.pngquant ? 'pngquant' : 'imagemagick';
    if (await _commandExists('apt-get')) {
      return _withOptionalSudo('apt-get', ['install', '-y', package]);
    }
    if (await _commandExists('dnf')) {
      final dnfPackage = backend == ImageOptimizerBackend.imagemagick
          ? 'ImageMagick'
          : package;
      return _withOptionalSudo('dnf', ['install', '-y', dnfPackage]);
    }
    if (await _commandExists('pacman')) {
      return _withOptionalSudo(
        'pacman',
        ['-S', '--needed', '--noconfirm', package],
      );
    }
    return null;
  }

  Future<ToolInstallCommand?> _windowsInstallCommand(
    ImageOptimizerBackend backend,
  ) async {
    if (backend == ImageOptimizerBackend.oxipng) {
      return _cargoInstallCommand();
    }
    if (backend == ImageOptimizerBackend.imagemagick &&
        await _commandExists('winget')) {
      return const ToolInstallCommand(
        executable: 'winget',
        arguments: [
          'install',
          'ImageMagick.Q16-HDRI',
          '--accept-package-agreements',
          '--accept-source-agreements',
        ],
      );
    }
    return null;
  }

  Future<ToolInstallCommand?> _cargoInstallCommand() async {
    if (!await _commandExists('cargo')) {
      return null;
    }
    return const ToolInstallCommand(
      executable: 'cargo',
      arguments: ['install', 'oxipng'],
    );
  }

  Future<ToolInstallCommand> _withOptionalSudo(
    String executable,
    List<String> arguments,
  ) async {
    if (await _commandExists('sudo')) {
      return ToolInstallCommand(
        executable: 'sudo',
        arguments: [executable, ...arguments],
      );
    }
    return ToolInstallCommand(
      executable: executable,
      arguments: arguments,
    );
  }

  Future<bool> _commandExists(String executable) async {
    final result = await _runner.run(executable, const ['--version']);
    return result.exitCode == 0;
  }

  void _validateCompatibility(
    ImageOptimizationProfile profile,
    ImageOptimizerBackend backend,
  ) {
    if (backend == ImageOptimizerBackend.pngquant &&
        profile == ImageOptimizationProfile.lossless) {
      throw const FormatException(
        'pngquant is lossy and cannot be used with --profile lossless.',
      );
    }
    if (backend == ImageOptimizerBackend.oxipng &&
        profile != ImageOptimizationProfile.lossless) {
      throw const FormatException(
        'oxipng is lossless; use it with --profile lossless.',
      );
    }
  }
}
