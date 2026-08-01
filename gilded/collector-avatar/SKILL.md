---
name: collector-avatar
description: Build and maintain evidence-grounded collector avatars for Gilded Edge Gallery — who actually buys the work, what they fear, what they say no to, and the before/after transformation each one is buying. Produces an avatar dossier, a transformation grid, and an objection map that downstream copy, offers, FAQ, and outreach all read from. Use when someone says "who is our buyer", "build customer avatars", "who are we selling to", "why aren't people buying", "what objections do collectors have", "write the FAQ", "segment the collector list", "who do we target at the fair", or is writing any copy that needs to know its reader. Hard rule — avatars are built from real evidence (the five prior buyers, fair contacts, Art Basel/UBS market research), never invented; every claim carries its source or is labelled ASSUMPTION.
---

# Collector Avatar

Turn what is actually known about this gallery's buyers into three reusable artefacts: an **avatar dossier**, a **transformation grid**, and an **objection map**. Adapted from the customer-avatar sequence in the Surreal Academy curriculum (Day 6), with its invent-ten-personas-from-nothing step replaced by an evidence discipline.

The curriculum's method is sound and the gallery has never done it. The gallery has five real collectors, a documented sale, a fair audience, and published market research on how HNW collectors buy — and yet no written statement of who the buyer is. Every piece of copy on the site is currently written to a reader nobody has described.

## When to use

- Writing or auditing shop copy, artwork descriptions, emails, or the FAQ.
- Designing an offer (the `collector-offer-ladder` skill reads this skill's output).
- Planning outreach — especially the split between the five prior buyers and colder fair contacts.
- Someone asks why conversion is flat.

## The evidence discipline

**Every line in an avatar dossier is one of three things, and is labelled as such:**

- `[OBSERVED]` — drawn from a real buyer, a real sale, a real DM, a real conversation. Cite it.
- `[RESEARCH]` — drawn from published art-market data. Cite the source and year.
- `[ASSUMPTION]` — a working hypothesis. Must state what would confirm or kill it.

An avatar that is 100% `[ASSUMPTION]` is a guess wearing a suit and must be presented as one. This mirrors the gallery's standing rule against inventing proof: never fabricate a testimonial, a statistic, a collector quote, or a demographic. If it isn't known, the honest output is "unknown — here is how to find out."

## Ground truth — the evidence that exists today

**Observed:**
- Five original works have sold into private collections, 2020–2024, direct and unrepresented — one conversation at a time. These buyers have the artist's personal email.
- One fully documented sale: "Horizon's Symphony," ed. 22, framed 30 × 40, **$3,050 + $160 shipping, November 2023, private collector, New York.** The buyer's name and address are in the invoice and are **never** published, quoted, or used in copy.
- Three works are at the Marbella Art Fair from 2026-07-30, represented by Monat Gallery (Madrid/Marbella): *Eternal Facade* $3,500, *The Silence Between The Tides* $3,500, *Midnight Silence* $3,000.
- Exhibited at Art Basel Miami 2025.

**Research (Art Basel & UBS 2025 survey, via `infrastructure/wiki/strategy/instagram-growth-playbook.md` §1):**
- 51% of HNW collectors have bought via Instagram sight-unseen.
- More than half of purchases connect to a fair.
- ~90% of artist inquiries arrive by DM.
- **Price opacity is a red flag — 69% of collectors hesitated over it.** Younger collectors read "price on inquiry" as a warning sign. Transparency converts.

That last finding is the most actionable thing known about this gallery's buyer, and the site already gets it right by publishing prices. Protect that.

**Never in an avatar:** the named NYC collector; the artist's home address (it appears on UPS/customs paperwork — use a CMRA box for any postal footer); the $500 declared customs value (that is a customs declaration, **not** a retail price, and quoting it would undercut the real prices by 85%).

## Workflow

### 1. Segment from what happened, not from imagination
Start with the five prior buyers and the fair audience. Ask, for each real sale that is documented: how did they find the work, what did they say about it, what did they ask before buying, how long did it take, what did they pay. Where the record is thin — and it is thin — say so and list the question to put to the artist.

Then, and only then, extend to plausible segments the fair and Instagram will produce. Label them `[ASSUMPTION]`.

### 2. Build the dossier
Three avatars, no more. Four is a list; three is a strategy. For each:

```
## Avatar — <name>
Evidence base: [OBSERVED n=? | RESEARCH | ASSUMPTION]

Who they are          — role, where they encounter the work, what else they own
What they are buying  — not the object; the thing the object does for them
Price band            — which rung of the offer ladder they land on
How they arrive       — fair booth / IG DM / referral from the artist / the site directly
What they need to see — the specific proof that unlocks the decision
What they fear        — the specific thing that makes them close the tab
Vocabulary            — the words they use; the words that would embarrass them
Do not say to them    — the register that reads wrong for this person
```

### 3. Transformation grid
For each avatar, the before and after — with the work as the hinge. Keep it concrete; "feels inspired" is not a transformation.

| | Before | After |
|---|---|---|
| Situation | | |
| What they have | | |
| What they feel | | |
| How they see themselves | | |
| What they can now say | | |

Close each with one sentence in *from-this-to-that* form. That sentence is the raw material for hero copy — hand it to the `artwork-narrative` skill.

### 4. Objection map — the highest-value output
For every avatar, list every real reason they do not buy. For each: the reason underneath it, and the specific, honest thing that dissolves it. This map is the direct source for the shop FAQ, which does not currently exist.

The gallery's actual live objections, as a starting set:

| Objection | What's underneath | What answers it |
|---|---|---|
| "$8,500 for a photograph?" | Photography reads as reproducible; they don't know what they're paying for | 1 of 1, never editioned, never reprinted; museum ArtBox build; the real production cost is not hidden |
| "What is an ArtBox?" | Unfamiliar format, can't picture it on a wall | Plain description of the build — Alu-Dibond, acrylic face mount, framed; the same standard the artist ships to galleries |
| "Is framing extra? Shipping?" | Fear of the checkout surprise | Both included in every price, worldwide, insured. Say it early, not in the footer |
| "Who is this artist?" | No track record they recognise | Art Basel Miami 2025; represented by Monat Gallery; Marbella Art Fair 2026; five works already in private collections |
| "Will it hold value?" | Investment anxiety | State edition structure and provenance honestly. **Never project appreciation** — see below |
| "Can I see it first?" | Sight-unseen risk on a four-figure object | A one-to-one call with the artist. Not a gallery visit — there is no physical space |
| "What if it arrives damaged?" | Logistics risk | Insured worldwide delivery, included |
| "Will I be charged import VAT?" | Real, unresolved, and expensive in the EU | **Currently unanswered.** ~19–21% on framed prints into the EU with no Stripe Tax configured. Flag as an open blocker; do not paper over it |

⚠️ **Investment-potential language.** "Investment potential" is a legitimate lever at the unique tier (see `collector-offer-ladder`), but it has a hard edge: describing what the edition structure *is* is fine; **projecting that a work will appreciate is a financial claim and is not made.** The source curriculum suggests "referencing similar pieces that have increased in worth over time" — do not do this with invented comparables.

### 5. Write it down and route it
Persist to `infrastructure/wiki/strategy/` as a dated collector-avatar dossier. Then say explicitly which downstream artefacts must change: shop FAQ, hero copy, the two outreach lanes, offer ladder rungs.

## The two outreach lanes

Segmentation here is already decided and must be respected:

- **The five prior buyers** bought from the artist directly and hold his personal email. Notes to them go **from Daniel personally.** A "Director of Collector Sales" signature reads as distance to someone who has his mobile.
- **Colder Art Basel / Marbella contacts** are the lane for a gallery-voice sender.

Getting this backwards damages the only warm relationships the gallery has.

## Anti-patterns

- Generating ten fictional personas because the prompt asked for ten. Three real ones beat ten invented ones.
- Demographic filler (age 28–55, primarily women, £40,000+) copied from a curriculum example about a different artist selling different work at a tenth of the price.
- Inventing testimonials, quotes, or statistics to populate a section. If the section has no evidence, the section does not ship.
- Writing avatars that imply a physical gallery — visits, openings, walk-ins, hours. It is an online showroom.
