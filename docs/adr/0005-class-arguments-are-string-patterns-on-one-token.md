---
status: superseded by ADR-0006
---

# A `CSSClass` argument is a string pattern matched against **one class token**

> **Superseded by [ADR 0006](./0006-three-levels-token-predicate-quantifier-conjunction.md).** Per-token matching survives as a _mechanism_, but the surface is gone: `CSSClass` is replaced by `ClassTest`, the implicit ∃ this ADR legislates becomes an explicit quantifier, and `Except` at the top level is removed as a category error.
>
> **Correction, and it is stronger than this ADR's own closing note.** The closing note calls the `CSSClass[Except[…]]` level jump an _unstated exception_. In fact **`Except["ad"]` is not a legal string pattern at all** — `Except`'s first argument must be single-character-width, so `StringMatchQ["x", Except["ad"]]` issues `StringExpression::invld` and comes back unevaluated. `Except["a"]` _is_ legal and means "any single character other than `a`". So the construct's very legality depended on the **length of the user's class name**, and both spellings were accepted only because `CSSClass` unwrapped `Except` before any string pattern saw it (the `CSSClass[Verbatim[Except][cls_]]` rule, removed in `bc5ae39`). That is the concrete evidence the level muddle was real rather than cosmetic.

Each argument to `CSSClass` is matched with `StringMatchQ` against the individual tokens of the element's class list (`StringSplit` of the `class` attribute), and the constraint holds when **some** token matches. No argument is reinterpreted: `_` is one character, `__` one or more, `___` zero or more, exactly as `StringsAndCharacters` documents, all scoped to a single class.

## Context

Through v1.2.5 the argument was matched against the **whole attribute value**, wrapped to fake token boundaries:

```wl
(___ ~~ Whitespace) ... ~~ cls ~~ (Whitespace ~~ ___) ...
```

That wrapper only bounds a _literal_; it cannot stop a pattern from spanning the boundary itself, and it lets whitespace-only values in. Both leaks were real:

|  | whole value | one token |
| --- | --- | --- |
| `CSSClass["lead" ~~ __]` vs `class="lead promo"` | matches — the `__` eats `" promo"` | no match |
| `CSSClass[__]` vs `class="   "` | matches | no match |
| `CSSClass[_]` vs `class="   "` | matches (one space is one character) | no match |
| `CSSClass[_]` vs `class="lead"` | no match | no match |

A prefix query like `CSSClass["col-" ~~ __]` is the ordinary reason to write a string pattern here, and it silently reported elements whose _later_ classes happened to follow a `col-` one.

`CSSClass[_]` matching nothing but one-character classes was the visible symptom, and v1.3.0 first "fixed" it by expanding a bare Blank to `Except[WhitespaceCharacter] ..` — "any one token". That was the wrong fix: the arguments are string patterns, so a Blank _should_ mean one character, and special-casing it buys one spelling of "any class" at the price of a rule the reader has to be told. Matching per token gives the same expressiveness with no special case, and fixes the boundary leak that the Blank patch left untouched.

## Decision

Match per token. Accept `_BlankSequence` and `_BlankNullSequence` alongside `_Blank` as arguments — with per-token matching they are meaningful (`__` and `___` both come to "any class at all", since a class token is never empty), whereas against the whole value `___` would have matched `class=""` and made `Except[___]` unsatisfiable.

`StringSplit` collapses the three ways of carrying no classes — no attribute (via the `""` default, see ADR 0004), `class=""`, and whitespace-only — to the empty class list, which is the behavior the browser has and the property ADR 0004 requires.

## Considered options

- **Keep whole-value matching and special-case `_`** (shipped briefly in 1.3.0) — rejected: it overrides documented string-pattern semantics for one spelling, leaves `__`/`___` rejected as arguments, and does nothing about a composite pattern running past a class boundary.
- **Bound the token with `Except[WhitespaceCharacter] ...` on both sides instead of `___ ~~ Whitespace`** — a tighter wrapper, but still one match against the whole value, so a `__` _inside_ the argument can still cross a boundary. Only splitting first makes the boundary structural.

## Consequences

`CSSClass[_]` again means "carries a one-character class", so "carries no classes" is written `CSSClass[Except[___]]`. Class matching now costs a `StringSplit` per element (~1 µs), negligible against tree traversal.

A `PatternTest` argument (`_?f`, `__?f`) remains accepted but does not do what it looks like: in a string pattern the test applies per character, not to the token. Unrelated to this decision, and unresolved.
