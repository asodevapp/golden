import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'variant.dart';

class GoldenTestViewSession {
  GoldenTestViewSession._(this._tester, this._previousPlatform);

  final WidgetTester _tester;
  final TargetPlatform? _previousPlatform;
  var _reset = false;

  static GoldenTestViewSession apply(
    WidgetTester tester,
    GoldenVariant variant,
  ) {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    final ratio = variant.device.devicePixelRatio;
    final safeArea = variant.device.safeArea;
    final padding = FakeViewPadding(
      left: safeArea.left * ratio,
      top: safeArea.top * ratio,
      right: safeArea.right * ratio,
      bottom: safeArea.bottom * ratio,
    );

    tester.view.devicePixelRatio = ratio;
    tester.view.physicalSize = variant.device.physicalSize;
    tester.view.padding = padding;
    tester.view.viewPadding = padding;

    final dispatcher = tester.platformDispatcher;
    dispatcher.localeTestValue = variant.locale;
    dispatcher.localesTestValue = [variant.locale];
    dispatcher.textScaleFactorTestValue = variant.textScale;
    dispatcher.platformBrightnessTestValue = variant.brightness;
    dispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
      highContrast: variant.highContrast,
    );
    debugDefaultTargetPlatformOverride = variant.platform;

    return GoldenTestViewSession._(tester, previousPlatform);
  }

  /// Preserves the view contract of the original `testDeviceGoldens` API.
  ///
  /// Legacy suites configured only physical size, device pixel ratio, and text
  /// scale. Applying newer axes here would silently invalidate existing golden
  /// baselines during a package-name migration.
  static GoldenTestViewSession applyLegacy(
    WidgetTester tester,
    GoldenVariant variant,
  ) {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    tester.view.devicePixelRatio = variant.device.devicePixelRatio;
    tester.view.physicalSize = variant.device.physicalSize;
    tester.platformDispatcher.textScaleFactorTestValue = variant.textScale;
    return GoldenTestViewSession._(tester, previousPlatform);
  }

  void reset() {
    if (_reset) return;
    _reset = true;
    _tester.view.resetPhysicalSize();
    _tester.view.resetDevicePixelRatio();
    _tester.view.resetPadding();
    _tester.view.resetViewPadding();
    final dispatcher = _tester.platformDispatcher;
    dispatcher.clearLocaleTestValue();
    dispatcher.clearLocalesTestValue();
    dispatcher.clearTextScaleFactorTestValue();
    dispatcher.clearPlatformBrightnessTestValue();
    dispatcher.clearAccessibilityFeaturesTestValue();
    debugDefaultTargetPlatformOverride = _previousPlatform;
  }
}
