---
name: ecosystem-scaffold-sync
description: Detect and safely reconcile fork drift between the two Gilded Edge sibling apps that were cloned from each other — gildedge-portal and edge-os-works — which share near-identical portal/, crm/, and aria/ code plus ~13 copied Supabase migrations. Use when a change lands in one fork's shared code and needs to reach the other, when the two repos' migrations or portal/CRM/ARIA folders have silently diverged, before porting a fix "the copy-paste way", or when someone says "sync the forks", "diff portal vs edge-os", "these two repos drifted", "port this change to the other app", "which migrations are out of sync", "did we duplicate this again", or "keep the shared code in step." Always diffs first (dry-run), reports drift per shared directory and per migration, and ports in ONE direction only after review — never a blind overwrite.
---

# Ecosystem Scaffold Sync — gildedge-portal ⇄ edge-os-works

`edge-os-works` was forked from `gildedge-portal` (or vice-versa). They still carry the same scaffolding:

- `src/app/portal/`, `src/app/crm/`, `src/app/portal/aria/`, `src/app/api/aria/`
- `src/components/portal/`, `src/lib/crm/`, `src/lib/aria/`
- `supabase/migrations/` — the same numbered migration set copied into both.

Because the shared code lives in two independent git repos with no shared package, a fix or schema change made in one fork does not reach the other. Over time they diverge silently. This skill makes the divergence visible and helps port it deliberately.

## Ground truth (verify with the drift script)

- **Migrations: 12 of the shared files are byte-identical copies** across both repos (`001_initial_schema` … `20260509_production_seed`). Each fork then has exactly **one** migration the other lacks:
  - only in `gildedge-portal`: `008_scrub_fabricated_metrics.sql`
  - only in `edge-os-works`: `20260514150000_lumier_social.sql`
  This is the canonical drift signature: a long identical prefix, then per-fork tails.
- **Code has drifted much further.** `src/app/portal/` shows ~70 differing/only entries between the forks; `src/app/crm/` ~5; `src/lib/aria/` ~6. edge-os-works has extra surface (Remotion/Seedance video, `generated-videos/`) that portal doesn't — not all differences are "drift to reconcile"; some are intentional per-venture features.

The skill's job is to separate *accidental* drift (a shared file edited in one fork only) from *intentional* divergence (a feature that belongs to only one venture).

## When to use

- You fixed a bug in `gildedge-portal/src/app/portal/...` and the same file exists in `edge-os-works` — port it before it rots.
- You added a migration to one fork and need to know if the other needs it too.
- Periodic hygiene: "are these two still in step?"
- Before cloning-and-editing yet another shared file (which deepens the fork).

## Workflow

1. **Report drift (always first, read-only):**
   ```bash
   bash scripts/drift-report.sh
   ```
   For each shared dir it prints: files only in A, only in B, and files present in both but differing. For `supabase/migrations` it additionally classifies every common file as SAME or DIFF and lists per-fork-only migrations (the ones that may need porting).
2. **Triage each difference.** For every "only in one fork" or "differs": decide *intentional* (venture-specific feature — leave it) or *accidental* (shared file edited in one place — port it). When unsure, read both versions before acting.
3. **Preview a one-directional port (dry-run):**
   ```bash
   bash scripts/port-change.sh --from gildedge-portal --to edge-os-works \
        --path src/app/portal/crm/leads/page.tsx
   ```
   This shows a `diff` (what would change in the destination) and does **nothing else**. `--path` may be a file or a directory.
4. **Apply only after review** by adding `--write`. The script copies `--from` → `--to` for that path, backing up any overwritten destination file to `<file>.bak-<stamp>` first. It refuses to run without an explicit `--from`/`--to` and never syncs both ways in one call.
5. **For migrations,** never rename or renumber. If `edge-os-works` genuinely needs `008_scrub_fabricated_metrics.sql`, port the file under its *existing* name so the ordering matches the source fork. Then run that venture's migration guard / `supabase db reset` to confirm it still applies cleanly.

## Gotchas

- **Direction is mandatory and single.** There is no "merge". You pick a source of truth per path and push it one way. Porting both directions in one pass is how you overwrite the wrong version — the script forbids it.
- **Never blind-overwrite.** Always run without `--write` first and read the diff. `--write` backs up the destination, but a backup is a consolation prize, not a substitute for reading the diff.
- **Not every difference is drift.** edge-os-works carries video-generation surface (`remotion/`, `seedance/`, `generated-videos/`, `extract-frames.mjs`) absent from portal. Those are intentional. Don't "sync" a venture's real feature away.
- **Migrations are append-only and ordered.** Copy under the identical filename; do not renumber to "fit". A migration ported with a new number will run in the wrong order and can collide. After porting, run the venture's `supabase db reset` (see the `supabase-migration-guard` skill) to prove it still resets cleanly.
- **Both repos also share top-level junk** (`fix_*.py`, `test-keys*.html`, `add_nosonar.py`). Those are not shared *product* code — don't treat their drift as meaningful; scope syncing to `src/app/portal`, `src/app/crm`, `src/lib/aria`, `src/lib/crm`, `src/components/portal`, and `supabase/migrations`.
- **These are separate git repos.** Porting a file does not port its history. Commit the port in the destination repo with a message referencing the source commit, e.g. `chore: port portal/leads fix from gildedge-portal@<sha>`.
- **The real fix is de-duplication.** Every port is interest paid on the fork. If a directory keeps needing sync, flag extracting it into a shared package as the durable solution — this skill treats the symptom.
