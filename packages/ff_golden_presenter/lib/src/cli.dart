import 'dart:io';

import 'package:path/path.dart' as path;

import 'catalog_scanner.dart';
import 'cli_options.dart';
import 'diff_cli.dart';
import 'failure_artifact_cleaner.dart';
import 'golden_image_factory.dart';
import 'golden_presenter.dart';
import 'html_report_renderer.dart';
import 'image_optimizer.dart';
import 'migration.dart';
import 'migration_cli_options.dart';
import 'optimizer_toolchain.dart';
import 'publication_cli_options.dart';
import 'publication_model.dart';
import 'publication_pipeline.dart';
import 'report_writer.dart';
import 'run_manifest.dart';
import 'screenshot_collector.dart';

const _actions = {
  'diff',
  'report',
  'collect',
  'optimize',
  'build',
  'doctor',
  'migrate',
  'clean-failures',
};

Future<int> runGoldenPresenter(
  List<String> arguments, {
  StringSink? output,
  StringSink? errors,
}) async {
  final out = output ?? stdout;
  final errorOutput = errors ?? stderr;

  if (arguments.isEmpty) {
    return _runReport(arguments, out, errorOutput);
  }
  if (arguments.length == 1 && arguments.first == '--version') {
    out.writeln('ff_golden_presenter $ffGoldenPresenterVersion');
    return 0;
  }
  if (arguments.length == 1 &&
      (arguments.first == '--help' || arguments.first == '-h')) {
    out.write(_rootUsage);
    return 0;
  }

  final first = arguments.first;
  if (!_actions.contains(first)) {
    return _runReport(arguments, out, errorOutput);
  }
  final actionArguments = arguments.skip(1).toList(growable: false);
  return switch (first) {
    'diff' => runDiff(actionArguments, out, errorOutput),
    'report' => _runReport(actionArguments, out, errorOutput),
    'collect' => _runCollect(actionArguments, out, errorOutput),
    'optimize' => _runOptimize(actionArguments, out, errorOutput),
    'build' => _runBuild(actionArguments, out, errorOutput),
    'doctor' => _runDoctor(actionArguments, out, errorOutput),
    'migrate' => _runMigrate(actionArguments, out, errorOutput),
    'clean-failures' => _runCleanFailures(actionArguments, out, errorOutput),
    _ => throw StateError('Unreachable action: $first'),
  };
}

Future<int> _runCleanFailures(
  List<String> arguments,
  StringSink out,
  StringSink errorOutput,
) async {
  late final CleanFailuresCliOptions options;
  try {
    options = CleanFailuresCliOptions.parse(arguments);
  } on FormatException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    errorOutput.writeln(
      CleanFailuresCliOptions.parse(const ['--help']).usage,
    );
    return 64;
  }
  if (options.showHelp) {
    out.write(options.usage);
    return 0;
  }

  final input = Directory(path.normalize(path.absolute(options.input)));
  if (!await input.exists()) {
    errorOutput.writeln(
      'Error: input directory does not exist: ${input.path}',
    );
    return 66;
  }
  try {
    final result = await FailureArtifactCleaner(
      inputDirectory: input,
      extensions: options.extensions,
    ).clean(dryRun: options.dryRun);
    final imageLabel =
        result.fileCount == 1 ? 'failure image' : 'failure images';
    out.writeln(
      '${options.dryRun ? 'Would delete' : 'Deleted'} '
      '${result.fileCount} $imageLabel (${_formatBytes(result.totalBytes)}) '
      'from ${input.path}',
    );
    return 0;
  } on FormatException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    return 64;
  } on FileSystemException catch (error) {
    return _reportFileSystemError(error, errorOutput);
  }
}

Future<int> _runReport(
  List<String> arguments,
  StringSink out,
  StringSink errorOutput,
) async {
  late final GoldenPresenterOptions options;
  try {
    options = GoldenPresenterOptions.parse(arguments);
  } on FormatException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    errorOutput.writeln(
      GoldenPresenterOptions.parse(const ['--help']).usage,
    );
    return 64;
  }

  if (options.showHelp) {
    out.write(options.usage);
    return 0;
  }
  if (options.showVersion) {
    out.writeln('ff_golden_presenter $ffGoldenPresenterVersion');
    return 0;
  }

  final inputPath = path.normalize(path.absolute(options.input));
  final outputPath = path.normalize(path.absolute(options.output));
  final inputDirectory = Directory(inputPath);
  if (!await inputDirectory.exists()) {
    errorOutput.writeln('Error: input directory does not exist: $inputPath');
    return 66;
  }

  try {
    final customization = await options.customization.resolve();
    final runIndex = await GoldenRunManifestLoader(
      projectDirectory: Directory.current,
      imageRoot: inputDirectory,
      manifestPaths: options.manifestPaths,
    ).load();
    if (runIndex.manifestCount > 0) {
      out.writeln(
        'Loaded ${runIndex.manifestCount} ff_golden.run shards with '
        '${runIndex.imageCount} captures.',
      );
    }
    final imageFactory = GoldenImageFactory(
      devicePattern: options.devicePattern,
      localePattern: options.localePattern,
      themePattern: options.themePattern,
    );
    final presenter = GoldenPresenter(
      scanner: GoldenCatalogScanner(
        inputDirectory: inputDirectory,
        imageFactory: imageFactory,
        runIndex: runIndex,
        goldenDirectoryName: options.goldenDirectory,
        extensions: options.extensions,
      ),
      renderer: HtmlReportRenderer(
        outputPath: outputPath,
        title: options.title,
        showSupportAttribution: options.supportAttribution,
        customization: customization,
      ),
      writer: HtmlReportWriter(outputPath: outputPath),
    );
    final result = await presenter.generate();
    out.writeln(
      'Generated ${result.catalog.imageCount} images across '
      '${result.catalog.scenarios.length} scenarios: $outputPath',
    );
    return 0;
  } on FormatException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    return 64;
  } on FileSystemException catch (error) {
    return _reportFileSystemError(error, errorOutput);
  }
}

Future<int> _runCollect(
  List<String> arguments,
  StringSink out,
  StringSink errorOutput,
) async {
  late final CollectCliOptions options;
  try {
    options = CollectCliOptions.parse(arguments);
  } on FormatException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    errorOutput.writeln(CollectCliOptions.parse(const ['--help']).usage);
    return 64;
  }
  if (options.showHelp) {
    out.write(options.usage);
    return 0;
  }

  final input = Directory(path.normalize(path.absolute(options.input)));
  if (!await input.exists()) {
    errorOutput.writeln(
      'Error: input directory does not exist: ${input.path}',
    );
    return 66;
  }
  final outputDirectory = Directory(
    path.normalize(path.absolute(options.outputDirectory)),
  );
  try {
    final result = await ScreenshotCollector(
      inputDirectory: input,
      outputDirectory: outputDirectory,
      extensions: options.extensions,
    ).collect(clean: options.clean, dryRun: options.dryRun);
    out.writeln(
      '${options.dryRun ? 'Would collect' : 'Collected'} '
      '${result.fileCount} images (${_formatBytes(result.totalBytes)}) '
      'to ${outputDirectory.path}',
    );
    return 0;
  } on FormatException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    return 64;
  } on FileSystemException catch (error) {
    return _reportFileSystemError(error, errorOutput);
  }
}

Future<int> _runOptimize(
  List<String> arguments,
  StringSink out,
  StringSink errorOutput,
) async {
  late final OptimizeCliOptions options;
  try {
    options = OptimizeCliOptions.parse(arguments);
  } on FormatException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    errorOutput.writeln(OptimizeCliOptions.parse(const ['--help']).usage);
    return 64;
  }
  if (options.showHelp) {
    out.write(options.usage);
    return 0;
  }

  final input = Directory(path.normalize(path.absolute(options.input)));
  if (!await input.exists()) {
    errorOutput.writeln(
      'Error: input directory does not exist: ${input.path}',
    );
    return 66;
  }
  try {
    final result = await ImageOptimizer(inputDirectory: input).optimize(
      profile: options.profile,
      requestedBackend: options.backend,
      jobs: options.jobs,
      installTools: options.installTools,
      dryRun: options.dryRun,
      onMessage: out.writeln,
    );
    if (options.dryRun) {
      out.writeln(
        'Would optimize ${result.fileCount} PNG files with '
        '${options.profile.cliName} profile.',
      );
    } else {
      out.writeln(
        'Optimized ${result.optimizedFileCount}/${result.fileCount} PNG files'
        '${result.backend == null ? '' : ' with ${result.backend!.cliName}'}; '
        'saved ${_formatBytes(result.savedBytes)}.',
      );
    }
    return 0;
  } on FormatException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    return 64;
  } on OptimizerToolException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    return 69;
  } on FileSystemException catch (error) {
    return _reportFileSystemError(error, errorOutput);
  }
}

Future<int> _runBuild(
  List<String> arguments,
  StringSink out,
  StringSink errorOutput,
) async {
  late final BuildCliOptions options;
  try {
    options = BuildCliOptions.parse(arguments);
  } on FormatException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    errorOutput.writeln(BuildCliOptions.parse(const ['--help']).usage);
    return 64;
  }
  if (options.showHelp) {
    out.write(options.usage);
    return 0;
  }

  final input = Directory(path.normalize(path.absolute(options.input)));
  if (!await input.exists()) {
    errorOutput.writeln(
      'Error: input directory does not exist: ${input.path}',
    );
    return 66;
  }
  final outputDirectory = Directory(
    path.normalize(path.absolute(options.outputDirectory)),
  );
  try {
    final customization = await options.customization.resolve();
    final result = await GoldenPublicationPipeline(
      options: GoldenPublicationOptions(
        inputDirectory: input,
        outputDirectory: outputDirectory,
        reportFileName: options.reportFileName,
        title: options.title,
        goldenDirectory: options.goldenDirectory,
        extensions: options.extensions,
        devicePattern: options.devicePattern,
        localePattern: options.localePattern,
        themePattern: options.themePattern,
        manifestPaths: options.manifestPaths,
        supportAttribution: options.supportAttribution,
        customization: customization,
        profile: options.profile,
        backend: options.backend,
        jobs: options.jobs,
        clean: options.clean,
        installTools: options.installTools,
        dryRun: options.dryRun,
      ),
    ).run(onMessage: out.writeln);
    if (options.dryRun) {
      out.writeln('Would create report: ${result.reportPath}');
    } else {
      out.writeln(
        'Generated ${result.report!.catalog.imageCount} images across '
        '${result.report!.catalog.scenarios.length} scenarios: '
        '${result.reportPath}',
      );
    }
    return 0;
  } on FormatException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    return 64;
  } on OptimizerToolException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    return 69;
  } on FileSystemException catch (error) {
    return _reportFileSystemError(error, errorOutput);
  }
}

Future<int> _runDoctor(
  List<String> arguments,
  StringSink out,
  StringSink errorOutput,
) async {
  late final DoctorCliOptions options;
  try {
    options = DoctorCliOptions.parse(arguments);
  } on FormatException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    errorOutput.writeln(DoctorCliOptions.parse(const ['--help']).usage);
    return 64;
  }
  if (options.showHelp) {
    out.write(options.usage);
    return 0;
  }
  if (options.profile == ImageOptimizationProfile.none) {
    out.writeln('Profile none does not require external tools.');
    return 0;
  }

  final toolchain = OptimizerToolchain();
  out.writeln(
    'Platform: ${toolchain.operatingSystem.name}; '
    'profile: ${options.profile.cliName}',
  );
  try {
    if (options.installTools) {
      final backend = await toolchain.resolve(
        options.profile,
        options.backend,
        installTools: true,
        onMessage: out.writeln,
      );
      out.writeln('Ready: ${backend.cliName}');
      return 0;
    }

    final diagnostics = await toolchain.diagnose(
      options.profile,
      options.backend,
    );
    var hasAvailableTool = false;
    for (final diagnostic in diagnostics) {
      hasAvailableTool = hasAvailableTool || diagnostic.available;
      final state = diagnostic.available ? 'available' : 'missing';
      out.writeln('${diagnostic.backend.cliName}: $state');
      if (!diagnostic.available) {
        final command = diagnostic.installCommand;
        out.writeln(
          command == null
              ? '  Install: ${diagnostic.manualInstallUrl}'
              : '  Install: ${command.display}',
        );
      }
    }
    return hasAvailableTool ? 0 : 69;
  } on FormatException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    return 64;
  } on OptimizerToolException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    return 69;
  }
}

Future<int> _runMigrate(
  List<String> arguments,
  StringSink out,
  StringSink errorOutput,
) async {
  late final MigrationCliOptions options;
  try {
    options = MigrationCliOptions.parse(arguments);
  } on FormatException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    errorOutput.writeln(MigrationCliOptions.parse(const ['--help']).usage);
    return 64;
  }
  if (options.showHelp) {
    out.write(options.usage);
    return 0;
  }

  final project = Directory(path.normalize(path.absolute(options.project)));
  if (!await project.exists()) {
    errorOutput.writeln(
      'Error: project directory does not exist: ${project.path}',
    );
    return 66;
  }

  try {
    final result = await FfGoldenProjectMigrator(
      projectDirectory: project,
    ).run(apply: options.apply);
    for (final finding in result.safeChanges) {
      final verb = result.applied ? 'changed' : 'would change';
      out.writeln(
        '$verb ${finding.filePath}:${finding.line}: ${finding.message}',
      );
    }
    for (final finding in result.manualReviews) {
      out.writeln(
        'review ${finding.filePath}:${finding.line}: ${finding.message}',
      );
    }
    out.writeln(
      'Scanned ${result.scannedFiles} files; '
      '${result.changedFiles} files changed; '
      '${result.safeChanges.length} safe changes; '
      '${result.manualReviews.length} manual reviews.',
    );

    if (options.check && !result.isClean) {
      errorOutput.writeln('Migration findings remain.');
      return 1;
    }
    return 0;
  } on FileSystemException catch (error) {
    return _reportFileSystemError(error, errorOutput);
  }
}

int _reportFileSystemError(
  FileSystemException error,
  StringSink errorOutput,
) {
  final location = error.path == null ? '' : ' (${error.path})';
  errorOutput.writeln('Error: ${error.message}$location');
  return 74;
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kibibytes = bytes / 1024;
  if (kibibytes < 1024) {
    return '${kibibytes.toStringAsFixed(1)} KiB';
  }
  return '${(kibibytes / 1024).toStringAsFixed(1)} MiB';
}

const _rootUsage = '''
Generate reports or build an optimized, publication-ready image catalog.

Usage: ff_golden_presenter [options]
       ff_golden_presenter <action> [options]

Actions:
  diff      Review local Git image changes and stage/unstage selected files.
  report    Generate HTML from images in place (default; legacy compatible).
  collect   Copy project screenshots into a staging directory.
  optimize  Optimize staged PNG files with an explicit profile.
  build     Collect, optimize, and generate index.html in one command.
  doctor    Check tools and show installation guidance for this platform.
  migrate   Audit or safely rename golden packages in an existing project.
  clean-failures
            Delete generated images below failures directories.

Run ff_golden_presenter <action> --help for action-specific options.
''';
