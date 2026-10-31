# Changelog

## Unreleased

### Changes

- **A test in the pattern may run past the n-th result, and fewer times.** `Reap[XMLCases[t, XMLPattern["li"]?((Sow[#]; True) &), 2]]` gives the first two `li` of `t` and may sow every `li`, where it sowed only the first two; a `Condition` in the pattern may run once per distinct value of the names it tests, in no promised order. The right-hand side, and a `Condition` on it, are still evaluated in result order and only until there are n results ([ADR 0024](docs/adr/0024-one-result-per-tuple-of-counted-names.md)).
- **A mistake in a list key's value is refused on every tree.** `XMLCases[t, XMLPattern["a", "classList" -> {___, PatternTest[x : PatternSequence[_, _], StringQ]}] :> x]` gives `XMLCases::badpat` and `$Failed` also when `t` has no `a` element, where it gave `{}`.
- **A counted name that can match text in an `XMLElement` pattern's contents is refused from the pattern alone**, with `::text`, also on a tree with no text there. `XMLCases[t, XMLPattern["tr"][{XMLElement["th", _, {s___}], ___}] :> {s}]` is refused even when every `th` holds only elements; give the name a pattern that matches only elements, as `s___XMLElement`.
- **A name inside an `XMLElement` pattern's attribute list has no position**, and is identified by its value. `XMLPosition[{XMLElement["p", {"a" -> "v", "b" -> "v"}, {}]}, XMLElement["p", {___, "b" -> h_}, _] :> h]` gives `{Missing["Literal"]}`, where it gave `{{1, Key["a"]}}`, the first attribute with that value. `XMLReplace` and `XMLDeleteCases` leave such a name alone.

### Performance

- Queries whose patterns are made of element patterns, names, `Descendant`, `Child`, `Alternatives`, `Condition`, `PatternTest` and `XMLDocument` run on a new engine that matches each part of the pattern against all elements at once. On a 15,000-element page, `XMLCases[page, a : XMLPattern["a", "href" -> h_] :> {a, h}]` takes about 19 ms where it took 455 ms, `XMLCases[page, "div a"]` 8 ms where it took 107 ms, and `XMLPosition[page, "div"[Descendant[p : "p"[Descendant[a : "a"]]]] :> {p, a}]` 15 ms where it took 107 ms.
- List constraints, `XMLElement` patterns' contents lists and token lists at a list key run on that engine too, each list matched over all its elements at once. On a page of 280 table rows, `XMLCases[page, "tr"[Descendant[XMLPattern["time", "datetime" -> d_]], {___, n : "td"}] :> {d, n}]` takes about 4 ms where it took 52 ms; on the 15,000-element page, `XMLCases[page, "ul"[{___, a : "li", b : "li", ___}] :> {a, b}]` takes about 11 ms where it took 195 ms, and `XMLCases[page, XMLPattern[_, "classList" -> {___, t : "reference", ___}] :> t]` 11 ms where it took 35 ms.
- Named and tested paths, and `Shortest` and `Longest` on `Descendant`, run on that engine too. On the 15,000-element page, `XMLCases[page, n : "div"[Shortest[Descendant[x : "a"]]] :> {n, x}]` takes about 22 ms where it took more than two minutes, and `XMLCases[page, "div"[p : Descendant[x : "a"]] :> {Length[p], x}]` 1.6 s where it took 3.2 s.
- A name bound more than once, and an `Except` that refers to a name bound elsewhere in the pattern, as the CSS `-of-type` selectors write, run on that engine too. On the 15,000-element page, `XMLCases[page, "*:nth-last-of-type(2)"]` takes about 0.7 s where it took 3.2 s, and `XMLCases[page, "ul"[{___, x : "li", ___, x : "li", ___}] :> x]` 0.4 s where it took 1.2 s.
- A document queried again keeps what queries computed for each of its elements, such as which elements pass a tag and attribute test, beside its index. A query with no match on a 15,000-element page, `XMLCases[page, "zzz"]`, takes about 6 ms where it took 12 ms.

## 4.0.0

A breaking release. Patterns are nested as the document is, and a query gives one result per distinct combination of the positions of the names its right-hand side uses ([ADR 0023](docs/adr/0023-patterns-are-nested-as-the-document-is.md), [ADR 0024](docs/adr/0024-one-result-per-tuple-of-counted-names.md)). The combinators are gone.

### Breaking changes

- **`Adjacent` and `Sibling` are removed, and `Child` is a constraint.** A query that still uses `Adjacent` or `Sibling` stays unevaluated inside the function it is given to, which gives `::badpat`, whose text shows the tree form; `Child` as a query gives `Child::place`. Rewrite each as a nested pattern that names what it gives:

  | 3.0.0 | 4.0.0 |
  |---|---|
  | `Child[XMLPattern["ul"], XMLPattern["li"]]` | `XMLPattern["ul"][Child[x : XMLPattern["li"]]] :> x` |
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

- Constraints on what is below an element go in a second bracket: `XMLPattern[tag][c…]` or `XMLPattern[tag, attrs][c…]`. Each `c` is a list pattern over the element children, such as `{XMLPattern["li"], ___}`, `Child[p]` or `Descendant[p]`, and all of them must hold. `XMLPattern[tag, attrs][]` is `XMLPattern[tag, attrs]`.
- `Child[p]`, a constraint that some element child matches `p`, the same as the list `{___, p, ___}`: `XMLPattern["ul"][Child[x : XMLPattern["li"]]] :> x`. Under `XMLDocument[c…]` the children are the top elements. A name or a test goes inside, `Child[n : p]` or `Child[p?f]`; on `Child` itself it gives `Child::name` or `Child::test`. `Child` takes one pattern; several patterns are several constraints or a list, and `Child[a, b]` gives `Child::args`.
- A one-element CSS selector string takes constraints as `XMLPattern` does: `"ul.c"[Child[x : "li"]] :> x` gives the `li` children of each `ul` of class `c`.
- `XMLPosition` and `XMLExtract`: the positions of the results of a query, and the parts of a tree at positions ([ADR 0025](docs/adr/0025-positions-count-element-children-from-the-document.md)).
- `XMLReplace`: rewrite what the names of a pattern match.
- `XMLFreeQ`, with a level spec in DOM depth (issue #32).
- `FromCSSSelector[n : "selector"]` names the element a selector selects ([ADR 0026](docs/adr/0026-fromcssselector-names-the-subject.md)). Translations write the bracket form, and `>` as `Child`: `FromCSSSelector[n : "ul > li"]` gives `XMLPattern["ul"][Child[n : XMLPattern["li"]]]`.
- `HTMLToTree`'s `"Focus"` and `"Hide"` take rules, and act on the positions of the names the right-hand side uses.

### Performance

Queries run on a new engine, and many are slower than in 3.0.0: commonly about twice as long, up to about six times for a position counted among the siblings that match a selector, and about eight times for a descendant selector 50 elements deep. A counted position before `~`, such as `.x:nth-of-type(2) ~ b`, takes 0.26 s over 5,000 siblings, against over a minute in 3.0.0 (issue #40).
