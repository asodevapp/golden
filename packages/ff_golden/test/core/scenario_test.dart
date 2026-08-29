import 'package:ff_golden/ff_golden.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typed scenarios preserve their compile-time state', () {
    const scenario = GoldenScenario<_ProbeState>(
      name: 'probe/loaded',
      state: _ProbeState.loaded,
    );

    expect(scenario.name, 'probe/loaded');
    expect(scenario.state, _ProbeState.loaded);
  });

  final events = <String>[];
  final fixture = _ProbeFixture();
  testFfGoldenScenarios<_ProbeFixture>(
    'typed scenario fixtures',
    scenarios: <GoldenScenario<_ProbeFixture>>[
      GoldenScenario<_ProbeFixture>(
        name: 'probe/fixture',
        state: fixture,
        prepare: (context, state) {
          events.add('prepare');
          state.installed = true;
        },
        interact: (context, state) {
          events.add('interact');
          expect(state.installed, isTrue);
        },
        dispose: (context, state) {
          events.add('dispose');
          state.installed = false;
        },
      ),
    ],
    build: (variant, state) {
      events.add('build');
      expect(state.installed, isTrue);
      return const SizedBox();
    },
    pump: (tester) => tester.pump(),
    configuration: const GoldenRunConfiguration(
      autoCapture: false,
      detectStaleGoldens: false,
    ),
    before: () => events.add('before'),
    after: () => events.add('after'),
  );

  test('typed scenario lifecycle is isolated around build and interaction', () {
    expect(
      events,
      <String>[
        'before',
        'prepare',
        'build',
        'interact',
        'dispose',
        'after',
      ],
    );
    expect(fixture.installed, isFalse);
  });
}

enum _ProbeState { loaded }

class _ProbeFixture {
  bool installed = false;
}
