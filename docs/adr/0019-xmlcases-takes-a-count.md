---
status: accepted
---

# `XMLCases[tree, pattern, n]` gives at most the first n results, and `XMLCases` never takes a levelspec

bs4's `find_all(…, limit=n)` had no counterpart: `XMLFirstCase` was the only way to stop early. The obvious spelling, `XMLCases[t, p, n]`, clashes with `Cases`, whose third argument is a levelspec and whose fourth is the count (`Cases[expr, pat, levelspec, n]`). A bare third argument with a different meaning from `Cases`'s would mislead WL users unless the levelspec slot is given up for good. Settled in [issue #14](https://github.com/mtirard/HTMLPatterns/issues/14).

## Decision

**No levelspec, ever.** WL levels are not element depth: each element adds at least two expression levels (the `XMLElement` and its child list), and an `XMLObject` adds more. A levelspec would mislead whatever it was defined to mean. That frees the third slot. A children-only search (bs4's `recursive=False`) is not a levelspec either. It needs the position of an element relative to the query's input, which CSS's `:root` and `:scope` also need, and [ADR 0018](./0018-the-document-above-the-top-elements.md) gives all three one answer: `Child[XMLDocument[], …]`.

**The count is the third argument**, as in the functions that have no levelspec: `StringCases[s, p, n]`, `Select[l, f, n]`, `SequenceCases`, `TextCases`. XML patterns are the paclet's third kind of pattern beside string patterns, so `StringCases` is the model. Options follow it: `XMLCases[tree, pattern, n, "AttributeReadings" -> …]`. `XMLCases[tree, pattern]` is unchanged. `MaxItems -> n` was rejected: system functions that limit results by option use `MaxItems` (`WebSearch`, `TextSearch`, `SemanticSearch`), but no pattern-matching function spells a count that way.

**`n` is a ceiling.** The result is the first `n` of `XMLCases[tree, pattern]` in [[Document order]], or all of them if there are fewer. Each element a combinator selects counts once. This is the selection convention (`Cases`, `Select`, `StringCases`, bs4's `limit`), not the `Take` and `Partition` convention, where `n` is exact and `UpTo[n]` relaxes it. An exact count composes: `Take[XMLCases[t, p, n], n]`.

**Valid `n`** is a non-negative integer or `Infinity`. `0` gives `{}`, and `Infinity` is no limit. `UpTo[n]` is refused, as in `StringCases`: accepting it as a synonym would suggest that a plain `n` is exact. `All`, negative numbers, non-integers, strings and lists (`{2}`, a `Cases` levelspec habit) give the general message `XMLCases::innf` ("Non-negative integer or Infinity expected at position 3 in …"), and the call stays unevaluated. There is no dedicated levelspec message. A third argument that is not a rule naming an option of `XMLCases`, or a list of them, is read as a count, as `XMLFirstCase` reads its default.

**Early stop.** With `pattern :> body`, `body` is evaluated only for the returned matches. With `pattern -> rhs`, `rhs` is evaluated once before any matching, as the usage says and as `Cases` does, even for `n = 0`. For a pattern that is not a combinator, the search also stops at the nth match, as `Cases[…, n]` does: `Position[tree, pat, Infinity, n]` stops at the nth match in `Cases` order, which visits an element after the elements nested in it. Any match earlier in document order that it has not visited is an element that a visited match is nested in, so the first `n` in document order are among the matches found and the elements on the way down to them, each tested once. `XMLFirstCase` uses the same search with `n = 1`. A combinator, and a body with a `Condition` that can reject a match, still collect every candidate before the first `n` are taken, as `XMLFirstCase` does for them; a test on a stage can then see elements past the nth result.

**Scope:** `XMLCases` only. `XMLDeleteCases`, where nested matches removed with an outer one make "the first n" ambiguous, and `XMLFirstCase` are unchanged.

## Consequences

The third argument of `XMLCases` now has a meaning, so `XMLCases[t, p, 2]` no longer gives `XMLCases::argrx`; a fourth positional argument gives `XMLCases::argt`. Silent unevaluation of a wrong argument count elsewhere is its own bug.
