import 'dart:io';

import 'package:ff_golden_presenter/ff_golden_presenter.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('ff_clean_goldens_');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  Future<File> write(String name, [List<int> bytes = const [1, 2]]) async {
    final file = File(path.join(root.path, name));
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file;
  }

  test('preview and cleanup use exact golden directories and supported formats',
      () async {
    final baselines = [
      await write('auth/golden/a.PNG'),
      await write('auth/golden/nested/b.jpg'),
      await write('other/golden/c.jpeg'),
      await write('other/golden/d.webp'),
      await write('other/golden/e.svg'),
    ];
    final preserved = [
      await write('auth/golden/notes.txt'),
      await write('auth/goldens/a.png'),
      await write('auth/not-golden/a.png'),
      await write('auth/a.png'),
      await write('auth/failures/a.png'),
      await write('auth/golden/failures/a.png'),
      await write('auth/failures/golden/a.png'),
    ];
    final cleaner = GoldenImageCleaner(inputDirectory: root);
    final preview = await cleaner.clean(dryRun: true);
    expect(preview.fileCount, 5);
    expect(preview.totalBytes, 10);
    for (final file in baselines) {
      expect(await file.exists(), isTrue);
    }
    expect((await cleaner.clean()).fileCount, 5);
    for (final file in baselines) {
      expect(await file.exists(), isFalse);
    }
    for (final file in preserved) {
      expect(await file.exists(), isTrue);
    }
    expect(
      (await GoldenImageCleaner(
        inputDirectory: Directory(path.join(root.path, 'auth/failures/golden')),
      ).clean())
          .fileCount,
      0,
    );
    expect(
        await Directory(path.join(root.path, 'other/golden')).exists(), isTrue);
  });

  test('accepts a golden directory directly and a restricted extension set',
      () async {
    final png = await write('golden/a.png'),
        webp = await write('golden/b.webp');
    final cleaner = GoldenImageCleaner(
      inputDirectory: Directory(path.join(root.path, 'golden')),
      extensions: const {'.PNG'},
    );
    expect((await cleaner.clean()).fileCount, 1);
    expect(await png.exists(), isFalse);
    expect(await webp.exists(), isTrue);
  });

  test('does not follow file, directory, or input symlinks', () async {
    final original = await write('outside/image.png');
    final golden = Directory(path.join(root.path, 'golden'));
    await golden.create();
    await Link(path.join(golden.path, 'linked.png')).create(original.path);
    await Link(path.join(golden.path, 'linked')).create(original.parent.path);
    final inputLink = Link(path.join(root.path, 'input'));
    await inputLink.create(golden.path);
    expect(
        (await GoldenImageCleaner(inputDirectory: root).clean()).fileCount, 0);
    expect(await original.exists(), isTrue);
    expect(
        await FileSystemEntity.type(path.join(golden.path, 'linked.png'),
            followLinks: false),
        FileSystemEntityType.link);
    await expectLater(
        GoldenImageCleaner(inputDirectory: Directory(inputLink.path)).clean(),
        throwsFormatException);
  },
      skip: Platform.isWindows
          ? 'Creating symlinks requires privileges on Windows.'
          : false);

  test(
      'prepared cleanup keeps new images and rejects changed or escaping files',
      () async {
    final first = await write('golden/a.png'),
        second = await write('golden/b.png');
    final cleaner = GoldenImageCleaner(inputDirectory: root);
    final files = await cleaner.scan(),
        plan = await cleaner.prepare(await cleaner.scan());
    final added = await write('golden/new.png');
    final modified = (await second.stat()).modified;
    await second.writeAsBytes([8, 9]);
    await second.setLastModified(modified);
    await expectLater(
        cleaner.cleanPrepared(plan), throwsA(isA<ImageCleanupException>()));
    expect(await first.exists(), isTrue);
    final selected = await cleaner
        .prepare(files.where((file) => file.relativePath == 'golden/a.png'));
    expect((await cleaner.cleanPrepared(selected)).fileCount, 1);
    expect(await added.exists(), isTrue);
    expect(await second.exists(), isTrue);
    await expectLater(
        cleaner.prepare([
          const ImageCleanupFile(
            relativePath: '../golden/escape.png',
            byteSize: 2,
            modifiedMicroseconds: 0,
          )
        ]),
        throwsA(isA<ImageCleanupException>()));
  });
}
