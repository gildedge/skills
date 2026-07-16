---
description: Pre-deploy checklist for the current venture (env vars in Vercel, webhook/cron secrets, prod build) — GO/NO-GO
allowed-tools: Bash, Read
---
Run pre-deploy verification for the CURRENT venture (cwd) before shipping to Vercel, using the **vercel-deploy-check** skill:

1. Parse `.env.example` and verify each var is actually set in Vercel (`vercel env ls`, or a manual checklist if the CLI isn't authenticated).
2. Flag webhook/cron/bot secrets that must be registered provider-side (Stripe, Telegram, n8n) — not just present in env.
3. `vercel env pull` and diff the key-set against `.env.example`.
4. Run a production build (auto-detect Vite vs Next).
5. Emit a clear **GO / NO-GO** verdict.

Do NOT run `vercel --prod` yourself. Only after showing me a GO verdict and getting my explicit confirmation.
