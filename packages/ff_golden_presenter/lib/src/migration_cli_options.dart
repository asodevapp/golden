import 'package:args/args.dart';

final class MigrationCliOptions {
  MigrationCliOptions._({
    required this.project,
    required this.apply,
    required this.check,
    required this.showHelp,
    required ArgParser parser,
  }) : _parser = parser;

  final String project;
  final bool apply;
  final bool check;
  final bool showHelp;
  final ArgParser _parser;

  static MigrationCliOptions parse(List<String> arguments) {
    final parser = ArgParser(usageLineLength: 100)
      ..addOption(
        'project',
        abbr: 'p',
        defaultsTo: '.',
        valueHelp: 'directory',
        help: 'Application root to audit.',
      )
      ..addFlag(
        'apply',
        negatable: false,
        help: 'Apply only unambiguous package/import/command renames.',
      )
      ..addFlag(
        'check',
        negatable: false,
        help: 'Exit with code 1 when migration findings remain.',
      )
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Print this usage information.',
      );
    final results = parser.parse(arguments);
    if (results.rest.isNotEmpty) {
      throw FormatException(
        'Unexpected positional arguments: ${results.rest.join(' ')}',
      );
    }
    final apply = results['apply'] as bool;
    final check = results['check'] as bool;
    if (apply && check) {
      throw const FormatException('--apply and --check cannot be combined.');
    }
    return MigrationCliOptions._(
      project: results['project'] as String,
      apply: apply,
      check: check,
      showHelp: results['help'] as bool,
      parser: parser,
    );
  }

  String get usage => '''
Audit or safely migrate a project from golden/golden_presenter.

Usage: ff_golden_presenter migrate [options]

${_parser.usage}

Preview:
  dart run ff_golden_presenter migrate --project .

Apply safe renames, then verify:
  dart run ff_golden_presenter migrate --project . --apply
  dart run ff_golden_presenter migrate --project . --check
''';
}
