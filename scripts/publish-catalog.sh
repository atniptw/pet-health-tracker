#!/usr/bin/env bash
# Publishes assets/catalog/symptoms.json to the catalog/symptoms doc with the
# Admin SDK. Publish only what is committed, so the bundled copy and the
# published one come from the same file. Uses Application Default Credentials
# (`gcloud auth application-default login`).
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT=pet-health-tracker-2eed5

if ! git diff --quiet HEAD -- assets/catalog test/data/catalog_keys.txt; then
  echo 'The catalog has uncommitted changes. Commit them first.' >&2
  exit 1
fi
flutter test test/data/catalog_file_test.dart

[ -d firestore-tests/node_modules ] || npm --prefix firestore-tests ci --no-fund --no-audit
node firestore-tests/publish-catalog.js "$PROJECT"
