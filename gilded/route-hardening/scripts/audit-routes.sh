#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# audit-routes.sh — READ-ONLY per-route security checklist for Next.js
# App Router API handlers (app/api/**/route.ts) in the Gilded Edge stack.
#
# Per route it reports the exported HTTP methods and a ✓/✗/– for:
#   AUTH   session / requireApiUser / cron-secret / hmac present
#   OWNER  DB query scoped by user_id/owner_id (only if the route hits the DB)
#   HMAC   webhook signature verified before side effects (webhook routes)
#   SSRF   outbound fetch(userUrl) guarded by checkOutboundUrl (only if it fetches)
#   RATE   uses the shared checkRateLimit()
#   [SVC]  uses the service-role client (RLS bypassed → auth+scoping mandatory)
#
# Signals, not proof — always open the ✗ files to confirm.
#
# Usage:
#   audit-routes.sh <dir>            # e.g. .../src/app/api
#   audit-routes.sh <dir> --md       # Markdown table
#
# Pure grep/shell. Never writes.
# ══════════════════════════════════════════════════════════════════
set -uo pipefail

MD=0
DIR=""
for a in "$@"; do
  case "$a" in
    --md) MD=1 ;;
    *) DIR="$a" ;;
  esac
done
DIR="${DIR:-.}"
[[ -d "$DIR" ]] || { echo "ERROR: dir not found: $DIR" >&2; exit 2; }

# while-read, not mapfile — macOS ships bash 3.2 which lacks mapfile.
ROUTES=()
while IFS= read -r _r; do [[ -n "$_r" ]] && ROUTES+=("$_r"); done < <(find "$DIR" -type f -name 'route.ts' | sort)
[[ ${#ROUTES[@]} -gt 0 ]] || { echo "No route.ts files under $DIR" >&2; exit 2; }

RED=$'\033[0;31m'; YEL=$'\033[0;33m'; GRN=$'\033[0;32m'; DIM=$'\033[2m'; RST=$'\033[0m'
[[ -t 1 && "$MD" -eq 0 ]] || { RED=""; YEL=""; GRN=""; DIM=""; RST=""; }

OK="${GRN}✓${RST}"; BAD="${RED}✗${RST}"; NA="${DIM}–${RST}"
[[ "$MD" -eq 1 ]] && { OK="OK"; BAD="MISSING"; NA="n/a"; }

# helpers ------------------------------------------------------------
has() { grep -qE "$1" "$2" 2>/dev/null; }
methods() {
  grep -oE 'export +(async +)?function +(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)' "$1" \
    | grep -oE '(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)' | paste -sd, - 2>/dev/null
}

flagged=0

if [[ "$MD" -eq 1 ]]; then
  echo "| Route | Methods | Auth | Owner | HMAC | SSRF | Rate | Svc-role |"
  echo "|-------|---------|------|-------|------|------|------|----------|"
else
  echo "Route hardening audit — ${#ROUTES[@]} route(s) under $DIR"
  echo "AUTH / OWNER / HMAC / SSRF / RATE   ([SVC]=service-role client, RLS bypassed)"
  echo "══════════════════════════════════════════════════════════════════"
fi

for f in "${ROUTES[@]}"; do
  rel="${f#"$DIR"/}"
  m="$(methods "$f")"; [[ -z "$m" ]] && m="(none)"

  # Signals -----------------------------------------------------------
  is_webhook=0;  [[ "$rel" == *webhook* || "$rel" == *stripe* ]] && is_webhook=1
  hits_db=0;     has '\.from\(' "$f" && hits_db=1
  does_fetch=0;  has '[^a-zA-Z]fetch\(' "$f" && does_fetch=1
  uses_svc=0;    has 'SERVICE_ROLE_KEY|getAdmin|getSupabaseAdmin|createAdminClient' "$f" && uses_svc=1

  # AUTH: session getUser, house guards, cron secret, or a signature check
  auth="$BAD"
  if has 'auth\.getUser|requireApiUser|requireApiAdmin|requireCron|CRON_SECRET|constructEvent|verify(Hmac|LemonSqueezy|Slack|Calendly)|hasValidIngestToken' "$f"; then
    auth="$OK"
  fi

  # OWNER scoping — only meaningful if the route touches the DB
  if [[ "$hits_db" -eq 1 ]]; then
    if has '\.eq\(\s*['"'"'"](user_id|owner_id)['"'"'"]' "$f"; then owner="$OK"; else owner="$BAD"; fi
  else
    owner="$NA"
  fi

  # HMAC — only meaningful for webhook routes
  if [[ "$is_webhook" -eq 1 ]]; then
    if has 'constructEvent|verify(Hmac|LemonSqueezy|Slack|Calendly)|timingSafeEqual' "$f"; then hmac="$OK"; else hmac="$BAD"; fi
  else
    hmac="$NA"
  fi

  # SSRF — only if the route makes an outbound fetch
  if [[ "$does_fetch" -eq 1 ]]; then
    if has 'checkOutboundUrl|isPrivateIp' "$f"; then ssrf="$OK"; else ssrf="$BAD"; fi
  else
    ssrf="$NA"
  fi

  # RATE limiter
  if has 'checkRateLimit|rateLimit\(|RATE_LIMITS' "$f"; then rate="$OK"; else rate="$BAD"; fi

  svc="$NA"; [[ "$uses_svc" -eq 1 ]] && svc="${YEL}SVC${RST}"
  [[ "$MD" -eq 1 && "$uses_svc" -eq 1 ]] && svc="yes"

  # Count a routes as flagged if any applicable check is missing.
  if [[ "$auth" == "$BAD" || "$owner" == "$BAD" || "$hmac" == "$BAD" || "$ssrf" == "$BAD" ]]; then
    flagged=$((flagged+1))
  fi

  if [[ "$MD" -eq 1 ]]; then
    echo "| $rel | $m | $auth | $owner | $hmac | $ssrf | $rate | $svc |"
  else
    printf '%s\n' "$rel"
    printf '    methods: %-28s AUTH:%s OWNER:%s HMAC:%s SSRF:%s RATE:%s %s\n' \
      "$m" "$auth" "$owner" "$hmac" "$ssrf" "$rate" \
      "$([[ "$uses_svc" -eq 1 ]] && echo "[${YEL}SVC${RST}]" || echo "")"
  fi
done

if [[ "$MD" -eq 0 ]]; then
  echo "══════════════════════════════════════════════════════════════════"
  echo "Legend: ${OK} present  ${BAD} missing  ${NA} not applicable  [${YEL}SVC${RST}] service-role client (RLS bypassed)"
  if [[ "$flagged" -gt 0 ]]; then
    echo "${RED}$flagged route(s) have at least one applicable check missing.${RST} Open them and apply references/guards.ts."
  else
    echo "${GRN}No applicable checks missing.${RST} (Still eyeball service-role routes.)"
  fi
fi

[[ "$flagged" -gt 0 ]] && exit 1 || exit 0
