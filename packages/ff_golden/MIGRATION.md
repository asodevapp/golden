# Migrating from golden to ff_golden

For dependency bootstrap, presenter migration, CI, rollback, and the automated
audit command, use the
[complete Flutter Files migration guide](https://github.com/Gorniv/golden/blob/master/MIGRATION.md).

Version `1.0.0-dev.1` intentionally regenerates some baselines because the old
device model mixed physical and logical pixels. Perform the migration in a
dedicated change and review every updated PNG.

## 1. Rename the dependency and import

```diff
- golden: ^0.3.0
+ ff_golden: ^1.0.0-dev.1
```

```diff
- import 'package:golden/golden.dart';
+ import 'package:ff_golden/ff_golden.dart';
```

`package:ff_golden/golden.dart` remains as a deprecated library shim, but the
primary entry point is `ff_golden.dart`.

## 2. Update custom devices

Presets such as `Device.iPhone11` continue to compile through a deprecated
alias. The automated migrator replaces unambiguous references with
`GoldenDevice.iPhone11`.

Custom devices must now specify logical geometry explicitly:

```diff
- Device(name: 'phone', size: Size(1170, 2532), devicePixelRatio: 3)
+ GoldenDevice(
+   name: 'phone',
+   logicalSize: Size(390, 844),
+   devicePixelRatio: 3,
+   platform: TargetPlatform.iOS,
+ )
```

Do not divide the test view size manually. `ff_golden` derives
`physicalSize = logicalSize * devicePixelRatio`.
Replace old `.size` reads explicitly with `.physicalSize` or `.logicalSize`.

## 3. Preserve legacy suites, then adopt new naming

`testDeviceGoldens` preserves its historical view setup, test names, and
`golden` tag so the package rename itself does not invalidate existing PNGs.
`GoldenTester` also preserves `postPumping`: its default pumps still happen
after comparison. Use `beforeCapture` explicitly only when a suite should settle
or advance animations before taking the image.
Legacy paths keep unsanitized scenario names and `Locale.toString()` suffixes;
the new BCP-47 path convention applies only after moving to `testFfGoldens`.
Corrected presets can still change geometry: `GoldenDevice.fullHd` is 1920x1080,
so projects with historical 1920x1800 baselines should keep a project-local
compatibility device until those baselines are migrated intentionally.

When a suite moves to `testFfGoldens`, locale suffixes use BCP-47 tags such as
`en-US`, default-axis suffixes are omitted only when unambiguous, and path
collisions are rejected before tests are registered.

## 4. Regenerate and review

```shell
flutter test --tags golden
flutter test --update-goldens
flutter test --tags golden
```

New matrix-suite baselines can change substantially because Flutter receives
the intended logical viewport and DPR. Treat these as reviewed suite upgrades,
not as part of the package-name rename.

If old and new filenames share a scenario directory, stale detection can report
the superseded PNGs after generating replacements. Compare them before deleting
only the reported stale files.

## 5. Move new suites to testFfGoldens

`GoldenTester` and `testDeviceGoldens` remain for incremental migration. New
tests should use `testFfGoldens`, `GoldenMatrix`, and `GoldenRunConfiguration` to
gain sampling, collision checks, overflow failures, stale detection, and JSON
reporting.

## Automated audit

After adding `ff_golden_presenter` as a development dependency, preview and
apply deterministic renames from the application root:

```shell
dart run ff_golden_presenter migrate --project .
dart run ff_golden_presenter migrate --project . --apply
dart run ff_golden_presenter migrate --project . --check
```

Custom device geometry and deprecated `.size` reads are reported for manual
review and are never rewritten automatically. Public
`Device`/`NamedTheme` aliases and their import ordering are migrated safely.
