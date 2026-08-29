---
title: Troubleshooting
description: Diagnose unexpected Flutter golden diffs, stale baselines, matrix budget failures, missing presenter metadata, overflow, and optimizer setup problems.
---

# Troubleshooting

Start with the first failing variant and keep the run out of update mode. A
baseline update removes evidence about the previous visual contract.

## Many screenshots changed unexpectedly

Check these boundaries in order:

1. Compare old and new PNG dimensions.
2. Verify logical size, DPR, and `captureScale` independently.
3. Confirm application fonts loaded without fallback.
4. Compare safe area, platform, locale, direction, text scale, theme,
   brightness, and contrast.
5. Check deterministic fixture data and ordering.
6. Verify the captured interaction checkpoint.
7. Inspect Flutter's `masterImage`, `testImage`, `isolatedDiff`, and
   `maskedDiff` artifacts.

A partial rewrite within one suite often indicates that only some variants use
the changed font, state, safe area, theme, or filename family.

## PNG dimensions are larger than expected

Native capture uses device DPR. For a `414 × 896` device at `2×`, a
`828 × 1792` PNG is expected. If the suite is intentionally layout-only, set an
explicit `captureScale: 1` while preserving device DPR.

Do not reduce `devicePixelRatio`; that changes the environment observed by the
application.

## `GoldenMatrixBudgetExceeded`

The selected `full`, `smoke`, or `pairwise` contract needs more combinations
than `maxCombinations` allows. The exception reports the required count.

Choose one intentional response:

- increase the budget;
- remove an axis that is not part of this suite's contract;
- exclude impossible combinations with a named rule;
- use `priority` when the hard cap is the actual contract.

FF Golden does not silently provide incomplete smoke or pairwise coverage.

## `GoldenPathCollision`

Two variants resolve to the same case-insensitive baseline path. Common causes
include duplicated axis names, names that sanitize identically, or default axes
that differ internally but are omitted from filenames.

Rename the conflicting value or use:

```dart
const GoldenPathStrategy(includeDefaultAxes: true)
```

Do not disable the validation: ambiguous files cannot be reviewed reliably.

## `StaleGoldenFilesFound`

The scenario directory contains PNGs outside the current plan. Map each file to
a removed scenario, variant, capture, or naming convention before deleting it.
An update run can still finish non-zero while stale detection identifies
superseded files.

## A `RenderFlex` overflow fails a matching image

This is expected with `failOnOverflow: true`. The overflow is treated as a
diagnostic failure even if it exists in the current baseline. Fix the layout or
explicitly scope `failOnOverflow: false` only when clipping is the intended
contract.

## Presenter shows images but no matrix metadata

Check that:

- the test uses a shared `JsonGoldenReporter`;
- each test file has a unique `shardName`;
- the report command points `--manifest` to the correct file or directory;
- `build/ff_golden` was not removed between the test and publication steps;
- image paths still resolve relative to the manifest's project and golden base.

Without a matching manifest, presenter falls back to filename parsing and
cannot infer run duration, status, failure phase, or every axis reliably.

## Presenter finds no scenarios

The scanner includes supported images only below a directory whose name matches
`--golden-directory`, which defaults to `golden`:

```text
test/screens/authentication/golden/sign_in/iphone11.png
```

Point `--input` at an ancestor of that marker or configure the actual marker
name.

## Optimizer is missing

```shell
dart run ff_golden_presenter doctor --profile balanced
```

Install the compatible command it reports, select another backend, or use
`--profile none`. The publication pipeline can always copy and report images
without an optimizer.

## `--clean` refuses the output directory

The guard protects broad or overlapping targets. Choose an isolated directory
such as `build/golden-report`. It must not be the filesystem root, home,
repository root, input directory, or an ancestor of the input.

## Still blocked?

Open an issue with:

- Flutter and Dart versions;
- host operating system;
- the focused test command;
- failing variant label and manifest shard;
- old/new PNG dimensions;
- changed-pixel count or failure artifacts;
- the smallest reproducible matrix and configuration.

[Report an FF Golden issue](https://github.com/Gorniv/golden/issues){ .md-button }
