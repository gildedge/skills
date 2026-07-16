#!/usr/bin/env bash
# push-vercel-env.sh — push one secret to Vercel for the right env scope.
#
# Usage:  push-vercel-env.sh <repo-path> <ENV_VAR> <production|preview|development>
#
# If the `vercel` CLI is present and the repo is linked, pipes a silently-read
# value into `vercel env add`. Otherwise prints exact manual dashboard steps.
#
# SAFETY: value is read with `read -s` and piped straight to the CLI on stdin.
# It is NEVER printed, echoed, or logged. No masked value is shown either.

set -euo pipefail

REPO="${1:-}"
VAR="${2:-}"
SCOPE="${3:-production}"

if [ -z "$REPO" ] || [ -z "$VAR" ]; then
  echo "Usage: $0 <repo-path> <ENV_VAR> <production|preview|development>"
  exit 1
fi
case "$SCOPE" in
  production|preview|development) ;;
  *) echo "Scope must be production | preview | development"; exit 1 ;;
esac
if ! printf '%s' "$VAR" | grep -Eq '^[A-Z_][A-Z0-9_]*$'; then
  echo "Refusing: '$VAR' is not a valid ENV_VAR name."; exit 1
fi

YELLOW=$'\033[1;33m'; GREEN=$'\033[0;32m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'

if ! command -v vercel >/dev/null 2>&1; then
  echo "${YELLOW}vercel CLI not found.${NC} Add it manually:"
  echo "  1. ${CYAN}https://vercel.com${NC} → your project → Settings → Environment Variables"
  echo "  2. Name: ${VAR}   Scope: ${SCOPE}"
  echo "  3. Paste the value (from the provider dashboard) and Save."
  echo "  Or install the CLI:  npm i -g vercel  &&  (cd $REPO && vercel link)"
  exit 0
fi

echo "vercel CLI found. Pushing ${VAR} to scope=${SCOPE} for repo $REPO"
printf "Paste value for %s (input hidden): " "$VAR" 1>&2
read -rs VALUE
echo 1>&2
if [ -z "$VALUE" ]; then
  echo "Empty value — aborting."; exit 1
fi

# `vercel env add <NAME> <ENV>` reads the value from stdin. Pipe it in; never echo it.
if ( cd "$REPO" && printf '%s' "$VALUE" | vercel env add "$VAR" "$SCOPE" ); then
  VALUE=""
  echo "${GREEN}✓ Pushed $VAR to Vercel ($SCOPE).${NC}"
  echo "  Verify later with:  (cd $REPO && vercel env pull .env.vercel.check)  # then delete that file"
else
  VALUE=""
  echo "${YELLOW}vercel env add did not complete.${NC} If the var already exists, remove then re-add,"
  echo "or set it in the dashboard: Project → Settings → Environment Variables."
  exit 1
fi
