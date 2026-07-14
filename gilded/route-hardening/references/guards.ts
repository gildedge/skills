// ══════════════════════════════════════════════════════════════════
// route-hardening — drop-in guard snippets for Gilded Edge API routes.
// These use helpers that ALREADY EXIST in the ventures. Copy the block
// you need into your app/api/**/route.ts. Adjust import paths per venture
// (gilded-art-works uses createServerSupabase; lumier-studios exports
// createClient + requireApiUser).
// ══════════════════════════════════════════════════════════════════

import { NextRequest, NextResponse } from 'next/server';

// ─────────────────────────────────────────────────────────────────
// 1. SESSION AUTH — require a logged-in user (RLS-respecting anon client)
//    gilded-art-works style: @/lib/supabase/server → createServerSupabase()
// ─────────────────────────────────────────────────────────────────
import { createServerSupabase } from '@/lib/supabase/server';

async function getUser() {
  const supabase = await createServerSupabase();
  const { data: { user } } = await supabase.auth.getUser();
  return { user, supabase };
}

export async function GET() {
  const { user, supabase } = await getUser();
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  // ── 2. OWNER SCOPING — every query filters by the caller's id ──
  const { data, error } = await supabase
    .from('artworks')
    .select('*')
    .eq('user_id', user.id)          // ✓ never return another tenant's rows
    .order('updated_at', { ascending: false });

  if (error) {
    console.error('[Artworks] List error:', error);
    return NextResponse.json({ error: 'Failed to load' }, { status: 500 });
  }
  return NextResponse.json({ artworks: data ?? [] });
}

// ── Mutations: scope delete/update by owner too (prevents IDOR) ──
export async function DELETE(request: NextRequest) {
  const { user, supabase } = await getUser();
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const id = new URL(request.url).searchParams.get('id');
  if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });

  const { error } = await supabase
    .from('artworks')
    .delete()
    .eq('id', id)
    .eq('user_id', user.id);         // ✓ constrain to owner — not just .eq('id', id)
  if (error) {
    console.error('[Artworks] Delete error:', error);
    return NextResponse.json({ error: 'Failed to delete' }, { status: 500 });
  }
  return NextResponse.json({ success: true });
}

/*
// ── lumier-studios variant: the shared guard from @/lib/api-auth ──
import { requireApiUser } from '@/lib/api-auth';

export async function POST(request: Request) {
  const auth = await requireApiUser();
  if (auth instanceof NextResponse) return auth;     // 401
  const user = auth;                                 // Supabase User
  // ...use user.id to scope queries / attribute spend...
}
// Use this on EVERY money-spending route (/api/ai/*) so anonymous
// callers can't burn Gemini / ElevenLabs quota.
*/


// ─────────────────────────────────────────────────────────────────
// 3. WEBHOOK SIGNATURE — verify the RAW body before any side effect.
//    Read request.text() FIRST; request.json() first breaks the HMAC.
// ─────────────────────────────────────────────────────────────────

// (a) Stripe — construct + verify in one step:
import { stripe } from '@/lib/stripe';

export async function POST_stripe(request: NextRequest) {
  if (!stripe) return NextResponse.json({ error: 'Stripe not configured' }, { status: 503 });
  const body = await request.text();                 // raw
  const signature = request.headers.get('stripe-signature');
  if (!signature) return NextResponse.json({ error: 'Missing signature' }, { status: 400 });

  let event;
  try {
    event = stripe.webhooks.constructEvent(body, signature, process.env.STRIPE_WEBHOOK_SECRET!);
  } catch (err) {
    console.error('[Webhook] Signature verification failed:', err);
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 });
  }
  // Make handlers idempotent (skip if event.id already recorded). Then dispatch on event.type.
  return NextResponse.json({ received: true });
}

// (b) Non-Stripe providers — use the shared verifiers in @/lib/webhook-utils:
import {
  verifyHmacSha256,
  verifyLemonSqueezySignature,
  // verifySlackSignature, verifyCalendlySignature,
} from '@/lib/webhook-utils';

export async function POST_lemonsqueezy(request: NextRequest) {
  const secret = process.env.LEMONSQUEEZY_WEBHOOK_SECRET;
  if (!secret) return NextResponse.json({ error: 'Not configured' }, { status: 500 });

  const rawBody = await request.text();              // raw, before JSON.parse
  const signature = request.headers.get('x-signature') || '';
  if (!verifyLemonSqueezySignature(rawBody, signature, secret)) {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 401 });
  }
  const payload = JSON.parse(rawBody);
  void payload; void verifyHmacSha256;               // (generic n8n/custom fallback)
  return NextResponse.json({ received: true });
}


// ─────────────────────────────────────────────────────────────────
// 4. SSRF GUARD — validate any user-supplied outbound URL before fetch.
//    checkOutboundUrl blocks non-HTTPS, localhost, RFC-1918, link-local
//    (incl. 169.254.169.254 cloud metadata), and CGNAT.
// ─────────────────────────────────────────────────────────────────
import { checkOutboundUrl } from '@/lib/url-guard';

async function dispatchOutbound(userUrl: string, body: string) {
  const guard = await checkOutboundUrl(userUrl);
  if (!guard.ok) throw new Error(`blocked destination: ${guard.reason}`);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);
  try {
    return await fetch(guard.url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }
}
void dispatchOutbound;


// ─────────────────────────────────────────────────────────────────
// 5. RATE LIMIT — the ONE shared limiter. Do not add a 4th copy.
//    (gilded-art-works had rate-limit.ts + rate-limiter.ts + proxy.ts.)
// ─────────────────────────────────────────────────────────────────
import { checkRateLimit, RATE_LIMITS } from '@/lib/rate-limit';

export async function POST_checkout(request: NextRequest) {
  const limited = checkRateLimit(request, ...RATE_LIMITS.checkout);  // 5/min
  if (limited) return limited;                       // 429 with Retry-After
  // ...
  return NextResponse.json({ ok: true });
}

// Note: the in-memory limiter resets on serverless cold start and does not
// share across instances — a speed bump, not a durable quota. For money/auth
// routes that need a real limit, back it with Upstash/Redis.
