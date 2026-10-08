import 'package:ff_golden/ff_golden.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final customDarkTheme = GoldenTheme(
    name: 'custom-dark',
    data: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff006875),
        brightness: Brightness.dark,
      ),
    ),
  );

  testFfGoldens(
    'default app supplies Material UI themes and localizations',
    scenario: 'material-ui/environment',
    coverage: GoldenCoverage(
      devices: const [
        GoldenDevice(
          name: 'android',
          logicalSize: Size(320, 480),
          platform: TargetPlatform.android,
        ),
        GoldenDevice(
          name: 'ios',
          logicalSize: Size(320, 480),
          platform: TargetPlatform.iOS,
        ),
      ],
      locales: const [Locale('en'), Locale('ar')],
      themes: [GoldenTheme.light, customDarkTheme],
    ),
    build: (_) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TextField(key: Key('input')),
        Switch.adaptive(value: true, onChanged: (_) {}),
        FilledButton(onPressed: () {}, child: const Text('Continue')),
      ],
    ),
    configuration: const GoldenRunConfiguration(
      autoCapture: false,
      detectStaleGoldens: false,
    ),
    interact: (context) async {
      final variant = context.variant;
      final element = context.tester.element(find.byKey(const Key('input')));
      final theme = Theme.of(element);
      final materialLocalizations = MaterialLocalizations.of(element);

      expect(theme.platform, variant.platform);
      expect(theme.brightness, variant.theme.data.brightness);
      expect(theme.colorScheme, variant.theme.data.colorScheme);
      expect(materialLocalizations, isA<GlobalMaterialLocalizations>());
      expect(
        materialLocalizations.okButtonLabel,
        variant.locale.languageCode == 'ar' ? 'حسنًا' : 'OK',
      );
      expect(Localizations.localeOf(element), variant.locale);
      expect(Directionality.of(element), variant.textDirection);
      expect(
        WidgetsLocalizations.of(element).textDirection,
        variant.textDirection,
      );

      await context.tester.enterText(find.byKey(const Key('input')), 'hello');
      await context.tester.pump();
      expect(find.text('hello'), findsOneWidget);
      expect(context.tester.takeException(), isNull);
    },
  );
}
