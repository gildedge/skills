#!/usr/bin/env node
/**
 * validate-itinerary.mjs — validate a composed itinerary against BOTH the
 * gilded-travel-works data-validation rules AND the existence of every
 * referenced entity in src/data/. READ-ONLY.
 *
 * Usage:
 *   node validate-itinerary.mjs path/to/itinerary.json
 *
 * GILDED_ROOT env overrides the ecosystem root (default ~/GILDED-EDGE-ECOSYSTEM).
 * Exit code 0 = pass, 1 = validation failures, 2 = usage/read error.
 * No dependencies beyond Node builtins.
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const ROOT = process.env.GILDED_ROOT || path.join(os.homedir(), 'GILDED-EDGE-ECOSYSTEM');
const DATA = path.join(ROOT, 'ventures', 'gilded-travel-works', 'src', 'data');

const file = process.argv[2];
if (!file) { console.error('Usage: validate-itinerary.mjs <itinerary.json>'); process.exit(2); }

let itin;
try { itin = JSON.parse(fs.readFileSync(file, 'utf8')); }
catch (e) { console.error(`ERROR reading ${file}: ${e.message}`); process.exit(2); }

// ── build the known-entity index from the data files (regex scan) ──
function readData(name) { try { return fs.readFileSync(path.join(DATA, name), 'utf8'); } catch { return ''; } }
const cityBlob = ['cityData.ts', 'cityDataPart2.ts', 'cityDataPart3.ts'].map(readData).join('\n');
const collBlob = readData('collectionData.ts');

const cityIds = new Set([...cityBlob.matchAll(/\bid:\s*'([a-zA-Z][\w-]*)'/g)].map((m) => m[1]));
const names = new Set([...cityBlob.matchAll(/\bname:\s*'([^']+)'/g)].map((m) => m[1]));      // hotels/villas/restaurants/experiences all use name:
const hotelKeys = new Set([...readData('hotelData.ts').matchAll(/'([a-z0-9-]+)':\s*\{/g)].map((m) => m[1]));
const collSlugs = new Set([...collBlob.matchAll(/collectionSlug:\s*'([a-z0-9-]+)'/g)].map((m) => m[1]));

const TIERS = new Set(['explorer', 'voyager', 'patron']);
const PLACEHOLDER = /(placeholder|upload|TODO|FIXME|TBD|lorem ipsum|coming soon|description here)/i;
const sentenceCount = (s) => (s.match(/[.!?](\s|$)/g) || []).length;

const errors = [];
const warns = [];
const err = (where, msg) => errors.push(`✗ ${where}: ${msg}`);
const warn = (where, msg) => warns.push(`! ${where}: ${msg}`);

// ── itinerary-level checks ───────────────────────────────────
if (!itin.slug || !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(itin.slug)) err('itinerary.slug', `not URL-safe: ${JSON.stringify(itin.slug)}`);
if (!itin.cityId) err('itinerary.cityId', 'missing');
else if (!cityIds.has(itin.cityId)) err('itinerary.cityId', `'${itin.cityId}' not found in cityData (known: ${[...cityIds].join(', ')})`);
if (itin.tier && !TIERS.has(itin.tier)) err('itinerary.tier', `invalid tier '${itin.tier}'`);
if (!Array.isArray(itin.days) || itin.days.length === 0) err('itinerary.days', 'must be a non-empty array');

// ── per-day checks ───────────────────────────────────────────
for (const d of itin.days || []) {
  const tag = `day ${d.day ?? '?'}`;
  // data-validation required fields
  if (!d.name || !String(d.name).trim()) err(tag, 'name is empty');
  if (!d.location || !String(d.location).trim()) err(tag, 'location is empty');
  if (!d.image || !String(d.image).trim()) err(tag, 'image is empty');
  else if (PLACEHOLDER.test(d.image)) err(tag, `image looks like a placeholder: ${d.image}`);
  // description quality
  const desc = d.description || '';
  if (desc.length < 50) err(tag, `description under 50 chars (${desc.length})`);
  if (sentenceCount(desc) < 2) err(tag, 'description needs at least 2 sentences');
  if (PLACEHOLDER.test(desc)) err(tag, 'description contains placeholder text');
  // tier
  if (d.tier && !TIERS.has(d.tier)) err(tag, `invalid tier '${d.tier}'`);
  if (d.tier && itin.tier && d.tier !== itin.tier) warn(tag, `day tier '${d.tier}' differs from itinerary tier '${itin.tier}'`);

  // reference existence
  const r = d.references || {};
  if (r.cityId && !cityIds.has(r.cityId)) err(tag, `references.cityId '${r.cityId}' not found`);
  if (r.hotelName && !names.has(r.hotelName) && !hotelKeys.has(r.hotelName)) err(tag, `hotel '${r.hotelName}' not found in cityData names or hotelGalleries keys`);
  for (const n of r.experienceNames || []) if (!names.has(n)) err(tag, `experience '${n}' not found in cityData`);
  for (const n of r.restaurantNames || []) if (!names.has(n)) err(tag, `restaurant '${n}' not found in cityData`);
  if (r.collectionSlug && !collSlugs.has(r.collectionSlug)) err(tag, `collectionSlug '${r.collectionSlug}' not found (known: ${[...collSlugs].join(', ')})`);
}

// ── report ───────────────────────────────────────────────────
console.log(`Validating itinerary: ${itin.slug || file}`);
console.log(`Known cities: ${cityIds.size} | hotelGalleries: ${hotelKeys.size} | collections: ${collSlugs.size} | named entities: ${names.size}\n`);
warns.forEach((w) => console.log(w));
if (errors.length) {
  errors.forEach((e) => console.log(e));
  console.log(`\nFAILED — ${errors.length} error(s).`);
  process.exit(1);
}
console.log(`PASSED — ${(itin.days || []).length} day(s), all references resolve, all data-validation rules met.`);
process.exit(0);
