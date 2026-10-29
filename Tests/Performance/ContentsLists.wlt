(* Contents lists over many siblings. A CSS string runs as its translation, a
   tree pattern. Times are the least of three runs on a 2026 laptop under the
   load of other work: 3.0.0's, which ran these on recognised shapes (ADR
   0020), then the tree engine's. The bounds are about three times the tree
   engine's time, to catch a walk that has become quadratic, not to
   benchmark. The test IDs keep the shape names of 3.0.0. *)

(* 10,000 sibling li, one in four of class a. *)
$tenThousand = XMLElement["body", {}, {XMLElement["ul", {},
  Table[XMLElement["li", If[Mod[i, 4] == 0, {"class" -> "a"}, {}], {"x"}], {i, 10000}]]}];

(* Anywhere among the children: 25 ms, 50 ms. *)
TestCreate[
  Length @ XMLCases[$tenThousand, "ul > li.a"],
  2500,
  TimeConstraint -> 0.15,
  TestID -> "perf-tree-anywhere-10000-siblings"
];

(* 5,000 sibling li in one list. *)
$fiveThousand = XMLElement["body", {}, {XMLElement["ul", {}, Table[XMLElement["li", {}, {"x"}], 5000]]}];

(* A position among all children from the start and from the end, a repeat
   of fixed-length blank groups, which moves by whole blocks: 20 ms, 45 ms
   each. Stepping one repeat at a time took 270 ms. *)
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

(* A position from the start among the children that match S: 10 ms, 65 ms,
   a repeat of two units of S, Except[S] ..., stepped once per pair of a's. *)
TestCreate[
  Length @ XMLCases[$thousandRows, "tr:nth-child(2n+1 of .a)"],
  334,
  TimeConstraint -> 0.2,
  TestID -> "perf-shape-counted-from-start-1000-siblings"
];

(* 5,000 siblings, li and p in turn. *)
$fiveThousandMixed = XMLElement["body", {}, {XMLElement["ul", {},
  Table[XMLElement[If[OddQ[i], "li", "p"], {}, {"x"}], {i, 5000}]]}];

(* A position from the end among the children of a type: 20 ms, 17 ms. *)
TestCreate[
  Length @ XMLCases[$fiveThousandMixed, "li:nth-last-of-type(2)"],
  1,
  TimeConstraint -> 0.1,
  TestID -> "perf-shape-counted-from-end-5000-siblings"
];

(* 5,000 siblings, h2, p and div in turn. *)
$fiveThousandSections = XMLElement["body", {}, {XMLElement["section", {},
  Table[XMLElement[{"h2", "p", "div"}[[Mod[i - 1, 3] + 1]], {}, {"x"}], {i, 5000}]]}];

(* Ordered entries, each p after the first h2: 10 ms (240 ms as the CSS
   string), 27 ms. *)
TestCreate[
  Length @ XMLCases[$fiveThousandSections, "section > h2 ~ p"],
  1667,
  TimeConstraint -> 0.1,
  TestID -> "perf-tree-ordered-5000-siblings"
];

(* A rule body using the entry's name binds it from the matched child, so
   it costs about what the query without a body does. Each test is bounded in
   memory too: matching such a list again on WL's matcher grows about as the
   cube of the number of siblings, and a time limit does not stop it. 10 ms,
   55 ms. *)
TestCreate[
  MemoryConstrained[
    Length @ XMLCases[$fiveThousandSections, XMLPattern["section", _, {___, XMLPattern["h2"], ___, c : XMLPattern["p"], ___}] :> c[[1]]],
    2*^9, $Failed],
  1667,
  TimeConstraint -> 0.2,
  TestID -> "perf-tree-ordered-body-5000-siblings"
];

(* With a Condition in the body: 15 ms, 53 ms. *)
TestCreate[
  MemoryConstrained[
    Length @ XMLCases[$fiveThousandSections, XMLPattern["section", _, {_, PatternSequence[_, _, _]..., c : XMLPattern["p"], ___}] :> c[[1]] /; True],
    2*^9, $Failed],
  1667,
  TimeConstraint -> 0.2,
  TestID -> "perf-tree-from-start-body-5000-siblings"
];

(* 5,000 siblings, li and p in turn, one in three of class x. *)
$fiveThousandClassed = XMLElement["body", {}, {XMLElement["ul", {},
  Table[XMLElement[If[OddQ[i], "li", "p"], If[Mod[i, 3] == 0, {"class" -> "x"}, {}], {"x"}], {i, 5000}]]}];

(* Counted positions, each a plain contents list. -of-type on a compound
   with no type shares a tag name into Except, and the list is walked once
   for each distinct tag among the siblings, with the name bound: 35 ms,
   44 ms for .x:nth-of-type(2); 26 ms, 45 ms for :nth-last-of-type(2), which
   took 6.4 s with an Except recording each child's tag, growing as the square
   of the siblings. *)
TestCreate[
  MemoryConstrained[Length @ XMLCases[$fiveThousandClassed, ".x:nth-of-type(2)"], 2*^9, $Failed],
  1,
  TimeConstraint -> 0.15,
  TestID -> "perf-shape-split-of-type-5000-siblings"
];

TestCreate[
  MemoryConstrained[Length @ XMLCases[$fiveThousandClassed, ":nth-last-of-type(2)"], 2*^9, $Failed],
  2,
  TimeConstraint -> 0.15,
  TestID -> "perf-shape-split-last-of-type-5000-siblings"
];

(* 44 ms, 23 ms. *)
TestCreate[
  MemoryConstrained[Length @ XMLCases[$fiveThousandClassed, "p + li:nth-of-type(2)"], 2*^9, $Failed],
  1,
  TimeConstraint -> 0.1,
  TestID -> "perf-shape-split-adjacent-5000-siblings"
];

$fiveThousandIds = Replace[$fiveThousandClassed, XMLElement[t_, a_, c_] :> XMLElement[t, Append[a, "id" -> "i"], c], {4}];

(* The entry naming two attribute values, at a counted position: the list
   FromCSSSelector writes, the tag name shared into Except, 45 ms against 11 ms
   in 3.0.0. A Condition over the run instead tests each split of the list and
   takes 2.2 s; the translations write none but for two An+B positions on one
   compound. *)
TestCreate[
  MemoryConstrained[TimeConstrained[
    XMLCases[$fiveThousandIds,
      XMLPattern["ul", _, {Except[XMLPattern[t_]]..., XMLPattern[t_], Except[XMLPattern[t_]]..., c : XMLPattern[t_, {"class" -> k_, "id" -> i_}], ___}] :> First[c]],
    5, $Failed], 2*^9, $Failed],
  {"li"},
  TimeConstraint -> 0.15,
  TestID -> "perf-tree-of-type-two-names-5000-siblings"
];

(* The other counted positions 3.0.0 wrote as a split condition, with its
   time, then the tree engine's. Each is linear: *:first-of-type
   took 1.6 s and .x:nth-of-type(2) + p 1.9 s with recorded Excepts, and
   p ~ li:nth-child(3) 3.8 s and p + li + p:nth-of-type(2) 4.0 s as a
   Condition over the run before the subject, now a prefix of two and a plain
   list. *)
$splitForms = {
  {"*:first-of-type", 3},                       (* 24 ms, 32 ms *)
  {":nth-child(1 of .x):nth-child(3)", 1},      (* 112 ms, 11 ms *)
  {"p:nth-of-type(2):nth-child(4)", 1},         (* 25 ms, 10 ms *)
  {"p ~ li:nth-child(3)", 1},                   (* 40 ms, 10 ms *)
  {"p + li + p:nth-of-type(2)", 1},             (* 59 ms, 20 ms *)
  {"li:nth-of-type(2) + p", 1},                 (* 23 ms, 23 ms *)
  {"li:nth-last-of-type(2) + p", 1},            (* 24 ms, 23 ms *)
  {".x:nth-of-type(2) + p", 1}};                (* 36 ms, 46 ms *)

Function[{css, n, id}, TestCreate[
  MemoryConstrained[Length @ XMLCases[$fiveThousandClassed, css], 2*^9, $Failed],
  n,
  TimeConstraint -> 0.15,
  TestID -> id]] @@@ MapIndexed[Append[#1, "perf-shape-split-form-" <> ToString[First[#2]] <> "-5000-siblings"] &, $splitForms];

(* A counted position before ~ (issue #40), on 5,000 siblings: a, b, p, a.x,
   p, b, then a, b and p chosen at random, so that the second a, of class x,
   is fourth and every b after it is selected. Over 60 s each in 3.0.0 with
   a, b and p at random and three in ten of class x; on the tree engine
   0.26 s and 46 ms there. *)
SeedRandom[40];
$randomRest = Table[XMLElement[RandomChoice[{"a", "b", "p"}], {}, {"x"}], 4994];
$fiveThousandRandom = XMLElement["body", {}, {XMLElement["section", {}, Join[
  {XMLElement["a", {}, {"x"}], XMLElement["b", {}, {"x"}], XMLElement["p", {}, {"x"}],
   XMLElement["a", {"class" -> "x"}, {"x"}], XMLElement["p", {}, {"x"}], XMLElement["b", {}, {"x"}]},
  $randomRest]]}];

TestCreate[
  MemoryConstrained[Length @ XMLCases[$fiveThousandRandom, ".x:nth-of-type(2) ~ b"], 2*^9, $Failed],
  Count[$randomRest, XMLElement["b", _, _]] + 1,
  TimeConstraint -> 0.8,
  TestID -> "perf-tree-of-type-before-sibling-5000-siblings"
];

TestCreate[
  MemoryConstrained[Length @ XMLCases[$fiveThousandRandom, "a:nth-of-type(2) ~ b"], 2*^9, $Failed],
  Count[$randomRest, XMLElement["b", _, _]] + 1,
  TimeConstraint -> 0.25,
  TestID -> "perf-tree-typed-before-sibling-5000-siblings"
];
