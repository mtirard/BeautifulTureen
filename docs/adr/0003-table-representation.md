# `<table>` maps to `Dataset`/`Grid`, not `Tabular`, and never loses data silently

`HTMLToNotebook` renders `<table>` as a **`Dataset`** when a `<thead>` (or a leading all-`<th>` row) supplies **unique** column labels and at least one body row follows it — giving an idiomatic GFM header row — and as a **`Grid`** otherwise (positional, blank GFM header, every row preserved as body). The choice is driven by two facts established empirically against the WL `"Markdown"` exporter.

**Why not `Tabular`** (the newer, semantically-truer table type): the paclet floor is `WolframVersion -> "12.3+"` and `Tabular` is 14.1+. Emitting `Tabular` would put an undefined symbol in the returned `Notebook[…]` on 12.3–14.0 kernels, breaking the notebook-as-primitive use (display/PDF) even though it would be fine for a 14+ user exporting to Markdown. `Dataset` (11+) and `Grid` keep the notebook well-formed everywhere ≥12.3 and export to identical GFM.

**Why the no-silent-loss header rule:** the exporter derives the GFM header row solely from the table's _column names_, and column names come from association keys, which are necessarily unique. So named-column constructs give a header but silently **collapse duplicate header labels into one column** — real data loss. Positional constructs (matrix → `Grid`) never lose data but have a blank header. There is no construct that does both. We default to the lossless representation and promote to a real header only when it is faithful (unique labels), rather than dropping a column for prettiness.

A header row with no body rows is not promoted either. A `Dataset` of zero rows has no column names to show, so the header text is lost from the notebook, and the `"Markdown"` exporter fails on it. The `Grid` keeps the header row as bold data.

The no-silent-loss rule also covers the `<caption>`. A GFM table has no caption, so dropping it would lose its text without a trace. Instead, in both forms, a caption becomes a `"Text"` cell immediately before the table's cell. Its content is converted as a paragraph's is, keeping formatting and links, and it exports as a line of its own above the table. A table without a caption is still a single cell.

Both forms sit in an `"Output"` cell. A `Dataset` brings its own look; the `Grid` is given one that reads as a document table rather than as an evaluation result: framed (`Frame -> All`), left-aligned, in the `"Text"` base style, with its strings shown as written (no quotes, operator glyphs or syntax colouring). A `<th>` cell in the `Grid` form is bold, so it exports as `**…**`; in the `Dataset` form the `<th>` row is the header and stays plain.

## Considered options

- **Always honor `<th>` as the header (named construct)** — rejected: silently drops a column when two header labels coincide. Losing data is a worse cost than a blank header row.
- **A dedicated `"TableRepresentation"` option** — rejected: the general `"Constructs"` rule already accepts a constructor-function RHS, so a user who wants `Tabular`, always-pretty, or a bespoke layout writes one rule (`XMLPattern["table"] :> fn`). No per-feature knob is warranted.

## Consequences

`colspan`/`rowspan`, nested tables, and block content inside a `<td>` have no faithful GFM target and degrade (cells survive as best GFM allows). The `<table>` default is itself a built-in constructor-function construct rule, so it is overridable like anything else.
