(* Names in the tag and attributes of a pattern root with no constraints.
   What they bind is read for all the elements at once, from their tags and
   attributes and the token lists split from them. Times on a 2026 laptop,
   the least of three runs, are given at each test, against
   HTMLClassList /@ XMLCases[$ps, XMLPattern["p"]] at about 17 ms. The bounds
   are generous, to catch a return to matching each element, not to
   benchmark. *)

$ps = ImportString[
  "<div>" <> StringJoin @ Table[
    "<p class='a b c" <> ToString[Mod[i, 12]] <> "' id='i" <> ToString[i] <> "'>t</p>",
    {i, 2500}] <> "</div>",
  {"HTML", "XMLObject"}];

(* 42 ms; 266 ms matching each element. *)
TestCreate[
  Length @ XMLCases[$ps, XMLPattern["p", "classList" -> c_] :> c],
  2500,
  TimeConstraint -> 0.08,
  TestID -> "perf-head-classlist-name-2500-elements"
];

(* 40 ms; 104 ms. *)
TestCreate[
  Length @ XMLCases[$ps, XMLPattern["p", "class" -> c_] :> c],
  2500,
  TimeConstraint -> 0.08,
  TestID -> "perf-head-class-name-2500-elements"
];

(* The token names of 2500 elements, 3 each: 88 ms; 773 ms. *)
TestCreate[
  Length @ XMLCases[$ps, XMLPattern["p", "classList" -> {___, c_, ___}] :> c],
  7500,
  TimeConstraint -> 0.15,
  TestID -> "perf-head-token-names-2500-elements"
];
