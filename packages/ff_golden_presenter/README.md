# FF Golden Presenter

FF Golden Presenter turns Flutter and Dart golden test images into a searchable, portable HTML report. It can also collect screenshots into an isolated staging directory, optimize PNG files, and produce the complete publication artifact in one command.

The generated page has no runtime dependencies. Open it locally, attach the whole directory to CI, or serve it as a static site. It includes scenario navigation, search and variant filters, remembered light/dark themes, responsive cards, a keyboard-friendly lightbox, and relative image URLs.

## Quick start

Add FF Golden Presenter to the Flutter or Dart project that owns the golden
tests as a project-local development dependency:

```shell
flutter pub add --dev ff_golden_presenter
```

Use `dart pub add --dev ff_golden_presenter` in a pure Dart project. Commit the
application pubspec and lockfile so developers and CI resolve the same version.

Build a publication directory from the conventional `test/screens` tree:

```shell
dart run ff_golden_presenter build \
  --input test/screens \
  --manifest build/ff_golden \
  --output-directory build/golden-report \
  --profile balanced \
  --clean
```

The result is self-contained:

```text
build/golden-report/
├── index.html
└── feature/golden/scenario/*.png
```

`--manifest` accepts a schema-v1/v2 `ff_golden.run` file or a directory of
runner shards. The default is `build/ff_golden`; a missing default is harmless.
When manifests are present, the report exposes authoritative capture, device,
theme, locale, text-scale, direction, platform, brightness, contrast, status,
duration, and failure information as searchable badges and filters.

`build` always optimizes the copied files, never the source goldens. The `balanced` profile uses `pngquant` when available and falls back to ImageMagick. Check the machine before the first run:

```shell
dart run ff_golden_presenter doctor --profile balanced
```

To install the compatible tool reported for macOS, Linux, or Windows, opt in explicitly:

```shell
dart run ff_golden_presenter doctor --profile balanced --install-tools
```

No optimizer is required when byte-for-byte copies are preferred:

```shell
dart run ff_golden_presenter build --profile none --clean
```

The equivalent manual dependency is:

```yaml
dev_dependencies:
  ff_golden_presenter: ^0.1.0
```

For an unreleased repository revision, use the package Git source and
`path: packages/ff_golden_presenter`. For a local checkout, use
`path: ../golden/packages/ff_golden_presenter`.

### Renaming from `golden_presenter`

The package and primary executable are now named `ff_golden_presenter` to match the Flutter Files infrastructure family such as `ff_bloc`:

```dart
import 'package:ff_golden_presenter/ff_golden_presenter.dart';
```

```shell
dart run ff_golden_presenter build
```

This is a package-name migration, so update all three surfaces together: the `dev_dependency` key, `package:` imports, and `dart run` command. Dart resolves `dart run golden_presenter` as the old package name; an executable alias inside the renamed package cannot transparently preserve that command.

See [MIGRATION.md](MIGRATION.md) for the complete presenter procedure. After
bootstrapping the new dependency, the CLI can preview, apply, and verify the
deterministic parts:

```shell
dart run ff_golden_presenter migrate --project .
dart run ff_golden_presenter migrate --project . --apply
dart run ff_golden_presenter migrate --project . --check
```

## Actions

Run `dart run ff_golden_presenter --help` for the action list and `<action> --help` for all flags.

| Action | Purpose |
| --- | --- |
| `build` | Collect images, optimize staged PNG files, and create `index.html`. |
| `collect` | Copy supported images recursively while preserving relative paths. |
| `optimize` | Optimize PNG files already in a staging directory. Requires `--in-place`. |
| `report` | Generate only the HTML file from an existing image tree. |
| `doctor` | Detect compatible tools and print a platform-specific install command. |
| `migrate` | Preview/apply safe package renames and report manual migration work. |
| `clean-failures` | Delete generated comparison images below `failures` directories. |

The original report-only invocation remains compatible:

```shell
dart run ff_golden_presenter \
  --input test \
  --output golden-report.html \
  --title "My app golden tests"
```

It is equivalent to `dart run ff_golden_presenter report ...`. With no arguments it scans `test/` and writes `golden-report.html`.

### Publication flags

The main `build` options are:

| Option | Default | Purpose |
| --- | --- | --- |
| `-i, --input <directory>` | `test/screens` | Source screenshots copied recursively. |
| `-o, --output-directory <directory>` | `build/golden-report` | Isolated publication directory. |
| `--report-file <filename>` | `index.html` | HTML file inside the publication directory. |
| `-p, --profile <name>` | `balanced` | `none`, `lossless`, `balanced`, or `small`. |
| `--backend <name>` | `auto` | `auto`, `pngquant`, `oxipng`, or `imagemagick`. |
| `-j, --jobs <count>` | CPU count | Maximum concurrent optimizer processes. |
| `--clean` | off | Remove the guarded output directory before copying. |
| `--install-tools` | off | Install a compatible missing optimizer. |
| `--dry-run` | off | Inspect the pipeline without writing or installing. |
| `--title <text>` | `Golden test report` | Heading displayed in the report. |
| `-g, --golden-directory <name>` | `golden` | Directory marker used to discover scenarios. |
| `--extensions <list>` | `png,jpg,jpeg,webp,svg` | Image extensions copied and included. |
| `--manifest <path>` | `build/ff_golden` | Runner manifest file or shard directory; repeatable. |
| `--[no-]support-attribution` | on | Show or remove the ASO.dev support attribution in the report footer. |

`--clean` refuses dangerous targets such as the filesystem root, home, repository root, input directory, or an ancestor of the input. Existing output is otherwise left intact unless the flag is passed.

### Cleaning failure images

Flutter's local golden comparator writes diagnostic PNGs into `failures`
directories. Preview and remove those generated images explicitly:

```shell
dart run ff_golden_presenter clean-failures \
  --input test/screens \
  --dry-run

dart run ff_golden_presenter clean-failures \
  --input test/screens
```

The command deletes only configured image extensions below directories named
exactly `failures`. It does not follow symlinks, remove non-image diagnostics,
or touch files elsewhere. Filesystem root and home-directory inputs are
rejected. Pass `--extensions png,jpg,jpeg,webp` to change the default PNG-only
selection.

Published reports include a visible “Made by the ASO.dev team” footer by
default. The link is marked as sponsored and includes a referral source. Projects
that require an unbranded report can pass `--no-support-attribution`; the
FF Golden Presenter generator credit remains intact.

The generated `<head>` also includes description, Open Graph, and Twitter card
metadata derived from the report title and catalog size.

### Optimization profiles

| Profile | Preferred backend | Behavior |
| --- | --- | --- |
| `none` | none | Copies images without changing them. |
| `lossless` | `oxipng` | Pixel-lossless PNG recompression; ImageMagick is the fallback. |
| `balanced` | `pngquant` | High-quality `75-95` quantization for normal publication. |
| `small` | `pngquant` | Stronger `55-80` quantization and slower compression. |

Optimized output replaces a staged file only when it is smaller. Other formats are copied but not changed. To force a backend, pass `--backend`; incompatible combinations such as `lossless + pngquant` fail with a clear error.

Standalone optimization is intentionally explicit because it changes files:

```shell
dart run ff_golden_presenter optimize \
  --input build/golden-report \
  --profile lossless \
  --in-place
```

Use `optimize --dry-run` to inspect the PNG count without changing anything.

### Tool support

All processes are launched directly rather than through a shell, so paths and arguments work consistently on macOS, Linux, and Windows.

| Platform | Automatic installation used by `--install-tools` |
| --- | --- |
| macOS | Homebrew packages for `pngquant`, `oxipng`, or ImageMagick; Cargo is an `oxipng` fallback. |
| Linux | `apt-get`, `dnf`, or `pacman` for `pngquant`/ImageMagick; Cargo for `oxipng`. |
| Windows | ImageMagick through `winget`; Cargo for `oxipng`. `pngquant` can also be installed manually. |

`doctor` prints the exact command it would use and official manual-install links when no supported package manager is found. See the upstream installation pages for [pngquant](https://pngquant.org/install.html), [oxipng](https://github.com/oxipng/oxipng), [ImageMagick](https://imagemagick.org/download/), and [Windows Package Manager](https://learn.microsoft.com/windows/package-manager/winget/install).

## Expected directory and filename structure

FF Golden Presenter collects every configured image format under `--input`, but the report includes only files below a directory named `golden`:

```text
test/
└── screens/
    └── authentication/
        └── golden/
            └── sign_in/
                ├── iphone_15[light](en-US).png
                └── iphone_15[dark](en-US).png
```

The `golden` marker is removed from the displayed breadcrumb. The example becomes the `authentication / sign_in` scenario when `test/screens` is the input.

Runner variants use this filename convention by default:

```text
[capture.]device[theme](locale){text-scale}{direction}{platform}{brightness}{contrast}.extension
```

Only `device` is required. Dots in device names, such as `iPadPro12.9`, are
preserved. A filename alone cannot distinguish a dotted device from the
optional multi-shot prefix, so `ff_golden.run` metadata is authoritative for
capture names. Without a manifest, the complete prefix before the first
structured suffix is treated as the device. Custom `--device-pattern`,
`--theme-pattern`, and `--locale-pattern` values use Dart `RegExp` syntax and
must contain a capture group.

## Demo

The repository contains a deterministic catalog under [`example/goldens`](example/goldens). Regenerate the checked-in [`example/report.html`](example/report.html):

Open the [live FF Golden demo](https://asodevapp.github.io/golden/demo/), rebuilt and
deployed to GitHub Pages from the `master` branch.

```shell
./tool/generate_demo.sh
```

To exercise the full staging pipeline without an external optimizer:

```shell
dart run ff_golden_presenter build \
  --input example/goldens \
  --output-directory build/demo \
  --profile none \
  --clean \
  --title "FF Golden Presenter demo"
```

## Docker publication

The repository includes a multi-stage [`Dockerfile`](Dockerfile). Its generator stage creates the complete report, while the runtime stage contains only the static files and an unprivileged nginx server listening on port `8080`.

Run the demo locally with one command:

```shell
docker compose up --build
```

Open <http://localhost:8080>. The image also exposes `/healthz` for container health checks.

For a Flutter project, copy `Dockerfile`, `.dockerignore`, and `docker/nginx.conf`, then build with project-specific arguments:

```shell
docker build \
  --build-arg SDK_IMAGE=ghcr.io/cirruslabs/flutter:stable \
  --build-arg "PUB_GET_COMMAND=flutter pub get" \
  --build-arg GOLDEN_INPUT=test/screens \
  --build-arg OPTIMIZATION_PROFILE=balanced \
  --build-arg INSTALL_TOOLS=true \
  --tag my-app-golden-report .

docker run --rm --publish 8080:8080 my-app-golden-report
```

Available build arguments:

| Argument | Default | Purpose |
| --- | --- | --- |
| `SDK_IMAGE` | `dart:stable` | SDK used by the generator stage. |
| `PUB_GET_COMMAND` | `dart pub get` | Dependency command; use `flutter pub get` for Flutter projects. |
| `GOLDEN_INPUT` | `example/goldens` | Screenshot directory inside the build context. |
| `REPORT_TITLE` | `FF Golden Presenter demo` | Generated page title. |
| `OPTIMIZATION_PROFILE` | `none` | Publication optimization profile. |
| `OPTIMIZATION_BACKEND` | `auto` | Explicit or automatically resolved optimizer. |
| `OPTIMIZATION_JOBS` | `4` | Concurrent optimization processes. |
| `INSTALL_TOOLS` | `false` | Allow the generator stage to install its optimizer. |

The final image does not contain Dart, Flutter, package caches, source code, or optimizer binaries. The nginx configuration disables server-version disclosure, adds basic security headers, avoids caching `index.html`, and gives images a short cache lifetime.

## CI/CD templates

Copy-ready templates live under [`example/ci`](example/ci):

- [GitHub Pages](example/ci/github-pages.yml) builds the report and deploys it with the official Pages artifact flow.
- [GitHub Container Registry](example/ci/github-container.yml) builds the Dockerfile and publishes commit plus `latest` tags to GHCR.
- [GitLab Pages](example/ci/gitlab-pages.yml) publishes the generated `public/` directory.
- [GitLab Container Registry](example/ci/gitlab-container.yml) builds and pushes commit plus `latest` container tags.

The templates target Flutter repositories and `test/screens` by default. For pure Dart projects, switch their setup step or SDK image as explained in the accompanying [`example/ci/README.md`](example/ci/README.md).

## Migrating a project shell script

A project no longer needs to copy files, check `pngquant`, or globally activate the package itself. Replace a pipeline like `scripts/_build_golden.sh` with the project-local command:

```shell
dart run ff_golden_presenter clean-failures --input test/screens

dart run ff_golden_presenter build \
  --input test/screens \
  --output-directory goldens \
  --report-file index.html \
  --profile balanced \
  --clean
```

Use `--install-tools` only on machines where the job is allowed to change system packages. For immutable CI images, run `doctor` and install the printed dependency in the image setup instead.

Legacy `--path`, `-p`, and `--test-path` remain accepted by the default/report-only command. New actions use `-p` for the optimization profile.

## Use in CI

Run the command after golden tests and upload the entire output directory as one artifact:

```yaml
- name: Build golden publication
  run: >-
    dart run ff_golden_presenter build
    --input test/screens
    --output-directory build/golden-report
    --profile balanced
    --clean
- uses: actions/upload-artifact@v4
  with:
    name: golden-report
    path: build/golden-report
```

## Project-local installation

Keep the executable in project `dev_dependencies`. This makes the version part
of the application lockfile and keeps local development and CI on the same
toolchain. A global activation is intentionally not part of the supported
repository workflow.

## Development

```shell
flutter pub get
cd packages/ff_golden_presenter
dart format --output=none --set-exit-if-changed .
dart analyze
flutter test
./tool/generate_demo.sh
```

The workspace contains the Flutter-based `ff_golden` package, so repository
scripts use the Flutter-aware Pub runner. Consumer projects still invoke the
installed executable with `dart run ff_golden_presenter` as shown above.

The public library entrypoint is `package:ff_golden_presenter/ff_golden_presenter.dart`; CLI implementation details live under `lib/src/`.

## Project support

FF Golden Presenter is part of the Flutter Files infrastructure and is
developed with support from [ASO.dev](https://aso.dev/).
