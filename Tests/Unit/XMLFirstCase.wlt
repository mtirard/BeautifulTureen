(* XMLFirstCase: first-match semantics across base patterns, combinators, and
   defaults. Fixtures $tree, $treeSiblings, $treeProducts, $realTree come from
   Tests/Support/Fixtures.wl.
   A test whose TestID ends in -as-list repeats the one before it with Adjacent
   and Sibling written as the list stages they are shorthands for (ADR 0016). *)

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

TestCreate[
  HTMLTextContent[XMLFirstCase[$treeSiblings, Child[XMLPattern[_], {___, XMLPattern["h2"], XMLPattern["p"], ___}]]],
  "First",
  TestID -> "firstcase-adjacent-as-list"
];

(* Adjacent with rule \[LongDash] both bindings *)
TestCreate[
  XMLFirstCase[$treeSiblings,
    Adjacent[h:XMLPattern["h2"], p:XMLPattern["p"]] :> {HTMLTextContent[h], HTMLTextContent[p]}
  ],
  {"Title", "First"},
  TestID -> "firstcase-adjacent-rule-both"
];

TestCreate[
  XMLFirstCase[$treeSiblings, Child[XMLPattern[_], {___, h:XMLPattern["h2"], p:XMLPattern["p"], ___}] :> {HTMLTextContent[h], HTMLTextContent[p]}],
  {"Title", "First"},
  TestID -> "firstcase-adjacent-rule-both-as-list"
];

(* Sibling *)
TestCreate[
  HTMLTextContent @ XMLFirstCase[$treeSiblings,
    Sibling[XMLPattern["h2"], XMLPattern["p"]]
  ],
  "First",
  TestID -> "firstcase-sibling"
];

TestCreate[
  HTMLTextContent[XMLFirstCase[$treeSiblings, Child[XMLPattern[_], {___, XMLPattern["h2"], ___, XMLPattern["p"], ___}]]],
  "First",
  TestID -> "firstcase-sibling-as-list"
];

(* Sibling miss *)
TestCreate[
  XMLFirstCase[$treeSiblings,
    Sibling[XMLPattern["p"], XMLPattern["h2"]]
  ],
  Missing["NotFound"],
  TestID -> "firstcase-sibling-miss"
];

TestCreate[
  XMLFirstCase[$treeSiblings, Child[XMLPattern[_], {___, XMLPattern["p"], ___, XMLPattern["h2"], ___}]],
  Missing["NotFound"],
  TestID -> "firstcase-sibling-miss-as-list"
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
  HTMLTextContent[XMLFirstCase[$treeSiblings, Child[XMLPattern[_], {___, XMLPattern["h2"], p:XMLPattern["p"], ___}] -> p]],
  "First",
  TestID -> "firstcase-rule-combinator-as-list"
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
