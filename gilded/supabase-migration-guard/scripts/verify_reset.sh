#!/usr/bin/env bash
# verify_reset.sh — prove the migration history replays cleanly against the LOCAL
# Supabase stack (never production). Runs 'supabase db reset' from the supabase dir.
# Usage: verify_reset.sh <venture-repo-root>
# Refuses to run unless a local stack appears to be up.

set -o pipefail
REPO="${1:?usage: verify_reset.sh <venture-repo-root>}"

command -v supabase >/dev/null 2>&1 || { echo "✗ supabase CLI not installed"; exit 1; }

# Locate supabase dir
SUPA=""
for cand in "$REPO/supabase" "$REPO/app/supabase" "$REPO/platform/supabase"; do
  [ -d "$cand" ] && { SUPA="$cand"; break; }
done
[ -z "$SUPA" ] && SUPA=$(find "$REPO" -maxdepth 4 -type d -name supabase -not -path '*/node_modules/*' 2>/dev/null | head -1)
[ -z "$SUPA" ] && { echo "✗ no supabase/ directory under $REPO"; exit 1; }

PROJ_DIR="$(dirname "$SUPA")"
echo "== verify_reset =="
echo "project dir: $PROJ_DIR"

# Safety: confirm a local stack is running so we never touch a linked remote DB.
if ! supabase status --workdir "$PROJ_DIR" >/dev/null 2>&1; then
  echo "✗ local Supabase stack is not running for this project."
  echo "  Start it first:  (cd '$PROJ_DIR' && supabase start)"
  echo "  This script only ever resets the LOCAL db, never a linked/production project."
  exit 1
fi

echo "→ running 'supabase db reset' (LOCAL — drops & replays migrations/ from scratch)"
if supabase db reset --workdir "$PROJ_DIR"; then
  echo ""
  echo "✓ CLEAN: every migration applied from an empty database. Schema is reproducible."
  exit 0
else
  echo ""
  echo "✗ reset FAILED. The error above names the first missing/colliding relation."
  echo "  → run find_collisions.sh, fix the offending migration, then re-run."
  exit 1
fi
