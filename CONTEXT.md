# HTMLPatterns — Context Glossary

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

**Role rule**: A user-supplied override (`HTMLInnerText`'s `"Roles"` option) of the form `pattern -> role`, where the pattern is an [[Element pattern]] and the role is one of five flat tokens (`"Block"`, `"Inline"`, `"Preformatted"`, `"LineBreak"`, `"Skip"`). Tried in order, first match wins; unmatched elements fall through to the [[Frozen UA stylesheet]]. _Avoid_: role override, classifier

**Tags-only**: The standing rule that display roles and constructs are decided from the tag name alone, never from `class` or inline `style=`. Predictable; tags-plus-CSS is not. _Avoid_: tag-based, CSS-aware

### Selection

**XML pattern**: The paclet's third kind of pattern, beside WL's patterns and string patterns: what the XML* functions (`XMLCases`, `XMLFirstCase`, `XMLDeleteCases`, `XMLMatchQ`) and the [[Role rule]] and [[Construct rule]] options take as a pattern. It is built as WL's patterns are built from `Blank`: `XMLPattern[tag]` and `XMLPattern[tag, attrs]`, the [[Combinator]]s, and `Alternatives` and `Condition` over these, and `PatternTest` over an element pattern, so alternatives of XML patterns are themselves an XML pattern. A [[CSS selector]] string, where an XML pattern is accepted, is one too: a combinator or an element pattern, depending on what it says. `MatchQ` and `Cases` treat it as a literal expression, as `MatchQ` treats a string pattern. It reads as an ordinary WL pattern at every level: `XMLPattern`'s `tag` and `attrs` are WL patterns (`attrs` is what `KeyValuePattern` takes, keys are literal and values are matched as written); a combinator is the list pattern over its [[Stage]]s; alternatives are WL's, and a name bound only in an alternative that did not match is `Sequence[]`. It departs from WL in three places: a literal string at a [[List key]] means "contains this token"; a combinator selects each element once, binding its names from one of the matches; and of alternatives that overlap, the first that accepts an element binds the names. _Avoid_: selector

**Element pattern**: An [[XML pattern]] that describes an element by what it is (its tag, attributes and contents), not by where it is in the tree, so it can be tested on an element alone, as `XMLMatchQ` and the [[Role rule]] and [[Construct rule]] options do. It is an `XMLPattern`, alternatives of element patterns, or either conditioned, tested (`pat?f`) or named. A test that looks inside the element (`XMLPattern["div"] /; …`, `XMLPattern["div"]?f`) keeps it an element pattern; a [[Combinator]], or alternatives holding one, is not. _Avoid_: selector, XMLElement pattern

**Combinator**: An [[XML pattern]] relating the elements its [[Stage]]s match by their place in the tree: `Child`, `Descendant`, `Adjacent` or `Sibling`, conditioned or not. A combinator may be a stage of another, and the whole reads left to right as a chain, as a CSS selector does; it selects the elements of its last stage. Its names scope as they would in the plain list pattern over its stages. _Avoid_: selector, relation, structural pattern

**Stage**: One of the [[XML pattern]]s a [[Combinator]] relates, or a [[List stage]] after a `Child` or `Descendant` link. _Avoid_: step, part, argument

**Link**: The [[Combinator]] head between two neighbouring [[Stage]]s of a chain: `Descendant[a, Child[b, c]]` is the stages *a*, *b*, *c* joined by the links `Descendant` and `Child`. A chain of *n* stages has *n* − 1 links; a plain query has one stage and none. _Avoid_: axis (XPath's word), relation, step

**List stage**: A [[Stage]] written as a WL list pattern over one parent's element children, after a `Child` or `Descendant` [[Link]]: `Child[p, {c, ___}]` selects a `c` that is the first element child of a `p`. Its **selected entry** is the last top-level entry that is an [[XML pattern]], and the chain continues from the element in that entry's place; every other entry is a **context entry**, which constrains the siblings around it. A [[Combinator]] entry stands in the list by its first stage: selected, the chain runs on to its last stage; as context, the rest of its chain is a test below that sibling. `Adjacent` and `Sibling` are shorthands for list stages. _Avoid_: position pattern, sibling pattern

**CSS selector**: A string in the static Selectors Level 4 dialect (literal case, no namespaces, no soupsieve extensions) that `FromCSSSelector` translates into an [[XML pattern]], and that the XML* functions and the [[Role rule]] and [[Construct rule]] options accept wherever an XML pattern goes, meaning its translation. The translation is literal, against the imported tree, so it matches what the importer put there. It is a way to write an XML pattern, not a fourth kind of pattern: a CSS selector says nothing its translation does not. _Avoid_: selector (alone), CSS pattern, CSS query

**Selector list**: A [[CSS selector]] of several selectors separated by commas, selecting what any of them selects. It translates to [[XML pattern]] alternatives: in one [[Stage]] when the selectors differ in one compound, otherwise as alternatives of whole [[Combinator]]s. _Avoid_: selector group, union (the general feature, not the CSS form)

**Top element**: An element with no element parent inside the tree a query is given: the root element of an `XMLObject` document, a bare `XMLElement` input itself, or each top-level element of a list. A query sees nothing outside its input, so there is no root above a top element. The input itself is never a result, as `Cases` never returns level 0, so a bare `XMLElement` input's top element is never one; every other top element can be. _Avoid_: root (alone; it can mean the input or a document's root element), document element

**Document**: The parent of the [[Top element]]s, which every input has: the `XMLObject` for a document input, the list for a list input, and a virtual parent above a bare `XMLElement` input. It is featureless: it is matched only by `XMLDocument[]`, only as a first [[Stage]], and is never a result. A [[List stage]] under it lists the top elements, so a list input's top elements are siblings and a document's root element is an only child. _Avoid_: document node, scope, scoping root (the input, which differs from the document for a bare element)

**Document order**: The order the tags open in the source: an element before the elements nested in it, an earlier sibling (and its subtree) before a later one — the DOM's tree order, a pre-order walk. `XMLCases` returns its matches in document order and `XMLFirstCase` the first of them, as `querySelectorAll` and `querySelector` do; "first in document order" among nested candidates is the outermost. Not WL's `Cases` order, which puts an element after the elements nested in it. _Avoid_: source order, Cases order

**Query**: What an XML* function is given to select by: an [[XML pattern]], or a rule `pattern -> rhs` or `pattern :> rhs` over one, whose right-hand side is evaluated for each match as in `Cases`. A [[CSS selector]] string is a query wherever an XML pattern is. _Avoid_: selector, search

**Compiled query**: A [[Query]] as the compiler leaves it, under the [[Reading]]s in force: its [[Combinator]]s flattened to one chain of [[Stage]]s and [[Link]]s (or alternatives of chains), each element pattern made an ordinary WL pattern, together with how each part runs, including the method for each [[Recognised shape]] it contains. Computed from the query alone, never from the tree. _Avoid_: normal form, plan, matcher

**Recognised shape**: A shape of [[XML pattern]] that the compiler recognises and runs by a dedicated method, with the same results as WL's matcher would give on the pattern as written. A recognised shape is a performance guarantee, listed in ADR 0020. A pattern of the same meaning in another shape is still correct, run by the general matcher. _Avoid_: fast path, idiom, special case

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
