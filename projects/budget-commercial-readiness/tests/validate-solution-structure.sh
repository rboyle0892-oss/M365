#!/usr/bin/env bash
set -euo pipefail

ROOT="projects/budget-commercial-readiness/src/solution"

required_files=(
  "$ROOT/[Content_Types].xml"
  "$ROOT/solution.xml"
  "$ROOT/customizations.xml"
  "$ROOT/Workflows/BCR_Readiness_Request_Generator-Flow.json"
)

for f in "${required_files[@]}"; do
  [[ -f "$f" ]] || { echo "Missing required file: $f" >&2; exit 1; }
done

if rg -n "REPLACE-ORG" "$ROOT/Workflows/BCR_Readiness_Request_Generator-Flow.json" >/dev/null; then
  echo "Flow still contains REPLACE-ORG placeholder. Configure OrgUrl parameter during deployment." >&2
  exit 1
fi

if ! rg -n '"entityName": "bcr_readinesstasks"' "$ROOT/Workflows/BCR_Readiness_Request_Generator-Flow.json" >/dev/null; then
  echo "Flow does not target bcr_readinesstasks as required." >&2
  exit 1
fi

echo "Solution structure validation passed."
