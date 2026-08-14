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
3. Verify we're on a clean working tree. If not, stop and ask the user what to do with the pending changes.
4. Create a new branch using the issue's `branchName` field verbatim (e.g. `thomasliu/milton-91-persist-share-calibration`) — it already returns the prescribed `{user}/{linear-id}-{kebab-slug}` shape. Do NOT invent a branch name; use the one Linear generated so the GitHub integration can auto-link.
5. Move the issue to **In Progress**. Resolve the state id from the team's `workflowStates` rather than guessing it, then update:

   ```sh
   linear-gql.sh 'mutation($id:String!,$state:String!){issueUpdate(id:$id,input:{stateId:$state}){success}}' \
     '{"id":"MILTON-91","state":"<state-uuid>"}'
   ```

6. Announce the transition in one line: `Moved MILTON-91 to In Progress on branch {branch-name}.`

Do not start editing code yet — wait for the user's next instruction about what to do on the issue.
