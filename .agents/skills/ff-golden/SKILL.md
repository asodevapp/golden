---
name: ff-golden
description: Build, migrate, review, or debug Flutter golden test suites with ff_golden and ff_golden_presenter. Use when choosing the legacy or matrix API, defining devices/themes/locales and deterministic scenarios, preserving or updating PNG baselines, diagnosing pixel diffs and stale files, or producing local and CI reports.
---

# Work with ff_golden

Use the checked-out package code and tests as the source of truth. Keep a package rename, a suite rewrite, and a reviewed visual change as separate operations unless the user explicitly combines them.

## Route the Work

- For a new or intentionally rewritten suite, read [the ff_golden guide](../../../packages/ff_golden/README.md), then inspect the closest tests under `packages/ff_golden/test/`.
- For migration from `golden` or `golden_presenter`, read [the complete migration guide](../../../MIGRATION.md) before editing the consumer project.
- For catalog, optimization, publication, Docker, or CI reporting, read [the presenter guide](../../../packages/ff_golden_presenter/README.md).
- For package maintenance, inspect the public exports and the focused implementation/test files before changing API behavior. Preserve compatibility with a regression test, not documentation alone.

## Choose the API Boundary

Keep existing suites on `testDeviceGoldens` + `GoldenTester` during a package-name migration. Their compatibility contract includes:

- the historical test names and the `golden` tag;
- physical size, DPR, and text scale view setup without silently applying new locale, safe-area, brightness, contrast, or platform axes;
- comparison before the default `postPumping`; `beforeCapture` is explicit opt-in behavior;
- unsanitized scenario/test/device names and `Locale.toString()` suffixes such as `zh_Hans`;
- project-local compatibility devices when a corrected preset would change existing geometry, such as a historical `1920x1800` FullHD baseline.

Do not accept baseline churn caused only by violating those invariants.

Use `testFfGoldens`, `GoldenScenario`, `GoldenMatrix`, and `GoldenRunConfiguration` for new suites. This API intentionally supplies the complete variant environment, sanitized collision-safe paths, BCP-47 locale tags, structured reports, overflow diagnostics, sampling, and stale detection.

## Build a Deterministic Suite

- Express device geometry in logical pixels and set DPR separately. Use `.logicalSize` or `.physicalSize` explicitly; do not rely on deprecated `.size` in new code.
- Model user-visible scenarios with fixed data, stable clocks/IDs, deterministic ordering, and bounded interaction.
- Select full, smoke, pairwise, or priority sampling from the coverage requirement. Do not reduce a matrix merely to make the test faster when it drops a meaningful axis value.
- Load application fonts and replace network, filesystem, timers, streams, platform services, and persistent state that can vary between runs.
- Use strict comparison by default. Add tolerance only for a justified rendering boundary and keep it below the smallest real regression the suite must detect.
- Keep capture scale explicit when it differs from native DPR. Never infer physical geometry by multiplying an already physical legacy size again.

## Protect Baselines

1. Record scoped tracked and untracked PNG state before running the test.
2. Run without `--update-goldens` and diagnose the first mismatch.
3. Update only for a new baseline or an intentional reviewed visual change.
4. Rerun the same command without updating.
5. Inspect every changed or added image, including mobile/desktop, themes, locales, overflow, clipping, text, scroll position, and overlays.
6. Recount tracked and untracked PNGs. A passing test does not excuse duplicate filename families or unrelated rewritten directories.

Do not edit PNGs manually or broadly regenerate a consumer project to hide harness drift. For an unexpected diff, compare dimensions, changed-pixel count, bounding box, failure images, capture timing, environment, fonts, and data before changing code or baselines. Delete stale or duplicate files only after mapping them to authoritative replacements; preserve a recoverable patch/archive for broad cleanup.

## Keep Runner and Presenter Responsibilities Separate

`ff_golden` owns execution, capture correctness, comparison, diagnostics, and run manifests. `ff_golden_presenter` consumes images/manifests and owns collection, optimization, HTML browsing, publication, and migration automation. Do not move correctness decisions into the report generator.

Use project-local execution:

```sh
dart run ff_golden_presenter migrate --project . --check
dart run ff_golden_presenter build --input test --output build/ff-golden-report
```

Prefer an explicit schema-v2 manifest directory when the suite emits one. Treat missing captures, failed captures, and ambiguous image mappings as report failures rather than silently cataloging incomplete output.

## Verify and Hand Off

Run checks proportional to the touched layer:

```sh
cd packages/ff_golden
flutter analyze
flutter test

cd ../ff_golden_presenter
dart analyze
dart test
```

For a consumer migration, also run the exact focused golden commands without updating, `migrate --check`, analyzer checks, and `git diff --check`. Report which API was used, matrix/sampling, baseline changes, images reviewed, exact commands, presenter output, and any intentionally deferred migration. Do not claim compatibility from package tests alone; verify at least one representative consumer baseline when a consumer project is in scope.
