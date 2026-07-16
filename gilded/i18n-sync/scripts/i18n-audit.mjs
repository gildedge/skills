#!/usr/bin/env node
/**
 * i18n-audit.mjs — Toutsweet trilingual + menu-consistency audit. READ-ONLY.
 *
 * Detects EN keys missing from ES/PT (which silently fall back to English),
 * orphan keys, and reconciles the menu across i18n.js / llms.txt / the Supabase
 * products seed.
 *
 * Usage:
 *   node i18n-audit.mjs [--json] [--lang es|pt]
 *
 * GILDED_ROOT env overrides the ecosystem root (default ~/GILDED-EDGE-ECOSYSTEM).
 * No dependencies beyond Node builtins.
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const ROOT = process.env.GILDED_ROOT || path.join(os.homedir(), 'GILDED-EDGE-ECOSYSTEM');
const TS = path.join(ROOT, 'ventures', 'Toutsweet');
const I18N = path.join(TS, 'i18n.js');
const LLMS = path.join(TS, 'llms.txt');
const SEED = path.join(TS, 'platform', 'supabase', 'migrations', '001_initial_schema.sql');

const args = process.argv.slice(2);
const wantJson = args.includes('--json');
const li = args.indexOf('--lang');
const onlyLang = li >= 0 ? args[li + 1] : null;

function read(p) {
  try { return fs.readFileSync(p, 'utf8'); } catch { console.error(`WARN: cannot read ${p}`); return ''; }
}

// ── extract per-language key sets from i18n.js ───────────────
// The file is `const translations = { en: {...}, es: {...}, pt: {...} }`.
function extractLangKeys(src, lang) {
  const start = src.indexOf(`${lang}: {`);
  if (start < 0) return [];
  // walk braces from the opening { to its match
  let i = src.indexOf('{', start);
  let depth = 0, end = -1;
  for (let j = i; j < src.length; j++) {
    if (src[j] === '{') depth++;
    else if (src[j] === '}') { depth--; if (depth === 0) { end = j; break; } }
  }
  const block = src.slice(i, end < 0 ? undefined : end);
  const keys = [];
  const re = /['"]([^'"]+)['"]\s*:/g;
  let m;
  while ((m = re.exec(block))) keys.push(m[1]);
  return keys;
}

const i18nSrc = read(I18N);
const en = extractLangKeys(i18nSrc, 'en');
const es = extractLangKeys(i18nSrc, 'es');
const pt = extractLangKeys(i18nSrc, 'pt');
const enSet = new Set(en), esSet = new Set(es), ptSet = new Set(pt);

const missingEs = en.filter((k) => !esSet.has(k));
const missingPt = en.filter((k) => !ptSet.has(k));
const orphanEs = es.filter((k) => !enSet.has(k));
const orphanPt = pt.filter((k) => !enSet.has(k));

// ── menu reconciliation ──────────────────────────────────────
// i18n EN product names
const productNames = en.filter((k) => /^product\.\d+\.name$/.test(k)).map((k) => {
  const re = new RegExp(`['"]${k.replace('.', '\\.')}['"]\\s*:\\s*['"]([^'"]+)['"]`);
  const m = i18nSrc.match(re);
  return m ? m[1] : k;
});

// llms.txt prices + bold menu items
const llms = read(LLMS);
const llmsPrices = [...llms.matchAll(/\$(\d[\d,]*)/g)].map((m) => m[1]);
const llmsItems = [...llms.matchAll(/\*\*([^*]+)\*\*/g)].map((m) => m[1].trim());

// SQL seed products (name + price_cents) — scope to the products INSERT block
// so unrelated CHECK-constraint literals (e.g. role 'customer') aren't captured.
const seed = read(SEED);
const insMatch = seed.match(/insert\s+into\s+public\.products[\s\S]*?;/i);
const seedBlock = insMatch ? insMatch[0] : '';
const seedProducts = [...seedBlock.matchAll(/\('([^']+)',\s*'[a-z0-9-]+',[\s\S]*?'(alfajores|cakes|loaves|special)',\s*(\d+)/g)]
  .map((m) => ({ name: m[1], category: m[2], price_cents: Number(m[3]) }));

const result = {
  translations: {
    en_keys: en.length, es_keys: es.length, pt_keys: pt.length,
    missing_es: missingEs, missing_pt: missingPt,
    orphan_es: orphanEs, orphan_pt: orphanPt,
  },
  menu: {
    i18n_product_names: productNames,
    llms_items: llmsItems,
    llms_prices: llmsPrices.map((p) => `$${p}`),
    seed_products: seedProducts.map((p) => `${p.name} — $${(p.price_cents / 100).toFixed(0)} (${p.category})`),
  },
};

if (wantJson) { console.log(JSON.stringify(result, null, 2)); process.exit(0); }

// human report
const line = (s = '') => console.log(s);
line('# Toutsweet i18n + menu audit\n');
line(`Keys — en: ${en.length}, es: ${es.length}, pt: ${pt.length}\n`);

const show = (label, arr) => {
  line(`## ${label} (${arr.length})`);
  if (!arr.length) line('  ✅ none');
  else arr.forEach((k) => line(`  - ${k}`));
  line('');
};
if (!onlyLang || onlyLang === 'es') show('Missing in ES (falls back to English)', missingEs);
if (!onlyLang || onlyLang === 'pt') show('Missing in PT (falls back to English)', missingPt);
if (!onlyLang || onlyLang === 'es') show('Orphan ES keys (not in EN)', orphanEs);
if (!onlyLang || onlyLang === 'pt') show('Orphan PT keys (not in EN)', orphanPt);

line('## Menu reconciliation (compare the three surfaces)');
line('### i18n.js product names (EN)');
productNames.forEach((n) => line(`  - ${n}`));
line('### llms.txt bold items');
llmsItems.forEach((n) => line(`  - ${n}`));
line(`  prices seen: ${result.menu.llms_prices.join(', ')}`);
line('### Supabase seed products (catalog of record)');
seedProducts.forEach((p) => line(`  - ${p.name} — $${(p.price_cents / 100).toFixed(0)} (${p.category})`));
line('\n⚠ Reconcile any item that appears in one surface but not the others. The SQL seed is often the stalest.');
