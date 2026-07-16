#!/usr/bin/env bash
# set-local-env.sh — safely write a secret into an app's .env.local.
#
# Usage:
#   set-local-env.sh <repo-path> <ENV_VAR>              # prompt silently for the value
#   set-local-env.sh <repo-path> <ENV_VAR> --generate   # generate openssl rand -hex 32
#
# SAFETY GUARANTEES:
#   - The value is read with `read -s` (no terminal echo) or generated in-process.
#   - The value is NEVER printed, echoed, or logged — only a masked prefix + length.
#   - Upserts (replaces existing line for that var, else appends). Idempotent.
#   - Refuses to touch anything but <repo>/.env.local, and ensures it is gitignored.
#   - Never runs git add/commit. .env.local must stay untracked.

set -euo pipefail

REPO="${1:-}"
VAR="${2:-}"
MODE="${3:-prompt}"

if [ -z "$REPO" ] || [ -z "$VAR" ]; then
  echo "Usage: $0 <repo-path> <ENV_VAR> [--generate]"
  exit 1
fi
if [ ! -d "$REPO" ]; then
  echo "Not a directory: $REPO"; exit 1
fi
if ! printf '%s' "$VAR" | grep -Eq '^[A-Z_][A-Z0-9_]*$'; then
  echo "Refusing: '$VAR' is not a valid ENV_VAR name (A-Z, 0-9, _)."; exit 1
fi

ENVFILE="$REPO/.env.local"
YELLOW=$'\033[1;33m'; GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; NC=$'\033[0m'

# --- obtain the value without ever echoing it ---
VALUE=""
if [ "$MODE" = "--generate" ]; then
  VALUE="$(openssl rand -hex 32)"
  echo "Generated a 64-char random secret for $VAR (value hidden)."
else
  # Read silently. Prompt goes to stderr so it works even if stdout is captured.
  printf "Paste value for %s (input hidden, will not be echoed): " "$VAR" 1>&2
  read -rs VALUE
  echo 1>&2
fi

if [ -z "$VALUE" ]; then
  echo "${RED}Empty value — aborting, nothing written.${NC}"; exit 1
fi

# --- ensure .env.local is gitignored (never commit real keys) ---
GITIGNORE="$REPO/.gitignore"
if [ -f "$GITIGNORE" ]; then
  if ! grep -Eq '(^|/)\.env(\.local|\*)?' "$GITIGNORE" 2>/dev/null; then
    echo "${YELLOW}Warning: .env.local may not be gitignored in $GITIGNORE — verify before any commit.${NC}"
  fi
else
  echo "${YELLOW}Warning: no .gitignore in repo — ensure .env.local is never committed.${NC}"
fi

# --- upsert the variable ---
touch "$ENVFILE"
chmod 600 "$ENVFILE" 2>/dev/null || true

TMP="$(mktemp)"
REPLACED=0
# Copy all lines except an existing definition of VAR.
while IFS= read -r line || [ -n "$line" ]; do
  if printf '%s' "$line" | grep -Eq "^[[:space:]]*(export[[:space:]]+)?${VAR}="; then
    REPLACED=1
    continue
  fi
  printf '%s\n' "$line" >> "$TMP"
done < "$ENVFILE"

# Append the new definition. printf avoids interpreting the value.
printf '%s=%s\n' "$VAR" "$VALUE" >> "$TMP"
mv "$TMP" "$ENVFILE"
chmod 600 "$ENVFILE" 2>/dev/null || true

# --- masked confirmation (never the raw value) ---
LEN=${#VALUE}
PREFIX="${VALUE:0:4}"
VALUE=""  # drop it from memory asap
if [ "$REPLACED" -eq 1 ]; then
  echo "${GREEN}✓ Updated${NC} $VAR in $ENVFILE  (masked: ${PREFIX}… · ${LEN} chars)"
else
  echo "${GREEN}✓ Added${NC}   $VAR in $ENVFILE  (masked: ${PREFIX}… · ${LEN} chars)"
fi
echo "  Next: push to Vercel → push-vercel-env.sh $REPO $VAR production"
echo "        log label     → scripts/log-provisioned-key.sh <app> <service> <app>-<env>"
