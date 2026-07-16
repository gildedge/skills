---
name: remotion-composition-builder
description: Scaffold a Remotion composition (animated .tsx + <Composition> registration + a copy-paste render command) from a plain scene spec, in the exact Remotion v4 conventions used across the Gilded Edge ecosystem — lumier-pictures (remotion/index.ts + Root.tsx, SceneComposition), edge-os-works (remotion/edge-commercial, src/Root.tsx), and lumier-studios. Use whenever someone says "make a Remotion composition/animation", "scaffold a video composition", "build an intro/title/lower-third/kinetic-text animation", "turn this scene spec into Remotion", "register a new <Composition>", "animate these UI screenshots", or "give me the remotion render command". Emits real Remotion API (AbsoluteFill, Sequence, interpolate, spring, useCurrentFrame, useVideoConfig, Img/staticFile) — not pseudo-code. Dry-run by default; add --run to write files. For the raw ffmpeg/frame/transcode steps AFTER a render, defer to the media-pipeline skill.
---

# Remotion Composition Builder

Turns a **scene spec** (title + a list of scenes with text/image/animation) into:

1. a compilable `<Name>.tsx` composition using the real Remotion v4 API, and
2. the `<Composition …/>` line to paste into that project's `Root.tsx`, and
3. the exact `remotion render` command for that venture.

It **prints everything and writes nothing** unless you pass `--run`. This is the
higher-level, authoring layer — once you have an `.mp4`, hand the frame
extraction / transcode / caption work to the **media-pipeline** skill.

## When to use

- "Scaffold / build a Remotion composition or animation from this spec."
- "Make a title card / kinetic text / lower-third / screenshot reveal / intro."
- "Register a new `<Composition>` in Root.tsx."
- "What's the render command for lumier / edge-os?"

## The three target projects (grounded, do not guess)

| Venture | Entry point | Root file | Render base |
|---|---|---|---|
| **lumier-pictures** | `remotion/index.ts` | `remotion/Root.tsx` (`RemotionRoot`) | `npm run remotion:render` → `remotion render remotion/index.ts` |
| **lumier-studios** | same layout as lumier-pictures | `remotion/Root.tsx` | `remotion render remotion/index.ts` |
| **edge-os-works** | `remotion/edge-commercial/src/index.ts` | `src/Root.tsx` (`RemotionRoot`) | `remotion render <CompId> out.mp4` (run inside `remotion/edge-commercial`) |

Remotion is pinned at **4.0.420** (lumier) / **4.0.461** (edge-commercial). Both
register comps by rendering `<Composition id … component … durationInFrames …
fps … width … height … defaultProps />` inside a `RemotionRoot`. lumier's
`SceneComposition` takes `defaultProps={{ sceneData: null }}` and is fed data at
render time via `--props`.

## Quick start

```bash
# 1. see the toolchain + detected ventures
bash scripts/new-composition.sh check

# 2. dry-run: print the .tsx, the Root.tsx line, and the render command
bash scripts/new-composition.sh assets/scene-spec.example.json --venture lumier-pictures

# 3. actually write the files (creates remotion/compositions/<Name>.tsx,
#    patches Root.tsx only if --patch-root is also given)
bash scripts/new-composition.sh my-spec.json --venture edge-os-works --run
```

Override the ecosystem root: `GILDED_ROOT=/path bash scripts/new-composition.sh …`
(falls back to `~/GILDED-EDGE-ECOSYSTEM`).

## Scene spec format

A small JSON file (`assets/scene-spec.example.json` is a working sample):

```jsonc
{
  "name": "EdgeOSIntro",          // PascalCase → Composition id + component + filename
  "fps": 30,
  "width": 1920,
  "height": 1080,
  "background": "#09090b",         // solid; or a CSS gradient string
  "scenes": [
    {
      "durationInFrames": 150,     // per-scene length; comp duration = sum
      "title": "EDGE OS WORKS",    // optional overlay text
      "image": "real-portal-home.png",   // optional; served via staticFile()
      "animation": "reveal-up"     // reveal-up | zoom-out | slide-left | fade-away | fade-in
    }
  ]
}
```

`durationInFrames` for the `<Composition>` is the **sum** of scene durations
(scenes are laid out as back-to-back `<Sequence>`s, matching edge-commercial's
`Composition.tsx`). Images resolve through `staticFile()`, so drop them in the
project's `public/` first.

## What the generated .tsx contains (real Remotion API)

- `AbsoluteFill` root with the background (solid or radial-gradient ambient glow).
- One `<Sequence from={offset} durationInFrames={n}>` per scene.
- A `CinematicUI` image block using `Img` + `staticFile`, animated with
  `interpolate(useCurrentFrame() - startFrame, …)` and the four Apple-style
  motions from edge-commercial (`reveal-up` uses `perspective()/rotateX`,
  `fade-away` adds a `blur()`).
- A `TitleFade` text overlay driven by `spring({ frame, fps, config:{damping:200} })`
  + an `interpolate` opacity envelope — the lumier/edge title convention.
- `useVideoConfig()` for `fps` so springs are frame-rate correct.

The file is TypeScript, `Inter, -apple-system` font, and uses the venture's
brand palette (edge-os indigo/cyan/gold on `#09090b`; lumier gold `#D4AF37` on
obsidian). No inline pseudo-Remotion — every import is a real 4.x export.

## Registering the composition

The script prints the exact block to paste inside the venture's `RemotionRoot`:

```tsx
<Composition
  id="EdgeOSIntro"
  component={EdgeOSIntro}
  durationInFrames={540}
  fps={30}
  width={1920}
  height={1080}
/>
```

Pass `--patch-root` **with** `--run` to have the script insert the import + the
`<Composition>` block automatically (it refuses if an id with that name already
exists). Without `--patch-root` it only writes the `.tsx` and prints the line —
safer, and the default.

## Rendering

```bash
# lumier-pictures / lumier-studios
npx remotion render remotion/index.ts EdgeOSIntro out/EdgeOSIntro.mp4

# with injected scene data (lumier SceneComposition pattern)
npx remotion render remotion/index.ts SceneComposition out.mp4 --props=./scene.json

# edge-os-works (run inside remotion/edge-commercial)
npx remotion render EdgeOSIntro out/EdgeOSIntro.mp4 --codec h264
```

Codecs Remotion accepts here: `h264` (default), `h265`, `vp8`, `vp9`, `prores`
(matches `RemotionRenderConfig` in `remotion/types/VideoData.ts`).

## Gotchas

- **Dry-run is the default.** Nothing is written without `--run`; `Root.tsx` is
  never touched without `--run --patch-root`.
- **durationInFrames must equal the sum of the sequences**, or trailing scenes
  get cut. The script computes it for you — don't hand-edit one without the other.
- **Images must exist in `public/`** before render; `staticFile("x.png")` throws
  at render time if missing. Put screenshots there first (edge-os keeps them in
  `remotion/edge-commercial/public/`).
- **`spring()` needs `fps`** from `useVideoConfig()`, not a literal — otherwise
  timing changes silently when fps changes.
- **edge-commercial renders from inside its own folder** (separate `package.json`
  + `remotion.config.ts`), not from the edge-os-works repo root.
- **Don't reimplement frame extraction here.** After the `.mp4` exists, the
  media-pipeline skill (`scripts/media.sh frames …`) handles WebP/JPEG scroll
  frames — this skill stops at the render command.
- **lumier `remotion/index.ts` registers `RemotionRoot`**; the composition file
  itself lives under `remotion/compositions/` and is imported by `Root.tsx`.

## Files

- `scripts/new-composition.sh` — `check | <spec.json>`; bash 3.2 safe, dry-run
  default, `--venture`, `--run`, `--patch-root`, `GILDED_ROOT` override. Emits
  the `.tsx`, the Root.tsx line, and the render command.
- `assets/composition.tsx.tmpl` — the Remotion v4 component template it fills.
- `assets/scene-spec.example.json` — a runnable 4-scene edge-os sample.
