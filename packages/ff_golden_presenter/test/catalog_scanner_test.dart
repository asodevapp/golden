import 'dart:io';

import 'package:ff_golden_presenter/ff_golden_presenter.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'ff_golden_presenter_scanner_',
    );
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('groups supported images into semantic scenarios', () async {
    await _touch(
      temporaryDirectory,
      'screens/settings/golden/language/iphone_15[dark](en-US).png',
    );
    await _touch(
      temporaryDirectory,
      'screens/settings/golden/language/pixel_8[light](de-DE).SVG',
    );
    await _touch(temporaryDirectory, 'screens/settings/not-golden/ignored.png');
    await _touch(
      temporaryDirectory,
      'screens/settings/golden/language/ignored.txt',
    );

    final catalog = await _scanner(temporaryDirectory).scan();

    expect(catalog.scenarios, hasLength(1));
    expect(catalog.imageCount, 2);
    expect(catalog.devices, ['iphone_15', 'pixel_8']);
    expect(catalog.themes, ['dark', 'light']);
    expect(catalog.locales, ['de-DE', 'en-US']);

    final scenario = catalog.scenarios.single;
    expect(scenario.pathSegments, ['screens', 'settings', 'language']);
    expect(scenario.breadcrumb, 'screens / settings / language');

    final image = scenario.images.first;
    expect(image.fileName, 'iphone_15[dark](en-US).png');
    expect(image.device, 'iphone_15');
    expect(image.theme, 'dark');
    expect(image.locale, 'en-US');
    expect(image.extension, 'png');
  });

  test('uses a Root scenario when images sit directly below the marker',
      () async {
    await _touch(temporaryDirectory, 'golden/tablet.png');

    final catalog = await _scanner(temporaryDirectory).scan();

    expect(catalog.scenarios.single.breadcrumb, 'Root');
    expect(catalog.scenarios.single.images.single.device, 'tablet');
  });

  test('keeps dotted devices and parses every filename coverage axis',
      () async {
    await _touch(
      temporaryDirectory,
      'golden/details/'
      'iPadPro12.9[dark](ar){text-1.5}{rtl}{macOS}{dark}'
      '{high-contrast}.png',
    );

    final image = (await _scanner(temporaryDirectory).scan()).images.single;

    expect(image.device, 'iPadPro12.9');
    expect(image.theme, 'dark');
    expect(image.locale, 'ar');
    expect(image.textScale, 1.5);
    expect(image.direction, 'rtl');
    expect(image.platform, 'macOS');
    expect(image.brightness, 'dark');
    expect(image.highContrast, isTrue);
  });
}

GoldenCatalogScanner _scanner(Directory input) {
  return GoldenCatalogScanner(
    inputDirectory: input,
    imageFactory: GoldenImageFactory(
      devicePattern: r'^(.+?)(?=\[|\(|\{|$)',
      localePattern: r'\(([^\)]+)\)',
      themePattern: r'\[([^\]]+)\]',
    ),
  );
}

Future<void> _touch(Directory root, String relativePath) async {
  final file = File(path.join(root.path, relativePath));
  await file.create(recursive: true);
}
