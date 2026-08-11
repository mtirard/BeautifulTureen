---
status: accepted
---

# `AttributeTest` quantifies the attribute set; emission stays `KeyValuePattern` plus one `Condition`

`AttributeTest[q]` is an element-level constraint, sitting alongside `ClassTest[…]` and `"href" -> _` in `XMLPattern`'s constraint slot. Its quantifier `q` — the same `AnyTrue` / `AllTrue` / `NoneTrue` trio as the token level (ADR 0006) — ranges over the element's **whole attribute set**, and its operand is an **attribute pattern**. The emitted pattern remains `KeyValuePattern` for positive rules plus **one** `Condition` `&&`-joining every quantifier.

## Context

"This `<p>` has an `href` and no other attributes" was a sentence with no syntax. Attribute-level ∀ and ¬∃ were inexpressible, and the mechanism that made them free never proposed a user-facing spelling — this was a hole, not a choice between known options.

## Decision

### The operand is an attribute pattern, not a string

`q`'s operand matches a `key -> value` **rule**, reusing the one sugar `XMLPattern` already has: a bare `key` means `key -> _`.

```wl
XMLPattern["a", AttributeTest[NoneTrue["class"]]]                    (* carries no class attribute   *)
XMLPattern["p", "href" -> _, AttributeTest[AllTrue["href"]]]         (* href and nothing else        *)
XMLPattern["p", AttributeTest[AnyTrue[Matching["data-" ~~ __]]]]     (* has some data-* attribute    *)
XMLPattern["p", AllTrue["href" | Matching["data-" ~~ __]]]           (* href and data-* only         *)
```

Note the deliberate **asymmetry with the token level**: a bare string pattern falls through to a predicate at the token level, but needs `Matching` in a key position here. This is principled rather than inconsistent — the fallthrough tracks the element type of the collection being quantified over. Tokens _are_ strings; attributes are rules.

This choice was made on measurement, not taste. Quantifying over `Keys` with a raw `StringMatchQ` makes namespaced `{namespace, name}` keys — which the importer really does produce — **silently vanish** from every quantifier, since they are not strings. `MatchQ` of an attribute pattern handles them for free.

`Except` is legal in the key slot, because there it is a genuine key _pattern_ inside an explicit quantifier. Bare `Except["href"]` as a constraint has **no meaning** and is refused: "∃ a non-`href` attribute" and "∀ attributes are non-`href`" (i.e. `href` is absent) are both implementable and they disagree, so a pattern head cannot stand in for a quantifier. This is the top-level-`Except` category error of ADR 0006, one level up.

Multiplicity does not arise: the HTML parser collapses duplicate attributes before we see them.

### `AttributeTest` is the only element-level constraint

Everything else is a `KeyValuePattern` rule. `AttributeTest` is therefore the only construct that needs a `Condition`, and several quantifiers on one element `&&`-join into a single one.

The measured price is worth stating plainly, since it is the kind of number a later reader will otherwise rediscover and re-litigate. On a 5 000-element page: `KeyValuePattern` alone is ~3 ms; with one `Condition` carrying a quantifier, ~38 ms. **One quantifier costs ~35 ms, and that cost is flat in the number of attribute rules.** Flatness is the property that makes this shape win.

That is a _larger_ number than the ~14 ms over which ADR 0006 retired confinement, which looks inconsistent and is not: confinement was an optimisation with a working alternative, whereas here there is no cheaper way to express a quantifier at all.

## Considered options

- **`{OrderlessPatternSequence[pos…, filler…]}` as the sole emitted attribute shape**, replacing both `KeyValuePattern` and the `PatternTest` wrapper — **rejected on measurement.** The source design claimed `Orderless` performs the permutation search so there is "no `n!` blowup, verified to 3 positives plus a negation". Three positives is exactly one short of where the blowup starts. On a 5 000-element page, hit counts equal throughout (`assets/ops-scaling.wls`, `assets/ops-open-world-scaling.wls`):

  | positives | `KeyValuePattern` (+ `Condition`) | OPS       | ratio    |
  | --------- | --------------------------------- | --------- | -------- |
  | 3         | 37.9 ms                           | 117.7 ms  | 3.1×     |
  | 4         | 37.9 ms                           | 632 ms    | 16.7×    |
  | 6         | 38.4 ms                           | 14 500 ms | **377×** |

  Plain open-world `{OPS[pos…, ___]}` — the proposed replacement for `KeyValuePattern` in the _common_ case, with no quantifier involved at all — is **402× slower at 6 positives**. Expressiveness was a dead heat across five queries including attribute absence and namespaced keys (`assets/ops-vs-condition.wls`), so there was never anything to weigh against this. Recorded as rejected on measurement rather than "unmotivated", because the weaker phrasing invites revival and the original claim of speed is still written down elsewhere.

- **A filler slot to express absence** — falls with OPS, which is where the filler lived. Absence is a quantifier (`NoneTrue`), not a hole in a sequence. The term `filler` is consequently **not** in the glossary; there is no filler in any shipped shape.

- **Quantifying over a _remainder_** — the attributes left after the positive rules are matched. This premise came from the filler slot, and once a `Condition` is the mechanism the carve-out never arises: `q` ranges over the whole attribute set and **∀ means ∀**. Measured identical to the OPS filler in results, with the carve-out itself spellable when wanted, as `AllTrue["href" | Matching[…]]`.

- **Quantifying over `Keys` with a bare string pattern** — rejected on the namespaced-key measurement above.

## Consequences

Both levels compose in one emitted pattern, verified: `XMLPattern["p", ClassTest[AnyTrue["lead"]], AttributeTest[NoneTrue["href"]]]` emits one `KeyValuePattern` and one `Condition`.

`OrderlessPatternSequence` is legal at this level and **illegal inside string patterns**, where `AnyOrder` and `FixedOrder` are the counterparts. Keep the vocabulary per level distinct; do not let one word name both.

Anything building a `Condition` must know that `f[q_] := pat /; cond` is read by WL as a conditional **definition**: the `/; cond` becomes a guard on the definition rather than part of the pattern returned, and since `cond` refers to names bound only _inside_ `pat`, the guard never holds and `f[…]` silently comes back unevaluated. The same trap applies to `With[{…}, expr /; cond]`. The escape survives `:=` with arguments:

```wl
mk[q_] := Condition @@ Hold[XMLElement["p", attrs : KeyValuePattern[{}], _],
                            q[tokenise[Lookup[attrs, "class", ""]]]];
```

Assets: `assets/attrset-surface.wls` (every candidate spelling as a real emitter against 12 fixtures), `assets/ops-vs-condition.wls`, `assets/ops-scaling.wls`, `assets/ops-open-world-scaling.wls`.
