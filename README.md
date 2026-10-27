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

Requires Wolfram Language 13.2 or later and `wolframscript`. Clone the repository and run:

```sh
make install
```

This builds the paclet with ``PacletTools`PacletBuild`` into `build/` and installs the archive. The build turns the author notebooks in `Documentation/` into the reference pages, guide page and tutorial that the Documentation Center reads; start from the guide page "HTMLPatterns".

To try the code without installing, load the clone for the current session instead. This does not give the built documentation.

```wl
PacletDirectoryLoad["/path/to/HTMLPatterns"];
Needs["MaximilienTirard`HTMLPatterns`"]
```

## Tests

```sh
make test
```

The tests use [UnitTestFramework](https://github.com/SjoerdSmitWolfram/UnitTestFramework), which `Tests/run_tests.wls` loads from GitHub if there is no local checkout beside this repository.

## License

MIT; see [LICENSE](LICENSE).
