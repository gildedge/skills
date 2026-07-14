#!/bin/bash
# session-handoff :: session-end.sh
# Executes PROTOCOL.md "On Session End". DRY-RUN by default: pass --write to
# actually create files + git add. Never runs git commit or git push.
# bash 3.2 safe.
#
# Usage:
#   bash session-end.sh --summary "one-line summary" [--wiki <path>] [--write]

set -u
WIKI="$HOME/GILDED-EDGE-ECOSYSTEM/infrastructure/wiki"
SUMMARY=""
WRITE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --summary) SUMMARY="${2:-}"; shift 2 ;;
    --wiki)    WIKI="${2:-}"; shift 2 ;;
    --write)   WRITE=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

SESS="$WIKI/session"
[ -d "$SESS" ] || { echo "ERROR: no session dir at $SESS" >&2; exit 1; }
[ -n "$SUMMARY" ] || { echo "ERROR: --summary is required" >&2; exit 1; }

STAMP=$(date "+%Y-%m-%d-%H%M")
ISO=$(date "+%Y-%m-%dT%H:%M:%S%z")
HIST="$SESS/history/$STAMP.md"
SNAP="$SESS/snapshots/$STAMP.md"
LOG="$SESS/log.md"
HANDOFF="$SESS/handoff.md"

mode="DRY-RUN (no files written)"; [ "$WRITE" -eq 1 ] && mode="WRITE"
echo "# session-end :: $mode :: stamp=$STAMP"
echo

# ── Handoff scaffold (PROTOCOL Handoff Template) ─────────────────────────────
read -r -d '' HANDOFF_BODY <<EOF
---
title: Session Handoff
type: session
updated: $ISO
---

# 🧠 Session Handoff

> Read this at the start of every session. Update it at the end.
> See [PROTOCOL.md](PROTOCOL.md) for full session continuity procedures.

## Active Context
- **Working on**: $SUMMARY
- **Previous session**: <1-line summary of prior session>
- **Momentum**: <what's flowing / what's stuck>

## Hot Entities (Recently Modified)
| Entity | Last Change | Status |
|--------|------------|--------|
| <link> | <change> | <status> |

## Pending Decisions
- [ ] <decision with deadline>

## Environment State
| System | Status |
|--------|--------|
| <system> | <state> |

## Blockers
1. <blocker with resolution path>

## Next Priority Actions
1. <most important next step>

## Momentum Notes
<What just clicked? What thread should the next session pick up immediately?>
EOF

# ── History scaffold (PROTOCOL Session Summary Template) ─────────────────────
read -r -d '' HIST_BODY <<EOF
# Session: $STAMP
## Duration: <X hours>

## Accomplishments
1. $SUMMARY

## Decisions Made
- <decision> → <rationale>

## Files Modified
- <file> — <what changed>

## Entities Updated
- <entity> — <what changed>

## Contradictions Discovered
- <if any>

## State at Close
- <key environment state>

## Recommendation for Next Session
<what should the next session prioritize?>
EOF

LOG_LINE="- $ISO — session end — $SUMMARY"

if [ "$WRITE" -eq 0 ]; then
  echo "Would OVERWRITE $HANDOFF with:"; echo "------------------------------------------------------------"
  printf '%s\n' "$HANDOFF_BODY"; echo "------------------------------------------------------------"; echo
  echo "Would CREATE $HIST with:"; echo "------------------------------------------------------------"
  printf '%s\n' "$HIST_BODY"; echo "------------------------------------------------------------"; echo
  echo "Would APPEND to $LOG:"; echo "  $LOG_LINE"; echo
  echo "Would RUN capture.sh -> $SNAP"
  echo "Would RUN: git add -A   (staging only — never commit/push)"
  echo
  echo "Re-run with --write to apply, then hand-edit the scaffolds with REAL content before committing."
  exit 0
fi

# ── WRITE mode ───────────────────────────────────────────────────────────────
mkdir -p "$SESS/history" "$SESS/snapshots"
printf '%s\n' "$HANDOFF_BODY" > "$HANDOFF"; echo "WROTE  $HANDOFF"
printf '%s\n' "$HIST_BODY"    > "$HIST";    echo "WROTE  $HIST"
[ -f "$LOG" ] || printf '# Session Log\n\n' > "$LOG"
printf '%s\n' "$LOG_LINE" >> "$LOG";        echo "APPEND $LOG"

if [ -f "$SESS/capture.sh" ]; then
  if bash "$SESS/capture.sh" > "$SNAP" 2>/dev/null; then echo "WROTE  $SNAP"
  else echo "WARN: capture.sh failed — note this in handoff, do not fabricate."; fi
fi

if command -v git >/dev/null 2>&1 && git -C "$WIKI" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$WIKI" add -A && echo "STAGED changes in $WIKI"
  echo
  echo "NEXT (run yourself after reviewing the diff, and after editing the scaffolds):"
  echo "  git -C \"$WIKI\" commit -m \"session: $SUMMARY\""
  echo "  git -C \"$WIKI\" push"
else
  echo "NOTE: $WIKI is not a git repo — skipped staging."
fi
echo
echo "REMINDER: the handoff + history are SKELETONS. Edit in the real accomplishments,"
echo "decisions, blockers, and Next Priority Actions before you commit."
