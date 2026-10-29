---
status: accepted (supersedes ADR-0014, ADR-0015 and ADR-0016; supersedes ADR-0011, ADR-0013 and ADR-0018 in part)
---

# Patterns are nested as the document is

The combinators (`Child`, `Descendant`, `Adjacent`, `Sibling`) were CSS-style paths: a query selected the elements of its last stage, and a combinator used as a stage was spliced into the chain (ADR 0014). Nesting did not mean nesting, and a query could not branch. A bank holiday row, a `tr` holding `th > time` and a last `td`, needed two calls per row. `Sibling[Child[d1 : XMLPattern["th"], XMLPattern[_]], XMLPattern["td"]] :> d1` found nothing, and the same expression as a list-stage entry (ADR 0016) read as its first stage, so one expression had two meanings. A name bound in a context entry came back unbound with no message. These are consequences of the path reading, not bugs to patch.

## Decision

### `XMLPattern[tag, attrs, c…]`

`XMLPattern` takes, after its tag and attributes, any number of **constraints** on what is below the element, all of which must hold:

- a WL **list pattern over the element children**, text not listed, as in CSS. Entries are XML patterns, `XMLElement` patterns, blanks and sequence patterns. Two list constraints match the same children;
- **`Descendant[p, levelspec]`**: some element strictly below matches `p`, the level spec in DOM depth, default `{1, Infinity}`;
- alternatives of constraints.

Several `Descendant` constraints are independent, as several `:has()` are. `Descendant` stands only in a constraint slot.

```wl
XMLPattern["tr", _, {XMLPattern["th", _, {XMLPattern["time", "datetime" -> d_]}], ___, n : XMLPattern["td"]}] :> {d, HTMLInnerText[n]}
```

### `XMLElement` patterns are WL literals, accepted everywhere

An `XMLElement` pattern keeps WL's meaning: exactly these contents, text and whitespace included, attributes as the raw rule list. It is accepted wherever a pattern goes, which reverses GitHub issue #31. It is how exact text is matched; otherwise text is reached through `HTMLInnerText` or `HTMLTextContent`.

### Context comes from where a pattern is rooted

There is no upward constraint. Context above an element is written by rooting the pattern higher and naming what is wanted. Two features cover what rooting alone cannot:

- **`XMLDocument[c…]`** is a pattern root that takes the same constraints, its contents list listing the top elements (ADR 0018). It may be named, and may be a branch of alternatives at the root (`XMLPattern[_, _, L] | XMLDocument[L]`, for a parent that may be the document).
- **Named paths.** `p : Descendant[…]` binds the elements strictly between the root and the match, and `Descendant[…]?test` tests them: `XMLDocument[Descendant[x : XMLPattern["a"]]?NoneTrue[XMLMatchQ["nav"]]] :> x` is XPath's `//a[not(ancestor::nav)]`.

`Shortest` and `Longest` on a `Descendant` constraint keep the nearest and the outermost root for each match.

### What goes

`Child`, `Adjacent`, `Sibling`, the path form of `Descendant`, list stages, and `XMLDocument[]` as a stage. Each has a tree-pattern form; the migration table is in the documentation.

## Considered options

- **Raw `XMLElement` patterns as the tree syntax.** They cannot reach list keys or skip text, and contents lists would have to list whitespace.
- **The combinators as tree nodes** (`Child[root, c…]`). Two patterns at different places in the tree sit side by side as arguments, where `XMLPattern`'s constraints nest as the tree does.
- **Listing text in contents lists.** In CSS, `+`, `~` and the structural pseudo-classes ignore text (checked in Chrome). Listing it would need a text-skipping gap at every sibling relation.
- **An upward constraint (`Ancestor[p]`).** It would stop element tests from testing one element alone. Rooting higher, named paths and `XMLDocument` cover the cases found.
- **`Descendant[p, levelspec, q]`**, every element between matching `q`. A path test says the same with no new argument.

## Consequences

- An element test (`XMLMatchQ`, a Roles or Constructs key) can take any element pattern, since constraints only look down.
- Patterns nest deeply. This is accepted as honest; flatter spellings may come later as conveniences that translate into this form.
- Negation of a constraint is a test: `XMLFreeQ` with a level spec in DOM depth (#32).
- Breaking: every combinator query is rewritten.
