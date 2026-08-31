import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

import 'device.dart';
import 'discovery.dart';
import 'error_capture.dart';
import 'test_view.dart';
import 'test_ff_goldens.dart';
import 'theme.dart';
import 'variant.dart';

const List<Locale> defaultLocales = <Locale>[Locale('us', 'US')];
const List<GoldenDevice> defaultDevices = <GoldenDevice>[
  GoldenDevice.iPhone11,
];
final List<GoldenTheme> defaultThemes = [GoldenTheme.defaultTheme];

/// Compatibility API for existing scenario-based suites.
///
/// New suites should prefer [testFfGoldens], which adds coverage sampling,
/// collision checks, automatic capture, and stale detection.
@isTestGroup
void testDeviceGoldens(
  String description,
  Future<void> Function(
    WidgetTester,
    GoldenDevice,
    Locale,
    GoldenTheme,
  ) builder, {
  FutureOr<void> Function()? setUp,
  FutureOr<void> Function()? tearDown,
  List<GoldenDevice> devices = defaultDevices,
  List<Locale> locales = defaultLocales,
  List<GoldenTheme>? themes,
  bool failOnOverflow = true,
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  Iterable<String>? tags,
}) {
  final effectiveThemes = themes ?? defaultThemes;
  for (final device in devices) {
    for (final locale in locales) {
      for (final theme in effectiveThemes) {
        final goldenVariant = GoldenVariant(
          device: device,
          locale: locale,
          theme: theme,
          textScale: device.textScale,
          direction: GoldenDirection.auto,
          platform: device.platform,
          brightness: device.brightness,
          highContrast: device.highContrast,
        );
        if (goldenDiscoveryEnabled) {
          registerGoldenDiscovery(
            testName: '$description (${device.name}:$locale:${theme.name})',
            description: description,
            variant: goldenVariant,
            legacy: true,
          );
          continue;
        }
        testWidgets(
          '$description (${device.name}:$locale:${theme.name})',
          (tester) async {
            final view = GoldenTestViewSession.applyLegacy(
              tester,
              goldenVariant,
            );
            final diagnostics = GoldenDiagnostics();
            try {
              await setUp?.call();
              await GoldenFlutterErrorCapture(diagnostics: diagnostics).run(
                () => builder(tester, device, locale, theme),
                failOnOverflow: failOnOverflow,
              );
            } finally {
              try {
                await tearDown?.call();
              } finally {
                view.reset();
              }
            }
          },
          skip: skip,
          timeout: timeout,
          semanticsEnabled: semanticsEnabled,
          variant: variant,
          tags: {'golden', ...?tags},
        );
      }
    }
  }
}
