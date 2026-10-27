# HTMLPatterns

Pattern-based HTML element selection and text extraction for the Wolfram Language.

> [!WARNING]
> **Work in progress.** HTMLPatterns is not yet released and is not on the Wolfram Paclet Repository. Its design is still changing, including how combinators such as `Child` and `Descendant` work, so expect breaking changes between commits. Issues and feedback are welcome.

HTMLPatterns works on the `XMLObject` tree that `Import[…, {"HTML", "XMLObject"}]` gives. It adds:

- **XML patterns**: `XMLPattern[tag, attrs]`, with the combinators `Child`, `Descendant`, `Adjacent` and `Sibling`, and CSS selector strings through `FromCSSSelector`
- **Selection**: `XMLCases`, `XMLFirstCase`, `XMLDeleteCases` and `XMLMatchQ`, with results in document order
- **Text**: `HTMLTextContent` and `HTMLInnerText`, the analogues of the DOM's `textContent` and `innerText`
- **Conversion**: `HTMLToNotebook` (and from there Markdown, PDF, …) and `HTMLToTree`

```wl
Needs["MaximilienTirard`HTMLPatterns`"]

html = ImportString[
  "<ul class=\"menu\"><li><a href=\"/a\">Home</a></li><li class=\"active\"><a href=\"/b\">Docs</a></li></ul>",
  {"HTML", "XMLObject"}];

XMLCases[html, "li.active a"]
(* {XMLElement["a", {"shape" -> "rect", "href" -> "/b"}, {"Docs"}]} *)

XMLCases[html, XMLPattern["a", {"href" -> h_}] :> h]
(* {"/a", "/b"} *)

HTMLInnerText[XMLFirstCase[html, "ul.menu"]]
(* "Home\nDocs" *)
```

## Installing

Requires Wolfram Language 13.2 or later. Clone the repository, then either load it for the current session:

```wl
PacletDirectoryLoad["/path/to/HTMLPatterns"];
Needs["MaximilienTirard`HTMLPatterns`"]
```

or build and install it with `make install`, which needs `wolframscript`.

The reference pages, the guide page and the tutorial are in `Documentation/`. Once the paclet is installed they are in the Documentation Center; start from the guide page "HTMLPatterns".

## Tests

```sh
make test
```

The tests use [UnitTestFramework](https://github.com/SjoerdSmitWolfram/UnitTestFramework), which `Tests/run_tests.wls` loads from GitHub if there is no local checkout beside this repository.

## License

MIT; see [LICENSE](LICENSE).
