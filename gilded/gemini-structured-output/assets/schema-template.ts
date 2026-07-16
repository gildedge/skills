/**
 * responseSchema starting points. Pick the block matching the venture's SDK.
 * Mark EVERY field the downstream code dereferences as `required`.
 */

/* ── NEW SDK: @google/genai (form-works, edge-design-works server) ── */
import { Type } from '@google/genai';

export const responseSchemaGenai = {
  type: Type.OBJECT,
  properties: {
    name: { type: Type.STRING },
    price: { type: Type.STRING },
    score: { type: Type.INTEGER, description: 'Confidence 0-100' },
    pass: { type: Type.BOOLEAN },
    tags: { type: Type.ARRAY, items: { type: Type.STRING } },
  },
  required: ['name', 'price', 'score', 'pass'],
};

/* ── CLIENT-SAFE mirror (edge-design-works): keeps the SDK OUT of the bundle ──
 * Ship this const on the client instead of importing `Type` from @google/genai. */
export const SchemaType = {
  OBJECT: 'OBJECT',
  STRING: 'STRING',
  INTEGER: 'INTEGER',
  BOOLEAN: 'BOOLEAN',
  ARRAY: 'ARRAY',
} as const;

export const responseSchemaClientSafe = {
  type: SchemaType.OBJECT,
  properties: {
    name: { type: SchemaType.STRING },
    price: { type: SchemaType.STRING },
  },
  required: ['name', 'price'],
};

/* ── LEGACY SDK: @google/generative-ai (estate-works client fallback) ──
 * import { SchemaType } from '@google/generative-ai';
 * Same shape; note response.text() is a METHOD, not a property. */
