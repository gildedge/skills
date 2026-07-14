---
name: edge-function-scaffold
description: Scaffolds a new Supabase (Deno) Edge Function that matches the exact conventions of the 8 functions shipped in gilded-estate-works — inlined shared CORS headers, OPTIONS preflight + method guard, an env-key presence check, the Gemini-proxy request/response pattern (server-side GEMINI_API_KEY, gemini-2.5-flash, candidates[0].content.parts[0].text extraction), a service-role Supabase client, the Stripe raw-body signature-verify webhook shape, and a consistent { error, detail } error envelope with matching HTTP status. Use whenever creating or fixing a Supabase Edge Function under supabase/functions/, when someone says "new edge function", "scaffold a Supabase function", "add a gemini proxy / AI proxy function", "an edge function that calls Gemini", "a Stripe webhook function", "proxy an external API server-side", or "match the estate-works functions". Includes a local `supabase functions serve` test note.
---

# Edge Function Scaffold

`gilded-estate-works/supabase/functions/` has 8 functions (`gemini-proxy`, `call-intelligence`, `property-lookup`, `property-lookup-byod`, `integration-connect`, `create-checkout`, `stripe-webhook`, `property-vision-iq`). They share one skeleton. This skill emits a new function in that skeleton so a new one is copy-consistent instead of ad-hoc.

## When to use

- Adding any function under `ventures/<venture>/supabase/functions/<name>/index.ts`.
- Standing up a **Gemini / AI proxy** so the API key stays server-side and never enters a client bundle.
- Proxying a third-party API (RentCast, PropertyRadar, etc.) with a service-role Supabase cache.
- A **Stripe webhook** receiver (raw body + signature verification).

For Next.js App Router API routes (`src/app/api/**/route.ts`) use `crud-route-scaffold` / `route-hardening` instead — those are a different runtime (Node, not Deno) and a different shape.

## Ground-truth conventions (from the 8 real functions)

**Runtime & imports (Deno, URL imports — no npm/package.json):**
```ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";           // when DB access needed
import Stripe from "https://esm.sh/stripe@14.14.0?target=deno";                   // stripe only
```

**CORS is inlined per function** — there is **no `_shared/` folder** in this repo. Every function declares its own `corsHeaders`:
```ts
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",   // webhooks also add: stripe-signature (to Allow-Headers)
};
```

**The skeleton every function follows:**
1. `if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });` — preflight.
2. Method guard → `405 { error: "Method not allowed" }` (except webhooks, which accept the provider POST only).
3. Required-secret presence check → `500 { error: "<KEY> not configured ..." }` before doing work.
4. `try { const {...} = await req.json(); ...validate... }`; missing/invalid input → `400`.
5. Do the work; on caught error `console.error(...)` then `500`.

**Error envelope is uniform:** `new Response(JSON.stringify({ error, detail }), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } })`. `detail` is `String(err)` or the upstream error text. Success responses are also JSON with `...corsHeaders`.

**Gemini proxy pattern (the key-safety core):**
- `const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");` — server-side only, **never** shipped to the browser. The whole reason these functions exist.
- `const MODEL = "gemini-2.5-flash";`
- URL: `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}`.
- Body: `{ contents: [{ parts: [{ text: prompt }] }], systemInstruction: { parts: [{ text }] }, generationConfig: { temperature, maxOutputTokens } }`.
- Extract: `data?.candidates?.[0]?.content?.parts?.[0]?.text || ""`.
- On non-`ok`: read `await res.text()`, `console.error`, and mirror the upstream status.
- For **multimodal** (audio/image) push an `{ inlineData: { mimeType, data: base64 } }` part first (see `call-intelligence`) — strip a leading `data:...,` prefix from the base64.
- If the function must return **structured JSON**, use the `gemini-structured-output` skill (responseSchema + Zod validation) on top of this proxy.

**Service-role Supabase client (server functions bypass RLS deliberately):**
```ts
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);
```
Used for caching (`property_cache` upsert with `onConflict`) and webhook writes (`subscriptions` upsert). `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` are auto-injected into the function runtime.

**Auth:** these functions rely on the Supabase gateway's `verify_jwt` (on by default) or take a `user_id`/API key in the body; none hand-roll JWT parsing. **Webhooks and public callbacks must set `verify_jwt = false`** in `supabase/config.toml` (or `--no-verify-jwt` on deploy) or Supabase rejects the unauthenticated provider call before your code runs. If you need the caller's identity inside the function, read the `Authorization` header and call `supabase.auth.getUser(jwt)`.

**Stripe webhook shape:** read the **raw** body with `await req.text()` (never `req.json()` — signature verification needs the exact bytes), require the `stripe-signature` header, `stripe.webhooks.constructEvent(body, sig, STRIPE_WEBHOOK_SECRET)` inside try/catch → `400` on failure, `switch (event.type)`, respond `{ received: true }`. Instantiate Stripe with `httpClient: Stripe.createFetchHttpClient()` and `apiVersion: "2023-10-16"`.

## Workflow

1. **Pick the template:** `gemini` (text AI proxy), `proxy` (third-party API + service-role cache), or `webhook` (Stripe raw-body verify). Decide whether it needs DB access and whether it is publicly callable (→ `verify_jwt = false`).
2. **Scaffold (dry-run first).** Prints `index.ts` to stdout; nothing is written until `--write`:
   ```bash
   bash ~/.claude/skills/edge-function-scaffold/scripts/new-edge-function.sh \
     --name lead-enrichment --template gemini
   # writes into gilded-estate-works by default; override with --venture
   bash ~/.claude/skills/edge-function-scaffold/scripts/new-edge-function.sh \
     --name paddle-webhook --template webhook --venture gildedge-portal --write
   ```
3. **Fill the body.** Replace the placeholder input fields and, for the `gemini` template, the `SYSTEM_PROMPT` constant and `generationConfig`. For `proxy`, wire the upstream URL/headers and the cache table.
4. **Register secrets & JWT policy.** `supabase secrets set GEMINI_API_KEY=...` (etc.). For a webhook add to `supabase/config.toml`:
   ```toml
   [functions.paddle-webhook]
   verify_jwt = false
   ```
5. **Serve locally & smoke-test:**
   ```bash
   supabase functions serve <name> --env-file ./supabase/.env.local
   # then, in another shell:
   curl -i -X POST http://localhost:54321/functions/v1/<name> \
     -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
     -H "Content-Type: application/json" \
     -d '{"prompt":"ping"}'
   # webhooks: forward real signed events with `stripe listen --forward-to ...`
   ```
   Confirm the OPTIONS preflight returns `ok`, a bad method returns 405, and a missing-secret run returns the 500 config error.
6. **Deploy:** `supabase functions deploy <name>` (add `--no-verify-jwt` for public webhooks if not set in config.toml).

## Before / after

**Before — a hand-rolled function that leaks the key and 500s inconsistently:**
```ts
serve(async (req) => {
  const { prompt } = await req.json();                       // no CORS, no method guard
  const r = await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" + Deno.env.get("GEMINI_API_KEY"), { method: "POST", body: JSON.stringify({ contents:[{parts:[{text:prompt}]}] }) });
  return new Response(await r.text());                        // no error envelope, browsers CORS-blocked
});
```

**After — the house skeleton (what the generator emits):**
```ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const MODEL = "gemini-2.5-flash";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
  if (!GEMINI_API_KEY) {
    return new Response(JSON.stringify({ error: "GEMINI_API_KEY not configured on server" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  try {
    const { prompt, systemInstruction } = await req.json();
    if (!prompt || typeof prompt !== "string") {
      return new Response(JSON.stringify({ error: "Missing 'prompt' field in request body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const url = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}`;
    const body: Record<string, unknown> = {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.3, maxOutputTokens: 2048 },
    };
    if (systemInstruction) body.systemInstruction = { parts: [{ text: systemInstruction }] };

    const res = await fetch(url, {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body),
    });
    if (!res.ok) {
      const errText = await res.text();
      console.error("Gemini API error:", errText);
      return new Response(JSON.stringify({ error: "Gemini API error", detail: errText }),
        { status: res.status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const data = await res.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text || "";
    return new Response(JSON.stringify({ text, raw: data }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    console.error("Edge function error:", err);
    return new Response(JSON.stringify({ error: "Internal server error", detail: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
```

## Ecosystem gotchas

- **No `_shared/` module** in this repo — CORS is inlined. Don't `import ... from "../_shared/cors.ts"`; it doesn't exist here. (If you introduce one, add it to every function and document it.)
- **Never `req.json()` a webhook** — Stripe signature verification needs the exact raw bytes from `req.text()`. Parsing first breaks `constructEvent`.
- **`verify_jwt` bites webhooks & OAuth callbacks.** Public/provider-called functions must set `verify_jwt = false` (config.toml) or deploy `--no-verify-jwt`, or Supabase 401s the call before your handler runs.
- **`GEMINI_API_KEY` is the whole point — keep it server-side.** Never move it to `NEXT_PUBLIC_*` or a client fetch. The proxy exists so the key never ships in a bundle.
- **Pin the same versions** as the existing functions (`std@0.168.0`, `supabase-js@2`, `stripe@14.14.0?target=deno`) so behavior stays consistent across the 8.
- **Env vars are `Deno.env.get(...)`**, not `process.env`. `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` are auto-injected; your own keys need `supabase secrets set`.
- **Service-role client bypasses RLS** — only for trusted server work (cache, webhook writes). Do not echo service-role data straight back to an unauthenticated caller.

## Files in this skill

- `scripts/new-edge-function.sh` — dry-run generator; prints an `index.ts` for `--template gemini|proxy|webhook`. `--write` to save under the venture's `supabase/functions/<name>/`.
- `references/gemini-proxy.ts` — the full text-AI proxy reference.
- `references/stripe-webhook.ts` — the raw-body signature-verify webhook reference.
