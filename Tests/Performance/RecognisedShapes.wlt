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
