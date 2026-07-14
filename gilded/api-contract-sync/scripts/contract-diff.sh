#!/bin/bash
# api-contract-sync :: contract-diff.sh
# Read-only. Diffs the docs-web client's request shapes against the docs-api
# FastAPI /openapi.json contract (or, offline, against the Pydantic source).
#
# Usage:
#   bash contract-diff.sh [--api-url http://localhost:8500]
#                         [--api-dir  <path to gilded-art-works-docs-api>]
#                         [--web-dir  <path to gilded-art-works-docs-web>]
#
# Exit codes: 0 = no hard drift, 2 = drift found, 1 = usage/error.
# Never writes anything. bash 3.2 safe.

set -u

API_URL=""
ECO="$HOME/GILDED-EDGE-ECOSYSTEM/ventures"
API_DIR="$ECO/gilded-art-works-docs-api"
WEB_DIR="$ECO/gilded-art-works-docs-web"

while [ $# -gt 0 ]; do
  case "$1" in
    --api-url) API_URL="${2:-}"; shift 2 ;;
    --api-dir) API_DIR="${2:-}"; shift 2 ;;
    --web-dir) WEB_DIR="${2:-}"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

MAIN_PY="$API_DIR/app/main.py"
GEN_TSX="$WEB_DIR/src/app/generate/page.tsx"
DRIFT=0

hr() { printf '%s\n' "------------------------------------------------------------"; }
say() { printf '%s\n' "$*"; }

[ -f "$MAIN_PY" ] || { echo "ERROR: cannot find $MAIN_PY" >&2; exit 1; }
[ -f "$GEN_TSX" ] || { echo "ERROR: cannot find $GEN_TSX" >&2; exit 1; }

say "# API Contract Diff"
say "> api-dir: $API_DIR"
say "> web-dir: $WEB_DIR"
say ""

# ── 1. Which /api/v1 routes does the CONTRACT declare? ───────────────────────
CONTRACT_ROUTES=""
CONTRACT_SRC=""
if [ -n "$API_URL" ] && command -v curl >/dev/null 2>&1; then
  JSON=$(curl -fsS "$API_URL/openapi.json" 2>/dev/null)
  if [ -n "$JSON" ]; then
    CONTRACT_SRC="live /openapi.json ($API_URL)"
    # Extract path strings from the "paths" object without a JSON parser.
    CONTRACT_ROUTES=$(printf '%s' "$JSON" \
      | tr ',{}' '\n\n\n' \
      | grep -oE '"/api/v1/[a-zA-Z0-9_/{}-]+"' \
      | tr -d '"' | sort -u)
  fi
fi
if [ -z "$CONTRACT_ROUTES" ]; then
  CONTRACT_SRC="offline: parsed $MAIN_PY decorators"
  CONTRACT_ROUTES=$(grep -oE '@app\.(get|post|put|delete)\("/api/v1/[^"]+"' "$MAIN_PY" \
    | sed -E 's/.*\("//; s/"$//' | sort -u)
fi

# ── 2. Which /api/v1 routes does the CLIENT call? ────────────────────────────
# Strip ${...} interpolations (including unterminated tails like ${result.doc...)
# and any trailing slash so /api/v1/download/${x} normalises to /api/v1/download.
CLIENT_ROUTES=$(grep -oE "/api/v1/[a-zA-Z0-9_/{}.\$-]+" "$GEN_TSX" \
  | sed -E 's/\$\{[^}]*\}//g; s#/?\$\{.*##; s#/+$##' \
  | grep -E '^/api/v1/.' | sort -u)

say "## Endpoint reachability   (source: $CONTRACT_SRC)"
hr
for r in $CLIENT_ROUTES; do
  # Normalise a client download path like /api/v1/download/xxx to the template.
  match=$(printf '%s\n' $CONTRACT_ROUTES | grep -E "^${r%/*}(/|$)|^$r$" | head -1)
  base=$(printf '%s\n' $CONTRACT_ROUTES | grep -E "^$r$" | head -1)
  if [ -n "$base" ]; then
    say "  OK    client calls $r  → present in contract"
  elif printf '%s\n' $CONTRACT_ROUTES | grep -q "^${r}/{"; then
    say "  OK    client calls $r  → matches templated route"
  else
    say "  DRIFT client calls $r  → NOT in contract (404 risk)"
    DRIFT=1
  fi
done
say ""

# ── 3. Field-level check for the JSON body models ────────────────────────────
# Pull one Pydantic model's fields: name + whether Optional/has-default.
model_fields() {
  # $1 = ClassName ; prints "field|required" or "field|optional"
  # Pydantic fields are INDENTED under "class Name(BaseModel):".
  awk -v cls="$1" '
    $0 ~ ("^class " cls "[(]") {inb=1; next}
    inb && /^class / {inb=0}
    inb && /^[ \t]+[a-zA-Z_][a-zA-Z0-9_]*[ \t]*:/ {
      # line looks like:  "    title: str"  OR  "    price: Optional[float] = None"
      line=$0; sub(/:.*/, "", line); gsub(/[ \t]/, "", line); name=line;
      opt = ($0 ~ /Optional\[/ || $0 ~ /=/) ? "optional" : "required";
      if (name != "") print name"|"opt;
    }
  ' "$MAIN_PY"
}

say "## Model field coverage  (Pydantic = source of truth)"
hr
say "### ArtworkMetadata vs client artworkData object"
CLIENT_ART=$(awk '/const artworkData = artworks\.map/{f=1} f{print} /\}\)\);/{if(f)exit}' "$GEN_TSX")
for pair in $(model_fields ArtworkMetadata); do
  fname=${pair%%|*}; req=${pair##*|}
  if printf '%s' "$CLIENT_ART" | grep -qE "(^|[^a-zA-Z_])$fname\b"; then
    :
  else
    if [ "$req" = "required" ]; then
      say "  DRIFT missing REQUIRED field '$fname' in client artwork payload"
      DRIFT=1
    else
      say "  note  optional field '$fname' never sent by client (ok, but UI can't set it)"
    fi
  fi
done
say ""

say "### Response envelope keys the client reads"
hr
# The 'document' object is whatever the renderer returns (app/services/pdf_renderer.py)
# plus 'download_token' injected in main.py. Search the whole app/ tree for the key
# token; if it appears nowhere the server cannot be setting it.
APP_DIR="$API_DIR/app"
for key in $(grep -oE 'result\.document\.[a-zA-Z_]+|document\?\.[a-zA-Z_]+|document\.[a-zA-Z_]+' "$GEN_TSX" \
              | sed -E 's/.*document[?.]*\.//' | sort -u); do
  [ -n "$key" ] || continue
  if grep -rqE "[\"'\.]$key[\"' =:]|\b$key\b" "$APP_DIR" 2>/dev/null; then
    say "  OK    client reads document.$key  → server sets it somewhere in app/"
  else
    say "  DRIFT client reads document.$key  → server never sets '$key' (undefined at runtime)"
    DRIFT=1
  fi
done
say ""

hr
if [ "$DRIFT" -eq 0 ]; then
  say "RESULT: no hard drift detected."
  exit 0
else
  say "RESULT: drift detected — fix the CLIENT to match the Pydantic contract."
  say "        (see SKILL.md 'Real drift' section for known cases)"
  exit 2
fi
