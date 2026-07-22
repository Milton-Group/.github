---
description: Start work on a Linear issue — move it to In Progress and create a properly-named branch.
---

Start work on Linear issue `$ARGUMENTS` (e.g. `MILTON-91`).

Steps:

1. Fetch the issue from the Linear MCP to confirm it exists, read its title and description, and check that it's assigned to the current user and not already Done / Cancelled.
2. If the issue has open `blockedBy` issues, stop and ask the user whether they want to tackle those first.
3. Verify we're on a clean working tree. If not, stop and ask the user what to do with the pending changes.
4. Create a new branch using the issue's `gitBranchName` field verbatim (e.g. `thomasliu/milton-91-persist-share-calibration`). Do NOT invent a branch name — use the one Linear generated so the GitHub integration can auto-link.
5. Move the issue to **In Progress** via the Linear MCP.
6. Announce the transition in one line: `Moved MILTON-91 to In Progress on branch {branch-name}.`

Do not start editing code yet — wait for the user's next instruction about what to do on the issue.
