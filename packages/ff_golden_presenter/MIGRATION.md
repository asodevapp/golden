# Migrating from golden_presenter to ff_golden_presenter

For the coordinated runner migration, baseline review, CI, and rollback, use the
[complete Flutter Files migration guide](https://github.com/Gorniv/golden/blob/master/MIGRATION.md).

## Dependency

Replace the old standalone package with the published package:

```yaml
dev_dependencies:
  ff_golden_presenter: ^0.1.0
```

For an unreleased repository revision, pin the Git dependency to a commit and
use `path: packages/ff_golden_presenter`.

Run `flutter pub get` for a Flutter application or `dart pub get` for a pure
Dart project. Commit the application lockfile.

## Audit and apply

The default mode is a read-only preview:

```shell
dart run ff_golden_presenter migrate --project .
```

Apply deterministic package, import, public type, repository, workspace-path,
and command renames, then resolve every reported manual review:

```shell
dart run ff_golden_presenter migrate --project . --apply
dart run ff_golden_presenter migrate --project . --check
```

`--check` exits with code `1` until the project is clean. The migrator ignores
`.dart_tool`, `.git`, `.idea`, `build`, `coverage`, `node_modules`, `Pods`, and
files larger than 2 MiB. It does not delete baselines or modify device geometry.
It safely replaces public `Device`/`NamedTheme` aliases and sorts the migrated
`ff_golden` import; custom `Device(size:)`, deprecated `.size` reads, and
`postPumping` remain explicit manual reviews.

## Imports and commands

```diff
- import 'package:golden_presenter/golden_presenter.dart';
+ import 'package:ff_golden_presenter/ff_golden_presenter.dart';
```

```diff
- flutter pub run golden_presenter:golden_presenter
- dart pub global run golden_presenter
+ dart run ff_golden_presenter
```

There is no global activation step. Keeping the presenter in
`dev_dependencies` locks local development and CI to the same revision.

## Replace custom shell pipelines

Use the project-local publication pipeline instead of copying images and
invoking optimizers manually:

```shell
dart run ff_golden_presenter build \
  --input test/screens \
  --manifest build/ff_golden \
  --output-directory build/golden-report \
  --profile none \
  --clean
```

Validate with `--profile none` first. Later, use `doctor --profile balanced` and
enable a publication optimization profile if wanted. Optimization only changes
staged report copies.

Upload or serve the entire `build/golden-report` directory because image URLs
inside `index.html` are relative.
