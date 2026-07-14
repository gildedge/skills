# Gilded Estate Works — brand tokens

Use these when rendering a report to PDF/HTML (see `src/services/pdfExportService.ts`)
or when styling any derived artifact. Reports themselves are plain markdown, but the
gold/obsidian identity must carry through to any exported/branded surface.

| Token            | Value      | Use |
|------------------|------------|-----|
| Gold (primary)   | `#c9a84c`  | Headers, rule lines, "GO" verdict, score accents, key metrics |
| Obsidian (bg)    | `#0a0a0a`  | Page/background on dark exports |
| Ink              | `#111827`  | Body text on light exports |
| Muted            | `#9ca3af`  | Labels, uppercase eyebrows, table headers |
| Pass / GO        | `#059669`  | Passing metric, GO verdict |
| Warn / NEGOTIATE | `#D97706`  | Borderline metric, NEGOTIATE verdict |
| Fail / NO-GO     | `#ef4444`  | Failed gate, NO-GO verdict |

Font: **Inter**, system-ui fallback (matches the ecosystem design language).

Risk / verdict glyphs used consistently across the library:
- Risk: 🟢 low (1–3) · 🟡 moderate (4–6) · 🔴 high (7–10)
- Verdict: GO ✅ · NEGOTIATE 🔄 · NO-GO ❌
- Section emoji are load-bearing for the library's visual scan: 🎙️ 📋 📝 🏠 📊 🎯
