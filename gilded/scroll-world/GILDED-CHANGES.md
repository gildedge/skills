# Gilded 10x pack — changes vs the cth9191/scroll-world fork

This directory vendors [cth9191/scroll-world](https://github.com/cth9191/scroll-world)
(MIT — see `LICENSE`, preserved unmodified; that fork's own delta vs oso95/scroll-world
is `FORK-CHANGES.md`, also preserved). This file records everything the Gilded Edge
ecosystem added on top. The additions are **additive**: all upstream references,
doctrine (anchor gate, previz tier, SSIM seam gate, actual-frame handoffs, budget
tiers, mobile tiers), scripts, and engine behavior are intact and unmodified except
for the three minimal SKILL.md edits listed below.

## New files (all Gilded additions)

| File | What it adds |
|---|---|
| `references/providers.md` | **Provider abstraction** — the pipeline no longer requires Higgsfield. Matrix mapping every generation step (stills, dives/legs with start-image, connectors with start+end image) onto Higgsfield CLI, fal.ai (`FAL_KEY`, Seedance 2.0 i2v — the ecosystem default, mirroring `edge-os-works/seedance/generate-cinematic.mjs`: `bytedance/seedance-2.0/image-to-video` + `/fast/` tier, `image_url`/`end_image_url`, `fal.storage.upload`), Replicate (`REPLICATE_API_TOKEN`, schema-check before promising arch B), and Gemini/Imagen+Veo (`GEMINI_API_KEY`, honestly marked architecture-A-only unless last-frame conditioning is verified). Includes a runnable `@fal-ai/client` runner with built-in dry-run/`--run` cost guard, env-key checks that never print values, and a cost-preflight section consistent with the `cinematic-render-pipeline` skill (planning rate table, estimate formula, explicit go-ahead required before any paid call). |
| `references/frame-scrub-engine.js` | **Frame-atlas render mode** — self-contained vanilla-JS canvas frame-sequence scrubber (the technique Apple ships): preloaded WebP frames drawn to canvas by scroll position. No seekability issues, immune to iOS Low Power Mode, perfect reverse scrub. Same config shape as `scrub-engine.js` (sections, nullable connectors, `scroll`/`linger` pacing, `scrollMobileFactor`, phone-class sequence tiering, reduced-motion/data-saver stills fallback, `data-sw-seo` passthrough, same `--sw-*` theme variables). `node --check` clean. |
| `references/frame-atlas.md` | When to choose frames vs video (honest byte-cost tradeoff — video-first recommended; frames for hero pages or when QA shows stutter), the ffmpeg extraction + WebP recipe (bash 3.2 safe, idempotent, ffmpeg-static discovery per the media-pipeline skill since this machine has no system ffmpeg), portrait tier, config wiring, and QA deltas. Names `edge-os-works` `useScrollFrame.ts`/`ScrollCinematic.tsx` as the in-repo React precedent. |
| `references/gilded-presets.md` | The house design language (obsidian `#0A0A0B` + gold `#D4AF37`, glassmorphism, cinematic luxury) as a scroll-world style preamble + palette + engine theme block, plus 4 ready world recipes — lumier-pictures (film production), gilded-travel-works (luxury city/yacht/jet), Toutsweet (Peruvian bakery), gilded-art-works (gallery/logistics) — each with 4-scene lean and 6-scene showcase journeys, camera-grammar picks from the Step 4 table, and eyebrow/title/body copy starters. Recipes never skip the interview gates. |
| `references/export-targets.md` | (1) Next.js App Router integration — thin client wrapper (`dynamic`, no SSR for the engine) with the `data-sw-seo` block server-rendered, matching edge-os-works conventions; (2) self-contained single-file HTML builds with honest size/CSP caveats; (3) storyboard exports — slide-by-slide mapping of stills + copy to the pptx/pdf skills for pitch decks and one-pagers (also the cheap "stills-only sign-off before video spend" path). |
| `GILDED-CHANGES.md` | This changelog. |

## Edits to existing files (minimal, SKILL.md only)

1. **Frontmatter `description`** — extended so triggering covers "make our site
   scroll like Apple's", "scroll cinematic for <venture>", scrollytelling phrasing,
   provider-agnostic wording (works without Higgsfield), and the frame-atlas mode.
   `name: scroll-world` unchanged.
2. **Step 0 — Bootstrap** — item 1's hard Higgsfield requirement replaced with
   provider selection (detect `higgsfield` CLI → `FAL_KEY` → `REPLICATE_API_TOKEN` /
   `GEMINI_API_KEY`; points to `references/providers.md` and its cost preflight).
   Item 2's ffmpeg line now notes discovery via media-pipeline conventions (system
   ffmpeg OR the `ffmpeg-static` npm binary; ffmpeg-static ships no ffprobe).
3. **Step 7 — Assemble the page** — added a short "Two engines — pick per page"
   paragraph pointing at `frame-scrub-engine.js` / `frame-atlas.md` /
   `export-targets.md`; the step's video-engine content is untouched.
4. **References section** — appended the five Gilded reference files under a
   "Gilded additions" subheading.

No other upstream file was modified. `references/pipeline.md`, `prompts.md`,
`gotchas.md`, `scrub-engine.js`, `index-template.html`, `knockout.py`,
`FORK-CHANGES.md`, and `LICENSE` are byte-identical to the vendored fork.

## Doctrine unchanged (on purpose)

- Anchor-still gate before batching; previz-first on 5+ scene runs.
- Frame handoffs from rendered clips, never stills; SSIM seam gate before browser QA.
- One model (and now: one provider) for the whole chain.
- Budget/mobile tier interview questions; spend estimate + explicit approval before
  generation — now stated in dollars when a non-Higgsfield provider is used.
- bash 3.2 safety everywhere; secrets are checked for presence only, never printed.
