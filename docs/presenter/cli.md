---
title: Presenter CLI reference
description: Command and option reference for ff_golden_presenter diff, build, collect, optimize, report, doctor, and migrate actions.
---

# Presenter CLI reference

Run the executable through the project's locked development dependency:

```shell
dart run ff_golden_presenter --help
dart run ff_golden_presenter <action> --help
```

## Actions

| Action | Purpose |
| --- | --- |
| `build` | Collect, optimize, and create a complete publication directory |
| `collect` | Copy supported images recursively while preserving relative paths |
| `optimize` | Optimize PNGs already in a staging directory; requires `--in-place` |
| `report` | Generate one HTML file from an existing image tree |
| `doctor` | Detect compatible optimizer tools and print install guidance |
| `migrate` | Preview, apply, or verify deterministic package migration work |
| `diff` | Review local Git image changes and stage/unstage selected files |

With no action, the legacy report-only invocation remains compatible.

## `diff`

```shell
dart run ff_golden_presenter diff
dart run ff_golden_presenter diff --input test/screens
dart run ff_golden_presenter diff --project ../my-app --no-open --port 8088
```

Starts a browser viewer on `127.0.0.1`; stop it with Ctrl-C. Git must be on
`PATH`. `--project` and `--input` default to `.`, with input relative to the
project. The default port is `0` (automatically selected), and the browser opens
automatically unless `--no-open` is passed.

Review **Unstaged** (index versus working tree) and **Staged** (HEAD versus index)
PNG, JPEG, and WebP changes with side-by-side, swipe, overlay, and pixel-diff
views. Switch the sidebar between a flat list and a collapsible folder tree;
folder checkboxes select their matching descendants. The compact two-row sidebar
toolbar contains search, a Git-status dropdown, Tree/List icons, and **⋯** for
expanding/collapsing folders and showing ignored files. An active **+ ignored (N)**
indicator can hide ignored files again with one click. **Highlight changes** adds
an adjustable overlay to the new version only, leaving the old version unchanged.
Zoom uses −/+, an editable
percentage, Fit, Width, 100%, and Changes (focus on the changed area). Ctrl/Cmd +
wheel zooms at the cursor, dragging pans, and double-click toggles 100%/Fit.
The active image has a stage/unstage button; the compact sidebar footer offers
**Stage (N)**, **Unstage (N)**, **×** to clear selection, and **⋯** for more actions.
Right-click files, folders, or the preview for the same action menu. On a checked
file it acts on the selection; otherwise it acts only on that file. Folder
commands apply to visible descendants. The header **⋯** acts on the active image.
Menus support Shift+F10, arrow keys, and Escape. Only selected index entries change. Working images are
not rewritten, and there is no commit, push, discard, or baseline acceptance.
Stale selections are rejected. Changes refresh every two seconds while visible.

The menu's **Ignore** command writes exact paths to `.golden_ignore` at the
Git repository root. Both staged and unstaged versions are hidden from review.
Use **Show ignored** and **Stop ignoring** to restore them; ignored images cannot
be staged or unstaged from the viewer. Selecting a folder adds its selected
files individually. Rules are literal paths, one per line, optionally prefixed
with `/`; blank lines and `#` comments are allowed, but glob patterns are not.
Manual changes to the file reload automatically. This only filters `diff`:
golden tests, reports, image files, and the Git index are unaffected.
The ignore file can be committed separately and is never staged automatically.

**Tests** opens a panel with project/folder/file/scenario scopes, command
preview, live logs, progress, exit status, **Run**, and **Stop**. **Run tests…**
is available in image, folder, selection, and staged/unstaged group menus;
**Run test file(s)…** chooses entire associated test files. Folder scopes include
unchanged files, overlapping scopes are deduplicated, and changing scope keeps
the variant filters. **Included tests & commands** shows the exact queue.

Drag the Tests panel's top divider to change its saved height (keyboard
Up/Down, Shift+Up/Down, Home/End and double-click reset are also available).
**Open test ↗** and the source links in **Included tests & commands** open test
files in the system's default `.dart` application. The ↗ above the log opens the
current/last test from that run, independently of the selected scope.
**Load variants** runs ff_golden discovery for the selected source files, then
fills dropdowns with their actual planned devices, themes, locales and advanced
axes. Imported/generated configuration and sampling are resolved by the runner.
Discovery compiles/initializes test files and may run shared setup hooks, but
does not execute golden builders, scenario callbacks, comparisons or reporters.
Use ff_golden 1.3.0 or newer; unsupported versions fail without running
golden callbacks. Reload variants after changing shared configuration.

Exact device/theme/locale filters work for both `ff_golden` APIs (`-` and `_`
locale separators are equivalent). More filters adds a literal test-name
substring and coverage-only text scale, direction, platform, and high contrast.
Each file gets its own combined scope/variant `--name` expression, so a scenario
name in one file never widens another file's selection.
The UI shows matching variant counts and compatible dropdown choices. Advanced
axes are disabled for legacy tests. Name is a literal substring of the test
name, not the name of a capture. Loaded files with no matches are excluded;
custom tagged tests and files without discovery data retain Flutter filtering.

Files run sequentially from their own package directories with
`flutter test --no-pub --tags=golden --concurrency=1 --reporter=expanded`.
Failures are recorded without aborting later files; the final queue fails if
any file fails. Stop/Ctrl-C terminates the owned process tree and cancels all
pending files. No matches do not fall back to running other tests. The viewer
never passes `--update-goldens`. Dependencies must be installed beforehand.

Discovery lists only golden `*_test.dart` files under `--project`, identified by
ff_golden API calls, literal `golden` tags on tests/groups/libraries, or explicit
source-file entries in run manifests. Folder/project counts and queues use the
same filtered list. Dynamic test names are supported; helper-generated suites
need a golden library tag or run manifest. `--input` and `.golden_ignore`
filter images only. Literal ff_golden declarations and group prefixes are
parsed without executing code; schema-v2 manifests in `build/ff_golden` also
provide capture/source mappings. Dynamic or ambiguous cases require manual
scope/name selection. Partially mapped image selections block automatic scope
selection instead of skipping files. Running a scenario runs all of its captures.

Only one queue can run at a time. Closing the panel/browser leaves it active.
**Copy log** copies the retained output with actual run commands, directories,
scenarios, filters and results for AI. **Copy errors** keeps detected Flutter
error blocks and stacks, falling back to the last 120 retained lines for unknown
failure formats. Active runs and truncated output are marked; changing filters
does not change the copied run context. Neither action resets log scrolling.
A manual copy dialog is available if clipboard access fails. No AI service is
contacted; check logs for secrets before sharing.
Logs stay in memory (latest approximately 512 KiB) until the next queue/server
shutdown. Launching tests currently supports macOS/Linux. Use
`--flutter /path/to/flutter` to override SDK discovery (package FVM,
`FLUTTER_ROOT`, Dart's Flutter SDK, `PATH`). Run only trusted project code.

Original image bytes are used without optimization. Browser pixel counts are
diagnostic and do not replace the runner's comparison result. The MVP excludes
Git LFS previews and symbolic links, shows renames as deletion/addition pairs,
and leaves merge conflicts to your Git client. Previews are limited to 32 MiB per
image and a combined 16-megapixel canvas.

## `build`

```shell
dart run ff_golden_presenter build \
  --input test/screens \
  --output-directory build/golden-report \
  --manifest build/ff_golden \
  --profile balanced \
  --clean
```

| Option | Default | Purpose |
| --- | --- | --- |
| `-i, --input` | `test/screens` | Screenshot source copied recursively |
| `-o, --output-directory` | `build/golden-report` | Isolated publication directory |
| `--report-file` | `index.html` | HTML filename inside the output |
| `--title` | `Golden test report` | Visible report title |
| `-g, --golden-directory` | `golden` | Directory marker for scenario discovery |
| `--extensions` | `png,jpg,jpeg,webp,svg` | Included image extensions |
| `--manifest` | `build/ff_golden` | Manifest file or shard directory; repeatable |
| `-p, --profile` | `balanced` | `none`, `lossless`, `balanced`, or `small` |
| `--backend` | `auto` | `auto`, `pngquant`, `oxipng`, or `imagemagick` |
| `-j, --jobs` | CPU count | Maximum concurrent optimizer processes |
| `--clean` | off | Remove the guarded output directory first |
| `--install-tools` | off | Install a compatible missing optimizer |
| `--dry-run` | off | Inspect the pipeline without changing files |
| `--[no-]support-attribution` | on | Show or remove ASO.dev support attribution |

Custom `--device-pattern`, `--theme-pattern`, and `--locale-pattern` values use
Dart `RegExp` syntax and must contain a capture group.

`--clean` refuses dangerous targets such as a filesystem root, home directory,
repository root, input directory, or an ancestor of the input.

## `collect`

```shell
dart run ff_golden_presenter collect \
  --input test/screens \
  --output-directory build/golden-report \
  --clean
```

Use `--dry-run` to inspect the file count without copying.

## `optimize`

```shell
dart run ff_golden_presenter optimize \
  --input build/golden-report \
  --profile lossless \
  --in-place
```

This action can replace PNGs under its input, so normal execution requires
`--in-place`. `--dry-run` does not require that acknowledgement.

## `report`

```shell
dart run ff_golden_presenter report \
  --input test \
  --output golden-report.html \
  --title "My app golden tests"
```

This creates one HTML file and references images relative to it. Prefer `build`
for isolated, upload-ready artifacts.

## `doctor`

```shell
dart run ff_golden_presenter doctor --profile balanced
```

Add `--install-tools` only when the current machine is allowed to change system
packages. The CLI invokes external processes directly, without a shell, for
portable path and argument handling.

## `migrate`

```shell
dart run ff_golden_presenter migrate --project .
dart run ff_golden_presenter migrate --project . --apply
dart run ff_golden_presenter migrate --project . --check
```

Preview and apply exit successfully after their work even when manual findings
remain. `--check` exits with code `1` while any safe or manual finding remains.
`--apply` and `--check` cannot be combined.
