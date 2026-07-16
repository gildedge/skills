#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# audit-rls.sh — READ-ONLY RLS auditor for a Supabase migrations tree.
#
# Flags the four anti-patterns that shipped as bugs in gilded-art-works:
#   1. CREATE TABLE with no matching ENABLE ROW LEVEL SECURITY
#   2. WITH CHECK (true)            → any client inserts rows for anyone
#   3. Recursive policy             → policy on <t> that sub-selects <t>
#   4. Leaky USING (active = ...)   → token/secret not bound in predicate
#
# Usage:
#   audit-rls.sh [path-to-supabase-dir-or-migrations]
#   audit-rls.sh ~/GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works/supabase
#
# Pure grep/awk/shell. Never writes. Exit 0 = clean, 1 = findings.
# ══════════════════════════════════════════════════════════════════
set -uo pipefail

TARGET="${1:-.}"
if [[ ! -e "$TARGET" ]]; then
  echo "ERROR: path not found: $TARGET" >&2; exit 2
fi

# Collect .sql files (schema.sql + migrations/*.sql).
# (while-read, not mapfile — macOS ships bash 3.2 which lacks mapfile.)
FILES=()
while IFS= read -r _f; do [[ -n "$_f" ]] && FILES+=("$_f"); done < <(find "$TARGET" -type f -name '*.sql' | sort)
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No .sql files under $TARGET" >&2; exit 2
fi

RED=$'\033[0;31m'; YEL=$'\033[0;33m'; GRN=$'\033[0;32m'; DIM=$'\033[2m'; RST=$'\033[0m'
[[ -t 1 ]] || { RED=""; YEL=""; GRN=""; DIM=""; RST=""; }

findings=0

echo "RLS audit — ${#FILES[@]} file(s) under $TARGET"
echo "══════════════════════════════════════════════════════════════════"

# ── 1. Tables created without RLS enabled ────────────────────────────
# Gather all created table names and all ENABLE RLS targets across the tree.
created="$(grep -hioE 'CREATE TABLE( IF NOT EXISTS)? +[a-z0-9_."]+' "${FILES[@]}" 2>/dev/null \
  | sed -E 's/.* //; s/"//g' | sort -u)"
rls_on="$(grep -hioE 'ALTER TABLE +[a-z0-9_."]+ +ENABLE ROW LEVEL SECURITY' "${FILES[@]}" 2>/dev/null \
  | sed -E 's/ENABLE.*//; s/ALTER TABLE +//I; s/[" ]//g' | sort -u)"

missing=""
while IFS= read -r t; do
  [[ -z "$t" ]] && continue
  if ! grep -qxF "$t" <<<"$rls_on"; then
    missing+="$t"$'\n'
  fi
done <<<"$created"

if [[ -n "${missing//[$'\n']/}" ]]; then
  echo "${RED}[1] Tables missing ENABLE ROW LEVEL SECURITY:${RST}"
  while IFS= read -r t; do [[ -n "$t" ]] && echo "    - $t"; done <<<"$missing"
  echo "    ${DIM}→ Public schema tables without RLS are anon read/write via PostgREST.${RST}"
  findings=$((findings+1))
else
  echo "${GRN}[1] OK — every CREATE TABLE has a matching ENABLE ROW LEVEL SECURITY.${RST}"
fi
echo ""

# ── 2. WITH CHECK (true) ─────────────────────────────────────────────
if grep -rniE 'WITH CHECK *\( *true *\)' "${FILES[@]}" >/dev/null 2>&1; then
  echo "${RED}[2] WITH CHECK (true) — any caller can insert rows for anyone:${RST}"
  grep -rniE 'WITH CHECK *\( *true *\)' "${FILES[@]}" | sed 's/^/    /'
  echo "    ${DIM}→ Bind the row to the caller: WITH CHECK (auth.uid() = user_id).${RST}"
  findings=$((findings+1))
else
  echo "${GRN}[2] OK — no WITH CHECK (true).${RST}"
fi
echo ""

# ── 3. Recursive policy (policy on <t> that sub-selects <t>) ──────────
# Parse each CREATE POLICY ... ON <t> ... block; flag if body re-selects <t>.
# Portable awk (BSD/macOS): split on ';' so each record is one statement;
# use tolower() + 2-arg match()/RSTART/RLENGTH (no gawk capture groups).
for f in "${FILES[@]}"; do
  awk -v FN="$f" '
    BEGIN{ RS=";" }
    {
      s=tolower($0)
      if (s ~ /create[ \t\n]+policy/) {
        if (match(s, /[ \t\n]on[ \t\n]+[a-z0-9_.]+/)) {
          tbl=substr(s, RSTART, RLENGTH)
          sub(/[ \t\n]on[ \t\n]+/, "", tbl)
          if (s ~ ("from[ \t\n]+" tbl "([^a-z0-9_]|$)")) {
            print FN": recursive policy references "tbl" inside its own policy"
          }
        }
      }
    }
  ' "$f"
done | sed 's/^/    /' > "/tmp/.rls_rec.$$" 2>/dev/null || true
if [[ -s /tmp/.rls_rec.$$ ]]; then
  echo "${RED}[3] Recursive RLS policy — Postgres will raise 'infinite recursion detected in policy':${RST}"
  cat /tmp/.rls_rec.$$
  echo "    ${DIM}→ Move the lookup into a SECURITY DEFINER function (see references/policy-patterns.sql #3).${RST}"
  findings=$((findings+1))
else
  echo "${GRN}[3] OK — no policy sub-selects its own table.${RST}"
fi
rm -f /tmp/.rls_rec.$$
echo ""

# ── 4. Leaky USING (active = ...) with no token/secret in predicate ──
if grep -rniE 'USING *\( *active *= *(true|TRUE)' "${FILES[@]}" >/dev/null 2>&1; then
  echo "${YEL}[4] Broad USING (active = TRUE) — verify no token/secret column is exposed:${RST}"
  grep -rniE 'USING *\( *active *= *(true|TRUE)' "${FILES[@]}" | sed 's/^/    /'
  echo "    ${DIM}→ For share/portal tokens, serve lookups through a SECURITY DEFINER RPC keyed by token (pattern #4).${RST}"
  findings=$((findings+1))
else
  echo "${GRN}[4] OK — no broad USING (active = TRUE) policies.${RST}"
fi
echo ""

echo "══════════════════════════════════════════════════════════════════"
if [[ "$findings" -gt 0 ]]; then
  echo "${RED}$findings category(ies) with findings.${RST} Fix with the patterns in references/policy-patterns.sql."
  exit 1
else
  echo "${GRN}Clean — no RLS anti-patterns detected.${RST}"
  exit 0
fi
