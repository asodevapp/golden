import 'package:ff_golden/ff_golden.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reporter = JsonGoldenReporter(
    'build/ff_golden',
    shardName: 'presenter-integration',
  );

  testFfGoldens(
    'presenter consumes every runner axis and named capture',
    scenario: 'presenter/multi-shot',
    coverage: GoldenCoverage(
      devices: const [GoldenDevice.iPadPro129],
      locales: const [Locale('ar')],
      themes: [GoldenTheme.dark],
      textScales: const [1.5],
      directions: const [GoldenDirection.rtl],
      platforms: const [TargetPlatform.macOS],
      brightnesses: const [Brightness.dark],
      highContrasts: const [true],
    ),
    build: (_) => const _PresenterProbe(),
    configuration: GoldenRunConfiguration(
      autoCapture: false,
      reporter: reporter,
    ),
    interact: (context) async {
      await context.capture(testName: 'empty');
      await context.tester.tap(find.byKey(const Key('toggle')));
      await context.tester.pump();
      await context.capture(testName: 'filled');
    },
  );
}

class _PresenterProbe extends StatefulWidget {
  const _PresenterProbe();

  @override
  State<_PresenterProbe> createState() => _PresenterProbeState();
}

class _PresenterProbeState extends State<_PresenterProbe> {
  var _filled = false;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 280,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FlutterLogo(size: 72),
                const SizedBox(height: 16),
                Text(_filled ? 'Filled state' : 'Empty state'),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('toggle'),
                  onPressed: () => setState(() => _filled = !_filled),
                  child: const Text('Toggle'),
                ),
              ],
            ),
          ),
        ),
      );
}
