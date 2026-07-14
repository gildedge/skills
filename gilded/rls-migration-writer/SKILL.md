---
name: rls-migration-writer
description: Scaffolds a Supabase Postgres table migration together with matching Row-Level Security (RLS) policies, foreign keys, indexes, and an updated_at trigger, in the Gilded Edge ecosystem's conventions. Use this whenever creating a new Supabase/Postgres table, writing a migration under supabase/migrations/, adding or fixing RLS policies, or when someone asks for "a migration", "a new table", "RLS policies", "owner-scoped access", or reports an "infinite recursion detected in policy" / "WITH CHECK (true)" / leaky-policy problem. Enables RLS by default, generates owner-scoped SELECT/INSERT/UPDATE/DELETE policies, refuses the recursive-policy and WITH CHECK (true) anti-patterns that shipped bugs in gilded-art-works, and emits a ready-to-apply .sql file.
---

# RLS Migration Writer

Generate a Supabase table migration that is **secure by default** in the exact style used across the Gilded Edge ventures (`gilded-art-works`, `lumier-studios`, `provenance-web`, etc.). Every table this skill produces enables RLS, is owner-scoped, and has FK constraints, indexes, and an `updated_at` trigger.

## When to use

- Adding a new table to any venture with a Supabase backend.
- Writing/fixing files under `ventures/<venture>/supabase/migrations/`.
- Reviewing or repairing RLS policies (especially the recursive-policy and `WITH CHECK (true)` bugs the 2026-07-04 gilded-art-works audit found).
- Standing up a `SECURITY DEFINER` helper so membership/role checks don't recurse.

## House conventions (learned from the real repos)

- Migrations live in `ventures/<venture>/supabase/migrations/` and are named `YYYYMMDD_phaseN_short_name.sql` (or a zero-padded `NNN_short_name.sql` for the baseline). Prefer a **date + descriptive** name.
- PK is `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`.
- Timestamps are `TIMESTAMPTZ DEFAULT now()`; every mutable table gets `created_at` **and** `updated_at`.
- The owner column is a `UUID ... REFERENCES auth.users(id) ON DELETE CASCADE`. Most tables call it `user_id`; some art-registry tables call it `owner_id`. Pick one and stay consistent within a table.
- `ALTER TABLE <t> ENABLE ROW LEVEL SECURITY;` is **mandatory** and comes right after the `CREATE TABLE`.
- Index the owner column and any FK you filter on.
- Auto-update `updated_at` with a shared `update_updated_at()` trigger function (already defined in `001_artwork_registry.sql`; reuse it, guard with `CREATE OR REPLACE`).
- Service role (used by webhook/admin routes) bypasses RLS — do **not** write policies for it.

## Anti-patterns this skill refuses to emit

These are real bugs from `AUDIT_2026-07-04.md` in gilded-art-works. Never reproduce them:

1. **`WITH CHECK (true)` on INSERT** — e.g. `notifications` and `artwork_scan_log` let any client insert rows for any user (phishing / spoofing). An INSERT policy's `WITH CHECK` must bind the row to the caller: `WITH CHECK (auth.uid() = user_id)`.
2. **Recursive policy** — `team_roles` policies that sub-select `team_roles` cause `infinite recursion detected in policy` and make *every* query on the table error. Move the membership/role lookup into a `SECURITY DEFINER` function that reads the table with RLS disabled inside the function body.
3. **Leaky `USING` predicate** — `USING (active = TRUE)` with the secret/token *not* in the predicate exposes every row's token. Token lookups must go through a `SECURITY DEFINER` RPC keyed by the token, never a broad SELECT policy.
4. **Public schema table with no RLS** — anon-readable/writable via PostgREST. If a table isn't meant to be public, it must have RLS enabled with real policies (or be an explicit, commented deny-all).
5. **Duplicate `CREATE TABLE IF NOT EXISTS` with different columns** — collides on a fresh `supabase db reset`. Use `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` to extend an existing table, or rename.

## Workflow

1. **Gather the shape.** Ask for (or infer): venture, table name, columns + types, the owner column name (`user_id` vs `owner_id`), any FK relationships, and whether any rows are meant to be publicly readable (e.g. an NFC verification page).
2. **Audit first (optional but recommended).** Run the auditor over the venture's existing migrations to see current RLS gaps before adding more:
   ```bash
   bash ~/.claude/skills/rls-migration-writer/scripts/audit-rls.sh ~/GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works/supabase
   ```
   It is read-only and flags: tables missing `ENABLE ROW LEVEL SECURITY`, `WITH CHECK (true)`, self-referential (recursive) policies, and leaky `USING (active = ...)` predicates.
3. **Scaffold the migration.** Use the generator to stamp out a starting file, then edit:
   ```bash
   bash ~/.claude/skills/rls-migration-writer/scripts/new-migration.sh \
     --venture gilded-art-works --table collections --owner user_id
   ```
   It prints the migration SQL to **stdout** (dry-run; it does not write into the repo unless you pass `--write`). Review, adjust columns, then save it into `supabase/migrations/`.
4. **Fill columns & FKs.** Replace the placeholder columns. Every FK gets `REFERENCES <parent>(id) ON DELETE CASCADE` (or `SET NULL` where a dangling reference is acceptable) and a matching index.
5. **Add a SECURITY DEFINER helper only if needed.** If access depends on membership/roles in *another* table (teams, org membership), do not sub-select inside the policy — call a helper. See the template in `references/policy-patterns.sql`.
6. **Verify locally.** The migration must survive a clean `supabase db reset`. Confirm no duplicate `CREATE TABLE` collides with an existing one and that every FK target is created by an earlier migration.

## Before / after

### Owner-scoped table (the correct default)

**Before — leaky, the anti-pattern:**
```sql
CREATE TABLE collections (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  name text
);
-- RLS never enabled → anon read/write via PostgREST
CREATE POLICY "insert" ON collections FOR INSERT WITH CHECK (true);   -- ❌ anyone inserts for anyone
CREATE POLICY "read"   ON collections FOR SELECT USING (true);         -- ❌ reads every tenant
```

**After — owner-scoped, RLS on, four explicit policies:**
```sql
-- ══════════════════════════════════════════════════════════════════
-- <venture> — collections
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS collections (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_collections_user ON collections(user_id);

ALTER TABLE collections ENABLE ROW LEVEL SECURITY;

-- SELECT: owner sees only their rows
CREATE POLICY "collections_select_own" ON collections
  FOR SELECT USING (auth.uid() = user_id);

-- INSERT: the new row must belong to the caller (never WITH CHECK (true))
CREATE POLICY "collections_insert_own" ON collections
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- UPDATE: owner may edit their rows, and may not reassign ownership away
CREATE POLICY "collections_update_own" ON collections
  FOR UPDATE USING (auth.uid() = user_id)
             WITH CHECK (auth.uid() = user_id);

-- DELETE: owner only
CREATE POLICY "collections_delete_own" ON collections
  FOR DELETE USING (auth.uid() = user_id);

-- Keep updated_at fresh (reuses the shared trigger fn from the baseline migration)
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER collections_updated_at
  BEFORE UPDATE ON collections
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

### Recursive membership policy → SECURITY DEFINER helper

**Before — the shipped bug (`20260504_phase10`), causes `infinite recursion detected in policy`:**
```sql
CREATE POLICY "Users can view roles in their teams" ON team_roles
  FOR SELECT USING (
    user_id = auth.uid()
    OR team_id IN (SELECT team_id FROM team_roles WHERE user_id = auth.uid())  -- ❌ selects team_roles inside a team_roles policy
  );
```

**After — lookup moved into a `SECURITY DEFINER` function (runs with the definer's rights, so the inner read does not re-trigger the policy):**
```sql
CREATE OR REPLACE FUNCTION is_team_member(target_team UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM team_roles
    WHERE team_id = target_team AND user_id = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION is_team_member(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION is_team_member(UUID) TO authenticated;

CREATE POLICY "team_roles_select_members" ON team_roles
  FOR SELECT USING (user_id = auth.uid() OR is_team_member(team_id));
```

More patterns (public-read + owner-write, token-keyed RPC, deny-all) are in `references/policy-patterns.sql`.

## Files in this skill

- `scripts/new-migration.sh` — dry-run generator; prints an owner-scoped migration (RLS + 4 policies + trigger). `--write` to save.
- `scripts/audit-rls.sh` — read-only grep auditor for RLS gaps and the four anti-patterns.
- `references/policy-patterns.sql` — copy-paste RLS recipes for the common access shapes.
