import 'package:ff_golden/ff_golden.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tolerance uses Flutter fraction semantics', () {
    const tolerance = GoldenTolerance(maxDiffRate: 0.001);

    expect(
      tolerance.allows(
        ComparisonResult(passed: false, diffPercent: 0.001),
      ),
      isTrue,
    );
    expect(
      tolerance.allows(
        ComparisonResult(passed: false, diffPercent: 0.01),
      ),
      isFalse,
    );
  });

  test('strict tolerance rejects every non-zero difference', () {
    expect(
      GoldenTolerance.strict.allows(
        ComparisonResult(passed: false, diffPercent: 0.000001),
      ),
      isFalse,
    );
  });
}
