# Frame-atlas render mode — canvas frame sequences instead of video scrubbing

Gilded addition (GILDED-CHANGES.md). This documents the second render engine,
`references/frame-scrub-engine.js`, and the extraction recipe that feeds it.
gotchas.md already names the technique ("Beyond video scrubbing"); this makes it a
first-class, wired-up option instead of a pointer.

**Everything upstream of the page is unchanged.** Stills, dives, connectors, frame
handoffs, encode, posters, and the SSIM seam gate (pipeline.md §1–§5c) all run exactly
as written — the frame sequences are extracted **from the encoded clips that already
passed the seam gate**, so seams stay frame-identical by construction. Only the paint
primitive swaps: `video.currentTime` → "draw frame i to a canvas".

## Video vs frames — pick per page (honest tradeoff)

| | `scrub-engine.js` (video) | `frame-scrub-engine.js` (frames) |
|---|---|---|
| Asset weight | **lighter** (~8 MB per 8s 1080p clip) | heavier (same clip at 12 fps ≈ 96 WebP frames, typically 1.3–2× the mp4 bytes; scales linearly with fps) |
| Scrub smoothness | decoder-seek bound; needs seek-coalescing + `-g 8`/`-g 4` tuning | **deterministic** — an image paint is an image paint; no seek latency, no pile-ups |
| Reverse scrub | seeks backward are the expensive direction | **identical cost both directions** |
| iOS Low Power Mode | blocks video entirely (engine falls back to stills) | **unaffected** — no `play()` gate on canvas |
| Seekability / hosting | needs blob loading (engine does it) | plain `<img>` fetches — works on any static host, progressive |
| Build tooling | encode only | encode + extract + count bookkeeping |

**Recommendation: video-first.** The video engine is lighter on bytes and the
hardening covers most pages. Reach for frames when:

- it's the **hero page** (flagship landing where scrub feel is the product),
- **QA shows stutter** the mobile encodes can't fix (Step 8 phone checklist, low-end
  devices, fast flicks),
- Low-Power-Mode users matter and stills-fallback isn't acceptable there,
- the host can't serve the page the way the blob loader wants and you'd rather ship
  plain images.

The in-repo precedent is `edge-os-works`: its landing cinematic is exactly this
technique — `src/components/cinematic/useScrollFrame.ts` (scroll→frame-index hook) +
`ScrollCinematic.tsx` (canvas cover-draw, 30-frame priority preload, batched
lazy-load, `/frames/frame-%03d.webp` + `/frames-mobile/` portrait tier), fed by
`seedance/extract-frames-4k.mjs`. `frame-scrub-engine.js` is the portable,
framework-free equivalent with the scroll-world chain math (per-segment `scroll`,
`linger`, null-connector crossfades, `data-sw-seo`) layered on.

## Extraction recipe (bash 3.2 safe)

Runs AFTER pipeline.md §5–§5c (encode + posters + green SSIM gate). Extract from
`$ASSETS/vid/*.mp4` — the encoded, gate-passed files — never from the raw downloads.

ffmpeg discovery per the media-pipeline skill conventions (this machine has **no
system ffmpeg**; the `ffmpeg-static` npm binary is the fallback):

```bash
FF="$(command -v ffmpeg || true)"
if [ -z "$FF" ]; then
  for v in edge-os-works aria-agent lumier-pictures; do
    c="$HOME/GILDED-EDGE-ECOSYSTEM/ventures/$v/node_modules/ffmpeg-static/ffmpeg"
    if [ -x "$c" ]; then FF="$c"; break; fi
  done
fi
if [ -z "$FF" ]; then
  echo "no ffmpeg: brew install ffmpeg  OR  (cd ~/GILDED-EDGE-ECOSYSTEM/ventures/edge-os-works && npm i ffmpeg-static)"
  exit 1
fi
# Note: ffmpeg-static ships no ffprobe — parse "$FF" -i output for duration if needed.
```

Extraction — 12 fps WebP is the proven recipe (edge-os-works ships it); idempotent
like the rest of the pipeline (skips a section whose frame dir is already populated):

```bash
FPS=12          # 12 smooth for scroll-scrub; 16–24 only for a hero page (bytes scale linearly)
FW=1920         # desktop frame width
for n in $NAMES; do
  d="$ASSETS/frames/$n"
  if [ -d "$d" ] && [ -n "$(ls "$d"/frame-*.webp 2>/dev/null)" ]; then echo "frames $n cached"; continue; fi
  mkdir -p "$d"
  "$FF" -v error -i "$ASSETS/vid/$n.mp4" \
    -vf "fps=$FPS,scale=$FW:-2:flags=lanczos" \
    -c:v libwebp -quality 82 -compression_level 4 "$d/frame-%03d.webp"
  echo "frames $n: $(ls "$d" | wc -l | tr -d ' ') frames, $(du -sh "$d" | cut -f1)"
done
i=0
for f in "$ASSETS"/vid/conn*.mp4; do
  [ -e "$f" ] || continue
  i=$((i+1)); d="$ASSETS/frames/conn$i"
  if [ -d "$d" ] && [ -n "$(ls "$d"/frame-*.webp 2>/dev/null)" ]; then echo "frames conn$i cached"; continue; fi
  mkdir -p "$d"
  "$FF" -v error -i "$f" -vf "fps=$FPS,scale=$FW:-2:flags=lanczos" \
    -c:v libwebp -quality 82 -compression_level 4 "$d/frame-%03d.webp"
done
```

If `libwebp` is missing from the ffmpeg build, fall back to `-c:v mjpeg -q:v 4` with
`.jpg` frames and `ext:'jpg'` in the config (same fallback as media-pipeline).

Mobile / portrait tier (optional — mirrors the video engine's tiers; the portrait
centre-crop is the edge-os-works recipe):

```bash
for n in $NAMES; do
  d="$ASSETS/frames-m/$n"; mkdir -p "$d"
  "$FF" -v error -i "$ASSETS/vid/$n.mp4" \
    -vf "fps=$FPS,scale=-1:1280:flags=lanczos,crop=720:1280" \
    -c:v libwebp -quality 78 -compression_level 4 "$d/frame-%03d.webp"
done
```

(For the hero-reframe / portrait-chain tiers, extract from the 9:16 renders instead —
pipeline.md §7. Same rule as posters: the frames must come from the encode/render the
device actually represents.)

## Wiring the config

Count the frames per directory (`ls "$ASSETS/frames/$n" | wc -l`) — the count goes in
the config; a wrong count truncates or freezes the tail of that segment:

```js
mountScrollWorldFrames(document.getElementById('world'), {
  brand: { name: 'BRAND' },
  diveScroll: 1.3, connScroll: 0.9,
  sections: [
    { id: 'farm', label: 'The Farms', still: 'assets/farm.webp',
      frames:       { path: 'assets/frames/farm/frame-',   count: 96, digits: 3, ext: 'webp' },
      framesMobile: { path: 'assets/frames-m/farm/frame-', count: 96, digits: 3, ext: 'webp' },
      accent: '#8FB98A', eyebrow: '…', title: '…', body: '…' },
    // …
  ],
  connectors: [ { path: 'assets/frames/conn1/frame-', count: 60, digits: 3, ext: 'webp' }, /* or null */ ],
});
```

Same knobs as the video engine: per-section `scroll`/`linger`, null connector slots
(direct crossfade), `scrollMobileFactor`, `data-sw-seo` block, `--sw-*` theme
variables (an existing theme block themes both engines). Posters are unnecessary —
frame 001 *is* the first paint; `still` remains the reduced-motion artwork and the
pre-load placeholder.

## QA deltas (Step 8)

Everything in SKILL Step 8 applies except the video-specific checks. Skip:
`video.seekable`, blob checks, iOS priming, Low-Power-Mode emulation (canvas is
immune). Add:

- **Frame counts**: config `count` == files on disk for every segment (an off-by-one
  freezes the last beat of a scene).
- **Network panel**: frames load in batches near the viewport, not all up-front; a
  full-page scroll on a throttled connection should show progressive fetches.
- **Total weight**: sum `du -sh $ASSETS/frames` and say the number out loud to the
  user — this mode trades bytes for determinism, and that tradeoff belongs to them.
