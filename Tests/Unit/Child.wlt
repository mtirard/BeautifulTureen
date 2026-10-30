(* Child[p], the constraint that some element child matches p. It means
   {___, p, ___}, in XMLPattern's bracket and in XMLDocument. The fixtures
   are literal trees, so positions are exact. *)

lists = doc[el["body",
  e["ul", "u1", e["li", "1"], " ", e["li", "2"]],
  e["ol", "o1", e["li", "3"]],
  e["ul", "u2", e["p", "4", e["li", "5"]]],
  e["ul", "u3"]]];

(* === Queries === *)

(* Each matching child once, in document order. *)
TestCreate[
  XMLCases[lists, XMLPattern["ul"][Child[x : XMLPattern["li"]]] :> id[x]],
  {"1", "2"},
  TestID -> "child-each-matching-child"
];

(* Positions count element children: u1's li are its children 1 and 2. *)
TestCreate[
  XMLPosition[lists, XMLPattern["ul"][Child[x : XMLPattern["li"]]] :> x],
  {{1, 1, 1}, {1, 1, 2}},
  TestID -> "child-positions"
];

(* An element with no matching child, or no children, does not match. *)
TestCreate[
  XMLCases[lists, XMLPattern["ul"][Child[XMLPattern["li"]]]] // Map[id],
  {"u1"},
  TestID -> "child-root-only"
];

TestCreate[
  XMLCases[lists, XMLPattern["ul"][Child[XMLPattern["li", "id" -> i_?(StringMatchQ["2"])]]] :> i],
  {"2"},
  TestID -> "child-test-inside"
];

TestCreate[
  XMLCases[lists, XMLPattern[t_][Child[XMLPattern["li"]]] :> t],
  {"ul", "ol", "p"},
  TestID -> "child-tag-name"
];

(* Several constraints all hold; Child beside Descendant, and two Child
   constraints, which are unordered. *)
TestCreate[
  {XMLCases[lists, XMLPattern["ul"][Child[XMLPattern["p"]], Descendant[x : XMLPattern["li"]]] :> id[x]],
    XMLCases[lists, XMLPattern["ul"][Child[y : XMLPattern["li", "id" -> "2"]], Child[x : XMLPattern["li"]]] :> {id[x], id[y]}]},
  {{"5"}, {{"1", "2"}, {"2", "2"}}},
  TestID -> "child-several-constraints"
];

TestCreate[
  XMLCases[lists, XMLPattern["ul", "id" -> i_][Child[XMLPattern["p"]] | {}] :> i],
  {"u2", "u3"},
  TestID -> "child-alternatives"
];

TestCreate[
  XMLCases[lists, XMLPattern["ul"][Child[x : XMLPattern["li"]] /; id[x] =!= "1"] :> id[x]],
  {"2"},
  TestID -> "child-condition"
];

(* Nested: a ul with a child that has an li child. *)
TestCreate[
  XMLCases[lists, XMLPattern["ul"][Child[XMLPattern[_][Child[x : XMLPattern["li"]]]]] :> id[x]],
  {"5"},
  TestID -> "child-nested"
];

TestCreate[
  XMLCases[lists, XMLPattern["ul"][Child[x : "li"]] :> id[x]],
  {"1", "2"},
  TestID -> "child-css-string"
];

(* Under XMLDocument, the children are the top-level elements. *)
TestCreate[
  {XMLMatchQ[lists, XMLDocument[Child[XMLPattern["body"]]]], XMLMatchQ[lists, XMLDocument[Child[XMLPattern["ul"]]]],
    XMLCases[{el["p"], "t", e["ul", "x"], e["ul", "y"]}, XMLDocument[Child[u : XMLPattern["ul"]]] :> id[u]]},
  {True, False, {"x", "y"}},
  TestID -> "child-document"
];

TestCreate[
  {XMLMatchQ[lists[[2, 3, 2]], XMLPattern["ol"][Child[XMLPattern["li"]]]],
    XMLMatchQ[XMLPattern["ul"][Child[XMLPattern["li"]]]] /@ lists[[2, 3, {1, 3, 4}]],
    XMLFreeQ[lists, XMLPattern["ol"][Child[XMLPattern["p"]]]],
    XMLFirstCase[lists, XMLPattern["ul"][Child[x : XMLPattern["li"]]] :> id[x]]},
  {True, {True, False, False}, True, "1"},
  TestID -> "child-element-tests"
];

TestCreate[
  {XMLDeleteCases[el["ul", el["li"], el["p"]], XMLPattern["ul"][Child[x : XMLPattern["li"]]] :> x],
    XMLReplace[el["ul", el["li"], el["p"]], XMLPattern["ul"][Child[x : XMLPattern["p"]]] :> x -> el["q"]]},
  {el["ul", el["p"]], el["ul", el["li"], el["q"]]},
  TestID -> "child-rewrites"
];

TestCreate[
  HTMLInnerText[el["div", el["ul", el["li", "a"]], el["ul", el["p", "b"]]],
    "Roles" -> {XMLPattern["ul"][Child[XMLPattern["li"]]] -> "Skip"}],
  "b",
  TestID -> "child-roles"
];

(* === The same as the list === *)

(* On seeded random trees (Support/RandomTrees.wl), Child[p] gives what
   {___, p, ___} gives, in the same order: named and unnamed, two Child
   constraints, nested, and under XMLDocument over a tree's top elements. *)
$childTrees = randomTrees[20261029, 6];

$childPairs = {
  {XMLPattern["div"][Child[x : XMLPattern["p"]]] :> x, XMLPattern["div"][{___, x : XMLPattern["p"], ___}] :> x},
  {XMLPattern["p"][Child[XMLPattern["span", "classList" -> "a"]]], XMLPattern["p"][{___, XMLPattern["span", "classList" -> "a"], ___}]},
  {XMLPattern[_][Child[x : XMLPattern["li", "classList" -> "a"]], Child[y : XMLPattern["span"]]] :> {x, y},
    XMLPattern[_][{___, x : XMLPattern["li", "classList" -> "a"], ___}, {___, y : XMLPattern["span"], ___}] :> {x, y}},
  {XMLPattern["div"][Child[XMLPattern[_][Child[x : XMLPattern["p"]]]]] :> x,
    XMLPattern["div"][{___, XMLPattern[_][{___, x : XMLPattern["p"], ___}], ___}] :> x},
  {XMLDocument[Child[x : XMLPattern["li"]]] :> x, XMLDocument[{___, x : XMLPattern["li"], ___}] :> x}};

(* Each pair gives the same results and positions on every tree, and some
   result on some tree. *)
TestCreate[
  Table[
    With[{runs = Table[
        With[{input = If[MatchQ[q[[1]], _XMLDocument :> _], t[[3]], t]},
          {XMLCases[input, q[[1]]], XMLCases[input, q[[2]]], XMLPosition[input, q[[1]]], XMLPosition[input, q[[2]]]}],
        {t, $childTrees}]},
      {AllTrue[runs, #[[1]] === #[[2]] && #[[3]] === #[[4]] &], AnyTrue[runs, #[[2]] =!= {} &]}],
    {q, $childPairs}] // Flatten // Union,
  {True},
  TestID -> "child-random-trees-as-list"
];
