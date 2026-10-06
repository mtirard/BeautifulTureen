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

Every other list stage runs on the general matcher: `ReplaceList` of the select rule over each parent's children.

## Consequences

The `{___, s, ___}` shape is recognised in one place, the compiler, from the list stage as compiled, and the list matcher no longer re-matches the select rule's shape at run time. Recognition still reads the compiled list's entries, so a change to how list stages are compiled must keep the recognisers in step. Behaviour and timing are unchanged: the performance tests measured the same before and after.

Later shapes (positions among all children, and counted positions with `of S` and `-of-type`) are added to the list with their tests, as the spec's later steps land.
