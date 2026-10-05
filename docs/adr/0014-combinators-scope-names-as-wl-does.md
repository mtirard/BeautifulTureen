---
status: accepted (amended after implementation; amended by ADR-0015, ADR-0016 and ADR-0018)
---

# A combinator is one plain pattern over its stages, and its names scope as WL's do

A structural combinator — `Child`, `Descendant`, `Adjacent`, `Sibling` — relates the elements matched by its **stages**, and a stage may itself be a combinator. The paclet reads the whole thing as one plain WL pattern over the list of its stages' elements, `{s1, …, sn}`, and gives every name in it exactly the scope that list pattern would give: a `Condition` on a stage sees that stage's names, a `Condition` on the combinator sees all of them, a name at two stages is one value, and a `PatternTest` sees none. This is ADR 0011's "everything inside is a plain WL pattern" carried from the element up to the combinator.

> **Amended after implementation.** A `Condition` in a rule's body (`comb :> body /; test`) now takes part in choosing an ancestor or earlier sibling, as a `Condition` on the combinator does; before, the first candidate was chosen without it, and a body that rejected that candidate lost the match. Written into "What a query returns, and in what order".
>
> **Amended by [ADR 0015](./0015-alternatives-of-combinators.md)** (2026-10-02). An `Alternatives` holding a combinator is no longer refused: it reads as WL's `Alternatives` over the combinators' list patterns, and the first alternative that accepts an element binds its names. A named combinator, and named alternatives holding one, stay `::badpat`. The refusal sentence in "Scoping follows the tuple pattern" is superseded.
>
> **Amended by [ADR 0016](./0016-list-stages.md)** (2026-10-02, not yet implemented). A stage after a `Child` or `Descendant` link may be a list stage, a WL list pattern over a parent's element children, and it reads as that list nested in the tuple pattern. `Adjacent` and `Sibling` are now shorthands for list stages. `XMLDeleteCases` accepts them: the last sentence of "`XMLDeleteCases`" and the refusal in "A combinator of combinators is a chain" are superseded.
>
> **Amended for issue #33.** A test `pat?f` is accepted on an element pattern and on a stage, but a test on a combinator, `Child[a, b]?f`, is refused with `::testcombinator`. It could only test the selected element, which `Child[a, b?f]` already says. To be reopened when a CSS selector string (ADR 0017) can be a combinator, as `"ul > li"?f` would then be the only way to test its selected element. Written into "Scoping follows the tuple pattern".
>
> **Amended by [ADR 0018](./0018-the-document-above-the-top-elements.md)** (2026-10-02, not yet implemented). Every input has a document above its top elements, matched by `XMLDocument[]` as a first stage. The root is then a second stage under it, not only a first stage. A list input's top-level elements are siblings, so `Adjacent` and `Sibling` match across them. The rest of "The root may match any stage but the last" stands: the input is never a result. `XMLDeleteCases` does not delete a document's root element (`::root`).
>
> **Amended for issue #11.** A combinator takes two or more stages; `L[s1, s2, …, sn]` reads as the right-nested chain. Written into "A combinator of combinators is a chain, read left to right".

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

The refusals are the shapes that have no tuple-pattern reading: an `Alternatives` holding a combinator (as the query or as a stage, conditioned or not) and a named combinator (as a stage or as the query) are `::badpat`. `XMLMatchQ` and the `Roles`/`Constructs` options take an element pattern, so they still refuse a combinator, conditioned or not (ADR 0013). A test on a combinator, `comb?f`, is refused with `::testcombinator` wherever it is written: it would restate a test on the last stage.

### A combinator of combinators is a chain, read left to right

A combinator whose stage is a combinator reads as a chain, as a CSS selector does: `Descendant[a, Child[b, c]]` and `Child[Descendant[a, b], c]` are both the chain *a* Descendant *b* Child *c*, and select the same elements. Every combinator query, nested or not, runs through one code path on positions in one tree: the tree is materialised once per query over the union of the list keys all stages name, and stripped once, at the output.

A combinator with more than two stages is the right-nested chain of its one link: `L[s1, s2, …, sn]`, for any of the four heads `L`, is exactly `L[s1, L[s2, …, L[s(n-1), sn]]]`, the chain *s1* L *s2* L … L *sn*. It is expanded where the query is compiled, before its normal form is built, so it has the same stages, links and conditions as the nested form and every consumer treats it as that form: the same matches, document order, name scoping and rule-body bindings, and the same refusals (`XMLMatchQ` and the `Roles`/`Constructs` rules still refuse it, as any combinator; `XMLDeleteCases` refuses `Adjacent` and `Sibling`). A `Condition` on such a combinator covers all its stages, as one on the outermost combinator of the nested form does. One call has one head, so a chain that mixes links nests a combinator as a stage: `Descendant[a, Child[b, c], d]` is `Descendant[a, Descendant[Child[b, c], d]]`. A combinator with one stage or none relates nothing and is refused with `::stages`, whose message says a combinator needs at least two.

### What a query returns, and in what order

Every query, plain or combinator, returns its results in **document order**, the DOM's tree order: an element before the elements nested in it, an earlier sibling and its subtree before a later sibling, as `querySelectorAll` and soupsieve's `select` return them. A combinator's result is the last stage's elements, each once, in document order; a rule body is evaluated once for each, in that order. `XMLFirstCase` returns the first in document order — of nested matches the outermost, as `querySelector` does — and evaluates a rule body for that match only. "First in document order" means this same order wherever it is used below, for a `Sibling` or `Descendant` binding as for a result.

The root may match any stage but the last, and is never a result, as base `XMLCases` never returns the tree it is given. Only a bare `XMLElement` input is affected: the root element of an `XMLObject` document and the top-level elements of a list are already below the tree, so base `XMLCases` returns them, and they could be any stage before. In practice the root can only be the first stage, as every later stage is below or beside an earlier one; the root has no siblings, so an `Adjacent` or `Sibling` link after it selects nothing. `Child[XMLPattern["body"], XMLPattern["div"]]` on a bare `body` element gives its `div` children, as `XMLDeleteCases` already deleted them.

A combinator query returns each matched element once, as the DOM's `querySelectorAll` and BeautifulSoup's `select` (soupsieve) do: CSS combinators select elements, not paths to them.

- `Sibling[before, after]` matches an `after` element that has *some* earlier sibling matching `before` such that the pair satisfies any shared name and any combinator `Condition`. A `before` name used in a rule body binds to the first such sibling in document order. `Sibling[Adjacent[a, b], c]` accordingly gives each `c` once.
- `Descendant[ancestor, desc]` matches a `desc` element that has *some* ancestor matching `ancestor` with which the whole pattern matches. An `ancestor` name used in a rule body binds to the first such ancestor in document order, which is the outermost; with a shared name or a combinator `Condition`, an inner ancestor serves when it is the only one that qualifies. `Descendant[a, Child[b, c]]` gives each `c` once, however many `a` ancestors its parent has.

Where several earlier stages could be chosen, the choice is the first in document order at the latest such stage, then at the one before, and so on.

A rule whose body can reject — a `Condition` at the top of the body, or under `With`, `Module` or `Block` — is matched where it gives a value, as `Cases` matches a rule: a candidate counts only if the body accepts it, so `Descendant[XMLPattern["div", "id" -> i_], XMLPattern["p"]] :> i /; i == "inner"` binds `i` to the inner `div` when the outer one is rejected. The value is kept from that test, so the body is evaluated once for each result, as `Cases` evaluates it. A candidate that is tested and rejected evaluates the body up to its `Condition`, as it would in `Cases`.

A query `pattern -> rhs` is read as `Cases` reads a `Rule`: `rhs` is evaluated once, when the query is given, and its value is then the body of `pattern :> value`, so the names the pattern binds are replaced in it by what they matched, and with a global value on a name the value is used, as `Cases[{1, 2}, x_ -> x]` gives `{5, 5}` after `x = 5`. Everything else is as for `:>`: the matches, their order, the conditions, the combinators and the list-key and element names (ADR 0012), whose renaming happens after `rhs` has been evaluated, on the value. One difference from the `:>` body: a `Condition` in the value is part of it, not a test that can reject a candidate, as in `Cases`, where `Cases[{1, 2}, x_ -> (x /; x > 1)]` gives `{1 /; 1 > 1, 2 /; 2 > 1}`.

### `XMLDeleteCases`

`XMLDeleteCases` accepts `Child` and `Descendant`, nested in each other and with a combinator `Condition`, and deletes the elements the last stage selects; parents are matched against the original tree, and the root may match any stage but the last, as for `XMLCases`. Giving each element once does not change what is deleted. `Adjacent` and `Sibling` stay `::unsupported` at any depth.

## Considered options

- **Cross-stage visibility for stage conditions** — built in 2f8587b and reverted. Convenient, and exactly the case where WL gives the other answer; the combinator `Condition` asks the same question in WL's own terms.
- **Refusing a name repeated across stages** (`::stagename`, also 2f8587b) — built and reverted. The repeated name was previously an internal error (`RuleDelayed::rhs`), so a refusal was an improvement, but `{a_, a_}` already says what it should mean.
- **One result per `(before, after)` pair for `Sibling`, or per matching ancestor for `Descendant`** — rejected. It duplicates elements the user asked for once, and differs from CSS's `~` and descendant combinator, which select elements, not pairs. `Descendant` gave one result per ancestor until it was aligned with `querySelectorAll` and soupsieve.
- **Keeping the root out of `XMLCases` and `XMLFirstCase` chains** — rejected. `XMLDeleteCases` already let the root be the first stage, and a bare `body` element is a natural input for `Child[XMLPattern["body"], …]`. Returning the root stays excluded, as base `XMLCases` excludes it.
- **Keeping `Cases` order for results** — rejected for the 2.0.0 release. `XMLCases` had returned what `Cases` returns, a nested element before its ancestor, plain patterns and combinators alike, and `XMLFirstCase` the first of that, which for nested matches is the innermost. It is WL's own convention and cost nothing, as `Cases` and `FirstCase` produced it natively. But it is the reverse of what every HTML tool returns, it made `XMLFirstCase` disagree with `querySelector`, and it read oddly beside the bindings, which already chose the first candidate in document order. Document order costs a sort of the matches' positions, skipped when no match is nested in another (see Consequences).
- **Keeping per-combinator code beside the chain runner** — rejected. The unnested code had its own bugs (an unbound `before` name in the `Sibling` rule form; siblings directly under a bare root missed), and two paths would have had to agree on every scoping rule above.

## Consequences

Measured at 5 000 elements during the rework: plain combinators run about twice as slowly as their dedicated code did (`Child` 3.6 → 7.5 ms), nested chains faster (30 → 17 ms), and `XMLDeleteCases` with `Child` much faster (15 → 4 ms). A tuple is matched against the whole tuple pattern only when a combinator `Condition` or a repeated name needs it; otherwise the stages' own matches decide. When they decide, `Descendant` searches below the outermost matching ancestors only: over 50 nested `div`s of 100 `p` each, `Descendant[XMLPattern["div"], XMLPattern["p"]]` fell from about 600 ms, pairing every `p` with each of its ancestors (127 500 pairs), to about 18 ms.

The order convention is a reversal for anyone reading `Descendant[a, b]` as "for each `a`, its `b`s": results follow the document order of the last stage's elements, not the first stage.

Document order is a breaking change from 1.x for queries with nested matches (`XMLPattern["div"]` on nested `div`s): the multiset of results is unchanged, the order is not, and `XMLFirstCase` now gives the outermost match rather than the innermost. A plain query takes `Position`'s matches, which come in `Cases` order, where the matches nested in an element form one block right before it; each element with matches nested in it is moved to the start of its block, found by a binary search, rather than sorting every position, which costs the depth of the positions for every match. `XMLFirstCase` still stops early, finding the first match `FirstPosition` visits and then the outermost match above it. Measured against `Cases`: 2.9 → 3.7 ms for 5 000 flat `div`s; 0.7 → 3.2 ms for the 5 000 `p`s of the 50-deep tree above, where `Position` and `Extract` pay for the depth of the positions; 0.7 → 5.2 ms for its 5 051 `div` and `p` matches, 51 of them with matches nested in them, against ≈ 14 ms sorting every position. `XMLFirstCase` is unchanged at 0.05–3 ms. A rule's left-hand side is matched twice on each match, once to find it and once to evaluate the body: 3.8 → 6.0 ms for the flat `div`s with `XMLPattern["div", "id" -> x_] :> x`.

Possible Issues, for documentation:

- A stage `Condition` cannot see another stage's names; move the test onto the combinator.
- A name shared across a `Descendant` link, or a combinator `Condition` over one, still pairs every element with every matching ancestor before choosing one: the cost is the depth times the elements. Measured ≈ 0.9 s for the 50-deep tree above with `/; True`.
- A name shared across a `Sibling` link is quadratic in the length of the sibling list when candidates fail: every earlier sibling is tried for every later one. Measured ≈ 3.6 s at 1 000 siblings where no pair matches, quadrupling per doubling (≈ 15 s at 2 000); a few tenths of a second at 5 000 when matches exist.
