---
status: accepted
---

# Two text functions mirroring `textContent` / `innerText`, not one mode option

## Context

`HTMLText` (through v1.0.2) concatenates a tree's descendant strings verbatim:
lossless, no whitespace collapse, no block breaks, `<br>` ignored. Callers
almost always then normalize it (the recurring `norm`/`plain` boilerplate),
which raised the question of whether "readable" text should be the default or an
option on a single function.

## Decision

Ship **two** functions, not one function with a whitespace mode:

- **`HTMLTextContent`** — the raw, lossless tree-fold (a rename of `HTMLText`).
- **`HTMLInnerText`** — readable text: collapses whitespace, breaks block-level
  tags onto their own lines, maps `<br>` → newline, preserves `<pre>` verbatim,
  drops non-rendered tags (`script`, `style`, …), and trims the result.

`HTMLText` is renamed to `HTMLTextContent` cleanly (no alias). The names and the
split are inherited from the web platform's two long-standing answers to "what
is the text of this HTML?": DOM `textContent` (a `Node` tree-fold) and
`innerText` (an `HTMLElement` rendering projection).

`HTMLInnerText` classifies each element **by tag alone** into one of five roles
(`Block`, `Inline`, `Preformatted`, `LineBreak`, `Skip`) using a frozen
transcription of the WHATWG HTML §15 default user-agent stylesheet. It never
reads CSS — not classes, not `<style>`, not even inline `style=`. Users override
the classification with the `"Roles"` option: an ordered list of
`XMLPattern -> role` rules (bare string sugars to `XMLPattern[string]`), tried
first-match-wins, falling back to the frozen table, with unmatched tags
defaulting to `Inline`. Block boundaries are joined by the `"BlockSeparator"`
option (default `"\n"`).

## Considered options

- **One function, `"Whitespace" -> "Collapse" | "Trim" | "Preserve"` (Option A).**
  Rejected: the two behaviors have *conflicting defaults*. The raw primitive's
  honest default is lossless; the readable function's whole value is that
  normalization is the default (killing the `plain` boilerplate). One symbol
  cannot satisfy both, and the readable function's option surface (`"Roles"`,
  `"BlockSeparator"`) is inert in raw mode — half-dead options on a primitive.
- **A `Function[el, …]` classifier override.** Rejected: a pattern LHS plus
  `RuleDelayed`/`Condition`/`PatternTest` subsumes it declaratively, reusing the
  paclet's own `XMLPattern`/`CSSClass` machinery — no second DSL.
- **CSS-style specificity for rule conflicts.** Rejected: reimplements the
  cascade we are explicitly avoiding. First-match-by-order is predictable and is
  the language's own `Replace` convention.
- **Honoring inline `style=`.** Rejected: we can see inline `display:none` but
  not the class-based equivalent, so honoring it makes behavior hinge on an
  invisible authoring accident. Tags-only is predictable.

## Consequences

- `HTMLInnerText` approximates `innerText`'s *non-rendered* fallback regime
  permanently (no layout engine), so it reproduces HTML-under-default-UA-styles,
  not this-page-as-rendered. A page that restyles a tag's `display` will not
  move it. Docs must say so plainly.
- `HTMLText` callers must migrate to `HTMLTextContent` (cheap at v1.0.2; the only
  in-repo caller is `html-to-markdown.wls`).
- `HTMLTextContent` also gains the bug fix that `HTMLText` silently returned `""`
  for a whole `XMLObject["Document"]`, plus a bad-argument message — aligning its
  input contract with `XMLCases`/`XMLFirstCase`.
- Paragraph-aware spacing (mixed per-tag break counts), true CSS-cascade hiding,
  and `ToMarkdown` are explicitly *out of scope* and left to a future structural
  transform, which would share this block/`<pre>` classification.
