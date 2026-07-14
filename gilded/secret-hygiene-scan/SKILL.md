---
name: secret-hygiene-scan
description: >-
  Scans the Gilded Edge ecosystem (all ventures) or a single venture repo for
  committed secrets and env-hygiene problems — tracked .env/.env.local/.env.bak
  files, high-entropy strings, known key prefixes (sk_, pk_, AIza, xoxb-, EZAK_,
  r8_, etc.), AND secrets buried in git HISTORY (not just the working tree).
  Zero-dependency by default (git + grep + shell); optionally uses gitleaks or
  trufflehog if installed. Use this whenever the user asks to "scan for secrets",
  "check for leaked keys", "secret hygiene", "did we commit a .env", "audit
  before pushing", "rotate a leaked key", or after any incident where an API key
  may have been committed. NEVER prints unmasked secret values.
---

# Secret Hygiene Scan

Find committed secrets and env-file hygiene problems across the Gilded Edge
ecosystem, then rotate-and-log anything that leaked. Works with **no external
tools** — just `git`, `grep`, and shell. `gitleaks`/`trufflehog` are used only
if they happen to be installed.

> On this machine, `gitleaks` and `brew` are **NOT** installed. The scanner is
> designed to run fully without them. Do not tell the user to `brew install`
> anything — the git+grep path is the supported path.

## When to use

- "Scan the ecosystem for secrets" / "check a repo before I push"
- "Did we commit a real `.env` anywhere?"
- "There's a leaked key — help me rotate it"
- Post-incident cleanup (see **Real incidents** below)
- Routine hygiene before a big push or org-wide audit

## What it detects

1. **Tracked env files** — `.env`, `.env.local`, `.env.bak`, `.env.production`,
   etc. that are actually committed to git (`.env.example` is allowed and
   ignored). Checks both the working tree and `git ls-files`.
2. **Known key prefixes in tracked files** — `sk_live_`, `sk_test_`, `pk_live_`,
   `AIza` (Google), `xoxb-`/`xoxp-` (Slack), `r8_` (Replicate), `EZAK_`/`EZTK_`
   (EasyPost), `re_` (Resend), `SG.` (SendGrid), `ghp_`/`gho_` (GitHub),
   `sk-` (OpenAI), plus ElevenLabs/Kling-style long hex/base64 assignments.
3. **High-entropy assignments** — `KEY=<longrandomstring>` where the value looks
   random (crude entropy heuristic), excluding obvious placeholders like
   `your_..._here`, `changeme`, `xxxx`, empty values.
4. **Secrets in git HISTORY** — greps every blob across all commits, so a key
   that was committed then "removed" is still caught (removal from the working
   tree does NOT remove it from history — the key must be rotated).

Everything is **masked** on output: only a prefix + length is ever shown
(e.g. `sk_live_51H…  [len 107]`). Full values are never printed.

## Workflow

### 1. Run the scanner

Whole ecosystem (all ventures + infrastructure):

```bash
bash ~/.claude/skills/secret-hygiene-scan/scripts/scan-secrets.sh ~/GILDED-EDGE-ECOSYSTEM
```

A single venture:

```bash
bash ~/.claude/skills/secret-hygiene-scan/scripts/scan-secrets.sh ~/GILDED-EDGE-ECOSYSTEM/ventures/lumier-studios
```

Include git history (slower, but catches removed-but-not-rotated keys):

```bash
SCAN_HISTORY=1 bash ~/.claude/skills/secret-hygiene-scan/scripts/scan-secrets.sh ~/GILDED-EDGE-ECOSYSTEM/ventures/lumier-pictures
```

The script auto-detects `gitleaks`/`trufflehog` and runs them **in addition**
to the built-in checks if present. Exit code is `1` if any finding is
`HIGH` severity (tracked env file or live key), else `0`.

### 2. Triage findings

For each finding the scanner prints: severity, repo, file (or commit for
history hits), the matched **rule**, and a **masked** sample. Classify:

- **Tracked live env file** (`.env`, `.env.local`, `.env.bak`) → HIGH. Must be
  untracked + rotated.
- **Live key prefix** (`sk_live_`, real `AIza…`, ElevenLabs/Kling key) → HIGH.
  Rotate immediately.
- **Test/placeholder** (`sk_test_`, `your_..._here`, blank) → INFO. No action.
- **History-only hit** → the file may be clean now, but the secret is public in
  history. **Rotation is the only fix** (this ecosystem's chosen remediation is
  rotate-only, no history rewrite — see the Kling incident note).

### 3. Remediate — untrack the file (does NOT remove from history)

```bash
cd <repo>
git rm --cached .env.local          # stop tracking; keep local copy
echo ".env.local" >> .gitignore     # if not already ignored
# ensure .env.example is still allowed through:
grep -q '!.env.example' .gitignore || echo '!.env.example' >> .gitignore
```

Then **commit the removal manually** — the skill never auto-commits. Remind the
user that removal from the tree does not scrub history; the leaked value must be
rotated regardless.

### 4. Rotate-and-log runbook

This ties into the ecosystem's real tooling. For every HIGH finding:

1. **Rotate** the key in the provider dashboard (get the new value). Dashboards
   are listed in `~/GILDED-EDGE-ECOSYSTEM/PROVISIONING_CHECKLIST.md`.
2. **Set the new value** in two places (never in the repo):
   - Vercel → Project → Settings → Environment Variables (correct env scope)
   - the app's local `.env.local` (gitignored)
3. **Log it** in the inventory table using the ecosystem's helper (labels/
   prefixes only, never the raw value):

   ```bash
   cd ~/GILDED-EDGE-ECOSYSTEM
   scripts/log-provisioned-key.sh <app> <service> <app>-<env>
   # e.g. scripts/log-provisioned-key.sh lumier-studios elevenlabs lumier-studios-prod
   # service ∈ {google-ai, stripe, supabase, resend, elevenlabs, other}
   ```

4. **Check it off** in `PROVISIONING_CHECKLIST.md`.
5. Re-run the scanner to confirm the working tree is clean.

A copy of this runbook lives at
`~/.claude/skills/secret-hygiene-scan/references/rotate-and-log.md`.

## Real incidents (this ecosystem)

These actually happened — use them as the canonical examples of what "HIGH"
looks like and confirm each is resolved when you scan:

| Incident | Location | Status / action |
|---|---|---|
| Live **ElevenLabs** key in a committed `.env.local` | `ventures/lumier-studios/app/.env.local` | Untrack + rotate ElevenLabs key, log as `lumier-studios-prod` |
| Committed **`.env` and `.env.bak`** | `infrastructure/mirofish/` | Untrack both, rotate anything inside (LLM_API_KEY / ZEP_API_KEY), log as `other` |
| Live **Kling** keys in `.env.example` | `ventures/lumier-pictures/.env.example` (history commit `b680eec`, pushed) | File sanitized; **keys must be rotated** in Kling dashboard. Remediation = rotate-only, no history rewrite → the values are in history, so rotation is mandatory |

The Kling case is the reason **history scanning matters**: the working-tree file
was sanitized, but the secret is permanent in the pushed history — the only real
fix is rotation.

## Ecosystem gotchas

- **`.env.example` is intentionally committed** and is the one env file allowed
  through `.gitignore` (`!.env.example`). Never flag it as HIGH *unless* it
  contains a real key value (the Kling incident) — real values in `.env.example`
  are a HIGH finding, placeholders (`your_..._here`) are not.
- **`VITE_` / `NEXT_PUBLIC_` vars are browser-exposed by design.** A provider
  secret in a `VITE_`/`NEXT_PUBLIC_` var is a leak even if it's "just" an env
  var — Lumier Pictures' `.env.example` warns about exactly this. The scanner
  flags real-looking secrets in `VITE_`/`NEXT_PUBLIC_` assignments.
- **Removing a file from the tree ≠ removing from history.** Always rotate.
- **This repo's policy is one key per app per service** — a rotated key should be
  re-provisioned per-app, not shared.
- The scanner is **read-only**: it never writes, never commits, never prints full
  secrets. All remediation commands above are for the user/Claude to run
  deliberately.

## Files in this skill

- `SKILL.md` — this file
- `scripts/scan-secrets.sh` — the zero-dependency scanner (optional gitleaks/trufflehog)
- `references/rotate-and-log.md` — the rotate-and-log runbook
