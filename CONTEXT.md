# BeautifulTureen — Context Glossary

BeautifulSoup-style HTML element selection and text extraction for the Wolfram Language. Operates on the static `XMLObject` tree produced by `Import[…, {"HTML", "XMLObject"}]`.

This file is a glossary, not a spec. It defines the language we use to talk about the domain. Implementation lives in the code; decisions live in `docs/adr/`.

**Naming convention** (not a domain term, but load-bearing for reading the glossary): a symbol reading a (near-)canonical property off the tree is named `HTML‹Noun›` — "the ‹noun› of the tree." A symbol performing a directed, lossy, opinionated projection — where there is no canonical answer — is named `‹X›To‹Y›`, signaling "expect loss, do not expect a round-trip."

## Language

### Text extraction

**HTMLTextContent**: The lossless concatenation of every descendant text node, in document order, with no whitespace inserted or removed. The DOM `textContent` analogue. _Avoid_: HTMLText (former name through v1.0.2), text content, raw text

**HTMLInnerText**: Text as the structural meaning of the tags implies it should read: whitespace collapsed, block tags on their own line, `<br>` as a newline, preformatted tags verbatim, non-rendered tags dropped. The DOM `innerText` analogue, approximated via the [[Frozen UA stylesheet]] since a non-rendered element has no layout to consult. _Avoid_: rendered text, visible text, display text

**Block separator**: The single global string (default `"\n"`) inserted between Block boundaries when `HTMLInnerText` emits text — the `get_text(separator=…)` analogue. Uniform across all tags; never varies per tag. _Avoid_: line separator, join string

### Display role

**Display role**: The per-element classification that drives readable-text extraction: **Block**, **Inline**, **Preformatted**, **LineBreak**, or **Skip**. Assigned by the [[Frozen UA stylesheet]] table or a [[Role rule]]. _Avoid_: display type, tag category, render mode

**Box**: The axis of a display role distinguishing **Block** (own line) from **Inline** (flows with neighbors). Decided fresh at every element; not inherited. _Avoid_: layout axis

**Whitespace mode**: The axis of a display role distinguishing **Normal** (whitespace runs collapse to one space) from **Preserve** (verbatim). Inherited down the tree, unlike [[Box]]. _Avoid_: whitespace handling

**Frozen UA stylesheet**: Our fixed tag → rendering table, snapshotting the WHATWG HTML §15 default user-agent stylesheet. Never consults per-page CSS — not classes, `<style>`, external sheets, or inline `style=`. Drives both [[Display role]] and default [[Construct]] assignment; both are [[Tags-only]]. _Avoid_: default stylesheet, UA CSS

**Role rule**: A user-supplied override (`HTMLInnerText`'s `"Roles"` option) of the form `pattern -> role`, where the pattern is an `XMLPattern` and the role is one of five flat tokens (`"Block"`, `"Inline"`, `"Preformatted"`, `"LineBreak"`, `"Skip"`). Tried in order, first match wins; unmatched elements fall through to the [[Frozen UA stylesheet]]. _Avoid_: role override, classifier

**Tags-only**: The standing rule that display roles and constructs are decided from the tag name alone, never from `class` or inline `style=`. Predictable; tags-plus-CSS is not. _Avoid_: tag-based, CSS-aware

### Selection

**Attribute set**: The collection of an element's attributes, each a `key -> value` pair. A **structural** collection: it is present in the tree as itself, and `AttributeTest` quantifies over it. _Avoid_: attribute list, attributes, attribute map

**Token list**: The collection obtained by splitting a single attribute's value on a [[Delimiter]]. A **derived** collection: it exists only because we read a string that way, and `TokenTest` quantifies over it. Derived does not mean unreachable — a token list can be _obtained_ as a value, not only quantified over. _Avoid_: token set, split value, word list

**Class list**: The [[Token list]] of an element's `class` attribute — the [[Reading]] that `ClassTest` and `HTMLClassList` share. `class=""` and a whitespace-only `class` both give the empty class list; an element with no `class` attribute has no class list at all, which is a different fact, and both testing and extraction observe it. _Avoid_: class attribute, classes

**Token predicate**: A `String -> Bool` test applied to one token of a [[Token list]]. A bare string pattern in a token position is sugar for one. _Avoid_: class matcher, token test (that names the construct, not the predicate inside it)

**Quantifier**: What lifts a [[Token predicate]] or an attribute pattern to a whole collection — `AnyTrue` (∃), `AllTrue` (∀), or `NoneTrue` (¬∃), always in operator form. The level that says _how many_ members must satisfy the test, never _what_ the test is. _Avoid_: combinator, matcher, negation (a negation is one quantifier, not the family)

**Microsyntax**: A convention for splitting an attribute value into a [[Token list]] — space-separated or comma-separated. **Key-independent**: `class`, `rel`, `headers`, `ping` and `itemprop` all share the space-separated one. _Avoid_: format, syntax, separator convention

**Reading**: A [[Microsyntax]] together with a fixed attribute key. The class reading is the only one that ships, which is why `"rel" -> ClassTest[q]` does not type-check. A reading comes in two forms — **testing** it (`ClassTest`) and **extracting** it (`HTMLClassList`) — and because the key and microsyntax are fixed, neither takes options. _Avoid_: shorthand, alias, named microsyntax (a reading fixes the key too)

**Delimiter**: The string pattern a [[Token list]] is split on. Distinct from the [[Microsyntax]] that selects it, which also fixes whether tokens are trimmed. The space-separated one is named `HTMLWhitespace`, and it is a **run** of one or more HTML ASCII whitespace characters — mirroring WL's `Whitespace`, not `WhitespaceCharacter`, so that splitting on it never yields a phantom empty token. It is narrower than WL's Unicode default, which splits on no-break space and six other characters HTML does not. _Avoid_: separator (that is the [[Block separator]], a different thing entirely)

**Lift**: Wrapping a string pattern so it can match in a slot that matches **expressions** rather than strings — the tag, an attribute key, an attribute value. Spelled `Matching`, and necessary because a bare string pattern silently fails to match an expression. _Avoid_: wrapper, coercion, cast

### Notebook conversion

**HTMLToNotebook**: A directed, lossy projection of an HTML/XML tree into a `Notebook[…]` expression: each Block [[Display role]] element becomes a `Cell`, each Inline element becomes a box inside the surrounding `TextData`. Markdown, PDF, RTF, and display fall out downstream via `Export`. _Avoid_: notebook export, HTML rendering

**Construct**: What an element becomes in the notebook, chosen after its [[Display role]] places it as block-or-inline. A **block construct** is an open-ended cell-style string (`"Text"`, `"Section"`, `"Item"`, …); an **inline construct** is one of a closed set of box-transform tokens (`"Bold"`, `"Italic"`, `"Underline"`, `"StrikeThrough"`, `"Code"`, `"Hyperlink"`, `"Plain"`). _Avoid_: cell style, render form

**Leaf-collapsing construct**: A construct (`<blockquote>`, `<pre>`, `<table>`) that collapses its whole subtree into a single cell's content rather than recursing into separate child cells. Contrasts with the default recurse-and-flatten behavior of most Block constructs. _Avoid_: table construct (too narrow — also covers blockquote/pre)

**Construct rule**: A user override of the default [[Construct]] map — the Layer-2 analogue of a [[Role rule]] — of the form `pattern -> construct`, tried in order, first match wins. The RHS is a block cell-style string, an inline token, or a constructor function; the [[Display role]] still decides block-vs-inline and wins on conflict. _Avoid_: construct override
