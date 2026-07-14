---
name: tier1-backfill
description: >-
  Brings an EXISTING Gilded Edge venture up to the Tier-1 conventions that
  create-venture.sh only bakes into brand-new repos. Adds .nvmrc + engines.node
  (20.9.0), pins exact Next 16.2.4 / React 19.2.4 (+ eslint-config-next), copies the
  canonical CI workflow, git hooks, and renovate.json from templates/, ensures
  CLAUDE.md/AGENTS.md + .env.example exist, wires lint-staged/prettier, then runs
  scripts/audit-ecosystem.sh and reports until green. Idempotent and safe to re-run.
  Use when the user says "bring <venture> up to standard/Tier-1", "make <repo> pass the
  audit", "backfill conventions", "gilded-estate-works is non-conforming", "fix audit
  failures", or "add CI/hooks/renovate/.nvmrc to <repo>."
---

# tier1-backfill

`create-venture.sh` gives NEW repos every convention as their starting state. But
actively-developed ventures that predate the standard (e.g. `gilded-estate-works`) land
non-conforming and fail `scripts/audit-ecosystem.sh`. This skill closes that gap for an
**existing** repo, idempotently, driving the audit to green.

It only ever copies canonical files from `~/GILDED-EDGE-ECOSYSTEM/templates/` and edits
the target repo. It does **not** touch other repos, secrets, or ecosystem-root scripts.

## What "Tier-1" means (the audit's checklist)

From `ECOSYSTEM_HEALTH.md` + `scripts/audit-ecosystem.sh`, a Node/Next repo must have:

| Concern | Standard |
|---|---|
| Node version | `.nvmrc` = `20.9.0` **and** `package.json` `engines.node` set |
| Next.js | exact `16.2.4` (also `eslint-config-next`) — Next repos only |
| React | exact `19.2.4` — Next repos only |
| CI | `.github/workflows/ci.yml` (from templates) |
| Renovate | `renovate.json` (from templates) |
| Hooks | `.githooks/pre-commit` + `pre-push`, `core.hooksPath=.githooks` |
| lint-staged | config block present in `package.json` |
| Agent rules | `CLAUDE.md` (→ `@AGENTS.md`) and `AGENTS.md` present |
| Env docs | `.env.example` checked in |
| Base files | `README.md`, `.gitignore`, `.gitattributes` (LFS globs) |

Python repos (`gilded-art-works-docs-api`) only need `.env.example` + CI. Static repos
(`lumier-*`, `photo-film-works`, `infrastructure/{skills,wiki,knowledge}`) need only the
base files — do **not** force Node conventions onto them.

## When to use / not use

Use to conform an existing repo, or to re-green the audit after drift. Do **not** use it
to scaffold a NEW venture (that's `create-venture.sh`) or to provision API keys (that's
`venture-provision`). Never bump a static/python repo to Node conventions.

## Safety

- **Idempotent.** Every step checks-then-acts; re-running changes nothing already correct.
  Version pins are rewritten to the exact target, never blindly appended.
- **Never auto-commit.** Leave changes staged for the user to review and commit. Show
  `git status`; the user decides. (Especially: never let a `.env.local` slip in — only
  `.env.example` is committable.)
- **`.env.example` carries names only, never real values.** The generator pulls variable
  names from source via `scripts/scan-env-vars.sh`; if a value ever appears, blank it.
- **package.json edits go through `node`/`jq`-style rewrites**, not blind sed, to avoid
  corrupting JSON. Back up to `package.json.bak` first.

## Workflow

### 0. Identify the repo and its kind

Confirm the target path and whether the audit treats it as `next`, `node`, `python`, or
`static` (see the `REPO_LIST` in `scripts/audit-ecosystem.sh`). The kind decides which
steps apply. `gilded-estate-works` is a **Vite + React** app graded as `node` (not
`next`) — so it needs Node conventions but is NOT held to the exact Next/React pins.

### 1. Baseline the current state

```bash
cd ~/GILDED-EDGE-ECOSYSTEM
bash scripts/audit-ecosystem.sh 2>&1 | sed -n '/== <repo> /,/^$/p'
```

Note every ✗ for the target repo — that's your worklist.

### 2. Run the backfill helper (idempotent)

```bash
bash ~/.claude/skills/tier1-backfill/scripts/backfill.sh <repo-path> [--kind next|node|python|static]
```

If `--kind` is omitted it is inferred from the audit's repo list, else from files
present (a `next` dependency ⇒ next; a `requirements.txt`/`pyproject.toml` ⇒ python; a
`package.json` ⇒ node; otherwise static). The helper, per applicable kind:

1. Copies `templates/configs/nvmrc` → `.nvmrc` (pins `20.9.0`).
2. Copies `templates/configs/gitattributes` → `.gitattributes` (LFS globs) if missing.
3. Copies `templates/configs/gitignore.nextjs` → `.gitignore` only if none exists
   (won't clobber a repo's existing ignore rules).
4. Copies `templates/ci/nextjs-ci.yml` → `.github/workflows/ci.yml`.
5. Copies `templates/configs/renovate.json` → `renovate.json`.
6. Ensures `CLAUDE.md` (`@AGENTS.md` indirection) and `AGENTS.md` exist (from the
   `venture-nextjs` template) — never overwrites an existing customized one.
7. `package.json`: sets `engines.node` to `>=20.9.0`, injects the `lint-staged` block,
   and — **for `next` repos only** — pins `next`/`eslint-config-next` to `16.2.4` and
   `react`/`react-dom` to `19.2.4`. Backs up to `package.json.bak`.
8. Generates `.env.example` from `scripts/scan-env-vars.sh` output if absent (names
   only; every value blank).

It prints each action as `+ added` / `= already ok` so you can see idempotency.

### 3. Wire the hooks

The canonical installer copies hooks, sets `core.hooksPath`, and injects lint-staged
across all Node repos (idempotent). Prefer it over hand-copying:

```bash
cd ~/GILDED-EDGE-ECOSYSTEM && bash scripts/install-hooks.sh
```

If the target repo isn't yet in that script's `NODE_REPOS` list, `backfill.sh` already
copied the hook files and set `core.hooksPath` for you as a fallback.

### 4. Install the dev tooling that makes hooks/CI real

Hooks are no-ops until the tools exist. In the repo:

```bash
cd <repo-path> && npm install -D lint-staged prettier
```

(For a `next` repo, `npm install` after the pin changes so the lockfile matches.)

### 5. Re-audit until green

```bash
cd ~/GILDED-EDGE-ECOSYSTEM && bash scripts/audit-ecosystem.sh
```

Repeat 2–4 for any remaining ✗. Report the before/after pass count for the repo and the
list of files added/changed. Leave everything **staged, not committed** — show
`git -C <repo> status` and let the user commit (`feat:`/`chore:` conventional message).

## Ecosystem gotchas

- **Vite ventures graded `node`, not `next`.** `edge-design-works`, `gilded-travel-works`,
  and `gilded-estate-works` must NOT be pinned to Next 16.2.4 / React 19.2.4 — the audit
  only enforces those for `next` repos. Forcing the Next pin breaks their Vite build.
  Let the helper's kind detection decide; when unsure, check the audit's `REPO_LIST`.
- **CI template is named `nextjs-ci.yml` but is the canonical CI for all Node repos.**
  For a Vite/`node` repo it still works (lint + typecheck + build via npm scripts); adapt
  build steps only if the repo lacks a `build` script.
- **Don't overwrite a customized `CLAUDE.md`/`AGENTS.md`.** The template `CLAUDE.md` is
  just `@AGENTS.md`; if the repo already has real agent rules, keep them.
- **`.env.example` must stay values-free.** The audit checks presence; the ecosystem
  policy forbids real values in-repo. Names only.
- **Static and Markdown-only repos** (`lumier-*`, `photo-film-works`,
  `infrastructure/{skills,wiki,knowledge}`) only need README/CLAUDE/AGENTS/.gitignore —
  never add Node tooling to them.
- **Leave it staged, never committed**, and never let real secrets or a `.env.local`
  enter the working tree — the ecosystem has had a leaked-secret incident before.

## Files

- `scripts/backfill.sh` — idempotent conventions backfill for one repo (steps 2 above).
