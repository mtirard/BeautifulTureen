---
status: accepted (amended after implementation)
---

# Inside an `XMLPattern`, everything is a plain WL pattern: literal keys, one attribute argument, one desugaring

An [[XML pattern]] is the paclet's third kind of pattern, beside WL's patterns and string patterns: an inert object that only the XML* functions interpret. Everything written inside one is an **ordinary WL pattern**, matched exactly as `MatchQ` would match it, and the paclet departs from that in as few places as possible — one desugaring, one set of exactly-decidable refusals, and the [[reading]] mechanism of ADR 0012. Nothing is auto-lifted, nothing is made orderless behind the user's back, and set questions about a token list are asked with WL's own list predicates.

> **Amended after implementation** (commit bc5ae39), where the code settled what this ADR left open: a list attribute argument is always the rule list, so a bare namespaced key is written `{{ns, name}}`; two rules on the same literal key are refused as duplicates, and an `Alternatives` key that shares a literal with another key is accepted (first refused too, until a satisfiable case turned up); at an `Alternatives` key the desugaring applies only if every alternative is a list key; a `Condition` on the attribute argument is refused; a `Condition` over several attribute names works, which WL alone does not give; and every refusal fires when a consumer compiles the query, since `XMLPattern` has no definitions. Each is written into the section it belongs to. Combinator scoping is [ADR 0014](./0014-combinators-scope-names-as-wl-does.md).

> **Amended 2026-10-02** (with [ADR 0015](./0015-alternatives-of-combinators.md)). "XML pattern" now names the whole kind: `XMLPattern[…]`, the combinators, and alternatives and conditions over them. This ADR is about one form of it, `XMLPattern[tag, attrs]`, and "everything written inside one" means inside that form. A combinator reads as a list pattern over its stages (ADR 0014) and alternatives as WL's (ADR 0015), so the kind is an ordinary WL pattern at every level. The raw `XMLElement` pattern accepted below is to be dropped (GitHub issue #31).

Supersedes ADR 0006, ADR 0007 and ADR 0008 in part — each of those ADRs states what specifically survives. Read together with [ADR 0012](./0012-readings-and-materialising-emission.md), which covers how a token list is produced and exposed.

## Context

The original three-level design (ADR 0006–0008) named vocabulary — `ClassTest`, `TokenTest`, `AttributeTest`, `Matching`, and `AnyTrue`/`AllTrue`/`NoneTrue` as adopted heads — for a token list and an attribute map that are, underneath, ordinary WL lists: a token list is a list of strings, an attribute map is a list of `key -> value` rules. Once that was recognised (`.scratch/xmlpattern-quantifiers/issues/13-adopt-first-party-list-predicates.md`), every one of those symbols turned out to be a sublanguage layered over pattern matching WL already has.

A first draft of this ADR stripped the symbols but kept three smaller pieces of cleverness: a desugaring of **every** bare specification `p` to `{p, ___}`, an automatic `OrderlessPatternSequence` around every list, and pattern-valued attribute keys whose value slot was reinterpreted by the key's reading. A sanity pass over the shipped documentation's examples (`.scratch/xmlpattern-quantifiers/assets/doc-examples-sanity.wls`) found the first one wrong on measurement: a token predicate (`_?(StringStartsQ["col-"])`) and a list predicate (`_?(FreeQ["ad"])`) have the same shape, so the desugaring cannot tell them apart, and it turned the documented `:not(.ad)` spelling into "some class is not `ad`" — `{"Sponsored.", "Body two."}` where `{"Body one.", "Body two."}` is right. The other two fell with it: each was the paclet guessing what the user meant, and each is spellable by the user in WL directly.

## Decision

### The shape: `XMLPattern[tag]` and `XMLPattern[tag, attrs]`

`XMLPattern` takes a tag and at most **one** attribute argument, and **no options, ever** — so a `Rule` in its argument list can never be mistaken for one. Consumer configuration (`"AttributeReadings"`, ADR 0012) lives on the consuming functions, which is also what keeps `XMLPattern` inert.

The attribute argument is **what `KeyValuePattern` takes**: a list of `key -> value` rules, matched as `KeyValuePattern` matches them — orderless and open-world, because attribute order carries no meaning and an element may carry attributes the query does not mention. A single rule, or a bare key (`"href"`, meaning `"href" -> _`), is a singleton list. A list is always the rule list, so `{ns, name}` alone is two bare keys, and a bare namespaced key is written `{{ns, name}}`. The argument may be named and tested as a whole, which is how any question about the whole [[attribute map]] is asked:

```wl
XMLPattern["a", "href" -> target_]
XMLPattern["input", {"type" -> "text", "required"}]
XMLPattern["div", attrs : {"id" -> _}?(Keys /* AnyTrue[StringStartsQ["data-"]])]
```

A binding or test on the attribute argument sees the element's **original** attribute map, never a synthesised attribute (ADR 0012). A `Condition` on the attribute argument (`attrs_ /; test`) is refused (`XMLPattern::badattrs`): the test is written with `?`, or as a `Condition` on the whole `XMLPattern`. A third argument is refused with a message pointing at the list form.

A `Condition` on the whole `XMLPattern`, on a combinator, or in a rule's body sees every name in the constraints. WL alone gets this wrong: it tests a `Condition` around a nested `KeyValuePattern` once the first rule is matched, with the later rules' names bound to nothing, and a `False` then is final, so `XMLPattern["a", {"href" -> h_, "data-id" -> i_}] /; StringContainsQ[h, i]` matched nothing before the compiler worked around it (`ReplaceList` also binds only the first rule's names). The compiler matches such a pattern in two steps: its skeleton, with no names and no `Condition`s, finds the candidates as fast as a plain query, and each candidate is matched with plain list patterns over copies of its attribute list, one rule per copy, so that every name is bound and the match backtracks. Any other pattern compiles as before. Measured at six named rules over 5 000 elements carrying six to nine attributes: about 60 ms, against about 18 s for `{OrderlessPatternSequence[rules…, ___]}`, which binds every name but costs the factorial of the attribute count (ADR 0007). A `Replace`-based test (33 ms) does not backtrack, and a `ReplaceList`-based one binds only the first name.

Varargs (`XMLPattern["a", c1, c2]`) are dropped in favour of the list. The list is what `KeyValuePattern` already takes, it gives the whole attribute map a single place to be named and tested, and it leaves the argument sequence free of rules that look like options.

### Keys are literal

A key is a string, a namespaced `{namespace, name}` pair, or an `Alternatives` of those (`("href" | "src") -> url_`). Anything else — a blank, a predicate, a `StringExpression` — is refused with a message. A question that needs a key pattern ("has some `data-*` attribute", "has `href` in any namespace") is asked of the whole attribute map through the binding above, where it is plain WL.

Two rules on the same literal key are refused with a message. This is not taste: `KeyValuePattern` demands distinct elements, so `KeyValuePattern[{"a" -> _?(MemberQ["x"]), "a" -> _?(MemberQ["y"])}]` is `False` against `{"a" -> {"x", "y"}}` even though each rule holds alone — a silent wrong answer. Every same-key conjunction is expressible as one value pattern instead. Two rules whose keys only share a literal through an `Alternatives` key are accepted with no message: each rule can take a different attribute, so `{("a" | "b") -> "1", "a" -> "2"}` matches `{"a" -> "2", "b" -> "1"}`. The first implementation refused this case too, with a message saying the pattern could never match, which was false. Such overlapping keys match whatever the order of the rules. `KeyValuePattern` alone does not give this: it does not backtrack over which attribute an `Alternatives` key takes, so `MatchQ[{"x" -> "1", "y" -> "2"}, KeyValuePattern[{("x" | "y") -> v_, "x" -> w_}]]` is `False` while the same rules in the other order give `True`. So a rule list with overlapping keys is matched in two steps, as a condition over a `KeyValuePattern` is, with or without a condition: a skeleton without the overlapping `Alternatives` rules finds the candidates, then each rule is matched against its own copy of the attribute list, each taking a different attribute, with full backtracking. Rule lists without overlapping keys compile to a plain `KeyValuePattern` as before.

A namespaced pair is foreign vocabulary by construction, exposed raw rather than normalised to an invented string, and the identical rule governs the tag slot: WL has no canonical namespaced-name string to normalise to (confirmed empty via `Names["System`*QName*"]` and its neighbours), and the importer keeps only the resolved URI, never the written prefix.

### Values are plain patterns, with one desugaring

A value is any WL pattern, matched as written. At a raw attribute key it is matched against the raw string, so `"class" -> "lead"` means a `class` of exactly `"lead"`. At a synthesised list key (ADR 0012) it is matched against the token list, so `"classList" -> {___, "lead", ___}`, `"classList" -> _?(MemberQ["lead"])`, `"classList" -> {}` and `"classList" -> c_` (binding the whole list) all mean what they would mean to `MatchQ`.

**The one desugaring:** at a list key, a literal string or an `Alternatives` of literal strings `s` means `{___, s, ___}`. At an `Alternatives` key it applies only if every alternative is a list key; `("classList" | "id") -> "k"` is matched as written at both. The criterion is exact: these are precisely the value patterns that can never match any list, so their literal reading is always `False` and the desugaring cannot turn a correct answer into a wrong one. It stops there. `Except["ad"]`, `_`, `_?f` and every blank *can* match a list, so they keep their plain meaning — `"classList" -> Except["ad"]` matches every list, and `:not(.ad)` is `"classList" -> _?(FreeQ["ad"])`. The desugaring applies at the top of a value only, never to the elements of a list pattern.

### Lists are positional; set questions use WL's list predicates

No `OrderlessPatternSequence` is emitted. A list pattern is an ordinary positional list pattern: `{"lead", "promo", ___}` means the first token is `lead` and the second `promo`. Order-free questions are asked with predicates WL already has — `MemberQ`, `FreeQ`, `ContainsAll`, `ContainsAny`, `ContainsNone`, `ContainsExactly`, `SubsetQ`, `IntersectingQ`, `DisjointQ` — or with an `OrderlessPatternSequence` the user writes. The `Contains*` family compares with `SameQ` by default; `SameTest -> StringMatchQ` makes it take string patterns, operator form included:

```wl
XMLPattern["div", "classList" -> _?(ContainsAll[{"col-" ~~ __, __ ~~ "-bold"}, SameTest -> StringMatchQ])]
```

Conjunction therefore has no special meaning. Across attributes it is the rule list; within one value it is a predicate or a `Condition` (`"classList" -> c_ /; MemberQ[c, "item"] && FreeQ[c, "ad"]`); disjunction is `Alternatives`, inside a value or around whole `XMLPattern`s. No Boolean algebra and no quantifier vocabulary ship — `AnyTrue`, `AllTrue` and `NoneTrue` remain usable exactly as WL documents them, as list predicates.

### No string pattern is auto-lifted

A bare `StringExpression` — `"col-" ~~ __` typed directly — is refused with `XMLPattern::strpat` everywhere a pattern is written: the tag, a value, and a list element. `MatchQ` never interprets a `StringExpression` as a string test (`MatchQ["col-6", "col-" ~~ __]` is `False`), so accepting one silently would give a query that fails forever with no message. The spelling that works costs no vocabulary: `_?(StringMatchQ["col-" ~~ __])`, or `_?(StringStartsQ["col-"])`.

This closes a piece of history that should not be reopened: an interim design auto-lifted a bare string pattern on the grounds that it "has no other reading", which was true for the tag and value slots in isolation and false the moment tokens became list elements — `{"lead", __}` has two readings that disagree.

## Considered options

- **Desugaring every bare specification, `p ≡ {p, ___}`** — rejected on measurement; see Context. The narrower desugaring above keeps the one case with no competing reading.
- **Refusing a literal string at a list key**, rather than desugaring it — rejected. It is exactly decidable either way, and the desugared reading is the only non-vacuous one, so a message would only make the user type `{___, "lead", ___}` for the most common query there is.
- **An automatic `OrderlessPatternSequence` around every list** — rejected. Everyone wants order-free class questions, but the list predicates answer them in WL's own terms, and an invisible rewrite of a list the user wrote is the paclet guessing. Anchoring is also easy to get wrong, measured: `{OrderlessPatternSequence["lead", "col-6"], ___}` fails on `{"x1", "lead", "col-6"}`, and `{OrderlessPatternSequence["lead", "col-6", ___]}` matches — worth a documentation example for users who write it themselves.
- **Pattern keys** — rejected. A pattern key cannot know which reading applies to its value, could see synthesised attributes, and needed its own restriction (value exactly `_`) and guard to be safe. A binding on the whole attribute map asks every such question in plain WL.
- **Varargs for attribute constraints** — rejected in favour of one list; see above.
- **An `Association` form for the attribute argument** — rejected. Closed in WL (`MatchQ[<|"a"->1,"b"->2|>, <|"a"->1|>]` is `False`), not the representation `XMLElement` uses, and an `Association` literal silently deduplicates keys (`<|"a"->1,"a"->2|>` is `<|"a"->2|>`), making a constraint vanish with no message.
- **Adopting `Contains*`, `SubsetQ` or `DisjointQ` as vocabulary** — rejected. Each is already usable at zero cost as `_?(…)`; adopting some would narrow an open set.

## Consequences

Exact-set pinning, cardinality (`"classList" -> {_, _}`), and token-level binding fall out of plain list patterns and need no feature of their own.

Messages, each an exactly-decidable refusal in `XMLPattern::strpat`'s tradition: a bare `StringExpression` anywhere a pattern is written (`::strpat`); a non-literal key (`::badkey`); two rules on the same literal key (`::dupkey`); a third argument (`::nargs`); a malformed tag (`::badtag`) or attribute argument (`::badattrs`). `XMLPattern` has no definitions, so none fires when an `XMLPattern` is written: each fires when a consumer compiles the query, which messages and gives `$Failed`.

A raw `XMLElement` pattern is still accepted wherever an element pattern is, and is run as written, so it cannot reach a list key.

Documentation must carry these as Possible Issues, since each is a silent wrong answer the paclet cannot detect:

- `?` binds tighter than function application: `_?MemberQ["lead"]` is `(_?MemberQ)["lead"]` and matches nothing; write `_?(MemberQ["lead"])`.
- `Except` at a list key is the plain WL `Except`: `"classList" -> Except["ad"]` matches every list.
- A list pattern is positional: `{"item", "active", ___}` does not match `class="active item"`.
- `"class" -> "menu"` is an exact match on the raw string and misses `class="menu compact"`; the class-aware spelling is `"classList" -> "menu"`.
- A user-written `OrderlessPatternSequence` needs its `___` inside it.
