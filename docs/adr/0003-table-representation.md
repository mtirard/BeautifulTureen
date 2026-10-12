# `<table>` maps to `Dataset`/`Grid`, not `Tabular`, and never loses data silently

`HTMLToNotebook` renders `<table>` as a **`Dataset`** when a header row supplies **unique** column labels, at least one body row follows it, and no body row is wider than it — giving an idiomatic GFM header row — and as a **`Grid`** otherwise (positional, blank GFM header, every row preserved as body). The choice is driven by two facts established empirically against the WL `"Markdown"` exporter.

A table's rows are the `<tr>` elements that are its children or children of its own `<thead>`, `<tbody>` or `<tfoot>`; the rows of a nested table are not. A row with no `<th>` or `<td>` cells is ignored. The header row is the one row of a `<thead>`, whatever its cells are; with no `<thead>`, or none with a row that has cells, it is a leading row made only of `<th>` cells. A `<thead>` with more than one row gives no header row, since a `Dataset` has one row of column names and the others would be lost.

**Why not `Tabular`** (the newer, semantically-truer table type): the paclet floor is `WolframVersion -> "12.3+"` and `Tabular` is 14.1+. Emitting `Tabular` would put an undefined symbol in the returned `Notebook[…]` on 12.3–14.0 kernels, breaking the notebook-as-primitive use (display/PDF) even though it would be fine for a 14+ user exporting to Markdown. `Dataset` (11+) and `Grid` keep the notebook well-formed everywhere ≥12.3 and export to identical GFM.

**Why the no-silent-loss header rule:** the exporter derives the GFM header row solely from the table's _column names_, and column names come from association keys, which are necessarily unique. So named-column constructs give a header but silently **collapse duplicate header labels into one column** — real data loss. Positional constructs (matrix → `Grid`) never lose data but have a blank header. There is no construct that does both. We default to the lossless representation and promote to a real header only when it is faithful (unique labels), rather than dropping a column for prettiness.

A header row with no body rows is not promoted either. A `Dataset` of zero rows has no column names to show, so the header text is lost from the notebook, and the `"Markdown"` exporter fails on it. The `Grid` keeps the header row as bold data.

Nor is a header row that a body row is wider than. Each row of a `Dataset` is an association keyed by the labels, so a cell beyond the last label has no key and would be dropped. A shorter body row is padded with blanks, which loses nothing.

A cell's text is what `HTMLInnerText` gives for the cell, under the call's `"Roles"`, so `<style>` and `<script>` are left out and `<br>` and block boundaries give line breaks. The line breaks are kept although the `"Markdown"` exporter (15.0) writes a newline in a table cell unchanged, which breaks the GFM table; that is the exporter's bug, and replacing the breaks would lose them from the notebook too.

The no-silent-loss rule also covers the `<caption>`. A GFM table has no caption, so dropping it would lose its text without a trace. Instead, in both forms, a caption becomes a `"Text"` cell immediately before the table's cell. Its content is converted as a paragraph's is, keeping formatting and links, and it exports as a line of its own above the table. A table without a caption is still a single cell.

Both forms sit in an `"Output"` cell. A `Dataset` brings its own look; the `Grid` is given one that reads as a document table rather than as an evaluation result: framed (`Frame -> All`), left-aligned, in the `"Text"` base style, with its strings shown as written (no quotes, operator glyphs or syntax colouring). A `<th>` cell in the `Grid` form is bold, so it exports as `**…**`; in the `Dataset` form the `<th>` row is the header and stays plain.

## Considered options

- **Always honor `<th>` as the header (named construct)** — rejected: silently drops a column when two header labels coincide. Losing data is a worse cost than a blank header row.
- **A dedicated `"TableRepresentation"` option** — rejected: the general `"Constructs"` rule already accepts a constructor-function RHS, so a user who wants `Tabular`, always-pretty, or a bespoke layout writes one rule (`XMLPattern["table"] :> fn`). No per-feature knob is warranted.

## Consequences

`colspan`/`rowspan` and nested tables have no faithful GFM target and degrade: a spanning cell counts as one cell, and a nested table is text in the cell that holds it. The `<table>` default is itself a built-in constructor-function construct rule, so it is overridable like anything else.
