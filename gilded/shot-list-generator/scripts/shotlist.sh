#!/usr/bin/env bash
# shotlist.sh — wrapper around shotlist.mjs.
# bash 3.2 safe. Prints JSON to stdout (dry-run); --run --out writes it.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
GILDED_ROOT="${GILDED_ROOT:-$HOME/GILDED-EDGE-ECOSYSTEM}"

if ! command -v node >/dev/null 2>&1; then
  echo "✗ node is required (stdlib only, no npm install needed)." >&2
  exit 1
fi

INPUT=""
ONLY="both"
RUN=0
OUT=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --only) ONLY="${2:-both}"; shift 2 ;;
    --run) RUN=1; shift ;;
    --out) OUT="${2:-}"; shift 2 ;;
    -) INPUT="-"; shift ;;
    -h|--help)
      echo "usage: shotlist.sh <script.txt|scene.json|-> [--only shots|blocking] [--run --out FILE]"; exit 0 ;;
    *) INPUT="$1"; shift ;;
  esac
done

if [ -z "$INPUT" ]; then
  # allow piped stdin with no arg
  if [ ! -t 0 ]; then INPUT="-"; else
    echo "usage: shotlist.sh <script.txt|scene.json|-> [--only shots|blocking] [--run --out FILE]" >&2
    exit 2
  fi
fi
if [ "$INPUT" != "-" ] && [ ! -f "$INPUT" ]; then
  echo "✗ input not found: $INPUT" >&2; exit 1
fi

RESULT="$(node "$HERE/shotlist.mjs" "$INPUT" --only "$ONLY")"

if [ "$RUN" -eq 1 ] && [ -n "$OUT" ]; then
  printf '%s\n' "$RESULT" > "$OUT"
  echo "✓ wrote $OUT"
  echo "  import shotList → lumier-pictures components/ShotList.tsx (project.shotList: ShotListItem[])"
  echo "  import blocking → lumier-pictures components/BlockingTool.tsx (scenes: BlockingScene[])"
  echo "  (root: $GILDED_ROOT/ventures/lumier-pictures)"
else
  printf '%s\n' "$RESULT"
  if [ "$RUN" -eq 1 ]; then echo "# (--run given but no --out; printed instead of writing)" >&2; fi
fi
