import 'dart:convert';
import 'dart:io';

import 'package:ff_golden_presenter/ff_golden_presenter.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory project;
  late Directory imageRoot;
  late Directory manifests;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('ff_golden_run_index_');
    imageRoot = Directory(path.join(project.path, 'test', 'screens'));
    manifests = Directory(path.join(project.path, 'build', 'ff_golden'));
    await imageRoot.create(recursive: true);
    await manifests.create(recursive: true);
  });

  tearDown(() => project.delete(recursive: true));

  test('merges shards and maps multi-shot paths with authoritative metadata',
      () async {
    const fileName = 'empty.iPadPro12.9[dark](ar){text-1.5}{rtl}{macOS}{dark}'
        '{high-contrast}.png';
    final image = File(
      path.join(
        imageRoot.path,
        'authentication',
        'golden',
        'checkout',
        fileName,
      ),
    );
    await image.create(recursive: true);
    await _writeManifest(
      File(path.join(manifests.path, 'authentication.ff-golden-run.json')),
      sourceTestFile: 'test/screens/authentication/checkout_test.dart',
      baseDirectory: 'test/screens/authentication',
      capturePath: 'golden/checkout/$fileName',
      captureName: 'empty',
      device: 'iPadPro12.9',
    );
    await _writeManifest(
      File(path.join(manifests.path, 'unrelated.ff-golden-run.json')),
      sourceTestFile: 'test/screens/settings/settings_test.dart',
      baseDirectory: 'test/screens/settings',
      capturePath: 'golden/profile/iphone11.png',
      device: 'iphone11',
    );

    final index = await GoldenRunManifestLoader(
      projectDirectory: project,
      imageRoot: imageRoot,
      manifestPaths: const ['build/ff_golden'],
    ).load();
    final catalog = await GoldenCatalogScanner(
      inputDirectory: imageRoot,
      runIndex: index,
      imageFactory: GoldenImageFactory(
        devicePattern: r'^(.+?)(?=\[|\(|\{|$)',
        localePattern: r'\(([^\)]+)\)',
        themePattern: r'\[([^\]]+)\]',
      ),
    ).scan();
    final golden = catalog.images.single;

    expect(index.manifestCount, 2);
    expect(golden.device, 'iPadPro12.9');
    expect(golden.captureName, 'empty');
    expect(golden.locale, 'ar');
    expect(golden.theme, 'dark');
    expect(golden.textScale, 1.5);
    expect(golden.direction, 'rtl');
    expect(golden.directionMode, 'rtl');
    expect(golden.platform, 'macOS');
    expect(golden.brightness, 'dark');
    expect(golden.highContrast, isTrue);
    expect(golden.status, GoldenImageStatus.failed);
    expect(golden.failurePhase, 'capture');
    expect(golden.error, 'pixel mismatch');
    expect(golden.sourceTestFile, contains('checkout_test.dart'));
  });

  test('supports schema v1 manifests through a unique path suffix', () async {
    final manifest = File(path.join(manifests.path, 'legacy.json'));
    await manifest.writeAsString(
      jsonEncode({
        'schema': 'ff_golden.run',
        'schemaVersion': 1,
        'results': [
          {
            'status': 'passed',
            'durationMs': 3,
            'goldenPaths': ['golden/login/iPadPro12.9.png'],
            'overflowCount': 0,
            'variant': {
              'device': {'name': 'iPadPro12.9'},
              'theme': 'light',
              'locale': 'en-US',
              'textScale': 1,
              'direction': 'ltr',
              'directionMode': 'auto',
              'platform': 'iOS',
              'brightness': 'light',
              'highContrast': false,
            },
          },
        ],
      }),
    );

    final index = await GoldenRunManifestLoader(
      projectDirectory: project,
      imageRoot: imageRoot,
      manifestPaths: [manifest.path],
    ).load();

    final metadata = index.metadataFor(
      'feature/golden/login/iPadPro12.9.png',
    );
    expect(metadata?.device, 'iPadPro12.9');
    expect(metadata?.status, GoldenImageStatus.passed);
  });
}

Future<void> _writeManifest(
  File file, {
  required String sourceTestFile,
  required String baseDirectory,
  required String capturePath,
  required String device,
  String? captureName,
}) async {
  await file.writeAsString(
    jsonEncode({
      'schema': 'ff_golden.run',
      'schemaVersion': 2,
      'source': {
        'testFile': sourceTestFile,
        'goldenBaseDirectory': baseDirectory,
      },
      'results': [
        {
          'status': 'failed',
          'durationMs': 12.5,
          'captures': [
            {'path': capturePath, 'name': captureName},
          ],
          'overflowCount': 1,
          'failurePhase': 'capture',
          'error': 'pixel mismatch',
          'variant': {
            'device': {'name': device},
            'theme': 'dark',
            'locale': 'ar',
            'textScale': 1.5,
            'direction': 'rtl',
            'directionMode': 'rtl',
            'platform': 'macOS',
            'brightness': 'dark',
            'highContrast': true,
          },
        },
      ],
    }),
  );
}
