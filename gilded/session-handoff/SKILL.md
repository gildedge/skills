---
name: session-handoff
description: Operationalize the Gilded Edge Intelligence Wiki session-continuity protocol (infrastructure/wiki/session/PROTOCOL.md), which calls context loss "the #1 problem in multi-session AI development." Use at the START of any working session to load prior context (read handoff.md, the last 3 history entries, and run capture.sh for a live snapshot), and at the END to write an updated handoff.md, a new history/YYYY-MM-DD-HHMM.md summary, append to log.md, capture a final snapshot, and stage everything for commit + push. Triggers on "start session", "resume", "where did we leave off", "load context", "session handoff", "wrap up the session", "end session", "write the handoff", "capture state", "session summary", or when beginning/finishing work across the ecosystem.
---

# Session Handoff — Continuity Protocol Runner

The wiki at `~/GILDED-EDGE-ECOSYSTEM/infrastructure/wiki/session/` defines a protocol whose entire purpose is to defeat context loss between AI conversations. This skill executes that protocol so it actually happens instead of being aspirational Markdown.

Canonical files (do not relocate):
- `PROTOCOL.md` — the spec (start steps, end steps, templates).
- `handoff.md` — the single living "read this first" doc. Overwritten each session end.
- `history/YYYY-MM-DD-HHMM.md` — append-only per-session summaries. One new file per session.
- `snapshots/YYYY-MM-DD-HHMM.md` — machine-captured state (git/ports/disk). One per capture.
- `capture.sh` — generates a snapshot to stdout.
- `log.md` — append-only one-line session-end log (create if missing).

## When to use

- **Session START** — before doing real work, so you inherit the last session's momentum, blockers, and pending decisions.
- **Session END** — before you stop, so the next session (or the next Claude) starts warm.
- **Mid-session** — optional, at natural breakpoints in long (>2h) sessions.

## Workflow — START

Run the loader; it prints everything the protocol says to read, in order:

```bash
bash scripts/session-start.sh
```

It will:
1. Print `session/handoff.md` (current state, hot entities, pending decisions, blockers).
2. Print the **last 3** files in `session/history/` (trajectory).
3. Run `session/capture.sh` and write the snapshot to `session/snapshots/<stamp>.md`, echoing it.
4. Flag any `decisions/**` files containing `Outcome: PENDING` and any `contradictions/**` (protocol steps 4–5), if those dirs exist.

Then, in your own words, tell the user the working context, the top pending decision, and the single "Next Priority Action" from the handoff before touching code.

## Workflow — END

Dry-run first (default) — it shows exactly what it *would* write, and writes nothing:

```bash
bash scripts/session-end.sh --summary "One-line summary of this session"
```

Review the previews, then commit the artifacts to disk (still local — no git push):

```bash
bash scripts/session-end.sh --summary "..." --write
```

`--write` will:
1. Scaffold an updated `handoff.md` from the PROTOCOL template (you then fill the real bullets — the script seeds structure + timestamp, it doesn't invent status).
2. Create `history/<YYYY-MM-DD-HHMM>.md` from the Session Summary template.
3. Append a one-line entry to `log.md`.
4. Run `capture.sh` into `snapshots/<stamp>.md`.
5. **Stage** with `git add -A` (only if the wiki is a git repo) and print the suggested commit + push commands. It does **not** run `commit` or `push` — that stays a human/confirmed step, because push is an irreversible publish.

After `--write`, edit the scaffolded `handoff.md` and history file with the *actual* accomplishments, decisions, and next actions before committing. The scaffold is a skeleton, not a substitute for judgment.

## Templates (from PROTOCOL.md)

The scripts embed the exact **Handoff Template** and **Session Summary Template** shipped in `PROTOCOL.md` (Active Context / Hot Entities / Pending Decisions / Environment State / Blockers / Next Priority Actions; and Accomplishments / Decisions Made / Files Modified / State at Close / Recommendation for Next Session). Keep them in sync: if `PROTOCOL.md` changes its template, update `scripts/session-end.sh` to match.

## Gotchas

- **Timestamp format is load-bearing.** History and snapshot filenames are `YYYY-MM-DD-HHMM` (e.g. `2026-07-14-1430`). The `last 3` loader sorts lexically, which only works because of this zero-padded format. Don't invent `-2pm` style names.
- **`capture.sh` uses legacy repo paths.** Its `REPOS` array still points at `$HOME/LUMIER STUDIOS`, `$HOME/Documents/gilded-artworks`, and `$HOME/Documents/GILDEDGE/wiki`. Those are the legacy symlinks — fine for a read-only snapshot, but if a path is missing you'll see "NOT A GIT REPO". That's the script's problem to fix, not this skill's; the loader still runs it and reports what it got.
- **handoff.md is overwritten, history is appended.** Never edit an old `history/*.md` to "update" state — write a new one and refresh `handoff.md`. History is the trajectory; handoff is the snapshot.
- **Push is not automatic.** The protocol's step 5 says commit + push, but this skill stops at staging and *prints* the commands. Publishing is a confirmed action — run it yourself once you've reviewed the diff.
- **Don't fabricate the snapshot.** If `capture.sh` fails (e.g. `lsof`/`vm_stat` unavailable), record that it failed in the handoff rather than writing plausible-looking numbers. The whole point is fidelity.
- **Run from anywhere.** Both scripts resolve the wiki via `$HOME/GILDED-EDGE-ECOSYSTEM/infrastructure/wiki` and `cd` internally; agent shells reset cwd between calls, so always invoke with the absolute script path.
