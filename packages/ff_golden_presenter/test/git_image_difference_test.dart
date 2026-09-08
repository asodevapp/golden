import 'dart:typed_data';

import 'package:ff_golden_presenter/src/git_image_difference.dart';
import 'package:ff_golden_presenter/src/git_image_review.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  test('reuses content metrics across files and invalidates changed bytes',
      () async {
    final fixture = await GitFixture.create();
    addTearDown(() => fixture.directory.delete(recursive: true));
    final bytes = _png(2, 2, const {});
    await fixture.write('a.png', bytes);
    await fixture.write('b.png', bytes);
    final repository =
        await GitImageRepository.open(project: fixture.directory);
    final queue = GitImageDifferenceQueue(repository);
    addTearDown(queue.close);
    final initial = await repository.scan();
    queue.schedule(initial);
    await queue.idle;
    final result = queue.stateFor(initial.changes.first);
    expect(result.status, GitImageDifferenceStatus.ready);
    expect(queue.stateFor(initial.changes.last), same(result));
    queue.schedule(await repository.scan());
    expect(queue.stateFor(initial.changes.first), same(result));
    await fixture.write('a.png', _png(3, 2, const {}));
    final changed = await repository.scan();
    queue.schedule(changed);
    await queue.idle;
    expect(queue.stateFor(changed.changes.first).totalPixels, 6);
    expect(queue.stateFor(changed.changes.last), same(result));
    await fixture.write('a.png', bytes);
    final restored = await repository.scan();
    queue.schedule(restored);
    expect(queue.stateFor(restored.changes.first), same(result));
  });

  test('counts exact changed RGBA pixels', () {
    final before = _png(2, 2, const {});
    final after = _png(2, 2, const {
      (1, 0): [255, 0, 0, 255]
    });

    final difference = calculateGitImageDifference(before, after);

    expect(difference, (changedPixels: 1, totalPixels: 4));
  });

  test('uses the union of differently sized images', () {
    final before = _png(2, 1, const {});
    final after = _png(1, 2, const {});

    final difference = calculateGitImageDifference(before, after);

    expect(difference, (changedPixels: 2, totalPixels: 3));
  });

  test('treats every pixel of an added or deleted image as changed', () {
    final bytes = _png(2, 2, const {});

    expect(
      calculateGitImageDifference(null, bytes),
      (changedPixels: 4, totalPixels: 4),
    );
    expect(
      calculateGitImageDifference(bytes, null),
      (changedPixels: 4, totalPixels: 4),
    );
  });

  test('rejects undecodable image data', () {
    expect(
      () => calculateGitImageDifference(Uint8List.fromList([1, 2, 3]), null),
      throwsA(isA<GitReviewException>()),
    );
  });
}

Uint8List _png(
  int width,
  int height,
  Map<(int, int), List<int>> changed,
) {
  final value = image.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final rgba = changed[(x, y)] ?? const [255, 255, 255, 255];
      value.setPixelRgba(x, y, rgba[0], rgba[1], rgba[2], rgba[3]);
    }
  }
  return image.encodePng(value);
}
