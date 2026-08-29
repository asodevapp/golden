import 'dart:convert';
import 'dart:io';

import 'package:ff_golden/ff_golden.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JSON reporter writes a presenter-ready bounded run manifest', () async {
    final directory = Directory.systemTemp.createTempSync('ff_golden_report_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final reporter = JsonGoldenReporter(
      directory.path,
      shardName: 'login-test',
      testFile: Uri.file('/project/test/screens/login_test.dart'),
      projectDirectory: Directory('/project'),
    );
    final plan = GoldenCoverage().plan();
    final variant = plan.variants.single;

    reporter.registerPlan(
      GoldenSuitePlan(
        description: 'screen',
        scenario: 'loaded',
        plan: plan,
        goldenPaths: const ['golden/loaded/iphone11(en-US).png'],
      ),
    );
    reporter.record(
      GoldenCaseResult(
        description: 'screen',
        scenario: 'loaded',
        variant: variant,
        status: GoldenResultStatus.passed,
        duration: const Duration(milliseconds: 12),
        captures: const [
          GoldenCapture(path: 'golden/loaded/iphone11(en-US).png'),
        ],
        overflowCount: 0,
      ),
    );
    await reporter.complete();

    final json = jsonDecode(await File(reporter.outputPath).readAsString())
        as Map<String, dynamic>;
    expect(json['schema'], 'ff_golden.run');
    expect(json['schemaVersion'], 2);
    expect(
      (json['source'] as Map<String, dynamic>)['goldenBaseDirectory'],
      'test/screens',
    );
    expect((json['summary'] as Map<String, dynamic>)['passed'], 1);
    expect((json['results'] as List<dynamic>), hasLength(1));
  });

  test('reporters use stable per-test-file shards in one directory', () async {
    final directory = Directory.systemTemp.createTempSync(
      'ff_golden_report_shards_',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final first = JsonGoldenReporter(
      directory.path,
      shardName: 'login-test',
      testFile: Uri.file('/project/test/auth/login_test.dart'),
      projectDirectory: Directory('/project'),
    );
    final second = JsonGoldenReporter(
      directory.path,
      shardName: 'profile-test',
      testFile: Uri.file('/project/test/settings/profile_test.dart'),
      projectDirectory: Directory('/project'),
    );

    await Future.wait([first.complete(), second.complete()]);

    expect(first.outputPath, isNot(second.outputPath));
    expect(await File(first.outputPath).exists(), isTrue);
    expect(await File(second.outputPath).exists(), isTrue);
  });
}
