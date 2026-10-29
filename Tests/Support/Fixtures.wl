(*
	Shared HTML/XML fixtures for the HTMLPatterns test suite, and the builders
	and helpers that many test files use.

	These trees are used by more than one test file (XMLFirstCase, XMLPattern,
	RealWorld), so they live here and are parsed once at PacletInitialization time
	rather than re-imported per file. Fixtures used by only a single file stay
	inline in that file, next to the tests that exercise them.

	Loaded by Tests/TestConfig.m's "PacletInitialization". The symbols are exported
	on the HTMLPatternsTests` context, which TestConfig.m adds to
	"PacletContexts" so tests can reference them unqualified.
*)

BeginPackage["HTMLPatternsTests`"];

$tree::usage = "$tree is an imported HTML document with a .main div (two <p>, a <span>) and a .sidebar div.";
$treeProducts::usage = "$treeProducts is an imported HTML product listing with data-price attributes and <a> children, for named-attribute extraction tests.";
$realTree::usage = "$realTree is the imported real-world wolfram-language.html page (Tests/assets), for integration-scale tests.";

(* Builders for literal trees, whose positions are exact. A test file that
   defines a function of the same name changes it for every file run after
   it, so give a local helper another name. *)
doc::usage = "doc[root] is an XMLObject document with root element root.";
e::usage = "e[tag, id, c1, c2, ...] is an XMLElement with tag, the attribute \"id\" -> id, and contents c1, c2, ....";
el::usage = "el[tag, c1, c2, ...] is an XMLElement with tag, no attributes, and contents c1, c2, ....";
id::usage = "id[x] is the id attribute of the XMLElement x.";

(* HTMLToTree's result as data. *)
shape::usage = "shape[tree] is a Tree as nested data: data -> {children} for a node with children, the bare data for a leaf.";
shell::usage = "shell[tag, attrs] is an element node's data, the element with no contents; attrs defaults to {}.";

Begin["`Private`"];

doc[root_] := XMLObject["Document"][{}, root, {}];
e[tag_, id_String, c___] := XMLElement[tag, {"id" -> id}, {c}];
el[tag_, c___] := XMLElement[tag, {}, {c}];
id[x_XMLElement] := Lookup[x[[2]], "id"];

shape[t_Tree] := Replace[TreeChildren[t], {None -> TreeData[t], cs_ :> TreeData[t] -> (shape /@ cs)}];
shell[tag_, attrs_ : {}] := XMLElement[tag, attrs, {}];

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
