"""
Drop-in pytest smoke test for the docs-api template layer.

Place at ventures/gilded-art-works-docs-api/tests/test_render.py so it runs in
ci.yml. Verifies: every template renders, autoescape holds, and the page-count
signal is present. The WeasyPrint PDF assertion is skipped automatically when the
system Pango/Cairo libs are absent (CI without them still passes on the HTML path).

    pytest tests/test_render.py -q
"""
import os
import pytest

from app.services.pdf_renderer import PDFRenderer

SAMPLE_ARTWORK = {
    "title": "Study in Ochre & <Gold>", "artist": "A. Rivera", "year": "2025",
    "medium": "oil on canvas", "dimensions": "60 x 90 cm", "hs_code": "9701.10",
    "edition": "1/1", "certificate_number": "PRV-1", "image_data": None,
}
GALLERY = {"name": "Gilded Artworks", "year": "2026"}
SHIPMENT = {"destination_country": "FR", "carrier": "UPS", "purpose": "sale"}


@pytest.fixture(scope="module")
def renderer():
    return PDFRenderer()


def test_templates_discovered(renderer):
    assert renderer.available_templates, "no templates discovered"


@pytest.mark.parametrize("template", ["brochure.html", "customs.html", "certificate.html"])
def test_html_preview_renders(renderer, template):
    html = renderer.render_html_preview(
        template, artworks=[SAMPLE_ARTWORK], gallery=GALLERY,
        shipment=SHIPMENT, document_title="Test",
    )
    assert len(html) > 200
    assert 'class="page' in html                # page-count signal
    assert "<Gold>" not in html                 # autoescape held
    assert "&lt;Gold&gt;" in html


def test_weasyprint_pdf_when_available(renderer):
    try:
        import weasyprint
    except Exception:
        pytest.skip("WeasyPrint / system libs not available")
    html = renderer.render_html_preview(
        "certificate.html", artworks=[SAMPLE_ARTWORK], gallery=GALLERY,
        document_title="Test",
    )
    doc = weasyprint.HTML(string=html).render()
    assert len(doc.pages) >= 1
