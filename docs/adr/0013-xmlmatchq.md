---
status: accepted (amended by ADR-0014)
---

# `XMLMatchQ` ships, as a whole-element test

`XMLMatchQ[element, pattern]` tests whether one element matches an [[XML pattern]], with an operator form `XMLMatchQ[pattern]`. It is to `XMLCases` what `StringMatchQ` is to `StringCases`: a test of the whole expression, beside a family that searches.

> **Amended by [ADR 0014](./0014-combinators-scope-names-as-wl-does.md).** The searching consumers now accept a `Condition` on a combinator. `XMLMatchQ` still refuses one, with `XMLMatchQ::condcombinator`, for the reason below. Everything else stands.

## Context

An earlier decision (`.scratch/xmlreplace/map.md`, "No `XMLMatchQ`") held that it already existed as `MatchQ`, because `XMLPattern` evaluated to a real `XMLElement` pattern. ADR 0011 and ADR 0012 make `XMLPattern` inert, so `MatchQ[el, XMLPattern["p"]]` is now `False` for every element — and that is the spelling the shipped documentation opens both the `XMLPattern` and `CSSClass` pages with. The earlier decision's second argument, that the name would lie because the XML* family searches at depth, does not hold either: `StringMatchQ` is a whole-string test inside a family that also searches.

## Decision

`XMLMatchQ` accepts an element pattern: an `XMLPattern`, an `Alternatives` of them, or a `Condition` on one, and takes the `"AttributeReadings"` option like the other consumers (ADR 0012). A structural combinator (`Child`, `Descendant`, `Adjacent`, `Sibling`) is refused with a message, and so is a `Condition` on one: each describes an element in relation to its parent or siblings, and a lone element has neither.

The operator form `XMLMatchQ[pattern]` stays unevaluated, as `MatchQ[pattern]` does, and keeps the compiled query between calls, keyed on the pattern, the value of the `"AttributeReadings"` option and `$AttributeReadings` ([issue #2](https://github.com/mtirard/BeautifulTureen/issues/2)). Compiling once per element cost about 115 µs per element. A refused pattern is not kept, so it gives its message on each call, as the two-argument form does. Giving the message once, when the operator is made, was rejected: `XMLMatchQ[bad]` would then evaluate to `$Failed` instead of an operator. The cache holds at most 256 entries and is emptied when full. It holds compiled queries, not split token lists, so ADR 0012's rejection of a `Once` cache, which is about trees and strings, does not apply.

## Consequences

`Cases`, `Position`, `ReplaceAll` and `MatchQ` no longer accept an `XMLPattern`. This is a Possible Issues entry on the `XMLPattern` page — the same trap as `MatchQ["abc", "a" ~~ __]` being `False` — with `XMLMatchQ` and the XML* functions as the answer.
