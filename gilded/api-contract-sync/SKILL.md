---
name: api-contract-sync
description: Keep the Gilded Artworks Documents web client (gilded-art-works-docs-web, Next.js) in lockstep with the FastAPI/Pydantic contract of the docs API (gilded-art-works-docs-api) so the upload/generate payloads never drift from the server models. Use when adding or changing a Pydantic model or endpoint in docs-api, when building the brochure/customs/certificate/upload request bodies in generate/page.tsx, when the client sends a field the server ignores or the server requires a field the client omits, when you see runtime 422/500 "field required" errors, or when someone says "sync the API types", "regenerate the API types", "does the client match the API", "the payload is wrong", "openapi", "contract drift". Fetches /openapi.json, diffs it against the client's request shapes, and (optionally) generates TypeScript types via openapi-typescript or orval.
---

# API Contract Sync — docs-api ⇄ docs-web

Two repos, one contract:

- **Server** `~/GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works-docs-api/` — FastAPI + Pydantic. The source of truth. `app/main.py` defines the models (`ArtworkMetadata`, `GalleryProfile`, `ShipmentInfo`, `BrochureRequest`, `CustomsRequest`, `CertificateRequest`) and the endpoints under `/api/v1/*`. FastAPI auto-serves the contract at `GET /openapi.json`.
- **Client** `~/GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works-docs-web/` — Next.js. `src/app/generate/page.tsx` hand-builds the JSON payloads and POSTs them to `${NEXT_PUBLIC_API_URL}/api/v1/...`. Nothing forces those hand-built objects to match the Pydantic models.

The gap between "hand-built object" and "Pydantic model" is where this skill lives.

## When to use

- You changed a Pydantic model or added/renamed an endpoint in `docs-api` and need the client to follow.
- You're editing the payload builder in `generate/page.tsx` and want to confirm every field the server expects is present (and you're not sending fields it silently drops).
- CI or runtime shows a `422 Unprocessable Entity` ("field required") or a `500` from the generator because a field arrived as the wrong type / under the wrong name.
- You want generated `openapi.d.ts` types so the client stops using loosely-typed `Record<string, unknown>` bodies.

## Real drift this repo pair already has

These are live examples — verify them with the diff script, they are why this skill exists:

1. **Phantom endpoint.** `generate/page.tsx` posts to `/api/v1/generate-all` for the "all documents" case:
   ```ts
   if (docType === 'all') { endpoint = '/api/v1/generate-all'; ... }
   ```
   `app/main.py` defines **no** `generate-all` route (only `/api/v1/brochure`, `/api/v1/customs`, `/api/v1/certificate`, `/api/v1/upload`, `/api/v1/download/{filename}`, `/api/v1/hs-classify`, `/api/v1/hs-codes`). That call 404s.
2. **Download link is missing the required token.** The server's `GET /api/v1/download/{filename}` calls `_verify_download_token` and returns **403** if `?token=` is absent or invalid; the generator response includes the token as `document.download_token`. But `generate/page.tsx` builds the link as `href={\`${API_URL}/api/v1/download/${result.document.html_filename}\`}` — no `?token=` — and the client never reads `download_token` at all. Every "Open Document" link 403s. (Note: `document.html_filename` itself *is* valid — `pdf_renderer.py` sets both `filename` and `html_filename` — the bug is the absent token, not the key.)
3. **Client interface narrower than the model.** The client `Artwork` interface omits Pydantic optionals `hs_code`, `edition`, `certificate_number`, and `image_url`. Not fatal (they're `Optional`), but the UI can never populate them, and `hs_code` is silently auto-classified server-side in `_prepare_artwork`.

## Workflow

1. **Get the live contract.** Start the API (`cd docs-api && uvicorn app.main:app --port 8500`) or use a running instance, then:
   ```bash
   bash scripts/contract-diff.sh --api-url http://localhost:8500
   ```
   If the server isn't running, the script falls back to parsing `app/main.py` Pydantic classes directly (regex, best-effort) so you still get a report offline.
2. **Read the drift report.** It lists, per endpoint the client calls: does the route exist in the contract; which required fields the client omits; which client fields the contract doesn't declare; and response keys the client reads that aren't in the response schema.
3. **Fix the client**, not the contract (the Pydantic model is the source of truth). Edit `generate/page.tsx` payload builders / interfaces. Only change `docs-api` if the *product* requirement changed — then the client follows.
4. **Optionally generate types** so this can't silently regress:
   ```bash
   bash scripts/gen-types.sh --api-url http://localhost:8500 \
     --out ~/GILDED-EDGE-ECOSYSTEM/ventures/gilded-art-works-docs-web/src/lib/api-types.d.ts
   ```
   Uses `openapi-typescript` if installed; otherwise prints the exact `npx` command and an `orval` alternative. It never installs anything itself.
5. **Re-run the diff** until it reports no drift, then type the fetch bodies against the generated `paths['/api/v1/brochure']['post']['requestBody']` types.

## Generators (optional, checked before use)

- **openapi-typescript** — lightweight, types-only. `npx openapi-typescript http://localhost:8500/openapi.json -o src/lib/api-types.d.ts`. Best default here: no client runtime, just `.d.ts`.
- **orval** — heavier; generates typed fetch/react-query hooks from the same `/openapi.json`. Use if you want a generated client, not just types. Needs an `orval.config.ts`.

The skill treats these as opt-in. Neither is in `docs-web`'s `package.json` today, so `gen-types.sh` checks `command -v` / `npx --no-install` first and degrades to printing the command.

## Gotchas

- **`NEXT_PUBLIC_API_URL` differs by env.** Locally it's `http://localhost:8500` (per `.env.example`); in prod it's the deployed API. Diff against the *same* env's contract you'll ship against.
- **FastAPI `Form(...)` vs JSON body.** `/api/v1/hs-classify` and `/api/v1/upload` take `multipart/form-data` (`Form`/`File`), not JSON. The client must send `FormData`, not `JSON.stringify`. openapi-typescript models these as `requestBody.content['multipart/form-data']` — don't blindly wrap everything in JSON.
- **Optional vs required.** Pydantic `Optional[...] = None` fields are omit-safe; a bare `field: str` is required and a missing one is a 422. The diff script separates "required-missing" (hard error) from "optional-missing" (cosmetic).
- **`price` type.** Pydantic `price: Optional[float]`. The client parses `parseFloat(a.price)` and sends `null` when empty — correct. Sending `""` would 422. Keep the `? parseFloat : null` guard.
- **Response envelope.** Endpoints wrap results as `{ status, message, document: {...}, artworks_processed }`. Type the *whole* envelope, not just `document`, or you'll miss `download_token`.
- Regenerated `.d.ts` is a build artifact — commit it, but never hand-edit it; re-run the generator instead.
