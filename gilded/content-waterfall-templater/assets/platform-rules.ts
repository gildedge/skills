// Verbatim from aria-agent/src/app/api/waterfall/route.ts — keep in sync.
// Used to build the write_piece Gemini prompt per platform/type.

export function getPlatformColor(platform: string): string {
  const colors: Record<string, string> = {
    youtube: '#FF0000',
    instagram: '#C13584',
    x: '#1DA1F2',
    linkedin: '#0A66C2',
    tiktok: '#EE1D52',
    newsletter: '#C9A84C',
  };
  return colors[platform] || '#888888';
}

export function getPlatformRules(platform: string, type: string): string {
  const rules: Record<string, string> = {
    youtube: `YouTube ${type}: Hook in first 3 seconds. Value-dense. Clear call-to-action. Retention-optimized.`,
    instagram: `Instagram ${type}: Visual-first. Mobile-optimized. ${type === 'Carousel' ? '5-7 slides, each with one clear insight' : type === 'Reel' ? '15-30 seconds, hook-first, loop-friendly' : 'Caption under 150 chars, strong CTA'}`,
    x: `X/Twitter ${type}: ${type === 'Thread' ? '8-12 tweets, numbered, each standalone valuable. Hook tweet is everything.' : 'Under 280 chars. Punchy. Contrarian or data-driven. No hashtags.'}`,
    linkedin: `LinkedIn ${type}: Professional tone. Lead with insight, not pitch. ${type === 'Article' ? '800-1200 words, structured with headers' : '200-300 words, personal story format'}`,
    tiktok: `TikTok ${type}: Maximum first-frame impact. Casual, relatable. Trend-aware. Hook in 0.5s. Pattern interrupt.`,
    newsletter: `Newsletter ${type}: ${type === 'Deep-Dive' ? '1000-1500 words, structured, actionable insights' : '300-500 words, personal voice, one key takeaway'}`,
  };
  return rules[platform] || 'Write platform-appropriate content.';
}
