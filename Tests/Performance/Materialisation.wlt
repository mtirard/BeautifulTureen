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

(* A condition on several attribute names is matched in two steps: a skeleton
   with no names finds the candidates, and each candidate is matched with
   plain list patterns. {OrderlessPatternSequence[rules..., ___]}, which also
   binds every name, costs the factorial of the attribute count: about 18 s
   here at six rules, against about 60 ms. *)
$wide = XMLElement["div", {}, Table[
  XMLElement["a", Join[
    {"href" -> "/p/" <> ToString[i], "class" -> "c", "id" -> "n" <> ToString[i],
     "rel" -> "next", "name" -> "f", "type" -> "text"},
    Take[{"title" -> "v", "lang" -> "v", "role" -> "v", "target" -> "v"}, Mod[i, 5]]], {"t"}],
  {i, 5000}]];

TestCreate[
  Length @ XMLCases[$wide,
    XMLPattern["a", {"href" -> h_, "class" -> _, "id" -> i_, "rel" -> _, "name" -> _, "type" -> t_}] /;
      StringEndsQ[i, "7"] && StringQ[h] && StringQ[t]],
  500,
  TimeConstraint -> 0.5,
  TestID -> "perf-condition-on-six-attribute-names"
];

(* A "Roles" or "Constructs" rule naming a list key splits each distinct raw
   value on the tree once, not once for each element a rule is tried on:
   HTMLToNotebook asks for an element's role up to three times. Here every
   element carries one of seven class values of a thousand tokens each.
   Measured at about 120 ms and 290 ms on a 2026 laptop; splitting per element
   measured about 350 ms and 1.1 s. The bounds are about twice the first, so
   they are tighter than the others in this file. *)
$longClasses = ImportString[
  "<body>" <> StringJoin @ Table[
    "<div class=\"" <> StringRiffle[Table["t" <> ToString[k], {k, 1000}]] <>
      " c" <> ToString[Mod[i, 7]] <> "\">x</div>",
    {i, 2000}] <> "</body>",
  {"HTML", "XMLObject"}];

TestCreate[
  StringLength @ HTMLInnerText[$longClasses,
    "Roles" -> {XMLPattern["div", "classList" -> "c3"] -> "Skip", XMLPattern[_, "classList" -> "hidden"] -> "Inline"}],
  3427,
  TimeConstraint -> 0.25,
  TestID -> "perf-innertext-classlist-roles"
];

TestCreate[
  Length @ First @ HTMLToNotebook[$longClasses,
    "Roles" -> {XMLPattern["div", "classList" -> "c3"] -> "Skip", XMLPattern[_, "classList" -> "hidden"] -> "Inline"},
    "Constructs" -> {XMLPattern["div", "classList" -> "c2"] -> "Section", XMLPattern[_, "classList" -> "c1"] -> "Bold"}],
  1714,
  TimeConstraint -> 0.6,
  TestID -> "perf-tonotebook-classlist-rules"
];

(* XMLMatchQ[pattern] compiles its query once, not once for each element it
   is applied to (issue #2). Measured at about 60 ms on a 2026 laptop, against
   about 0.6 s compiling once per element. *)
$ps = XMLCases[$big, XMLPattern["div"]];

TestCreate[
  Length @ Select[$ps, XMLMatchQ[XMLPattern["div", "classList" -> "c3"]]],
  714,
  TimeConstraint -> 0.2,
  TestID -> "perf-xmlmatchq-operator-5000-elements"
];
