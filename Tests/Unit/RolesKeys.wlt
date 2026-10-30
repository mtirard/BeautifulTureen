(* "Roles" and "Constructs" keys: a pattern key
   is an element test, each element tested as the pattern root, its names
   bound for the value; a rule key is a query over the original input, whose
   counted element positions get the value. A CSS string is whichever its
   translation is. The fixtures are local to this file. *)

page = doc[el["body", el["nav", el["a", "Home"], el["a", "News"]], el["p", "Text"]]];

(* === Examples === *)

TestCreate[
  HTMLInnerText[page, "Roles" -> {"nav a" -> "Block"}],
  "Home\nNews\nText",
  TestID -> "roles-context-selector-key"
];

TestCreate[
  HTMLInnerText[page, "Roles" -> {(XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> x) -> "Block"}],
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
   HTMLToNotebook[page, "Roles" -> {(XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> x) -> "Block"}]},
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

(* The value takes the matches of the element's first result. *)
TestCreate[
  HTMLToNotebook[doc[el["body", el["div", XMLElement["h2", {"class" -> "Section"}, {}], XMLElement["h2", {"class" -> "Subsection"}, {}], "x"]]],
    "Constructs" -> {XMLPattern["div"][Descendant[XMLPattern["h2", "class" -> s_]]] :> s}],
  Notebook[{Cell[TextData[{"x"}], "Section"]}],
  TestID -> "constructs-key-first-result-matches"
];

(* A function value is given the element as it is in the input. *)
TestCreate[
  HTMLToNotebook[doc[el["body", XMLElement["a", {"href" -> "/x"}, {"go"}]]],
    "Constructs" -> {"a" -> Function[e, {e}], (XMLPattern["body"][{x_}] :> x) -> "Bold"}],
  Notebook[{Cell[TextData[{Cell[BoxData[XMLElement["a", {"href" -> "/x"}, {"go"}]]]}], "Text"]}],
  TestID -> "constructs-function-gets-the-element-as-given"
];

(* === Query keys select positions, not values === *)

same = doc[el["ul", el["li", "x"], el["li", "x"], el["li", "x"]]];

TestCreate[
  {HTMLInnerText[same, "Roles" -> {"li:first-child" -> "Skip"}],
   HTMLInnerText[same, "Roles" -> {(XMLPattern["ul"][{___, x_}] :> x) -> "Skip"}]},
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
  HTMLToNotebook[doc[el["p", XMLElement["a", {"href" -> "/x"}, {"go"}]]], "Constructs" -> {(XMLPattern["p"][{x__}] :> x) -> "Bold"}],
  $Failed,
  {HTMLToNotebook::keytarget},
  TestID -> "constructs-keytarget-run"
];

(* HTMLToTree's "Roles" take both kinds, as HTMLInnerText's do; the drawn
   elements are as given. *)
treeShape[t_Tree] := TreeData[t] -> (treeShape /@ Replace[TreeChildren[t], None -> {}]);

TestCreate[
  treeShape /@ {HTMLToTree[page, "MergeText" -> HTMLInnerText], HTMLToTree[page, "MergeText" -> HTMLInnerText, "Roles" -> {"nav a" -> "Block"}]},
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

(* An element-test key that is refused is named as given, not as the query
   built from it. *)

(* The name and text of each message an evaluation gives, its arguments in
   InputForm. *)
SetAttributes[keyMessages, HoldFirst];
keyMessages[expr_] := Module[{texts = {}},
  Internal`HandlerBlock[
    {"Message", Function[m,
      Replace[m, Hold[Message[mn : MessageName[_, _], args___], _] :>
        AppendTo[texts, {Hold[mn], ToString[
          StringForm[mn, Sequence @@ (List @@ Map[Function[a, ToString[Unevaluated[a], InputForm], HoldAllComplete], Hold[args]])],
          OutputForm, PageWidth -> Infinity]}]]]},
    Quiet[expr]];
  texts];

(* A badpat text ends with the sentence that names what was refused. *)
TestCreate[
  Map[{#[[1]], Last[StringSplit[#[[2]], ". "]]} &, keyMessages /@ Unevaluated[{
    HTMLInnerText[page, "Roles" -> {1 -> "Block"}],
    HTMLInnerText[page, "Roles" -> {{XMLPattern["a"]} -> "Block"}],
    HTMLInnerText[page, "Roles" -> {("a" | "nav a") -> "Block"}],
    HTMLInnerText[page, "Roles" -> {(n : "nav a") -> "Block"}],
    HTMLToNotebook[page, "Constructs" -> {XMLDocument[Descendant[XMLPattern["a"]]] -> "Bold"}],
    HTMLToNotebook[page, "Constructs" -> {{XMLPattern["a"]} :> "Bold"}],
    HTMLToTree[page, "Roles" -> {1 -> "Block"}]}], {2}],
  {{{Hold[HTMLInnerText::badpat], "Got 1."}}, {{Hold[HTMLInnerText::badpat], "Got {XMLPattern[\"a\"]}."}},
    {{Hold[HTMLInnerText::badpat], "Got \"nav a\"."}}, {{Hold[HTMLInnerText::badpat], "Got \"nav a\"."}},
    {{Hold[HTMLToNotebook::badpat], "Got XMLDocument[Descendant[XMLPattern[\"a\"]]]."}},
    {{Hold[HTMLToNotebook::badpat], "Got {XMLPattern[\"a\"]}."}},
    {{Hold[HTMLToTree::badpat], "Got 1."}}},
  TestID -> "test-key-refusal-names-the-key"
];

(* A blank text starts with the blank it was given. *)
TestCreate[
  Map[{#[[1]], First[StringSplit[#[[2]], ","]]} &, keyMessages /@ Unevaluated[{
    HTMLInnerText[page, "Roles" -> {_ -> "Block"}],
    HTMLToNotebook[page, "Constructs" -> {_ :> "Bold"}]}], {2}],
  {{{Hold[HTMLInnerText::blank], "_ is a blank"}}, {{Hold[HTMLToNotebook::blank], "_ is a blank"}}},
  TestID -> "test-key-blank-names-the-key"
];

(* So is a key that uses Adjacent or Sibling, removed in version 4. *)
TestCreate[
  Map[{#[[1]], Last[StringSplit[#[[2]], ". "]]} &, keyMessages /@ Unevaluated[{
    HTMLInnerText[page, "Roles" -> {Adjacent[XMLPattern["a"], XMLPattern["a"]] -> "Block"}],
    HTMLToNotebook[page, "Constructs" -> {(XMLPattern["nav"] | Sibling[XMLPattern["a"], XMLPattern["a"]]) :> "Bold"}]}], {2}],
  {{{Hold[HTMLInnerText::badpat], "Got Adjacent[XMLPattern[\"a\"], XMLPattern[\"a\"]]."}},
    {{Hold[HTMLToNotebook::badpat], "Got XMLPattern[\"nav\"] | Sibling[XMLPattern[\"a\"], XMLPattern[\"a\"]]."}}},
  TestID -> "test-key-removed-combinator-names-the-key"
];
