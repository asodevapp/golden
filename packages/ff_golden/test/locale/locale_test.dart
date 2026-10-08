import 'package:ff_golden/ff_golden.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const locales = <Locale>[
  Locale('en'),
  Locale('en', 'US'),
  Locale('id', 'ID'),
  Locale('vi'),
  Locale('ms'),
  Locale('th'),
];

void main() {
  setUpAll(() async {});

  /// flutter test --update-goldens test/locale/locale_test.dart
  group('Example golden -', () {
    ExampleGoldenTester exampleTester = ExampleGoldenTester();

    setUp(() {
      exampleTester = ExampleGoldenTester();
    });

    testDeviceGoldens(
      'loaded page',
      (tester, device, locale, theme) async {
        return exampleTester.builder(
          tester,
          device,
          locale,
          theme,
          scenarioName: 'init',
          scenario: (_) async {
            await exampleTester.init();
          },
        );
      },
      devices: [Device.iPhone11],
      locales: locales,
    );
  });
}

class ExampleGoldenTester extends GoldenTester {
  ExampleGoldenTester()
    : super(
        widget: (key) => const ExampleWidget(),
        wrapper: (child, locale, brightness) => MaterialApp(
          supportedLocales: locales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          locale: locale,
          home: Scaffold(body: child),
        ),
      );

  Future<void> init() async {
    await tester.pumpAndSettle();
  }
}

class ExampleWidget extends StatelessWidget {
  const ExampleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Test'));
  }
}
