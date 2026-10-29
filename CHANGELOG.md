# Changelog

## 4.0.0

A breaking release. Patterns are nested as the document is, and a query gives one result per distinct combination of the positions of the names its right-hand side uses ([ADR 0023](docs/adr/0023-patterns-are-nested-as-the-document-is.md), [ADR 0024](docs/adr/0024-one-result-per-tuple-of-counted-names.md)). The combinators are gone.

### Breaking changes

- **`Child`, `Adjacent` and `Sibling` are removed.** A query that still uses one stays unevaluated inside the function it is given to, which gives `::badpat`, whose text shows the tree form. Rewrite each as a nested pattern that names what it gives:

  | 3.0.0 | 4.0.0 |
  |---|---|
  | `Child[XMLPattern["ul"], XMLPattern["li"]]` | `XMLPattern["ul"][{___, x : XMLPattern["li"], ___}] :> x` |
  | `Descendant[XMLPattern["nav"], XMLPattern["a"]]` | `XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> x` |
  | `Sibling[XMLPattern["h2"], XMLPattern["p"]]` | `XMLPattern[_][{___, XMLPattern["h2"], ___, x : XMLPattern["p"], ___}] :> x` |
  | `Adjacent[XMLPattern["h2"], XMLPattern["p"]]` | `XMLPattern[_][{___, XMLPattern["h2"], x : XMLPattern["p"], ___}] :> x` |
  | `Child[XMLPattern["ul"], {XMLPattern["li"], ___}]` (a list stage) | `XMLPattern["ul"][{x : XMLPattern["li"], ___}] :> x` |

  CSS selector strings keep working as before: `"nav a"` still gives the links inside a `nav`.
- **`Descendant` is a constraint**, an argument of the constraint bracket of `XMLPattern[tag, attrs][c…]` or of `XMLDocument[c…]`: `Descendant[p]` or `Descendant[p, levelspec]`, with the level spec in DOM depth. The two-pattern form `Descendant[a, b]` gives `Descendant::level`, and `Descendant` as a whole query gives `Descendant::place`.
- **List stages are removed.** A list pattern over an element's children is now a constraint: `XMLPattern[tag, attrs][{…}]`.
- **`XMLDocument[]` is no longer a first stage.** `XMLDocument[c…]` is a pattern root, which takes constraints on the top elements and can be named (its position is `{}`) or be a branch of alternatives at the top.
- **A query whose right-hand side uses no names gives at most one result.** More generally, `XMLCases[t, p :> rhs]` gives one result per distinct combination of the positions of the names `rhs` uses, not one per match: `XMLCases[t, XMLPattern["a"] -> 1]` gives `{1}`. A bare pattern still gives each match, as `Cases` does.
- **`XMLDeleteCases` accepts rules**: `XMLDeleteCases[t, p :> x]` deletes what the name `x` matches, which can be an element, a run of children, an attribute, a token or the contents of an element.
- **`FromCSSSelector` of a selector that looks above or beside its element**, such as `"nav a"`, gives `FromCSSSelector::name` and `$Failed`: name the element it selects, as in `FromCSSSelector[n : "nav a"]`, which gives `XMLPattern["nav"][Descendant[n : XMLPattern["a"]]]`.
- **`XMLMatchQ` accepts tree patterns, `XMLDocument` patterns and list patterns, and refuses rules.**
- **`XMLElement` patterns are accepted everywhere**, with their literal WL meaning (issue #31 is closed as not planned).
- **`"Roles"` and `"Constructs"` accept query keys**: a rule key, or a CSS selector that looks above the element such as `"nav a"`, is matched once against the whole input, and the elements it selects get the value.
- **Messages removed:** `::stages`, `::testcombinator`, `::condcombinator`, `XMLMatchQ::combinator` and `::liststage`. `XMLPattern::constraint` replaces `XMLPattern::nargs`.

### New

- Constraints on what is below an element go in a second bracket: `XMLPattern[tag][c…]` or `XMLPattern[tag, attrs][c…]`. Each `c` is a list pattern over the element children, such as `{___, XMLPattern["li"], ___}`, or `Descendant[p]`, and all of them must hold. `XMLPattern[tag, attrs][]` is `XMLPattern[tag, attrs]`.
- `XMLPosition` and `XMLExtract`: the positions of the results of a query, and the parts of a tree at positions ([ADR 0025](docs/adr/0025-positions-count-element-children-from-the-document.md)).
- `XMLReplace`: rewrite what the names of a pattern match.
- `XMLFreeQ`, with a level spec in DOM depth (issue #32).
- `FromCSSSelector[n : "selector"]` names the element a selector selects ([ADR 0026](docs/adr/0026-fromcssselector-names-the-subject.md)).
- `HTMLToTree`'s `"Focus"` and `"Hide"` take rules, and act on the positions of the names the right-hand side uses.

### Performance

Queries run on a new engine, and many are slower than in 3.0.0: commonly about twice as long, up to about six times for a position counted among the siblings that match a selector, and about eight times for a descendant selector 50 elements deep. A counted position before `~`, such as `.x:nth-of-type(2) ~ b`, takes 0.26 s over 5,000 siblings, against over a minute in 3.0.0 (issue #40).
