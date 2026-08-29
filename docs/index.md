---
title: Flutter visual regression testing with FF Golden
description: Deterministic Flutter golden tests across devices, themes, locales, accessibility settings, and stateful scenarios, with searchable reports for review and CI.
---

<div class="ff-hero" markdown>

# Golden tests that explain what changed

Run deterministic Flutter scenarios across real device geometry, themes,
locales, text scales, directions, platforms, brightness, and accessibility
settings. Review every capture in a portable, searchable report.

<div class="ff-actions" markdown>
[Get started](getting-started.md){ .md-button .md-button--primary }
[Open the live report](https://asodevapp.github.io/golden/demo/){ .md-button }
[View on GitHub](https://github.com/asodevapp/golden){ .md-button }
</div>

</div>

FF Golden is the visual-testing stack for Flutter Files. It combines a strict
Flutter runner with a project-local publication tool without moving correctness
decisions into the report layer.

<div class="ff-grid" markdown>

<div class="ff-card" markdown>
### Device fidelity

Apply logical size, physical size, DPR, safe areas, target platform, brightness,
and high contrast to the Flutter test view.
</div>

<div class="ff-card" markdown>
### Controlled coverage

Cover devices and environment axes with full, smoke, pairwise, or risk-priority
sampling. Insufficient coverage fails instead of silently dropping cases.
</div>

<div class="ff-card" markdown>
### Stateful scenarios

Enter text, tap controls, wait with bounded virtual time, and capture one or
several named moments from the same workflow.
</div>

<div class="ff-card" markdown>
### Review-ready output

Merge sharded run metadata with images into a searchable static report that can
be opened locally, attached to CI, or published to Pages.
</div>

</div>

## Five-minute example

Add the runner as a development dependency:

```shell
flutter pub add --dev 'ff_golden:^1.0.0'
```

Create a deterministic scenario:

```dart
import 'package:ff_golden/ff_golden.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testFfGoldens(
    'sign in validation',
    scenario: 'authentication/invalid-email',
    coverage: GoldenCoverage(
      devices: const [
        GoldenDevice.iPhone11,
        GoldenDevice.iPad,
      ],
      themes: [GoldenTheme.light, GoldenTheme.dark],
      locales: const [Locale('en'), Locale('ar')],
      textScales: const [1, 1.5],
      sampling: GoldenSampling.pairwise,
    ),
    build: (variant) => const SignInPage(),
    interact: (context) async {
      await context.tester.enterText(
        find.byKey(const Key('email')),
        'not-an-email',
      );
      await context.tester.tap(find.text('Continue'));
    },
  );
}
```

Generate and verify baselines with Flutter's normal commands:

```shell
flutter test --update-goldens
flutter test
```

!!! warning "Review every regenerated PNG"
    `--update-goldens` accepts a new visual contract. It is not a generic way
    to make a failing test pass.

## Two packages, one clear boundary

<div class="ff-boundary" markdown>
<div markdown>
**`ff_golden` owns correctness**

Test expansion, view configuration, capture, comparison, overflow diagnostics,
stale-baseline checks, naming, and machine-readable run manifests.
</div>
<div markdown>
**`ff_golden_presenter` owns publication**

Image collection, staged optimization, search and filtering, HTML generation,
Docker packaging, CI artifacts, and migration automation.
</div>
</div>

The generated report never decides whether a visual test passed. It presents
the runner's result and preserves the original golden files.

## Choose your next step

- Follow [Get started](getting-started.md) to add fonts, initial coverage, and a
  local report.
- Understand [device fidelity](concepts/device-fidelity.md) before defining
  custom presets or changing capture scale.
- Use [stateful and multi-shot scenarios](guides/stateful-scenarios.md) for real
  user workflows.
- Read [Migration](migration.md) before renaming an existing `golden` suite.
- Open the [live FF Golden Presenter demo](https://asodevapp.github.io/golden/demo/)
  to explore the final review surface.

## Requirements

- Flutter 3.27 or newer
- Dart 3.6 or newer
- Baselines stored and reviewed with the application source

Both packages are available under the MIT License.
