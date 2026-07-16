---
name: cost-engine-updater
description: Batch-update Toutsweet ingredient costs and regenerate COGS, margin alerts, and price-suggestion reports using the venture's existing cost-engine.ts model. Use when someone says "update ingredient costs", "flour/butter/dulce de leche went up", "recalculate COGS", "which products are below target margin", "regenerate the cost report", "suggest new prices", "weekly cost report for Toutsweet", or when a supplier price change needs to ripple into margins and price suggestions. Everything stays in integer cents — money is never floated.
---

# Cost Engine Updater (Toutsweet)

Batch-apply new ingredient costs, then recompute COGS, margins, below-target
alerts, and price suggestions **using the exact math already shipped in
Toutsweet's `cost-engine.ts`** — so the numbers this skill produces match what
`/api/costs/calculate` and the admin Reports page show. No parallel/rival model.

## Ground truth (read these first)
- `ventures/Toutsweet/platform/src/lib/cost-engine.ts` — the model. Do not fork the formulas; mirror them.
- `ventures/Toutsweet/platform/src/app/api/costs/calculate/route.ts` — how products+recipes+ingredients are shaped for `analyzeProducts`.
- `ventures/Toutsweet/platform/supabase/migrations/001_initial_schema.sql` — tables: `ingredients.current_cost_cents`, `recipes.quantity`, `products.price_cents` / `target_margin_pct` (default 60), `ingredient_price_history` (auto-logged), `cost_reports`.

## When to use
- A supplier/ingredient cost changed and you need the margin + price fallout.
- Producing/refreshing a weekly `cost_reports` row (with `price_suggestions`).
- Auditing which active products dropped below their `target_margin_pct`.

## The model — mirror it exactly (all cents, all integers)
```ts
calculateProductCOGS(ings) = Σ Math.round(quantity * current_cost_cents)
calculateMargin(price, cogs) = price === 0 ? 0 : Math.round(((price - cogs) / price) * 10000) / 100
suggestPrice(cogs, targetPct) = Math.ceil( (cogs / (1 - targetPct/100)) / 50 ) * 50   // round UP to nearest 50¢
// alert when: margin_pct < target_margin_pct
```
`current_cost_cents`, `price_cents`, `cogs_cents`, `total_*_cents` are **integers**.
Never introduce a float dollar amount into a stored value. Convert dollars only
at the edge with `Math.round(dollars * 100)`, and only for display use
`formatCents(cents)`.

## Workflow
1. **Snapshot the catalog.** Get the current products+recipes+ingredients in the
   `analyzeProducts` input shape. Either save the JSON response of the authed
   `GET /api/costs/calculate`, or dump it from Supabase:
   ```sql
   select p.id, p.name, p.category, p.price_cents, p.target_margin_pct,
          json_agg(json_build_object(
            'id', i.id, 'name', i.name, 'unit', i.unit,
            'current_cost_cents', i.current_cost_cents, 'quantity', r.quantity)) as ingredients
   from products p
   join recipes r on r.product_id = p.id
   join ingredients i on i.id = r.ingredient_id
   where p.is_active = true
   group by p.id;
   ```
   Save as `catalog.json` (array of products, each with an `ingredients` array).
2. **Write the cost updates** as `cost-updates.json`:
   ```json
   [
     { "ingredient": "Dulce de Leche", "new_cost_cents": 450 },
     { "ingredient_id": "…uuid…",      "new_cost_cents": 1290 }
   ]
   ```
   Match by `ingredient_id` (preferred) or case-insensitive `ingredient` name.
   Values MUST be integer cents. (A `new_cost_dollars` key is accepted and
   converted with `Math.round(d*100)`, but cents is canonical.)
3. **Run the analysis (read-only):**
   ```bash
   node ~/.claude/skills/cost-engine-updater/scripts/costs-report.mjs \
     --catalog catalog.json --updates cost-updates.json
   ```
   You get: the per-ingredient change (with `calculateCostChange` direction),
   a per-product COGS/margin table, below-target **alerts**, and price
   **suggestions** rounded up to the nearest 50¢.
4. **Emit the report artifacts** you need:
   - `--json` → machine JSON (mirrors `analyzeProducts` return: `products`, `suggestions`, `totalRevenuePotential`, `averageMargin`, `alertCount`).
   - `--cost-report` → a `cost_reports`-row-shaped JSON block ready to insert (`total_revenue_cents`, `total_cogs_cents`, `price_suggestions`).
   - `--emit-sql` → prints the `UPDATE public.ingredients SET current_cost_cents=… WHERE id=…;` statements. **Dry-run: printed, never executed.** Applying them fires the `on_ingredient_price_change` trigger, which auto-writes `ingredient_price_history` — good, that's the audit trail.
5. **Apply** the ingredient updates yourself (SQL editor / migration) only after
   reviewing the printed SQL. Then persist the `cost_reports` row if wanted.

## Real snippet — what the script computes
For a product priced at `price_cents: 2800` whose recipe COGS recomputes to
`1400` at a `target_margin_pct: 60`:
```
margin = round(((2800-1400)/2800)*10000)/100 = 50.0%   → BELOW target 60%
suggest = ceil((1400/(1-0.60))/50)*50 = ceil(3500/50)*50 = 3500  → raise $28.00 → $35.00
```

## Ecosystem gotchas
- **Two different `price_suggestions` shapes.** `cost-engine.ts` emits
  `current_price_cents` / `suggested_price_cents`, but the admin Reports page
  (`admin/reports/page.tsx`) reads `current_cents` / `suggested_cents`. The
  stored `cost_reports.price_suggestions` JSON must use the **Reports-page**
  keys or the UI shows blanks. `--cost-report` output already uses the
  Reports-page keys; `--json` mirrors the engine keys. Don't mix them.
- **`quantity` is `decimal`, cost is integer cents.** COGS uses
  `Math.round(quantity * current_cost_cents)` per line — round per-ingredient,
  exactly as the engine does; don't sum floats then round once.
- **`target_margin_pct` defaults to 60** and can be null on older rows — the API
  route coerces `|| 60`; do the same.
- **Only `is_active = true` products** feed the analysis (see the API route
  filter). Don't report on inactive SKUs.
- **Updating a cost is auto-audited.** The `on_ingredient_price_change` trigger
  logs to `ingredient_price_history` on any `current_cost_cents` change — never
  hand-insert history rows.
- **This is Next.js with breaking changes** (`platform/AGENTS.md`): read
  `node_modules/next/dist/docs/` before touching route/server code. The helper
  script here is plain Node and touches nothing in the app.
