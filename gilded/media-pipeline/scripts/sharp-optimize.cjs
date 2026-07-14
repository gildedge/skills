#!/usr/bin/env node
/* Resize one image to responsive WebP/AVIF variants with sharp (libvips).
   Invoked by media.sh from inside a venture that has `sharp` installed.
   Config comes via env so there is zero shell-quoting risk:
     SRC     absolute path to the source image
     OUTDIR  absolute output directory
     WIDTHS  comma list, e.g. "400,800,1200"
     FMTS    comma list of webp|avif|jpeg
     Q       base quality (avif uses Q-12) */
const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

const src = process.env.SRC;
const out = process.env.OUTDIR;
const widths = (process.env.WIDTHS || '400,800,1200').split(',').map((n) => parseInt(n, 10)).filter(Boolean);
const fmts = (process.env.FMTS || 'webp').split(',').map((s) => s.trim()).filter(Boolean);
const q = parseInt(process.env.Q || '82', 10);

if (!src || !out) { console.error('sharp-optimize: SRC and OUTDIR env required'); process.exit(1); }
const bn = path.basename(src).replace(/\.[^.]+$/, '');
fs.mkdirSync(out, { recursive: true });

(async () => {
  for (const w of widths) {
    for (const f of fmts) {
      const dest = path.join(out, `${bn}-${w}w.${f}`);
      let img = sharp(src).resize({ width: w, withoutEnlargement: true });
      if (f === 'webp') img = img.webp({ quality: q });
      else if (f === 'avif') img = img.avif({ quality: Math.max(1, q - 12) });
      else img = img.jpeg({ quality: q, mozjpeg: true });
      await img.toFile(dest);
      console.log('   +', path.basename(dest));
    }
  }
})().catch((e) => { console.error('sharp-optimize failed:', e.message); process.exit(1); });
