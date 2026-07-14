---
name: crm-document-generator
description: One-shot branded PDF generator for the Gilded Edge ecosystem — invoice, quote, proposal, contract, and certificate of authenticity (COA) from a client record + line items, using @react-pdf/renderer in the Obsidian-black + gold (#D4AF37) house style. Use whenever someone needs to "generate an invoice/quote/proposal/contract/COA PDF", "make a client document", "bill a client", "send a proposal", "produce a service agreement", or wire a `/api/invoices|contracts|proposals` route in lumier-studios, gilded-art-works, or gildedge-portal. Renders server-side (renderToStream / renderToBuffer), resolves React + @react-pdf from a venture's existing node_modules (nothing new to install), and dry-runs by default.
---

# CRM Document Generator

Turn a client record + line items into a polished, brand-aligned PDF —
**invoice · quote · proposal · contract · COA** — that looks like it came out
of the same design system as the rest of the Gilded Edge ventures.

## When to use

- "Generate an invoice / quote / proposal / contract / certificate of authenticity."
- "Bill this client," "send them a proposal," "draft the service agreement."
- Wiring or fixing a PDF route: `app/api/invoices/[id]/route.ts`,
  `.../contracts/[id]/route.ts`, `.../proposals/[id]/route.ts`.
- Serves **lumier-studios** (`app/`), **gilded-art-works**, and **gildedge-portal**
  — all three already ship `@react-pdf/renderer`.

## Brand tokens (the house style)

Canonical ecosystem palette = **Obsidian black + Gold**. Defined once in
`templates/brand-tokens.mjs`:

| token | value | use |
|-------|-------|-----|
| `OBSIDIAN` | `#0A0A0F` | page background |
| `SURFACE`  | `#13131A` | cards / meta blocks |
| `ACCENT`   | `#D4AF37` | gold — rules, labels, logo |
| `TEXT`     | `#E8E6E0` | body text (warm off-white) |
| `MUTED`    | `#8A8578` | secondary text |
| `SUCCESS`  | `#10B981` | totals / paid / signed |

Per-venture accent overrides via `--brand`:
- `gilded` (default) — gold `#D4AF37`, the ecosystem standard.
- `lumier` — orange `#FF6B35`, matches Lumier Studios CRM's existing dark theme
  (`src/lib/pdf/*-template.tsx`).
- `artworks` — antique gold `#B8996A`, matches Gilded Artworks' HTML docs
  (`src/lib/document-css.ts`).

Font is @react-pdf's built-in `Helvetica` (no font registration / network needed).

## Workflow

1. **Identify the doc type and gather the payload** — a client object plus line
   items (or an amount). Minimal invoice payload:
   ```json
   {
     "org": { "name": "LUMIER STUDIOS", "email": "studio@lumierstudios.com", "site": "lumierstudios.com" },
     "number": "INV-0042", "status": "sent", "currency": "USD",
     "created_at": "2026-07-14", "due_at": "2026-08-14",
     "client": { "full_name": "Ava Sinclair", "company": "Sinclair & Co.", "email": "ava@sinclair.co" },
     "line_items": [
       { "description": "Cinematic Brand Film — 90s hero cut", "qty": 1, "unit_price": 18000 },
       { "description": "Social cutdowns (6 × 15s)", "qty": 6, "unit_price": 750 }
     ],
     "tax_rate": 0.0725
   }
   ```
   Line items accept `{ description, qty, unit_price }` **or** a flat `{ description, amount }`.
   See `assets/sample-proposal.json` for a fuller example.

2. **Dry-run it** (renders in memory, writes nothing):
   ```bash
   node scripts/render.mjs --type invoice --data payload.json
   # or with no data, uses a built-in sample:
   node scripts/render.mjs --type coa --brand artworks
   ```
   Output reports the byte size and which venture's renderer was used.

3. **Write the PDF** only when asked, with `--out`:
   ```bash
   node scripts/render.mjs --type proposal --data payload.json \
     --brand gilded --out ./proposal.pdf
   ```

4. **To ship it inside a venture** (the real integration): import the kit from a
   `.tsx` route the same way the existing templates do — see the pattern below.
   The standalone `render.mjs` is for previews, batch generation, and CI; the
   in-app route uses `renderToStream`.

## Integrating into a Next.js route (the ecosystem pattern)

The ventures render server-side and stream the PDF. This mirrors
`lumier-studios/app/src/app/api/invoices/[invoiceId]/route.ts`:

```ts
import { renderToStream } from '@react-pdf/renderer';
import React from 'react';
// Author a .tsx template OR reuse the kit's builders.
const element = React.createElement(InvoiceDocument, payload);
// @react-pdf has a known React 19 type mismatch — cast to any:
const stream = await renderToStream(element as any);
return new NextResponse(webStream, {
  headers: { 'Content-Type': 'application/pdf',
    'Content-Disposition': `inline; filename="invoice-${num}.pdf"`,
    'Cache-Control': 'no-store' },
});
```

The kit in `templates/document-kit.mjs` is framework-agnostic JS (no JSX) so it
runs under plain `node` for previews. When embedding in a venture you can either
call `makeKit({ React, ReactPDF, brand })` from a server module, or copy a
builder into a `.tsx` template — both produce identical output.

## Files

- `templates/brand-tokens.mjs` — the palette + money/date helpers. Single source of truth.
- `templates/document-kit.mjs` — `makeKit({ React, ReactPDF, brand })` → `{ InvoiceDocument, QuoteDocument, ProposalDocument, ContractDocument, CoaDocument }`. Uses `React.createElement` (no build step).
- `scripts/render.mjs` — CLI. Resolves React + @react-pdf from a venture, renders, dry-runs unless `--out`.
- `assets/sample-proposal.json` — worked example payload.

## Gotchas

- **No new dependencies.** `render.mjs` resolves `react` + `@react-pdf/renderer`
  from a venture's `node_modules` via `createRequire`. If none is found it tells
  you to pass `--venture <path>` (e.g. `ventures/lumier-studios/app`). It never
  runs `npm install`.
- **React 19 type mismatch.** In `.tsx` routes, `renderToStream(element as any)`
  — the ventures all do this and leave the eslint-disable comment. Don't "fix" it.
- **`renderToBuffer` export shape.** Depending on the @react-pdf build it lives at
  the top level or under `.default`; `render.mjs` checks both.
- **Percent fields are fractions.** `tax_rate: 0.0725` = 7.25%, `deposit_pct: 0.5` = 50%.
- **Money is server-formatted** via `Intl.NumberFormat` — pass raw numbers, not
  pre-formatted strings.
- **Contract is 2 pages** and auto-splits its sections; pass `sections: [{title, body}]`
  to override the default legal boilerplate (California / LA arbitration, 50% deposit,
  IP-on-final-payment — matching the existing Lumier contract template).
- **COA** takes `artwork: { title, artist, year, medium, dimensions, price }` (or an
  `artworks: [...]` array — first entry is used) and is meant for Gilded Artworks;
  default `--brand artworks`.
