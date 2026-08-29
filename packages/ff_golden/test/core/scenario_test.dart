import 'package:ff_golden/ff_golden.dart';
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
}

enum _ProbeState { loaded }
