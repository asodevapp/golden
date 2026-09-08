## 1.1.8

- Preserved open tree menus, focus, selection, collapsed folders, and scroll
  position during automatic refresh and background metric updates. Folder
  percentages now update incrementally without rebuilding unchanged rows.
- Reused image difference results by comparison identity with bounded caches,
  deduplicated queued calculations, and retries for transient file changes.
  Updating generated failure masks no longer recalculates expected/actual diffs.
- Displayed new Git images in one full-width pane with a **new** badge, including
  staged additions. Returning to a modified image restores comparison settings.
- Added browser regression coverage for polling, menu state, metric updates, and
  new-image display, with a dedicated CI job.

## 1.1.7

- Added a dedicated **Failures** filter that groups Flutter's expected, actual,
  isolated-diff, and masked-diff artifacts into one tree row, with pinned counts
  and asynchronous Dart-isolate difference percentages.
- Added confirmed one-click cleanup for generated failure images, with immediate
  progress, exact-directory and symlink guards, and protection against cleanup
  while golden tests are running. Failure artifacts no longer appear as Git
  changes.

## 1.1.6

- Fixed stale Git `index.lock` recovery on Windows when Git reports the lock
  path with forward slashes and Dart normalizes it with backslashes.
- Synchronized the CLI `--version` output with the published package version.

## 1.1.5

- Added guarded working-tree revert actions for files, folders, and selections;
  tracked files restore from the index while revalidated untracked files are
  deleted only after explicit confirmation.
- Added asynchronous Dart-isolate pixel-difference percentages for image files
  and pixel-weighted folder aggregates in the `diff` tree, plus persistent
  shown/unstaged/staged counts above the scrolling file list.

## 1.1.4

- Limited generated report filter menus to values that are applicable to the
  current search and other active filters, and omitted filters for metadata axes
  absent from every rendered image.
- Recovered `diff` stage and unstage actions from a stale Git `index.lock` only
  after verifying that no process holds the unchanged lock file; active or
  unverifiable locks remain untouched. Stage actions now show immediate progress
  and report when the stale lock was removed.

## 1.1.3

- Added support for `analyzer` 14 while retaining compatibility with analyzer 7
  and Dart 3.6.

## 1.1.2

- Replaced relative README screenshot paths with absolute repository URLs so
  pub.dev renders the live report and Git diff images instead of alt text.
- Fixed Git repository-root validation on Windows when Git uses forward slashes
  and Dart reports the same path with backslashes.

## 1.1.1

- Added pub.dev screenshots for the searchable live report and local Git diff
  viewer, and moved the live demo link to the top of the package README.

## 1.1.0

- Styled the linked `aso.dev` credit in the local viewer with its own blue
  accent and hover state.
- Compacted the file toolbar to two rows, keeping Git filtering and Tree/List
  controls visible while moving folder actions and Show ignored into a keyboard
  accessible menu. Visible ignored files have a removable status indicator.
- Added quick source-file opening and Copy log / Copy errors with actual run
  commands, filters, results and diagnostic context for AI, including explicit
  truncation notices and a manual clipboard fallback.
- Preserved log scroll/selection on polling and new output; manual scrolling
  pauses Follow logs, with resume at the end or through the checkbox.
- Added a resizable Tests panel with saved height and actual variant dropdowns
  loaded from ff_golden, compatible-choice filtering, matching counts, and
  coverage-only advanced filters. Discovery uses the existing queue/logs/Stop
  controls and never falls back to golden execution on unsupported runners.
- Limited Tests discovery, folder/project counts, and queues to golden test
  files, identified by ff_golden calls, explicit golden tags, or run manifests.
- Extended Tests to project, folder, file, scenario, and image-selection scopes,
  with static Dart/manifest discovery, deduplicated per-file queues, exact scoped
  filters, included-command previews, progress, and cancellation of pending files.
- Added a Tests panel to `diff`: explicit test-file selection, combined variant
  filters, command preview, bounded live logs, exit status, and process-tree
  cancellation on macOS/Linux. Image menus can suggest a source test from run
  manifests. Runs verify goldens without updating baselines; `--flutter` selects
  an SDK explicitly.
- Added `diff`, a loopback Git image viewer with staged/unstaged groups,
  side-by-side, swipe, overlay and pixel-diff modes, zoom, synchronized scrolling,
  automatic refresh, and selected-file stage/unstage with stale-selection checks.
- Added a collapsible file tree with folder selection, adjustable side-by-side
  change highlighting, cursor-centered zoom, drag-to-pan, and zoom-to-changes.
- Added `.golden_ignore` for persistent, reversible diff exclusions, with
  single-file and selected-file actions, ignored-file visibility, and exact
  repository-relative paths. Golden tests and the Git index are unchanged.
- Simplified the selection toolbar to Stage/Unstage counts and moved ignore
  commands into context menus for files, folders, selections, and image previews,
  with keyboard navigation and visible overflow buttons.
- Stopped unstage when the HEAD lookup is interrupted or fails unexpectedly,
  instead of treating that failure as an unborn branch.

## 1.0.4

- Added reusable report branding with a project primary color, embedded
  favicon, and responsive header navigation links for `report` and `build`.

## 1.0.3

- Grouped scenarios by their first path segment with hierarchical navigation
  and filter-aware group counts.
- Replaced lightbox font glyphs with centered SVG controls and refined the
  responsive and print layouts for grouped reports.

## 1.0.2

- Linked the companion `ff_golden` runner directly from the package README
  displayed on pub.dev.

## 1.0.1

- Completed dartdoc coverage for the public cleanup and catalog-scanning
  surfaces used by project tooling.
- Kept the local Docker URL as code in the README so package links satisfy
  pub.dev's secure-link convention.

## 1.0.0

- Declared the presenter workflow stable after long-term production use of the
  underlying golden-test publication approach.
- Stabilized the existing CLI, public Dart API, report format, optimization
  pipeline, migration tooling, and failure-artifact cleanup without behavioral
  changes from `0.1.1`.

## 0.1.1

- Added a guarded `clean-failures` command with dry-run support for removing
  generated golden comparison images without touching baseline images.

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
- Moved into the `asodevapp/golden` Pub workspace as the companion publication package for `ff_golden`.
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
- Added the hosted FF Golden guide and moved the live report below `/demo/` in
  the shared documentation site.

## 0.0.3

- Initial version.
