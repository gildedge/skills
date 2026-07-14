#!/usr/bin/env node
/**
 * run-eval.mjs — golden-case runner + CI gate. Zero deps (Node >= 18).
 *
 *   node run-eval.mjs [--dir cases] [--array-key id] [--verbose]
 *
 * Loads every *.input.* / *.expected.json pair in cases/, runs callFeature()
 * on the input, scores against expected, prints a table, and EXITS NON-ZERO if
 * any case fails the gate (so CI catches regressions).
 *
 * Wire callFeature() to the venture's real proxy/route — never embed an API key.
 */
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { scoreObject, scoreArray, gate } from './score.mjs';

const args = process.argv.slice(2);
const opt = (flag, def) => {
  const i = args.indexOf(flag);
  return i >= 0 ? args[i + 1] : def;
};
const DIR = opt('--dir', 'cases');
const ARRAY_KEY = opt('--array-key', null); // e.g. "id" for form-works fields[]
const VERBOSE = args.includes('--verbose');

/**
 * TODO: replace this stub with the venture's real call.
 * Next.js route:   POST http://localhost:3000/api/analyze (multipart/JSON)
 * Vite proxy:      POST /api/gemini
 * Supabase:        supabase.functions.invoke('gemini-proxy', ...)
 * MUST return the parsed object the feature produces. Use temperature: 0.
 */
async function callFeature(input) {
  throw new Error(
    'callFeature() is a stub — wire it to the venture proxy/route before running.',
  );
  // Example (Next.js route returning { fields: [...] }):
  // const res = await fetch(process.env.EVAL_URL ?? 'http://localhost:3000/api/analyze', {
  //   method: 'POST', headers: { 'content-type': 'application/json' },
  //   body: JSON.stringify(input) });
  // return res.json();
}

function loadCases(dir) {
  const files = readdirSync(dir);
  const bases = new Set(
    files
      .filter((f) => f.includes('.expected.json'))
      .map((f) => f.replace('.expected.json', '')),
  );
  return [...bases].sort().map((base) => {
    const inputFile = files.find((f) => f.startsWith(base + '.input.'));
    if (!inputFile) throw new Error(`case ${base} has no .input.* file`);
    const rawIn = readFileSync(join(dir, inputFile), 'utf8');
    const input = inputFile.endsWith('.json') ? JSON.parse(rawIn) : rawIn;
    const expected = JSON.parse(readFileSync(join(dir, base + '.expected.json'), 'utf8'));
    return { name: base, input, expected };
  });
}

function scoreCase(expected, actual) {
  if (ARRAY_KEY) {
    // expected/actual may wrap the array, e.g. { fields: [...] }; unwrap common shapes.
    const pick = (o) => (Array.isArray(o) ? o : o.fields ?? o.items ?? o.data ?? []);
    return scoreArray(pick(expected), pick(actual), ARRAY_KEY);
  }
  return scoreObject(expected, actual);
}

async function main() {
  const cases = loadCases(DIR);
  let failed = 0;
  console.log(`\nprompt-eval-harness — ${cases.length} case(s) in ${DIR}\n`);
  for (const c of cases) {
    let score, g;
    try {
      const actual = await callFeature(c.input);
      score = scoreCase(c.expected, actual);
      g = gate(score);
    } catch (err) {
      score = { completeness: 0, accuracy: 0 };
      g = { pass: false, reasons: [`error: ${err.message}`] };
    }
    if (!g.pass) failed++;
    const tag = g.pass ? 'PASS' : 'FAIL';
    console.log(
      `[${tag}] ${c.name}  completeness=${score.completeness.toFixed(2)} accuracy=${score.accuracy.toFixed(2)}` +
        (g.pass ? '' : `  <- ${g.reasons.join('; ')}`),
    );
    if (VERBOSE && score.misses?.length) console.log('       misses:', JSON.stringify(score.misses));
  }
  console.log(`\n${cases.length - failed}/${cases.length} passed.\n`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(2);
});
