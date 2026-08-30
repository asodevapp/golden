# Publishing packages

The workspace root is private. Publish only an individual package from its own
directory.

## Prepare a release

1. Update the package version and `CHANGELOG.md`.
2. For `ff_golden_presenter`, keep `pubspec.yaml` and
   `lib/src/cli_options.dart` on the same version.
3. Commit and push the exact release source. Confirm that the package worktree
   is clean before publishing.
4. Confirm that the account is authenticated with pub.dev and has access to the
   package publisher.

## Publish `ff_golden_presenter`

Run from `packages/ff_golden_presenter`:

```shell
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
flutter test
./tool/generate_demo.sh
git diff --exit-code -- example/report.html
flutter pub publish --dry-run
flutter pub publish
```

## Publish `ff_golden`

Run from `packages/ff_golden`:

```shell
dart format --output=none --set-exit-if-changed bin lib test example
flutter analyze
flutter test
flutter pub run ff_golden --version
flutter pub run ff_golden update --dry-run
flutter pub publish --dry-run
flutter pub publish
```

## Verify

Wait until pub.dev exposes the new version, then verify it from a consumer
project rather than the workspace:

```shell
flutter pub upgrade ff_golden_presenter
dart run ff_golden_presenter --version
dart run ff_golden_presenter clean-failures --input test/screens --dry-run
```

For the runner package, upgrade it and verify the hosted executable from the
consumer project:

```shell
flutter pub upgrade ff_golden
flutter pub run ff_golden --version
flutter pub run ff_golden update --dry-run
```

Never publish from the repository root.
