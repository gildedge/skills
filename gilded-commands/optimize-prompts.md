---
description: Run an autonomous prompt-optimization session on the current venture's AI prompts (prompt-lab loop)
allowed-tools: Read, Write, Edit, Bash
---
Optimize this venture's AI prompts using the **prompt-lab** skill (Karpathy autoresearch evaluate-and-iterate loop):

1. Load the prompt-lab skill.
2. Identify this venture's prompt surfaces (e.g. `services/ai/*`, `geminiService.ts`, `aria-prompt.ts`, `api/analyze`, Genkit flows).
3. Establish baselines: generate outputs with the current prompts across the test cases and score them.
4. Run 3–5 experiments, scoring each; log to the skill's `experiments/` dir.
5. Present the WINNER diffs for my review.

**Do NOT apply any prompt change without my explicit approval.** After changes land, use the **prompt-eval-harness** skill to lock in the improvement and catch regressions.
