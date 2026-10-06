---
status: accepted
---

# CSS translates to a visible XML pattern, and the compiler recognises shapes of it and runs them by dedicated methods

Some queries are orders of magnitude slower than queries that look no harder. On a 2,032-element page `li a` takes 4 ms and `li:first-child a` 30 ms, and `tr:nth-child(2n+1 of .a)` over 1,000 siblings takes 6.6 s, because its translation is a `Count` inside a `Condition` that `ReplaceList` tests on every split of the list. No value said how a query runs. The compiler gave a compiled query that said what it means, and each runner decided at run time how to run it. Speed-ups went into two places, neither written down as a guarantee: the translator, which writes a faster equivalent pattern (ADR 0017, positions moved along a `+` run), and the list matcher, which recognised the exact pattern shape that the select-rule builder wrote 60 lines away (`{___, s, ___}`, ADR 0016's Consequences). Settled in the architecture review of 2026-10-06 and its spec, `.scratch/compiled-query-plan/spec.md`.

## Decision

### The pipeline

A query goes one way: a CSS selector translates to a visible, WL-native XML pattern, with `Condition`, `PatternTest` or `Except` where it needs them, and the compiler compiles that pattern into a compiled query. The translator emits no private head, and there is no path from CSS to a compiled query that skips the XML pattern. A CSS-side optimisation is a choice of which pattern to emit, in a shape the compiler recognises.

### Recognised shapes

The compiler may recognise a **shape** of XML pattern and run it by a dedicated method, with the same results, in content, order, count and bindings, as WL's matcher gives on the pattern as written. A recognised shape is a performance guarantee: it is listed below, each with a performance test in `Tests/Performance` whose time limit fails `make test` when the shape stops being recognised. A pattern written in a shape that is not recognised gives the same answer, only more slowly. Recognition is never a condition of correctness.

The decision is made once, by `compileQuery`, from the query alone and never from the tree, and is recorded in the compiled query: each list stage carries its method, a recognised shape with its parameters or the general matcher with its rule. The runners read the method and do not inspect the pattern.

A private switch, `$recogniseShapes`, turns recognition off for an evaluation (`Block[{$recogniseShapes = False}, …]`), so that every list stage runs on the general matcher. It is for tests and maintainers, to check a recognised method against WL's matcher on the same input (`Tests/Unit/RecognisedShapes.wlt`). The compiled query records whether recognition was on, and the `XMLMatchQ` operator-form cache keys on the switch.

### Compounds are intersected on the CSS side

The translator intersects the simple selectors of a compound in its own branch form, before it projects the result to an `XMLPattern`. An intersection may need a disjunction, such as several tags or two constraints on one key, that a single `KeyValuePattern` cannot hold, so it cannot be done after the projection.

### The list of recognised shapes

Positions count the element children of one parent, with text left out, as list stages do (ADR 0016).

| # | Shape | Method | Performance test |
|---|---|---|---|
| 1 | Anywhere: `{___, C, ___}`, where `C` is the selected entry (named or not, with its own tests), with no other entry and no name, `Condition` or test on the list | each child that `C` matches, found by `Position`, in one pass over each parent's children | `perf-shape-anywhere-10000-siblings` |
| 2 | Position from the start among all children: `{P…, C, ___}`, where the entries `P` before `C` match a number of children in an arithmetic set `{B, B + A, B + 2A, …}`, bounded or not: `{C, ___}` (`:first-child`), `{Repeated[_, {k}], C, ___}` (`:nth-child(k+1)`), `{Repeated[_, {0, k}], C, ___}` (negative A), `{_ (×r), PatternSequence[_ (×A)]..., C, ___}` (positive A), `{Except[_], C, ___}` (no position), and the same counts written by hand with `_`, `__`, `___`, `Repeated` and `RepeatedNull` of `_` or `PatternSequence[_, …]`. No entry is named or tested, no repeat has two lengths of step (`{Repeated[_, {0, 1}], PatternSequence[_, _]..., C, ___}` is not recognised), and, as for shape 1, `C` is the only XML-pattern entry, with no name, `Condition` or test on the list | the indices the set allows, computed once per parent from the number of children, and `C` tested at those alone; a parent with no child that `C` matches is passed over | `perf-shape-from-start-5000-siblings` |
| 3 | Position from the end among all children: the mirror of 2, `{___, C, P…}`, including `{___, C}` (`:last-child`) and `{___, C, _}` (`:nth-last-child(2)`). A list with positions at both ends, such as `{C}` (`:only-child`) or `{_, C, Repeated[_, {2}]}`, is both 2 and 3: the indices both sets allow | as 2, counting from the end | `perf-shape-from-end-5000-siblings` |

Every other list stage runs on the general matcher: `ReplaceList` of the select rule over each parent's children.

### Context entries are compiled once

A context combinator entry of a list stage (ADR 0016) is compiled once, with the query, as a chain of its own in the compiled query's `"ContextEntries"`, with its stages, tuple test and two-step match built and any list stage in it given its method. A run tests a child against it from that child's site, at most once per child, and builds nothing for it. This is a property of the compiled query, not a recognised shape: a list stage with a context entry is in no shape above and runs on the general matcher. Its cost is then the general matcher's. `Child["body", {___, Child["div", "p"], "div.c3", ___}]` over 3,000 siblings takes about 70 ms (`perf-context-entry-3000-siblings`), but with `___` between the two entries it takes about 39 s, because `ReplaceList` enumerates every split of the list that places the two entries, and it is about as slow with the context entry's test replaced by `True`. Making that linear would mean recognising lists with context entries, which this decision leaves out.

## Consequences

The `{___, s, ___}` shape is recognised in one place, the compiler, from the list stage as compiled, and the list matcher no longer re-matches the select rule's shape at run time. Recognition still reads the compiled list's entries, so a change to how list stages are compiled must keep the recognisers in step. Behaviour and timing are unchanged: the performance tests measured the same before and after.

Shapes 2 and 3 make a position among all children cost about what the selector without it does: on the 2,032-element `Tests/assets/wolfram-language.html`, `li:first-child a` and `li:nth-child(2n+1)` went from about 28 ms to 9 ms, against 4 ms for `li a`. Most of what remains is visiting every element as a possible parent, since the translation's parent stage, `XMLDocument[] | XMLPattern[_]`, matches every element. A fixed position such as `:nth-last-child(3)` was already fast on one long list, since WL's matcher places a fixed-length prefix or suffix at once, so its performance test would not tell the shape apart; the tests use `2n+1`, which the general matcher tries at every split.

The arithmetic sets of lengths, and which lengths up to a bound they hold, are decided in one place (`lengths`, `lengthsUpTo`), for the counted positions to reuse. Shape 1 also passes over a parent with no child that `C` matches, which took `Child[XMLDocument[] | XMLPattern[_], {___, XMLPattern["li"], ___}]` on that page from about 29 ms to 9 ms.

Later shapes (counted positions with `of S` and `-of-type`) are added to the list with their tests, as the spec's later steps land.
