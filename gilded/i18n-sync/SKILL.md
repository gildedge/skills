---
name: i18n-sync
description: Keep Toutsweet's trilingual landing page consistent — detect new or changed English strings in i18n.js and produce the matching Spanish (ES) and Portuguese (PT) entries, then reconcile the menu across i18n.js, llms.txt, and the platform product catalog (Supabase seed / products table) so the same items and prices appear everywhere. Use when someone says "translate the new strings", "add ES/PT", "the site has untranslated text", "sync i18n", "the menu doesn't match between the landing page and the app", "update llms.txt", "add a new product to the site", or after any menu/copy change on the Toutsweet landing page.
---

# i18n Sync (Toutsweet)

Two jobs that must stay in lockstep:
1. **Translation parity** — every key in `en` also exists in `es` and `pt`
   (missing keys silently fall back to English, so gaps are invisible in QA).
2. **Menu consistency** — the products/flavors/prices are the SAME across the
   three surfaces that describe the menu: the landing `i18n.js`, the
   AI-discovery `llms.txt`, and the platform catalog (Supabase seed + `products`).

## Ground truth (read these first)
- `ventures/Toutsweet/i18n.js` — the dictionaries. Shape: `const translations = { en:{'key':'value',…}, es:{…}, pt:{…} }`. Text is swapped into DOM via `data-i18n` attributes in `index.html`. `t()` falls back `currentLang → en → key`.
- `ventures/Toutsweet/llms.txt` — the AI/LLM-facing menu + prices ($28, $42, $75, $100, $35…).
- `ventures/Toutsweet/platform/supabase/migrations/001_initial_schema.sql` — the seeded `products` (name, slug, category, `price_cents`). This is the catalog of record for the app.

## When to use
- New EN copy was added and ES/PT need to catch up.
- A product/price/flavor changed and only one surface was updated.
- Pre-deploy audit of the landing page's trilingual completeness.

## Workflow
1. **Audit (read-only):**
   ```bash
   node ~/.claude/skills/i18n-sync/scripts/i18n-audit.mjs
   ```
   It prints:
   - **Missing translations** — keys in `en` absent from `es` / `pt` (these fall
     back to English on the live site).
   - **Orphan keys** — keys in `es` / `pt` that no longer exist in `en` (delete or re-key).
   - **Menu reconciliation** — product names/prices found in `i18n.js` vs
     `llms.txt` vs the SQL seed, side by side, so you can spot drift.
   Add `--json` for machine output, `--lang es` to focus one language.
2. **Fill missing translations** directly in `i18n.js`. Add the key under BOTH
   `es` and `pt`, in the same section-comment block as its `en` sibling. Match
   the house voice — lowercase, trailing-colon labels, and keep any `<br>` /
   `&` / trademark punctuation identical (the renderer treats a value containing
   `<br>` as `innerHTML`, everything else as `textContent`).
3. **Reconcile the menu.** Pick the intended source of truth (usually the
   current `i18n.js` + `llms.txt`, since the SQL seed is the oldest surface) and
   bring the others into line:
   - Update `llms.txt` menu bullets + FAQ prices.
   - Update the Supabase `products` seed / live rows (`price_cents` in **cents**:
     $28 → `2800`). See the `cost-engine-updater` skill for anything touching costs/margins.
4. **Re-run the audit** until missing/orphan/menu sections are all clean.

## Real snippet — adding one product string across all three langs
`i18n.js` (three edits, same key):
```js
en: { 'product.12.name': 'guava & cheese roll:', 'product.12.desc': 'flaky pastry with guava paste and queso fresco' }
es: { 'product.12.name': 'enrollado de guayaba y queso:', 'product.12.desc': 'hojaldre con pasta de guayaba y queso fresco' }
pt: { 'product.12.name': 'rocambole de goiaba e queijo:', 'product.12.desc': 'massa folhada com goiabada e queijo fresco' }
```
Then add the matching bullet to `llms.txt` and a `products` row
(`price_cents`, unique `slug`, valid `category` ∈ alfajores|cakes|loaves|special).

## Ecosystem gotchas
- **Silent English fallback.** `t()` returns `translations.en[key]` when the
  current language lacks a key — the page never errors, so untranslated strings
  ship unnoticed. The audit is the only guard. Run it before every landing deploy.
- **The three surfaces already disagree.** As of writing, `i18n.js`/`llms.txt`
  list *zucchini bread*, *banana chocolate bread*, and *lemon olive oil poppy
  seed loaf*, while the SQL seed still has *Lemon Blueberry Loaf* and *Banana
  Bread*. Treat the SQL seed as stale and reconcile — don't assume it's correct.
- **`product.3` is intentionally skipped** in `i18n.js` (keys run 1,2,4,5,6,7,8,
  9,10,11). Don't "fix" the gap by renumbering — the numbers map to DOM
  `data-i18n` attributes in `index.html`; renumbering breaks the bindings.
- **Prices live in cents in the app, dollars in copy.** `i18n.js`/`llms.txt`
  show `$28`; `products.price_cents` stores `2800`. Never write a float dollar
  value into `price_cents`.
- **`<br>` values render as HTML.** Keep line breaks (e.g. delivery hours) as
  literal `<br>` in ES/PT too, or the layout changes.
- **Categories are constrained** by a CHECK: `alfajores | cakes | loaves |
  special`. A new menu item must map to one of these in the seed.
