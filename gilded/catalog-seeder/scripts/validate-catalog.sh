#!/usr/bin/env bash
# validate-catalog.sh — read-only pre-flight for a catalog seed batch (CSV, header row).
# Reuses the data-validation skill's rules: required fields, image-path existence +
# placeholder scan, slug/SKU uniqueness within the batch, cents sanity.
# bash 3.2-safe. Exit 0 = clean, 1 = blocking issues. Override root with GILDED_ROOT.
set -euo pipefail

GILDED_ROOT="${GILDED_ROOT:-$HOME/GILDED-EDGE-ECOSYSTEM}"
VENTURE=""
FILE=""

usage() { echo "Usage: validate-catalog.sh --venture <edge-design-works|gilded-art-works> rows.csv" >&2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --venture) VENTURE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) FILE="$1"; shift ;;
  esac
done
[ -n "$VENTURE" ] && [ -n "$FILE" ] && [ -f "$FILE" ] || { usage; exit 2; }

PUBLIC_DIR="$GILDED_ROOT/ventures/$VENTURE/public"
FAILS=0
WARNS=0
fail() { printf '  FAIL %s\n' "$1"; FAILS=$((FAILS+1)); }
warn() { printf '  warn %s\n' "$1"; WARNS=$((WARNS+1)); }
ok()   { printf '  ok   %s\n' "$1"; }

# Header -> column index map (1-based). Handles simple CSV (no quoted commas in header).
HEADER="$(head -1 "$FILE")"
col_idx() {
  awk -v name="$1" -F',' 'NR==1{for(i=1;i<=NF;i++){h=$i;gsub(/^[ \t"]+|[ \t"]+$/,"",h);if(h==name){print i;exit}}}' "$FILE"
}

# Required columns per target.
case "$VENTURE" in
  edge-design-works) REQ="name slug image_url price_cents" ; IMG_COLS="image_url image_thumbnail image_cutout" ; UNIQ="slug sku" ;;
  gilded-art-works)  REQ="artwork_id title artist"          ; IMG_COLS="image_url"                            ; UNIQ="artwork_id" ;;
  *) echo "Unknown venture: $VENTURE" >&2; exit 2 ;;
esac

echo "Pre-flight: $FILE  (venture: $VENTURE)"
echo "Header: $HEADER"

# 1. Required columns present.
for c in $REQ; do
  if [ -n "$(col_idx "$c")" ]; then ok "required column present: $c"
  else fail "missing required column: $c"; fi
done

# If a required column is missing entirely, stop — row checks would be meaningless.
if [ "$FAILS" -gt 0 ]; then echo ""; echo "FAILED — fix header before row checks."; exit 1; fi

ROWS="$(( $(wc -l < "$FILE") - 1 ))"
echo "Data rows: $ROWS"

# 2. Required fields non-empty per row.
for c in $REQ; do
  idx="$(col_idx "$c")"
  EMPTY="$(awk -v i="$idx" -F',' 'NR>1{v=$i;gsub(/^[ \t"]+|[ \t"]+$/,"",v);if(v=="")print NR}' "$FILE" | head -5 | tr '\n' ' ')"
  [ -z "$EMPTY" ] && ok "no empty '$c'" || fail "empty '$c' at line(s): $EMPTY"
done

# 3. price_cents must be a positive INTEGER (cents, not float dollars) — edge-design-works.
if [ "$VENTURE" = "edge-design-works" ]; then
  idx="$(col_idx price_cents)"
  BADP="$(awk -v i="$idx" -F',' 'NR>1{v=$i;gsub(/[ \t"]/,"",v);if(v!~/^[0-9]+$/)print NR":"v}' "$FILE" | head -5 | tr '\n' ' ')"
  [ -z "$BADP" ] && ok "price_cents all integer cents" || fail "price_cents not integer cents (float/dollars?) at: $BADP"
fi

# 4. Image paths: no placeholder markers; local paths must exist under public/.
for c in $IMG_COLS; do
  idx="$(col_idx "$c")"
  [ -n "$idx" ] || continue
  # placeholder markers
  BADI="$(awk -v i="$idx" -F',' 'NR>1{v=$i;if(v ~ /placeholder|upload|TODO/)print NR}' "$FILE" | head -5 | tr '\n' ' ')"
  [ -z "$BADI" ] && ok "$c: no placeholder markers" || fail "$c: placeholder/upload/TODO at line(s): $BADI"
  # local-file existence (paths starting with /)
  MISS=""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in
      /*) [ -f "$PUBLIC_DIR$p" ] || MISS="$MISS $p" ;;
      http*://*) : ;;  # remote — not checked here
    esac
  done <<< "$(awk -v i="$idx" -F',' 'NR>1{v=$i;gsub(/^[ \t"]+|[ \t"]+$/,"",v);print v}' "$FILE")"
  [ -z "$MISS" ] && ok "$c: local paths resolve under public/" || warn "$c: missing under $PUBLIC_DIR:$MISS"
done

# 5. Uniqueness within the batch for the conflict keys.
for c in $UNIQ; do
  idx="$(col_idx "$c")"
  [ -n "$idx" ] || continue
  DUP="$(awk -v i="$idx" -F',' 'NR>1{v=$i;gsub(/^[ \t"]+|[ \t"]+$/,"",v);if(v!="")print v}' "$FILE" | sort | uniq -d | head -5 | tr '\n' ' ')"
  [ -z "$DUP" ] && ok "$c unique within batch" || fail "$c has duplicate value(s) in batch: $DUP"
  # slug URL-safety
  if [ "$c" = "slug" ]; then
    BADS="$(awk -v i="$idx" -F',' 'NR>1{v=$i;gsub(/^[ \t"]+|[ \t"]+$/,"",v);if(v!="" && v!~/^[a-z0-9-]+$/)print NR}' "$FILE" | head -5 | tr '\n' ' ')"
    [ -z "$BADS" ] && ok "slugs URL-safe" || fail "non-URL-safe slug at line(s): $BADS"
  fi
done

echo ""
if [ "$FAILS" -eq 0 ]; then
  echo "CLEAN — $ROWS rows ready to seed ($WARNS warning(s))."; exit 0
else
  echo "FAILED — $FAILS blocking issue(s), $WARNS warning(s). Fix source data before seeding."; exit 1
fi
