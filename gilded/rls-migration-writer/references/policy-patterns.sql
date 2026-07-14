-- ══════════════════════════════════════════════════════════════════
-- RLS POLICY PATTERNS — Gilded Edge ecosystem
-- Copy the block that matches the table's access shape. Every table
-- MUST run `ALTER TABLE <t> ENABLE ROW LEVEL SECURITY;` first.
-- Service role bypasses RLS — do NOT write policies for it.
-- ══════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────
-- 1. OWNER-SCOPED (the default). Column: user_id (or owner_id).
--    One policy per verb so INSERT/UPDATE both carry WITH CHECK.
-- ──────────────────────────────────────────────────────────────────
CREATE POLICY "<t>_select_own" ON <t>
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "<t>_insert_own" ON <t>
  FOR INSERT WITH CHECK (auth.uid() = user_id);   -- never WITH CHECK (true)

CREATE POLICY "<t>_update_own" ON <t>
  FOR UPDATE USING (auth.uid() = user_id)
             WITH CHECK (auth.uid() = user_id);    -- WITH CHECK stops ownership hand-off

CREATE POLICY "<t>_delete_own" ON <t>
  FOR DELETE USING (auth.uid() = user_id);


-- ──────────────────────────────────────────────────────────────────
-- 2. PUBLIC-READ + OWNER-WRITE.
--    e.g. artwork_registry: anyone can read an ACTIVE row (NFC tap
--    verification page), only the owner can mutate.
--    Keep the public predicate NARROW — expose only non-sensitive rows,
--    and never a secret/token column via a broad SELECT (see #4).
-- ──────────────────────────────────────────────────────────────────
CREATE POLICY "<t>_public_read_active" ON <t>
  FOR SELECT USING (status IN ('active', 'pending'));

CREATE POLICY "<t>_owner_all" ON <t>
  FOR ALL USING (auth.uid() = owner_id)
          WITH CHECK (auth.uid() = owner_id);


-- ──────────────────────────────────────────────────────────────────
-- 3. MEMBERSHIP / ROLE-SCOPED via SECURITY DEFINER (avoids recursion).
--    Use when access depends on rows in ANOTHER table (teams, orgs).
--    NEVER sub-select the SAME table inside its own policy.
-- ──────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION is_team_member(target_team UUID)
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM team_roles
    WHERE team_id = target_team AND user_id = auth.uid()
  );
$$;
REVOKE ALL ON FUNCTION is_team_member(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION is_team_member(UUID) TO authenticated;

-- Optional role-gated variant for admin-only mutations:
CREATE OR REPLACE FUNCTION has_team_role(target_team UUID, roles TEXT[])
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM team_roles
    WHERE team_id = target_team AND user_id = auth.uid() AND role = ANY(roles)
  );
$$;
REVOKE ALL ON FUNCTION has_team_role(UUID, TEXT[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION has_team_role(UUID, TEXT[]) TO authenticated;

CREATE POLICY "<t>_select_members" ON <t>
  FOR SELECT USING (is_team_member(team_id));

CREATE POLICY "<t>_manage_admins" ON <t>
  FOR ALL USING (has_team_role(team_id, ARRAY['owner','admin']))
          WITH CHECK (has_team_role(team_id, ARRAY['owner','admin']));


-- ──────────────────────────────────────────────────────────────────
-- 4. TOKEN / SHARE-LINK LOOKUP — NEVER a broad SELECT policy.
--    Anti-pattern (shipped bug): USING (active = TRUE) leaks every
--    row's token. Instead: deny-all SELECT + a SECURITY DEFINER RPC
--    keyed by the exact token, called from a service context.
-- ──────────────────────────────────────────────────────────────────
-- (no permissive SELECT policy — table stays locked to anon/authenticated)

CREATE OR REPLACE FUNCTION resolve_share(p_token TEXT)
RETURNS SETOF document_shares
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE
AS $$
  SELECT * FROM document_shares
  WHERE token = p_token AND active = TRUE AND (expires_at IS NULL OR expires_at > now());
$$;
REVOKE ALL ON FUNCTION resolve_share(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION resolve_share(TEXT) TO anon, authenticated;


-- ──────────────────────────────────────────────────────────────────
-- 5. EXPLICIT DENY-ALL — table only ever touched by service role.
--    RLS on + zero policies = no anon/authenticated access. Comment WHY
--    so a future migration doesn't "helpfully" add a permissive policy.
-- ──────────────────────────────────────────────────────────────────
ALTER TABLE webhook_events ENABLE ROW LEVEL SECURITY;
-- Intentionally NO policies: written/read only by the service-role
-- client in /api/webhook. Deny-all for anon + authenticated.


-- ──────────────────────────────────────────────────────────────────
-- 6. EXTEND AN EXISTING TABLE — do this, not a second CREATE TABLE.
--    Duplicate CREATE TABLE IF NOT EXISTS with different columns breaks
--    `supabase db reset` (later index/policy statements error).
-- ──────────────────────────────────────────────────────────────────
ALTER TABLE existing_table ADD COLUMN IF NOT EXISTS new_col TEXT;
