# Gilded Edge — Custom Slash-Commands

7 workflow recipes converted from the ventures' `.agents/workflows/*.md` into
Claude Code slash-commands. Symlinked into `~/.claude/commands/<name>.md` (source
of truth is here). Invoke with `/<name>` in any project.

| Command | What it does |
|---------|-------------|
| `/save-version` | Stage tracked files + Conventional Commit (branches off `main` first; no auto-push) |
| `/clean` | Kill zombie dev servers + clear Vite/Next cache |
| `/start-app` | Detect stack (Next/Vite/Express) → clean → launch dev server |
| `/lint-and-fix` | Lint + typecheck + safe auto-fix, house rules preserved |
| `/audit` | Runs `secret-hygiene-scan` + `route-hardening` + RLS audit; hands off to `security-engineer` |
| `/deploy` | Pre-deploy GO/NO-GO via the `vercel-deploy-check` skill |
| `/optimize-prompts` | `prompt-lab` optimization loop → WINNER diffs for review |

**Important:** unlike the source workflows — which hardcoded stale legacy paths
like `~/Documents/DM FILMWORKS/...` (violating the canonical-path rule) — these
are **generalized to the current working directory** and wired into the custom
skills/agents rather than ad-hoc greps.

**Skipped as redundant/niche:** `build`, `start-api` / `start-web` / `start-all` /
`start-server` (folded into `/start-app`), `check-links`, `audit-business-docs`,
standalone `lint` (folded into `/lint-and-fix`).
