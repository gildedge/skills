#!/usr/bin/env bash
# scaffold-eval.sh — scaffold a golden-case eval suite for an AI feature.
# bash 3.2 safe. DRY-RUN by default: prints what it WOULD create, writes nothing.
# Pass --write to create the files. Pass --promptfoo to also emit a promptfoo config.
#
# Usage:
#   scaffold-eval.sh --feature form-field-extraction [--venture gilded-form-works] \
#                    [--array-key id] [--promptfoo] [--write]
set -eu

FEATURE=""
VENTURE=""
ARRAY_KEY=""
PROMPTFOO=0
WRITE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --feature)   FEATURE="${2:-}"; shift 2 ;;
    --venture)   VENTURE="${2:-}"; shift 2 ;;
    --array-key) ARRAY_KEY="${2:-}"; shift 2 ;;
    --promptfoo) PROMPTFOO=1; shift ;;
    --write)     WRITE=1; shift ;;
    -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$FEATURE" ]; then
  echo "ERROR: --feature is required (e.g. --feature form-field-extraction)" >&2
  exit 2
fi

ASSETS="$(cd "$(dirname "$0")/../assets" && pwd)"
DEST="evals/${FEATURE}"

echo "== prompt-eval-harness scaffold =="
echo "feature:   ${FEATURE}"
echo "venture:   ${VENTURE:-<unset>}"
echo "array-key: ${ARRAY_KEY:-<none> (object scoring)}"
echo "dest:      ${DEST}/"
echo "promptfoo: $([ "$PROMPTFOO" -eq 1 ] && echo yes || echo no)"
echo "mode:      $([ "$WRITE" -eq 1 ] && echo WRITE || echo DRY-RUN)"
echo "----------------------------------------"
echo "Would create:"
echo "  ${DEST}/cases/001-example.input.json"
echo "  ${DEST}/cases/001-example.expected.json"
echo "  ${DEST}/run-eval.mjs        (copied from skill assets)"
echo "  ${DEST}/score.mjs           (copied from skill assets)"
echo "  ${DEST}/CASES.md            (how to author cases)"
[ "$PROMPTFOO" -eq 1 ] && echo "  ${DEST}/promptfoo.config.yaml   (OPTIONAL — promptfoo not required to run)"
RUN_HINT="node run-eval.mjs"
[ -n "$ARRAY_KEY" ] && RUN_HINT="node run-eval.mjs --array-key ${ARRAY_KEY}"
echo "----------------------------------------"
echo "Then: cd ${DEST} && ${RUN_HINT}"

if [ "$WRITE" -ne 1 ]; then
  echo "(dry-run) re-run with --write to create the suite."
  exit 0
fi

mkdir -p "${DEST}/cases"

# Copy the runner + scorer from the skill's assets (kept as the single source).
cp "${ASSETS}/run-eval.mjs" "${DEST}/run-eval.mjs"
cp "${ASSETS}/score.mjs"    "${DEST}/score.mjs"
cp "${ASSETS}/case.example.md" "${DEST}/CASES.md"

# Seed one placeholder case if none exists.
if [ ! -e "${DEST}/cases/001-example.input.json" ]; then
  printf '%s\n' '{ "TODO": "replace with a real feature input" }' > "${DEST}/cases/001-example.input.json"
  printf '%s\n' '{ "TODO": "replace with the minimal expected output" }' > "${DEST}/cases/001-example.expected.json"
fi

if [ "$PROMPTFOO" -eq 1 ] && [ ! -e "${DEST}/promptfoo.config.yaml" ]; then
  cat > "${DEST}/promptfoo.config.yaml" <<'YAML'
# OPTIONAL — only used if you have promptfoo installed (`npx promptfoo eval`).
# The zero-dep `node run-eval.mjs` path does NOT need this file.
prompts:
  - file://prompt.txt
providers:
  - id: google:gemini-2.5-flash
    config:
      temperature: 0            # deterministic scoring
# promptfoo reads GEMINI_API_KEY from the environment — never commit the key.
tests:
  - vars:
      input: file://cases/001-example.input.json
    assert:
      - type: is-json
      - type: javascript
        value: |
          // return true/false or a 0..1 score
          output && typeof output === 'object'
YAML
fi

echo "----------------------------------------"
echo "WROTE suite to ${DEST}/"
echo "Next: author real cases in ${DEST}/cases, wire callFeature() in run-eval.mjs, then run ${RUN_HINT}"
