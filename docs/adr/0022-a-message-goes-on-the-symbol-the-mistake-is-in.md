---
status: accepted
---

# A message goes on the symbol the mistake is in

A refusal's message goes on the innermost package symbol that the mistake is in: a symbol used wrongly, or the symbol whose argument is wrong. A mistake at the top level of the query goes on the consumer, and so does a construct that is valid elsewhere but that the consumer cannot take.

## Context

`XMLCases[tree, Child[XMLPattern["a"]]]` gave `XMLCases::stages`. The text was right, but the Front End's `>>` link opens the page of the symbol before `::`, so it led to `XMLCases`, while the correct form of `Child` is on `Child`'s page. A user reading `XMLCases::stages` also looks for the mistake in the call to `XMLCases`, not in the `Child` inside it.

WL puts a message about a construct inside a pattern on that construct, even when another function finds it:

- `StringMatchQ["a", RegularExpression["("]]` gives `RegularExpression::msg14`.
- `Cases[{1}, Repeated[_, {-1}]]` gives `Repeated::range`. The mistake is the argument `{-1}`, and the message is on the symbol that holds it.

The paclet already did this for `XMLPattern` (ADR 0011): `XMLPattern::badtag`, `::badkey` and the rest fire when a consumer compiles the query, but are `XMLPattern`'s. The combinator and `XMLDocument[]` refusals were the exception.

## Decision

A message is placed by where the mistake is, which can be read from the input alone:

| Input | Message |
|---|---|
| `Child[a]` | `Child::stages` |
| `Child[a, b]?f` | `Child::testcombinator` |
| `Child[a, _]` | `Child::blank` |
| `XMLCases[tree, _]` | `XMLCases::blank` |
| `Sibling[a, {…}]`, `Child[{…}, b]`, a list with no XML-pattern entry | `Sibling::liststage`, `Child::liststage` |
| `Child[a, {b, _XMLElement}]` | `Child::listentry` |
| `XMLCases[tree, {…}]` | `XMLCases::liststage` |
| `Child[a, XMLDocument[]]`, `d : XMLDocument[]`, `XMLDocument[]` alone | `XMLDocument::place` |
| `XMLMatchQ[el, Child[a, b]]`, and `Child[a]` or `Child[a, b]?f` there | `XMLMatchQ::combinator`, `::stages`, `::testcombinator` |
| `XMLMatchQ[el, XMLDocument[]]`, the same in `"Roles"` or `"Constructs"` | `XMLMatchQ::badpat`, `HTMLInnerText::badpat` |
| `XMLPattern[1]` | `XMLPattern::badtag` |

- **Innermost.** In `Descendant[a, Child[b]]` the message is `Child::stages`. In a list stage, a mistake in an entry is the combinator's that holds the list; a context combinator entry in it is a test of that list.
- **A test on alternatives** holding combinators is refused under the first combinator as written. The message shows the whole pattern, so naming one of them is enough. A test on alternatives of lists holds no combinator and is refused under the symbol that holds it.
- **The element-pattern consumers.** `XMLMatchQ` and the `"Roles"` and `"Constructs"` rules of `HTMLInnerText` and `HTMLToNotebook` take only an element pattern (ADR 0013). There, any combinator and `XMLDocument[]` are the consumer's mistake, not the construct's, so every message stays the consumer's. Pointing to `Child`'s page for a fix that the consumer would then refuse would mislead.
- **A combinator's message names it.** Each combinator has its own copy, made from one template, so the text says "Child needs at least two stages, as in Child[a, b]", not "a combinator such as Child or Descendant".
- **Unchanged.** `::badpat` and `::badtree` describe a consumer's own arguments. A CSS selector string is the consumer's argument too, so `"div > :root"` still gives `::badpat` with the string, not `XMLDocument::place`.

## Consequences

- Each combinator's page, and `XMLDocument`'s, shows its messages under Possible Issues.
- `Quiet[…, XMLCases::stages]` no longer catches a one-stage combinator. The paclet had not been published when the names moved.
- `XMLCases`, `XMLFirstCase` and `XMLDeleteCases` keep `::testcombinator` for the test on alternatives of lists, the only case that still reaches them.
- A wrong stage that is not a blank, a list or `XMLDocument[]`, such as `Child[a, 5]`, still gives the consumer's `::badpat`. Under this rule it would be the combinator's, but `::badpat`'s text describes the consumer's whole query.
- Combinators in `"Roles"` and `"Constructs"` rules are tracked in issue #51. If they are allowed, the consumer-specific combinator messages of `HTMLInnerText` and `HTMLToNotebook` go away.
