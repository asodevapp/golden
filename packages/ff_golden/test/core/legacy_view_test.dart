import 'package:ff_golden/ff_golden.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testDeviceGoldens(
    'legacy runner preserves its original view contract',
    (tester, device, locale, theme) async {
      expect(tester.view.physicalSize, const Size(640, 480));
      expect(tester.view.devicePixelRatio, 2);
      expect(tester.view.padding.top, 0);
      expect(tester.view.viewPadding.top, 0);
      expect(tester.platformDispatcher.textScaleFactor, 1.5);
      expect(tester.platformDispatcher.locale, isNot(const Locale('ar')));
      expect(tester.platformDispatcher.platformBrightness, Brightness.light);
      expect(debugDefaultTargetPlatformOverride, isNull);
    },
    devices: const [
      GoldenDevice(
        name: 'legacy',
        logicalSize: Size(320, 240),
        devicePixelRatio: 2,
        platform: TargetPlatform.iOS,
        safeArea: EdgeInsets.only(top: 24),
        brightness: Brightness.dark,
        highContrast: true,
        textScale: 1.5,
      ),
    ],
    locales: const [Locale('ar')],
    themes: [
      GoldenTheme(name: 'dark', data: ThemeData.dark()),
    ],
  );

  testWidgets('legacy GoldenTester captures before postPumping',
      (tester) async {
    final events = <String>[];
    final goldenTester = _RecordingGoldenTester(
      events,
      beforeCapture: (_) async => events.add('beforeCapture'),
      postPumping: (_) async => events.add('postPumping'),
    );

    await goldenTester.builder(
      tester,
      GoldenDevice.iPhone11,
      const Locale('en'),
      GoldenTheme.defaultTheme,
      scenarioName: 'order',
      scenario: (_) async => events.add('scenario'),
    );

    expect(
      events,
      <String>['scenario', 'beforeCapture', 'capture', 'postPumping'],
    );
  });

  testWidgets(
      'legacy GoldenTester preserves unsanitized paths and Locale.toString',
      (tester) async {
    final events = <String>[];
    final goldenTester = _RecordingGoldenTester(events);

    await goldenTester.builder(
      tester,
      const GoldenDevice(
        name: 'device name',
        logicalSize: Size(320, 240),
      ),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      GoldenTheme.dark,
      scenarioName: 'scenario name',
      scenario: (_) async {},
    );

    expect(
      goldenTester.capturedPath,
      'golden/scenario name/device name[dark](zh_Hans).png',
    );
  });
}

class _RecordingGoldenTester extends GoldenTester {
  _RecordingGoldenTester(
    this.events, {
    super.beforeCapture,
    super.postPumping,
  }) : super(
          widget: (_) => const SizedBox(),
          wrapper: (child, locale, theme) => child,
        );

  final List<String> events;
  String? capturedPath;

  @override
  Future<void> matchesGolden() async {
    events.add('capture');
    capturedPath = goldenPath;
  }
}
