# A variadic Child

`Child` takes one pattern: `Child[a, b]`, for an element with children that match `a` and `b`, is not planned.

## Why this is out of scope

`Child[p]` is the constraint that some element child matches `p`, the same as the list constraint `{___, p, ___}`. A second argument could mean two things, and each already has one way to write it:

- **Unordered**, some child matches `a` and some child matches `b`: two `Child` constraints, `XMLPattern[tag][Child[a], Child[b]]`.
- **Ordered**, a child matching `a` before one matching `b`: a list constraint, `XMLPattern[tag][{___, a, ___, b, ___}]`. The list also says whether the two children are adjacent, `{___, a, b, ___}`, which a variadic `Child` would have to leave out or add a convention for.

A second spelling of either is not wanted. It would also make readers ask which of the two meanings `Child[a, b]` has, and 3.0's `Child[a, b]`, with a different meaning again (the `b` children of an `a`), makes that worse. `Child[a, b]` gives `Child::args`, whose text shows both forms.

## Prior requests
