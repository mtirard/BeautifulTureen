(* The positions of a query's matches: the sites the query's runner selects, in
   document order, at most n. HTMLToTree's focus and hide are built on them.
   These tests reach inside, as no public function gives positions: each query
   is checked against XMLCases, whose elements are the elements at the
   positions, on a document, a bare element and a list. A query that selects
   nothing is not a check, so each must select something. *)

$positionsHTML = "<html><body><div id='d' class='a b'><ul><li class='a'>x</li><li>x</li><li class='a'>y</li></ul>\
<p><a href='/k1' data-id='k1'>one</a></p><h2>H</h2><p>after</p><p>later</p></div>\
<ul><li>x</li><li>x</li></ul></body></html>";

$positionsDoc = ImportString[$positionsHTML, {"HTML", "XMLObject"}];
$positionsRoot = $positionsDoc[[2]];
$positionsList = With[{body = $positionsRoot[[3, 1]]}, {"text", body[[3, 1]], "more", body[[3, 2]]}];

positionsOf[tree_, q_, n_ : Infinity] :=
  MaximilienTirard`HTMLPatterns`PackageScope`queryPositions[
    MaximilienTirard`HTMLPatterns`PackageScope`compileQuery[q, XMLCases], tree, n];

(* Whether the positions of q in tree give XMLCases's elements, each site once,
   in document order, and give some. *)
agreesQ[tree_, q_, n_ : Infinity] :=
  MemoryConstrained[TimeConstrained[
    With[{ps = positionsOf[tree, q, n], cs = XMLCases[tree, q, n]},
      ListQ[ps] && ps =!= {} && Extract[tree, ps] === cs && DuplicateFreeQ[ps] &&
        MaximilienTirard`HTMLPatterns`PackageScope`documentOrdering[ps] === Range[Length[ps]]],
    30, "time"], 2*^9, "memory"];

(* The queries that select something on each input form. *)
agreeingOn[qs_] := AllTrue[qs, agreesQ[$positionsDoc, #] && agreesQ[$positionsRoot, #] && agreesQ[$positionsList, #] &];

(* === Plain queries === *)

TestCreate[
  agreeingOn[{
    XMLPattern["li"],
    XMLPattern["li", "classList" -> {___, "a", ___}],
    XMLPattern["a", {"href" -> h_, "data-id" -> i_}] /; StringContainsQ[h, i],
    XMLPattern["li"]?(MemberQ[#[[3]], "y"] &),
    XMLElement["li", _, _],
    "li"}],
  True,
  TestID -> "positions-plain-patterns"
];

(* A rule's body gives values, not sites, so the positions are those of its
   left-hand side, less those a Condition in the body rejects. *)
TestCreate[
  agreeingOn[{
    e : XMLPattern["li"] :> e,
    e : XMLPattern["li"] :> e /; True,
    e : XMLPattern["li"] :> e /; MemberQ[e[[3]], "y"]}],
  True,
  TestID -> "positions-plain-rules"
];

TestCreate[
  positionsOf[$positionsDoc, e : XMLPattern["li"] :> e /; MemberQ[e[[3]], "y"]],
  {{2, 3, 1, 3, 1, 3, 1, 3, 3}},
  TestID -> "positions-plain-rejecting-body"
];

(* === Chains === *)

TestCreate[
  agreeingOn[{
    Child["ul", "li"],
    Descendant[XMLPattern["div"], XMLPattern["li"]],
    Adjacent["h2", "p"],
    Sibling["h2", "p"],
    "li:first-child",
    "div p > a",
    Child["ul", x : XMLPattern["li"]] /; True}],
  True,
  TestID -> "positions-chains"
];

(* List stages, on WL's matcher and by a recognised shape (ADR 0020), and a
   list stage with a context entry. *)
SetAttributes[unrecognised, HoldFirst];
unrecognised[expr_] := Block[{MaximilienTirard`HTMLPatterns`PackageScope`$recogniseShapes = False}, expr];

$listStageQueries = {
  "li:nth-child(2n+1)",
  "li:nth-of-type(2)",
  "li:last-child",
  Child[XMLDocument[] | XMLPattern[_], {___, x : XMLPattern["li"], ___} /; True],
  Child[XMLPattern["ul"], {___, XMLPattern["li", "classList" -> "a"], ___}],
  Child[XMLPattern["div"], {___, Child["p", "a"], ___, x : XMLPattern["p"], ___}]};

TestCreate[
  agreeingOn[$listStageQueries],
  True,
  TestID -> "positions-list-stages"
];

TestCreate[
  unrecognised @ agreeingOn[$listStageQueries],
  True,
  TestID -> "positions-list-stages-unrecognised"
];

(* XMLDocument[] is the site of a document, never a result: on a bare root
   the root is the input, and is not selected. *)
TestCreate[
  {positionsOf[$positionsDoc, ":root"], positionsOf[$positionsDoc, Child[XMLDocument[], XMLPattern["html"]]],
   positionsOf[$positionsRoot, ":root"]},
  {{{2}}, {{2}}, {}},
  TestID -> "positions-xmldocument"
];

(* A Condition in the body can reject a tuple, and the tuples it accepts give
   the sites. *)
TestCreate[
  agreeingOn[{
    Descendant[d : XMLPattern["div"], e : XMLPattern["li"]] :> e /; True,
    Descendant[d : XMLPattern["div"], e : XMLPattern["li"]] :> e /; MemberQ[e[[3]], "y"],
    Child[u : XMLPattern["ul"], e : XMLPattern["li"]] :> e}],
  True,
  TestID -> "positions-chain-rules"
];

(* A value of Nothing is no element, but its site is selected. *)
TestCreate[
  Length /@ {positionsOf[$positionsDoc, Child["ul", e : XMLPattern["li"]] :> Nothing /; True],
    XMLCases[$positionsDoc, Child["ul", e : XMLPattern["li"]] :> Nothing /; True]},
  {5, 0},
  TestID -> "positions-chain-no-value"
];

TestCreate[
  positionsOf[$positionsDoc, Descendant[d : XMLPattern["div"], e : XMLPattern["li"]] :> e /; MemberQ[e[[3]], "y"]],
  {{2, 3, 1, 3, 1, 3, 1, 3, 3}},
  TestID -> "positions-chain-rejecting-body"
];

(* === Alternatives of combinators (ADR 0015) === *)

TestCreate[
  agreeingOn[{
    "ul > li, p",
    Child[XMLPattern["ul"], XMLPattern["li"]] | XMLPattern["p"],
    Adjacent["h2", "p"] | Child["ul", "li:first-child"],
    (Child["ul", e : XMLPattern["li"]] | Child["div", e : XMLPattern["p"]]) :> e /; !MemberQ[e[[3]], "x"]}],
  True,
  TestID -> "positions-alternatives"
];

(* A rule's values are not the elements at its sites: its sites are those of
   its left-hand side that it gives a value for. *)
TestCreate[
  With[{q = Child["ul", e : XMLPattern["li"]] | XMLPattern["p"]},
    {positionsOf[$positionsDoc, q :> 1 /; True] === positionsOf[$positionsDoc, q],
     Length[positionsOf[$positionsDoc, q :> 1 /; True]], Length[XMLCases[$positionsDoc, q :> 1 /; True]]}],
  {True, 8, 8},
  TestID -> "positions-alternatives-values"
];

(* === List keys (ADR 0012) and two-step patterns === *)

(* Materialising a list key moves no element, so the sites in the
   materialised tree are sites in the input. *)
TestCreate[
  agreeingOn[{
    Child[XMLPattern["div", "classList" -> {___, "b", ___}], XMLPattern["ul"]],
    Child["ul", XMLPattern["li", "classList" -> {"a"}]] | XMLPattern["p"],
    Child["p", XMLPattern["a", {"href" -> h_, "data-id" -> i_}] /; StringContainsQ[h, i]],
    Descendant[XMLPattern["div", "classList" -> c_], XMLPattern["li", "classList" -> c2_]] /; SubsetQ[c, c2]}],
  True,
  TestID -> "positions-list-keys-two-step"
];

(* === The count === *)

TestCreate[
  AllTrue[{
    {XMLPattern["li"], 2},
    {e : XMLPattern["li"] :> e /; True, 1},
    {Descendant[XMLPattern["div"], XMLPattern["li"]], 2},
    {Child["ul", e : XMLPattern["li"]] :> e /; True, 4},
    {"ul > li, p", 3},
    {(Child["ul", e : XMLPattern["li"]] | Child["div", e : XMLPattern["p"]]) :> e /; !MemberQ[e[[3]], "x"], 2}},
    agreesQ[$positionsDoc, Sequence @@ #] &],
  True,
  TestID -> "positions-count"
];

TestCreate[
  positionsOf[$positionsDoc, "li", 0],
  {},
  TestID -> "positions-count-zero"
];

(* === Sites, not elements === *)

(* Two equal li: the first child is one site. Looking its element up gives
   both. *)
$equalSiblings = ImportString["<ul><li>a</li><li>a</li></ul>", {"HTML", "XMLObject"}];

TestCreate[
  positionsOf[$equalSiblings, "li:first-child"],
  {{2, 3, 1, 3, 1, 3, 1}},
  TestID -> "positions-equal-siblings"
];

TestCreate[
  {positionsOf[$equalSiblings, Adjacent["li", "li"]], positionsOf[$equalSiblings, "li:nth-child(2)"],
   positionsOf[$equalSiblings, "li"]},
  {{{2, 3, 1, 3, 1, 3, 2}}, {{2, 3, 1, 3, 1, 3, 2}}, {{2, 3, 1, 3, 1, 3, 1}, {2, 3, 1, 3, 1, 3, 2}}},
  TestID -> "positions-equal-siblings-sites"
];

(* Random trees widen the comparison: every query is checked on every tree
   that it selects something on, and selects something on some. *)
$positionsTrees = randomTrees[20261023, 12];

TestCreate[
  AllTrue[{
    XMLPattern["p", "classList" -> {___, "a", ___}],
    Child[XMLPattern["div"], {___, XMLPattern["li"], ___, XMLPattern["span"], ___}],
    Descendant["div", "span"] | Adjacent["p", "li"],
    Sibling[XMLPattern[_, "classList" -> {___, "b", ___}], XMLPattern["p"]]},
    Function[q, With[{ts = Select[$positionsTrees, XMLCases[#, q] =!= {} &]}, ts =!= {} && AllTrue[ts, agreesQ[#, q] &]]]],
  True,
  TestID -> "positions-random-trees"
];

(* === Refusals === *)

TestCreate[
  positionsOf["<p>", "p"],
  $Failed,
  {XMLCases::badtree},
  TestID -> "positions-refused-tree"
];
