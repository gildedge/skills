#!/usr/bin/env node
/**
 * costs-report.mjs — Toutsweet COGS / margin / price-suggestion report.
 *
 * READ-ONLY by default. Mirrors ventures/Toutsweet/platform/src/lib/cost-engine.ts
 * exactly (all money in integer cents — never floated). Applies a batch of
 * ingredient cost updates to a catalog snapshot and recomputes the analysis.
 *
 * Usage:
 *   node costs-report.mjs --catalog catalog.json [--updates cost-updates.json]
 *                         [--json] [--cost-report] [--emit-sql]
 *
 * --catalog       products[] each: {id,name,category,price_cents,target_margin_pct,ingredients:[{id,name,unit,current_cost_cents,quantity}]}
 * --updates       [{ingredient|ingredient_id, new_cost_cents|new_cost_dollars}]
 * --json          print analyzeProducts-shaped JSON (engine key names)
 * --cost-report   print a cost_reports-row-shaped JSON (Reports-page key names)
 * --emit-sql      print UPDATE statements for changed ingredients (dry-run; not executed)
 *
 * GILDED_ROOT env overrides the ecosystem root (default ~/GILDED-EDGE-ECOSYSTEM).
 * No dependencies beyond Node builtins.
 */
import fs from 'node:fs';

// ── arg parsing ──────────────────────────────────────────────
const args = process.argv.slice(2);
function opt(name) {
  const i = args.indexOf(name);
  return i >= 0 ? (args[i + 1] && !args[i + 1].startsWith('--') ? args[i + 1] : true) : undefined;
}
const catalogPath = opt('--catalog');
const updatesPath = opt('--updates');
const wantJson = args.includes('--json');
const wantCostReport = args.includes('--cost-report');
const wantSql = args.includes('--emit-sql');

if (!catalogPath || catalogPath === true) {
  console.error('ERROR: --catalog <path> is required. See --help in the SKILL.md.');
  process.exit(2);
}

// ── model (verbatim mirror of cost-engine.ts) ────────────────
const calculateProductCOGS = (ings) =>
  ings.reduce((t, i) => t + Math.round((i.quantity || 0) * (i.current_cost_cents || 0)), 0);

const calculateMargin = (price, cogs) =>
  price === 0 ? 0 : Math.round(((price - cogs) / price) * 10000) / 100;

const suggestPrice = (cogs, targetPct) =>
  Math.ceil(cogs / (1 - targetPct / 100) / 50) * 50; // round up to nearest 50¢

const formatCents = (c) => `$${(c / 100).toFixed(2)}`;

const calculateCostChange = (cur, prev) => {
  const changeCents = cur - prev;
  const changePct = prev > 0 ? Math.round(((cur - prev) / prev) * 10000) / 100 : 0;
  return { changeCents, changePct, direction: changeCents > 0 ? 'up' : changeCents < 0 ? 'down' : 'stable' };
};

// ── load inputs ──────────────────────────────────────────────
const readJson = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));
let catalog = readJson(catalogPath);
if (!Array.isArray(catalog)) {
  // tolerate the API response shape { products: [...] } if handed directly
  catalog = catalog.products || [];
}
const updates = updatesPath && updatesPath !== true ? readJson(updatesPath) : [];

// normalize + validate updates to integer cents (never float money)
const normUpdates = updates.map((u, idx) => {
  let cents;
  if (u.new_cost_cents != null) cents = u.new_cost_cents;
  else if (u.new_cost_dollars != null) cents = Math.round(u.new_cost_dollars * 100);
  else throw new Error(`update[${idx}] missing new_cost_cents/new_cost_dollars`);
  if (!Number.isInteger(cents)) throw new Error(`update[${idx}] new_cost_cents must be an integer (cents): got ${cents}`);
  return { id: u.ingredient_id, name: u.ingredient, cents };
});

// ── apply updates, tracking the before/after for each ingredient ──
const priceChanges = []; // {id,name,prev,next,...calculateCostChange}
const matchUpdate = (ing) =>
  normUpdates.find((u) =>
    (u.id && ing.id && u.id === ing.id) ||
    (u.name && ing.name && u.name.toLowerCase() === ing.name.toLowerCase()));

const applied = new Set();
for (const p of catalog) {
  for (const ing of p.ingredients || []) {
    const u = matchUpdate(ing);
    if (u && ing.current_cost_cents !== u.cents) {
      const key = ing.id || ing.name;
      if (!applied.has(key)) {
        priceChanges.push({ id: ing.id, name: ing.name, prev: ing.current_cost_cents, next: u.cents, ...calculateCostChange(u.cents, ing.current_cost_cents) });
        applied.add(key);
      }
      ing.current_cost_cents = u.cents;
    }
  }
}
const unmatched = normUpdates.filter((u) => !catalog.some((p) => (p.ingredients || []).some((i) => (u.id && i.id === u.id) || (u.name && i.name && i.name.toLowerCase() === u.name.toLowerCase()))));

// ── analyze (mirror analyzeProducts) ─────────────────────────
const products = [];
const suggestions = [];
for (const p of catalog) {
  const cogs = calculateProductCOGS(p.ingredients || []);
  const price = p.price_cents;
  const target = p.target_margin_pct || 60;
  const margin = calculateMargin(price, cogs);
  const below = margin < target;
  products.push({ product_id: p.id, product_name: p.name, category: p.category, selling_price_cents: price, cogs_cents: cogs, margin_pct: margin, target_margin_pct: target, is_below_target: below });
  if (below) {
    const suggested = suggestPrice(cogs, target);
    const increase = suggested - price;
    suggestions.push({
      product_id: p.id, product_name: p.name,
      current_price_cents: price, suggested_price_cents: suggested,
      current_margin_pct: margin, target_margin_pct: target,
      reason: `Margin is ${margin.toFixed(1)}% (target: ${target}%). COGS is ${formatCents(cogs)}. ` +
              `Suggest increasing price by ${formatCents(increase)} from ${formatCents(price)} to ${formatCents(suggested)}.`,
    });
  }
}
const averageMargin = products.length ? Math.round((products.reduce((s, r) => s + r.margin_pct, 0) / products.length) * 100) / 100 : 0;
const totalRevenuePotential = products.reduce((s, r) => s + r.selling_price_cents, 0);
const totalCogs = products.reduce((s, r) => s + r.cogs_cents, 0);
const analysis = { products, suggestions, totalRevenuePotential, averageMargin, alertCount: suggestions.length };

// ── output ───────────────────────────────────────────────────
if (wantJson) { console.log(JSON.stringify(analysis, null, 2)); process.exit(0); }

if (wantCostReport) {
  // cost_reports row shape — price_suggestions uses the Reports-PAGE keys.
  const today = new Date().toISOString().slice(0, 10);
  const row = {
    week_start: today, week_end: today,
    total_revenue_cents: totalRevenuePotential,
    total_cogs_cents: totalCogs,
    price_suggestions: suggestions.map((s) => ({
      product_name: s.product_name,
      current_cents: s.current_price_cents,   // NOTE: Reports page reads *_cents (not *_price_cents)
      suggested_cents: s.suggested_price_cents,
      reason: s.reason,
    })),
  };
  console.log(JSON.stringify(row, null, 2));
  process.exit(0);
}

if (wantSql) {
  if (!priceChanges.length) { console.log('-- no ingredient cost changes to apply'); process.exit(0); }
  console.log('-- DRY RUN: review before running. Triggers ingredient_price_history auto-log.');
  for (const c of priceChanges) {
    if (c.id) console.log(`UPDATE public.ingredients SET current_cost_cents=${c.next} WHERE id='${c.id}'; -- ${c.name}: ${formatCents(c.prev)} -> ${formatCents(c.next)}`);
    else console.log(`UPDATE public.ingredients SET current_cost_cents=${c.next} WHERE lower(name)=lower('${(c.name || '').replace(/'/g, "''")}'); -- ${formatCents(c.prev)} -> ${formatCents(c.next)}`);
  }
  process.exit(0);
}

// default: human-readable markdown report
const L = [];
L.push('# Toutsweet Cost Report (dry-run)\n');
if (priceChanges.length) {
  L.push('## Ingredient cost changes');
  for (const c of priceChanges) {
    const arrow = c.direction === 'up' ? '▲' : c.direction === 'down' ? '▼' : '•';
    L.push(`- ${arrow} ${c.name}: ${formatCents(c.prev)} → ${formatCents(c.next)} (${c.changePct > 0 ? '+' : ''}${c.changePct}%)`);
  }
  L.push('');
}
if (unmatched.length) { L.push('## ⚠ Unmatched updates (no ingredient found)'); unmatched.forEach((u) => L.push(`- ${u.name || u.id}`)); L.push(''); }
L.push('## Products');
L.push('| Product | Category | Price | COGS | Margin | Target | Below? |');
L.push('|---|---|---:|---:|---:|---:|:--:|');
for (const p of products) L.push(`| ${p.product_name} | ${p.category} | ${formatCents(p.selling_price_cents)} | ${formatCents(p.cogs_cents)} | ${p.margin_pct}% | ${p.target_margin_pct}% | ${p.is_below_target ? '🔴' : '✅'} |`);
L.push('');
L.push(`**Average margin:** ${averageMargin}%  |  **Alerts:** ${analysis.alertCount}  |  **Revenue potential:** ${formatCents(totalRevenuePotential)}\n`);
if (suggestions.length) {
  L.push('## Price suggestions');
  for (const s of suggestions) L.push(`- **${s.product_name}** — ${s.reason}`);
}
console.log(L.join('\n'));
