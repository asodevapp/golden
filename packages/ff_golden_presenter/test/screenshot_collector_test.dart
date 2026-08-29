import 'dart:io';

import 'package:ff_golden_presenter/ff_golden_presenter.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test('copies supported screenshots and preserves relative paths', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'ff_golden_presenter_collect_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final input = Directory(path.join(temporaryDirectory.path, 'input'));
    final output = Directory(path.join(temporaryDirectory.path, 'output'));
    final png = File(path.join(input.path, 'auth/golden/login/phone.png'));
    final text = File(path.join(input.path, 'auth/golden/login/notes.txt'));
    await png.create(recursive: true);
    await png.writeAsBytes([1, 2, 3]);
    await text.writeAsString('ignored');

    final result = await ScreenshotCollector(
      inputDirectory: input,
      outputDirectory: output,
      extensions: const {'png'},
    ).collect(clean: false);

    expect(result.fileCount, 1);
    expect(result.totalBytes, 3);
    expect(
      await File(path.join(output.path, 'auth/golden/login/phone.png'))
          .exists(),
      isTrue,
    );
    expect(
      await File(path.join(output.path, 'auth/golden/login/notes.txt'))
          .exists(),
      isFalse,
    );
  });

  test('refuses to clean an output directory that contains the input',
      () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'ff_golden_presenter_collect_guard_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final input = Directory(path.join(temporaryDirectory.path, 'input'));
    await File(path.join(input.path, 'golden/example.png'))
        .create(recursive: true);

    final collector = ScreenshotCollector(
      inputDirectory: input,
      outputDirectory: temporaryDirectory,
      extensions: const {'png'},
    );

    expect(
      () => collector.collect(clean: true),
      throwsA(isA<FormatException>()),
    );
  });
}
