---
name: catalog-seeder
description: Validate then bulk-load catalog rows into Supabase as an idempotent seed migration — edge-design-works furniture (catalog_items / catalog_categories, keyed on sku + slug) or gilded-art-works artworks (artwork_registry, keyed on artwork_id). Takes a CSV/JSON of rows, checks required fields + image paths (delegating the validation RULES to the existing data-validation skill), then emits an INSERT ... ON CONFLICT DO NOTHING seed .sql following rls-migration-writer conventions so re-running never duplicates or clobbers. Use when someone says "seed the catalog", "bulk load furniture/products/artworks", "import this catalog CSV", "load these rows into Supabase", "generate a seed migration", "onboard a new brand's items", "backfill catalog_items", or "make an idempotent seed". NOT a validator rewrite — it reuses data-validation's rules and focuses on the VALIDATED BULK LOAD.
---

# Catalog Seeder

Turn a batch of catalog rows into a **safe, idempotent Supabase seed migration**. Two supported targets:

| Target venture | Table(s) | Conflict key (idempotency) | Owner / RLS |
|----------------|----------|----------------------------|-------------|
| `edge-design-works` | `catalog_items` (+ `catalog_categories`) | `sku` and/or `slug` (both UNIQUE) | Reference data — **no `user_id`**; public-read catalog |
| `gilded-art-works`  | `artwork_registry` | `artwork_id` (UNIQUE; `nfc_uid` also UNIQUE) | `owner_id → auth.users(id)` |

The job is **validated bulk load**, not reinventing validation. The field/image rules come
from the existing **`data-validation`** skill; this skill adds the seeding half:
dedupe-safe `INSERT ... ON CONFLICT DO NOTHING` in the ecosystem's migration conventions.

## When to use

- Loading a brand's furniture line or an artwork batch into Supabase for the first time.
- Re-importing / topping up a catalog where re-running must NOT create duplicates.
- Producing a `supabase/migrations/*.sql` seed that survives a clean `supabase db reset`.

## Ground truth (real schemas — do not guess columns)

- **`catalog_items`** (`ventures/edge-design-works/supabase/migrations/001_edge_design_works_schema.sql`):
  required `name`, `slug` (UNIQUE, NOT NULL), `image_url` (NOT NULL), `price_cents` (INT, NOT NULL, **cents not dollars**).
  Optional: `brand`, `sku` (UNIQUE), `category_id → catalog_categories(id)`, `currency`, `purchase_url`,
  `commission_rate`, `availability`, `image_thumbnail`, `image_cutout`, `image_storage_path`, `description`,
  `dimensions` (JSONB), `materials`/`colors`/`style_tags`/`suggested_rooms` (TEXT[]), `ai_description`, `is_featured`, `is_active`.
  The client mapper is `services/catalogService.ts` (`mapItem`) — match those column names.
- **`catalog_categories`**: `name`, `slug` (UNIQUE). Seed/resolve categories BEFORE items so `category_id` FKs resolve.
- **`artwork_registry`** (`ventures/gilded-art-works/supabase/migrations/001_artwork_registry.sql`):
  required `artwork_id` (UNIQUE, e.g. `GA-2026-00431`), `title`, `artist`. Optional: `year`, `medium`,
  `dimensions`, `image_url`, `owner_id`, `current_owner`, `provenance` (JSONB), `documents` (JSONB), `status`, `notes`.
- **Migration conventions** (from `rls-migration-writer`): files live in `ventures/<venture>/supabase/migrations/`,
  named `YYYYMMDD_seed_<what>.sql`; PK is `gen_random_uuid()`; must survive `supabase db reset`;
  service role bypasses RLS so a seed run as service role is fine. Catalog tables are reference data
  (public-read) so seeds don't set an owner; `artwork_registry` rows should set `owner_id` when known.

## Workflow

1. **Get the rows.** Accept a CSV or JSON array. Confirm the target venture/table and the conflict key.
2. **Validate FIRST — reuse the `data-validation` skill.** Do not re-implement rules; apply that skill's
   checks to this batch:
   - Required fields non-empty (`name`+`slug`+`image_url`+`price_cents` for items; `artwork_id`+`title`+`artist` for artworks).
   - **Image path validation** — every `image_url` / `image_thumbnail` / `image_cutout` must resolve to a real file
     (under the venture's `public/` for local paths) and must NOT contain `placeholder`, `upload`, `TODO`.
   - Slugs URL-safe (lowercase, hyphens, no spaces); SKUs/artwork_ids unique **within the batch**.
   - Prices sane: `catalog_items.price_cents` is an INTEGER of CENTS (e.g. `549900`), never a float dollar value.
   Run the bundled pre-flight to catch these fast:
   ```bash
   bash ~/.claude/skills/catalog-seeder/scripts/validate-catalog.sh --venture edge-design-works rows.csv
   ```
   It is read-only and exits non-zero on any blocking issue. Fix the source data before seeding.
3. **Generate the seed (dry-run).** Prints SQL to stdout; writes nothing without `--write`:
   ```bash
   bash ~/.claude/skills/catalog-seeder/scripts/seed-catalog.sh \
     --venture edge-design-works --table catalog_items --conflict slug rows.csv
   # artworks:
   bash ~/.claude/skills/catalog-seeder/scripts/seed-catalog.sh \
     --venture gilded-art-works --table artwork_registry --conflict artwork_id rows.json
   ```
   Output is one `INSERT INTO <table> (...) VALUES (...), (...) ON CONFLICT (<key>) DO NOTHING;`
   wrapped in a `BEGIN; ... COMMIT;` transaction, with values SQL-escaped and JSONB/array columns cast.
4. **Review, then save.** Add `--write` to drop the file into `supabase/migrations/` with a dated name.
   Never overwrite an existing migration.
5. **Apply the migration** yourself the normal way (`supabase db push` / `supabase migration up`), or
   via the Supabase MCP `apply_migration`. The skill does not apply it for you.

## Idempotency rules (the whole point)

- Always `ON CONFLICT (<unique_key>) DO NOTHING`. Never `DO UPDATE` in a seed unless the user explicitly
  asks to overwrite — a seed re-run must be a no-op, not a silent data change.
- Pick a conflict target that is actually UNIQUE in the schema: `slug` or `sku` for `catalog_items`,
  `artwork_id` for `artwork_registry`. A non-unique conflict target makes Postgres error.
- If rows carry an explicit `id`, keep it stable across runs (fixed UUID) so cross-table FKs stay valid;
  otherwise let `gen_random_uuid()` fill it and conflict on the natural key instead.
- Categories before items: resolve `category_id` by seeding `catalog_categories` (conflict on `slug`) first,
  then reference categories by a `SELECT id FROM catalog_categories WHERE slug = '...'` subquery in the item insert.

## Gotchas

- **Cents, not dollars.** `$5,499.00` → `549900`. `mapItem` divides by 100. Passing `5499` ships a $54.99 sofa.
- **NOT NULL columns must be present** — `catalog_items` needs `name`, `slug`, `image_url`, `price_cents` on every row.
- **Arrays & JSONB need casts** — `materials/colors/style_tags/suggested_rooms` are `TEXT[]` (`ARRAY['leather','walnut']`
  or `'{leather,walnut}'`); `dimensions/provenance/documents` are JSONB (`'{"width":84}'::jsonb`). The generator
  emits these casts; hand-editing them wrong is the #1 seed failure.
- **FK to categories** — an item's `category_id` must reference a category that exists first, or use the subquery form.
- **Escape quotes** — an apostrophe in a product name (`Womb Chair 'Classic'`) must be doubled. The generator does this;
  verify if you hand-edit.
- **RLS**: catalog tables are reference/public-read; do not add `user_id`. For `artwork_registry`, set `owner_id`
  only to a real `auth.users` id — a bogus UUID violates the FK. Leave it NULL if unknown.
- **Don't commit or push.** `--write` only stages the file; the user applies + commits.

## Files in this skill

- `scripts/validate-catalog.sh` — read-only pre-flight (required fields, image-path existence + placeholder scan,
  slug/SKU uniqueness, cents sanity). Reuses the `data-validation` rule set.
- `scripts/seed-catalog.sh` — dry-run seed generator; emits idempotent `ON CONFLICT DO NOTHING` SQL. `--write` to save.
- `references/seed-patterns.sql` — copy-paste idempotent seed recipes for items, categories, and artworks.
