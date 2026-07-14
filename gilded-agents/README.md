# Gilded Edge — Custom Subagents

15 venture role-agents converted from the ventures' `.agents/agents/*.md` into
Claude Code subagent format. Symlinked into `~/.claude/agents/<name>.md` (source
of truth is here). They coexist with the pre-existing `gsd-*` agents.

**Invoke** explicitly ("use the security-engineer agent on this route") or let
Claude auto-delegate based on each agent's `description`.

| Agent | Model | Scope |
|-------|-------|-------|
| `code-reviewer` | sonnet | Review across React/TS, FastAPI/Python, full-stack *(deduped from 3 ventures)* |
| `security-engineer` | opus | App-sec audits — secrets, injection, auth/RLS, PII *(deduped from 3)* |
| `frontend-architect` | sonnet | React/TS frontend architecture *(deduped from 2)* |
| `ui-design-director` | sonnet | Design systems, tokens, premium UI *(deduped from 2)* |
| `ai-architect` | opus | Genkit/Gemini AI systems — Taste Graph, bidding (travel) |
| `bidding-engine-engineer` | opus | 3-tier charter pricing engine (travel) |
| `content-curator` | sonnet | Luxury content data-quality + brand voice (travel) |
| `growth-strategist` | sonnet | Revenue/growth, membership tiers, ARR (travel) |
| `luxury-concierge` | sonnet | UHNWI booking-flow / trip-planning UX (travel) |
| `member-experience-designer` | sonnet | Member journey, AI concierge chat (travel) |
| `ai-services-engineer` | opus | Multi-AI orchestration for film pipeline (Lumier) |
| `backend-architect` | opus | Express/TS backend + media pipelines (Lumier) |
| `api-architect` | opus | FastAPI + WeasyPrint docs API (art) |
| `pdf-engineer` | sonnet | Jinja2/WeasyPrint museum-grade PDFs (art) |
| `agency-ops` | sonnet | Lumier Studios agency workspace |

**Conversion notes.** Kebab-case `name` matches filename; `description` rewritten
action-oriented for auto-delegation; review agents restricted to read-only tools;
builders inherit all tools; opus reserved for architecture/security depth. The
original `emoji`/`vibe` keys were dropped (persona folded into the body), and
stale stack refs were corrected (e.g. `pdfkit`/`wkhtmltopdf` → WeasyPrint).

Sources: `_legacy/lumier-pictures-v1-local`, `ventures/gilded-art-works-docs-api`,
`ventures/gilded-travel-works`, `ventures/lumier-studios` (`.agents/agents/`).
