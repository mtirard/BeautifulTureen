---
status: accepted (amended by ADR-0018)
---

# A list stage is a WL list pattern over a parent's element children, and `Adjacent` and `Sibling` are its shorthands

> **Amended by [ADR 0018](./0018-the-document-above-the-top-elements.md)** (2026-10-02, implemented 2026-10-05). A list stage after `XMLDocument[]` lists the top elements, so `Child[XMLDocument[] | XMLPattern[_], {…}]` reaches the root, and "The root" below is reversed. In "`Adjacent` and `Sibling`", `_` as the parent stands for `XMLDocument[] | XMLPattern[_]`.

A combinator relates elements by ancestry and by the next or a later sibling, but it cannot say where an element sits among its siblings. CSS's child-indexed pseudo-classes (`:first-child`, `:nth-child(2n+1)`, `:nth-last-of-type(-n+3)`) need that. Comparing an element by value with its parent's children cannot express it: identical siblings collapse, so Hacker News `tr:nth-child(2n+1)` gave 65 rows instead of 50. WL already has a language for position in a sequence, the list pattern, and a [[Stage]] that is one reads `:nth-child(n)` as `{Repeated[_, {n - 1}], c, ___}`. This ADR adds that stage. A prototype matched it against soupsieve on the CSS-Rosetta snapshots: 29 of 31 selectors agree, and the two misses are the root (`.scratch/css-selectors/issues/03-prototype-list-stage-matching-on-real-pages.md`).

## Decision

### Reading

A **list stage** is a WL list pattern written as a stage after a `Child` or `Descendant` link. It is matched against the element children of one parent, with text and other non-element children left out, as `Adjacent` and `Sibling` already leave them out.

- `Child[p, {…}]` matches the list against the element children of each element that `p` matches.
- `Descendant[a, {…}]` matches it against the element children of each element that is `a` or lies inside `a`, one parent at a time. `Descendant[XMLPattern["div"], {x : XMLPattern["p"], ___}]` is `div p:first-child`.

A list stage may be followed by more stages: `Descendant[Child[XMLPattern[_], {XMLPattern["li"], ___}], XMLPattern["a"]]` is `li:first-child a`. Everywhere else a list is `::badpat`. That includes a list as the whole query, where WL users might read it as alternatives (as `StringCases` reads a list), a list as the first stage of a chain (`Child[{c, ___}, d]`, which has no parent to list), and a list after an `Adjacent` or `Sibling` link.

### Entries

An entry is an [[XML pattern]] or a WL pattern over the children: blanks, and `Repeated`, `RepeatedNull`, `Except`, `PatternSequence`, `Alternatives`, `Optional`, `Condition` and `PatternTest` over entries. A raw `XMLElement` pattern and a list inside an entry are `::badpat`. A [[List key]] inside an entry is materialised as anywhere else (ADR 0012).

The **selected entry** is the last top-level entry that is an XML pattern: an `XMLPattern`, a combinator, alternatives of them, or any of these named, conditioned or tested. The chain continues from the child in that entry's place. Every other entry is a **context entry**. `_`, `___`, `Repeated`, `Except[…] ...`, and alternatives that include a blank are always context entries, so a last element child of any tag is written `{___, XMLPattern[_]}`, not `{___, _}`. A list with no XML-pattern entry (`{}`, `{___}`, `{_, _}`) is `::badpat`. There is no marker for selecting an entry that is not last. Named patterns reach the other entries in a rule body.

A combinator entry stands in the list by its **first** stage, which is the child in that place, exactly as a combinator splices into a chain as a stage (ADR 0014, and ADR 0015 for alternatives):

- **Selected**: the chain runs on to the combinator's last stage. `Child[a, {___, Descendant[b, c], ___}]` selects the `c`s below a `b` that is a child of an `a`, the same as `Child[a, Descendant[b, c]]`. `Child[a, {___, x, Descendant[b, c], ___}]` is `a > x + b c`.
- **Context**: the rest of its chain is a test below that sibling. `Child[_, {___, Descendant[b, c], x, ___}]` is `b:has(c) + x`.

The first stage of a combinator entry must be an element pattern. A list stage there is `::badpat`.

### Alternatives, conditions and names

Alternatives of lists are a stage, as in ADR 0015: `Child[_, {c, ___} | {___, c}]` is `:is(:first-child, :last-child)`, and each alternative has its own selected entry. `{…} /; test` is a condition on the list.

A list stage reads as the list pattern itself, nested in ADR 0014's tuple: `Child[p, {x : a, ___, c}]` reads as `{p, {x : a, ___, c}}`. So, as in WL:

- A condition on an entry sees that entry's names. A condition on the list sees every name in it. A condition on the combinator sees every stage's names.
- A name shared between an entry and another stage, or between two entries, is one value. Element and attribute-map names compare as the stripped originals (ADR 0012).
- A named sequence entry binds a `Sequence`: `{pre___, c, ___}` binds `pre` to the elements before `c`.
- A named list, `s : {…}`, binds `s` to the `List` of the parent's element children, stripped. A name on alternatives of lists binds the same `List`.

When one selected child matches the list in several ways, **WL's first match binds**, in WL's own matching order, skipping matches that a condition or a rule body rejects (ADR 0014's amendment). For `{___, x : a, ___, c, ___}` this is the earliest `a`, which is the earlier sibling `Sibling` binds today. The choice is made at the list stage, before any earlier stage's, in line with ADR 0014's "latest stage first". A name in a context combinator entry binds as that combinator's chain would bind it on its own (ADR 0014: first in document order).

### `Adjacent` and `Sibling`

`Adjacent` and `Sibling` remain, defined as shorthands:

- `Adjacent[a, b]` is `Child[_, {___, a, b, ___}]`.
- `Sibling[a, b]` is `Child[_, {___, a, ___, b, ___}]`.

In a chain, an `Adjacent` or `Sibling` link reads as a list over the parent of the previous stage's element, with that element in its place: `Adjacent[Descendant[x, a], b]` is `Descendant[x, {___, a, b, ___}]`, and `Sibling[Adjacent[a, b], c]` is `Child[_, {___, a, b, ___, c, ___}]`. Their matches, document order and bindings are the list stage's, which are what they are today.

### Consumers

- `XMLCases` and `XMLFirstCase` accept list stages anywhere a stage may be one.
- `XMLDeleteCases` accepts list stages and deletes the selected elements by position in the original tree, as for a `Child` or `Descendant` chain. It now also accepts `Adjacent` and `Sibling`: the `::unsupported` refusal in ADR 0014 and ADR 0015 is lifted.
- `XMLMatchQ` and the `Roles`/`Constructs` options take an element pattern, and refuse a combinator holding a list stage as they refuse any combinator (ADR 0013).

### The root

A list stage never selects the root of the tree it is given. For an `XMLObject`, the root element has no `XMLElement` parent, so it is in no list. For a bare `XMLElement` input, the root is never a result (ADR 0014). soupsieve and Selectors 4 count the root as the only child of a parent that is not an element, so `html:first-child` matches there and not here. This is meant to be reversed. How a query reaches the root and the input it was given is one question, which also decides `:root`, `:scope` and a children-only search (#14), so it is decided separately (`.scratch/css-selectors/issues/07-decide-how-a-query-reaches-the-root-and-the-input.md`).

## Considered options

- **Comparing an element by value with its parent's children** (`Child[p : XMLPattern[_], e : …] /; First[Position[Last[p], e]] …`). This was the CSS-Rosetta demo's approach. Identical siblings collapse into one, so it gets Hacker News rows and `div p:first-child` wrong.
- **Fixed-index forms or new heads** (`NthChild[c, n]`, `FirstChild[c]`). Each pseudo-class would need its own head, and `An+B` and `of S` would need their own argument language, when WL's list patterns already say all of it.
- **A combinator entry standing for its last stage**, the child being one of the elements the combinator selects, its earlier stages anywhere above. This gives "a combinator as a stage" a second meaning, used only inside lists, and needs a search of the whole input for each entry. Rejected for the first-stage reading, which is how a combinator already splices into a chain.
- **Refusing combinators as entries.** Simpler, but then an entry is "any XML pattern except one kind", and `b:has(c) + x` and `a > x + b c` have no list form.
- **Refusing a named list**, as a named combinator is refused (ADR 0015). The reason for that refusal does not apply here: a combinator's elements are not a sequence of anything, but a list's entries are siblings, and binding them is WL's meaning for `s : {…}`.
- **A marker for selecting an entry that is not last**, for `:has(+ b)` and `:has(~ b)`. Deferred: named patterns already reach the other entries in a rule body, which is more idiomatic. It may come back for `XMLDeleteCases`, which cannot use a rule body.
- **Keeping the `Adjacent` and `Sibling` engines beside the list matcher.** Rejected, as ADR 0014 rejected per-combinator code: two engines would have to agree on every scoping rule.
- **Fast paths for fixed indices** (`{c, ___}`, `{___, c}`, `{Repeated[_, {m}], c, ___}`). The prototype measured 0.6 ms against 0.7–1.1 ms on a 1,000-row table. Not worth a second code path.

## Consequences

One list matcher runs every list stage and every `Adjacent` and `Sibling` link. The prototype found the time on real pages goes to finding parents and slicing their children: about 44 ms on the CSS page (6,275 elements) before any matching, against 35 ms for today's `Child`. List stages run 50–110 ms there, against soupsieve's 4–8 ms, which is the same ratio as today's combinators.

The matcher is `ReplaceList` over a parent's element children, with the entries before the selected one matched as one named `PatternSequence`, whose length is the selected child's index. Two shapes are matched without enumerating, as they select the same children: `{___, c, ___}` with no other entry is the children `c` matches, found by `Position`, since `ReplaceList` builds the sequence before each match and costs the square of the children (300 ms against 1 ms over 5,000 siblings); and an `Adjacent` link reads `{b, ___}` over the children after a site, which needs only the next one, so the sites under one parent are tested together. A `Sibling` link reads `{___, b, ___}` over the children after the earliest site under a parent when the stages decide, and after each choice otherwise, as before.

Measured on a 2026 laptop (median of five), before and after:

| Query | Before ms | After ms |
|---|--:|--:|
| 1,000 rows, `Adjacent[tr.a, tr.b]` (500 results) | 2.1 | 3.2 |
| 1,000 rows, `Sibling[tr.a, tr.b]` | 2.8 | 3.1 |
| 1,000 rows, `Adjacent` with a shared name, no pair | 6.0 | 7.4 |
| 1,000 rows, `Sibling` with a shared name, no pair | 3,904 | 3,912 |
| 1,000 rows, `Sibling[…] /; True` | 15.9 | 15.6 |
| 5,000 sibling `div`s, `Adjacent[div, div]` | 13.0 | 13.6 |
| 5,000 sibling `div`s, `Sibling[div, div]` | 15.9 | 15.0 |
| CSS page, `div.mw-heading + p` | 21.8 | 22.8 |
| CSS page, `div.mw-heading ~ table` | 23.0 | 21.8 |
| 5,000 `div`s, `Child[div, p]` (no list) | 32.9 | 33.6 |
| CSS page, `tr > th` (no list) | 3.7 | 3.8 |
| 1,000 rows, `XMLDeleteCases` with `Adjacent` | refused | 2.3 |

List stages on the 1,000-row table, as `Child[XMLPattern[_], {…}]`, matched in full: `{c, ___}` 25 ms, `{___, c}` 24 ms, `{Repeated[_, {499}], c, ___}` 25 ms, `{PatternSequence[_, _] ..., c, ___}` 40 ms (500 results), `{___, c, Repeated[_, {0, 2}]}` 26 ms, `{___, a, b, ___}` 34 ms, and `{___, a, ___, b, ___}` 2.3 s. Most of the 25 ms is finding the parents: every element matches `XMLPattern[_]` and has its children listed. `XMLDeleteCases` with `{PatternSequence[_, _] ..., c, ___}` takes 40 ms. On the CSS page, `Descendant[XMLPattern["div"], {XMLPattern["p"], ___}]` takes 45 ms and `p:nth-of-type(2)` as a list 93 ms.

As built, three points are narrower than the decision above:

- A context combinator entry's later stages bind names for its own test only. A name bound there and used elsewhere in the pattern is refused (`::listentry`), and a rule body does not see them. Running the test from a single child cannot return the names it bound, and the chain runner has one tuple per chain, not a branch for each context entry.
- Alternatives that hold a combinator can be the selected entry, which makes one chain per alternative, but not a context entry, which is refused (`::listentry`).
- A refused list gives `::liststage` (the list cannot stand there, or has no XML-pattern entry) or `::listentry` (an entry is a list, an `XMLElement` pattern, a combinator whose first stage is a list, or one of the two cases above), each with the reason, rather than `::badpat`.

A raw `XMLElement` pattern is refused as an entry, though it is still accepted as an element pattern elsewhere. When raw `XMLElement` patterns are dropped everywhere (GitHub issue #31), this refusal becomes part of that one.

`FromCSSSelector` writes the child-indexed pseudo-classes as list stages (ADR 0017).

Possible Issues, for documentation:

- A list stage after an element pattern does not select the root, though a browser's `:first-child` and `:only-child` match it. After `XMLDocument[] | XMLPattern[_]` it does (ADR 0018).
- A list sees element children only. A named list or a named sequence entry gives the elements without the text between them.
- A list with two unbounded gaps around context entries, such as `{___, a, ___, b, ___}` written out, is quadratic in the number of children when matched in full: 2.3 s at 1,000 children.
- A combinator as a context entry searches below every candidate sibling, as `:has` does.
- A literal list as the whole query is refused, not read as alternatives.
- There is no marker for selecting an entry that is not last, so `:has(+ b)` and `:has(~ b)` have no list form.
