# Rotate-and-Log Runbook

Use this for every **HIGH** finding from `scan-secrets.sh`. A key that was ever
committed (working tree OR history) is compromised — untracking the file is not
enough. **Rotate it.**

## 0. Untrack the file (if a tracked env file was found)

```bash
cd <repo>
git rm --cached .env.local            # keep the local copy, stop tracking it
grep -q '^\.env' .gitignore || printf '.env\n.env.*\n!.env.example\n' >> .gitignore
```

Commit this yourself — the skill never auto-commits. Note: this removes the file
going forward but the value is still in pushed history. Continue to step 1.

## 1. Rotate in the provider dashboard

Find the dashboard in `~/GILDED-EDGE-ECOSYSTEM/PROVISIONING_CHECKLIST.md`. Common ones:

| Service | Dashboard |
|---|---|
| Google AI (Gemini) | https://aistudio.google.com/apikey |
| Stripe | https://dashboard.stripe.com/apikeys |
| Supabase | https://supabase.com/dashboard (Settings → API) |
| Resend | https://resend.com/api-keys |
| ElevenLabs | https://elevenlabs.io/app/settings/api-keys |
| Replicate | https://replicate.com/account/api-tokens |
| EasyPost | https://www.easypost.com/account/api-keys |
| Kling | (Kling dashboard) |
| Telegram | @BotFather |

Delete/revoke the old key, generate a new one. Label it `<app>-<env>`
(e.g. `lumier-studios-prod`).

## 2. Land the new value in EXACTLY two places (never the repo)

1. **Vercel** — Project → Settings → Environment Variables → correct scope
   (Production / Preview / Development). Or:
   ```bash
   cd ventures/<app>
   vercel env add <VAR_NAME> production      # paste value at the prompt
   ```
2. **Local** — the app's `.env.local` (gitignored).

Never paste the raw value into any tracked file, commit message, wiki, or the
inventory table.

## 3. Log it (labels/prefixes only)

```bash
cd ~/GILDED-EDGE-ECOSYSTEM
scripts/log-provisioned-key.sh <app> <service> <app>-<env>
# service ∈ {google-ai, stripe, supabase, resend, elevenlabs, other}
```

This updates the inventory table in `ECOSYSTEM_HEALTH.md`. The helper already
truncates to a short label — good.

## 4. Check off + verify

- Tick the row in `PROVISIONING_CHECKLIST.md`.
- Re-run: `bash ~/.claude/skills/secret-hygiene-scan/scripts/scan-secrets.sh <repo>`
- For history hits, also run with `SCAN_HISTORY=1` to confirm you've accounted
  for every commit. Ecosystem policy is **rotate-only, no history rewrite** — so
  a clean re-scan of the working tree + a rotated key is the definition of done.

## Incident cross-reference

- **lumier-studios** — ElevenLabs key in `app/.env.local` → rotate ElevenLabs, log `lumier-studios elevenlabs lumier-studios-prod`.
- **mirofish** — committed `.env`/`.env.bak` → rotate `LLM_API_KEY`/`ZEP_API_KEY`, log `mirofish other`.
- **lumier-pictures** — Kling keys in `.env.example` history (`b680eec`) → rotate `KLING_ACCESS_KEY`/`KLING_SECRET_KEY`, log `lumier-pictures other`.
