---
description: Stage, commit, and version the current venture using Gilded Edge conventions (conventional commits, tracked files only)
argument-hint: [optional commit message]
allowed-tools: Bash(git add:*), Bash(git commit:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git checkout:*)
---
Save and version the CURRENT repository — operate on the working directory, never a hardcoded path, and respect the canonical `~/GILDED-EDGE-ECOSYSTEM/` layout.

1. Show what changed: `git status --short` and `git diff --stat`.
2. Stage tracked changes with `git add -u`. Do NOT add untracked files unless I explicitly ask; if new files clearly belong, list them and ask first.
3. If currently on the default branch (`main`/`master`), create a feature branch first per house policy, then commit onto it.
4. Commit with a Conventional Commit message (`feat:` / `fix:` / `perf:` / `chore:` / `docs:`). Use "$ARGUMENTS" as the message if provided; otherwise infer a concise, accurate one from the diff.
5. End the commit body with:
   `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
6. Do NOT push unless I explicitly ask.
