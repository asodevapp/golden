import 'package:flutter_test/flutter_test.dart';

typedef GoldenWaitCondition = bool Function();

/// Advances Flutter's virtual test clock through bounded, diagnostic waits.
///
/// Golden tests should wait for an observable state instead of pumping an
/// arbitrary number of frames. This driver is shared by the coverage and
/// legacy APIs so migrated suites can adopt deterministic waits without
/// changing their baseline naming or capture behavior.
class GoldenTestDriver {
  GoldenTestDriver({
    required this.tester,
    this.context,
  });

  final WidgetTester tester;

  /// Scenario and variant information appended to timeout diagnostics.
  final String? context;

  /// Pumps [count] fixed virtual-time frames.
  Future<void> pumpFrames(
    int count, {
    Duration step = const Duration(milliseconds: 16),
  }) async {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'must not be negative');
    }
    _validateStep(step);
    for (var index = 0; index < count; index++) {
      await tester.pump(step);
    }
  }

  /// Advances Flutter's virtual test clock by exactly [duration].
  Future<void> elapse(Duration duration) async {
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'must not be negative');
    }
    await tester.pump(duration);
  }

  /// Pumps bounded virtual-time steps until [condition] becomes true.
  Future<void> pumpUntil(
    GoldenWaitCondition condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration step = const Duration(milliseconds: 16),
    String description = 'condition',
  }) async {
    if (timeout.isNegative) {
      throw ArgumentError.value(timeout, 'timeout', 'must not be negative');
    }
    _validateStep(step);

    var elapsed = Duration.zero;
    while (!condition() && elapsed < timeout) {
      final remaining = timeout - elapsed;
      final interval = remaining < step ? remaining : step;
      await tester.pump(interval);
      elapsed += interval;
    }

    if (!condition()) {
      final contextSuffix = context == null ? '' : ' ($context)';
      throw TestFailure(
        'ff_golden timed out waiting for $description after $timeout'
        '$contextSuffix.',
      );
    }
  }

  /// Pumps bounded virtual time until [finder] matches at least one widget.
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
    Duration step = const Duration(milliseconds: 16),
  }) =>
      pumpUntil(
        () => finder.evaluate().isNotEmpty,
        timeout: timeout,
        step: step,
        description: '$finder to appear',
      );

  /// Pumps bounded virtual time until [finder] no longer matches a widget.
  Future<void> pumpUntilGone(
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
    Duration step = const Duration(milliseconds: 16),
  }) =>
      pumpUntil(
        () => finder.evaluate().isEmpty,
        timeout: timeout,
        step: step,
        description: '$finder to disappear',
      );

  static void _validateStep(Duration step) {
    if (step <= Duration.zero) {
      throw ArgumentError.value(step, 'step', 'must be greater than zero');
    }
  }
}
