---
name: supabase-migration-guard
description: >-
  Makes a Gilded Edge venture's Supabase database reproducible from `supabase db
  reset`. Use when a venture relies on a manual `schema.sql` that "runs in the SQL
  Editor" instead of ordered migrations, when `supabase db reset` fails on
  duplicate/colliding CREATE statements, when base tables are missing from the
  migrations folder, or when someone asks to "baseline the schema", "fix the
  migrations", "make the DB reset cleanly", "generate a 000_baseline", or "add CI
  for Supabase migrations". Grounded in the ventures that actually have this P0:
  gilded-art-works, gilded-art-works-docs-web, gilded-estate-works, lumier-studios,
  and Toutsweet.
---

# Supabase Migration Guard

## Purpose

The ecosystem's #1 P0: several ventures keep a hand-maintained `supabase/schema.sql`
("paste into the Supabase SQL Editor") **instead of** an ordered, replayable
`supabase/migrations/` history. The consequences observed in the real repos:

- **Base tables are missing from migrations.** `schema.sql` creates `profiles`,
  `documents`, etc., but those `CREATE`s live *outside* `supabase/migrations/`, so
  `supabase db reset` (which only replays the migrations folder) never creates them
  and later migrations fail with `relation "..." does not exist`.
- **Duplicate / colliding CREATEs.** The same table is defined in more than one
  migration, or in both a hand-written `FULL_SCHEMA.sql` and the numbered
  migrations, so a clean reset dies on `relation already exists`.

Confirmed instances at authoring time:

| Venture | Supabase dir | Symptom |
|---|---|---|
| `gilded-art-works` | `ventures/gilded-art-works/supabase` | `schema.sql` outside migrations; `webhook_events`, `team_roles`, `rate_limit_log`, `notification_preferences`, `compliance_snapshots`, `api_keys` each `CREATE`d in **2** migrations |
| `gilded-estate-works` | `ventures/gilded-estate-works/supabase` | `migrations/FULL_SCHEMA.sql` re-creates every table the numbered migrations already create (`workspaces`, `deals`, `subscriptions`, `notifications`, … all ×2) |
| `gilded-art-works-docs-web` | `ventures/gilded-art-works-docs-web/supabase` | `schema.sql` only, no `migrations/` folder — nothing to replay |
| `lumier-studios` | `ventures/lumier-studios/app/supabase` | `schema.sql` + ad-hoc `migration_*.sql` (not timestamp-ordered) |
| `Toutsweet` | `ventures/Toutsweet/platform/supabase` | single `001_initial_schema.sql`; verify no drift vs live |

This skill turns that mess into a database that **rebuilds deterministically** from
`supabase db reset`, and wires CI so it can never silently rot again.

## When to use

Trigger this skill when the user says any of: "the migrations won't reset",
"`supabase db reset` fails", "base tables missing", "duplicate CREATE", "relation
already exists", "baseline the schema", "convert schema.sql to a migration",
"generate 000_baseline", "make the Supabase DB reproducible", or "add migration CI"
— for any venture listed above (or any venture whose `supabase/` folder has a loose
`schema.sql`).

## House conventions (match these — do not invent your own)

- Migrations live in `<venture>/supabase/migrations/` and use a `YYYYMMDD...` or
  `NNN_name.sql` prefix. The baseline you generate sorts **first**, so name it
  `000_baseline.sql` (three-digit `000` sorts before both the `001_...` and
  `20260504...` styles already present).
- SQL is lowercase-keyword friendly (`create table if not exists`, `alter table ...
  enable row level security`, `create policy "..."`). Preserve the existing casing
  and comment banners in each repo — do not reformat.
- **RLS is mandatory.** Every table in these repos does `enable row level security`
  and defines `auth.uid()`-based policies. The baseline must carry those verbatim.
- SSR auth: tables reference `auth.users` / `public.profiles(id)`; keep those FKs.
- Never point `psql`/reset at production. Work against the **local** stack
  (`supabase start`) or a throwaway branch DB.

## Workflow

### Step 0 — Preflight (read-only)
Run the doctor to see what's wrong before changing anything:

```sh
bash ~/.claude/skills/supabase-migration-guard/scripts/migration_doctor.sh \
  ~/GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works
```

It prints: whether a loose `schema.sql` exists outside `migrations/`, which table
names are `CREATE`d more than once (and in which files), whether a `000_baseline`
already exists, and whether the Supabase CLI is available. It is strictly read-only.

### Step 1 — Generate `000_baseline` from `schema.sql`
When base tables live in a loose `schema.sql`, fold it into the migration history as
the first migration:

```sh
bash ~/.claude/skills/supabase-migration-guard/scripts/generate_baseline.sh \
  ~/GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works
```

By default this is a **dry run** — it prints what it would write. Re-run with
`--apply` to actually create `supabase/migrations/000_baseline.sql`:

```sh
bash ~/.claude/skills/supabase-migration-guard/scripts/generate_baseline.sh \
  ~/GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works --apply
```

The generated baseline is the verbatim `schema.sql` body with a provenance header.
It intentionally keeps the file's existing `if not exists` guards. After generating,
**do not delete `schema.sql`** in the same commit — leave it one release as a
reference, but stop treating it as the source of truth (say so in the PR).

For `gilded-estate-works` the base lives in `migrations/FULL_SCHEMA.sql` rather than a
top-level `schema.sql`. There the fix is the reverse: promote `FULL_SCHEMA.sql` to
`000_baseline.sql` **and delete the now-duplicated numbered migrations' table
creates** (see Step 2), because the numbered files replayed the same tables.

### Step 2 — Resolve duplicate / colliding CREATEs
Re-run the doctor (or `scripts/find_collisions.sh`) to list every table/type/policy
created more than once. For each collision, decide which file is canonical:

- If the baseline now owns the table, later migrations must **not** re-`CREATE` it —
  convert the later definition to the incremental change it was really meant to be
  (`alter table ... add column ...`) or delete it if redundant.
- If two feature migrations both create the table, keep the earliest and make the
  later one `create table if not exists` **only** if the column sets are identical;
  otherwise reconcile the columns explicitly. Never rely on `if not exists` to
  paper over *different* definitions — that hides real drift.

```sh
bash ~/.claude/skills/supabase-migration-guard/scripts/find_collisions.sh \
  ~/GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works/supabase/migrations
```

Edit the offending migrations by hand (the skill does not auto-rewrite SQL — a wrong
automated edit to a migration is worse than the collision).

### Step 3 — Verify a clean deploy with `supabase db reset`
This is the acceptance test. Against the **local** stack only:

```sh
bash ~/.claude/skills/supabase-migration-guard/scripts/verify_reset.sh \
  ~/GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works
```

It runs `supabase db reset` (local), which drops the local DB and replays
`migrations/` from scratch. Exit 0 = the whole history applies cleanly with no
`already exists` / `does not exist` errors. If it fails, the error names the first
colliding or missing relation — go back to Step 2.

### Step 4 — Recommend CI wiring
Once reset is green, wire it so drift can't return. The audit script
(`scripts/audit-ecosystem.sh`) already checks for `.github/workflows/ci.yml`; add a
job that fails the PR if the migrations don't replay. A ready-to-drop snippet is in
`scripts/ci-snippet.yml` — recommend it, show it, and let the human commit it into
the venture's `.github/workflows/ci.yml`. Do not push CI changes silently.

## Gotchas specific to this ecosystem

- **Next.js 16 + SSR auth:** the app reads `auth.uid()` through `@supabase/ssr`
  cookies. If RLS policies are dropped from the baseline, the app "works" locally
  with the service role but leaks across tenants in prod. Keep every `enable row
  level security` + `create policy` block.
- **`db reset` only replays `supabase/migrations/`.** A loose `schema.sql` at the
  `supabase/` root is invisible to it. That is the entire root cause — the fix is
  always "get the base tables *into* the migrations folder as `000_baseline`".
- **Timestamp vs numeric prefixes coexist.** `gilded-art-works` mixes `001_...` and
  `20260504_...`. `000_baseline` sorts first under both schemes; do not renumber the
  existing files.
- **`lumier-studios` supabase dir is nested at `app/supabase`,** not the repo root.
  Pass the repo root; the scripts locate the `supabase/` dir (including `app/`).
- **Never run reset against a linked prod project.** Some repos have
  `supabase/.temp/linked-project.json`. The scripts refuse to run `db reset` unless a
  local stack is up, but double-check you are not `--linked`.
- **`if not exists` is a smell, not a cure.** It silences "already exists" but lets
  two *different* definitions of the same table diverge. Treat every duplicate as a
  reconciliation task, not a suppression task.

## Example (end to end)

```sh
SKILL=~/.claude/skills/supabase-migration-guard/scripts
REPO=~/GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works

bash $SKILL/migration_doctor.sh   $REPO            # 1. see the damage (read-only)
bash $SKILL/generate_baseline.sh  $REPO            # 2. preview 000_baseline
bash $SKILL/generate_baseline.sh  $REPO --apply    #    write it
bash $SKILL/find_collisions.sh    $REPO/supabase/migrations   # 3. list dupes → fix by hand
supabase start                                     # 4. local stack
bash $SKILL/verify_reset.sh       $REPO            #    green = reproducible
# 5. add scripts/ci-snippet.yml to .github/workflows/ci.yml, open PR
```
