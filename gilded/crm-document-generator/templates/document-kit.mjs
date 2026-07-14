/* ═══════════════════════════════════════════════════════════
   Gilded Edge — Document Kit (@react-pdf/renderer)
   One brand-aligned family: invoice · quote · proposal ·
   contract · coa (certificate of authenticity).

   No JSX, no build step: uses React.createElement so it runs
   directly under `node`. React and @react-pdf/renderer are
   INJECTED by the caller (render.mjs resolves them from the
   target venture's node_modules) — this module imports neither,
   which sidesteps ESM bare-specifier resolution across ventures.

   const kit = makeKit({ React, ReactPDF, brand: 'gilded' });
   const el  = kit.InvoiceDocument(payload);
   ═══════════════════════════════════════════════════════════ */

import { resolveBrand, money, shortMoney, fmtDate } from './brand-tokens.mjs';

export function makeKit({ React, ReactPDF, brand = 'gilded' } = {}) {
  if (!React || !ReactPDF) throw new Error('makeKit requires { React, ReactPDF }');
  const h = React.createElement;
  const { Document, Page, Text, View, StyleSheet } = ReactPDF;
  const C = resolveBrand(brand);

  const s = StyleSheet.create({
    page: { backgroundColor: C.OBSIDIAN, padding: 48, fontFamily: 'Helvetica', color: C.TEXT, fontSize: 10 },
    header: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 32, paddingBottom: 20, borderBottomWidth: 2, borderBottomColor: C.ACCENT },
    brandRow: { flexDirection: 'row', alignItems: 'center', marginBottom: 3 },
    brandDot: { width: 8, height: 8, backgroundColor: C.ACCENT, marginRight: 10 },
    logo: { fontSize: 22, fontWeight: 'bold', color: C.ACCENT, letterSpacing: 1 },
    tagline: { fontSize: 8, color: C.MUTED, marginTop: 3, letterSpacing: 0.5 },
    companyLine: { fontSize: 8, color: C.MUTED, marginTop: 2 },
    right: { alignItems: 'flex-end' },
    docLabel: { fontSize: 9, color: C.MUTED, textTransform: 'uppercase', letterSpacing: 2, marginBottom: 4 },
    docNum: { fontSize: 18, fontWeight: 'bold', color: C.TEXT, marginBottom: 4 },
    docDate: { fontSize: 9, color: C.MUTED },
    badge: { marginTop: 8, paddingHorizontal: 10, paddingVertical: 4, borderRadius: 4, fontSize: 8, fontWeight: 'bold', textTransform: 'uppercase', letterSpacing: 1 },
    metaRow: { flexDirection: 'row', marginBottom: 28, gap: 20 },
    metaBlock: { flex: 1, backgroundColor: C.SURFACE, borderRadius: 8, padding: 16 },
    metaLabel: { fontSize: 7, color: C.ACCENT, textTransform: 'uppercase', letterSpacing: 1.5, marginBottom: 8, fontWeight: 'bold' },
    metaValue: { fontSize: 12, color: C.TEXT, fontWeight: 'bold', marginBottom: 2 },
    metaSub: { fontSize: 9, color: C.MUTED, marginTop: 1 },
    sectionTitle: { fontSize: 8, color: C.ACCENT, textTransform: 'uppercase', letterSpacing: 1.5, fontWeight: 'bold', marginBottom: 12, marginTop: 6 },
    tHead: { flexDirection: 'row', backgroundColor: C.SURFACE, borderRadius: 6, padding: '10 14', marginBottom: 2 },
    tRow: { flexDirection: 'row', padding: '12 14', borderBottomWidth: 1, borderBottomColor: C.DIVIDER },
    cDesc: { flex: 5, fontSize: 10, color: C.TEXT },
    cQty: { flex: 1, fontSize: 10, color: C.TEXT, textAlign: 'right' },
    cUnit: { flex: 2, fontSize: 10, color: C.TEXT, textAlign: 'right' },
    cAmt: { flex: 2, fontSize: 10, color: C.TEXT, textAlign: 'right', fontWeight: 'bold' },
    hDesc: { flex: 5, fontSize: 7, color: C.MUTED, textTransform: 'uppercase', letterSpacing: 0.8 },
    hQty: { flex: 1, fontSize: 7, color: C.MUTED, textTransform: 'uppercase', letterSpacing: 0.8, textAlign: 'right' },
    hUnit: { flex: 2, fontSize: 7, color: C.MUTED, textTransform: 'uppercase', letterSpacing: 0.8, textAlign: 'right' },
    hAmt: { flex: 2, fontSize: 7, color: C.MUTED, textTransform: 'uppercase', letterSpacing: 0.8, textAlign: 'right' },
    totals: { alignItems: 'flex-end', marginTop: 18, marginBottom: 30 },
    totalsDivider: { width: 220, height: 2, backgroundColor: C.ACCENT, marginVertical: 6 },
    totalsRow: { flexDirection: 'row', gap: 20, marginBottom: 5 },
    tLabel: { fontSize: 10, color: C.TEXT, width: 120, textAlign: 'right' },
    tVal: { fontSize: 10, color: C.TEXT, width: 100, textAlign: 'right' },
    tBigLabel: { fontSize: 10, color: C.TEXT, width: 120, textAlign: 'right', fontWeight: 'bold' },
    tBig: { fontSize: 20, color: C.SUCCESS, width: 100, textAlign: 'right', fontWeight: 'bold' },
    box: { backgroundColor: C.SURFACE, borderRadius: 8, padding: 16, marginBottom: 20 },
    boxText: { fontSize: 9, color: C.MUTED, lineHeight: 1.6 },
    sectionNum: { fontSize: 8, color: C.ACCENT, fontWeight: 'bold', marginBottom: 4, marginTop: 12 },
    legalTitle: { fontSize: 12, color: C.TEXT, fontWeight: 'bold', marginBottom: 10, textTransform: 'uppercase', letterSpacing: 0.5 },
    legalBody: { fontSize: 9, color: C.MUTED, lineHeight: 1.7, marginBottom: 14 },
    sigSection: { marginTop: 28, paddingTop: 20, borderTopWidth: 2, borderTopColor: C.ACCENT },
    sigRow: { flexDirection: 'row', gap: 40, marginTop: 20 },
    sigBox: { flex: 1 },
    sigLine: { borderBottomWidth: 1, borderBottomColor: C.MUTED, marginBottom: 6, paddingBottom: 28 },
    sigLabel: { fontSize: 8, color: C.MUTED },
    sigSub: { fontSize: 7, color: C.MUTED, marginTop: 2 },
    certWrap: { borderWidth: 1, borderColor: C.ACCENT, borderRadius: 6, padding: 32, marginTop: 8, alignItems: 'center' },
    certEyebrow: { fontSize: 8, color: C.ACCENT, textTransform: 'uppercase', letterSpacing: 3, marginBottom: 14 },
    certTitle: { fontSize: 28, color: C.TEXT, marginBottom: 6, textAlign: 'center' },
    certMeta: { fontSize: 10, color: C.MUTED, marginBottom: 18, textAlign: 'center' },
    certBody: { fontSize: 9, color: C.MUTED, lineHeight: 1.7, textAlign: 'center', marginBottom: 18, maxWidth: 380 },
    footer: { position: 'absolute', bottom: 32, left: 48, right: 48, borderTopWidth: 1, borderTopColor: C.DIVIDER, paddingTop: 10, flexDirection: 'row', justifyContent: 'space-between' },
    footerText: { fontSize: 7, color: C.MUTED },
  });

  // ── Shared fragments ───────────────────────────────────────
  const org = (o = {}) => ({
    name: o.name || 'Gilded Edge', tagline: o.tagline || '', email: o.email || '', site: o.site || '',
  });

  function Header({ o, label, num, date, status }) {
    const st = statusStyle(status, C);
    return h(View, { style: s.header }, [
      h(View, { key: 'l' }, [
        h(View, { key: 'br', style: s.brandRow }, [
          h(View, { key: 'd', style: s.brandDot }),
          h(Text, { key: 't', style: s.logo }, o.name),
        ]),
        o.tagline ? h(Text, { key: 'tg', style: s.tagline }, o.tagline) : null,
        o.email ? h(Text, { key: 'em', style: s.companyLine }, o.email) : null,
        o.site ? h(Text, { key: 'si', style: s.companyLine }, o.site) : null,
      ]),
      h(View, { key: 'r', style: s.right }, [
        h(Text, { key: 'lb', style: s.docLabel }, label),
        h(Text, { key: 'nm', style: s.docNum }, num),
        h(Text, { key: 'dt', style: s.docDate }, `Issued ${fmtDate(date)}`),
        status ? h(View, { key: 'bd', style: [s.badge, { backgroundColor: st.bg, color: st.fg }] },
          h(Text, {}, String(status).toUpperCase())) : null,
      ]),
    ]);
  }

  function BillTo(client = {}) {
    return h(View, { key: 'm1', style: s.metaBlock }, [
      h(Text, { key: 'l', style: s.metaLabel }, 'Bill To'),
      h(Text, { key: 'n', style: s.metaValue }, client.full_name || client.name || '—'),
      client.company ? h(Text, { key: 'c', style: s.metaSub }, client.company) : null,
      client.email ? h(Text, { key: 'e', style: s.metaSub }, client.email) : null,
      client.phone ? h(Text, { key: 'p', style: s.metaSub }, client.phone) : null,
    ]);
  }

  function LineItemsTable({ items, currency }) {
    const rows = (items || []).map((it, i) => h(View, { key: `r${i}`, style: s.tRow }, [
      h(Text, { key: 'd', style: s.cDesc }, it.description || it.title || '—'),
      h(Text, { key: 'q', style: s.cQty }, String(it.qty ?? it.quantity ?? 1)),
      h(Text, { key: 'u', style: s.cUnit }, money(it.unit_price ?? it.price ?? it.amount ?? 0, currency)),
      h(Text, { key: 'a', style: s.cAmt }, money(lineAmount(it), currency)),
    ]));
    return h(View, {}, [
      h(View, { key: 'h', style: s.tHead }, [
        h(Text, { key: 'd', style: s.hDesc }, 'Description'),
        h(Text, { key: 'q', style: s.hQty }, 'Qty'),
        h(Text, { key: 'u', style: s.hUnit }, 'Unit'),
        h(Text, { key: 'a', style: s.hAmt }, 'Amount'),
      ]),
      ...rows,
    ]);
  }

  function Totals({ items, currency, taxRate = 0, depositPct = 0, big = 'Amount Due' }) {
    const sub = (items || []).reduce((t, it) => t + lineAmount(it), 0);
    const tax = sub * (Number(taxRate) || 0);
    const total = sub + tax;
    const deposit = total * (Number(depositPct) || 0);
    const rows = [
      h(View, { key: 'sub', style: s.totalsRow }, [h(Text, { key: 'a', style: s.tLabel }, 'Subtotal'), h(Text, { key: 'b', style: s.tVal }, money(sub, currency))]),
    ];
    if (taxRate) rows.push(h(View, { key: 'tax', style: s.totalsRow }, [h(Text, { key: 'a', style: s.tLabel }, `Tax (${(taxRate * 100).toFixed(1)}%)`), h(Text, { key: 'b', style: s.tVal }, money(tax, currency))]));
    rows.push(h(View, { key: 'div', style: s.totalsDivider }));
    rows.push(h(View, { key: 'big', style: s.totalsRow }, [h(Text, { key: 'a', style: s.tBigLabel }, big), h(Text, { key: 'b', style: s.tBig }, money(total, currency))]));
    if (depositPct) rows.push(h(View, { key: 'dep', style: s.totalsRow }, [h(Text, { key: 'a', style: s.tLabel }, `Deposit (${(depositPct * 100).toFixed(0)}%)`), h(Text, { key: 'b', style: s.tVal }, money(deposit, currency))]));
    return h(View, { style: s.totals }, rows);
  }

  function Footer({ o, num }) {
    const year = new Date().getFullYear();
    return h(View, { style: s.footer, fixed: true }, [
      h(Text, { key: 'l', style: s.footerText }, `© ${year} ${o.name} — Confidential`),
      h(Text, { key: 'r', style: s.footerText }, `${num}${o.site ? ' · ' + o.site : ''}`),
    ]);
  }

  // ── Documents ──────────────────────────────────────────────
  function InvoiceDocument(p = {}) {
    const o = org(p.org);
    const currency = p.currency || 'USD';
    const num = p.number || `INV-${String(p.id || '0001').replace(/^inv-/i, '').toUpperCase().padStart(4, '0')}`;
    const items = p.line_items || (p.amount != null ? [{ description: p.description || 'Professional Services', qty: 1, unit_price: p.amount }] : []);
    return h(Document, { title: `Invoice ${num}`, author: o.name },
      h(Page, { size: 'A4', style: s.page }, [
        h(Header, { key: 'hd', o, label: 'Invoice', num, date: p.created_at || p.date, status: p.status }),
        h(View, { key: 'meta', style: s.metaRow }, [
          BillTo(p.client || {}),
          h(View, { key: 'm2', style: s.metaBlock }, [
            h(Text, { key: 'l', style: s.metaLabel }, 'Details'),
            h(Text, { key: 'n', style: s.metaSub }, `Invoice #: ${num}`),
            h(Text, { key: 'd', style: s.metaSub }, `Date: ${fmtDate(p.created_at || p.date)}`),
            h(Text, { key: 'du', style: s.metaSub }, `Due: ${fmtDate(p.due_at)}`),
            h(Text, { key: 'c', style: s.metaSub }, `Currency: ${currency}`),
          ]),
        ]),
        h(Text, { key: 'st', style: s.sectionTitle }, 'Line Items'),
        h(LineItemsTable, { key: 'tbl', items, currency }),
        h(Totals, { key: 'tot', items, currency, taxRate: p.tax_rate || 0, big: 'Amount Due' }),
        h(View, { key: 'nb', style: s.box }, h(Text, { style: s.boxText },
          `Payment is due by the date above. Reference ${num} with your remittance. Late balances accrue 1.5% per month.`)),
        h(Footer, { key: 'ft', o, num }),
      ]));
  }

  function QuoteDocument(p = {}) {
    const o = org(p.org);
    const currency = p.currency || 'USD';
    const num = p.number || `Q-${String(p.id || '0001').toUpperCase()}`;
    const items = p.line_items || [];
    return h(Document, { title: `Quote ${num}`, author: o.name },
      h(Page, { size: 'A4', style: s.page }, [
        h(Header, { key: 'hd', o, label: 'Quote', num, date: p.created_at || p.date, status: p.status }),
        h(View, { key: 'meta', style: s.metaRow }, [
          BillTo(p.client || {}),
          h(View, { key: 'm2', style: s.metaBlock }, [
            h(Text, { key: 'l', style: s.metaLabel }, 'Valid Until'),
            h(Text, { key: 'v', style: s.metaValue }, fmtDate(p.valid_until || p.expires_at)),
            h(Text, { key: 'n', style: s.metaSub }, `Quote #: ${num}`),
          ]),
        ]),
        h(Text, { key: 'st', style: s.sectionTitle }, 'Estimate'),
        h(LineItemsTable, { key: 'tbl', items, currency }),
        h(Totals, { key: 'tot', items, currency, taxRate: p.tax_rate || 0, depositPct: p.deposit_pct || 0, big: 'Estimated Total' }),
        h(View, { key: 'nb', style: s.box }, h(Text, { style: s.boxText },
          p.notes || 'This estimate is valid until the date shown and subject to a signed agreement. Prices exclude applicable taxes unless stated.')),
        h(Footer, { key: 'ft', o, num }),
      ]));
  }

  function ProposalDocument(p = {}) {
    const o = org(p.org);
    const currency = p.currency || 'USD';
    const num = p.number || `PROP-${String(p.id || '0001').toUpperCase()}`;
    const items = p.line_items || [];
    return h(Document, { title: p.title || `Proposal ${num}`, author: o.name },
      h(Page, { size: 'A4', style: s.page }, [
        h(Header, { key: 'hd', o, label: 'Proposal', num, date: p.created_at || p.date, status: p.status }),
        h(View, { key: 'meta', style: s.metaRow }, [
          BillTo(p.client || {}),
          h(View, { key: 'm2', style: s.metaBlock }, [
            h(Text, { key: 'l', style: s.metaLabel }, 'Prepared For'),
            h(Text, { key: 'n', style: s.metaValue }, (p.client && (p.client.company || p.client.full_name)) || '—'),
            h(Text, { key: 'd', style: s.metaSub }, fmtDate(p.created_at || p.date)),
          ]),
        ]),
        p.summary ? h(View, { key: 'sum', style: s.box }, h(Text, { style: s.boxText }, p.summary)) : null,
        h(Text, { key: 'st', style: s.sectionTitle }, 'Scope & Investment'),
        h(LineItemsTable, { key: 'tbl', items, currency }),
        h(Totals, { key: 'tot', items, currency, taxRate: p.tax_rate || 0, depositPct: p.deposit_pct || 0.5, big: 'Total Investment' }),
        h(Footer, { key: 'ft', o, num }),
      ]));
  }

  function ContractDocument(p = {}) {
    const o = org(p.org);
    const currency = p.currency || 'USD';
    const title = p.title || 'Service Agreement';
    const num = p.number || `AGR-${String(p.id || '0001').toUpperCase()}`;
    const total = Number(p.total || (p.line_items || []).reduce((t, it) => t + lineAmount(it), 0)) || 0;
    const deposit = Math.round(total * (p.deposit_pct || 0.5));
    const client = p.client || {};
    const sections = p.sections || defaultContractSections({ o, client, total, deposit, currency });
    const pageA = h(Page, { size: 'A4', style: s.page, key: 'p1' }, [
      h(Header, { key: 'hd', o, label: 'Agreement', num, date: p.created_at || p.date, status: p.status }),
      h(View, { key: 'parties', style: s.metaRow }, [
        h(View, { key: 'm2', style: s.metaBlock }, [
          h(Text, { key: 'l', style: s.metaLabel }, 'Service Provider'),
          h(Text, { key: 'n', style: s.metaValue }, o.name),
          o.email ? h(Text, { key: 'e', style: s.metaSub }, o.email) : null,
        ]),
        BillTo(client),
      ]),
      ...sections.slice(0, Math.ceil(sections.length / 2)).map((sec, i) => h(View, { key: `sa${i}` }, [
        h(Text, { key: 'n', style: s.sectionNum }, `SECTION ${i + 1}`),
        h(Text, { key: 't', style: s.legalTitle }, sec.title),
        h(Text, { key: 'b', style: s.legalBody }, sec.body),
      ])),
      h(Footer, { key: 'ft', o, num }),
    ]);
    const rest = sections.slice(Math.ceil(sections.length / 2));
    const pageB = h(Page, { size: 'A4', style: s.page, key: 'p2' }, [
      ...rest.map((sec, i) => h(View, { key: `sb${i}` }, [
        h(Text, { key: 'n', style: s.sectionNum }, `SECTION ${Math.ceil(sections.length / 2) + i + 1}`),
        h(Text, { key: 't', style: s.legalTitle }, sec.title),
        h(Text, { key: 'b', style: s.legalBody }, sec.body),
      ])),
      h(View, { key: 'sig', style: s.sigSection }, [
        h(Text, { key: 'l', style: s.metaLabel }, 'Signatures & Authorization'),
        h(View, { key: 'row', style: s.sigRow }, [
          h(View, { key: 'c', style: s.sigBox }, [h(View, { key: 'ln', style: s.sigLine }), h(Text, { key: 'nm', style: s.sigLabel }, `Client — ${client.full_name || client.name || ''}`), h(Text, { key: 'sb', style: s.sigSub }, client.company || 'Individual')]),
          h(View, { key: 'p', style: s.sigBox }, [h(View, { key: 'ln', style: s.sigLine }), h(Text, { key: 'nm', style: s.sigLabel }, `${o.name} Representative`), h(Text, { key: 'sb', style: s.sigSub }, 'Authorized Signatory')]),
        ]),
      ]),
      h(Footer, { key: 'ft', o, num }),
    ]);
    return h(Document, { title, author: o.name }, [pageA, pageB]);
  }

  // Certificate of Authenticity — for Gilded Artworks.
  function CoaDocument(p = {}) {
    const o = org(p.org.name ? p.org : { ...p.org, name: p.org && p.org.name || 'Gilded Artworks' });
    const num = p.number || `COA-${String(p.id || '0001').toUpperCase()}`;
    const art = (p.artworks && p.artworks[0]) || p.artwork || {};
    const meta = [art.artist, art.year, art.medium, art.dimensions].filter(Boolean).join(' · ');
    return h(Document, { title: `Certificate of Authenticity — ${num}`, author: o.name },
      h(Page, { size: 'A4', style: s.page }, [
        h(Header, { key: 'hd', o, label: 'Certificate', num, date: p.created_at || p.date }),
        h(View, { key: 'cert', style: s.certWrap }, [
          h(Text, { key: 'eb', style: s.certEyebrow }, 'This Certifies That'),
          h(Text, { key: 'ti', style: s.certTitle }, art.title || 'Artwork'),
          h(Text, { key: 'mt', style: s.certMeta }, meta || ''),
          h(Text, { key: 'bd', style: s.certBody }, p.statement ||
            'We hereby certify that the above work of art is original and authentic, created by the artist named herein. This certificate accompanies the work and confirms its provenance.'),
          art.price != null ? h(Text, { key: 'pr', style: [s.certMeta, { color: C.ACCENT }] }, `Appraised Value: ${shortMoney(art.price, p.currency || 'USD')}`) : null,
        ]),
        h(View, { key: 'sig', style: s.sigRow }, [
          h(View, { key: 's1', style: s.sigBox }, [h(View, { key: 'ln', style: s.sigLine }), h(Text, { key: 'nm', style: s.sigLabel }, p.signatory || o.name), h(Text, { key: 'sb', style: s.sigSub }, 'Authorized Representative')]),
        ]),
        h(Footer, { key: 'ft', o, num }),
      ]));
  }

  return { InvoiceDocument, QuoteDocument, ProposalDocument, ContractDocument, CoaDocument, tokens: C };
}

// ── pure helpers ─────────────────────────────────────────────
function lineAmount(it = {}) {
  if (it.amount != null) return Number(it.amount) || 0;
  const qty = Number(it.qty ?? it.quantity ?? 1) || 1;
  const unit = Number(it.unit_price ?? it.price ?? 0) || 0;
  return qty * unit;
}

function statusStyle(status, C) {
  switch (String(status || '').toLowerCase()) {
    case 'paid': case 'signed': return { bg: 'rgba(16,185,129,0.2)', fg: C.SUCCESS };
    case 'sent': return { bg: 'rgba(96,165,250,0.2)', fg: C.INFO };
    case 'overdue': return { bg: 'rgba(239,68,68,0.2)', fg: C.ERROR };
    default: return { bg: 'rgba(138,133,120,0.2)', fg: C.MUTED };
  }
}

function defaultContractSections({ o, client, total, deposit, currency }) {
  const name = client.full_name || client.name || 'Client';
  return [
    { title: 'Scope of Work', body: `${o.name} ("Provider") agrees to deliver the services described in the approved proposal to ${name} ("Client"). Changes after execution require a written amendment signed by both parties.` },
    { title: 'Payment Terms', body: `Total fee: ${money(total, currency)}. A deposit of ${money(deposit, currency)} is due on execution; the balance is due on delivery and Client approval, payable within 14 days of invoice. Overdue balances accrue 1.5% per month.` },
    { title: 'Intellectual Property', body: 'On receipt of full payment, Provider transfers all rights in the final deliverables to Client. Until then, all IP remains with Provider. Provider retains portfolio rights and ownership of raw/source files unless separately agreed.' },
    { title: 'Confidentiality', body: 'Both parties maintain confidentiality of proprietary information disclosed during the engagement. This obligation survives termination for two (2) years.' },
    { title: 'Termination', body: 'Either party may terminate with thirty (30) days written notice; Client pays for work completed to date. Either party may terminate immediately on uncured material breach after fifteen (15) days written notice.' },
    { title: 'General Provisions', body: 'This agreement is the entire understanding between the parties and is governed by the laws of the State of California. Disputes are resolved by binding arbitration in Los Angeles County.' },
  ];
}
