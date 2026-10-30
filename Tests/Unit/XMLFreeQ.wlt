(* XMLFreeQ (#32, as amended for tree patterns in 4.0.0): True when
   no element at the given DOM depths below the input matches the pattern as
   the pattern root. Level 0 is the input itself. The fixtures are local to
   this file. *)

nav = doc[e["nav", "o", e["a", "a1"], e["nav", "i", e["a", "a2"]], e["a", "a3"]]];

(* The default level spec is {0, Infinity}, as FreeQ's. *)
TestCreate[
  {XMLFreeQ[nav[[2]], XMLPattern["nav"]], XMLFreeQ[nav[[2]], XMLPattern["nav"], {1, Infinity}],
    XMLFreeQ[nav[[2, 3, 2]], XMLPattern["nav"], {1, Infinity}]},
  {False, False, True},
  TestID -> "xmlfreeq-default-levels"
];

TestCreate[
  {XMLFreeQ[nav[[2]], XMLPattern["p"]], XMLFreeQ[nav[[2]], XMLPattern["a"]], XMLFreeQ[nav, XMLPattern["a", "id" -> "a2"]]},
  {True, False, False},
  TestID -> "xmlfreeq-searches-below"
];

(* Level specs in DOM depth, in FreeQ's forms. *)
TestCreate[
  {XMLFreeQ[nav[[2]], XMLPattern["a"], 1], XMLFreeQ[nav[[2]], XMLPattern["a"], {2}],
    XMLFreeQ[nav[[2]], XMLPattern["a", "id" -> "a2"], 1], XMLFreeQ[nav[[2]], XMLPattern["a", "id" -> "a2"], {2, 3}],
    XMLFreeQ[nav[[2]], XMLPattern["nav"], {0}], XMLFreeQ[nav[[2]], XMLPattern["a"], {0}],
    XMLFreeQ[nav[[2]], XMLPattern["a"], Infinity], XMLFreeQ[nav[[2]], XMLPattern["a"], {3, Infinity}]},
  {False, False, True, False, False, True, False, True},
  TestID -> "xmlfreeq-level-specs"
];

(* A document is at depth 0, its root element at 1; only an XMLDocument
   pattern matches the document. *)
TestCreate[
  {XMLFreeQ[nav, XMLPattern["nav"], {1}], XMLFreeQ[nav, XMLPattern["nav"], {0}],
    XMLFreeQ[nav, XMLDocument[{XMLPattern["nav"]}]], XMLFreeQ[nav, XMLDocument[], {1, Infinity}],
    XMLFreeQ[nav[[2]], XMLDocument[]]},
  {False, True, False, True, True},
  TestID -> "xmlfreeq-document"
];

(* A list is not an element: its elements are at depth 1, and strings are
   skipped. *)
TestCreate[
  {XMLFreeQ[{" ", nav[[2]]}, XMLPattern["nav"]], XMLFreeQ[{" ", nav[[2]]}, XMLPattern["nav"], {0}],
    XMLFreeQ[{" ", nav[[2]]}, XMLPattern["a", "id" -> "a2"], 2], XMLFreeQ[{}, XMLPattern[_]]},
  {False, True, True, True},
  TestID -> "xmlfreeq-list"
];

(* Tree patterns, each element tested as the pattern root. *)
TestCreate[
  {XMLFreeQ[nav[[2]], XMLPattern["nav"][{XMLPattern["a"], ___, XMLPattern["a"]}], {1, Infinity}],
    XMLFreeQ[nav[[2]], XMLPattern["nav"][{XMLPattern["a"], ___, XMLPattern["a"]}]],
    XMLFreeQ[nav, n : XMLPattern["nav"] /; Length[n[[3]]] == 3, {2, Infinity}],
    XMLFreeQ[nav, "nav#i"], XMLFreeQ[nav, XMLElement["a", {"id" -> "a2"}, {}]]},
  {True, False, True, False, False},
  TestID -> "xmlfreeq-tree-patterns"
];

(* The operator form takes no level spec, and tests depth 0 too. *)
TestCreate[
  {Select[{nav[[2]], nav[[2, 3, 2]], nav[[2, 3, 1]]}, XMLFreeQ[XMLPattern["nav", "id" -> "i"]]],
    Select[{nav[[2]], nav[[2, 3, 1]]}, XMLFreeQ[XMLPattern["a"]]]},
  {{nav[[2, 3, 1]]}, {}},
  TestID -> "xmlfreeq-operator-form"
];

(* In the operator form too, an element or a list is free of an XMLDocument
   pattern, and a list itself is not tested. *)
TestCreate[
  {XMLFreeQ[XMLDocument[]] /@ {nav[[2]], {nav[[2]]}, nav},
    XMLFreeQ[XMLPattern["nav", "id" -> "i"]] /@ {nav, {" ", nav[[2]]}, {" "}}},
  {{True, True, False}, {False, False, True}},
  TestID -> "xmlfreeq-operator-form-kinds"
];

(* The use that #32 was opened for: a construct rule that looks inside the
   element it tests. *)
TestCreate[
  With[{sups = {el["sup", el["a", "[1]"]], el["sup", "2"]}},
    Cases[sups, s : XMLElement["sup", _, _] /; !XMLFreeQ[s, XMLPattern["a"], {1, Infinity}] :> "Plain"]],
  {"Plain"},
  TestID -> "xmlfreeq-in-a-test"
];

TestCreate[
  {XMLFreeQ[XMLElement["p", {"class" -> "x y"}, {}], XMLPattern["p", "classList" -> "y"]],
    XMLFreeQ[XMLElement["a", {"rel" -> "next"}, {}], XMLPattern["a", "relList" -> "next"], "AttributeReadings" -> <|"rel" -> <||>|>],
    XMLFreeQ[XMLPattern["a", "relList" -> "next"], "AttributeReadings" -> <|"rel" -> <||>|>][XMLElement["a", {"rel" -> "next"}, {}]]},
  {False, False, False},
  TestID -> "xmlfreeq-attribute-readings"
];

(* === Refusals === *)

TestCreate[
  {XMLFreeQ[nav, x : XMLPattern["a"] :> x], XMLFreeQ[nav, "nav a"]},
  {$Failed, $Failed},
  {XMLFreeQ::badpat, XMLFreeQ::badpat},
  TestID -> "xmlfreeq-refuses-rule-and-context-selector"
];

TestCreate[
  {XMLFreeQ[nav, {___, XMLPattern["a"]}], XMLFreeQ[nav, Descendant[XMLPattern["a"]]]},
  {$Failed, $Failed},
  {XMLFreeQ::badpat, Descendant::place},
  TestID -> "xmlfreeq-refuses-list-and-descendant"
];

TestCreate[
  {XMLFreeQ[nav, XMLPattern["a"], -1], XMLFreeQ[nav, XMLPattern["a"], {2, 1}]},
  {$Failed, $Failed},
  {XMLFreeQ::level, XMLFreeQ::level},
  TestID -> "xmlfreeq-refuses-level-spec"
];

TestCreate[
  {XMLFreeQ["text", XMLPattern["a"]], XMLFreeQ[{el["a"], 5}, XMLPattern["a"]]},
  {$Failed, $Failed},
  {XMLFreeQ::badtree, XMLFreeQ::badmember},
  TestID -> "xmlfreeq-refuses-tree"
];

TestCreate[
  {XMLFreeQ[XMLPattern["a"]], XMLFreeQ[nav, XMLPattern["a"], 1, 2]},
  {XMLFreeQ[XMLPattern["a"]], XMLFreeQ[nav, XMLPattern["a"], 1, 2]},
  {XMLFreeQ::argt},
  TestID -> "xmlfreeq-argument-count"
];
