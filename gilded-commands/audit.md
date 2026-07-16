---
description: Quick house security + quality audit of the current venture (secrets, route auth, RLS, dead links)
allowed-tools: Bash, Read, Grep, Glob
---
Run a fast security + quality sweep of the CURRENT venture (cwd), reusing the ecosystem's own tooling rather than ad-hoc greps:

1. **Secrets** — run the secret-hygiene-scan skill's scanner on this repo:
   `~/.claude/skills/secret-hygiene-scan/scripts/scan-secrets.sh .`
   Add `SCAN_HISTORY=1` if I ask for a history scan.
2. **API routes** — if this is a Next.js app with `app/api`, run the route-hardening skill's `audit-routes.sh` (auth / IDOR / webhook HMAC / SSRF / rate-limit).
3. **RLS** — if there's a `supabase/` folder, run the rls-migration-writer skill's `audit-rls.sh`.
4. **Dead links/routes** — compare nav/footer link targets against defined routes; flag mismatches.
5. Summarize findings by severity (HIGH / WARN / INFO).

Report only — do not modify code. For a deeper application-security review, hand off to the **security-engineer** agent.
