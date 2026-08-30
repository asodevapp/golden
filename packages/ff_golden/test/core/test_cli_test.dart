import 'dart:io';

import 'package:ff_golden/src/test_cli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('ff_golden test CLI', () {
    late Directory project;

    setUp(() async {
      project = await Directory.systemTemp.createTemp('ff_golden_cli_');
      await Directory(path.join(project.path, 'test', 'screens'))
          .create(recursive: true);
    });

    tearDown(() => project.delete(recursive: true));

    test('update discovers sorted golden test files and uses safe defaults',
        () async {
      await _touch(project, 'test/screens/z_golden_test.dart');
      await _touch(project, 'test/a_golden_test.dart');
      await _touch(project, 'test/ordinary_test.dart');
      late String executable;
      late List<String> childArguments;

      final exitCode = await runFfGolden(
        const ['update', '--flutter', 'flutter-probe'],
        workingDirectory: project,
        processRunner: (value, arguments) async {
          executable = value;
          childArguments = arguments;
          return 0;
        },
      );

      expect(exitCode, 0);
      expect(executable, 'flutter-probe');
      expect(childArguments, const [
        'test',
        '--no-pub',
        '--update-goldens',
        '--tags=golden',
        '--concurrency=8',
        'test/a_golden_test.dart',
        'test/screens/z_golden_test.dart',
      ]);
    });

    test('test forwards a target and Flutter filters without discovery',
        () async {
      await _touch(project, 'test/ignored_golden_test.dart');
      late List<String> childArguments;

      final exitCode = await runFfGolden(
        const [
          'test',
          '--flutter=flutter-probe',
          'test/screens/login_test.dart',
          '--plain-name',
          'loaded page',
          '-v',
        ],
        workingDirectory: project,
        processRunner: (_, arguments) async {
          childArguments = arguments;
          return 7;
        },
      );

      expect(exitCode, 7);
      expect(childArguments, const [
        'test',
        '--no-pub',
        '--tags=golden',
        '--concurrency=8',
        'test/screens/login_test.dart',
        '--plain-name',
        'loaded page',
        '-v',
      ]);
    });

    test('verify supports runner overrides and forwards arguments after --',
        () async {
      late List<String> childArguments;

      final exitCode = await runFfGolden(
        const [
          'verify',
          '--flutter',
          'flutter-probe',
          '--pub',
          '--all-tests',
          '--tags',
          'ff_golden',
          '--concurrency=3',
          '--',
          '--exclude-tags',
          'slow',
        ],
        workingDirectory: project,
        processRunner: (_, arguments) async {
          childArguments = arguments;
          return 0;
        },
      );

      expect(exitCode, 0);
      expect(childArguments, const [
        'test',
        '--tags=ff_golden',
        '--concurrency=3',
        '--exclude-tags',
        'slow',
      ]);
    });

    test('dry-run prints the command and does not start Flutter', () async {
      await _touch(project, 'test/login_golden_test.dart');
      final output = StringBuffer();
      var started = false;

      final exitCode = await runFfGolden(
        const [
          'update',
          '--flutter',
          'flutter-probe',
          '--dry-run',
          '--plain-name',
          'loaded page',
        ],
        output: output,
        workingDirectory: project,
        processRunner: (_, __) async {
          started = true;
          return 0;
        },
      );

      expect(exitCode, 0);
      expect(started, isFalse);
      expect(
        output.toString(),
        contains("--plain-name 'loaded page'"),
      );
      expect(output.toString(), contains('test/login_golden_test.dart'));
    });

    test('finds the project FVM Flutter executable first', () async {
      late String executable;
      final expected = path.join(
        project.path,
        '.fvm',
        'flutter_sdk',
        'bin',
        'flutter',
      );

      final exitCode = await runFfGolden(
        const ['test', '--all-tests'],
        workingDirectory: project,
        resolvedExecutable: '/standalone/dart/bin/dart',
        environment: const {},
        isWindows: false,
        fileExists: (candidate) => candidate == expected,
        processRunner: (value, _) async {
          executable = value;
          return 0;
        },
      );

      expect(exitCode, 0);
      expect(executable, expected);
    });

    test('finds Flutter beside the SDK that launched Dart', () async {
      late String executable;
      const expected = '/opt/flutter/bin/flutter';

      final exitCode = await runFfGolden(
        const ['test', '--all-tests'],
        workingDirectory: project,
        resolvedExecutable: '/opt/flutter/bin/cache/dart-sdk/bin/dart',
        environment: const {},
        isWindows: false,
        fileExists: (candidate) => candidate == expected,
        processRunner: (value, _) async {
          executable = value;
          return 0;
        },
      );

      expect(exitCode, 0);
      expect(executable, expected);
    });

    test('rejects invalid concurrency before starting Flutter', () async {
      final errors = StringBuffer();
      var started = false;

      final exitCode = await runFfGolden(
        const ['test', '--concurrency=0'],
        errors: errors,
        workingDirectory: project,
        processRunner: (_, __) async {
          started = true;
          return 0;
        },
      );

      expect(exitCode, 64);
      expect(started, isFalse);
      expect(errors.toString(), contains('positive integer'));
    });

    test('shows root and command help without starting Flutter', () async {
      final rootOutput = StringBuffer();
      final commandOutput = StringBuffer();

      expect(
        await runFfGolden(const [], output: rootOutput),
        0,
      );
      expect(
        await runFfGolden(const ['update', '--help'], output: commandOutput),
        0,
      );
      expect(rootOutput.toString(), contains('Commands:'));
      expect(commandOutput.toString(), contains('--test-root'));
    });
  });
}

Future<void> _touch(Directory root, String relativePath) async {
  final file = File(path.join(root.path, relativePath));
  await file.parent.create(recursive: true);
  await file.writeAsString('// fixture\n');
}
