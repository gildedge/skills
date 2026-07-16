---
name: shot-list-generator
description: Turn a screenplay / scene text into a structured shot list AND a stage-blocking plan that drop straight into lumier-pictures' ShotList and BlockingTool / SceneStudio components. Emits ShotListItem[] (shotNumber, sceneNumber, setup, shotType, lens, angle, movement, duration, notes) and BlockingScene[] with ActorMark[] marks (x/y 0–100), using the EXACT controlled vocabularies the real components ship with. Use whenever someone says "generate a shot list", "break this scene into coverage", "shot list from this script", "block this scene", "make blocking marks / stage positions", "coverage for SceneStudio", "storyboard breakdown", or "how would you shoot this". Produces a deterministic offline first-pass (no API spend) that mirrors lumier's generateShotList / generateBlocking output shape; the live Gemini path (services/ai/blockingAI.ts, services/geminiService.generateShotList) is the runtime upgrade. Dry-run to stdout by default; --run --out writes the JSON.
---

# Shot List Generator

Reads a scene (or a whole multi-scene script) and produces two artifacts that
lumier-pictures already knows how to consume:

- **`shotList`** — `ShotListItem[]` (the shape in `types.ts` line 1768, rendered
  by `components/ShotList.tsx`).
- **`blocking`** — `BlockingScene[]` with `ActorMark[]` (the shape in
  `components/BlockingTool.tsx`, fed by `services/ai/blockingAI.ts`).

It runs **fully offline and deterministic by default** — a director's-eye
heuristic coverage pass, no Gemini call, no spend — and prints to stdout. Pass
`--run --out <file>` to write. The live AI path
(`geminiService.generateShotList`, `blockingAI.generateBlocking`) is the
in-app upgrade; this skill gives you a correct, immediately-importable
first-pass and a schema you can trust.

## When to use

- "Generate / draft a shot list for this scene or script."
- "Break this into coverage" · "how would you shoot this."
- "Block this scene" · "give me stage marks / actor positions."
- "Coverage JSON for SceneStudio / ShotList / BlockingTool."

## Controlled vocabularies (grounded — do NOT invent values)

These come verbatim from `components/ShotList.tsx` and `components/BlockingTool.tsx`.
Using anything else breaks the inline dropdowns in the UI.

```
SHOT_TYPES = Wide, Medium, Close-Up, ECU, Over-Shoulder, POV, Aerial, Insert, Two-Shot, Master
LENSES     = 14mm, 24mm, 35mm, 50mm, 85mm, 100mm, 135mm, 200mm
ANGLES     = Eye Level, Low, High, Dutch, Bird's Eye, Worm's Eye
MOVEMENTS  = Static, Pan, Tilt, Dolly, Crane, Steadicam, Handheld, Tracking, Jib
BEAT_TYPES = entrance, cross, center, exit, kneel, fight, dance, custom
```

Blocking coordinate convention (from `blockingAI.ts`, top-down stage):
`x: 0 = stage right → 100 = stage left`, `y: 0 = upstage/back →
100 = downstage/front (nearest audience)`. Marks are clamped to 3–97 so no actor
sits on the wall. `ActorMark` also carries `color` (from `ACTOR_COLORS`) and a
`beat` tag from `BEAT_TYPES`.

## Input format

Either raw screenplay text, or a small JSON scene file. Sluglines
(`INT.`/`EXT. LOCATION - TIME`) split scenes; ALL-CAPS tokens and a
`CHARACTERS:` line seed the cast. Minimal JSON:

```jsonc
{
  "scenes": [
    {
      "number": 12,
      "title": "The Confrontation",
      "intExt": "INT",
      "location": "VICTORIAN PARLOR",
      "timeOfDay": "Night",
      "characters": ["ELENA", "MARCUS"],
      "description": "Elena enters. Marcus rises from the chair. They circle each other. She slaps him. He exits."
    }
  ]
}
```

## Quick start

```bash
# stdin or file; screenplay .txt or scene .json — auto-detected
bash scripts/shotlist.sh scene.json
bash scripts/shotlist.sh script.txt --only shots        # shot list only
bash scripts/shotlist.sh script.txt --only blocking     # blocking only
bash scripts/shotlist.sh scene.json --run --out coverage.json   # write both

# pipe a scene straight in
pbpaste | bash scripts/shotlist.sh -
```

`GILDED_ROOT=/path` overrides `~/GILDED-EDGE-ECOSYSTEM` (only used to print the
import target paths in the summary).

## The coverage heuristic (what a first-pass DP would shoot)

Per scene, in order (skips beats that don't apply):

1. **Master / Wide establishing** — `Wide`, wide glass (`24mm`), `Static` or a
   slow `Dolly` push; `Eye Level` (`Low` if the scene reads as a power move).
2. **Two-Shot** for the primary pair — `Two-Shot`, `35mm`, `Static`.
3. **Medium** per speaking character — `Medium`, `50mm`, `Eye Level`.
4. **Over-Shoulder pair** when ≥2 characters — reciprocal `Over-Shoulder`,
   `85mm`.
5. **Close-Up** per character on the emotional peak — `Close-Up`, `85mm`;
   `ECU` + `100mm` if the description hints at a micro-moment (tear, hand, eyes).
6. **Insert** when a prop/object is named — `Insert`, `100mm`, `Static`.
7. Motion escalates with conflict verbs (fight/run/chase → `Handheld` /
   `Steadicam` / `Tracking`; slap/confront → `Dutch` accent CU).

Each shot's `notes` carries the same rationale voice as ShotList.tsx's
`explainShot()` (e.g. "Low angle grants the subject power and dominance.").
`setup` groups shots that share a camera position so the 1st AD can batch them.

Blocking mirrors `blockingAI.ts`: entrances from the wings (x near 3 or 97),
a center confrontation (both near x 50, low y = downstage for intimacy),
and exits back to a wing — every beat moves at least one actor.

## Output shape (paste-ready)

```jsonc
{
  "shotList": [
    { "shotNumber": 1, "sceneNumber": 12, "setup": "A", "shotType": "Wide",
      "lens": "24mm", "angle": "Eye Level", "movement": "Dolly",
      "duration": "0:08", "notes": "Opens wide to establish geography…" }
  ],
  "blocking": [
    { "id": "block-12", "sceneNumber": 12, "title": "The Confrontation",
      "stageNotes": "…",
      "marks": [
        { "id": "m1", "actorName": "ELENA", "color": "#fb7185",
          "x": 8, "y": 85, "cueNote": "enters DSR", "beat": "entrance" }
      ] }
  ]
}
```

`shotList` imports directly where `ShotList.tsx` reads `project.shotList`;
`blocking` maps to `BlockingTool`'s `scenes` prop (`BlockingScene[]`).

## Gotchas

- **Dry-run to stdout is the default.** `--run --out FILE` is the only thing
  that writes.
- **Only the controlled-vocabulary strings are valid.** The script clamps any
  computed value back into the lists above; if you hand-edit, keep them exact
  (`Close-Up` not `Closeup`, `Eye Level` not `eye-level`).
- **Blocking x/y are stage coordinates, not screen pixels** — 0..100, x flipped
  (0 = stage right), and clamped 3–97. Don't feed camera-space coords.
- **This is a first pass, not final coverage.** It won't know a story beat you
  didn't write down. For nuance, run the in-app Gemini path
  (`generateShotList` / `generateBlocking`) — this skill deliberately does NOT
  spend on an API by default.
- **Cast detection is heuristic.** Give a `characters` array (JSON) or a
  `CHARACTERS:` line for reliable names; otherwise it infers ALL-CAPS cue names
  and falls back to 2 generic actors.
- **`duration` is a string** (`"0:08"`, "8s") to match `ShotListItem.duration`,
  not a number.

## Files

- `scripts/shotlist.sh` — thin bash 3.2 wrapper (arg parse, stdin, `--run`).
- `scripts/shotlist.mjs` — the deterministic coverage + blocking engine
  (Node, stdlib only, no npm deps). Emits the exact `ShotListItem[]` /
  `BlockingScene[]` shapes above.
