---
name: media-pipeline
description: Unified helper for the recurring Gilded Edge media chores — transcode/rename video, extract WebP/JPEG scroll-player frames, transcribe/caption audio to SRT/VTT, and optimize images to responsive WebP/AVIF with a ready-made srcset. Replaces the scattered ad-hoc .mjs/.sh scripts in edge-os-works, photo-film-works, aria-agent, and lumier-pictures. Use whenever someone says "transcode this video", "extract frames", "compress/optimize images", "make WebP/AVIF", "generate a srcset", "add captions/subtitles", "transcribe this audio", "convert to mp4/webm", or "shrink these assets". No Homebrew assumed: finds ffmpeg (system or the ffmpeg-static npm package), whisper/faster-whisper, and sharp — falling back to macOS `sips` like photo-film-works. Dry-runs by default; add --run to execute.
---

# Media Pipeline

One script, `scripts/media.sh`, for the media chores that keep getting
re-implemented across the ecosystem. It **prints the commands it would run and
writes nothing** unless you pass `--run`, and it **degrades gracefully** when a
tool is missing (this machine has no ffmpeg/whisper; it says exactly what to
install).

## When to use

- "Transcode / convert this video to mp4/webm," "re-encode," "rename output."
- "Extract frames" for a scroll-driven canvas player (the edge-os-works pattern).
- "Optimize / compress these images," "make WebP/AVIF," "generate a srcset."
- "Transcribe this," "add captions/subtitles," "make an SRT/VTT."

Replaces: `edge-os-works/extract-frames.mjs` + `seedance/extract-frames-4k.mjs`,
`photo-film-works/optimize-images.sh`, and the ad-hoc ffmpeg calls in
`aria-agent` / `lumier-pictures`.

## First: check the toolchain

```bash
bash scripts/media.sh check
```
Reports what's available and how to install what isn't. On the current machine:
ffmpeg ✗, whisper ✗, sharp ✓ (via edge-os-works), sips ✓.

## Commands (all dry-run unless `--run`)

```bash
# metadata
bash scripts/media.sh probe input.mp4

# transcode / rename  (h264 mp4 default; also webm/vp9, mov/prores)
bash scripts/media.sh transcode input.mov --to mp4 --crf 20 --scale 1920:1080 --out hero.mp4 --run

# frames for a scroll player  (WebP q85 @ 12fps — the edge-os-works recipe)
bash scripts/media.sh frames hero.mp4 --fps 12 --scale 1920:1080 --format webp --out public/frames --run
#   -> prints the totalFrames / frameExt to paste into ScrollCinematicLoader.tsx

# captions  (whisper / faster-whisper / whisper.cpp)
bash scripts/media.sh transcribe hero.mp4 --model base --format srt --out captions --run

# responsive images  (sharp -> WebP + AVIF; falls back to sips -> WebP only)
bash scripts/media.sh optimize assets/images --widths 400,800,1200 --format webp,avif --out optimized --run
#   -> also prints a ready <img srcset ...> snippet
```

## How tool discovery works (no Homebrew)

- **ffmpeg** — uses a system `ffmpeg` if present; otherwise resolves the
  `ffmpeg-static` npm binary from `edge-os-works` / `aria-agent` /
  `lumier-pictures` node_modules, exactly like `extract-frames.mjs` does. If
  neither exists it stops and tells you: `brew install ffmpeg` **or**
  `cd ventures/edge-os-works && npm i ffmpeg-static`.
- **whisper** — checks `whisper`, `whisper-cli`, `whisper-cpp`, `faster-whisper`,
  then `python3 -m whisper`. whisper.cpp gets a 16 kHz mono WAV extracted first
  (via ffmpeg) since it needs one.
- **images** — prefers `sharp` (libvips) resolved from a venture's node_modules
  → true WebP **and** AVIF. With no sharp, falls back to macOS `sips` → WebP
  only (AVIF unsupported by sips), the same tool `photo-film-works` uses.

Override the ecosystem root with `GILDED_ECO=/path bash scripts/media.sh ...`.

## Files

- `scripts/media.sh` — the dispatcher. bash 3.2 safe. `check | probe | transcode | frames | transcribe | optimize`.
- `scripts/sharp-optimize.cjs` — the sharp worker invoked by `optimize`. Reads
  `SRC/OUTDIR/WIDTHS/FMTS/Q` from env (zero shell-quoting risk); called with
  `NODE_PATH` pointed at the venture that has sharp.

## Gotchas

- **Dry-run is the default.** Nothing is written without `--run`. The dry-run
  prints the exact command so you can eyeball flags before committing.
- **ffmpeg-static ships no ffprobe.** `probe` uses system `ffprobe` if present,
  else parses `ffmpeg -i` output for Duration/Stream lines.
- **WebP frames need libwebp** in the ffmpeg build. If `--format webp` fails,
  re-run with `--format jpg` (the frames command notes this; the original
  extract-frames.mjs has the same fallback).
- **sips can't do AVIF** and can't build a real multi-format srcset — it only
  resamples to WebP per width. For AVIF, install sharp in any venture
  (`npm i sharp`) and the script auto-prefers it.
- **NODE_PATH, not cwd.** Node resolves `require('sharp')` relative to the
  worker file, so the script passes `NODE_PATH=<venture>/node_modules` — don't
  "simplify" it to a bare `cd`.
- **Percent/quality:** `--quality 82` is the JPEG/WebP quality; AVIF is derived
  at `quality-12` in the sharp worker to keep file sizes comparable.
- **Paths are absolutized** before handing off to the sharp worker, so relative
  inputs/outputs work regardless of which directory the worker runs in.
