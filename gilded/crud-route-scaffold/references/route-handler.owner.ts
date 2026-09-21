// ═══════════════════════════════════════════════════════════════════
// Reference OWNER-SCOPED route handler: gildedge-portal conventions
// src/app/api/<entity>/route.ts
//
// Full GET / POST / PATCH / DELETE for a per-user entity: every row belongs
// to exactly one user and nobody else can read or change it.
// - requireAuth(SECTION) on every method for authentication + section RBAC.
//   No admin check: owners manage their own rows.
// - OWNER_COLUMN is stamped from the verified session user on insert and is
//   never read from the body. Every select / update / delete also filters on
//   it, so the route stays owner-scoped even if an RLS policy is missing or
//   too broad. Pair it with the four owner policies from rls-migration-writer.
// - Session client (createClient) for every query, so RLS applies as well.
// - Writes copy only ALLOWED_FIELDS out of the request body. id, the owner
//   column, created_at and updated_at are never client-settable.
// - Uniform NextResponse.json({ error }, { status }) error shape. Clients
//   get a generic message; the real DB error is console.error'd server-side.
// - Postgres 42P01 (undefined_table) treated as a soft success.
// - logAuditEvent(...).catch(() => {}) fire-and-forget on writes.
//
// No service-role client here: it bypasses RLS and would make the owner
// filter the only thing standing between users. If a route genuinely needs
// one, create it only AFTER this handler has authenticated and authorized
// the caller, and keep the OWNER_COLUMN filter on every query.
// ═══════════════════════════════════════════════════════════════════

import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { requireAuth } from '@/lib/require-auth';
import { logAuditEvent } from '@/lib/audit';

const TABLE = 'ENTITY';        // e.g. 'saved_views'
const SECTION = 'SECTION';     // RBAC section, e.g. 'metrics'
const OWNER_COLUMN = 'OWNER';  // owner column, e.g. 'user_id' (--owner)

// Columns a caller may set on POST / PATCH. Every other key in the body is
// dropped, so nobody can write id, the owner column, created_at, updated_at,
// or a column added to the table later without also being added here.
// new-crud-entity.sh fills this from --column / --fk; after that, keep it in
// step with the migration. Never add OWNER_COLUMN to this list.
const ALLOWED_FIELDS: readonly string[] = [/* FIELDS */];

// Copy only allowlisted keys out of an untrusted request body.
function pickAllowed(body: Record<string, unknown>): Record<string, unknown> {
  const row: Record<string, unknown> = {};
  for (const key of ALLOWED_FIELDS) {
    if (key === OWNER_COLUMN) continue;
    if (Object.prototype.hasOwnProperty.call(body, key)) row[key] = body[key];
  }
  return row;
}

// req.json() can resolve to null, a string or an array. Only a plain object
// is a usable row; anything else is treated like unparseable JSON.
async function readJsonObject(req: NextRequest): Promise<Record<string, unknown> | null> {
  try {
    const body: unknown = await req.json();
    if (body && typeof body === 'object' && !Array.isArray(body)) {
      return body as Record<string, unknown>;
    }
  } catch {
    // fall through to null
  }
  return null;
}

// ─── GET /api/ENTITY: list the caller's own rows ─────────────────────
export async function GET() {
  let userId: string;
  try {
    userId = (await requireAuth(SECTION)).user.id;
  } catch {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const supabase = await createClient();
    const { data, error } = await supabase
      .from(TABLE)
      .select('*')
      .eq(OWNER_COLUMN, userId)
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

// ─── POST /api/ENTITY: create a row owned by the caller ──────────────
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

  const supabase = await createClient();
  const { data, error } = await supabase
    .from(TABLE)
    // Owner stamped last, from the session, so the body can never set it.
    .insert({ ...pickAllowed(body), [OWNER_COLUMN]: user.id })
    .select()
    .single();
  if (error) {
    console.error(`[${TABLE} POST] error:`, error);
    return NextResponse.json({ error: 'Failed to create' }, { status: 500 });
  }

  logAuditEvent({
    actor_id: user.id, actor_email: user.email, actor_role: role,
    action: 'write', resource_type: TABLE, resource_id: data.id,
    org_id: orgId, outcome: 'success',
  }).catch(() => {});

  return NextResponse.json({ item: data }, { status: 201 });
}

// ─── PATCH /api/ENTITY: update one of the caller's rows by id ────────
export async function PATCH(req: NextRequest) {
  let user: { id: string; email: string }; let role: string; let orgId: string;
  try {
    const auth = await requireAuth(SECTION);
    user = auth.user; role = auth.role; orgId = auth.orgId;
  } catch {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const body = await readJsonObject(req);
  if (!body) return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  const id = body.id;
  if (typeof id !== 'string' || !id) {
    return NextResponse.json({ error: 'Missing id' }, { status: 400 });
  }
  const patch = pickAllowed(body);
  if (Object.keys(patch).length === 0) {
    return NextResponse.json({ error: 'No updatable fields' }, { status: 400 });
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from(TABLE)
    .update(patch)
    .eq('id', id)
    .eq(OWNER_COLUMN, user.id)
    .select('id');
  if (error) {
    if (error.code === '42P01') return NextResponse.json({ success: true, note: 'table not yet provisioned' });
    console.error(`[${TABLE} PATCH] error:`, error);
    return NextResponse.json({ error: 'Failed to update' }, { status: 500 });
  }
  // Someone else's row and a nonexistent row both match nothing. Answer 404
  // for both so the route does not reveal which ids exist.
  if (!data?.length) return NextResponse.json({ error: 'Not found' }, { status: 404 });

  logAuditEvent({
    actor_id: user.id, actor_email: user.email, actor_role: role,
    action: 'write', resource_type: TABLE, resource_id: id,
    org_id: orgId, outcome: 'success',
  }).catch(() => {});

  return NextResponse.json({ success: true, id });
}

// ─── DELETE /api/ENTITY?id=...: delete one of the caller's rows ──────
export async function DELETE(req: NextRequest) {
  let user: { id: string; email: string }; let role: string; let orgId: string;
  try {
    const auth = await requireAuth(SECTION);
    user = auth.user; role = auth.role; orgId = auth.orgId;
  } catch {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const id = req.nextUrl.searchParams.get('id');
  if (!id) return NextResponse.json({ error: 'Missing id' }, { status: 400 });

  const supabase = await createClient();
  const { data, error } = await supabase
    .from(TABLE)
    .delete()
    .eq('id', id)
    .eq(OWNER_COLUMN, user.id)
    .select('id');
  if (error) {
    console.error(`[${TABLE} DELETE] error:`, error);
    return NextResponse.json({ error: 'Failed to delete' }, { status: 500 });
  }
  if (!data?.length) return NextResponse.json({ error: 'Not found' }, { status: 404 });

  logAuditEvent({
    actor_id: user.id, actor_email: user.email, actor_role: role,
    action: 'delete', resource_type: TABLE, resource_id: id,
    org_id: orgId, outcome: 'success',
  }).catch(() => {});

  return NextResponse.json({ success: true, id });
}
