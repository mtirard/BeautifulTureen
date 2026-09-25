---
status: accepted
---

# `XMLMatchQ` ships, as a whole-element test

`XMLMatchQ[element, pattern]` tests whether one element matches an [[XML pattern]], with an operator form `XMLMatchQ[pattern]`. It is to `XMLCases` what `StringMatchQ` is to `StringCases`: a test of the whole expression, beside a family that searches.

## Context

An earlier decision (`.scratch/xmlreplace/map.md`, "No `XMLMatchQ`") held that it already existed as `MatchQ`, because `XMLPattern` evaluated to a real `XMLElement` pattern. ADR 0011 and ADR 0012 make `XMLPattern` inert, so `MatchQ[el, XMLPattern["p"]]` is now `False` for every element — and that is the spelling the shipped documentation opens both the `XMLPattern` and `CSSClass` pages with. The earlier decision's second argument, that the name would lie because the XML* family searches at depth, does not hold either: `StringMatchQ` is a whole-string test inside a family that also searches.

## Decision

`XMLMatchQ` accepts an element pattern: an `XMLPattern`, an `Alternatives` of them, or a `Condition` on one, and takes the `AttributeReadings` option like the other consumers (ADR 0012). A structural combinator (`Child`, `Descendant`, `Adjacent`, `Sibling`) is refused with a message: each describes an element in relation to its parent or siblings, and a lone element has neither.

## Consequences

`Cases`, `Position`, `ReplaceAll` and `MatchQ` no longer accept an `XMLPattern`. This is a Possible Issues entry on the `XMLPattern` page — the same trap as `MatchQ["abc", "a" ~~ __]` being `False` — with `XMLMatchQ` and the XML* functions as the answer.
