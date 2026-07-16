---
name: pwa-cache-bumper
description: Ship a content change safely on the photo-film-works PWA (vanilla HTML/CSS/JS, no build step) — atomically bump the sw.js cache version so returning visitors get fresh assets, update sitemap.xml <lastmod> + manifest on real content change, and add a portfolio/gallery item across index.html + scene.js + sitemap from a single dropped asset (with generated alt text). Use when someone says "bump the cache", "bust the service-worker cache", "new cache version", "returning users see stale photos", "sw.js version", "add a portfolio item / gallery photo", "new work to the site", "update the sitemap lastmod", "ship a photo to photofilm", or after dropping an image into assets/images. Delegates the actual image optimization (resize/WebP) to the media-pipeline skill. Bash 3.2, dry-run by default, GILDED_ROOT override.
---

# PWA Cache Bumper (photo-film-works)

`ventures/photo-film-works` is a **build-step-free** vanilla PWA. Because there's no
bundler hashing filenames, freshness is controlled entirely by the service worker's
cache name. Ship a content change wrong and returning visitors keep the **old** photos
forever. This skill does the three chores that must travel together:

1. **Bump `sw.js`** `CACHE_NAME` (e.g. `photofilmworks-v4` → `-v5`). The `activate`
   handler purges every cache whose name ≠ the current one, so a version bump is what
   actually evicts stale assets. **Any change to a precached shell asset REQUIRES a bump.**
2. **Update `sitemap.xml` `<lastmod>`** (and `manifest.json` if name/theme changed) on a
   real content change — so search engines and the installed-app metadata stay honest.
3. **Add a portfolio item** from one dropped asset across the three places that must stay
   in sync: the `index.html` `.portfolio-grid`, the `PHOTO_URLS` array in `scene.js`
   (the WebGL floating gallery), and `sitemap.xml`.

Path base (override with `GILDED_ROOT`): `$GILDED_ROOT/ventures/photo-film-works`
— default `~/GILDED-EDGE-ECOSYSTEM`. **Safe by default: every action DRY-RUNS and writes
nothing until you pass `--run`.**

## What lives where (grounded in the repo)

- `sw.js` — line 1 `const CACHE_NAME = 'photofilmworks-vN';` then `PRECACHE_URLS = [...]`
  (the shell: `/`, index.html, styles.css, scene.js, manifest.json, robots.txt,
  sitemap.xml, logo). Images use stale-while-revalidate; **shell uses network-first but
  is precached at install** — so a shell edit without a bump can still be served stale.
- `scene.js` — `PHOTO_URLS = [ 'assets/images/optimized/...jpg', ... ]` near the top,
  `const PHOTO_COUNT = PHOTO_URLS.length;` right after. The 3D gallery renders one plane
  per URL, so **appending a URL grows the gallery automatically** (positions wrap).
- `index.html` — `<section id="portfolio">` → `.portfolio-grid` with repeated
  `.portfolio-item` blocks: an `<img src="assets/images/optimized/NAME.jpg" alt="..."
  loading="lazy" width= height=>` plus a `.portfolio-item-overlay` label. `tall`/`wide`
  modifier classes control grid span.
- `sitemap.xml` — currently a single `<url>` for `https://photofilm.works/`. Portfolio
  items are one-page anchors, so the site-level `<lastmod>` is what to touch.
- `optimize-images.sh` — existing `sips`-based resizer (JPEG q82; 1200px portfolio/3D,
  800px service). **Do NOT reimplement it here** — see delegation below.

## Delegation — image optimization is NOT this skill's job

When a raw asset is dropped, hand the resize/compression to the **media-pipeline** skill
(`optimize` verb → WebP/AVIF + srcset, `sips` fallback identical to this repo), or the
repo's own `optimize-images.sh`. This skill assumes the optimized file already lives (or
will live) at `assets/images/optimized/<name>.jpg` and only wires it into the three files
+ bumps the cache. `scripts/pwa_bump.sh add ... --optimize` just prints the exact
media-pipeline / optimize-images.sh command to run first — it never resizes itself.

## Workflow

### A. Bump the cache after any shell/content change
```
scripts/pwa_bump.sh bump                 # dry-run: shows vN -> vN+1 in sw.js
scripts/pwa_bump.sh bump --run           # apply
```
Also refreshes `sitemap.xml` `<lastmod>` to today. Add `--date YYYY-MM-DD` to pin it.

### B. Add a portfolio / gallery item from one asset
```
scripts/pwa_bump.sh add \
  --name new-portrait-IMGL9001 \
  --label "Fine-Art Portrait" \
  --alt "Fine art portrait by Daniel Montero, luxury photographer NYC" \
  --span tall                            # tall|wide|none (grid size)
# dry-run prints the exact index.html block, the scene.js PHOTO_URLS insert,
# the sitemap touch, AND the required cache bump.
scripts/pwa_bump.sh add --name ... --label ... --run
```
- If `--alt` is omitted, the script **generates alt text** from `--label` + the house
  descriptors (e.g. `"Executive Branding — luxury photography by DM Photofilmworks"`).
  Always review generated alt text for accuracy; alt text is for real users on screen
  readers, not keyword stuffing.
- `add` always implies a cache **bump** (a new precached-adjacent asset shipped), so it
  updates `sw.js` too. The optimized JPEG must exist at
  `assets/images/optimized/<name>.jpg` — run media-pipeline first (see `--optimize`).

### C. Verify
```
scripts/pwa_bump.sh verify   # checks sw.js version is unique vs git, PHOTO_URLS length
                             # matches PHOTO_COUNT usage, every portfolio <img> resolves
                             # to a file on disk, sitemap lastmod parses.
```

## Gotchas

- **The #1 stale-content bug**: editing index.html/styles.css/scene.js WITHOUT bumping
  `CACHE_NAME`. They're precached at SW install; returning visitors keep the old copy
  until the cache name changes. When in doubt, `bump`.
- **Version must strictly increase and be unique** — the `activate` purge keeps exactly
  the one matching `CACHE_NAME` and deletes the rest. Reusing an old name means no purge.
  `verify` checks the new name isn't already in git history.
- **`scene.js` count** — `PHOTO_COUNT` is derived (`PHOTO_URLS.length`), so you only edit
  the array; never hand-edit a magic number. Keep entries as
  `'assets/images/optimized/NAME.jpg'` (relative, no leading slash — matches the file).
- **Path shape differs by file**: `scene.js` uses `assets/images/optimized/...` (no
  leading slash, relative to page); `sw.js` PRECACHE uses `/absolute` root paths. Don't
  cross them.
- **Optimized file must exist** before `--run add`, or the portfolio `<img>` and the 3D
  plane 404. `verify` catches missing files.
- **Don't precache every portfolio image** in `sw.js` — they're intentionally left to the
  stale-while-revalidate image path so the install payload stays small. Only shell assets
  belong in `PRECACHE_URLS`.
- Not a git tool — it edits files; you commit. Conventional commit e.g.
  `chore: bump sw cache to v5` / `feat: add <label> portfolio item`.

## Files
- `scripts/pwa_bump.sh` — `bump` / `add` / `verify`. Bash 3.2, dry-run by default
  (`--run` to write), `GILDED_ROOT` override, no exotic deps (grep/sed/awk). Delegates
  image optimization to media-pipeline / optimize-images.sh; never resizes itself.
