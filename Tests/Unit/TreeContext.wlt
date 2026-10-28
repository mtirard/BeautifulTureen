(* Context above an element: named paths, path tests, Shortest and Longest
   on Descendant, and XMLDocument as a pattern root. The fixtures are
   literal trees, so positions are exact. *)

nav     = doc[e["nav", "o", e["a", "a1"], e["nav", "i", e["a", "a2"]], e["a", "a3"]]];
links   = doc[el["p", e["a", "1"], e["a", "2"], e["a", "3"]]];
body    = doc[el["body", e["nav", "n", e["a", "in"]], e["a", "out"]]];
tables  = doc[XMLElement["table", {"id" -> "A"}, {el["caption"], el["tr",
            e["td", "o", XMLElement["table", {"id" -> "B"}, {el["tr", e["td", "t"]]}]]]}]];

(* === XMLDocument as a pattern root === *)

(* The document's position is {}; its value is the input, and {e} for a bare
   element e. *)
TestCreate[
  {XMLCases[nav, d : XMLDocument[] :> d],
    XMLCases[nav[[2]], d : XMLDocument[] :> d],
    XMLCases[{nav[[2]], " "}, d : XMLDocument[] :> d]},
  {{nav}, {{nav[[2]]}}, {{nav[[2]], " "}}},
  TestID -> "document-named"
];

(* A bare pattern is r$ : p :> r$, so XMLDocument alone gives the input. *)
TestCreate[
  {XMLCases[nav, XMLDocument[]], XMLCases[nav, XMLDocument[{XMLPattern["nav"]}]], XMLCases[nav, XMLDocument[{XMLPattern["p"]}]]},
  {{nav}, {nav}, {}},
  TestID -> "document-bare"
];

(* The contents list of XMLDocument lists the top elements. A bare input's own
   position {1} is never counted; positions inside it can be. *)
TestCreate[
  {XMLCases[body, XMLDocument[{x_}] :> x[[1]]],
    XMLCases[body[[2]], XMLDocument[{x_}] :> x],
    XMLCases[body[[2]], XMLDocument[Descendant[x : XMLPattern["a"]]] :> id[x]],
    XMLCases[{e["a", "1"], " ", e["a", "2"]}, XMLDocument[{___, x_}] :> id[x]]},
  {{"body"}, {}, {"in", "out"}, {"2"}},
  TestID -> "document-top-elements"
];

(* Conditioned and tested: the test sees the document's value, {e} for a bare
   element. *)
TestCreate[
  {XMLCases[nav, XMLDocument[{_}] /; True], XMLCases[nav, XMLDocument[{_}] /; False],
    XMLCases[nav, (d : XMLDocument[]) /; MatchQ[d, XMLObject["Document"][___]] :> 1],
    XMLCases[nav, XMLDocument[]?(MatchQ[XMLObject["Document"][___]])],
    XMLCases[nav[[2]], XMLDocument[]?ListQ]},
  {{nav}, {}, {1}, {nav}, {{nav[[2]]}}},
  TestID -> "document-conditioned-tested"
];

(* A branch of Alternatives at the pattern root: siblings among the top
   elements too, as Adjacent was. *)
TestCreate[
  With[{L = {___, XMLPattern["a"], x : XMLPattern["b"], ___}},
    XMLCases[{e["a", "1"], e["b", "2"], el["div", e["a", "3"], e["b", "4"]]}, (XMLPattern[_, _, L] | XMLDocument[L]) :> id[x]]],
  {"2", "4"},
  TestID -> "document-alternatives-branch"
];

(* === Paths === *)

(* A path test sees the elements strictly between the pattern root and the
   match; under XMLDocument, exactly the match's ancestors. *)
TestCreate[
  XMLCases[body, XMLDocument[Descendant[x : XMLPattern["a"]]?(NoneTrue[XMLMatchQ["nav"]])] :> id[x]],
  {"out"},
  TestID -> "path-test-not-inside"
];

(* A named path binds the elements strictly between: a child gives {}, and
   the match's DOM depth below the root is Length[p] + 1. *)
TestCreate[
  XMLCases[nav, n : XMLPattern["nav", _, p : Descendant[x : XMLPattern["a"]]] :> {id[n], id[x], Length[p] + 1}],
  {{"o", "a1", 1}, {"o", "a2", 2}, {"o", "a3", 1}, {"i", "a2", 1}},
  TestID -> "path-named-depth"
];

(* Counting a path counts both its ends; it sorts by its lower end, then its
   upper end. *)
TestCreate[
  XMLCases[nav, XMLPattern["nav", _, p : Descendant[x : XMLPattern["a"]]] :> {id[x], Length[p] + 1}],
  {{"a1", 1}, {"a2", 2}, {"a2", 1}, {"a3", 1}},
  TestID -> "path-counts-both-ends"
];

TestCreate[
  {XMLCases[nav, XMLPattern["nav", "id" -> "o", p : Descendant[XMLPattern["a", "id" -> "a2"]]] :> id /@ p],
    XMLCases[nav, XMLDocument[p : Descendant[XMLPattern["a", "id" -> "a2"]]] :> id /@ p]},
  {{{"i"}}, {{"o", "i"}}},
  TestID -> "path-value"
];

(* === Shortest and Longest === *)

TestCreate[
  XMLCases[nav, n : XMLPattern["nav", _, Descendant[x : XMLPattern["a"]]] :> {id[n], id[x]}],
  {{"o", "a1"}, {"o", "a2"}, {"o", "a3"}, {"i", "a2"}},
  TestID -> "nearest-unfiltered"
];

TestCreate[
  XMLCases[nav, n : XMLPattern["nav", _, Shortest@Descendant[x : XMLPattern["a"]]] :> {id[n], id[x]}],
  {{"o", "a1"}, {"o", "a3"}, {"i", "a2"}},
  TestID -> "nearest-shortest"
];

TestCreate[
  XMLCases[nav, n : XMLPattern["nav", _, Longest@Descendant[x : XMLPattern["a"]]] :> {id[n], id[x]}],
  {{"o", "a1"}, {"o", "a2"}, {"o", "a3"}},
  TestID -> "nearest-longest"
];

(* With the root not counted, Shortest changes nothing. *)
TestCreate[
  XMLCases[nav, XMLPattern["nav", _, Shortest@Descendant[x : XMLPattern["a"]]] :> id[x]],
  {"a1", "a2", "a3"},
  TestID -> "nearest-root-uncounted"
];

(* Shortest compares the whole root pattern; a path test compares what it
   says. B has no caption, so it does not shadow A. *)
TestCreate[
  XMLCases[tables, n : XMLPattern["table", _, {XMLPattern["caption"], ___}, Shortest@Descendant[x : XMLPattern["td"]]] :> {id[n], id[x]}],
  {{"A", "o"}, {"A", "t"}},
  TestID -> "nearest-whole-root-pattern"
];

TestCreate[
  XMLCases[tables, n : XMLPattern["table", _, {XMLPattern["caption"], ___}, Descendant[x : XMLPattern["td"]]?(NoneTrue[XMLMatchQ["table"]])] :> {id[n], id[x]}],
  {{"A", "o"}},
  TestID -> "path-test-whole-path"
];

(* Under XMLDocument there is one root, so Shortest has no effect. Inside a
   contents list Shortest keeps WL's meaning, which changes no counted
   result. *)
TestCreate[
  {XMLCases[nav, XMLDocument[Shortest@Descendant[x : XMLPattern["a"]]] :> id[x]],
    XMLCases[links, XMLPattern["p", _, {Shortest[x__], ___}] :> Length[{x}]],
    XMLCases[links, XMLPattern["p", _, {x__, ___}] :> Length[{x}]]},
  {{"a1", "a2", "a3"}, {3, 2, 1}, {3, 2, 1}},
  TestID -> "nearest-no-effect"
];

(* A path can be conditioned, and a test on it can be uncounted. *)
TestCreate[
  {XMLCases[nav, XMLPattern["nav", _, (p : Descendant[x : XMLPattern["a"]]) /; Length[p] > 0] :> id[x]],
    XMLCases[nav, XMLPattern["nav", _, p : Descendant[x : XMLPattern["a"]]] :> id[x] /; Length[p] > 0],
    XMLFirstCase[nav, n : XMLPattern["nav", _, p : Descendant[x : XMLPattern["a"]]] :> {id[n], id[x], Length[p]}]},
  {{"a2"}, {"a2"}, {"o", "a1", 0}},
  TestID -> "path-conditioned"
];

(* A bare input is context: a tuple counting its position, directly or as
   the upper end of a counted path, is dropped. *)
TestCreate[
  {XMLCases[nav[[2]], n : XMLPattern["nav", _, Descendant[x : XMLPattern["a"]]] :> {id[n], id[x]}],
    XMLCases[nav[[2]], XMLPattern["nav", _, p : Descendant[x : XMLPattern["a"]]] :> {id[x], Length[p] + 1}],
    XMLCases[nav[[2]], XMLPattern["nav", _, Descendant[x : XMLPattern["a"]]] :> id[x]],
    XMLCases[nav[[2]], XMLDocument[p : Descendant[x : XMLPattern["a", "id" -> "a2"]]] :> id /@ p]},
  {{{"i", "a2"}}, {{"a2", 1}}, {"a1", "a2", "a3"}, {{"o", "i"}}},
  TestID -> "path-bare-input"
];

(* === Refusals === *)

TestCreate[
  {XMLCases[links, XMLPattern["ul", _, Shortest[{___, XMLPattern["li"]}]]],
    XMLCases[links, XMLDocument[Longest[{___}]]]},
  {$Failed, $Failed},
  {XMLPattern::shortest, XMLDocument::shortest},
  TestID -> "shortest-not-descendant"
];

(* === XMLDocument refusals === *)

TestCreate[
  {XMLCases[nav, XMLPattern["nav", _, Descendant[XMLDocument[]]]],
    XMLCases[nav, XMLPattern["nav", "id" -> XMLDocument[]]],
    XMLCases[nav, XMLElement["nav", _, {XMLDocument[]}]]},
  {$Failed, $Failed, $Failed},
  {XMLDocument::place, XMLDocument::place, XMLDocument::place, General::stop},
  TestID -> "document-place"
];

TestCreate[
  {XMLCases[nav, XMLPattern["nav", _, {___, XMLDocument[], ___}]],
    XMLCases[nav, XMLDocument[{___, XMLDocument[], ___}]],
    XMLCases[nav, XMLDocument[{___, Descendant[XMLPattern["a"]]}]]},
  {$Failed, $Failed, $Failed},
  {XMLPattern::listentry, XMLDocument::listentry, XMLDocument::listentry},
  TestID -> "document-listentry"
];

TestCreate[
  XMLCases[nav, XMLDocument[XMLPattern["nav"]]],
  $Failed,
  {XMLDocument::constraint},
  TestID -> "document-constraint"
];
