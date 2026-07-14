#!/usr/bin/env bash
# render-pipeline.sh — staged orchestrator for the edge-os-works cinematic flow.
# bash 3.2 safe. PLAN/DRY-RUN by default. Paid stages REFUSE to spend without --run.
# Never prints API key VALUES. GILDED_ROOT override. Delegates ffmpeg to media-pipeline.
set -eu

GILDED_ROOT="${GILDED_ROOT:-$HOME/GILDED-EDGE-ECOSYSTEM}"
EDGE="$GILDED_ROOT/ventures/edge-os-works"
SEEDANCE_DIR="$EDGE/seedance"
MEDIA_SKILL="$HOME/.claude/skills/media-pipeline/scripts/media.sh"

# ── Rough planning rate table ($ per output second). ESTIMATE ONLY. ───
# Update when provider pricing changes; this is a spend guard, not a bill.
RATE_SEEDANCE="0.50"        # bytedance/seedance-2.0 image-to-video
RATE_SEEDANCE_FAST="0.20"   # /fast/ tier
RATE_VEO="0.75"             # veo-3.0-generate-001
RATE_VEO_FAST="0.40"        # veo-3.0-fast-generate-001
RATE_REPLICATE="0.30"       # generic i2v/t2v fallback

# ── flags ─────────────────────────────────────────────────────────────
RUN=0; SCENES=5; DURATION=5; MODEL=""; FAST=0; OUT=""; FPS=12
POSITIONAL=""
CMD="${1:-plan}"; [ "$#" -gt 0 ] && shift || true
while [ "$#" -gt 0 ]; do
  case "$1" in
    --run) RUN=1; shift ;;
    --fast) FAST=1; shift ;;
    --scenes) SCENES="${2:-5}"; shift 2 ;;
    --duration) DURATION="${2:-5}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --fps) FPS="${2:-12}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    *) POSITIONAL="$POSITIONAL $1"; shift ;;
  esac
done
set -- $POSITIONAL

# ── helpers ───────────────────────────────────────────────────────────
have() { command -v "$1" >/dev/null 2>&1; }
key_present() { # $1 = var name; prints ✓/✗ WITHOUT the value
  eval "v=\${$1:-}"
  if [ -n "$v" ]; then echo "  ✓ $1 present"; return 0; else echo "  ✗ $1 MISSING (export it before a paid run)"; return 1; fi
}
dep_present() { # $1 = node module, $2 = install hint dir
  if [ -d "$EDGE/node_modules/$1" ]; then echo "  ✓ dep $1"; return 0
  else echo "  ✗ dep $1 missing → (cd $EDGE && npm i ${1})"; return 1; fi
}
# multiply two decimals (2dp) without bc, bash-3.2 / awk
money() { awk -v a="$1" -v b="$2" -v c="$3" 'BEGIN{printf "%.2f", a*b*c}'; }

banner() { echo "== cinematic-render-pipeline :: $1 =="; }

# ── preflight: the cost guard (also used internally by paid stages) ───
# usage: do_preflight <seedance|veo|replicate>  → returns 0 if safe to spend
do_preflight() {
  provider="$1"
  banner "preflight ($provider)"
  ok=1

  # 1. param validation
  case "$SCENES" in ''|*[!0-9]*) echo "  ✗ --scenes must be a positive integer"; ok=0 ;; esac
  case "$DURATION" in ''|*[!0-9]*) echo "  ✗ --duration must be an integer (seconds)"; ok=0 ;; esac
  [ "${SCENES:-0}" -ge 1 ] 2>/dev/null || { echo "  ✗ need at least 1 scene"; ok=0; }

  rate=""; keyvar=""; dep=""; mdl="$MODEL"
  case "$provider" in
    seedance)
      keyvar="FAL_KEY"; dep="@fal-ai/client"
      if [ "$FAST" -eq 1 ]; then rate="$RATE_SEEDANCE_FAST"; [ -z "$mdl" ] && mdl="bytedance/seedance-2.0/fast/image-to-video"
      else rate="$RATE_SEEDANCE"; [ -z "$mdl" ] && mdl="bytedance/seedance-2.0/image-to-video"; fi
      # duration range check (seedance clips ~3–12s)
      if [ "$DURATION" -lt 3 ] || [ "$DURATION" -gt 12 ]; then echo "  ✗ seedance duration out of range (3–12s), got ${DURATION}s"; ok=0; fi
      # i2v needs first-frame assets
      if [ ! -d "$SEEDANCE_DIR/assets" ]; then echo "  ✗ no seedance/assets (image→video needs first-frame PNGs)"; ok=0
      else echo "  ✓ seedance/assets present ($(ls "$SEEDANCE_DIR/assets" 2>/dev/null | grep -c '.' ) files)"; fi
      ;;
    veo)
      keyvar="GEMINI_API_KEY"; dep="@google/genai"
      if [ "$FAST" -eq 1 ]; then rate="$RATE_VEO_FAST"; [ -z "$mdl" ] && mdl="veo-3.0-fast-generate-001"
      else rate="$RATE_VEO"; [ -z "$mdl" ] && mdl="veo-3.0-generate-001"; fi
      if [ "$DURATION" -lt 2 ] || [ "$DURATION" -gt 8 ]; then echo "  ✗ veo duration out of typical range (2–8s), got ${DURATION}s"; ok=0; fi
      case "$mdl" in veo-3.*generate-001) : ;; *) echo "  ✗ unknown veo model '$mdl' (expected veo-3.x-*generate-001)"; ok=0 ;; esac
      ;;
    replicate)
      keyvar="REPLICATE_API_TOKEN"; dep="replicate"; rate="$RATE_REPLICATE"
      [ -z "$mdl" ] && mdl="(set --model owner/name:version)"
      ;;
    *) echo "  ✗ unknown provider '$provider' (seedance|veo|replicate)"; return 2 ;;
  esac
  echo "  model   : $mdl"

  # 2. key present (value never printed)
  key_present "$keyvar" || ok=0
  # dependency present (informational — doesn't block the estimate)
  dep_present "$dep" || true

  # 3. cost estimate
  est="$(money "$SCENES" "$DURATION" "$rate")"
  echo "  estimate: $SCENES scenes × ${DURATION}s × \$${rate}/s  ≈  \$$est   (ESTIMATE — verify provider pricing)"

  if [ "$ok" -eq 1 ]; then
    echo "  → preflight PASSED. Add --run to actually spend."
    return 0
  else
    echo "  → preflight FAILED. Fix the ✗ items above; no paid call will be made."
    return 1
  fi
}

# guarded paid stage runner
guarded_paid() {
  provider="$1"; script="$2"
  if ! do_preflight "$provider"; then exit 1; fi
  if [ "$RUN" -eq 0 ]; then
    echo
    echo "PLAN ONLY — not spending. To run the real generation:"
    faststr=""; [ "$FAST" -eq 1 ] && faststr="--fast "
    echo "  bash render-pipeline.sh $provider --scenes $SCENES --duration $DURATION ${faststr}--run"
    echo "  (invokes: $script)"
    exit 0
  fi
  # --run given AND preflight passed → hand off to the real script
  if [ ! -f "$script" ]; then echo "✗ generator script not found: $script"; exit 1; fi
  echo
  echo "▶ RUNNING PAID GENERATION → $script"
  case "$provider" in
    seedance) ( cd "$SEEDANCE_DIR" && node "$script" $( [ "$FAST" -eq 1 ] && echo --fast ) ) ;;
    veo)      ( cd "$EDGE" && node "$script" ) ;;
    *)        echo "✗ no runner wired for $provider"; exit 1 ;;
  esac
}

# ── dispatch ──────────────────────────────────────────────────────────
case "$CMD" in
  check)
    banner "check"
    echo "GILDED_ROOT = $GILDED_ROOT"
    echo "edge-os     = $([ -d "$EDGE" ] && echo ✓ || echo '✗ not found')"
    have node && echo "node        ✓ $(node -v)" || echo "node        ✗"
    have ffmpeg && echo "ffmpeg      ✓ (system)" || echo "ffmpeg      ✗ (media-pipeline will find ffmpeg-static or tell you)"
    have git && (git lfs version >/dev/null 2>&1 && echo "git-lfs     ✓" || echo "git-lfs     ✗ (lfs stage prints manual commands)") || echo "git         ✗"
    [ -f "$MEDIA_SKILL" ] && echo "media-pipe  ✓ $MEDIA_SKILL" || echo "media-pipe  ✗ (install the media-pipeline skill for frames/stitch)"
    echo "-- API keys (values never shown) --"
    key_present FAL_KEY || true
    key_present GEMINI_API_KEY || true
    key_present REPLICATE_API_TOKEN || true
    ;;

  plan)
    banner "plan"
    cat <<PLAN
Stages (→ = delegates to another skill). Nothing runs here.
  0 screenshots  capture dashboard PNGs into seedance/assets & edge-commercial/public
  1 frames       → media-pipeline: media.sh frames <video> --fps $FPS --format webp
  2a remotion    → remotion-composition-builder (FREE, deterministic UI compositing)
  2b seedance    PAID i2v (fal). Guard: preflight seedance ; run: seedance --run
  3 veo          PAID t2v (Google). Guard: preflight veo ; run: veo --run
  4 stitch       → media-pipeline: media.sh transcode / concat clips
  5 atlas        → media-pipeline frames → sprite atlas for the scroll player
  6 lfs          git lfs track '*.mp4' && git add

Recommended order for the edge-os commercial:
  screenshots → (2a remotion for UI shots)  OR  (preflight seedance → seedance --run)
             → stitch → frames → atlas → lfs
Always: run 'preflight' before any paid stage.
PLAN
    ;;

  preflight)
    prov="${1:-}"
    [ -z "$prov" ] && { echo "usage: preflight <seedance|veo|replicate> [--scenes N --duration S --model M --fast]"; exit 2; }
    do_preflight "$prov" || exit 1
    ;;

  screenshots)
    banner "screenshots (plan)"
    echo "Capture real dashboard PNGs (the generate-cinematic.mjs inputs):"
    echo "  required in $SEEDANCE_DIR/assets/ : real-portal-home.png real-pipeline.png real-analytics.png real-crm-hub.png"
    echo "  also used by Remotion: $EDGE/remotion/edge-commercial/public/"
    echo "Use a headless browser / the webapp-testing skill to screenshot the live dashboards, then drop PNGs here."
    ;;

  frames)
    src="${1:-}"
    [ -z "$src" ] && { echo "usage: frames <video.mp4> [--fps 12] [--run]"; exit 2; }
    banner "frames (delegates to media-pipeline)"
    if [ -f "$MEDIA_SKILL" ]; then
      echo "→ media-pipeline handles ffmpeg frame extraction:"
      echo "  bash $MEDIA_SKILL frames \"$src\" --fps $FPS --scale 1920:1080 --format webp --out $EDGE/public/frames $( [ "$RUN" -eq 1 ] && echo --run )"
      [ "$RUN" -eq 1 ] && bash "$MEDIA_SKILL" frames "$src" --fps "$FPS" --scale 1920:1080 --format webp --out "$EDGE/public/frames" --run || echo "(dry-run; add --run)"
    else
      echo "✗ media-pipeline skill not found; install it or run extract-frames.mjs manually."
    fi
    ;;

  remotion)
    banner "remotion (free, delegates to remotion-composition-builder)"
    echo "For UI/screenshot compositing use the remotion-composition-builder skill:"
    echo "  bash ~/.claude/skills/remotion-composition-builder/scripts/new-composition.sh <spec.json> --venture edge-os-works"
    echo "Then: cd $EDGE/remotion/edge-commercial && npx remotion render <CompId> out/<CompId>.mp4 --codec h264"
    ;;

  seedance)
    guarded_paid seedance "$SEEDANCE_DIR/generate-cinematic.mjs"
    ;;

  veo)
    guarded_paid veo "$EDGE/generate-video.mjs"
    ;;

  replicate)
    if ! do_preflight replicate; then exit 1; fi
    echo; echo "PLAN ONLY — no replicate runner is wired (no committed script). Preflight validated params/key/cost above."
    echo "Wire your replicate call, then guard it the same way (preflight → --run)."
    ;;

  stitch)
    banner "stitch (delegates to media-pipeline)"
    [ -z "$OUT" ] && OUT="$EDGE/generated-videos/edge-cinematic.mp4"
    echo "Concatenate the scene clips, then transcode to a clean h264 mp4:"
    echo "  # (media-pipeline transcode; for concat use an ffmpeg concat list — see generate-video.mjs)"
    echo "  bash $MEDIA_SKILL transcode <concat-or-input> --to mp4 --crf 20 --out \"$OUT\" $( [ "$RUN" -eq 1 ] && echo --run )"
    echo "Inputs given: $*"
    ;;

  atlas)
    banner "atlas (plan)"
    echo "Sprite atlas = frames (media-pipeline) packed into a sheet (seedance/generate-atlas.mjs logic)."
    echo "  1) bash render-pipeline.sh frames <video.mp4> --fps $FPS --run"
    echo "  2) node $SEEDANCE_DIR/generate-atlas.mjs   (packs public/frames → atlas + manifest)"
    echo "(kept as a thin pointer; the packing math lives in generate-atlas.mjs)"
    ;;

  lfs)
    src="${1:-}"
    [ -z "$src" ] && { echo "usage: lfs <output.mp4> [--run]"; exit 2; }
    banner "lfs"
    echo "Track large media in git-lfs, not plain git (edge-os has .gitattributes):"
    echo "  cd $EDGE"
    echo "  git lfs track '*.mp4' 'public/frames/**'"
    echo "  git add .gitattributes \"$src\""
    if [ "$RUN" -eq 1 ]; then
      if git -C "$EDGE" lfs version >/dev/null 2>&1; then
        ( cd "$EDGE" && git lfs track '*.mp4' 'public/frames/**' && git add .gitattributes "$src" 2>/dev/null ) && echo "✓ tracked + staged $src"
      else
        echo "✗ git-lfs not installed — run 'brew install git-lfs && git lfs install' then re-run."
      fi
    else
      echo "(dry-run; add --run to track + stage)"
    fi
    ;;

  *)
    echo "usage: render-pipeline.sh <check|plan|preflight|screenshots|frames|remotion|seedance|veo|replicate|stitch|atlas|lfs> [flags]" >&2
    echo "  paid stages (seedance|veo|replicate) preflight automatically and refuse to spend without --run" >&2
    exit 2
    ;;
esac
