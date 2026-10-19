#!/usr/bin/env bash
# Gives households made before owners an ownerId, with the Admin SDK. Without
# --apply it only lists what it would set. Uses Application Default
# Credentials (`gcloud auth application-default login`).
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT=pet-health-tracker-2eed5

[ -d firestore-tests/node_modules ] || npm --prefix firestore-tests ci --no-fund --no-audit
node firestore-tests/backfill-owners.js "$PROJECT" "$@"
