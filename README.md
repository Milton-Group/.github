# Milton-Group/.github

This directory stages the contents of the `Milton-Group/.github` repo. GitHub routes this repo's `profile/README.md` to the organization's public profile page at [github.com/Milton-Group](https://github.com/Milton-Group), and the `.github/workflows/` directory hosts **reusable workflows** callable from any repo in the org via `workflow_call`.

## Contents

- `profile/README.md` — org landing page
- `CODEOWNERS` — org-level default ownership
- `SECURITY.md` — vulnerability disclosure intake
- `.github/workflows/node-ci.yml` — reusable Node CI (lint + typecheck + test). Tagged `v1`.

## Consumer pattern

Any Milton-Group repo adopts CI by creating `.github/workflows/ci.yml` in its own repo:

```yaml
name: CI
on:
  pull_request:
    branches: [dev, staging, main]
  push:
    branches: [dev, staging, main]

jobs:
  ci:
    uses: Milton-Group/.github/.github/workflows/node-ci.yml@v1
    with:
      node-version: "22"
```

The consumer owns the `on:` triggers; the reusable workflow owns the job logic. Updates to job logic propagate by retagging `@v1` (non-breaking) or cutting `@v2` (breaking, consumer opts in via PR).

The repeated `.github` path (`.github/.github/workflows/`) is GitHub's convention for this repo type. Not a typo.

## Cuts from v2 draft

Python CI workflow and Docker build workflow are deferred to v4 — see `../deferred/` for rationale. V1 ships one working Node workflow end-to-end rather than three half-working ones.
