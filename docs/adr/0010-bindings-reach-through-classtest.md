---
status: superseded by ADR-0011 (dissolved, not replaced)
---

# A binding reaches through `ClassTest`; the test constructs are inert

`ClassTest[q]` _is_ a rule, so it offers no slot to bind and a user who matched on it could not name the value they matched. The three test constructs become **inert** — expanded by the `XMLPattern` compiler rather than by evaluation — and the compiler recognises `name : ClassTest[q]`, binding the raw `class` attribute value. Nothing about `Rule` changes: `c : ("href" -> _)` remains an error.

Amends ADR 0006, which states that `ClassTest[…]` evaluates to a `Rule`.

> **Dissolved by [ADR 0011](./0011-plain-patterns-inside-xmlpattern.md), not replaced.** There is no `ClassTest` left for a binding to reach through, and this ADR's whole problem — a construct that evaluates to a `Rule` before `Pattern` can see it, so a user cannot name what they matched — does not arise once tokens are materialised as real subexpressions (ADR 0012) and specifications are written as plain WL patterns: `"classList" -> cls_` binds the whole token list the same way any WL pattern binds, with no compiler-recognised construct required to make it possible.

## Context

ADR 0006 makes `ClassTest[q]` a pure rewrite of `"class" -> TokenTest[q]`. That is what makes it ergonomic, and it is also a cliff: `"rel" -> r : TokenTest[q]` binds natively because the user wrote the rule themselves, but `ClassTest[q]` hides the rule, so the moment a user wants the matched value they must know the expansion and drop to the long form. The reading leaks precisely when it is most useful.

**`ClassTest` is the only construct with this problem**, which is what makes a fix for it a principle rather than a special case: it is the only one that hides a rule. `TokenTest` sits in a value slot the user wrote. `AttributeTest` hides a `Condition`, not a rule (ADR 0007).

## Decision

### The test constructs are inert

`ClassTest`, `TokenTest` and `AttributeTest` no longer evaluate to their emitted forms. They stay as themselves until the `XMLPattern` compiler expands them.

This is what makes the binding expressible at all. `Pattern` has `HoldFirst` — only its _first_ argument is held — so under the old evaluating behaviour `cls : ClassTest["head"]` became `Pattern[cls, Rule["class", _?f]]` before anything could see it, indistinguishable from a hand-written `cls : ("class" -> _?f)`. Inertness preserves the distinction.

All three change, not just `ClassTest`. Leaving `TokenTest` and `AttributeTest` evaluating would be an asymmetry a reader trips on for no gain, inert constructs are how WL's own pattern heads behave, and it makes the constructs printable rather than dissolving on sight into an emitted pattern. It also makes "pure rewrite" more literally true than before — the rewrite is now performed by the compiler, which is where the ADR 0006 phrase always implied it happened.

### `name : ClassTest[q]` binds the raw class value

The compiler recognises `Pattern[name, ClassTest[q]]` in the constraint slot and pushes the binding onto the value, emitting `"class" -> name : _?(…)`. So:

```wl
XMLCases[tree, XMLPattern["h1", cls : ClassTest["head"]] :> StringSplit[cls, HTMLWhitespace]]
```

What is bound is the **raw attribute value string**, not the token list — the token list is unbindable, since a pattern cannot bind a computed value, and ADR 0006 already rules token-level capture out of scope on that ground. `HTMLClassList` (ADR 0009) means most users never need the binding at all: `HTMLClassList /@ XMLCases[tree, XMLPattern["h1", ClassTest["head"]]]` needs no capture, no expansion, and no long form.

### `c : ("href" -> _)` stays an error

`XMLPattern` rejects a `Pattern`-wrapped rule today with `XMLPattern::badconstraint`, and it continues to.

The tempting generalisation — rewrite _any_ `Pattern[n, Rule[k, v]]` to bind the value — is a **false friend**. Measured, `KeyValuePattern[{c : ("class" -> _)}]` binds the whole rule, `"class" -> "lead"`, not the value. So a general rewrite would make our syntax mean the opposite of what the identical syntax means in the very construct it compiles into, and a user with a correct `KeyValuePattern` model would be silently wrong. Defining it to bind the _pair_ instead would agree with WL, but there is no demand for it: a user who wants the value writes `"href" -> c_`, which has always worked. An error is better than either.

This also keeps the two levels telling themselves apart honestly. `cls : ClassTest[q]` yields a value because `ClassTest` names a value; a pair is obtained by writing a pair.

### No binding on `AttributeTest`

`attrs : AttributeTest[q]` is technically reachable — the whole attribute list could be bound at the `XMLElement` attribute slot — and is not offered. `AttributeTest` hides a `Condition`, so the binding's natural referent is the entire attribute set, which is already available as `el[[2]]` from the returned element and would be **identical across every `AttributeTest` on that element**. A binding that is not about the constraint it is attached to is worse than no binding.

## Considered options

- **An `UpValue` on `ClassTest`** — structurally impossible, twice over. `ClassTest /: Pattern[n_, ClassTest[q_]] :=` is rejected at _definition_ time with `Pattern::patvar`, because `n_` is not a valid pattern name in that position; and even setting that aside, under the old evaluating behaviour `ClassTest[q]` became a `Rule` before `Pattern` was reached, so no `ClassTest` up-value could fire. This is the same eager-evaluation wall that makes the two-argument `AllTrue` forms unreachable in ADR 0006.
- **`ClassTest[cls : q]`, binding inside the argument list** — rejected for two reasons. It clashes with ADR 0008's disambiguation rule, under which any argument that is not a symbol-keyed `Rule` falls through to a **token predicate**, so it would need a third category. And it is misleading about what it binds: sitting inside the quantifier's argument, `cls` visually scopes to what the quantifier ranges over — the token list — while it can only ever bind the raw string. Putting the binding _outside_ the argument list avoids both.
- **A general `Pattern[n, Rule[k, v]]` rewrite** — the false friend above.

## Consequences

ADR 0006's rejection of `Not @* ClassTest["ad"]` is argued from `ClassTest[…]` evaluating to a `Rule`, which is no longer true. **The conclusion is unaffected**: an inert `ClassTest[…]` is still not a Boolean, so `Not` still overloads a Boolean head onto a non-Boolean, and element-level `Not` remains rejected.

Inertness means `ClassTest[q]` typed outside an `XMLPattern` returns itself rather than an emitted pattern. This is how `Condition`, `Blank` and friends behave and is not a regression — but it does remove the ability to inspect the emitted shape by evaluating the constructor alone, which the tests never relied on (they exercise the public surface only).
