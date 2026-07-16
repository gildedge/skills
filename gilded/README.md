# Gilded Edge — Custom Skills

31 ecosystem-specific Claude Code skills authored from the 2026-07-14 audit
([`../../../SKILLS_AUDIT_2026-07-14.md`](../../../SKILLS_AUDIT_2026-07-14.md)).

**Source of truth.** These directories are the canonical copies. Each is symlinked
into `~/.claude/skills/<name>`, so editing here updates the live skill — no drift.

**Conventions.** Helper scripts are bash 3.2 / BSD-awk compatible, dry-run or
read-only by default, honor a `GILDED_ROOT` override, never print unmasked
secrets, and never auto-commit.

## Tier 1 — ecosystem-wide (highest leverage)
| Skill | Purpose |
|-------|---------|
| `supabase-migration-guard` | Make a venture's DB reproducible from `supabase db reset` (baseline, collision detect, CI) |
| `slug-normalize` | Remap 14→6 `venture_id` slugs + add `ventures(slug PK)` + FK guardrail |
| `rls-migration-writer` | Scaffold tables with owner-scoped RLS; refuses `WITH CHECK (true)` / recursive policies |
| `route-hardening` | Audit API routes for auth / IDOR / webhook HMAC / SSRF / rate-limit |
| `secret-hygiene-scan` | Scan working tree + git history for leaked keys (zero-dep) |
| `vercel-deploy-check` | Pre-deploy GO/NO-GO: env vars in Vercel, webhook/cron secrets, prod build |
| `venture-provision` | Guided, resumable per-app key provisioning across 18 providers |
| `tier1-backfill` | Bring an existing venture up to Tier-1 conventions, audit to green |

## Tier 2 — shared build accelerators
| Skill | Purpose |
|-------|---------|
| `crud-route-scaffold` | Full CRM entity: page + route + migration + seed |
| `edge-function-scaffold` | New Supabase Edge Function matching house conventions |
| `gemini-structured-output` | Standardized responseSchema + key-safe proxy + Zod validation |
| `prompt-eval-harness` | Golden-case regression suite for AI features (complements `prompt-lab`) |
| `crm-document-generator` | Branded invoice/quote/proposal/contract/COA PDFs |
| `media-pipeline` | Transcode / frames / transcribe / image-optimize (ffmpeg/whisper/sharp/sips) |
| `api-contract-sync` | Keep docs-web in lockstep with the FastAPI/Pydantic contract |
| `session-handoff` | Operationalize the wiki session-continuity protocol |
| `ecosystem-scaffold-sync` | Detect + safely reconcile portal ↔ edge-os fork drift |

## Tier 3 — per-venture
`cost-engine-updater`, `i18n-sync`, `itinerary-builder`, `pdf-form-filler`,
`content-waterfall-templater`, `aria-tool-scaffold`, `remotion-composition-builder`,
`shot-list-generator`, `cinematic-render-pipeline`, `deal-report-generator`,
`catalog-seeder`, `jinja-pdf-template-authoring`, `hs-code-classifier-maintainer`,
`pwa-cache-bumper`.

See each skill's own `SKILL.md` for its trigger phrases and workflow.
