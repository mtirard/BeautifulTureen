# A class negation reads a missing `class` attribute as an empty class list

`CSSClass[Except[cls]]` matches an element that does not carry class `cls`, **including an element with no `class` attribute at all**. A missing `class` and `class=""` are the same fact — an empty class list — so no `CSSClass` constraint may distinguish them.

Through v1.2.5 they were distinguished, and not by design. `CSSClass` returns a constraint that `XMLPattern` drops into `KeyValuePattern`, and `KeyValuePattern` requires the key to be **present** before the value pattern is consulted. So an absent `class` never reached the negation test: it was not "fails the test" but "never took the test". The tell that this was a leak rather than a decision: `class=""` _passed_ `Except["a"]` while a missing `class` failed it, although the two elements have identical class lists. `Except` also had no test coverage.

The cost was silent wrong answers. `CSSClass[Except["ad"]]` — the natural way to write "everything but the ads" — missed every element carrying no class, which on a real page is most of them, with no message and no visible symptom. CSS `p:not(.a)` matches a classless `<p>`, and `CSSClass` is our abstraction over that same class-list model, so the class list is what it must select on.

**Mechanism.** A negation cannot be expressed as a `KeyValuePattern` rule at all, so it is lifted out of the rule list: positive constraints stay in `KeyValuePattern` and the negations become a `PatternTest` on the whole attribute list, reading the class list as `Lookup[attrs, "class", ""]`. Mixed `CSSClass["promo", Except["a"]]` splits into both parts. `""` is the right default because the class list of `""` is empty (ADR 0005), which is exactly the fact a missing attribute states.

**Knock-on.** `CSSClass[Except[___]]` means "carries no classes" and works — the mirror of `CSSClass[___]`, "carries at least one class". An empty class list fails both directions however it arose: no attribute, `class=""`, or whitespace only. Element **presence** of the attribute, when that is genuinely what you want, remains the bare-attribute shorthand `XMLPattern["p", "class"]`, which `class=""` satisfies.

## Considered options

- **Reinterpret raw negated rules too** (`"href" -> Except["#"]` matching an element with no `href`) — rejected. A raw rule is the user's own WL pattern going into a documented `KeyValuePattern`; presence-requiring is the honest behavior there, and silently rewriting a user's `Except` would be magic. The escape hatch for absence-tolerant raw attributes is the condition form: `el:XMLPattern["a"] /; !MatchQ[Lookup[el[[2]], "href", ""], "#"]`.
- **Leave it and document it** — rejected: the `class=""` / missing-`class` split is not defensible under any model of "does this element have class `x`", and the failure is a silent wrong answer.
- **Build the whole attribute pattern as a predicate on the attribute list** (dropping `KeyValuePattern`) — rejected: `KeyValuePattern` is the right, readable tool for the positive cases and for namespaced pair keys; only negation needs the lift.

## Consequences

Breaking for anyone who relied on `CSSClass[Except[…]]` skipping classless elements (v1.3.0). `CSSClass` may now return a **list** of constraints when positives and negations are mixed; `XMLPattern` already flattens its constraint sequence, so this is invisible at the call site, but `CSSClass` output is only meaningful inside `XMLPattern` — it is not a `KeyValuePattern` rule in general.
