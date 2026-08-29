# Demo catalog

This directory is a runnable example of the input convention and generated output.

From `packages/ff_golden_presenter`:

```shell
./tool/generate_demo.sh
```

Open `report.html` locally. Do not edit it by hand; CI regenerates the file and verifies that it stays in sync with the renderer and the SVG fixtures.

To demonstrate collection and publication as well, run:

```shell
dart run ff_golden_presenter build \
  --input example/goldens \
  --output-directory build/demo \
  --profile none \
  --clean \
  --title "FF Golden Presenter demo"
```

This copies the fixtures and creates `build/demo/index.html` without requiring an external PNG optimizer.

Alternatively, build and serve the demo through the production container:

```shell
docker compose up --build
```

Open <http://localhost:8080>. Copy-ready GitHub and GitLab publication workflows are available in [`ci/`](ci/).
