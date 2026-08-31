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

  test('ignores both Git versions once, preserving comments, index and images',
      () async {
    const target = 'test/golden/phone[1](en US).png';
    const neighbor = 'test/golden/phone1(en US).png';
    const original = '# Keep this comment\r\n/other.png\r\n';
    await fixture.file(reviewIgnoreFileName).writeAsString(original);
    await fixture.write(target, [1]);
    await fixture.write(neighbor, [2]);
    await fixture.write('notes.txt', [3]);
    await fixture.commitAll();
    final originalIndex = await fixture.blob(':$reviewIgnoreFileName');
    await fixture.write(target, [4]);
    await fixture.write('notes.txt', [5]);
    await fixture.git(['add', '--', target, 'notes.txt']);
    await fixture.write(target, [6]);
    await fixture.write(neighbor, [7]);
    final selected =
        (await repository.scan()).changes.where((c) => c.path == target);
    expect(selected, hasLength(2));
    await repository.setIgnored({for (final c in selected) c.id: c.revision},
        ignored: true);
    expect(await fixture.file(reviewIgnoreFileName).readAsString(),
        '$original/$target\n');
    final changes = (await repository.scan()).changes;
    expect(changes.where((c) => c.ignored), hasLength(2));
    expect(changes.singleWhere((c) => c.path == neighbor).ignored, isFalse);
    expect(await fixture.blob(':$target'), [4]);
    expect(await fixture.file(target).readAsBytes(), [6]);
    expect(await fixture.blob(':notes.txt'), [5]);
    expect(await fixture.blob(':$reviewIgnoreFileName'), originalIndex);
    final ignored = changes.firstWhere((c) => c.ignored && !c.staged);
    await expectLater(
        repository.setStaged({ignored.id: ignored.revision}, staged: true),
        throwsA(isA<GitReviewException>()));
  });

  test('repository-root rules reload in a subdirectory and cover deleted files',
      () async {
    await fixture.write('test/golden/deleted.png', [1]);
    await fixture.commitAll();
    await fixture.git(['rm', '--', 'test/golden/deleted.png']);
    await fixture.write('test/golden/#new [dark].png', [2]);
    await fixture.file(reviewIgnoreFileName).writeAsString(
        '# Literal paths, not patterns\n/test/golden/deleted.png\n'
        '/test/golden/#new [dark].png\n');
    final scoped = await GitImageRepository.open(
        project: Directory(p.join(fixture.directory.path, 'test')));
    expect((await scoped.scan()).changes.every((c) => c.ignored), isTrue);
    await fixture
        .file(reviewIgnoreFileName)
        .writeAsString('# Cleared by hand\n');
    expect((await scoped.scan()).changes.every((c) => !c.ignored), isTrue);
  });

  test('unignore removes only the exact path, including duplicate entries',
      () async {
    const target = '#phone [light].png';
    await fixture.write(target, [1]);
    final change = (await repository.scan()).changes.single;
    await repository.setIgnored({change.id: change.revision}, ignored: true);
    expect(await fixture.file(reviewIgnoreFileName).readAsString(),
        contains('/$target\n'));
    expect((await repository.scan()).changes.single.ignored, isTrue);
    const comments = '# Keep\r\n/other.png\r\n';
    await fixture
        .file(reviewIgnoreFileName)
        .writeAsString('$comments/$target\r\n/$target\n');
    await repository.setIgnored({change.id: change.revision}, ignored: false);
    expect(await fixture.file(reviewIgnoreFileName).readAsString(), comments);
    expect((await repository.scan()).changes.single.ignored, isFalse);
    expect(await fixture.file(target).readAsBytes(), [1]);
  });

  test('stale selections and arbitrary paths cannot write ignore rules',
      () async {
    await fixture.write('one.png', [1]);
    await fixture.write('two.png', [2]);
    final old = (await repository.scan()).changes;
    await fixture.write('two.png', [3]);
    await expectLater(
      repository
          .setIgnored({for (final c in old) c.id: c.revision}, ignored: true),
      throwsA(isA<GitReviewException>()
          .having((e) => e.conflict, 'conflict', isTrue)),
    );
    await expectLater(
        repository.setIgnored({'../../outside.png': 'made-up'}, ignored: true),
        throwsA(isA<GitReviewException>()));
    expect(await fixture.file(reviewIgnoreFileName).exists(), isFalse);
  });

  test('line breaks in a selected file name cannot inject ignore entries',
      () async {
    await fixture.write('valid.png', [1]);
    await fixture.write('bad\nother.png', [2]);
    final changes = (await repository.scan()).changes;
    await expectLater(
        repository.setIgnored({for (final c in changes) c.id: c.revision},
            ignored: true),
        throwsA(isA<GitReviewException>()
            .having((e) => e.message, 'message', contains('line breaks'))));
    expect(await fixture.file(reviewIgnoreFileName).exists(), isFalse);
  },
      skip:
          Platform.isWindows ? 'Windows forbids line breaks in paths.' : false);

  test('a symlink at .golden_ignore is never followed for reading or writing',
      () async {
    await fixture.write('one.png', [1]);
    final change = (await repository.scan()).changes.single;
    await fixture.file('protected.txt').writeAsString('unchanged');
    await Link(fixture.file(reviewIgnoreFileName).path).create('protected.txt');
    await expectLater(repository.scan(), throwsA(isA<GitReviewException>()));
    await expectLater(
        repository.setIgnored({change.id: change.revision}, ignored: true),
        throwsA(isA<GitReviewException>()));
    expect(await fixture.file('protected.txt').readAsString(), 'unchanged');
  }, skip: Platform.isWindows ? 'Symlink privileges vary on Windows.' : false);
}
