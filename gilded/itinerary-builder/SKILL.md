---
name: itinerary-builder
description: Assemble a day-by-day luxury travel itinerary for gilded-travel-works by composing SELECTED hotels, experiences, restaurants, villas, and flights from the EXISTING src/data schema (cities, hotelGalleries, collectionItems) into a structured Itinerary — with output that passes the venture's existing data-validation skill. Use when someone says "build an itinerary", "plan a 3/5/7-day trip", "day-by-day for Kyoto/Paris/Maldives", "assemble a member itinerary", "curate a stay", "put together a trip from our hotels and experiences", or needs a validated itinerary data entry. Complements — does not duplicate — the existing data-validation and stop-slop skills in .agents/skills.
---

# Itinerary Builder (Gilded Ventures VIP / gilded-travel-works)

Compose a day-by-day itinerary strictly from entities that **already exist** in
`src/data/` — never invent a hotel or experience. Every day-item reuses a real
entry's name / description / image / location, so the assembled itinerary passes
the existing `data-validation` skill by construction.

## Ground truth (read these first)
- `src/data/cityData.ts` (+ `cityDataPart2.ts`, `cityDataPart3.ts`) — `CityGuide` objects with `hotels[]`, `villas[]`, `restaurants[]`, `experiences[]`, `flightOptions[]`, `vipServices[]`. Exported as `allCities`; look up with `getCityById(id)`.
- `src/data/hotelData.ts` — `hotelGalleries` (keyed by `hotelId`) with `rooms[]` (`pricePerNight` in **dollars**, not cents).
- `src/data/collectionData.ts` — `collectionItems[]` villas (price as a `'$28,500'` string) keyed by `collectionSlug`.
- `.agents/skills/data-validation/SKILL.md` — the bar every entry must clear (this skill's output is designed to pass it).
- `.agents/skills/stop-slop/SKILL.md` — run over any new prose you write.
- `AGENTS.md` — brand voice (warm, discreet), tier system, and the `npm run lint` gate.

## Data facts that constrain the build
- **Tiers:** `MembershipTier = 'explorer' | 'voyager' | 'patron'`. Each hotel /
  villa / experience / flight carries a `tier`. Don't put a `patron`-tier item
  in an `explorer` itinerary.
- **Prices are heterogeneous** across files — `rooms[].pricePerNight` and
  `experiences[].priceFrom` are **numbers (USD)**; `collectionItems[].price` is
  a **string** (`'$28,500'`). Preserve each source's own format; don't coerce.
- **Cross-links exist**: `CityHotel.hotelSlug → /hotel/:id`,
  `CityVilla.collectionSlug → /collection/:slug`. Reuse those slugs.

## Itinerary shape (the type this skill emits)
```ts
export interface ItineraryDay {
  day: number;
  title: string;          // e.g. "Arrival & the Old Imperial City"
  name: string;           // required by data-validation (non-empty)
  description: string;    // >= 2 sentences / >= 50 chars, brand voice
  image: string;          // reuse the referenced entity's image URL/path
  location: string;       // required — the city name
  tier: 'explorer' | 'voyager' | 'patron';
  references: {           // ids/slugs/names that MUST resolve in src/data
    cityId: string;
    hotelName?: string;   // from city.hotels[].name or a hotelGalleries key
    experienceNames?: string[];
    restaurantNames?: string[];
    collectionSlug?: string;
    flightRoute?: string;
  };
}
export interface Itinerary {
  slug: string;           // URL-safe: lowercase, hyphens, no spaces
  title: string;
  city: string;
  cityId: string;
  tier: 'explorer' | 'voyager' | 'patron';
  nights: number;
  days: ItineraryDay[];
}
```

## Workflow
1. **Pick a city** by its `id` field — the hyphenated slug, not the export name:
   `paris`, `kyoto`, `santorini`, `maldives`, `london`, `monaco`, `cape-town`,
   `new-york`, `marrakech`, `venice`, `dubai`, `aspen`. Confirm with
   `getCityById` (the validator lists the known ids if you guess wrong).
2. **Select real entities** from that city's arrays (and optionally a
   `collectionItems` villa or a `hotelGalleries` room). Keep every selection at
   or below the itinerary's target tier.
3. **Draft each day**: reuse the source entity's `image` and set `location` to
   the city name. Write a 2+ sentence `description` in the discreet-advisor voice
   (run it through `stop-slop`). Keep `slug` URL-safe.
4. **Validate (read-only):**
   ```bash
   node ~/.claude/skills/itinerary-builder/scripts/validate-itinerary.mjs path/to/itinerary.json
   ```
   It confirms (a) every referenced `cityId` / hotel / experience / restaurant /
   `collectionSlug` actually resolves in `src/data/`, and (b) each day passes the
   `data-validation` rules (name non-empty, description ≥2 sentences & ≥50 chars,
   image present & non-placeholder, location non-empty, tier valid, slug URL-safe).
   Exit code is non-zero if anything fails.
5. **Emit the TS data file** only after validation passes. Suggested home:
   `src/data/itineraries/<slug>.ts` exporting a typed `Itinerary`. Write it
   yourself (this skill's script does not write into the repo). Then run
   `npm run lint` per `AGENTS.md`, and the `data-validation` scan.

## Real snippet — one validated Kyoto day (all fields resolve in cityData.ts)
```ts
{
  day: 2, title: 'Tea, Temples & a Three-Star Table',
  name: 'Private Tea Ceremony & Kikunoi Kaiseki',
  description: 'Morning opens with a private Chanoyu ceremony led by a 15th-generation tea master in a historic Urasenke tearoom. The evening closes at Kikunoi Honten, Yoshihiro Murata\'s three-star kaiseki temple, for a seasonal course reflecting the 72 microseasons.',
  image: 'https://images.unsplash.com/photo-1524413840807-0c3cb6fa808d?q=80&w=2070&auto=format&fit=crop',
  location: 'Kyoto',
  tier: 'patron',
  references: { cityId: 'kyoto', experienceNames: ['Private Tea Ceremony with Grandmaster'], restaurantNames: ['Kikunoi Honten'] },
}
```
A complete runnable example is in `examples/kyoto-3day.json`.

## Ecosystem gotchas
- **Never invent entities.** If a hotel/experience isn't already in `src/data/`,
  add it there first (passing `data-validation`) — the itinerary only *composes*
  existing entries. The validator fails on any unresolved reference.
- **Descriptions need ≥2 sentences / ≥50 chars.** A one-line day blurb fails
  `data-validation`. Reuse or expand the source entity's own description.
- **No placeholder image tokens.** `placeholder`, `upload`, `TODO` in an image
  path fail validation. Reuse the referenced entity's real URL.
- **Tier discipline.** Mixing a `patron` villa into an `explorer` itinerary is a
  content bug even though it "renders" — keep the whole itinerary tier-coherent.
- **Don't coerce prices.** Leave `pricePerNight`/`priceFrom` as numbers and
  `collectionItems.price` as its `'$…'` string; different pages parse each format.
- **Slugs are URL-safe** (lowercase, hyphens) because they feed React Router
  paths like `/hotel/:id` and `/collection/:slug`.
- **Lint is the gate** (`AGENTS.md`): `npm run lint` must pass with zero TS
  errors before the new data file is considered done.
