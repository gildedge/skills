---
name: cinematic-render-pipeline
description: One orchestrator for edge-os-works's cinematic video pipeline — replaces the scattered generate-video.mjs / generate-cinematic.mjs / test-veo.mjs / extract-frames*.mjs / generate-atlas.mjs scripts with a single staged flow (screenshots/frames → Remotion or Seedance i2v → Veo t2v → stitch → LFS-tracked output). Its headline job is a COST PRE-FLIGHT GUARD before any paid generative call (Veo via @google/genai, Seedance/fal via @fal-ai/client, or Replicate): it validates params, checks the required API key is present, and prints an estimated spend — and REFUSES to actually call a paid API unless you pass --run. Use whenever someone says "generate the cinematic", "run the video pipeline", "render the edge-os commercial", "seedance / veo / fal generation", "how much will this cost", "stitch the scenes", "extract frames and build the atlas", "track the output in LFS", or is about to run one of those loose .mjs scripts. Delegates the low-level frame/transcode/concat work to the media-pipeline skill instead of reimplementing ffmpeg. Bash 3.2 safe, GILDED_ROOT override, dry-run/plan by default.
---

# Cinematic Render Pipeline

The edge-os-works cinematic flow is currently a pile of one-off scripts
(`generate-video.mjs`, `seedance/generate-cinematic.mjs`, `test-veo.mjs`,
`extract-frames.mjs`, `seedance/extract-frames-4k.mjs`,
`seedance/generate-atlas.mjs`). This skill wraps them in **one staged
orchestrator** with a **cost pre-flight guard** so nobody fires a paid Veo/fal
job by accident.

**Everything is a plan/dry-run by default. No paid API is called, and nothing is
written, without `--run`.** The single most important feature is the
`preflight` gate in front of every paid stage.

## The pipeline stages

```
 0. screenshots  →  capture real dashboard PNGs  (public/, edge-commercial/public/)
 1. frames       →  extract WebP/JPEG scroll frames   [delegates to media-pipeline]
 2a. remotion    →  deterministic, FREE composited render  [remotion-composition-builder]
 2b. seedance    →  PAID image→video (fal, first/last-frame continuity)  ⚠ guarded
 3. veo          →  PAID text→video (Google Veo 3.x)  ⚠ guarded
 4. stitch       →  concat clips + transcode          [delegates to media-pipeline]
 5. atlas        →  sprite atlas for the scroll player [delegates to media-pipeline frames]
 6. lfs          →  git-lfs track + add the .mp4 output
```

Prefer **2a (Remotion)** when the shot is UI/screenshot compositing — it's free
and deterministic (use the `remotion-composition-builder` skill). Reach for
**2b/3 (Seedance/Veo)** only for genuinely generative footage.

## Quick start — always preflight first

```bash
bash scripts/render-pipeline.sh check                 # toolchain + which keys are present
bash scripts/render-pipeline.sh plan                  # print the whole staged plan, no spend

# COST GUARD — validates params, checks key, prints $ estimate, does NOT spend:
bash scripts/render-pipeline.sh preflight seedance --scenes 5 --duration 5 --model seedance-2.0
bash scripts/render-pipeline.sh preflight veo --scenes 5 --duration 5 --model veo-3.0

# Only with --run does it actually invoke the paid script:
bash scripts/render-pipeline.sh seedance --scenes 5 --duration 5 --run
bash scripts/render-pipeline.sh veo --scenes 5 --run

# Free / local stages (still dry-run until --run for the ones that write):
bash scripts/render-pipeline.sh frames output/edge-cinematic.mp4 --fps 12 --run
bash scripts/render-pipeline.sh stitch output/scene*.mp4 --out output/edge-cinematic.mp4 --run
bash scripts/render-pipeline.sh lfs output/edge-cinematic.mp4 --run
```

`GILDED_ROOT=/path` overrides `~/GILDED-EDGE-ECOSYSTEM`.

## The cost pre-flight guard (the point of this skill)

`preflight <seedance|veo|replicate> [flags]` runs BEFORE any spend and checks
three things, refusing to continue on any failure:

1. **Params valid** — scenes ≥ 1, duration in the model's allowed range, model
   id is one this skill knows, required input assets exist for i2v.
2. **Key present** — the required env var is set (NEVER printed):
   - Seedance/fal → `FAL_KEY`
   - Veo → `GEMINI_API_KEY` (the `@google/genai` path in `generate-video.mjs` /
     `test-veo.mjs`)
   - Replicate → `REPLICATE_API_TOKEN`
3. **Estimated cost** — prints a spend estimate from a built-in rate table
   (`scenes × duration × per-second rate`) and the total, e.g.
   `5 scenes × 5s × $0.50/s ≈ $12.50 (Seedance 2.0)`.

The paid stages (`seedance`, `veo`, `replicate`) **call `preflight` internally
and then hard-stop unless `--run` is present.** So the default of every paid
command is: show the estimate, confirm the key, and exit 0 without spending.

> Rates are rough planning figures kept in the script's `RATE_*` table — treat
> them as an order-of-magnitude guard, not a billing source of truth. Update the
> table when a provider's pricing changes.

## Grounded provider details (from the real scripts)

- **Seedance (fal)** — `seedance/generate-cinematic.mjs`: `@fal-ai/client`,
  `fal.config({ credentials: FAL_KEY })`, model
  `bytedance/seedance-2.0/image-to-video` (or `/fast/` with `--fast`),
  `fal.subscribe(model, { input:{ prompt, image_url, duration, end_image_url } })`,
  uploads local PNGs via `fal.storage.upload`. Uses **first-frame/last-frame
  continuity** (last frame of scene N = first frame of N+1) for the infinite
  scroll loop.
- **Veo (Google)** — `generate-video.mjs` / `test-veo.mjs`: `@google/genai`
  `new GoogleGenAI({ apiKey: GEMINI_API_KEY })`,
  `ai.models.generateVideos({ model:'veo-3.0-generate-001', prompt,
  config:{ aspectRatio:'16:9', numberOfVideos:1 } })`, then poll
  `ai.operations.get({ operation })` until `operation.done`. `test-veo.mjs` uses
  `veo-3.1-generate-001`. Falls back to `veo-3.0-fast-generate-001` on quota.
- **Frames / stitch / atlas** — the ffmpeg work in `extract-frames*.mjs` and
  `generate-atlas.mjs` is **delegated to the media-pipeline skill**
  (`scripts/media.sh frames|transcode`). This skill prints the exact
  `media.sh` command rather than shelling out to raw ffmpeg.

## Degrade gracefully

- **No `FAL_KEY` / `GEMINI_API_KEY`** → preflight reports the key missing and
  stops; it never proceeds to a paid call. (Expected on a fresh machine.)
- **No ffmpeg** → the frame/stitch stages defer to media-pipeline, which itself
  finds `ffmpeg-static` in a venture's node_modules or tells you what to install.
- **No `@fal-ai/client` / `@google/genai` installed** → preflight notes the
  missing dep and prints the `npm i` line; still no spend.
- **No git-lfs** → the `lfs` stage prints the manual `git lfs track` commands.

## Gotchas

- **Dry-run / plan is the default; paid stages need `--run`.** Preflight alone
  never spends. This is the whole safety model — don't add a "just do it" flag.
- **Seedance is image→video** and needs the first-frame PNGs to exist in
  `seedance/assets/` (real dashboard screenshots). Preflight checks for them;
  missing assets are a hard stop before any upload/spend.
- **Veo is async + polled** — a run can take minutes and burns quota per
  attempt. The estimate counts *attempts*, and quota errors suggest the
  `-fast-` model, mirroring `generate-video.mjs`.
- **Output goes to LFS, not plain git.** edge-os-works has `.gitattributes`;
  `.mp4`/large frames must be `git lfs track`-ed. The `lfs` stage enforces this
  so you don't commit a 40 MB mp4 to regular git history.
- **Don't reimplement ffmpeg here.** Frames, transcodes, and concat are the
  media-pipeline skill's job — this orchestrator only sequences and guards.
- **Rate table is an estimate**, not a bill. Re-check provider pricing before a
  large batch.

## Files

- `scripts/render-pipeline.sh` — the orchestrator. bash 3.2 safe.
  `check | plan | preflight | screenshots | frames | remotion | seedance | veo |
  replicate | stitch | atlas | lfs`. Dry-run/plan default; `--run` required for
  any write or paid call. `GILDED_ROOT` override. Never prints key values.
