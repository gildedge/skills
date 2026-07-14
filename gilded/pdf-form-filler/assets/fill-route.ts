import { NextRequest, NextResponse } from "next/server";
import { PDFDocument } from "pdf-lib";

// ═══════════════════════════════════════════════════════════════
// POST /api/fill — the missing output half of Gilded Forms.
// Body (multipart): pdf=<File>, interview=<JSON string {fields, answers}>
// Returns: application/pdf (the filled form)
//
// Mirrors scripts/fill-pdf-form.mjs. NEVER logs a sensitive value.
// ═══════════════════════════════════════════════════════════════

export const maxDuration = 60;

const SENSITIVE_RE =
  /ssn|social.?security|tax.?id|\bein\b|passport|driver.?licen|account.?(number|no)|routing|\bdob\b|date.?of.?birth|card.?number/i;

type Field = { id: string; fieldLabel?: string; type?: string; options?: string[] };
const norm = (s: string) => (s || "").toLowerCase().replace(/[^a-z0-9]+/g, "");
const isSensitive = (f?: Field) =>
  !!f && (f.type === "sensitive" || SENSITIVE_RE.test(f.id) || SENSITIVE_RE.test(f.fieldLabel || ""));

export async function POST(req: NextRequest) {
  try {
    const formData = await req.formData();
    const file = formData.get("pdf") as File | null;
    const interviewRaw = formData.get("interview");
    if (!file) return NextResponse.json({ error: "No PDF provided" }, { status: 400 });

    const interview = JSON.parse(String(interviewRaw ?? "{}"));
    const fields: Field[] = interview.fields || [];
    const answers: Record<string, string> = interview.answers || {};
    const byId = new Map(fields.map((f) => [f.id, f]));
    const flatten = formData.get("flatten") === "true";

    const doc = await PDFDocument.load(await file.arrayBuffer(), { updateMetadata: false });
    const form = doc.getForm();
    const pdfFields = form.getFields();
    if (pdfFields.length === 0) {
      return NextResponse.json(
        { error: "This PDF has no interactive AcroForm fields; it needs overlay placement, not field fill." },
        { status: 422 }
      );
    }

    const realByName = new Map(pdfFields.map((f) => [f.getName(), f]));
    const realByNorm = new Map(pdfFields.map((f) => [norm(f.getName()), f]));
    const unmatched: string[] = [];

    for (const [answerId, rawVal] of Object.entries(answers)) {
      if (rawVal == null || String(rawVal).trim() === "") continue;
      const meta = byId.get(answerId);
      const target =
        realByName.get(answerId) ||
        (meta && realByNorm.get(norm(meta.fieldLabel || ""))) ||
        realByNorm.get(norm(answerId));
      if (!target) {
        unmatched.push(answerId); // id only — never the value
        continue;
      }
      const kind = target.constructor.name;
      const v = String(rawVal);
      try {
        if (kind === "PDFTextField") (target as ReturnType<typeof form.getTextField>).setText(v);
        else if (kind === "PDFCheckBox") {
          const cb = form.getCheckBox(target.getName());
          /^(y|yes|true|1|on|checked|x)$/i.test(v.trim()) ? cb.check() : cb.uncheck();
        } else if (kind === "PDFRadioGroup") {
          const rg = form.getRadioGroup(target.getName());
          const hit = rg.getOptions().find((o) => norm(o) === norm(v));
          if (hit) rg.select(hit);
        } else if (kind === "PDFDropdown") {
          const dd = form.getDropdown(target.getName());
          const hit = dd.getOptions().find((o) => norm(o) === norm(v));
          hit ? dd.select(hit) : dd.select(v);
        } else if (kind === "PDFOptionList") {
          const ol = form.getOptionList(target.getName());
          const hit = ol.getOptions().find((o) => norm(o) === norm(v));
          if (hit) ol.select(hit);
        }
      } catch (e) {
        // Log the field NAME + widget kind only — never the value, could be sensitive.
        console.error(`fill: ${target.getName()} [${kind}] failed`, isSensitive(meta) ? "(sensitive)" : (e as Error).message);
      }
    }

    try { form.updateFieldAppearances(); } catch {}
    if (flatten) form.flatten();

    const bytes = await doc.save();
    return new NextResponse(Buffer.from(bytes), {
      headers: {
        "Content-Type": "application/pdf",
        "Content-Disposition": `attachment; filename="${file.name.replace(/\.pdf$/i, "")}.filled.pdf"`,
        "X-Unmatched-Fields": String(unmatched.length),
      },
    });
  } catch (error: unknown) {
    console.error("PDF fill error:", error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Fill failed" },
      { status: 500 }
    );
  }
}
