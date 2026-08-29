import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture.dart';
import 'comparator.dart';
import 'device.dart';
import 'naming.dart';
import 'theme.dart';
import 'variant.dart';

typedef GoldenLegacyWrapper = Widget Function(
    Widget child, Locale locale, GoldenTheme theme);
typedef GoldenVariantWrapper = Widget Function(
    Widget child, GoldenVariant variant);

abstract class GoldenTesterBase {
  GoldenTesterBase({
    required Widget Function(Key key) widget,
    GoldenLegacyWrapper? wrapper,
    GoldenVariantWrapper? variantWrapper,
    this.testName = '',
    this.pathStrategy = const GoldenPathStrategy(),
    this.captureScale,
    this.tolerance = GoldenTolerance.strict,
    this.freezeAnimations = false,
  })  : assert(
          (wrapper == null) != (variantWrapper == null),
          'Provide exactly one of wrapper or variantWrapper.',
        ),
        _widget = widget,
        _legacyWrapper = wrapper,
        _variantWrapper = variantWrapper,
        key = UniqueKey(),
        captureKey = UniqueKey();

  @protected
  final Key key;

  @protected
  final Key captureKey;

  final Widget Function(Key key) _widget;
  final GoldenLegacyWrapper? _legacyWrapper;
  final GoldenVariantWrapper? _variantWrapper;

  final String testName;
  final GoldenPathStrategy pathStrategy;

  /// PNG raster scale. `null` preserves the active device pixel ratio.
  final double? captureScale;
  final GoldenTolerance tolerance;
  final bool freezeAnimations;

  late String scenarioName;
  late WidgetTester tester;
  late GoldenVariant variant;

  GoldenDevice get device => variant.device;
  Locale get locale => variant.locale;
  GoldenTheme get theme => variant.theme;
  String get folder => pathStrategy.folder;

  @mustCallSuper
  Future<void> setScenario({
    required WidgetTester tester,
    required String scenarioName,
    required GoldenDevice device,
    required Locale locale,
    required GoldenTheme theme,
  }) =>
      setVariantScenario(
        tester: tester,
        scenarioName: scenarioName,
        variant: GoldenVariant(
          device: device,
          locale: locale,
          theme: theme,
          textScale: device.textScale,
          direction: GoldenDirection.auto,
          platform: device.platform,
          brightness: device.brightness,
          highContrast: device.highContrast,
        ),
      );

  @mustCallSuper
  Future<void> setVariantScenario({
    required WidgetTester tester,
    required String scenarioName,
    required GoldenVariant variant,
  }) async {
    this.tester = tester;
    this.scenarioName = scenarioName;
    this.variant = variant;

    final child = _widget(key);
    final wrapped = _variantWrapper?.call(child, variant) ??
        _legacyWrapper!(child, variant.locale, variant.theme);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: TickerMode(enabled: !freezeAnimations, child: wrapped),
      ),
    );
  }

  String get goldenPath {
    if (_legacyWrapper != null) {
      final dot = testName.isEmpty ? '' : '.';
      final localeName = locale.toString();
      final localePostfix = localeName == 'en' ? '' : '($localeName)';
      final themePostfix =
          theme == GoldenTheme.defaultTheme ? '' : '[${theme.name}]';
      return '$folder/$scenarioName/'
          '$testName$dot${device.name}$themePostfix$localePostfix.png';
    }
    return pathStrategy.build(
      scenario: scenarioName,
      variant: variant,
      testName: testName,
    );
  }

  Future<void> matchesGolden() => expectFfGolden(
        find.byKey(captureKey),
        goldenPath,
        captureScale: captureScale ?? device.devicePixelRatio,
        tolerance: tolerance,
      );
}

typedef PumpingCallback = Future<void> Function(WidgetTester tester);

class GoldenTester extends GoldenTesterBase {
  GoldenTester({
    required super.widget,
    super.wrapper,
    super.variantWrapper,
    super.testName,
    super.pathStrategy,
    super.captureScale,
    super.tolerance,
    super.freezeAnimations,
    PumpingCallback? beforeCapture,
    PumpingCallback? postPumping = _defaultPostPumping,
  })  : _beforeCapture = beforeCapture,
        _postPumping = postPumping;

  final PumpingCallback? _beforeCapture;
  final PumpingCallback? _postPumping;

  Future<void> builder(
    WidgetTester tester,
    GoldenDevice device,
    Locale locale,
    GoldenTheme theme, {
    required String scenarioName,
    required Future<void> Function(GoldenTesterBase tester) scenario,
    bool wrapRunAsync = false,
  }) async {
    await setScenario(
      tester: tester,
      device: device,
      scenarioName: scenarioName,
      locale: locale,
      theme: theme,
    );
    await _runScenario(scenario, wrapRunAsync: wrapRunAsync);
  }

  Future<void> builderVariant(
    WidgetTester tester,
    GoldenVariant variant, {
    required String scenarioName,
    required Future<void> Function(GoldenTesterBase tester) scenario,
    bool wrapRunAsync = false,
  }) async {
    await setVariantScenario(
      tester: tester,
      scenarioName: scenarioName,
      variant: variant,
    );
    await _runScenario(scenario, wrapRunAsync: wrapRunAsync);
  }

  Future<void> _runScenario(
    Future<void> Function(GoldenTesterBase tester) scenario, {
    required bool wrapRunAsync,
  }) async {
    if (wrapRunAsync) {
      await tester.runAsync(() => scenario(this));
    } else {
      await scenario(this);
    }
    await _beforeCapture?.call(tester);
    await matchesGolden();
    await _postPumping?.call(tester);
  }

  static Future<void> _defaultPostPumping(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  }
}
