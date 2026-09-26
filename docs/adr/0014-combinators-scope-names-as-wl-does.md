---
status: accepted
---

# A combinator is one plain pattern over its stages, and its names scope as WL's do

A structural combinator — `Child`, `Descendant`, `Adjacent`, `Sibling` — relates the elements matched by its **stages**, and a stage may itself be a combinator. The paclet reads the whole thing as one plain WL pattern over the list of its stages' elements, `{s1, …, sn}`, and gives every name in it exactly the scope that list pattern would give: a `Condition` on a stage sees that stage's names, a `Condition` on the combinator sees all of them, a name at two stages is one value, and a `PatternTest` sees none. This is ADR 0011's "everything inside is a plain WL pattern" carried from the element up to the combinator.

## Context

Before this decision each unnested combinator had its own code in each consumer, a combinator could not be a stage, and a `Condition` on a combinator was refused (`::condcombinator`, v1.2.4, recorded in no ADR). ADR 0012's materialisation made this visible: when a query names a list key, element and attribute-map names are renamed and restored stripped around the places that can see them, and a later stage's `/; test` then saw an unbound name where the user expected an earlier stage's value.

The first fix (2f8587b) made that expectation true: a later stage's test was wrapped in every earlier stage's bindings. It worked, and it was the wrong rule. In WL the test in `{a_, b_ /; test}` does not see `a` — `MatchQ[{1, 2}, {a_, b_ /; a == 1}]` is `False` — because a `Condition` sees only the names bound inside the pattern it wraps. The user's ruling was to follow WL exactly, with the precedent already set by `{a_, a_}`, which matches `{2, 2}` and not `{1, 2}`: WL has an answer for each of these questions, and a user who knows WL should not have to learn a second one.

## Decision

### Scoping follows the tuple pattern `{s1, …, sn}`

- A `Condition` on a stage sees only that stage's names. `Child[XMLPattern["div", "id" -> a_], XMLPattern["p"] /; a === "x"]` matches nothing, as its list analogue does.
- A `Condition` on a combinator sees every name of every stage inside it, and `(comb /; test) :> body` is accepted. On a combinator that is itself a stage, the test sees only that combinator's stages. An element or attribute-map name is the original, stripped element in the test, as it is in a rule body (ADR 0012).
- A name at two stages means one value: `Descendant[XMLPattern["div", "id" -> a_], XMLPattern["p", "id" -> a_]]`. Element and attribute-map names compare as the stripped originals, so a list key at one stage does not make them differ.
- A `PatternTest`'s function sees no pattern names, as in WL, whether or not the name is bound elsewhere.
- A rule body sees every stage's names.

The refusals are the shapes that have no tuple-pattern reading: an `Alternatives` holding a combinator (as the query or as a stage, conditioned or not) and a named combinator (as a stage or as the query) are `::badpat`. `XMLMatchQ` and the `Roles`/`Constructs` options take an element pattern, so they still refuse a combinator, conditioned or not (ADR 0013).

### A combinator of combinators is a chain, read left to right

A combinator whose stage is a combinator reads as a chain, as a CSS selector does: `Descendant[a, Child[b, c]]` and `Child[Descendant[a, b], c]` are both the chain *a* Descendant *b* Child *c*, and select the same elements. Every combinator query, nested or not, runs through one code path on positions in one tree: the tree is materialised once per query over the union of the list keys all stages name, and stripped once, at the output.

### What a query returns, and in what order

The result is the last stage's elements, each once, in the order a base `XMLCases` would return them — `Cases` order, so a nested element comes before its ancestor. `XMLFirstCase` returns the first of that order.

The root may match any stage but the last, and is never a result, as base `XMLCases` never returns the tree it is given. Only a bare `XMLElement` input is affected: the root element of an `XMLObject` document and the top-level elements of a list are already below the tree, so base `XMLCases` returns them, and they could be any stage before. In practice the root can only be the first stage, as every later stage is below or beside an earlier one; the root has no siblings, so an `Adjacent` or `Sibling` link after it selects nothing. `Child[XMLPattern["body"], XMLPattern["div"]]` on a bare `body` element gives its `div` children, as `XMLDeleteCases` already deleted them.

A combinator query returns each matched element once, as the DOM's `querySelectorAll` and BeautifulSoup's `select` (soupsieve) do: CSS combinators select elements, not paths to them.

- `Sibling[before, after]` matches an `after` element that has *some* earlier sibling matching `before` such that the pair satisfies any shared name and any combinator `Condition`. A `before` name used in a rule body binds to the first such sibling in document order. `Sibling[Adjacent[a, b], c]` accordingly gives each `c` once.
- `Descendant[ancestor, desc]` matches a `desc` element that has *some* ancestor matching `ancestor` with which the whole pattern matches. An `ancestor` name used in a rule body binds to the first such ancestor in document order, which is the outermost; with a shared name or a combinator `Condition`, an inner ancestor serves when it is the only one that qualifies. `Descendant[a, Child[b, c]]` gives each `c` once, however many `a` ancestors its parent has.

Where several earlier stages could be chosen, the choice is the first in document order at the latest such stage, then at the one before, and so on.

### `XMLDeleteCases`

`XMLDeleteCases` accepts `Child` and `Descendant`, nested in each other and with a combinator `Condition`, and deletes the elements the last stage selects; parents are matched against the original tree, and the root may match any stage but the last, as for `XMLCases`. Giving each element once does not change what is deleted. `Adjacent` and `Sibling` stay `::unsupported` at any depth.

## Considered options

- **Cross-stage visibility for stage conditions** — built in 2f8587b and reverted. Convenient, and exactly the case where WL gives the other answer; the combinator `Condition` asks the same question in WL's own terms.
- **Refusing a name repeated across stages** (`::stagename`, also 2f8587b) — built and reverted. The repeated name was previously an internal error (`RuleDelayed::rhs`), so a refusal was an improvement, but `{a_, a_}` already says what it should mean.
- **One result per `(before, after)` pair for `Sibling`, or per matching ancestor for `Descendant`** — rejected. It duplicates elements the user asked for once, and differs from CSS's `~` and descendant combinator, which select elements, not pairs. `Descendant` gave one result per ancestor until it was aligned with `querySelectorAll` and soupsieve.
- **Keeping the root out of `XMLCases` and `XMLFirstCase` chains** — rejected. `XMLDeleteCases` already let the root be the first stage, and a bare `body` element is a natural input for `Child[XMLPattern["body"], …]`. Returning the root stays excluded, as base `XMLCases` excludes it.
- **Keeping per-combinator code beside the chain runner** — rejected. The unnested code had its own bugs (an unbound `before` name in the `Sibling` rule form; siblings directly under a bare root missed), and two paths would have had to agree on every scoping rule above.

## Consequences

Measured at 5 000 elements during the rework: plain combinators run about twice as slowly as their dedicated code did (`Child` 3.6 → 7.5 ms), nested chains faster (30 → 17 ms), and `XMLDeleteCases` with `Child` much faster (15 → 4 ms). A tuple is matched against the whole tuple pattern only when a combinator `Condition` or a repeated name needs it; otherwise the stages' own matches decide. When they decide, `Descendant` searches below the outermost matching ancestors only: over 50 nested `div`s of 100 `p` each, `Descendant[XMLPattern["div"], XMLPattern["p"]]` fell from about 600 ms, pairing every `p` with each of its ancestors (127 500 pairs), to about 18 ms.

The order convention is a reversal for anyone reading `Descendant[a, b]` as "for each `a`, its `b`s": results follow `Cases`, not the first stage.

Possible Issues, for documentation:

- A stage `Condition` cannot see another stage's names; move the test onto the combinator.
- A name shared across a `Descendant` link, or a combinator `Condition` over one, still pairs every element with every matching ancestor before choosing one: the cost is the depth times the elements. Measured ≈ 0.9 s for the 50-deep tree above with `/; True`.
- A name shared across a `Sibling` link is quadratic in the length of the sibling list when candidates fail: every earlier sibling is tried for every later one. Measured ≈ 3.6 s at 1 000 siblings where no pair matches, quadrupling per doubling (≈ 15 s at 2 000); a few tenths of a second at 5 000 when matches exist.
