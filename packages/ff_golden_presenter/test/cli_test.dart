import 'dart:io';

import 'package:ff_golden_presenter/src/cli.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
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
    expect(output.toString(), 'ff_golden_presenter 1.0.1\n');
  });

  test('generates a report end to end', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'ff_golden_presenter_cli_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final input = Directory(path.join(temporaryDirectory.path, 'input'));
    final image = File(path.join(input.path, 'auth/golden/login/phone.png'));
    await image.create(recursive: true);
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
    expect(
      await File(path.join(publication, 'index.html')).readAsString(),
      isNot(contains('aso.dev')),
    );
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
