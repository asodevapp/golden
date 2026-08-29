---
title: CI and publication
description: Run sharded FF Golden suites, merge authoritative manifests, publish portable presenter reports, and deploy a static artifact to CI or Pages.
---

# CI and publication

CI has two separate responsibilities: verify visual contracts with
`ff_golden`, then publish evidence with `ff_golden_presenter`. A report must not
turn a failed comparison into a pass.

## Produce isolated manifest shards

Create one `JsonGoldenReporter` per test file and give it a unique `shardName`:

```dart
final reporter = JsonGoldenReporter(
  'build/ff_golden',
  shardName: 'authentication-goldens',
);
```

The runner writes `build/ff_golden/authentication-goldens.ff-golden-run.json`.
Separate test isolates never write the same file, and presenter merges every
shard from the directory.

Start CI from an empty `build/ff_golden` directory. Otherwise a shard belonging
to a deleted test file can survive from an earlier cached job.

## Minimal artifact job

```yaml
- name: Run golden tests
  run: flutter test --tags ff_golden

- name: Build golden report
  if: always()
  run: >-
    dart run ff_golden_presenter build
    --input test/screens
    --manifest build/ff_golden
    --output-directory build/golden-report
    --profile none
    --clean

- name: Upload golden report
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: golden-report
    path: build/golden-report
```

`if: always()` keeps failure evidence available after a comparison failure. The
test step still determines the job result.

## Manifest-first reports

When manifests exist, presenter uses them as the authoritative source for:

- capture and dotted device names;
- every matrix axis;
- pass or fail status;
- duration and failure phase;
- overflow count, error, and standard Flutter diff artifacts.

Images without a matching manifest remain browsable through filename parsing,
but they do not have the same execution metadata.

## Optimization in CI

Start with `--profile none`. Once test output is stable, publication can use:

| Profile | Intended use |
| --- | --- |
| `none` | Byte-for-byte staged copies and migration validation |
| `lossless` | Smaller PNGs without pixel changes |
| `balanced` | Normal web publication with high-quality quantization |
| `small` | Size-sensitive publication with stronger quantization |

Run `dart run ff_golden_presenter doctor --profile balanced` in the target
image to discover the required optimizer. Immutable CI images should install
the dependency during image setup rather than use `--install-tools` at runtime.

## GitHub Pages

Presenter output is a static, relative-URL directory and can be uploaded with
the official Pages artifact flow. A copy-ready application template is
available in the repository:

- [GitHub Pages workflow](https://github.com/asodevapp/golden/blob/master/packages/ff_golden_presenter/example/ci/github-pages.yml)
- [GitLab Pages workflow](https://github.com/asodevapp/golden/blob/master/packages/ff_golden_presenter/example/ci/gitlab-pages.yml)
- [Container publication](https://github.com/asodevapp/golden/tree/master/packages/ff_golden_presenter/example/ci)

Upload the complete directory, not only `index.html`, because report image URLs
are relative to the publication root.

## Docker

The presenter package includes a multi-stage Dockerfile. Its runtime image
contains only the generated static artifact and an unprivileged nginx server;
it does not contain Dart, Flutter, source code, Pub caches, or optimizer tools.

Use the container path when reports need a stable internal review URL or an
artifact registry rather than branch-based Pages hosting.
