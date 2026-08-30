import 'dart:io';

import 'package:path/path.dart' as path;

const ffGoldenVersion = '1.2.2';

/// Starts a child process and returns its exit code.
typedef GoldenProcessRunner = Future<int> Function(
  String executable,
  List<String> arguments,
);

/// Runs the `ff_golden` test command-line interface.
Future<int> runFfGolden(
  List<String> arguments, {
  StringSink? output,
  StringSink? errors,
  Directory? workingDirectory,
  GoldenProcessRunner? processRunner,
  String? resolvedExecutable,
  Map<String, String>? environment,
  bool? isWindows,
  bool Function(String path)? fileExists,
}) async {
  final out = output ?? stdout;
  final errorOutput = errors ?? stderr;

  if (arguments.isEmpty || _isHelp(arguments)) {
    out.write(_rootUsage);
    return 0;
  }
  if (arguments.length == 1 && arguments.first == '--version') {
    out.writeln('ff_golden $ffGoldenVersion');
    return 0;
  }

  final command = _GoldenTestCommand.parse(arguments.first);
  if (command == null) {
    errorOutput.writeln('Error: unknown command "${arguments.first}".');
    errorOutput.write(_rootUsage);
    return 64;
  }

  late final _GoldenTestOptions options;
  try {
    options = _GoldenTestOptions.parse(arguments.skip(1).toList());
  } on FormatException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    errorOutput.write(_commandUsage(command));
    return 64;
  }
  if (options.showHelp) {
    out.write(_commandUsage(command));
    return 0;
  }

  final currentDirectory = workingDirectory ?? Directory.current;
  final forwardedArguments = options.forwardedArguments;
  final hasExplicitTarget = forwardedArguments.any(
    (argument) => _looksLikeTestTarget(argument, currentDirectory),
  );
  final discoveredTargets = options.allTests || hasExplicitTarget
      ? const <String>[]
      : await _discoverGoldenTests(
          currentDirectory: currentDirectory,
          testRoot: options.testRoot,
        );
  final flutterArguments = <String>[
    'test',
    if (!options.runPub) '--no-pub',
    if (command.updatesGoldens) '--update-goldens',
    '--tags=${options.tags}',
    '--concurrency=${options.concurrency}',
    ...discoveredTargets,
    ...forwardedArguments,
  ];
  final flutterExecutable = options.flutterExecutable ??
      _resolveFlutterExecutable(
        currentDirectory: currentDirectory,
        resolvedExecutable: resolvedExecutable ?? Platform.resolvedExecutable,
        environment: environment ?? Platform.environment,
        isWindows: isWindows ?? Platform.isWindows,
        fileExists: fileExists ?? (candidate) => File(candidate).existsSync(),
      );

  if (options.dryRun || options.printCommand) {
    out.writeln(
      _formatCommand(<String>[flutterExecutable, ...flutterArguments]),
    );
  }
  if (options.dryRun) {
    return 0;
  }

  try {
    return await (processRunner ?? _runProcess)(
      flutterExecutable,
      flutterArguments,
    );
  } on ProcessException catch (error) {
    errorOutput.writeln('Error: ${error.message}');
    return 69;
  }
}

Future<int> _runProcess(String executable, List<String> arguments) async {
  final process = await Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  return process.exitCode;
}

enum _GoldenTestCommand {
  test,
  verify,
  update;

  bool get updatesGoldens => this == update;

  static _GoldenTestCommand? parse(String value) => switch (value) {
        'test' => test,
        'verify' => verify,
        'update' => update,
        _ => null,
      };
}

final class _GoldenTestOptions {
  const _GoldenTestOptions({
    required this.showHelp,
    required this.dryRun,
    required this.printCommand,
    required this.runPub,
    required this.allTests,
    required this.concurrency,
    required this.tags,
    required this.testRoot,
    required this.flutterExecutable,
    required this.forwardedArguments,
  });

  factory _GoldenTestOptions.parse(List<String> arguments) {
    var showHelp = false;
    var dryRun = false;
    var printCommand = false;
    var runPub = false;
    var allTests = false;
    var concurrency = 8;
    var tags = 'golden';
    var testRoot = 'test';
    String? flutterExecutable;
    final forwardedArguments = <String>[];

    for (var index = 0; index < arguments.length; index += 1) {
      final argument = arguments[index];
      if (argument == '--') {
        forwardedArguments.addAll(arguments.skip(index + 1));
        break;
      }
      switch (argument) {
        case '--help':
        case '-h':
          showHelp = true;
        case '--dry-run':
          dryRun = true;
        case '--print-command':
          printCommand = true;
        case '--pub':
          runPub = true;
        case '--no-pub':
          runPub = false;
        case '--all-tests':
          allTests = true;
        case '--concurrency':
        case '-j':
          final value = _nextValue(arguments, index, argument);
          index += 1;
          concurrency = _parseConcurrency(value);
        case '--tags':
          tags = _nextValue(arguments, index, argument);
          index += 1;
        case '--test-root':
          testRoot = _nextValue(arguments, index, argument);
          index += 1;
        case '--flutter':
          flutterExecutable = _nextValue(arguments, index, argument);
          index += 1;
        default:
          if (argument.startsWith('--concurrency=')) {
            concurrency = _parseConcurrency(argument.substring(14));
          } else if (argument.startsWith('--tags=')) {
            tags = _nonEmptyValue('--tags', argument.substring(7));
          } else if (argument.startsWith('--test-root=')) {
            testRoot = _nonEmptyValue('--test-root', argument.substring(12));
          } else if (argument.startsWith('--flutter=')) {
            flutterExecutable =
                _nonEmptyValue('--flutter', argument.substring(10));
          } else {
            forwardedArguments.add(argument);
          }
      }
    }

    if (tags.isEmpty) {
      throw const FormatException('--tags requires a non-empty value.');
    }
    return _GoldenTestOptions(
      showHelp: showHelp,
      dryRun: dryRun,
      printCommand: printCommand,
      runPub: runPub,
      allTests: allTests,
      concurrency: concurrency,
      tags: tags,
      testRoot: testRoot,
      flutterExecutable: flutterExecutable,
      forwardedArguments: List.unmodifiable(forwardedArguments),
    );
  }

  final bool showHelp;
  final bool dryRun;
  final bool printCommand;
  final bool runPub;
  final bool allTests;
  final int concurrency;
  final String tags;
  final String testRoot;
  final String? flutterExecutable;
  final List<String> forwardedArguments;
}

String _nextValue(List<String> arguments, int index, String option) {
  if (index + 1 >= arguments.length) {
    throw FormatException('$option requires a value.');
  }
  return _nonEmptyValue(option, arguments[index + 1]);
}

String _nonEmptyValue(String option, String value) {
  if (value.isEmpty) {
    throw FormatException('$option requires a non-empty value.');
  }
  return value;
}

int _parseConcurrency(String value) {
  final concurrency = int.tryParse(value);
  if (concurrency == null || concurrency < 1) {
    throw FormatException(
      '--concurrency must be a positive integer, got "$value".',
    );
  }
  return concurrency;
}

bool _looksLikeTestTarget(String argument, Directory currentDirectory) {
  if (argument.startsWith('-')) {
    return false;
  }
  if (argument.endsWith('_test.dart') || argument.endsWith('.dart')) {
    return true;
  }
  final candidate = path.isAbsolute(argument)
      ? argument
      : path.join(currentDirectory.path, argument);
  return FileSystemEntity.typeSync(candidate, followLinks: false) !=
      FileSystemEntityType.notFound;
}

Future<List<String>> _discoverGoldenTests({
  required Directory currentDirectory,
  required String testRoot,
}) async {
  final rootPath = path.isAbsolute(testRoot)
      ? path.normalize(testRoot)
      : path.normalize(path.join(currentDirectory.path, testRoot));
  final root = Directory(rootPath);
  if (!await root.exists()) {
    return const [];
  }

  final targets = <String>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('_golden_test.dart')) {
      continue;
    }
    targets.add(
      path.isAbsolute(testRoot)
          ? path.normalize(entity.path)
          : path.normalize(
              path.relative(entity.path, from: currentDirectory.path)),
    );
  }
  targets.sort();
  return targets;
}

String _resolveFlutterExecutable({
  required Directory currentDirectory,
  required String resolvedExecutable,
  required Map<String, String> environment,
  required bool isWindows,
  required bool Function(String path) fileExists,
}) {
  final executableName = isWindows ? 'flutter.bat' : 'flutter';
  final localFvm = path.join(
    currentDirectory.path,
    '.fvm',
    'flutter_sdk',
    'bin',
    executableName,
  );
  if (fileExists(localFvm)) {
    return localFvm;
  }

  final flutterRoot = environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    final fromEnvironment = path.join(flutterRoot, 'bin', executableName);
    if (fileExists(fromEnvironment)) {
      return fromEnvironment;
    }
  }

  var dartParent = resolvedExecutable;
  for (var level = 0; level < 4; level += 1) {
    dartParent = path.dirname(dartParent);
  }
  final fromFlutterSdk = path.join(dartParent, executableName);
  if (fileExists(fromFlutterSdk)) {
    return fromFlutterSdk;
  }
  return executableName;
}

bool _isHelp(List<String> arguments) =>
    arguments.length == 1 &&
    (arguments.first == '--help' || arguments.first == '-h');

String _formatCommand(List<String> parts) => parts.map(_shellQuote).join(' ');

String _shellQuote(String value) {
  if (value.isEmpty) {
    return "''";
  }
  if (RegExp(r'^[A-Za-z0-9_./:=+,-]+$').hasMatch(value)) {
    return value;
  }
  return "'${value.replaceAll("'", "'\\''")}'";
}

String _commandUsage(_GoldenTestCommand command) => '''
Usage: flutter pub run ff_golden ${command.name} [options] [flutter test arguments]

Runs golden tests with project-safe defaults. Unknown arguments are forwarded
to `flutter test` unchanged.

Runner options:
  --concurrency <jobs>  Parallel test processes (default: 8).
  --tags <expression>   Test tag expression (default: golden).
  --test-root <path>    Root scanned for *_golden_test.dart (default: test).
  --all-tests           Skip file discovery and let Flutter scan all tests.
  --pub                 Allow Flutter to run pub first (default: --no-pub).
  --flutter <path>      Override the Flutter executable.
  --dry-run             Print the resolved command without running it.
  --print-command       Print the resolved command before running it.
  -h, --help            Show this help.

Examples:
  flutter pub run ff_golden ${command.name}
  flutter pub run ff_golden ${command.name} test/screens/login_golden_test.dart
  flutter pub run ff_golden ${command.name} --plain-name 'loaded page'
''';

const _rootUsage = '''
FF Golden test runner

Usage: flutter pub run ff_golden <command> [options] [flutter test arguments]

Commands:
  test      Run golden tests without changing baselines.
  verify    Alias for test, intended for CI.
  update    Regenerate golden baselines for review.

Run `flutter pub run ff_golden <command> --help` for runner options.
Report generation and image optimization belong to `ff_golden_presenter`.
''';
