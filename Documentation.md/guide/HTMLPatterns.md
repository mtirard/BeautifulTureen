# HTMLPatterns

HTMLPatterns finds elements in HTML and XML imported as ``XMLObject`` expressions, and extracts their text. An ``XMLPattern`` matches an element by its tag, attributes and classes, and by the elements below it, so a pattern is nested as the document is. ``XMLCases`` and related functions search, test and edit a tree with these patterns, and accept CSS selector strings wherever a pattern goes. ``HTMLInnerText`` and ``HTMLToNotebook`` turn the results into text or a notebook, and ``HTMLToTree`` draws the structure of a tree.

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern) — pattern for an element: its tag, attributes and classes, and the elements below it

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases) — find the elements of a tree that match a pattern, or the results of a rule

### Building Patterns

* [Child](paclet:MaximilienTirard/HTMLPatterns/ref/Child), [Descendant](paclet:MaximilienTirard/HTMLPatterns/ref/Descendant) — constraints met by an element that has a matching element child, or a match anywhere below it

* [FromCSSSelector](paclet:MaximilienTirard/HTMLPatterns/ref/FromCSSSelector) — translate a CSS selector to an ``XMLPattern``

* [XMLDocument](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDocument)

### Classes and Other Token Attributes

* [HTMLClassList](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLClassList) — the classes of an element, as a list of strings

* [$AttributeReadings](paclet:MaximilienTirard/HTMLPatterns/ref/$AttributeReadings) — attributes whose values ``XMLPattern`` can match as lists of tokens, such as ``class``

* [HTMLWhitespace](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLWhitespace)

### Finding Elements

* [XMLFirstCase](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFirstCase) — find the first element that matches a pattern

* [XMLMatchQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLMatchQ) — test whether an element matches a pattern

* [XMLFreeQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFreeQ)

### Positions and Editing

* [XMLDeleteCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDeleteCases) — remove matching elements, or the parts bound to the names in a rule

* [XMLReplace](paclet:MaximilienTirard/HTMLPatterns/ref/XMLReplace) — replace the parts of a tree bound to the names in a pattern

* [XMLPosition](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPosition), [XMLExtract](paclet:MaximilienTirard/HTMLPatterns/ref/XMLExtract) — give the positions of matching elements or of the results of a rule, and the parts of a tree at positions

### Extracting Text

* [HTMLTextContent](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLTextContent) — the text of a tree, with its whitespace as written

* [HTMLInnerText](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLInnerText) — readable text, with whitespace collapsed, blocks on separate lines and scripts dropped

### Converting and Viewing Trees

* [HTMLToNotebook](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLToNotebook) — convert a tree into a notebook, for display or export to Markdown, PDF, RTF, etc.

* [HTMLToTree](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLToTree) — draw the elements and text of a tree as a ``Tree``

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [XML Import & Export](paclet:guide/XMLImportAndExport)

* [Tree Visualization](paclet:guide/TreeVisualization)

## Related Links

* [HTMLPatterns on GitHub](https://github.com/mtirard/HTMLPatterns)
