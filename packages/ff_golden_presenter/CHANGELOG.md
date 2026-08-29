## 0.1.0

- Renamed the package, public entrypoint, and executable to `ff_golden_presenter` for the Flutter Files infrastructure family.
- Replaced the generic folder tree with a scenario-based catalog model.
- Added a responsive HTML report with summary metrics, filters, navigation, and an accessible lightbox.
- Standardized the CLI around `--input`, `--output`, and documented filename conventions.
- Added a reproducible demo, focused tests, and continuous integration.
- Removed Freezed, code generation, Equatable, and the project-specific shell pipeline.
- Added `build`, `collect`, `optimize`, `report`, and `doctor` actions.
- Added safe staging, concurrent PNG optimization profiles, backend detection, and explicit cross-platform tool installation.
- Added a multi-stage, health-checked, unprivileged nginx container and a one-command Docker Compose demo.
- Added copy-ready GitHub Pages, GitHub Container Registry, GitLab Pages, and GitLab Container Registry templates.
- Moved into the `Gorniv/golden` Pub workspace as the companion publication package for `ff_golden`.
- Added a safe `migrate` preview/apply/check command and a coordinated migration guide.
- Extended migration to public `GoldenDevice`/`GoldenTheme` names and import
  ordering while reporting geometry and deprecated `.size` usage for review.
- Kept `postPumping` unchanged because `ff_golden` preserves its legacy
  after-capture behavior.
- Added schema-v1/v2 `ff_golden.run` shard ingestion with exact capture-to-image mapping.
- Fixed dotted-device parsing and added structured text-scale, direction, platform, brightness, and contrast axes.
- Added capture/status filters, duration badges, and expandable failure diagnostics to the HTML report.
- Added an end-to-end runner-to-presenter CI contract test.
- Licensed the package under MIT.
- Added transparent sponsored ASO.dev support attribution with a
  `--no-support-attribution` opt-out for report and build commands.
- Added a repository-owned GitHub Pages deployment for the live demo.

## 0.0.3

- Initial version.
