# Gilded presets — house style + ready world recipes

Gilded addition (GILDED-CHANGES.md). The ecosystem design language (CLAUDE.md:
obsidian black + gold #D4AF37 + white, glassmorphism, cinematic luxury) translated
into scroll-world terms, plus four venture-ready world recipes. Everything here plugs
into the standard interview (SKILL Step 1) — these are defaults to propose, not
overrides; the user still edits the journey and approves the anchor and the spend.

## The Gilded house palette

| Name | Hex | Role |
|---|---|---|
| obsidian | `#0A0A0B` | scene + page background (`--sw-bg`) |
| onyx | `#141416` | secondary surfaces in-scene |
| gold | `#D4AF37` | primary accent (`--sw-accent`), light motif |
| champagne | `#E9D9A8` | soft gold, secondary glow |
| ivory | `#F7F4EC` | text (`--sw-ink`), highlights |
| smoke | `#8A8578` | muted text (`--sw-ink-soft`) |

Engine theme block (both engines — same variables; see the dark-theme note in
gotchas.md: the copy scrim and title shadow follow `--sw-bg` automatically):

```html
<style>
  :root, .sw-root, .swf-root {
    --sw-bg: #0A0A0B; --sw-ink: #F7F4EC; --sw-ink-soft: #8A8578; --sw-accent: #D4AF37;
    --sw-font-display: Inter, system-ui, sans-serif;
    --sw-font-body: Inter, system-ui, sans-serif;
  }
</style>
```

## The Gilded house preamble (photoreal luxury — the default for these ventures)

This is the "photoreal architectural" direction from prompts.md, tuned to the house
language. Full-bleed scenes (no floating islands, skip knockout/Step 3), architecture
**A** (continuous forward take — grounded luxury reads wrong with arch-B pull-outs),
cohesion from the byte-identical preamble. Reuse verbatim in every scene prompt:

```
Ultra-photorealistic cinematic photography, dark obsidian-black environment (#0A0A0B)
with deep soft shadows, warm gold accent lighting (#D4AF37) tracing edges, thin
luminous gold detail lines, glass and polished dark stone surfaces with subtle
reflections and gentle volumetric haze, cinematic luxury, editorial magazine quality,
anamorphic, shallow depth of field, no people, absolutely no text, no letters, no
numbers, no logos.
```

Honest warnings that come with this direction (from gotchas.md): photoreal interiors
are the NSFW-false-positive hot zone — budget the re-roll buffer, keep "empty,
unoccupied, architectural" in interior prompts, and don't pass an `--image` reference
between scenes (it clones the same room; the preamble alone carries cohesion).

**Playful variant** (Toutsweet-class brands): the clay-diorama preamble from
prompts.md with the brand's warm palette + a gold accent — dioramas floating on
obsidian read as "jewel-box miniatures" and keep the house feel without the
photoreal filter risk.

## Copy tone

Confident, plain-spoken, short. Eyebrows are uppercase value-prop labels (2–4 words).
Titles state a conviction, not a feature. Bodies are one sentence from the visitor's
side. No "elevate", no "seamless", no "curated" — the visuals carry the luxury; the
words stay direct.

---

## Recipe 1 — lumier-pictures (film production world)

Style: Gilded house preamble. Architecture A. Camera grammar: **steadicam glide
through doorways** + **low lateral track** alongside stage/desk lines (Step 4 table —
real estate/industrial hybrids).

**Lean (4 scenes):** writers-room → soundstage → color-and-edit suite → premiere.
**Showcase (6 scenes):** writers-room → camera department (gear walls, lenses) →
soundstage → color-and-edit suite → mix stage → premiere.

| Scene | Eyebrow | Title | Body starter |
|---|---|---|---|
| writers-room | FROM THE PAGE | Every film starts as a sentence. | A dark table, one lamp, and a script that refuses to stay quiet. |
| camera dept | THE INSTRUMENTS | Glass, steel, intent. | Every lens on this wall was chosen for a shot that doesn't exist yet. |
| soundstage | ON THE DAY | Where the world gets built. | Sets rise, light bends, and the page becomes a place. |
| color/edit | THE POLISH | Cut by cut, frame by frame. | The story is found twice — once on set, once in this room. |
| mix stage | THE SOUND | You feel it before you hear it. | A room built so silence has weight. |
| premiere | THE PAYOFF | Lights down. Yours up. | Your story, finished, in front of the people it was made for. — CTA |

Accents: gold `#D4AF37` throughout; edit suite may take champagne `#E9D9A8`.
Focal-point notes: soundstage leg tracks low past set builds; color suite is the
half-orbit exception (orbit the grading desk's glow).

## Recipe 2 — gilded-travel-works (luxury city / yacht / jet world)

Style: Gilded house preamble (night-leaning: city lights + gold interiors).
Architecture A. Grammar: **drone rise-and-reveal** into **steadicam glide** (travel
row of the Step 4 table).

**Lean (4 scenes):** private jet cabin → superyacht at a night marina → penthouse
suite → Michelin table.
**Showcase (6 scenes):** skyline arrival (aerial) → private jet cabin → superyacht →
penthouse suite → spa/wellness → Michelin table.

| Scene | Eyebrow | Title | Body starter |
|---|---|---|---|
| skyline arrival | THE APPROACH | The city, before it knows you're here. | Gold lights below, a quiet cabin above. |
| jet cabin | WHEELS UP | Time zones, on your terms. | The schedule bends to you from the moment the door closes. |
| superyacht | OPEN WATER | The address is: the sea. | Crewed, provisioned, pointed wherever you say. |
| penthouse | THE KEYS | Fifty floors of quiet. | Checked in before you land; unpacked before you ask. |
| spa | THE RESET | Do absolutely nothing, perfectly. | Two hours where nobody needs you. |
| michelin table | THE TABLE | Booked-out means nothing to us. | The chef knows you're coming. — CTA |

NSFW warning zone: spa/pool/suite scenes are exactly the false-positive contexts
gotchas.md lists — write them "empty, unoccupied, architectural" and budget re-rolls.

## Recipe 3 — Toutsweet (Peruvian bakery world)

Style: **playful variant** — clay diorama preamble (prompts.md default) with palette:
cream `#F5EDE0` scene background, dulce caramel `#C88A5A`, Peruvian coral `#E2725B`,
pistachio `#9CAF88`, gold `#D4AF37` as CTA/accent. Architecture **B is allowed** here
(miniature world — dives + aerial connectors read as intended). Grammar: **push-in +
ease back** on the craft moments (food row of the Step 4 table).

**Lean (4 scenes):** Lima bakery façade at dawn → oven room (alfajores baking) →
counter and pastry case → hero alfajor finale.
**Showcase (6 scenes):** ingredient market (lucuma, cacao, limes) → Lima bakery
façade → oven room → counter and pastry case → café terrace → hero alfajor finale.

| Scene | Eyebrow | Title | Body starter |
|---|---|---|---|
| market | FROM PERU, WITH BUTTER | It starts at the market. | Lucuma, cacao, and dulce de leche worth the trip. |
| façade | THE CORNER SHOP | Follow the smell of caramel. | Doors open at dawn; the ovens never really stopped. |
| oven room | THE CRAFT | Two cookies, one impossible filling. | Dulce de leche, cooked slow until it behaves. |
| counter | THE CASE | Pick one. (You won't.) | Alfajores, tres leches, and things we refuse to translate. |
| terrace | THE PAUSE | Coffee, sun, crumbs. | Stay twenty minutes longer than you planned. |
| hero alfajor | THE ONE | The alfajor that started it all. | Order by the box — they don't survive the drive home. — CTA |

Finale still: single oversized alfajor centerpiece per the prompts.md hero-product
tip.

## Recipe 4 — gilded-art-works (gallery / fine-art logistics world)

Style: Gilded house preamble. Architecture A. Grammar: **slow half-orbit** around
the hero artwork, steadicam between rooms (product/luxury row of the Step 4 table).

**Lean (4 scenes):** gallery hall → conservation studio → crating & logistics bay →
collector's wall (hero artwork).
**Showcase (6 scenes):** gallery hall → conservation studio → documentation room
(provenance, certificates) → crating & logistics bay → climate vault → collector's
wall.

| Scene | Eyebrow | Title | Body starter |
|---|---|---|---|
| gallery hall | THE WORK | Art deserves an entourage. | From this wall to yours, nothing is left to luck. |
| conservation | THE CARE | Centuries old. Handled like tomorrow matters. | Examined, stabilized, documented — before it moves an inch. |
| documentation | THE PAPER TRAIL | Provenance, in writing. | Every certificate, condition report, and customs form — museum-grade. |
| crating | THE JOURNEY | Built around the artwork, not the box. | Custom crates, climate control, and a chain of custody with no gaps. |
| vault | THE WAIT | Stored like it's still on display. | Light, humidity, and access — all on the ledger. |
| collector's wall | THE ARRIVAL | Home, hung, insured. | White-glove to the wall, paperwork in your hand. — CTA |

Ties into the venture: the documentation scene's copy can mirror the real Provenance
OS document types (brochures, customs, certificates).

---

## Using a recipe

1. Confirm the venture + variant (lean/showcase) with the user — recipes are starting
   points; the journey is still theirs to edit (SKILL Step 1.5).
2. Budget tier still gets asked first, mobile tier still gets asked, and the spend
   estimate still closes the interview. A recipe never skips a gate.
3. Anchor scene suggestions: lumier → soundstage; travel → penthouse; Toutsweet →
   oven room; art-works → gallery hall (the most style-defining scene of each).
