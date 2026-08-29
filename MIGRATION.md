# Migrating to the Flutter Files golden stack

This guide migrates an application from `golden` and `golden_presenter` to
`ff_golden` and `ff_golden_presenter`. Make the migration in a dedicated branch:
device geometry and baseline names are corrected intentionally, so PNG changes
must be reviewed separately from normal product changes.

## Requirements

- Flutter 3.27 or newer (the packages require Dart 3.6 or newer).
- A clean or committed application worktree so generated baseline changes can
  be reviewed and reverted independently.
- A passing pre-migration test run, or a recorded list of existing failures.

Before changing dependencies, record the current state:

```shell
flutter test --tags golden
git status --short
```

## 1. Bootstrap the new packages

Replace the old development dependencies with the two published packages:

```yaml
dev_dependencies:
  ff_golden: ^1.0.0-dev.1
  ff_golden_presenter: ^0.1.0
```

For an unreleased repository revision, pin both Git dependencies to the same
tag or commit and use their `packages/ff_golden*` monorepo paths.

Run:

```shell
flutter pub get
```

The presenter must be bootstrapped manually because its new package provides
the migration executable. A project that does not publish reports may remove
`ff_golden_presenter` after completing the audit, but keeping it gives local and
CI users one locked report toolchain.

## 2. Preview and apply deterministic changes

From the application root, preview the migration without writing files:

```shell
dart run ff_golden_presenter migrate --project .
```

Apply only deterministic renames:

```shell
dart run ff_golden_presenter migrate --project . --apply
dart format test
flutter pub get
```

The command updates:

- `golden` and `golden_presenter` dependency keys;
- public `package:` imports;
- unambiguous `Device` -> `GoldenDevice` and `NamedTheme` -> `GoldenTheme`
  references, including import ordering;
- the old standalone presenter repository URL and monorepo `path` values;
- legacy local/global presenter commands;
- old `packages/golden*` workspace paths.

It ignores generated and build directories. It does not edit device geometry,
rename `postPumping`, delete old PNGs, update the lockfile directly, or run
golden tests. Those changes need project-specific judgment.

After resolving every reported manual item, make the audit a CI-safe check:

```shell
dart run ff_golden_presenter migrate --project . --check
```

`--check` exits with code `1` while either a safe change or a manual review is
still detected. Preview and `--apply` exit successfully after completing their
own work, even when manual reviews remain.

## 3. Review runner API changes

### Imports and compatibility names

Use the primary public entrypoint:

```dart
import 'package:ff_golden/ff_golden.dart';
```

The migrator replaces unambiguous `Device` and `NamedTheme` references with
`GoldenDevice` and `GoldenTheme`. `GoldenTester` and `testDeviceGoldens` remain
as compatibility APIs for incremental migration. New suites should use
`testFfGoldens` and `GoldenMatrix`.

Private imports such as `package:golden/src/device.dart` have no automatic
equivalent. Replace them with the public `ff_golden.dart` entrypoint.

### Custom devices use logical pixels

The old `Device.size` represented physical pixels. Divide it by the DPR and set
the target platform explicitly:

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

Do not divide preset dimensions: replace `Device.iPhone14` with
`GoldenDevice.iPhone14`, whose corrected logical geometry is already built in.
Keep safe-area values in logical pixels.
Replace deprecated `.size` reads explicitly with `.physicalSize` when the old
physical-pixel value is intended, or `.logicalSize` for layout calculations.

### Capture timing stays compatible

`GoldenTester.postPumping` remains supported and runs after image comparison,
exactly as it did in `golden`. Existing suites should keep this callback during
the package rename. New or intentionally rewritten suites can use
`beforeCapture` when they need to stabilize the frame after the scenario and
before comparison. When both callbacks are supplied, the order is scenario,
`beforeCapture`, comparison, then `postPumping`.

Legacy `GoldenTester` paths also remain byte-for-byte compatible: scenario,
test, and device names are not sanitized, and locale suffixes continue to use
`Locale.toString()` (for example, `zh_Hans`). BCP-47 suffixes and sanitized
paths apply only to new `testFfGoldens` suites.

### Prefer the matrix API for new or rewritten suites

Compatibility suites can continue to call `testDeviceGoldens`. When rewriting a
suite, migrate behavior into `testFfGoldens` with an explicit `scenario`,
`GoldenMatrix`, `build`, and optional `interact`. Do this separately from the
package rename when a small, reviewable migration is more important than using
all new features immediately.

`testDeviceGoldens` deliberately preserves the old view setup, test names, and
`golden` tag so a package rename does not invalidate existing PNGs. Corrected
standard presets are the exception. For example, `GoldenDevice.fullHd` is the
actual 1920x1080 viewport; a project with historical 1920x1800 baselines should
temporarily declare a project-local compatibility device and migrate those
baselines separately.

## 4. Regenerate and review baselines

First run without updating to expose unexpected compile, geometry, and naming
changes:

```shell
flutter test --tags golden
```

Then generate the intended baselines:

```shell
flutter test --update-goldens --tags golden
```

Expected one-time changes include corrected logical viewports, native-DPR image
sizes, BCP-47 locale suffixes such as `en-US`, and sanitized/collision-checked
filenames. Review old and new PNGs before removing files reported as stale.
Stale detection can intentionally leave the first update run non-zero while it
identifies superseded files.

Finish with a clean verification run:

```shell
flutter test --tags golden
git status --short
```

Do not combine broad baseline regeneration with unrelated UI or font changes.
If many screenshots differ unexpectedly, stop and verify custom logical sizes,
DPR, fonts, locale, platform, and animation settling before accepting them.

## 5. Replace the presenter pipeline

Replace global activation and copied `golden.sh` pipelines with the locked local
executable:

```shell
dart run ff_golden_presenter build \
  --input test/screens \
  --manifest build/ff_golden \
  --output-directory build/golden-report \
  --profile none \
  --clean
```

Start with `--profile none` while validating migration parity. Enable
`balanced` or `lossless` publication optimization only after the source golden
run is stable; the presenter optimizes staged copies, not baseline PNGs.

Upload the complete output directory, not only `index.html`:

```yaml
- name: Run golden tests
  run: flutter test --tags ff_golden

- name: Verify migration is complete
  run: dart run ff_golden_presenter migrate --project . --check

- name: Build golden report
  run: >-
    dart run ff_golden_presenter build
    --input test/screens
    --manifest build/ff_golden
    --output-directory build/golden-report
    --profile none
    --clean

- uses: actions/upload-artifact@v4
  with:
    name: golden-report
    path: build/golden-report
```

## Completion checklist

- Both dependencies resolve from one pinned `asodevapp/golden` revision.
- No project source imports `package:golden/` or `package:golden_presenter/`.
- Every custom device uses verified logical geometry and platform metadata.
- Every `postPumping` callback was classified as pre-capture stabilization or
  post-capture cleanup.
- Baseline additions, changes, and stale deletions were visually reviewed.
- `migrate --check`, `flutter analyze`, and golden tests pass in CI.
- The full presenter directory opens correctly from the CI artifact.

If rollback is needed, restore the application commit and its lockfile together
with the old baselines. Do not keep the new runner with old physical-pixel custom
devices or mix runner and presenter revisions unintentionally.
