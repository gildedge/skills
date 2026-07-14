---
description: Clean-start the current venture's dev server (kill zombies, clear cache, detect Vite/Next/Express, launch)
allowed-tools: Bash(lsof:*), Bash(kill:*), Bash(rm:*), Read, Bash(npm:*)
---
Start the CURRENT venture's dev server cleanly — cwd-based, respect canonical paths.

1. Detect the stack: read `package.json` scripts and deps to tell Next.js vs Vite vs Express (and the dev port).
2. Kill existing servers on the relevant port(s) and clear the matching cache (`.next` or `node_modules/.vite`) — same as `/clean`.
3. Launch with the project's own dev script (e.g. `npm run dev`). When a live preview is useful, prefer the Browser preview tool (`preview_start`) over a raw backgrounded process.
4. Report the local URL once it's up.

Never start a second dev server on a port that already has one — clean first.
