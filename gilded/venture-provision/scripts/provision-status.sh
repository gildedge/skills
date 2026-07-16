#!/usr/bin/env bash
# provision-status.sh — resumable per-app provisioning progress.
#
# Usage:  provision-status.sh <app> [repo-path]
# Example: provision-status.sh aria-agent
#          provision-status.sh gildedge-portal ~/GILDED-EDGE-ECOSYSTEM/ventures/gildedge-portal
#
# Reads data/providers.tsv for <app>, then checks the app's .env.local for each
# required env var. Prints DONE (variable present) / PENDING (missing) per provider.
#
# SAFETY: only ever inspects whether a variable NAME exists. It never reads, prints,
# or logs any secret VALUE.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TSV="$SKILL_DIR/data/providers.tsv"

APP="${1:-}"
if [ -z "$APP" ]; then
  echo "Usage: $0 <app> [repo-path]"
  echo "Apps in map:"
  awk -F'\t' 'NF && $1 !~ /^#/ && $1 != "app" {print "  "$1}' "$TSV" | sort -u
  exit 1
fi

# Resolve repo path: explicit arg, else guess under the ecosystem root.
ECO_ROOT="${GILDED_EDGE_ROOT:-$HOME/GILDED-EDGE-ECOSYSTEM}"
REPO="${2:-}"
if [ -z "$REPO" ]; then
  if [ -d "$ECO_ROOT/ventures/$APP" ]; then
    REPO="$ECO_ROOT/ventures/$APP"
  elif [ -d "$ECO_ROOT/infrastructure/$APP" ]; then
    REPO="$ECO_ROOT/infrastructure/$APP"
  else
    REPO="$ECO_ROOT/ventures/$APP"
  fi
fi

ENVFILE="$REPO/.env.local"

GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'

echo "${CYAN}Provisioning status: ${APP}${NC}"
echo "Repo:      $REPO"
if [ -f "$ENVFILE" ]; then
  echo "Env file:  $ENVFILE (present)"
else
  echo "Env file:  ${YELLOW}$ENVFILE (not found — all keys will read PENDING)${NC}"
fi
echo "Label policy: <app>-<env>  ·  one key per app per service, never shared"
echo ""

# Is a given VAR name defined (non-empty) in .env.local?
var_present() {
  local var="$1"
  [ -f "$ENVFILE" ] || return 1
  # match:  VAR=...  or  export VAR=...  with a non-empty value
  grep -Eq "^[[:space:]]*(export[[:space:]]+)?${var}=[^[:space:]].*" "$ENVFILE"
}

DONE=0; PENDING=0; ROWS=0
# awk splits on tab; skip comments/header/other apps.
while IFS=$'\t' read -r app provider service label env_vars dashboard notes; do
  case "$app" in ''|'#'*|'app') continue ;; esac
  [ "$app" = "$APP" ] || continue
  ROWS=$((ROWS+1))

  # A provider row is DONE only if ALL its env vars are present.
  missing=""
  IFS=',' read -ra VARS <<< "$env_vars"
  for v in "${VARS[@]}"; do
    v="$(echo "$v" | tr -d '[:space:]')"
    [ -z "$v" ] && continue
    if ! var_present "$v"; then
      missing="${missing:+$missing }$v"
    fi
  done

  if [ -z "$missing" ]; then
    printf "  ${GREEN}DONE   ${NC} %-28s %s\n" "$provider" "[$env_vars]"
    DONE=$((DONE+1))
  else
    printf "  ${RED}PENDING${NC} %-28s label=${YELLOW}%s${NC}\n" "$provider" "$label"
    printf "           needs: %s\n" "$missing"
    printf "           create: %s\n" "$dashboard"
    [ -n "${notes:-}" ] && printf "           note: %s\n" "$notes"
    PENDING=$((PENDING+1))
  fi
done < "$TSV"

echo ""
if [ "$ROWS" -eq 0 ]; then
  echo "${YELLOW}No providers mapped for '$APP'. Check the app slug against data/providers.tsv.${NC}"
  exit 1
fi
echo "${YELLOW}---${NC}"
printf "%s providers:  ${GREEN}%s done${NC} · ${RED}%s pending${NC}\n" "$ROWS" "$DONE" "$PENDING"
if [ "$PENDING" -gt 0 ]; then
  echo "Next: create the top PENDING key (human step), then land it with:"
  echo "  set-local-env.sh $REPO <ENV_VAR>"
  echo "  push-vercel-env.sh $REPO <ENV_VAR> production"
  echo "  (cd $ECO_ROOT && scripts/log-provisioned-key.sh $APP <service-slug> <label>)"
else
  echo "${GREEN}All mapped providers landed locally for $APP.${NC} Verify Vercel + inventory, then run scripts/audit-ecosystem.sh."
fi
