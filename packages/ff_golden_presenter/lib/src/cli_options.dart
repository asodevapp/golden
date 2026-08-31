import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import 'report_customization_cli.dart';

const ffGoldenPresenterVersion = '1.1.2';

/// Parsed command-line configuration for FF Golden Presenter.
final class GoldenPresenterOptions {
  GoldenPresenterOptions._({
    required this.input,
    required this.output,
    required this.title,
    required this.goldenDirectory,
    required this.extensions,
    required this.devicePattern,
    required this.localePattern,
    required this.themePattern,
    required this.manifestPaths,
    required this.supportAttribution,
    required this.customization,
    required this.showHelp,
    required this.showVersion,
    required ArgParser parser,
  }) : _parser = parser;

  final String input;
  final String output;
  final String title;
  final String goldenDirectory;
  final Set<String> extensions;
  final String devicePattern;
  final String localePattern;
  final String themePattern;
  final List<String> manifestPaths;
  final bool supportAttribution;
  final ReportCustomizationCliOptions customization;
  final bool showHelp;
  final bool showVersion;
  final ArgParser _parser;

  static GoldenPresenterOptions parse(List<String> arguments) {
    final parser = _buildParser();
    final normalizedArguments = [
      for (final argument in arguments)
        if (argument == '-p')
          '-i'
        else if (argument.startsWith('-p') && !argument.startsWith('--'))
          '-i${argument.substring(2)}'
        else
          argument,
    ];
    final results = parser.parse(normalizedArguments);
    if (results.rest.isNotEmpty) {
      throw FormatException(
        'Unexpected positional arguments: ${results.rest.join(' ')}',
      );
    }

    var input = results['input'] as String;
    if (results.wasParsed('test-path')) {
      input = path.join(input, results['test-path'] as String);
    }
    final extensions = (results['extensions'] as List<String>)
        .map((extension) => extension.replaceFirst('.', '').toLowerCase())
        .where((extension) => extension.isNotEmpty)
        .toSet();
    if (extensions.isEmpty) {
      throw const FormatException('--extensions must not be empty.');
    }

    return GoldenPresenterOptions._(
      input: input,
      output: results['output'] as String,
      title: results['title'] as String,
      goldenDirectory: results['golden-directory'] as String,
      extensions: extensions,
      devicePattern: results['device-pattern'] as String,
      localePattern: results['locale-pattern'] as String,
      themePattern: results['theme-pattern'] as String,
      manifestPaths: List.unmodifiable(results['manifest'] as List<String>),
      supportAttribution: results['support-attribution'] as bool,
      customization: parseReportCustomization(results),
      showHelp: results['help'] as bool,
      showVersion: results['version'] as bool,
      parser: parser,
    );
  }

  String get usage => '''
Generate a searchable HTML catalog from golden test images.

Usage: ff_golden_presenter report [options]
       ff_golden_presenter [options]  # legacy shorthand

${_parser.usage}

Example:
  dart run ff_golden_presenter report --input test --output golden-report.html
''';

  static ArgParser _buildParser() {
    final parser = ArgParser(usageLineLength: 100)
      ..addOption(
        'input',
        abbr: 'i',
        aliases: const ['path'],
        defaultsTo: 'test',
        valueHelp: 'directory',
        help:
            'Directory to scan recursively. --path remains available as a legacy alias.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        defaultsTo: 'golden-report.html',
        valueHelp: 'file',
        help: 'HTML report file to create.',
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
        aliases: const ['golden-folder', 'golden-dir'],
        defaultsTo: 'golden',
        valueHelp: 'name',
        help: 'Directory name that marks the start of a golden scenario.',
      )
      ..addMultiOption(
        'extensions',
        defaultsTo: const ['png', 'jpg', 'jpeg', 'webp', 'svg'],
        valueHelp: 'list',
        help: 'Image extensions to include (comma-separated).',
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
        'test-path',
        hide: true,
        help: 'Legacy path appended to --input.',
      )
      ..addFlag(
        'version',
        negatable: false,
        help: 'Print the package version.',
      )
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Print this usage information.',
      );
    addReportCustomizationOptions(parser);
    return parser;
  }
}
