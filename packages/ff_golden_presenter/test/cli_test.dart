import 'dart:io';

import 'package:ff_golden_presenter/src/cli.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('diff help does not start a server or open a browser', () async {
    final output = StringBuffer();
    final code = await runGoldenPresenter(['diff', '--help'],
        output: output, errors: StringBuffer());
    expect(code, 0);
    expect(output.toString(), contains('127.0.0.1'));
    expect(output.toString(), contains('--[no-]open'));
  });
  test('--help exits successfully without generating a report', () async {
    final output = StringBuffer();
    final errors = StringBuffer();

    final code = await runGoldenPresenter(
      const ['--help'],
      output: output,
      errors: errors,
    );

    expect(code, 0);
    expect(output.toString(), contains('Usage: ff_golden_presenter [options]'));
    expect(errors, isEmpty);
  });

  test('--version uses the Flutter Files package name', () async {
    final output = StringBuffer();

    final code = await runGoldenPresenter(
      const ['--version'],
      output: output,
      errors: StringBuffer(),
    );

    expect(code, 0);
    expect(output.toString(), 'ff_golden_presenter 1.1.0\n');
  });

  test('generates a report end to end', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'ff_golden_presenter_cli_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final input = Directory(path.join(temporaryDirectory.path, 'input'));
    final image = File(path.join(input.path, 'auth/golden/login/phone.png'));
    await image.create(recursive: true);
    final favicon = File(path.join(temporaryDirectory.path, 'favicon.png'));
    await favicon.writeAsBytes([1, 2, 3]);
    final reportPath = path.join(temporaryDirectory.path, 'report/index.html');
    final output = StringBuffer();

    final code = await runGoldenPresenter(
      [
        '--input',
        input.path,
        '--output',
        reportPath,
        '--title',
        'CLI report',
        '--primary-color',
        '0xFF18BFFB',
        '--favicon',
        favicon.path,
        '--header-link',
        'Home=https://aso.dev/',
        '--header-link',
        'Blog=https://aso.dev/blog/',
      ],
      output: output,
      errors: StringBuffer(),
    );

    expect(code, 0);
    expect(
        output.toString(), contains('Generated 1 images across 1 scenarios'));
    expect(await File(reportPath).exists(), isTrue);
    final report = await File(reportPath).readAsString();
    expect(report, contains('CLI report'));
    expect(report, contains('https://aso.dev/'));
    expect(report, contains('--accent: #18BFFB;'));
    expect(report, contains('data:image/png;base64,AQID'));
    expect(report, contains('>Home</a>'));
    expect(report, contains('>Blog</a>'));
  });

  test('reports a missing input directory with a stable exit code', () async {
    final errors = StringBuffer();

    final code = await runGoldenPresenter(
      const ['--input', '/definitely/missing/ff-golden-presenter-input'],
      output: StringBuffer(),
      errors: errors,
    );

    expect(code, 66);
    expect(errors.toString(), contains('input directory does not exist'));
  });

  test('build collects images and creates a staged report', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'ff_golden_presenter_build_cli_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final input = Directory(path.join(temporaryDirectory.path, 'screens'));
    final image = File(path.join(input.path, 'auth/golden/login/phone.png'));
    await image.create(recursive: true);
    final favicon = File(path.join(temporaryDirectory.path, 'favicon.svg'));
    await favicon.writeAsString('<svg xmlns="http://www.w3.org/2000/svg"/>');
    final publication = path.join(temporaryDirectory.path, 'publication');
    final output = StringBuffer();
    final errors = StringBuffer();

    final code = await runGoldenPresenter(
      [
        'build',
        '--input',
        input.path,
        '--output-directory',
        publication,
        '--profile',
        'none',
        '--no-support-attribution',
        '--primary-color',
        '#18BFFB',
        '--favicon',
        favicon.path,
        '--header-link',
        'Project=/',
        '--clean',
      ],
      output: output,
      errors: errors,
    );

    expect(code, 0);
    expect(errors, isEmpty);
    expect(await File(path.join(publication, 'index.html')).exists(), isTrue);
    expect(
      await File(path.join(publication, 'auth/golden/login/phone.png'))
          .exists(),
      isTrue,
    );
    expect(output.toString(), contains('Collected 1 images'));
    expect(output.toString(), contains('Generated 1 images'));
    final report =
        await File(path.join(publication, 'index.html')).readAsString();
    expect(report, isNot(contains('aso.dev')));
    expect(report, contains('--accent: #18BFFB;'));
    expect(report, contains('data:image/svg+xml;base64,'));
    expect(report, contains('href="/">Project</a>'));
  });

  test('clean-failures previews and deletes only failure images', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'ff_golden_presenter_clean_failures_cli_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final failureImage = File(
      path.join(
        temporaryDirectory.path,
        'screens/auth/failures/masterImage.png',
      ),
    );
    await failureImage.create(recursive: true);
    await failureImage.writeAsBytes([1, 2, 3]);
    final goldenImage = File(
      path.join(
        temporaryDirectory.path,
        'screens/auth/golden/login/failure.png',
      ),
    );
    await goldenImage.create(recursive: true);
    await goldenImage.writeAsBytes([4]);
    final output = StringBuffer();

    final previewCode = await runGoldenPresenter(
      [
        'clean-failures',
        '--input',
        path.join(temporaryDirectory.path, 'screens'),
        '--dry-run',
      ],
      output: output,
      errors: StringBuffer(),
    );

    expect(previewCode, 0);
    expect(output.toString(), contains('Would delete 1 failure image (3 B)'));
    expect(await failureImage.exists(), isTrue);

    final cleanOutput = StringBuffer();
    final cleanCode = await runGoldenPresenter(
      [
        'clean-failures',
        '--input',
        path.join(temporaryDirectory.path, 'screens'),
      ],
      output: cleanOutput,
      errors: StringBuffer(),
    );

    expect(cleanCode, 0);
    expect(cleanOutput.toString(), contains('Deleted 1 failure image (3 B)'));
    expect(await failureImage.exists(), isFalse);
    expect(await goldenImage.exists(), isTrue);
  });

  test('migrate supports preview, apply, and clean check modes', () async {
    final project = await Directory.systemTemp.createTemp(
      'ff_golden_presenter_migrate_cli_',
    );
    addTearDown(() => project.delete(recursive: true));
    final testFile = File(path.join(project.path, 'test', 'old_test.dart'));
    await testFile.create(recursive: true);
    await testFile.writeAsString("import 'package:golden/golden.dart';\n");

    final preview = StringBuffer();
    final previewCode = await runGoldenPresenter(
      ['migrate', '--project', project.path],
      output: preview,
      errors: StringBuffer(),
    );

    expect(previewCode, 0);
    expect(preview.toString(), contains('would change test/old_test.dart:1'));
    expect(await testFile.readAsString(), contains('package:golden/'));

    final checkErrors = StringBuffer();
    final checkCode = await runGoldenPresenter(
      ['migrate', '--project', project.path, '--check'],
      output: StringBuffer(),
      errors: checkErrors,
    );
    expect(checkCode, 1);
    expect(checkErrors.toString(), contains('Migration findings remain'));

    final applyCode = await runGoldenPresenter(
      ['migrate', '--project', project.path, '--apply'],
      output: StringBuffer(),
      errors: StringBuffer(),
    );
    expect(applyCode, 0);
    expect(
      await testFile.readAsString(),
      contains('package:ff_golden/ff_golden.dart'),
    );

    final cleanCode = await runGoldenPresenter(
      ['migrate', '--project', project.path, '--check'],
      output: StringBuffer(),
      errors: StringBuffer(),
    );
    expect(cleanCode, 0);
  });
}
