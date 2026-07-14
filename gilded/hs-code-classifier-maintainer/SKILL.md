---
name: hs-code-classifier-maintainer
description: Extend and validate the HS tariff-code classifier in the Gilded Artworks Documents API (gilded-art-works-docs-api/app/services/hs_classifier.py) — the HS_CODE_DATABASE medium→code mapping and classify_hs_code() logic that the customs and commercial-invoice sheets depend on for correct codes like 9701 for hand-executed paintings. Use whenever someone says "add a medium to the HS classifier", "wrong HS code on the customs doc", "classify <medium>", "validate the HS codes", "the tariff code is off", "9701 vs 9702 vs 9703", "giclée should be 4911 not 9701", "add sculpture/print/photo mediums", or is editing hs_classifier.py / the /api/v1/hs-classify + /hs-codes endpoints. Ships a unit-test + validator that checks real Chapter-97/49/69/70/58 logic and the keyword-substring ordering trap. Pure Python 3, stdlib only.
---

# HS Code Classifier Maintainer (Gilded Artworks Documents API)

Maintain `app/services/hs_classifier.py` in **`ventures/gilded-art-works-docs-api`**.
`classify_hs_code(medium)` maps a free-text artwork medium to a Harmonized System
tariff code; `_prepare_artwork()` in `app/main.py` calls it whenever an artwork has a
medium but no explicit `hs_code`, and the result is stamped onto the **customs** and
**commercial-invoice** sheets. A wrong code is a customs-clearance problem, so changes
here are validated, not vibes.

Path base (override with `GILDED_ROOT`): `$GILDED_ROOT/ventures/gilded-art-works-docs-api`
— default `~/GILDED-EDGE-ECOSYSTEM`.

## How classification works (read before editing)

`classify_hs_code(medium)` runs three tiers, in order:

1. **Exact match** (`confidence: high`) — `medium.lower().strip()` is a key in
   `HS_CODE_DATABASE`.
2. **Keyword substring** (`confidence: medium`) — first DB key that is a **substring**
   of the medium wins. This iterates `HS_CODE_DATABASE.items()` in **insertion order**.
3. **Default fallback** (`confidence: low`) — `9701.90` "Other original works of art".

`get_all_codes()` returns the deduped, code-sorted list behind `/api/v1/hs-codes`.

### The substring-ordering trap (the #1 bug to avoid)

Tier 2 returns the **first inserted key that is a substring** of the medium — not the
longest or most specific. Consequences you must respect when adding entries:

- A short generic key inserted *before* a specific one can shadow it. E.g. if `"print"`
  (9702.00, original prints) sits above `"giclée print"` context, the medium
  `"archival giclée print"` could match `"print"` first and return the wrong chapter.
  The DB dodges this today by giving giclée/photo their **own exact keys** — preserve
  that. When you add a generic short token, add the specific multi-word variants too,
  and put specific-longer keys where they'll be reached (exact match tier makes exact
  strings safe regardless of order; the ordering only bites the substring tier).
- Always add the **exact medium string** you care about as its own key so it resolves at
  tier 1 and never depends on ordering.

## The real tariff logic (WCO HS 2024 — keep codes correct)

| Code | Covers | Example mediums |
|------|--------|-----------------|
| **9701.10** | Paintings, drawings, pastels executed **entirely by hand** | oil, acrylic, watercolour, gouache, tempera, charcoal, pastel, ink on paper |
| **9701.90** | Other original works (mixed media, collage, assemblage) + **default fallback** | mixed media, collage, installation |
| **9702.00** | Original **engravings, prints, lithographs** (hand-pulled, limited) | etching, lithograph, screenprint, serigraph, woodcut, monotype |
| **9703.00** | Original **sculptures & statuary** | bronze, marble, stone, wood carving, cast resin, kinetic |
| **4911.91** | **Printed/reproduced** pictures & **photographs** (NOT chapter 97) | giclée, digital/inkjet print, poster, c-print, gelatin silver, cyanotype |
| **6913.10 / .90** | Ornamental **ceramics** (porcelain = .10) | porcelain (.10), stoneware, earthenware, raku (.90) |
| **7013.99** | **Glassware** articles | blown / fused / stained glass, glass sculpture |
| **5805.00** | Hand-woven **tapestries & textile art** | tapestry, fiber art, weaving, embroidery |

Rules of thumb that must hold in tests:

- **Hand-made original = Chapter 97**; **mechanically printed / photographic reproduction
  = 4911.91 (Chapter 49)**. This is the classic error: a *giclée* is a print, NOT a
  9701 painting. A hand-pulled *lithograph/etching* IS 9702, an original work.
- **Porcelain** is `6913.10`; other ceramics `6913.90`.
- Empty / whitespace / unknown medium ⇒ `9701.90` low-confidence (never crash, never
  guess a specific chapter).

## Workflow — add or fix a medium

1. **Reproduce first**: `python3 scripts/hs_check.py "the exact medium string"` prints
   the code, confidence, and which tier fired. Confirm it's actually wrong.
2. **Edit `HS_CODE_DATABASE`** in `hs_classifier.py`. Add the **exact lowercase medium**
   as a key (tier-1 safe) plus any obvious variants (`"oil on linen"` alongside `"oil"`).
   Keep the existing dict-entry shape: `{"code","description","chapter"}`. Group under
   the right chapter comment block.
3. **Guard the ordering**: if you add a short generic token, run
   `python3 scripts/hs_check.py --audit` — it flags any DB key whose substring-tier
   result differs from its own exact-match code (i.e. a key that another shorter key
   would shadow). Fix by adding explicit exact keys for the shadowed variants.
4. **Run the unit tests**: `python3 scripts/test_hs_classifier.py` (stdlib `unittest`,
   no venv needed). Add a case for the medium you just fixed. It already locks in the
   9701/9702/9703/4911 boundaries and the empty-input default.
5. Keep `/api/v1/hs-codes` honest — `get_all_codes()` dedupes by code, so adding a new
   medium that reuses an existing code adds no new row; adding a genuinely new code does.

## Gotchas

- **Never** let a reproduction/print silently classify as 9701 — customs treats original
  vs printed very differently. The test suite asserts giclée/poster/photograph → 4911.91.
- The classifier lower-cases and strips but does **not** handle accents beyond what's in
  the DB — `giclee` and `giclée` are BOTH keyed on purpose. Add both spellings.
- `.90` vs `.10` sub-headings matter (porcelain 6913.10). Don't collapse them.
- Don't reorder the DB casually — the substring tier depends on insertion order. If you
  must reorder, re-run `--audit` and the tests.
- This is a heuristic aid, not legal customs advice — low-confidence results carry a
  "review recommended" source string; keep that surfaced to the user.

## Files
- `scripts/hs_check.py` — classify one medium and explain the tier; `--audit` flags
  shadowing/ordering hazards across the whole DB. Read-only.
- `scripts/test_hs_classifier.py` — stdlib unittest suite locking in the chapter
  boundaries + edge mediums. Runnable standalone or under pytest; add to the repo tests/.
