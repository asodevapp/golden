import 'dart:io';

import 'package:ff_golden_presenter/src/failure_artifact_review.dart';
import 'package:ff_golden_presenter/src/git_image_review.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

void main() {
  test(
      'artifact order is stable and diagnostic masks do not invalidate metrics',
      () async {
    const expected = FailureImageArtifact(
        relativePath: 'a_masterImage.png',
        byteSize: 20,
        modifiedMicroseconds: 1);
    const actual = FailureImageArtifact(
        relativePath: 'a_testImage.png', byteSize: 20, modifiedMicroseconds: 2);
    final first = FailureImageChange(path: 'a.png', artifacts: {
      FailureArtifactKind.expected: expected,
      FailureArtifactKind.actual: actual,
    });
    final reordered = FailureImageChange(path: 'a.png', artifacts: {
      FailureArtifactKind.actual: actual,
      FailureArtifactKind.expected: expected,
    });
    final masked = FailureImageChange(path: 'a.png', artifacts: {
      ...first.artifacts,
      FailureArtifactKind.maskedDiff: const FailureImageArtifact(
          relativePath: 'a_maskedDiff.png',
          byteSize: 20,
          modifiedMicroseconds: 3),
    });
    expect(reordered.revision, first.revision);
    expect(masked.revision, isNot(first.revision));
    expect(masked.differenceKey, first.differenceKey);
  });

  test('failure scans cache metrics and reject a rewrite with preserved mtime',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('ff_failure_cache_');
    addTearDown(() => directory.delete(recursive: true));
    final before = File('${directory.path}/failures/a_masterImage.png');
    final after = File('${directory.path}/failures/a_testImage.png');
    await before.create(recursive: true);
    final pixels = image.Image(width: 2, height: 2, numChannels: 4);
    final bytes = image.encodePng(pixels, level: 0);
    await before.writeAsBytes(bytes);
    await after.writeAsBytes(bytes);
    final repository = FailureImageRepository(inputDirectory: directory);
    final queue = FailureImageDifferenceQueue(repository);
    addTearDown(queue.close);
    final initial = await repository.scan();
    queue.schedule(initial);
    await queue.idle;
    final result = queue.stateFor(initial.changes.single);
    expect(result.percent, 0);
    await File('${directory.path}/failures/a_maskedDiff.png')
        .writeAsBytes(bytes);
    final masked = await repository.scan();
    queue.schedule(masked);
    expect(queue.stateFor(masked.changes.single), same(result));

    final stat = await after.stat();
    // Ensure a distinct ctime even on filesystems with a coarse timestamp.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    pixels.setPixelRgba(0, 0, 255, 0, 0, 255);
    final replacement = image.encodePng(pixels, level: 0);
    expect(replacement.length, bytes.length);
    await after.writeAsBytes(replacement);
    await after.setLastModified(stat.modified);
    final nextStat = await after.stat();
    expect(nextStat.changed, isNot(stat.changed));
    await expectLater(
      repository.readImage(initial.changes.single, before: false),
      throwsA(isA<GitReviewException>()),
    );
    final changed = await repository.scan();
    expect(changed.changes.single.differenceKey,
        isNot(initial.changes.single.differenceKey));
    queue.schedule(changed);
    await queue.idle;
    expect(queue.stateFor(changed.changes.single).percent, 25);
  }, skip: Platform.isWindows ? 'Windows ctime is file creation time.' : false);
}
