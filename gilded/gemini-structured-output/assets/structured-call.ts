/**
 * gemini-structured-output — reusable validate + repair helper.
 *
 * Copy into the venture (adjust the import path for its proxy client).
 * Works with either SDK: you pass in a `call` closure that already knows
 * how to hit this venture's server proxy and returns the raw model text.
 *
 * Contract:
 *   - `schema` is the Zod contract your TS code actually trusts.
 *   - `call(repairHint?)` performs ONE proxy round-trip and returns raw text.
 *   - `fallback` is returned (never thrown) if both attempts fail, so the
 *     UI degrades gracefully instead of surfacing a 500 / SyntaxError.
 */
import { z } from 'zod';

export async function structured<T>(
  schema: z.ZodType<T>,
  call: (repairHint?: string) => Promise<string>,
  fallback: T,
): Promise<T> {
  let lastIssues: unknown = 'no attempt';
  for (let attempt = 0; attempt < 2; attempt++) {
    const raw = await call(
      attempt === 0
        ? undefined
        : 'Your previous reply was not valid JSON matching the required schema. ' +
            'Return ONLY the JSON object — no markdown fences, no commentary.',
    );
    const json = extractJson(raw);
    const parsed = schema.safeParse(json);
    if (parsed.success) return parsed.data;
    lastIssues = parsed.error?.issues ?? 'JSON.parse failed';
    console.warn(`[gemini] structured attempt ${attempt + 1} failed`, lastIssues);
  }
  console.warn('[gemini] falling back to safe default after repair attempt', lastIssues);
  return fallback;
}

/**
 * Pull a JSON value out of a model reply that may be fenced, prefixed with
 * prose, or truncated. Returns null on total failure (caught by safeParse).
 */
export function extractJson(text: string): unknown {
  if (!text) return null;
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const body = fenced
    ? fenced[1]
    : text.match(/[\{\[][\s\S]*[\}\]]/)?.[0] ?? text;
  try {
    return JSON.parse(body.trim());
  } catch {
    return null;
  }
}
