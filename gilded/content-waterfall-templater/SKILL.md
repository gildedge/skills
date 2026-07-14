---
name: content-waterfall-templater
description: Expand one source script into aria-agent's 26-piece multi-platform content waterfall — the exact YouTube/Instagram/X/LinkedIn/TikTok/Newsletter breakdown that /api/waterfall produces — with per-channel formatting rules baked in. Use when someone says "run the waterfall", "1 script to 26 pieces", "atomize this script", "spin up the content set", "generate the derivative pieces", "waterfall this video", "content calendar from this script", or is building/extending aria-agent's waterfall route. Emits a deterministic plan (WaterfallPiece[] matching the aria_content table + 14-day calendar) offline with NO API key, then hands off the per-piece Gemini write step. Keeps the template and platform rules IN SYNC with the shipped route.
---

# Content Waterfall Templater

`aria-agent` already has the engine: `src/app/api/waterfall/route.ts` turns one source script into **26 platform-optimized pieces** and writes them to Supabase (`aria_content`, `aria_calendar`). This skill mirrors that engine so you can (a) generate the plan deterministically without hitting the DB or an API key, (b) extend the template without it silently drifting from the route, and (c) drive the per-piece Gemini write step.

**Keep this in sync with the route.** The template and platform rules below are copied verbatim from `waterfall/route.ts`. If you change the mix, change both. The GET handler of that route is the source of truth for the current template.

## The canonical 26-piece mix

| Platform | Count | Pieces |
|---|---|---|
| YouTube | 4 (1 source + 3) | Full Video (source), Hook Clip, Best Moment, Tutorial Extract |
| Instagram | 6 | Reel v1 (Hook), Reel v2 (Story), Key Takeaways Carousel, Behind the Scenes Story, Quote Card, Insight Graphic |
| X / Twitter | 5 | Deep-Dive Thread, Hook Tweet, Contrarian Take, Data Point, Question Hook |
| LinkedIn | 4 | Authority Post, Lesson Learned, Behind the Build, Native Video Clip |
| TikTok | 4 | Hook-First Edit, POV Style, Trend Remix, Stitch Bait |
| Newsletter | 3 | Weekly Deep-Dive, Quick Insights Digest, Personal Story Edition |

Total template = 26. When the source platform is `youtube` (default), the YouTube `Long-form` slot IS the source, so 25 derivative children are inserted and `waterfallCount` = 26.

## Data shape (matches `aria_content`)

Each derivative piece the route inserts:

```ts
{
  title: `${sourceTitle} — ${suffix}`,
  platform: 'youtube'|'instagram'|'x'|'linkedin'|'tiktok'|'newsletter',
  type: string,               // 'Reel' | 'Thread' | 'Short' | 'Post' | 'Deep-Dive' ...
  status: 'idea',             // pieces start as ideas; write_piece promotes to 'draft'
  parent_id: <source uuid>,   // links every child to the source video
  content_body: null,         // filled by the Gemini write step
  tags: [...userTags, 'waterfall', `from:${sourceTitle.slice(0,30)}`],
  scheduled_date: 'YYYY-MM-DD' // spread 2/day over 14 days
}
```

Scheduling: `Math.floor(index / 2) + 1` days out — two pieces per day starting tomorrow. The first 14 pieces also get `aria_calendar` rows with the platform brand color.

## Workflow

1. **Generate the plan (offline, deterministic, no key).** Prints the 25 derivative pieces + schedule + per-platform summary as JSON or a markdown calendar.
   ```bash
   node ~/.claude/skills/content-waterfall-templater/scripts/waterfall-plan.mjs \
     --title "How We Ship AI Films in 48h" --source-platform youtube --tags launch,ai \
     --format markdown
   ```
   Add `--json` (or `--format json`) to emit the exact `WaterfallPiece[]` array you can `insert()` into `aria_content`.
2. **Persist via the live route** (when the app is running) — this is what the UI does; the script is the offline mirror:
   ```
   POST /api/waterfall  { "action": "generate", "sourceTitle": "...", "sourceScript": "...", "tags": [] }
   ```
3. **Write each piece's body** with Gemini, honoring the per-channel rules:
   ```
   POST /api/waterfall  { "action": "write_piece", "pieceId": "<uuid>", "parentScript": "..." }
   ```
   The route builds the prompt from `getPlatformRules(platform, type)` (reproduced in `assets/platform-rules.ts`). Offline, `--print-prompts` emits the ready-to-send prompt for each piece so you can batch them through any Gemini caller.
4. **Check completion**: `POST /api/waterfall { "action": "status", "sourceId": "<uuid>" }` → `{ written, completion% }`.

## Per-channel formatting (verbatim from the route)

- **YouTube** — Hook in first 3s. Value-dense. Clear CTA. Retention-optimized.
- **Instagram** — Visual-first, mobile. Carousel = 5-7 slides, one insight each. Reel = 15-30s, hook-first, loop-friendly. Post = caption <150 chars, strong CTA.
- **X** — Thread = 8-12 numbered tweets, each standalone valuable, hook tweet is everything. Tweet = <280 chars, punchy, contrarian or data-driven, **no hashtags**.
- **LinkedIn** — Professional. Lead with insight, not pitch. Article = 800-1200 words with headers. Post = 200-300 words, personal-story format.
- **TikTok** — Max first-frame impact. Casual, relatable, trend-aware. Hook in 0.5s. Pattern interrupt.
- **Newsletter** — Deep-Dive = 1000-1500 words, structured, actionable. Digest/Story = 300-500 words, personal voice, one takeaway.

Platform brand colors (for calendar rows): youtube `#FF0000`, instagram `#C13584`, x `#1DA1F2`, linkedin `#0A66C2`, tiktok `#EE1D52`, newsletter `#C9A84C`.

## Gotchas

- **The route inserts 25 children, not 26** — the source counts as the 26th. Don't double-insert a YouTube Long-form.
- **`write_piece` uses `GEMINI_API_KEY` via raw REST** (`generativelanguage.googleapis.com/.../gemini-2.5-flash:generateContent?key=`), not the `@google/genai` SDK the chat route uses. Match whichever the route already uses; don't introduce a third calling convention (see the `gemini-structured-output` skill).
- **Source script is truncated to 5000 chars** in the write prompt (`sourceScript.slice(0, 5000)`). Very long scripts lose their tail — summarize first if the payoff is at the end.
- **`content_body` is null until written.** `status` stays `idea`; the write step promotes to `draft`. The calendar shows scheduled slots before bodies exist.
- **Tags carry provenance** (`from:<title-prefix>`) — keep that so pieces trace back to their source even if `parent_id` joins get messy.
- Newsletter isn't in the `ContentPiece.platform` union in some older type defs — it IS a valid platform here; widen the type if TS complains.
