import 'dart:async';

import 'package:ff_golden/ff_golden.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pumpUntil advances bounded virtual time', (tester) async {
    var ready = false;
    Timer(const Duration(milliseconds: 48), () => ready = true);
    final driver = GoldenTestDriver(
      tester: tester,
      context: 'scenario async, variant phone',
    );

    await driver.pumpUntil(
      () => ready,
      timeout: const Duration(milliseconds: 64),
      description: 'repository response',
    );

    expect(ready, isTrue);
  });

  testWidgets('pumpUntil reports the condition and test context on timeout',
      (tester) async {
    final driver = GoldenTestDriver(
      tester: tester,
      context: 'scenario async, variant phone',
    );

    await expectLater(
      () => driver.pumpUntil(
        () => false,
        timeout: const Duration(milliseconds: 32),
        description: 'profile bloc to load',
      ),
      throwsA(
        isA<TestFailure>()
            .having(
              (failure) => failure.message,
              'message',
              contains('profile bloc to load'),
            )
            .having(
              (failure) => failure.message,
              'message',
              contains('scenario async, variant phone'),
            ),
      ),
    );
  });

  testWidgets('finder waits cover appearance and removal', (tester) async {
    final visible = ValueNotifier<bool>(false);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (_, value, __) => value
            ? const SizedBox(key: Key('result'))
            : const SizedBox.shrink(),
      ),
    );
    final driver = GoldenTestDriver(tester: tester);
    final result = find.byKey(const Key('result'));

    Timer(const Duration(milliseconds: 32), () => visible.value = true);
    await driver.pumpUntilFound(result);
    expect(result, findsOneWidget);

    Timer(const Duration(milliseconds: 32), () => visible.value = false);
    await driver.pumpUntilGone(result);
    expect(result, findsNothing);
  });

  testWidgets('pumpFrames and elapse use virtual time', (tester) async {
    var elapsed = false;
    Timer(const Duration(milliseconds: 50), () => elapsed = true);
    final driver = GoldenTestDriver(tester: tester);

    await driver.pumpFrames(
      3,
      step: const Duration(milliseconds: 10),
    );
    expect(elapsed, isFalse);

    await driver.elapse(const Duration(milliseconds: 20));
    expect(elapsed, isTrue);
  });
}
