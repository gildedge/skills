#!/usr/bin/env bash
#
# scan-secrets.sh — zero-dependency secret & env-hygiene scanner for the
# Gilded Edge ecosystem.
#
# Usage:
#   scan-secrets.sh [ROOT]                 # scan ROOT (default: cwd)
#   SCAN_HISTORY=1 scan-secrets.sh [ROOT]  # also scan git HISTORY (slower)
#
# Detects, per git repo found under ROOT:
#   1. Tracked env files (.env, .env.local, .env.bak, ...) — NOT .env.example
#   2. Known live key prefixes in tracked files
#   3. High-entropy KEY=<value> assignments in tracked files
#   4. (optional) the same, across all of git history
#
# SAFETY: read-only. Never writes, never commits, never prints an unmasked
# secret — only a short prefix + length. Optionally shells out to gitleaks /
# trufflehog IF they are installed; works fully without them.
#
# Exit code: 1 if any HIGH finding, else 0.

# Note: intentionally NOT using `set -u` — this must run on macOS's stock
# bash 3.2, where empty-array expansion under `set -u` errors.
set -o pipefail

ROOT="${1:-.}"
SCAN_HISTORY="${SCAN_HISTORY:-0}"

if [ ! -d "$ROOT" ]; then
  echo "Not a directory: $ROOT" >&2
  exit 2
fi
ROOT="$(cd "$ROOT" && pwd)"

# ── styling ────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  RED=$'\033[31m'; YEL=$'\033[33m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; RST=$'\033[0m'
else
  RED=""; YEL=""; DIM=""; BOLD=""; RST=""
fi

HIGH_COUNT=0
WARN_COUNT=0
INFO_COUNT=0

# Env filenames that must NEVER be tracked (anything but .env.example).
ENV_FILE_RE='(^|/)\.env(\.[A-Za-z0-9_-]+)?$'

# Known live/secret key prefixes -> label. Test-mode kept separate (INFO).
# (regex fragments; matched anywhere on a line)
KEY_PATTERNS='sk_live_[A-Za-z0-9]{16,}|rk_live_[A-Za-z0-9]{16,}|pk_live_[A-Za-z0-9]{16,}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[A-Za-z0-9-]{10,}|r8_[A-Za-z0-9]{30,}|EZAK_[A-Za-z0-9]{20,}|EZTK_[A-Za-z0-9]{20,}|re_[A-Za-z0-9_]{20,}|SG\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xai-[A-Za-z0-9]{20,}'

# ── helpers ─────────────────────────────────────────────────────────────────

# Mask a secret-ish string: show first 8 chars + [len N]. Never emit the rest.
mask() {
  local s="$1"
  local n=${#s}
  local head="${s:0:8}"
  printf '%s… [len %d]' "$head" "$n"
}

hit_high() { HIGH_COUNT=$((HIGH_COUNT+1)); printf '  %s[HIGH]%s %s\n' "$RED$BOLD" "$RST" "$1"; }
hit_warn() { WARN_COUNT=$((WARN_COUNT+1)); printf '  %s[WARN]%s %s\n' "$YEL" "$RST" "$1"; }
hit_info() { INFO_COUNT=$((INFO_COUNT+1)); printf '  %s[info]%s %s\n' "$DIM" "$RST" "$1"; }

# Is a value an obvious placeholder / empty?
is_placeholder() {
  local v="$1"
  [ -z "$v" ] && return 0
  case "$v" in
    *your_*_here|*YOUR_*|*changeme*|*CHANGEME*|xxx*|XXX*|*_here|*example*|*placeholder*|"...")
      return 0 ;;
  esac
  # all x's or all same char
  [[ "$v" =~ ^x+$ ]] && return 0
  return 1
}

# Crude Shannon-ish entropy gate: treat as high-entropy if length>=20 and it
# contains a mix of classes and isn't a placeholder. Pure bash, no deps.
looks_random() {
  local v="$1"
  local n=${#v}
  [ "$n" -lt 20 ] && return 1
  is_placeholder "$v" && return 1
  # require at least two of: lower, upper, digit
  local cl=0
  [[ "$v" =~ [a-z] ]] && cl=$((cl+1))
  [[ "$v" =~ [A-Z] ]] && cl=$((cl+1))
  [[ "$v" =~ [0-9] ]] && cl=$((cl+1))
  [ "$cl" -ge 2 ] || return 1
  # reject things that are clearly URLs / emails / paths
  case "$v" in
    http*|*@*|/*|./*|*.com|*.dev|*.io) return 1 ;;
  esac
  # reject code expressions that merely READ an env var (not a literal secret):
  # os.environ.get(...), os.getenv(...), process.env.X, import.meta.env.X,
  # Deno.env.get(...), ${VAR}, $VAR, <template>, {interpolation}
  case "$v" in
    os.*|process.env*|import.meta*|Deno.env*|'$'*|'${'*|'{'*|'<'*|*environ*|*getenv*|*getEnv*) return 1 ;;
  esac
  return 0
}

# ── locate git repos under ROOT (bash 3.2: no mapfile) ──────────────────────
REPOS=()
while IFS= read -r d; do
  [ -z "$d" ] && continue
  REPOS+=("$d")
done < <(find "$ROOT" -type d -name .git -prune 2>/dev/null | sed 's#/\.git$##' | sort)

# If ROOT itself is a repo but has no nested repos found, ensure it's included.
if [ "${#REPOS[@]}" -eq 0 ] && [ -d "$ROOT/.git" ]; then
  REPOS=("$ROOT")
fi
# Also treat ROOT as a plain dir (non-git) fallback: still grep the tree.
if [ "${#REPOS[@]}" -eq 0 ]; then
  REPOS=("$ROOT")
fi

echo "${BOLD}Secret Hygiene Scan${RST}"
echo "Root:        $ROOT"
echo "Repos found: ${#REPOS[@]}"
echo "History:     $( [ "$SCAN_HISTORY" = "1" ] && echo ON || echo off )"
command -v gitleaks   >/dev/null 2>&1 && echo "gitleaks:    detected (will run in addition)" || echo "gitleaks:    ${DIM}not installed — using git+grep fallback${RST}"
command -v trufflehog >/dev/null 2>&1 && echo "trufflehog:  detected (will run in addition)"
echo

scan_repo() {
  local repo="$1"
  local name
  name="$(basename "$repo")"
  echo "${BOLD}▸ $name${RST} ${DIM}($repo)${RST}"

  local is_git=1
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || is_git=0

  # ---- 1. tracked env files ----
  if [ "$is_git" = 1 ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      # allow .env.example
      case "$f" in */.env.example|.env.example) continue ;; esac
      if [[ "$f" =~ $ENV_FILE_RE ]]; then
        hit_high "tracked env file committed to git: ${BOLD}$f${RST}  → git rm --cached, then ROTATE its contents"
      fi
    done < <(git -C "$repo" ls-files 2>/dev/null | grep -E "$ENV_FILE_RE" || true)
  else
    # non-git: just note stray env files on disk
    while IFS= read -r f; do
      case "$f" in */.env.example) continue ;; esac
      hit_warn "env file on disk (repo not git-tracked): $f"
    done < <(find "$repo" -maxdepth 3 -type f -name '.env*' ! -name '.env.example' 2>/dev/null || true)
  fi

  # ---- 2 & 3. key prefixes + high-entropy in TRACKED files ----
  local files
  if [ "$is_git" = 1 ]; then
    files="$(git -C "$repo" ls-files 2>/dev/null)"
  else
    files="$(cd "$repo" && find . -type f \
      -not -path '*/node_modules/*' -not -path '*/.next/*' \
      -not -path '*/.git/*' -not -path '*/dist/*' -not -path '*/build/*' \
      -not -path '*/.venv/*' 2>/dev/null | sed 's#^\./##')"
  fi

  local f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    # skip binaries / lockfiles / this scanner's own patterns
    case "$f" in
      *.png|*.jpg|*.jpeg|*.gif|*.webp|*.mp4|*.mov|*.webm|*.zip|*.psd|*.ai|*.pdf|*.ico|*.woff*|*.ttf|*.otf) continue ;;
      *package-lock.json|*pnpm-lock.yaml|*yarn.lock) continue ;;
    esac
    local path="$repo/$f"
    [ -f "$path" ] || continue

    # (2) known key prefixes
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      local m
      m="$(printf '%s' "$line" | grep -oE "$KEY_PATTERNS" | head -1)"
      [ -z "$m" ] && continue
      case "$f" in
        */.env.example|.env.example)
          hit_high "real key in .env.example (placeholder expected!): $f  →  $(mask "$m")" ;;
        *)
          hit_high "key prefix in tracked file: $f  →  $(mask "$m")" ;;
      esac
    done < <(grep -aInE "$KEY_PATTERNS" "$path" 2>/dev/null | cut -d: -f2- | head -20)

    # test-mode keys → INFO
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      local m
      m="$(printf '%s' "$line" | grep -oE 'sk_test_[A-Za-z0-9]{16,}|pk_test_[A-Za-z0-9]{16,}|EZTK_[A-Za-z0-9]{20,}' | head -1)"
      [ -n "$m" ] && hit_info "test-mode key (usually safe): $f  →  $(mask "$m")"
    done < <(grep -aInE 'sk_test_|pk_test_|EZTK_' "$path" 2>/dev/null | cut -d: -f2- | head -10)

    # (3) high-entropy KEY=VALUE in env-like / config files only
    case "$f" in
      *.env*|*.sh|*.yml|*.yaml|*.json|*.ts|*.tsx|*.js|*.jsx|*.py|*.toml|*.ini)
        while IFS= read -r kv; do
          # kv like KEY=VALUE or KEY: VALUE (strip quotes)
          local key val
          key="$(printf '%s' "$kv" | sed -E 's/^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*[:=].*/\2/')"
          val="$(printf '%s' "$kv" | sed -E 's/^[^:=]*[:=][[:space:]]*//; s/^["'"'"']//; s/["'"'"'][[:space:]]*,?$//')"
          # strip a trailing " # inline comment" (space + hash) that would
          # otherwise inflate the value length / defeat placeholder detection
          val="$(printf '%s' "$val" | sed -E 's/[[:space:]]+#.*$//; s/[[:space:]]+$//')"
          [ -z "$key" ] && continue
          # only care about secret-ish var names
          case "$key" in
            *KEY*|*SECRET*|*TOKEN*|*PASSWORD*|*PASSWD*|*PRIVATE*|*CREDENTIAL*) : ;;
            *) continue ;;
          esac
          if looks_random "$val"; then
            case "$f" in
              */.env.example|.env.example)
                hit_high "non-placeholder value in .env.example: $f → $key=$(mask "$val")" ;;
              *)
                # browser-exposed prefix = worse
                if [[ "$key" == VITE_* || "$key" == NEXT_PUBLIC_* ]]; then
                  hit_high "secret in browser-exposed var: $f → $key=$(mask "$val")"
                else
                  hit_warn "high-entropy value: $f → $key=$(mask "$val")"
                fi ;;
            esac
          fi
        done < <(grep -aInE '^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*[:=]' "$path" 2>/dev/null | cut -d: -f2- | head -100)
        ;;
    esac
  done <<< "$files"

  # ---- 4. git HISTORY ----
  if [ "$is_git" = 1 ] && [ "$SCAN_HISTORY" = "1" ]; then
    # grep across all commits for key prefixes (masked)
    while IFS= read -r hline; do
      [ -z "$hline" ] && continue
      local commit m
      commit="$(printf '%s' "$hline" | cut -d: -f1)"
      m="$(printf '%s' "$hline" | grep -oE "$KEY_PATTERNS" | head -1)"
      [ -z "$m" ] && continue
      hit_high "key in git HISTORY (commit ${commit:0:9}) — ROTATE, present in pushed history: $(mask "$m")"
    done < <(git -C "$repo" grep -aInE "$KEY_PATTERNS" $(git -C "$repo" rev-list --all 2>/dev/null) 2>/dev/null | head -40 || true)

    # committed env files anywhere in history
    while IFS= read -r ef; do
      [ -z "$ef" ] && continue
      case "$ef" in */.env.example|.env.example) continue ;; esac
      hit_warn "env file existed in history: $ef  (rotate contents; history is permanent)"
    done < <(git -C "$repo" log --all --pretty=format: --name-only --diff-filter=A 2>/dev/null | grep -E "$ENV_FILE_RE" | sort -u | head -40 || true)
  fi

  # ---- optional external scanners ----
  if [ "$is_git" = 1 ] && command -v gitleaks >/dev/null 2>&1; then
    echo "  ${DIM}running gitleaks…${RST}"
    if [ "$SCAN_HISTORY" = "1" ]; then
      gitleaks detect --source "$repo" --no-banner --redact 2>/dev/null | sed 's/^/    /' || true
    else
      gitleaks detect --source "$repo" --no-git --no-banner --redact 2>/dev/null | sed 's/^/    /' || true
    fi
  fi
  if [ "$is_git" = 1 ] && command -v trufflehog >/dev/null 2>&1; then
    echo "  ${DIM}running trufflehog…${RST}"
    trufflehog filesystem "$repo" --only-verified --no-update 2>/dev/null | sed 's/^/    /' || true
  fi

  echo
}

for r in "${REPOS[@]}"; do
  scan_repo "$r"
done

echo "${BOLD}── Summary ──${RST}"
printf '  %sHIGH: %d%s   %sWARN: %d%s   %sinfo: %d%s\n' \
  "$RED$BOLD" "$HIGH_COUNT" "$RST" "$YEL" "$WARN_COUNT" "$RST" "$DIM" "$INFO_COUNT" "$RST"

if [ "$HIGH_COUNT" -gt 0 ]; then
  echo
  echo "  ${RED}HIGH findings present.${RST} Runbook: ~/.claude/skills/secret-hygiene-scan/references/rotate-and-log.md"
  echo "  Reminder: untracking a file does NOT remove it from git history — ROTATE the key."
  exit 1
fi
exit 0
