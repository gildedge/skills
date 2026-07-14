// ═══════════════════════════════════════════════════════════════════
// Reference CRM route handler — gildedge-portal conventions
// src/app/api/<entity>/route.ts
//
// Full GET / POST / PATCH / DELETE for a staff-shared CRM entity.
// - Session client (createClient) for RLS-scoped reads.
// - Service client (createServiceClient) for trusted writes after
//   the caller has been authenticated + authorized.
// - Uniform NextResponse.json({ error }, { status }) error shape.
// - Postgres 42P01 (undefined_table) treated as a soft success.
// - logAuditEvent(...).catch(() => {}) fire-and-forget on writes.
//
// For an OWNER-SCOPED entity instead: drop requireAuth/role checks,
// use `const { data: { user } } = await supabase.auth.getUser()` and
// add `.eq('user_id', user.id)` to every query (see marketing/strategies).
// ═══════════════════════════════════════════════════════════════════

import { NextRequest, NextResponse } from 'next/server';
import { createClient, createServiceClient } from '@/lib/supabase/server';
import { requireAuth } from '@/lib/require-auth';
import { logAuditEvent } from '@/lib/audit';

const TABLE = 'ENTITY';        // e.g. 'quotes'
const SECTION = 'SECTION';     // RBAC section, e.g. 'crm'

// ─── GET /api/ENTITY — list ──────────────────────────────────────────
export async function GET() {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

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

// ─── POST /api/ENTITY — create ───────────────────────────────────────
export async function POST(req: NextRequest) {
  let user: { id: string; email: string }; let role: string; let orgId: string;
  try {
    const auth = await requireAuth(SECTION);
    user = auth.user; role = auth.role; orgId = auth.orgId;
  } catch {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  let body: Record<string, unknown> = {};
  try { body = await req.json(); } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const supabase = await createServiceClient();
  const { data, error } = await supabase.from(TABLE).insert(body).select().single();
  if (error) {
    console.error(`[${TABLE} POST] error:`, error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  logAuditEvent({
    actor_id: user.id, actor_email: user.email, actor_role: role,
    action: 'write', resource_type: TABLE, resource_id: data.id,
    org_id: orgId, outcome: 'success',
  }).catch(() => {});

  return NextResponse.json({ item: data }, { status: 201 });
}

// ─── PATCH /api/ENTITY — update by id ────────────────────────────────
export async function PATCH(req: NextRequest) {
  let user: { id: string; email: string }; let role: string; let orgId: string;
  try {
    const auth = await requireAuth(SECTION);
    user = auth.user; role = auth.role; orgId = auth.orgId;
  } catch {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }
  if (role !== 'admin') {
    return NextResponse.json({ error: 'Forbidden — admin only' }, { status: 403 });
  }

  let body: { id?: string; [k: string]: unknown } = {};
  try { body = await req.json(); } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }
  const { id, ...patch } = body;
  if (!id) return NextResponse.json({ error: 'Missing id' }, { status: 400 });

  const supabase = await createServiceClient();
  const { error } = await supabase.from(TABLE).update(patch).eq('id', id);
  if (error) {
    if (error.code === '42P01') return NextResponse.json({ success: true, note: 'table not yet provisioned' });
    console.error(`[${TABLE} PATCH] error:`, error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  logAuditEvent({
    actor_id: user.id, actor_email: user.email, actor_role: role,
    action: 'write', resource_type: TABLE, resource_id: id,
    org_id: orgId, outcome: 'success',
  }).catch(() => {});

  return NextResponse.json({ success: true, id });
}

// ─── DELETE /api/ENTITY?id=... — delete ──────────────────────────────
export async function DELETE(req: NextRequest) {
  let user: { id: string; email: string }; let role: string; let orgId: string;
  try {
    const auth = await requireAuth(SECTION);
    user = auth.user; role = auth.role; orgId = auth.orgId;
  } catch {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }
  if (role !== 'admin') {
    return NextResponse.json({ error: 'Forbidden — admin only' }, { status: 403 });
  }

  const id = req.nextUrl.searchParams.get('id');
  if (!id) return NextResponse.json({ error: 'Missing id' }, { status: 400 });

  const supabase = await createServiceClient();
  const { error } = await supabase.from(TABLE).delete().eq('id', id);
  if (error) {
    console.error(`[${TABLE} DELETE] error:`, error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  logAuditEvent({
    actor_id: user.id, actor_email: user.email, actor_role: role,
    action: 'delete', resource_type: TABLE, resource_id: id,
    org_id: orgId, outcome: 'success',
  }).catch(() => {});

  return NextResponse.json({ success: true, id });
}
