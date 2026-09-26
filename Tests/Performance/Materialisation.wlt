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
   tree, as an unnested combinator does. Measured at about 17 ms here. *)
TestCreate[
  Length @ XMLCases[$big,
    Descendant[XMLPattern["html"], Child[XMLPattern["body"], XMLPattern["div", "classList" -> "c3"]]]],
  714,
  TimeConstraint -> 0.5,
  TestID -> "perf-classlist-nested-chain-5000-elements"
];

(* Every combinator runs as a chain. A sibling relation reads each site's next
   sibling from a table built once per list of siblings: scanning the list per
   site is quadratic in these 5000 siblings. Measured at about 12 ms, against
   about 6 ms before combinators shared one path. *)
TestCreate[
  Length @ XMLCases[$big, Adjacent[XMLPattern["div"], XMLPattern["div", "class" -> "c3 lead"]]],
  714,
  TimeConstraint -> 0.5,
  TestID -> "perf-adjacent-5000-siblings"
];

(* Sibling starts, within each list of siblings, from the first site its earlier
   stage selects: pairing every earlier site with every later one is quadratic
   in these 5000 siblings. Measured at about 15 ms. *)
TestCreate[
  Length @ XMLCases[$big, Sibling[XMLPattern["div"], XMLPattern["div", "class" -> "c3 lead"]]],
  714,
  TimeConstraint -> 0.5,
  TestID -> "perf-sibling-5000-siblings"
];

(* Descendant gives each element once. When the stages' own matches decide, it
   searches below the outermost matching ancestors only: searching below every
   matching ancestor costs the depth times the elements, here 127 500 pairs from
   50 nested divs of 100 p each. Measured at about 18 ms, against about 600 ms
   searching below every ancestor. *)
$deep = XMLObject["Document"][{},
  XMLElement["body", {}, {Nest[XMLElement["div", {}, Append[Table[XMLElement["p", {}, {"x"}], 100], #]] &,
    XMLElement["div", {}, {}], 50]}], {}];

TestCreate[
  Length @ XMLCases[$deep, Descendant[XMLPattern["div"], XMLPattern["p"]]],
  5000,
  TimeConstraint -> 0.5,
  TestID -> "perf-descendant-50-deep"
];
