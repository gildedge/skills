---
name: gemini-structured-output
description: Standardize the repeated Gemini structured-JSON plumbing across the Gilded Edge ventures — define a responseSchema, call Gemini through a key-safe SERVER proxy (never expose GEMINI_API_KEY in the client bundle), then validate/repair the returned JSON with Zod and retry on malformed output. Use whenever adding or fixing a Gemini call that must return JSON: field extraction (gilded-form-works), asset/fidelity analysis (edge-design-works), deal analysis (gilded-estate-works), Toutsweet, aria-agent, or lumier. Triggers on "structured output", "responseSchema", "responseMimeType application/json", "Gemini returns JSON", "parse the model output", "validate the AI response", "the model returned markdown/invalid JSON", "move the API key server-side", "gemini proxy", "@google/genai vs @google/generative-ai".
---

# Gemini Structured Output

One reusable pattern for the plumbing that is currently copy-pasted (and subtly different) in every venture that calls Gemini for JSON. It standardizes four things that keep going wrong:

1. **Key safety** — the API key must live ONLY on the server. edge-design-works went as far as removing `@google/genai` from the client bundle entirely (Sprint 4C). Never regress this.
2. **A declared `responseSchema`** so Gemini emits JSON, not prose.
3. **Zod validation** of the parsed result, because `responseMimeType: "application/json"` still returns malformed / markdown-fenced / truncated JSON often enough to break production.
4. **Retry + repair** on malformed output instead of throwing a stack trace at the user.

## When to use

- Adding a new Gemini call that returns JSON in any venture.
- Hardening an existing call that does `JSON.parse(response.text)` with no schema or validation (this is the current state in form-works and edge-design-works — see Gotchas).
- Someone reports "the model returned invalid JSON", a `SyntaxError: Unexpected token` in an analyze route, or a client bundle that leaks `GEMINI_API_KEY`.

Not for: prompt *quality* iteration (use `prompt-lab`), or regression suites over a whole AI feature (use `prompt-eval-harness`).

## The two SDKs (know which one you're in)

| SDK | Import | Type enum | Used by |
|---|---|---|---|
| **new** | `@google/genai` | `import { Type } from '@google/genai'` | gilded-form-works, edge-design-works (server) |
| **legacy** | `@google/generative-ai` | `SchemaType` | gilded-estate-works client fallback |

New SDK call shape (server side):
```ts
import { GoogleGenAI } from '@google/genai';
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
const response = await ai.models.generateContent({
  model: 'gemini-2.5-flash',
  contents: [{ role: 'user', parts: [{ text: prompt }] }],
  config: { responseMimeType: 'application/json', responseSchema },
});
const text = response.text; // property, NOT a function in @google/genai
```
Legacy SDK returns `response.text()` — a function. Mixing these up is the #1 cause of `text is not a function`.

## Workflow

1. **Locate the proxy.** Every venture already routes the key server-side one of three ways. Do NOT invent a fourth — reuse the venture's existing pattern:
   - **Next.js App Router** (form-works): a route handler `src/app/api/<x>/route.ts` reads `process.env.GOOGLE_GENERATIVE_AI_API_KEY` and calls the SDK server-side. Client does `fetch('/api/<x>')`.
   - **Vite + Vercel function** (edge-design-works): client → `services/proxyClient.ts` → `POST /api/gemini` (`api/gemini.ts`) → `server/geminiHandler.ts` holds the key. The client ships a hand-mirrored `SchemaType` const so the SDK never enters the bundle.
   - **Supabase Edge Function** (estate-works): client → `supabase.functions.invoke('gemini-proxy')` → Deno function reads `Deno.env.get('GEMINI_API_KEY')`.
2. **Define the `responseSchema`** next to the call. Mark every field the downstream code dereferences as `required`. See `assets/schema-template.ts`.
3. **Add a Zod schema** that mirrors it (`assets/zod-template.ts`). The responseSchema is a hint to the model; Zod is the actual contract your TS code trusts.
4. **Wrap the call** in the parse → validate → retry helper (`assets/structured-call.ts`). On a Zod failure or JSON parse failure, retry once with a repair instruction appended, then fall back to a safe default rather than throwing into the UI.
5. **Verify the key never reaches the client.** For Vite/bundled apps run the grep in Gotchas.

Scaffold a new call with the helper (dry-run prints to stdout; nothing is written unless you pass `--write`):
```bash
bash ~/.claude/skills/gemini-structured-output/scripts/scaffold-structured-call.sh \
  --name analyzeInvoice --venture gilded-form-works
```

## The key-safe server-proxy pattern (edge-design-works, verbatim shape)

Client never imports the SDK — it posts to the proxy and mirrors the enum locally:
```ts
// services/geminiService.ts (CLIENT) — no @google/genai import
const SchemaType = { OBJECT:'OBJECT', STRING:'STRING', INTEGER:'INTEGER', BOOLEAN:'BOOLEAN', ARRAY:'ARRAY' } as const;

const response = await proxyGenerateContent('gemini-2.5-flash',
  { parts: [part, { text: 'Analyze this asset...' }] },
  { responseMimeType: 'application/json',
    responseSchema: { type: SchemaType.OBJECT,
      properties: { name:{type:SchemaType.STRING}, price:{type:SchemaType.STRING} },
      required: ['name','price'] } });
```
```ts
// server/geminiHandler.ts (SERVER) — the ONLY place the key exists
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
const response = await ai.models.generateContent({ model, contents, config });
```

## Validate + repair (the part everyone skips)

```ts
import { z } from 'zod';

async function structured<T>(schema: z.ZodType<T>, call: (repair?: string) => Promise<string>, fallback: T): Promise<T> {
  for (let attempt = 0; attempt < 2; attempt++) {
    const raw = await call(attempt === 0 ? undefined
      : 'Your previous reply was not valid JSON matching the schema. Return ONLY the JSON object, no markdown fences.');
    const json = extractJson(raw);                 // strips ```json fences / grabs {...}
    const parsed = schema.safeParse(json);
    if (parsed.success) return parsed.data;
    console.warn('Gemini JSON validation failed', parsed.error?.issues ?? 'parse error');
  }
  return fallback;                                  // degrade gracefully, never 500 the user
}

function extractJson(text: string): unknown {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const body = fenced ? fenced[1] : (text.match(/[\{\[][\s\S]*[\}\]]/)?.[0] ?? text);
  try { return JSON.parse(body.trim()); } catch { return null; }
}
```

## Gotchas

- **`response.text` is a property in `@google/genai`, a method in `@google/generative-ai`.** Check the import before writing `.text` vs `.text()`.
- **`responseMimeType: 'application/json'` is not a guarantee.** form-works and edge-design-works both still hand-roll a `text.match(/\{[\s\S]*\}/)` fallback because Gemini wraps JSON in ```` ```json ```` fences or truncates at `maxOutputTokens`. Always keep the `extractJson` step even with a schema.
- **`maxOutputTokens` too low silently truncates JSON** → parse error mid-object. form-works sets `65536` for big PDFs. Size it to the largest expected payload.
- **Image models need `responseModalities`, not a JSON schema.** `geminiHandler.ts` injects `['IMAGE','TEXT']` when the model name includes `image`. Don't put `responseMimeType: application/json` on an image model.
- **Env var name differs per venture:** `GEMINI_API_KEY` (edge-design-works, estate-works) vs `GOOGLE_GENERATIVE_AI_API_KEY` (form-works). Match the venture's `.env.local`; don't rename.
- **Key-leak check for bundled (Vite) apps** — this must return nothing pointing at client code:
  ```bash
  grep -rn "GEMINI_API_KEY\|VITE_GEMINI\|new GoogleGenAI\|new GoogleGenerativeAI" src/ 2>/dev/null
  ```
  A hit under `src/` (client) means the key or SDK is in the browser bundle. It belongs under `server/`, `api/`, or `supabase/functions/`. estate-works allows exactly one exception: a `VITE_GEMINI_API_KEY` *development-only* fallback that logs a warning — never ship that path enabled in prod.
- **Retries cost tokens and latency.** Cap at one repair attempt (as above), then fall back. Don't loop.
- **Estate-works' proxy uses raw `fetch` to the REST endpoint**, not the SDK, and pins `MODEL` server-side. If you add a schema there, add it to the `generationConfig` in the Deno function, not the client.

## Files
- `assets/structured-call.ts` — drop-in `structured()` + `extractJson()` helper.
- `assets/schema-template.ts` — `responseSchema` starting points (both SDK enums).
- `assets/zod-template.ts` — matching Zod contract.
- `scripts/scaffold-structured-call.sh` — dry-run scaffolder for a new named call.
