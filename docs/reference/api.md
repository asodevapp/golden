---
title: API reference
description: Find generated ff_golden and ff_golden_presenter API documentation, package pages, source code, examples, and local dartdoc commands.
---

# API reference

The guides explain behavior and decisions. Generated dartdoc remains the source
for public constructor signatures, members, and documentation comments.

## Published packages

- [`ff_golden` on pub.dev](https://pub.dev/packages/ff_golden)
- [`ff_golden_presenter` on pub.dev](https://pub.dev/packages/ff_golden_presenter)

After publication, pub.dev generates version-specific API documentation for
each public library.

## Public entrypoints

```dart
import 'package:ff_golden/ff_golden.dart';
import 'package:ff_golden_presenter/ff_golden_presenter.dart';
```

`package:ff_golden/golden.dart` is a deprecated compatibility entrypoint. New
code should use `ff_golden.dart`. Do not import files below `lib/src/`.

## Generate API docs locally

Run Pub resolution first, then generate or validate each package:

```shell
cd packages/ff_golden
flutter pub get
dart doc .
dart doc --dry-run .
```

```shell
cd packages/ff_golden_presenter
flutter pub get
dart doc .
dart doc --dry-run .
```

Generated files are written below `doc/api` by default and are intentionally
ignored by Git. Serve that directory over HTTP for working search.

## Source and examples

- [Runner public exports](https://github.com/asodevapp/golden/blob/master/packages/ff_golden/lib/ff_golden.dart)
- [Runner example](https://github.com/asodevapp/golden/blob/master/packages/ff_golden/example/ff_golden_example_test.dart)
- [Presenter public exports](https://github.com/asodevapp/golden/blob/master/packages/ff_golden_presenter/lib/ff_golden_presenter.dart)
- [Presenter demo sources](https://github.com/asodevapp/golden/tree/master/packages/ff_golden_presenter/example)
