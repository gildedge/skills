#!/usr/bin/env bash
#
# deploy-check.sh — pre-deploy go/no-go verification for a Gilded Edge venture.
#
# Usage:
#   deploy-check.sh <venture-path>
#
# Env flags:
#   VERCEL_ENV=production|preview|development   (default: production)
#   RUN_BUILD=1|0   run prod build              (default: 1)
#   PULL=1|0        run `vercel env pull` diff  (default: 1)
#
# What it does:
#   1. Parse .env.example -> required var list (client vs server)
#   2. Check each var is set in Vercel (vercel env ls) OR emit manual checklist
#   3. Flag webhook/cron/bot secrets needing provider-side registration
#   4. `vercel env pull` and diff the KEY SET vs .env.example (no values shown)
#   5. Run the production build
#   6. Print GO / NO-GO
#
# SAFETY: read-only w.r.t. the repo. Never deploys. Never prints secret VALUES
# (only key names + SET/MISSING). Pulls env into a temp file, never overwrites
# the repo's .env.local, and shreds the temp file on exit.

# Not using `set -u`: must run on macOS stock bash 3.2 (empty-array expansion
# errors under `set -u` there).
set -o pipefail

REPO="${1:-}"
VERCEL_ENV="${VERCEL_ENV:-production}"
RUN_BUILD="${RUN_BUILD:-1}"
PULL="${PULL:-1}"

if [ -z "$REPO" ] || [ ! -d "$REPO" ]; then
  echo "Usage: deploy-check.sh <venture-path>" >&2
  exit 2
fi
REPO="$(cd "$REPO" && pwd)"
NAME="$(basename "$REPO")"

if [ -t 1 ]; then
  RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; RST=$'\033[0m'
else
  RED=""; GRN=""; YEL=""; DIM=""; BOLD=""; RST=""
fi

NOGO=0
WARN=0

echo "${BOLD}Vercel Deploy Check — $NAME${RST}"
echo "Repo:  $REPO"
echo "Scope: $VERCEL_ENV"
echo

EXAMPLE="$REPO/.env.example"
if [ ! -f "$EXAMPLE" ]; then
  echo "${YEL}No .env.example found — cannot derive required vars.${RST}"
  echo "This venture may not need env vars, or is missing its .env.example (ecosystem policy requires one)."
else
  echo "${BOLD}1. Required vars (from .env.example)${RST}"
fi

# ── parse .env.example into VAR names ────────────────────────────────────────
REQUIRED=()
CLIENT=()
if [ -f "$EXAMPLE" ]; then
  while IFS= read -r raw; do
    line="${raw%%#*}"                       # strip inline comments
    line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -z "$line" ] && continue
    case "$line" in *=*) : ;; *) continue ;; esac
    key="${line%%=*}"
    key="$(printf '%s' "$key" | sed -E 's/^export[[:space:]]+//; s/[[:space:]]*$//')"
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    REQUIRED+=("$key")
    if [[ "$key" == NEXT_PUBLIC_* || "$key" == VITE_* ]]; then
      CLIENT+=("$key")
    fi
  done < "$EXAMPLE"
  # dedupe (bash 3.2: no mapfile)
  DEDUP=()
  while IFS= read -r v; do
    [ -z "$v" ] && continue
    DEDUP+=("$v")
  done < <(printf '%s\n' "${REQUIRED[@]:-}" | awk 'NF && !seen[$0]++')
  REQUIRED=()
  if [ "${#DEDUP[@]}" -gt 0 ]; then REQUIRED=("${DEDUP[@]}"); fi
  printf '   %d vars required (%d client-exposed).\n' "${#REQUIRED[@]}" "${#CLIENT[@]}"
fi

is_client() { local k="$1"; for c in "${CLIENT[@]:-}"; do [ "$c" = "$k" ] && return 0; done; return 1; }

# ── 2. check against Vercel ──────────────────────────────────────────────────
echo
echo "${BOLD}2. Vercel environment ($VERCEL_ENV)${RST}"

HAVE_VERCEL=0
VERCEL_LINKED=0
if command -v vercel >/dev/null 2>&1; then
  HAVE_VERCEL=1
  if [ -f "$REPO/.vercel/project.json" ]; then VERCEL_LINKED=1; fi
fi

SET_KEYS=""
if [ "$HAVE_VERCEL" = 1 ]; then
  # vercel env ls <env> prints a table; extract the first column (var names).
  LS_OUT="$(cd "$REPO" && vercel env ls "$VERCEL_ENV" 2>/dev/null)"
  if [ -z "$LS_OUT" ]; then
    LS_OUT="$(cd "$REPO" && vercel env ls 2>/dev/null)"
  fi
  # var names are tokens that look like ENV_VAR (UPPER/_/digits), first col
  SET_KEYS="$(printf '%s\n' "$LS_OUT" | grep -oE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*' | sed -E 's/^[[:space:]]*//' | sort -u)"
fi

if [ "$HAVE_VERCEL" = 1 ] && [ -n "$SET_KEYS" ]; then
  for k in "${REQUIRED[@]}"; do
    if printf '%s\n' "$SET_KEYS" | grep -qx "$k"; then
      printf '   %s✓ SET%s     %s\n' "$GRN" "$RST" "$k"
    else
      if is_client "$k"; then
        printf '   %s✗ MISSING%s %s  %s(client/build-time — ships undefined if unset)%s\n' "$RED" "$RST" "$k" "$DIM" "$RST"
      else
        printf '   %s✗ MISSING%s %s\n' "$RED" "$RST" "$k"
      fi
      NOGO=1
    fi
  done
else
  echo "   ${YEL}Vercel CLI not available/linked — manual checklist:${RST}"
  echo "   ${DIM}(Vercel → $NAME → Settings → Environment Variables → $VERCEL_ENV)${RST}"
  for k in "${REQUIRED[@]}"; do
    if is_client "$k"; then
      printf '   [ ] %s   %s(client/build-time)%s\n' "$k" "$DIM" "$RST"
    else
      printf '   [ ] %s\n' "$k"
    fi
  done
  WARN=1
  [ "$HAVE_VERCEL" = 0 ] && echo "   ${DIM}Install/auth: npm i -g vercel && vercel login && vercel link${RST}"
fi

# ── 3. provider-side registration flags ─────────────────────────────────────
echo
echo "${BOLD}3. Webhook / cron / bot secrets — need provider-side registration${RST}"
FOUND_HOOK=0
for k in "${REQUIRED[@]}"; do
  case "$k" in
    *WEBHOOK_SECRET|STRIPE_WEBHOOK_SECRET|CRON_SECRET|TELEGRAM_BOT_TOKEN|N8N_WEBHOOK_*|AUTOMATION_WEBHOOK_SECRET|DOWNLOAD_SECRET|*_WEBHOOK_*)
      FOUND_HOOK=1
      printf '   %s! %s%s — env var alone is NOT enough; register the endpoint with the provider.\n' "$YEL" "$k" "$RST"
      ;;
  esac
done
if [ "$FOUND_HOOK" = 1 ]; then
  WARN=1
  echo "   ${DIM}→ Verify each in references/webhook-cron-checklist.md (Stripe webhook, Telegram setWebhook, vercel.json crons, n8n prod URLs).${RST}"
else
  echo "   ${DIM}none detected.${RST}"
fi

# ── 3b. cold-start in-memory state heuristic ────────────────────────────────
echo
echo "${BOLD}3b. Serverless cold-start state check${RST}"
STATE_HITS="$(grep -rInE '(new Map\(|new Set\(|:\s*Record<[^>]*>\s*=\s*\{\})' "$REPO/src" "$REPO/app" "$REPO/pages" "$REPO/api" "$REPO/server" 2>/dev/null \
  --include='*.ts' --include='*.tsx' --include='*.js' \
  | grep -iE 'history|session|cache|store|state|conversation|rate|memory|messages' \
  | grep -viE 'test|spec|\.d\.ts' | head -8)"
if [ -n "$STATE_HITS" ]; then
  WARN=1
  echo "   ${YEL}Possible in-memory state used as persistence (wiped on every cold start):${RST}"
  printf '%s\n' "$STATE_HITS" | sed 's#'"$REPO"'/#   #' | cut -c1-140
  echo "   ${DIM}→ On Vercel serverless, module-level Map/Set is NOT durable and NOT shared across lambdas. Move to Supabase/Redis. (ARIA history-reset failure.)${RST}"
else
  echo "   ${DIM}no obvious module-level Map/Set persistence found.${RST}"
fi

# ── 4. vercel env pull diff (key set only) ──────────────────────────────────
echo
echo "${BOLD}4. env pull diff (documented vs actually set)${RST}"
if [ "$HAVE_VERCEL" = 1 ] && [ "$PULL" = 1 ]; then
  TMP="$(mktemp -t vercelenv.XXXXXX)"
  trap 'rm -f "$TMP" 2>/dev/null' EXIT
  if (cd "$REPO" && vercel env pull "$TMP" --environment="$VERCEL_ENV" --yes >/dev/null 2>&1); then
    PULLED_KEYS="$(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$TMP" | sed 's/=$//' | sort -u)"
    DOC_KEYS="$(printf '%s\n' "${REQUIRED[@]}" | sort -u)"
    UNDOC="$(comm -13 <(printf '%s\n' "$DOC_KEYS") <(printf '%s\n' "$PULLED_KEYS"))"
    UNSET_="$(comm -23 <(printf '%s\n' "$DOC_KEYS") <(printf '%s\n' "$PULLED_KEYS"))"
    if [ -n "$UNSET_" ]; then
      echo "   ${RED}In .env.example but NOT in Vercel:${RST}"
      printf '%s\n' "$UNSET_" | sed 's/^/     - /'
      NOGO=1
    fi
    if [ -n "$UNDOC" ]; then
      echo "   ${YEL}Set in Vercel but NOT in .env.example (undocumented drift):${RST}"
      printf '%s\n' "$UNDOC" | sed 's/^/     - /'
      WARN=1
    fi
    [ -z "$UNSET_$UNDOC" ] && echo "   ${GRN}✓ key sets match.${RST}"
    rm -f "$TMP"; trap - EXIT
  else
    echo "   ${DIM}vercel env pull failed (not linked/authed) — skipping diff.${RST}"
    rm -f "$TMP" 2>/dev/null; trap - EXIT
  fi
else
  echo "   ${DIM}skipped (no Vercel CLI or PULL=0).${RST}"
fi

# ── 5. production build ─────────────────────────────────────────────────────
echo
echo "${BOLD}5. Production build${RST}"
if [ "$RUN_BUILD" = 1 ]; then
  if [ -f "$REPO/package.json" ]; then
    BUILD_CMD="npm run build"
    if command -v jq >/dev/null 2>&1; then
      HAS_BUILD="$(jq -r '.scripts.build // empty' "$REPO/package.json" 2>/dev/null)"
      [ -z "$HAS_BUILD" ] && BUILD_CMD=""
    fi
    if [ -n "$BUILD_CMD" ]; then
      echo "   ${DIM}running: $BUILD_CMD  (this can take a minute)…${RST}"
      if (cd "$REPO" && $BUILD_CMD >/tmp/deploy-check-build.$$ 2>&1); then
        echo "   ${GRN}✓ build succeeded.${RST}"
      else
        echo "   ${RED}✗ build FAILED — last 25 lines:${RST}"
        tail -25 "/tmp/deploy-check-build.$$" | sed 's/^/     /'
        NOGO=1
      fi
      rm -f "/tmp/deploy-check-build.$$" 2>/dev/null
    else
      echo "   ${YEL}no \"build\" script in package.json — skipping.${RST}"
    fi
  else
    echo "   ${DIM}no package.json (static/other) — skipping build.${RST}"
  fi
else
  echo "   ${DIM}skipped (RUN_BUILD=0).${RST}"
fi

# ── verdict ─────────────────────────────────────────────────────────────────
echo
echo "${BOLD}── Verdict ──${RST}"
if [ "$NOGO" = 1 ]; then
  echo "   ${RED}${BOLD}NO-GO${RST} — required vars missing and/or build failed. Fix above, then re-run."
  [ "$WARN" = 1 ] && echo "   ${YEL}(plus warnings to verify manually).${RST}"
  exit 1
else
  if [ "$WARN" = 1 ]; then
    echo "   ${YEL}${BOLD}GO — with manual checks${RST} — required vars OK, but verify the webhook/cron/state warnings above before \`vercel --prod\`."
  else
    echo "   ${GRN}${BOLD}GO${RST} — required vars set, build clean. Safe to \`vercel --prod\`."
  fi
  exit 0
fi
