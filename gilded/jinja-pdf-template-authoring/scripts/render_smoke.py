#!/usr/bin/env python3
"""
render_smoke.py — rendered-PDF smoke test for a docs-api template.

Renders one template from app/templates with representative context and asserts
it produced valid output. If WeasyPrint is importable it renders a real PDF and
asserts >=1 page; otherwise it validates the HTML path (non-empty + page-count
signal present). Writes to a throwaway temp dir — never touches the repo output/.

    python3 render_smoke.py <template_name>      # e.g. certificate  or  invoice
    GILDED_ROOT=/path python3 render_smoke.py brochure

Exit 0 = pass, non-zero = fail (usable in CI).
"""
import os
import sys
import tempfile

GILDED_ROOT = os.environ.get(
    "GILDED_ROOT", os.path.expanduser("~/GILDED-EDGE-ECOSYSTEM")
)
API_DIR = os.path.join(GILDED_ROOT, "ventures", "gilded-art-works-docs-api")
TEMPLATE_DIR = os.path.join(API_DIR, "app", "templates")

# Representative context — matches what _prepare_artwork() produces at runtime.
SAMPLE_ARTWORK = {
    "title": "Study in Ochre & <Gold>",   # includes chars that MUST be escaped
    "artist": "A. Rivera",
    "year": "2025",
    "medium": "oil on canvas",
    "dimensions": "60 × 90 cm",
    "price": 12000.0,
    "hs_code": "9701.10",
    "origin_country": "US",
    "edition": "1/1 · Unique",
    "certificate_number": "PRV-STU-2025-1",
    "image_data": None,
}
SAMPLE_GALLERY = {
    "name": "Gilded Artworks", "year": "2026", "date": "2026-07-14",
    "address": "New York, NY", "contact_email": "docs@gilded.art",
}
SAMPLE_SHIPMENT = {  # only used by customs-style templates
    "destination_country": "FR", "carrier": "UPS",
    "declared_total": 12000.0, "purpose": "exhibition and sale",
    "date": "2026-07-14",
}


def fail(msg):
    print(f"FAIL: {msg}")
    sys.exit(1)


def main():
    if len(sys.argv) < 2:
        fail("usage: render_smoke.py <template_name>  (e.g. certificate)")
    name = sys.argv[1]
    if not name.endswith(".html"):
        name += ".html"
    path = os.path.join(TEMPLATE_DIR, name)
    if not os.path.isfile(path):
        fail(f"template not found: {path}")

    try:
        from jinja2 import Environment, FileSystemLoader, select_autoescape
    except ImportError:
        fail("jinja2 not importable — run inside the docs-api venv (pip install -r requirements.txt)")

    env = Environment(
        loader=FileSystemLoader(TEMPLATE_DIR),
        autoescape=select_autoescape(["html", "xml"]),  # same as pdf_renderer.py
    )
    tmpl = env.get_template(name)
    html = tmpl.render(
        artworks=[SAMPLE_ARTWORK, dict(SAMPLE_ARTWORK, title="Second Work")],
        gallery=SAMPLE_GALLERY,
        shipment=SAMPLE_SHIPMENT,
        document_title="Smoke Test Document",
    )

    # ── Assertions on the HTML ──────────────────────────────────
    if not html or len(html) < 200:
        fail("rendered HTML is empty/too short")
    if 'class="page' not in html:
        fail('no `class="page"` wrapper found — the HTML page-count estimate will be 0')
    # autoescape check: the raw '<Gold>' must NOT appear unescaped
    if "<Gold>" in html:
        fail("user text was NOT escaped — autoescape broken or `| safe` misused")
    if "&lt;Gold&gt;" not in html:
        print("WARN: escaped title marker not found (template may not render artwork.title)")
    page_signal = html.count('class="page')
    print(f"OK  html rendered: {len(html)} bytes, page-count signal = {page_signal}")

    # ── Real PDF path if WeasyPrint is present ──────────────────
    try:
        import weasyprint  # noqa
    except Exception as e:
        print(f"OK  (HTML-only) WeasyPrint not available ({type(e).__name__}); "
              "skipping PDF assertion. Open the HTML + Cmd+P for a real PDF.")
        print("PASS")
        return 0

    with tempfile.TemporaryDirectory() as tmp:
        pdf_path = os.path.join(tmp, "smoke.pdf")
        doc = weasyprint.HTML(string=html, base_url=TEMPLATE_DIR).render()
        doc.write_pdf(pdf_path)
        pages = len(doc.pages)
        size = os.path.getsize(pdf_path)
        if pages < 1:
            fail("WeasyPrint produced 0 pages")
        if size < 500:
            fail(f"PDF suspiciously small ({size} bytes)")
        print(f"OK  weasyprint PDF: {pages} page(s), {size} bytes")
    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
