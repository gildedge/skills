#!/usr/bin/env python3
"""
hs_check.py — classify one medium, or audit the whole DB for ordering hazards.

Imports the LIVE HS_CODE_DATABASE / classify_hs_code from the docs-api so it can
never drift from what the API actually returns.

    python3 hs_check.py "oil on canvas"     # classify + explain which tier fired
    python3 hs_check.py --audit             # flag substring-shadowing hazards
    GILDED_ROOT=/path python3 hs_check.py --audit

Read-only. Python 3 stdlib only.
"""
import os
import sys

GILDED_ROOT = os.environ.get(
    "GILDED_ROOT", os.path.expanduser("~/GILDED-EDGE-ECOSYSTEM")
)
API_DIR = os.path.join(GILDED_ROOT, "ventures", "gilded-art-works-docs-api")
sys.path.insert(0, API_DIR)


def _load():
    try:
        from app.services.hs_classifier import HS_CODE_DATABASE, classify_hs_code
        return HS_CODE_DATABASE, classify_hs_code
    except Exception as e:
        print(f"ERROR: could not import hs_classifier from {API_DIR}\n  {type(e).__name__}: {e}")
        sys.exit(2)


def explain(medium, DB, classify):
    ml = medium.lower().strip()
    result = classify(medium)
    if ml in DB:
        tier = "1 exact"
    else:
        tier = "3 default (no match)"
        for k in DB:
            if k in ml:
                tier = f"2 keyword-substring (matched '{k}')"
                break
    print(f"medium     : {medium!r}")
    print(f"code       : {result['code']}  (chapter {result['chapter']})")
    print(f"description: {result['description']}")
    print(f"confidence : {result['confidence']}")
    print(f"tier fired : {tier}")
    print(f"source     : {result['source']}")


def audit(DB, classify):
    """Flag keys whose substring-tier outcome would differ from their own code.

    For each key, simulate what a *fresh* medium equal to that key would resolve
    to via the substring tier ALONE (ignoring exact match), to expose shadowing
    by an earlier, shorter key.
    """
    keys = list(DB.keys())
    hazards = 0
    for key in keys:
        own = DB[key]["code"]
        # first inserted key that is a substring of `key`
        shadow = None
        for other in keys:
            if other != key and other in key:
                shadow = other
                break
        if shadow and DB[shadow]["code"] != own:
            hazards += 1
            print(f"HAZARD: '{key}' ({own}) is shadowed by earlier '{shadow}' "
                  f"({DB[shadow]['code']}) in the substring tier.")
            print(f"        -> ensure '{key}' stays an EXACT key (it is: "
                  f"{'yes' if key in DB else 'NO'}), so tier-1 protects it.")
    if hazards == 0:
        print(f"OK  no substring-shadowing hazards across {len(keys)} keys.")
    else:
        print(f"\n{hazards} hazard(s). These are safe ONLY because exact-match (tier 1) "
              "runs first — do not remove the exact keys or reorder blindly.")
    return hazards


def main():
    DB, classify = _load()
    if len(sys.argv) < 2:
        print("usage: hs_check.py \"<medium>\"   |   hs_check.py --audit")
        sys.exit(1)
    if sys.argv[1] == "--audit":
        sys.exit(1 if audit(DB, classify) else 0)
    explain(" ".join(sys.argv[1:]), DB, classify)


if __name__ == "__main__":
    main()
