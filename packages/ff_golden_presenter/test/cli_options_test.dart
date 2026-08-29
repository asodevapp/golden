import 'package:ff_golden_presenter/src/cli_options.dart';
import 'package:ff_golden_presenter/src/migration_cli_options.dart';
import 'package:ff_golden_presenter/src/publication_cli_options.dart';
import 'package:ff_golden_presenter/src/publication_model.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('uses the standardized defaults', () {
    final options = GoldenPresenterOptions.parse(const []);

    expect(options.input, 'test');
    expect(options.output, 'golden-report.html');
    expect(options.goldenDirectory, 'golden');
    expect(options.extensions, containsAll(['png', 'jpg', 'webp', 'svg']));
    expect(options.devicePattern, r'^(.+?)(?=\[|\(|\{|$)');
    expect(options.manifestPaths, ['build/ff_golden']);
    expect(options.supportAttribution, isTrue);
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
