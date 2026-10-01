---
status: superseded by ADR-0012
---

# `TokenTest` takes options, with `Method` as pure shorthand for `Delimiters` and `TrimTokens`

A [[token list]] is produced by `StringSplit`, and `TokenTest` is told how to split by three symbol-keyed options — `Method`, `Delimiters`, `TrimTokens` — where `Method` is **pure shorthand** _defining_ the other two rather than an opaque enum beside them. `ClassTest` is a **reading**: it fixes a key _and_ a microsyntax, and it is the only reading that ships.

> **Superseded by [ADR 0012](./0012-readings-and-materialising-emission.md), body retained.** `TokenTest` and `ClassTest` are dropped along with the rest of the pattern-construct vocabulary (ADR 0011). **What survives outright, rehomed onto the `$AttributeReadings` table:** the `Method`/`Delimiters`/`TrimTokens` two-layer resolution (renamed `TrimWhitespace`, and joined by a `"ListKey"` field naming the synthesised attribute), the `StringSplit`-for-both-microsyntaxes finding, and the reasoning against key inference and a user-supplied tokeniser. `class` remains the only reading that ships by default; the table now lives as a global a caller can extend, rather than as an argument to a dropped constructor.

## Context

`TokenTest[q]` applies a quantifier to the tokenised value, and ADR 0006 makes it a plain rule-position construct available at **any** attribute. But HTML has **two** token microsyntaxes:

| microsyntax | attributes |
| --- | --- |
| space-separated | `class`, `rel`, `headers`, `sandbox`, `ping`, `itemprop`, `aria-labelledby` |
| comma-separated | `accept`, `coords` |

So tokenisation could no longer be nailed shut at HTML's ASCII whitespace, and something had to carry the choice.

## Decision

### The options, and how they resolve

| `Method` | `Delimiters` | `TrimTokens` |
| --- | --- | --- |
| `"SpaceSeparated"` (default) | `" " \| "\t" \| "\n" \| "\f" \| "\r" ..` | `False` |
| `"CommaSeparated"` | `","` | `True` |

`Automatic` on a primitive means "take this field from `Method`". An explicit value overrides **that field only**, so `TokenTest[q, Method -> "CommaSeparated", TrimTokens -> False]` is a coherent thing to write.

The enum-versus-primitives dichotomy was false: both ship, layered. What makes the layering work is that **`Delimiters` takes any string pattern**, not just a literal. This is the load-bearing choice — `"SpaceSeparated"` is _inexpressible_ as a literal-string delimiter, so a literal-only `Delimiters` would collapse `Method` back into exactly the opaque enum the layering exists to avoid.

`Method`'s default is the **literal** `"SpaceSeparated"`, never `Automatic`. `Automatic` would read as a promise to infer the microsyntax from the attribute key, and that promise cannot be kept (see below).

### Options are symbol-keyed; everything else is a token predicate

ADR 0006 leaves extra arguments to `TokenTest` as conjoined predicates, which settles the disambiguation rule: **a symbol-keyed `Rule` is an option; every other argument falls through to a token predicate.** Two consequences are surface-visible and worth stating:

- A **positional** microsyntax was never available. `TokenTest[q, "comma-separated"]` already means "…and has a token spelled literally `comma-separated`".
- This departs from the repo's existing string-keyed options (`Options[HTMLInnerText]`, `Kernel/BeautifulTureen.wl:787`). Not a semantic distinction — symbols are the more idiomatic WL form, and they are what makes the rule above expressible at all.

### `ClassTest` is a reading, and the only one

The distinction is load-bearing and easy to get wrong:

- A **microsyntax** is key-independent. `class`, `rel`, `headers`, `ping` and `itemprop` all share the space-separated one.
- A **reading** fixes a key _and_ a microsyntax.

`ClassTest` is a reading, not "the named microsyntax" — if it were the latter, `"rel" -> ClassTest[q]` would have to type-check. This is also the real answer to "what is `ClassTest` for", which brevity alone does not supply: it is the one construct where a user never has to learn that the microsyntax vocabulary exists at all. No sibling readings ship. `class` earns a head by sheer dominance in real queries; `"rel" -> TokenTest[q]` is already short enough.

### Emission is `StringSplit`, one code path for both

ADR 0006's decision stands — HTML's ASCII whitespace, **not** `StringSplit`'s Unicode default — but the mechanism moves from `StringCases[Except[htmlWS] ..]` to `StringSplit[v, delims]`. This is a correction rather than a decision, forced by a measurement.

The two microsyntaxes **disagree about empty tokens.** The spec says of comma-separated lists that "the empty string can be a token" — its own example `"a ,b,,d d"` yields **four** — while space-separated is defined as words separated by one or more ASCII whitespace, so empties cannot arise. `StringSplit` reproduces both exactly, empties included, with no third option needed. An asymmetry that looked like it would cost a parameter cost nothing.

One deliberate divergence: `accept=""` gives `{}`, where the spec's algorithm arguably yields a single empty token. `{}` is what we want — it is what makes `AllTrue` vacuous and `NoneTrue` true on an empty attribute, consistent with `class=""` (ADR 0006).

## Considered options

- **Key → microsyntax inference** — `"accept" -> TokenTest[q]` choosing commas by itself. Refused **structurally**, not on taste: `TokenTest` never receives the key, and routing the key to it would make `t = TokenTest[q]` mean different things at different keys, destroying the referential transparency of a bound pattern.
- **A user-supplied tokeniser function** — rejected. A `Function` in the emitted pattern reintroduces precisely the closure that retired confinement (ADR 0006), and the escape hatch already exists with no new vocabulary: the plain value slot accepts any pattern, so `"style" -> _?(myOwnTest)` is available today at full power.
- **A third `Method` value for the empty-token disagreement** — unnecessary, per the `StringSplit` finding above.

## Consequences

Refusing key inference has a price, and it is a silent one: `"accept" -> TokenTest[AnyTrue["image/png"]]` **under-matches**, because it splits on whitespace while `accept` is comma-separated. This is the cost of structural refusal, and it belongs in a **Possible Issues** documentation section (ADR 0006's standing rule), naming the comma attributes against the space-separated ones.

**Two-level attributes are out of scope** — `srcset` and `sizes` (comma, then space), `style` (semicolon, then colon), `allow`. They are not token lists at all: they are **parsed**, each by its own spec algorithm, and naive splitting is unsound in a visible way. `style="background-image: url(data:image/png;base64,…); color: red"` split on `;` then `:` yields `{{"background-image", "url(data:image/png"}, {"base64,…)"}, {"color", "red"}}`, with one entry having lost its key entirely. There is a deeper reason too: the natural result of parsing one is an `Association`, whose quantifier operand is a `key -> value` attribute pattern — that is `AttributeTest`'s operand language (ADR 0007), not `TokenTest`'s. A delimiter argument that silently switched the operand language would be unpredictable, so if a use case appears this starts from `AttributeTest`'s shape, not this one.

Asset: `assets/split-emission.wls`.
