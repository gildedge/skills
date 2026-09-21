---
name: crud-route-scaffold
description: Scaffolds a complete CRM entity for the gildedge-portal Next.js 16 App Router stack in one shot — a server page.tsx, a route.ts handler with GET/POST/PATCH/DELETE, a Supabase table migration, and an idempotent fixed-UUID seed — all in the ecosystem's exact conventions (@supabase/ssr createClient, requireAuth + logAuditEvent, NextResponse error shape, CSS Modules). Use this whenever adding a new CRM entity or admin resource to gildedge-portal (or a sibling Next.js venture), when someone says "scaffold a CRM entity/table/route", "new leads/quotes/invoices/contracts/pipeline resource", "add a portal CRUD page", "kill the copy-paste across the CRM route folders", or "generate page + route + migration + seed". Delegates the RLS half to the rls-migration-writer skill's conventions rather than duplicating them.
---

# CRUD Route Scaffold

gildedge-portal has ~16 near-identical CRM entities (leads, clients, projects, deliverables, invoices, interactions, quotes, contracts, calendar_events, messages, forms, …). They all share the same four moving parts. This skill stamps out all four at once so you stop copy-pasting.

The four parts of one entity:
1. **Migration** — `supabase/migrations/<date>_<entity>.sql` (table + indexes + RLS + `updated_at` trigger).
2. **Seed** — appended to the migration (or its own `_seed.sql`): fixed-UUID rows with `ON CONFLICT (id) DO NOTHING` so it is safe to re-run.
3. **Route handler** — `src/app/api/<entity>/route.ts` with `GET`/`POST`/`PATCH`/`DELETE`.
4. **Page** — `src/app/portal/<entity>/page.tsx` (RSC) + a `page.module.css`.

## When to use

- Adding any new CRM/admin entity to `ventures/gildedge-portal` (or a sibling Next.js 16 + `@supabase/ssr` venture).
- You are about to copy an existing `src/app/portal/<x>/` folder and rename it — do this instead.
- Someone asks for "a page + route + migration + seed" for one resource.

Do **not** use it for AI-proxy or webhook endpoints (that is a different shape — those live under `api/aria`, `api/hermes`, `api/stripe`). For Supabase Edge Functions use the `edge-function-scaffold` skill.

## Ground-truth conventions (learned from the real repo)

**Stack:** Next.js `^16.2.4`, React `19.2.4`, `@supabase/ssr ^0.10`, `@supabase/supabase-js ^2`. Node `>=20.9.0`. App Router. TypeScript strict. **CSS Modules only — never Tailwind, never inline styles** (per CLAUDE.md).

**Supabase clients** live in `src/lib/supabase/server.ts` and are **async** (Next 15+ `cookies()` is awaited):
- `createClient()` — anon client, respects RLS, carries the user's session cookies. Use for user-scoped reads/writes.
- `createServiceClient()` — service-role, **bypasses RLS**. Use only in trusted server code (webhooks, cron), and only after the handler has done its own authn + authz. ⚠️ never returned to the browser. The generated CRUD routes do not use it at all.

**Two auth patterns coexist — pick per entity:**
- **RSC page guard:** `const { user, role, orgId } = await requireAuth('<section>')` from `@/lib/require-auth`. Redirects to `/login` or `/portal?access=denied`. Pages then `logAuditEvent({...}).catch(() => {})` (fire-and-forget).
- **Route-handler guard:** either `requireAuth('<section>')` wrapped in try/catch → 401, plus a `role !== 'admin'` → 403 check (see `api/milestones/route.ts`); **or** the leaner `const { data: { user } } = await supabase.auth.getUser(); if (!user) return 401;` then owner-scope every query with `.eq('user_id', user.id)` (see `api/marketing/strategies/route.ts`).

**Error shape (uniform across routes):** `return NextResponse.json({ error: 'message' }, { status })`. Codes: `401` unauthenticated, `403` forbidden, `400` bad/missing input or invalid JSON, `404` when a PATCH/DELETE id matches no row the caller can see, `500` on caught errors (always `console.error('[Entity METHOD] ...', err)` first). The `error` string sent to the client is always a fixed generic message (`'Failed to create'`); never put `error.message` or any raw DB error in the response, it leaks table, column and constraint names. Gracefully treat Postgres `42P01` (undefined_table) as a soft success when a table may not be provisioned yet.

**Writes are allowlisted.** Every generated route has an `ALLOWED_FIELDS` list and copies only those keys out of the request body (`pickAllowed(body)`). `id`, `created_at`, `updated_at` and the owner column are never client-settable: the database or the server stamps them. Never pass a raw `body` to `.insert()` / `.update()`.

**Migrations:** early ones are `NNN_name.sql`, newer ones `YYYYMMDD_name.sql`. Prefer the date form. PK is `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`. Every mutable table gets `created_at` **and** `updated_at TIMESTAMPTZ DEFAULT now()`, a shared `update_updated_at()` trigger (guard with `CREATE OR REPLACE`), and indexes on FKs and any filtered column.

**The CRM RLS model is staff-shared, not owner-scoped.** In `005_crm_tables.sql` every CRM table uses `CREATE POLICY "Authenticated CRM access" ON <t> FOR ALL USING (auth.role() = 'authenticated')` — admin/team see all rows; the service role bypasses RLS for cron/webhooks. This is deliberate for internal CRM data and is different from the per-user `auth.uid() = user_id` default. **Decide up front which model the entity needs and delegate the policy block to the `rls-migration-writer` skill** (see below) — do not hand-roll `WITH CHECK (true)`.

**Seeds are idempotent:** fixed UUIDs like `a1000001-0001-0001-0001-0000000000NN` + `ON CONFLICT (id) DO NOTHING`, so a re-run (or a fresh `supabase db reset`) never duplicates or errors.

## Workflow

1. **Gather the shape.** Entity name (snake_case, plural — `quotes`), its columns + types, the FK parents (e.g. `client_id → clients(id)`), and the access model (staff-shared CRM vs owner-scoped per-user). Pick the auth pattern accordingly.
2. **Scaffold all four files (dry-run first).** The generator prints every file to stdout with clear separators; nothing is written until you pass `--write`:
   ```bash
   bash ~/.claude/skills/crud-route-scaffold/scripts/new-crud-entity.sh \
     --entity quotes --section crm \
     --column 'quote_number:text:notnull' --column 'total:numeric' \
     --column 'status:text' --fk 'client_id:clients' \
     --access staff
   ```
   `ALLOWED_FIELDS` in the route is filled from the `--column` and `--fk` names. Add `--owner user_id` and `--access owner` for a per-user entity: that emits `references/route-handler.owner.ts` instead, which stamps `user_id: user.id` on insert, adds `.eq('user_id', user.id)` to every select/update/delete, drops the admin gate (owners manage their own rows) and indexes the owner column. `--access staff` (the default) keeps the staff-shared route. Review the output, then re-run with `--write` to drop the files into `ventures/gildedge-portal` (override with `--venture <name>`).
3. **Delegate the RLS block.** The migration the generator emits contains a clearly marked `-- >>> RLS: delegate to rls-migration-writer` placeholder. Fill it using that skill so the policies match house conventions and avoid the shipped anti-patterns (`WITH CHECK (true)`, recursive policies):
   ```bash
   bash ~/.claude/skills/rls-migration-writer/scripts/new-migration.sh \
     --venture gildedge-portal --table quotes --owner user_id
   ```
   For staff-shared CRM tables, use the `auth.role() = 'authenticated'` FOR ALL policy from `005_crm_tables.sql` instead of the owner-scoped four.
4. **Fill real columns & FK indexes.** Replace placeholder columns with the true schema; every FK gets `REFERENCES <parent>(id)` (add `ON DELETE CASCADE` for child rows like line-items) and a matching `CREATE INDEX`.
5. **Wire the client UI.** The generated `page.tsx` renders a minimal server list. Build the interactive `<Entity>Client.tsx` + `.module.css` following the existing `portal/crm/CRMDashboardClient.tsx` pattern (glassmorphism, gold `#D4AF37`).
6. **Verify.** `npm run build` in the venture, and confirm the migration survives a clean `supabase db reset` (FK parents must be created by an earlier migration; no duplicate `CREATE TABLE`).

## Before / after

### Before — copy `portal/crm/`, rename, hand-edit 4 files, forget the audit log and the `42P01` guard.

### After — one command emits all four, in-convention:

**`src/app/api/quotes/route.ts` (staff-shared; PATCH/DELETE admin only):**
```ts
import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { requireAuth } from '@/lib/require-auth';
import { logAuditEvent } from '@/lib/audit';

const TABLE = 'quotes';
const SECTION = 'crm';

// Only these keys are ever written from a request body (from --column / --fk).
const ALLOWED_FIELDS: readonly string[] = ['client_id', 'quote_number', 'total', 'status'];
// pickAllowed(body) copies just those keys; readJsonObject(req) returns null
// unless the body is a plain JSON object. Both are in the reference handler.

// GET /api/quotes: list (section-gated, RLS-scoped via the session client)
export async function GET() {
  try {
    await requireAuth(SECTION);
  } catch {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const supabase = await createClient();
    const { data, error } = await supabase
      .from(TABLE)
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      if (error.code === '42P01') return NextResponse.json({ items: [] });
      throw error;
    }
    return NextResponse.json({ items: data ?? [] });
  } catch (err) {
    console.error(`[${TABLE} GET] error:`, err);
    return NextResponse.json({ error: 'Failed to load' }, { status: 500 });
  }
}

// POST /api/quotes: create
export async function POST(req: NextRequest) {
  let user: { id: string; email: string }; let role: string; let orgId: string;
  try {
    const auth = await requireAuth(SECTION);
    user = auth.user; role = auth.role; orgId = auth.orgId;
  } catch {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const body = await readJsonObject(req);
  if (!body) return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });

  // Session client, not the service client: RLS applies to the write too.
  const supabase = await createClient();
  const { data, error } = await supabase
    .from(TABLE)
    .insert(pickAllowed(body))
    .select()
    .single();
  if (error) {
    console.error(`[${TABLE} POST] error:`, error);  // real error stays server-side
    return NextResponse.json({ error: 'Failed to create' }, { status: 500 });
  }

  logAuditEvent({
    actor_id: user.id, actor_email: user.email, actor_role: role,
    action: 'write', resource_type: TABLE, resource_id: data.id,
    org_id: orgId, outcome: 'success',
  }).catch(() => {});

  return NextResponse.json({ item: data }, { status: 201 });
}
```

PATCH and DELETE follow the same shape: `requireAuth` + `role !== 'admin'` gate, `pickAllowed` on the PATCH body (400 if nothing allowlisted remains), `.select('id')` after the write and `404` when it matched no row. The owner variant (`--access owner`) is the same file with `[OWNER_COLUMN]: user.id` stamped on insert and `.eq(OWNER_COLUMN, user.id)` on every query.

**Migration `supabase/migrations/<date>_quotes.sql`** — table + indexes + `updated_at` trigger, with the RLS block delegated:
```sql
CREATE TABLE IF NOT EXISTS quotes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id    UUID REFERENCES clients(id) NOT NULL,
  quote_number TEXT NOT NULL,
  total        NUMERIC NOT NULL DEFAULT 0,
  status       TEXT NOT NULL DEFAULT 'draft',
  created_at   TIMESTAMPTZ DEFAULT now(),
  updated_at   TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_quotes_client ON quotes(client_id);

ALTER TABLE quotes ENABLE ROW LEVEL SECURITY;
-- >>> RLS: delegate to rls-migration-writer (staff-shared or owner-scoped) <<<

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE TRIGGER set_updated_at BEFORE UPDATE ON quotes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

**Idempotent seed** (re-runnable):
```sql
INSERT INTO quotes (id, client_id, quote_number, total, status) VALUES
  ('b1000001-0001-0001-0001-000000000001', 'c1000001-0001-0001-0001-000000000001', 'Q-2026-001', 4900, 'sent')
ON CONFLICT (id) DO NOTHING;
```

## Ecosystem gotchas

- **`createClient()`/`createServiceClient()` are async** — always `await`. Forgetting the await returns a Promise and every `.from()` throws.
- **Service client bypasses RLS.** Only use it after you have authenticated + authorized the caller yourself. For CRUD reads AND writes, use the session `createClient()` so RLS does the scoping; the generated routes never touch the service client. If you add one later, keep `pickAllowed` and (for owner tables) the owner filter, because nothing else is checking.
- **`requireAuth` currently has a test bypass** (returns a hard-coded admin) in this repo — keep the guard call in place so it works once real auth is restored; don't build logic that assumes the bypass.
- **CRM tables are staff-shared** (`auth.role() = 'authenticated'`), so a per-user `user_id` column is optional there. Only add owner-scoping for genuinely private per-user data (e.g. `marketing_strategies`, which is `.eq('user_id', user.id)` + `onConflict: 'user_id,module_id'`).
- **Canonical paths only** — write under `~/GILDED-EDGE-ECOSYSTEM/ventures/gildedge-portal`, never the `~/Documents/GILDEDGE/...` symlinks.
- **Don't invent an ORM** — everything is raw `supabase.from(...)`; match it.

## Files in this skill

- `scripts/new-crud-entity.sh` — dry-run generator; prints page.tsx + route.ts + migration + seed. `--write` to save into the venture.
- `references/route-handler.ts` — the full annotated GET/POST/PATCH/DELETE reference handler (staff-shared, `--access staff`).
- `references/route-handler.owner.ts`: the owner-scoped variant (`--access owner`); stamps and filters on the owner column.
- `references/page.tsx` — the reference RSC page + audit-log wiring.
