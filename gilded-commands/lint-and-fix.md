---
description: Run the current venture's linter and type-checker, then fix what's safely auto-fixable
allowed-tools: Bash(npm:*), Bash(npx:*), Read, Edit, Grep, Glob
---
Lint, type-check, and fix the CURRENT venture — cwd-based.

1. Detect tooling from `package.json`: the linter (`eslint` / `next lint`), formatter (`prettier`), and typecheck (`tsc --noEmit`).
2. Run them and capture all errors.
3. Auto-fix the safely-fixable: `eslint --fix`, prettier formatting.
4. For issues needing judgment, fix them manually with minimal diffs. Per house rules: preserve all existing comments/docstrings, keep TypeScript strict, CSS Modules (no inline styles / no Tailwind unless the repo already uses it).
5. Re-run to confirm green. Report anything you did NOT fix and why.

Do not introduce broad refactors — this command is about lint/type cleanliness, not redesign.
