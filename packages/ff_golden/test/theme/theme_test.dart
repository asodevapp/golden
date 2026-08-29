import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ff_golden/ff_golden.dart';

/// flutter test --update-goldens test/theme/theme_test.dart

void main() {
  group(
    'Theme golden -',
    () {
      ThemeGoldenTester themeGoldenTester = ThemeGoldenTester();

      testDeviceGoldens(
        'default',
        (tester, device, locale, brightness) async {
          return themeGoldenTester.builder(
            tester,
            device,
            locale,
            brightness,
            scenarioName: 'default',
            scenario: (_) async {
              await themeGoldenTester.init();
            },
          );
        },
      );

      testDeviceGoldens('light and dark',
          (tester, device, locale, brightness) async {
        return themeGoldenTester.builder(
          tester,
          device,
          locale,
          brightness,
          scenarioName: 'different',
          scenario: (_) async {
            await themeGoldenTester.init();
          },
        );
      }, themes: [
        NamedTheme(name: 'light', data: ThemeData.light()),
        NamedTheme(name: 'dark', data: ThemeData.dark()),
      ]);
    },
  );
}

class ThemeGoldenTester extends GoldenTester {
  ThemeGoldenTester()
      : super(
          widget: (key) => const ExampleWidget(),
          wrapper: (child, locale, theme) => MaterialApp(
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              DefaultCupertinoLocalizations.delegate,
            ],
            theme: theme.data,
            locale: locale,
            home: Scaffold(body: child),
          ),
        );

  Future<void> init() async {
    await tester.pump();
  }
}

class ExampleWidget extends StatelessWidget {
  const ExampleWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('Test')),
    );
  }
}
