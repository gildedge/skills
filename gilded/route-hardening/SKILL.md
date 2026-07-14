---
name: route-hardening
description: Audits and hardens Next.js App Router API routes (app/api/**/route.ts) across the Gilded Edge ventures for the exact security holes their 2026-07 audits found — missing session auth, DB queries not scoped to the owner (IDOR), webhook receivers with no HMAC/signature check, SSRF in outbound fetch to user-supplied URLs, and missing or duplicated in-memory rate limiters. Use whenever writing or reviewing an API route, when someone says "harden this route", "is this endpoint safe", "audit the API", "add auth to this route", "check for IDOR/SSRF", "verify the webhook", "rate limit this", or before shipping/deploying a route that touches money, email, the database, or an outbound request. Produces a per-route checklist report and scaffolds the guard code (requireApiUser, owner-scoping, HMAC verify, checkOutboundUrl, shared rate limiter) using the ecosystem's existing helpers.
---

# Route Hardening

Bring a Next.js **App Router** `route.ts` handler up to the Gilded Edge security bar. Grounded in real findings from `gilded-art-works/AUDIT_2026-07-04.md` and the `lumier-studios` review:

- `gilded-art-works`: unauthenticated `/api/errors` writing via the **service-role** client (RLS bypassed, spoofable `user_id`, forgeable `critical` audit rows); an integrations webhook receiver that accepted anonymous POSTs with **no signature check**; **SSRF** in the outbound webhook dispatchers (POST to user-supplied URLs, no host validation); and **three duplicate** in-memory rate limiters (`rate-limit.ts`, `rate-limiter.ts`, one inside `proxy.ts`).
- `lumier-studios`: unauthenticated **money-spending** AI endpoints (Gemini/ElevenLabs quota burn) and a **forgeable payment webhook**.

## When to use

- Writing a new `app/api/**/route.ts`, or reviewing one before merge/deploy.
- Any endpoint that: reads/writes the DB, spends money (AI, email, payments), or makes an outbound `fetch` to a URL that isn't a hard-coded constant.
- Triage: "which of my routes are unauthenticated / un-scoped / unverified?"

## The five checks

For **every** route, answer each. The auditor script does a first pass; you confirm by reading the file.

1. **Session auth.** Does a mutating or data-returning handler call `supabase.auth.getUser()` (or a guard that does) and 401 when there's no user? Cron/webhook/public routes are the *only* exemptions, and they must have their own gate (CRON_SECRET / HMAC / a deliberately-public predicate).
2. **Owner scoping (IDOR).** Does every DB query filter by the caller's id — `.eq('user_id', user.id)` (or `owner_id`) — on SELECT/UPDATE/DELETE? A route that takes an `id` from the query/body and doesn't also constrain by owner lets any user touch any tenant's row.
3. **Webhook signature.** Is the raw body HMAC-verified before any side effect? Stripe → `stripe.webhooks.constructEvent`. Others → the helpers in `@/lib/webhook-utils` (`verifyHmacSha256`, `verifyLemonSqueezySignature`, `verifySlackSignature`, `verifyCalendlySignature`). Read the **raw** body with `await request.text()` — never `request.json()` first, or the signature won't match.
4. **SSRF on outbound fetch.** Before `fetch(userUrl)`, is the URL passed through `checkOutboundUrl()` from `@/lib/url-guard` (blocks non-HTTPS, loopback, RFC-1918, link-local `169.254.169.254`, CGNAT)? Never fetch a user-supplied host raw.
5. **Rate limiting.** Do sensitive routes (auth, keys, email, checkout, AI, webhooks-test) call the **one shared** `checkRateLimit(request, ...RATE_LIMITS.x)` from `@/lib/rate-limit`? Do **not** add a fourth copy — reuse the shared limiter (and prefer a durable store like Upstash for anything that must hold across serverless instances).

## Workflow

1. **Audit the tree (read-only) to get the per-route report:**
   ```bash
   bash ~/.claude/skills/route-hardening/scripts/audit-routes.sh \
     ~/GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works/src/app/api
   ```
   For each `route.ts` it prints which HTTP methods are exported and a ✓/✗/– for auth, owner-scoping, webhook-verify, SSRF-guard, and rate-limit — plus a flag if the route uses the **service-role** client (RLS bypassed → auth + manual scoping are mandatory). Add `--md` for a Markdown table.
2. **Read every ✗ route** and confirm the finding (the grep is a signal, not proof — e.g. a route may auth via a helper the grep didn't catch).
3. **Scaffold the missing guards** by copying from `references/guards.ts` (drop-in snippets that use the ecosystem's real helpers). Keep the house style: `NextResponse.json({ error }, { status })`, `console.error('[Route] ...', err)`.
4. **Re-run the auditor** to confirm the ✗ became ✓.

## Before / after

### 1. Add session auth + owner scoping (the artworks pattern)

**Before — unauthenticated, no scoping (IDOR + open write):**
```ts
export async function DELETE(request: NextRequest) {
  const supabase = getAdmin();                       // ❌ service-role, RLS bypassed
  const id = new URL(request.url).searchParams.get('id');
  await supabase.from('artworks').delete().eq('id', id);   // ❌ any id, any tenant
  return NextResponse.json({ success: true });
}
```

**After — session required, delete constrained to the owner:**
```ts
import { NextRequest, NextResponse } from 'next/server';
import { createServerSupabase } from '@/lib/supabase/server';

export async function DELETE(request: NextRequest) {
  const supabase = await createServerSupabase();     // anon client → RLS applies
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const id = new URL(request.url).searchParams.get('id');
  if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });

  const { error } = await supabase
    .from('artworks')
    .delete()
    .eq('id', id)
    .eq('user_id', user.id);                         // ✓ owner-scoped
  if (error) {
    console.error('[Artworks] Delete error:', error);
    return NextResponse.json({ error: 'Failed to delete' }, { status: 500 });
  }
  return NextResponse.json({ success: true });
}
```

> In `lumier-studios`, the house guard is `requireApiUser()` from `@/lib/api-auth`:
> ```ts
> const auth = await requireApiUser();
> if (auth instanceof NextResponse) return auth;     // 401
> // auth is the Supabase User — use auth.id to scope queries
> ```
> Use it on every money-spending AI route (`/api/ai/*`) so anonymous callers can't burn Gemini/ElevenLabs quota.

### 2. Verify a webhook before any side effect

**Before — forgeable (accepts anonymous POSTs, no signature):**
```ts
export async function POST(request: NextRequest) {
  const payload = await request.json();              // ❌ body trusted as-is
  if (payload.event === 'order_created') await markInvoicePaid(payload);
  return NextResponse.json({ received: true });
}
```

**After — HMAC-verified raw body (Lemon Squeezy shown; Stripe uses constructEvent):**
```ts
import { verifyLemonSqueezySignature } from '@/lib/webhook-utils';

export async function POST(request: NextRequest) {
  const secret = process.env.LEMONSQUEEZY_WEBHOOK_SECRET;
  if (!secret) return NextResponse.json({ error: 'Not configured' }, { status: 500 });

  const rawBody = await request.text();              // ✓ raw body, before JSON.parse
  const signature = request.headers.get('x-signature') || '';
  if (!verifyLemonSqueezySignature(rawBody, signature, secret)) {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 401 });
  }

  const payload = JSON.parse(rawBody);
  // ... dispatch. Make handlers idempotent (skip if already processed).
  return NextResponse.json({ received: true });
}
```

### 3. Guard an outbound fetch against SSRF

**Before:**
```ts
await fetch(sub.url, { method: 'POST', body });      // ❌ user-supplied host
```

**After — reuse the canonical guard:**
```ts
import { checkOutboundUrl } from '@/lib/url-guard';

const guard = await checkOutboundUrl(sub.url);       // blocks http, loopback, RFC-1918, 169.254.169.254
if (!guard.ok) throw new Error(`blocked destination: ${guard.reason}`);
const res = await fetch(guard.url, { method: 'POST', body /* + AbortController timeout */ });
```

### 4. Rate-limit with the shared limiter (don't add a 4th copy)

```ts
import { checkRateLimit, RATE_LIMITS } from '@/lib/rate-limit';

export async function POST(request: NextRequest) {
  const limited = checkRateLimit(request, ...RATE_LIMITS.checkout);  // 5/min
  if (limited) return limited;                        // 429
  // ...
}
```
If a venture has drifted into `rate-limiter.ts` or an inline limiter inside `proxy.ts`, consolidate onto `rate-limit.ts` rather than importing whichever one is nearest.

## Ecosystem gotchas

- **`getAdmin()` fallback foot-gun.** Several routes define `getAdmin()` as `createClient(url, SERVICE_ROLE_KEY || ANON_KEY)`. The silent `|| ANON_KEY` means admin ops degrade to anon and fail confusingly *and* any route using the service-role client has **no RLS backstop** — so auth + explicit `.eq('user_id', ...)` scoping in the handler is the only thing protecting the data. Prefer the anon `createServerSupabase()` unless the route genuinely needs to bypass RLS (webhooks, cron), and if it does, gate it hard.
- **Raw body for signatures.** App Router lets you read the body once. For any signed webhook, `await request.text()` first, verify, *then* `JSON.parse` — calling `request.json()` first breaks Stripe/LS/Slack signature checks.
- **`x-forwarded-host` / `next` redirect trust.** Auth-callback style routes must validate `next` starts with a single `/` and pin the redirect host to an allowlist; don't trust client `x-forwarded-host` in prod.
- **In-memory rate limits reset on cold start** and don't share across serverless instances — fine as a speed bump, not as a real quota. Money/auth routes that need durable limits should move to Upstash/Redis.

## Files in this skill

- `scripts/audit-routes.sh` — read-only per-route checklist auditor (text or `--md` table).
- `references/guards.ts` — drop-in guard snippets wired to the ecosystem's real helpers (`createServerSupabase`, `requireApiUser`, `webhook-utils`, `url-guard`, `rate-limit`).
