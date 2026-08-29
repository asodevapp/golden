import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ff_golden/ff_golden.dart';

const locales = <Locale>[
  Locale('en'),
];

void main() {
  setUpAll(() async {});

  /// flutter test --update-goldens test/devices/devices_test.dart
  group(
    'Example golden -',
    () {
      ExampleGoldenTester exampleTester = ExampleGoldenTester();

      setUp(() {
        exampleTester = ExampleGoldenTester();
      });

      testDeviceGoldens(
        'page',
        (tester, device, locale, theme) async {
          return exampleTester.builder(
            tester,
            device,
            locale,
            theme,
            scenarioName: 'sizes',
            scenario: (_) async {
              await exampleTester.init();
            },
          );
        },
        devices: [
          Device.iPhone5S,
          Device.iPhone5SLandscape,
          Device.iPhone11,
          Device.iPhone11Pro,
          Device.iPhone11ProLandscape,
          Device.iPhone11ProMax,
          Device.iPhone11ProMaxLandscape,
          Device.iPhone14,
          Device.iPhone14Plus,
          Device.iPhone15Pro,
          Device.iPhone15ProMax,
          Device.iPadPro129,
          Device.iPadPro129Landscape,
          Device.iPad,
          Device.iPadLandscape,
          Device.fullHd,
          Device.macOS,
          Device.uHD4k,
          Device.iPadPro129,
          Device.iPadPro129Landscape,
          Device.iPadAirGen5,
          Device.iPad7102,
          Device.iPad7102Landscape,
        ],
        locales: [
          const Locale('en'),
        ],
      );
    },
  );
}

class ExampleGoldenTester extends GoldenTester {
  ExampleGoldenTester()
      : super(
          widget: (key) => const ExampleWidget(),
          wrapper: (child, locale, brightness) => MaterialApp(
            supportedLocales: locales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              DefaultCupertinoLocalizations.delegate,
            ],
            locale: locale,
            home: Scaffold(body: child),
          ),
        );

  Future<void> init() async {
    await tester.pumpAndSettle();
  }
}

class ExampleWidget extends StatelessWidget {
  const ExampleWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    return Center(
        child: Column(
      children: [
        Text('Width = ${media.size.width}', style: theme.textTheme.titleLarge),
        Text('Height = ${media.size.height}',
            style: theme.textTheme.titleLarge),
        Text('DevicePixelRatio = ${media.devicePixelRatio}',
            style: theme.textTheme.titleLarge),
      ],
    ));
  }
}
