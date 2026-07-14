---
name: slug-normalize
description: >-
  Normalizes free-text `venture_id` slugs across the Gilded Edge Supabase database
  (project gildedge-portal / xuhsybqoecbmjeupnrxe) and installs the guardrail that
  stops them re-drifting. Use when someone says "normalize venture slugs", "fix the
  venture_id values", "the slugs are inconsistent", "rename ventures in the DB",
  "consolidate venture ids", "remap slugs", "add a ventures table / FK on
  venture_id", or reports duplicate/variant venture identifiers (e.g.
  `vc_lumier_studios`, `Lumier Studios`, `photofilm` all meaning one venture). The
  root cause is that `venture_id` is free text with NO foreign key or constraint —
  this skill remaps the 14 variants to 6 canonical slugs in one transaction, then
  adds a canonical `ventures(slug PK)` table + FK so it CANNOT drift again.
  Codifies VENTURE_SLUG_MIGRATION_SCOPE.md.
---

# Slug Normalize

## Purpose

`venture_id` is a **free-text `text` column on ~33 tables** (plus `aria_metrics.venture`)
in the `gildedge-portal` Supabase project. Because there is **no foreign key and no
constraint** on it, the same six real ventures accumulated ~14 spelling variants plus
junk — `lumier-studios`, `vc_lumier_studios`, `lumier`, `Lumier Studios` all mean one
venture; `photofilmworks`, `photofilm`, `PhotoFilmWorks` mean another; `@danielmontero`
is junk in `aria_metrics`.

**The root cause is the missing constraint.** Renaming values on top of unconstrained
free text just mints *new* inconsistent values. So this skill does two things, in order:

1. **Normalize** — remap 14 variants → 6 canonical slugs, all-or-nothing, in a single
   transaction, after a full backup.
2. **Guardrail** — add a canonical `ventures(slug PK)` table and a `FK` (or `CHECK`)
   from every `venture_id` so an out-of-range value is *rejected by the database*, not
   just discouraged.

If you only do step 1, the mess comes back. The guardrail is the point.

## Canonical mapping (from VENTURE_SLUG_MIGRATION_SCOPE.md)

The 6 canonical slugs (they match the deployed code + the audit-script folder names,
so **no redeploy** is required):

| Variant (current) | rows | → Canonical |
|---|---|---|
| `lumier-studios`, `vc_lumier_studios`, `lumier`, `Lumier Studios` | 78+64+11+2 | `lumier-studios` |
| `lumier-pictures` | 79 | `lumier-pictures` |
| `gilded-artworks`, `artworks`, `dm-galleries` * | 34+5+28 | `gilded-art-works` |
| `photofilmworks`, `photofilm`, `PhotoFilmWorks` | 45+10+1 | `photo-film-works` |
| `gilded-ventures` | 11 | `gilded-travel-works` |
| `@danielmontero` * | 8 | `gildedge-holdings` |
| `null` | 1 | leave / clean |

\* **Decisions the user must confirm before running** (do not assume):
- `dm-galleries` (28 rows, legacy "Development" entity) — **merge into `gilded-art-works`**
  or retire in place?
- `@danielmontero` (8 rows, `aria_metrics` only, junk handle) — **null out** or reassign
  to `gildedge-holdings`?

The mapping lives in `sql/mapping.csv`. Edit it to reflect the confirmed decisions
before generating SQL. Everything downstream reads from that one file.

## When to use

Trigger on: "normalize venture slugs", "consolidate venture_id", "the slugs drifted",
"remap ventures", "canonical slug table", "add FK on venture_id", "why do we have
`vc_lumier_studios` and `lumier-studios`", or any request to clean up venture
identifiers in the `gildedge-portal` DB.

## Prerequisites

- A `psql` connection string to the `gildedge-portal` project (pooler URL). Never put
  it on the command line where it lands in shell history — export it:
  `export PGURI='postgresql://...pooler...'` and pass `"$PGURI"` to the scripts.
- Confirm you are pointed at the intended project: `xuhsybqoecbmjeupnrxe`.
- **This mutates production data.** Steps 1–2 are read-only; the write step (Step 4)
  is transactional and preceded by a backup, but get the user's explicit go-ahead.

## Workflow

### Step 1 — Scan the actual distinct values (read-only)
Never trust a stale doc — re-derive the current reality first:

```sh
bash ~/.claude/skills/slug-normalize/scripts/scan_slugs.sh "$PGURI"
```

This discovers every table with a `venture_id text` column (via
`information_schema`), unions their distinct values with row counts, and adds
`aria_metrics.venture`. Compare the output against `sql/mapping.csv`; add any variant
the scan found that the mapping is missing. **If a value has no mapping, stop** —
mapping every observed value is what makes the transaction safe.

### Step 2 — Confirm the decisions
Resolve `dm-galleries` and `@danielmontero` with the user, then edit
`sql/mapping.csv` accordingly. Rows you want left alone (e.g. `null`) get canonical =
empty and are skipped.

### Step 3 — Back up (mandatory, reversible)
Generate and run the backup. It snapshots every `(table, pk, venture_id)` into a
dedicated `bak_YYYYMMDD` schema — the scope doc's proven rollback mechanism:

```sh
bash ~/.claude/skills/slug-normalize/scripts/generate_sql.sh --backup > /tmp/00_backup.sql
psql "$PGURI" -f /tmp/00_backup.sql
```

Rollback for any table (per the scope doc):
`UPDATE public.<t> SET venture_id = b.venture_id FROM bak_YYYYMMDD.<t> b WHERE <t>.id = b.id;`

### Step 4 — Remap in ONE transaction
Generate the remap SQL from the mapping. It builds a CTE of `(variant → canonical)`
and `UPDATE`s every discovered table + `aria_metrics`, wrapped in a single
`BEGIN…COMMIT` so it is all-or-nothing:

```sh
bash ~/.claude/skills/slug-normalize/scripts/generate_sql.sh --remap > /tmp/01_remap.sql
# REVIEW /tmp/01_remap.sql with the user, then:
psql "$PGURI" -f /tmp/01_remap.sql
```

### Step 5 — Install the guardrail (the actual fix)
Create the canonical registry table and constrain every `venture_id`:

```sh
bash ~/.claude/skills/slug-normalize/scripts/generate_sql.sh --guardrail > /tmp/02_guardrail.sql
psql "$PGURI" -f /tmp/02_guardrail.sql
```

`sql/guardrail.sql` (templated by the generator) does:
1. `create table public.ventures (slug text primary key, name text not null, …)` and
   seeds the 6 canonical rows.
2. For every table with `venture_id`, adds
   `alter table public.<t> add constraint <t>_venture_id_fk
    foreign key (venture_id) references public.ventures(slug)
    on update cascade on delete restrict;`
   `on update cascade` means a future *intentional* rename is a one-row update to
   `ventures` that propagates everywhere — drift becomes impossible because an
   unknown slug now raises a FK violation.
   (Where a column is nullable and legitimately NULL, the FK still allows NULL; if you
   prefer a softer guard, the generator can emit a `CHECK (venture_id IN (...))`
   instead with `--guardrail --check`.)

### Step 6 — Verify
```sh
bash ~/.claude/skills/slug-normalize/scripts/scan_slugs.sh "$PGURI"
```
Expect **only the 6 canonical slugs** (+ NULL where allowed). Then prove the guard
works by attempting a bad insert — it must fail:
`insert into public.leads (venture_id) values ('nope');  -- expect FK violation`

## Root cause, stated plainly

> The slugs drifted **because `venture_id` had no FK/constraint.** Normalizing the data
> without adding the constraint fixes today and guarantees tomorrow's re-drift. The
> deliverable is the `ventures(slug PK)` table + FK, not the one-off `UPDATE`.

## Gotchas specific to this ecosystem

- **Registry tables are NOT the data tables.** `pricing_ventures.slug` is all-NULL with
  mixed-case dupes; `organizations.slug` (`gildedge`) and `forms.slug` are unrelated.
  The FK target is a **new** `public.ventures` table, not any of these. Dedupe
  `pricing_ventures` separately (scope doc §5.3) — don't FK to it.
- **`aria_metrics.venture`** carries the slug under a different **column name**
  (`venture`, not `venture_id`). The scan and generated SQL special-case it; if you add
  the FK there, the constraint is on `venture`.
- **Do NOT touch real external identifiers** (scope doc §4): Firebase project
  `gilded-ventures-vip`, email domain `@gilded-ventures.com`, `gilded-artworks.com` /
  `cname.gilded-artworks.com`, and the `.ics` filename. These are not `venture_id`
  values — leave them exactly as-is.
- **Canonical slugs match deployed code**, so DB normalization needs **no redeploy**.
  The larger "internal -Works slug" rename (code + routes + `?v=` links + 301s) is a
  separate, optional, out-of-scope effort (scope doc §3). This skill is data +
  constraint only.
- **Order matters:** you cannot add the FK before the data is clean — a leftover
  variant will make the `alter table … add constraint` fail. Always Step 4 before
  Step 5. If Step 5 fails, the error names the row still holding an unmapped value.
- **Every value must be mapped before the transaction.** An unmapped variant left in
  the data will survive the remap and then block the FK. That is why Step 1's scan is
  mandatory and non-skippable.

## Example

```sh
export PGURI='postgresql://...pooler.supabase.com:6543/postgres'
S=~/.claude/skills/slug-normalize
bash $S/scripts/scan_slugs.sh "$PGURI"                       # 1. reality check
# 2. confirm dm-galleries / @danielmontero, edit $S/sql/mapping.csv
bash $S/scripts/generate_sql.sh --backup    > /tmp/00.sql && psql "$PGURI" -f /tmp/00.sql  # 3
bash $S/scripts/generate_sql.sh --remap     > /tmp/01.sql   # 4. review, then:
psql "$PGURI" -f /tmp/01.sql
bash $S/scripts/generate_sql.sh --guardrail > /tmp/02.sql && psql "$PGURI" -f /tmp/02.sql  # 5
bash $S/scripts/scan_slugs.sh "$PGURI"                       # 6. expect only 6 slugs
```
