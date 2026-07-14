---
name: pdf-form-filler
description: Write completed Gilded Forms interview answers BACK into a PDF's AcroForm fields with pdf-lib — the missing output half of gilded-form-works (whose /api/analyze only EXTRACTS fields). Use whenever someone says "fill the PDF", "write answers into the form", "flatten the form", "generate the filled PDF", "export the completed form", "the AcroForm fields", "map interview answers to the PDF", or needs the download step after the guided interview. Handles text / checkbox / radio / dropdown (option-list) field types, maps AI-generated snake_case field ids to real AcroForm field names by label, reports unmatched fields, and NEVER logs the value of any field flagged sensitive (SSN, tax-ID, DOB, account numbers). Dry-runs by default.
---

# PDF Form Filler

`gilded-form-works` has two halves. The first ships: `src/app/api/analyze/route.ts` sends a PDF to Gemini (`@google/genai`, `gemini-2.5-flash`) and gets back an `AnalysisData` object — a list of `fields`, each with an `id`, `fieldLabel`, `type`, `pageNumber`, `options`, etc. The interview UI (`src/app/interview/page.tsx`) collects `answers: Record<fieldId, string>`.

The **second half is missing**: nothing writes those answers back into the PDF's interactive AcroForm fields. That is what this skill does, using `pdf-lib` (already a dependency: `pdf-lib ^1.17.1`, alongside `pdf-parse`).

## When to use

- Building the "Generate PDF" / "Download completed form" button behind `#generate-pdf-btn`.
- Wiring a new `src/app/api/fill/route.ts` that takes the original PDF + answers and returns a filled PDF.
- Any request to fill, flatten, or export a PDF form from collected answers.

Not for: extracting fields (that is `/api/analyze`, already built), or rendering a brand-new PDF from scratch (use the `pdf` or `crm-document-generator` skills).

## The core problem: id ≠ AcroForm field name

The extractor invents an `id` (snake_case, e.g. `applicant_full_name`) and captures the human `fieldLabel` (e.g. "Applicant Full Name"). **Neither is guaranteed to equal the actual AcroForm field name** inside the PDF (which might be `topmostSubform[0].Page1[0].f1_01[0]`). So filling is a *mapping* problem, not a lookup. The helper script resolves it in this priority order, then reports anything it could not place:

1. exact answer-key `id` === AcroForm field name
2. normalized `fieldLabel` === normalized field name / field's partial name
3. a user-supplied `--map` override file (`{ "answer_id": "ActualPdfFieldName" }`)
4. unmatched → listed in the report, never silently dropped

Always run `inspect` first to see the real field names, then fill.

## Workflow

1. **Inspect** the blank PDF to list real AcroForm fields, their types, and (for radio/dropdown) their allowed export values. Never prints any values — a blank form has none anyway, but this stays value-free by design.
   ```bash
   node ~/.claude/skills/pdf-form-filler/scripts/fill-pdf-form.mjs inspect \
     --pdf ./original.pdf
   ```
2. **Plan** the mapping (dry-run, default). Feeds the interview export (`{ fields, answers }`) and prints, per field: answer-id → resolved AcroForm name → type → MATCHED/UNMATCHED. Sensitive fields show `[sensitive: value hidden]` instead of the value.
   ```bash
   node ~/.claude/skills/pdf-form-filler/scripts/fill-pdf-form.mjs fill \
     --pdf ./original.pdf --interview ./interview.json
   ```
3. **Write** only after the plan looks right — add `--write --out ./filled.pdf`. Add `--flatten` to bake values in (removes interactivity so they can't be edited).
   ```bash
   node ~/.claude/skills/pdf-form-filler/scripts/fill-pdf-form.mjs fill \
     --pdf ./original.pdf --interview ./interview.json --write --out ./filled.pdf --flatten
   ```

`--interview` accepts either the combined shape `{ fields: [...], answers: {...} }` or you may pass `--analysis analysis.json --answers answers.json` separately. `GILDED_ROOT` overrides the ecosystem root used to resolve `pdf-lib` from `ventures/gilded-form-works/node_modules` (default `~/GILDED-EDGE-ECOSYSTEM`); `--venture <name>` picks a different venture's node_modules.

## Field-type handling (pdf-lib)

| Extractor `type` | AcroForm widget | pdf-lib call |
|---|---|---|
| `text`, `email`, `phone`, `address`, `number`, `date`, `sensitive` | text field | `form.getTextField(name).setText(value)` |
| `select` with 2 options that are yes/no-ish, or a lone checkbox | checkbox | `getCheckBox(name).check()/.uncheck()` |
| `select` (radio group) | radio group | `getRadioGroup(name).select(exportValue)` |
| `select` (combo/list) | dropdown / option list | `getDropdown(name).select(value)` or `getOptionList(name).select(value)` |

The script probes the **actual** widget type via pdf-lib's `field.constructor.name` (a `select` may be a radio group in one PDF and a dropdown in another) and dispatches on that, using the extractor `type` only as a fallback hint. For radio/dropdown it validates the answer against the field's real export/option values and reports a mismatch rather than throwing.

## Sensitive fields — never log values

A field is treated as sensitive if its extractor `type === "sensitive"` OR its `id`/`fieldLabel` matches `/ssn|social.?security|tax.?id|ein|passport|driver.?licen|account.?(number|no)|routing|dob|date.?of.?birth|card.?number/i`. For those:

- The value is still written into the PDF (that's the point).
- It is **never** printed to stdout, logs, or the mapping report — the report shows `[sensitive: value hidden]`.
- The script never writes an intermediate debug/temp file containing values.

Do not remove this masking to "make debugging easier". If you must debug a sensitive mapping, debug on a synthetic non-sensitive fixture.

## Gotchas

- **`response.text` is a property** in `@google/genai` (the SDK form-works uses), not a function — relevant if you touch the analyze side while here.
- **pdf-lib needs the field to exist as an AcroForm field.** Some "forms" are just flat images/print layouts with no interactive fields — `inspect` will return zero fields. Those cannot be filled by field name; they need overlay text placement (drawText at page coordinates) using the extractor's `pageNumber`. The script warns when it finds zero AcroForm fields.
- **Checkbox export value isn't always `Yes`.** The script reads the real on-state name from the widget's appearance dictionary before checking.
- **`updateFieldAppearances`** is called after filling so viewers that don't auto-regenerate appearances (some mobile PDF viewers) still show the values.
- **Flatten is one-way.** Keep the unflattened copy if the user might re-edit.
- The extractor sets `type: "sensitive"` for SSN/tax-IDs (see the analyze system prompt rule #4) — trust that signal first, then the regex as backstop.

## Wiring it into gilded-form-works

The download button (`#generate-pdf-btn`) should POST the original PDF (kept in state / re-uploaded) + `answers` to a new `src/app/api/fill/route.ts`. That route mirrors the script's logic server-side with pdf-lib and returns the bytes with `Content-Type: application/pdf`. The script is the reference implementation and the CLI for testing; `assets/fill-route.ts` in this skill is a paste-ready route handler in the venture's conventions.
