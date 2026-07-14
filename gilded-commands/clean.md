---
description: Kill zombie dev servers and clear stale build caches (Vite/Next) for the current venture
allowed-tools: Bash(lsof:*), Bash(kill:*), Bash(pkill:*), Bash(rm:*)
---
Clean the CURRENT venture's dev environment — operate on the working directory, never a hardcoded legacy path.

1. Kill any dev servers listening on the common ports (3000, 3001, 5173, 8080): for each, `lsof -ti :PORT | xargs kill -9 2>/dev/null` — ignore "no such process".
2. Clear ONLY the stale caches that exist in this repo: `rm -rf node_modules/.vite` (Vite) and/or `rm -rf .next` (Next.js). Never delete `node_modules` wholesale or any source.
3. Report exactly what was killed and cleared.

House rule: never run two dev servers on the same port — that causes the stale-cache crashes this command exists to prevent.
