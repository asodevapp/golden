## Unreleased

## 1.3.1

- Added a pub.dev screenshot and an early README visual showing one scenario
  across controlled device, theme, locale, direction, and platform variants.

## 1.3.0

- Added opt-in variant discovery for ff_golden_presenter: with
  `--dart-define=FF_GOLDEN_DISCOVERY=true` and `--tags=ff_golden_discovery`,
  the legacy and coverage APIs expose planned variants through Flutter's JSON
  reporter without golden callbacks, captures, comparisons, or reporters.
  Normal test execution is unchanged; file initialization and shared setup
  hooks still run during discovery.

## 1.2.2

- Linked the companion `ff_golden_presenter` package directly from the package
  README displayed on pub.dev.

## 1.2.1

- Added API documentation for the primary device, theme, variant, and
  comparison surfaces.
- Published the runnable coverage example at the conventional
  `example/example.dart` path used by pub.dev.

## 1.2.0

- Added `ff_golden test`, `verify`, and `update` commands with golden-test file
  discovery, project-local FVM resolution, safe test defaults, argument
  forwarding, and dry-run support.

## 1.1.0

- Added bounded virtual-time helpers for predicate, finder, fixed-frame, and
  fixed-duration waits in both the coverage and legacy APIs.
- Added typed per-scenario `prepare` and `dispose` fixture lifecycle callbacks.
- Added controlled async fake examples and deterministic fixture guidance.

## 1.0.0

- Declared the current runner API stable after long-term production use of the
  underlying golden-test workflow.
- Stabilized the existing legacy compatibility layer, coverage API, device
  fidelity, strict diagnostics, and presenter manifest contract without
  behavioral changes from `1.0.0-dev.1`.

## 1.0.0-dev.1

- Renamed the package from `golden` to `ff_golden`.
- Added `testFfGoldens` and a complete `GoldenVariant` test environment.
- Named the new suite configuration `GoldenCoverage` with the `coverage:`
  parameter, plus matching rule, plan, and budget-exception types.
- Added typed `GoldenScenario<T>` state tables over shared coverage.
- Corrected device presets to distinguish logical and physical pixels.
- Added coverage constraints and full, smoke, pairwise, and priority sampling.
- Added deterministic path generation with BCP-47 locales and collision checks.
- Added strict overflow and stale baseline diagnostics.
- Added explicit pixel and percentage tolerance policies.
- Added independent PNG capture scaling, native-DPR captures by default, and
  optional real shadow rendering.
- Added application font loading through `loadFfGoldenFonts`.
- Added JSON run reports for CI and `ff_golden_presenter`.
- Made JSON reporting isolate-safe with required stable shard names, schema-v2
  capture records, and source baseline directories for presenter ingestion.
- Converted the repository to a native Pub workspace and added
  `ff_golden_presenter` as the publication package.
- Preserved `GoldenTester`, `testDeviceGoldens`, `Device`, and `NamedTheme` as
  migration APIs.
- Preserved the legacy `testDeviceGoldens` view, test-name, and tag contracts so
  package renames do not invalidate existing baselines.
- Preserved legacy `GoldenTester.postPumping` capture order; `beforeCapture` is
  now an explicit opt-in for advancing a frame before comparison.
- Preserved legacy `GoldenTester` path names and `Locale.toString()` suffixes;
  sanitized BCP-47 paths remain exclusive to the new coverage API.
- Aligned the Flutter minimum with the Dart 3.6 requirement and documented the
  end-to-end automated migration workflow.
- Added an end-to-end multi-shot runner-to-presenter CI fixture.
- Added the hosted FF Golden guide and package API documentation links.
- Licensed the package under MIT.

## 0.3.0

- Support multiple themes.
- Add theme tests.
- Enhance `Device`.

## 0.2.0

- Support multiple languages.
- Update test examples.

## 0.0.1

- Initial release.
