#!/usr/bin/env python3
"""
test_hs_classifier.py — unit tests for the docs-api HS classifier.

Locks in the WCO Chapter-97/49/69/70/58 boundaries and the edge mediums that the
customs / commercial-invoice sheets depend on. Runs against the LIVE classifier.

    python3 scripts/test_hs_classifier.py       # standalone (stdlib unittest)
    pytest scripts/test_hs_classifier.py        # or under pytest / CI

Drop-in for the repo at tests/test_hs_classifier.py. Python 3 stdlib only.
"""
import os
import sys
import unittest

GILDED_ROOT = os.environ.get(
    "GILDED_ROOT", os.path.expanduser("~/GILDED-EDGE-ECOSYSTEM")
)
API_DIR = os.path.join(GILDED_ROOT, "ventures", "gilded-art-works-docs-api")
sys.path.insert(0, API_DIR)

from app.services.hs_classifier import classify_hs_code, get_all_codes  # noqa: E402


class TestChapter97Originals(unittest.TestCase):
    def test_hand_paintings_are_9701_10(self):
        for medium in ("oil", "oil on canvas", "acrylic", "watercolour",
                       "gouache", "tempera", "charcoal", "pastel", "ink on paper"):
            with self.subTest(medium=medium):
                r = classify_hs_code(medium)
                self.assertEqual(r["code"], "9701.10", medium)
                self.assertEqual(r["chapter"], "97")

    def test_mixed_media_is_9701_90(self):
        for medium in ("mixed media", "collage", "assemblage", "installation"):
            self.assertEqual(classify_hs_code(medium)["code"], "9701.90", medium)

    def test_prints_are_9702(self):
        for medium in ("lithograph", "etching", "screenprint", "serigraph",
                       "woodcut", "monotype", "engraving"):
            self.assertEqual(classify_hs_code(medium)["code"], "9702.00", medium)

    def test_sculptures_are_9703(self):
        for medium in ("sculpture", "bronze", "marble", "stone",
                       "wood carving", "cast resin", "kinetic sculpture"):
            self.assertEqual(classify_hs_code(medium)["code"], "9703.00", medium)


class TestReproductionsAndPhotos(unittest.TestCase):
    """The classic error: a print/photo is Chapter 49, NOT a 9701 painting."""

    def test_giclee_and_prints_are_4911(self):
        for medium in ("giclée", "giclee", "giclée print", "digital print",
                       "inkjet print", "archival print", "poster"):
            with self.subTest(medium=medium):
                r = classify_hs_code(medium)
                self.assertEqual(r["code"], "4911.91", medium)
                self.assertEqual(r["chapter"], "49")
                self.assertNotEqual(r["code"], "9701.10")

    def test_photographs_are_4911(self):
        for medium in ("photograph", "c-print", "gelatin silver print",
                       "cyanotype", "daguerreotype"):
            self.assertEqual(classify_hs_code(medium)["code"], "4911.91", medium)


class TestOtherChapters(unittest.TestCase):
    def test_porcelain_is_6913_10_others_90(self):
        self.assertEqual(classify_hs_code("porcelain")["code"], "6913.10")
        for medium in ("ceramic", "stoneware", "earthenware", "raku"):
            self.assertEqual(classify_hs_code(medium)["code"], "6913.90", medium)

    def test_glass_is_7013(self):
        for medium in ("glass", "blown glass", "stained glass", "glass sculpture"):
            self.assertEqual(classify_hs_code(medium)["code"], "7013.99", medium)

    def test_textiles_are_5805(self):
        for medium in ("tapestry", "fiber art", "weaving", "embroidery"):
            self.assertEqual(classify_hs_code(medium)["code"], "5805.00", medium)


class TestEdgeCases(unittest.TestCase):
    def test_empty_and_whitespace_default_low(self):
        for medium in ("", "   ", None):
            r = classify_hs_code(medium)
            self.assertEqual(r["code"], "9701.90")
            self.assertEqual(r["confidence"], "low")

    def test_unknown_medium_defaults_low(self):
        r = classify_hs_code("holographic plasma projection")
        self.assertEqual(r["code"], "9701.90")
        self.assertEqual(r["confidence"], "low")

    def test_exact_match_is_high_confidence(self):
        self.assertEqual(classify_hs_code("oil on canvas")["confidence"], "high")

    def test_case_and_whitespace_insensitive(self):
        self.assertEqual(classify_hs_code("  OIL ON CANVAS  ")["code"], "9701.10")

    def test_keyword_substring_is_medium_confidence(self):
        # "abstract oil on canvas" isn't an exact key -> substring tier
        r = classify_hs_code("large abstract oil on canvas, framed")
        self.assertEqual(r["code"], "9701.10")
        self.assertEqual(r["confidence"], "medium")


class TestCatalog(unittest.TestCase):
    def test_get_all_codes_deduped_and_sorted(self):
        codes = get_all_codes()
        raw = [c["code"] for c in codes]
        self.assertEqual(raw, sorted(raw), "codes not sorted")
        self.assertEqual(len(raw), len(set(raw)), "codes not deduped")
        self.assertIn("9701.10", raw)
        self.assertIn("4911.91", raw)


if __name__ == "__main__":
    unittest.main(verbosity=2)
