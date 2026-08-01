---
name: collector-offer-ladder
description: Design, price, and pressure-test the tiered offer ladder for Gilded Edge Gallery (and sibling art ventures) — entry / acquisition / premium / unique tiers, upsells, cross-sells, and the value levers appropriate to each price band. Use when someone says "we have nothing under $850", "what's our entry offer", "build the offer ladder", "add an introductory tier", "how should we price this", "increase average order value", "what upsells make sense", "we need a lead magnet for collectors", "plan a fair-week offer", or is designing anything a collector can buy. Enforces the luxury guardrails: never discount, never give art away free, scarcity must be structural (edition size) not manufactured (countdown timers), and every price anchors to real WhiteWall production cost — never to "energetic alignment".
---

# Collector Offer Ladder

Build and price the ladder of things a collector can actually buy, from first contact to unique work. Adapted from the tiered-offer architecture in the Surreal Academy art-marketing curriculum (Days 7–9), stripped of its DTC/Meta-ads assumptions and re-grounded in this gallery's real unit economics.

The organising idea is the one luxury houses use: **a ladder, not a price list.** Chanel sells a $38 lipstick and a $8,000 jacket from the same brand equity — the lipstick is not a discount on the jacket, it is a different rung. A gallery with only a $850 floor has no rung for the collector who just met the work and is not yet ready to spend four figures on a stranger.

## When to use

- There is a hole in the ladder (today: **nothing exists below $850**).
- A new offer, bundle, add-on, or fair-week package is being designed.
- Someone asks how to raise average order value.
- A price needs justifying, defending, or revisiting.
- Reviewing whether an offer cheapens the brand.

## Ground truth — read before proposing anything

Read these first. Do not propose a price without them.

| Fact | Source of truth |
|---|---|
| Live catalog + full cost model | `ventures/gilded-edge-gallery/src/lib/shop.ts` (pricing header comment) |
| Unit economics, fees, Monat commission, VAT | `infrastructure/wiki/strategy/2026-07-gilded-edge-gallery-strategy.md` §2a |
| Brand rules (online showroom, no physical space, Monat disambiguation) | `ventures/gilded-edge-gallery/CLAUDE.md` |
| Collector avatars & objections | the `collector-avatar` skill's output |

**The ladder as it stands today:**

| Rung | Offer | Price | Status |
|---|---|---|---|
| Entry | — | — | **EMPTY — this is the gap** |
| Acquisition | — | — | **EMPTY** |
| Premium | Editions of 7 per size, 40/60/90/120/150 cm long edge | $850 / $1,400 / $2,200 / $2,950 / $3,900 | Live in `shop.ts` |
| Unique | "Midtown Dusk" · "Cape Florida, Full Moon" | $6,800 · $8,500 | Live in `shop.ts` |
| Relationship | Collectors Circle (free, by invitation) · private viewing (free, one-to-one call) | $0 | Live, free — keep free |

**Every price includes museum framing (WhiteWall ArtBox) and insured worldwide delivery.** That is the presentation standard the artist actually ships. It is priced in and is **never** an upsell — do not propose "add framing for $X".

**Real margin, not headline margin.** Production targets ≤ ~35% of retail, but the honest net is lower:
- Stripe international card: **5.4% + $0.30** (most fair-originated collectors pay on international cards) → direct-sale net ≈ **61–62%**, not 67%.
- Monat Gallery commission on fair-originated sales: typically **40–50% of retail**. A $3,900 edition at a 50% split nets ≈ $650 after production — a ~17% margin. **Fair sales are collector acquisition, not margin.**
- EU import VAT ~19–21% on framed prints is unresolved and unbudgeted.
- Price parity across channels is mandatory. Galleries terminate artists who undercut them online.

## The four guardrails

Apply these to every proposal. A proposal that fails any one of them is rejected, not softened.

1. **Never discount.** Reframe value instead. If a moment needs a commercial gesture (fair week, a returning collector), add something — a folio, a print of the artist's contact sheet, priority on the next release — never subtract from the price. A gallery that discounts once has told the market its prices were fiction.
2. **Never give the art away free.** Free things may be *about* the work (a catalogue, a viewing, a letter). The work itself always has a price.
3. **Scarcity must be structural, never manufactured.** Edition of 7. One of one. Three works at the Marbella fair. Those are true and verifiable. Countdown timers, "only 2 left!" banners, and invented deadlines are forbidden — they read as fraud to a collector who has bought at a fair.
4. **Every price anchors to a real number.** Production cost from a real WhiteWall order, a real comparable (Laumont ~$1,722 for a framed 30×40), or a real prior sale ("Horizon's Symphony," ed. 22, framed 30×40, $3,050 + $160 shipping, Nov 2023 — the buyer is **never named**). The source curriculum's "intuitive pricing guide / energetic alignment" prompt is not used here. Intuition may break a tie between two cost-justified prices; it may not set one.

## Value levers by price band

This is the most useful thing the source curriculum contains, and the part most often applied at the wrong altitude. **The levers that justify a $60 catalogue are not the levers that justify an $8,500 photograph.** Match the band.

| Band | Levers to maximise | Levers to minimise | Register |
|---|---|---|---|
| **Entry** (< ~$100) | Perceived value per dollar, immediacy, education, the sense of being let in | Effort, sacrifice, friction, commitment | Generous, plainspoken |
| **Acquisition** (~$300–800) | Craft, "first real piece", the same production standard as the big work | Perceived risk, buyer's remorse, fear of the wrong choice | Warm, reassuring at the point of action |
| **Premium** ($850–5,000) | Emotional resonance, rarity, aesthetic authority, the artist's specific eye | Market accessibility (deliberately) | Curatorial |
| **Unique** ($5,000+) | **Cultural capital · rarity · provenance · emotional impact · investment potential** | Accessibility, availability, anything that reads as retail | Lot essay |

The unique-tier lever set is the one to memorise. For a 1/1 photograph at $8,500, the argument is never "it will look great in your space" — it is *this frame exists once, it was made this way, here is where it has been, here is what it costs to never be able to buy it again.*

Provenance is a lever the gallery can actually pull: physical works sold through the gallery consume **Gilded Artworks'** provenance-certificate and verification services (strategy §5). Do not build a parallel provenance stack inside the gallery.

## Cause linkage — the donation model

The positioning is **not** eco-materials. It is *best available materials, plus an absolute line about who profits from what:*

**Corrected 2026-07-30 by the founder.** Both lines sell through **Gilded Edge Gallery**. Gilded Artworks is platform and infrastructure only — marketplace tooling, NFC provenance, verification, document generation, subscriptions — and **sells no art at all**. An earlier version of this section put the AI line on Artworks; that was an inference, and it was wrong.

| Line (both sold by the gallery) | Work | Pledge |
|---|---|---|
| **Photography** | Daniel Montero's own photographs | **No pledge. Full margin retained.** |
| **Generative works** | Machine-made pieces | **100% to ocean conservation — the artist takes nothing** |

This is a stance, not a percentage, and it is much stronger than a split rate. *"I don't take a penny from machine-made work. I live on my own photographs."* It resolves three problems at once:

- **It removes the AI objection entirely.** The researched position in `instagram-growth-playbook.md` §1 is that AI backlash in art audiences is acute — Meta's auto-label fires even on generative-fill retouching. The objection is specifically that machines are taking money artists used to earn. At 50% that objection still lands; at **100% it has nothing to grip.** The artist is not in the financial equation.
- **It separates the two lines by conviction rather than by policy.** Now that both sell under one roof, the pledge is what keeps them legibly distinct — and a stance is more durable than a rule someone has to remember to enforce.
- **It protects the photography's pricing.** No pledge on the photography means no risk of a $8,500 unique reading as absolution-for-sale, and no awkward asymmetry to explain. The photography stands on 1 of 1, museum ArtBox, Art Basel, Monat — which is what it should have been standing on all along.

100% is also the only version of this that is *news*. 50% is a marketing percentage; 100% is a position. Treat it as a launch story.

### The word "profits" is now the whole vulnerability

At 50%, a loose definition of profit is invisible. At **100%, "profit" becomes the only variable in the sentence**, and every cost deducted before the donation reads to a skeptic as clawing it back. "100% of profits — after I pay myself, my hosting, my marketing, and my time" is the headline nobody wants.

**Do not use "100% of profits." Use one of these instead, in order of strength:**

1. **Published arithmetic.** State the sale price, state the production cost, state that the entire difference is donated. `$X sale − $Y production = $Z to <charity>.` Unattackable, and radical transparency is itself the story.
2. **A fixed amount per work.** "$Z from every work goes to <charity>" — where $Z *is* the whole margin. Concrete, verifiable, and it survives volume.
3. **"100% of proceeds after direct production and payment costs,"** with those two costs published and nothing else deductible. Acceptable, but weaker than the first two.

Whichever is chosen, **publish the definition next to the claim**, not in a footnote.

### Settled 2026-07-29: Gilded Artworks' revenue is the platform only

Confirmed by the founder. The venture earns from the **platform** — marketplace, NFC provenance, verification, document generation, and the Professional / Studio / Gallery subscription tiers. **AI artwork sales are not a revenue line.** Four consequences follow, and they all point the same way:

**1. The pledge is now free.** Donating 100% of AI-artwork margin costs the venture nothing it was counting on, and buys maximum credibility. This is the ideal configuration for a claim like this — most companies cannot make it because the revenue is real.

**2. The overhead question disappears, which makes the arithmetic unattackable.** Because no platform cost is allocated to the artwork line, the only deductions before donating are **generation cost, physical production (if phygital), and payment fees.** Nothing else. That produces the strongest possible published claim: *"We allocate no overhead to this. The platform pays for itself."* Publish those two or three cost lines and the difference. There is no room left for a skeptic to work in.

**3. Price the AI work seriously — do not price it cheap.** The instinct when something isn't a revenue line is to price it low. That is wrong here, twice over: a lower price means a smaller donation, and a marketplace whose own flagship works sell for $50 has told the market that the entire category is worth $50. **Price at what the work is worth and donate all of it.** The platform's positioning depends on the art being taken seriously.

**4. The artwork is a demonstration, not a product.** Every AI work sold should run through the platform's own pipeline end to end — minted, NFC-tagged, provenance-certified, documented via the doc-gen API — so each sale is a live proof that the infrastructure works. Judge the artwork line by **subscription signups**, not by units sold.

⚠️ **Keep the pledge out of the platform's pitch.** Artists and galleries subscribe because they need provenance and authentication infrastructure, not because they want to fund ocean conservation. The pledge is a credibility asset for the *artwork*; it is not a reason to buy a Studio tier. Same discipline as the gallery — cause linkage sits where it earns its keep and nowhere else.

### Still open: permanent, per-collection, or time-boxed?

A 100% pledge is easy at low volume and hard at scale. Because the artwork line is not carrying revenue, permanent is now the defensible default — but say so explicitly and phrase the public commitment to match. Quietly walking a 100% pledge back later is worse than never making it.

### Tax — do not assume giving it away means owing nothing

Donating 100% of margin does **not** automatically mean zero tax exposure. Charitable deductions are capped (US: roughly 10% of taxable income for a C-corp; pass-through income flows to the personal return with its own AGI limits). It is entirely possible to owe tax on income already given away. This is a structuring question for a CPA before the first sale, not after — the answer usually shapes whether the pledge is priced in, routed through a formal arrangement, or handled some other way.

### Compliance guardrails — non-negotiable

A donation claim is a factual claim about money. It sits under the same never-invent-proof rule as a testimonial, and it carries legal exposure a testimonial does not.

1. ⚠️ **The named beneficiary does not exist under that name.** There is no charity called "Save the Ocean Foundation." Real candidates with similar names and very different missions: [Save Our Seas Foundation](https://saveourseas.com/) (Geneva; sharks and rays), [The Ocean Foundation](https://oceanfdn.org/) (community foundation for the ocean), [Sea Save Foundation](https://seasave.org/), [Oceana](https://oceana.org/). **Pick one, record its exact legal name and registration number, and use only that.** Nothing ships naming a beneficiary until this is settled.
2. **Get written permission before using a charity's name or logo.** Most have a partnership process and brand guidelines. Naming them without it is a trademark problem and a relationship problem.
3. **Never publish the words "100% of profits."** See the section above — use published arithmetic or a fixed amount per work.
4. **This makes the venture a commercial co-venturer, and a 100% claim draws the most scrutiny of any version.** Advertising that a purchase triggers a charitable contribution triggers commercial co-venture rules — in several US states that means registration, a written contract with the charity, bonding, and accounting; the UK and EU have their own charity-advertising regimes. Shipping is enabled to US, CA, GB, DE, FR, ES, IT, CH, AE. **Route this to counsel before launch**, alongside the existing `/terms` and `/privacy` flag. Raising the pledge from 50% to 100% raises the compliance bar; it does not lower it.
5. **Track and remit, and be able to evidence it.** A pledge that cannot be shown is worse than no pledge.
6. **Never state a cumulative total** ("we've donated $X to date") unless it is real, current, and reconcilable.

## Workflow

### 1. Locate the gap
Lay out the current ladder. Name the rung that is missing and say who falls through it. Today: a collector who meets the work at Marbella, is moved, and is not going to wire $850 to a photographer they met an hour ago. There is nothing for them to say yes to, so they say nothing, and the gallery loses the name.

### 2. Generate candidates against the emotional benefits
For each rung, generate 5 candidate offers per emotional benefit the work delivers. Derive the benefits from the `collector-avatar` output, not from imagination.

Constrain every candidate with:
- Under ~5 hours to create and maintain (the artist is one person and gains energy from making pictures, not from logistics).
- High gross margin (entry rung should clear ~90%+).
- Zero brand dilution.
- Fulfilment that already exists or is one supplier away (WhiteWall is already integrated; the artist holds a token).

### 3. Screen against the guardrails
Kill anything that discounts, gives away work, manufactures scarcity, or prices from feel. Kill anything that requires a physical space — **there isn't one.** No opening receptions, no gallery hours, no address, no walk-ins. Private viewings are one-to-one calls with the artist.

### 4. Raise perceived value before raising price
For each surviving candidate, run the enhancement pass:
- What would justify a 10× price? Do a defensible fraction of it.
- What could be added at near-zero marginal cost that materially raises perceived value?
- What does the collector get to *say* about owning this?

Bonus stock that is brand-safe here: a signed print of the frame's technical sheet (real EXIF only — two works have stripped metadata and honestly get none); the artist's written note on where and when the frame was taken; priority access to the next release; a one-to-one call; installation guidance for the specific wall.

### 5. Price it
Cost-anchor first, then triage on this grid:

| Offer | Production cost | Fulfilment effort | Emotional impact (1–10) | Net margin after fees | Proposed price |
|---|---|---|---|---|---|

Anything below ~60% net at the premium/unique tiers gets re-examined. Anything above ~90% at the entry tier is correctly designed.

### 6. Present as a proposal, not a decision
Prices are **the artist's to bless.** `shop.ts` says so in its own header. Output a recommendation with the cost arithmetic shown, and flag what needs his sign-off.

## Standing recommendations for the two empty rungs

These are the current best candidates. They are proposals awaiting the artist's sign-off, not shipped facts.

**Entry rung — the *First Light* folio, ~$45–85.** A printed, signed catalogue of the inaugural collection: the four frames, the artist's note on each, real technical plates where the metadata exists, and the account of the fifteen-year-old who was handed his father's camera. Gallery-native — every serious gallery sells its catalogue. Ships worldwide. Touches nothing in the edition ladder. Converts an anonymous browser into a named collector who has already paid the gallery once, which is the single largest predictor that they will pay it again.

**Acquisition rung — a small-format framed work, ~$450–550.** A 20 × 20 cm framed ArtBox costs ~$141 at real WhiteWall pricing. Retailed at ~$450–550 it clears ~70% and it puts a *real, framed, museum-standard* Montero on a wall for under the price of a weekend. Same production standard as the $3,900 piece — that is the argument.

⚠️ **Edition-dilution risk, must be resolved before this ships.** The premium tier's scarcity claim is "edition of 7 per size." A small format sold at volume either becomes an eighth size in that ladder (fine — 7 copies, sells out, done) or an open edition (which quietly contradicts the collection's scarcity story). Decide which, in writing, and make the site say it. Do not let this rung ship ambiguous.

## Anti-patterns

Carried over from the source curriculum and explicitly rejected here:

- **Meta cold-traffic funnels as the primary channel.** For $850–$8,500 photographs the real channels are fair-originated collectors, the five prior buyers, Monat's collector list, and email. Paid social may support a $60 folio; it does not sell a $8,500 unique to a stranger.
- **Discount-led moments** (Black Friday and similar). If a seasonal moment is used at all, it reframes value — it never cuts price.
- **"Intuitive/energetic" pricing.** Cost-anchored, always.
- **Free-shipping-style upsells.** Framing and insured delivery are already included. Do not un-include them to sell them back.
