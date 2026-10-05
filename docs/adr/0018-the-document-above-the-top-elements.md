---
status: accepted
---

# Every input has a document above its top elements, matched by `XMLDocument[]`

A query cannot say where an element sits relative to the input it was given. Four features wait on that: list stages that reach the root (ADR 0016 left `html:first-child` unmatched), CSS's `:root` and `:scope` (refused by ADR 0017), and a children-only search, bs4's `recursive=False` (set aside in #14). They are decided together here, so that no one of them settles it by accident. The design was settled in `.scratch/css-selectors/issues/07-decide-how-a-query-reaches-the-root-and-the-input.md`, and the implementation spec is `.scratch/css-selectors/specs/root-and-input.md`.

## Decision

### The input is the whole tree, and is never a result

A query sees nothing outside the tree it is given. A **top element** is an element with no element parent inside that tree:

- for an `XMLObject` document, its root element;
- for a bare `XMLElement`, the input itself;
- for a list, each top-level `XMLElement`. A list holds elements and strings only (`validTreeQ`), though the `::badtree` messages say "a list of these", documents included.

ADR 0014 stands: the input itself is never a result, as `Cases` never returns level 0. So a bare `XMLElement` input's top element is never a result, and every other top element can be one. This is the DOM's answer. `document.querySelectorAll("html")` gives `html`, and `el.querySelectorAll(…)` never gives `el`. soupsieve agrees: `body.select(":scope")` is `[]`.

### The document

Above the top elements is a **document**:

- for an `XMLObject` input, the `XMLObject`;
- for a list input, the list. Should a list ever hold documents, each `XMLObject` in it is the document of its own root element, so that a document's root behaves the same alone and in a list;
- for a bare `XMLElement` input, a virtual parent whose only child is the input.

`XMLDocument[]` is a stage that matches the document. It takes no arguments, because Selectors 4 calls a virtual root "featureless". Its element children are the top elements below it, with text, comments and declarations left out, as a list stage always leaves them out. So a document input's root element is the only element child of its document, and a list input's top-level elements are siblings.

`XMLDocument[]` may be a first stage, alone or as a branch of alternatives in the first stage (`XMLDocument[] | XMLPattern[_]`). Everywhere else it is `::badpat`: as a later stage, as the whole query (where it could never select anything), named (`d : XMLDocument[]`, as a named combinator is refused), and with arguments. `XMLMatchQ` and the `Roles`/`Constructs` rules refuse it, because it is not an [[Element pattern]].

### What follows from it

- **List stages at the top.** "Any parent" in a list stage is `XMLDocument[] | XMLPattern[_]`. `Child[XMLDocument[] | XMLPattern[_], {x : XMLPattern["html"], ___}]` is `html:first-child`, and selects the root of a document input, as Selectors 4 and soupsieve do. On a bare `html` input it serves as the first stage of `html:first-child > body`, and is not itself a result.
- **`Adjacent` and `Sibling`** are shorthands for that list stage: `Adjacent[a, b]` is `Child[XMLDocument[] | XMLPattern[_], {___, a, b, ___}]`. So they now match across the top-level elements of a list input, where they gave `{}`. Selectors 4 treats a DocumentFragment's children as siblings in the same way.
- **`:root`** is `Child[XMLDocument[], {x : XMLPattern[_]}]`, the only top element under a document, with the compound merged into `x`. soupsieve gives no `:root` for a fragment with two top-level elements, and neither does this.
- **`:scope`** translates as `:root`. A query here always runs on the whole tree, so the scoping element is either the only top element (a bare `XMLElement` input) or absent, in which case Selectors 4 makes `:scope` the root.
- **A children-only search** needs no option and no new combinator. `soup.find_all("p", recursive=False)` is `Child[XMLDocument[], XMLPattern["p"]]`, which gives the top-level `p`s of a list and the root element of a document if it is a `p`. `tag.find_all("p", recursive=False)` is `Child[XMLDocument[], XMLPattern[_], XMLPattern["p"]]`, or the CSS string `":scope > p"`.
- **`XMLDeleteCases`** deletes a list's top elements, as it does now, and never the input. It does not delete a document's root element: an `XMLObject` needs one. It issues `XMLDeleteCases::root` and gives the document with its other deletions made.

## Considered options

- **A list stage with no parent counts the top elements as children of an unnamed parent.** No new head, but the parent is implicit, `Child[_, XMLPattern["html"]]` would change meaning on a document, and nothing names the document for `:root` or a children-only search.
- **A stage that names only the input (`XMLScope[]`).** It covers `:scope`, but a document's root element still has no parent to be listed under. On a bare element input, the scope is the element, not its parent, so it is a different node from the document.
- **No virtual parent above a bare `XMLElement`.** Then `html:first-child > body` would match on a document input and not on the same `html` given bare.
- **Every top element is a result**, so that the three inputs agree. It breaks ADR 0014 and WL's level-0 rule, and the DOM, which never returns the element a query is called on.
- **`_` as a stage meaning "any element or the document".** It is `::badpat` today. It would be a second spelling beside `XMLPattern[_]` that differs only at the top. The alternatives say the same thing with what exists.
- **A marker inside `XMLPattern` for `:scope`.** A marker is needed in the DOM because a query there can look above its scope. Here it cannot, so the scope is always the document or the only top element, and both have spellings.
- **A list input as one document whose children are every top element**, including the roots of documents in it. A document's root would then behave differently alone and in a list.
- **Deleting a document's root element.** `XMLDeleteCases` does this today, and the result `XMLObject["Document"][prolog, {}, epilog]` is not a valid `XMLObject`.

## Consequences

Possible Issues, for documentation:

- soupsieve also refuses `:root` when there is top-level text. A list stage does not see text, so this does not.
- On a list input with several top elements, Selectors 4 makes the list a virtual scope, so `:scope > p` should give the top-level `p`s. It gives `{}` here. Write `Child[XMLDocument[], XMLPattern["p"]]`.
- `XMLDocument[]` alone selects nothing, and `Child[XMLDocument[], p]` on a bare `p` gives `{}`, because the input is never a result.

As built:

- The document is the chain site `{0}`, which is no position in the tree; `Extract` gives the tree's head there, which the compiled `XMLDocument[]` matches. A bare `XMLElement` input stays at `{}`, so no position shifts.
- `XMLMatchQ` and the `Roles`/`Constructs` rules refuse `XMLDocument[]` with `::badpat`, since it is not a combinator. A combinator holding it is refused as any combinator is.
- As an entry in a list stage, `XMLDocument[]` is refused with `::listentry`, as any entry that is not an XML pattern is, rather than `::badpat`.
- `Adjacent[XMLDocument[], b]` gives `{}`, as the document has no siblings, rather than a refusal.
- A CSS string given as a later stage, such as `Child[a, "li:first-child"]`, starts with `XMLPattern[_]` there, not `XMLDocument[] | XMLPattern[_]`, since no later stage can be the document. A string that needs the document there, such as `":root"`, is `::badpat`.
- `:root` and `:scope` in a run with `+` or `~` (`:root + p`) are `::unsupported`, as after a combinator: the top element has no siblings. On `:root`, a position among siblings holds when it admits index 1 and otherwise never matches, so `:root:nth-child(2)` is `Child[XMLDocument[], {Except[_], XMLPattern[_]}]`.
- `Sibling` over 1,000 top-level elements of a list costs what it costs over 1,000 children of one element (2.5 ms both).
- On the Rosetta pages, `html:first-child`, `html:only-child`, `:only-of-type`, `:root`, `:root > body`, `:scope > *` and the other root rows give soupsieve's elements in soupsieve's order.
