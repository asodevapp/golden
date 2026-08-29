import 'package:ff_golden/ff_golden.dart';
import 'package:flutter/material.dart';

void main() {
  testFfGoldens(
    'new runner applies the complete variant',
    scenario: 'variant-surface',
    matrix: GoldenMatrix(
      devices: const [
        GoldenDevice(
          name: 'probe',
          logicalSize: Size(320, 240),
          devicePixelRatio: 2,
          platform: TargetPlatform.iOS,
          safeArea: EdgeInsets.only(top: 12),
        ),
      ],
      locales: const [Locale('ar')],
      textScales: const [1.5],
      highContrasts: const [true],
    ),
    build: (variant) => Builder(
      builder: (context) {
        final media = MediaQuery.of(context);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('size: ${media.size.width}x${media.size.height}'),
            Text('dpr: ${media.devicePixelRatio}'),
            Text('text: ${media.textScaler.scale(10)}'),
            Text('safe-top: ${media.padding.top}'),
            Text('direction: ${Directionality.of(context).name}'),
            Text('contrast: ${media.highContrast}'),
          ],
        );
      },
    ),
  );
}
