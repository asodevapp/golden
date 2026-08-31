// Run explicitly with --dart-define=FF_GOLDEN_DISCOVERY=true
// --tags=ff_golden_discovery --reporter=json. Nothing here may build/capture.
import 'package:ff_golden/ff_golden.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Never forbidden() => throw StateError('A golden callback ran during discovery');

void main() {
  group('Resolved configuration', () {
    final coverage = GoldenCoverage(
      devices: const [GoldenDevice.iPhone11, GoldenDevice.iPadPro129],
      locales: const [Locale('en', 'US'), Locale('ar')],
      themes: [GoldenTheme.light, GoldenTheme.dark],
      textScales: const [1, 1.5],
      highContrasts: const [false, true],
      sampling: GoldenSampling.priority,
      maxCombinations: 2,
    );
    testFfGoldens('Generated coverage',
        scenario: 'probe',
        coverage: coverage,
        build: (_) => forbidden(),
        before: forbidden,
        after: forbidden,
        prepare: (_) => forbidden(),
        interact: (_) => forbidden(),
        dispose: (_) => forbidden());
    testFfGoldenScenarios<int>('Generated cases',
        scenarios: List.generate(
            2, (index) => GoldenScenario(name: 'case-$index', state: index)),
        coverage: coverage,
        build: (_, state) => forbidden());
    testDeviceGoldens(
        'Legacy', (tester, device, locale, theme) async => forbidden(),
        locales: const [Locale('en', 'US'), Locale('ar')],
        setUp: forbidden,
        tearDown: forbidden);
    testWidgets(
        'Ordinary golden test must not run', (tester) async => forbidden(),
        tags: ['golden']);
  });
}
