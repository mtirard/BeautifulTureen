---
status: accepted (supersedes ADR-0014 and ADR-0015 with ADR-0023; supersedes ADR-0019 in part; amended: evaluation of tests in the pattern)
---

# A query gives one result per distinct tuple of positions of its counted names

Once patterns are trees (ADR 0023) there is no last stage to select, and CSS's implicit subject has nothing to attach to. Something else must say what a query gives.

## Decision

### The result rule

A query `lhs :> rhs` gives **one result for each distinct tuple of positions of its counted names**. A name **counts** if the right-hand side uses it outside the tests of `Condition`s (through `With` initialisers, and every name of a `Module` or `Block` that has a test). Unnamed parts and uncounted names are tests that need one passing match. Equal values at different positions are different results.

This is the database rule: tree-pattern matches projected onto the named nodes with set semantics, as in Datalog heads, twig queries and SPARQL `SELECT DISTINCT`. It is not `ReplaceList`, which counts every way the unnamed parts match.

There is **no implicit result**. A bare pattern `p` is erased to `r$ : p :> r$` before any consumer reads it, so it gives its matches as `Cases` does. A rule whose right-hand side uses no names gives at most one result: `XMLCases[t, XMLPattern["a"] -> 1]` is `{1}`, unlike `Cases`.

### Order

Results are a nested loop over the counted names in pattern order, the first name slowest (XQuery's `for` order). Each name runs in position order: by where a position starts in the source, a container before what it holds. One `Alternatives` is one slot. Uncounted names take their first passing position. `XMLCases[t, q, n]` counts results in this order (ADR 0019); `XMLFirstCase` gives the first.

### Evaluation (amended)

The right-hand side, with the `Condition`s it tests, is evaluated in result order, once per result tried, and only until there are `n` results. The tests in the pattern carry no such promise:

- a `Condition` or `PatternTest` in the pattern may be evaluated on candidates past the `n`-th result, and before any result is given;
- a `Condition` in the pattern may be evaluated once per distinct tuple of the places (parts of the tree) that the names it tests bind, in no promised order, and a `PatternTest` once per element it tests.

So `Reap[XMLCases[t, XMLPattern["li"]?((Sow[#]; True) &), 2]]` gives the first two `li` and may sow every `li`. Code whose side effects or cost depend on how often, or in which order, a test in the pattern runs must move that code to the right-hand side.

The reason is the engine: the query engine matches each part of a pattern against all candidates at once, as columns of integers, which is several times faster on pages with many results than visiting candidates one at a time, and a test that stopped at the `n`-th result would need the visit order back.

### Every consumer reads the same rule

The pattern and what a consumer acts on are one object:

- `XMLCases` and `XMLFirstCase` evaluate the right-hand side per tuple; `XMLPosition` replaces the names by positions;
- `XMLDeleteCases[t, lhs :> names]` deletes the named positions, which reverses the refusal of rules there, and `HTMLToTree`'s `"Hide"` and `"Focus"` act on them;
- `XMLReplace[t, lhs :> {x -> new}]` replaces the named positions, only the left sides counting; any other right-hand side replaces the pattern root;
- `XMLMatchQ` and element-test keys of `"Roles"` and `"Constructs"` test the left side as the pattern root; a key that is a rule is a query whose counted elements get the value.

## Considered options

- **Every name counts.** A name used only in a `Condition` would multiply results that the user asked for once.
- **`ReplaceList` semantics.** It counts unnamed parts: `f[___, x_, ___, _, ___] :> x` on `f[a, b, c, d]` gives `{a, a, a, b, b, c}`.
- **The pattern root as an implicit result**, with names adding more. It keeps a subject, and a named context element would still need a rule to drop it.
- **A `Target` marker** for what rewriting consumers act on. Two objects to keep in step; the right-hand side already names the parts.
- **Innermost name slowest, right-hand-side order, matcher order** for results. The first has no meaning without a subject; the second reads arbitrary code; the third is implementation-defined.
- **A collecting form** (CDuce `x::R`, Specter `collect`). Named runs and nested queries in the right-hand side cover it; it may return as a convenience.

## Consequences

- Results are identified by position, not value, so the implementation carries positions; `DeleteDuplicates` on values is wrong.
- The docs must teach that results multiply by the names used, not by matches, with `Cases` as the contrast.
- Each counted name can multiply cost and results by the size of the input; unnamed parts are linear existence tests.
