#!/usr/bin/env node
/**
 * shotlist.mjs — deterministic first-pass coverage + stage blocking.
 * Node stdlib only, no npm deps. Emits ShotListItem[] and BlockingScene[]
 * matching lumier-pictures' ShotList.tsx / BlockingTool.tsx / blockingAI.ts.
 *
 * Usage: node shotlist.mjs <file|-> [--only shots|blocking]
 * Reads screenplay .txt OR scene .json (auto-detected). Prints JSON to stdout.
 */

import { readFileSync } from 'fs';

// ── Controlled vocabularies (verbatim from the components) ────────────
const SHOT_TYPES = ['Wide','Medium','Close-Up','ECU','Over-Shoulder','POV','Aerial','Insert','Two-Shot','Master'];
const LENSES = ['14mm','24mm','35mm','50mm','85mm','100mm','135mm','200mm'];
const ANGLES = ['Eye Level','Low','High','Dutch',"Bird's Eye","Worm's Eye"];
const MOVEMENTS = ['Static','Pan','Tilt','Dolly','Crane','Steadicam','Handheld','Tracking','Jib'];
const ACTOR_COLORS = ['#fb7185','#c084fc','#60a5fa','#34d399','#fbbf24','#f97316','#e879f7','#22d3ee'];

const clampV = (val, list, fallback) => (list.includes(val) ? val : fallback);
const clampXY = (n) => Math.max(3, Math.min(97, Math.round(n)));

// ── Rationale voice (mirrors ShotList.tsx explainShot) ────────────────
const SHOT_WHY = {
  'Wide': 'Opens wide to establish geography and spatial relationships.',
  'Master': 'Master covers the whole scene in one for editorial safety.',
  'Medium': 'Medium balances character emotion with environmental context.',
  'Close-Up': 'Close-up isolates emotion — draws the audience into the inner world.',
  'ECU': 'Extreme close-up magnifies a crucial detail or micro-expression.',
  'Over-Shoulder': 'OTS creates spatial depth and implies the dialogue connection.',
  'POV': "POV forces the audience to experience it through the character's eyes.",
  'Two-Shot': 'Two-shot holds both characters in frame — relationship in one image.',
  'Insert': 'Insert highlights a prop or action detail critical to the story.',
  'Aerial': "Aerial establishes scale and a god's-eye perspective.",
};
const MOVE_WHY = {
  'Static': 'Static frame amplifies tension or composure.',
  'Dolly': 'Dolly draws the viewer in with smooth energy.',
  'Steadicam': 'Steadicam follows the action fluidly and immersively.',
  'Handheld': 'Handheld brings raw, documentary urgency for emotional volatility.',
  'Tracking': 'Tracking moves alongside the subject for kinetic energy.',
};
const ANGLE_WHY = {
  'Low': 'Low angle grants the subject power and dominance.',
  'High': 'High angle implies vulnerability or surveillance.',
  'Dutch': 'Dutch tilt signals psychological instability or unease.',
};

// ── Cue detection ─────────────────────────────────────────────────────
const CONFLICT = /\b(fight|slap|punch|shove|strike|attack|struggle|grab|throw)\b/i;
const MOTION = /\b(run|runs|running|chase|flee|rush|escape|walk|walks|enters?|exits?|crosses?)\b/i;
const MICRO = /\b(tear|tears|eye|eyes|hand|hands|trembl|whisper|breath|blink|clench)\b/i;
const PROP = /\b(gun|knife|letter|phone|photo|glass|ring|key|book|note|watch|bottle|door)\b/i;

const secs = (n) => `0:${String(n).padStart(2,'0')}`;

// ── Parse input ───────────────────────────────────────────────────────
function parseScenes(raw) {
  const text = raw.trim();
  if (text.startsWith('{') || text.startsWith('[')) {
    const j = JSON.parse(text);
    const arr = Array.isArray(j) ? j : (j.scenes || [j]);
    return arr.map((s, i) => ({
      number: s.number ?? i + 1,
      title: s.title || `Scene ${s.number ?? i + 1}`,
      intExt: s.intExt || 'INT',
      location: s.location || '',
      timeOfDay: s.timeOfDay || 'Day',
      characters: (s.characters || []).map(String),
      description: s.description || s.action || s.text || '',
    }));
  }
  // screenplay: split on sluglines
  const lines = text.split(/\r?\n/);
  const scenes = [];
  let cur = null, n = 0;
  const slug = /^\s*(INT|EXT|INT\.\/EXT|I\/E)[\.\s]/i;
  for (const ln of lines) {
    if (slug.test(ln)) {
      if (cur) scenes.push(cur);
      n++;
      const m = ln.match(/^\s*(INT|EXT|INT\.\/EXT|I\/E)[\.\s]+(.*?)(?:\s[-–]\s*(DAY|NIGHT|DAWN|DUSK|MORNING|EVENING).*)?$/i);
      cur = { number: n, title: (m && m[2] ? m[2].trim() : `Scene ${n}`).replace(/\.$/,''),
        intExt: /EXT/i.test(ln) ? 'EXT' : 'INT',
        location: m && m[2] ? m[2].trim() : '', timeOfDay: (m && m[3]) ? cap(m[3]) : 'Day',
        characters: [], description: '' };
    } else if (cur) {
      const cm = ln.match(/^CHARACTERS?:\s*(.+)$/i);
      if (cm) { cur.characters = cm[1].split(/[,;]/).map(s => s.trim()).filter(Boolean); continue; }
      cur.description += (cur.description ? ' ' : '') + ln.trim();
      // ALL-CAPS dialogue cue names
      const cue = ln.trim().match(/^([A-Z][A-Z .'\-]{1,28})(\s*\(.*\))?$/);
      if (cue && cue[1].length >= 2 && !slug.test(ln)) {
        const name = cue[1].trim();
        if (!/^(THE|AND|A|INT|EXT|CUT|FADE|CONTINUED|CONT|SMASH)$/.test(name) && !cur.characters.includes(name))
          cur.characters.push(name);
      }
    }
  }
  if (cur) scenes.push(cur);
  return scenes.length ? scenes : [{ number: 1, title: 'Scene 1', intExt: 'INT', location: '', timeOfDay: 'Day', characters: [], description: text }];
}
const cap = (s) => s ? s[0].toUpperCase() + s.slice(1).toLowerCase() : s;

// ── Coverage: build ShotListItem[] for one scene ──────────────────────
function coverScene(scene) {
  const desc = scene.description || '';
  const chars = scene.characters.length ? scene.characters : ['ACTOR 1', 'ACTOR 2'];
  const isConflict = CONFLICT.test(desc);
  const isMotion = MOTION.test(desc);
  const hasMicro = MICRO.test(desc);
  const hasProp = PROP.test(desc);
  const power = /\b(power|dominate|looms|towers|kneel|beg)\b/i.test(desc);

  const shots = [];
  let setupCode = 'A'.charCodeAt(0);
  const push = (o) => {
    const shotType = clampV(o.shotType, SHOT_TYPES, 'Medium');
    const movement = clampV(o.movement, MOVEMENTS, 'Static');
    const angle = clampV(o.angle, ANGLES, 'Eye Level');
    const notes = [SHOT_WHY[shotType], MOVE_WHY[movement], ANGLE_WHY[angle]].filter(Boolean).join(' ');
    shots.push({
      shotNumber: 0, sceneNumber: scene.number,
      setup: String.fromCharCode(setupCode++),
      shotType, lens: clampV(o.lens, LENSES, '50mm'),
      angle, movement, duration: o.duration || secs(6),
      notes: o.notes ? `${o.notes} ${notes}`.trim() : notes,
    });
  };

  // 1. Master / wide establishing
  push({ shotType: 'Wide', lens: '24mm', angle: power ? 'Low' : 'Eye Level',
    movement: isMotion ? 'Dolly' : 'Static', duration: secs(8),
    notes: `Establish ${scene.intExt}. ${scene.location || 'the space'}.` });

  // 2. Two-shot for the primary pair
  if (chars.length >= 2) push({ shotType: 'Two-Shot', lens: '35mm', angle: 'Eye Level', movement: 'Static', duration: secs(6) });

  // 3. Medium per speaking character
  chars.slice(0, 4).forEach((c) => push({ shotType: 'Medium', lens: '50mm', angle: 'Eye Level',
    movement: isMotion ? 'Steadicam' : 'Static', duration: secs(5), notes: `Coverage on ${c}.` }));

  // 4. Reciprocal OTS
  if (chars.length >= 2) {
    push({ shotType: 'Over-Shoulder', lens: '85mm', angle: 'Eye Level', movement: 'Static', duration: secs(5), notes: `OTS favoring ${chars[0]}.` });
    push({ shotType: 'Over-Shoulder', lens: '85mm', angle: 'Eye Level', movement: 'Static', duration: secs(5), notes: `OTS favoring ${chars[1]}.` });
  }

  // 5. Close-ups on the peak (Dutch accent when conflict)
  chars.slice(0, 4).forEach((c) => push({
    shotType: hasMicro ? 'ECU' : 'Close-Up', lens: hasMicro ? '100mm' : '85mm',
    angle: isConflict ? 'Dutch' : 'Eye Level',
    movement: isMotion ? 'Handheld' : 'Static', duration: secs(4), notes: `CU on ${c}.` }));

  // 6. Insert on a named prop
  if (hasProp) push({ shotType: 'Insert', lens: '100mm', angle: 'High', movement: 'Static', duration: secs(3), notes: 'Insert on the key object.' });

  // renumber sequentially across the scene
  shots.forEach((s, i) => { s.shotNumber = i + 1; });
  return shots;
}

// ── Blocking: BlockingScene with ActorMark[] ──────────────────────────
function blockScene(scene) {
  const chars = scene.characters.length ? scene.characters : ['ACTOR 1', 'ACTOR 2'];
  const marks = [];
  let mi = 0;
  const add = (name, x, y, beat, cueNote) => {
    marks.push({ id: `m${scene.number}-${++mi}`, actorName: name,
      color: ACTOR_COLORS[(mi - 1) % ACTOR_COLORS.length],
      x: clampXY(x), y: clampXY(y), cueNote, beat: clampV(beat, ['entrance','cross','center','exit','kneel','fight','dance','custom'], 'custom') });
  };
  // entrances from alternating wings (x near 8 / 92), downstage-ish
  chars.forEach((c, i) => {
    const fromRight = i % 2 === 0;
    add(c, fromRight ? 8 : 92, 78 - i * 6, 'entrance', fromRight ? 'enters DSR' : 'enters DSL');
  });
  // a center confrontation/meeting for the primary pair (distance = emotion)
  if (chars.length >= 2) {
    const isConflict = CONFLICT.test(scene.description || '');
    add(chars[0], 42, isConflict ? 60 : 50, isConflict ? 'fight' : 'center', 'holds the line');
    add(chars[1], 58, isConflict ? 60 : 50, isConflict ? 'fight' : 'cross', 'closes the gap');
  }
  return {
    id: `block-${scene.number}`, sceneNumber: scene.number,
    title: scene.title,
    stageNotes: `${scene.intExt} ${scene.location || ''} — ${scene.timeOfDay}. ${chars.length} on stage. Wing entrances → center → exits.`.trim(),
    marks,
  };
}

// ── Main ──────────────────────────────────────────────────────────────
function main() {
  const args = process.argv.slice(2);
  const only = (args.includes('--only')) ? args[args.indexOf('--only') + 1] : 'both';
  const fileArg = args.find(a => a !== '--only' && a !== only && !a.startsWith('--'));

  let raw = '';
  if (!fileArg || fileArg === '-') {
    raw = readFileSync(0, 'utf8');
  } else {
    raw = readFileSync(fileArg, 'utf8');
  }

  const scenes = parseScenes(raw);
  const out = {};
  if (only !== 'blocking') out.shotList = scenes.flatMap(coverScene);
  if (only !== 'shots') out.blocking = scenes.map(blockScene);
  out._meta = { scenes: scenes.length,
    shots: out.shotList ? out.shotList.length : undefined,
    engine: 'deterministic-firstpass', note: 'Upgrade with in-app generateShotList/generateBlocking (Gemini).' };
  process.stdout.write(JSON.stringify(out, null, 2) + '\n');
}
main();
