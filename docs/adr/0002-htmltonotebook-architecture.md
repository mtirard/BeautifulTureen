# `HTMLToNotebook` is a cell-emitter sibling of `HTMLInnerText`, not a wrapper

`HTMLToNotebook` converts an HTML/XML tree into a `Notebook[…]` expression;
Markdown, PDF, RTF, and display all fall out downstream via `Export`, so we
never emit those formats ourselves. We chose the notebook as the primitive
(rather than a direct `…ToMarkdown` string emitter) because the Cell tree is the
common ancestor of every one of those outputs — a thin `…ToMarkdown` convenience
can sit on top later, but the reverse coupling would strand PDF/RTF/display.

The conversion is built as **two layers over a substrate shared with
`HTMLInnerText`**, not as a wrapper around it:

- **Layer 1 — display role** (`Block`/`Inline`/`Preformatted`/`LineBreak`/`Skip`):
  the structural skeleton — does an element start a cell, flow inline, preserve
  whitespace, break, or prune? This is exactly the classification +
  tree-walk + inline-run buffering + whitespace policy that `HTMLInnerText`
  already needs, so it is factored into a private substrate that both functions
  share.
- **Layer 2 — construct map**: given the role's placement, the concrete form —
  which cell-style string for a block, which inline box for an inline. This
  layer is `HTMLToNotebook`-only. The role gates placement and wins on conflict;
  the construct supplies the form.

## Considered options

- **`HTMLToNotebook` consumes `HTMLInnerText`'s output** — rejected. That output
  is a *string*; it has already discarded the inline structure (`<b>`→`StyleBox`,
  `<a>`→`ButtonBox`, `<code>`→framed `StyleBox`) that the notebook must preserve.
  The notebook path is strictly richer, so it cannot be a post-process of the
  text path.
- **A single combined classifier instead of two layers** — rejected. The five
  display roles are too coarse for cells (`<h1>`, `<p>`, `<ul>`, `<blockquote>`
  are all `Block`; `<b>`, `<a>`, `<code>`, `<span>` are all `Inline`). Splitting
  "skeleton" from "form" lets Layer 1 stay shared and battle-tested while Layer 2
  is a pure lookup that never re-derives block-vs-inline. It also gives users two
  orthogonal override knobs — `"Roles"` (skeleton) and `"Constructs"` (form).

## Consequences

The first implementation step is to extract the classification / walk / buffer
substrate out of `HTMLInnerText` (still inline in its section as of this
writing) into a reusable private piece, then build both functions as emitters
over it. Block nesting is represented only through cell-style names (list depth
via `Subitem`/`Subsubitem`), since a `Notebook` is a flat cell sequence;
`<blockquote>`/`<pre>`/`<table>` are leaf-collapsing exceptions that do not
recurse into separate cells.
