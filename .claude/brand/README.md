# `.claude/brand/` — the brand system, as data

This directory is the Milton brand system in machine-readable form. Agents read it; they do not
carry it. Anything here is a **fact about the brand** that a reviewer should hold you to.

It is a baseline artifact class, so **every repo in the fleet receives this directory** and every
repo receives the same content. That uniformity is the point — a brand that differs per repo is not
a brand.

## Who owns this

**Design owns the content. Engineering owns the plumbing.**

You do not need to understand skills, agents, or the sync engine to work here. Write the rules in
these Markdown files and the review skills pick them up on the next sync. If you find yourself
needing to change how a file is *read*, that is a plumbing change — open an issue rather than
editing a skill.

## What goes here

| File | Holds |
|---|---|
| `voice.md` | How Milton sounds. Tone, register, vocabulary, worked before/after rewrites, phrasings that are off-limits. |
| `design-system.md` | How Milton looks. Semantic colour roles, type scale, spacing, component conventions, the accessibility floor. |

Add a file when a genuinely new axis of the brand needs stating (say `motion.md`, or
`photography.md`). Keep one axis per file — the review skills cite the file a finding came from, and
a grab-bag file produces uncitable findings.

## What does *not* go here

- **Repo-specific or product-specific rules.** This directory is fleet-wide and identical
  everywhere. A rule that applies to one product is not a brand rule.
- **Raw design-tool exports.** Figma dumps, full token JSON, generated palettes. State the *rule* a
  reviewer must apply, not the artifact it was derived from.
- **Anything secret.** This syncs into every repo, including public ones. Treat it as published.
- **Rationale essays.** A short *why* is useful when it changes how a rule is applied. A page of
  brand philosophy is not something an agent can check a button against.

## How to write a rule an agent can actually apply

The review skills are only as good as the specificity here. Prefer rules that are **checkable**:

- Bad: "Our tone is confident but approachable."
- Good: "Never hedge a factual claim with *we believe* or *we think* — state it, or cite it.
  Contractions are correct in product copy; avoid them in legal and security notices."

- Bad: "Use adequate contrast."
- Good: "Body text meets WCAG 2.2 AA (4.5:1). Text on the accent colour must be the dark ink, never
  white — white on accent measures 2.8:1 and fails."

Where a rule genuinely is a judgement call, say so explicitly and say what to weigh. A reviewer told
"this is a judgement call, weigh X against Y" gives a useful finding; a reviewer told "be tasteful"
invents rules.

## Placeholder state

`voice.md` and `design-system.md` ship as **scaffolds**. Until they are filled in, they carry a
`> STATUS: placeholder` line near the top.

`/brand-review` checks for that marker and **refuses to review against a placeholder file** — it
reports the file as unpopulated instead of inventing rules from the section headings. So a
half-finished brand system degrades to "I can't check that axis yet", never to a confident review
against rules nobody wrote.

Remove the `> STATUS: placeholder` line when a file's content is real. That line is the only signal
the skill uses; there is no separate registry to update.

## How this reaches repos

`bootstrap.sh` copies each file if the destination is missing, and on `--upgrade` replaces it if the
repo's copy is byte-pristine for a known baseline version. A repo that **edits** a file here has
diverged it, and that file then stops receiving updates — deliberately, so local edits are never
silently clobbered. Since brand content is meant to be uniform, a diverged brand file is usually a
mistake worth chasing rather than a customization worth keeping.

Changes here are engine-written from oracle-verified content, so the fleet sweep treats this
directory as an auto-merge class alongside `agents/`, `commands/` and `skills/`.
