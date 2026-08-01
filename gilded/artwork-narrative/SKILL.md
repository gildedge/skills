---
name: artwork-narrative
description: Write the words that sell a photograph — wall labels, curatorial notes, lot essays, shop copy, hero lines, collector-email story blocks, and hooks — in Gilded Edge Gallery's register. Applies Hero's-Journey/Pixar story structure and price-tier value levers, and enforces the gallery's two hardest rules — never invent proof (no fabricated statistics, testimonials, EXIF, provenance, or appreciation claims) and never write down to the reader (a $8,500 photograph is not sold at a 7th-grade reading level). Use when someone says "write the artwork description", "wall label", "lot essay", "copy for the shop", "describe this piece", "write the collector email", "we need hooks", "rewrite this listing", "the copy is flat", or is producing any collector-facing prose.
---

# Artwork Narrative

Write the prose around the work: what a collector reads before they decide. Adapted from the storytelling and copy sequences of the Surreal Academy curriculum (Days 10, 14, 17–18), with two of its central instructions inverted because they are wrong for this brand.

## The two inversions — read these first

**1. Reject the Flesch-Kincaid 7th–8th grade target.** The source curriculum applies it to nearly every prompt, on the reasoning that people skim and simple copy converts. That is true of a $40 DTC product. It is false of a $8,500 one-of-one photograph sold to someone who reads auction catalogues for pleasure. Copy written down to a collector reads as a brand that does not know what it is.

Keep the *principle* underneath it — no fog, no throat-clearing, no sentence that exists to sound expensive. Drop the metric. The register to hit is **the wall label and the lot essay**: precise, concrete, unhurried, and completely free of decoration. Short sentences are welcome. Simple *vocabulary* is not the goal; simple *thinking* rendered exactly is.

**2. Reject "clickbait".** The curriculum asks repeatedly for "clickbait and high-converting headlines." A gallery that clickbaits has told a collector exactly how much to trust its provenance claims. Write hooks that are *specific and true* — the specificity is the hook.

## The non-negotiable rule: never invent proof

The source curriculum will ask you to generate 15 testimonials, hooks containing statistics ("art reduces stress by 40%"), and appreciation comparables. **Do none of these.** This gallery's copy has one durable advantage — everything in it is verifiably true — and one fabricated collector quote destroys it permanently.

Never generate:
- **Any donation or cause claim on a PHOTOGRAPH — there is none.** The gallery sells two lines (corrected 2026-07-30): **photography, which carries no pledge and retains full margin**, and **generative works, where 100% of margin goes to ocean conservation**. Never attach the pledge to a photograph, and never import sustainability-of-materials language. If a collector asks why only one line gives, the honest answer is the one to use: *the photography is how the artist makes his living; the machine-made work funds ocean conservation — that line is deliberate.*
- **Testimonials or collector quotes.** Five people own a Montero. None have given a usable public quote. If one does, it is quoted verbatim and attributed as agreed.
- **Statistics.** No "70% of collectors say…", no cortisol percentages. If a real, citable market statistic is needed, take it from the sourced research in `infrastructure/wiki/strategy/instagram-growth-playbook.md` §1 and cite it.
- **EXIF.** Wall labels use real camera metadata extracted from the source files. Two works have stripped metadata and honestly carry **no** technical label. Leaving it blank is the correct output.
- **Provenance, exhibition history, or press.** The real credentials are listed below. There are no others.
- **Appreciation claims.** Describing the edition structure is fine. Projecting that a work will rise in value is a financial claim and is not made.
- **Prices, edition sizes, or dates** that are not in `src/lib/shop.ts` or `src/lib/collection.ts`.

When proof is missing, the output is a flagged gap, not a plausible sentence.

## Ground truth — the real material

Everything below is confirmed and is the entire permitted factual palette.

**The artist.** Daniel Montero. Colombian-born, New York-based. Self-taught. His father handed him his first professional camera at fifteen; he taught himself everything after that. Cites Peter Lik as a direct influence. Shoots a Canon EOS R5 C.

**The credentials.** Five original works sold into private collections, 2020–2024, direct and unrepresented. Art Basel Miami 2025. Represented by **Monat Gallery** (Madrid/Marbella) at the **Marbella Art Fair**, opening 2026-07-30.

> Phrasing, corrected by the artist: the event is the **Marbella Art Fair**; Monat is the **representing gallery**, not the venue. Write "Marbella Art Fair, with Monat" or "represented by Monat." Never "Monat Gallery Marbella" as though it were the show.
>
> This Monat is the contemporary art gallery. It is unrelated to the Monat consulting line, which never appears on this brand under any circumstances.

**The collection.** *First Light* — the inaugural collection, four frames catching the moment darkness gives way to light, shot between Miami, New York, and Rome. Dates: **"Opening soon."** No opening date is announced.

**The Marbella works.** *Eternal Facade* (2020) — St Mark's Square, Venice, **shot during the COVID lockdown, the square completely empty.** *The Silence Between The Tides* (2015) — a boat in fog, **never exhibited in eleven years.** *Midnight Silence* (2023) — frost trees, star field.

**The documented sale.** "Horizon's Symphony," ed. 22, framed 30 × 40, sold November 2023 for $3,050 + $160 shipping to a private New York collector. The sale may be cited. **The buyer is never named.**

## The hard brand constraints

- **It is an online showroom. There is no physical space.** Never write doors opening, gallery hours, an address, an appointment at a location, or a walk-in. Miami appears only as where the artist is based and where work was shot. A private viewing is a one-to-one call with the artist.
- **It shows collections, not exhibitions.** *First Light* is the inaugural **collection**. The route is `/showroom`.
- **Never merge with Gilded Artworks.** Sibling venture, separate brand, no shared voice or nav.
- **Never mention the Monat consulting line.**
- **Framing and insured worldwide delivery are included in every price.** Never written as an upsell or an add-on.

## Register

Obsidian, gold, warm white. Cormorant Garamond over Inter. The prose should sit inside that.

**Write like this:** *Fifteen seconds of open shutter over Manhattan. The building lights hold still; everything moving turns to light.*

**Not like this:** *This breathtaking, world-class masterpiece will transform your space and boast unmatched elegance.*

Concrete nouns. Real numbers. No "nestled," "boasts," "curated experience," "journey," "elevate," "timeless elegance," "must-have," or any adjective that could be swapped onto a different photograph without anyone noticing.

**There is no cause angle in photography copy.** A photograph stands on 1 of 1, the museum ArtBox build, Art Basel Miami 2025, and Monat representation — a complete argument on its own. The pledge belongs to the generative line only, and importing it here hands an $8,500 collector a reason to think they were buying absolution rather than a photograph. Positioning is **best available materials**, never eco-materials.

⚠️ **The two lines must never blend in one collection view.** They now sit under one brand, so the separation has to be done by the interface: distinct programs, distinct pages, never interleaved in the same grid. And the "shot in camera" claim attaches to **the photography program**, never to the gallery as a whole — see the note in `collector-offer-ladder`.

**Lead with the sharpest true fact — never with reassurance.** This was learned the hard way on this site: a first pass led with comfort copy ("you don't need the vocabulary yet") and the artist rejected it. Reassurance does not sell art; it relocates the friction. An unknown, self-taught, previously unrepresented photographer is a *stronger* story owned directly — *"Self-taught. Unrepresented. Until now."* — than softened around. Reassurance belongs in one sentence at the point of hesitation, never as the opening argument.

## Workflow

### 1. Establish the facts for this piece
Pull the artwork record from `src/lib/collection.ts` and the price/edition from `src/lib/shop.ts`. List what is genuinely known: where, when, what happened, the real EXIF if it survived. This list is your ceiling. You will not exceed it.

### 2. Find the frame's own story
Every good wall label rests on one true thing that happened. St Mark's Square empty during lockdown. Fifteen seconds of open shutter. A boat unshown for eleven years. A fifteen-year-old handed a camera.

Where that one thing is not known, **ask for it.** A description written without it will be decoration, and decoration reads as filler to a collector.

### 3. Choose the structure
- **Wall label / `detail` field** (40–70 words): what it is, where and when, the one true thing. No selling.
- **Lot essay** (150–250 words, unique tier): Hero's-Journey shape — the situation, what changed, what was taken, what it now means to own. This is where cultural capital, rarity, and provenance are argued.
- **Shop listing**: the object first (size, edition, build, what's included), the story second, the price plainly stated. **Never obscure the price** — 69% of collectors hesitate over price opacity, and younger collectors read "inquire" as a warning.
- **Hero line** (≤ 15 words): the sharpest true fact.
- **Collector email**: one story, one work, one ask. Match the lane — the five prior buyers get a note from Daniel personally; colder fair contacts get the gallery voice.

### 4. Match levers to the price band
From `collector-offer-ladder`:

| Band | Argue |
|---|---|
| Entry (< $100) | Access, education, being let in |
| Acquisition (~$450–550) | Craft; the same museum build as the large work |
| Premium ($850–3,900) | Emotional resonance, rarity, the specificity of this eye |
| Unique ($6,800–8,500) | Cultural capital · rarity · provenance · emotional impact · investment potential |

An $8,500 argument is never "it will look beautiful in your home." It is: *this frame exists once, it was made this way, this is where it has been, and it will not be available again.*

### 5. Produce variants, then cut
Write three. Read them aloud. Keep the one with the most true detail per sentence, not the one with the most feeling per sentence — in this register those turn out to be the same thing.

### 6. Self-audit before delivering
- [ ] Every factual claim traces to `collection.ts`, `shop.ts`, or the ground-truth section above.
- [ ] No invented statistic, testimonial, EXIF, provenance, or appreciation claim.
- [ ] No physical-space language. No announced opening date.
- [ ] Monat phrased correctly; consulting line absent.
- [ ] Price stated plainly; framing and shipping described as included.
- [ ] No banned adjective survives.
- [ ] Every sentence would still be true if a collector fact-checked it at the fair.

## Escalation

For an adversarial read before anything ships, hand the draft to the **art-world-panel** agent — it runs the copy past dealer, critic, and collector perspectives and reports what each would refuse to say. For general AI-tell removal, the `stop-slop` and `anti-ai-writing` skills compose cleanly with this one; run them after, never instead.
