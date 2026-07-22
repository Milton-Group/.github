---
name: handoff
description: Generate a self-contained "pick up here" prompt for the next Claude Code session, then copy it to the clipboard and save a file fallback. Use when context usage is high (~250-300K) and you want to /clear and continue the SAME work in a fresh session without losing the thread. After running, the user manually runs /clear, pastes (Cmd+V), and hits Enter.
baseline: v0.7.0
---

# /handoff — context handoff prompt generator

Use this when the current session's context is getting large and the user wants to `/clear` and keep going on the **same work** in a fresh, low-context session. This skill writes the curated continuation prompt so the user doesn't have to ask for one by hand.

It does NOT clear or paste anything itself — Claude Code cannot run `/clear` on itself or type into its own input box. This skill's job is to make the next session start *correct and cheap*; the user does the 3 manual keystrokes (`/clear`, Cmd+V, Enter).

## Arguments

Parse from the invocation (e.g. `/handoff focus on the apply runbook only`):

- Free-text after `/handoff` — an optional steer for what the next session should prioritize, or what to leave out. Fold it into the "Immediate next step" and scope sections. If absent, infer the natural next step from the conversation.

## Steps

### Step 1 — Reconstruct the live work state

From the current conversation, assemble the facts a fresh session would need. Pull from what actually happened this session, not assumptions. Run quick read-only commands to ground the prompt in current reality rather than stale memory:

- `git -C <active repo> branch --show-current` and `git -C <active repo> status --short` — current branch + uncommitted state.
- `git -C <active repo> log --oneline -5` — recent commits, so the handoff references real shas.

Do these in parallel. Don't run anything that mutates state.

### Step 2 — Write the handoff prompt

Compose a **self-contained** prompt addressed to the next session. It must let a zero-context Claude resume without re-reading this whole conversation. Use this skeleton (drop sections that genuinely don't apply, but prefer completeness over brevity — the whole point is to not re-discover things):

```
Continue work on <one-line goal>.

## Where we are
- Repo: <path> | Branch: <branch>
- Status: <what's done so far, in 2-4 bullets, referencing real commit shas>
- Uncommitted: <files dirty in working tree, or "clean">

## Immediate next step
<the single concrete next action, specific enough to start typing — file + what to change, or command to run>

## Key files & paths
- <path:line> — <why it matters>
- ...

## Decisions already made (don't relitigate)
- <decision> — <one-line rationale>
- ...

## Gotchas / do NOT
- <thing that will bite a fresh session — a shadowed rule, a fragile dependency, a "looks wrong but is intentional">
- ...

## Definition of done / how to verify
- <what "finished" looks like; the test or check to run>

## Memory pointers
- <relevant ~/.claude memory file slugs, e.g. project_milton_281_b1_warm_standby — so the next session recalls them>
```

Rules for a good handoff prompt:
- **Resolve all pronouns and "it"s.** A fresh session has no idea what "the canary" or "that fix" refers to — name things fully.
- **Quote real identifiers**: shas, file paths, Linear IDs, branch names, IPs. No "the recent commit."
- **Carry forward the *why*, not just the *what*** for any non-obvious decision, so the next session doesn't undo it.
- **Respect repo conventions**: if the active repo has a CLAUDE.md, the next session will reload it automatically — don't restate generic rules, only call out the ones specifically in play for this task.
- **Honor the user's steer** (the free-text arg) for scope.
- Keep it tight. This is a launch pad, not a transcript. If it's over ~60 lines, you're including too much narrative.

### Step 3 — Deliver it

1. Write the prompt to a **per-repo, per-branch** fallback file so parallel handoffs on different branches don't clobber each other. Derive the path from the active repo name and current branch, sanitizing `/` in the branch to `-`:

   ```bash
   REPO=$(basename "$(git -C <active repo> rev-parse --show-toplevel)")
   BRANCH=$(git -C <active repo> branch --show-current | tr '/' '-')
   FALLBACK="$HOME/.claude/handoff-${REPO}-${BRANCH}.md"
   mkdir -p "$HOME/.claude"
   # write the composed prompt to "$FALLBACK" (overwrite)
   ```

   This is the durable fallback if the clipboard gets clobbered.
2. Copy it to the clipboard, trying each platform's tool in turn (template consumers include Linux Coder workspaces, not just macOS). Check that the copy actually **succeeded** — the tool exists *and* the command exited 0 — not merely that the tool is present:

   ```bash
   COPIED=""
   if command -v pbcopy >/dev/null 2>&1 && pbcopy < "$FALLBACK"; then
     COPIED="pbcopy"                                  # macOS
   elif command -v wl-copy >/dev/null 2>&1 && wl-copy < "$FALLBACK"; then
     COPIED="wl-copy"                                 # Wayland
   elif command -v xclip >/dev/null 2>&1 && xclip -selection clipboard < "$FALLBACK"; then
     COPIED="xclip"                                   # X11
   fi
   # $COPIED holds the tool that succeeded, or is empty if every copy failed.
   ```

   Only claim "Copied to clipboard" when a copy command actually returned success. If a tool is missing **or** its copy errored, fall through to the next tool; if none succeed, end at the file-only message — the fallback file still holds the prompt.
3. Print the full prompt back in the chat (in a fenced block) so the user can eyeball it before clearing — and so it survives in scrollback even if the clipboard is lost.
4. End with the exact next actions, keyed to which tool succeeded (`$COPIED`):

   - **`pbcopy` succeeded (macOS):**
     > Copied to clipboard (and saved to `~/.claude/handoff-<repo>-<branch>.md`).
     > Next: run `/clear`, then paste with **Cmd+V**, then Enter.
   - **`wl-copy` or `xclip` succeeded (Linux):**
     > Copied to clipboard (and saved to `~/.claude/handoff-<repo>-<branch>.md`).
     > Next: run `/clear`, then paste with **Ctrl+Shift+V** (terminal paste), then Enter.
   - **no copy succeeded (file only):**
     > Saved to `~/.claude/handoff-<repo>-<branch>.md` (no working clipboard tool — copy it from there manually).
     > Next: run `/clear`, paste the prompt, then Enter.

Do not call `/clear` or attempt to type for the user — neither is possible from inside the session, and pretending otherwise would lose their work.
