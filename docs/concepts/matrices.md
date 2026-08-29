---
title: Matrices and sampling
description: Define feasible Flutter golden variants and select full, smoke, pairwise, or risk-priority coverage without silently weakening the test plan.
---

# Matrices and sampling

`GoldenMatrix` expands the environment axes, removes impossible combinations,
then applies a deterministic sampling strategy. The resulting variant plan is
known before any Flutter test is registered.

## Available axes

- devices;
- locales;
- themes;
- text scales;
- text directions;
- target platforms;
- brightness modes;
- high-contrast modes.

If an axis is omitted, FF Golden uses its documented default or the selected
device's value.

## Sampling strategies

| Strategy | Contract | Budget behavior |
| --- | --- | --- |
| `full` | Keep every feasible combination | Fails if all variants exceed the budget |
| `smoke` | Cover every individual axis value | Fails if complete single-value coverage exceeds the budget |
| `pairwise` | Cover every feasible pair of axis values | Fails if complete pair coverage exceeds the budget |
| `priority` | Sort by a risk function | Applies `maxCombinations` as a hard cap |

`full`, `smoke`, and `pairwise` never silently weaken their coverage promise.
They throw `GoldenMatrixBudgetExceeded` with the required count. Increase the
budget, reduce the declared axes, add a feasibility rule, or intentionally use
`priority`.

## A pairwise matrix

```dart
final accountMatrix = GoldenMatrix(
  devices: const [
    GoldenDevice.iPhone11,
    GoldenDevice.iPad,
    GoldenDevice.macOS,
  ],
  locales: const [Locale('en'), Locale('ar'), Locale('de')],
  themes: [GoldenTheme.light, GoldenTheme.dark],
  textScales: const [1, 1.5, 2],
  directions: const [GoldenDirection.auto],
  highContrasts: const [false, true],
  sampling: GoldenSampling.pairwise,
  maxCombinations: 30,
);
```

Pairwise is a strong default for a broad compatibility suite. It is not a
substitute for explicitly enumerating a small set of high-value product states.

## Exclude impossible combinations

```dart
rules: [
  GoldenMatrixRule.excludeWhen(
    'Cupertino screen is iOS-only',
    (variant) => variant.platform != TargetPlatform.iOS,
  ),
],
```

`excludeWhen` removes variants matching its predicate. `require` keeps only
variants that satisfy its predicate. Give every rule a name that explains the
product constraint, not merely the boolean expression.

## Risk-priority sampling

```dart
GoldenMatrix(
  // axes omitted
  sampling: GoldenSampling.priority,
  maxCombinations: 12,
  priority: (variant) {
    var score = 0;
    if (variant.locale.languageCode == 'ar') score += 10;
    if (variant.textScale >= 2) score += 8;
    if (variant.highContrast) score += 4;
    return score;
  },
)
```

Priority sampling is the only strategy whose contract is the hard cap itself.
Use it when the organization has an explicit risk model or a bounded pull
request suite. Keep a broader pairwise or full run on a scheduled pipeline when
those combinations still matter.

## Inspect the plan

```dart
final plan = accountMatrix.plan();

print(plan.rawCount);
print(plan.excludedCount);
print(plan.selectedCount);
print(plan.variants);
```

The JSON reporter records the same raw, excluded, selected, and sampling data,
so CI reports can explain why a particular variant was or was not executed.
