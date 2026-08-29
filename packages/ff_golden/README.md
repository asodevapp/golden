# ff_golden

Deterministic visual regression testing for the Flutter Files toolchain.

`ff_golden` runs one scenario against controlled coverage of devices, themes,
locales, text scales, directions, platforms, brightness modes, and accessibility
settings. It keeps every combination as an isolated Flutter test and emits
stable machine-readable run metadata alongside the golden artifacts.

## Why ff_golden

- Accurate device geometry: logical size, physical size, device pixel ratio,
  safe areas, target platform, brightness, and high contrast are applied to the
  Flutter test view.
- Declarative coverage with constraints and deterministic `full`, `smoke`,
  `pairwise`, or risk-based `priority` sampling.
- Stateful scenarios: interact with the widget, wait with bounded virtual time,
  and capture one or several named moments.
- Strict diagnostics by default: pixel-perfect comparison, `RenderFlex`
  overflow failures, filename collision detection, and stale baseline checks.
- Explicit escape hatches: a per-test tolerance, independent raster capture
  scale, custom app wrapper, custom pump, real shadows, and arbitrary hooks.
- JSON output designed for CI and richer presenter integration.
- A compatibility layer for the previous `golden` package API.

## Install

Add the package as a development dependency:

```shell
flutter pub add --dev 'ff_golden:^1.1.0'
```

Then import the primary library:

```dart
import 'package:ff_golden/ff_golden.dart';
```

## Load application fonts

Real application fonts must be loaded before the suite. Add
`test/flutter_test_config.dart`:

```dart
import 'dart:async';

import 'package:ff_golden/ff_golden.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadFfGoldenFonts();
  await testMain();
}
```

## Quick start

```dart
import 'package:ff_golden/ff_golden.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reporter = JsonGoldenReporter(
    'build/ff_golden',
    shardName: 'login-goldens',
  );

  testFfGoldens(
    'login with an invalid email',
    scenario: 'login/invalid-email',
    coverage: GoldenCoverage(
      devices: const [
        GoldenDevice.iPhone11,
        GoldenDevice.iPad,
      ],
      locales: const [Locale('en'), Locale('ar')],
      themes: [GoldenTheme.light, GoldenTheme.dark],
      textScales: const [1, 1.5, 2],
      highContrasts: const [false, true],
      sampling: GoldenSampling.pairwise,
      maxCombinations: 24,
      rules: [
        GoldenCoverageRule.excludeWhen(
          'dark theme owns brightness',
          (variant) =>
              variant.theme.name == 'dark' &&
              variant.brightness == Brightness.light,
        ),
      ],
    ),
    build: (variant) => const LoginPage(),
    interact: (context) async {
      await context.tester.enterText(
        find.byKey(const Key('email')),
        'not-an-email',
      );
      await context.tester.tap(find.text('Continue'));
    },
    configuration: GoldenRunConfiguration(reporter: reporter),
  );
}
```

Generate and verify baselines with the standard Flutter commands:

```shell
flutter test --update-goldens
flutter test
```

Always review regenerated PNGs. `--update-goldens` is an approval step, not a
way to make a failing test green automatically.

## Device fidelity and capture resolution

These values solve different problems and are intentionally independent:

- `GoldenDevice.logicalSize` controls Flutter layout and `MediaQuery.size`.
- `devicePixelRatio` converts that geometry to the test view's physical size
  and is exposed through `MediaQuery.devicePixelRatio`.
- `GoldenRunConfiguration.captureScale` changes only the PNG raster density.
  Its default `null` preserves the device DPR, so a 3× device produces a 3×
  baseline.

Keeping DPR at `1` to speed up tests changes application behavior and can hide
density-specific regressions. Prefer `GoldenSampling.smoke`, `pairwise`, or
`priority` to reduce the number of tests; set `captureScale: 1` only when raster
fidelity is not part of the contract.

## Coverage strategies

`GoldenCoverage.plan()` expands the Cartesian product, applies every rule, and
then samples the feasible variants:

- `full` keeps all feasible combinations.
- `smoke` greedily covers every individual axis value.
- `pairwise` covers every feasible pair of axis values.
- `priority` sorts variants by a risk function and applies
  `maxCombinations` as a hard cap.

For the first three strategies, an insufficient budget throws
`GoldenCoverageBudgetExceeded`; coverage is never silently weakened. Use
`GoldenCoverageRule.require` or `excludeWhen` to model impossible combinations.

## Stateful and multi-shot scenarios

Automatic capture happens after `interact`. Disable it when the workflow needs
several checkpoints:

```dart
testFfGoldens(
  'checkout flow',
  scenario: 'checkout',
  build: (_) => const CheckoutPage(),
  configuration: const GoldenRunConfiguration(autoCapture: false),
  interact: (context) async {
    await context.capture(testName: 'empty');
    await context.tester.tap(find.text('Add item'));
    await context.tester.pumpAndSettle();
    await context.capture(testName: 'with-item');
  },
);
```

`context.pumpUntilFound(...)` advances bounded virtual time and fails with the
active variant in its diagnostic instead of waiting indefinitely.

Use `context.pumpUntil(...)` for application state, `pumpUntilGone(...)` for a
completed loading surface, `pumpFrames(...)` for an intentional fixed-frame
contract, and `elapse(...)` for a known timer or animation checkpoint. The same
helpers are available from legacy `GoldenTesterBase` subclasses.

For compile-time-checked state tables, reuse one coverage definition with
`testFfGoldenScenarios<T>`:

```dart
testFfGoldenScenarios<AsyncState>(
  'profile states',
  scenarios: const [
    GoldenScenario(name: 'profile/loading', state: AsyncState.loading),
    GoldenScenario(name: 'profile/loaded', state: AsyncState.loaded),
    GoldenScenario(name: 'profile/error', state: AsyncState.error),
  ],
  build: (variant, state) => ProfilePage(initialState: state),
  coverage: profileCoverage,
);
```

## Comparison policy

The default is pixel-perfect:

```dart
const GoldenRunConfiguration(
  tolerance: GoldenTolerance.strict,
  failOnOverflow: true,
  detectStaleGoldens: true,
  freezeAnimations: true,
)
```

When renderer noise is understood and accepted, configure the smallest local
tolerance. `maxDiffRate` is a fraction, so `0.001` means `0.1%`:

```dart
const GoldenRunConfiguration(
  tolerance: GoldenTolerance(
    maxDiffRate: 0.001,
    maxDifferentPixels: 20,
  ),
  renderShadows: true,
)
```

## App wrappers and localization

The default `FfGoldenTestApp` provides Material, Cupertino, and Widgets
localizations. Production apps should usually provide their real root widget:

```dart
wrapper: (child, variant) => MyApp(
  locale: variant.locale,
  theme: variant.theme.data,
  child: child,
),
```

The variant is also available to `build`, so DI overrides and state fixtures can
be selected without global mutable configuration.

Typed scenarios can install per-case fixtures before the widget is built and
release them after capture or failure:

```dart
GoldenScenario<ProfileFixture>(
  name: 'profile/loaded',
  state: fixture,
  prepare: (_, fixture) => fixture.install(),
  dispose: (_, fixture) => fixture.uninstall(),
)
```

Keep fakes application-local and prefer a controlled `Completer` over nested
fake-async zones or real delays. See the
[fixtures and async guide](https://asodevapp.github.io/golden/guides/fixtures-and-async/).

## Reports and ff_golden_presenter

Share one `JsonGoldenReporter` instance across every scenario in a test file.
Give each file a stable, project-unique `shardName`. At the end of the suite it
writes one schema-v2 `ff_golden.run` shard into the output directory with:

- planned, excluded, and selected combination counts;
- complete variant metadata;
- pass/fail status, duration, overflow count, and failure phase;
- captured golden paths and the standard Flutter diff artifact names.

Separate test-file isolates never write the same file. For example,
`shardName: 'login-goldens'` produces
`build/ff_golden/login-goldens.ff-golden-run.json`; presenter merges every
shard in that directory. Start CI from an empty build directory so shards from
deleted test files cannot survive from an earlier job.

`ff_golden` owns execution and correctness. The companion presenter owns human
review, browsing, filtering, optimization, and publication. Add it to an
application as a project-local development dependency:

```yaml
dev_dependencies:
  ff_golden_presenter: ^1.0.0
```

Then build a self-contained report with:

```shell
dart run ff_golden_presenter build \
  --input test/screens \
  --manifest build/ff_golden
```

Presenter merges schema-v1/v2 shards and uses them as the authoritative source
for multi-shot capture names, dotted device names, every coverage axis, run
status, duration, and failure diagnostics. Images without a matching manifest
remain available through filename parsing.

## Migrating from golden

See [MIGRATION.md](MIGRATION.md). Existing `GoldenTester` and
`testDeviceGoldens` suites remain available, but new suites should use
`testFfGoldens`.

## Test tags

All generated tests have both `golden` and `ff_golden` tags:

```shell
flutter test --tags ff_golden
```

## Project support

FF Golden is part of the Flutter Files infrastructure and is developed with
support from [ASO.dev](https://aso.dev/).
