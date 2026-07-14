---
name: jinja-pdf-template-authoring
description: Add or maintain a WeasyPrint document type in the Gilded Artworks Documents API (gilded-art-works-docs-api) — a Jinja2 template that extends base.html, matching CSS with the house brand tokens, the correct @page size (A5 by default), escaping-safe interpolation, a watermark/footer, plus a rendered-PDF smoke test. Use whenever someone says "add a new PDF/document type", "new brochure/customs/certificate-style template", "author a Jinja2 template for the docs API", "new WeasyPrint page", "invoice/label/packing-list/consignment PDF", "the template renders blank / fonts missing / page count wrong", or is wiring a new render_* method + endpoint in app/main.py + app/services/pdf_renderer.py. Grounded in the existing app/templates (base.html, brochure.html, customs.html, certificate.html). Knows WeasyPrint needs system Pango/Cairo and falls back to HTML print-to-PDF.
---

# Jinja PDF Template Authoring (Gilded Artworks Documents API)

Author a new print-ready document type in **`ventures/gilded-art-works-docs-api`**
(FastAPI + Jinja2 + WeasyPrint). Every template extends `base.html`, reuses the
brand design-system tokens, prints to **A5** through `@page`, and is verified by a
rendered smoke test before you wire the endpoint.

Path base (override with `GILDED_ROOT` if the ecosystem lives elsewhere):
`$GILDED_ROOT/ventures/gilded-art-works-docs-api` — default `~/GILDED-EDGE-ECOSYSTEM`.

## How the engine actually works (read before editing)

- `app/services/pdf_renderer.py` builds a Jinja2 `Environment` with
  **`autoescape=select_autoescape(["html","xml"])`** — interpolation is HTML-escaped
  for you. Do NOT add `| safe` to user data (title/artist/medium/etc.); that reopens
  template injection. The only pre-trusted value is `artwork.image_data` (a base64
  `data:` URI the API builds itself).
- Each `render_*` method loads a template, calls `template.render(**context)`, then
  `_generate_output(html, filename, doc_type)`.
- `_generate_output` **always writes an `.html`** file, and *additionally* writes a
  `.pdf` **only if WeasyPrint imported** (system Pango/Cairo present). With no
  WeasyPrint it silently falls back to HTML-only + a "print with Cmd+P" note — so a
  "successful" API response with no `pdf_path` usually means the libs are missing,
  not that your template is broken. `check_engine.py` tells you which case you're in.
- Page count is derived two ways: WeasyPrint reports `len(pdf_doc.pages)`; the HTML
  path *estimates* via `html.count('class="page')`. So **every printable page
  container must carry `class="page ..."`** or the count is wrong.

## The house design system (from base.html — reuse, don't reinvent)

Brand tokens live in `:root` in `base.html`; inherit them by `{% extends "base.html" %}`:

```
--ink #0d0d0d   --paper #faf8f5  --cream #f0ece4  --rule #d4c9b8
--gold #b8996a  --gold2 #8a6f40  --mid #7a756e    --light #c8c2b8
```

Fonts: `Cormorant Garamond` (serif display) + `Inter` (sans / labels), pulled from
Google Fonts in `base.html`. Page geometry: **A5 = 148mm × 210mm**, `@page { size:A5; margin:0 }`.
`base.html` already ships reusable `.page-header`, `.page-footer`, `.footer-brand`,
`.section-title`, `.spec-item/.spec-label/.spec-value` classes and print-color-fidelity
(`print-color-adjust:exact`). Prefer those over new CSS.

> Note: the ecosystem CLAUDE.md cites gold `#D4AF37`, but this API's templates use the
> muted archival gold `#b8996a`. **Match base.html** here (`--gold`), not the portal.

## Workflow — add a new document type

1. **Confirm the engine state**: `python3 scripts/check_engine.py`. If WeasyPrint is
   missing and you want real PDFs locally, install system libs (see Gotchas), else
   develop against the HTML output.
2. **Create `app/templates/<type>.html`** extending base. Copy the skeleton in
   `references/template_skeleton.html` (a watermark + footer + escaping-safe A5 page,
   already wired to the tokens). Keep every page wrapper as `class="page ..."`.
3. **Interpolate safely**: `{{ artwork.title }}` (auto-escaped). Use Jinja
   `| default(...)` for optional fields exactly like `certificate.html` does
   (`{{ artwork.edition | default('1/1 · Unique') }}`). Never `| safe` on user text.
4. **Add a `render_<type>` method** in `pdf_renderer.py` mirroring `render_certificate`
   (get_template → render → `_generate_output`). Give it a deterministic `filename`
   fallback with a timestamp.
5. **Add the Pydantic request model + endpoint** in `app/main.py` mirroring
   `/api/v1/certificate` (rate-limit check, `_prepare_artwork`, `_generate_download_token`,
   structured JSON, try/except → 500). Add the new template name to nothing else — it's
   auto-discovered by `available_templates`.
6. **Smoke-test the render** before shipping:
   `python3 scripts/render_smoke.py <type>` — renders your template with sample context,
   asserts non-empty output, checks the page-count signal, and (if WeasyPrint is present)
   asserts the PDF has ≥1 page. Writes to a temp dir; never touches the repo `output/`.
7. Drop `references/test_render.py` into the repo's test suite (pytest) if you want the
   smoke check to run in CI alongside `ci.yml`.

## Gotchas

- **Blank/È boxes in the PDF** = fonts didn't load. WeasyPrint fetches Google Fonts at
  render time; offline CI has no network. Either vendor the fonts locally and point
  `@font-face` at a file, or accept system-font fallback — don't chase it as a template
  bug.
- **WeasyPrint import fails with an OSError about `libgobject`/`pango`** — that's the
  missing-system-libs path, caught in `pdf_renderer.py`. macOS: `brew install pango`;
  Debian/CI: `apt-get install libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf2.0-0`.
  No brew? The HTML output path still works (Cmd+P → Save as PDF).
- **Page count is 0 or wrong** on the HTML path → a page container is missing
  `class="page"`. The literal substring `class="page` is what's counted.
- **Image too big / render slow** — images must be the base64 `image_data` produced by
  `image_processor.process_for_template`; don't inline raw multi-MB originals.
- **`@page` margin** must stay `0`; the page's own padding (see certificate `10mm 12mm`)
  provides the safe area, and the decorative gold border uses `position:absolute; inset:6mm`.
- WeasyPrint ignores most JS and some modern CSS (no flex-gap quirks, limited
  `object-fit`). The existing templates stay on simple fl/grid + absolute positioning —
  follow that, and preview the `.html` in a browser for parity.

## Files
- `scripts/check_engine.py` — reports whether WeasyPrint/pdfkit are importable and what
  the API will do (PDF vs HTML fallback). Read-only.
- `scripts/render_smoke.py` — renders one template with representative context and
  asserts it produced valid output; safe temp dir, dry by nature (no repo writes).
- `references/template_skeleton.html` — copy-me A5 template: extends base, watermark,
  footer, escaping-safe loop.
- `references/test_render.py` — pytest smoke test to add to the repo.
