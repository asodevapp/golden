## 1.0.0-dev.1

- Renamed the package from `golden` to `ff_golden`.
- Added `testFfGoldens` and a complete `GoldenVariant` test environment.
- Added typed `GoldenScenario<T>` state tables over a shared matrix.
- Corrected device presets to distinguish logical and physical pixels.
- Added matrix constraints and full, smoke, pairwise, and priority sampling.
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
  sanitized BCP-47 paths remain exclusive to the new matrix API.
- Aligned the Flutter minimum with the Dart 3.6 requirement and documented the
  end-to-end automated migration workflow.
- Added an end-to-end multi-shot runner-to-presenter CI fixture.
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
