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

(* === Combinators as stages === *)

(* A combinator's stage may itself be a combinator: the stages chain from left to
   right, as a CSS selector does, whichever way they are nested. *)
$treeNest = ImportString[
  "<div class=\"outer\"><section><p>1</p><div><p>2</p></div></section><p>3</p></div>\
<section><p>4</p></section>",
  {"HTML", "XMLObject"}];

nestTexts[q_] := HTMLTextContent /@ XMLCases[$treeNest, q];

TestCreate[
  nestTexts @ Descendant[XMLPattern["div", "classList" -> "outer"], Child[XMLPattern["section"], XMLPattern["p"]]],
  {"1"},
  TestID -> "nested-descendant-of-child"
];

(* A combinator as the ancestor or parent stage. *)
TestCreate[
  {nestTexts @ Descendant[Child[XMLPattern["section"], XMLPattern["div"]], XMLPattern["p"]],
   nestTexts @ Child[Descendant[XMLPattern["div", "classList" -> "outer"], XMLPattern["section"]], XMLPattern["p"]]},
  {{"2"}, {"1"}},
  TestID -> "nested-combinator-as-first-stage"
];

(* A combinator as the child stage: Child[a, Descendant[b, c]] is Descendant[Child[a, b], c]. *)
TestCreate[
  nestTexts @ Child[XMLPattern["section"], Descendant[XMLPattern["div"], XMLPattern["p"]]],
  {"2"},
  TestID -> "nested-child-of-descendant"
];

(* In the rule form, a name bound at any stage is in scope of the body, and an
   element binding is the original even when a stage names a list key. *)
TestCreate[
  XMLCases[$treeNest,
    Descendant[d : XMLPattern["div", "classList" -> "outer"], Child[s : XMLPattern["section"], x : XMLPattern["p"]]] :>
      {d[[2]], s[[1]], HTMLTextContent[x]}],
  {{{"class" -> "outer"}, "section", "1"}},
  TestID -> "nested-rule-binds-every-stage"
];

(* Sibling relations chain too. The siblings may be direct children of the
   ancestor, and a Sibling stage starts from its first match, as unnested. *)
TestCreate[
  {HTMLTextContent /@ XMLCases[$treeSiblings, Descendant[XMLPattern["div"], Adjacent[XMLPattern["h2"], XMLPattern["p"]]]],
   HTMLTextContent /@ XMLCases[$treeSiblings, Child[XMLPattern["div"], Sibling[XMLPattern["p"], XMLPattern["p"]]]],
   HTMLTextContent /@ XMLCases[$treeSiblings, Sibling[XMLPattern["p", "classList" -> "lead"], XMLPattern["p"]]]},
  {{"First"}, {"Second", "Fourth"}, {"Second", "Fourth"}},
  TestID -> "nested-sibling-relations"
];

(* A sibling stage followed by a child stage. *)
TestCreate[
  nestTexts @ Child[Adjacent[XMLPattern["p"], XMLPattern["div"]], XMLPattern["p"]],
  {"2"},
  TestID -> "nested-child-of-adjacent"
];

(* XMLFirstCase gives the first of what XMLCases gives, plain and rule forms. *)
TestCreate[
  {XMLFirstCase[$treeNest, Descendant[XMLPattern["div"], Child[XMLPattern["div"], XMLPattern["p"]]]],
   XMLFirstCase[$treeNest,
     Descendant[d : XMLPattern["div", "classList" -> "outer"], Child[XMLPattern["section"], x : XMLPattern["p"]]] :>
       {d[[2]], HTMLTextContent[x]}],
   XMLFirstCase[$treeNest, Child[XMLPattern["section"], Descendant[XMLPattern["div"], XMLPattern["p"]]], "none"],
   XMLFirstCase[$treeNest, Child[XMLPattern["section"], Descendant[XMLPattern["div"], XMLPattern["span"]]], "none"]},
  {XMLElement["p", {}, {"2"}], {{"class" -> "outer"}, "1"}, XMLElement["p", {}, {"2"}], "none"},
  TestID -> "nested-firstcase"
];

(* === A later stage's test sees an earlier stage's names === *)

$treeCard = ImportString[
  "<article><div class=\"card\" id=\"k\"><p class=\"lead\">1</p><p class=\"ad\">2</p></div></article>",
  {"HTML", "XMLObject"}];

(* An earlier stage's element binding is the original element in a later stage's
   test, even when a stage names a list key. *)
TestCreate[
  XMLCases[$treeCard,
    Descendant[d : XMLPattern["div", "classList" -> "card"], p : XMLPattern["p"] /; d[[2]] === {"class" -> "card", "id" -> "k"}] :>
      HTMLTextContent[p]],
  {"1", "2"},
  TestID -> "later-stage-test-sees-earlier-element"
];

(* Sibling relations and the plain form see earlier names too. *)
TestCreate[
  {XMLCases[$treeCard,
     Adjacent[a : XMLPattern["p", "classList" -> "lead"], b : XMLPattern["p"] /; a[[2]] === {"class" -> "lead"}] :>
       HTMLTextContent[b]],
   HTMLTextContent /@ XMLCases[$treeCard,
     Sibling[a : XMLPattern["p", "classList" -> "lead"], XMLPattern["p"] /; a[[2]] === {"class" -> "lead"}]],
   HTMLTextContent /@ XMLCases[$treeCard,
     Child[d : XMLPattern["div", "classList" -> "card"], XMLPattern["p"] /; d[[2]] === {"class" -> "card", "id" -> "k"}]]},
  {{"2"}, {"2"}, {"1", "2"}},
  TestID -> "later-stage-test-sees-earlier-element-every-combinator"
];

(* A name on an earlier stage's attribute argument is the original map, and a
   value binding is the value, in a later stage's test. *)
TestCreate[
  {XMLCases[$treeCard,
     Child[XMLPattern["div", as : {"classList" -> "card"}], p : XMLPattern["p"] /; as === {"class" -> "card", "id" -> "k"}] :>
       HTMLTextContent[p]],
   HTMLTextContent /@ XMLCases[$treeCard,
     Descendant[XMLPattern["div", {"classList" -> "card", "id" -> i_}], XMLPattern["p"] /; i === "k"]]},
  {{"1", "2"}, {"1", "2"}},
  TestID -> "later-stage-test-sees-earlier-attrs-and-values"
];

(* In a chain, a later stage's test sees every earlier stage, plain and rule forms. *)
TestCreate[
  {XMLCases[$treeCard,
     Descendant[a : XMLPattern["article"],
       Child[d : XMLPattern["div", "classList" -> "card"], p : XMLPattern["p", "classList" -> "ad"] /; {a[[1]], d[[2]]} === {"article", {"class" -> "card", "id" -> "k"}}]] :>
       HTMLTextContent[p]],
   HTMLTextContent /@ XMLCases[$treeCard,
     Child[Descendant[XMLPattern["article"], d : XMLPattern["div", "classList" -> "card"]], XMLPattern["p"] /; d[[2, 1]] === ("class" -> "card")]]},
  {{"2"}, {"1", "2"}},
  TestID -> "chain-later-stage-test-sees-earlier-stages"
];

TestCreate[
  {XMLFirstCase[$treeCard,
     Sibling[a : XMLPattern["p", "classList" -> "lead"], p : XMLPattern["p"] /; a[[2]] === {"class" -> "lead"}] :> HTMLTextContent[p]],
   XMLFirstCase[$treeCard,
     Descendant[d : XMLPattern["div", "classList" -> "card"], XMLPattern["p"] /; d[[2]] === {"class" -> "card", "id" -> "k"}]],
   XMLDeleteCases[$treeCard,
     Child[d : XMLPattern["div", "classList" -> "card"], XMLPattern["p"] /; d[[2]] === {"class" -> "card", "id" -> "k"}]][[2, 3, 1]],
   XMLDeleteCases[$treeCard,
     Descendant[d : XMLPattern["div", "classList" -> "card"], XMLPattern["p", "classList" -> "ad"] /; d[[1]] === "div"]][[2, 3, 1]]},
  {"2", XMLElement["p", {"class" -> "lead"}, {"1"}],
   XMLElement["div", {"class" -> "card", "id" -> "k"}, {}],
   XMLElement["div", {"class" -> "card", "id" -> "k"}, {XMLElement["p", {"class" -> "lead"}, {"1"}]}]},
  TestID -> "firstcase-and-deletecases-later-stage-test-sees-earlier-element"
];

(* A name for an element or its attribute map is bound at one stage: the same
   name at two stages is refused under the consumer's head. *)
TestCreate[
  {XMLCases[$treeCard, Descendant[d : XMLPattern["div"], d : XMLPattern["p"]] :> d],
   XMLFirstCase[$treeCard, Child[XMLPattern["div", "id" -> d_], d : XMLPattern["p", "classList" -> "ad"]]],
   XMLDeleteCases[$treeCard, Descendant[XMLPattern["article"], Child[XMLPattern["div", d : _], d : XMLPattern["p"]]]]},
  {$Failed, $Failed, $Failed},
  {XMLCases::stagename, XMLFirstCase::stagename, XMLDeleteCases::stagename},
  TestID -> "name-bound-at-two-stages-refused"
];
