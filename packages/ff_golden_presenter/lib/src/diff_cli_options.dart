import 'package:args/args.dart';
import 'package:path/path.dart' as p;

final class DiffCliOptions {
  DiffCliOptions._(this.project, this.input, this.port, this.openBrowser,
      this.showHelp, this.flutterExecutable, this._parser);
  final String project;
  final String input;
  final int port;
  final bool openBrowser;
  final bool showHelp;
  final String? flutterExecutable;
  final ArgParser _parser;

  static DiffCliOptions parse(List<String> arguments) {
    final parser = ArgParser(usageLineLength: 100)
      ..addOption('project',
          defaultsTo: '.', help: 'Project directory inside a Git repository.')
      ..addOption('input',
          abbr: 'i',
          defaultsTo: '.',
          help: 'Image path scope, relative to --project.')
      ..addOption('port',
          defaultsTo: '0', help: 'Local port; 0 chooses an available port.')
      ..addOption('flutter', help: 'Flutter executable for the Tests panel.')
      ..addFlag('open',
          defaultsTo: true, help: 'Open the viewer in the default browser.')
      ..addFlag('help',
          abbr: 'h', negatable: false, help: 'Print this usage information.');
    final result = parser.parse(arguments);
    if (result.rest.isNotEmpty) {
      throw const FormatException('Unexpected positional arguments.');
    }
    final port = int.tryParse(result['port'] as String);
    if (port == null || port < 0 || port > 65535) {
      throw const FormatException('--port must be between 0 and 65535.');
    }
    return DiffCliOptions._(
      result['project'] as String,
      result['input'] as String,
      port,
      result['open'] as bool,
      result['help'] as bool,
      switch (result['flutter'] as String?) {
        final executable?
            when executable.contains('/') || executable.contains('\\') =>
          p.absolute(executable),
        final executable => executable,
      },
      parser,
    );
  }

  String get usage => '''
Review local image changes, stage/unstage selected files, and run golden tests.

Usage: ff_golden_presenter diff [options]

${_parser.usage}

The viewer binds only to 127.0.0.1. Stop it with Ctrl-C.
PNG, JPEG and WebP are supported. No images are rewritten or committed.
Tests runs scenario/file/folder queues with filters and live logs on macOS/Linux; no baseline updates.

Example:
  dart run ff_golden_presenter diff --input test
''';
}
