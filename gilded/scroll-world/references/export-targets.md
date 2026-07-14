# Export targets — Next.js, single-file HTML, storyboard decks

Gilded addition (GILDED-CHANGES.md). Three ways to ship a finished world beyond the
standalone `index-template.html`. All of them consume the same assets and config —
nothing upstream changes.

## 1. Next.js App Router integration (the ecosystem default)

Pattern proven in `edge-os-works` (`ScrollCinematicLoader.tsx`): the engine is
client-only, loaded with `dynamic(..., { ssr: false })`; the SEO copy is
server-rendered. Three files:

**`public/` assets** — copy `assets/` (stills, posters, `vid/` or `frames/`) and the
engine file (`scrub-engine.js` or `frame-scrub-engine.js`) into the app's `public/`.
Large mp4s in a repo belong in git LFS (the edge-os-works convention — see the
cinematic-render-pipeline skill's `lfs` stage).

**`components/scroll-world/ScrollWorld.tsx`** — thin client wrapper. The engine
builds its own DOM, so React's only job is the container ref + config:

```tsx
'use client';

import { useEffect, useRef } from 'react';
import { WORLD_CONFIG } from './world.config';

export default function ScrollWorld({ children }: { children?: React.ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let cancelled = false;
    // Engine ships as a plain script exposing a global — load it once, then mount.
    const mount = () => {
      if (cancelled || !ref.current) return;
      // @ts-expect-error engine attaches itself to window
      window.mountScrollWorld(ref.current, WORLD_CONFIG);
    };
    if ((window as unknown as Record<string, unknown>).mountScrollWorld) mount();
    else {
      const s = document.createElement('script');
      s.src = '/scrub-engine.js';
      s.onload = mount;
      document.head.appendChild(s);
    }
    return () => { cancelled = true; };
  }, []);

  // children = the server-rendered data-sw-seo block (crawlable copy)
  return <div id="world" ref={ref}>{children}</div>;
}
```

**`app/(marketing)/page.tsx`** — server component; the `data-sw-seo` block is
rendered HERE so crawlers get it in the served HTML (SKILL Step 7's SEO rule —
`dynamic({ ssr: false })` on the engine is exactly why the copy must not live only
in the client config):

```tsx
import dynamic from 'next/dynamic';

const ScrollWorld = dynamic(() => import('@/components/scroll-world/ScrollWorld'), {
  ssr: false,
});

export default function Page() {
  return (
    <ScrollWorld>
      <section data-sw-seo>
        <h1>The hero line.</h1>
        <p>One-sentence pitch.</p>
        {/* one h2 + p per scene, real CTA links */}
      </section>
    </ScrollWorld>
  );
}
```

Notes:
- If the app's Next version rejects `ssr: false` in a server component (newer App
  Router builds), put the `dynamic()` call inside another `'use client'` file —
  exactly the `ScrollCinematicLoader.tsx` shape — and keep the SEO block in the
  server page around it.
- Theme via a CSS Module or global stylesheet setting `--sw-*` on `.sw-root` —
  never inline styles (ecosystem standard). The engine's `@layer sw` wrapper means
  the page tokens win without specificity hacks.
- The engine's own injected CSS is namespaced (`sw-`/`swf-`) and won't fight CSS
  Modules.
- Keep `mountScrollWorld` out of the React render path; it must run once per mount
  (the `useEffect` above). Unmount cleanup is optional for a landing page but if the
  route is revisited client-side, guard against double-mounting (check for
  `.sw-root` on the container first).

## 2. Self-contained single-file HTML (demo / artifact delivery)

For "send me one file" reviews: inline the engine and config into
`index-template.html`.

Build it mechanically (bash 3.2 safe):

```bash
# 1. Start from index-template.html with the real config filled in.
# 2. Replace  <script src="scrub-engine.js"></script>  with an inline copy:
awk '/<script src="scrub-engine.js"><\/script>/ {
       print "<script>";
       while ((getline line < "scrub-engine.js") > 0) print line;
       close("scrub-engine.js");
       print "</script>"; next
     } { print }' index.html > world-single.html
```

Asset honesty — the three delivery levels:

1. **Single HTML + sibling `assets/` folder (recommended).** The file references
   relative paths; zip the folder. Everything works from any static host. Serve
   locally with any server — the blob loader means byte-range support does NOT
   matter (SKILL Step 6), so even `python3 -m http.server` is fine.
2. **Truly single-file (assets as `data:` URIs).** Only sane for a **previz-tier or
   frame-mode demo with few frames** — base64 inflates bytes ~33%, and a full
   video world is ~8 MB × (2N−1) clips before inflation. Say the resulting file
   size to the user before building this; past ~25–30 MB most chat/mail transports
   reject it.
3. **Hosted artifact page.** If publishing to a sandboxed artifact host, note the
   CSP usually blocks external fetches — level 2 (inlined data URIs) is the only
   shape that works there, with the same size warning. Prefer deploying the folder
   (level 1) to real static hosting instead.

`file://` caveat: `fetch()` of relative clip paths is blocked from `file://` in most
browsers — tell reviewers to run a one-line local server, or ship level 2.

## 3. Storyboard exports (pitch deck / one-pager via the pptx & pdf skills)

The world's stills + copy are already a storyboard. Hand them to the ecosystem's
`pptx` or `pdf` skill with this mapping — no regeneration, no extra spend:

**Deck structure (one world → one deck):**

| Slide | Content |
|---|---|
| 1 — Cover | brand name, hero line (section 1 `title`), finale still full-bleed |
| 2 — The journey | all N stills in a row + one-line beat map (label → label → …) |
| 3..N+2 — One per scene | still full-bleed (or right half), `eyebrow` as kicker, `title` as heading, `body` + `tags` as supporting text |
| N+3 — The flight | seam map: architecture (A/B), camera grammar per leg, connector list — this is the "how it moves" slide for stakeholders |
| N+4 — CTA | finale copy + CTA labels/links |

**Asset prep:** use the source stills (`$WORK/still_*.png`, highest fidelity), not
the extracted posters. Convert/resize via the media-pipeline skill (`optimize`) if
deck weight matters.

**Theming:** pass the palette to the deck skill explicitly — Gilded house: obsidian
`#0A0A0B` background slides, ivory `#F7F4EC` text, gold `#D4AF37` kickers/rules
(matching `gilded-presets.md`); or the brand kit captured in the Step 1 interview.

**One-pager (pdf skill):** hero still on top, the N beats as an eyebrow+title list
with thumbnail stills, CTA block at the bottom. Same palette rules.

This is also the cheap "sell the concept first" path: run the interview + Step 2
stills only (anchor-gated), export the storyboard deck, get sign-off, and only then
spend the video budget.
