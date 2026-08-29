---
title: Comparison and baselines
description: Keep Flutter golden comparison strict, scope justified tolerance, detect overflow and stale baselines, and review PNG changes as source changes.
---

# Comparison and baselines

The default FF Golden policy is intentionally strict:

```dart
const GoldenRunConfiguration(
  tolerance: GoldenTolerance.strict,
  failOnOverflow: true,
  detectStaleGoldens: true,
  freezeAnimations: true,
  renderShadows: false,
)
```

## Tolerance is local policy

Only add tolerance after identifying a renderer boundary that is expected to
vary and smaller than the real regressions the suite must catch:

```dart
const GoldenRunConfiguration(
  tolerance: GoldenTolerance(
    maxDiffRate: 0.001,
    maxDifferentPixels: 20,
  ),
)
```

`maxDiffRate` is a fraction: `0.001` means `0.1%`. A comparison passes when the
normal Flutter comparator passes, the diff rate is within its budget, or the
estimated changed-pixel count is within the absolute budget.

Avoid a project-wide tolerance chosen only to make current failures disappear.
Different visual surfaces often need different contracts.

## Overflow is a visual failure

With `failOnOverflow: true`, captured `RenderFlex` overflow diagnostics fail the
case even if the current image happens to match. This prevents an overflow
stripe or clipped layout from becoming an accepted baseline.

## Stale baselines are reported

FF Golden knows the expected paths for every planned variant. At suite teardown
it reports PNG files in a scenario scope that are no longer generated. Inspect
the mapping before deleting them: a stale file might be a superseded device,
locale, state, or naming convention.

## Naming is deterministic

New matrix suites use sanitized, collision-checked paths:

```text
golden/<scenario>/[capture.]device[theme](locale){text-scale}{direction}{platform}{brightness}{contrast}.png
```

Default-valued axes are omitted unless
`GoldenPathStrategy(includeDefaultAxes: true)` is selected. If two variants
would resolve to the same case-insensitive path, registration fails with
`GoldenPathCollision` before tests start.

## Safe baseline workflow

1. Record tracked and untracked PNG state.
2. Run the focused test without `--update-goldens`.
3. Diagnose the first mismatch and its failure artifacts.
4. Update only the intended suite.
5. Review every changed and added PNG.
6. Rerun the same command without update mode.
7. Remove stale files only after mapping them to replacements.

Review mobile and desktop geometry, both themes, localized text, clipping,
overflow, scroll position, focus, overlays, and the exact captured moment. A
green update run is not visual approval.
