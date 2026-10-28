(* "Roles" and "Constructs" keys: a pattern key
   is an element test, each element tested as the pattern root, its names
   bound for the value; a rule key is a query over the original input, whose
   counted element positions get the value. A CSS string is whichever its
   translation is. The fixtures are local to this file. *)

doc[root_] := XMLObject["Document"][{}, root, {}];
el[tag_, c___] := XMLElement[tag, {}, {c}];

page = doc[el["body", el["nav", el["a", "Home"], el["a", "News"]], el["p", "Text"]]];

(* === Examples === *)

TestCreate[
  HTMLInnerText[page, "Roles" -> {"nav a" -> "Block"}],
  "Home\nNews\nText",
  TestID -> "roles-context-selector-key"
];

TestCreate[
  HTMLInnerText[page, "Roles" -> {(XMLPattern["nav", _, Descendant[x : XMLPattern["a"]]] :> x) -> "Block"}],
  "Home\nNews\nText",
  TestID -> "roles-rule-key"
];

TestCreate[
  HTMLInnerText[page, "Roles" -> {XMLDocument[Descendant[XMLPattern["a"]]] -> "Block"}],
  $Failed,
  {HTMLInnerText::badpat},
  TestID -> "roles-document-key-refused"
];

(* The same by HTMLToNotebook: each link is a Text cell of its own. *)
$pageCells = Notebook[{Cell[TextData[{"Home"}], "Text"], Cell[TextData[{"News"}], "Text"], Cell[TextData[{"Text"}], "Text"]}];

TestCreate[
  {HTMLToNotebook[page, "Roles" -> {"nav a" -> "Block"}],
   HTMLToNotebook[page, "Roles" -> {(XMLPattern["nav", _, Descendant[x : XMLPattern["a"]]] :> x) -> "Block"}]},
  {$pageCells, $pageCells},
  TestID -> "tonotebook-roles-query-keys"
];

TestCreate[
  HTMLToNotebook[page, "Roles" -> {XMLDocument[Descendant[XMLPattern["a"]]] -> "Block"}],
  $Failed,
  {HTMLToNotebook::badpat},
  TestID -> "tonotebook-roles-document-key-refused"
];

(* === Element tests bind names for the value === *)

TestCreate[
  HTMLToNotebook[doc[el["body", XMLElement["p", {"class" -> "Section"}, {"Hi"}], el["p", "There"]]],
    "Constructs" -> {XMLPattern["p", "class" -> s_] :> s}],
  Notebook[{Cell[TextData[{"Hi"}], "Section"], Cell[TextData[{"There"}], "Text"]}],
  TestID -> "constructs-key-binds-an-attribute"
];

(* The value takes the bindings of the element's first result. *)
TestCreate[
  HTMLToNotebook[doc[el["body", el["div", XMLElement["h2", {"class" -> "Section"}, {}], XMLElement["h2", {"class" -> "Subsection"}, {}], "x"]]],
    "Constructs" -> {XMLPattern["div", _, Descendant[XMLPattern["h2", "class" -> s_]]] :> s}],
  Notebook[{Cell[TextData[{"x"}], "Section"]}],
  TestID -> "constructs-key-first-result-bindings"
];

(* A function value is given the element as it is in the input. *)
TestCreate[
  HTMLToNotebook[doc[el["body", XMLElement["a", {"href" -> "/x"}, {"go"}]]],
    "Constructs" -> {"a" -> Function[e, {e}], (XMLPattern["body", _, {x_}] :> x) -> "Bold"}],
  Notebook[{Cell[TextData[{Cell[BoxData[XMLElement["a", {"href" -> "/x"}, {"go"}]]]}], "Text"]}],
  TestID -> "constructs-function-gets-the-element-as-given"
];

(* === Query keys select positions, not values === *)

same = doc[el["ul", el["li", "x"], el["li", "x"], el["li", "x"]]];

TestCreate[
  {HTMLInnerText[same, "Roles" -> {"li:first-child" -> "Skip"}],
   HTMLInnerText[same, "Roles" -> {(XMLPattern["ul", _, {___, x_}] :> x) -> "Skip"}]},
  {"x\nx", "x\nx"},
  TestID -> "roles-query-key-equal-elements"
];

(* Rules are tried in order, whatever their kind; the first that selects an
   element wins. *)
TestCreate[
  {HTMLInnerText[same, "Roles" -> {"li:first-child" -> "Skip", "li" -> "Inline"}],
   HTMLInnerText[same, "Roles" -> {"li" -> "Inline", "li:first-child" -> "Skip"}]},
  {"xx", "xxx"},
  TestID -> "roles-first-rule-wins-across-kinds"
];

(* An element test tests the bare input's root too; a query never selects
   it (ADR 0018). *)
TestCreate[
  {HTMLInnerText[el["p", "a", el["b", "c"]], "Roles" -> {"p" -> "Skip"}],
   HTMLInnerText[el["p", "a", el["b", "c"]], "Roles" -> {(x : XMLPattern["p"] :> x) -> "Skip", "b" -> "Skip"}]},
  {"ac", "a"},
  TestID -> "roles-bare-root"
];

TestCreate[
  HTMLInnerText[doc[el["p", XMLElement["a", {"href" -> "/x"}, {"go"}]]], "Roles" -> {(XMLPattern["a", "href" -> h_] :> h) -> "Block"}],
  $Failed,
  {HTMLInnerText::keytarget},
  TestID -> "roles-keytarget"
];

TestCreate[
  HTMLToNotebook[doc[el["p", XMLElement["a", {"href" -> "/x"}, {"go"}]]], "Constructs" -> {(XMLPattern["p", _, {x__}] :> x) -> "Bold"}],
  $Failed,
  {HTMLToNotebook::keytarget},
  TestID -> "constructs-keytarget-run"
];

(* HTMLToTree's "Roles" take both kinds, as HTMLInnerText's do; the drawn
   elements are as given. *)
shape[t_Tree] := TreeData[t] -> (shape /@ Replace[TreeChildren[t], None -> {}]);

TestCreate[
  shape /@ {HTMLToTree[page, "MergeText" -> HTMLInnerText], HTMLToTree[page, "MergeText" -> HTMLInnerText, "Roles" -> {"nav a" -> "Block"}]},
  {"#document" -> {el["body"] -> {el["nav"] -> {"HomeNews" -> {}}, el["p"] -> {"Text" -> {}}}},
   "#document" -> {el["body"] -> {el["nav"] -> {el["a"] -> {"Home" -> {}}, el["a"] -> {"News" -> {}}}, el["p"] -> {"Text" -> {}}}}},
  TestID -> "tree-roles-query-key"
];

(* A context selector named is refused as a key of either kind. *)
TestCreate[
  HTMLInnerText[page, "Roles" -> {(n : "nav a") -> "Block"}],
  $Failed,
  {HTMLInnerText::badpat},
  TestID -> "roles-named-context-key-refused"
];
