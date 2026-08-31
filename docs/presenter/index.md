---
title: FF Golden Presenter
description: Review local golden changes, run filtered tests, and publish searchable portable HTML reports.
---

# FF Golden Presenter

Package: [`ff_golden_presenter` on pub.dev](https://pub.dev/packages/ff_golden_presenter)

FF Golden Presenter reviews local Git image changes, runs selected golden tests,
and turns Flutter and Dart golden images into a searchable, portable HTML report.
The generated report has no runtime dependencies and uses relative image URLs,
so the whole output directory can be opened locally, attached to CI, published
to Pages, or served by a container.

[Open the live report](https://asodevapp.github.io/golden/demo/){ .md-button .md-button--primary }

## Install project-locally

```shell
flutter pub add --dev ff_golden_presenter
```

Use `dart pub add --dev ff_golden_presenter` in a pure Dart project. Keep the
version in the application lockfile rather than globally activating the CLI.

## Review local changes

```shell
dart run ff_golden_presenter diff
```

The loopback-only viewer shows staged and unstaged PNG, JPEG, and WebP changes
in tree or list form. Compare versions side by side, by swipe, overlay, or pixel
diff; zoom and highlight changes on the new version; then stage or unstage only
the selected files. Secondary file actions live in context menus, including
reversible `.golden_ignore` exclusions.

Open **Tests** to run a project, folder, file, scenario, or image selection with
live logs. With `ff_golden` 1.3.0 or newer, **Load variants** reads the planned
devices, themes, locales, scale, direction, platform, and contrast without
calling golden builders or updating baselines. See the
[CLI reference](cli.md#diff) for scope rules, safety limits, and shortcuts.

## Build a publication directory

```shell
dart run ff_golden_presenter build \
  --input test/screens \
  --manifest build/ff_golden \
  --output-directory build/golden-report \
  --profile balanced \
  --clean
```

The output is self-contained:

```text
build/golden-report/
├── index.html
└── feature/golden/scenario/*.png
```

`build` collects images into the isolated output directory, optimizes only
those staged copies, loads runner manifests, and generates the report.

!!! note "Source baselines remain untouched"
    Publication profiles never optimize files below the input tree. Standalone
    in-place optimization requires an explicit `--in-place` acknowledgement.

## What the report provides

- scenario navigation and search;
- device, theme, locale, text scale, direction, platform, brightness, and
  contrast filters;
- pass/fail status, duration, overflow count, and failure phase;
- multi-shot capture names and standard Flutter diff artifacts;
- responsive cards, keyboard-friendly lightbox, and remembered theme;
- a single static artifact with no server-side runtime.

## Why manifests matter

Filename parsing is intentionally available for ordinary golden directories.
An `ff_golden.run` schema-v2 manifest is authoritative when present because it
can distinguish capture names from dotted device names and carries execution
status that an image alone cannot express.

Pass either one manifest or a directory of shards. The default
`build/ff_golden` is harmless when absent.

## Optimization profiles

| Profile | Preferred backend | Behavior |
| --- | --- | --- |
| `none` | none | Copy without changing image bytes |
| `lossless` | `oxipng` | Lossless PNG recompression |
| `balanced` | `pngquant` | High-quality `75–95` web quantization |
| `small` | `pngquant` | Stronger `55–80` quantization |

ImageMagick is the portable fallback. Output replaces a staged file only when
the optimized result is smaller.

Check the current machine before enabling optimization:

```shell
dart run ff_golden_presenter doctor --profile balanced
```

## Attribution

Published reports show “Made with support from ASO.dev” by default. The link is
marked as sponsored. Projects requiring an unbranded report can pass:

```shell
dart run ff_golden_presenter build --no-support-attribution
```

The FF Golden Presenter generator credit remains present.

## Next steps

- See the complete [CLI reference](cli.md).
- Build a failure artifact in [CI](../guides/ci.md).
- Follow [Migration](../migration.md) when replacing `golden_presenter`.
