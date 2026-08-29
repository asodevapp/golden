import 'package:ff_golden/ff_golden.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default axes keep migration-friendly compact paths', () {
    final variant = GoldenCoverage(
      locales: const [Locale('en')],
    ).plan().variants.single;

    expect(
      const GoldenPathStrategy().build(
        scenario: 'loaded page',
        variant: variant,
      ),
      'golden/loaded-page/iphone11.png',
    );
  });

  test('non-default axes are encoded without ambiguity', () {
    final variant = GoldenVariant(
      device: GoldenDevice.iPhone11,
      locale: const Locale('en', 'US'),
      theme: GoldenTheme(name: 'dark mode', data: ThemeData.dark()),
      textScale: 1.5,
      direction: GoldenDirection.rtl,
      platform: TargetPlatform.android,
      brightness: Brightness.dark,
      highContrast: true,
    );

    expect(
      const GoldenPathStrategy().build(
        scenario: 'loaded',
        testName: 'after tap',
        variant: variant,
      ),
      'golden/loaded/after-tap.iphone11[dark-mode](en-US)'
      '{text-1.5}{rtl}{android}{dark}{high-contrast}.png',
    );
  });

  test('case-insensitive collisions are rejected before tests register', () {
    final variant =
        GoldenCoverage(locales: const [Locale('en')]).plan().variants.single;

    expect(
      () => const GoldenPathStrategy().validate(
        scenario: 'same',
        variants: [variant, variant],
      ),
      throwsA(isA<GoldenPathCollision>()),
    );
  });
}
