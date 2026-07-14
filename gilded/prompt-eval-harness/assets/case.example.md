# Writing a good golden case

A case is two files sharing a base name in `cases/`:

- `NNN-slug.input.json` (or `.txt`, or a path to a `.pdf`) — what the feature receives.
- `NNN-slug.expected.json` — the *minimal* correct output you'd accept.

## Principles

1. **Partial expectations.** List only the fields that matter. The scorer checks
   the keys you provide and ignores the rest, so a harmless new field in the
   model output won't fail the case.
2. **Assert structure and required values, not prose.** Gemini's wording varies
   even at temperature 0. Assert enums, booleans, IDs, verdict tokens, and
   presence — not full sentences.
3. **Span the difficulty range.** Easy → typical → adversarial (empty, huge,
   malformed, tricky edge). Each production bug becomes a new case.
4. **Match arrays by a stable key.** For `fields[]`, key on `id`/`fieldLabel`,
   never array index.

## Example — form-works field extraction (array feature)

`001-simple-w2.input.json`
```json
{ "pdfPath": "./fixtures/simple-w2.pdf" }
```

`001-simple-w2.expected.json` (run the runner with `--array-key id`)
```json
{
  "fields": [
    { "id": "employee_name",  "type": "text",      "required": true },
    { "id": "ssn",            "type": "sensitive",  "required": true },
    { "id": "wages",          "type": "number",     "required": true }
  ]
}
```
This asserts: all three fields are extracted (completeness/recall), `ssn` is
classified `sensitive` not `text` (accuracy), and each is `required` — without
pinning the exact `question`/`helpText` wording.

## Example — estate-works deal analysis (prose feature)

`003-subto-thin-margin.expected.json`
```json
{ "verdict": "NO-GO", "hasSection_cashflow": true, "hasSection_risk": true }
```
Wire `callFeature` to post-process the prose into `{ verdict, hasSection_* }`
(regex the `## 🔥 Verdict` line and section headers) so scoring stays
deterministic. Keep any LLM-judge scoring behind a flag.
