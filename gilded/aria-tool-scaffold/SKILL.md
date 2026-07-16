---
name: aria-tool-scaffold
description: Generate a new aria-agent /api/* agent tool or workflow route in ARIA's exact house conventions — an { action } switch POST handler, a GET capabilities manifest, Gemini wiring (via the gemini-structured-output conventions), zod-validated input, and notifyARIA (Telegram) + Supabase logging. Use when someone says "add an ARIA tool", "new aria endpoint", "scaffold an agent workflow", "give ARIA a new capability/skill", "new /api route for aria-agent", "wire an ARIA automation", or is extending the agent's toolset. Matches the shape of the existing chat / waterfall / script / automations routes (Response.json, {action} dispatch, GEMINI_API_KEY, @/lib/notify, @/lib/supabase). Dry-runs by default; refuses to overwrite without --force.
---

# ARIA Tool Scaffold

Every ARIA capability is a Next.js App Router route under `aria-agent/src/app/api/<name>/route.ts` that follows one shape. This skill emits a new one in that exact shape instead of hand-copying `waterfall/route.ts` and editing it.

## The ARIA route contract (learned from the shipped routes)

- **POST dispatches on `action`** (or `workflow` for orchestrators): `const { action } = await req.json()` → `switch`, each case validates input, does its work, returns `Response.json(...)`. Unknown action → `{ error, available: [...] }` at 400. (See `waterfall`, `script`.)
- **GET returns a capabilities manifest** — engine name + available actions/params. The UI and other agents introspect this. (See `waterfall` GET, `script` GET.)
- **Responses use `Response.json(...)`** (Web API), not always `NextResponse` — both appear; the newer agent routes use `Response.json`.
- **Gemini**: server-side key only. Two shapes coexist — the `@google/genai` SDK (`chat/route.ts`: `new GoogleGenAI({apiKey}).models.generateContent`, `response.text` is a **property**) and raw REST to `generativelanguage.googleapis.com/.../gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}` (`waterfall`, `script`). Pick the SDK for new tools — it's cleaner and matches the `gemini-structured-output` skill. For JSON output set `responseMimeType: 'application/json'` and validate with zod.
- **Env**: `GEMINI_API_KEY` (note: `analyze` in form-works uses `GOOGLE_GENERATIVE_AI_API_KEY`; aria-agent standardizes on `GEMINI_API_KEY`).
- **Notify**: `import { notifyARIA } from '@/lib/notify'` → pushes a Markdown message to Daniel's Telegram. Use it for anything Daniel should know about (new lead, published content, errors worth a ping).
- **Supabase**: `import { supabase, supabaseService } from '@/lib/supabase'`. `supabase` = anon (RLS-respecting reads); `supabaseService` = service role for server-side writes (memory/log tables need it). Log agent actions to a table so ARIA has persistent memory.
- **Error handling**: wrap in try/catch, `console.error('[ARIA <Tool>] Error:', error)`, return `{ error: message }` at 500. The chat route additionally maps `CONSUMER_SUSPENDED` / `API_KEY_INVALID` to friendly messages — copy that if the tool calls Gemini.

## Workflow

1. Scaffold (dry-run prints the file; nothing is written):
   ```bash
   bash ~/.claude/skills/aria-tool-scaffold/scripts/scaffold-aria-tool.sh \
     --name deal-scanner --actions scan,summarize --gemini --log-table aria_tool_log
   ```
2. Review the printed route. Adjust actions/params to the real task.
3. Write it: add `--write` (refuses to clobber an existing route unless `--force`):
   ```bash
   bash ~/.claude/skills/aria-tool-scaffold/scripts/scaffold-aria-tool.sh \
     --name deal-scanner --actions scan,summarize --gemini --notify --log-table aria_tool_log --write
   ```

Flags: `--name` (kebab route name, required) · `--actions a,b,c` (default `run`) · `--gemini` (wire the `@google/genai` SDK call) · `--notify` (import + call `notifyARIA`) · `--log-table <t>` (log each run via `supabaseService`) · `--write` · `--force` · `GILDED_ROOT` env overrides the ecosystem root.

## zod input validation

The task calls for zod-validated input. **`zod` is NOT currently a dependency of aria-agent** — the scaffold emits the zod import and a `parse` guard, and prints a reminder to `npm i zod` in the venture. If you'd rather not add the dep, pass `--no-zod` to get an equivalent hand-rolled guard (`typeof` checks) instead. Either way, never trust `await req.json()` shape blindly — the shipped routes destructure without validating, which is a latent bug this scaffold fixes.

## Respect the existing facts

- Do **not** invent revenue numbers, mark features "live", or add ventures — that violates `aria-prompt.ts`'s hard rules. A tool that summarizes for Telegram must not fabricate metrics; pull them from Supabase.
- Reuse `@/lib/notify` and `@/lib/supabase` — do not create a second Telegram sender or a second Supabase client.
- If the tool returns JSON from Gemini, follow the `gemini-structured-output` skill (responseSchema + zod + retry), don't `JSON.parse` raw.
- An `aria-prompt-sync` idea exists for keeping the system prompt aligned; that's out of scope here — this skill scaffolds *tools*, not the prompt.

## Gotchas

- **`response.text` is a property** in `@google/genai`, a **function** in the legacy `@google/generative-ai`. aria-agent uses `@google/genai`. Mixing them up → `text is not a function`.
- **Service-role key is server-only** — `supabaseService` must never be imported into a client component. Route handlers are server-side, so it's fine here.
- **`notifyARIA` swallows errors** (`.catch(() => {})`) and no-ops if `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID` are unset — so a missing token won't crash the route, but also won't warn. Don't rely on it as your only success signal.
- **GET manifest must list the real actions** you implemented — other agents dispatch off it. Keep it in sync when you add a case.
- aria-agent's `AGENTS.md` warns Next.js APIs may differ from training data — check `node_modules/next/dist/docs/` if a Next API behaves unexpectedly.
