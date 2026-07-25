# BeautifulTureen — Context Glossary

BeautifulSoup-style HTML element selection and text extraction for the Wolfram
Language. Operates on the static `XMLObject` tree produced by
`Import[…, {"HTML", "XMLObject"}]`.

This file is a glossary, not a spec. It defines the language we use to talk
about the domain. Implementation lives in the code; decisions live in
`docs/adr/`.

## Terms

The two text functions take their names and their split straight from the web
platform's two long-standing answers to "what is the text of this HTML?" —
`textContent` (a `Node` tree-fold) and `innerText` (an `HTMLElement` rendering
projection). We inherit that convention rather than invent our own.

**Naming principle.** A symbol's name idiom tracks its semantics, not surface
uniformity. A function that *reads a (near-)canonical property off* the tree is
named `HTML‹Noun›` — "the ‹noun› of the tree" (`HTMLTextContent`,
`HTMLInnerText`). A function that performs a *directed, lossy, opinionated
projection* — where there is no canonical answer and decisions are being made —
is named `‹X›To‹Y›` (`HTMLToNotebook`). The `To` is a deliberate signal: expect
choices, expect loss, do not expect a round-trip.

### Text content (`HTMLTextContent`)

The lossless concatenation of every descendant text node, in document order,
with no whitespace inserted or removed. The analogue of the DOM's
`textContent`. Faithful but verbose: source indentation, newlines, and
`<pre>` whitespace all survive unchanged. The low-level primitive; normalizing
transforms sit _above_ it, never inside it. (Shipped as `HTMLText` through
v1.0.2; see ADR on the rename.)

### Inner text (`HTMLInnerText`)

Text as the **structural meaning of the tags** implies it should read: internal
whitespace collapsed, block tags broken onto their own lines, `<br>` → newline,
preformatted tags left verbatim, non-rendered tags dropped. The analogue of the
DOM's `innerText` — and like `innerText` on a non-rendered element, it has no
layout to consult, so it approximates using the [[frozen-ua-stylesheet]]. See
**Tags-only**: we judge by tag, never by the CSS cascade, so we reproduce
HTML-in-general, not this-page-as-rendered.

### Display role

The classification that drives readable-text extraction; assigned per element by
the [[frozen-ua-stylesheet]] table or a user [[role-rule]]. It is really **two
orthogonal axes plus two special atoms**:

- **Box** (local, _not_ inherited): **Block** sits on its own line; **Inline**
  flows with its neighbours. Re-decided at every element.
- **Whitespace** (environmental, _inherited_ down the fold): **Normal** collapses
  whitespace runs to a single space; **Preserve** keeps text verbatim.
- **Skip**: prune the element _and its whole subtree_ (`script`, `style`).
- **LineBreak**: an empty forced single newline (`<br>`) — no box, and never
  doubled by the [[block-separator]].

The inhabited combinations: **Inline** (Inline+Normal), **Block** (Block+Normal),
**Preformatted** (Block+Preserve). Inline+Preserve is representable but has no
built-in occupant. Only the Whitespace axis is threaded through the fold; Box,
Skip, and LineBreak are decided locally.

In a [[role-rule]], a role is written as one of **five flat string tokens** —
`"Block"`, `"Inline"`, `"Preformatted"`, `"LineBreak"`, `"Skip"`. The
orthogonal `{Box, Whitespace}` form was rejected: it only buys the empty
Inline+Preserve quadrant, so the flat enum is the practical choice (the option
could grow to also accept a pair later, without breaking the flat form).

### Block separator

A single global string (default `"\n"`) inserted between Block boundaries when
emitting readable text — the BeautifulSoup `get_text(separator=…)` analogue.
`"\n\n"` gives paragraph-style gaps. It is deliberately _uniform_: we do **not**
vary it per tag (no "`<p>` gets a blank line but `<li>` doesn't"). That mixed,
structure-aware spacing is the job of a separate Markdown transform, not the text
extractor. `<br>` ([[display-role]] LineBreak) is always one newline, immune to
this option.

### Frozen UA stylesheet

Our fixed tag → rendering tables. A deliberate _snapshot_ of the WHATWG HTML
§15 "Rendering" default user-agent stylesheet — the spec's own definition of how
each tag renders by default. "Frozen" because we never consult per-page CSS:
not classes, not `<style>` blocks, not external sheets, not even inline
`style=`. A page that overrides a tag's `display` in its own CSS will not move
us. The same snapshot drives **two layers**: the `display` property gives each
element's [[display-role]] (the structural skeleton); the font rendering
(bold/italic/…) gives its default inline [[construct]]. Both are [[tags-only]].

### Role rule

A user-supplied override (the `"Roles"` option of `HTMLInnerText`) of the form
`pattern -> role` (or `pattern :> role`).
The left-hand side is an `XMLPattern` — the paclet's _own_ selection language,
reused — with a bare string sugaring to `XMLPattern[string]` (exact tag match).
Combinators (`Child`/`Adjacent`/`Sibling`/`Descendant`) are not accepted, because
a role is assigned to each element in isolation, not by its tree position. Rules
are tried **in order, first match wins** (the `Replace` convention — deliberately
_not_ CSS-style specificity); if none match, the [[frozen-ua-stylesheet]] table
decides, and an unknown tag defaults to **Inline** (as in browsers). Because the
LHS is a full pattern and the rule may be delayed, `PatternTest`, `Condition`,
and a computed RHS subsume any need for a separate "classifier function" override.

### Tags-only

The standing rule that display roles are decided from the **tag name alone**.
Inline `style="display:none"` is technically present in the tree but
deliberately _not_ read, because honoring it while being unable to honor the
class-based equivalent (`class="hidden"`) would make behavior hinge on an
invisible authoring accident. Tags-only is predictable; tags-plus-inline-CSS is
not. The escape hatch for users who _do_ know their CSS is an injectable role
classifier (see code / ADRs), not a CSS engine.

### Class list

What a `CSSClass` constraint selects on: the whitespace-separated **tokens** of an
element's `class` attribute. Three different-looking elements have the same
**empty** class list — no `class` attribute, `class=""`, and whitespace only —
because they state the same fact in HTML, so no class constraint may distinguish
them.

Each `CSSClass` argument is an **ordinary string pattern matched against one
token**, never against the whole attribute value: `_` is one character, `__` one
or more, `___` zero or more, and `"col-" ~~ __` is a class beginning with `col-`
and cannot run past the space into the next class. Nothing is reinterpreted; the
token is simply the unit of matching (ADR 0005).

The empty class list is why a negation is absence-tolerant: `CSSClass[Except["ad"]]`
matches an element carrying no class, exactly as CSS `:not(.ad)` does, and
`CSSClass[Except[___]]` reads as "carries no classes" — the mirror of
`CSSClass[___]`, "carries at least one class" (ADR 0004). Presence of the
*attribute* is a different question, asked with the bare-attribute shorthand
`XMLPattern["p", "class"]`, which `class=""` satisfies. A raw attribute rule
(`"href" -> Except["#"]`) keeps plain `KeyValuePattern` semantics and does require
the key — it is the user's own pattern, not our abstraction.

### Notebook conversion (`HTMLToNotebook`)

A directed, lossy projection of an HTML/XML tree into a Wolfram `Notebook[…]`
expression: each [[display-role]] Block element becomes a `Cell`, each Inline
element becomes a box inside the surrounding cell's `TextData`. Markdown, PDF,
RTF, and display then fall out via `Export` — we never emit those formats
ourselves. Named with the `‹X›To‹Y›` idiom rather than `HTML‹Noun›` precisely
because it makes projection choices (lossy, no canonical answer) — see the
naming principle at the top.

### Construct

What an element _becomes_ in the notebook, chosen **after** its [[display-role]]
has placed it — the role decides block-vs-inline, the construct supplies the
form. Two kinds, gated by the role: a **block construct** is a Wolfram
cell-style string used directly (`"Text"`, `"Section"`, `"Item"`, … — an open
set `Export` already understands, so we adopt WL's names rather than invent our
own); an **inline construct** is one of a **closed** token set — `"Bold"`,
`"Italic"`, `"Underline"`, `"StrikeThrough"`, `"Code"`, `"Hyperlink"`,
`"Plain"` — each naming a box transform whose WL form (e.g.
`FrameBox[StyleBox[…, "Code"]]` for `"Code"`) is hidden. Block is open/native;
inline is closed/named, because inline boxes have no clean string analogue.
`"Plain"` means _unwrap_: splice the children's boxes in with no wrapper.

Most Block elements **recurse-and-flatten**: their block children become their
own cells, nesting surviving only through style-name depth (`Item`/`Subitem`/…),
since a `Notebook` is a flat cell sequence. The exceptions are
**leaf-collapsing** constructs — `<blockquote>`, `<pre>`, and `<table>` — which
do _not_ recurse into separate cells but collapse their whole subtree into one
cell's content (a framed inline render, verbatim code text, or a tabular data
structure respectively). Nested _quotes_ still survive (the quote renderer
prefixes each line, so depth composes via `>`); nested non-quote blocks inside
them flatten to lines.

### Construct rule

A user override of the default [[construct]] map, the Layer-2 analogue of a
[[role-rule]]: `pattern -> construct` (or `pattern :> construct`), bare-string
LHS sugaring to `XMLPattern[string]`, tried in order, first match wins. The
delayed form lets the construct be computed from the matched element (read an
attribute, count children). The [[display-role]] still decides block-vs-inline
placement; a construct rule only supplies the form and yields to the role on
conflict. Two override layers therefore coexist on the conversion: `"Roles"`
shapes the skeleton, the construct map shapes the form.

The RHS [[construct]] takes one of **three forms**: a block cell-style string,
an inline token, or a **constructor function** `element ↦ Cell/boxes` — the
universal escape hatch for anything bespoke. There are therefore **no
per-feature options** (no table-style knob, no image knob): the general
construct rule with a function RHS subsumes them, exactly as the [[role-rule]]'s
full-pattern + delayed RHS subsumes a separate classifier override. A few
built-in defaults are themselves function-valued rules — notably `<table>`,
which builds a `Dataset` when a `<thead>`/`<th>` row gives unique column labels
(idiomatic header) and a `Grid` otherwise (positional, no silent column loss).
`Dataset`/`Grid` over `Tabular` because the paclet floor is WL 12+ and `Tabular`
is 14.1+.
