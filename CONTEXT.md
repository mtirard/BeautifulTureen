# BeautifulTureen — Context Glossary

BeautifulSoup-style HTML element selection and text extraction for the Wolfram Language. Operates on the static `XMLObject` tree produced by `Import[…, {"HTML", "XMLObject"}]`.

This file is a glossary, not a spec. It defines the language we use to talk about the domain. Implementation lives in the code; decisions live in `docs/adr/`.

**Audience**: people working on the repository. The terms here are for code, tests, ADRs and design discussion; they are not the vocabulary of what users see. User-facing text — documentation pages, `::usage` strings and messages — is written in plain language for its reader, and uses a term from here only when the reader needs the concept, defining it on first use. An _Avoid_ entry governs internal discussion and does not rule out the plain word in user-facing text: the pages say "attributes", not "attribute map". Internal names (private functions, helpers, comments) may use the glossary freely.

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

**XML pattern**: The paclet's third kind of pattern, beside WL's patterns and string patterns: an inert `XMLPattern[tag]` or `XMLPattern[tag, attrs]` that only the XML* functions (`XMLCases`, `XMLFirstCase`, `XMLDeleteCases`, `XMLMatchQ`) and the [[Role rule]] and [[Construct rule]] options interpret. `MatchQ` and `Cases` treat it as a literal expression, as `MatchQ` treats a string pattern. Everything written inside one is an ordinary WL pattern: `attrs` is what `KeyValuePattern` takes, keys are literal, and values are matched as written, with one exception at a [[List key]]. _Avoid_: element pattern, selector

**Combinator**: A pattern relating the elements its [[Stage]]s match by their place in the tree: `Child`, `Descendant`, `Adjacent` or `Sibling`. A combinator may be a stage of another, and the whole reads left to right as a chain, as a CSS selector does; it selects the elements of its last stage. Its names scope as they would in the plain list pattern over its stages. _Avoid_: selector, relation, structural pattern

**Stage**: One of the patterns a [[Combinator]] relates: an element pattern (an [[XML pattern]] or alternatives of them, conditioned or not), or a combinator. _Avoid_: step, part, argument

**Document order**: The order the tags open in the source: an element before the elements nested in it, an earlier sibling (and its subtree) before a later one — the DOM's tree order, a pre-order walk. `XMLCases` returns its matches in document order and `XMLFirstCase` the first of them, as `querySelectorAll` and `querySelector` do; "first in document order" among nested candidates is the outermost. Not WL's `Cases` order, which puts an element after the elements nested in it. _Avoid_: source order, Cases order

**Attribute map**: The map from an element's attribute names to their values: each name at most once, every value an opaque string. Attribute order is kept but carries no meaning. A **structural** collection: it is present in the tree as itself, and an [[XML pattern]] matches against it directly; a question about the whole map (such as "has some `data-*` attribute") is asked by binding it. An `Association` in spirit, with two differences: the tree holds it as a list of `key -> value` rules, and key order does not count towards equality. Any structure inside a value is a [[Microsyntax]], layered above the markup. _Avoid_: attribute set (drops the one-value-per-name guarantee), attribute list, attributes

**Token list**: The collection obtained by splitting a single attribute's value on a [[Delimiter]]. A **derived** collection: it exists only because we read a string that way, and an [[XML pattern]] reaches it through a [[List key]], never through the raw attribute. An ordinary WL list of strings, matched by ordinary list patterns and list predicates; its order is positional to a pattern, and order-free questions use `MemberQ`, `ContainsAll` and the like. _Avoid_: token set, split value, word list

**List key**: The name under which an [[XML pattern]] reaches a [[Token list]]: `classList` for `class`, by default the raw key with `List` appended, after the DOM's `classList` and `relList`. Exists only for keys with a [[Reading]], and reads as the empty list when the raw attribute is absent. The raw key keeps meaning the raw string, so `"class" -> "menu"` is an exact match and `"classList" -> "menu"` asks for a token; a literal string, or alternatives of them, at a list key means "contains this token", since it could never match a list as written. _Avoid_: synthetic key, virtual attribute

**Class list**: The [[Token list]] of an element's `class` attribute, reached as `classList` in a pattern and returned by `HTMLClassList`. A missing `class`, `class=""` and a whitespace-only `class` all give the empty class list, as in a browser; whether the attribute itself is present is a separate question, asked of `class`. Keeps duplicate tokens (`class="lead lead promo"` gives three) because the document does: the DOM stores the attribute value with its duplicates, and only a browser's `classList` view deduplicates, on read. The class list therefore diverges from `classList`, not from the document. _Avoid_: class attribute, classes

**Microsyntax**: A convention for splitting an attribute value into a [[Token list]] — space-separated or comma-separated. **Key-independent**: `class`, `rel`, `headers`, `ping` and `itemprop` all share the space-separated one. _Avoid_: format, syntax, separator convention

**Reading**: A [[Microsyntax]] together with a fixed attribute key and a [[List key]] — what makes a token list available to an [[XML pattern]] at all. Adding a reading adds a key and, with the default list key, never changes what an existing key means; an explicit list key naming a real attribute takes that name over, by the caller's choice. The class reading is the only one that ships by default (in `$AttributeReadings`); `rel`, `headers`, `ping` and `itemprop` share its microsyntax in HTML but carry no reading unless a caller adds one, globally or per query through the consumers' `"AttributeReadings"` option. Matching a reading is written with its list key (`"classList" -> …`); extracting it has its own function (`HTMLClassList` for the class reading). _Avoid_: shorthand, alias, named microsyntax (a reading fixes the key too)

**Delimiter**: The string pattern a [[Token list]] is split on. Distinct from the [[Microsyntax]] that selects it, which also fixes whether tokens are trimmed. The space-separated one is named `HTMLWhitespace`, and it is a **run** of one or more HTML ASCII whitespace characters — mirroring WL's `Whitespace`, not `WhitespaceCharacter`, so that splitting on it never yields a phantom empty token. It is narrower than WL's Unicode default, which splits on no-break space and six other characters HTML does not. _Avoid_: separator (that is the [[Block separator]], a different thing entirely)

### Notebook conversion

**HTMLToNotebook**: A directed, lossy projection of an HTML/XML tree into a `Notebook[…]` expression: each Block [[Display role]] element becomes a `Cell`, each Inline element becomes a box inside the surrounding `TextData`. Markdown, PDF, RTF, and display fall out downstream via `Export`. _Avoid_: notebook export, HTML rendering

**Construct**: What an element becomes in the notebook, chosen after its [[Display role]] places it as block-or-inline. A **block construct** is an open-ended cell-style string (`"Text"`, `"Section"`, `"Item"`, …); an **inline construct** is one of a closed set of box-transform tokens (`"Bold"`, `"Italic"`, `"Underline"`, `"StrikeThrough"`, `"Code"`, `"Hyperlink"`, `"Plain"`). _Avoid_: cell style, render form

**Leaf-collapsing construct**: A construct (`<blockquote>`, `<pre>`, `<table>`) that collapses its whole subtree into a single cell's content rather than recursing into separate child cells. Contrasts with the default recurse-and-flatten behavior of most Block constructs. _Avoid_: table construct (too narrow — also covers blockquote/pre)

**Construct rule**: A user override of the default [[Construct]] map — the Layer-2 analogue of a [[Role rule]] — of the form `pattern -> construct`, tried in order, first match wins. The RHS is a block cell-style string, an inline token, or a constructor function; the [[Display role]] still decides block-vs-inline and wins on conflict. _Avoid_: construct override
