import 'package:ff_golden/ff_golden.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final themes = [
    GoldenTheme.defaultTheme,
    GoldenTheme(name: 'dark', data: ThemeData.dark()),
  ];

  test('full coverage expands independent axes', () {
    final plan = GoldenCoverage(
      devices: const [GoldenDevice.iPhone11, GoldenDevice.iPad],
      locales: const [Locale('en'), Locale('ar')],
      themes: themes,
      textScales: const [1, 1.5],
      directions: const [GoldenDirection.auto, GoldenDirection.ltr],
      highContrasts: const [false, true],
      maxCombinations: 128,
    ).plan();

    expect(plan.rawCount, 64);
    expect(plan.selectedCount, 64);
    expect(plan.excludedCount, 0);
  });

  test('rules remove invalid combinations before sampling', () {
    final plan = GoldenCoverage(
      locales: const [Locale('en'), Locale('ar')],
      themes: themes,
      rules: [
        GoldenCoverageRule.excludeWhen(
          'no dark Arabic',
          (variant) =>
              variant.locale.languageCode == 'ar' &&
              variant.theme.name == 'dark',
        ),
      ],
    ).plan();

    expect(plan.rawCount, 4);
    expect(plan.excludedCount, 1);
    expect(plan.selectedCount, 3);
  });

  test('smoke sampling keeps every axis value represented', () {
    final full = GoldenCoverage(
      devices: const [GoldenDevice.iPhone11, GoldenDevice.iPad],
      locales: const [Locale('en'), Locale('ar')],
      themes: themes,
      textScales: const [1, 1.5],
      highContrasts: const [false, true],
    ).plan();
    final smoke = GoldenCoverage(
      devices: const [GoldenDevice.iPhone11, GoldenDevice.iPad],
      locales: const [Locale('en'), Locale('ar')],
      themes: themes,
      textScales: const [1, 1.5],
      highContrasts: const [false, true],
      sampling: GoldenSampling.smoke,
    ).plan();

    expect(
      smoke.variants.expand((variant) => variant.axisValues).toSet(),
      containsAll(
        full.variants.expand((variant) => variant.axisValues).toSet(),
      ),
    );
    expect(smoke.selectedCount, lessThan(full.selectedCount));
  });

  test('pairwise sampling covers every feasible value pair', () {
    final full = GoldenCoverage(
      devices: const [GoldenDevice.iPhone11, GoldenDevice.iPad],
      locales: const [Locale('en'), Locale('ar')],
      themes: themes,
      textScales: const [1, 1.5],
    ).plan();
    final pairwise = GoldenCoverage(
      devices: const [GoldenDevice.iPhone11, GoldenDevice.iPad],
      locales: const [Locale('en'), Locale('ar')],
      themes: themes,
      textScales: const [1, 1.5],
      sampling: GoldenSampling.pairwise,
    ).plan();

    expect(_pairs(pairwise.variants), containsAll(_pairs(full.variants)));
    expect(pairwise.selectedCount, lessThan(full.selectedCount));
  });

  test('coverage-preserving strategies reject an insufficient budget', () {
    expect(
      () => GoldenCoverage(
        devices: const [GoldenDevice.iPhone11, GoldenDevice.iPad],
        locales: const [Locale('en'), Locale('ar')],
        themes: themes,
        sampling: GoldenSampling.pairwise,
        maxCombinations: 1,
      ).plan(),
      throwsA(isA<GoldenCoverageBudgetExceeded>()),
    );
  });

  test('priority sampling uses maxCombinations as a hard cap', () {
    final plan = GoldenCoverage(
      devices: const [GoldenDevice.iPhone11, GoldenDevice.iPad],
      locales: const [Locale('en'), Locale('ar')],
      themes: themes,
      textScales: const [1, 1.5],
      sampling: GoldenSampling.priority,
      maxCombinations: 3,
    ).plan();

    expect(plan.selectedCount, 3);
  });
}

Set<String> _pairs(Iterable<GoldenVariant> variants) {
  final result = <String>{};
  for (final variant in variants) {
    final values = variant.axisValues;
    for (var left = 0; left < values.length; left++) {
      for (var right = left + 1; right < values.length; right++) {
        result.add('$left:${values[left]}|$right:${values[right]}');
      }
    }
  }
  return result;
}
