import 'package:ff_golden_presenter/src/cli_options.dart';
import 'package:ff_golden_presenter/src/diff_cli_options.dart';
import 'package:ff_golden_presenter/src/migration_cli_options.dart';
import 'package:ff_golden_presenter/src/publication_cli_options.dart';
import 'package:ff_golden_presenter/src/publication_model.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('diff defaults to a local viewer and validates the port', () {
    final options = DiffCliOptions.parse([]);
    expect(options.project, '.');
    expect(options.input, '.');
    expect(options.port, 0);
    expect(options.openBrowser, isTrue);
    expect(DiffCliOptions.parse(['--no-open']).openBrowser, isFalse);
    expect(
        DiffCliOptions.parse(['--flutter', './sdk/bin/flutter'])
            .flutterExecutable,
        path.absolute('./sdk/bin/flutter'));
    expect(
        () => DiffCliOptions.parse(['--port', '65536']), throwsFormatException);
    expect(() => DiffCliOptions.parse(['unexpected']), throwsFormatException);
  });
  test('uses the standardized defaults', () {
    final options = GoldenPresenterOptions.parse(const []);

    expect(options.input, 'test');
    expect(options.output, 'golden-report.html');
    expect(options.goldenDirectory, 'golden');
    expect(options.extensions, containsAll(['png', 'jpg', 'webp', 'svg']));
    expect(options.devicePattern, r'^(.+?)(?=\[|\(|\{|$)');
    expect(options.manifestPaths, ['build/ff_golden']);
    expect(options.supportAttribution, isTrue);
    expect(options.customization.primaryColor, isNull);
    expect(options.customization.faviconPath, isNull);
    expect(options.customization.headerLinks, isEmpty);
  });

  test('report parses reusable project customization', () {
    final options = GoldenPresenterOptions.parse(
      const [
        '--primary-color',
        '0xFF18BFFB',
        '--favicon',
        'web/favicon.png',
        '--header-link',
        'Home=https://aso.dev/',
        '--header-link',
        'Blog=https://aso.dev/blog/?source=goldens',
      ],
    );

    expect(options.customization.primaryColor, '#18BFFB');
    expect(options.customization.faviconPath, 'web/favicon.png');
    expect(
      options.customization.headerLinks.map((link) => link.label),
      ['Home', 'Blog'],
    );
    expect(
      options.customization.headerLinks.last.url,
      'https://aso.dev/blog/?source=goldens',
    );
  });

  test('report rejects malformed or unsafe header links', () {
    expect(
      () => GoldenPresenterOptions.parse(
        const ['--header-link', 'https://aso.dev/'],
      ),
      throwsFormatException,
    );
    expect(
      () => GoldenPresenterOptions.parse(
        const ['--header-link', 'Unsafe=javascript:alert(1)'],
      ),
      throwsFormatException,
    );
  });

  test('report support attribution can be disabled', () {
    final options = GoldenPresenterOptions.parse(
      const ['--no-support-attribution'],
    );

    expect(options.supportAttribution, isFalse);
  });

  test('keeps legacy path arguments compatible', () {
    final options = GoldenPresenterOptions.parse(
      const ['-p', 'test', '--test-path', 'screens'],
    );

    expect(options.input, path.join('test', 'screens'));
  });

  test('rejects positional arguments', () {
    expect(
      () => GoldenPresenterOptions.parse(const ['unexpected']),
      throwsFormatException,
    );
  });

  test('build defaults to the publication pipeline', () {
    final options = BuildCliOptions.parse(const []);

    expect(options.input, 'test/screens');
    expect(options.outputDirectory, 'build/golden-report');
    expect(options.reportFileName, 'index.html');
    expect(options.profile, ImageOptimizationProfile.balanced);
    expect(options.backend, ImageOptimizerBackend.auto);
    expect(options.manifestPaths, ['build/ff_golden']);
    expect(options.supportAttribution, isTrue);
    expect(options.customization.primaryColor, isNull);
  });

  test('build accepts the same report customization flags', () {
    final options = BuildCliOptions.parse(
      const [
        '--primary-color',
        '#18BFFB',
        '--favicon',
        'favicon.svg',
        '--header-link',
        'Home=/',
      ],
    );

    expect(options.customization.primaryColor, '#18BFFB');
    expect(options.customization.faviconPath, 'favicon.svg');
    expect(options.customization.headerLinks.single.url, '/');
  });

  test('build support attribution can be disabled', () {
    final options = BuildCliOptions.parse(
      const ['--no-support-attribution'],
    );

    expect(options.supportAttribution, isFalse);
  });

  test('standalone optimization requires explicit in-place consent', () {
    expect(
      () => OptimizeCliOptions.parse(const ['--profile', 'balanced']),
      throwsFormatException,
    );
    expect(
      OptimizeCliOptions.parse(const ['--profile', 'balanced', '--dry-run'])
          .dryRun,
      isTrue,
    );
  });

  test('migration defaults to a non-writing preview', () {
    final options = MigrationCliOptions.parse(const []);

    expect(options.project, '.');
    expect(options.apply, isFalse);
    expect(options.check, isFalse);
  });

  test('migration apply and check modes are mutually exclusive', () {
    expect(
      () => MigrationCliOptions.parse(const ['--apply', '--check']),
      throwsFormatException,
    );
  });
}
