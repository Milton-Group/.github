# CLAUDE.md

Instructions for Claude Code when working in this repository.

## Repo-specific rules

<!-- Rules in this section are specific to this repo. Edit freely — bootstrap.sh won't touch anything above the "Company baseline" section. -->

### Tech stack

- _e.g. Next.js 14 (App Router), TypeScript, Tailwind, Prisma, PostgreSQL_

### Key commands

- `npm run dev` — start the dev server
- `npm run build` — production build
- `npm test` — run the test suite
- `npm run lint` — lint + format check

### Repo-specific conventions

- _e.g. All API routes live in `src/app/api/`. Use server actions for mutations, not API routes._
- _e.g. Database migrations go through `npx prisma migrate dev --name <description>`._

### Important context

- _e.g. This repo powers the public-facing marketing site. Changes are visible to customers immediately on merge._

## Company baseline

> Maintained in `Milton-Group/harness`. Last synced: 2026-08-24 (v0.18.0)

### Working style

- **Ask before taking risky actions.** Anything that touches shared state (pushing code, creating PRs, sending Feishu/Linear messages, deleting branches, dropping tables, `rm -rf`) should be confirmed before execution unless the user has already authorized it for this session. Local, reversible edits don't need confirmation.
- **Don't bypass safety checks to unblock yourself.** `--no-verify`, `--force`, and `reset --hard` are not shortcuts around failing hooks — they're signals to stop and diagnose. If a pre-commit hook is failing, fix the underlying issue.
- **Match scope to the request.** A bug fix doesn't need a refactor. A one-shot script doesn't need a helper library. Don't introduce abstractions or backwards-compatibility shims for scenarios that aren't real yet. Feature flags follow the same rule with one deliberate exception: a flag that lets **real, in-progress** work merge to `main` behind an off switch is the org's release mechanism, not speculation (`docs/CONVENTIONS.md` § Git & branching). A flag guarding a hypothetical is still scope creep, and a flag whose rollout is finished is dead code — delete it.
- **Trust the tools you have.** Prefer `Read`/`Edit`/`Grep`/`Glob` over shelling out to `cat`/`sed`/`grep`/`find`. Run independent tool calls in parallel.

### Memory — what to save during a session

Project memory should capture operational facts that an outside observer could not recover from the repository or its diff. Save these facts when you discover or change them:

- **Credential lifetimes** — when a token, certificate, or secret was created, when it expires, and where it is stored. Never save the secret value itself.
- **Live or manual changes** — edits to a running system, admin console, or other external state that are not yet durable in code, including any rollback or follow-up needed.
- **External-state surfaces** — settings and third-party configuration where drift can affect the project.
- **Lifecycle events** — resources or environments that were created, applied, paused, archived, migrated, or retired.
- **Decisions with non-obvious rationale** — what was chosen and why, especially when the repository records the outcome but not the tradeoff.

Update or replace the memory when the fact changes so stale operational state does not become guidance.

### Plan → Execute → Review (the quality harness)

Non-trivial changes go through three explicit phases. The phases matter more than the specific tools — but every non-trivial change should *visibly* go through all three. Trivial edits (typo, comment fix, single-line tweak) skip the process.

The main session is the **orchestrator**: it plans inline, spawns reviewers and builders as subagents, and synthesizes — it does not build non-trivial work inline in the main channel.

Review findings must earn their complexity: every Critical/High finding carries a plain-language failure scenario (the concrete situation → what fails → what it costs), fixes name their cost when they add machinery, and the user — not the panel — decides which risks are worth engineering away. Declined findings are recorded in the marker as accepted risks so later laps don't re-raise them. (Canonical: `Milton-Group/harness` → `docs/CONVENTIONS.md` § Findings must earn their complexity.)

- **Tier 1 — Plan.** Decide *what* you're doing and *why* before writing code. For anything non-trivial, run `/plan-review` on the plan — it maps the plan's topics to the right specialist reviewer agents (shipped in `.claude/agents/`, pinned `model: opus`, panel capped at 4) and runs them in parallel, before the plan becomes code. Findings come back scenario-tagged; the user adjudicates which Critical/High findings are worth their fix's cost, the accepted ones get folded in, and the review re-runs until GO (cap 3 laps) — declined findings land in the marker as accepted risks. Skip the planner only when the *what* is unambiguous and the *why* is "the user explicitly asked for it." After GO: convert the plan to Linear issues (a `model: sonnet` agent, consent-gated) so branches and PRs have issue IDs to hang off.
- **Tier 2 — Execute.** When the user says to start, spawn a build agent (`model: opus`, `run_in_background: true`) to implement what was planned, nothing more. Keep the diff scoped to what Tier 1 agreed: no opportunistic refactors, no scope creep. If the work needs something the plan didn't anticipate, stop and re-plan rather than silently expand the diff. If the planning session runs long, `/handoff` carries the context to a fresh session.
- **Tier 3 — Review.** Before commit/PR: run `/milton-review` on the diff. It deterministically spawns the three core lanes (one Opus lane running a review-checklist pass plus its own correctness pass, an independent Fable read of the same diff, a Codex adversarial pass if the plugin is installed) plus conditional specialist lanes when the diff triggers them (security → `Security Engineer`; sprawl → `Minimal Change Engineer` delete-list; reliability → `SRE`), synthesizes by severity and convergence, and returns SHIP / SHIP WITH FIXES / REWORK. On REWORK, the user adjudicates the Critical/High findings the same way; the accepted ones go to a fresh build agent and the review re-runs (cap 3 rounds). Do not push past unresolved blockers — return to Tier 2 (or Tier 1 if the plan itself was wrong).

| Change shape | Process expected |
|---|---|
| Typo, comment edit, single-line tweak | None — ship it |
| Small fix, no design choices | Tier 3 only (`/milton-review`) |
| Multi-file feature work | All three tiers |
| Security-sensitive (auth, secrets, networking, payments, PII) | All three + `Security Engineer` in plan (review picks it up via the trigger table) |
| New service / new repo scaffolding | All three + `Software Architect` in plan |

"Review" means what fits the repo: in app repos it's tests + `/milton-review`; in infra repos it's the plan diff + `/milton-review` plus that repo's apply policy. If unsure, run the planner — a 60-second plan you immediately approve is cheap; un-shipping a bad change is not. (Canonical version of this table: `Milton-Group/harness` → `docs/CONVENTIONS.md` § Quality harness. When they disagree, CONVENTIONS wins and this file gets updated.)

### Commits

- Use [Conventional Commits](https://www.conventionalcommits.org/) prefixes: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `test:`, `perf:`.
- Keep the subject line under 72 characters and focused on the *why*, not the *what* — the diff already shows the what.
- Never commit secrets. Never `git add -A` / `git add .` blindly; stage specific files so you don't sweep in `.env` or credentials.
- Never amend a published commit. If a pre-commit hook fails, fix and create a *new* commit — don't `--amend`, which can destroy prior work.
- Never skip hooks (`--no-verify`, `--no-gpg-sign`) unless the user has explicitly asked for it.

### Branches and PRs

- Branch names should follow `{user}/{linear-id}-{kebab-slug}` — e.g. `thomasliu/milton-91-persist-share-calibration`. Use the issue's `branchName` field from the Linear API verbatim so the GitHub integration can auto-link — it already returns exactly that shape.
- One PR should do one thing. If you find yourself writing "and also" in the description, it's two PRs.
- PR titles are under 70 characters. Details go in the description, not the title.
- Never force-push to `main` or `master`. Never push directly to `main` — always open a PR.
- **Parallel threads in one repo use `git worktree`, not a second clone or a branch switch.** The repo root is the canonical checkout and stays on `main`; every other live thread is a linked worktree at `.worktrees/<branchName>/` (gitignored by the baseline), one `.git`, N checkouts. `/start-issue` creates one automatically whenever the current checkout isn't a clean `main` — or on request — and prints the relaunch line. Each worktree is a full checkout including `.claude/`, so **start the session from the worktree root** (`cd .worktrees/<branchName> && claude`); a session started at the repo root that `cd`s into a worktree does not pick up its skills, hooks or settings. Untracked state (`.env`, `node_modules/`, `.terraform/`) is per-worktree and is not carried over — bootstrap it in the new thread. Two dev servers in two worktrees collide on the default port, so dev scripts honour `PORT` and the second thread sets it. Merged worktrees are cleaned up by the post-merge hook (below).
- **Merged-branch cleanup is automated.** The baseline ships `.githooks/post-merge`: after a `git pull` on a long-lived branch (`main`/`master`/`dev`/`staging`), it deletes local branches proven merged — a merged PR head SHA equal to the local tip, or gone upstream + ancestor of the pulled branch. A branch checked out in a worktree gets the same proof test, and a clean worktree is removed along with it; a worktree holding uncommitted or untracked files is kept and named in the summary. Nothing with possible unpushed commits is ever deleted. Enable once per clone with `git config core.hooksPath .githooks`; bypass a single pull with `MILTON_SKIP_BRANCH_CLEANUP=1`.

### Linear sync

This repo is connected to a Linear project via the native Linear ↔ GitHub integration. The integration handles PR-open → In Review and PR-merge → Done transitions automatically. **Do not duplicate those transitions manually** — it fights the integration and creates double-posts.

Everything else goes through the Linear API. There is deliberately **no Linear MCP server** installed — the context it costs isn't worth it, so don't look for one. `~/.claude/scripts/linear-gql.sh '<graphql>' ['<vars-json>' | @vars.json]` POSTs to `https://api.linear.app/graphql` and prints the raw JSON reply. It reads `LINEAR_API_KEY_MILTON` from the environment; never pass the key as an argument, where it would land in shell history and process listings. Reads (issue lookup, workflow states, what's assigned to whom) need no ceremony — query freely. Writes touch shared state, so they stay consent-gated per **Ask before taking risky actions** above. The three that come up:

```sh
# State transition — get stateId from the team's workflowStates, don't guess it
linear-gql.sh 'mutation($id:String!,$state:String!){issueUpdate(id:$id,input:{stateId:$state}){success}}' '{"id":"MILTON-91","state":"<state-uuid>"}'

# Comment
linear-gql.sh 'mutation($id:String!,$body:String!){commentCreate(input:{issueId:$id,body:$body}){success}}' @vars.json

# New issue — the reply carries branchName, so the branch to create comes back with the ID
linear-gql.sh 'mutation($i:IssueCreateInput!){issueCreate(input:$i){issue{identifier branchName url}}}' @vars.json
```

Any multi-line body — an issue description, a comment that isn't one line — **must** use the `@vars.json` file form. Inline JSON quoting breaks on Markdown: backticks, newlines, and quotes are mangled by the shell before `jq` ever builds the payload.

- When the user agrees to work on an issue, move it to **In Progress** and announce the transition (`Moved MILTON-91 to In Progress.`).
- After each commit whose branch or message references an issue, post a one-line Linear comment: `{sha-short} — {commit subject}`. No narrative.
- Don't comment on Linear with summaries of what you're about to do. Linear comments are for concrete facts.
- If you spot a discrepancy (branch references a closed issue, assignee mismatch, open blockers), pause and ask — don't auto-resolve.

### Testing and verification

- For UI or frontend changes, start the dev server and exercise the feature in a browser before claiming the task is done. Type checks and unit tests verify code correctness, not feature correctness.
- If you can't test the UI (no dev server, no browser), say so explicitly. Don't claim success on the basis of "it compiles."
- For backend changes, run the relevant test suite and the type checker before reporting done.

### Dev server links

When you start a dev server (or anything else listening on a port) inside a Coder workspace — detectable by `$CODER_WORKSPACE_NAME` being set — print the URL every way the user can reach it, not just `localhost`:

- **Local:** `http://localhost:<port>` — works inside the workspace and through a manual port-forward.
- **Coder Connect:** `http://$CODER_WORKSPACE_AGENT_NAME.$CODER_WORKSPACE_NAME.$CODER_WORKSPACE_OWNER_NAME.coder:<port>` — opens directly from a laptop running Coder Desktop with Coder Connect enabled, no port-forward needed.
- **Browser (no Coder Desktop):** `$VSCODE_PROXY_URI` with `{{port}}` replaced by the port — the dashboard wildcard URL, for anyone working through coder.milton.co in a browser.

Expand the variables to their real values before printing — the user needs clickable links, not shell expressions. On a machine that isn't a Coder workspace (no `$CODER_WORKSPACE_NAME`), print only the `localhost` link.

### Code style

- **Default to writing no comments.** Only add a comment when the *why* is non-obvious — a hidden constraint, a workaround for a specific bug, behavior that would surprise a reader. Don't narrate *what* the code does; named identifiers do that.
- **No references to the current task in code.** Don't write `// fixes MILTON-91` or `// added for the onboarding flow`. That context belongs in the PR description and rots as the code evolves.
- **Don't leave dead code or "removed X" comments.** If something is unused, delete it.
- **No emojis in code or commits** unless explicitly asked.

### When in doubt

Ask. A 10-second clarifying question beats 20 minutes of rework. The user can always redirect — they can't un-push a bad commit.
