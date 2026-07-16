/* ============================================================================
   scroll-world — frame-atlas scrub engine (canvas frame-sequence renderer)
   ----------------------------------------------------------------------------
   Gilded addition (GILDED-CHANGES.md). The ALTERNATIVE render mode to
   scrub-engine.js: instead of scrubbing video.currentTime, it draws a
   pre-extracted WebP frame sequence to a full-viewport <canvas> by scroll
   position — the technique Apple ships on its scroll pages.

   WHY / WHEN (full tradeoff discussion: frame-atlas.md)
     + deterministic paint: no decoder seek latency, no seek pile-ups
     + no seekability problem at all (no byte-ranges, no blob loading)
     + iOS Low Power Mode CANNOT freeze it (images always paint; no play() gate)
     + perfect reverse scrub (a seek backward costs the same as forward)
     - assets are heavier than the video encodes; recommend video-first,
       frames for hero pages or when QA shows scrub stutter (frame-atlas.md)

   Framework-agnostic vanilla JS, zero dependencies, builds its own DOM +
   injects its own namespaced CSS (prefix `swf-`; same `--sw-*` theme variables
   as scrub-engine.js, so an existing theme block works on both engines).

   USAGE — same config shape as scrub-engine.js, with `frames` replacing `clip`:
     mountScrollWorldFrames(document.getElementById('world'), {
       brand: { name: 'Pearl & Co.', href: '#top' },
       cta: { label: 'Order now', href: '#finale' },
       hint: 'scroll to fly in',
       nav: true,
       diveScroll: 1.3, connScroll: 0.9,      // viewport-heights of scroll per segment
       scrollMobileFactor: 1.2,               // longer scroll run on phones (same as video engine)
       crossfade: 0.12,                       // seam dissolve width (vh) — frames are seam-identical
                                              // by doctrine, so this mostly matters for null connectors
       sections: [
         { id, label, still,                  // still = reduced-motion / pre-load artwork (webp)
           frames:       { path:'assets/frames/farm/frame-', count:96, digits:3, ext:'webp', start:1 },
           framesMobile: { … },               // optional portrait/lighter sequence, phone-class only
           accent, scroll, linger,            // same pacing knobs as scrub-engine.js
           eyebrow, title, body, tags:[…], cta:{…} },
         …
       ],
       connectors:       [ {path,count,digits,ext,start} | null, … ],  // length = sections-1
       connectorsMobile: [ … ],               // optional, same length
     });

   Sequences are extracted from the SAME encoded clips that passed the SSIM seam
   gate (pipeline.md §5c), so seams stay frame-identical — the doctrine carries
   over unchanged; only the paint primitive swaps. Extraction recipe:
   frame-atlas.md.

   STILLS MODE: prefers-reduced-motion and data-saver flip the page to the
   section stills cross-dissolving on scroll (no sequence is fetched). There is
   no Low-Power-Mode fallback because none is needed — canvas has no play() gate.

   SEO: same `data-sw-seo` contract as scrub-engine.js — put the crawlable copy
   block in the container; it's hidden on mount.
   ========================================================================== */

function mountScrollWorldFrames(container, config) {
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const coarse = window.matchMedia('(hover: none) and (pointer: coarse)').matches;
  const smallMQ = window.matchMedia('(max-width: 860px)');
  const isMobile = () => coarse || smallMQ.matches;
  // Same device-class rule as scrub-engine.js: sequence tier by screen short side
  // (≤600 CSS px = phone). iPads get the desktop sequence.
  const phoneClass = Math.min(screen.width, screen.height) <= 600;
  const conn = navigator.connection;
  const dataSaver = !!(conn && conn.saveData);
  const slowNet = !!(conn && /^(slow-2g|2g|3g)$/.test(conn.effectiveType || ''));
  // Stills mode is decided up-front; unlike video there is no runtime OS gate
  // (canvas paints regardless of Low Power Mode).
  const stillsOnly = reduce || dataSaver;

  const SECTIONS = config.sections || [];
  const CONNECTORS = config.connectors || [];
  const CONNECTORS_M = config.connectorsMobile || [];
  const DIVE_W = config.diveScroll || 1.3;
  const CONN_W = config.connScroll || 0.9;
  const CROSSFADE = (config.crossfade != null) ? config.crossfade : 0.12;
  const N = SECTIONS.length;
  if (!N) return;

  injectFrameCSS();
  container.classList.add('sw-root', 'swf-root');
  container.querySelectorAll('[data-sw-seo]').forEach(n => { n.hidden = true; });

  // ---- segment chain: dive0, conn0, dive1, … (same interleave as scrub-engine) ----
  const SEGMENTS = [];
  SECTIONS.forEach((s, i) => {
    const spec = (phoneClass && s.framesMobile) ? s.framesMobile : s.frames;
    const dive = { kind: 'dive', si: i, spec: stillsOnly ? null : spec, still: s.still,
                   accent: s.accent, w: s.scroll || DIVE_W, linger: s.linger || 0 };
    SEGMENTS.push(dive);
    s._seg = dive;
    // Connectors are optional (null slot = direct crossfade), same as the video engine.
    const cSpec = (phoneClass && CONNECTORS_M[i]) ? CONNECTORS_M[i] : CONNECTORS[i];
    if (i < N - 1 && cSpec) {
      SEGMENTS.push({ kind: 'conn', si: i, spec: stillsOnly ? null : cSpec,
                      still: SECTIONS[i + 1].still, accent: SECTIONS[i + 1].accent,
                      w: CONN_W, linger: 0 });
    }
  });
  const NSEG = SEGMENTS.length;

  // ---- DOM ----
  const canvas = el('canvas', 'swf-canvas');
  const ctx = canvas.getContext('2d');
  const scrollbar = el('div', 'swf-scrollbar');
  const scrollbarFill = el('span'); scrollbar.appendChild(scrollbarFill);

  const topbar = el('div', 'swf-topbar');
  if (config.brand) {
    const brand = el('a', 'swf-brand'); brand.href = (config.brand.href || '#');
    brand.appendChild(el('span', 'swf-brand__mark'));
    const nm = el('span', 'swf-brand__name'); nm.textContent = config.brand.name || '';
    brand.appendChild(nm);
    topbar.appendChild(brand);
  }
  const nav = el('nav', 'swf-nav'); if (config.nav !== false) topbar.appendChild(nav);
  if (config.cta && config.cta.label) {
    const c = el('a', 'swf-topcta'); c.href = config.cta.href || '#'; c.textContent = config.cta.label;
    topbar.appendChild(c);
  }

  const copylayer = el('div', 'swf-copylayer');
  const route = el('div', 'swf-route');
  const hint = el('div', 'swf-hint');
  const hintText = el('span'); hintText.textContent = config.hint || 'scroll'; hint.appendChild(hintText);
  hint.appendChild(el('i'));
  const track = el('div', 'swf-track');
  [canvas, scrollbar, topbar, copylayer, route, hint, track].forEach(n => container.appendChild(n));

  // per-section copy / route / nav (same structure as scrub-engine.js)
  const copies = [], dots = [];
  SECTIONS.forEach((s, i) => {
    const c = el('article', 'swf-copy'); c.style.setProperty('--sw-accent', s.accent || '');
    c.innerHTML =
      `<span class="swf-copy__num">${pad(i + 1)} / ${pad(N)}</span>` +
      (s.eyebrow ? `<span class="swf-copy__eyebrow">${esc(s.eyebrow)}</span>` : '') +
      (s.title ? `<h2 class="swf-copy__title">${esc(s.title)}</h2>` : '') +
      (s.body ? `<p class="swf-copy__body">${esc(s.body)}</p>` : '') +
      (s.tags && s.tags.length ? `<ul class="swf-copy__tags">${s.tags.map(t => `<li>${esc(t)}</li>`).join('')}</ul>` : '') +
      (s.cta ? `<div class="swf-copy__cta">${ctaBtns(s.cta)}</div>` : '');
    copylayer.appendChild(c); copies.push(c);

    const dot = el('button', 'swf-route__dot'); dot.style.setProperty('--sw-accent', s.accent || '');
    dot.innerHTML = `<span class="swf-route__label">${esc(s.label || '')}</span><i></i>`;
    dot.addEventListener('click', () => jumpTo(i)); route.appendChild(dot); dots.push(dot);

    if (config.nav !== false) {
      const b = el('button', 'swf-nav__item'); b.textContent = s.label || '';
      b.addEventListener('click', () => jumpTo(i)); nav.appendChild(b);
    }
  });

  // ---- frame loading ----
  // Each segment lazily owns an Image[] for its sequence, loaded in small batches
  // when scroll approaches. The section still is loaded eagerly as the immediate
  // paint (and IS the artwork in stills mode).
  function frameSrc(spec, i) {
    const start = (spec.start != null) ? spec.start : 1;
    const digits = spec.digits || 3;
    return spec.path + String(i + start).padStart(digits, '0') + '.' + (spec.ext || 'webp');
  }
  SEGMENTS.forEach(s => {
    s.imgs = null; s.loadedTo = -1; s.loading = false;
    s.stillImg = null;
    if (s.still) {
      const im = new Image(); im.decoding = 'async'; im.src = s.still;
      im.onload = () => { needsDraw = true; };
      s.stillImg = im;
    }
  });

  function loadSeq(s) {
    if (!s.spec || s.loading || (s.imgs && s.loadedTo >= s.spec.count - 1)) return;
    s.loading = true;
    if (!s.imgs) s.imgs = new Array(s.spec.count);
    const BATCH = 12;
    let next = s.loadedTo + 1;
    function batch() {
      const end = Math.min(next + BATCH, s.spec.count);
      let pending = end - next;
      if (pending <= 0) { s.loading = false; return; }
      for (let i = next; i < end; i++) {
        const im = new Image(); im.decoding = 'async';
        const done = () => {
          if (--pending === 0) { s.loadedTo = end - 1; next = end; needsDraw = true; batch(); }
        };
        im.onload = done; im.onerror = done;   // an error leaves a hole; nearest-frame fill covers it
        im.src = frameSrc(s.spec, i);
        s.imgs[i] = im;
      }
    }
    batch();
  }

  // Best drawable image for segment s at eased progress t (0..1):
  // exact frame if loaded, else nearest earlier loaded frame, else the still.
  function pickFrame(s, t) {
    if (!s.spec || !s.imgs) return s.stillImg;
    const idx = Math.max(0, Math.min(s.spec.count - 1, Math.round(t * (s.spec.count - 1))));
    for (let i = idx; i >= 0; i--) {
      const im = s.imgs[i];
      if (im && im.complete && im.naturalWidth) return im;
    }
    return s.stillImg;
  }

  // ---- math (identical contracts to scrub-engine.js) ----
  const clamp = (x, a, b) => Math.min(b == null ? 1 : b, Math.max(a == null ? 0 : a, x));
  const smooth = x => { x = clamp(x); return x * x * (3 - 2 * x); };
  const lingerEase = (x, L) => { L = clamp(L); const c = x - 0.5; return (1 - L) * x + L * (4 * c * c * c + 0.5); };

  let vh = window.innerHeight, totalW = 0, activeIndex = -1;
  let laidOutW = window.innerWidth;
  let smoothY = window.scrollY || 0;
  let needsDraw = true;
  let dpr = 1;

  function sizeCanvas() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.round(window.innerWidth * dpr);
    canvas.height = Math.round(window.innerHeight * dpr);
    needsDraw = true;
  }

  function layout() {
    vh = window.innerHeight;
    laidOutW = window.innerWidth;
    const wf = isMobile() ? (config.scrollMobileFactor != null ? config.scrollMobileFactor : 1.2) : 1;
    let off = 0;
    SEGMENTS.forEach(s => { s.start = off * vh; off += s.w * wf; s.end = off * vh; });
    totalW = off;
    track.style.height = (totalW * vh + vh) + 'px';
    sizeCanvas();
    read(true);
  }

  function jumpTo(i) {
    const seg = SECTIONS[i]._seg;
    window.scrollTo({ top: seg.start + (seg.end - seg.start) * 0.5, behavior: reduce ? 'auto' : 'smooth' });
  }

  function drawCover(img, alpha) {
    if (!img || !img.complete || !img.naturalWidth) return;
    const cw = canvas.width, ch = canvas.height;
    const sc = Math.max(cw / img.naturalWidth, ch / img.naturalHeight);
    const w = img.naturalWidth * sc, h = img.naturalHeight * sc;
    ctx.globalAlpha = clamp(alpha);
    // Bias the crop slightly above centre (object-position: center 42% parity).
    ctx.drawImage(img, (cw - w) / 2, (ch - h) * 0.42, w, h);
    ctx.globalAlpha = 1;
  }

  // ---- per-scroll UI + prefetch ----
  function read(force) {
    const y = smoothY;
    let ci = 0;
    for (let i = 0; i < NSEG; i++) if (y >= SEGMENTS[i].start) ci = i;

    const lookahead = slowNet ? 0.4 : 1.6;
    if (!stillsOnly) {
      for (let i = 0; i < NSEG; i++) {
        const s = SEGMENTS[i];
        if (y > s.start - lookahead * vh && y < s.end + lookahead * vh) loadSeq(s);
      }
    }

    // copy visibility (same shape as the video engine)
    for (let i = 0; i < N; i++) {
      const seg = SECTIONS[i]._seg;
      const pr = clamp((y - seg.start) / (seg.end - seg.start));
      const before = y < seg.start, after = y > seg.end;
      let cop;
      if (i === 0) cop = after ? 0 : smooth(1 - pr / 0.62);
      else if (i === N - 1) cop = before ? 0 : smooth(pr / 0.4);
      else cop = (before || after) ? 0 : smooth(1 - Math.abs(pr - 0.5) / 0.5);
      const c = copies[i];
      c.style.opacity = cop;
      c.style.transform = reduce ? 'none' : `translateY(${(0.5 - pr) * 4}vh)`;
      c.style.pointerEvents = cop > 0.5 ? 'auto' : 'none';
    }

    const cur = SEGMENTS[ci];
    const near = clamp(cur.kind === 'dive' ? cur.si
      : (((y - cur.start) / (cur.end - cur.start)) > 0.5 ? cur.si + 1 : cur.si), 0, N - 1);
    if (near !== activeIndex || force) {
      activeIndex = near;
      dots.forEach((d, k) => d.classList.toggle('is-active', k === near));
      nav.querySelectorAll('.swf-nav__item').forEach((n, k) => n.classList.toggle('is-active', k === near));
      container.style.setProperty('--sw-accent', SECTIONS[near].accent || '');
    }
    scrollbarFill.style.transform = `scaleX(${clamp(y / (totalW * vh))})`;
    hint.style.opacity = clamp(1 - y / (0.5 * vh));
  }

  // ---- paint ----
  let lastKey = '';
  function paint() {
    const y = smoothY;
    let ci = 0;
    for (let i = 0; i < NSEG; i++) if (y >= SEGMENTS[i].start) ci = i;
    const cur = SEGMENTS[ci];
    const local = clamp((y - cur.start) / (cur.end - cur.start));
    const t = cur.linger ? lingerEase(local, cur.linger) : local;
    const img = pickFrame(cur, stillsOnly ? 0 : t);

    // Seam dissolve: within the fade band after a segment's start, blend the
    // previous segment's final frame over the current one. With doctrine-true
    // sequences the two frames are near-identical (insurance only); with null
    // connectors or stills mode this IS the transition.
    const fade = (stillsOnly ? 0.35 : CROSSFADE) * vh;
    const into = y - cur.start;
    let prevImg = null, prevAlpha = 0;
    if (ci > 0 && fade > 0 && into < fade) {
      prevImg = pickFrame(SEGMENTS[ci - 1], 1);
      prevAlpha = smooth(1 - into / fade);
    }

    const key = ci + ':' + (img ? img.src : '-') + ':' + t.toFixed(3) + ':' + prevAlpha.toFixed(2);
    if (key === lastKey && !needsDraw) return;
    lastKey = key; needsDraw = false;

    ctx.clearRect(0, 0, canvas.width, canvas.height);
    if (img) drawCover(img, 1);
    else if (cur.stillImg) drawCover(cur.stillImg, 1);
    if (prevImg && prevAlpha > 0.001) drawCover(prevImg, prevAlpha);
  }

  // ---- main loop: lerp scroll, update UI, paint ----
  let ticking = false;
  function loop() {
    const target = window.scrollY || window.pageYOffset || 0;
    const ease = reduce ? 1 : 0.18;
    smoothY += (target - smoothY) * ease;
    if (Math.abs(target - smoothY) < 0.5) smoothY = target;
    read(false);
    paint();
    requestAnimationFrame(loop);
  }

  function onResize() {
    // Ignore URL-bar-only (height) resizes on touch — same rule as scrub-engine.js.
    if (coarse && window.innerWidth === laidOutW) return;
    layout();
  }
  window.addEventListener('scroll', () => { if (!ticking) { ticking = true; requestAnimationFrame(() => { ticking = false; }); } }, { passive: true });
  window.addEventListener('resize', onResize);
  window.addEventListener('orientationchange', layout);
  window.addEventListener('load', layout);
  layout();
  if (!stillsOnly && SEGMENTS[0]) loadSeq(SEGMENTS[0]);   // first segment eagerly
  requestAnimationFrame(loop);

  // ---- helpers ----
  function el(tag, cls) { const n = document.createElement(tag); if (cls) n.className = cls; return n; }
  function pad(n) { return String(n).padStart(2, '0'); }
  function esc(s) { return String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }
  function ctaBtns(cta) {
    let h = '';
    if (cta.primary) h += `<a class="swf-btn swf-btn--primary" href="${esc(cta.primary.href || '#')}">${esc(cta.primary.label)}</a>`;
    if (cta.secondary) h += `<a class="swf-btn swf-btn--ghost" href="${esc(cta.secondary.href || '#')}">${esc(cta.secondary.label)}</a>`;
    return h;
  }
}

function injectFrameCSS() {
  if (document.getElementById('swf-css')) return;
  const css = `
  .swf-root{--sw-bg:#F5EDE0;--sw-ink:#241d2b;--sw-ink-soft:#6a6072;--sw-accent:#8a7bb5;
    --sw-font-display:ui-rounded,"SF Pro Rounded","Segoe UI",system-ui,sans-serif;
    --sw-font-body:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,system-ui,sans-serif;
    color:var(--sw-ink);font-family:var(--sw-font-body);}
  html,body{margin:0;background:var(--sw-bg,#F5EDE0);overflow-x:hidden;}
  .swf-canvas{position:fixed;inset:0;z-index:10;width:100%;height:100%;pointer-events:none;background:var(--sw-bg);}
  .swf-scrollbar{position:fixed;top:0;left:0;right:0;height:3px;z-index:60;background:color-mix(in srgb,var(--sw-accent) 14%,transparent);}
  .swf-scrollbar span{display:block;height:100%;width:100%;transform-origin:0 50%;transform:scaleX(0);background:var(--sw-accent);}
  .swf-topbar{position:fixed;top:0;left:0;right:0;z-index:50;display:flex;align-items:center;justify-content:space-between;gap:16px;padding:clamp(14px,2.4vw,26px) clamp(18px,5vw,64px);}
  .swf-brand{display:flex;align-items:center;gap:10px;text-decoration:none;color:var(--sw-ink);}
  .swf-brand__mark{width:24px;height:28px;border-radius:7px 7px 10px 10px;background:linear-gradient(160deg,var(--sw-accent),color-mix(in srgb,var(--sw-accent) 60%,#000));box-shadow:0 6px 14px color-mix(in srgb,var(--sw-accent) 40%,transparent);}
  .swf-brand__name{font-family:var(--sw-font-display);font-weight:700;font-size:1.1rem;}
  .swf-nav{display:flex;gap:4px;padding:5px;background:color-mix(in srgb,#fff 55%,transparent);backdrop-filter:blur(10px);border:1px solid color-mix(in srgb,var(--sw-accent) 16%,transparent);border-radius:999px;}
  .swf-nav__item{font:inherit;font-size:.82rem;color:var(--sw-ink-soft);border:0;background:transparent;cursor:pointer;padding:7px 14px;border-radius:999px;transition:color .25s,background .25s;}
  .swf-nav__item:hover{color:var(--sw-ink);} .swf-nav__item.is-active{color:#fff;background:var(--sw-accent);}
  .swf-topcta{text-decoration:none;font-weight:600;font-size:.9rem;color:#fff;background:var(--sw-ink);padding:10px 20px;border-radius:999px;white-space:nowrap;}
  .swf-copylayer{position:fixed;inset:0;z-index:20;pointer-events:none;}
  .swf-copylayer::before{content:"";position:absolute;inset:0;width:min(58vw,780px);background:linear-gradient(90deg,var(--sw-bg) 0%,color-mix(in srgb,var(--sw-bg) 82%,transparent) 34%,color-mix(in srgb,var(--sw-bg) 40%,transparent) 62%,transparent 100%);}
  .swf-copy{position:absolute;left:clamp(18px,5vw,64px);top:50%;transform:translateY(-50%);width:min(42vw,460px);opacity:0;will-change:opacity,transform;}
  .swf-copy__num{font-family:ui-monospace,Menlo,monospace;font-size:.74rem;letter-spacing:.12em;color:var(--sw-ink-soft);}
  .swf-copy__eyebrow{display:block;margin-top:18px;font-family:var(--sw-font-display);font-weight:700;font-size:.8rem;letter-spacing:.16em;text-transform:uppercase;color:var(--sw-accent);}
  .swf-copy__title{font-family:var(--sw-font-display);font-weight:700;color:var(--sw-ink);font-size:clamp(2rem,4.4vw,3.5rem);line-height:1.03;margin:12px 0 0;letter-spacing:-.01em;text-shadow:0 2px 20px color-mix(in srgb,var(--sw-bg) 70%,transparent);}
  .swf-copy__body{margin-top:18px;font-size:clamp(1rem,1.25vw,1.14rem);line-height:1.55;color:color-mix(in srgb,var(--sw-ink) 78%,var(--sw-ink-soft));max-width:40ch;text-shadow:0 1px 12px color-mix(in srgb,var(--sw-bg) 90%,transparent);}
  .swf-copy__tags{list-style:none;display:flex;flex-wrap:wrap;gap:8px;margin:24px 0 0;padding:0;}
  .swf-copy__tags li{font-size:.82rem;font-weight:600;color:color-mix(in srgb,var(--sw-accent) 70%,#000);padding:7px 14px;border-radius:999px;background:color-mix(in srgb,var(--sw-accent) 14%,#fff);border:1px solid color-mix(in srgb,var(--sw-accent) 30%,transparent);}
  .swf-copy__cta{display:flex;flex-wrap:wrap;gap:12px;margin-top:28px;pointer-events:auto;}
  .swf-btn{text-decoration:none;font-weight:600;font-size:.95rem;padding:13px 24px;border-radius:999px;transition:transform .2s;}
  .swf-btn--primary{color:#fff;background:var(--sw-ink);} .swf-btn--primary:hover{transform:translateY(-2px);}
  .swf-btn--ghost{color:var(--sw-ink);border:1.5px solid color-mix(in srgb,var(--sw-ink) 25%,transparent);} .swf-btn--ghost:hover{transform:translateY(-2px);}
  .swf-route{position:fixed;right:clamp(14px,2.4vw,30px);top:50%;z-index:40;transform:translateY(-50%);display:flex;flex-direction:column;gap:22px;padding:18px 10px;}
  .swf-route::before{content:"";position:absolute;left:50%;top:22px;bottom:22px;width:2px;transform:translateX(-50%);background:var(--sw-accent);opacity:.28;}
  .swf-route__dot{position:relative;border:0;background:transparent;cursor:pointer;width:14px;height:14px;display:grid;place-items:center;}
  .swf-route__dot i{width:9px;height:9px;border-radius:50%;background:color-mix(in srgb,var(--sw-accent) 40%,transparent);transition:transform .3s,background .3s,box-shadow .3s;}
  .swf-route__dot:hover i{transform:scale(1.25);background:var(--sw-accent);}
  .swf-route__dot.is-active i{background:var(--sw-accent);transform:scale(1.4);box-shadow:0 0 0 5px color-mix(in srgb,var(--sw-accent) 22%,transparent);}
  .swf-route__label{position:absolute;right:24px;top:50%;transform:translateY(-50%) translateX(6px);white-space:nowrap;font-size:.78rem;font-weight:600;color:var(--sw-ink);background:color-mix(in srgb,#fff 85%,transparent);backdrop-filter:blur(6px);padding:5px 11px;border-radius:999px;opacity:0;pointer-events:none;transition:opacity .25s,transform .25s;border:1px solid color-mix(in srgb,var(--sw-accent) 14%,transparent);}
  .swf-route__dot:hover .swf-route__label,.swf-route__dot.is-active .swf-route__label{opacity:1;transform:translateY(-50%) translateX(0);}
  .swf-hint{position:fixed;left:50%;bottom:26px;z-index:30;transform:translateX(-50%);display:flex;flex-direction:column;align-items:center;gap:10px;font-size:.76rem;letter-spacing:.14em;text-transform:uppercase;color:var(--sw-ink-soft);transition:opacity .3s;}
  .swf-hint i{width:22px;height:34px;border-radius:12px;border:2px solid color-mix(in srgb,var(--sw-ink) 28%,transparent);position:relative;}
  .swf-hint i::after{content:"";position:absolute;left:50%;top:7px;width:4px;height:7px;border-radius:2px;background:var(--sw-accent);transform:translateX(-50%);animation:swf-wheel 1.7s ease-in-out infinite;}
  @keyframes swf-wheel{0%{opacity:0;top:6px}40%{opacity:1}100%{opacity:0;top:17px}}
  .swf-track{position:relative;z-index:1;width:100%;pointer-events:none;}
  @media (max-width:860px){
    .swf-nav{display:none;}
    .swf-copylayer::before{width:100%;height:60%;top:auto;bottom:0;background:linear-gradient(0deg,var(--sw-bg) 8%,color-mix(in srgb,var(--sw-bg) 70%,transparent) 46%,transparent 100%);}
    .swf-copy{left:clamp(18px,5vw,64px);right:clamp(18px,5vw,64px);top:auto;bottom:clamp(64px,14vh,120px);transform:none;width:auto;max-width:560px;}
    .swf-copy{bottom:calc(clamp(56px,12dvh,110px) + env(safe-area-inset-bottom));}
    .swf-copy__title{font-size:clamp(1.9rem,7.5vw,2.7rem);}
    .swf-copy__body{max-width:none;font-size:clamp(.98rem,3.6vw,1.1rem);}
    .swf-hint{bottom:calc(20px + env(safe-area-inset-bottom));}
    .swf-route{gap:16px;right:6px;} .swf-route__label{display:none;}
  }
  @media (hover:none) and (pointer:coarse){
    .swf-route{padding:14px 6px;}
    .swf-route__dot{width:28px;height:28px;}
    .swf-btn{padding:15px 26px;}
  }
  @media (prefers-reduced-motion:reduce){ .swf-hint i::after{animation:none;} }
  `;
  // Same cascade-layer trick as scrub-engine.js: page-level theme tokens always win.
  const style = document.createElement('style'); style.id = 'swf-css';
  style.textContent = '@layer sw {\n' + css + '\n}';
  document.head.appendChild(style);
}

// Expose for module + global use.
if (typeof module !== 'undefined' && module.exports) module.exports = { mountScrollWorldFrames };
if (typeof window !== 'undefined') window.mountScrollWorldFrames = mountScrollWorldFrames;
