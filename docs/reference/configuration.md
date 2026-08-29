---
title: Configuration reference
description: Quick reference for GoldenRunConfiguration, GoldenCoverage, GoldenDevice, GoldenPathStrategy, and JSON reporting options.
---

# Configuration reference

This page summarizes the high-level public configuration. Use the generated API
reference for constructor signatures and complete type documentation.

## `GoldenRunConfiguration`

| Field | Default | Meaning |
| --- | --- | --- |
| `pathStrategy` | `GoldenPathStrategy()` | Baseline folder and filename policy |
| `testName` | empty | Optional automatic capture prefix |
| `captureScale` | `null` | PNG scale; `null` preserves device DPR |
| `tolerance` | `GoldenTolerance.strict` | Pixel comparison policy |
| `failOnOverflow` | `true` | Fail captured Flutter overflow diagnostics |
| `freezeAnimations` | `true` | Disable tickers below the captured application |
| `renderShadows` | `false` | Render real Material shadows instead of deterministic boxes |
| `detectStaleGoldens` | `true` | Report unexpected PNGs in the scenario scope |
| `autoCapture` | `true` | Capture once after interaction and pump |
| `reporter` | `null` | Optional machine-readable result reporter |

## `GoldenCoverage`

| Field | Default | Meaning |
| --- | --- | --- |
| `devices` | `GoldenDevice.iPhone11` | Device geometry and environment defaults |
| `locales` | `Locale('en', 'US')` | Locale variants |
| `themes` | `GoldenTheme.defaultTheme` | Named theme variants |
| `textScales` | device default | Independent text-scale variants |
| `directions` | `GoldenDirection.auto` | Automatic, LTR, or RTL direction |
| `platforms` | device default | Target platform variants |
| `brightnesses` | device default | Light or dark environment brightness |
| `highContrasts` | device default | High-contrast variants |
| `rules` | empty | Feasibility requirements and exclusions |
| `sampling` | `GoldenSampling.full` | Full, smoke, pairwise, or priority plan |
| `maxCombinations` | `256` | Coverage budget or priority hard cap |
| `priority` | built-in risk score | Custom risk function for priority sampling |

## `GoldenDevice`

| Field | Default | Meaning |
| --- | --- | --- |
| `name` | required | Stable human-readable and filename identity |
| `logicalSize` | required | Flutter layout viewport in logical pixels |
| `devicePixelRatio` | `1` | Logical-to-physical scale |
| `platform` | Android | Default target platform |
| `safeArea` | zero | Logical safe-area insets |
| `brightness` | light | Default environment brightness |
| `highContrast` | `false` | Default high-contrast value |
| `textScale` | `1` | Legacy device default; prefer coverage text scales |

`physicalSize` is derived. The deprecated `.size` getter returns physical size
for compatibility and should not be used in new code.

## `GoldenPathStrategy`

| Field | Default | Meaning |
| --- | --- | --- |
| `folder` | `golden` | Baseline folder below the test file |
| `includeDefaultAxes` | `false` | Include axes even when they match defaults |

Names are sanitized and paths are checked case-insensitively for collisions
before tests register.

## `JsonGoldenReporter`

```dart
JsonGoldenReporter(
  'build/ff_golden',
  shardName: 'checkout-goldens',
)
```

The first argument can be a directory or `.json` output path. `shardName` is
required and must be stable and unique across test files. Share the instance
within a file so every registered scenario contributes to one schema-v2 shard.

## Test registration

`testFfGoldens` accepts the scenario, builder, optional coverage, application
wrapper, interaction, pump, configuration, per-case hooks, standard Flutter
test controls, and additional tags. It creates one `testWidgets` case per
selected variant.

`testFfGoldenScenarios<T>` registers a typed state table against the same
coverage and configuration.
