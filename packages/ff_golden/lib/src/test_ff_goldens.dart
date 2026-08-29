import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

import 'capture.dart';
import 'comparator.dart';
import 'error_capture.dart';
import 'coverage.dart';
import 'naming.dart';
import 'report.dart';
import 'stale.dart';
import 'test_driver.dart';
import 'test_view.dart';
import 'variant.dart';

typedef GoldenWidgetBuilder = Widget Function(GoldenVariant variant);
typedef GoldenAppBuilder = Widget Function(Widget child, GoldenVariant variant);
typedef GoldenInteraction = FutureOr<void> Function(GoldenTestContext context);
typedef GoldenLifecycle = FutureOr<void> Function(GoldenTestContext context);
typedef GoldenPump = Future<void> Function(WidgetTester tester);
typedef GoldenScenarioWidgetBuilder<T> = Widget Function(
  GoldenVariant variant,
  T state,
);
typedef GoldenScenarioInteraction<T> = FutureOr<void> Function(
  GoldenTestContext context,
  T state,
);
typedef GoldenScenarioLifecycle<T> = FutureOr<void> Function(
  GoldenTestContext context,
  T state,
);

@immutable
class GoldenScenario<T> {
  const GoldenScenario({
    required this.name,
    required this.state,
    this.interact,
    this.prepare,
    this.dispose,
  });

  /// Stable path segment and human-readable state name.
  final String name;
  final T state;
  final GoldenScenarioInteraction<T>? interact;

  /// Installs data fixtures or dependency overrides before [state] is built.
  final GoldenScenarioLifecycle<T>? prepare;

  /// Releases resources installed by [prepare] after capture or failure.
  final GoldenScenarioLifecycle<T>? dispose;
}

@immutable
class GoldenRunConfiguration {
  const GoldenRunConfiguration({
    this.pathStrategy = const GoldenPathStrategy(),
    this.testName = '',
    this.captureScale,
    this.tolerance = GoldenTolerance.strict,
    this.failOnOverflow = true,
    this.freezeAnimations = true,
    this.renderShadows = false,
    this.detectStaleGoldens = true,
    this.autoCapture = true,
    this.reporter,
  }) : assert(
          captureScale == null || captureScale > 0,
          'captureScale must be greater than zero.',
        );

  final GoldenPathStrategy pathStrategy;
  final String testName;

  /// PNG raster scale. `null` preserves the device pixel ratio.
  final double? captureScale;
  final GoldenTolerance tolerance;
  final bool failOnOverflow;
  final bool freezeAnimations;

  /// Renders real Material shadows instead of Flutter's deterministic boxes.
  ///
  /// Real shadows can differ slightly between renderers. Keep this disabled
  /// for strict component tests or configure an explicit [tolerance].
  final bool renderShadows;
  final bool detectStaleGoldens;
  final bool autoCapture;
  final GoldenReporter? reporter;
}

class GoldenTestContext {
  GoldenTestContext._({
    required this.tester,
    required this.variant,
    required this.scenario,
    required this.configuration,
    required this.diagnostics,
    required this.captureFinder,
  });

  final WidgetTester tester;
  final GoldenVariant variant;
  final String scenario;
  final GoldenRunConfiguration configuration;
  final GoldenDiagnostics diagnostics;
  final Finder captureFinder;
  final List<GoldenCapture> _captures = [];

  List<GoldenCapture> get captures => List.unmodifiable(_captures);

  GoldenTestDriver get driver => GoldenTestDriver(
        tester: tester,
        context: 'scenario $scenario, variant ${variant.label}',
      );

  String path({String? testName}) => configuration.pathStrategy.build(
        scenario: scenario,
        variant: variant,
        testName: testName ?? configuration.testName,
      );

  Future<void> capture({String? testName}) async {
    final resolvedName = testName ?? configuration.testName;
    final goldenPath = path(testName: resolvedName);
    _GoldenStaleTracker.expect(goldenPath);
    _captures.add(
      GoldenCapture(
        path: goldenPath,
        name: resolvedName.isEmpty ? null : resolvedName,
      ),
    );
    await expectFfGolden(
      captureFinder,
      goldenPath,
      captureScale:
          configuration.captureScale ?? variant.device.devicePixelRatio,
      tolerance: configuration.tolerance,
    );
  }

  Future<void> pumpFrames(
    int count, {
    Duration step = const Duration(milliseconds: 16),
  }) =>
      driver.pumpFrames(count, step: step);

  Future<void> elapse(Duration duration) => driver.elapse(duration);

  Future<void> pumpUntil(
    GoldenWaitCondition condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration step = const Duration(milliseconds: 16),
    String description = 'condition',
  }) =>
      driver.pumpUntil(
        condition,
        timeout: timeout,
        step: step,
        description: description,
      );

  /// Pumps in bounded virtual-time steps until [finder] appears.
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
    Duration step = const Duration(milliseconds: 16),
  }) =>
      driver.pumpUntilFound(finder, timeout: timeout, step: step);

  Future<void> pumpUntilGone(
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
    Duration step = const Duration(milliseconds: 16),
  }) =>
      driver.pumpUntilGone(finder, timeout: timeout, step: step);
}

@isTestGroup
void testFfGoldens(
  String description, {
  required String scenario,
  required GoldenWidgetBuilder build,
  GoldenCoverage? coverage,
  GoldenAppBuilder? wrapper,
  GoldenInteraction? interact,
  GoldenLifecycle? prepare,
  GoldenLifecycle? dispose,
  GoldenPump pump = _pumpAndSettle,
  GoldenRunConfiguration configuration = const GoldenRunConfiguration(),
  FutureOr<void> Function()? before,
  FutureOr<void> Function()? after,
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  Iterable<String> tags = const [],
}) {
  final plan = (coverage ?? GoldenCoverage()).plan();
  final plannedPaths = plan.variants
      .map(
        (variant) => configuration.pathStrategy.build(
          scenario: scenario,
          variant: variant,
          testName: configuration.testName,
        ),
      )
      .toList(growable: false);
  configuration.pathStrategy.validate(
    scenario: scenario,
    variants: plan.variants,
    testName: configuration.testName,
  );

  if (configuration.detectStaleGoldens) {
    _GoldenStaleTracker.register(
      scope:
          '${configuration.pathStrategy.folder}/${ffGoldenSafeName(scenario)}',
      expectedPaths: plannedPaths,
    );
  }
  final reporter = configuration.reporter;
  if (reporter != null) {
    reporter.registerPlan(
      GoldenSuitePlan(
        description: description,
        scenario: scenario,
        plan: plan,
        goldenPaths: plannedPaths,
      ),
    );
    _GoldenReporterTracker.register(reporter);
  }

  for (final goldenVariant in plan.variants) {
    testWidgets(
      '$description (${goldenVariant.label})',
      (tester) async {
        final stopwatch = Stopwatch()..start();
        final view = GoldenTestViewSession.apply(tester, goldenVariant);
        final diagnostics = GoldenDiagnostics();
        final boundaryKey = UniqueKey();
        final context = GoldenTestContext._(
          tester: tester,
          variant: goldenVariant,
          scenario: scenario,
          configuration: configuration,
          diagnostics: diagnostics,
          captureFinder: find.byKey(boundaryKey),
        );
        final errorCapture = GoldenFlutterErrorCapture(
          diagnostics: diagnostics,
        );
        final previousDebugDisableShadows = debugDisableShadows;
        debugDisableShadows = !configuration.renderShadows;
        Object? failure;
        StackTrace? failureStack;
        String? failurePhase;
        var phase = 'setup';
        var fixtureStarted = prepare == null;

        try {
          await before?.call();
          phase = 'fixture setup';
          if (prepare != null) {
            fixtureStarted = true;
            await prepare(context);
          }
          phase = 'build';
          await errorCapture.run(() async {
            final child = build(goldenVariant);
            final app = wrapper?.call(child, goldenVariant) ??
                FfGoldenTestApp(variant: goldenVariant, child: child);
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundaryKey,
                child: TickerMode(
                  enabled: !configuration.freezeAnimations,
                  child: app,
                ),
              ),
            );
            await pump(tester);
            phase = 'interaction';
            await interact?.call(context);
            if (interact != null) await pump(tester);
            phase = 'capture';
            if (configuration.autoCapture) await context.capture();
          }, failOnOverflow: configuration.failOnOverflow);
        } catch (error, stackTrace) {
          failure = error;
          failureStack = stackTrace;
          failurePhase = phase;
        } finally {
          try {
            phase = 'fixture teardown';
            if (fixtureStarted) await dispose?.call(context);
          } catch (error, stackTrace) {
            failure ??= error;
            failureStack ??= stackTrace;
            failurePhase ??= phase;
          }
          try {
            phase = 'teardown';
            await after?.call();
          } catch (error, stackTrace) {
            failure ??= error;
            failureStack ??= stackTrace;
            failurePhase ??= phase;
          }
          try {
            view.reset();
          } finally {
            debugDisableShadows = previousDebugDisableShadows;
          }
          stopwatch.stop();
          reporter?.record(
            GoldenCaseResult(
              description: description,
              scenario: scenario,
              variant: goldenVariant,
              status: failure == null
                  ? GoldenResultStatus.passed
                  : GoldenResultStatus.failed,
              duration: stopwatch.elapsed,
              captures: context.captures,
              overflowCount: diagnostics.overflows.length,
              failurePhase: failurePhase,
              error: failure?.toString(),
              stackTrace: failureStack?.toString(),
            ),
          );
        }
        if (failure != null) {
          Error.throwWithStackTrace(failure, failureStack!);
        }
      },
      skip: skip,
      timeout: timeout,
      semanticsEnabled: semanticsEnabled,
      variant: variant,
      tags: {'golden', 'ff_golden', ...tags},
    );
  }
}

/// Registers a typed set of states against one shared golden coverage plan.
///
/// This keeps loading, loaded, empty, and error cases compile-time checked
/// without duplicating the device and comparison configuration.
@isTestGroup
void testFfGoldenScenarios<T>(
  String description, {
  required Iterable<GoldenScenario<T>> scenarios,
  required GoldenScenarioWidgetBuilder<T> build,
  GoldenCoverage? coverage,
  GoldenAppBuilder? wrapper,
  GoldenPump pump = _pumpAndSettle,
  GoldenRunConfiguration configuration = const GoldenRunConfiguration(),
  FutureOr<void> Function()? before,
  FutureOr<void> Function()? after,
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  Iterable<String> tags = const [],
}) {
  final cases = scenarios.toList(growable: false);
  if (cases.isEmpty) {
    throw ArgumentError.value(
      cases,
      'scenarios',
      'must contain at least one typed scenario',
    );
  }
  final names = <String>{};
  for (final scenarioCase in cases) {
    final safeName = ffGoldenSafeName(scenarioCase.name).toLowerCase();
    if (!names.add(safeName)) {
      throw ArgumentError(
        'Duplicate golden scenario path: ${scenarioCase.name}',
      );
    }

    testFfGoldens(
      '$description — ${scenarioCase.name}',
      scenario: scenarioCase.name,
      build: (goldenVariant) => build(goldenVariant, scenarioCase.state),
      coverage: coverage,
      wrapper: wrapper,
      interact: scenarioCase.interact == null
          ? null
          : (context) => scenarioCase.interact!(context, scenarioCase.state),
      prepare: scenarioCase.prepare == null
          ? null
          : (context) => scenarioCase.prepare!(context, scenarioCase.state),
      dispose: scenarioCase.dispose == null
          ? null
          : (context) => scenarioCase.dispose!(context, scenarioCase.state),
      pump: pump,
      configuration: configuration,
      before: before,
      after: after,
      skip: skip,
      timeout: timeout,
      semanticsEnabled: semanticsEnabled,
      variant: variant,
      tags: tags,
    );
  }
}

class FfGoldenTestApp extends StatelessWidget {
  const FfGoldenTestApp({
    super.key,
    required this.variant,
    required this.child,
  });

  final GoldenVariant variant;
  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: variant.theme.data.copyWith(platform: variant.platform),
        locale: variant.locale,
        supportedLocales: [variant.locale],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        home: Directionality(
          textDirection: variant.textDirection,
          child: Scaffold(body: Center(child: child)),
        ),
      );
}

Future<void> _pumpAndSettle(WidgetTester tester) => tester.pumpAndSettle();

class _GoldenStaleTracker {
  static final Map<String, Set<String>> _expectedByScope = {};
  static var _tearDownRegistered = false;

  static void register({
    required String scope,
    required Iterable<String> expectedPaths,
  }) {
    _expectedByScope.putIfAbsent(scope, () => {}).addAll(expectedPaths);
    if (_tearDownRegistered) return;
    _tearDownRegistered = true;
    tearDownAll(_verify);
  }

  static void expect(String path) {
    for (final entry in _expectedByScope.entries) {
      if (path.startsWith('${entry.key}/')) {
        entry.value.add(path);
        return;
      }
    }
  }

  static void _verify() {
    final comparator = goldenFileComparator;
    if (comparator is! LocalFileComparator) return;
    final stale = <String>[];
    for (final entry in _expectedByScope.entries) {
      stale.addAll(
        findStaleGoldenFiles(
          baseDirectory: comparator.basedir,
          expectedPaths: entry.value,
          scope: entry.key,
        ),
      );
    }
    _expectedByScope.clear();
    _tearDownRegistered = false;
    if (stale.isNotEmpty) throw StaleGoldenFilesFound(stale);
  }
}

class _GoldenReporterTracker {
  static final Set<GoldenReporter> _reporters = {};
  static var _tearDownRegistered = false;

  static void register(GoldenReporter reporter) {
    if (reporter is JsonGoldenReporter) {
      for (final existing in _reporters.whereType<JsonGoldenReporter>()) {
        if (!identical(existing, reporter) &&
            existing.outputPath == reporter.outputPath) {
          throw StateError(
            'Multiple JsonGoldenReporter instances target '
            '${reporter.outputPath}. Share one reporter per test file or use '
            'a different shardName.',
          );
        }
      }
    }
    _reporters.add(reporter);
    if (_tearDownRegistered) return;
    _tearDownRegistered = true;
    tearDownAll(_complete);
  }

  static Future<void> _complete() async {
    for (final reporter in _reporters) {
      await reporter.complete();
    }
    _reporters.clear();
    _tearDownRegistered = false;
  }
}
