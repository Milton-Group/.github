# Design system

> STATUS: placeholder

Remove the line above when the content below is real. While it is present, `/brand-review` reports
this axis as unpopulated instead of reviewing against it. See `README.md` in this directory for how
to write a rule an agent can apply.

---

## Colour

<!-- State colour as SEMANTIC ROLES, not a swatch list. A reviewer needs to catch "accent used for a
     destructive action", which requires knowing what each colour MEANS. Give the hex alongside the
     role, and give the contrast facts — those are the checkable part. -->

| Role | Value | Use for | Never use for |
|---|---|---|---|
| _TODO_ | _TODO_ | _TODO_ | _TODO_ |

### Contrast facts

<!-- The measured pairs that pass and fail. This is what makes an accessibility finding concrete
     rather than speculative. e.g. "ink on accent = 8.1:1 (AA, AAA for large); white on accent =
     2.8:1 (FAILS) — never white on accent." -->

_TODO_

### Light and dark

<!-- Whether both are supported, and how roles remap. If a role inverts, say so — an agent cannot
     infer it. -->

_TODO_

## Typography

<!-- Families with their fallback stacks, the scale with actual sizes and line-heights, and which
     weights are legitimate. Name the sizes so findings can cite them. -->

| Step | Size / line-height | Weight | Use for |
|---|---|---|---|
| _TODO_ | _TODO_ | _TODO_ | _TODO_ |

## Spacing and layout

<!-- The spacing scale and the rule for choosing a step. Max content width. Grid or breakpoints if
     they are prescriptive. -->

_TODO_

## Components

<!-- Per component, the conventions a reviewer should enforce: which variants exist, when each is
     correct, and the states that must be handled (hover, focus, disabled, loading, error, empty).
     Missing states are the most common real finding here. -->

_TODO_

## Accessibility floor

<!-- The non-negotiables. Target level (e.g. WCAG 2.2 AA), contrast minimums, focus-visible
     requirements, hit-target size, motion-reduction handling, what must never convey meaning by
     colour alone. `/brand-review` treats a breach of this section as blocking, so put here only what
     genuinely should block. -->

_TODO_

## Anti-patterns

<!-- Specific things that keep happening and are always wrong. Concrete beats abstract: "drop shadows
     on flat surfaces", "centre-aligned body text", "icon-only buttons with no accessible name". -->

_TODO_

## Judgement calls

<!-- Where the system deliberately leaves room, and what to weigh. -->

_TODO_
