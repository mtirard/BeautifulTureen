---
status: accepted (supersedes ADR-0018 in part)
---

# Positions count element children from the document

ADR 0024 makes a result's identity a tuple of positions, and `XMLPosition`, `XMLExtract` and `XMLReplace` expose them. Their representation is user-facing.

## Decision

A position is a list of **element-child indices from the document**, with at most one terminal step:

```
position := {i₁, …, iₖ} | {i₁, …, iₖ, terminal}
terminal := 0 | Key[All] | Key[key] | Key[listKey] | Key[listKey], tail | All | m ;; n | n ;; n-1
tail     := i | m ;; n | n ;; n-1
```

- `{}` is the document. An `XMLObject`'s root element is `{1}`, a list input's `i`-th element `{i}`, and a bare `XMLElement` input is wrapped as `{1}` under a virtual document.
- Indices count **element children only**, as the DOM's `children` does. **Text is not a position**, as in CSS; it is reached through its element.
- `0` is the tag (part 0 is the head throughout WL). `Key` wraps attribute keys, so they never collide with structural steps; `Key["class"]` is the raw string and `Key["classList"]` its token list. `All` is the contents, text included. A run is a span; a gap is an empty span, `n ;; n-1`, the place before element child `n`.

`XMLPosition[input, lhs :> rhs]` gives `rhs` with each counted name replaced by its position. `XMLExtract` mirrors `Extract`.

## Considered options

- **WL part specifications** (`{2, 3, 1, 3, 2}`). The `3` for `XMLElement`'s contents slot at every level is unreadable, whitespace text shifts indices, and a gap between two elements separated by text has no empty span. `Extract` compatibility is not needed, as the paclet provides its own functions.
- **Attribute indices.** The attribute map's order carries no meaning.
- **Positions relative to the input** rather than the document. A bare element and `{e}` would number differently, and `XMLDocument` patterns would have no base.
- **A head wrapping positions.** Lists sort with `LexicographicSort` into document order and read as WL part lists.

## Consequences

- A counted name that binds text, possible only inside an `XMLElement` pattern's contents, is refused.
- Rewriting by position (`XMLReplacePart`) is out of scope; `XMLReplace` rewrites at matched places.
