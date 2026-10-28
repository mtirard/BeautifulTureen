(* A contents-list entry with a constraint of its own, the context of the
   entry after it: each is tested once per child. The bounds catch quadratic
   behaviour, such as the constraint run over the whole tree for each child,
   not a benchmark. *)

(* 3,000 sibling div, one in seven of class c3, one in five with a p child. *)
$threeThousand = XMLElement["body", {}, Table[
  XMLElement["div", {"class" -> "c" <> ToString[Mod[i, 7]]}, If[Mod[i, 5] == 0, {XMLElement["p", {}, {"x"}]}, {"t"}]],
  {i, 3000}]];

(* The CSS translations, where the context entry is a nested constraint,
   div:has(> p). Measured at about 98 ms and 95 ms on a 2026 laptop, against
   31 ms and 32 ms in 3.0.0. *)
TestCreate[
  Length @ XMLCases[$threeThousand, "body > div:has(> p) + div.c3"],
  85,
  TimeConstraint -> 0.3,
  TestID -> "perf-tree-context-entry-3000-siblings"
];

TestCreate[
  Length @ XMLCases[$threeThousand, "body > div:has(> p) ~ div.c3"],
  428,
  TimeConstraint -> 0.3,
  TestID -> "perf-tree-ordered-context-entry-3000-siblings"
];
