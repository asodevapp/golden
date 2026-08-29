# Flutter Files Golden

Golden-test infrastructure for the Flutter Files toolchain. This repository is
a native Dart Pub workspace; the repository root is private and each product is
an independently versioned, publishable package.

## Packages

| Package | Responsibility |
| --- | --- |
| [`ff_golden`](packages/ff_golden) | Flutter golden execution, device fidelity, scenario matrices, comparison, and diagnostics. |
| [`ff_golden_presenter`](packages/ff_golden_presenter) | Project-local CLI for collecting, optimizing, browsing, and publishing golden artifacts. |

Read the [FF Golden documentation](https://gorniv.github.io/golden/) or explore
the generated report in the
[live FF Golden demo](https://gorniv.github.io/golden/demo/).

## Codex skill

This repository includes the repo-local [`$ff-golden`](.agents/skills/ff-golden/SKILL.md) skill for building new matrix suites, preserving legacy baselines during migration, diagnosing pixel diffs, and producing presenter reports. Codex can discover it automatically while working in this checkout, or it can be invoked explicitly as `$ff-golden`.

The boundary is intentional: test execution stays Flutter-focused, while HTML,
image optimization, Docker, and CI publication stay in the presenter package.
No Melos or globally activated executable is required.

## Add to a project

Add one or both published packages as project-local development dependencies:

```shell
flutter pub add --dev 'ff_golden:^1.0.0-dev.1'
flutter pub add --dev ff_golden_presenter
```

To test an unreleased repository revision, replace the hosted constraints with
Git dependencies that use the matching `path` values from the package table.

Run golden tests, then build the static publication artifact:

```shell
flutter test
dart run ff_golden_presenter build \
  --input test/screens \
  --manifest build/ff_golden \
  --output-directory build/golden-report \
  --profile balanced \
  --clean
```

Migrating an existing project? Follow the end-to-end
[`golden`/`golden_presenter` migration guide](MIGRATION.md), including the safe
preview/apply/check command and baseline review procedure.

## Develop the workspace

Resolve the shared dependency graph once from the repository root:

```shell
flutter pub get
dart pub workspace list
```

Run package checks from their directories:

```shell
cd packages/ff_golden
flutter analyze
flutter test

cd ../ff_golden_presenter
dart analyze --fatal-infos
flutter test
./tool/generate_demo.sh
```

The checked-in GitHub Actions workflow performs these checks and exercises the
presenter on Linux, macOS, and Windows. A separate integration job produces
multi-shot runner baselines plus sharded metadata, then verifies that presenter
retains the exact device and every matrix axis.

Build the documentation locally with:

```shell
python3 -m pip install -r requirements-docs.txt
python3 -m mkdocs build --strict
python3 -m mkdocs serve
```

GitHub Pages publishes this guide at the site root and the generated presenter
report below `/demo/` as one static artifact.

## One-command demo

Build the presenter and serve its deterministic light/dark report through the
production nginx image:

```shell
docker compose up --build
```

Open <http://localhost:8080>. Copy-ready GitHub and GitLab Pages/container
templates live in
[`packages/ff_golden_presenter/example/ci`](packages/ff_golden_presenter/example/ci).

## License

Both packages are available under the MIT License.
