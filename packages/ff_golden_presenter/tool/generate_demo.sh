#!/usr/bin/env sh
set -eu

repository_directory=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repository_directory"

flutter pub run ff_golden_presenter:ff_golden_presenter report \
  --input example/goldens \
  --output example/report.html \
  --title "FF Golden Presenter demo"
