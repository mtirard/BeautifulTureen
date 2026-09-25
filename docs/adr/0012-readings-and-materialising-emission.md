---
status: accepted
---

# A reading synthesises a `‹key›List` attribute, by an additive, query-driven materialisation

A [[reading]] — a microsyntax fixed to an attribute key — makes a **new, synthesised attribute** available to an [[XML pattern]]: the element's `class` stays the raw string it always was, and `classList` is its [[token list]]. The query says which one it means by naming the key, so a reading never changes what an existing key's value is. This ADR settles the reading table, the synthesised names, what an absent attribute reads as, and the emission that materialises a token list as a real, bindable subexpression without losing the original element.

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
| `TrimWhitespace` | `Automatic` (from `Method`), or an explicit Boolean |
| `"ListKey"` | `Automatic`, meaning `key <> "List"`, or an explicit string |

| `Method` | `Delimiters` | `TrimWhitespace` |
| --- | --- | --- |
| `"SpaceSeparated"` | `HTMLWhitespace` (ADR 0009) | `False` |
| `"CommaSeparated"` | `","` | `True` |

An `AttributeReadings` option on the **consuming** functions (`XMLCases`, `XMLFirstCase`, `XMLDeleteCases`, `XMLMatchQ`, `HTMLInnerText`, `HTMLToNotebook`) **adds to** the global rather than replacing it, and is not on `XMLPattern` (ADR 0011: it takes no options, and stays inert so `XMLPattern[…] | XMLPattern[…]` composes and a reading resolves once per query). A global rather than an internal constant is chosen for inspectability: a user can print it. Accepted footgun, routed to documentation: `Block[{$AttributeReadings = …}]` drops the built-ins.

Reading keys are **literal strings**. The synthesised name must be computable from the entry, and a string-pattern reading key (`"data-" ~~ __`) would make a query's literal `"data-tagsList"` resolvable only by reversing a pattern.

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

`e` is identical to the original while `cls` binds the materialised list, from one match. A `PatternTest` on the attribute argument is applied to the stripped map. `HTMLInnerText` and `HTMLToNotebook` need no special-casing: output is byte-identical on a materialised tree, verified including hyperlinks and tables. A `Roles`/`Constructs` **function** right-hand side still receives the materialised element; that residual is a Possible Issues entry, since there is no exactly-decidable check against an arbitrary function.

### Materialisation is query-driven, and there is no cache

Only the list keys a query names are materialised, and only the **distinct** raw values on the tree are split. Measured: 6.6 ms for one named key, 8.2 ms for two, against 7 ms for the `Condition` emission this replaces and 26 ms for eager tree-wide materialisation — 1.7× for one query on a tree, break-even at two.

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

Materialisation costs about 1.7× the superseded `Condition` emission for one query naming one list key, break-even at two — the price of bindable tokens and a lossless inverse.

Extending `$AttributeReadings` no longer changes the meaning of any existing query: it only makes a new key available.
