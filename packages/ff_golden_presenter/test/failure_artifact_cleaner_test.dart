import 'dart:io';

import 'package:ff_golden_presenter/ff_golden_presenter.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'ff_golden_failure_cleaner_',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('dry-run reports failure images without deleting them', () async {
    final failureImage = await _writeFile(
      temporaryDirectory,
      'auth/failures/masterImage.png',
      [1, 2, 3],
    );

    final result = await FailureArtifactCleaner(
      inputDirectory: temporaryDirectory,
    ).clean(dryRun: true);

    expect(result.fileCount, 1);
    expect(result.totalBytes, 3);
    expect(await failureImage.exists(), isTrue);
  });

  test('deletes only configured images below exact failures directories',
      () async {
    final pngFailure = await _writeFile(
      temporaryDirectory,
      'auth/failures/masterImage.PNG',
      [1],
    );
    final webpFailure = await _writeFile(
      temporaryDirectory,
      'auth/failures/diff.webp',
      [2],
    );
    final failureNotes = await _writeFile(
      temporaryDirectory,
      'auth/failures/notes.txt',
      [3],
    );
    final similarlyNamedDirectory = await _writeFile(
      temporaryDirectory,
      'auth/not-failures/masterImage.png',
      [4],
    );
    final golden = await _writeFile(
      temporaryDirectory,
      'auth/golden/login/failure.png',
      [5],
    );

    final result = await FailureArtifactCleaner(
      inputDirectory: temporaryDirectory,
      extensions: const {'png', 'webp'},
    ).clean();

    expect(result.fileCount, 2);
    expect(result.totalBytes, 2);
    expect(await pngFailure.exists(), isFalse);
    expect(await webpFailure.exists(), isFalse);
    expect(await failureNotes.exists(), isTrue);
    expect(await similarlyNamedDirectory.exists(), isTrue);
    expect(await golden.exists(), isTrue);
  });

  test('refuses to clean from the filesystem root', () async {
    final root = Directory(path.rootPrefix(temporaryDirectory.path));

    expect(
      () => FailureArtifactCleaner(inputDirectory: root).clean(),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('filesystem root'),
        ),
      ),
    );
  });

  test('accepts a failures directory as the input itself', () async {
    final failures = Directory(
      path.join(temporaryDirectory.path, 'auth', 'failures'),
    );
    final failureImage = await _writeFile(
      failures,
      'masterImage.png',
      [1],
    );

    final result = await FailureArtifactCleaner(
      inputDirectory: failures,
    ).clean();

    expect(result.fileCount, 1);
    expect(await failureImage.exists(), isFalse);
  });
}

Future<File> _writeFile(
  Directory root,
  String relativePath,
  List<int> bytes,
) async {
  final file = File(path.join(root.path, relativePath));
  await file.create(recursive: true);
  await file.writeAsBytes(bytes);
  return file;
}
