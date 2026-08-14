# AGENTS.md

Instructions for Codex when working in this repository.

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

> Maintained in `claude-template`. Last synced: 2026-08-14 (v0.17.0)

This section is authored for Codex. It is **not** a substitution pass over the Claude-facing `CLAUDE.md` — where the two files differ on harness mechanics, each is correct for its own runtime. Where they differ on *policy* (commits, branches, Linear, safety), they are meant to agree, and `docs/CONVENTIONS.md` in `claude-template` is canonical for both.

### Your two modes

You run in this repo in one of two modes. Work out which one you are in *before* you start, because they differ in scope, not just in tone.

**Mode 1 — Primary (this is the default).** A human ran `codex` from the CLI and is talking to you directly. You are the whole harness: plan, build, verify, report, ask when unsure. Everything in this baseline applies to you as written. The repo's own skills and subagents are yours to use (see the table below). Assume this mode unless something in your prompt says otherwise.

**Mode 2 — Reviewer (only when your prompt explicitly says so).** Another agent — usually Claude Code running a review lane — handed you a diff, a scope preamble, and an output contract. The downgrade is always explicit: a stated role, a required output format, often a "do not write files" clause. In that mode:

- **One pass, no fan-out.** Deliver the single review you were asked for. Don't spawn subagents, don't start a multi-lane harness, don't expand into work adjacent to the diff. The caller is already running the other lanes; duplicating them is waste, and agreeing with yourself is not convergence.
- **Read whatever the diff touches — all of it.** Reviewer mode is the one job that legitimately reaches across every tree in the repo, `.claude/` included. If the diff changes `.claude/skills/**`, reading those files *is* the review. Don't refuse to look at something because it belongs to another agent's harness.
- **Respect the output contract literally.** Return the format you were asked for and nothing else. No marker files, no commits, no branch creation, and no writes at all unless the prompt explicitly grants them.
- **Stay in scope on findings.** Report what's wrong with the diff. Don't file findings about the repo's general state, and don't fix what you find — the caller decides.

Never self-promote from Mode 2 to Mode 1, and never self-demote from Mode 1 to Mode 2. A human who typed `codex` gets a full agent; a caller who handed you a contract gets exactly that contract.

### Your harness

This repo carries harness trees for more than one agent. Yours are:

| Surface | Location | Notes |
|---|---|---|
| Instructions | `AGENTS.md` (this file) | Read every session |
| Skills | `.agents/skills/<name>/SKILL.md` | Repo-local; also `~/.agents/skills/` for personal ones |
| Subagents | `.codex/agents/*.toml` | Repo-local; also `$CODEX_HOME/agents/` |
| Hooks | `.codex/hooks.json` + `.codex/hooks/` | Enforced by the runtime, not by you |

**`.claude/` is Claude Code's tree, not yours** — subagents as `.md` with YAML frontmatter, skills that assume Claude's tool names and `model:` pins. Read it freely; in Mode 2 you may have to. But in **both** modes:

- **Never execute `.claude/skills/**` as a workflow.** Those files name Claude models (`opus`, `fable`, `sonnet`) and Claude tools. Following them makes you improvise a runtime you don't have. Reading such a file to understand or review it is fine — treating its steps as your instructions is not. If a `.claude/` skill describes something genuinely useful, say so and let a human decide.
- **Never write anything under `.claude/`.** Not markers, not settings, not fixes — unless the diff you were asked to *author* is itself a change to that tree, which only happens in Mode 1 and only when the user asked for it. Otherwise: that tree is maintained by `bootstrap.sh` from the `claude-template` baseline, so stray local edits get reverted and are invisible to review.
- **Ignore `model:` pins wherever you find them.** You do not select models by name. A pin is an instruction to a different runtime; it is not a task for you. Reviewing whether a pin is *correct* is still fair game in Mode 2.

### Working style

- **Ask before taking risky actions.** Anything that touches shared state (pushing code, creating PRs, sending Feishu/Linear messages, deleting branches, dropping tables, `rm -rf`) should be confirmed before execution unless the user has already authorized it for this session. Local, reversible edits don't need confirmation.
- **Don't bypass safety checks to unblock yourself.** `--no-verify`, `--force`, and `reset --hard` are not shortcuts around failing hooks — they're signals to stop and diagnose. If a pre-commit hook is failing, fix the underlying issue.
- **Match scope to the request.** A bug fix doesn't need a refactor. A one-shot script doesn't need a helper library. Don't introduce abstractions or backwards-compatibility shims for scenarios that aren't real yet. Feature flags follow the same rule with one deliberate exception: a flag that lets **real, in-progress** work merge to `main` behind an off switch is the org's release mechanism, not speculation (`docs/CONVENTIONS.md` § Git & branching). A flag guarding a hypothetical is still scope creep, and a flag whose rollout is finished is dead code — delete it.
- **Report what actually happened.** If tests fail, say so and paste the output. If you skipped a step, say which. Don't upgrade "it compiles" into "it works."

### Memory — what to save during a session

Project memory should capture operational facts that an outside observer could not recover from the repository or its diff. Save these facts when you discover or change them:

- **Credential lifetimes** — when a token, certificate, or secret was created, when it expires, and where it is stored. Never save the secret value itself.
- **Live or manual changes** — edits to a running system, admin console, or other external state that are not yet durable in code, including any rollback or follow-up needed.
- **External-state surfaces** — settings and third-party configuration where drift can affect the project.
- **Lifecycle events** — resources or environments that were created, applied, paused, archived, migrated, or retired.
- **Decisions with non-obvious rationale** — what was chosen and why, especially when the repository records the outcome but not the tradeoff.

Update or replace the memory when the fact changes so stale operational state does not become guidance.

### Plan → Execute → Review (the quality harness)

Non-trivial changes go through three explicit phases. The phases matter more than the tooling — but every non-trivial change should *visibly* go through all three. Trivial edits (typo, comment fix, single-line tweak) skip the process.

- **Tier 1 — Plan.** Decide *what* you're doing and *why* before writing code. State the plan in the channel and get agreement before it becomes code. Skip planning only when the *what* is unambiguous and the *why* is "the user explicitly asked for it." Once agreed, file the Linear issues (see **Linear sync**) so branches and PRs have IDs to hang off.
- **Tier 2 — Execute.** Implement what was planned, nothing more. No opportunistic refactors, no scope creep. If the work needs something the plan didn't anticipate, stop and re-plan rather than silently expanding the diff.
- **Tier 3 — Review.** Before commit/PR, review the diff against the change-shape table below and run whatever the repo's own verify step is (`scripts/verify.sh` where one exists, otherwise tests + type check + lint). Do not push past an unresolved blocker — go back to Tier 2, or Tier 1 if the plan itself was wrong.

| Change shape | Process expected |
|---|---|
| Typo, comment edit, single-line tweak | None — ship it |
| Small fix, no design choices | Tier 3 only |
| Multi-file feature work | All three tiers |
| Security-sensitive (auth, secrets, networking, payments, PII) | All three, with an explicit security pass over the diff |
| New service / new repo scaffolding | All three, with an explicit architecture pass on the plan |

**Findings must earn their complexity.** This binds you in both modes — reviews you run as the primary agent and reviews you deliver as a lane in someone else's harness. Attach a plain-language failure scenario to every Critical or High finding: the concrete situation that triggers it → what fails → what it costs. A risk you cannot attach a concrete scenario to is an open question or Medium at most, and does not block a verdict. When a fix you propose adds machinery — a queue, a table, a dependency, an abstraction, a config surface — say so in one line: the human weighs the risk against the engineering, and a risk they decline to engineer away is their decision, settled unless new information arrives. A clean pass with few or no findings is a successful review; do not manufacture findings to justify the pass. (Canonical: `docs/CONVENTIONS.md` § Findings must earn their complexity.)

**On review depth.** This repo may carry multi-lane review skills under `.agents/skills/` (`plan-review`, `milton-review` and kin). They are real and, in **Mode 1**, they are yours to run — but they are **expensive**, and they are opt-in. Run one when the user asks for it by name, or when you have proposed it and they agreed. Do **not** fan out into a review harness because the task text happened to resemble a review request; a scoped task deserves a scoped answer. If you think a change warrants the full harness, say so in one line and wait. In **Mode 2**, never start one — you *are* a lane in someone else's harness.

"Review" means what fits the repo: in app repos it's tests plus a read of the diff; in infra repos it's the plan diff plus that repo's apply policy. If unsure, plan first — a 60-second plan you immediately approve is cheap; un-shipping a bad change is not. (Canonical version of this table: `claude-template` → `docs/CONVENTIONS.md` § Quality harness. When they disagree, CONVENTIONS wins and this file gets updated.)

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
- **Merged-branch cleanup is automated.** The baseline ships `.githooks/post-merge`: after a `git pull` on a long-lived branch (`main`/`master`/`dev`/`staging`), it deletes local branches proven merged — a merged PR head SHA equal to the local tip, or gone upstream + ancestor of the pulled branch. It never touches worktree-checked-out branches or anything with possible unpushed commits. Enable once per clone with `git config core.hooksPath .githooks`; bypass a single pull with `MILTON_SKIP_BRANCH_CLEANUP=1`.

### Linear sync

This repo is connected to a Linear project via the native Linear ↔ GitHub integration. The integration handles PR-open → In Review and PR-merge → Done transitions automatically. **Do not duplicate those transitions manually** — it fights the integration and creates double-posts.

Everything else goes through the Linear API over plain HTTP. There is deliberately **no Linear MCP server** — don't look for one, and don't treat its absence as a missing capability. `~/.claude/scripts/linear-gql.sh '<graphql>' ['<vars-json>' | @vars.json]` POSTs to `https://api.linear.app/graphql` and prints the raw JSON reply; it is shared shell tooling, not a Claude-only tool, and the path is stable regardless of which agent invokes it. It reads `LINEAR_API_KEY_MILTON` from the environment; never pass the key as an argument, where it would land in shell history and process listings. Reads (issue lookup, workflow states, what's assigned to whom) need no ceremony — query freely. Writes touch shared state, so they stay consent-gated per **Ask before taking risky actions** above. The three that come up:

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
