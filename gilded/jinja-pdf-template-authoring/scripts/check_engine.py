#!/usr/bin/env python3
"""
check_engine.py — report the docs-api PDF engine state.

Mirrors the import probe in app/services/pdf_renderer.py so you know, BEFORE
debugging a "blank PDF", whether WeasyPrint is actually available or the API is
silently on the HTML print-to-PDF fallback.

Read-only. No exotic deps. Uses only what the venture already installs.
    python3 check_engine.py
"""
import importlib
import os
import sys

GILDED_ROOT = os.environ.get(
    "GILDED_ROOT", os.path.expanduser("~/GILDED-EDGE-ECOSYSTEM")
)
API_DIR = os.path.join(GILDED_ROOT, "ventures", "gilded-art-works-docs-api")


def _probe(mod):
    try:
        importlib.import_module(mod)
        return True, ""
    except Exception as e:  # ImportError OR OSError (missing Pango/Cairo)
        return False, f"{type(e).__name__}: {e}"


def main():
    print(f"docs-api: {API_DIR}")
    print(f"  templates dir exists: {os.path.isdir(os.path.join(API_DIR, 'app', 'templates'))}")

    weasy_ok, weasy_err = _probe("weasyprint")
    pdfkit_ok, pdfkit_err = _probe("pdfkit")

    if weasy_ok:
        engine = "weasyprint"
    elif pdfkit_ok:
        engine = "pdfkit"
    else:
        engine = "html"

    print(f"\nEffective engine: {engine}")
    print(f"  weasyprint importable: {weasy_ok}" + (f"  ({weasy_err})" if not weasy_ok else ""))
    print(f"  pdfkit importable:     {pdfkit_ok}" + (f"  ({pdfkit_err})" if not pdfkit_ok else ""))

    if engine == "html":
        print(
            "\n=> API will write HTML only (no .pdf in the response).\n"
            "   This is the fallback, not a template bug. To get real PDFs:\n"
            "     macOS:  brew install pango\n"
            "     Debian: apt-get install libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf2.0-0\n"
            "   Otherwise open the generated .html and Cmd+P -> Save as PDF."
        )
    else:
        print(f"\n=> API will render real PDFs via {engine}.")


if __name__ == "__main__":
    sys.exit(main())
