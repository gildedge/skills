# Providers — running the pipeline without (or with) Higgsfield

Gilded addition (see GILDED-CHANGES.md). Upstream assumes the Higgsfield CLI; this
matrix maps every generation step onto four providers so the skill runs with whatever
key the machine has. **Nothing else changes**: the seam doctrine (SKILL Steps 4–5),
the anchor gate, the previz tier, the SSIM gate, frame handoffs, idempotency — all of
it is provider-independent. Only the "generate pixels" call swaps.

## Selection order (SKILL Step 0)

1. `higgsfield` CLI on `$PATH` → use upstream flow verbatim (`references/pipeline.md`).
2. `FAL_KEY` set → **fal.ai — the Gilded ecosystem default.** Seedance 2.0 i2v lives
   there and it frame-locks both ends (start + end image), so it does the full skill.
3. `REPLICATE_API_TOKEN` → Replicate. End-frame support is model-dependent — verify
   before promising architecture B.
4. `GEMINI_API_KEY` → Imagen/Gemini for stills + Veo for video. **Architecture-A-only
   unless you verify last-frame support** (below).

Key presence check — bash 3.2 safe, **never prints a value**:

```bash
for k in FAL_KEY REPLICATE_API_TOKEN GEMINI_API_KEY; do
  eval "v=\${$k:-}"
  [ -n "$v" ] && echo "$k: present" || echo "$k: missing"
done
v=""   # don't leave the last value in a shell var longer than needed
command -v higgsfield >/dev/null 2>&1 && echo "higgsfield: present" || echo "higgsfield: missing"
```

## Capability matrix

The skill's own selection rule (SKILL Step 4) applies to providers exactly as it does
to models: **chained clips must accept a start image; connectors also an end image.**
A provider that can't do both is architecture-A-only; one that can't even start-image
is unusable for chains.

| Step | Higgsfield CLI | fal.ai (`FAL_KEY`) | Replicate (`REPLICATE_API_TOKEN`) | Gemini/Veo (`GEMINI_API_KEY`) |
|---|---|---|---|---|
| Scene stills (t2i) | `gpt_image_2` | `fal-ai/flux/schnell` (fast/cheap) or `fal-ai/flux/dev` | e.g. `black-forest-labs/flux-schnell` | `imagen-4.0-generate-001` via `ai.models.generateImages` |
| Anchor style-lock (image-referenced still) | `--image anchor.png` | image-editing model, e.g. `fal-ai/nano-banana/edit` (image + prompt) — **verify schema on the model page first** | model-dependent (look for an `image`/reference input) | `gemini-2.5-flash-image` (image + text in, image out); plain Imagen is text-only |
| Dive / leg video (start image) | roster models, `--start-image` | `bytedance/seedance-2.0/image-to-video` — `image_url` | model-dependent — look for `image` / first-frame input | Veo `generateVideos` with `image` (first-frame conditioning) |
| Connector (start + end image) | roster models, `--start-image --end-image` | same fal model — `image_url` + `end_image_url` ✓ | **model-dependent** — many Replicate video models are start-image-only → arch-A-only | **not reliably available** on the Developer API — treat as arch-A-only (see Veo notes) |

Honesty notes, per the seam doctrine:

- **fal Seedance 2.0** is the only non-Higgsfield path confirmed in this ecosystem to
  frame-lock both ends (it's exactly how `edge-os-works/seedance/generate-cinematic.mjs`
  builds its first/last-frame continuity chain). It does the full skill, both
  architectures.
- **Replicate**: before promising architecture B, fetch the model's input schema and
  look for an end/last-frame field. No such field = that model can only *condition*,
  not *continue* — architecture-A-only (start-image models) or unusable (reference-only
  models). Schema check (no spend):
  ```bash
  curl -s -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
    https://api.replicate.com/v1/models/<owner>/<name> \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('latest_version',{}).get('openapi_schema',{}).get('components',{}).get('schemas',{}).get('Input',{}).get('properties',{}), indent=2))"
  ```
- **Veo**: first-frame `image` conditioning is supported (i2v). Last-frame conditioning
  is a Veo 3.1-era feature that is **not guaranteed on the public `GEMINI_API_KEY`
  surface** — if your SDK version doesn't expose a working last-frame/`lastFrame`
  config for your model id, do not fake it: Veo is **architecture-A-only**. A Veo model
  that only does text→video (no `image` input in your tier) can't hold any seam —
  unusable for chains; use it, if at all, for a standalone hero clip outside the chain.
- **Mixing providers mid-chain** is the same sin as mixing models mid-chain (SKILL
  Step 4): render-character shift = subtle pop. One provider + one model for all
  chained clips; the only sanctioned exception is the single-clip NSFW fallback.

## Cost preflight — REQUIRED before any paid call

Same convention as the `cinematic-render-pipeline` skill: **estimate the spend, show
it, and get an explicit go-ahead (`--run` on scripts, or a plain "yes" in the
interview) before the first paid API call.** The SKILL Step 1 interview close is that
gate — with a non-Higgsfield provider, state the estimate in dollars, not credits.

Planning rates (order-of-magnitude, NOT a bill — re-check the provider's pricing page
before a large batch, and update these when pricing moves):

| What | Planning rate |
|---|---|
| Seedance 2.0 (fal, full) | ~$0.50 / video-second (fast tier roughly half) |
| Replicate video models | ~$0.10–0.50 / video-second — read the model page |
| Veo 3.x | ~$0.40–0.75 / video-second (`-fast-` variants cheaper) |
| Stills (flux / gpt-image / imagen class) | ~$0.03–0.08 / image |

Formula (mirrors SKILL Step 1.4): videos = `N` (arch A) or `2N-1` (arch B); seconds =
~8s per dive/leg + ~5s per connector; add the 20–30% re-roll buffer (interiors trip
content filters). Example — 6-scene arch-B showcase on fal Seedance:
`6×8s + 5×5s = 73s × $0.50 ≈ $37`, plus re-rolls ≈ **$45–50**, plus 6 stills (~$0.50)
— state that number and wait for the go-ahead. The previz tier (fast/mini model)
still applies and still pays for itself.

Never echo a key. Check presence with the loop above; pass keys to SDKs only via env.

## Runnable equivalents (Node, `@fal-ai/client`) — fal.ai path

Mirrors `edge-os-works/seedance/generate-cinematic.mjs` (the in-repo precedent).
Install once: `npm i @fal-ai/client` (any venture's node_modules works via `NODE_PATH`).
Keep the pipeline.md workflow — prompts in `$WORK/*.txt`, outputs in `$WORK`,
skip-if-exists idempotency — and swap only the gen calls:

```js
// gen-fal.mjs — one runner for stills, dives, connectors. Idempotent like pipeline.md.
// Usage:
//   node gen-fal.mjs still  <name> <prompt.txt> [anchor.png]
//   node gen-fal.mjs dive   <name> <prompt.txt> <start.png> [duration]
//   node gen-fal.mjs conn   <i>    <prompt.txt> <start.png> <end.png> [duration]
// Env: FAL_KEY (required), WORK (default /tmp/scroll-world), FAL_FAST=1 for the fast tier.
// COST GUARD: refuses to spend unless --run is passed; otherwise prints the estimate only.
import { fal } from "@fal-ai/client";
import fs from "fs";
import path from "path";

const FAL_KEY = process.env.FAL_KEY;
if (!FAL_KEY) { console.error("FAL_KEY missing (not printing values; set it in the env)"); process.exit(1); }
fal.config({ credentials: FAL_KEY });

const WORK = process.env.WORK || "/tmp/scroll-world";
const RUN = process.argv.includes("--run");
const args = process.argv.filter(a => a !== "--run").slice(2);
const [kind, name, promptFile, ...rest] = args;

const VIDEO_MODEL = process.env.FAL_FAST
  ? "bytedance/seedance-2.0/fast/image-to-video"   // previz tier (cheaper, still frame-locks)
  : "bytedance/seedance-2.0/image-to-video";       // full tier
const IMAGE_MODEL = "fal-ai/flux/schnell";
const RATE_PER_SEC = 0.50, RATE_PER_IMAGE = 0.05;  // planning figures — see rate table

async function upload(p) {
  const blob = new Blob([fs.readFileSync(p)], { type: "image/png" });
  return fal.storage.upload(blob);                 // fal needs a URL, not a local path
}
async function download(url, out) {
  const r = await fetch(url);
  fs.writeFileSync(out, Buffer.from(await r.arrayBuffer()));
  console.log("saved", out, (fs.statSync(out).size / 1048576).toFixed(1) + " MB");
}

const prompt = fs.readFileSync(promptFile, "utf8");
let out, est;
if (kind === "still") { out = path.join(WORK, `still_${name}.png`); est = RATE_PER_IMAGE; }
else if (kind === "dive") { out = path.join(WORK, `dive_${name}.mp4`); est = (Number(rest[1]) || 8) * RATE_PER_SEC; }
else if (kind === "conn") { out = path.join(WORK, `conn_${name}.mp4`); est = (Number(rest[2]) || 5) * RATE_PER_SEC; }
else { console.error("kind must be still|dive|conn"); process.exit(1); }

if (fs.existsSync(out) && fs.statSync(out).size > 0) { console.log(kind, name, "cached"); process.exit(0); }
console.log(`estimated spend: ~$${est.toFixed(2)} (${kind} ${name}, planning rate)`);
if (!RUN) { console.log("dry-run — pass --run after the user has approved the spend."); process.exit(0); }

if (kind === "still") {
  // Anchor style-lock note: flux/schnell is text-only. For the SKILL Step 2 anchor
  // lock, either switch IMAGE_MODEL to an image-editing model (e.g. fal-ai/nano-banana/edit,
  // input { prompt, image_urls: [anchorUrl] } — VERIFY the schema on the model page first)
  // or rely on the byte-identical style preamble, which is the primary cohesion tool anyway.
  const r = await fal.subscribe(IMAGE_MODEL, { input: { prompt, image_size: "landscape_16_9", num_images: 1 } });
  await download(r.data.images[0].url, out);
} else {
  const dur = kind === "dive" ? (rest[1] || 8) : (rest[2] || 5);
  const input = { prompt, image_url: await upload(rest[0]), duration: String(dur) };
  if (kind === "conn") input.end_image_url = await upload(rest[1]);   // the frame-lock
  const r = await fal.subscribe(VIDEO_MODEL, {
    input, logs: true,
    onQueueUpdate: u => { if (u.status === "IN_PROGRESS") process.stdout.write("."); },
  });
  await download(r.data.video?.url || r.data.video, out);
}
```

Wire it into pipeline.md's loops by replacing the `higgsfield generate create …` line
inside `gen_still` / `gen_dive` / `gen_conn` with the matching `node gen-fal.mjs … --run`
call — the surrounding idempotency, frame extraction (§3), encode (§5), posters (§5b),
and SSIM gate (§5c) run unchanged. `fal.subscribe` blocks until done (it long-polls the
queue), so run the batch script detached exactly as pipeline.md says. Stills come back
16:9 (`landscape_16_9`) rather than upstream's 3:2 — that's fine (the clip is 16:9
anyway; posters are extracted from encoded clips per §5b).

Re-rolls: delete the output file and re-run — same as upstream. Seedance's NSFW filter
behaves the same through fal as through Higgsfield (see gotchas.md); fal's Kling
deployments are the equivalent cross-filter fallback if one clip keeps flagging.

### Previz on fal

`FAL_FAST=1` swaps to `bytedance/seedance-2.0/fast/image-to-video`, which keeps
start+end conditioning — the same "draft tier that still frame-locks" role as
`seedance_2_0_mini` upstream. Run the whole chain there first (SKILL Step 4, previz
doctrine), review the assembled page, then clear the draft clips and re-run without
`FAL_FAST`.

## Replicate path (curl)

```bash
# 1. Verify the model frame-locks (schema check above). Then:
curl -s -X POST "https://api.replicate.com/v1/models/<owner>/<name>/predictions" \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Prefer: wait" \
  -d @- <<JSON > "$WORK/dive_$n.json"
{"input": {"prompt": $(python3 -c "import json,sys;print(json.dumps(open('$WORK/dive_$n.txt').read()))"),
 "image": "<https-url-or-data-uri-of-start-frame>", "duration": 8}}
JSON
# Poll GET https://api.replicate.com/v1/predictions/<id> until status=succeeded,
# then download .output. Field names (image / first_frame_image / end-frame) come from
# the schema check — do not guess them.
```

Local frames must be passed as data URIs or uploaded via Replicate's files API —
Replicate does not read local paths. If the chosen model has no end-frame input:
architecture A only, and say so to the user rather than shipping crossfade-only seams
as if they were flights.

## Gemini / Veo path (Node, `@google/genai`)

Mirrors `edge-os-works/generate-video.mjs` conventions (see the
`cinematic-render-pipeline` skill for the grounded details):

```js
import { GoogleGenAI } from "@google/genai";
import fs from "fs";
const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

// Stills: Imagen (text-only — no anchor image lock; the verbatim preamble carries cohesion)
const img = await ai.models.generateImages({ model: "imagen-4.0-generate-001",
  prompt, config: { numberOfImages: 1, aspectRatio: "16:9" } });

// Legs (architecture A): first-frame conditioned i2v, then poll the operation
let op = await ai.models.generateVideos({
  model: "veo-3.0-generate-001",   // falls back to veo-3.0-fast-generate-001 on quota
  prompt,
  image: { imageBytes: fs.readFileSync(lastFramePng).toString("base64"), mimeType: "image/png" },
  config: { aspectRatio: "16:9", numberOfVideos: 1 },
});
while (!op.done) { await new Promise(r => setTimeout(r, 10000)); op = await ai.operations.getVideosOperation({ operation: op }); }
```

Architecture A works: leg N's `image` = leg N-1's ACTUAL extracted last frame, exactly
per SKILL Step 4. Connectors (start+end) — only if your SDK/model exposes working
last-frame conditioning; verify with a single cheap test clip and an SSIM check on its
end seam **before** planning an architecture-B world on Veo. If the end frame doesn't
lock (SSIM < 0.90 against the target frame), Veo is architecture-A-only for you. Veo is
async + polled and burns quota per attempt — count attempts in the estimate.

## What stays identical across all providers

- Anchor gate (one still → approval → batch), previz-first, spend gate at interview close.
- Frame handoffs from **rendered** clips, never stills (SKILL Step 5).
- Encode recipe, extracted-frame posters, SSIM seam gate (pipeline.md §5–5c).
- One model, one provider, for all chained clips.
- Generations take minutes everywhere — run detached, poll, re-roll individual failures.
