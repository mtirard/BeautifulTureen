---
status: accepted (amended by ADR-0018 and ADR-0020)
---

# `FromCSSSelector` translates a static CSS selector into XML patterns, and a bare string where an XML pattern goes is CSS

> **Amended by [ADR 0018](./0018-the-document-above-the-top-elements.md)** (2026-10-02, implemented 2026-10-05). `:root` and `:scope` translate as `Child[XMLDocument[], {C}]`, with the rest of the compound in `C`, at the start of a selector, and a child-indexed pseudo-class at the start of a chain lists under `XMLDocument[] | XMLPattern[_]`, so it reaches the root. After a combinator, before `+` or `~`, and inside `:not()`, `:is()`, `:where()`, `:has()` and `of S`, `:root` and `:scope` are still `::unsupported`.

> **Amended by [ADR 0020](./0020-recognised-shapes.md)** (2026-10-06). A position among the siblings that match `S` (`:nth-child(An+B of S)`, `:nth-last-child(An+B of S)`) or of the compound's type (the `-of-type` forms) is no longer a `Count` in a condition on the list. For a compound alone in its run it is written with plain entries, which the compiler recognises as shapes 4 and 5 of ADR 0020 and runs in one pass over each parent's children: the siblings that do not match `S`, then a unit `PatternSequence[S, Except[S] ...]` for each earlier sibling that does, with the An+B units as for a position among all children, and the mirror from the end. `p:nth-of-type(2)` becomes `Child[XMLDocument[] | XMLPattern[_], {Except[XMLPattern["p"]] ..., PatternSequence[XMLPattern["p"], Except[XMLPattern["p"]] ...], XMLPattern["p"], ___}]`, and `tr:nth-child(2n+1 of .a)` takes about 12 ms over 1,000 rows, against 8.3 s. `of S` is intersected into the compound, as before, so the selected entry matches `S` itself; `S` is the selector's pattern, or `_?m` with `m = XMLMatchQ[S]` when it names its element. The general condition form stays for a counted position in a run of more than one compound (other than the first or last of its kind on the run's first or last compound), for two positions on one side of one compound, as in `:nth-child(1 of .a):nth-child(2)`, and for `-of-type` on a compound with no type, which counts the element's own tag. That form is recognised too, as shape 7 of ADR 0020, a condition on the list over `Count`, `Length` and `MatchQ` of the siblings on each side, and runs in one pass over each parent's children; the translation keeps it. A CSS-side optimisation is a choice of which pattern to emit, in a shape the compiler recognises, never a private head.

A bs4 user writes `soup.select("div.note > p")`. The same query here is `XMLCases[tree, Child[XMLPattern["div", "classList" -> "note"], XMLPattern["p"]]]`, about 2.5 times the characters. The CSS-Rosetta demo measured this on every row of Wikipedia's selector table (`.scratch/wtc-presentation/demos/css-rosetta/README.md`). Every clean row is longer than its CSS, and a CSS-fluent user has to learn the symbolic form before writing their first query. This ADR adds a translator from CSS to the paclet's existing patterns, and lets a CSS string stand wherever an XML pattern is accepted. The symbolic form stays the language. CSS is a way to write it, and `FromCSSSelector` shows the user what they wrote.

The design was settled in `.scratch/css-selectors/issues/01-decide-the-shape-of-the-css-selector-front-end.md`. The grammar is in `.scratch/css-selectors/research/css-grammar-v1.md`, and the implementation spec is `.scratch/css-selectors/specs/fromcssselector-v1.md`.

## Decision

### `FromCSSSelector[s]` evaluates to an XML pattern

`FromCSSSelector["div.note > p"]` evaluates at once to `Child[XMLPattern["div", "classList" -> "note"], XMLPattern["p"]]`. It is not a new kind of pattern, and it is not inert. An inert head would gain no speed (measured on main), and the symbolic form is the part worth showing. The name follows ADR 0006 and ADR 0009, which named it as future work.

The translation is **literal**, against the tree the importer gives. `td[rowspan]` becomes `XMLPattern["td", "rowspan"]`, which matches every cell, because the importer adds `rowspan="1"` (FRICTION; the importer defects are tracked upstream). The translator does not try to undo the importer's work.

The output contains only public symbols and pattern names that `FromCSSSelector` makes for itself. Those names cannot collide with the user's, so a translation can be spliced into a larger pattern.

### The dialect

- **Static Selectors Level 4**, tokenised by CSS Syntax 3: escapes, strings, comments, and unclosed blocks closed at the end of the input.
- **Case is literal** for element names, attribute names and values. Lowercasing would break SVG inside HTML and every XML document. Keywords (pseudo-class names, the `i`/`s` flags, An+B) are ASCII case-insensitive, as Selectors 4 requires.
- **No namespaces** in v1.
- **No soupsieve extensions**, such as `:contains()`. Tests on text are left to the symbolic form, which can do more.

### What v1 translates

- Type selectors, `*`, `.class`, `#id`, every attribute operator, and the `i` and `s` flags. `i` folds A–Z only, as the spec requires. WL's `IgnoreCase` also folds `é` and `É`, so it cannot be used.
- Compounds and the four combinators: descendant, `>`, `+` and `~` become `Descendant`, `Child`, `Adjacent` and `Sibling`.
- Through conditions: `:not()` and `:is()`/`:where()` over compound selectors, `:has()` with relative selectors that start with a descendant or `>` combinator, `:empty`, `:checked`, `:link` and `:any-link`.
- Since ADR 0016, the child-indexed pseudo-classes, as list stages over the parent's element children: `:first-child`, `:last-child`, `:only-child`, `:nth-child()` and `:nth-last-child()` (with `of S` over compounds), and the `-of-type` forms. `li:nth-child(2n+1)` becomes `Child[XMLPattern[_], {PatternSequence[_, _] ..., XMLPattern["li"], ___}]`. A run of compounds joined by `+` or `~` in which one has a position is one list, as `Adjacent` and `Sibling` are its shorthands: `a + b:last-child` becomes `Child[XMLPattern[_], {___, XMLPattern["a"], XMLPattern["b"]}]`. A position among all the siblings of a compound joined to the first of its run by `+` alone is one of the first, less the compounds between, and the same from the end: `b + a:nth-child(5)` becomes `Child[XMLPattern[_], {Repeated[_, {3}], XMLPattern["b"], XMLPattern["a"], ___}]`. Two positions on one end of a run, a position reached across `~`, several positions in one compound, a position that needs the prefix of a sibling entry, and `-of-type` on a compound with no type use a condition on the list over named entries. At the start of a chain the parent is `XMLPattern[_]`, so the root is not reached until ADR 0018 is implemented.
- Selector lists whose selectors differ in at most one compound, as alternatives in that stage: `a > b, a > c` becomes `Child[a, b | c]`.
- Since ADR 0015, any other selector list, as the alternatives of its selectors' translations, in written order: `a > b, c d` becomes `Child[a, b] | Descendant[c, d]`. So does `:is()`/`:where()` with complex arguments in a selector of one compound, the rest of the compound merged into each argument's last compound: `p:is(div p, section > p)` becomes `Descendant[div, p] | Child[section, p]`.

`[foo~="x"]` always becomes `"fooList" -> "x"`. `FromCSSSelector` takes no readings option. The reading is supplied where the query runs, through the consumer's `"AttributeReadings"` option or `$AttributeReadings`, and a consumer warns when a list key has no reading (#24).

`:checked` matches `type` ASCII case-insensitively, as HTML matches enumerated attributes. Literal case applies to what the user writes. A fixed definition can fold an attribute that HTML defines as case-insensitive.

`:is()` and `:where()` are forgiving, as Selectors 4 says. An argument that is not valid CSS is dropped, so `:is(p, ::before)` means `:is(p)`. An argument that is valid but outside the subset, or impossible, is still refused, because dropping it would change the meaning without saying so.

### What v1 refuses

Each refusal is a message and `$Failed`. There is one message per kind, and the message names the symbolic workaround where one exists.

- **`FromCSSSelector::invalid`**: the string is not a valid selector, including unknown pseudo-classes, Level 5 names, `:matches()` and soupsieve extensions.
- **`FromCSSSelector::unsupported`**: valid Selectors 4 that v1 does not translate:
  - namespaces and the `||` combinator
  - complex arguments to `:not()`, and to `:is()` and `:where()` in a selector of more than one compound. `x :is(a b)` matches an element with the ancestors `x` and `a` in either order, or one element that is both, so it is a conjunction of chains, not a chain with `:is()` as its last stage; its expansion grows combinatorially, as for `A :is(B C) D`.
  - `:has(+ …)` and `:has(~ …)`
  - a child-indexed pseudo-class inside `:not()`, `:is()` or `:where()`, which needs the element's parent, and `of S` with a complex `S`
  - `:root` and `:scope` anywhere but the first compound of a selector, followed by `>` or a descendant combinator (ADR 0018)
  - `:lang()`, `:dir()` and the form-state pseudo-classes
- **`FromCSSSelector::impossible`**: the selector depends on a browser session, layout, the URL or shadow trees. This covers pseudo-elements, the user-action, media and display-state pseudo-classes, `:visited`, `:target` and `:host`.

### A bare string is CSS

A string anywhere an XML pattern is accepted means `FromCSSSelector[string]`:

- the pattern argument of `XMLCases`, `XMLFirstCase`, `XMLDeleteCases` and `XMLMatchQ`
- the left-hand side of a rule given to them
- a stage of a combinator
- the left-hand side of a `Roles` or `Constructs` rule

So `XMLCases[tree, "div.note > p"]` and `XMLCases[tree, "a[href]" :> …]` work. Where the consumer takes only an element pattern (`XMLMatchQ`, `Roles`, `Constructs`), a string that translates to a combinator is refused with the message the consumer gives for a combinator. A string that fails to translate gives `FromCSSSelector`'s message, and the consumer gives `$Failed`.

A string stage that translates to a combinator is **spliced** into the chain, as any combinator stage is (ADR 0014). `Child["div p", x : XMLPattern["span"]]` is the chain div Descendant p Child x.

`XMLPattern`'s tag slot is unchanged. `.` is legal in an XML tag name (`<a.b>`, Maven's `<project.build.sourceEncoding>`), and `:` already means a namespace there, so `XMLPattern["a.b"]` stays the tag `a.b`.

In a `Roles` or `Constructs` rule, a string used to be a tag name. A tag that is a CSS identifier means the same element pattern either way, and every tag in HTML is one. Tags such as `a.b` or `svg:rect` now need `XMLPattern["a.b"]`. This is a breaking change, recorded in the release notes and as a Possible Issue. Before this ADR, a string anywhere else was `::badpat`, so nothing else changes meaning.

### Later phases

Two features widen the translator as they land, each as a phase of the spec:

- **ADR 0015 (alternatives of combinators), done:** selector lists of any shapes, and `:is()`/`:where()` with complex arguments in a selector of one compound, become `Alternatives` of their selectors' translations, in written order. The spec also read `x :is(a b, c > d)` as `Descendant[x, Descendant[a, b] | Child[c, d]]`, but that puts `a` inside `x`, where CSS (and soupsieve) also match an `a` around `x`, so it stays `::unsupported`.
- **ADR 0016 (list stages), done:** `:first-child`, `:last-child`, `:nth-child()`, `:nth-last-child()` (with `of S`) and the `-of-type` forms become list stages. `:only-*` moves to list stages, and the restriction to the start of a chain or after `>` goes.

Until a feature lands, v1 refuses the selectors that need it, with `::unsupported`.

## Considered options

- **An inert `CSSSelector["…"]` head, compiled by the consumers.** It hides the translation, which the user should see as a bridge to the symbolic form, and was measured to gain no speed.
- **A CSS reading of `XMLPattern`'s tag slot** (`XMLPattern["div.note"]`). `.` and `:` already mean something there, in XML.
- **Lowercasing, as HTML browsers do.** This breaks SVG inside HTML (`foreignObject`, `viewBox`) and every XML document.
- **Working around the importer** (ignoring the `rowspan="1"` defaults). The translator would then disagree with the symbolic form it prints.
- **A readings option on `FromCSSSelector`.** The reading would be split between where the pattern is made and where it runs. One place, the consumer or the global, is simpler.
- **Translating `:root` as `XMLPattern["html"]`.** The importer can nest `html` inside `html`, and XML documents have other roots. How a query reaches the root is decided separately (`.scratch/css-selectors/issues/07-decide-how-a-query-reaches-the-root-and-the-input.md`).
- **Comparing elements by value for the child-indexed pseudo-classes**, as the Rosetta demo did. Identical siblings collapse into one, so Hacker News `tr:nth-child(2n+1)` gave 65 rows instead of 50. List stages (ADR 0016) replace it.
- **Running each selector of a list as its own query and joining the results.** Elements that both select are lost (17 on the CSS page). ADR 0015 replaces it.
- **Keeping tag strings in `Roles` and `Constructs` rules beside CSS strings.** That means two readings of one string, depending on where it is. CSS agrees with the tag reading for every HTML tag.

## Consequences

A CSS string is the shortest way to write a query that CSS can express, and `FromCSSSelector` turns it into the symbolic form for anything further: names, rule bodies, value tests.

Two issues this depends on are tracked on their own: a `"classList"` key, which most translated CSS uses, makes a query rebuild the whole tree (#22), and a pattern that names a list key with no reading, as `[foo~=x]` does without a reading for `foo`, gives no warning (#24).

`:not` and `:has` become a nested `XMLMatchQ` or `XMLFirstCase` in a condition. They also inherit their readings, which is why ADR 0012 now makes the `"AttributeReadings"` option a `Block` of `$AttributeReadings` around the whole call.

They inherit the per-candidate cost of the nested call. Measured on the Rosetta pages (v1 phase 1, 2026-10-05; time for the whole query, then per element that the compound's own `XMLPattern` takes):

| selector | page | BeautifulTureen | soupsieve | per candidate |
|---|---|---|---|---|
| `li:not(.mw-list-item)` (merged into the class list) | css | 29 ms | 4.7 ms | 40 µs |
| `a:not([href^="#"])` | sel4 | 17 ms | 12 ms | 5 µs |
| `div:has(> table)` | css | 7 ms | 4.4 ms | 20 µs |
| `ul:has(ul li)` | css | 33 ms | 4.7 ms | 200 µs |

- `:not` with a condition tests with the operator form `XMLMatchQ[C][e]`, which keeps its compiled matcher per readings table. The two-argument form compiled `C` for every candidate and took 320 ms on the `a:not` row.
- `:has(s)` for one compound searches `Cases[Last[e], _XMLElement]`, not `Last[e]`: a list given to `XMLFirstCase` may hold only elements and strings, and an XML document's children can hold comments. Every other `:has` form runs a chain from the anchor element, at about 0.2 to 0.5 ms per candidate. It is the slowest translation, and a candidate for a cache of the compiled chain.
- A position among all the siblings is written with `Repeated` entries. A position among the siblings of a type or that match a selector, other than the first or the last, is written as a condition on the list instead: `{g___, x : C, ___} /; Count[{g}, XMLElement["p", _, _]] + 1 == 2`. The `Repeated` form of `p:nth-of-type(2)`, `{PatternSequence[Except[p] ..., p], Except[p] ..., p, ___}`, backtracks: on a table of 1,000 rows (phase 3, 2026-10-05), `tr:nth-of-type(2)` took 0.9 s and `tr:nth-of-type(50)` more than 20 s, against 0.06 s as a condition. On the same table, `tr:nth-child(500)` takes 23 ms, `tr:nth-child(2n+1)` 37 ms, `tr:nth-of-type(500)` 59 ms, and the general form with two positions in one compound 33 ms. The general form is quadratic when its entries are costly to match: `.a:nth-of-type(500)` takes 2.5 s and `.b ~ .a:nth-child(500)` 1.6 s (2026-10-06), as the class list is tested at every split, and `tr:nth-child(2n+1 of .a)` 8.5 s, as `of S` tests each earlier sibling with `XMLMatchQ` for every candidate. A position moved along `+` to the first compound of its run is written with `Repeated` entries, as above: `.b + .a:nth-child(500)` takes 32 ms, against 1.6 s as the general form, `.b + .a:nth-child(2n+1)` 44 ms against 1.6 s, and `tr + tr:nth-child(500)` 26 ms against 42 ms (2026-10-06). On the Rosetta pages every child-indexed row checked takes under 0.4 s. Since ADR 0020, a counted position of a compound alone in its run is written with plain entries that the compiler recognises (see the note at the top), so the condition form remains for the cases that note lists.
- Translation takes 0.3 ms at the median and 0.6 ms at most per Rosetta selector, about 4% of the query on the `css` page at the median, so a string is translated each time its query is compiled, with no cache of its own. `XMLMatchQ[string]` is cached by the operator form's own cache (ADR 0013).

Possible Issues, for documentation:

- Matching is against the imported tree, so `[rowspan]`, `[colspan]`, `[shape]` and `[type]` match the importer's defaults.
- Case is literal: `DIV` does not match the importer's `div`.
- `[foo~=x]` needs a reading for `foo`, given where the query runs.
- `[a="é" i]` does not match `É`, as the spec says. soupsieve matches it.
- `:checked` tests the `selected` attribute only. HTML's rule that the first `option` is selected by default is not applied, and soupsieve does not apply it either.
- `:root` and `:scope` are translated only at the start of a selector. Top-level text does not stop `:root`, as it does in soupsieve, and `:scope > p` on a list of several top-level elements gives `{}` (ADR 0018).
- A selector with a child-indexed pseudo-class translates to a combinator, so `XMLMatchQ` and `Roles` refuse it.
- The positions written as a condition are quadratic in the number of siblings when their entries are costly to match. `tr:nth-child(2n+1 of .a)` took 8.5 s over 1,000 rows as a condition, and takes about 12 ms as the recognised plain form (ADR 0020).
- In a `Roles` or `Constructs` rule, a string is CSS: a tag such as `a.b` needs `XMLPattern["a.b"]`.
- A selector list of *n* selectors of different shapes runs *n* chains (ADR 0015). On the Rosetta `css` and `sel4` pages (phase 2, 2026-10-05), every two- and three-selector list checked, and each complex `:is()`/`:where()`, gave soupsieve's elements in soupsieve's order, and translating `div.mw-heading + p, table code, tr > th` took 0.8 ms, the slowest of the Rosetta selectors.
- `:is()` or `:where()` with a combinator inside is translated only in a selector of one compound: `x :is(a b)` is refused.
