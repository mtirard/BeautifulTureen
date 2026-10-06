(* Recognised shapes (ADR 0020): each is a performance guarantee, with a test
   here whose ID ADR 0020 lists beside the shape. The bounds are generous, to
   catch a shape that is no longer recognised, not to benchmark. *)

(* 10,000 sibling li, one in four of class a. *)
$tenThousand = XMLElement["body", {}, {XMLElement["ul", {},
  Table[XMLElement["li", If[Mod[i, 4] == 0, {"class" -> "a"}, {}], {"x"}], {i, 10000}]]}];

(* Shape 1, anywhere. Measured at about 28 ms on a 2026 laptop, against about
   450 ms on the general matcher, which builds the sequence before each
   child. *)
TestCreate[
  Length @ XMLCases[$tenThousand, Child[XMLPattern["ul"], {___, XMLPattern["li", "classList" -> "a"], ___}]],
  2500,
  TimeConstraint -> 0.2,
  TestID -> "perf-shape-anywhere-10000-siblings"
];

(* 5,000 sibling li in one list. *)
$fiveThousand = XMLElement["body", {}, {XMLElement["ul", {}, Table[XMLElement["li", {}, {"x"}], 5000]]}];

(* Shapes 2 and 3, a position among all children from the start and from the
   end. Each measured at about 20 ms on a 2026 laptop, against about 450 ms on
   the general matcher, which tries every split of the list. The fixed
   positions, such as :nth-last-child(3), cost the general matcher about 60 ms
   here, too little for a generous bound to tell apart. *)
TestCreate[
  Length @ XMLCases[$fiveThousand, "li:nth-child(2n+1)"],
  2500,
  TimeConstraint -> 0.15,
  TestID -> "perf-shape-from-start-5000-siblings"
];

TestCreate[
  Length @ XMLCases[$fiveThousand, "li:nth-last-child(2n+1)"],
  2500,
  TimeConstraint -> 0.15,
  TestID -> "perf-shape-from-end-5000-siblings"
];

(* 1,000 sibling tr, two in three of class a. *)
$thousandRows = XMLElement["table", {}, {XMLElement["tbody", {},
  Table[XMLElement["tr", If[Mod[i, 3] != 0, {"class" -> "a"}, {}], {"x"}], {i, 1000}]]}];

(* Shape 4, a position from the start among the children that match S.
   Measured at about 12 ms on a 2026 laptop, against about 8.3 s as a
   Count in a condition on the list, as it was translated before, and more
   than 60 s on the general matcher. *)
TestCreate[
  Length @ XMLCases[$thousandRows, "tr:nth-child(2n+1 of .a)"],
  334,
  TimeConstraint -> 0.2,
  TestID -> "perf-shape-counted-from-start-1000-siblings"
];

(* 5,000 siblings, li and p in turn. *)
$fiveThousandMixed = XMLElement["body", {}, {XMLElement["ul", {},
  Table[XMLElement[If[OddQ[i], "li", "p"], {}, {"x"}], {i, 5000}]]}];

(* Shape 5, a position from the end among the children of a type. Measured
   at about 18 ms on a 2026 laptop, against about 440 ms as a Count in a
   condition on the list, and more than 60 s on the general matcher. *)
TestCreate[
  Length @ XMLCases[$fiveThousandMixed, "li:nth-last-of-type(2)"],
  1,
  TimeConstraint -> 0.2,
  TestID -> "perf-shape-counted-from-end-5000-siblings"
];

(* 5,000 siblings, h2, p and div in turn. *)
$fiveThousandSections = XMLElement["body", {}, {XMLElement["section", {},
  Table[XMLElement[{"h2", "p", "div"}[[Mod[i - 1, 3] + 1]], {}, {"x"}], {i, 5000}]]}];

(* Shape 6, ordered element-pattern entries: each p after the first h2.
   Measured at about 10 ms on a 2026 laptop, against about 1.2 s at 1,000
   siblings and 9.9 s at 2,000 on the general matcher. *)
TestCreate[
  Length @ XMLCases[$fiveThousandSections, Child[XMLPattern["section"], {___, XMLPattern["h2"], ___, XMLPattern["p"], ___}]],
  1667,
  TimeConstraint -> 0.2,
  TestID -> "perf-shape-ordered-5000-siblings"
];

(* A rule body using the selected entry's name binds it from the selected
   child, so it costs about what the query without a body does. Each test is
   bounded in memory too: matching such a list again on WL's matcher, as the
   body did before, grows about as the cube of the number of siblings, and a
   time limit does not stop it. Before, the body with ordered entries took
   0.26 s at 200 siblings and more than 30 s at 1,000, and with a position
   among all children 1.1 s at 1,000. *)
TestCreate[
  MemoryConstrained[
    Length @ XMLCases[$fiveThousandSections, Child[XMLPattern["section"], {___, XMLPattern["h2"], ___, c : XMLPattern["p"], ___}] :> c[[1]]],
    2*^9, $Failed],
  1667,
  TimeConstraint -> 0.3,
  TestID -> "perf-shape-ordered-body-5000-siblings"
];

TestCreate[
  MemoryConstrained[
    Length @ XMLCases[$fiveThousandSections, Child[XMLPattern["section"], {_, PatternSequence[_, _, _]..., c : XMLPattern["p"], ___}] :> c[[1]] /; True],
    2*^9, $Failed],
  1667,
  TimeConstraint -> 0.3,
  TestID -> "perf-shape-from-start-body-5000-siblings"
];
