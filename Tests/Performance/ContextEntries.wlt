(* Context entries are compiled once (ADR 0020): each is a chain of its own in
   the compiled query, run from each child at most once, and a run builds no
   chain, tuple test or two-step match for it (Tests/Unit/CompiledQuery.wlt
   counts that). The bound is generous, to catch quadratic behaviour, such as a
   context entry run over the whole tree for each child, not to benchmark. *)

(* 3,000 sibling div, one in seven of class c3, one in five with a p child. *)
$threeThousand = XMLElement["body", {}, Table[
  XMLElement["div", {"class" -> "c" <> ToString[Mod[i, 7]]}, If[Mod[i, 5] == 0, {XMLElement["p", {}, {"x"}]}, {"t"}]],
  {i, 3000}]];

(* The context entry is next to the selected entry. The list is recognised
   shape 6 and measured at about 78 ms on a 2026 laptop, most of it in the
   context entry; on the general matcher, which tries one split per c3, it
   took about 70 ms. *)
TestCreate[
  Length @ XMLCases[$threeThousand, Child["body", {___, Child["div", "p"], "div.c3", ___}]],
  85,
  TimeConstraint -> 1,
  TestID -> "perf-context-entry-3000-siblings"
];

(* The same list with ___ between the two entries: shape 6, ordered entries,
   with a context combinator entry. Measured at about 78 ms on a 2026 laptop,
   against about 39 s on the general matcher, which enumerates every split of
   the list that places the two entries, and whose memory grows as fast. *)
TestCreate[
  Length @ XMLCases[$threeThousand, Child["body", {___, Child["div", "p"], ___, "div.c3", ___}]],
  428,
  TimeConstraint -> 1,
  TestID -> "perf-shape-ordered-context-entry-3000-siblings"
];
