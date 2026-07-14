/**
 * Zod contract mirroring the responseSchema. This — not the responseSchema —
 * is what your TypeScript trusts. Keep the two in sync.
 *
 * Prefer `.catch()`/`.default()` on non-critical fields so a single missing
 * value doesn't discard an otherwise-usable payload.
 */
import { z } from 'zod';

export const AssetMetadataSchema = z.object({
  name: z.string().default('Unknown Item'),
  brand: z.string().default('Generic'),
  price: z.string().default('N/A'),
  description: z.string().default('No description available.'),
});
export type AssetMetadata = z.infer<typeof AssetMetadataSchema>;

/** A safe fallback to pass as `structured(..., fallback)`. */
export const ASSET_METADATA_FALLBACK: AssetMetadata = {
  name: 'Identified Asset',
  brand: 'Unknown',
  price: 'Unknown',
  description: 'Analysis unavailable.',
};

/** Example: an array-of-fields extraction (form-works shape). */
export const ExtractedFieldSchema = z.object({
  id: z.string(),
  question: z.string(),
  type: z.enum(['text', 'date', 'number', 'select', 'email', 'phone', 'address', 'sensitive']),
  required: z.boolean().default(false),
  options: z.array(z.string()).optional(),
});
export const AnalyzeResultSchema = z.object({
  documentTitle: z.string().default('Untitled'),
  fields: z.array(ExtractedFieldSchema).default([]),
});
export type AnalyzeResult = z.infer<typeof AnalyzeResultSchema>;
