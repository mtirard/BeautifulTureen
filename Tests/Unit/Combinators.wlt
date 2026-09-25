(* Combinators for XMLCases: Child, Adjacent, Sibling, Descendant, the base
   rule form, and named-attribute extraction flowing through them.
   Fixtures $tree, $treeSiblings, $treeProducts come from Tests/Support/Fixtures.wl. *)

(* === Child combinator === *)

TestCreate[
  HTMLTextContent /@ XMLCases[$tree, Child[XMLPattern["div", "classList" -> "main"], XMLPattern["p"]]],
  {"Hello", "World"},
  TestID -> "child-basic"
];

TestCreate[
  XMLCases[$tree, Child[XMLPattern["div", "classList" -> "main"], XMLPattern["p"]] :> "found"],
  {"found", "found"},
  TestID -> "child-rule-constant"
];

TestCreate[
  XMLCases[$tree, Child[XMLPattern["div", "classList" -> "main"], x:XMLPattern["p"]] :> HTMLTextContent[x]],
  {"Hello", "World"},
  TestID -> "child-rule-named"
];

(* Child does not match grandchildren *)
TestCreate[
  XMLCases[$tree, Child[XMLPattern["body"], XMLPattern["p"]]],
  {},
  TestID -> "child-not-grandchild"
];

(* Child with named attribute on child *)
TestCreate[
  XMLCases[$tree, Child[XMLPattern["div", "classList" -> "main"], XMLPattern["p", "class" -> cls_]] :> cls],
  {"special"},
  TestID -> "child-rule-attr"
];

(* === Adjacent sibling combinator === *)

TestCreate[
  HTMLTextContent /@ XMLCases[$treeSiblings, Adjacent[XMLPattern["h2"], XMLPattern["p"]]],
  {"First"},
  TestID -> "adjacent-basic"
];

TestCreate[
  XMLCases[$treeSiblings, Adjacent[XMLPattern["h2"], x:XMLPattern["p"]] :> HTMLTextContent[x]],
  {"First"},
  TestID -> "adjacent-rule-named"
];

(* Adjacent: p immediately after p *)
TestCreate[
  XMLCases[$treeSiblings, Adjacent[XMLPattern["p", "classList" -> "lead"], x:XMLPattern["p"]] :> HTMLTextContent[x]],
  {"Second"},
  TestID -> "adjacent-p-after-p"
];

(* Adjacent: span is not immediately after h2 *)
TestCreate[
  XMLCases[$treeSiblings, Adjacent[XMLPattern["h2"], XMLPattern["span"]]],
  {},
  TestID -> "adjacent-not-adjacent"
];

(* Adjacent rule can reference both before and after bindings *)
TestCreate[
  XMLCases[$treeSiblings,
    Adjacent[h:XMLPattern["h2"], p:XMLPattern["p"]] :> {HTMLTextContent[h], HTMLTextContent[p]}
  ],
  {{"Title", "First"}},
  TestID -> "adjacent-rule-both-bindings"
];

(* === General sibling combinator === *)

TestCreate[
  HTMLTextContent /@ XMLCases[$treeSiblings, Sibling[XMLPattern["h2"], XMLPattern["p"]]],
  {"First", "Second", "Fourth"},
  TestID -> "sibling-all-after"
];

TestCreate[
  XMLCases[$treeSiblings, Sibling[XMLPattern["h2"], x:XMLPattern["p"]] :> HTMLTextContent[x]],
  {"First", "Second", "Fourth"},
  TestID -> "sibling-rule-named"
];

(* Sibling: span after h2 \[LongDash] not adjacent, but still a sibling *)
TestCreate[
  HTMLTextContent /@ XMLCases[$treeSiblings, Sibling[XMLPattern["h2"], XMLPattern["span"]]],
  {"Third"},
  TestID -> "sibling-non-adjacent"
];

(* Sibling: nothing before h2 *)
TestCreate[
  XMLCases[$treeSiblings, Sibling[XMLPattern["p"], XMLPattern["h2"]]],
  {},
  TestID -> "sibling-wrong-order"
];

(* === Descendant combinator === *)

TestCreate[
  HTMLTextContent /@ XMLCases[$tree, Descendant[XMLPattern["div", "classList" -> "main"], XMLPattern["p"]]],
  {"Hello", "World"},
  TestID -> "descendant-basic"
];

TestCreate[
  XMLCases[$tree, Descendant[XMLPattern["div", "classList" -> "main"], x:XMLPattern["p"]] :> HTMLTextContent[x]],
  {"Hello", "World"},
  TestID -> "descendant-rule-named"
];

(* === Base XMLCases with rule === *)

TestCreate[
  XMLCases[$tree, x:XMLPattern["p"] :> HTMLTextContent[x]],
  {"Hello", "World", "Nav"},
  TestID -> "base-rule-named"
];

(* === Named attribute extraction (benchmark 04 style) === *)

(* Named attribute flows through XMLPattern *)
TestCreate[
  XMLCases[$treeProducts, XMLPattern["a", "href" -> href_] :> href],
  {"/sale", "/regular"},
  TestID -> "attr-extraction-href"
];

(* Child with named extraction from child *)
TestCreate[
  XMLCases[$treeProducts,
    Child[XMLPattern["div", "classList" -> "on-sale"], el:XMLPattern["a", "href" -> href_]] :> {HTMLTextContent[el], href}
  ],
  {{"Sale Item", "/sale"}},
  TestID -> "child-rule-full-extraction"
];

(* Cross-level: parent AND child bindings in the same rule *)
TestCreate[
  XMLCases[$treeProducts,
    Child[XMLPattern["div", {"classList" -> "product", "data-price" -> price_}], el:XMLPattern["a"]] :> {price, HTMLTextContent[el]}
  ],
  {{"19.99", "Sale Item"}, {"49.99", "Regular Item"}},
  TestID -> "child-rule-cross-level"
];

(* Cross-level with Descendant *)
TestCreate[
  XMLCases[$treeProducts,
    Descendant[XMLPattern["div", "data-price" -> price_], el:XMLPattern["a"]] :> {price, HTMLTextContent[el]}
  ],
  {{"19.99", "Sale Item"}, {"49.99", "Regular Item"}},
  TestID -> "descendant-rule-cross-level"
];

(* === The classList key in both stages === *)

(* A query naming a list key in any stage runs on one materialised tree, and every
   element it returns or binds is the original. *)
$treeCards = ImportString[
  "<div class=\"card\"><p class=\"lead\">1</p><p class=\"ad\">2</p><p class=\"lead ad\">3</p></div>\
<div><p class=\"lead\">4</p></div>",
  {"HTML", "XMLObject"}];

TestCreate[
  XMLCases[$treeCards,
    Child[XMLPattern["div", "classList" -> "card"], XMLPattern["p", "classList" -> _?(FreeQ["ad"])]]],
  {XMLElement["p", {"class" -> "lead"}, {"1"}]},
  TestID -> "child-classlist-both-stages"
];

TestCreate[
  XMLCases[$treeCards,
    Descendant[d : XMLPattern["div", "classList" -> c1_], p : XMLPattern["p", "classList" -> c2 : {"lead", ___}]] :>
      {d[[2]], c1, HTMLTextContent[p], c2, p[[2]]}],
  {{{"class" -> "card"}, {"card"}, "1", {"lead"}, {"class" -> "lead"}},
   {{"class" -> "card"}, {"card"}, "3", {"lead", "ad"}, {"class" -> "lead ad"}},
   {{}, {}, "4", {"lead"}, {"class" -> "lead"}}},
  TestID -> "descendant-classlist-bindings-both-stages"
];

TestCreate[
  XMLCases[$treeCards,
    Adjacent[XMLPattern["p", "classList" -> "ad"], a : XMLPattern["p", "classList" -> "lead"]] :> a],
  {XMLElement["p", {"class" -> "lead ad"}, {"3"}]},
  TestID -> "adjacent-classlist-both-stages"
];

TestCreate[
  XMLCases[$treeCards,
    Sibling[XMLPattern["p", "classList" -> {"lead"}], XMLPattern["p", "classList" -> "ad"]]],
  {XMLElement["p", {"class" -> "ad"}, {"2"}], XMLElement["p", {"class" -> "lead ad"}, {"3"}]},
  TestID -> "sibling-classlist-both-stages"
];

TestCreate[
  XMLFirstCase[$treeCards,
    Child[XMLPattern["div", "classList" -> {}], x : XMLPattern["p"]] :> x],
  XMLElement["p", {"class" -> "lead"}, {"4"}],
  TestID -> "firstcase-child-classlist-absent-parent"
];

(* A combinator's stages are element patterns. *)
TestCreate[
  XMLCases[$treeCards, Descendant[XMLPattern["div"], Child[XMLPattern["div"], XMLPattern["p"]]]],
  $Failed,
  {XMLCases::badpat},
  TestID -> "combinator-stage-must-be-element-pattern"
];
