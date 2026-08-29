---
title: Migrate from golden and golden_presenter
description: Safely rename packages, preserve compatibility suites, convert physical device geometry, review baseline changes, and replace presenter publication commands.
---

# Migrate from `golden` and `golden_presenter`

Treat the package rename, a matrix-API rewrite, and visual baseline changes as
separate reviewable operations. Existing `GoldenTester` and
`testDeviceGoldens` suites remain available so a dependency rename does not
need to rewrite the entire harness.

!!! warning "Start from a known visual state"
    Use a dedicated branch with a clean or committed worktree. Record the
    current golden result and PNG status before changing dependencies.

## 1. Record the current result

```shell
flutter test --tags golden
git status --short
```

Save the existing failure list if the suite is not green.

## 2. Bootstrap the new packages

```yaml
dev_dependencies:
  ff_golden: ^1.0.0-dev.1
  ff_golden_presenter: ^0.1.0
```

```shell
flutter pub get
```

The presenter provides the migration executable, even when the final project
will publish only runner output.

## 3. Preview, apply, and check

```shell
dart run ff_golden_presenter migrate --project .
dart run ff_golden_presenter migrate --project . --apply
dart format test
flutter pub get
dart run ff_golden_presenter migrate --project . --check
```

The migrator applies only unambiguous dependency, import, public compatibility
name, repository path, workspace path, and presenter command changes. It does
not alter device geometry, rename capture hooks, delete PNGs, update the
lockfile directly, or run golden tests.

## 4. Keep compatibility API behavior stable

During the package rename, existing suites can continue using
`testDeviceGoldens` and `GoldenTester`. This path preserves historical test
names, tags, capture timing, unsanitized paths, and locale suffixes.

Use the new primary import:

```dart
import 'package:ff_golden/ff_golden.dart';
```

Move to `testFfGoldens` and `GoldenMatrix` in a later intentional rewrite when
you want complete variant environments, sanitized paths, structured reports,
sampling, overflow diagnostics, and stale detection.

## 5. Convert custom device geometry

Legacy custom `Device.size` values were physical pixels. Divide them by DPR and
declare the platform:

```diff
- const Device(
+ const GoldenDevice(
    name: 'phone',
-   size: Size(1170, 2532),
+   logicalSize: Size(390, 844),
    devicePixelRatio: 3,
+   platform: TargetPlatform.iOS,
  )
```

Do not divide FF Golden built-in presets. Replace the old preset with its new
counterpart and review any corrected geometry as a separate visual change.

## 6. Verify before updating

```shell
flutter test --tags golden
```

Unexpected changes often point to custom physical sizes, corrected presets,
font loading, locale naming, platform behavior, or capture timing. Diagnose
them before update mode.

Generate only the intended baselines, review every PNG, then verify cleanly:

```shell
flutter test --update-goldens --tags golden
flutter test --tags golden
git status --short
```

## 7. Replace the publication pipeline

```shell
dart run ff_golden_presenter build \
  --input test/screens \
  --manifest build/ff_golden \
  --output-directory build/golden-report \
  --profile none \
  --clean
```

Start with `--profile none` for migration parity. Upload the complete output
directory, not only `index.html`.

## Completion checklist

- [ ] No source imports `package:golden/` or `package:golden_presenter/`.
- [ ] Every custom device has verified logical geometry and platform metadata.
- [ ] Existing capture timing was preserved or intentionally rewritten.
- [ ] Baseline additions, changes, and stale deletions were visually reviewed.
- [ ] `migrate --check`, analyzer, and focused golden tests pass.
- [ ] The complete presenter directory opens from the CI artifact.

The repository also keeps the
[full migration source](https://github.com/Gorniv/golden/blob/master/MIGRATION.md)
next to the packages for review during offline checkout work.
