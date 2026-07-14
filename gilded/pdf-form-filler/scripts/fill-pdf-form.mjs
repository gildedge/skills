#!/usr/bin/env node
/*
 * fill-pdf-form.mjs — write Gilded Forms interview answers into a PDF AcroForm.
 * The missing output half of gilded-form-works.
 *
 * Modes:
 *   inspect  --pdf f.pdf                     List real AcroForm fields + types (no values).
 *   fill     --pdf f.pdf --interview i.json  Plan the mapping (DRY-RUN by default).
 *            ... --write --out out.pdf        Actually write the filled PDF.
 *            ... --flatten                    Bake values in (removes interactivity).
 *            ... --map map.json               Override answer_id -> AcroForm field name.
 *            ... --analysis a.json --answers x.json   (instead of --interview)
 *
 * Resolves pdf-lib from a venture's node_modules. Never installs anything.
 *   GILDED_ROOT   ecosystem root (default ~/GILDED-EDGE-ECOSYSTEM)
 *   --venture     venture whose node_modules holds pdf-lib (default gilded-form-works)
 *
 * NEVER logs the value of a field flagged sensitive.
 */

import { readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { homedir } from 'node:os';
import path from 'node:path';

// ---- arg parsing (no deps) --------------------------------------------------
const argv = process.argv.slice(2);
const mode = argv[0] && !argv[0].startsWith('--') ? argv.shift() : 'fill';
const opt = {};
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a.startsWith('--')) {
    const key = a.slice(2);
    const next = argv[i + 1];
    if (next === undefined || next.startsWith('--')) opt[key] = true;
    else { opt[key] = next; i++; }
  }
}

const ROOT = process.env.GILDED_ROOT || path.join(homedir(), 'GILDED-EDGE-ECOSYSTEM');
const VENTURE = opt.venture || 'gilded-form-works';

function loadPdfLib() {
  const candidates = [
    path.join(ROOT, 'ventures', VENTURE, 'node_modules', 'pdf-lib'),
    path.join(ROOT, 'ventures', VENTURE, 'package.json'),
  ];
  for (const base of candidates) {
    try {
      const req = createRequire(base.endsWith('.json') ? base : base + '/package.json');
      return req('pdf-lib');
    } catch { /* try next */ }
  }
  // last resort: this skill's own resolution
  try { return createRequire(import.meta.url)('pdf-lib'); } catch {}
  fail(`Could not resolve pdf-lib. Looked under ${path.join(ROOT, 'ventures', VENTURE, 'node_modules')}.\n` +
       `Run this from a venture that has pdf-lib installed, or set --venture / GILDED_ROOT.`);
}

function fail(msg) { console.error('ERROR: ' + msg); process.exit(1); }

const SENSITIVE_RE = /ssn|social.?security|tax.?id|\bein\b|passport|driver.?licen|account.?(number|no)|routing|\bdob\b|date.?of.?birth|card.?number/i;
function isSensitive(field) {
  if (!field) return false;
  if (field.type === 'sensitive') return true;
  return SENSITIVE_RE.test(field.id || '') || SENSITIVE_RE.test(field.fieldLabel || '');
}
function show(field, value) { return isSensitive(field) ? '[sensitive: value hidden]' : JSON.stringify(value); }

const norm = (s) => String(s || '').toLowerCase().replace(/[^a-z0-9]+/g, '');

async function main() {
  if (!opt.pdf) fail('--pdf <file> is required');
  const { PDFDocument } = loadPdfLib();
  const bytes = readFileSync(opt.pdf);
  const doc = await PDFDocument.load(bytes, { updateMetadata: false });
  const form = doc.getForm();
  const pdfFields = form.getFields();

  if (mode === 'inspect') {
    if (pdfFields.length === 0) {
      console.log('No AcroForm fields found. This PDF is flat (image/print layout) — it must be filled by');
      console.log('overlay text placement (drawText at page coords), not by field name.');
      return;
    }
    console.log(`AcroForm fields in ${path.basename(opt.pdf)} (${pdfFields.length}):\n`);
    for (const f of pdfFields) {
      const kind = f.constructor.name.replace(/^PDF/, '');
      let extra = '';
      try {
        if (typeof f.getOptions === 'function') extra = '  options=' + JSON.stringify(f.getOptions());
      } catch {}
      console.log(`  ${f.getName()}  [${kind}]${extra}`);
    }
    return;
  }

  // ---- fill mode ----
  const { fields, answers } = loadInterview();
  const byId = new Map(fields.map((f) => [f.id, f]));
  const override = opt.map ? JSON.parse(readFileSync(opt.map, 'utf8')) : {};

  if (pdfFields.length === 0) {
    console.log('WARNING: no AcroForm fields in this PDF. Nothing can be filled by field name.');
    console.log('This form needs overlay text placement using each field.pageNumber. Aborting.');
    return;
  }

  // index real fields for matching
  const realByName = new Map(pdfFields.map((f) => [f.getName(), f]));
  const realByNorm = new Map();
  for (const f of pdfFields) realByNorm.set(norm(f.getName()), f);

  const write = !!opt.write;
  const plan = [];
  for (const [answerId, rawVal] of Object.entries(answers)) {
    if (rawVal === undefined || rawVal === null || String(rawVal).trim() === '') continue;
    const meta = byId.get(answerId);
    let target = null;
    let via = '';
    if (override[answerId] && realByName.has(override[answerId])) { target = realByName.get(override[answerId]); via = 'map'; }
    else if (realByName.has(answerId)) { target = realByName.get(answerId); via = 'id'; }
    else if (meta && realByNorm.has(norm(meta.fieldLabel))) { target = realByNorm.get(norm(meta.fieldLabel)); via = 'label'; }
    else if (realByNorm.has(norm(answerId))) { target = realByNorm.get(norm(answerId)); via = 'id~'; }

    if (!target) { plan.push({ answerId, meta, status: 'UNMATCHED', rawVal }); continue; }

    const kind = target.constructor.name.replace(/^PDF/, '');
    let status = 'MATCHED';
    if (write) {
      try { status = applyValue(target, kind, rawVal, meta); }
      catch (e) { status = 'ERROR: ' + e.message; }
    }
    plan.push({ answerId, meta, target: target.getName(), via, kind, status, rawVal });
  }

  // ---- report (value-safe) ----
  console.log(`Mapping plan (${write ? 'WRITE' : 'DRY-RUN'}) — ${plan.length} answered fields\n`);
  for (const p of plan) {
    const label = p.meta ? p.meta.fieldLabel || p.meta.id : p.answerId;
    if (p.status === 'UNMATCHED') {
      console.log(`  [UNMATCHED] ${p.answerId} ("${label}") -> no AcroForm field  value=${show(p.meta, p.rawVal)}`);
    } else {
      console.log(`  [${p.status}] ${p.answerId} -> "${p.target}" (${p.kind}, via ${p.via})  value=${show(p.meta, p.rawVal)}`);
    }
  }
  const unmatched = plan.filter((p) => p.status === 'UNMATCHED').length;
  if (unmatched) console.log(`\n${unmatched} unmatched — supply a --map override file to place them.`);

  if (!write) {
    console.log('\nDry-run only. Re-run with --write --out <file.pdf> to produce the filled PDF.');
    return;
  }

  try { form.updateFieldAppearances(); } catch {}
  if (opt.flatten) form.flatten();
  const out = opt.out || opt.pdf.replace(/\.pdf$/i, '') + '.filled.pdf';
  const outBytes = await doc.save();
  writeFileSync(out, outBytes);
  console.log(`\nWrote ${out}${opt.flatten ? ' (flattened)' : ''}.`);
}

function applyValue(field, kind, value, meta) {
  const v = String(value);
  switch (kind) {
    case 'TextField':
      field.setText(v);
      return 'MATCHED';
    case 'CheckBox': {
      const truthy = /^(y|yes|true|1|on|checked|x)$/i.test(v.trim());
      truthy ? field.check() : field.uncheck();
      return 'MATCHED';
    }
    case 'RadioGroup': {
      const opts = field.getOptions();
      const hit = opts.find((o) => norm(o) === norm(v)) || (opts.includes(v) ? v : null);
      if (!hit) return `MISMATCH: "${isSensitive(meta) ? '***' : v}" not in [${opts.join(', ')}]`;
      field.select(hit);
      return 'MATCHED';
    }
    case 'Dropdown':
    case 'OptionList': {
      const opts = field.getOptions();
      const hit = opts.find((o) => norm(o) === norm(v));
      if (hit) { field.select(hit); return 'MATCHED'; }
      // dropdowns can accept custom text when editable
      try { field.select(v); return 'MATCHED (custom)'; }
      catch { return `MISMATCH: "${isSensitive(meta) ? '***' : v}" not in [${opts.join(', ')}]`; }
    }
    default:
      return `SKIPPED: unsupported widget ${kind}`;
  }
}

function loadInterview() {
  if (opt.interview) {
    const j = JSON.parse(readFileSync(opt.interview, 'utf8'));
    return { fields: j.fields || [], answers: j.answers || {} };
  }
  if (opt.analysis && opt.answers) {
    const a = JSON.parse(readFileSync(opt.analysis, 'utf8'));
    const ans = JSON.parse(readFileSync(opt.answers, 'utf8'));
    return { fields: a.fields || [], answers: ans.answers || ans };
  }
  fail('Provide --interview <file> or (--analysis <file> --answers <file>)');
}

main().catch((e) => fail(e.stack || e.message));
