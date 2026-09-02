import 'dart:io';

import 'package:ff_golden_presenter/src/git_image_review.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  late GitFixture fixture;
  late GitImageRepository repository;
  setUp(() async {
    fixture = await GitFixture.create();
    repository = await GitImageRepository.open(project: fixture.directory);
  });
  tearDown(() => fixture.directory.delete(recursive: true));

  test('reads HEAD, index and worktree as three distinct binary versions',
      () async {
    const file = 'test/golden/login/phone[light](en US).png';
    await fixture.write(file, [0, 255, 128]);
    await fixture.commitAll();
    await fixture.write(file, [0, 254, 127]);
    await fixture.git(['add', '--', file]);
    await fixture.write(file, [0, 253, 126]);

    final snapshot = await repository.scan();
    expect(snapshot.changes, hasLength(2));
    final unstaged = snapshot.changes.first;
    final staged = snapshot.changes.last;
    expect(unstaged.staged, isFalse);
    expect(staged.staged, isTrue);
    expect(await repository.readImage(staged, before: true), [0, 255, 128]);
    expect(await repository.readImage(staged, before: false), [0, 254, 127]);
    expect(await repository.readImage(unstaged, before: true), [0, 254, 127]);
    expect(await repository.readImage(unstaged, before: false), [0, 253, 126]);
  });

  test(
      'stage and unstage touch only literal selected paths, preserving other staged work',
      () async {
    const target = 'test/golden/file[1].png';
    const neighbor = 'test/golden/file1.png';
    await fixture.write(target, [1]);
    await fixture.write(neighbor, [2]);
    await fixture.write('notes.txt', [3]);
    await fixture.commitAll();
    await fixture.write(target, [4]);
    await fixture.write(neighbor, [5]);
    await fixture.write('notes.txt', [6]);
    await fixture.git(['add', '--', 'notes.txt']);
    final selected =
        (await repository.scan()).changes.singleWhere((c) => c.path == target);
    await repository.setStaged({selected.id: selected.revision}, staged: true);
    expect(await fixture.blob(':$target'), [4]);
    expect(await fixture.blob(':$neighbor'), [2]);
    expect(await fixture.blob(':notes.txt'), [6]);
    final staged =
        (await repository.scan()).changes.singleWhere((c) => c.staged);
    await repository.setStaged({staged.id: staged.revision}, staged: false);
    expect(await fixture.blob(':$target'), [1]);
    expect(await fixture.blob(':notes.txt'), [6]);
    expect(await fixture.file(target).readAsBytes(), [4]);
  });

  test('staging removes an unheld stale index lock and retries once', () async {
    await fixture.write('image.png', [1]);
    await fixture.commitAll();
    await fixture.write('image.png', [2]);
    final selected = (await repository.scan()).changes.single;
    final lock = fixture.file('.git/index.lock');
    await lock.writeAsString('stale');
    repository = await GitImageRepository.open(
      project: fixture.directory,
      lockUsageProbe: (_) async => false,
    );

    final removedStaleIndexLock = await repository.setStaged(
      {selected.id: selected.revision},
      staged: true,
    );

    expect(removedStaleIndexLock, isTrue);
    expect(await lock.exists(), isFalse);
    expect(await fixture.blob(':image.png'), [2]);
  });

  test('staging preserves an active or unverifiable index lock', () async {
    await fixture.write('image.png', [1]);
    await fixture.commitAll();
    await fixture.write('image.png', [2]);
    final selected = (await repository.scan()).changes.single;
    final lock = fixture.file('.git/index.lock');
    await lock.writeAsString('active');
    for (final inUse in <bool?>[true, null]) {
      repository = await GitImageRepository.open(
        project: fixture.directory,
        lockUsageProbe: (_) async => inUse,
      );

      await expectLater(
        repository.setStaged(
          {selected.id: selected.revision},
          staged: true,
        ),
        throwsA(isA<GitReviewException>().having(
            (error) => error.message, 'message', contains('index.lock'))),
      );

      expect(await lock.readAsString(), 'active');
      expect(await fixture.blob(':image.png'), [1]);
    }
  });

  test('stale batch is rejected before staging any selected path', () async {
    await fixture.write('one.png', [1]);
    await fixture.write('two.png', [2]);
    await fixture.commitAll();
    await fixture.write('one.png', [3]);
    await fixture.write('two.png', [4]);
    final before = await repository.scan();
    await fixture.write('two.png', [5]);
    await expectLater(
      repository.setStaged({for (final c in before.changes) c.id: c.revision},
          staged: true),
      throwsA(isA<GitReviewException>()
          .having((e) => e.conflict, 'conflict', isTrue)),
    );
    expect(await fixture.blob(':one.png'), [1]);
    expect(await fixture.blob(':two.png'), [2]);
    await expectLater(repository.readImage(before.changes.last, before: false),
        throwsA(isA<GitReviewException>()));
  });

  test(
      'new, staged-added, deleted and staged-deleted images have missing sides',
      () async {
    await fixture.write('deleted.png', [1]);
    await fixture.write('staged-deleted.png', [2]);
    await fixture.commitAll();
    await fixture.file('deleted.png').delete();
    await fixture.git(['rm', '--', 'staged-deleted.png']);
    await fixture.write('new.png', [3]);
    await fixture.write('staged-new.png', [4]);
    await fixture.git(['add', '--', 'staged-new.png']);
    final changes = (await repository.scan()).changes;
    expect(changes, hasLength(4));
    for (final change in changes) {
      final deleted = change.path.contains('deleted');
      expect(change.hasBefore, deleted);
      expect(change.hasAfter, !deleted);
      expect(await repository.readImage(change, before: deleted), isNotEmpty);
    }
  });

  test(
      'unstaging on an unborn branch preserves working files and other index entries',
      () async {
    await fixture.write('one.png', [1]);
    await fixture.write('two.png', [2]);
    await fixture.git(['add', '--', 'one.png', 'two.png']);
    await fixture.write('one.png', [3]);
    final change = (await repository.scan())
        .changes
        .singleWhere((c) => c.staged && c.path == 'one.png');
    await repository.setStaged({change.id: change.revision}, staged: false);
    expect(await fixture.file('one.png').readAsBytes(), [3]);
    expect(await fixture.blob(':two.png'), [2]);
    expect(
        (await repository.scan())
            .changes
            .any((c) => c.path == 'one.png' && c.status == '?'),
        isTrue);
  });

  test('scope includes deleted directories and excludes neighboring images',
      () async {
    await fixture.write('test/golden/a.png', [1]);
    await fixture.write('other/b.png', [2]);
    await fixture.commitAll();
    await Directory(p.join(fixture.directory.path, 'test'))
        .delete(recursive: true);
    await fixture.write('other/b.png', [3]);
    final scoped = await GitImageRepository.open(
        project: fixture.directory, input: 'test');
    expect((await scoped.scan()).changes.single.path, 'test/golden/a.png');
    await expectLater(
        GitImageRepository.open(project: fixture.directory, input: '..'),
        throwsA(isA<GitReviewException>()));
  });

  test('symlinks are not read or offered for stage', () async {
    await fixture.write('secret.txt', [1]);
    await Link(p.join(fixture.directory.path, 'linked.png'))
        .create('secret.txt');
    final snapshot = await repository.scan();
    expect(snapshot.changes, isEmpty);
    expect(snapshot.warnings.single, contains('regular file'));
  }, skip: Platform.isWindows ? 'Symlink privileges vary on Windows.' : false);

  test('LFS pointers fail explicitly instead of being shown as image bytes',
      () async {
    await fixture.file('image.png').writeAsString(
        'version https://git-lfs.github.com/spec/v1\noid sha256:abc\nsize 10\n');
    final change = (await repository.scan()).changes.single;
    await expectLater(
        repository.readImage(change, before: false),
        throwsA(isA<GitReviewException>()
            .having((e) => e.message, 'message', contains('LFS'))));
  });

  test('conflicted images cannot be offered for staging', () async {
    await fixture.write('conflict.png', [0, 1]);
    await fixture.commitAll();
    await fixture.git(['checkout', '-b', 'side']);
    await fixture.write('conflict.png', [0, 2]);
    await fixture.commitAll();
    await fixture.git(['checkout', '-b', 'other', 'HEAD~1']);
    await fixture.write('conflict.png', [0, 3]);
    await fixture.commitAll();
    await expectLater(fixture.git(['merge', 'side']), throwsStateError);
    final snapshot = await repository.scan();
    expect(snapshot.changes, isEmpty);
    expect(snapshot.warnings.single, contains('Resolve the Git conflict'));
  });
}
