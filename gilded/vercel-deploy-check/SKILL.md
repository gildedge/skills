---
name: vercel-deploy-check
description: >-
  Pre-deploy verification for a Gilded Edge venture before shipping to Vercel.
  Parses the venture's .env.example, checks each var is actually set in Vercel
  (via `vercel env ls` when the CLI is authenticated, else emits a manual
  checklist), flags webhook/cron secrets that must be registered on the provider
  side (Stripe/Telegram/n8n) rather than only in env, runs `vercel env pull` and
  diffs it against .env.example, and runs a production build. Emits a go/no-go
  checklist. Use whenever the user says "check before deploy", "pre-deploy
  check", "is <app> ready to ship", "verify Vercel env", "did I set all the env
  vars", "deploy checklist", or is about to run `vercel --prod`. Degrades
  gracefully with no Vercel CLI (produces the manual checklist).
---

# Vercel Deploy Check

Run a go/no-go gate before deploying a Gilded Edge venture to Vercel. Catches the
two failure modes that have actually bitten this ecosystem:

1. **A var is in `.env.example` but was never set in Vercel** → runtime crash or
   silent misbehavior in prod.
2. **A webhook/cron secret exists in env but the endpoint was never registered
   on the provider side** → the integration never fires. (See the real
   ARIA-Telegram incident below.)

Works with the Vercel CLI when it's authenticated; falls back to a **manual
checklist** when it isn't. It never deploys for you — it produces a report and
you decide.

## When to use

- "Is `<app>` ready to deploy?" / "pre-deploy check" / "deploy checklist"
- Right before `vercel --prod`
- "Did I set all the env vars in Vercel?" / "verify my Vercel config"
- After adding a new integration (Stripe webhook, cron job, Telegram bot)

## Workflow

### 1. Run the checker against a venture

```bash
bash ~/.claude/skills/vercel-deploy-check/scripts/deploy-check.sh ~/GILDED-EDGE-ECOSYSTEM/ventures/gildedge-portal
```

Optional flags (env vars):

- `VERCEL_ENV=production` (default) — which scope to check (`production`/`preview`/`development`)
- `RUN_BUILD=0` — skip the prod build step (faster dry run)
- `PULL=0` — skip `vercel env pull` diff

The script:

1. **Parses `.env.example`** into the canonical required-var list (ignoring
   comments/blank values), noting which are `NEXT_PUBLIC_`/`VITE_` (client) vs
   server-only.
2. **Checks Vercel** — if `vercel` is authenticated, runs `vercel env ls` and
   reports, per var: `SET` / `MISSING` / (client var present, etc.). If the CLI
   is missing or not linked, it prints a **manual checklist** to tick off in the
   Vercel dashboard instead.
3. **Flags provider-side registrations** — any var matching webhook/cron/bot
   patterns (`*WEBHOOK_SECRET`, `STRIPE_WEBHOOK_SECRET`, `CRON_SECRET`,
   `TELEGRAM_BOT_TOKEN`, `N8N_WEBHOOK_*`, `AUTOMATION_WEBHOOK_SECRET`) is listed
   with a reminder that setting the env var is **not sufficient** — the endpoint
   must also be registered with the provider (see checklist in
   `references/webhook-cron-checklist.md`).
4. **`vercel env pull` diff** — pulls the real env into a temp file and diffs the
   *key set* against `.env.example` (values are never printed) to surface
   drift in both directions (missing in Vercel, or set in Vercel but undocumented).
5. **Prod build** — runs the repo's build (`npm run build`, or `vite build`/
   `next build` as detected) to catch build-time failures before deploy.

### 2. Read the go/no-go verdict

The script ends with a **GO** / **NO-GO** line and an exit code (`0` = GO,
`1` = NO-GO). NO-GO triggers: any required server var MISSING in Vercel, or the
build failing. Webhook/cron reminders are **warnings** (manual verification
required) — surface them to the user but they don't auto-fail.

### 3. Manual verification the script can't do

Some things need eyes on a dashboard — walk the user through
`references/webhook-cron-checklist.md`:

- **Stripe webhook** endpoint URL registered in Stripe → Developers → Webhooks,
  and its signing secret matches `STRIPE_WEBHOOK_SECRET` in Vercel.
- **Telegram bot** webhook registered via
  `https://api.telegram.org/bot<TOKEN>/setWebhook?url=<prod-url>/api/telegram`
  (the ARIA failure — see below).
- **Cron jobs** declared in `vercel.json` and their `CRON_SECRET` matches.
- **n8n** production webhook URLs live (not the test URLs).

## Real failures this guards against

- **ARIA Telegram webhook never registered.** The `TELEGRAM_BOT_TOKEN` was set
  in Vercel, the `/api/telegram` route existed, but the bot's webhook was never
  pointed at the deployed URL via `setWebhook`. Result: the bot silently
  received nothing in production. Setting the env var is necessary but **not
  sufficient** — the provider-side registration is a separate manual step this
  checklist forces you to confirm.

- **In-memory `Map` history resetting on cold start.** Serverless functions on
  Vercel are stateless and freeze/cold-start between invocations. Any
  conversation/session/rate-limit state kept in a module-level `Map` (or plain
  object) is **wiped on every cold start** and not shared across concurrent
  lambda instances — so "it worked locally" but history vanished in prod. The
  build step and `references/webhook-cron-checklist.md` remind you: persistent
  state must live in Supabase/Redis/a durable store, not process memory. The
  checker greps the source for `new Map(`/module-level mutable state used as a
  store and warns if it looks like request-scoped persistence.

## Ecosystem gotchas

- **`.env.example` is the source of truth** for what a venture needs — it's the
  one env file committed to each repo (`!.env.example` in `.gitignore`). This
  skill treats every non-placeholder-named key in it as required.
- **`VITE_` / `NEXT_PUBLIC_` vars are client-exposed.** They must be set at
  **build time** in Vercel (baked into the bundle), so a missing one won't throw
  at runtime — it just ships `undefined`. The checker calls these out separately.
- **Vite vs Next builds differ.** Vite ventures (`edge-design-works`,
  `lumier-pictures`, `gilded-estate-works`, `gilded-travel-works`,
  `creative-deal-analyzer`) use `vite build`; Next ventures use `next build`. The
  script detects from `package.json`.
- **One key per app per service** (ecosystem policy) — a var being set in another
  app's Vercel project does not count. Check the specific project.
- **`vercel env pull` writes `.env.local`** by default — the script pulls into a
  temp file instead and never commits or overwrites the working `.env.local`.
- Read-only: the script never deploys, never writes secrets to the repo, never
  prints secret values.

## Files in this skill

- `SKILL.md` — this file
- `scripts/deploy-check.sh` — the verifier (Vercel CLI optional; manual-checklist fallback)
- `references/webhook-cron-checklist.md` — provider-side registration + cold-start-state checklist
