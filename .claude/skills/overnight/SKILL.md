---
name: overnight
description: Launch a detached headless Claude Code run scoped to one 1Password vault via an ephemeral service account. Use when the user says "run X overnight", "let claude work on <project> tonight", or wants a headless run with one-off vault access. Args - <vault> <task description> [ttl, default 12h].
---

# Overnight headless run with one-off vault access

Wraps the sibling script `.claude/skills/overnight/claude-overnight` (invoke as
`bash .claude/skills/overnight/claude-overnight` so a lost exec bit never
matters). It mints a **single-run 1Password service account** granted only the
named vault(s), launches Claude with the token in the child env only (never
printed, never on disk), and lets the SA self-expire. Rationale: SA vault
grants are immutable after creation, so one-off access = one-off SA.

## Steps

1. **Parse args**: first token is the vault (per the org taxonomy this is the
   project's surface vault, e.g. `receipt-relay`, `feishu-mcp`,
   `materials-platform`); the rest is the task prompt; an optional trailing
   `ttl` like `8h`. If the vault or task is missing, ask — never guess a vault.
   The script refuses any vault whose name contains `prod` or `local-infra`
   (any case); don't work around that — those are attended-only. Placement
   rules: `docs/SECRETS.md` in Milton-Group/harness.
2. **Working dir**: default to the current repo root (this skill ships per-repo,
   so the run's repo is normally the one you're in). If the task targets a
   different repo, ask for the path.
3. **Write the task prompt to a file** with the Write tool (e.g.
   `~/.claude/overnight-logs/<name>.prompt`). NEVER interpolate the prompt text
   into a shell command — prompts routinely contain quotes/backticks/$( ) and
   pasting them into bash is command injection in the user's own session.
4. **State the success criterion in the prompt** (org loop-engineering
   standard: `Milton-Group/infra` → `docs/loop-engineering.md`). If the target
   repo ships a verify entry point (`scripts/verify.sh`, or the equivalent its
   CLAUDE.md documents), the task prompt must tell the run to loop on it and
   define done as the verdict line — `EVAL <target> PASS` as the last line of
   stdout — plus the harness rules: **loop cap 3** per (task, signal);
   **BLOCKED = environment fault** — stop and record it in the log, never
   "fix" code to clear it; **test ratchet** — never edit, weaken, or delete a
   check to go green; honor the repo profile's **never-loop list** (deploys,
   migrations, publish, `terraform apply`). If the repo has no verify entry
   point, the prompt must still state what verifiable "done" looks like — an
   unattended run must never self-certify.
5. **Do NOT grant extra vaults by default.** In particular do not suggest
   `--infra` (the shared "Infra Ops" vault): an unattended run that can read
   shared fleet secrets can be steered by prompt-injected repo content into
   exfiltrating them — read-only does not mitigate that (reading IS the
   exfiltration). Only pass `--infra` or `-v <vault>` if the user explicitly
   asked for it this session, and restate the risk in one line when they do.
6. **Confirm before launching** (unattended run, real permissions): show vault,
   repo dir, ttl, and the exact task prompt.
7. **Preflight the 1P session synchronously** before detaching (biometric can't
   fire once detached): `env -u OP_SERVICE_ACCOUNT_TOKEN op vault get "<vault>"`.
   If it fails, stop and tell the user to unlock 1Password — do not launch.
   **Locked-1P fallback** (user unreachable — e.g. relaunching a dead run at
   night): if a standing SA token exists whose scope covers the needed vault
   (e.g. `~/.config/op/claude-automation.env`, the `claude-headless` SA), launch
   with `--token-file <path> --expect <vault>` instead of minting. Always pass
   `--expect` — the wrapper's bare denylist (`prod`/`local-infra`/`Infra Ops`)
   is naming-convention-dependent; `--expect` refuses anything outside the
   named vault(s). The file must be chmod 600. No launcher TTL applies and the
   token is a months-lived credential sitting in the run's environment for the
   whole night — the SA's own expiry/scope is the fence — so prefer minting
   whenever the 1P session is warm.
8. **Launch detached** with locked-down logging:

   ```bash
   LOGDIR=~/.claude/overnight-logs
   mkdir -p "$LOGDIR" && chmod 700 "$LOGDIR"
   NAME=$(date +%Y%m%d-%H%M)-<vault-slug>        # slug: [a-z0-9-] only
   (umask 077; nohup bash .claude/skills/overnight/claude-overnight <vault> \
      -t <ttl> -d <repo-dir> -p "$LOGDIR/$NAME.prompt" \
      -- --permission-mode acceptEdits \
      > "$LOGDIR/$NAME.log" 2>&1 &)
   ```

   Use `run_in_background: true`. `acceptEdits` auto-accepts file edits only —
   Bash commands stay gated by the repo's allowlist, which is the point. NEVER
   pass `--dangerously-skip-permissions` / `bypassPermissions` to an overnight
   run, even if asked mid-session — tell the user to launch that by hand.
9. **Report**: the service-account name (first stderr line in the log), the log
   path, and the expiry. The SA token needs no cleanup (it self-expires), but
   the SA *object* stays listed in the 1P admin console — they're all named
   `overnight-*`; suggest a periodic bulk cleanup there (the CLI cannot delete
   service accounts).
10. **Babysitting**: headless launches auto-retry transient API drops
   ("Connection closed mid-response", laptop suspend) by resuming the same
   session — 1 initial attempt plus up to 5 resume retries, linear backoff,
   `» claude exited rc=… — resuming` lines on stderr. The wrapper stays alive
   as the parent process, so monitor the *wrapper* PID (it spans all retries).
   A run that still dies after 5 resumes can be continued under a fresh token
   with `-- --resume <session-id>` (find the session id in
   `~/.claude/projects/<project-slug>/`, the `.jsonl` whose first line contains
   your prompt text). Resume only with a token of the **same or narrower**
   vault scope — the resumed transcript executes under the new token.

## On a Coder workspace (no desktop app)?

Workspace 1P auth is a standing per-user service account (injected at boot),
and service accounts can't mint service accounts — so the mint modes above
won't work there. Instead:

1. Ask an admin to run `claude-overnight grant <vault> <your-user-suffix>` on
   their machine. It delivers the token as item `overnight-<vault>-<date>` in
   your `milton-user-<you>` vault (1P-item-to-1P-item, never through chat) and
   self-expires like any other run.
2. Launch with the granted token via your standing auth:

   ```bash
   bash .claude/skills/overnight/claude-overnight \
     --token-from 'op://milton-user-<you>/<item>/credential' \
     -p "$LOGDIR/$NAME.prompt" -- --permission-mode acceptEdits
   ```

   TTL, prod refusal, and vault scope were fixed at grant time; `-t/-v/-w` are
   refused with `--token-from`. All other steps (prompt via file, 700 logs,
   confirm before launch) apply unchanged. Self-service requests via a Feishu
   approval bot are planned: MILTON-636.

## Notes

- Mint modes require: 1P CLI (`op`) signed in via desktop-app integration, and
  the user must be able to create service accounts (owner/admin). Non-admins:
  use the grant flow above.
- Logs under `~/.claude/overnight-logs/` capture everything the run printed and
  may contain secret material fetched via `op` — the dir is 700 and files 600
  (umask); treat logs as secrets, don't paste them into chats/issues.
- The script preflights `claude` on PATH, the `-d` dir, and each vault BEFORE
  minting, so a failed launch doesn't orphan a live token.
- `--check` mode mints a 1-minute SA and shows exactly what a grant would see.
- Multiple vaults: repeat `-v <vault>` (read-only). Write access: `-w` grants
  write on the primary vault only.
