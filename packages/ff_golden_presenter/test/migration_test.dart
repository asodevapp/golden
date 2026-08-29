import 'dart:io';

import 'package:ff_golden_presenter/ff_golden_presenter.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory project;
  late File pubspec;
  late File goldenTest;
  late File script;
  late File template;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('ff_golden_migration_');
    pubspec = File(path.join(project.path, 'pubspec.yaml'));
    goldenTest = File(path.join(project.path, 'test', 'login_test.dart'));
    script = File(path.join(project.path, 'scripts', 'golden.sh'));
    template = File(path.join(project.path, 'templates', 'golden_test.tmpl'));
    await goldenTest.create(recursive: true);
    await script.create(recursive: true);
    await template.create(recursive: true);
    await pubspec.writeAsString('''
name: example
dev_dependencies:
  golden:
    git:
      url: https://github.com/Gorniv/golden.git
      path: packages/golden
  golden_presenter:
    git:
      url: https://github.com/Gorniv/golden_presenter.git
''');
    await goldenTest.writeAsString('''
import 'package:flutter/widgets.dart';
import 'package:golden/golden.dart';

const phone = Device(
  name: 'phone',
  size: Size(1170, 2532),
  devicePixelRatio: 3,
);

const devices = <Device>[Device.iPhone11];
final themes = <NamedTheme>[NamedTheme.defaultTheme];
final physicalHeight = Device.iPhone11.size.height;

final goldenTester = GoldenTester(
  widget: (_) => const SizedBox(),
  wrapper: (child, locale, theme) => child,
  postPumping: null,
);
''');
    await script.writeAsString('''
#!/bin/sh
flutter pub run golden_presenter:golden_presenter --path test
''');
    await template.writeAsString('''
import 'package:flutter_test/flutter_test.dart';
import 'package:golden/golden.dart';
''');
  });

  tearDown(() => project.delete(recursive: true));

  test('preview reports safe changes without writing files', () async {
    final originalPubspec = await pubspec.readAsString();
    final originalTest = await goldenTest.readAsString();

    final result = await FfGoldenProjectMigrator(
      projectDirectory: project,
    ).run();

    expect(result.applied, isFalse);
    expect(result.changedFiles, 0);
    expect(result.safeChanges, isNotEmpty);
    expect(
      result.safeChanges.map((finding) => finding.message),
      contains('replace the golden package import'),
    );
    expect(
      result.safeChanges.map((finding) => finding.message),
      contains('replace the legacy Device alias with GoldenDevice'),
    );
    expect(
      result.safeChanges.map((finding) => finding.message),
      contains('replace the legacy NamedTheme alias with GoldenTheme'),
    );
    expect(
      result.manualReviews.map((finding) => finding.message),
      contains(
        'convert physical Device(size:) to GoldenDevice('
        'logicalSize: physicalSize / devicePixelRatio) manually',
      ),
    );
    expect(
      result.manualReviews.map((finding) => finding.message),
      contains(
        'replace deprecated device.size with logicalSize or physicalSize',
      ),
    );
    expect(
      result.safeChanges.map((finding) => finding.message),
      contains('add git.path: packages/ff_golden_presenter'),
    );
    expect(await pubspec.readAsString(), originalPubspec);
    expect(await goldenTest.readAsString(), originalTest);
  });

  test('apply writes only deterministic renames', () async {
    final result = await FfGoldenProjectMigrator(
      projectDirectory: project,
    ).run(apply: true);

    expect(result.applied, isTrue);
    expect(result.changedFiles, 4);
    expect(await pubspec.readAsString(), contains('  ff_golden:'));
    expect(
      await pubspec.readAsString(),
      contains('path: packages/ff_golden'),
    );
    expect(await pubspec.readAsString(), contains('  ff_golden_presenter:'));
    expect(
      await pubspec.readAsString(),
      contains('https://github.com/Gorniv/golden.git'),
    );
    expect(
      await pubspec.readAsString(),
      contains('path: packages/ff_golden_presenter'),
    );
    expect(
      await goldenTest.readAsString(),
      contains("package:ff_golden/ff_golden.dart"),
    );
    final migratedTest = await goldenTest.readAsString();
    expect(
      migratedTest.indexOf('package:ff_golden/ff_golden.dart'),
      lessThan(migratedTest.indexOf('package:flutter/widgets.dart')),
    );
    expect(await goldenTest.readAsString(), contains('size: Size(1170, 2532)'));
    expect(
      await goldenTest.readAsString(),
      contains('const devices = <GoldenDevice>[GoldenDevice.iPhone11]'),
    );
    expect(
      await goldenTest.readAsString(),
      contains(
        'final themes = <GoldenTheme>[GoldenTheme.defaultTheme]',
      ),
    );
    expect(await goldenTest.readAsString(), contains('postPumping: null'));
    expect(
      await script.readAsString(),
      contains('dart run ff_golden_presenter --path test'),
    );
    final migratedTemplate = await template.readAsString();
    expect(
      migratedTemplate,
      contains("package:ff_golden/ff_golden.dart"),
    );
    expect(
      migratedTemplate.indexOf('package:ff_golden/ff_golden.dart'),
      lessThan(
          migratedTemplate.indexOf('package:flutter_test/flutter_test.dart')),
    );

    final remaining = await FfGoldenProjectMigrator(
      projectDirectory: project,
    ).run();
    expect(remaining.safeChanges, isEmpty);
    expect(remaining.manualReviews, isNotEmpty);
  });

  test('skips generated and build directories', () async {
    final generated = File(
      path.join(project.path, '.dart_tool', 'generated', 'old.dart'),
    );
    final build = File(path.join(project.path, 'build', 'old.dart'));
    await generated.create(recursive: true);
    await build.create(recursive: true);
    await generated.writeAsString("import 'package:golden/golden.dart';");
    await build.writeAsString("import 'package:golden/golden.dart';");

    await FfGoldenProjectMigrator(
      projectDirectory: project,
    ).run(apply: true);

    expect(await generated.readAsString(), contains('package:golden/'));
    expect(await build.readAsString(), contains('package:golden/'));
  });
}
