---
name: dimora-design-system
description: Dimora Private's obsidian-and-gold design doctrine for UHNW estate-management software. Use when building or reviewing any Dimora UI (platform modules, dashboard, marketing pages) — tokens, typography, glass bands, hairline grids, queue urgency edges, schedule/date-chip patterns, and the motion budget. Enforces CSS Modules, no inline styles, and the "Dimora" naming rule.
---

# Dimora Design System

Cinematic luxury for UHNW estate management: **obsidian black + gold + white,
restraint over spectacle**. The reference implementation is
`ventures/dimora-private` — `app/globals.css` (tokens), `components/ui.tsx` +
`ui.module.css` (shared kit), `app/platform/dashboard.module.css` (composition).

## Naming rule (hard)

User-facing strings say **Dimora** — never "DOMUS" / "DOMUS AI". DOMUS survives
only in code comments, `/api/domus/*` paths, and strategy docs.

## Tokens (`app/globals.css`)

- Surfaces: `--paper #0a0a0b` → `--paper-2 #131315` → `--paper-3 #1b1b1f`
- Ink: `--ink #f5f5f4`, `--ink-2` 74%, `--ink-3` 50%
- Gold: `--gold #d4af37`; **`--gold-deep #e8c766` is the LIGHTER gold** (hover/highlights);
  `--gold-wash` rgba(212,175,55,.12)
- Lines: `--line` rgba(212,175,55,.2), `--line-soft` rgba(245,245,244,.1)
- Theme-relative: `--glass`, `--glass-strong`, `--wash`, `--wash-border`, `--spec`
  (specular edge on glass), `--grain-opacity` — components use these, never raw
  white/black rgba, so both themes work without per-component forks
- Sky: `--sky-a/b/c` — set per `data-theme` × `data-time` in globals.css
- Alert colors: ember `#e07a5f`, amber `#e5c07b`, green `#9ccfa4` — pills and
  status only, never large surfaces. **On light theme they deepen** for AA:
  `#b0492e` / `#96700f` / `#35743f` (overrides live beside the base rules)
- Radius scale: **0 structural · 1px glass cards · 2px controls · 999px pills**

## Themes & Atmosphere (added 2026-08-05)

- Obsidian is the default and the brand face; **light is warm ivory `#f4f1ea`,
  never clinical white** — gold deepens to `#a9821f` for contrast, glass turns
  to frosted porcelain
- The Atmosphere (`components/Atmosphere.tsx`) is the platform's living
  background: three soft orbs drifting on transform-only 90–120s orbits (no
  blur filters — the gradients carry the softness), **god-ray beams** sweeping
  on 130–200s alternate-direction orbits (gradient strips, elliptical-mask
  softened edges, `mix-blend-mode: screen`, tinted by `--beam-a/b`),
  a static SVG-turbulence grain veil, and a vignette. **Pointer parallax**:
  orbs lerp ~14px toward the cursor, beams counter-drift — fine-pointer only,
  rAF-lerped, skipped on touch/reduced-motion. Wrapper `.field` divs have
  `inset: -4vmax` bleed so parallax never exposes an edge
- The sky follows **the actual New York sun** (solar chapters, see Auto mode
  below), re-checked every minute. Chapter changes **morph, never snap**:
  `--sky-*` and `--beam-*` are `@property`-registered `<color>`s with a 1200s
  `:root` transition — a chapter flip washes across the sky over ~20 minutes
  like real light (browsers without @property swap instantly — the graceful
  floor). When QA-ing a 1200s transition, shorten the curve inline first; at
  3s into 1200s the interpolation rounds to the start value and looks "broken"
- Theme state: `data-theme` + `data-time` on `<html>`; preference persists in
  `localStorage['dimora-theme']`; `?theme=` and `?sky=` URL params override
  for QA and sharing
- **Solar Auto mode (default)**: the toggle is Night / Auto / Day. Auto computes
  sunrise/sunset daily (NOAA-lite, NYC 40.7°N, noon 12.5 ET — `sunTimes()` in
  Atmosphere.tsx) and flips the theme at the sun's own schedule; manual
  Night/Day always wins and persists. Chapters are solar too: dawn =
  sunrise−0.5h→+1h, day → sunset−1.5h, **dusk starts 1.5h BEFORE sunset** so the
  approach glows orange before night falls, night after sunset+0.5h
- **Theme flips cross-fade, never snap**: the core palette tokens (`--paper*`,
  `--ink*`, `--gold*`, `--line*`, `--glass*`, `--wash*`, `--spec`) are
  `@property`-registered `<color>`s with `transition: … var(--theme-fade)` on
  `:root`. Atmosphere sets `--theme-fade` inline: **0.6s for a manual tap,
  240s when the sun flips it** — evening settles in over four minutes
- **Boot guard (hard-won)**: Chromium transitions registered properties FROM
  their `@property initial-value` on first style resolution — without a guard,
  every page load morphs for 20 minutes out of the night-dark defaults (a grey
  smudge on ivory in daylight). The anti-flash script sets `data-sky-boot` on
  `<html>` (`:root[data-sky-boot] { transition: none }`); Atmosphere clears it
  after the first painted frame. The same script must compute data-theme AND
  data-time pre-paint with the same solar math — keep layout.tsx and
  Atmosphere.tsx in sync. `<html>` carries `suppressHydrationWarning` for this
- Anti-flash: `next/script beforeInteractive` in the ROOT layout, **path-guarded
  to `/platform|/demo`** so marketing never inherits the preference. NEVER put
  a raw `<script>` in a server component — React refuses it and it kills
  hydration (real incident, 2026-08-05)
- **Theme-invariant ink on gold**: `--on-gold: #241c05` — gold stays gold in
  both themes, so text on a gold fill never flips. Never `color: #0a0a0b` on
  gold (24 sites swept 2026-08-05)
- **Light-theme orbs**: `mix-blend-mode: screen` — a cool tint may only ADD
  light on ivory; dark-blob-on-paper is structurally impossible
- **Sweep rule**: any raw white/black `rgba(255…/rgba(0…` or hardcoded hex ink
  in a module CSS is a light-mode bug waiting to ship — map it to a token
  (~235 literals across 20 modules swept 2026-08-05). Gold washes
  `rgba(212,175,55,≤0.12)` survive in both themes by hue; prefer
  `var(--gold-wash)` / `var(--line)` for new work. Match `color-scheme` to the
  theme or native controls (selects, date inputs, scrollbars) glare dark on
  ivory
- The toggle lives in the sidebar footer on desktop and re-surfaces as a fixed
  frosted chip at ≤820px (sidebar footer hides). In shrink-to-fit fixed
  containers use `flex: 1 1 auto`, never `flex: 1` — basis 0 collapses the chip

## The one doctrine

**Gold marks singularity.** One hero number, one rule under a table header, one
active nav item, one hairline track. Everything that repeats divides with ink
hairlines (`--line-soft`), not gold. Never two gold focal points in one viewport.
Ember means "a person must act" (overdue rows, not-ready flags) — it never touches
the brand centerpiece, even when the state is alerting.

## Typography

- `--display` (Bodoni Moda, next/font in `app/layout.tsx`): **h1 and hero
  numerals only** — hairlines get fragile below ~28px
- `--serif` (Iowan Old Style/Palatino stack): all other headings, stat values,
  date chips. Italic serif for the qualifier beside a hero number
  ("of 7 residences")
- `--sans`: body, labels, tables
- Numerals in stats/hero/dates: `font-variant-numeric: tabular-nums`
- Eyebrows/section titles: `--step-back`, letter-spacing .14–.18em, uppercase,
  gold-deep. Hero eyebrow gets a 26px gold dash leader

## Component patterns (copy from, don't reinvent)

| Pattern | Where | Rule |
|---|---|---|
| Glass band | `.hero` | rgba(10,10,11,.58) + blur(14px) saturate(115%), one gold hairline top edge (gradient fading right), radial gold wash at 10% -10% |
| Stat band | `.statGrid/.statCard` | 1px-gap hairline grid over glass; hover draws a gold hairline from the left (`::after` scaleX); optional 17px stroke icon, top-right, gold at 75% |
| Section | `.section` | hairline-topped zone, never a boxed card; `.sectionHead` = title + right-aligned aside (counts/links) |
| Table | `.table` | gold rule under `thead` only; row hover = 2% white wash + 2px gold inset edge on first cell |
| Queue urgency | dashboard `.rowOverdue/.rowToday` | persistent inset edge: ember = overdue, gold = due today |
| Pills | `.pill` + tones | the ONLY deliberately round shape besides avatar/checkbox |
| Liquid gold | `.actionApprove`, `.demoBarCta` | molten 250%-size gradient that flows on hover + travelling specular sheen + gold halo; ink `#241c05` text; one gold act per row — reject stays quiet graphite |
| Glass panel | dashboard `.panel` | frosted wrap for operational tables: `var(--glass)` + blur(14px) + `inset 0 1px 0 var(--spec)` specular top edge |
| Schedule | `.schedule` + `.dateChip` | serif day numeral (gold-deep) over 3-letter month, hairline box 46px |
| Readiness fills | `.heroTrackFill/.readinessFill` | hairline (2–4px), stepped `data-width` 10–100 → `transform: scaleX()`; gradient `#8a6d1f → gold → gold-deep` |
| WaxSeal | `components/WaxSeal.tsx` + `.sealBtn` | the signature gesture: HOLD 850ms while molten gold fills the button, then a wax "D" seal stamps down (squash + shockwave ring) and the form submits. Early release settles, never fires. Pointer clicks must NOT submit (guard with a fromPointer ref — a click after a cancelled hold is a non-event); keyboard/reduced-motion seal instantly. Demo mode: seal for real, withhold only the mutation, show an italic "in the live house…" note |
| Sunday Brief | `app/platform/brief/` | the owner's one page: letter not dashboard — centered masthead (tracked wordmark + italic serif edition + gold rule), THE number in Bodoni gold, hairline-row blocks, colophon. Print = stationery: `@page` margins, chrome hidden, `:root` tokens hard-reset to ink-on-paper, `break-inside: avoid` per block. **globals.css print hides every `header`/`footer` — a letter's masthead must re-declare `display: block !important`** |

## Motion budget

- **One authored moment per page.** The platform's is the staggered content rise
  in `platform.module.css` (45ms steps, `--dur-med 420ms`, `--ease-out`)
- **The WaxSeal is the exception that proves the rule** — a signature gesture
  may hold the stage for ~1.4s because it IS the brand moment (hold 850ms +
  stamp 520ms). One per action, never decorative
- Fill tracks get one slow light sweep (`trackSheen`, 3.6s) — nothing else loops
- Hover: 160ms (`--dur-fast`); active press: `translateY(1px)`
- `prefers-reduced-motion` neutralizes everything globally — never add animation
  that carries information

## Code rules (ecosystem-wide, enforced in review)

- CSS Modules only — **no Tailwind, no inline styles**. Variable widths use
  stepped `data-*` attributes (see `readinessFill[data-width]`), never `style=`
- React Server Components; shared kit in `components/ui.tsx` stays client-safe
  (no server-only imports)
- Preserve existing comments/docstrings; comments carry doctrine, keep them current
- Two themes, one code path: use theme-relative tokens (`--glass`, `--wash`,
  `--ink-3`…); raw `rgba(255,255,255,…)` / `rgba(10,10,11,…)` in component CSS
  is a light-mode bug waiting to ship. Status hues get `:root[data-theme='light']`
  deepening overrides beside the base rule
- Demo/live honesty: demo mode renders the fictional portfolio and says so;
  readiness-style meters show real counts only, never seed data; demo links
  stay inside `/demo` (base-aware hrefs — a `/platform/*` link in the demo
  307s to login); demo shows approval buttons inert-disabled, never hidden

## Living scenes (WeatherSky pattern, 2026-08)

`components/WeatherSky.tsx` renders a pure-CSS weather window per residence:
condition text → kind via `weatherKind()` (most-severe first: thunder→storm,
rain, snow, fog, overcast→cloudy, partly, else clear) → scene layers
(sun with rotating conic rays / moon+stars at `data-time='night'`, drifting
gradient clouds, two-depth rain streaks, storm lightning on a 9s cycle, snow,
fog banks, gold horizon hairline).

Hard-won rules:

- **Pass the kind as `data-kind`, never a class modifier.** Layer class names
  like `styles.rain`/`styles.snow` collide with a `styles[kind]` modifier of
  the same name in the CSS Module — the scene then inherits layer rules
  (`position:absolute; inset:-40%`) and renders off-screen. Modifier CSS only
  where safe: `.scene[data-kind='cloudy']`, `[data-kind='storm']`.
- **Sky particles need theme-aware tints.** Snowflakes must be blue-grey on
  ivory and near-white only under `:root[data-theme='dark']`; same for rain
  streak opacity — invisible-on-ivory is the default failure.
- **Demo weather requires seed lat/lng.** `seedProperties` without
  coordinates yields zero weather rows; every seed residence carries
  plausible coordinates (NYC, Litchfield, Greenwich, Boca, Sagaponack, Aspen).
- QA override URL params: `?theme=`, `?sky=dawn|day|dusk|night`, `?hour=`.

## Review checklist

1. Exactly one gold focal point per viewport?
2. Didone only at h1/hero-numeral scale?
3. Any inline styles or Tailwind? (reject)
4. New fill/bar → stepped data-width, sheen animation, hairline not block?
5. Alert colors confined to pills/dots/edges, deepened on light?
6. "Dimora" in every user-facing string?
7. Theme-relative tokens only — does it hold up in ivory?
8. Raw `<script>` in an RSC? (reject — next/script beforeInteractive, path-guarded)
