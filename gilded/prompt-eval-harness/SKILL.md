---
name: prompt-eval-harness
description: Scaffold a golden-case regression/eval suite for an AI feature in the Gilded Edge ecosystem — fixtures in, expected out, deterministic scoring of completeness + accuracy, and a CI-style pass/fail gate that catches prompt regressions before they ship. Complements prompt-lab (which OPTIMIZES prompts by exploration); this skill LOCKS IN quality with a repeatable suite you re-run after any prompt or model change. Use when someone says "eval harness", "golden cases", "test the AI feature", "did my prompt change break anything", "regression test the extraction", "score the model output", "catch prompt regressions", "measure field-extraction accuracy", or "set up promptfoo". Example targets: gilded-form-works field extraction, gilded-estate-works deal analysis, lumier prompt modules. Can optionally emit a promptfoo config (promptfoo is OPTIONAL — not required to run).
---

# Prompt Eval Harness

A golden-case regression suite for an AI feature: a folder of input fixtures, their expected outputs, a deterministic scorer, and a pass/fail gate. Re-run it after every prompt edit, model bump, or SDK upgrade to prove you didn't regress.

## How this differs from prompt-lab

They are two halves of the same discipline — keep both.

| | `prompt-lab` | `prompt-eval-harness` (this) |
|---|---|---|
| Goal | **Optimize** — push scores higher | **Protect** — prove scores didn't drop |
| Loop | hypothesize → modify → generate → score → keep/discard | fixtures → run → score → gate (pass/fail) |
| Cadence | exploratory sessions | every change / CI |
| Output | winning prompt diffs for review | a red/green regression verdict |
| Cases | 3 rotating test premises | a fixed, growing golden set (add every bug as a case) |

Use prompt-lab to *find* a better prompt; use this to *guard* it forever after. When prompt-lab lands a winner, add a golden case here so it can never silently regress.

## When to use

- Standing up quality gates for a Gemini feature that returns structured data (field extraction, deal analysis, asset metadata).
- Before/after a prompt change, model swap (`gemini-2.5-flash` → next), `maxOutputTokens` change, or `@google/genai` upgrade.
- After a production incident: capture the bad input as a new fixture so the class of bug is regression-tested going forward.

## Suite layout

The scaffolder creates this under the venture (or `evals/<feature>/` if you keep them central):

```
evals/<feature>/
├── cases/
│   ├── 001-simple-w2.input.json        # or .txt / .pdf path
│   ├── 001-simple-w2.expected.json     # golden expected output
│   ├── 002-multipage-lease.input.json
│   └── 002-multipage-lease.expected.json
├── run-eval.mjs                        # runner: feeds inputs, scores vs expected
├── score.mjs                           # completeness + accuracy scoring
└── promptfoo.config.yaml               # OPTIONAL — only if promptfoo is installed
```

## Workflow

1. **Pick the target feature** and its call site. Examples in this ecosystem:
   - `gilded-form-works/src/app/api/analyze/route.ts` → field extraction (`fields[]` array). Score = did we extract every expected field, with the right `type`/`required`?
   - `gilded-estate-works/src/services/aiService.ts` → `analyzeDeal` (prose + a GO/NO-GO verdict). Score = verdict match + presence of required sections.
   - lumier prompt modules (`geminiService.ts` scorers) → structural completeness of generated scripts.
2. **Scaffold the suite** (dry-run by default; nothing written unless `--write`):
   ```bash
   bash ~/.claude/skills/prompt-eval-harness/scripts/scaffold-eval.sh \
     --feature form-field-extraction --venture gilded-form-works
   ```
3. **Author golden cases.** Start with 3–5 hand-verified real inputs spanning easy → adversarial. For each, write the `.expected.json` you would accept as correct. Keep expected outputs minimal — assert the fields that matter, not the whole payload (see "partial expectations" in the scorer).
4. **Wire the runner to the real call.** `run-eval.mjs` ships with a `callFeature()` stub — point it at the venture's proxy/route so it exercises the same path production does. Never put an API key in the eval; call the server proxy like the app does.
5. **Define the gate.** Set thresholds in `score.mjs` (defaults: completeness ≥ 0.9, accuracy ≥ 0.85, zero hard-required-field misses). The runner exits non-zero when any case fails the gate — usable directly in CI.
6. **Grow the set.** Every production miss becomes case N+1. The suite's value is cumulative.

## Scoring model (deterministic, no LLM judge required)

Two orthogonal scores per case, so a regression tells you *which* way it broke:

- **Completeness** = expected keys/fields that are present in the actual output ÷ total expected. Catches truncation, dropped array items, `maxOutputTokens` regressions.
- **Accuracy** = of the present fields, how many match the expected value (exact for enums/booleans/IDs, normalized-string for text, tolerance for numbers). Catches wrong `type` classification, flipped `required`, wrong verdict.

For array features (field extraction), match items by a stable key (`id`/`fieldLabel`) and report per-item precision/recall, plus a hard check that every `required: true` expected field is present. See `assets/score.mjs`.

> LLM-as-judge is deliberately optional. Deterministic scoring is reproducible and free — reach for a judge only for free-form prose (e.g. estate-works deal narrative) and keep it behind a flag so the core gate stays deterministic.

## Optional: promptfoo

If (and only if) the user has promptfoo, the scaffolder can emit `promptfoo.config.yaml` mapping the same `cases/` to promptfoo tests with `assert` blocks. It is never required — the plain `node run-eval.mjs` path has zero dependencies beyond Node. Do not `npm install` promptfoo unless asked.

```yaml
# promptfoo.config.yaml (emitted only with --promptfoo)
prompts: [file://prompt.txt]
providers: ['google:gemini-2.5-flash']   # promptfoo reads GEMINI_API_KEY from env
tests:
  - vars: { input: file://cases/001-simple-w2.input.json }
    assert:
      - type: is-json
      - type: javascript
        value: file://assert-completeness.js
```

## Gotchas

- **Gemini is non-deterministic even at low temp.** Set `temperature: 0` in the eval call and score on *structure and required values*, not exact prose. Don't assert on wording that legitimately varies.
- **Score structure, not phrasing.** For prose features (estate-works), assert the verdict token (`GO`/`NO-GO`/`NEGOTIATE`) and required section headers exist — not the full text.
- **Match array items by a stable key.** form-works `fields[]` order is not guaranteed; matching by array index produces false regressions. Match by `id`/`fieldLabel`.
- **Keep expectations partial.** Assert only fields that matter; a full-payload diff turns every harmless addition into a failure and rots the suite.
- **Real PDFs/inputs can be large or sensitive.** Store fixtures as small redacted samples; reference big/binary inputs by path and keep them out of git if they contain PII.
- **Don't duplicate prompt-lab.** This suite doesn't propose prompt changes — it fails the build when quality drops. If you find yourself iterating on the prompt, switch to prompt-lab, then bring the winner back as a new golden case.
- **CI cost.** Each case is a live API call. Keep the golden set tight (10–20 high-signal cases), and gate the suite on the AI-touching paths only, not every commit, if quota is a concern.
- **The gate must exit non-zero on failure** or CI won't catch anything — `run-eval.mjs` already does; keep it.

## Files
- `scripts/scaffold-eval.sh` — dry-run scaffolder for a new eval suite.
- `assets/run-eval.mjs` — zero-dep Node runner + gate (exits non-zero on failure).
- `assets/score.mjs` — completeness/accuracy scoring incl. array precision/recall.
- `assets/case.example.md` — how to write a good golden case.
