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

  test('scan returns stable relative metadata without deleting images',
      () async {
    final failureImage = await _writeFile(
      temporaryDirectory,
      'auth/failures/login_testImage.png',
      [1, 2, 3, 4],
    );

    final files = await FailureArtifactCleaner(
      inputDirectory: temporaryDirectory,
    ).scan();

    expect(files, hasLength(1));
    expect(files.single.relativePath, 'auth/failures/login_testImage.png');
    expect(files.single.byteSize, 4);
    expect(files.single.modifiedMicroseconds, greaterThan(0));
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

  test(
      'confirmed cleanup keeps new and unselected files and rejects a rewrite before deleting anything',
      () async {
    final first =
        await _writeFile(temporaryDirectory, 'failures/a.png', [1, 2]);
    final second =
        await _writeFile(temporaryDirectory, 'failures/b.png', [3, 4]);
    final cleaner = FailureArtifactCleaner(inputDirectory: temporaryDirectory);
    final plan = await cleaner.prepare(await cleaner.scan());
    final added = await _writeFile(temporaryDirectory, 'failures/new.png', [5]);
    final modified = (await second.stat()).modified;
    await second.writeAsBytes([6, 7]);
    await second.setLastModified(modified);
    await expectLater(cleaner.cleanPrepared(plan),
        throwsA(isA<FailureArtifactCleanupException>()));
    expect(await first.exists(), isTrue);
    expect(await added.exists(), isTrue);
    final selected = await cleaner.prepare((await cleaner.scan())
        .where((file) => file.relativePath == 'failures/a.png'));
    expect((await cleaner.cleanPrepared(selected)).fileCount, 1);
    expect(await first.exists(), isFalse);
    expect(await second.exists(), isTrue);
    expect(await added.exists(), isTrue);
  });

  test('cleanup refuses a failure directory replaced by a symbolic link',
      () async {
    await _writeFile(temporaryDirectory, 'failures/a.png', [1]);
    final cleaner = FailureArtifactCleaner(inputDirectory: temporaryDirectory);
    final plan = await cleaner.prepare(await cleaner.scan());
    final original = Directory(path.join(temporaryDirectory.path, 'failures'));
    final moved =
        await original.rename(path.join(temporaryDirectory.path, 'preserved'));
    await Link(original.path).create(moved.path);
    await expectLater(cleaner.cleanPrepared(plan),
        throwsA(isA<FailureArtifactCleanupException>()));
    expect(await File(path.join(moved.path, 'a.png')).exists(), isTrue);
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
