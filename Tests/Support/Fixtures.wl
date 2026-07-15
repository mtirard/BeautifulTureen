(*
	Shared HTML/XML fixtures for the BeautifulTureen test suite.

	These trees are used by more than one test file (Combinators, XMLFirstCase,
	RealWorld), so they live here and are parsed once at PacletInitialization time
	rather than re-imported per file. Fixtures used by only a single file stay
	inline in that file, next to the tests that exercise them.

	Loaded by Tests/TestConfig.m's "PacletInitialization". The symbols are exported
	on the BeautifulTureenTests` context, which TestConfig.m adds to
	"PacletContexts" so tests can reference them unqualified.
*)

BeginPackage["BeautifulTureenTests`"];

$tree::usage = "$tree is an imported HTML document with a .main div (two <p>, a <span>) and a .sidebar div.";
$treeSiblings::usage = "$treeSiblings is an imported HTML document of an <h2> followed by mixed <p>/<span> siblings, for combinator tests.";
$treeProducts::usage = "$treeProducts is an imported HTML product listing with data-price attributes and <a> children, for named-attribute extraction tests.";
$realTree::usage = "$realTree is the imported real-world wolfram-language.html page (Tests/assets), for integration-scale tests.";

Begin["`Private`"];

$tree = ImportString["<html><body>
  <div class=\"main\">
    <p>Hello</p>
    <p class=\"special\">World</p>
    <span>Ignored</span>
  </div>
  <div class=\"sidebar\">
    <p>Nav</p>
  </div>
</body></html>", {"HTML", "XMLObject"}];

$treeSiblings = ImportString["<html><body>
  <div>
    <h2>Title</h2>
    <p class=\"lead\">First</p>
    <p>Second</p>
    <span>Third</span>
    <p>Fourth</p>
  </div>
</body></html>", {"HTML", "XMLObject"}];

$treeProducts = ImportString["<html><body>
  <div class=\"products\">
    <div class=\"product on-sale\" data-price=\"19.99\">
      <a href=\"/sale\">Sale Item</a>
    </div>
    <div class=\"product\" data-price=\"49.99\">
      <a href=\"/regular\">Regular Item</a>
    </div>
  </div>
</body></html>", {"HTML", "XMLObject"}];

$realTree = Import[
  FileNameJoin[{ParentDirectory[DirectoryName[$InputFileName]], "assets", "wolfram-language.html"}],
  {"HTML", "XMLObject"}];

End[];

EndPackage[];
