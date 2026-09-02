import 'dart:typed_data';

import 'package:ff_golden_presenter/src/git_image_difference.dart';
import 'package:ff_golden_presenter/src/git_image_review.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

void main() {
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
