#!/usr/bin/env bash
# Publishes firestore.rules through the Firebase Rules API. The firebase CLI
# also checks that the Firestore API is enabled, which needs more access than
# the CI service account has; this needs only Firebase Rules Admin.
# Uses the access token from `gcloud auth print-access-token`.
set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT=pet-health-tracker-2eed5
API="https://firebaserules.googleapis.com/v1/projects/$PROJECT"
TOKEN=$(gcloud auth print-access-token)

ruleset=$(jq -n --rawfile rules firestore.rules \
  '{source: {files: [{name: "firestore.rules", content: $rules}]}}' \
  | curl -sSf -X POST "$API/rulesets" \
      -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d @- \
  | jq -r .name)
echo "created $ruleset"

jq -n --arg name "projects/$PROJECT/releases/cloud.firestore" --arg ruleset "$ruleset" \
  '{release: {name: $name, rulesetName: $ruleset}}' \
  | curl -sSf -X PATCH "$API/releases/cloud.firestore" \
      -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d @- \
  | jq -r '"released \(.rulesetName) as \(.name)"'
