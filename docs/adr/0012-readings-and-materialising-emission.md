---
status: accepted (amended after implementation)
---

# A reading synthesises a `‹key›List` attribute, by an additive, query-driven materialisation

A [[reading]] — a microsyntax fixed to an attribute key — makes a **new, synthesised attribute** available to an [[XML pattern]]: the element's `class` stays the raw string it always was, and `classList` is its [[token list]]. The query says which one it means by naming the key, so a reading never changes what an existing key's value is. This ADR settles the reading table, the synthesised names, what an absent attribute reads as, and the emission that materialises a token list as a real, bindable subexpression without losing the original element.

> **Amended after implementation** (commits bc5ae39, ca3c763, a86bfa5). Corrected in place: the trim field is the string `"TrimWhitespace"`; the option is the string `"AttributeReadings"`, and an entry in it replaces the global's entry for that key whole; trimming strips HTML whitespace only; a `Roles`/`Constructs` function now receives the stripped element, so that Possible Issues residual is gone; the shipped cost is about 2.5×, not 1.7×. Added: the validation of reading tables, including the two list-key collisions it refuses. The design-time measurements are kept as history beside the shipped ones.
>
> **Amended again after implementation**: `Roles` and `Constructs` rules no longer run on a materialised tree. Written into "The emission is additive, not in-place" and "Materialisation is query-driven".

Supersedes ADR 0007 (`AttributeTest` and its `Condition` emission do not survive) and ADR 0008 (`TokenTest`/`ClassTest` do not survive; the options table does, renamed and rehomed below). Amends ADR 0009 on absence.

## Context

`ClassTest`/`TokenTest` (ADR 0006, 0008) tested a token list by splitting the raw string inside a `Condition` at match time and discarding the result the instant the `Condition` returned. That suffices for a Boolean test but not for binding: a bound token list must be a real subexpression for the binding to reach a rule's right-hand side, and that requires the token list to *exist on the tree*.

A first draft of this ADR materialised the token list but exposed it by **reinterpreting** the raw key: with a reading, `"class" -> spec` matched `spec` against the token list, and `Verbatim["class"]` opted back out to the raw string. That made one key mean two things depending on a global table — registering a reading silently changed the meaning of every existing query at that key — and it needed `Verbatim` to reach the value the document actually holds. A separately named attribute has neither problem, and the DOM already names it: `Element.classList`, and `relList` on `<a>` and `<link>`.

## Decision

### The reading table

A global, `$AttributeReadings`, maps a literal attribute key to its reading. It ships with one entry, `class`. Each entry has four fields:

| field | meaning |
| --- | --- |
| `Method` | `"SpaceSeparated"` (default) or `"CommaSeparated"` — pure shorthand *defining* the next two |
| `Delimiters` | `Automatic` (from `Method`), or an explicit string pattern |
| `"TrimWhitespace"` | `Automatic` (from `Method`), or an explicit Boolean |
| `"ListKey"` | `Automatic`, meaning `key <> "List"`, or an explicit string |

| `Method` | `Delimiters` | `"TrimWhitespace"` |
| --- | --- | --- |
| `"SpaceSeparated"` | `HTMLWhitespace` (ADR 0009) | `False` |
| `"CommaSeparated"` | `","` | `True` |

Trimming strips HTML whitespace (`HTMLWhitespace`, ADR 0009) from each token and nothing else, so a no-break space stays part of a comma-separated token, as the delimiter keeps it part of a space-separated one. A leading comma gives no leading empty token, since `StringSplit` drops it; the WHATWG comma parser keeps it. The divergence is kept.

An `"AttributeReadings"` option on the **consuming** functions (`XMLCases`, `XMLFirstCase`, `XMLDeleteCases`, `XMLMatchQ`, `HTMLInnerText`, `HTMLToNotebook`; a bare symbol `AttributeReadings` is accepted too) **adds to** the global rather than replacing it — the table used is `Join[$AttributeReadings, option]`, so an entry for a key the global already has replaces that entry whole, with no merging of fields — and is not on `XMLPattern` (ADR 0011: it takes no options, and stays inert so `XMLPattern[…] | XMLPattern[…]` composes and a reading resolves once per query). A global rather than an internal constant is chosen for inspectability: a user can print it. Accepted footgun, routed to documentation: `Block[{$AttributeReadings = …}]` drops the built-ins.

Reading keys are **literal strings**. The synthesised name must be computable from the entry, and a string-pattern reading key (`"data-" ~~ __`) would make a query's literal `"data-tagsList"` resolvable only by reversing a pattern.

The table in force — global joined with option — is validated each time a consumer is called, and a failure messages and gives `$Failed`, each an exactly-decidable refusal under `$AttributeReadings`: `::notassoc` (the table is not an `Association`), `::badkey` (a key is not a string), `::badentry` (an entry is not an `Association`), `::badfield` (an unknown field), `::badmethod`, `::badvalue` (a field value of the wrong kind), and two list-key collisions — `::duplistkey`, two readings with one list key, and `::listkeyisreading`, a list key that is itself a key with a reading, so that a query naming it would mean two things.

### The synthesised attribute, and absence

A query that names a list key (`"classList" -> …`) is matched against the element's token list for the corresponding raw key. An element with **no** raw attribute reads as `{}` at the list key, as a browser's `classList` does, and so do `class=""` and a whitespace-only `class`. The raw key keeps its presence semantics: `"class"` alone still asks whether the attribute exists, and `class=""` satisfies it. Absence reads as `{}` **only** for keys with a reading, so `relList` is `{}` on every element once a caller registers `rel` — harmless, and what the DOM does.

A list key is resolved by name, so a real attribute spelled like one is not reachable through it. The HTML importer lowercases attribute names (`classList="x"` arrives as `"classlist"`), so this can only happen in XML or hand-built trees, where the real attribute stays reachable through a binding on the whole attribute map (ADR 0011). This is a Possible Issues entry.

### The emission is additive, not in-place

The raw value is never rewritten. The token list is added to the element's attribute list under a private key head, beside the original, and the query's list key compiles to that private slot. The private head is what keeps the inverse exact: stripping it restores the element byte for byte (`strip[mat[e]] === e`, verified on imported and hand-built elements, children included), and it cannot be confused with any real attribute, including one named `classList`. In-place rewriting was rejected because its natural inverse is a riffle, which fails on hand-built and comma-microsyntax values, and with the absent ⇒ `{}` default would invent a `class=""` the source never had.

The compiler wraps every binding that can see the element's attributes in the inverse — an element binding, and a binding or test on the attribute argument:

```wl
(* user writes    *)  e : XMLPattern["p", "classList" -> cls_] :> {e, cls}
(* compiler emits *)  pat[e$]                                  :> With[{e = strip[e$]}, body]
```

`e` is identical to the original while `cls` binds the materialised list, from one match. A `PatternTest` on the attribute argument is applied to the stripped map.

`HTMLInnerText` and `HTMLToNotebook` never see a materialised tree. A `Roles` or `Constructs` rule is tried on one element at a time, so the rule set splits the distinct raw values on the tree once, up front, and attaches an element's token lists to a copy of it only when a rule is tried on it; the emitters walk the tree as it is, and a **function** right-hand side receives the element as it is in the tree with nothing to strip. They first ran on a tree materialised at entry, and relied on the emitters' output being byte-identical on it, which held but left `strip` calls in the emitters (and a bug where one was missing, a86bfa5).

### Materialisation is query-driven, and there is no cache

Only the list keys a query names are materialised, and only the **distinct** raw values on the tree are split. Measured at design time: 6.6 ms for one named key, 8.2 ms for two, against 7 ms for the `Condition` emission this replaces and 26 ms for eager tree-wide materialisation — 1.7× for one query on a tree, break-even at two. Measured on the shipped implementation at 5 000 elements: about 17 ms for one `classList` query against 6.8 ms for the superseded emission, about 2.5×. A query naming only raw keys materialises nothing and runs on the tree as it is.

For `Roles` and `Constructs` rules, measured with two list-key rules in each on 5 000 elements and on a real 2 000-element page: splitting each element's value whenever a rule is tried on it cost 18–45% more than materialising at entry, since `HTMLToNotebook` asks for an element's role up to three times; splitting the distinct values up front and attaching per element costs 4–7% more than materialising at entry, and is what ships. With a thousand-token `class` on 2 000 elements the per-element split was 3–4× slower.

No `Once` cache: whole-tree caching is ≈120× faster warm but retains up to 1.5 MB per tree with no cap, and per-string caching is measured 54× *slower* than a plain split and never warms. Splitting only the distinct values beats both — a real page has on the order of a dozen distinct `class` strings across thousands of elements.

### Namespaced keys never carry a reading

A `{namespace, name}` pair is a literal key but never has a reading: it is foreign vocabulary, and assuming an HTML microsyntax for it would be the unearned interpretation ADR 0004's absence-tolerance was rejected for.

## Considered options

- **Reinterpreting the raw key's value slot, with `Verbatim` to opt out** — the first draft; rejected, see Context.
- **A visible string key for the synthesised slot** — rejected. `strip` could not tell it from a real attribute of the same name, so the inverse would stop being exact.
- **Eager, tree-wide materialisation of every registered key** — rejected on measurement: ~18 ms per attribute per 5 000 elements (72 ms for eight keys) against a 28.8 ms parse, paid whether or not a query names the key.
- **`Once`-based caching** — rejected; see above.
- **Position-mapping** (`Position` on the materialised tree, `Extract` on the original) instead of an inverse — rejected. Cheap (5.3 ms against 5.0 ms for a plain `Cases`) but unable to serve a rule body, which is where the untouched element matters.
- **Per-element readings** — not needed for v1. The consuming-function option covers per-query readings.

## Consequences

**ADR 0009 is amended: `HTMLClassList` returns `{}` for an element with no `class`**, not `Missing["KeyAbsent", "class"]`, so that extraction and `"classList"` agree about the same element, as a browser's `classList` does. The raw attribute's presence stays a separate question, asked of `"class"`.

**The class list keeps duplicate tokens, and so diverges from a browser's `classList`, deliberately.** `class="lead lead promo"` gives `{"lead", "lead", "promo"}`. The WHATWG ordered-set parser behind `Element.classList` deduplicates on read, but the DOM stores the attribute value with its duplicates — `getAttribute("class")` is `"lead lead promo"` — so the token list agrees with the document, and only differs from one view of it. Deduplication is one `DeleteDuplicates` away; the reverse is impossible.

Materialisation costs about 2.5× the superseded `Condition` emission for one query naming one list key (1.7× in the design-time prototype) — the price of bindable tokens and a lossless inverse. Queries on raw keys pay nothing.

Extending `$AttributeReadings` no longer changes the meaning of any existing query: it only makes a new key available. This holds for the default `key <> "List"` names, which the HTML importer's lowercasing keeps apart from every imported attribute. An explicit `"ListKey"` is taken at its word: one that names a real attribute, such as `"ListKey" -> "href"`, takes that name over, and that is the caller's choice. It is neither refused nor warned about.
