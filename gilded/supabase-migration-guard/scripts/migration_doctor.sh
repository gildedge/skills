#!/usr/bin/env bash
# migration_doctor.sh — READ ONLY diagnosis of a venture's Supabase migration health.
# Usage: migration_doctor.sh <venture-repo-root>
# Prints: loose schema.sql, duplicate CREATEs, baseline presence, CLI availability.
# Never writes anything. Safe to run against any repo.

set -o pipefail

REPO="${1:?usage: migration_doctor.sh <venture-repo-root>}"

# Locate the supabase dir (repo root, or nested app/ e.g. lumier-studios).
SUPA=""
for cand in "$REPO/supabase" "$REPO/app/supabase" "$REPO/platform/supabase"; do
  [ -d "$cand" ] && { SUPA="$cand"; break; }
done
if [ -z "$SUPA" ]; then
  SUPA=$(find "$REPO" -maxdepth 4 -type d -name supabase -not -path '*/node_modules/*' 2>/dev/null | head -1)
fi
[ -z "$SUPA" ] && { echo "✗ no supabase/ directory found under $REPO"; exit 1; }

MIG="$SUPA/migrations"
echo "== Supabase migration doctor =="
echo "repo:       $REPO"
echo "supabase:   $SUPA"
echo "migrations: ${MIG}"
echo ""

# 1. Loose schema.sql outside migrations/
echo "-- loose schema (base tables outside the replay path) --"
FOUND_LOOSE=0
for s in "$SUPA/schema.sql" "$SUPA/../schema.sql"; do
  if [ -f "$s" ]; then
    n=$(grep -ciE 'create (table|type|function|policy)' "$s" 2>/dev/null)
    echo "  ! $s  ($n CREATE statements NOT in migrations/ → invisible to 'db reset')"
    FOUND_LOOSE=1
  fi
done
# FULL_SCHEMA-style base file that lives *inside* migrations but duplicates numbered ones
if [ -d "$MIG" ]; then
  for f in "$MIG"/*FULL_SCHEMA*.sql "$MIG"/*full_schema*.sql; do
    [ -f "$f" ] && echo "  ! $(basename "$f")  (full-schema file inside migrations/ — likely duplicates numbered migrations)"
  done
fi
[ "$FOUND_LOOSE" -eq 0 ] && echo "  ok: no loose schema.sql at supabase root"
echo ""

# 2. Duplicate CREATE TABLE / TYPE across migrations
echo "-- duplicate CREATE across migrations/ --"
if [ -d "$MIG" ]; then
  DUPES=$(grep -rhoiE 'create (table|type)( if not exists)? +(public\.)?[a-z0-9_]+' "$MIG" 2>/dev/null \
    | sed -E 's/ if not exists//I; s/public\.//; s/create /create /I' \
    | tr 'A-Z' 'a-z' | sort | uniq -c | awk '$1 > 1')
  if [ -n "$DUPES" ]; then
    echo "$DUPES" | while read -r count decl; do
      obj=$(echo "$decl" | awk '{print $NF}')
      files=$(grep -rilE "create (table|type)( if not exists)? +(public\.)?$obj\b" "$MIG" 2>/dev/null | xargs -n1 basename 2>/dev/null | paste -sd, -)
      printf "  ✗ %sx  %-30s  in: %s\n" "$count" "$obj" "$files"
    done
  else
    echo "  ok: no duplicated CREATE TABLE/TYPE"
  fi
else
  echo "  ! no migrations/ directory — nothing to replay"
fi
echo ""

# 3. Baseline presence
echo "-- baseline --"
if ls "$MIG"/000_baseline*.sql >/dev/null 2>&1; then
  echo "  ok: $(ls "$MIG"/000_baseline*.sql | xargs -n1 basename)"
else
  echo "  ! no 000_baseline.sql — run generate_baseline.sh"
fi
echo ""

# 4. Tooling
echo "-- tooling --"
if command -v supabase >/dev/null 2>&1; then
  echo "  ok: supabase CLI $(supabase --version 2>/dev/null | head -1)"
else
  echo "  ! supabase CLI not found (needed for verify_reset.sh)"
fi
[ -f "$SUPA/.temp/linked-project.json" ] && \
  echo "  ⚠ this repo is LINKED to a remote project — never run 'db reset --linked'"

echo ""
echo "Read-only diagnosis complete. Nothing was modified."
