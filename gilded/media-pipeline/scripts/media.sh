#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  Gilded Edge — media.sh
#  Unified helper for the recurring media chores across
#  edge-os-works, photo-film-works, aria-agent, lumier-pictures:
#
#    check       report which tools are installed + how to get them
#    probe       show media metadata (duration/size/streams)
#    transcode   re-encode / rename a video (ffmpeg)
#    frames      extract WebP/JPEG frames for scroll players (ffmpeg)
#    transcribe  captions .srt/.vtt/.txt (whisper / faster-whisper)
#    optimize    images -> WebP/AVIF + responsive srcset (sharp | sips)
#
#  SAFE BY DEFAULT: every command DRY-RUNS (prints what it would
#  run, writes nothing). Add --run to actually execute.
#
#  Degrades gracefully: no Homebrew assumed; ffmpeg via system or
#  the ffmpeg-static npm package already in edge-os-works; images
#  fall back to macOS `sips` exactly like photo-film-works does.
#  bash 3.2 compatible.
# ═══════════════════════════════════════════════════════════

set -u
SELF="$(basename "$0")"
RUN=0   # 0 = dry-run (default), 1 = execute

# ── pretty output ────────────────────────────────────────────
say()  { printf '%s\n' "$*"; }
head_() { printf '\n== %s ==\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# directory this script lives in (for sibling helpers)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# absolute path for a file or dir (bash 3.2, no realpath dependency)
abspath() {
  case "$1" in
    /*) printf '%s\n' "$1";;
    *)  if [ -d "$1" ]; then (cd "$1" && pwd)
        else printf '%s/%s\n' "$(cd "$(dirname "$1")" && pwd)" "$(basename "$1")"; fi;;
  esac
}

# Print a command; run it only if --run was given.
do_cmd() {
  if [ "$RUN" -eq 1 ]; then
    printf '  RUN  %s\n' "$*"
    eval "$@"
  else
    printf '  DRY  %s\n' "$*"
  fi
}

# ── tool detection (no brew assumed) ─────────────────────────
# Candidate ventures that already carry ffmpeg-static in node_modules.
ECO="${GILDED_ECO:-$HOME/GILDED-EDGE-ECOSYSTEM}"
FFMPEG_VENTURES="$ECO/ventures/edge-os-works $ECO/ventures/aria-agent $ECO/ventures/lumier-pictures"

find_ffmpeg() {
  # 1) system ffmpeg
  if command -v ffmpeg >/dev/null 2>&1; then command -v ffmpeg; return 0; fi
  # 2) ffmpeg-static npm package resolved from a venture (like extract-frames.mjs)
  if command -v node >/dev/null 2>&1; then
    for v in $FFMPEG_VENTURES; do
      [ -d "$v" ] || continue
      p=$(cd "$v" && node -e "try{process.stdout.write(require('ffmpeg-static')||'')}catch(e){}" 2>/dev/null)
      if [ -n "$p" ] && [ -x "$p" ]; then printf '%s\n' "$p"; return 0; fi
    done
  fi
  return 1
}

find_whisper() {
  for c in whisper whisper-cli whisper-cpp faster-whisper; do
    if command -v "$c" >/dev/null 2>&1; then printf '%s\n' "$c"; return 0; fi
  done
  # python module form
  if command -v python3 >/dev/null 2>&1 && python3 -c "import whisper" >/dev/null 2>&1; then
    printf 'python3 -m whisper\n'; return 0
  fi
  return 1
}

find_sharp() {
  command -v node >/dev/null 2>&1 || return 1
  for v in $FFMPEG_VENTURES $ECO/ventures/photo-film-works $ECO/ventures/gildedge-portal; do
    [ -d "$v" ] || continue
    if (cd "$v" && node -e "require('sharp')" >/dev/null 2>&1); then printf '%s\n' "$v"; return 0; fi
  done
  return 1
}

find_sips() { command -v sips >/dev/null 2>&1 && command -v sips; }

# ── check ────────────────────────────────────────────────────
cmd_check() {
  head_ "media toolchain"
  if ff=$(find_ffmpeg); then say "ffmpeg     ✓  $ff"; else
    say "ffmpeg     ✗  not found"
    say "             install: brew install ffmpeg  — OR (no brew) —"
    say "             cd ventures/edge-os-works && npm i ffmpeg-static"; fi
  if wh=$(find_whisper); then say "whisper    ✓  $wh"; else
    say "whisper    ✗  not found  (transcribe unavailable)"
    say "             install: pipx install openai-whisper   (needs ffmpeg)"
    say "             or faster: pipx install faster-whisper"; fi
  if sh=$(find_sharp); then say "sharp      ✓  (node module in $sh)"; else
    say "sharp      ✗  not found  (will fall back to sips for images)"
    say "             install: cd <venture> && npm i sharp"; fi
  if sp=$(find_sips); then say "sips       ✓  $sp  (macOS built-in image fallback)"; else
    say "sips       ✗  not on this platform"; fi
  say ""
  say "Mode: $( [ "$RUN" -eq 1 ] && echo 'RUN (executes)' || echo 'DRY-RUN (default; add --run to execute)' )"
}

# ── probe ────────────────────────────────────────────────────
cmd_probe() {
  in="${1:-}"; [ -n "$in" ] || die "usage: $SELF probe <file> [--run]"
  [ -f "$in" ] || die "no such file: $in"
  ff=$(find_ffmpeg) || die "ffmpeg not available (run: $SELF check)"
  head_ "probe: $in"
  say "  size: $(stat -f%z "$in" 2>/dev/null || stat -c%s "$in" 2>/dev/null) bytes"
  # ffprobe ships beside system ffmpeg; ffmpeg-static has no ffprobe, so parse -i.
  if command -v ffprobe >/dev/null 2>&1; then
    do_cmd "ffprobe -v error -show_format -show_streams \"$in\""
  else
    do_cmd "$ff -hide_banner -i \"$in\" 2>&1 | grep -E 'Duration|Stream' || true"
  fi
}

# ── transcode / rename ───────────────────────────────────────
cmd_transcode() {
  in=""; to="mp4"; crf="20"; scale=""; out=""
  while [ $# -gt 0 ]; do case "$1" in
    --to) to="$2"; shift 2;;
    --crf) crf="$2"; shift 2;;
    --scale) scale="$2"; shift 2;;
    --out) out="$2"; shift 2;;
    --run) RUN=1; shift;;
    -*) die "unknown flag $1";;
    *) in="$1"; shift;;
  esac; done
  [ -n "$in" ] || die "usage: $SELF transcode <input> [--to mp4|webm|mov] [--crf 20] [--scale 1920:1080] [--out file] [--run]"
  [ -f "$in" ] || die "no such file: $in"
  ff=$(find_ffmpeg) || die "ffmpeg not available (run: $SELF check)"
  base="${in%.*}"; [ -n "$out" ] || out="${base}.${to}"
  vf=""; [ -n "$scale" ] && vf="-vf scale=${scale}:flags=lanczos"
  case "$to" in
    webm) venc="-c:v libvpx-vp9 -b:v 0 -crf ${crf} -c:a libopus";;
    mov)  venc="-c:v prores_ks -profile:v 3 -c:a pcm_s16le";;
    *)    venc="-c:v libx264 -preset fast -crf ${crf} -pix_fmt yuv420p -c:a aac -movflags +faststart";;
  esac
  head_ "transcode -> $out"
  do_cmd "$ff -y -i \"$in\" $vf $venc \"$out\""
}

# ── frames (scroll-player extraction) ────────────────────────
# Mirrors edge-os-works/extract-frames.mjs: fps=12, WebP q85, JPEG fallback.
cmd_frames() {
  in=""; fps="12"; scale="1920:1080"; fmt="webp"; out="frames"
  while [ $# -gt 0 ]; do case "$1" in
    --fps) fps="$2"; shift 2;;
    --scale) scale="$2"; shift 2;;
    --format) fmt="$2"; shift 2;;
    --out) out="$2"; shift 2;;
    --run) RUN=1; shift;;
    -*) die "unknown flag $1";;
    *) in="$1"; shift;;
  esac; done
  [ -n "$in" ] || die "usage: $SELF frames <input> [--fps 12] [--scale 1920:1080] [--format webp|jpg] [--out dir] [--run]"
  [ -f "$in" ] || die "no such file: $in"
  ff=$(find_ffmpeg) || die "ffmpeg not available (run: $SELF check)"
  head_ "frames -> $out/frame-%03d.$fmt  (fps=$fps, scale=$scale)"
  do_cmd "mkdir -p \"$out\""
  if [ "$fmt" = "webp" ]; then
    do_cmd "$ff -y -i \"$in\" -vf \"fps=${fps},scale=${scale}:flags=lanczos\" -c:v libwebp -quality 85 -compression_level 4 \"$out/frame-%03d.webp\""
    say "  (if libwebp is unavailable, re-run with --format jpg)"
  else
    do_cmd "$ff -y -i \"$in\" -vf \"fps=${fps},scale=${scale}:flags=lanczos\" -q:v 3 \"$out/frame-%03d.jpg\""
  fi
  if [ "$RUN" -eq 1 ]; then
    n=$(ls "$out" 2>/dev/null | grep -c "^frame-")
    say "  extracted $n frames -> update your ScrollCinematicLoader: totalFrames={$n} frameExt=\"$fmt\""
  fi
}

# ── transcribe / caption ─────────────────────────────────────
cmd_transcribe() {
  in=""; model="base"; fmt="srt"; out="."
  while [ $# -gt 0 ]; do case "$1" in
    --model) model="$2"; shift 2;;
    --format) fmt="$2"; shift 2;;
    --out) out="$2"; shift 2;;
    --run) RUN=1; shift;;
    -*) die "unknown flag $1";;
    *) in="$1"; shift;;
  esac; done
  [ -n "$in" ] || die "usage: $SELF transcribe <audio|video> [--model base] [--format srt|vtt|txt] [--out dir] [--run]"
  [ -f "$in" ] || die "no such file: $in"
  wh=$(find_whisper) || die "whisper not available. Install: pipx install openai-whisper (or faster-whisper). See: $SELF check"
  head_ "transcribe: $in ($wh, model=$model, $fmt)"
  do_cmd "mkdir -p \"$out\""
  case "$wh" in
    faster-whisper)
      do_cmd "faster-whisper \"$in\" --model $model --output_dir \"$out\" --output_format $fmt";;
    whisper-cli|whisper-cpp)
      # whisper.cpp wants 16k mono wav; extract first if we have ffmpeg.
      ff=$(find_ffmpeg || true)
      wav="$out/$(basename "${in%.*}").wav"
      [ -n "$ff" ] && do_cmd "$ff -y -i \"$in\" -ar 16000 -ac 1 \"$wav\"" || warn "no ffmpeg: feed a 16kHz mono wav to whisper.cpp yourself"
      do_cmd "$wh -m models/ggml-${model}.bin -f \"$wav\" -o${fmt}";;
    *)
      do_cmd "$wh \"$in\" --model $model --output_dir \"$out\" --output_format $fmt";;
  esac
}

# ── optimize images (WebP/AVIF + srcset) ─────────────────────
# Prefers sharp; falls back to macOS sips exactly like photo-film-works.
cmd_optimize() {
  src=""; widths="400,800,1200"; fmts="webp"; out="optimized"; q="82"
  while [ $# -gt 0 ]; do case "$1" in
    --widths) widths="$2"; shift 2;;
    --format) fmts="$2"; shift 2;;
    --quality) q="$2"; shift 2;;
    --out) out="$2"; shift 2;;
    --run) RUN=1; shift;;
    -*) die "unknown flag $1";;
    *) src="$1"; shift;;
  esac; done
  [ -n "$src" ] || die "usage: $SELF optimize <file|dir> [--widths 400,800,1200] [--format webp,avif] [--quality 82] [--out dir] [--run]"
  [ -e "$src" ] || die "no such path: $src"

  # collect input files
  files=""
  if [ -d "$src" ]; then
    for f in "$src"/*.jpg "$src"/*.jpeg "$src"/*.png; do [ -f "$f" ] && files="$files
$f"; done
  else files="$src"; fi
  [ -n "$files" ] || die "no jpg/png images found in $src"

  sharp_venture=$(find_sharp || true)
  sips_bin=$(find_sips || true)
  outabs=$(abspath "$out")
  head_ "optimize -> $out  (widths=$widths, formats=$fmts)"
  do_cmd "mkdir -p \"$outabs\""

  if [ -n "$sharp_venture" ]; then
    say "  engine: sharp (libvips) via $sharp_venture — WebP + AVIF, true srcset"
    OLD_IFS="$IFS"; IFS='
'
    for f in $files; do [ -n "$f" ] || continue
      fabs=$(abspath "$f")
      do_cmd "NODE_PATH=\"$sharp_venture/node_modules\" SRC=\"$fabs\" OUTDIR=\"$outabs\" WIDTHS=\"$widths\" FMTS=\"$fmts\" Q=\"$q\" node \"$SCRIPT_DIR/sharp-optimize.cjs\""
    done
    IFS="$OLD_IFS"
  elif [ -n "$sips_bin" ]; then
    say "  engine: sips (macOS built-in) — resample + WebP only (no AVIF; install sharp for AVIF)"
    OLD_IFS="$IFS"; IFS='
'
    for f in $files; do [ -n "$f" ] || continue
      fabs=$(abspath "$f"); bn=$(basename "${f%.*}")
      OLD2="$IFS"; IFS=','
      for w in $widths; do
        do_cmd "sips -s format webp -s formatOptions $q --resampleWidth $w \"$fabs\" --out \"$outabs/${bn}-${w}w.webp\""
      done
      IFS="$OLD2"
    done
    IFS="$OLD_IFS"
    warn "sips cannot emit AVIF — WebP variants only. Add sharp to a venture for AVIF."
  else
    die "no image engine: install sharp (npm i sharp) or run on macOS with sips."
  fi

  # print a ready-to-paste responsive snippet for the first image
  first=$(printf '%s' "$files" | sed -n '2p'); [ -n "$first" ] || first=$(printf '%s' "$files" | head -1)
  bn=$(basename "${first%.*}")
  head_ "responsive srcset snippet"
  _print_srcset "$bn" "$widths" "$out"
}

_print_srcset() {
  bn="$1"; widths="$2"; out="$3"
  say "<img"
  say "  src=\"$out/${bn}-800w.webp\""
  printf '  srcset="'
  OLD="$IFS"; IFS=','; first=1
  for w in $widths; do [ $first -eq 1 ] || printf ', '; printf '%s' "$out/${bn}-${w}w.webp ${w}w"; first=0; done
  IFS="$OLD"; printf '"\n'
  say "  sizes=\"(max-width: 768px) 100vw, 50vw\""
  say "  loading=\"lazy\" decoding=\"async\" alt=\"\">"
}

# ── dispatch ─────────────────────────────────────────────────
# strip a global --run anywhere (subcommands also accept it)
for a in "$@"; do [ "$a" = "--run" ] && RUN=1; done

sub="${1:-}"; [ $# -gt 0 ] && shift
case "$sub" in
  check)      cmd_check "$@";;
  probe)      cmd_probe "$@";;
  transcode)  cmd_transcode "$@";;
  frames)     cmd_frames "$@";;
  transcribe|caption) cmd_transcribe "$@";;
  optimize)   cmd_optimize "$@";;
  ""|-h|--help|help)
    say "Gilded Edge media.sh — unified media chores (dry-run by default)"
    say ""
    say "  $SELF check                          tool availability + install hints"
    say "  $SELF probe <file>                   show metadata"
    say "  $SELF transcode <in> [--to mp4] ...  re-encode / rename video"
    say "  $SELF frames <in> [--fps 12] ...     extract WebP/JPEG frames"
    say "  $SELF transcribe <in> [--model base] captions (srt/vtt/txt)"
    say "  $SELF optimize <dir> [--format webp,avif] images + srcset"
    say ""
    say "Add --run to execute. Without it, commands are printed only."
    ;;
  *) die "unknown command '$sub' (try: $SELF help)";;
esac
