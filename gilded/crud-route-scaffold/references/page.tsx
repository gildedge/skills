// ═══════════════════════════════════════════════════════════════════
// Reference CRM page — gildedge-portal conventions
// src/app/portal/<entity>/page.tsx  (React Server Component)
//
// - requireAuth('<section>') at the top (redirects if unauthorized).
// - logAuditEvent(...).catch(() => {}) fire-and-forget 'read' event.
// - export const revalidate for ISR; export const metadata for <title>.
// - Fetches server-side via the session client, hands data to a
//   client component (build <Entity>Client.tsx + .module.css yourself,
//   modeled on portal/crm/CRMDashboardClient.tsx — CSS Modules, no Tailwind).
// ═══════════════════════════════════════════════════════════════════

import { requireAuth } from '@/lib/require-auth';
import { logAuditEvent } from '@/lib/audit';
import { createClient } from '@/lib/supabase/server';
// import EntityClient from './EntityClient';

export const revalidate = 60;
export const metadata = { title: 'ENTITY_TITLE — GildEdge Portal' };

export default async function EntityPage() {
  const { user, role, orgId } = await requireAuth('SECTION');

  logAuditEvent({
    actor_id: user.id, actor_email: user.email, actor_role: role,
    action: 'read', resource_type: 'ENTITY', org_id: orgId, outcome: 'success',
  }).catch(() => {});

  let items: unknown[] = [];
  try {
    const supabase = await createClient();
    const { data } = await supabase
      .from('ENTITY')
      .select('*')
      .order('created_at', { ascending: false });
    items = data ?? [];
  } catch {
    items = [];
  }

  return (
    <div>
      {/* <EntityClient items={items} /> */}
      <pre>{JSON.stringify(items, null, 2)}</pre>
    </div>
  );
}
