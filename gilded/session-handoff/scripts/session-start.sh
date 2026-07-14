#!/bin/bash
# session-handoff :: session-start.sh
# Executes PROTOCOL.md "On Session Start". Read-only except for writing a fresh
# snapshot into session/snapshots/. bash 3.2 safe.
#
# Usage: bash session-start.sh [--wiki <path to infrastructure/wiki>]

set -u
WIKI="$HOME/GILDED-EDGE-ECOSYSTEM/infrastructure/wiki"
while [ $# -gt 0 ]; do
  case "$1" in
    --wiki) WIKI="${2:-}"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

SESS="$WIKI/session"
[ -d "$SESS" ] || { echo "ERROR: no session dir at $SESS" >&2; exit 1; }
hr() { printf '\n============================================================\n'; }

hr; echo "STEP 1 — session/handoff.md"; hr
if [ -f "$SESS/handoff.md" ]; then cat "$SESS/handoff.md"; else echo "(no handoff.md yet — first session)"; fi

hr; echo "STEP 2 — last 3 history entries (trajectory)"; hr
if [ -d "$SESS/history" ]; then
  LAST3=$(ls -1 "$SESS/history"/*.md 2>/dev/null | sort | tail -3)
  if [ -n "$LAST3" ]; then
    for f in $LAST3; do
      echo "----- $f -----"; cat "$f"; echo
    done
  else
    echo "(history/ is empty)"
  fi
else
  echo "(no history/ dir)"
fi

hr; echo "STEP 3 — live snapshot (capture.sh)"; hr
STAMP=$(date "+%Y-%m-%d-%H%M")
SNAP="$SESS/snapshots/$STAMP.md"
if [ -x "$SESS/capture.sh" ] || [ -f "$SESS/capture.sh" ]; then
  mkdir -p "$SESS/snapshots"
  if bash "$SESS/capture.sh" > "$SNAP" 2>/dev/null; then
    echo "Wrote $SNAP"; echo; cat "$SNAP"
  else
    echo "WARN: capture.sh failed. Record this failure in the handoff — do NOT fabricate state."
  fi
else
  echo "(no capture.sh found)"
fi

hr; echo "STEP 4 — pending decisions (Outcome: PENDING)"; hr
if [ -d "$WIKI/decisions" ]; then
  grep -rl "Outcome: *PENDING" "$WIKI/decisions" 2>/dev/null || echo "(none pending)"
else
  echo "(no decisions/ dir — skip)"
fi

hr; echo "STEP 5 — unresolved contradictions"; hr
if [ -d "$WIKI/contradictions" ]; then
  ls -1 "$WIKI/contradictions"/*.md 2>/dev/null || echo "(none)"
else
  echo "(no contradictions/ dir — skip)"
fi

hr
echo "START COMPLETE. Before coding, state to the user: the working context,"
echo "the top pending decision, and the single Next Priority Action from handoff.md."
