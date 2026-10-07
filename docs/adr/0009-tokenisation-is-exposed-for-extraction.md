---
status: accepted (amended by ADR-0012)
---

# Tokenisation is exposed for extraction: `HTMLClassList` and `HTMLWhitespace`

ADR 0006 named the [[token list]] and the [[class list]], but they existed only _inside_ the matcher — a user who matched an element and then wanted its classes had to re-derive them, and the obvious spelling is silently wrong. Two public symbols close the gap: **`HTMLClassList[element]`**, the extraction form of the `class` [[reading]], and **`HTMLWhitespace`**, the delimiter the space-separated [[microsyntax]] splits on.

> **Amended by [ADR 0012](./0012-readings-and-materialising-emission.md).** An element with no `class` attribute now gives `{}`, not `Missing["KeyAbsent", "class"]`, so that `HTMLClassList` agrees with the synthesised `"classList"` attribute a query matches against, and with a browser's `classList`. The "Absence" section below is retained as history. `ClassTest`, named below as the testing form of the reading, is dropped (ADR 0011); the testing form is now `"classList" -> …`. Everything else stands.

## Context

`CONTEXT.md` names four collection-shaped concepts in its `Selection` cluster — attribute set, token list, class list, delimiter — and the API could hand the user none of them. Every out-of-scope ruling in the effort that produced ADR 0006–0008 routes the user to the **rule body** (token-level capture, two-level attributes, user-supplied tokenisers, key inference all end "use `StringCases` in the rule body"), so the rule body is load-bearing four times over, and it had no access to the library's own tokenisation.

The natural thing to write there is `StringSplit[cls]`, and it is **wrong**. `StringSplit`'s default is Unicode whitespace; HTML's is five ASCII characters. Measured, `StringSplit` splits on all of these where HTML splits on none:

| character                  |     | character                |     |
| -------------------------- | --- | ------------------------ | --- |
| U+00A0 no-break space      | ✗   | U+0085 next line         | ✗   |
| U+2028 line separator      | ✗   | U+2003 em space          | ✗   |
| U+2029 paragraph separator | ✗   | U+3000 ideographic space | ✗   |
| U+000B vertical tab        | ✗   |                          |     |

This is not a theoretical divergence. `&nbsp;` is the most common entity in HTML and is injected into attributes routinely by CMSes, WYSIWYG editors and template concatenation, and the importer decodes it in place: `ImportString["<p class=\"btn&nbsp;btn-primary\">", …]` yields one class name, `btn\:00a0btn-primary`, with character code 160 measured sitting between the two words.

**The payoff is agreeing with the browser, not being pedantic.** When an NBSP lands in a `class`, the browser also reads one token, `.btn` does not apply, and the page is visibly broken. A scraper splitting on Unicode whitespace would report that element as carrying class `btn` — disagreeing with the browser about the same document, in exactly the case where scraping is hardest. Well-formed markup never exercises the difference.

## Decision

### `HTMLWhitespace` is the delimiter, and it is a **run**

`HTMLWhitespace` is the string pattern `(" " | "\t" | "\n" | "\f" | "\r") ..` — one _or more_ HTML ASCII whitespace characters, not one.

This follows WL's own precedent exactly, and the reason is a measured hazard rather than symmetry. `Whitespace` means a run and `WhitespaceCharacter` means one character, so that `StringSplit["a  b", Whitespace]` is `{"a", "b"}` while `StringSplit["a  b", WhitespaceCharacter]` is `{"a", "", "b"}`. Class attributes contain double spaces constantly, so a character-class constant used the obvious way would yield a **phantom empty token** — a silent wrong answer, which is the failure mode this whole line of work exists to remove. Defining the constant as the run makes the obvious spelling correct, and a stray `..` is idempotent, so `StringSplit[v, HTMLWhitespace ..]` stays correct too.

The name carries **no `$` prefix**, departing from the usual convention for a global constant. It lives at a `StringSplit` call site where `Whitespace`, `DigitCharacter` and `LetterCharacter` are its immediate neighbours, and matching those matters more there than matching a convention for settable globals — which this is not. `HTMLWhitespaceCharacter` is the obvious sibling if a composable single-character form is ever wanted; it does not ship now.

### `HTMLClassList[element]` takes an element, and only an element

`HTMLClassList` is the extraction form of the same **reading** `ClassTest` tests: it fixes the key `class` and the space-separated microsyntax together, which is why — like `ClassTest` — it takes no options.

It accepts a single `XMLElement`. It does **not** accept a list, a document, or a bare string, and this is a deliberate break from `HTMLTextContent`'s input surface. The paclet's list convention is "a list is a forest, give **one** answer" — `HTMLTextContent[{p1, p2}]` measurably returns `"onetwo"`, concatenated — and concatenating class lists across a forest is meaningless while mapping instead would silently contradict every neighbouring function. `HTMLClassList /@ XMLCases[tree, pat]` is explicit and costs one character. A bare string is refused for the same kind of reason: in this paclet a bare string already means a **text node** (`validTextInputQ`, `Kernel/HTMLPatterns.wl:145`), so making it mean an attribute value here would collide.

### Absence is `Missing["KeyAbsent", "class"]`

`class=""` and a whitespace-only `class` both give `{}`. An element with **no** `class` attribute gives `Missing["KeyAbsent", "class"]`.

`CONTEXT.md` already commits to these being different facts, and ADR 0006 made the matcher presence-requiring on exactly that ground — so returning `{}` for a missing attribute would make the extraction surface disagree with the matching surface about the same element. `Missing["KeyAbsent", key]` is also precisely what `Lookup` returns for an absent key on an attribute rule list (measured), so the shape is borrowed rather than invented.

### The value level is `StringSplit`, not a function

There is no `HTMLTokenList`. Value-level splitting is spelled `StringSplit[v, HTMLWhitespace]`, using the function every WL user already knows.

This is what earns `HTMLWhitespace` its place: exposing the delimiter is not a convenience on top of a splitter, it is **what makes the splitter unnecessary**. The division is `HTMLClassList[el]` at the element level, `StringSplit[v, HTMLWhitespace]` at the value level, and nothing in between.

## Considered options

- **`HTMLTokenList[v, Method -> "SpaceSeparated"]`** — the extraction counterpart of `TokenTest`, mirroring its options. Rejected as too thin a wrapper to earn a symbol, and the option spelling is far too long for what is one `StringSplit` call. `TokenTest`'s options exist because a _pattern_ cannot carry a function; an extraction call has no such constraint.
- **A comma delimiter constant** — `HTMLCommaDelimiter = HTMLWhitespace... ~~ "," ~~ HTMLWhitespace...`, folding the comma microsyntax's trim into the delimiter. Very nearly works, and was rejected **because** of how nearly. Measured against the spec it agrees on every interior case, including the awkward ones (`"a ,b,,d d"` → four tokens; `"a, ,b"` → `{"a", "", "b"}`), and fails only at the **outer edges**: `" image/png, image/jpeg "` → `{" image/png", "image/jpeg "}`. A delimiter matches _between_ tokens so it structurally cannot reach the ends of the string, and it cannot be widened to do so, because a comma token may legitimately contain spaces (`"d d"`) and a delimiter matching bare whitespace would shred them. The spelling that works is `StringSplit[StringTrim[v, HTMLWhitespace], HTMLCommaDelimiter]` — two constants and a remembered wrapper, at which point the "why not just use `StringSplit`" argument that rejected `HTMLTokenList` no longer holds. This is the hazard species ADR 0006 names in its closing section: correct, cheap-looking, failing past the point anyone checked.
- **Abandoning HTML's ASCII whitespace** for `StringSplit`'s Unicode default, so the naive rule body is simply right — the cheapest fix available, and what the current `classList` (`Kernel/HTMLPatterns.wl:159`) already does. Rejected: it buys convenience by agreeing with the browser less often, per the Context above, and it would only ever help the space-separated microsyntax. ADR 0006's delimiter table stands unchanged.

## Consequences

**The comma microsyntax has no extraction surface**, and the naive spelling is wrong there in a second way that no constant can fix: it trims, so `StringSplit["a , b", ","]` gives `{"a ", " b"}`. ADR 0008 already routes an `"accept" -> TokenTest[…]` gotcha to a **Possible Issues** section; this is the same gotcha's other face and belongs in the same entry. If comma extraction ever earns real demand, the honest answer is a function, not a constant that almost works.

**Correctness costs exactly one symbol.** `HTMLClassList` is justified on its own — it is useful with no reference to the pattern language at all — and ADR 0006's delimiter table already existed. `HTMLWhitespace` is the entire price of refusing to degrade the matcher.

`FromCSSSelector` (ADR 0017), noted as future work by ADR 0006, is unaffected: it emits patterns rather than extracting, and `[foo~=x]` goes through the same reading and delimiter.
