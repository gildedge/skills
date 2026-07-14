#!/usr/bin/env node
/* ═══════════════════════════════════════════════════════════
   Gilded Edge — CRM document renderer (CLI)

   Renders a brand-aligned PDF (invoice | quote | proposal |
   contract | coa) from a JSON client/line-item payload using
   the ecosystem @react-pdf/renderer document kit.

   React + @react-pdf/renderer are resolved from a TARGET
   VENTURE's node_modules (they already ship it) — nothing new
   to install. Point --venture at any venture that has it, e.g.
   ventures/lumier-studios/app or ventures/gilded-art-works.

   DRY-RUN BY DEFAULT: renders in-memory and reports size/pages
   but writes NOTHING. Pass --out <file.pdf> to actually write.

   Usage:
     node render.mjs --type invoice --data payload.json \
       --venture ~/GILDED-EDGE-ECOSYSTEM/ventures/lumier-studios/app \
       [--brand gilded|lumier|artworks] [--out invoice.pdf]

   With no --venture, it auto-probes a few known ventures.
   ═══════════════════════════════════════════════════════════ */

import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { makeKit } from '../templates/document-kit.mjs';

const args = parseArgs(process.argv.slice(2));
if (args.help || !args.type) {
  console.log(`crm-document-generator · render.mjs
  --type     invoice | quote | proposal | contract | coa   (required)
  --data     path to JSON payload (default: stdin, else built-in sample)
  --venture  path to a venture that has @react-pdf/renderer installed
  --brand    gilded (default) | lumier | artworks
  --out      write PDF here (omit = DRY-RUN, nothing written)`);
  process.exit(args.type ? 0 : 1);
}

const TYPES = { invoice: 'InvoiceDocument', quote: 'QuoteDocument', proposal: 'ProposalDocument', contract: 'ContractDocument', coa: 'CoaDocument' };
const builder = TYPES[args.type];
if (!builder) { console.error(`✗ unknown --type "${args.type}". Valid: ${Object.keys(TYPES).join(', ')}`); process.exit(1); }

// ── Resolve React + @react-pdf/renderer from a venture ───────
const CANDIDATES = [
  args.venture,
  path.join(os.homedir(), 'GILDED-EDGE-ECOSYSTEM/ventures/lumier-studios/app'),
  path.join(os.homedir(), 'GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works'),
  path.join(os.homedir(), 'GILDED-EDGE-ECOSYSTEM/ventures/gildedge-portal'),
].filter(Boolean);

let ReactPDF, React, usedVenture;
for (const v of CANDIDATES) {
  try {
    const req = createRequire(path.join(v, 'package.json'));
    const pdfPath = req.resolve('@react-pdf/renderer');
    const reactPath = req.resolve('react');
    ReactPDF = await import(pathToFileURL(pdfPath).href);
    React = (await import(pathToFileURL(reactPath).href)).default;
    usedVenture = v;
    break;
  } catch { /* try next */ }
}
if (!ReactPDF || !React) {
  console.error('✗ Could not resolve @react-pdf/renderer + react from any venture.');
  console.error('  Pass --venture <path to a venture with it installed>, e.g.');
  console.error('  --venture ~/GILDED-EDGE-ECOSYSTEM/ventures/lumier-studios/app');
  console.error('  (install with: npm i @react-pdf/renderer  inside that venture)');
  process.exit(2);
}
// @react-pdf exposes renderToBuffer either at top level or under .default
const renderToBuffer = ReactPDF.renderToBuffer || (ReactPDF.default && ReactPDF.default.renderToBuffer);
if (!renderToBuffer) { console.error('✗ renderToBuffer not found on @react-pdf/renderer export'); process.exit(2); }

// ── Payload ──────────────────────────────────────────────────
let payload;
if (args.data) {
  payload = JSON.parse(readFileSync(args.data, 'utf8'));
} else {
  let stdinData = '';
  try { if (!process.stdin.isTTY) stdinData = readFileSync(0, 'utf8'); } catch { /* no stdin */ }
  if (stdinData.trim()) {
    payload = JSON.parse(stdinData);
  } else {
    payload = sampleFor(args.type);
    console.log('ℹ no --data / stdin — using built-in sample payload');
  }
}

// ── Render ───────────────────────────────────────────────────
const kit = makeKit({ React, ReactPDF: ReactPDF.default || ReactPDF, brand: args.brand || payload.brand || 'gilded' });
const element = kit[builder](payload);

const buf = await renderToBuffer(element);

console.log(`✓ rendered ${args.type} · brand=${args.brand || payload.brand || 'gilded'} · ${(buf.length / 1024).toFixed(1)} KB`);
console.log(`  renderer resolved from: ${usedVenture}`);

if (args.out) {
  writeFileSync(args.out, buf);
  console.log(`✓ wrote ${args.out}`);
} else {
  console.log('DRY-RUN: nothing written. Re-run with --out <file.pdf> to save.');
}

// ── helpers ──────────────────────────────────────────────────
function parseArgs(argv) {
  const a = {};
  for (let i = 0; i < argv.length; i++) {
    const t = argv[i];
    if (t === '--help' || t === '-h') a.help = true;
    else if (t.startsWith('--')) { a[t.slice(2)] = (argv[i + 1] && !argv[i + 1].startsWith('--')) ? argv[++i] : true; }
  }
  return a;
}

function sampleFor(type) {
  const S = {
    invoice: {
      org: { name: 'LUMIER STUDIOS', tagline: 'Cinematic Storytelling & Brand Film', email: 'studio@lumierstudios.com', site: 'lumierstudios.com' },
      number: 'INV-0042', status: 'sent', currency: 'USD', created_at: '2026-07-14', due_at: '2026-08-14',
      client: { full_name: 'Ava Sinclair', company: 'Sinclair & Co.', email: 'ava@sinclair.co', phone: '+1 (310) 555-0182' },
      line_items: [
        { description: 'Cinematic Brand Film — 90s hero cut', qty: 1, unit_price: 18000 },
        { description: 'Social cutdowns (6 × 15s)', qty: 6, unit_price: 750 },
      ],
      tax_rate: 0.0725,
    },
    coa: {
      org: { name: 'GILDED ARTWORKS', tagline: 'Fine Art Gallery', email: 'registry@gildedartworks.com' },
      brand: 'artworks', number: 'COA-2026-0007', created_at: '2026-07-14',
      artwork: { title: 'Meridian No. 3', artist: 'D. Montero', year: '2025', medium: 'Oil on linen', dimensions: '120 × 90 cm', price: 42000 },
      signatory: 'Daniel Montero',
    },
  };
  return S[type] || S.invoice;
}
