/* ═══════════════════════════════════════════════════════════
   Gilded Edge — Canonical PDF brand tokens
   Obsidian black + Gold (#D4AF37). Shared by every venture's
   invoice / contract / proposal / quote / COA documents.
   ═══════════════════════════════════════════════════════════ */

// Canonical ecosystem palette (Obsidian + Gold).
export const GILDED = {
  OBSIDIAN: '#0A0A0F', // page background
  SURFACE:  '#13131A', // cards / meta blocks
  ACCENT:   '#D4AF37', // gold — the ecosystem accent
  ACCENT_2: '#E6C766', // lighter gold for gradients / hovers
  TEXT:     '#E8E6E0', // warm off-white body text
  MUTED:    '#8A8578', // secondary text
  DIVIDER:  '#262019', // hairlines
  SUCCESS:  '#10B981',
  ERROR:    '#EF4444',
  INFO:     '#60A5FA',
};

// Per-venture accent overrides. Lumier Studios CRM historically ships an
// orange dark theme (#FF6B35); pass brand: 'lumier' to match existing output.
// Everything else defaults to the canonical gold.
export const BRANDS = {
  gilded: { ...GILDED },
  lumier: { ...GILDED, ACCENT: '#FF6B35', ACCENT_2: '#FF8A5B' },
  // Gilded Artworks leans warmer/antique gold on its HTML docs; approximate
  // it here so PDFs and web docs read as one family.
  artworks: { ...GILDED, ACCENT: '#B8996A', ACCENT_2: '#D4BC8A' },
};

export function resolveBrand(name) {
  return BRANDS[name] || BRANDS.gilded;
}

// Money + date helpers used across every template.
export function money(v, currency = 'USD') {
  const n = Number(v) || 0;
  return new Intl.NumberFormat('en-US', {
    style: 'currency', currency, minimumFractionDigits: 2, maximumFractionDigits: 2,
  }).format(n);
}

export function shortMoney(v, currency = 'USD') {
  const n = Number(v) || 0;
  return new Intl.NumberFormat('en-US', {
    style: 'currency', currency, minimumFractionDigits: 0, maximumFractionDigits: 0,
  }).format(n);
}

export function fmtDate(d) {
  if (!d) return '—';
  const dt = new Date(d);
  if (Number.isNaN(dt.getTime())) return String(d);
  return dt.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
}
