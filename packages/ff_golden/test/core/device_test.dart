import 'package:ff_golden/ff_golden.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

void main() {
  test('iPhone 11 keeps logical geometry and physical density separate', () {
    expect(GoldenDevice.iPhone11.logicalSize, const Size(414, 896));
    expect(GoldenDevice.iPhone11.physicalSize, const Size(828, 1792));
    expect(GoldenDevice.iPhone11.devicePixelRatio, 2);
    expect(GoldenDevice.iPhone11.platform, TargetPlatform.iOS);
    expect(
      GoldenDevice.iPhone11.safeArea,
      const EdgeInsets.only(top: 44, bottom: 34),
    );
  });

  test('landscape swaps geometry and rotates safe-area edges', () {
    final landscape = GoldenDevice.iPhone11.landscape();

    expect(landscape.logicalSize, const Size(896, 414));
    expect(
      landscape.safeArea,
      const EdgeInsets.only(left: 44, right: 34),
    );
  });
}
