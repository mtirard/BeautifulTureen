(* Repeated names: a name for a
   place bound in two constraints of one tree pattern is one position; every
   other repeated name compares values, and a counted one keeps both
   positions. Names shared by the branches of one Alternatives are bound
   once. *)

same = doc[el["ul", el["li", "x"], el["li", "x"], el["li", "x"], el["li", "x"], el["li", "x"]]];
dups = doc[el["tbody", el["tr", "a"], el["tr", "b"], el["tr", "a"]]];

(* === Position across constraints === *)

(* li:nth-child(3):nth-last-child(2) on five equal li: one child, not two
   equal ones. *)
TestCreate[
  XMLCases[same, XMLPattern["ul"][{_, _, n : XMLPattern["li"], ___}, {___, n : XMLPattern["li"], _}] :> n],
  {},
  TestID -> "repeated-position-across-constraints-none"
];

TestCreate[
  XMLPosition[same, XMLPattern["ul"][{_, _, n : XMLPattern["li"], ___}, {___, n : XMLPattern["li"], _, _}] :> n],
  {{1, 3}},
  TestID -> "repeated-position-across-constraints-one"
];

(* === Value within one list === *)

TestCreate[
  XMLCases[dups, XMLPattern["tbody"][{___, x : XMLPattern["tr"], ___, x : XMLPattern["tr"], ___}] :> x],
  {el["tr", "a"]},
  TestID -> "repeated-value-within-list"
];

TestCreate[
  XMLPosition[dups, XMLPattern["tbody"][{___, x : XMLPattern["tr"], ___, x : XMLPattern["tr"], ___}] :> x],
  {{{1, 1}, {1, 3}}},
  TestID -> "repeated-value-both-positions"
];

(* A name inside Repeated binds at each repeat, and its values must be
   equal, as in WL. *)
TestCreate[
  {XMLPosition[same, XMLPattern["ul"][{(x : XMLPattern["li"]) ..}] :> x],
    XMLCases[dups, XMLPattern["tbody"][{(x : XMLPattern["tr"]) ..}] :> x],
    XMLCases[dups, XMLPattern["tbody"][{(x : XMLPattern["tr"]) ..}]]},
  {{{{1, 1}, {1, 2}, {1, 3}, {1, 4}, {1, 5}}}, {}, {}},
  TestID -> "repeated-inside-repeated"
];

TestCreate[
  XMLPosition[dups, XMLPattern["tbody"][{___, PatternSequence[x : XMLPattern["tr"], _] .., ___}] :> x],
  {{1, 1}, {1, 2}},
  TestID -> "repeated-inside-repeated-once"
];

(* An ancestor and a descendant compare values: an element never equals one
   inside it. *)
TestCreate[
  XMLCases[doc[el["div", el["div"]]], x : XMLPattern["div"][Descendant[x : XMLPattern["div"]]] :> x],
  {},
  TestID -> "repeated-ancestor-descendant-value"
];

(* A tag name, a string, compares by value across constraints. *)
TestCreate[
  XMLCases[doc[el["div", el["p"], el["b"], el["p"]]], XMLPattern["div"][{XMLPattern[t_], ___}, {___, x : XMLPattern[t_]}] :> x],
  {el["p"]},
  TestID -> "repeated-string-across-constraints-value"
];

(* A name once in one constraint and twice in another never matches. *)
TestCreate[
  XMLCases[dups, XMLPattern["tbody"][{___, x : XMLPattern["tr"], ___, x : XMLPattern["tr"], ___}, {x : XMLPattern["tr"], ___}] :> 1],
  {},
  TestID -> "repeated-mixed-never-matches"
];

(* === Alternatives === *)

(* A name in several branches of one Alternatives is bound once. The
   spike's engine read the shared g2 as repeated, kept it, and grew memory
   quadratically. *)
siblings = doc[el["div", Sequence @@ Table[el[If[OddQ[k], "a", "b"]], {k, 1000}]]];
(* The second run of each, so that neither pays for what the first call to
   the engine caches. *)
memoryOf[q_] := MemoryConstrained[Last @ Table[MaxMemoryUsed[XMLCases[siblings, q]], 2], 10^9, Infinity];

TestCreate[
  With[{
      shared = memoryOf[(XMLPattern[_][{g___, XMLPattern["a"], x : XMLPattern["b"], g2___}] |
        XMLDocument[{g___, XMLPattern["a"], x : XMLPattern["b"], g2___}]) :> x],
      unshared = memoryOf[(XMLPattern[_][{g___, XMLPattern["a"], x : XMLPattern["b"], g2___}] |
        XMLDocument[{h___, XMLPattern["a"], x : XMLPattern["b"], h2___}]) :> x]},
    shared <= 1.1 unshared],
  True,
  TestID -> "repeated-alternatives-shared-costs-no-more"
];

TestCreate[
  XMLCases[doc[el["li", el["a"], el["span"]]], XMLPattern["li"][{___, (x : XMLPattern["a"]) | (x : XMLPattern["span"]), ___}] :> x],
  {el["a"], el["span"]},
  TestID -> "repeated-alternatives-bound-once"
];

(* === Except referring to a name matched outside it === *)

(* Siblings whose tags repeat: b a c a b a. *)
types = doc[el["div", e["b", "1"], e["a", "2"], e["c", "3"], e["a", "4"], e["b", "5"], e["a", "6"]]];

(* An Except before its name is bound refers to it: :first-of-type, where
   WL's matcher would give only the first child. *)
TestCreate[
  XMLCases[types, XMLPattern["div"][{Except[XMLPattern[t_]] ..., n : XMLPattern[t_], ___}] :> id[n]],
  {"1", "2", "3"},
  TestID -> "except-ref-first-of-type"
];

TestCreate[
  XMLCases[types, XMLPattern["div"][{___, n : XMLPattern[t_], Except[XMLPattern[t_]] ...}] :> id[n]],
  {"3", "5", "6"},
  TestID -> "except-ref-last-of-type"
];

TestCreate[
  XMLCases[types, XMLPattern["div"][{___, n : XMLPattern[t_], Except[XMLPattern[t_]] ..., XMLPattern[t_], Except[XMLPattern[t_]] ...}] :> id[n]],
  {"1", "4"},
  TestID -> "except-ref-nth-last-of-type"
];

(* Not preceded by its own tag. *)
TestCreate[
  XMLCases[types, XMLPattern["div"][{Except[XMLPattern[t_]] ..., x : XMLPattern[t_], ___}] :> x],
  {e["b", "1"], e["a", "2"], e["c", "3"]},
  TestID -> "except-ref-not-preceded-by-own-tag"
];

(* Across constraints an Except excludes the child itself, not the equal
   ones: every li but the first, on equal li. *)
TestCreate[
  XMLPosition[same, XMLPattern["ul"][{n : XMLPattern["li"], ___}, {___, Except[n : XMLPattern["li"], x : XMLPattern["li"]], ___}] :> x],
  {{1, 2}, {1, 3}, {1, 4}, {1, 5}},
  TestID -> "except-ref-across-constraints-excludes-that-child"
];

(* Within one list the same Except compares values, and equal li are
   excluded too. *)
TestCreate[
  XMLPosition[same, XMLPattern["ul"][{n : XMLPattern["li"], ___, Except[n : XMLPattern["li"], x : XMLPattern["li"]], ___}] :> x],
  {},
  TestID -> "except-ref-within-list-compares-values"
];

(* A name bound outside the Except too may be used in the right-hand side. *)
TestCreate[
  XMLCases[types, XMLPattern["div"][{Except[XMLPattern[t_]] ..., n : XMLPattern[t_], ___}] :> {t, id[n]}],
  {{"b", "1"}, {"a", "2"}, {"c", "3"}},
  TestID -> "except-ref-name-in-rhs"
];

(* An Except referring to a name matched on an ancestor compares values. *)
TestCreate[
  XMLCases[doc[el["div", el["p", el["div"], el["b"]], el["p", el["b"]]]],
    XMLPattern[t_][Descendant[x : XMLPattern["p"][{Except[XMLPattern[t_]] ..}]]] :> x],
  {el["p", el["b"]]},
  TestID -> "except-ref-ancestor-value"
];

TestCreate[
  {XMLMatchQ[types[[2]], XMLPattern["div"][{___, XMLPattern[t_], Except[XMLPattern[t_]], XMLPattern[t_], ___}]],
    XMLMatchQ[types[[2]], XMLPattern["div"][{___, XMLPattern[t_], XMLPattern[t_], ___}]]},
  {True, False},
  TestID -> "except-ref-xmlmatchq"
];

(* A name bound only inside Except stays local. *)
TestCreate[
  XMLCases[types, XMLPattern["div"][{Except[x : XMLPattern["b"]] ..., ___}] :> x],
  $Failed,
  {XMLCases::exceptname},
  TestID -> "except-local-name-in-rhs"
];

TestCreate[
  XMLCases[types, XMLPattern["div"][{Except[XMLPattern["b"]], y : XMLPattern[t_], ___}] :> id[y]],
  {},
  TestID -> "except-local-name-unbound-elsewhere"
];

(* === A counted name with two positions, as targets === *)

dupsQuery = XMLPattern["tbody"][{___, x : XMLPattern["tr"], ___, x : XMLPattern["tr"], ___}] :> x;

TestCreate[
  {XMLExtract[dups, {{1, 1}, {1, 3}}], XMLExtract[dups, #] & /@ XMLPosition[dups, dupsQuery]},
  {{el["tr", "a"], el["tr", "a"]}, {{el["tr", "a"], el["tr", "a"]}}},
  TestID -> "repeated-extract-reads-both"
];

TestCreate[
  XMLDeleteCases[dups, dupsQuery],
  doc[el["tbody", el["tr", "b"]]],
  TestID -> "repeated-delete-both"
];

TestCreate[
  XMLReplace[dups, XMLPattern["tbody"][{___, x : XMLPattern["tr"], ___, x : XMLPattern["tr"], ___}] :> {x -> "z"}],
  doc[el["tbody", "z", el["tr", "b"], "z"]],
  TestID -> "repeated-replace-both"
];

(* At each of its positions a target reads the name there, as rewritten so
   far: the b inside the second li is rewritten first. *)
TestCreate[
  XMLReplace[doc[el["ul", el["li", el["b"]], el["li", el["b"]]]],
    XMLPattern["ul"][{x : XMLPattern["li"], x : XMLPattern["li"][{b : XMLPattern["b"]}]}] :> {b -> el["i"], x -> el["ol", x]}],
  doc[el["ul", el["ol", el["li", el["b"]]], el["ol", el["li", el["i"]]]]],
  TestID -> "repeated-replace-reads-own-position"
];

rows = doc[el["tbody", XMLElement["tr", {"class" -> "a"}, {}], XMLElement["tr", {"class" -> "b"}, {}], XMLElement["tr", {"class" -> "a"}, {}]]];
rowsQuery = XMLPattern["tbody"][{___, x : XMLPattern["tr"], ___, x : XMLPattern["tr"], ___}] :> x;

TestCreate[
  shape /@ {HTMLToTree[rows, "Hide" -> rowsQuery], HTMLToTree[rows, "Focus" -> rowsQuery]},
  {"#document" -> {shell["tbody"] -> {shell["tr", {"class" -> "b"}]}},
    "#document" -> {shell["tr", {"class" -> "a"}], Missing["Collapsed", 1], shell["tr", {"class" -> "a"}]}},
  TestID -> "repeated-hide-and-focus-both"
];
