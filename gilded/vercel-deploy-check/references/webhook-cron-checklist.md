# Provider-Side Registration & Cold-Start State Checklist

Setting an env var in Vercel is necessary but **not sufficient** for
webhooks, crons, and bots. These are the manual, dashboard-side steps the
script can't perform. Walk through every item that applies to the venture.

## Stripe webhook

- [ ] Endpoint registered in **Stripe → Developers → Webhooks** pointing at the
      **prod** URL (e.g. `https://<app>.vercel.app/api/stripe/webhook`), not
      localhost.
- [ ] The endpoint's **signing secret** matches `STRIPE_WEBHOOK_SECRET` in Vercel
      (Production scope). Each app has its own endpoint → its own secret.
- [ ] For Stripe Connect (gilded-art-works): the **Connect** webhook is a
      separate endpoint → `STRIPE_CONNECT_WEBHOOK_SECRET`.
- [ ] Live-mode keys (`sk_live_`) in prod, test-mode (`sk_test_`) in preview/dev.

## Telegram bot  (the ARIA failure)

Setting `TELEGRAM_BOT_TOKEN` in Vercel does nothing on its own — Telegram has to
be told where to deliver updates.

- [ ] Register the webhook once, pointing at the deployed route:
      ```
      curl "https://api.telegram.org/bot<TOKEN>/setWebhook?url=https://<app>.vercel.app/api/telegram"
      ```
- [ ] Confirm it stuck:
      ```
      curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"
      ```
      `url` should be the prod URL and `pending_update_count` sane.
- [ ] `TELEGRAM_CHAT_ID` set (from `getUpdates` after messaging the bot).

> ARIA's Telegram integration silently received nothing in prod because this
> `setWebhook` step was skipped even though the token and route both existed.

## Vercel Cron

- [ ] Cron jobs declared in **`vercel.json`** (`{"crons":[{"path":"/api/…","schedule":"…"}]}`).
- [ ] The route verifies the caller with `CRON_SECRET` (compare the incoming
      `Authorization`/query secret to `process.env.CRON_SECRET`).
- [ ] `CRON_SECRET` set in Vercel matches what the route checks.
- [ ] `AUTOMATION_WEBHOOK_SECRET` / `DOWNLOAD_SECRET` similarly verified where used.

## n8n webhooks

- [ ] `N8N_WEBHOOK_CONTENT` / `N8N_WEBHOOK_LEAD` point at the **Production** URLs
      from n8n (the `/webhook/…` path), **not** the `/webhook-test/…` test URLs.
- [ ] The n8n workflows are **Active** (not just saved).

## Serverless cold-start state  (the in-memory Map failure)

Vercel functions are stateless and freeze between requests; each cold start (and
each concurrent lambda) has its own fresh memory.

- [ ] No conversation/session/rate-limit/history state kept in a **module-level
      `Map`/`Set`/object**. That state is wiped on every cold start and is not
      shared across concurrent instances — "worked locally, empty in prod."
- [ ] Durable state lives in **Supabase** (or Redis/Upstash), keyed per user.
- [ ] Rate limiters that must be global use a shared store, not process memory.

> Symptom: chat/history/rate-limit counters that "reset randomly" in production.
> Cause: an in-memory `Map` used as if it were a database.

## Final gate

- [ ] `deploy-check.sh` printed **GO** (required vars set, build clean).
- [ ] Every applicable box above is ticked.
- [ ] Only then: `cd ventures/<app> && vercel --prod`.
