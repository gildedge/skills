#!/bin/bash
# ecosystem-scaffold-sync :: port-change.sh
# Port a shared path ONE direction between the two forks.
# DRY-RUN by default (shows the diff). --write applies it, backing up any
# overwritten destination file. Refuses two-way sync. bash 3.2 safe.
#
# Usage:
#   bash port-change.sh --from gildedge-portal --to edge-os-works \
#        --path src/app/portal/crm/leads/page.tsx [--write]
#
#   --from / --to accept a fork NAME (gildedge-portal | edge-os-works) or a full path.
#   --path is a repo-relative file OR directory shared by both forks.

set -u
VENTURES="$HOME/GILDED-EDGE-ECOSYSTEM/ventures"
FROM=""; TO=""; RELPATH=""; WRITE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --from) FROM="${2:-}"; shift 2 ;;
    --to)   TO="${2:-}"; shift 2 ;;
    --path) RELPATH="${2:-}"; shift 2 ;;
    --ventures) VENTURES="${2:-}"; shift 2 ;;
    --write) WRITE=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "$FROM" ] && [ -n "$TO" ] && [ -n "$RELPATH" ] || {
  echo "ERROR: --from, --to, and --path are all required (single direction only)." >&2; exit 1; }

resolve() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s' "$VENTURES/$1" ;; esac; }
SRC_REPO=$(resolve "$FROM"); DST_REPO=$(resolve "$TO")
[ "$SRC_REPO" = "$DST_REPO" ] && { echo "ERROR: --from and --to are the same repo." >&2; exit 1; }
[ -d "$SRC_REPO" ] || { echo "ERROR: source repo not found: $SRC_REPO" >&2; exit 1; }
[ -d "$DST_REPO" ] || { echo "ERROR: dest repo not found: $DST_REPO" >&2; exit 1; }

SRC="$SRC_REPO/$RELPATH"; DST="$DST_REPO/$RELPATH"
[ -e "$SRC" ] || { echo "ERROR: source path missing: $SRC" >&2; exit 1; }

echo "# port-change  ($([ "$WRITE" -eq 1 ] && echo WRITE || echo DRY-RUN))"
echo "> from: $SRC"
echo "> to:   $DST"
echo

echo "## diff (what would change in the destination; '>' = current dest, '<' = incoming)"
echo "------------------------------------------------------------"
if [ -e "$DST" ]; then
  diff -ru "$DST" "$SRC" 2>/dev/null || true
else
  echo "(destination does not exist yet — this port CREATES it)"
fi
echo "------------------------------------------------------------"
echo

if [ "$WRITE" -eq 0 ]; then
  echo "DRY-RUN only. Review the diff above, then re-run with --write to apply."
  exit 0
fi

STAMP=$(date "+%Y%m%d-%H%M%S")
if [ -d "$SRC" ]; then
  # Directory port: back up dest dir if present, then copy recursively.
  if [ -e "$DST" ]; then
    mv "$DST" "$DST.bak-$STAMP" && echo "BACKUP $DST -> $DST.bak-$STAMP"
  fi
  mkdir -p "$(dirname "$DST")"
  cp -R "$SRC" "$DST" && echo "PORTED dir $SRC -> $DST"
else
  mkdir -p "$(dirname "$DST")"
  if [ -f "$DST" ]; then
    cp "$DST" "$DST.bak-$STAMP" && echo "BACKUP $DST -> $DST.bak-$STAMP"
  fi
  cp "$SRC" "$DST" && echo "PORTED file $SRC -> $DST"
fi

echo
echo "NEXT: review, then commit in the DESTINATION repo referencing the source commit:"
echo "  git -C \"$DST_REPO\" add \"$RELPATH\""
echo "  git -C \"$DST_REPO\" commit -m \"chore: port $RELPATH from $(basename "$SRC_REPO")@<sha>\""
echo "If you ported a migration, run that venture's 'supabase db reset' to prove it applies cleanly."
