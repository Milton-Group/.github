---
description: Stage, commit, push, and open a PR for the current branch.
---

Ship the current branch.

Steps:

1. Run `git status` and `git diff` in parallel to see what's staged and unstaged.
2. Run `git log main..HEAD --oneline` to see commits already on this branch.
3. Draft a PR title under 70 characters and a short description. The description should focus on the *why*, not a line-by-line *what*. Include a short test plan.
4. Stage only the files that belong in this PR — never `git add -A` blindly. Flag any `.env`, credentials, or large binaries and stop if you find them.
5. Commit using Conventional Commits (`feat:`, `fix:`, `chore:`, etc.). Never pass `--no-verify`. If a pre-commit hook fails, fix the underlying issue and create a new commit — do not amend.
6. Show the user the proposed PR title and description. **Wait for approval** before pushing.
7. After approval: push the branch and open the PR with `gh pr create`. Return the PR URL.
8. The Linear ↔ GitHub integration will move the issue to **In Review** automatically — do not touch the issue state manually.

If the branch has no Linear issue reference in its name, ask the user whether to proceed anyway or stop to create an issue first.
