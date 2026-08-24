---
description: Start work on a Linear issue — move it to In Progress and create a properly-named branch.
---

Start work on Linear issue `$ARGUMENTS` (e.g. `MILTON-91`).

Linear goes over HTTP, not MCP — see CLAUDE.md § "Linear sync" for the helper, the
`LINEAR_API_KEY_MILTON` handling, and the `@vars.json` rule.

Steps:

1. Fetch the issue to confirm it exists, read its title and description, and check that it's assigned to the current user and not already Done / Cancelled. One query covers the whole step, including step 2's blockers:

   ```sh
   linear-gql.sh 'query($id:String!){issue(id:$id){identifier title description branchName
     state{name type} assignee{email}
     inverseRelations{nodes{type relatedIssue{identifier title state{name type}}}}}}' \
     '{"id":"MILTON-91"}'
   ```

2. Filter `inverseRelations.nodes` to `type == "blocks"` yourself — the field takes no filter argument. If any such `relatedIssue` is still open (`state.type` is neither `completed` nor `canceled`), stop and ask the user whether they want to tackle those first.
3. Decide **branch in place** or **worktree**. The branch name is the issue's `branchName` field verbatim (e.g. `thomasliu/milton-91-persist-share-calibration`) — it already returns the prescribed `{user}/{linear-id}-{kebab-slug}` shape. Do NOT invent a branch name; use the one Linear generated so the GitHub integration can auto-link. Then:
   - **Branch in place** when this checkout is on the default branch (`main`, or whatever `git symbolic-ref --short refs/remotes/origin/HEAD` names) with a clean working tree, and the user hasn't asked for a worktree: `git fetch origin && git switch -c <branchName> origin/<default>`.
   - **Worktree** when this checkout is on any other branch, when the tree is dirty, or when the user asked for one (`/start-issue MILTON-91 --worktree`, or "in a worktree"). Another thread is live here; don't stash or switch under it. Create a sibling checkout instead — the house layout is `.worktrees/<branchName>/` under the repo root, which is gitignored by the baseline:

     ```sh
     REPO_ROOT=$(git rev-parse --path-format=absolute --git-common-dir | sed 's|/\.git$||')
     git fetch origin
     git worktree add -b <branchName> "$REPO_ROOT/.worktrees/<branchName>" origin/<default>
     ```

     `--git-common-dir` resolves to the canonical checkout even when `/start-issue` is itself run from inside a worktree, so threads never nest. If `.worktrees/<branchName>` already exists, it is this issue's thread from an earlier session — reuse it, don't recreate it. If the branch already exists locally but has no worktree (the issue was started in place earlier and the checkout has since returned to `main`), `-b` fails — check it out instead: `git worktree add "$REPO_ROOT/.worktrees/<branchName>" <branchName>`.
   - A dirty tree on a non-default branch is **not** a reason to stop and ask any more; it's the worktree signal. Only stop if the tree is dirty *on the default branch* — that's uncommitted work with no thread to belong to, and the user decides what happens to it.
4. If a worktree was created, a new Claude session has to start from its root — skills, agents, hooks and settings under `.claude/` register only from the directory a session is *started* in, so `cd`-ing there from this session would run the new thread unguarded. Finish steps 5–6 here, then print exactly:

   > Type `/exit`, then paste:
   > ```
   > cd <repo-root>/.worktrees/<branchName> && claude
   > ```

   with `<repo-root>` expanded to the real path. Untracked state (`.env`, `node_modules/`, `.terraform/`) is per-worktree and does **not** carry over — say so in the same message if the repo needs any of it, so the new session knows to bootstrap. If two threads will each run a dev server, they collide on the default port; start the second with `PORT=<other>` (repo dev scripts should honour it).
5. Move the issue to **In Progress**. Resolve the state id from the team's `workflowStates` rather than guessing it, then update:

   ```sh
   linear-gql.sh 'mutation($id:String!,$state:String!){issueUpdate(id:$id,input:{stateId:$state}){success}}' \
     '{"id":"MILTON-91","state":"<state-uuid>"}'
   ```

6. Announce the transition in one line: `Moved MILTON-91 to In Progress on branch {branch-name}.` — append ` (worktree: .worktrees/{branch-name})` when one was created.

Do not start editing code yet — wait for the user's next instruction about what to do on the issue.
