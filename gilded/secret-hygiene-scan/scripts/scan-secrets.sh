#!/usr/bin/env bash
# Secret Hygiene Scan — Gilded Edge Ecosystem
#
# Rewritten 2026-08-17. The previous implementation looped per-file and per-line
# with nested process substitutions, spawning tens of thousands of subprocesses.
# On macOS/bash 3.2 that exhausted file descriptors mid-run: `basename` and `git`
# began returning empty, every remaining repo silently scanned nothing, and the
# script still exited 0 — a security gate reporting "all clear" while blind.
# (Observed 2026-08-17: 29/29 repos "scanned", 0 findings, exit 0 — all false.)
#
# This version issues a handful of `git grep` calls per repo instead, and FAILS
# LOUDLY (exit 2) if any repo could not be probed, so a broken run can never be
# mistaken for a clean one.
#
# Usage:  scan-secrets.sh [ROOT]
# Env:    SCAN_HISTORY=1   also scan full git history (slow)
# Exit:   0 clean · 1 HIGH findings present · 2 scan incomplete (do not trust)
set -uo pipefail

ROOT="${1:-$PWD}"
[ -d "$ROOT" ] || { echo "No such directory: $ROOT" >&2; exit 2; }
ROOT="$(cd "$ROOT" && pwd)"

if [ -t 1 ]; then
  RED=$'\033[31m'; YEL=$'\033[33m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; RST=$'\033[0m'
else
  RED=''; YEL=''; DIM=''; BOLD=''; RST=''
fi

# Live-credential prefixes. `re_` is anchored with \b so it cannot match inside
# ordinary words (fi>re_<engine, _ensu>re_<comment, P>re_<Seed_Executive...),
# which previously produced 47 of 50 raw matches as noise.
KEY_PATTERNS='sk_live_[A-Za-z0-9]{16,}|rk_live_[A-Za-z0-9]{16,}|pk_live_[A-Za-z0-9]{16,}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[A-Za-z0-9-]{10,}|r8_[A-Za-z0-9]{30,}|EZAK_[A-Za-z0-9]{20,}|\bre_[A-Za-z0-9]{20,}|SG\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xai-[A-Za-z0-9]{20,}'
JWT_PATTERN='eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}'

HIGH_COUNT=0; WARN_COUNT=0; INFO_COUNT=0; FAILED_REPOS=0; SCANNED=0

mask() { printf '%s… [len %d]' "${1:0:8}" "${#1}"; }
hit_high() { HIGH_COUNT=$((HIGH_COUNT+1)); printf '  %s[HIGH]%s %s\n' "$RED$BOLD" "$RST" "$1"; }
hit_warn() { WARN_COUNT=$((WARN_COUNT+1)); printf '  %s[WARN]%s %s\n' "$YEL" "$RST" "$1"; }
hit_info() { INFO_COUNT=$((INFO_COUNT+1)); printf '  %s[info]%s %s\n' "$DIM" "$RST" "$1"; }

# jwt_claim <token> <claim> — prints the claim value only, never the token.
# A service_role key bypasses Row Level Security entirely; an anon key is
# public by design. Telling them apart is the whole point of this check.
jwt_claim() {
  local payload pad dec
  payload="${1#*.}"; payload="${payload%%.*}"
  pad=$(( (4 - ${#payload} % 4) % 4 ))
  case $pad in 1) payload="${payload}=";; 2) payload="${payload}==";; 3) payload="${payload}===";; esac
  dec="$(printf '%s' "$payload" | tr '_-' '/+' | base64 -d 2>/dev/null)" || return 0
  printf '%s' "$dec" | grep -oE "\"$2\":\"?[A-Za-z0-9_.-]+\"?" | head -1 | sed -E 's/.*":"?//; s/"$//'
}

REPOS=()
while IFS= read -r d; do
  [ -n "$d" ] && REPOS+=("$d")
done < <(find "$ROOT" -type d -name .git -prune 2>/dev/null | sed 's#/\.git$##' \
         | grep -vE '/(node_modules|build|dist|\.venv|SourcePackages|Pods|vendor)/' | sort)
[ "${#REPOS[@]}" -eq 0 ] && REPOS=("$ROOT")

echo "${BOLD}Secret Hygiene Scan${RST}"
echo "Root:        $ROOT"
echo "Repos found: ${#REPOS[@]}"
echo "History:     $( [ "${SCAN_HISTORY:-0}" = "1" ] && echo ON || echo off )"
echo

for repo in "${REPOS[@]}"; do
  name="${repo##*/}"
  echo "${BOLD}▸ $name${RST} ${DIM}($repo)${RST}"

  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    echo "  ${RED}[SCAN-FAILED]${RST} could not probe this repo — results are NOT trustworthy"
    FAILED_REPOS=$((FAILED_REPOS+1)); continue
  fi
  SCANNED=$((SCANNED+1))

  # 1. tracked .env files — a .env must never be committed
  while IFS= read -r envf; do
    [ -n "$envf" ] && hit_high "tracked .env file: $envf"
  done < <(git -C "$repo" ls-files 2>/dev/null | grep -E '(^|/)\.env($|\.)' | grep -v '\.example')

  # 2. live-credential prefixes in tracked files
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    f="${line%%:*}"
    case "$f" in *package-lock.json|*pnpm-lock.yaml|*yarn.lock) continue ;; esac
    m="$(printf '%s' "$line" | grep -oE "$KEY_PATTERNS" | head -1)"
    [ -z "$m" ] && continue
    case "$f" in
      *.env.example) hit_high "real key in .env.example (placeholder expected!): $f  →  $(mask "$m")" ;;
      *)             hit_high "key prefix in tracked file: $f  →  $(mask "$m")" ;;
    esac
  done < <(git -C "$repo" grep -InE "$KEY_PATTERNS" 2>/dev/null | head -60)

  # 3. JWTs — decode the role claim
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    f="${line%%:*}"
    case "$f" in *package-lock.json|*pnpm-lock.yaml|*yarn.lock) continue ;; esac
    t="$(printf '%s' "$line" | grep -oE "$JWT_PATTERN" | head -1)"
    [ -z "$t" ] && continue
    role="$(jwt_claim "$t" role)"; ref="$(jwt_claim "$t" ref)"
    case "$role" in
      service_role) hit_high "SERVICE_ROLE key — bypasses RLS — $f  →  $(mask "$t")  project=${ref:-unknown}" ;;
      anon)         hit_info "supabase anon key (public by design): $f  →  project=${ref:-unknown}" ;;
      *)            hit_warn "JWT in tracked file: $f  →  $(mask "$t")  role=${role:-unknown}" ;;
    esac
  done < <(git -C "$repo" grep -InE "$JWT_PATTERN" 2>/dev/null | head -60)

  # 4. optional full-history pass (first-Monday-of-month convention)
  if [ "${SCAN_HISTORY:-0}" = "1" ]; then
    revs="$(git -C "$repo" rev-list --all 2>/dev/null | head -400)"
    if [ -n "$revs" ]; then
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        m="$(printf '%s' "$line" | grep -oE "$KEY_PATTERNS|$JWT_PATTERN" | head -1)"
        [ -n "$m" ] && hit_warn "in git HISTORY: $(printf '%s' "$line" | cut -c1-70)  →  $(mask "$m")"
      done < <(git -C "$repo" grep -InE "$KEY_PATTERNS|$JWT_PATTERN" $revs 2>/dev/null | head -40)
    fi
  fi
done

echo
echo "── Summary ──"
echo "  Repos scanned: $SCANNED / ${#REPOS[@]}"
echo "  HIGH: $HIGH_COUNT   WARN: $WARN_COUNT   info: $INFO_COUNT"
if [ "$FAILED_REPOS" -gt 0 ]; then
  echo "  ${RED}${BOLD}$FAILED_REPOS repo(s) could not be scanned — THIS RUN IS NOT A PASS.${RST}"
  exit 2
fi
if [ "$HIGH_COUNT" -gt 0 ]; then
  echo "  ${RED}HIGH findings present.${RST} Runbook: ~/.claude/skills/secret-hygiene-scan/references/rotate-and-log.md"
  echo "  Reminder: untracking a file does NOT remove it from history — ROTATE the key."
  exit 1
fi
echo "  clean"
exit 0
