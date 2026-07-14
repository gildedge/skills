#!/usr/bin/env bash
# validate-report.sh — read-only check that a deal report meets the library contract.
# Verifies the 3 machine-parseable strings, score ranges, and required sections.
# bash 3.2-safe. Exit 0 = pass, 1 = failures found.
set -euo pipefail

FILE="${1:-}"
[ -n "$FILE" ] && [ -f "$FILE" ] || { echo "Usage: validate-report.sh <report.md>" >&2; exit 2; }

FAILS=0
ok()   { printf '  ok   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; FAILS=$((FAILS+1)); }

echo "Validating: $FILE"

# --- Required sections ---
for section in \
  "## 📋 Call Summary" \
  "## 📝 Key Transcript Highlights" \
  "## 🏠 Extracted Deal Data" \
  "## 🎯 Scores"; do
  if grep -qF "$section" "$FILE"; then ok "section present: $section"
  else fail "missing section: $section"; fi
done

# --- Parseable Outcome line (extractOutcome) ---
if grep -qE '\*\*Outcome:\*\*[[:space:]]*[^[:space:]]' "$FILE"; then
  ok "**Outcome:** line present"
else
  fail "**Outcome:** line missing or empty (extractOutcome would return null)"
fi

# --- Motivation Score (extractMotivationScore): 0-100 ---
MOT="$(grep -ioE 'Seller Motivation Score:[[:space:]]*[0-9]+[[:space:]]*/[[:space:]]*100' "$FILE" | head -1 || true)"
if [ -n "$MOT" ]; then
  N="$(printf '%s' "$MOT" | grep -oE '[0-9]+' | head -1)"
  if [ "$N" -ge 0 ] && [ "$N" -le 100 ]; then ok "Motivation Score $N/100"
  else fail "Motivation Score out of range: $N"; fi
else
  fail "missing 'Seller Motivation Score: N/100' (regex-parsed by app)"
fi

# --- Agent Scorecard (extractAgentScore): 0-100 ---
AGT="$(grep -ioE 'Agent Performance Scorecard:[[:space:]]*[0-9]+[[:space:]]*/[[:space:]]*100' "$FILE" | head -1 || true)"
if [ -n "$AGT" ]; then
  N="$(printf '%s' "$AGT" | grep -oE '[0-9]+' | head -1)"
  if [ "$N" -ge 0 ] && [ "$N" -le 100 ]; then ok "Agent Scorecard $N/100"
  else fail "Agent Scorecard out of range: $N"; fi
else
  fail "missing 'Agent Performance Scorecard: N/100' (regex-parsed by app)"
fi

# --- Leftover placeholders ---
if grep -qE '<Speaker>|<why you|<one-line|NOT PROVIDED>|<Rep \(Company\)>' "$FILE"; then
  fail "unfilled placeholders remain (search for '<' angle-bracket stubs)"
else
  ok "no obvious unfilled placeholders"
fi

echo ""
if [ "$FAILS" -eq 0 ]; then echo "PASS — report meets the library contract."; exit 0
else echo "FAILED — $FAILS issue(s) above."; exit 1; fi
