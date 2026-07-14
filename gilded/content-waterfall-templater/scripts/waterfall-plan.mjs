#!/usr/bin/env node
/*
 * waterfall-plan.mjs — deterministic mirror of aria-agent /api/waterfall "generate".
 * Expands one source into the 25 derivative pieces (26 incl. source), schedules
 * them 2/day over 14 days, and (optionally) prints the per-piece Gemini prompts.
 *
 * No API key, no network, no DB. Pure planning.
 *
 *   --title "..."            (required) source title
 *   --source-platform p      default youtube
 *   --tags a,b,c             extra tags
 *   --format markdown|json   default markdown  (or --json)
 *   --print-prompts          also emit the write_piece Gemini prompt per piece
 *   --source-script "..."    used only when --print-prompts (truncated to 5000)
 */

const argv = process.argv.slice(2);
const opt = {};
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (!a.startsWith('--')) continue;
  const key = a.slice(2);
  const next = argv[i + 1];
  if (next === undefined || next.startsWith('--')) opt[key] = true;
  else { opt[key] = next; i++; }
}

if (!opt.title) { console.error('ERROR: --title is required'); process.exit(1); }
const sourcePlatform = opt['source-platform'] || 'youtube';
const tags = opt.tags && opt.tags !== true ? String(opt.tags).split(',').map((s) => s.trim()).filter(Boolean) : [];
const format = opt.json ? 'json' : (opt.format || 'markdown');

// ── canonical template (verbatim from waterfall/route.ts) ────────────────────
const WATERFALL_TEMPLATE = [
  { platform: 'youtube', type: 'Long-form', suffix: 'Full Video' },
  { platform: 'youtube', type: 'Short', suffix: 'Hook Clip' },
  { platform: 'youtube', type: 'Short', suffix: 'Best Moment' },
  { platform: 'youtube', type: 'Short', suffix: 'Tutorial Extract' },
  { platform: 'instagram', type: 'Reel', suffix: 'Reel v1 (Hook)' },
  { platform: 'instagram', type: 'Reel', suffix: 'Reel v2 (Story)' },
  { platform: 'instagram', type: 'Carousel', suffix: 'Key Takeaways Carousel' },
  { platform: 'instagram', type: 'Story', suffix: 'Behind the Scenes Story' },
  { platform: 'instagram', type: 'Post', suffix: 'Quote Card' },
  { platform: 'instagram', type: 'Post', suffix: 'Insight Graphic' },
  { platform: 'x', type: 'Thread', suffix: 'Deep-Dive Thread' },
  { platform: 'x', type: 'Tweet', suffix: 'Hook Tweet' },
  { platform: 'x', type: 'Tweet', suffix: 'Contrarian Take' },
  { platform: 'x', type: 'Tweet', suffix: 'Data Point' },
  { platform: 'x', type: 'Tweet', suffix: 'Question Hook' },
  { platform: 'linkedin', type: 'Article', suffix: 'Authority Post' },
  { platform: 'linkedin', type: 'Post', suffix: 'Lesson Learned' },
  { platform: 'linkedin', type: 'Post', suffix: 'Behind the Build' },
  { platform: 'linkedin', type: 'Video', suffix: 'Native Video Clip' },
  { platform: 'tiktok', type: 'Short', suffix: 'Hook-First Edit' },
  { platform: 'tiktok', type: 'Short', suffix: 'POV Style' },
  { platform: 'tiktok', type: 'Short', suffix: 'Trend Remix' },
  { platform: 'tiktok', type: 'Short', suffix: 'Stitch Bait' },
  { platform: 'newsletter', type: 'Deep-Dive', suffix: 'Weekly Deep-Dive' },
  { platform: 'newsletter', type: 'Digest', suffix: 'Quick Insights Digest' },
  { platform: 'newsletter', type: 'Story', suffix: 'Personal Story Edition' },
];

const PLATFORM_COLOR = {
  youtube: '#FF0000', instagram: '#C13584', x: '#1DA1F2',
  linkedin: '#0A66C2', tiktok: '#EE1D52', newsletter: '#C9A84C',
};

function getPlatformRules(platform, type) {
  const rules = {
    youtube: `YouTube ${type}: Hook in first 3 seconds. Value-dense. Clear call-to-action. Retention-optimized.`,
    instagram: `Instagram ${type}: Visual-first. Mobile-optimized. ${type === 'Carousel' ? '5-7 slides, each with one clear insight' : type === 'Reel' ? '15-30 seconds, hook-first, loop-friendly' : 'Caption under 150 chars, strong CTA'}`,
    x: `X/Twitter ${type}: ${type === 'Thread' ? '8-12 tweets, numbered, each standalone valuable. Hook tweet is everything.' : 'Under 280 chars. Punchy. Contrarian or data-driven. No hashtags.'}`,
    linkedin: `LinkedIn ${type}: Professional tone. Lead with insight, not pitch. ${type === 'Article' ? '800-1200 words, structured with headers' : '200-300 words, personal story format'}`,
    tiktok: `TikTok ${type}: Maximum first-frame impact. Casual, relatable. Trend-aware. Hook in 0.5s. Pattern interrupt.`,
    newsletter: `Newsletter ${type}: ${type === 'Deep-Dive' ? '1000-1500 words, structured, actionable insights' : '300-500 words, personal voice, one key takeaway'}`,
  };
  return rules[platform] || 'Write platform-appropriate content.';
}

const title = opt.title;
const today = new Date();
const pieces = WATERFALL_TEMPLATE
  .filter((t) => !(t.platform === sourcePlatform && t.type === 'Long-form'))
  .map((t, index) => {
    const d = new Date(today);
    d.setDate(d.getDate() + Math.floor(index / 2) + 1);
    return {
      title: `${title} — ${t.suffix}`,
      platform: t.platform,
      type: t.type,
      status: 'idea',
      parent_id: '<source-uuid>',
      content_body: null,
      tags: [...tags, 'waterfall', `from:${title.slice(0, 30)}`],
      scheduled_date: d.toISOString().split('T')[0],
    };
  });

const summary = ['youtube', 'instagram', 'x', 'linkedin', 'tiktok', 'newsletter'].reduce((acc, p) => {
  acc[p] = pieces.filter((x) => x.platform === p).length + (p === sourcePlatform ? 1 : 0);
  return acc;
}, {});

if (format === 'json') {
  console.log(JSON.stringify({ sourceTitle: title, sourcePlatform, waterfallCount: pieces.length + 1, summary, pieces }, null, 2));
} else {
  console.log(`# Waterfall — "${title}"  (${pieces.length + 1} pieces incl. source)\n`);
  console.log(`Source: ${sourcePlatform} Long-form · schedule: 2/day over 14 days\n`);
  console.log(`Summary: ` + Object.entries(summary).map(([k, v]) => `${k} ${v}`).join(' · ') + '\n');
  let cur = '';
  for (const p of pieces) {
    if (p.platform !== cur) { cur = p.platform; console.log(`\n## ${cur}  (${PLATFORM_COLOR[cur]})`); }
    console.log(`- [${p.scheduled_date}] ${p.type} — ${p.title.split(' — ')[1]}`);
  }
}

if (opt['print-prompts']) {
  const src = (opt['source-script'] && opt['source-script'] !== true ? String(opt['source-script']) : '<paste source script>').slice(0, 5000);
  console.log('\n\n===== WRITE PROMPTS (one per piece) =====');
  for (const p of pieces) {
    console.log(`\n----- ${p.title} -----`);
    console.log(`You are writing a ${p.type} for ${p.platform} based on this source content:\n\nSOURCE: "${src}"\n\nTASK: Write a "${p.title}" piece.\n\nPLATFORM RULES:\n${getPlatformRules(p.platform, p.type)}\n\nOUTPUT: Write ONLY the final content. No commentary. No formatting instructions. Just the ready-to-post content.`);
  }
}
