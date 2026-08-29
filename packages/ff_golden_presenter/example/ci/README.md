# CI/CD templates

These files are copy-ready examples for a Flutter repository that keeps golden images under `test/screens` and has `ff_golden_presenter` in `dev_dependencies`.

| Template | Copy to | Publishes |
| --- | --- | --- |
| `github-pages.yml` | `.github/workflows/golden-pages.yml` | Static report through GitHub Pages. |
| `github-container.yml` | `.github/workflows/golden-container.yml` | nginx image through GitHub Container Registry. |
| `gitlab-pages.yml` | Merge into `.gitlab-ci.yml` | Static report through GitLab Pages. |
| `gitlab-container.yml` | Merge into `.gitlab-ci.yml` | nginx image through GitLab Container Registry. |

Change `test/screens`, report title, branch rules, or optimization profile to
match the project. The Pages templates run `ff_golden` tests first and merge
any schema-v1/v2 shards found in `build/ff_golden`; projects without a reporter
still receive a filename-derived catalog. For a pure Dart repository, use
`dart pub get` and a Dart SDK image/setup action instead of the Flutter
equivalents.

GitHub Pages must use **Settings → Pages → Build and deployment → GitHub Actions**. GitLab container publishing requires a runner that permits Docker-in-Docker. In production, pin third-party actions and container images to reviewed commit SHAs or image digests according to the repository's dependency policy.
