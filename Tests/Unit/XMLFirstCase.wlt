(* XMLFirstCase: first-match semantics across patterns, rules and defaults.
   Fixtures $tree, $treeProducts, $realTree come from
   Tests/Support/Fixtures.wl. *)

(* Base: returns first match *)
TestCreate[
  HTMLTextContent @ XMLFirstCase[$tree, XMLPattern["p"]],
  "Hello",
  TestID -> "firstcase-base"
];

(* Base with rule *)
TestCreate[
  XMLFirstCase[$tree, x:XMLPattern["p"] :> HTMLTextContent[x]],
  "Hello",
  TestID -> "firstcase-base-rule"
];

(* No match \[LongDash] default Missing["NotFound"] *)
TestCreate[
  XMLFirstCase[$tree, XMLPattern["table"]],
  Missing["NotFound"],
  TestID -> "firstcase-no-match-default"
];

(* No match \[LongDash] explicit default *)
TestCreate[
  XMLFirstCase[$tree, XMLPattern["table"], "fallback"],
  "fallback",
  TestID -> "firstcase-no-match-explicit"
];

(* Real-world: OG title via rule + base *)
TestCreate[
  XMLFirstCase[$realTree,
    XMLPattern["meta", {"property" -> "og:title", "content" -> c_}] :> c
  ],
  "Wolfram Language: Programming Language + Built-In Knowledge",
  TestID -> "firstcase-real-og-title"
];

(* A rule pattern -> rhs, its rhs evaluated when the query is given *)
TestCreate[
  XMLFirstCase[$tree, XMLPattern["p"] -> 1],
  1,
  TestID -> "firstcase-rule"
];

TestCreate[
  XMLFirstCase[$tree, XMLPattern["table"] -> 1, "fallback"],
  "fallback",
  TestID -> "firstcase-rule-default"
];

TestCreate[
  XMLFirstCase[$tree, XMLPattern["p"] -> 1, "fallback"],
  1,
  TestID -> "firstcase-rule-default-unused"
];

TestCreate[
  Block[{x = 5},
    {XMLFirstCase[$realTree, XMLPattern["meta", "property" -> x_] -> x],
     FirstCase[{"property" -> "og:title"}, ("property" -> x_) -> x]}],
  {5, 5},
  TestID -> "firstcase-rule-global-value-as-firstcase"
];
