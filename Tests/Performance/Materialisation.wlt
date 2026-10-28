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

(* Elements and their children share one materialisation: 19 ms in 3.0.0,
   71 ms. *)
TestCreate[
  Length @ XMLCases[$big,
    XMLPattern["body", "classList" -> {}, {___, n : XMLPattern["div", "classList" -> {___, "lead"}], ___}] :> n],
  5000,
  TimeConstraint -> 0.25,
  TestID -> "perf-tree-classlist-list-5000-elements"
];

(* Deletion strips the whole tree. 19 ms in 3.0.0; 79 ms on the tree
   engine, which deletes the elements it targets with Delete, and took 143 ms
   rewriting each through the opened nodes. *)
TestCreate[
  Length @ XMLCases[XMLDeleteCases[$big, XMLPattern["div", "classList" -> "c3"]], XMLPattern["div"]],
  4286,
  TimeConstraint -> 0.3,
  TestID -> "perf-classlist-delete-5000-elements"
];

(* A contents list below a Descendant: 18 ms in 3.0.0, 40 ms. *)
TestCreate[
  Length @ XMLCases[$big, "html body > div.c3"],
  714,
  TimeConstraint -> 0.15,
  TestID -> "perf-tree-classlist-nested-5000-elements"
];

(* A sibling relation is a contents list, walked once over the 5000
   siblings: 18 ms in 3.0.0, 37 ms. *)
TestCreate[
  Length @ XMLCases[$big, "div + div[class='c3 lead']"],
  714,
  TimeConstraint -> 0.15,
  TestID -> "perf-tree-adjacent-5000-siblings"
];

(* A contents list with a ___ gap: 18 ms in 3.0.0, 40 ms. *)
TestCreate[
  Length @ XMLCases[$big, "div ~ div[class='c3 lead']"],
  714,
  TimeConstraint -> 0.15,
  TestID -> "perf-tree-sibling-5000-siblings"
];

(* Descendant gives each element once: searching below every matching
   ancestor costs the depth times the elements, here 127 500 pairs from 50
   nested divs of 100 p each. *)
$deep = XMLObject["Document"][{},
  XMLElement["body", {}, {Nest[XMLElement["div", {}, Append[Table[XMLElement["p", {}, {"x"}], 100], #]] &,
    XMLElement["div", {}, {}], 50]}], {}];

(* As XMLPattern["div", _, Descendant[n : XMLPattern["p"]]]: only the
   outermost matching div is searched below, as a pattern root whose every
   constraint is a Descendant has a subset of its solutions at an element
   inside another it matches. 18 ms in 3.0.0, 143 ms; 3.2 s searching below
   every div. *)
TestCreate[
  Length @ XMLCases[$deep, "div p"],
  5000,
  TimeConstraint -> 0.4,
  TestID -> "perf-tree-descendant-50-deep"
];

(* A condition on several attribute names is matched in two steps: a skeleton
   with no names finds the candidates, and each candidate is matched with
   plain list patterns. {OrderlessPatternSequence[rules..., ___]}, which also
   binds every name, costs the factorial of the attribute count: about 18 s
   here at six rules, against about 60 ms. On the tree engine a Condition
   that sees only names bound by "key" -> name_ is a function of the
   attribute values: 39 ms, against 78 ms in 3.0.0 and 356 ms matching each
   element. *)
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
  TimeConstraint -> 0.2,
  TestID -> "perf-condition-on-six-attribute-names"
];

(* A Condition on a contents list sees c alone, so g1 and g2 are never
   bound: restoring them, when the query names a list key, made each test
   linear in the 1000 siblings (about 2.3 s in all). *)
$trs = XMLElement["tbody", {}, Table[
  XMLElement["tr", If[OddQ[i], {"class" -> "a"}, {}], {XMLElement["td", {}, {ToString[i]}]}], {i, 1000}]];

(* 9 ms in 3.0.0, 9 ms. *)
TestCreate[
  Length @ XMLCases[$trs,
    XMLPattern["tbody", _, {g1___, c : XMLPattern["tr", "classList" -> "a"], g2___} /; c[[3, 1, 3, 1]] === "501"] :> c],
  1,
  TimeConstraint -> 0.1,
  TestID -> "perf-tree-list-condition-unused-names-1000-siblings"
];

(* A "Roles" or "Constructs" rule naming a list key splits each distinct raw
   value on the tree once, not once for each element a rule is tried on:
   HTMLToNotebook asks for an element's role up to three times. Here every
   element carries one of seven class values of a thousand tokens each.
   Measured at about 120 ms and 290 ms on a 2026 laptop; splitting per element
   measured about 350 ms and 1.1 s. The bounds are about twice the first, so
   they are tighter than the others in this file. Each rule now runs as a
   query on the tree engine, whose tag and attribute test is run once for
   each distinct tag and attribute list: 58 ms and 159 ms, against 93 ms and
   259 ms in 3.0.0, and 117 ms and 280 ms testing each element. *)
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
   is applied to (issue #2), and a pattern root with no constraints is one
   MatchQ, about a hundred times faster per element than the tree engine.
   Measured at about 60 ms on a 2026 laptop, against about 0.6 s compiling
   once per element. *)
$ps = XMLCases[$big, XMLPattern["div"]];

TestCreate[
  Length @ Select[$ps, XMLMatchQ[XMLPattern["div", "classList" -> "c3"]]],
  714,
  TimeConstraint -> 0.2,
  TestID -> "perf-xmlmatchq-operator-5000-elements"
];
