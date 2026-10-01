(* XMLFirstCase: first-match semantics across base patterns, combinators, and
   defaults. Fixtures $tree, $treeSiblings, $treeProducts, $realTree come from
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

(* Child *)
TestCreate[
  HTMLTextContent @ XMLFirstCase[$tree,
    Child[XMLPattern["div", "classList" -> "main"], XMLPattern["p"]]
  ],
  "Hello",
  TestID -> "firstcase-child"
];

(* Child with rule *)
TestCreate[
  XMLFirstCase[$tree,
    Child[XMLPattern["div", "classList" -> "main"], x:XMLPattern["p"]] :> HTMLTextContent[x]
  ],
  "Hello",
  TestID -> "firstcase-child-rule"
];

(* Child miss returns default *)
TestCreate[
  XMLFirstCase[$tree,
    Child[XMLPattern["body"], XMLPattern["p"]],
    None
  ],
  None,
  TestID -> "firstcase-child-miss"
];

(* Descendant *)
TestCreate[
  HTMLTextContent @ XMLFirstCase[$tree,
    Descendant[XMLPattern["div", "classList" -> "main"], XMLPattern["p"]]
  ],
  "Hello",
  TestID -> "firstcase-descendant"
];

(* Descendant with rule *)
TestCreate[
  XMLFirstCase[$treeProducts,
    Descendant[XMLPattern["div", "data-price" -> price_], el:XMLPattern["a"]] :>
      {price, HTMLTextContent[el]}
  ],
  {"19.99", "Sale Item"},
  TestID -> "firstcase-descendant-rule-cross-level"
];

(* Adjacent *)
TestCreate[
  HTMLTextContent @ XMLFirstCase[$treeSiblings,
    Adjacent[XMLPattern["h2"], XMLPattern["p"]]
  ],
  "First",
  TestID -> "firstcase-adjacent"
];

(* Adjacent with rule \[LongDash] both bindings *)
TestCreate[
  XMLFirstCase[$treeSiblings,
    Adjacent[h:XMLPattern["h2"], p:XMLPattern["p"]] :> {HTMLTextContent[h], HTMLTextContent[p]}
  ],
  {"Title", "First"},
  TestID -> "firstcase-adjacent-rule-both"
];

(* Sibling *)
TestCreate[
  HTMLTextContent @ XMLFirstCase[$treeSiblings,
    Sibling[XMLPattern["h2"], XMLPattern["p"]]
  ],
  "First",
  TestID -> "firstcase-sibling"
];

(* Sibling miss *)
TestCreate[
  XMLFirstCase[$treeSiblings,
    Sibling[XMLPattern["p"], XMLPattern["h2"]]
  ],
  Missing["NotFound"],
  TestID -> "firstcase-sibling-miss"
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
  HTMLTextContent @ XMLFirstCase[$treeSiblings, Adjacent[XMLPattern["h2"], p : XMLPattern["p"]] -> p],
  "First",
  TestID -> "firstcase-rule-combinator"
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
