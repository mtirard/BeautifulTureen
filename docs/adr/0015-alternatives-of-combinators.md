---
status: accepted (amended by ADR-0016)
---

# Alternatives of combinators read as WL alternatives, and the first alternative that accepts an element binds its names

> **Amended by [ADR 0016](./0016-list-stages.md)** (2026-10-02). `XMLDeleteCases` accepts `Adjacent` and `Sibling`, so an alternative holding one no longer makes the query `::unsupported`. Alternatives of list stages are a stage, read as here.

ADR 0014 refused an `Alternatives` holding a combinator as having "no tuple-pattern reading". It has one: `Child[a, b] | Descendant[c, d, e]` reads as `{a, b} | {c, d, e}`, an ordinary WL pattern. What actually stood in the way was that each query compiled to one chain and ran as one pass. CSS selector lists (`a > b, c d e`) need the shape, and running the alternatives as separate queries and joining the results is wrong: on the CSS page it loses 17 identical elements, and padding the alternatives to one shape costs 0.2–2.3 s (probes summarised in `.scratch/css-selectors/issues/01-decide-the-shape-of-the-css-selector-front-end.md`). This ADR lifts the refusal.

## Decision

### Reading

Alternatives of [[XML pattern]]s, combinators among them, are an XML pattern, and read as WL's `Alternatives` over the list patterns of their combinators. They are accepted as the query, as a [[Stage]], and conditioned, in either place. An alternative may be an [[Element pattern]]: `XMLPattern["p"] | Child[a, b]` reads as `{p} | {a, b}`. An alternative that is an element pattern selects what a plain query with it selects, so it never returns the root.

As a stage, they splice into the chain as any stage does: `Child[x, Descendant[c, d] | e]` reads as `{x, PatternSequence[c, d] | e}`, and is the chains *x* Child *c* Descendant *d* and *x* Child *e*. The link before the stage attaches to the first stage of each alternative.

`Child[a | b, c]`, alternatives of element patterns as a stage, is unchanged: one chain whose stage is an element pattern.

### Names

- A name bound only in an alternative that did not match is `Sequence[]`, as in WL, in a rule body, in a `Condition` on the alternatives, and in a `Condition` on a combinator that holds them. `{i, j}` in a body is then a list of length 1.
- A name in several alternatives is one name, bound by the alternative that matched.
- A name shared between an alternative and a stage outside the alternatives must agree only when that alternative matched.
- Within an alternative, ADR 0014's scoping holds unchanged. A `Condition` inside one alternative does not see the names of another, which are then neither bound nor `Sequence[]`, as in WL, where the test in `{x_ /; test} | {y_, _}` sees the global `y`.

### Which alternative binds

A combinator query still returns each element once, in [[Document order]] (ADR 0014). When several alternatives select one element, the **first alternative, in written order, that accepts it** binds the names and gives the rule-body value, as `Cases` does: `Cases[{{1, 2}}, {x_, 2} | {_, x_} :> x]` gives `{1}`. An alternative is rejected, and the next one tried, when a `Condition` on the alternatives, a `Condition` on a combinator that holds them, or a `Condition` in the rule body rejects every one of its tuples. Within an alternative, ADR 0014's rule chooses the tuple.

The choice of alternative ranks above every choice of stage, wherever the alternatives sit in the chain. With several stages that are alternatives, the combinations are tried in lexicographic order of the written alternatives, the leftmost most significant. So in

```wl
Descendant[XMLPattern["div", "id" -> i_],
  XMLPattern["a", "id" -> i_] | Child[XMLPattern["p"], XMLPattern["a"]]] :> i
```

on `<div id="x"><div id="y"><p><a id="y"/></p></div></div>`, the first alternative accepts the `a` with the inner `div`, and the result is `"y"`, though the outer `div` would satisfy the second alternative.

### Consumers

- `XMLCases` gives the elements any alternative selects, each once, in document order; a rule body is evaluated once for each.
- `XMLFirstCase` gives the first of these in document order, with the value from the first alternative that accepts it.
- `XMLDeleteCases` deletes the elements any alternative selects. An `Adjacent` or `Sibling` link in any alternative makes the query `::unsupported`, as for one chain.
- `XMLMatchQ` and the `Roles`/`Constructs` options take an element pattern, and refuse alternatives holding a combinator as they refuse a combinator (ADR 0013).

### Refusals that stay

A named combinator, and named alternatives holding a combinator (`u : (Child[a, b] | c)`), are `::badpat`, as a stage or as the query. In WL a named `PatternSequence` binds a `Sequence` of the elements, which would say nothing about how they relate in the tree, and nothing in CSS needs it.

## Considered options

- **Left to right: the earlier stage's choice first, then the alternative.** In the example above it gives `"x"`. It follows how WL backtracks through a list pattern, but WL never chooses among several tuples, so it does not settle this, and it runs opposite to ADR 0014's existing choice, the latest stage first. Rejected for one rule that fits the existing code.
- **The first match in document order across all alternatives' tuples.** It is not what `Cases` does when one expression matches two alternatives.
- **Running each alternative as its own query and joining the results.** It loses elements the alternatives share, and gets the order and the bindings wrong.
- **Allowing named alternatives of combinators, bound to the `Sequence` of elements.** Deferred, together with named combinators, until something needs it.
- **Matching each element against every alternative, as browsers and soupsieve match a selector list right to left.** It would be a second engine beside the left-to-right chain runner.

## Consequences

Alternatives that hold combinators are run as the list of their alternatives' chains, in disjunctive normal form, one materialisation shared, and merged per element, as XPath's `union` merges node sets into document order without duplicates. A stage that is alternatives multiplies: *k* such stages of two alternatives each give 2^*k* chains, each run in full. A CSS selector list of *n* selectors gives *n*.

A query without alternatives of combinators runs as before. Measured on a 2026 laptop, a query without them was unchanged within noise: on 5 000 `div`s each holding a `p`, `Child[div, p]` 34.5 → 34.2 ms and `Child[div | section, p]` 34.3 → 35.1 ms; on the CSS page, `tr > th` 3.7 → 3.7 ms. A union costs about the sum of its alternatives run as separate queries, plus the merge: on the CSS page, `tr > th | table code` 6.3 ms against 3.7 + 3.2 ms, and with `div.mw-heading + p` as a third alternative 30 ms against 28 ms. On the 5 000 `div`s, `Child[div, p] | Child[body, div.c3]` took 86 ms against 59 ms for the two queries, and a third alternative selecting one `p` 92 ms against 62 ms: one alternative names a list key, so all of them run on the materialised tree and the 5 714 results are stripped, which the separate query without a list key does not pay. `XMLFirstCase` on `p | tr > th`, whose first match is early, took 4.5 ms: the element pattern stops at its first match (1.5 ms alone), but a chain alternative runs in full, as one chain does in `XMLFirstCase` (3.7 ms alone), and so does an element-pattern alternative when the rule body can reject, as its body is the test.

Running alternative after alternative changes one thing a single chain does not have: a rule body that can reject (`:> body /; test`) is tried on each candidate of the first alternative, then of the next, not on all candidates in document order. Each result's body is still evaluated once, and a site an earlier alternative accepted is not tried again.

Possible Issues, for documentation:

- A name bound only in another alternative is `Sequence[]`, and disappears from a list in the body.
- Of overlapping alternatives, the first that accepts an element binds the names, even where a later alternative would bind them through an earlier ancestor.
- Each stage that is alternatives multiplies the chains run.
