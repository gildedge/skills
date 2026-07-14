#!/usr/bin/env bash
# find_collisions.sh — list every DB object CREATEd more than once across a
# migrations directory, with the files each appears in. READ ONLY.
# Usage: find_collisions.sh <path-to-supabase/migrations>
# Exit 0 if clean, 2 if collisions found (useful in CI). Portable to bash 3.2.

set -o pipefail
MIG="${1:?usage: find_collisions.sh <supabase/migrations>}"
[ -d "$MIG" ] || { echo "✗ not a directory: $MIG"; exit 1; }

echo "== CREATE collisions in $MIG =="
STATUS=0

for kind in table type; do
  KUP=$(printf '%s' "$kind" | tr 'a-z' 'A-Z')
  DUP=$(grep -rhoiE "create ${kind}( if not exists)? +(public\.)?[a-z0-9_]+" "$MIG" 2>/dev/null \
    | sed -E "s/ if not exists//I; s/public\.//" \
    | tr 'A-Z' 'a-z' | awk '{print $NF}' | sort | uniq -c | awk '$1 > 1')
  if [ -n "$DUP" ]; then
    echo ""
    echo "-- duplicated CREATE ${KUP} --"
    # feed via here-string (no pipe) so the loop runs in THIS shell and STATUS sticks
    while read -r count obj; do
      [ -z "$obj" ] && continue
      files=$(grep -rilE "create ${kind}( if not exists)? +(public\.)?${obj}\b" "$MIG" 2>/dev/null \
        | xargs -n1 basename 2>/dev/null | paste -sd',' - | sed 's/,/, /g')
      printf "  ✗ %sx  %-30s  %s\n" "$count" "$obj" "$files"
    done <<EOF
$DUP
EOF
    STATUS=2
  fi
done

if [ "$STATUS" -eq 0 ]; then
  echo "  ✓ no duplicated CREATE TABLE/TYPE — migrations should replay cleanly"
else
  echo ""
  echo "Resolve each: keep ONE canonical CREATE (usually the baseline / earliest),"
  echo "convert the later ones to ALTER TABLE ... or delete if redundant."
  echo "Do NOT just add 'if not exists' unless the column sets are byte-identical."
fi
exit $STATUS
