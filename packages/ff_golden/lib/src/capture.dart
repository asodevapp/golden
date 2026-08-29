import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'comparator.dart';

Future<void> expectFfGolden(
  Finder finder,
  String goldenPath, {
  double captureScale = 1,
  GoldenTolerance tolerance = GoldenTolerance.strict,
}) async {
  if (captureScale <= 0 || !captureScale.isFinite) {
    throw ArgumentError.value(
      captureScale,
      'captureScale',
      'must be finite and greater than zero',
    );
  }

  await withFfGoldenTolerance(tolerance, () async {
    if (captureScale == 1) {
      await expectLater(finder, matchesGoldenFile(goldenPath));
      return;
    }

    final elements = finder.evaluate().toList(growable: false);
    if (elements.length != 1) {
      throw TestFailure(
        'ff_golden expected exactly one capture widget, found '
        '${elements.length}.',
      );
    }

    RenderObject? renderObject = elements.single.renderObject;
    while (renderObject != null && renderObject is! RenderRepaintBoundary) {
      renderObject = renderObject.parent;
    }
    if (renderObject is! RenderRepaintBoundary) {
      throw TestFailure('No RepaintBoundary found for $finder.');
    }

    final ui.Image image = await renderObject.toImage(pixelRatio: captureScale);
    try {
      await expectLater(image, matchesGoldenFile(goldenPath));
    } finally {
      image.dispose();
    }
  });
}
