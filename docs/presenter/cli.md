---
title: Presenter CLI reference
description: Command and option reference for ff_golden_presenter build, collect, optimize, report, doctor, and migrate actions.
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

With no action, the legacy report-only invocation remains compatible.

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
