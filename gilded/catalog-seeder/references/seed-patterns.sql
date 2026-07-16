-- ══════════════════════════════════════════════════════════════════
-- catalog-seeder — idempotent seed recipes
-- Every recipe is safe to run repeatedly: ON CONFLICT (<unique>) DO NOTHING.
-- Conventions per rls-migration-writer: dated file, gen_random_uuid() PKs,
-- survives `supabase db reset`, run as service role (bypasses RLS).
-- ══════════════════════════════════════════════════════════════════

-- ── 1. Categories FIRST (edge-design-works) — conflict on UNIQUE slug ──
BEGIN;
INSERT INTO catalog_categories (name, slug, icon, description, sort_order) VALUES
  ('Sofas',         'sofas',         'Sofa',  'Seating for living spaces', 10),
  ('Dining Tables', 'dining-tables', 'Table', 'Dining surfaces',           20)
ON CONFLICT (slug) DO NOTHING;
COMMIT;

-- ── 2. Catalog items — conflict on UNIQUE slug (or sku) ──
-- price_cents is INTEGER CENTS (549900 = $5,499.00). Arrays -> TEXT[]. dimensions -> JSONB.
-- category_id resolved by subquery so the FK always points at a real category.
BEGIN;
INSERT INTO catalog_items
  (category_id, name, brand, sku, slug, price_cents, currency, image_url,
   description, dimensions, materials, colors, style_tags, is_featured, is_active)
VALUES
  (
    (SELECT id FROM catalog_categories WHERE slug = 'sofas'),
    'Eames Lounge Chair', 'Herman Miller', 'HM-ELC-2026', 'eames-lounge-chair',
    549900, 'USD', '/catalog/eames-lounge.webp',
    'Iconic mid-century lounge chair and ottoman.',
    '{"width":84,"depth":37,"height":33,"unit":"in"}'::jsonb,
    ARRAY['leather','walnut','steel'],
    ARRAY['black','cognac'],
    ARRAY['mid-century','modern','iconic'],
    true, true
  )
ON CONFLICT (slug) DO NOTHING;
COMMIT;

-- If rows also carry a stable SKU and you prefer to dedupe on it:
--   ... ON CONFLICT (sku) DO NOTHING;   -- sku is UNIQUE in the schema

-- ── 3. Artworks (gilded-art-works) — conflict on UNIQUE artwork_id ──
-- owner_id must be a REAL auth.users id or NULL (FK). provenance/documents are JSONB arrays.
BEGIN;
INSERT INTO artwork_registry
  (artwork_id, title, artist, year, medium, dimensions, image_url,
   current_owner, provenance, documents, status, owner_id)
VALUES
  (
    'GA-2026-00431', 'Gilded Horizon', 'A. Rivera', 2026,
    'Oil on canvas', '48 x 36 in', '/registry/ga-2026-00431.webp',
    'DM Galleries',
    '[{"owner":"DM Galleries","period":"2026-Present","location":"Miami, FL"}]'::jsonb,
    '[{"type":"Certificate of Authenticity","date":"2026-04-12","status":"active"}]'::jsonb,
    'active', NULL
  )
ON CONFLICT (artwork_id) DO NOTHING;
COMMIT;

-- ── Anti-patterns to avoid ──
-- ✗ ON CONFLICT (name) ...            -- name is NOT unique -> Postgres error / no dedupe
-- ✗ DO UPDATE in a seed               -- silently mutates existing rows on re-run; only if user asks to overwrite
-- ✗ price_cents = 5499 for a $5,499 item  -- that's $54.99; must be 549900
-- ✗ owner_id = '00000000-...'         -- violates FK to auth.users; use a real id or NULL
