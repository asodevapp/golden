import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

@immutable
class GoldenTolerance {
  const GoldenTolerance({
    this.maxDiffRate = 0,
    this.maxDifferentPixels = 0,
  })  : assert(maxDiffRate >= 0 && maxDiffRate <= 1),
        assert(maxDifferentPixels >= 0);

  /// Fraction from 0 to 1. For example, 0.001 means 0.1%.
  final double maxDiffRate;

  /// Absolute changed-pixel budget.
  final int maxDifferentPixels;

  static const strict = GoldenTolerance();

  bool get isStrict => maxDiffRate == 0 && maxDifferentPixels == 0;

  bool allows(ComparisonResult result) {
    if (result.passed) return true;
    if (result.diffPercent <= maxDiffRate) return true;
    if (maxDifferentPixels == 0) return false;

    final image = result.diffs?['testImage'];
    if (image == null) return false;
    final differentPixels =
        (result.diffPercent * image.width * image.height).round();
    return differentPixels <= maxDifferentPixels;
  }
}

class FfGoldenFileComparator extends LocalFileComparator {
  FfGoldenFileComparator(super.testFile,
      {this.tolerance = GoldenTolerance.strict});

  final GoldenTolerance tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (tolerance.allows(result)) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(
      '$error\nConfigured ff_golden tolerance: '
      'maxDiffRate=${tolerance.maxDiffRate} '
      '(${tolerance.maxDiffRate * 100}%), '
      'maxDifferentPixels=${tolerance.maxDifferentPixels}.',
    );
  }
}

Future<T> withFfGoldenTolerance<T>(
  GoldenTolerance tolerance,
  Future<T> Function() body,
) async {
  if (tolerance.isStrict) return body();

  final previous = goldenFileComparator;
  if (previous is! LocalFileComparator) {
    throw StateError(
      'A non-zero ff_golden tolerance requires LocalFileComparator. '
      'The active comparator is ${previous.runtimeType}.',
    );
  }

  goldenFileComparator = FfGoldenFileComparator(
    previous.basedir.resolve('_ff_golden_test.dart'),
    tolerance: tolerance,
  );
  try {
    return await body();
  } finally {
    goldenFileComparator = previous;
  }
}
