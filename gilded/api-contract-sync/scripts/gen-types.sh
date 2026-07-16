#!/bin/bash
# api-contract-sync :: gen-types.sh
# Generate TypeScript types from the docs-api FastAPI /openapi.json.
# Dry-run by default: it will NOT install packages and NOT overwrite an existing
# output file unless --force is passed. bash 3.2 safe.
#
# Usage:
#   bash gen-types.sh --api-url http://localhost:8500 \
#        --out <web>/src/lib/api-types.d.ts [--force]
#
# Prefers a locally-available `openapi-typescript` (via npx --no-install).
# If unavailable, prints the exact command to run plus an orval alternative.

set -u

API_URL="http://localhost:8500"
OUT="$HOME/GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works-docs-web/src/lib/api-types.d.ts"
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --api-url) API_URL="${2:-}"; shift 2 ;;
    --out)     OUT="${2:-}"; shift 2 ;;
    --force)   FORCE=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

SPEC="$API_URL/openapi.json"
echo "# gen-types :: spec=$SPEC out=$OUT"

if [ -f "$OUT" ] && [ "$FORCE" -eq 0 ]; then
  echo "NOTE: $OUT already exists. Re-run with --force to overwrite (never hand-edit generated types)."
fi

# Verify the spec is reachable before suggesting a generator.
if command -v curl >/dev/null 2>&1; then
  if ! curl -fsS "$SPEC" >/dev/null 2>&1; then
    echo "WARN: $SPEC is not reachable. Start the API first:"
    echo "      cd ~/GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works-docs-api && uvicorn app.main:app --port 8500"
    echo "      (or pass the deployed --api-url)."
  fi
fi

# Preferred generator: openapi-typescript, only if resolvable without install.
if command -v npx >/dev/null 2>&1 && npx --no-install openapi-typescript --help >/dev/null 2>&1; then
  if [ "$FORCE" -eq 1 ] || [ ! -f "$OUT" ]; then
    echo "RUN: npx --no-install openapi-typescript \"$SPEC\" -o \"$OUT\""
    mkdir -p "$(dirname "$OUT")"
    npx --no-install openapi-typescript "$SPEC" -o "$OUT" \
      && echo "OK: wrote $OUT" \
      || echo "FAILED: generator errored (is the spec reachable?)"
  else
    echo "SKIP: output exists; pass --force to regenerate."
  fi
  exit 0
fi

# Not installed — print, do not install.
cat <<EOF
openapi-typescript is not installed in docs-web. This script never installs it.

To generate types-only (recommended here — the client has no generated runtime):
  cd ~/GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works-docs-web
  npm i -D openapi-typescript
  npx openapi-typescript "$SPEC" -o "$OUT"

Then type a request body against it, e.g.:
  import type { paths } from '@/lib/api-types';
  type BrochureBody =
    paths['/api/v1/brochure']['post']['requestBody']['content']['application/json'];

Alternative — orval (generates a typed client, not just types):
  npm i -D orval
  # orval.config.ts -> input: "$SPEC", output: src/lib/api-client.ts
  npx orval
EOF
exit 0
