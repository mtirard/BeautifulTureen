# BeautifulTureen — Context Glossary

BeautifulSoup-style HTML element selection and text extraction for the Wolfram Language. Operates on the static `XMLObject` tree produced by `Import[…, {"HTML", "XMLObject"}]`.

This file is a glossary, not a spec. It defines the language we use to talk about the domain. Implementation lives in the code; decisions live in `docs/adr/`.

**Naming convention** (not a domain term, but load-bearing for reading the glossary): a symbol reading a (near-)canonical property off the tree is named `HTML‹Noun›` — "the ‹noun› of the tree." A symbol performing a directed, lossy, opinionated projection — where there is no canonical answer — is named `‹X›To‹Y›`, signaling "expect loss, do not expect a round-trip."

## Language

### Text extraction

**HTMLTextContent**:
The lossless concatenation of every descendant text node, in document order, with no whitespace inserted or removed. The DOM `textContent` analogue.
_Avoid_: HTMLText (former name through v1.0.2), text content, raw text

**HTMLInnerText**:
Text as the structural meaning of the tags implies it should read: whitespace collapsed, block tags on their own line, `<br>` as a newline, preformatted tags verbatim, non-rendered tags dropped. The DOM `innerText` analogue, approximated via the [[Frozen UA stylesheet]] since a non-rendered element has no layout to consult.
_Avoid_: rendered text, visible text, display text

**Block separator**:
The single global string (default `"\n"`) inserted between Block boundaries when `HTMLInnerText` emits text — the `get_text(separator=…)` analogue. Uniform across all tags; never varies per tag.
_Avoid_: line separator, join string

### Display role

**Display role**:
The per-element classification that drives readable-text extraction: **Block**, **Inline**, **Preformatted**, **LineBreak**, or **Skip**. Assigned by the [[Frozen UA stylesheet]] table or a [[Role rule]].
_Avoid_: display type, tag category, render mode

**Box**:
The axis of a display role distinguishing **Block** (own line) from **Inline** (flows with neighbors). Decided fresh at every element; not inherited.
_Avoid_: layout axis

**Whitespace mode**:
The axis of a display role distinguishing **Normal** (whitespace runs collapse to one space) from **Preserve** (verbatim). Inherited down the tree, unlike [[Box]].
_Avoid_: whitespace handling

**Frozen UA stylesheet**:
Our fixed tag → rendering table, snapshotting the WHATWG HTML §15 default user-agent stylesheet. Never consults per-page CSS — not classes, `<style>`, external sheets, or inline `style=`. Drives both [[Display role]] and default [[Construct]] assignment; both are [[Tags-only]].
_Avoid_: default stylesheet, UA CSS

**Role rule**:
A user-supplied override (`HTMLInnerText`'s `"Roles"` option) of the form `pattern -> role`, where the pattern is an `XMLPattern` and the role is one of five flat tokens (`"Block"`, `"Inline"`, `"Preformatted"`, `"LineBreak"`, `"Skip"`). Tried in order, first match wins; unmatched elements fall through to the [[Frozen UA stylesheet]].
_Avoid_: role override, classifier

**Tags-only**:
The standing rule that display roles and constructs are decided from the tag name alone, never from `class` or inline `style=`. Predictable; tags-plus-CSS is not.
_Avoid_: tag-based, CSS-aware

### Selection

**Class list**:
The whitespace-separated tokens of an element's `class` attribute — what a `CSSClass` constraint selects on. A missing `class` attribute, `class=""`, and whitespace-only class all count as the same empty class list.
_Avoid_: class attribute, classes

### Notebook conversion

**HTMLToNotebook**:
A directed, lossy projection of an HTML/XML tree into a `Notebook[…]` expression: each Block [[Display role]] element becomes a `Cell`, each Inline element becomes a box inside the surrounding `TextData`. Markdown, PDF, RTF, and display fall out downstream via `Export`.
_Avoid_: notebook export, HTML rendering

**Construct**:
What an element becomes in the notebook, chosen after its [[Display role]] places it as block-or-inline. A **block construct** is an open-ended cell-style string (`"Text"`, `"Section"`, `"Item"`, …); an **inline construct** is one of a closed set of box-transform tokens (`"Bold"`, `"Italic"`, `"Underline"`, `"StrikeThrough"`, `"Code"`, `"Hyperlink"`, `"Plain"`).
_Avoid_: cell style, render form

**Leaf-collapsing construct**:
A construct (`<blockquote>`, `<pre>`, `<table>`) that collapses its whole subtree into a single cell's content rather than recursing into separate child cells. Contrasts with the default recurse-and-flatten behavior of most Block constructs.
_Avoid_: table construct (too narrow — also covers blockquote/pre)

**Construct rule**:
A user override of the default [[Construct]] map — the Layer-2 analogue of a [[Role rule]] — of the form `pattern -> construct`, tried in order, first match wins. The RHS is a block cell-style string, an inline token, or a constructor function; the [[Display role]] still decides block-vs-inline and wins on conflict.
_Avoid_: construct override
