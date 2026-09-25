(* Materialisation cost (ADR 0012). A query naming a list key materialises the
   tree once, splitting only the distinct raw values: a page has a handful of
   distinct class strings across thousands of elements. Measured at about 20 ms
   for this query on a 2026 laptop, against about 4 ms for a raw-key query; the
   bounds are generous, to catch a per-element split or a repeated
   materialisation, not to benchmark. *)

$big = ImportString[
  "<body>" <> StringJoin @ Table[
    "<div class='c" <> ToString[Mod[i, 7]] <> " lead' id='i" <> ToString[i] <> "'>x</div>",
    {i, 5000}] <> "</body>",
  {"HTML", "XMLObject"}];

TestCreate[
  Length @ XMLCases[$big, XMLPattern["div", "classList" -> "c3"]],
  714,
  TimeConstraint -> 0.5,
  TestID -> "perf-classlist-query-5000-elements"
];

(* Combinator stages share one materialisation. *)
TestCreate[
  Length @ XMLCases[$big,
    Child[XMLPattern["body", "classList" -> {}], XMLPattern["div", "classList" -> {___, "lead"}]]],
  5000,
  TimeConstraint -> 0.5,
  TestID -> "perf-classlist-combinator-5000-elements"
];

(* Deletion strips the whole tree. *)
TestCreate[
  Length @ XMLCases[XMLDeleteCases[$big, XMLPattern["div", "classList" -> "c3"]], XMLPattern["div"]],
  4286,
  TimeConstraint -> 0.5,
  TestID -> "perf-classlist-delete-5000-elements"
];

(* A chain (a combinator as a stage) runs on positions in the one materialised
   tree. Measured at about 30 ms here, against about 15 ms unnested. *)
TestCreate[
  Length @ XMLCases[$big,
    Descendant[XMLPattern["html"], Child[XMLPattern["body"], XMLPattern["div", "classList" -> "c3"]]]],
  714,
  TimeConstraint -> 0.5,
  TestID -> "perf-classlist-nested-chain-5000-elements"
];
