import 'dart:io';

import 'package:args/args.dart';

import 'publication_model.dart';

const publicationInputDefault = 'test/screens';
const publicationOutputDefault = 'build/golden-report';
const publicationExtensionsDefault = ['png', 'jpg', 'jpeg', 'webp', 'svg'];

final class CollectCliOptions {
  CollectCliOptions._({
    required this.input,
    required this.outputDirectory,
    required this.extensions,
    required this.clean,
    required this.dryRun,
    required this.showHelp,
    required ArgParser parser,
  }) : _parser = parser;

  final String input;
  final String outputDirectory;
  final Set<String> extensions;
  final bool clean;
  final bool dryRun;
  final bool showHelp;
  final ArgParser _parser;

  static CollectCliOptions parse(List<String> arguments) {
    final parser = _collectionParser();
    final results = parser.parse(arguments);
    _rejectRest(results);
    return CollectCliOptions._(
      input: results['input'] as String,
      outputDirectory: results['output-directory'] as String,
      extensions: _parseExtensions(results),
      clean: results['clean'] as bool,
      dryRun: results['dry-run'] as bool,
      showHelp: results['help'] as bool,
      parser: parser,
    );
  }

  String get usage => '''
Collect screenshots into an isolated publication directory.

Usage: ff_golden_presenter collect [options]

${_parser.usage}

Example:
  dart run ff_golden_presenter collect --input test/screens --clean
''';
}

final class OptimizeCliOptions {
  OptimizeCliOptions._({
    required this.input,
    required this.profile,
    required this.backend,
    required this.jobs,
    required this.installTools,
    required this.inPlace,
    required this.dryRun,
    required this.showHelp,
    required ArgParser parser,
  }) : _parser = parser;

  final String input;
  final ImageOptimizationProfile profile;
  final ImageOptimizerBackend backend;
  final int jobs;
  final bool installTools;
  final bool inPlace;
  final bool dryRun;
  final bool showHelp;
  final ArgParser _parser;

  static OptimizeCliOptions parse(List<String> arguments) {
    final parser =
        _optimizationParser(includeInput: true, includeInPlace: true);
    final results = parser.parse(arguments);
    _rejectRest(results);
    final options = OptimizeCliOptions._(
      input: results['input'] as String,
      profile: ImageOptimizationProfile.parse(results['profile'] as String),
      backend: ImageOptimizerBackend.parse(results['backend'] as String),
      jobs: _parseJobs(results),
      installTools: results['install-tools'] as bool,
      inPlace: results['in-place'] as bool,
      dryRun: results['dry-run'] as bool,
      showHelp: results['help'] as bool,
      parser: parser,
    );
    if (!options.showHelp &&
        !options.dryRun &&
        options.profile != ImageOptimizationProfile.none &&
        !options.inPlace) {
      throw const FormatException(
        'optimize changes PNG files. Pass --in-place or use --dry-run.',
      );
    }
    return options;
  }

  String get usage => '''
Optimize PNG files in a staging directory.

Usage: ff_golden_presenter optimize [options]

${_parser.usage}

Example:
  dart run ff_golden_presenter optimize --input build/golden-report --profile balanced --in-place
''';
}

final class BuildCliOptions {
  BuildCliOptions._({
    required this.input,
    required this.outputDirectory,
    required this.reportFileName,
    required this.title,
    required this.goldenDirectory,
    required this.extensions,
    required this.devicePattern,
    required this.localePattern,
    required this.themePattern,
    required this.manifestPaths,
    required this.supportAttribution,
    required this.profile,
    required this.backend,
    required this.jobs,
    required this.clean,
    required this.installTools,
    required this.dryRun,
    required this.showHelp,
    required ArgParser parser,
  }) : _parser = parser;

  final String input;
  final String outputDirectory;
  final String reportFileName;
  final String title;
  final String goldenDirectory;
  final Set<String> extensions;
  final String devicePattern;
  final String localePattern;
  final String themePattern;
  final List<String> manifestPaths;
  final bool supportAttribution;
  final ImageOptimizationProfile profile;
  final ImageOptimizerBackend backend;
  final int jobs;
  final bool clean;
  final bool installTools;
  final bool dryRun;
  final bool showHelp;
  final ArgParser _parser;

  static BuildCliOptions parse(List<String> arguments) {
    final parser = _buildParser();
    final results = parser.parse(arguments);
    _rejectRest(results);
    return BuildCliOptions._(
      input: results['input'] as String,
      outputDirectory: results['output-directory'] as String,
      reportFileName: results['report-file'] as String,
      title: results['title'] as String,
      goldenDirectory: results['golden-directory'] as String,
      extensions: _parseExtensions(results),
      devicePattern: results['device-pattern'] as String,
      localePattern: results['locale-pattern'] as String,
      themePattern: results['theme-pattern'] as String,
      manifestPaths: List.unmodifiable(results['manifest'] as List<String>),
      supportAttribution: results['support-attribution'] as bool,
      profile: ImageOptimizationProfile.parse(results['profile'] as String),
      backend: ImageOptimizerBackend.parse(results['backend'] as String),
      jobs: _parseJobs(results),
      clean: results['clean'] as bool,
      installTools: results['install-tools'] as bool,
      dryRun: results['dry-run'] as bool,
      showHelp: results['help'] as bool,
      parser: parser,
    );
  }

  String get usage => '''
Collect, optimize, and render a publication-ready golden report.

Usage: ff_golden_presenter build [options]

${_parser.usage}

Example:
  dart run ff_golden_presenter build --input test/screens --profile balanced --clean
''';
}

final class DoctorCliOptions {
  DoctorCliOptions._({
    required this.profile,
    required this.backend,
    required this.installTools,
    required this.showHelp,
    required ArgParser parser,
  }) : _parser = parser;

  final ImageOptimizationProfile profile;
  final ImageOptimizerBackend backend;
  final bool installTools;
  final bool showHelp;
  final ArgParser _parser;

  static DoctorCliOptions parse(List<String> arguments) {
    final parser = ArgParser(usageLineLength: 100);
    _addOptimizationSelection(parser);
    parser
      ..addFlag(
        'install-tools',
        negatable: false,
        help: 'Install a compatible missing optimizer, then verify it.',
      )
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Print this usage information.',
      );
    final results = parser.parse(arguments);
    _rejectRest(results);
    return DoctorCliOptions._(
      profile: ImageOptimizationProfile.parse(results['profile'] as String),
      backend: ImageOptimizerBackend.parse(results['backend'] as String),
      installTools: results['install-tools'] as bool,
      showHelp: results['help'] as bool,
      parser: parser,
    );
  }

  String get usage => '''
Check optimizer availability and show platform-specific installation guidance.

Usage: ff_golden_presenter doctor [options]

${_parser.usage}

Example:
  dart run ff_golden_presenter doctor --profile balanced
''';
}

ArgParser _collectionParser() {
  final parser = ArgParser(usageLineLength: 100);
  _addCollectionSelection(parser);
  parser
    ..addFlag(
      'clean',
      negatable: false,
      help: 'Remove the output directory before copying (guarded for safety).',
    )
    ..addFlag(
      'dry-run',
      negatable: false,
      help: 'Show how many files would be copied without changing anything.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    );
  return parser;
}

ArgParser _optimizationParser({
  required bool includeInput,
  required bool includeInPlace,
}) {
  final parser = ArgParser(usageLineLength: 100);
  if (includeInput) {
    parser.addOption(
      'input',
      abbr: 'i',
      defaultsTo: publicationOutputDefault,
      valueHelp: 'directory',
      help: 'Directory containing PNG files to optimize.',
    );
  }
  _addOptimizationSelection(parser);
  parser
    ..addOption(
      'jobs',
      abbr: 'j',
      defaultsTo: Platform.numberOfProcessors.toString(),
      valueHelp: 'count',
      help: 'Maximum number of optimizer processes to run concurrently.',
    )
    ..addFlag(
      'install-tools',
      negatable: false,
      help: 'Install a compatible optimizer when none is available.',
    );
  if (includeInPlace) {
    parser.addFlag(
      'in-place',
      negatable: false,
      help: 'Acknowledge that PNG files in --input may be replaced.',
    );
  }
  parser
    ..addFlag(
      'dry-run',
      negatable: false,
      help: 'Inspect files without running an optimizer.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    );
  return parser;
}

ArgParser _buildParser() {
  final parser = ArgParser(usageLineLength: 100);
  _addCollectionSelection(parser);
  _addOptimizationSelection(parser);
  parser
    ..addOption(
      'report-file',
      defaultsTo: 'index.html',
      valueHelp: 'filename',
      help: 'HTML filename created inside --output-directory.',
    )
    ..addOption(
      'title',
      defaultsTo: 'Golden test report',
      valueHelp: 'text',
      help: 'Title displayed at the top of the report.',
    )
    ..addOption(
      'golden-directory',
      abbr: 'g',
      defaultsTo: 'golden',
      valueHelp: 'name',
      help: 'Directory name that marks the start of a golden scenario.',
    )
    ..addOption(
      'device-pattern',
      defaultsTo: r'^(.+?)(?=\[|\(|\{|$)',
      valueHelp: 'regexp',
      help: 'Dart RegExp whose first capture group is the device name.',
    )
    ..addOption(
      'locale-pattern',
      defaultsTo: r'\(([^\)]+)\)',
      valueHelp: 'regexp',
      help: 'Dart RegExp whose first capture group is the locale.',
    )
    ..addOption(
      'theme-pattern',
      defaultsTo: r'\[([^\]]+)\]',
      valueHelp: 'regexp',
      help: 'Dart RegExp whose first capture group is the theme.',
    )
    ..addMultiOption(
      'manifest',
      defaultsTo: const ['build/ff_golden'],
      valueHelp: 'file-or-directory',
      help: 'ff_golden.run manifest file or shard directory.',
    )
    ..addFlag(
      'support-attribution',
      defaultsTo: true,
      negatable: true,
      help: 'Show ASO.dev support attribution in the report footer.',
    )
    ..addOption(
      'jobs',
      abbr: 'j',
      defaultsTo: Platform.numberOfProcessors.toString(),
      valueHelp: 'count',
      help: 'Maximum number of optimizer processes to run concurrently.',
    )
    ..addFlag(
      'clean',
      negatable: false,
      help: 'Remove the output directory before publishing.',
    )
    ..addFlag(
      'install-tools',
      negatable: false,
      help: 'Install a compatible optimizer when none is available.',
    )
    ..addFlag(
      'dry-run',
      negatable: false,
      help: 'Inspect and print the pipeline without changing anything.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    );
  return parser;
}

void _addCollectionSelection(ArgParser parser) {
  parser
    ..addOption(
      'input',
      abbr: 'i',
      defaultsTo: publicationInputDefault,
      valueHelp: 'directory',
      help: 'Screenshot directory to copy recursively.',
    )
    ..addOption(
      'output-directory',
      abbr: 'o',
      aliases: const ['output'],
      defaultsTo: publicationOutputDefault,
      valueHelp: 'directory',
      help: 'Isolated directory prepared for publication.',
    )
    ..addMultiOption(
      'extensions',
      defaultsTo: publicationExtensionsDefault,
      valueHelp: 'list',
      help: 'Image extensions to copy (comma-separated).',
    );
}

void _addOptimizationSelection(ArgParser parser) {
  parser
    ..addOption(
      'profile',
      abbr: 'p',
      allowed:
          ImageOptimizationProfile.values.map((profile) => profile.cliName),
      defaultsTo: ImageOptimizationProfile.balanced.cliName,
      valueHelp: 'name',
      help: 'Optimization profile: none, lossless, balanced, or small.',
    )
    ..addOption(
      'backend',
      allowed: ImageOptimizerBackend.values.map((backend) => backend.cliName),
      defaultsTo: ImageOptimizerBackend.auto.cliName,
      valueHelp: 'name',
      help: 'Optimizer implementation: auto, pngquant, oxipng, or imagemagick.',
    );
}

Set<String> _parseExtensions(ArgResults results) {
  final extensions = (results['extensions'] as List<String>)
      .map((extension) => extension.replaceFirst('.', '').toLowerCase())
      .where((extension) => extension.isNotEmpty)
      .toSet();
  if (extensions.isEmpty) {
    throw const FormatException('--extensions must not be empty.');
  }
  return extensions;
}

int _parseJobs(ArgResults results) {
  final jobs = int.tryParse(results['jobs'] as String);
  if (jobs == null || jobs < 1) {
    throw const FormatException('--jobs must be a positive integer.');
  }
  return jobs;
}

void _rejectRest(ArgResults results) {
  if (results.rest.isNotEmpty) {
    throw FormatException(
      'Unexpected positional arguments: ${results.rest.join(' ')}',
    );
  }
}
