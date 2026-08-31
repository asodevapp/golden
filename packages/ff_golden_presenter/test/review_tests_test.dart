import 'dart:convert';
import 'dart:io';

import 'package:ff_golden_presenter/src/git_image_review.dart';
import 'package:ff_golden_presenter/src/review_test_catalog.dart';
import 'package:ff_golden_presenter/src/review_test_runner.dart';
import 'package:ff_golden_presenter/src/review_test_source.dart';
import 'package:ff_golden_presenter/src/review_test_variants.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  test(
      'discovers literal legacy, coverage and typed scenarios without evaluating code',
      () {
    final cases = readReviewScenarios(r'''
void main() {
  // testDeviceGoldens('fake', (_) {});
  group('Screen', () {
    testDeviceGoldens('light and dark', (tester, device, locale, theme) {
      return builder(tester, scenarioName: 'different');
    });
    testFfGoldens('Loaded [1]', scenario: 'screen/loaded', build: (_) => Widget());
    testFfGoldenScenarios('States', scenarios: [
      const GoldenScenario(name: 'empty', state: 0),
      GoldenScenario(name: 'filled', state: 1),
    ], build: (_, state) => Widget());
    testFfGoldens(computeDescription(), scenario: 'dynamic', build: (_) => Widget());
  });
  group(dynamicName, () { testDeviceGoldens('unknown group', (_) {}); });
}
''');
    expect(cases.map((item) => item.fullName), [
      'Screen light and dark',
      'Screen Loaded [1]',
      'Screen States — empty',
      'Screen States — filled',
    ]);
    expect(cases.first.goldenFolder, 'golden/different');
    expect(cases[1].goldenFolder, 'golden/screen-loaded');
    expect(readReviewScenarios('void main( {'), isEmpty);
  });
  test('custom paths require manifest mapping for single and typed scenarios',
      () {
    final cases = readReviewScenarios(r'''
void main() {
  testFfGoldens('Custom', scenario: 'loaded',
    configuration: GoldenRunConfiguration(pathStrategy: customPath),
    build: (_) => Widget());
  testFfGoldenScenarios('Custom states',
    scenarios: [GoldenScenario(name: 'empty', state: 0)],
    configuration: GoldenRunConfiguration(pathStrategy: customPath),
    build: (_, state) => Widget());
  testFfGoldenScenarios('Unknown configuration',
    scenarios: [GoldenScenario(name: 'empty', state: 0)],
    configuration: sharedConfiguration, build: (_, state) => Widget());
}
''');
    expect(cases.map((item) => item.fullName), [
      'Custom',
      'Custom states — empty',
      'Unknown configuration — empty',
    ]);
    expect(cases.map((item) => item.goldenFolder), everyElement(isNull));
  });
  test('golden file detection preserves dynamic registrations and literal tags',
      () {
    for (final source in [
      'void main() { testDeviceGoldens(description, builder); }',
      'void main() { testFfGoldens(description, scenario: name, build: builder); }',
      'void main() { testFfGoldenScenarios(description, scenarios: cases, build: builder); }',
      "void main() { testWidgets('shot', callback, tags: ['golden']); }",
      "void main() { test('shot', callback, tags: 'golden'); }",
      "void main() { group('shots', callback, tags: {'golden', 'slow'}); }",
      "@Tags(['golden']) library; void main() { registerTests(); }",
      "@test.Tags(['golden']) library; void main() { registerTests(); }",
    ]) {
      expect(readReviewTestSource(source).isGolden, isTrue, reason: source);
    }
    for (final source in [
      "void main() { test('golden parser', callback); }",
      "void main() { testWidgets('ordinary', callback, tags: ['unit']); }",
      "void main() { otherCall(tags: ['golden']); }",
      "// testFfGoldens('comment', build: builder);\nvoid main() {}",
      '''void main() { print("testDeviceGoldens('string', builder)"); }''',
      'void main( {',
    ]) {
      expect(readReviewTestSource(source).isGolden, isFalse, reason: source);
    }
  });
  group('variant filters', () {
    bool matches(Map<String, String> filters, String name) =>
        RegExp(ReviewTestFilters.parse(filters).pattern!).hasMatch(name);
    test('combines exact device, theme, locale and literal name for both APIs',
        () {
      final filters = {
        'device': 'iPadPro12.9',
        'theme': 'dark',
        'locale': 'en-US',
        'name': 'case [1]'
      };
      expect(
          matches(filters, 'group case [1] (iPadPro12.9:en_US:dark)'), isTrue);
      expect(
          matches(filters,
              'group case [1] (iPadPro12.9, dark, en-US, 1.0x text, ltr, iOS)'),
          isTrue);
      for (final other in [
        'group case [1] (iPadPro12x9:en_US:dark)',
        'group case [1] (iPadPro12.9:en_US:light)',
        'group case [1] (iPadPro12.9:ar:dark)',
        'group case 1 (iPadPro12.9:en_US:dark)',
        'group case [1] (iPadPro12.9, dark, en-US, 1.0x text, ltr, iOS) extra',
      ]) {
        expect(matches(filters, other), isFalse, reason: other);
      }
    });
    test('advanced axes select only matching coverage variants', () {
      final filters = {
        'textScale': '1.50',
        'direction': 'rtl',
        'platform': 'macOS',
        'highContrast': 'true'
      };
      const name =
          'capture (tablet, dark, ar, 1.5x text, rtl, macOS, high-contrast)';
      expect(matches(filters, name), isTrue);
      expect(matches(filters, name.replaceFirst('1.5x', '1.0x')), isFalse);
      expect(matches(filters, name.replaceFirst('rtl', 'ltr')), isFalse);
      expect(matches(filters, name.replaceFirst('macOS', 'iOS')), isFalse);
      expect(
          matches(filters, name.replaceFirst(', high-contrast', '')), isFalse);
      expect(matches(filters, 'capture (tablet:ar:dark)'), isFalse);
      expect(matches({'highContrast': 'false'}, name), isFalse);
      expect(
          matches({'highContrast': 'false'},
              name.replaceFirst(', high-contrast', '')),
          isTrue);
      expect(
          matches({'textScale': '1'},
              'case (phone, light, zh-Hans-CN, 1.0x text, ltr, iOS)'),
          isTrue);
    });
    test('empty and name-only filters never interpolate arbitrary regex', () {
      expect(ReviewTestFilters.parse({}).pattern, isNull);
      expect(matches({'name': '(a|b).*'}, 'group (a|b).* test'), isTrue);
      expect(matches({'name': '(a|b).*'}, 'group aaa test'), isFalse);
      for (final invalid in [
        {'name': 'a\nb'},
        {'unknown': 'x'},
        {'device': 42},
        {'textScale': 'NaN'},
        {'textScale': '0'},
        {'platform': 'shell'},
      ]) {
        expect(() => ReviewTestFilters.parse(invalid), throwsFormatException);
      }
    });
  });

  group('test catalog and runner', () {
    late GitFixture fixture;
    late ReviewTestCatalog catalog;
    late ReviewTestRunner runner;
    Future<void> write(String path, String text) =>
        fixture.write(path, utf8.encode(text));
    Future<void> flutterScript(String body) async {
      await write('fake-flutter', '#!/bin/sh\n$body\n');
      final chmod =
          await Process.run('chmod', ['+x', fixture.file('fake-flutter').path]);
      expect(chmod.exitCode, 0);
    }

    Map<String, Object> body([Map<String, String> filters = const {}]) => {
          'testId': catalog.targets.values
              .firstWhere((t) => t.path.endsWith('screen_test.dart'))
              .id,
          'filters': filters
        };
    setUp(() async {
      fixture = await GitFixture.create();
      await write('packages/app/pubspec.yaml', 'name: app\n');
      await write('packages/app/test/screen/screen_test.dart',
          'void main() { testDeviceGoldens(description, builder); }');
      await write('packages/other/pubspec.yaml', 'name: other\n');
      await write('packages/other/test/other_test.dart',
          'void main() { testFfGoldens(description, scenario: name, build: builder); }');
      catalog = ReviewTestCatalog(
          await GitImageRepository.open(project: fixture.directory));
      await catalog.refresh();
      runner = ReviewTestRunner(catalog,
          flutterExecutable: fixture.file('fake-flutter').path);
    });
    tearDown(() async {
      await runner.close();
      await fixture.directory.delete(recursive: true);
    });

    test(
        'finds nearest package, scopes --project, rejects links and arbitrary IDs',
        () async {
      expect(catalog.targets.length, 2);
      final plan = await runner.plan(body());
      expect(
          plan.commands.single.directory,
          await Directory(fixture.file('packages/app').path)
              .resolveSymbolicLinks());
      expect(
          plan.commands.single.arguments,
          containsAll([
            '--no-pub',
            '--tags=golden',
            '--concurrency=1',
            './test/screen/screen_test.dart'
          ]));
      expect(
          plan.commands.single.arguments, isNot(contains('--update-goldens')));
      await expectLater(
          runner.plan({'testId': '../../outside.dart', 'filters': {}}),
          throwsA(isA<GitReviewException>()));
      await expectLater(
          runner.plan({
            ...body(),
            'arguments': ['--update-goldens']
          }),
          throwsFormatException);
      final file = fixture.file('packages/app/test/screen/screen_test.dart');
      await file.delete();
      await Link(file.path)
          .create(fixture.file('packages/other/test/other_test.dart').path);
      await expectLater(
          runner.plan(body()), throwsA(isA<GitReviewException>()));
      final scoped = ReviewTestCatalog(await GitImageRepository.open(
          project: Directory(fixture.file('packages/other/test').path)));
      await scoped.refresh();
      expect(scoped.targets.values.single.packagePath, 'packages/other');
    });

    test(
        'file lists, folder counts and project queues contain only golden files',
        () async {
      await write('packages/app/test/screen/unit_test.dart',
          "void main() { test('unit', callback); }");
      await write('packages/app/test/unit/golden_test.dart',
          "void main() { test('golden parser', callback); }");
      await write('packages/app/test/screen/tagged_test.dart',
          "void main() { testWidgets('snapshot', callback, tags: ['golden']); }");
      await catalog.refresh();
      final data = catalog.toJson();
      expect((data['tests'] as List).map((test) => test['path']), [
        'packages/app/test/screen/screen_test.dart',
        'packages/app/test/screen/tagged_test.dart',
        'packages/other/test/other_test.dart',
      ]);
      expect(
          catalog.scopes.values.any((scope) =>
              scope.kind == 'folder' && scope.path == 'packages/app/test/unit'),
          isFalse);
      final folder = catalog.scopes.values.singleWhere((scope) =>
          scope.kind == 'folder' && scope.path == 'packages/app/test/screen');
      expect(folder.fileIds, hasLength(2));
      final plan = await runner.plan({
        'scopeIds': ['project'],
        'filters': {}
      });
      expect(plan.commands, hasLength(3));
      expect(
          plan.commands.every(
              (job) => !job.selection.target.path.endsWith('/unit_test.dart')),
          isTrue);
      // Refresh must notice a source changing from golden to an ordinary test.
      await write('packages/app/test/screen/tagged_test.dart',
          "void main() { testWidgets('now ordinary', callback); }");
      await catalog.refresh();
      expect(catalog.targets, hasLength(2));
    });

    test(
        'explicit manifest sources retain wrapped golden tests without captures',
        () async {
      await write('packages/app/test/wrapped_test.dart',
          'void main() { registerProjectSnapshots(); }');
      await catalog.refresh();
      expect(catalog.targets, hasLength(2));
      await write(
          'packages/app/build/ff_golden/run.json',
          jsonEncode({
            'schema': 'ff_golden.run',
            'schemaVersion': 2,
            'source': {'testFile': 'test/wrapped_test.dart'},
            'results': [],
          }));
      await catalog.refresh();
      expect(catalog.targets.values.map((target) => target.path),
          contains('packages/app/test/wrapped_test.dart'));
      await fixture.file('packages/app/build/ff_golden/run.json').delete();
      await catalog.refresh();
      expect(catalog.targets, hasLength(2));
    });

    test(
        'maps manifest capture to explicit test and axes, does not guess ambiguous files',
        () async {
      final image = GitImageChange(
          path: 'packages/app/test/screen/golden/loaded/shot.png',
          staged: false,
          status: '?',
          beforeBlob: null,
          afterBlob: null);
      var data = catalog.toJson(image: image);
      expect(data['suggestedTestId'], body()['testId']);
      expect(data['filters'], isEmpty);
      await write('packages/app/test/screen/another_test.dart',
          'void main() { testDeviceGoldens(description, builder); }');
      await catalog.refresh();
      expect(catalog.toJson(image: image)['suggestedTestId'], isNull);
      await write(
          'packages/app/build/ff_golden/run.json',
          jsonEncode({
            'schema': 'ff_golden.run',
            'schemaVersion': 2,
            'source': {
              'testFile': 'test/screen/screen_test.dart',
              'goldenBaseDirectory': 'test/screen'
            },
            'results': [
              {
                'status': 'passed',
                'captures': [
                  {'path': 'golden/loaded/shot.png'}
                ],
                'variant': {
                  'device': {'name': 'tablet'},
                  'theme': 'dark',
                  'locale': 'ar',
                  'textScale': 1.5,
                  'direction': 'rtl',
                  'platform': 'macOS',
                  'highContrast': true
                },
              }
            ],
          }));
      await catalog.refresh();
      data = catalog.toJson(image: image);
      expect(data['suggestedTestId'], body()['testId']);
      expect(data['filters'], containsPair('device', 'tablet'));
      expect(data['filters'], containsPair('highContrast', 'true'));
    });

    test(
        'streams before exit, preserves literal arguments, reports exit and cursors',
        () async {
      await flutterScript(
          'printf "%s\\n" "\$PWD" "\$@"\nprintf "diagnostic\\n" >&2\nsleep 0.5\nexit 7');
      await runner.start(body({'name': r'$(touch injected);.*'}));
      await waitFor(() => (runner.snapshot()['logs'] as List)
          .any((e) => (e['text'] as String).contains('diagnostic')));
      expect(runner.active, isTrue);
      final cursor = runner.snapshot()['cursor'] as int;
      await expectLater(
          runner.start(body()), throwsA(isA<GitReviewException>()));
      expect(() => runner.stop('old-run'), throwsA(isA<GitReviewException>()));
      await waitFor(() => !runner.active);
      expect(runner.snapshot()['status'], 'failed');
      expect(runner.snapshot()['exitCode'], 7);
      expect(runner.snapshot(after: cursor)['logs'], isNotEmpty);
      expect(runner.snapshot(after: runner.snapshot()['cursor'] as int)['logs'],
          isEmpty);
      expect(fixture.file('packages/app/injected').existsSync(), isFalse);
    }, skip: Platform.isWindows);

    test('bounds logs, reports success and startup failures', () async {
      await flutterScript('yes output | head -c 700000\nexit 0');
      await runner.start(body());
      await waitFor(() => !runner.active);
      final data = runner.snapshot();
      expect(data['status'], 'passed');
      expect(data['truncated'], isTrue);
      expect(
          (data['logs'] as List)
              .fold<int>(0, (n, e) => n + (e['text'] as String).length),
          lessThanOrEqualTo(512 * 1024));
      expect(runner.logReport(runner.runId!, errorsOnly: false),
          contains('WARNING: Earlier output was truncated'));
      expect(() => runner.logReport(runner.runId!, errorsOnly: true),
          throwsA(isA<GitReviewException>()));
      await fixture.file('fake-flutter').delete();
      await runner.start(body());
      await waitFor(() => !runner.active);
      expect(runner.snapshot()['status'], 'failed');
      expect(runner.snapshot()['exitCode'], 1);
      expect(runner.logReport(runner.runId!, errorsOnly: true),
          contains('Could not start Flutter'));
    }, skip: Platform.isWindows);

    test(
        'log reports keep run filters, isolate failed files and reject old IDs',
        () async {
      await flutterScript(r'''
case "$PWD" in
  */app) printf '00:00 +0: failed screen\nExpected: 1\nActual: 0\n00:01 +0 -1: failed screen [E]\n'; exit 1;;
  *) printf 'passed-neighbor-output\n'; exit 0;;
esac''');
      final filters = {'theme': 'dark'};
      await runner.start({
        'scopeIds': ['project'],
        'filters': filters
      });
      final id = runner.runId!;
      final activeReport = runner.logReport(id, errorsOnly: false);
      expect(activeReport, contains('NOTE: The run is still active'));
      filters['theme'] = 'light';
      await waitFor(() => !runner.active);
      final full = runner.logReport(id, errorsOnly: false);
      final errors = runner.logReport(id, errorsOnly: true);
      expect(full, contains('passed-neighbor-output'));
      expect(full, contains('Filters: {"theme":"dark"}'));
      expect(full, contains('Files completed: 2/2'));
      expect(errors, contains('Expected: 1\nActual: 0'));
      expect(errors, contains('Directory:'));
      expect(errors, contains('--tags=golden'));
      expect(errors, isNot(contains('other_test.dart')));
      expect(errors, isNot(contains('passed-neighbor-output')));
      await runner.start(body());
      expect(() => runner.logReport(id, errorsOnly: false),
          throwsA(isA<GitReviewException>()));
      await waitFor(() => !runner.active);
    }, skip: Platform.isWindows);

    test(
        'folder and project scopes include unchanged files; overlapping scopes run each file once',
        () async {
      await write('packages/app/test/screen/second_test.dart',
          "void main() { testFfGoldens('Second', scenario: 'second', build: (_) => null); }");
      await catalog.refresh();
      final folder = catalog.scopes.values.singleWhere((scope) =>
          scope.kind == 'folder' && scope.path == 'packages/app/test/screen');
      final scenario = catalog.scenarios.values.single;
      var plan = await runner.plan({
        'scopeIds': [folder.id, scenario.id, body()['testId']],
        'filters': {}
      });
      expect(plan.commands.length, 2);
      expect(plan.commands.every((job) => job.selection.scenarios.isEmpty),
          isTrue);
      plan = await runner.plan({
        'scopeIds': ['project', folder.id],
        'filters': {}
      });
      expect(plan.commands.length, 3);
      expect(plan.commands.map((job) => job.directory).toSet().length, 2);
      await expectLater(
          runner.plan({
            'scopeIds': ['folder:../../outside'],
            'filters': {}
          }),
          throwsFormatException);
    });

    test(
        'discovery loads real named variants and filters each file independently',
        () async {
      final name =
          'group capture [1] (tablet, dark, ar, 1.5x text, rtl, macOS, high-contrast)';
      final metadata = {
        'schema': 1,
        'api': 'coverage',
        'description': 'capture [1]',
        'axes': {
          'device': 'tablet',
          'theme': 'dark',
          'locale': 'ar',
          'textScale': '1.5',
          'direction': 'rtl',
          'platform': 'macOS',
          'highContrast': 'true'
        },
      };
      final output = [
        jsonEncode({
          'type': 'testStart',
          'test': {'id': 3, 'name': name}
        }),
        jsonEncode({
          'type': 'print',
          'testID': 3,
          'message': '${ReviewVariantReader.prefix}${jsonEncode(metadata)}'
        }),
      ].join('\n');
      await flutterScript("cat <<'VARIANTS'\n$output\nVARIANTS\n");
      final request = body({'device': 'not-a-real-device'});
      final preview = await runner.plan(request, discovery: true);
      expect(preview.commands.single.arguments,
          contains('--dart-define=FF_GOLDEN_DISCOVERY=true'));
      expect(preview.commands.single.arguments,
          contains('--tags=ff_golden_discovery'));
      expect(preview.commands.single.arguments, isNot(contains('--name')));
      await runner.start(request, discovery: true);
      await waitFor(() => !runner.active);
      expect(runner.snapshot()['status'], 'passed');
      final selection = ReviewTestSelection(
          await catalog.validate(body()['testId'] as String), []);
      final filters = ReviewTestFilters.parse({
        'name': 'capture [1]',
        'device': 'tablet',
        'theme': 'dark',
        'locale': 'ar',
        'textScale': '1.50',
        'direction': 'rtl',
        'platform': 'macOS',
        'highContrast': 'true'
      });
      final options = catalog.variantOptions([selection], filters);
      expect(options['complete'], isTrue);
      expect(options['matching'], 1);
      expect((options['options'] as Map)['direction'], ['rtl']);
      expect(options['names'], ['capture [1]']);
      expect(catalog.variantsFor(selection)!.single.fullName, name);
      final verify = await runner.plan(body(filters.values));
      expect(verify.commands.single.arguments,
          isNot(contains('--dart-define=FF_GOLDEN_DISCOVERY=true')));
      await expectLater(
          runner.plan(body({'direction': 'ltr'})), throwsFormatException);
      // An unknown file is kept; a loaded nonmatching file is excluded.
      final project = await runner.plan({
        'scopeIds': ['project'],
        'filters': {'device': 'phone'}
      });
      expect(project.commands.single.selection.target.path,
          'packages/other/test/other_test.dart');
      await write(selection.target.path,
          'void main() { testDeviceGoldens(changedDescription, changedBuilder); }');
      await catalog.refresh();
      expect(catalog.variantsFor(selection), isNull);
    }, skip: Platform.isWindows);

    test('partial ff_golden discovery never excludes custom tagged tests',
        () async {
      await write('packages/app/test/screen/screen_test.dart', """
void main() {
  testFfGoldens('Known', scenario: 'known', build: builder);
  testWidgets('Custom snapshot', customBuilder, tags: ['golden']);
}
""");
      await catalog.refresh();
      final target = await catalog.validate(body()['testId'] as String);
      final selection = ReviewTestSelection(target, []);
      catalog.rememberVariants(target, const [
        ReviewTestVariant(
            'Known (phone, light, en-US, 1.0x text, ltr, iOS)', 'Known', {
          'device': 'phone',
          'theme': 'light',
          'locale': 'en-US',
          'textScale': '1.0',
          'direction': 'ltr',
          'platform': 'iOS',
          'highContrast': 'false'
        })
      ]);
      final filters = ReviewTestFilters.parse({'name': 'Custom snapshot'});
      expect(catalog.variantOptions([selection], filters)['complete'], isFalse);
      final plan = await runner.plan(body(filters.values));
      expect(plan.commands.single.selection.target.id, target.id);
    });

    test(
        'discovery fails clearly without support and does not cache partial results',
        () async {
      await flutterScript('echo "No tests ran."\nexit 0');
      await runner.start(body(), discovery: true);
      await waitFor(() => !runner.active);
      expect(runner.snapshot()['status'], 'failed');
      expect(
          (runner.snapshot()['logs'] as List)
              .map((entry) => entry['text'])
              .join(),
          contains('discovery support'));
    }, skip: Platform.isWindows);

    test(
        'scenario scope maps a different folder name and combines exact case with variant filters',
        () async {
      await write('packages/app/test/screen/screen_test.dart', """
void main() {
  group('Screen', () {
    testDeviceGoldens('light and dark', (_) => builder(scenarioName: 'different'));
    testDeviceGoldens('default', (_) => builder(scenarioName: 'default'));
  });
}
""");
      await catalog.refresh();
      final image = GitImageChange(
          path: 'packages/app/test/screen/golden/different/phone.png',
          staged: false,
          status: 'M',
          beforeBlob: null,
          afterBlob: null);
      final context = catalog.context([image],
          folder: 'packages/app/test/screen/golden/different');
      final plan = await runner.plan({
        'scopeIds': context['scopeIds'],
        'filters': {'device': 'iphone11', 'theme': 'dark'}
      });
      expect(plan.commands.length, 1);
      final job = plan.commands.single;
      final regex = RegExp(job.arguments[job.arguments.indexOf('--name') + 1]);
      expect(regex.hasMatch('Screen light and dark (iphone11:en_US:dark)'),
          isTrue);
      expect(regex.hasMatch('Screen light and dark (iphone11:en_US:light)'),
          isFalse);
      expect(
          regex.hasMatch('Other Screen light and dark (iphone11:en_US:dark)'),
          isFalse);
      expect(regex.hasMatch('Screen default (iphone11:en_US:dark)'), isFalse);
      final fileContext = catalog.context([image], wholeFiles: true);
      expect(fileContext['scopeIds'], [body()['testId']]);
      final missing = GitImageChange(
          path: 'unknown.png',
          staged: false,
          status: '?',
          beforeBlob: null,
          afterBlob: null);
      expect(catalog.context([image, missing])['scopeIds'], isEmpty);
      final unmapped = GitImageChange(
          path: 'packages/app/test/screen/golden/unknown/phone.png',
          staged: false,
          status: '?',
          beforeBlob: null,
          afterBlob: null);
      expect(
          catalog.context([image, unmapped],
              folder: 'packages/app/test/screen/golden')['scopeIds'],
          isNotEmpty);
      expect(
          catalog.context([image, unmapped],
              folder: 'packages/app/test/screen/golden/different')['scopeIds'],
          isEmpty);
    });

    test('queue keeps per-file name filters and continues after a failure',
        () async {
      await write('packages/app/test/screen/screen_test.dart',
          "void main() { testFfGoldens('First', scenario: 'first', build: (_) => null); }");
      await write('packages/other/test/other_test.dart',
          "void main() { testFfGoldens('Second', scenario: 'second', build: (_) => null); }");
      await catalog.refresh();
      final request = {
        'scopeIds': catalog.scenarios.keys.toList(),
        'filters': {'theme': 'dark'}
      };
      final plan = await runner.plan(request);
      expect(plan.commands.first.arguments.join(' '), contains('First'));
      expect(
          plan.commands.first.arguments.join(' '), isNot(contains('Second')));
      expect(plan.commands.last.arguments.join(' '), contains('Second'));
      await flutterScript(
          'printf "%s\\n" "\$PWD" "\$@"\ncase "\$*" in *screen_test.dart*) exit 7;; *) exit 0;; esac');
      await runner.start(request);
      await waitFor(() => !runner.active);
      expect(runner.snapshot()['status'], 'failed');
      expect(runner.snapshot()['exitCode'], 7);
      expect(
          (runner.snapshot()['results'] as List)
              .map((result) => result['status']),
          ['failed', 'passed']);
    }, skip: Platform.isWindows);

    test('Stop cancels pending files and allows a fresh queue', () async {
      await flutterScript('printf "%s" "\$\$" > started.pid\nsleep 60');
      await runner.start({
        'scopeIds': ['project'],
        'filters': {}
      });
      await waitFor(fixture.file('packages/app/started.pid').existsSync);
      runner.stop(runner.runId!);
      await waitFor(() => !runner.active);
      expect(runner.snapshot()['status'], 'cancelled');
      expect(fixture.file('packages/other/started.pid').existsSync(), isFalse);
      await flutterScript('exit 0');
      await runner.start({
        'scopeIds': ['project'],
        'filters': {}
      });
      await waitFor(() => !runner.active);
      expect(runner.snapshot()['status'], 'passed');
      expect(runner.snapshot()['completed'], 2);
    }, skip: Platform.isWindows);

    test('Stop and server shutdown terminate owned child processes', () async {
      await flutterScript('sleep 60 &\nprintf "%s" "\$!" > child.pid\nwait');
      final childFile = fixture.file('packages/app/child.pid');
      for (final shutdown in [false, true]) {
        await runner.start(body());
        await waitFor(childFile.existsSync);
        final child = int.parse(await childFile.readAsString());
        if (shutdown) {
          await runner.close();
        } else {
          runner.stop(runner.snapshot()['id'] as String);
        }
        await waitFor(() => !runner.active);
        expect(runner.snapshot()['status'], 'cancelled');
        final check = await Process.run('ps', ['-p', '$child', '-o', 'stat=']);
        expect(
            (check.stdout as String).trim(), anyOf(isEmpty, startsWith('Z')));
        await childFile.delete();
      }
    }, skip: Platform.isWindows);
  });
}

Future<void> waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for the test process.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
