---
name: venture-provision
description: >-
  Guided, resumable API-key provisioning for the Gilded Edge ecosystem. Walks one
  app at a time through the 18-provider PROVISIONING_CHECKLIST — create key (human
  step) → push to Vercel → write to local .env.local → log to the ECOSYSTEM_HEALTH.md
  inventory — while enforcing the `<app>-<env>` label policy and "one key per app per
  service, never shared." Use when the user says things like "provision keys for
  <app>", "set up API keys", "finish provisioning", "which keys does <app> still
  need", "add the Gemini/Stripe/Supabase/Resend key for <app>", or "resume
  provisioning." NEVER prints secret values; key creation always stays a human step.
---

# venture-provision

Turns `PROVISIONING_CHECKLIST.md` (18 providers, ~50 keys across the portfolio) into a
calm, resumable, one-app-at-a-time flow. For every key an app needs, you orchestrate the
**4-step landing**:

1. **Create** the key in the provider dashboard — a **human step**. You give the exact
   dashboard URL and the exact label; the user creates it and pastes it into a secure
   prompt. You never generate, invent, or transcribe real secret values.
2. **Vercel** — add it under the right env scope (Production / Preview / Development).
3. **Local** — write it into the app's `.env.local` (gitignored).
4. **Inventory** — append the label (not the value) to `ECOSYSTEM_HEALTH.md` via
   `scripts/log-provisioned-key.sh`.

## Hard safety rules (never violate)

- **Never print, echo, log, or repeat a secret value** — not in chat, not in a tool
  call, not in a commit. The helper scripts read secrets silently and only ever display
  a masked prefix. If you ever see a raw value in a tool result, do not reproduce it.
- **Key creation is a human step.** You orchestrate and log; you do not exfiltrate,
  fetch, or fabricate keys. Entering credentials into dashboards is the user's job.
- **Never auto-commit secrets.** `.env.local` is gitignored — leave it that way. Only
  the inventory (labels/prefixes) is safe to commit, and only when the user asks.
- **One key per app per service — never share across ventures.** Each venture gets its
  own key even for the same provider. Reuse is a policy violation; flag it, don't do it.
- **Label policy `<app>-<env>`**: `-prod` for Production, `-preview` for Vercel preview,
  `-dev` for local dev. Example: `aria-agent-prod`, `gilded-form-works-dev`.
- Only the values in `data/providers.tsv` and the repo's own `.env.example` are the
  source of truth for what an app needs — don't guess env-var names.

## When to use / not use

Use for: provisioning or finishing keys for any app; "what's left for `<app>`"; resuming
a half-done pass; adding a single provider's key. Do **not** use it to rotate a leaked
key silently (that needs a deliberate rotate-and-relog), to create NEW repos
(`create-venture.sh`), or to bring a repo up to Tier-1 conventions (use the
`tier1-backfill` skill).

## Workflow

Work **one app at a time**. The checklist is organized by provider ("do all Gemini keys,
then all Stripe"), but this skill is app-scoped so progress is legible and resumable — a
person provisioning across dashboards can still follow provider order within an app.

### 1. Pick the app and show remaining work (resume point)

```bash
bash ~/.claude/skills/venture-provision/scripts/provision-status.sh <app>
```

`<app>` is the canonical folder slug (e.g. `aria-agent`, `gildedge-portal`,
`gilded-art-works`). The script reads `data/providers.tsv` for that app, checks the app's
`.env.local` for each required variable, and prints each key as **DONE** (present locally)
or **PENDING**. This derives progress from the filesystem, so it is naturally resumable —
re-run it any time to see where you left off. It **never** prints any value, only whether
the variable name exists.

Read the PENDING list back to the user and confirm which key to do next.

### 2. Create the key (human step)

For the next PENDING key, tell the user:
- the **dashboard URL** (from providers.tsv),
- the exact **label** to use: `<app>-<env>`,
- the **env-var name(s)** it maps to,
- the reminder: create a NEW key for this app — do not reuse another venture's.

Wait for the user to confirm they created it. You do not need to see the value yet.

### 3. Land the key — local, then Vercel, then inventory

**Local `.env.local`** — run the silent writer. It prompts for the value with no echo,
never prints it back, and upserts it into the app's `.env.local`:

```bash
bash ~/.claude/skills/venture-provision/scripts/set-local-env.sh <repo-path> <ENV_VAR>
# e.g. set-local-env.sh ~/GILDED-EDGE-ECOSYSTEM/ventures/aria-agent GEMINI_API_KEY
```

**Vercel** — push the same variable to the right scope. If the `vercel` CLI is present
the helper pipes the value in from a silent prompt (again, no echo); if not, it prints the
manual dashboard steps:

```bash
bash ~/.claude/skills/venture-provision/scripts/push-vercel-env.sh <repo-path> <ENV_VAR> <production|preview|development>
```

**Inventory** — log the *label* (never the value) into `ECOSYSTEM_HEALTH.md`:

```bash
cd ~/GILDED-EDGE-ECOSYSTEM
scripts/log-provisioned-key.sh <app> <service-slug> <label>
# e.g. scripts/log-provisioned-key.sh aria-agent google-ai aria-agent-prod
```

Service slugs the inventory understands: `google-ai`, `stripe`, `supabase`, `resend`,
`elevenlabs`, `other`. (The providers.tsv `service` column already gives the right slug
per row.) Anything not a first-class column lands in `other`.

### 4. Re-run status and continue

Re-run `provision-status.sh <app>` to confirm the key flipped to DONE, then move to the
next PENDING key. When an app shows all DONE, tell the user and offer the next app.

### 5. Final audit

Once the inventory is filled in, verify nothing else drifted:

```bash
cd ~/GILDED-EDGE-ECOSYSTEM && bash scripts/audit-ecosystem.sh
```

## Ecosystem gotchas

- **Env-var names differ per app for the same provider.** Gemini is `GEMINI_API_KEY` in
  `aria-agent`, but `GOOGLE_GENERATIVE_AI_API_KEY` in `gilded-form-works` and
  `VITE_GEMINI_API_KEY` in the Vite apps. Always trust `providers.tsv` / the repo
  `.env.example`, never a single canonical name.
- **Vite vs Next public vars.** Vite ventures (`edge-design-works`, `gilded-travel-works`,
  `gilded-estate-works`) use `VITE_*`; Next uses `NEXT_PUBLIC_*`. Client-exposed keys
  (anon/publishable) are still real env vars — treat them with the same care.
- **Supabase = 3 vars per project** (`*_SUPABASE_URL`, `*_ANON_KEY`,
  `SUPABASE_SERVICE_ROLE_KEY`). The service_role key is a secret — never client-side.
- **Stripe** secret key is account-wide but each app pulls it from its own env and each
  app has its **own** `STRIPE_WEBHOOK_SECRET` and price IDs.
- **Locally-generated secrets** (`CRON_SECRET`, `AUTOMATION_WEBHOOK_SECRET`,
  `DOWNLOAD_SECRET`) come from `openssl rand -hex 32`, not a dashboard. `set-local-env.sh
  --generate` can create and store one without ever displaying it.
- **`.env.local` stays gitignored.** If you find real keys staged for commit, stop and
  warn — the ecosystem has already had one leaked-secret incident.

## Files

- `data/providers.tsv` — per-app provider → env-vars → label → service-slug → dashboard.
- `scripts/provision-status.sh` — resumable per-app progress from `.env.local`.
- `scripts/set-local-env.sh` — silent-read, no-echo upsert into `.env.local` (`--generate`
  for local random secrets).
- `scripts/push-vercel-env.sh` — silent push to Vercel via CLI, or manual instructions.
