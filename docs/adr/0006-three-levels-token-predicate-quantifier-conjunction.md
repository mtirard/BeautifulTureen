---
status: accepted
---

# `XMLPattern` matching has three levels: token predicate, quantifier, conjunction

An `XMLPattern` attribute constraint operates at three distinct levels, and until now only one of them was named. A **token predicate** tests one token (`"lead"`, `"col-" ~~ __`); a **quantifier** lifts a predicate to a whole collection (∃ / ∀ / ¬∃); a **conjunction** combines constraints on one element. Each level gets its own vocabulary and its own syntax, and no construct is allowed to stand in for a level it does not belong to.

Supersedes ADR 0004 and ADR 0005, both outright.

## Context

Through v1.3.0 the quantifier was an implicit ∃ at two levels at once — `classMatchQ`'s `AnyTrue` over class tokens, and `KeyValuePattern`'s existential reading of attribute rules — while ∀ was inexpressible at either level and ¬∃ existed only as `CSSClass[Except[…]]`.

That last form is the evidence the muddle was real rather than cosmetic. `Except` is a **pattern head**, not a quantifier, so `CSSClass[Except["ad"]]` is a level jump: every other argument to `CSSClass` was a string pattern tested against one token, and this one was a negated quantifier over the whole list. ADR 0005 recorded this as an "unstated exception." The truth is stronger and stranger: **`Except["ad"]` is not a legal string pattern at all.** `Except`'s first argument must be single-character-width, so `StringMatchQ["x", Except["ad"]]` issues `StringExpression::invld` and comes back unevaluated. It worked only because `CSSClass` unwrapped `Except` before it ever reached a string pattern (`Kernel/BeautifulTureen.wl:182`). The construct's very legality depended on the **length of the user's class name** — `Except["a"]` is legal and means "any single character other than `a`", `Except["ad"]` is not legal at all, and both were accepted because the wrapper never let either be tested. ADR 0004 and ADR 0005 both use the illegal spelling in their worked examples.

Naming the levels is therefore not a tidying exercise. It is what makes ∀ expressible, ¬∃ honest, and the `Except` jump impossible to write.

## Decision

### The token level is predicate-shaped, with sugar on top

`TokenTest[q]` constrains an attribute value read as a [[token list]]. `ClassTest[q]` is a **pure rewrite** of `"class" -> TokenTest[q]`, nothing more.

`q` is an `AnyTrue` / `AllTrue` / `NoneTrue` **operator form**, and its operand is a `String -> Bool` predicate. A bare string pattern `p` desugars to `AnyTrue[StringMatchQ[p]]` by a **fallthrough** rule: any argument whose head is not one of the three quantifiers is a token predicate. This keeps `ClassTest["lead"]` as short as `CSSClass["lead"]` ever was, while `ClassTest[AllTrue["col-" ~~ __]]` says something previously unsayable.

Operator form is not a stylistic preference — it is the only available option. The two-argument forms evaluate eagerly to nonsense before we could ever see them: `AllTrue["a", "b"]` is `True`. There is no design freedom here to revisit.

Because the predicate is `StringMatchQ`, **regular expressions come for free**: `RegularExpression` is itself a legal string-pattern head, so `ClassTest[RegularExpression["col-\\d+"]]` falls through and works with no vocabulary of our own. Verified to compose with the operator forms (hence all three quantifiers) and inside a `StringExpression` (`"x" ~~ RegularExpression["col-\\d+"]`). `StringMatchQ` anchors it to the whole token, which is the token-level semantic we want — `RegularExpression["col-\\d+"]` does not match the token `xcol-6y`. `Except[RegularExpression[…]]` is illegal, consistent with the single-character-width rule above. This is the general benefit of a predicate-shaped surface: whatever `StringMatchQ` accepts, we accept.

### `Except` at the top level is gone

Negating a predicate is `Not` or `NoneTrue`. `Except` is a pattern head and survives only _inside_ a predicate, where it is a legal string-pattern construct subject to the single-character-width rule above. `ClassTest[Except[…]]` no longer has a meaning, and that is the point.

### Expression slots take a named lift

Three slots match expressions rather than strings — the tag, the attribute key, and the attribute value — and all three share one trap: `MatchQ["data-x", "data-" ~~ __]` is `False`, because a `StringExpression` is not an expression pattern. All three therefore accept `Matching[p]` ≡ `_String?(StringMatchQ[p])`, and all three **reject** a bare `StringExpression` with `XMLPattern::strpat`, echoing the user's own pattern already wrapped in `Matching`.

`Matching` deliberately does _not_ carry the `…Test` suffix. That suffix means "takes a quantifier"; `Matching` takes a string pattern. Capture composes with it unchanged: `k : Matching["data-" ~~ __] -> v_`.

### Nothing is absence-tolerant

**A constraint that names an attribute requires that attribute.** One rule, true everywhere — `"href" -> _`, `"class" -> Except["a"]`, and `"rel" -> TokenTest[…]` alike. This is what makes `ClassTest[q]` a pure rewrite: it emits a plain `KeyValuePattern` rule, with no lift and no `Condition`.

Absence is spelled by the user, as a disjunction of whole patterns, and is _measured_ equivalent to the tolerant emission it replaces (`assets/explicit-absence.wls`: 8.1 ms strict against 7.0 ms tolerant on a 5 000-element page):

```wl
XMLPattern["p", ClassTest[NoneTrue["ad"]]] | XMLPattern["p", AttributeTest[NoneTrue["class"]]]
```

Vacuity is inherited from WL, never legislated by us: `AllTrue` and `NoneTrue` are both `True` on an empty token list, so `class=""` satisfies "every class is a `col-` class" exactly as `{}` does.

### Conjunction stays one quantifier per argument

Multiple arguments conjoin. This is _foreclosed_ rather than chosen — with quantifiers as operator forms there is no second reading available — and is recorded so a later reader does not mistake it for an open design question.

### `CSSClass` is removed with a message, not silently

`CSSClass` does not survive as an alias: its semantics changed, and keeping two spellings of a construct that no longer means the same thing is worse than breaking. But it is removed with a `CSSClass::obs` message pointing at `ClassTest`, because an inert unevaluated `CSSClass[…]` inside `XMLPattern` yields a pattern that simply never matches — a silent wrong answer, which is the exact failure mode this whole effort exists to remove.

### Gotchas are documented, not diagnosed

Where a construct is legal, load-bearing, and still surprising, the home for it is a **Possible Issues** documentation section — WL's own idiom — not a message.

This rule was established by a planned rejection that turned out to be wrong. A `Pattern` inside a token predicate looked like it should be refused; in fact the binding is legitimate and load-bearing (`StringMatchQ["ab", x_ ~~ y_ /; x != y]` is `True`), and only its _escape_ to the enclosing scope is impossible. `XMLPattern::strpat` above is the deliberate exception: that rejection cannot be wrong, because a bare `StringExpression` in an expression slot has no valid reading at all.

The gotchas this effort identified and routes to documentation rather than diagnostics:

- **`*` and `@` are metacharacters inside string literals under `StringMatchQ`** — and only there; `StringCases` and `StringContainsQ` read them literally. `ClassTest["a*b"]` does not mean what a reader assumes. This is independent of anything decided here.
- **A `PatternTest` in a token predicate applies per character, not per token.** Inherited unresolved from ADR 0005.
- **A name bound on only one branch of an `Alternatives` silently becomes `Sequence[]`**, so a capture written across the absence disjunction above yields nothing on the absent branch, with no message. Verified: capturing `c` across the two branches gives `Hold["lead"]` on the present branch and `Hold[]` on the absent one. WL's semantics rather than ours, but it meets anyone who wants absence-tolerance _and_ capture.

## Considered options

- **Confinement** — rewriting the user's token predicate so it cannot cross a token boundary, making all three quantifiers pure string patterns with no `StringSplit` and no closure anywhere. Verified sound (189 differential cases against the `StringSplit` oracle, 0 mismatches) and **rejected on measurement**: it buys ~14 ms on a 5 000-element page that costs 28.8 ms merely to parse, and the closure-free, printable emission credited to it comes from **operator forms**, which are available without it (`assets/perf.wls`). Two further findings stand against reviving it: the equivalence claim is only true **relative to a fixed option set** — `IgnoreCase` is invisible to any fold over the pattern and changes the language matched, so an unqualified "confinement is semantics-preserving" is false — and a literal containing `*` or `@` crosses a token boundary under `StringMatchQ`, a failure mode the original sketch did not anticipate.
- **New quantifier symbols** instead of `AnyTrue`/`AllTrue`/`NoneTrue` — rejected: the WL names are already the right words, already documented, and already understood, and the operator forms compose with user-written predicates for free.
- **Dropping token predicates** in favour of quantifiers only — rejected. Predicates are what makes the surface uniform: every type in it is something WL already documents, and nothing is overloaded.
- **Absence-tolerance, retained** (ADR 0004's conclusion) — rejected. See "ADR 0004 falls" below.
- **Token-level capture** — binding the token list or a sub-token as a pattern variable. Unreachable, not merely unwanted: a named binding inside a string pattern cannot escape `StringMatchQ`, which returns a **Boolean**, so the submatch is discarded silently. The rule-body idiom covers every use case raised: `XMLCases[tree, pat :> StringCases[c, "col-" ~~ n : DigitCharacter .. :> n]]`.
- **Element-level `Not` as a constraint combinator** — rejected: `ClassTest[…]` evaluates to a `Rule`, so `Not @* ClassTest["ad"]` does not type-check, and `Not[constraint]` overloads a Boolean head onto a non-Boolean. The one thing it bought was attribute absence, which `AttributeTest` supplies properly (ADR 0007).
- **A regex surface of our own** — an option or head routing a pattern to PCRE. Rejected as duplication, and note carefully that this is _not_ a rejection of regular expressions: `RegularExpression` is inherited through `StringMatchQ` at no cost, as recorded above. WL string patterns remain the idiomatic surface, and they _compile to_ PCRE anyway (`` `StringPattern`PatternConvert["col-" ~~ __] `` is `"(?ms)col-.+"`), so there is nothing left for a parallel surface to buy.
- **Cardinality quantifiers** ("exactly two classes") — out of scope, not rejected. A counting family is a different kind of quantifier from ∃/∀/¬∃ and doubles the vocabulary work without threatening any of it.

## Why ADR 0004 falls, conclusion included

ADR 0004 held that a missing `class` and `class=""` state the same fact and that **no** constraint may distinguish them. Under this design they _are_ distinguishable, by design, so the holding goes rather than just its mechanism.

Its reasoning was correct in its own world and is obsolete in this one. Tolerance was _forced_: `CSSClass[Except[…]]` was the only way to spell "not an ad", so tolerance had to be baked into that spelling or the query could not be written at all. This effort supplies the vocabulary that makes the query writable, so the premise is gone. Do not re-derive absence-tolerance from `Lookup`'s `""` default — that route is closed.

What survives of ADR 0004 is its _other_ holding, and it now applies uniformly instead of as a carve-out: **never silently reinterpret the user's own pattern.** That is precisely the rule that keeps `"class" -> Except["a"]` presence-requiring alongside everything else.

The cost of dropping tolerance is real and worth naming: `ClassTest[NoneTrue["ad"]]` **under-matches versus CSS `:not(.ad)`**, because it skips classless elements. The disjunction above is the fix. The intended long-term answer is a translator (`FromCSSSelector`) that emits the disjunction automatically, so a CSS-fluent user never meets the mismatch; that is a separate effort, mentioned here only so the mitigation is on the record.

## Consequences

Breaking for every existing class query (v1.4.0). The library is experimental and unreleased, so this is a cost worth paying once rather than a compatibility burden to carry.

The three levels give the rest of the design its shape: ADR 0007 applies the same three quantifiers to the attribute set, and ADR 0008 decides how a token list is produced in the first place.

One recurring hazard showed up often enough in this effort to name, since it is the reason several "verified" claims in the source design turned out to be wrong: **a construct that is correct and looks cheap, whose cost or failure only appears past the point anyone checked.** Three instances are recorded across these ADRs — the `Except`-width trap above, whose legality depends on a string length nobody varied; `OrderlessPatternSequence`'s factorial blowup, verified to exactly one positive short of where it starts (ADR 0007); and `f[q_] := pat /; cond`, which WL reads as a conditional _definition_ so that the function silently returns unevaluated (ADR 0007).
