(* Context entries are compiled once (ADR 0020): each is a chain of its own in
   the compiled query, run from each child at most once, and a run builds no
   chain, tuple test or two-step match for it (Tests/Unit/CompiledQuery.wlt
   counts that). The bound is generous, to catch a context entry run from more
   than its child, or more than once per child, not to benchmark. *)

(* 3,000 sibling div, one in seven of class c3, one in five with a p child. *)
$threeThousand = XMLElement["body", {}, Table[
  XMLElement["div", {"class" -> "c" <> ToString[Mod[i, 7]]}, If[Mod[i, 5] == 0, {XMLElement["p", {}, {"x"}]}, {"t"}]],
  {i, 3000}]];

(* The context entry is next to the selected entry, so the general matcher
   tries one split per c3 and the time goes to the context entry. Measured at
   about 70 ms on a 2026 laptop. The same list with ___ between the two,
   {___, Child["div", "p"], ___, "div.c3", ___}, takes about 39 s: ReplaceList
   enumerates every split of the list, about as fast with the context entry
   replaced by True, and a list stage with a context entry is no recognised
   shape. *)
TestCreate[
  Length @ XMLCases[$threeThousand, Child["body", {___, Child["div", "p"], "div.c3", ___}]],
  85,
  TimeConstraint -> 1,
  TestID -> "perf-context-entry-3000-siblings"
];
