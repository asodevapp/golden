---
title: Runner CLI reference
description: Discover, update, and verify Flutter golden tests with deterministic project defaults and transparent Flutter argument forwarding.
---

# Runner CLI reference

Run the executable through the project's locked development dependency:

```shell
flutter pub run ff_golden <command> [runner options] [flutter test arguments]
```

Use Flutter's Pub runner because `ff_golden` declares Flutter SDK dependencies;
the standalone Dart runner cannot resolve a Flutter package executable.

## Commands

| Command | Purpose |
| --- | --- |
| `test` | Verify golden baselines without changing them. |
| `verify` | Alias for `test`, useful as an explicit CI step. |
| `update` | Run in `--update-goldens` mode so changed baselines can be reviewed. |

Every command delegates to the Flutter SDK selected by the project. The runner
looks for `.fvm/flutter_sdk/bin/flutter` first, then `FLUTTER_ROOT`, then the
Flutter SDK that launched Dart, and finally `flutter` on `PATH`.

## Defaults

Without explicit test paths, the runner recursively discovers and sorts
`test/**/*_golden_test.dart`. It then invokes Flutter with:

```text
flutter test --no-pub --tags=golden --concurrency=8 <discovered files>
```

`update` adds `--update-goldens`. If no matching files exist, Flutter performs
its normal test discovery and the tag expression still limits execution.

These defaults replace project scripts that repeat a `find` command and the
full Flutter invocation:

```shell
flutter pub run ff_golden update "$@"
```

For an FVM-managed application, prefix the same command with `fvm`:

```shell
fvm flutter pub run ff_golden update "$@"
```

Arguments not owned by FF Golden are forwarded unchanged. A focused update can
therefore stay readable:

```shell
flutter pub run ff_golden update test/screens/login_golden_test.dart \
  --plain-name 'loaded page'
```

Use `--` when an argument must bypass runner option parsing completely.

## Runner options

| Option | Effect |
| --- | --- |
| `--concurrency <jobs>` | Override the default eight parallel test processes. `-j` is accepted too. |
| `--tags <expression>` | Override the default `golden` tag expression. |
| `--test-root <path>` | Scan another root for `*_golden_test.dart`. |
| `--all-tests` | Skip file discovery and let Flutter scan the complete test tree. |
| `--pub` | Allow Flutter to resolve packages before running; the default is `--no-pub`. |
| `--flutter <path>` | Use an explicit Flutter executable. |
| `--dry-run` | Print the resolved command without executing it. |
| `--print-command` | Print the command before executing it. |

Start with dry-run when replacing an existing project script:

```shell
flutter pub run ff_golden update --dry-run
```

Baseline updates remain an approval operation. Review every added, changed, and
deleted PNG, then run `flutter pub run ff_golden test` before committing.

Report collection, failure-artifact cleanup, staged PNG optimization, and HTML
publication remain separate `ff_golden_presenter` responsibilities.
