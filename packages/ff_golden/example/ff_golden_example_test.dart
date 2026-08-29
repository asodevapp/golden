import 'package:ff_golden/ff_golden.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testFfGoldens(
    'counter after one tap',
    scenario: 'counter/incremented',
    coverage: GoldenCoverage(
      devices: const [GoldenDevice.iPhone11, GoldenDevice.iPad],
      locales: const [Locale('en'), Locale('ar')],
      themes: [GoldenTheme.light, GoldenTheme.dark],
      textScales: const [1, 1.5],
      sampling: GoldenSampling.pairwise,
      maxCombinations: 12,
    ),
    build: (_) => const _CounterCard(),
    interact: (context) => context.tester.tap(find.byIcon(Icons.add)),
  );
}

class _CounterCard extends StatefulWidget {
  const _CounterCard();

  @override
  State<_CounterCard> createState() => _CounterCardState();
}

class _CounterCardState extends State<_CounterCard> {
  var count = 0;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Count: $count'),
              IconButton(
                onPressed: () => setState(() => count++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      );
}
