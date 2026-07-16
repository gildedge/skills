#!/usr/bin/env bash
# new-composition.sh — scaffold a Remotion v4 composition from a scene spec.
# bash 3.2 safe. Dry-run by default; --run writes files. GILDED_ROOT override.
set -eu

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMPL="$SKILL_DIR/assets/composition.tsx.tmpl"
GILDED_ROOT="${GILDED_ROOT:-$HOME/GILDED-EDGE-ECOSYSTEM}"

VENTURE="lumier-pictures"
RUN=0
PATCH_ROOT=0
SPEC=""

# ── arg parse ────────────────────────────────────────────────────────
CMD="${1:-}"
if [ "$CMD" = "check" ]; then
  echo "== remotion-composition-builder :: toolchain =="
  echo "GILDED_ROOT = $GILDED_ROOT"
  command -v node >/dev/null 2>&1 && echo "node        ✓ $(node -v)" || echo "node        ✗ (needed to parse the spec JSON)"
  command -v npx  >/dev/null 2>&1 && echo "npx         ✓" || echo "npx         ✗ (needed for 'npx remotion render')"
  echo "-- detected remotion ventures --"
  for v in lumier-pictures lumier-studios edge-os-works; do
    if [ -d "$GILDED_ROOT/ventures/$v/remotion" ]; then
      echo "  ✓ $v"
    else
      echo "  ✗ $v (no remotion/ dir)"
    fi
  done
  exit 0
fi

for a in "$@"; do
  case "$a" in
    --run) RUN=1 ;;
    --patch-root) PATCH_ROOT=1 ;;
    --venture=*) VENTURE="${a#--venture=}" ;;
    --venture) : ;;                 # value handled below
    *.json) SPEC="$a" ;;
  esac
done
# support "--venture NAME" (space form)
prev=""
for a in "$@"; do
  if [ "$prev" = "--venture" ]; then VENTURE="$a"; fi
  prev="$a"
done

if [ -z "$SPEC" ]; then
  echo "usage: new-composition.sh <spec.json> [--venture lumier-pictures|lumier-studios|edge-os-works] [--run] [--patch-root]" >&2
  echo "       new-composition.sh check" >&2
  exit 2
fi
if [ ! -f "$SPEC" ]; then echo "✗ spec not found: $SPEC" >&2; exit 1; fi
if ! command -v node >/dev/null 2>&1; then echo "✗ node required to parse the spec" >&2; exit 1; fi
# absolutize so node require() resolves it regardless of cwd
case "$SPEC" in /*) : ;; *) SPEC="$(cd "$(dirname "$SPEC")" && pwd)/$(basename "$SPEC")" ;; esac

# ── resolve venture paths ────────────────────────────────────────────
case "$VENTURE" in
  edge-os-works)
    REMOTION_DIR="$GILDED_ROOT/ventures/edge-os-works/remotion/edge-commercial"
    COMPS_SUBDIR="src"
    ROOT_FILE="$REMOTION_DIR/src/Root.tsx"
    LAYOUT="sibling"               # Root.tsx and comp are siblings in src/
    RENDER_ENTRY=""                # edge renders by comp id from inside the folder
    ;;
  lumier-pictures|lumier-studios)
    REMOTION_DIR="$GILDED_ROOT/ventures/$VENTURE/remotion"
    COMPS_SUBDIR="compositions"
    ROOT_FILE="$REMOTION_DIR/Root.tsx"
    LAYOUT="nested"               # Root.tsx one level above compositions/
    RENDER_ENTRY="remotion/index.ts"
    ;;
  *)
    echo "✗ unknown venture: $VENTURE (expected lumier-pictures | lumier-studios | edge-os-works)" >&2
    exit 1
    ;;
esac

# ── read spec + compute derived values via node (no npm deps) ────────
NAME="$(node -e 'const s=require(process.argv[1]);process.stdout.write((s.name||"MyComposition").replace(/[^A-Za-z0-9]/g,""))' "$SPEC")"
TOTAL="$(node -e 'const s=require(process.argv[1]);let t=0;(s.scenes||[]).forEach(x=>t+=(x.durationInFrames||150));process.stdout.write(String(t||150))' "$SPEC")"
FPS="$(node -e 'const s=require(process.argv[1]);process.stdout.write(String(s.fps||30))' "$SPEC")"
W="$(node -e 'const s=require(process.argv[1]);process.stdout.write(String(s.width||1920))' "$SPEC")"
H="$(node -e 'const s=require(process.argv[1]);process.stdout.write(String(s.height||1080))' "$SPEC")"

# import path is relative to Root.tsx (sibling for edge-os, nested for lumier)
if [ "$LAYOUT" = "sibling" ]; then IMPORT_PATH="./$NAME"; else IMPORT_PATH="./compositions/$NAME.tsx"; fi

# brand token block (edge-os indigo/cyan/gold vs lumier gold/obsidian)
BRAND_JSON="$(node -e '
const s=require(process.argv[1]);
const bg = s.background || "#09090b";
const edge = { text:"white", glow:"rgba(99,102,241,0.15)", background:bg };
const lum  = { text:"#FFFFFF", glow:"rgba(212,175,55,0.18)", background:bg };
const b = (s.brand==="lumier") ? lum : edge;
process.stdout.write(JSON.stringify(b));
' "$SPEC")"

# build the <Sequence> blocks + the Root.tsx <Composition> line
SEQS="$(node -e '
const s=require(process.argv[1]);
let from=0, out="";
(s.scenes||[]).forEach((sc,i)=>{
  const d=sc.durationInFrames||150;
  out += "      <Sequence from={"+from+"} durationInFrames={"+d+"}>\n";
  if(sc.image) out += "        <CinematicUI src="+JSON.stringify(sc.image)+" startFrame={"+from+"} animationType="+JSON.stringify(sc.animation||"fade-in")+" />\n";
  if(sc.title) out += "        <TitleFade text="+JSON.stringify(sc.title)+" delay={20} />\n";
  out += "      </Sequence>\n";
  from += d;
});
process.stdout.write(out.replace(/\n$/,""));
' "$SPEC")"

# ── render the template ──────────────────────────────────────────────
TSX="$(cat "$TMPL")"
# perl for safe multiline/special-char substitution (present on macOS)
OUT_TSX="$(NAME="$NAME" BRAND_JSON="$BRAND_JSON" SEQS="$SEQS" perl -0pe '
  s/__NAME__/$ENV{NAME}/g;
  s/__BRAND__/$ENV{BRAND_JSON}/g;
  s/__SEQUENCES__/$ENV{SEQS}/g;
' <<EOF
$TSX
EOF
)"

TARGET="$REMOTION_DIR/$COMPS_SUBDIR/$NAME.tsx"

COMP_LINE="      <Composition
        id=\"$NAME\"
        component={$NAME}
        durationInFrames={$TOTAL}
        fps={$FPS}
        width={$W}
        height={$H}
      />"

echo "== remotion-composition-builder =="
echo "venture : $VENTURE"
echo "name    : $NAME   (id + component + file)"
echo "duration: $TOTAL frames @ ${FPS}fps  (${W}x${H})"
echo "target  : $TARGET"
echo "root    : $ROOT_FILE"
echo

if [ "$RUN" -eq 0 ]; then
  echo "----- DRY RUN (add --run to write) -----"
  echo "----- $NAME.tsx -----"
  printf '%s\n' "$OUT_TSX"
  echo
  echo "----- paste into $ROOT_FILE (inside <RemotionRoot>) -----"
  echo "import { $NAME } from \"$IMPORT_PATH\";"
  printf '%s\n' "$COMP_LINE"
else
  mkdir -p "$REMOTION_DIR/$COMPS_SUBDIR"
  if [ -f "$TARGET" ]; then echo "✗ refuse to overwrite existing $TARGET (delete it or rename in spec)"; exit 1; fi
  printf '%s\n' "$OUT_TSX" > "$TARGET"
  echo "✓ wrote $TARGET"
  if [ "$PATCH_ROOT" -eq 1 ]; then
    if [ ! -f "$ROOT_FILE" ]; then echo "✗ Root.tsx not found at $ROOT_FILE — printed the line instead:"; printf '%s\n' "$COMP_LINE"; exit 0; fi
    if grep -q "id=\"$NAME\"" "$ROOT_FILE"; then echo "✗ Root.tsx already has a Composition id=\"$NAME\" — not patching."; exit 0; fi
    echo "  (auto-patch of Root.tsx is intentionally manual — paste this after the last </Composition>):"
    echo "import { $NAME } from \"$IMPORT_PATH\";"
    printf '%s\n' "$COMP_LINE"
  fi
fi

echo
echo "----- render command -----"
if [ -n "$RENDER_ENTRY" ]; then
  echo "cd $GILDED_ROOT/ventures/$VENTURE && npx remotion render $RENDER_ENTRY $NAME out/$NAME.mp4 --codec h264"
else
  echo "cd $REMOTION_DIR && npx remotion render $NAME out/$NAME.mp4 --codec h264"
fi
echo "(after render, hand frames/transcode to the media-pipeline skill)"
