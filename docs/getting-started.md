---
title: Get started
description: Install ff_golden, load application fonts, create deterministic golden coverage, and build a searchable report.
---

# Get started

This guide creates a first coverage-based golden suite and an optional local
review report. Keep `ff_golden` and `ff_golden_presenter` in
`dev_dependencies`; they are test and publication infrastructure, not runtime
application dependencies.

## 1. Install the packages

=== "Runner only"

    ```shell
    flutter pub add --dev 'ff_golden:^1.2.2'
    ```

=== "Runner and presenter"

    ```shell
    flutter pub add --dev 'ff_golden:^1.2.2'
    flutter pub add --dev ff_golden_presenter
    ```

Commit both `pubspec.yaml` and `pubspec.lock` so local development and CI use
the same toolchain.

Package pages: [`ff_golden`](https://pub.dev/packages/ff_golden) and
[`ff_golden_presenter`](https://pub.dev/packages/ff_golden_presenter).

## 2. Load the application fonts

Create `test/flutter_test_config.dart`:

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

`loadFfGoldenFonts()` loads fonts declared in the application pubspec and fails
with a focused diagnostic when an asset cannot be loaded. A rendered fallback
font can change wrapping, glyph metrics, and every affected baseline.

## 3. Write the first scenario

Create a file below `test/`, for example
`test/screens/counter/counter_golden_test.dart`:

```dart
import 'package:ff_golden/ff_golden.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reporter = JsonGoldenReporter(
    'build/ff_golden',
    shardName: 'counter-goldens',
  );

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
    build: (_) => const CounterCard(),
    interact: (context) => context.tester.tap(find.byIcon(Icons.add)),
    configuration: GoldenRunConfiguration(reporter: reporter),
  );
}
```

Share one `JsonGoldenReporter` instance across the scenarios in a test file.
Give every test file a stable, project-unique `shardName`. The runner completes
the reporter after that file's suite and writes one manifest shard.

The repository contains a complete
[counter example](https://github.com/asodevapp/golden/blob/master/packages/ff_golden/example/example.dart).

## 4. Generate and verify the baselines

Generate the initial contract:

```shell
flutter pub run ff_golden update --tags ff_golden
```

Review every added PNG, then run without update mode:

```shell
flutter pub run ff_golden test --tags ff_golden
```

Every generated test carries both the `golden` and `ff_golden` tags. The first
tag keeps existing project-level commands useful; the second isolates new
FF Golden suites.

The runner normally discovers `test/**/*_golden_test.dart`, sorts the paths,
and applies `--no-pub` plus eight-way concurrency. It forwards explicit test
paths and Flutter filters such as `--plain-name`. See the
[runner CLI reference](runner-cli.md) for overrides and dry-run mode.

## 5. Build a local report

```shell
dart run ff_golden_presenter build \
  --input test/screens \
  --manifest build/ff_golden \
  --output-directory build/golden-report \
  --profile none \
  --clean
```

Open `build/golden-report/index.html`. Start with `--profile none` so report
generation cannot be confused with a visual baseline change. Publication
profiles only optimize staged copies and never edit the source goldens.

## 6. Use the real application wrapper

`FfGoldenTestApp` is convenient for components and supplies Material,
Cupertino, and Widgets localizations. For production screens, provide the same
root concerns as the application:

```dart
wrapper: (child, variant) => MyApp(
  locale: variant.locale,
  theme: variant.theme.data,
  child: child,
),
```

Use the variant to select deterministic DI overrides and state fixtures rather
than reading mutable global state.

## Next steps

- Learn why [logical size, DPR, and capture scale](concepts/device-fidelity.md)
  are independent.
- Choose a [coverage sampling strategy](concepts/coverage.md).
- Model real workflows with [stateful and multi-shot tests](guides/stateful-scenarios.md).
- Control repositories and loading states with
  [typed fixtures and bounded async waits](guides/fixtures-and-async.md).
- Add the suite to [CI and publication](guides/ci.md).
