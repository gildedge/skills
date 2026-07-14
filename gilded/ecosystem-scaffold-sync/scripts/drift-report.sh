#!/bin/bash
# ecosystem-scaffold-sync :: drift-report.sh
# Read-only. Reports fork drift between gildedge-portal and edge-os-works across
# their shared scaffolding dirs + Supabase migrations. bash 3.2 safe.
#
# Usage: bash drift-report.sh [--ventures <path to .../ventures>]

set -u
VENTURES="$HOME/GILDED-EDGE-ECOSYSTEM/ventures"
while [ $# -gt 0 ]; do
  case "$1" in
    --ventures) VENTURES="${2:-}"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

A="$VENTURES/gildedge-portal"
B="$VENTURES/edge-os-works"
[ -d "$A" ] || { echo "ERROR: missing $A" >&2; exit 1; }
[ -d "$B" ] || { echo "ERROR: missing $B" >&2; exit 1; }

SHARED="src/app/portal src/app/crm src/components/portal src/lib/crm src/lib/aria src/app/api/aria"
hr() { printf '%s\n' "------------------------------------------------------------"; }
DRIFT=0

echo "# Fork Drift Report"
echo "> A = gildedge-portal   ($A)"
echo "> B = edge-os-works     ($B)"
echo

for d in $SHARED; do
  echo "## $d"
  hr
  if [ ! -d "$A/$d" ] && [ ! -d "$B/$d" ]; then echo "  (absent in both)"; echo; continue; fi
  if [ ! -d "$A/$d" ]; then echo "  only in B (edge-os-works)"; DRIFT=1; echo; continue; fi
  if [ ! -d "$B/$d" ]; then echo "  only in A (gildedge-portal)"; DRIFT=1; echo; continue; fi
  # brief=diff -rq classifies: only-in-A, only-in-B, differ
  out=$(diff -rq "$A/$d" "$B/$d" 2>/dev/null)
  if [ -z "$out" ]; then
    echo "  IN SYNC (identical)"
  else
    n=$(printf '%s\n' "$out" | grep -c .)
    echo "  $n difference(s):"
    printf '%s\n' "$out" \
      | sed -e "s#$A/#A:#g" -e "s#$B/#B:#g" -e 's/^/    /'
    DRIFT=1
  fi
  echo
done

# ── Migrations: classify each common file SAME/DIFF + list per-fork-only ─────
echo "## supabase/migrations"
hr
MA="$A/supabase/migrations"; MB="$B/supabase/migrations"
if [ -d "$MA" ] && [ -d "$MB" ]; then
  same=0; diffn=0
  for f in $(ls "$MA" 2>/dev/null); do
    if [ -f "$MB/$f" ]; then
      if diff -q "$MA/$f" "$MB/$f" >/dev/null 2>&1; then
        echo "  SAME  $f"; same=$((same+1))
      else
        echo "  DIFF  $f   <-- shared migration edited in one fork only"; diffn=$((diffn+1)); DRIFT=1
      fi
    fi
  done
  echo
  for f in $(ls "$MA" 2>/dev/null); do
    [ -f "$MB/$f" ] || { echo "  ONLY-IN-A  $f   (edge-os-works may need this)"; DRIFT=1; }
  done
  for f in $(ls "$MB" 2>/dev/null); do
    [ -f "$MA/$f" ] || { echo "  ONLY-IN-B  $f   (gildedge-portal may need this)"; DRIFT=1; }
  done
  echo
  echo "  summary: $same identical, $diffn differing among common migrations"
else
  echo "  (one or both migrations dirs missing)"
fi
echo

hr
if [ "$DRIFT" -eq 0 ]; then
  echo "RESULT: forks in sync across shared scaffolding."
else
  echo "RESULT: drift present. Triage each item (intentional feature vs accidental)."
  echo "        Port with: scripts/port-change.sh --from <fork> --to <fork> --path <p>  (dry-run first)"
fi
