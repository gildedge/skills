#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
# new-edge-function.sh — scaffold a Supabase (Deno) edge function in the
# gilded-estate-works house style (inlined CORS, OPTIONS + method guard,
# env-key check, { error, detail } envelope).
#
# DRY-RUN BY DEFAULT: prints index.ts to stdout. Pass --write to save it
# under <venture>/supabase/functions/<name>/index.ts. Pure bash 3.2,
# no exotic deps. Read-only unless --write.
#
# Usage:
#   new-edge-function.sh --name lead-enrichment --template gemini
#   new-edge-function.sh --name paddle-webhook  --template webhook --write
#   new-edge-function.sh --name zillow-lookup   --template proxy \
#     --venture gilded-estate-works --write
#
# Flags:
#   --name      <name>   kebab-case function name (required)
#   --template  gemini|proxy|webhook   (default: gemini)
#   --venture   <name>   target venture (default: gilded-estate-works)
#   --write              write the file instead of printing
# ══════════════════════════════════════════════════════════════════
set -e

NAME=""
TEMPLATE="gemini"
VENTURE="gilded-estate-works"
WRITE=0
ROOT="${GILDED_ROOT:-$HOME/GILDED-EDGE-ECOSYSTEM}"
REFDIR="$(dirname "$0")/../references"

while [ $# -gt 0 ]; do
  case "$1" in
    --name)     NAME="$2";     shift 2 ;;
    --template) TEMPLATE="$2"; shift 2 ;;
    --venture)  VENTURE="$2";  shift 2 ;;
    --write)    WRITE=1;       shift ;;
    -h|--help)  grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$NAME" ]; then echo "ERROR: --name is required" >&2; exit 2; fi
case "$NAME" in
  [a-z]*) : ;;
  *) echo "ERROR: --name must be kebab-case (start with a-z): '$NAME'" >&2; exit 2 ;;
esac

OUT="$ROOT/ventures/$VENTURE/supabase/functions/$NAME/index.ts"

# ── proxy template (third-party API + service-role cache) ──────────
gen_proxy() {
cat <<'TS'
// ═══════════════════════════════════════════════════════════════════
// __NAME__ — Supabase edge function (third-party API proxy + cache)
// Proxies an upstream API server-side and caches results with the
// service-role client. Keeps the upstream API key off the client.
// Secrets: UPSTREAM_API_KEY (+ SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY auto-injected)
// ═══════════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const UPSTREAM_API_KEY = Deno.env.get("UPSTREAM_API_KEY") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const CACHE_TTL_HOURS = 24;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const { query } = await req.json();
    if (!query || typeof query !== "string") {
      return new Response(JSON.stringify({ error: "Missing 'query' field" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const key = query.trim().toLowerCase();
    const expiry = new Date(Date.now() - CACHE_TTL_HOURS * 3600 * 1000).toISOString();

    // ── cache read ──
    const { data: cached } = await supabase
      .from("__SNAKE___cache")
      .select("*")
      .eq("cache_key", key)
      .gte("cached_at", expiry)
      .single();
    if (cached) {
      return new Response(JSON.stringify({ ...cached.payload, source: "cached" }), {
        status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ── upstream fetch ──
    const res = await fetch(`https://api.example.com/v1/lookup?q=${encodeURIComponent(query)}`, {
      headers: { Authorization: `Bearer ${UPSTREAM_API_KEY}`, Accept: "application/json" },
    });
    if (!res.ok) {
      const detail = await res.text();
      console.error("Upstream error:", detail);
      return new Response(JSON.stringify({ error: "Upstream API error", detail }), {
        status: res.status, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const payload = await res.json();

    // ── cache write ──
    await supabase.from("__SNAKE___cache").upsert(
      { cache_key: key, payload, cached_at: new Date().toISOString() },
      { onConflict: "cache_key" }
    );

    return new Response(JSON.stringify({ ...payload, source: "live" }), {
      status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("__NAME__ error:", err);
    return new Response(JSON.stringify({ error: "Internal server error", detail: String(err) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
TS
}

emit_body() {
  case "$TEMPLATE" in
    gemini)  cat "$REFDIR/gemini-proxy.ts" ;;
    webhook) cat "$REFDIR/stripe-webhook.ts" ;;
    proxy)   SNAKE="$(printf '%s' "$NAME" | tr '-' '_')"
             gen_proxy | sed -e "s/__SNAKE__/$SNAKE/g" -e "s/__NAME__/$NAME/g" ;;
    *) echo "ERROR: --template must be gemini|proxy|webhook: '$TEMPLATE'" >&2; exit 2 ;;
  esac
}

if [ "$WRITE" -eq 1 ]; then
  mkdir -p "$(dirname "$OUT")"
  emit_body > "$OUT"
  echo "Wrote: $OUT"
  echo
  echo "Next:"
  echo "  1. Fill the input fields / SYSTEM_PROMPT / upstream URL."
  echo "  2. supabase secrets set <KEY>=..."
  if [ "$TEMPLATE" = "webhook" ]; then
    echo "  3. Add to supabase/config.toml:  [functions.$NAME]  verify_jwt = false"
  fi
  echo "  4. supabase functions serve $NAME --env-file ./supabase/.env.local"
  echo "  5. supabase functions deploy $NAME"
else
  echo "# DRY RUN — nothing written. Re-run with --write to save into $VENTURE."
  echo "# Target: $OUT"
  echo "# Template: $TEMPLATE"
  echo "# ────────────────────────────────────────────────────────────────"
  emit_body
fi
