#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  Gilded Edge — pwa_bump.sh   (photo-film-works)
#
#    bump     bump sw.js CACHE_NAME vN->vN+1 + refresh sitemap lastmod
#    add      add a portfolio/gallery item across index.html + scene.js
#             + sitemap, then bump the cache
#    verify   sanity-check versions, PHOTO_URLS, portfolio <img> files
#
#  SAFE BY DEFAULT: every action DRY-RUNS (prints the diff/plan, writes
#  nothing). Add --run to actually write files.
#
#  Image optimization is delegated to the media-pipeline skill /
#  optimize-images.sh — this script never resizes an image.
#
#  bash 3.2 compatible. Deps: grep/sed/awk only. GILDED_ROOT override.
# ═══════════════════════════════════════════════════════════
set -u

SELF="$(basename "$0")"
RUN=0
GILDED_ROOT="${GILDED_ROOT:-$HOME/GILDED-EDGE-ECOSYSTEM}"
APP="$GILDED_ROOT/ventures/photo-film-works"

SW="$APP/sw.js"
SCENE="$APP/scene.js"
INDEX="$APP/index.html"
SITEMAP="$APP/sitemap.xml"

# args
NAME=""; LABEL=""; ALT=""; SPAN="none"; DATE=""; DO_OPT=0

say()  { printf '%s\n' "$*"; }
head_(){ printf '\n== %s ==\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# write a file only if --run; else show intended action
apply() { # apply <dest> <tmpfile> <label>
  local dest="$1" tmp="$2" label="$3"
  if [ "$RUN" -eq 1 ]; then
    cp "$tmp" "$dest" && printf '  WROTE %s (%s)\n' "$dest" "$label"
  else
    printf '  DRY   would update %s (%s)\n' "$dest" "$label"
    if command -v diff >/dev/null 2>&1; then
      diff -u "$dest" "$tmp" 2>/dev/null | sed 's/^/    /' | head -40
    fi
  fi
  rm -f "$tmp"
}

today() { [ -n "$DATE" ] && printf '%s' "$DATE" || date +%Y-%m-%d; }

check_paths() {
  [ -d "$APP" ] || die "photo-film-works not found at $APP (set GILDED_ROOT)"
  [ -f "$SW" ]  || die "sw.js not found at $SW"
}

current_version() { # -> e.g. photofilmworks-v4
  grep -Eo "photofilmworks-v[0-9]+" "$SW" | head -1
}

# ── bump ────────────────────────────────────────────────────
cmd_bump() {
  check_paths
  local cur num next
  cur="$(current_version)"
  [ -n "$cur" ] || die "could not find CACHE_NAME 'photofilmworks-vN' in sw.js"
  num="${cur##*-v}"
  next="photofilmworks-v$((num + 1))"
  head_ "cache bump"
  say "  sw.js CACHE_NAME: $cur -> $next"

  local tmp; tmp="$(mktemp)"
  sed "s/$cur/$next/g" "$SW" > "$tmp"
  apply "$SW" "$tmp" "CACHE_NAME -> $next"

  bump_sitemap_lastmod
  if [ "$RUN" -eq 1 ]; then
    say "  next: git commit -m 'chore: bump sw cache to ${next##*-}'"
  fi
}

bump_sitemap_lastmod() {
  [ -f "$SITEMAP" ] || { warn "sitemap.xml missing; skipping lastmod"; return; }
  local d tmp; d="$(today)"; tmp="$(mktemp)"
  sed -E "s#<lastmod>[0-9]{4}-[0-9]{2}-[0-9]{2}</lastmod>#<lastmod>$d</lastmod>#g" \
    "$SITEMAP" > "$tmp"
  head_ "sitemap lastmod -> $d"
  apply "$SITEMAP" "$tmp" "lastmod $d"
}

# ── add portfolio/gallery item ──────────────────────────────
gen_alt() {
  [ -n "$ALT" ] && { printf '%s' "$ALT"; return; }
  # generate from label using the house voice
  printf '%s — luxury photography by DM Photofilmworks' "$LABEL"
}

cmd_add() {
  check_paths
  [ -n "$NAME" ]  || die "add requires --name (e.g. new-portrait-IMGL9001)"
  [ -n "$LABEL" ] || die "add requires --label (e.g. \"Fine-Art Portrait\")"
  local rel="assets/images/optimized/${NAME}.jpg"
  local abs="$APP/$rel"
  local alt; alt="$(gen_alt)"

  head_ "add portfolio item: $LABEL"
  say "  asset: $rel"
  say "  alt  : $alt"

  if [ ! -f "$abs" ]; then
    warn "optimized asset missing: $abs"
    say  "  -> optimize it FIRST (delegated, not done here):"
    say  "     media-pipeline: scripts/media.sh optimize <raw> --run   (WebP/AVIF+srcset)"
    say  "     or in-repo    : ./optimize-images.sh"
    [ "$DO_OPT" -eq 1 ] && say "  (--optimize only PRINTS the command above; it does not resize)"
    [ "$RUN" -eq 1 ] && die "refusing to --run add: optimized asset does not exist yet"
  fi

  # sizing: tall -> 1200x1800, else 1200x800
  local w=1200 h=800; [ "$SPAN" = "tall" ] && h=1800
  local cls="portfolio-item"; [ "$SPAN" = "tall" ] && cls="portfolio-item tall"
  [ "$SPAN" = "wide" ] && cls="portfolio-item wide"

  # 1) index.html — insert a .portfolio-item before the grid's closing tag
  if [ -f "$INDEX" ]; then
    local block tmp
    block="            <div class=\"$cls\">\n\
                <img src=\"$rel\" alt=\"$alt\" loading=\"lazy\" width=\"$w\" height=\"$h\">\n\
                <div class=\"portfolio-item-overlay\"><span class=\"portfolio-item-label\">$LABEL</span></div>\n\
            </div>"
    tmp="$(mktemp)"
    # insert before the first </div> that closes .portfolio-grid:
    # marker = line containing 'portfolio-grid' opening; we append at end of that grid.
    awk -v blk="$block" '
      BEGIN{ ins=0; depth=0; inside=0 }
      {
        if ($0 ~ /class="portfolio-grid"/) { inside=1 }
        # when inside grid, insert our block right after the grid opens
        print $0
        if (inside==1 && ins==0 && $0 ~ /class="portfolio-grid"/) {
          gsub(/\\n/,"\n",blk); print blk; ins=1
        }
      }' "$INDEX" > "$tmp"
    head_ "index.html .portfolio-grid"
    apply "$INDEX" "$tmp" "insert $LABEL item"
  else
    warn "index.html missing; skipping portfolio grid"
  fi

  # 2) scene.js — append URL to PHOTO_URLS array (before its closing '];')
  if [ -f "$SCENE" ]; then
    local tmp; tmp="$(mktemp)"
    # Buffer lines inside the array so we can add a trailing comma to the LAST
    # existing entry (the repo's final entry has none) before appending ours —
    # otherwise --run would emit two adjacent string literals = invalid JS.
    awk -v url="        '$rel'," '
      BEGIN{ inarr=0; done=0; havePrev=0; prev="" }
      {
        if ($0 ~ /const PHOTO_URLS = \[/) { inarr=1; print; next }
        if (inarr==1 && done==0 && $0 ~ /^[[:space:]]*\];[[:space:]]*$/) {
          if (havePrev) {
            # commify prev only if it is a quoted entry lacking a trailing comma
            if (prev ~ /'"'"'[^'"'"']*'"'"'/ && prev !~ /,[[:space:]]*$/) {
              sub(/[[:space:]]*$/, "", prev); prev = prev ","
            }
            print prev; havePrev=0
          }
          print url          # our new entry (trailing comma OK as last element)
          print $0           # the ];
          done=1; inarr=0; next
        }
        if (inarr==1 && done==0) {   # array content line — buffer it
          if (havePrev) print prev
          prev=$0; havePrev=1; next
        }
        print $0
      }
      END { if (havePrev) print prev }' "$SCENE" > "$tmp"
    head_ "scene.js PHOTO_URLS (WebGL gallery)"
    apply "$SCENE" "$tmp" "append $rel (+ comma on prior entry)"
  else
    warn "scene.js missing; skipping 3D gallery"
  fi

  # 3) sitemap lastmod + 4) cache bump (adding an asset ships new content)
  bump_sitemap_lastmod
  cmd_bump
}

# ── verify ──────────────────────────────────────────────────
cmd_verify() {
  check_paths
  local rc=0
  head_ "verify"

  local cur="$(current_version)"
  say "  sw.js CACHE_NAME: ${cur:-MISSING}"
  [ -n "$cur" ] || { warn "no CACHE_NAME"; rc=1; }
  # uniqueness vs git history
  if command -v git >/dev/null 2>&1 && git -C "$APP" rev-parse >/dev/null 2>&1; then
    if [ -n "$cur" ] && git -C "$APP" log -S "$cur" --oneline -- sw.js 2>/dev/null | grep -q .; then
      warn "CACHE_NAME '$cur' already appears in git history — bump before shipping"
      rc=1
    else
      say "  version appears unique vs git history: OK"
    fi
  fi

  # PHOTO_URLS present + count derivation intact
  if [ -f "$SCENE" ]; then
    local n
    n="$(awk '/const PHOTO_URLS = \[/{f=1;next} /^\s*\];/{f=0} f&&/assets\/images\/optimized/{c++} END{print c+0}' "$SCENE")"
    say "  scene.js PHOTO_URLS entries: $n"
    grep -q "PHOTO_URLS.length" "$SCENE" && say "  PHOTO_COUNT derives from length: OK" \
      || { warn "PHOTO_COUNT not derived from PHOTO_URLS.length"; rc=1; }
  fi

  # every portfolio <img src> resolves on disk
  if [ -f "$INDEX" ]; then
    local missing=0 src
    for src in $(grep -Eo 'assets/images/optimized/[^"]+' "$INDEX" | sort -u); do
      [ -f "$APP/$src" ] || { warn "portfolio img missing on disk: $src"; missing=$((missing+1)); }
    done
    [ "$missing" -eq 0 ] && say "  all portfolio images resolve on disk: OK" || rc=1
  fi

  # sitemap lastmod parses
  if [ -f "$SITEMAP" ]; then
    grep -Eq "<lastmod>[0-9]{4}-[0-9]{2}-[0-9]{2}</lastmod>" "$SITEMAP" \
      && say "  sitemap lastmod parses: OK" || { warn "sitemap lastmod malformed/missing"; rc=1; }
  fi

  say ""
  [ "$rc" -eq 0 ] && say "VERIFY: PASS" || say "VERIFY: issues found"
  return $rc
}

usage() {
  cat <<EOF
$SELF — photo-film-works PWA cache + portfolio helper (dry-run by default)

  $SELF bump   [--run] [--date YYYY-MM-DD]
  $SELF add    --name <slug> --label "<Label>" [--alt "<text>"]
               [--span tall|wide|none] [--optimize] [--run]
  $SELF verify

Notes:
  * DRY-RUN unless --run. Image optimization is delegated to media-pipeline.
  * Optimized asset must exist at assets/images/optimized/<name>.jpg for add --run.
  * GILDED_ROOT overrides the ecosystem root (default ~/GILDED-EDGE-ECOSYSTEM).
EOF
}

# ── arg parse ───────────────────────────────────────────────
[ $# -ge 1 ] || { usage; exit 1; }
CMD="$1"; shift
while [ $# -gt 0 ]; do
  case "$1" in
    --run) RUN=1;;
    --optimize) DO_OPT=1;;
    --name)  NAME="$2"; shift;;
    --label) LABEL="$2"; shift;;
    --alt)   ALT="$2"; shift;;
    --span)  SPAN="$2"; shift;;
    --date)  DATE="$2"; shift;;
    -h|--help) usage; exit 0;;
    *) die "unknown arg: $1";;
  esac
  shift
done

case "$CMD" in
  bump)   cmd_bump;;
  add)    cmd_add;;
  verify) cmd_verify;;
  -h|--help|help) usage;;
  *) die "unknown command: $CMD (bump|add|verify)";;
esac
