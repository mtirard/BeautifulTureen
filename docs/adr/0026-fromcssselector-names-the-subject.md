---
status: accepted (supersedes ADR-0017)
---

# `FromCSSSelector` names the subject of a context selector, and never invents that name

A CSS selector has an implicit subject; a query here has no implicit result (ADR 0024). `"nav a"` must become a pattern rooted at the `nav` with the `a` named, and something has to choose that name.

## Decision

### Carried over from ADR 0017

Static Selectors Level 4, literal case, no namespaces, no soupsieve extensions; a literal translation against the importer's tree; no readings option; the refusals `::invalid`, `::unsupported` and `::impossible`; forgiving `:is()`; a bare string is CSS wherever a pattern goes; `XMLPattern`'s tag slot unchanged; a translation is a visible pattern with no private heads, and a CSS-side optimisation is a choice of which pattern to emit (from ADR 0020, which this supersedes with ADR 0017). The measurements of ADRs 0017 and 0020 stay as history.

### One-element and context selectors

A **one-element selector** looks only at its subject and below (a compound, downward `:has()`, `:not()`/`:is()`/`:where()` over compounds, a list of these). It is a pattern. A **context selector** picks its subject by what is above or beside it. It is a pattern only once its subject is named.

- `FromCSSSelector[s]` accepts one-element selectors only. A context selector is `FromCSSSelector::name`, which suggests `FromCSSSelector[n : s]`.
- `FromCSSSelector[n : s]` gives the pattern rooted at the first compound with the subject named `n`: `FromCSSSelector[n : "nav a"]` is `XMLPattern["nav"][Descendant[n : XMLPattern["a"]]]`.
- Consumers that accept an unnamed context selector name its subject themselves, out of sight.

Two substitution statements hold wherever their form is accepted: `s` ⇔ `FromCSSSelector[n : s] :> n` for a fresh `n`, and `n : s` ⇔ `FromCSSSelector[n : s]`. Naming is transparent: where adding `n :` would change an answer, the named form is refused.

### What the tree form adds

Selector lists become one pattern over alternatives sharing `n`, so their union needs no merge (ADR 0015 ran and merged chains). A parent that may be the document is `XMLPattern[_][L] | XMLDocument[L]`. A translation writes constraints in the bracket form of ADR 0023, and a `>` child as `Child[p]`, named or not, as in `Child[n : XMLPattern["li"]]` for `"ul > li"` with the `li` named; positional selectors keep their list forms, so the position stays visible. Complex `:not()`, `:is()` and `:where()` over descendant and `>` combinators become tests on the subject's path, so `a:not(nav a)` and `x :is(a b)` translate. `:has(+ …)` and `:has(~ …)` translate, rooted at the parent. `:not(:has(…))` is `XMLFreeQ` with a level spec.

### Counted positions without conditions over runs

ADR 0017 wrote some counted positions as a `Condition` over a run of siblings, `{g___, n : C, ___} /; Count[{g}, …] …`, and ADR 0020 recognised that form (shape 7) because WL's matcher, and any engine walking the list, tests it once per candidate over a run: quadratic. The translation now avoids it. Typed `-of-type`, `of S` and positions inside `+`/`~` runs are plain entries. `-of-type` on a compound with no type uses a fresh uncounted tag name shared into `Except`, as in `{Except[XMLPattern[t$_]] ..., n : XMLPattern[t$_], ___}` for `:first-of-type`. For that, a name inside `Except` that is also bound outside it refers to that binding wherever it is, which differs from WL only where WL's answer is degenerate (an `Except` before its name is bound matches nothing). Two positions on one compound use a fixed prefix when one is a fixed index; only two `An+B` positions keep the general condition form, and its quadratic cost is accepted. No recognised shapes remain.

## Considered options

- **A generated subject name in `FromCSSSelector`'s output** (`e$`). The user would see it, it could collide when spliced into a larger pattern, and two translations would bind the same name.
- **A general meaning for a rule on the left of a query arrow**, so that `"nav a" :> v` counts the subject. It invites `((q :> x) :> v) :> w`; with no nesting, `"a" :> 1` gives `{1}` as any rule without counted names does.
- **Alternatives of rules, or a list of rules, for selector lists.** The first rule would win where CSS takes the union.
- **Keep the condition form and recognise it (ADR 0020's shape 7 restated).** Linear, and it keeps WL's left-to-right reading of `Except`, but it keeps a shape table whose recognisers must track the compiler, for what is mostly an edge case.
- **A contents-list construct for "the same tag as `n`".** Not WL, and it covers only the tag.

## Consequences

- `XMLCases[t, "nav a"]` and `"Roles" -> {"nav a" -> "Block"}` work unchanged for users; `XMLCases[t, "nav a" :> v]` is refused, and `n : "nav a" :> v` is the spelling.
- `XMLMatchQ` refuses context selectors with a message saying the selector looks above the element.
