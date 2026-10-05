(* Combinators for XMLCases: Child, Adjacent, Sibling, Descendant, the base
   rule form, and named-attribute extraction flowing through them.
   Fixtures $tree, $treeSiblings, $treeProducts come from Tests/Support/Fixtures.wl.
   A test whose TestID ends in -as-list repeats the one before it with Adjacent
   and Sibling written as the list stages they are shorthands for (ADR 0016). *)

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
  HTMLTextContent /@ XMLCases[$treeSiblings, Child[XMLPattern[_], {___, XMLPattern["h2"], XMLPattern["p"], ___}]],
  {"First"},
  TestID -> "adjacent-basic-as-list"
];

TestCreate[
  XMLCases[$treeSiblings, Adjacent[XMLPattern["h2"], x:XMLPattern["p"]] :> HTMLTextContent[x]],
  {"First"},
  TestID -> "adjacent-rule-named"
];

TestCreate[
  XMLCases[$treeSiblings, Child[XMLPattern[_], {___, XMLPattern["h2"], x:XMLPattern["p"], ___}] :> HTMLTextContent[x]],
  {"First"},
  TestID -> "adjacent-rule-named-as-list"
];

(* Adjacent: p immediately after p *)
TestCreate[
  XMLCases[$treeSiblings, Adjacent[XMLPattern["p", "classList" -> "lead"], x:XMLPattern["p"]] :> HTMLTextContent[x]],
  {"Second"},
  TestID -> "adjacent-p-after-p"
];

TestCreate[
  XMLCases[$treeSiblings, Child[XMLPattern[_], {___, XMLPattern["p", "classList" -> "lead"], x:XMLPattern["p"], ___}] :> HTMLTextContent[x]],
  {"Second"},
  TestID -> "adjacent-p-after-p-as-list"
];

(* Adjacent: span is not immediately after h2 *)
TestCreate[
  XMLCases[$treeSiblings, Adjacent[XMLPattern["h2"], XMLPattern["span"]]],
  {},
  TestID -> "adjacent-not-adjacent"
];

TestCreate[
  XMLCases[$treeSiblings, Child[XMLPattern[_], {___, XMLPattern["h2"], XMLPattern["span"], ___}]],
  {},
  TestID -> "adjacent-not-adjacent-as-list"
];

(* Adjacent rule can reference both before and after bindings *)
TestCreate[
  XMLCases[$treeSiblings,
    Adjacent[h:XMLPattern["h2"], p:XMLPattern["p"]] :> {HTMLTextContent[h], HTMLTextContent[p]}
  ],
  {{"Title", "First"}},
  TestID -> "adjacent-rule-both-bindings"
];

TestCreate[
  XMLCases[$treeSiblings, Child[XMLPattern[_], {___, h:XMLPattern["h2"], p:XMLPattern["p"], ___}] :> {HTMLTextContent[h], HTMLTextContent[p]}],
  {{"Title", "First"}},
  TestID -> "adjacent-rule-both-bindings-as-list"
];

(* === General sibling combinator === *)

TestCreate[
  HTMLTextContent /@ XMLCases[$treeSiblings, Sibling[XMLPattern["h2"], XMLPattern["p"]]],
  {"First", "Second", "Fourth"},
  TestID -> "sibling-all-after"
];

TestCreate[
  HTMLTextContent /@ XMLCases[$treeSiblings, Child[XMLPattern[_], {___, XMLPattern["h2"], ___, XMLPattern["p"], ___}]],
  {"First", "Second", "Fourth"},
  TestID -> "sibling-all-after-as-list"
];

TestCreate[
  XMLCases[$treeSiblings, Sibling[XMLPattern["h2"], x:XMLPattern["p"]] :> HTMLTextContent[x]],
  {"First", "Second", "Fourth"},
  TestID -> "sibling-rule-named"
];

TestCreate[
  XMLCases[$treeSiblings, Child[XMLPattern[_], {___, XMLPattern["h2"], ___, x:XMLPattern["p"], ___}] :> HTMLTextContent[x]],
  {"First", "Second", "Fourth"},
  TestID -> "sibling-rule-named-as-list"
];

(* Sibling: span after h2 \[LongDash] not adjacent, but still a sibling *)
TestCreate[
  HTMLTextContent /@ XMLCases[$treeSiblings, Sibling[XMLPattern["h2"], XMLPattern["span"]]],
  {"Third"},
  TestID -> "sibling-non-adjacent"
];

TestCreate[
  HTMLTextContent /@ XMLCases[$treeSiblings, Child[XMLPattern[_], {___, XMLPattern["h2"], ___, XMLPattern["span"], ___}]],
  {"Third"},
  TestID -> "sibling-non-adjacent-as-list"
];

(* Sibling: nothing before h2 *)
TestCreate[
  XMLCases[$treeSiblings, Sibling[XMLPattern["p"], XMLPattern["h2"]]],
  {},
  TestID -> "sibling-wrong-order"
];

TestCreate[
  XMLCases[$treeSiblings, Child[XMLPattern[_], {___, XMLPattern["p"], ___, XMLPattern["h2"], ___}]],
  {},
  TestID -> "sibling-wrong-order-as-list"
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
  XMLCases[$treeCards, Child[XMLPattern[_], {___, XMLPattern["p", "classList" -> "ad"], a:XMLPattern["p", "classList" -> "lead"], ___}] :> a],
  {XMLElement["p", {"class" -> "lead ad"}, {"3"}]},
  TestID -> "adjacent-classlist-both-stages-as-list"
];

TestCreate[
  XMLCases[$treeCards,
    Sibling[XMLPattern["p", "classList" -> {"lead"}], XMLPattern["p", "classList" -> "ad"]]],
  {XMLElement["p", {"class" -> "ad"}, {"2"}], XMLElement["p", {"class" -> "lead ad"}, {"3"}]},
  TestID -> "sibling-classlist-both-stages"
];

TestCreate[
  XMLCases[$treeCards,
    Child[XMLPattern[_], {___, XMLPattern["p", "classList" -> {"lead"}], ___, XMLPattern["p", "classList" -> "ad"], ___}]],
  {XMLElement["p", {"class" -> "ad"}, {"2"}], XMLElement["p", {"class" -> "lead ad"}, {"3"}]},
  TestID -> "sibling-classlist-both-stages-as-list"
];

TestCreate[
  XMLCases[$treeCards, Child[XMLPattern[_], {___, XMLPattern["p", "classList" -> {"lead"}], ___, XMLPattern["p", "classList" -> "ad"], ___}]],
  {XMLElement["p", {"class" -> "ad"}, {"2"}], XMLElement["p", {"class" -> "lead ad"}, {"3"}]},
  TestID -> "sibling-classlist-both-stages-as-list"
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

TestCreate[
  {HTMLTextContent /@ XMLCases[$treeSiblings, Descendant[XMLPattern["div"], {___, XMLPattern["h2"], XMLPattern["p"], ___}]], HTMLTextContent /@ XMLCases[$treeSiblings, Child[XMLPattern["div"], {___, XMLPattern["p"], ___, XMLPattern["p"], ___}]], HTMLTextContent /@ XMLCases[$treeSiblings, Child[XMLPattern[_], {___, XMLPattern["p", "classList" -> "lead"], ___, XMLPattern["p"], ___}]]},
  {{"First"}, {"Second", "Fourth"}, {"Second", "Fourth"}},
  TestID -> "nested-sibling-relations-as-list"
];

(* A sibling stage followed by a child stage. *)
TestCreate[
  nestTexts @ Child[Adjacent[XMLPattern["p"], XMLPattern["div"]], XMLPattern["p"]],
  {"2"},
  TestID -> "nested-child-of-adjacent"
];

TestCreate[
  nestTexts @ Child[Child[XMLPattern[_], {___, XMLPattern["p"], XMLPattern["div"], ___}], XMLPattern["p"]],
  {"2"},
  TestID -> "nested-child-of-adjacent-as-list"
];

TestCreate[
  nestTexts[Child[XMLPattern[_], {___, XMLPattern["p"], XMLPattern["div"], ___}, XMLPattern["p"]]],
  {"2"},
  TestID -> "nested-child-of-adjacent-as-list"
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

(* === A stage's test sees only its own stage's names === *)

(* As in WL, where MatchQ[{1, 2}, {a_, b_ /; Head[a] === Symbol}] is True, a
   Condition sees only the names bound inside the pattern it wraps: in a later
   stage's test, an earlier stage's name is the plain symbol. *)
$treeCard = ImportString[
  "<article><div class=\"card\" id=\"k\"><p class=\"lead\">1</p><p class=\"ad\">2</p></div></article>",
  {"HTML", "XMLObject"}];

TestCreate[
  {XMLCases[$treeCard,
     Descendant[d : XMLPattern["div", "classList" -> "card"], p : XMLPattern["p"] /; Head[d] === Symbol] :>
       HTMLTextContent[p]],
   XMLCases[$treeCard,
     Adjacent[a : XMLPattern["p", "classList" -> "lead"], b : XMLPattern["p"] /; Head[a] === Symbol] :>
       HTMLTextContent[b]],
   HTMLTextContent /@ XMLCases[$treeCard,
     Sibling[a : XMLPattern["p"], XMLPattern["p"] /; Head[a] === Symbol]],
   HTMLTextContent /@ XMLCases[$treeCard,
     Child[d : XMLPattern["div"], XMLPattern["p"] /; Head[d] === Symbol]]},
  {{"1", "2"}, {"2"}, {"2"}, {"1", "2"}},
  TestID -> "stage-test-sees-not-earlier-element"
];

TestCreate[
  {XMLCases[$treeCard, Descendant[d:XMLPattern["div", "classList" -> "card"], p:XMLPattern["p"] /; Head[d] === Symbol] :> HTMLTextContent[p]], XMLCases[$treeCard, Child[XMLPattern[_], {___, a:XMLPattern["p", "classList" -> "lead"], b:XMLPattern["p"] /; Head[a] === Symbol, ___}] :> HTMLTextContent[b]], HTMLTextContent /@ XMLCases[$treeCard, Child[XMLPattern[_], {___, a:XMLPattern["p"], ___, XMLPattern["p"] /; Head[a] === Symbol, ___}]], HTMLTextContent /@ XMLCases[$treeCard, Child[d:XMLPattern["div"], XMLPattern["p"] /; Head[d] === Symbol]]},
  {{"1", "2"}, {"2"}, {"2"}, {"1", "2"}},
  TestID -> "stage-test-sees-not-earlier-element-as-list"
];

(* Nor an earlier stage's attribute map or value; its own names it sees, an
   element or attribute map as the original even when a stage names a list key. *)
TestCreate[
  {XMLCases[$treeCard,
     Child[XMLPattern["div", as : {"classList" -> "card"}], p : XMLPattern["p"] /; Head[as] === Symbol] :>
       HTMLTextContent[p]],
   HTMLTextContent /@ XMLCases[$treeCard,
     Descendant[XMLPattern["div", {"classList" -> "card", "id" -> i_}], XMLPattern["p"] /; Head[i] === Symbol]],
   HTMLTextContent /@ XMLCases[$treeCard,
     Child[XMLPattern["div"], p : XMLPattern["p", as : {"classList" -> _}] /; {p[[2]], as} === {{"class" -> "ad"}, {"class" -> "ad"}}]]},
  {{"1", "2"}, {"1", "2"}, {"2"}},
  TestID -> "stage-test-sees-not-earlier-attrs-and-values"
];

TestCreate[
  {XMLCases[$treeCard,
     Descendant[a : XMLPattern["article"],
       Child[d : XMLPattern["div", "classList" -> "card"], p : XMLPattern["p", "classList" -> "ad"] /; Head[a] === Head[d] === Symbol]] :>
       HTMLTextContent[p]],
   HTMLTextContent /@ XMLCases[$treeCard,
     Child[Descendant[XMLPattern["article"], d : XMLPattern["div", "classList" -> "card"]], XMLPattern["p"] /; Head[d] === Symbol]]},
  {{"2"}, {"1", "2"}},
  TestID -> "chain-stage-test-sees-not-earlier-stages"
];

TestCreate[
  {XMLFirstCase[$treeCard,
     Sibling[a : XMLPattern["p", "classList" -> "lead"], p : XMLPattern["p"] /; Head[a] === Symbol] :> HTMLTextContent[p]],
   XMLFirstCase[$treeCard,
     Descendant[d : XMLPattern["div", "classList" -> "card"], XMLPattern["p"] /; Head[d] === Symbol]],
   XMLFirstCase[
     XMLDeleteCases[$treeCard,
       Child[d : XMLPattern["div", "classList" -> "card"], XMLPattern["p", "classList" -> "ad"] /; Head[d] === Symbol]],
     XMLPattern["div"]]},
  {"2", XMLElement["p", {"class" -> "lead"}, {"1"}],
   XMLElement["div", {"class" -> "card", "id" -> "k"}, {XMLElement["p", {"class" -> "lead"}, {"1"}]}]},
  TestID -> "firstcase-and-deletecases-stage-test-sees-not-earlier-element"
];

TestCreate[
  {XMLFirstCase[$treeCard, Child[XMLPattern[_], {___, a:XMLPattern["p", "classList" -> "lead"], ___, p:XMLPattern["p"] /; Head[a] === Symbol, ___}] :> HTMLTextContent[p]], XMLFirstCase[$treeCard, Descendant[d:XMLPattern["div", "classList" -> "card"], XMLPattern["p"] /; Head[d] === Symbol]], XMLFirstCase[XMLDeleteCases[$treeCard, Child[d:XMLPattern["div", "classList" -> "card"], XMLPattern["p", "classList" -> "ad"] /; Head[d] === Symbol]], XMLPattern["div"]]},
  {"2", XMLElement["p", {"class" -> "lead"}, {"1"}], XMLElement["div", {"class" -> "card", "id" -> "k"}, {XMLElement["p", {"class" -> "lead"}, {"1"}]}]},
  TestID -> "firstcase-and-deletecases-stage-test-sees-not-earlier-element-as-list"
];

(* === A name at two stages is one value === *)

(* As in WL, where MatchQ[{1, 2}, {a_, a_}] is False, a name bound at two stages
   means the same value at both: a value, an element or an attribute map, the
   last two compared as they are in the tree even when a stage names a list key. *)
$treeTwice = ImportString[
  "<div id=\"k\"><p data-for=\"z\">0</p><p class=\"a\">1</p><p class=\"a\">2</p><p class=\"a\">1</p><p class=\"b\">1</p>\
<p data-for=\"k\">3</p></div>",
  {"HTML", "XMLObject"}];

TestCreate[
  {XMLCases[$treeTwice, Child[XMLPattern["div", "id" -> i_], p : XMLPattern["p", "data-for" -> i_]] :> {i, HTMLTextContent[p]}],
   HTMLTextContent /@ XMLCases[$treeTwice, Sibling[XMLPattern["p", "data-for" -> i_], XMLPattern["p", "data-for" -> i_]]]},
  {{{"k", "3"}}, {}},
  TestID -> "value-name-at-two-stages-is-one-value"
];

TestCreate[
  {XMLCases[$treeTwice, Child[XMLPattern["div", "id" -> i_], p:XMLPattern["p", "data-for" -> i_]] :> {i, HTMLTextContent[p]}], HTMLTextContent /@ XMLCases[$treeTwice, Child[XMLPattern[_], {___, XMLPattern["p", "data-for" -> i_], ___, XMLPattern["p", "data-for" -> i_], ___}]]},
  {{{"k", "3"}}, {}},
  TestID -> "value-name-at-two-stages-is-one-value-as-list"
];

TestCreate[
  {XMLCases[$treeTwice, Sibling[e : XMLPattern["p", "classList" -> "a"], e : XMLPattern["p"]] :> e],
   HTMLTextContent /@ XMLCases[$treeTwice,
     Adjacent[XMLPattern["p", as : {"classList" -> _}], XMLPattern["p", as : {"class" -> _}]]],
   XMLFirstCase[$treeTwice,
     Adjacent[XMLPattern["p", as : {"classList" -> _}], XMLPattern["p", as : {"class" -> _}]] :> as]},
  {{XMLElement["p", {"class" -> "a"}, {"1"}]}, {"2", "1"}, {"class" -> "a"}},
  TestID -> "element-and-attrs-name-at-two-stages-is-one-value"
];

TestCreate[
  {XMLCases[$treeTwice, Child[XMLPattern[_], {___, e:XMLPattern["p", "classList" -> "a"], ___, e:XMLPattern["p"], ___}] :> e], HTMLTextContent /@ XMLCases[$treeTwice, Child[XMLPattern[_], {___, XMLPattern["p", as:{"classList" -> _}], XMLPattern["p", as:{"class" -> _}], ___}]], XMLFirstCase[$treeTwice, Child[XMLPattern[_], {___, XMLPattern["p", as:{"classList" -> _}], XMLPattern["p", as:{"class" -> _}], ___}] :> as]},
  {{XMLElement["p", {"class" -> "a"}, {"1"}]}, {"2", "1"}, {"class" -> "a"}},
  TestID -> "element-and-attrs-name-at-two-stages-is-one-value-as-list"
];

(* Sibling[before, after] matches an element with some earlier sibling that
   matches before together with it: here the second h2, not the first. *)
$treeLaterBefore = ImportString[
  "<div id=\"k\"><h2 id=\"x\">H</h2><h2 id=\"y\">H2</h2><p data-for=\"k\">1</p><p data-for=\"y\">2</p></div>",
  {"HTML", "XMLObject"}];

TestCreate[
  {XMLCases[$treeLaterBefore,
     Sibling[XMLPattern["h2", "id" -> i_], p : XMLPattern["p", "data-for" -> i_]] :> HTMLTextContent[p]],
   HTMLTextContent @ XMLFirstCase[$treeLaterBefore,
     Sibling[XMLPattern["h2", "id" -> i_], XMLPattern["p", "data-for" -> i_]]]},
  {{"2"}, "2"},
  TestID -> "sibling-shared-name-reaches-later-before"
];

TestCreate[
  {XMLCases[$treeLaterBefore, Child[XMLPattern[_], {___, XMLPattern["h2", "id" -> i_], ___, p:XMLPattern["p", "data-for" -> i_], ___}] :> HTMLTextContent[p]], HTMLTextContent[XMLFirstCase[$treeLaterBefore, Child[XMLPattern[_], {___, XMLPattern["h2", "id" -> i_], ___, XMLPattern["p", "data-for" -> i_], ___}]]]},
  {{"2"}, "2"},
  TestID -> "sibling-shared-name-reaches-later-before-as-list"
];

(* So does a test on the whole combinator. *)
TestCreate[
  {XMLCases[$treeLaterBefore,
     (Sibling[XMLPattern["h2", "id" -> i_], p : XMLPattern["p", "data-for" -> f_]] /; f === i) :> HTMLTextContent[p]],
   HTMLTextContent @ XMLFirstCase[$treeLaterBefore,
     Sibling[h : XMLPattern["h2"], p : XMLPattern["p"]] /; HTMLTextContent[h] === "H2" && HTMLTextContent[p] === "1"]},
  {{"2"}, "1"},
  TestID -> "sibling-combinator-test-reaches-later-before"
];

TestCreate[
  {XMLCases[$treeLaterBefore, Child[XMLPattern[_], {___, XMLPattern["h2", "id" -> i_], ___, p:XMLPattern["p", "data-for" -> f_], ___}] /; f === i :> HTMLTextContent[p]], HTMLTextContent[XMLFirstCase[$treeLaterBefore, Child[XMLPattern[_], {___, h:XMLPattern["h2"], ___, p:XMLPattern["p"], ___}] /; HTMLTextContent[h] === "H2" && HTMLTextContent[p] === "1"]]},
  {{"2"}, "1"},
  TestID -> "sibling-combinator-test-reaches-later-before-as-list"
];

(* Each matched element comes once, however many earlier siblings match with
   it; the before stage's name is bound to the first of them. *)
$treeManyBefore = ImportString[
  "<div><h2 class=\"a\">1</h2><h2 class=\"b\">2</h2><h2 class=\"a\">3</h2><p class=\"a\">x</p><p class=\"b\">y</p></div>",
  {"HTML", "XMLObject"}];

TestCreate[
  {XMLCases[$treeManyBefore,
     Sibling[h : XMLPattern["h2", "class" -> c_], p : XMLPattern["p", "class" -> c_]] :> {HTMLTextContent[h], HTMLTextContent[p]}],
   XMLFirstCase[$treeManyBefore,
     (Sibling[h : XMLPattern["h2"], p : XMLPattern["p"]] /; h[[2]] === p[[2]]) :> {HTMLTextContent[h], HTMLTextContent[p]}]},
  {{{"1", "x"}, {"2", "y"}}, {"1", "x"}},
  TestID -> "sibling-shared-name-element-once-bound-to-first-before"
];

TestCreate[
  {XMLCases[$treeManyBefore,
     Child[XMLPattern[_], {___, h : XMLPattern["h2", "class" -> c_], ___, p : XMLPattern["p", "class" -> c_], ___}] :>
       {HTMLTextContent[h], HTMLTextContent[p]}],
   XMLFirstCase[$treeManyBefore,
     (Child[XMLPattern[_], {___, h : XMLPattern["h2"], ___, p : XMLPattern["p"], ___}] /; h[[2]] === p[[2]]) :>
       {HTMLTextContent[h], HTMLTextContent[p]}]},
  {{{"1", "x"}, {"2", "y"}}, {"1", "x"}},
  TestID -> "sibling-shared-name-element-once-bound-to-first-before-as-list"
];

TestCreate[
  {XMLCases[$treeManyBefore, Child[XMLPattern[_], {___, h:XMLPattern["h2", "class" -> c_], ___, p:XMLPattern["p", "class" -> c_], ___}] :> {HTMLTextContent[h], HTMLTextContent[p]}], XMLFirstCase[$treeManyBefore, Child[XMLPattern[_], {___, h:XMLPattern["h2"], ___, p:XMLPattern["p"], ___}] /; h[[2]] === p[[2]] :> {HTMLTextContent[h], HTMLTextContent[p]}]},
  {{{"1", "x"}, {"2", "y"}}, {"1", "x"}},
  TestID -> "sibling-shared-name-element-once-bound-to-first-before-as-list"
];

(* Sibling as any link of a chain. An element that follows the p after some h2
   comes once, whichever h2 and p lead to it. *)
TestCreate[
  {XMLCases[$treeManyBefore,
     Child[XMLPattern["div"], Sibling[XMLPattern["h2", "class" -> c_], p : XMLPattern["p", "class" -> c_]]] :> HTMLTextContent[p]],
   HTMLTextContent /@ XMLCases[$treeManyBefore,
     Sibling[Sibling[XMLPattern["h2", "class" -> c_], XMLPattern["h2", "class" -> c_]], XMLPattern["p"]]],
   HTMLTextContent /@ XMLCases[$treeManyBefore,
     Sibling[Adjacent[XMLPattern["h2"], XMLPattern["h2"]], XMLPattern["p"]]]},
  {{"x", "y"}, {"x", "y"}, {"x", "y"}},
  TestID -> "sibling-in-chain-element-once"
];

TestCreate[
  {XMLCases[$treeManyBefore, Child[XMLPattern["div"], {___, XMLPattern["h2", "class" -> c_], ___, p:XMLPattern["p", "class" -> c_], ___}] :> HTMLTextContent[p]], HTMLTextContent /@ XMLCases[$treeManyBefore, Child[XMLPattern[_], {___, XMLPattern["h2", "class" -> c_], ___, XMLPattern["h2", "class" -> c_], ___, XMLPattern["p"], ___}]], HTMLTextContent /@ XMLCases[$treeManyBefore, Child[XMLPattern[_], {___, XMLPattern["h2"], XMLPattern["h2"], ___, XMLPattern["p"], ___}]]},
  {{"x", "y"}, {"x", "y"}, {"x", "y"}},
  TestID -> "sibling-in-chain-element-once-as-list"
];

(* === Descendant gives each element once === *)

(* As querySelectorAll and soupsieve's select do, Descendant gives each matched
   element once, however many ancestors match. *)
$treeDeep = ImportString[
  "<div id=\"a\"><div id=\"b\"><p data-for=\"b\">1</p><p data-for=\"a\">2</p></div><p data-for=\"a\">3</p></div>",
  {"HTML", "XMLObject"}];

TestCreate[
  {HTMLTextContent /@ XMLCases[$treeDeep, Descendant[XMLPattern["div"], XMLPattern["p"]]],
   HTMLTextContent @ XMLFirstCase[$treeDeep, Descendant[XMLPattern["div"], XMLPattern["p"]]]},
  {{"1", "2", "3"}, "1"},
  TestID -> "descendant-element-once"
];

(* A name at the ancestor stage is bound to the outermost matching ancestor,
   the first in document order. *)
TestCreate[
  {XMLCases[$treeDeep, Descendant[XMLPattern["div", "id" -> i_], p : XMLPattern["p"]] :> {i, HTMLTextContent[p]}],
   XMLFirstCase[$treeDeep, Descendant[d : XMLPattern["div"], XMLPattern["p"]] :> d[[2]]]},
  {{{"a", "1"}, {"a", "2"}, {"a", "3"}}, {"id" -> "a"}},
  TestID -> "descendant-binds-outermost-ancestor"
];

(* In a chain too: each element once, whichever ancestors lead to it. *)
TestCreate[
  {HTMLTextContent /@ XMLCases[$treeDeep, Descendant[XMLPattern["div"], Child[XMLPattern["div"], XMLPattern["p"]]]],
   HTMLTextContent /@ XMLCases[$treeDeep, Descendant[XMLPattern["html"], Descendant[XMLPattern["div"], XMLPattern["p"]]]],
   HTMLTextContent /@ XMLCases[$treeDeep, Child[Descendant[XMLPattern[_], XMLPattern["div"]], XMLPattern["p"]]],
   HTMLTextContent /@ XMLCases[$treeDeep, Descendant[XMLPattern["div"], Adjacent[XMLPattern["p"], XMLPattern["p"]]]],
   HTMLTextContent /@ XMLCases[$treeDeep, Descendant[XMLPattern["div"], Sibling[XMLPattern[_], XMLPattern["p"]]]]},
  {{"1", "2"}, {"1", "2", "3"}, {"1", "2", "3"}, {"2"}, {"2", "3"}},
  TestID -> "descendant-in-chain-element-once"
];

TestCreate[
  {HTMLTextContent /@ XMLCases[$treeDeep, Descendant[XMLPattern["div"], Child[XMLPattern["div"], XMLPattern["p"]]]], HTMLTextContent /@ XMLCases[$treeDeep, Descendant[XMLPattern["html"], Descendant[XMLPattern["div"], XMLPattern["p"]]]], HTMLTextContent /@ XMLCases[$treeDeep, Child[Descendant[XMLPattern[_], XMLPattern["div"]], XMLPattern["p"]]], HTMLTextContent /@ XMLCases[$treeDeep, Descendant[XMLPattern["div"], {___, XMLPattern["p"], XMLPattern["p"], ___}]], HTMLTextContent /@ XMLCases[$treeDeep, Descendant[XMLPattern["div"], {___, XMLPattern[_], ___, XMLPattern["p"], ___}]]},
  {{"1", "2"}, {"1", "2", "3"}, {"1", "2", "3"}, {"2"}, {"2", "3"}},
  TestID -> "descendant-in-chain-element-once-as-list"
];

(* With a test on the combinator or a name at two stages, the ancestor is the
   outermost with which the whole pattern matches: here the inner div for the
   p "1". *)
TestCreate[
  {XMLCases[$treeDeep,
     (Descendant[XMLPattern["div", "id" -> i_], p : XMLPattern["p"]] /; StringQ[i]) :> {i, HTMLTextContent[p]}],
   XMLCases[$treeDeep,
     Descendant[XMLPattern["div", "id" -> i_], p : XMLPattern["p", "data-for" -> i_]] :> {i, HTMLTextContent[p]}],
   XMLCases[$treeDeep,
     Descendant[d : XMLPattern[_], Descendant[XMLPattern["div"], p : XMLPattern["p"]] /; True] /; True :>
       {First[d], HTMLTextContent[p]}],
   HTMLTextContent /@ XMLCases[$treeDeep,
     Descendant[XMLPattern["div", "id" -> i_], Sibling[XMLPattern["p"], XMLPattern["p", "data-for" -> f_]]] /; f === i]},
  {{{"a", "1"}, {"a", "2"}, {"a", "3"}}, {{"b", "1"}, {"a", "2"}, {"a", "3"}}, {{"html", "1"}, {"html", "2"}, {"html", "3"}}, {"2"}},
  TestID -> "descendant-tested-element-once"
];

TestCreate[
  {XMLCases[$treeDeep, Descendant[XMLPattern["div", "id" -> i_], p:XMLPattern["p"]] /; StringQ[i] :> {i, HTMLTextContent[p]}], XMLCases[$treeDeep, Descendant[XMLPattern["div", "id" -> i_], p:XMLPattern["p", "data-for" -> i_]] :> {i, HTMLTextContent[p]}], XMLCases[$treeDeep, Descendant[d:XMLPattern[_], Descendant[XMLPattern["div"], p:XMLPattern["p"]] /; True] /; True :> {First[d], HTMLTextContent[p]}], HTMLTextContent /@ XMLCases[$treeDeep, Descendant[XMLPattern["div", "id" -> i_], {___, XMLPattern["p"], ___, XMLPattern["p", "data-for" -> f_], ___}] /; f === i]},
  {{{"a", "1"}, {"a", "2"}, {"a", "3"}}, {{"b", "1"}, {"a", "2"}, {"a", "3"}}, {{"html", "1"}, {"html", "2"}, {"html", "3"}}, {"2"}},
  TestID -> "descendant-tested-element-once-as-list"
];

(* === One path for every combinator === *)

(* A name on the earlier Sibling stage is bound in the body. *)
TestCreate[
  {XMLCases[$treeSiblings,
     Sibling[a : XMLPattern["h2"], b : XMLPattern["p"]] :> {HTMLTextContent[a], HTMLTextContent[b]}],
   XMLFirstCase[$treeSiblings,
     Sibling[a : XMLPattern["h2"], b : XMLPattern["p"]] :> {HTMLTextContent[a], HTMLTextContent[b]}]},
  {{{"Title", "First"}, {"Title", "Second"}, {"Title", "Fourth"}}, {"Title", "First"}},
  TestID -> "sibling-rule-binds-both-stages"
];

TestCreate[
  {XMLCases[$treeSiblings, Child[XMLPattern[_], {___, a:XMLPattern["h2"], ___, b:XMLPattern["p"], ___}] :> {HTMLTextContent[a], HTMLTextContent[b]}], XMLFirstCase[$treeSiblings, Child[XMLPattern[_], {___, a:XMLPattern["h2"], ___, b:XMLPattern["p"], ___}] :> {HTMLTextContent[a], HTMLTextContent[b]}]},
  {{{"Title", "First"}, {"Title", "Second"}, {"Title", "Fourth"}}, {"Title", "First"}},
  TestID -> "sibling-rule-binds-both-stages-as-list"
];

(* Siblings may be direct children of a root given as a bare XMLElement. *)
$bareRoot = XMLElement["div", {},
  {XMLElement["h2", {}, {"T"}], XMLElement["p", {}, {"1"}], XMLElement["p", {}, {"2"}]}];

TestCreate[
  {XMLCases[$bareRoot, Adjacent[XMLPattern["h2"], XMLPattern["p"]]][[All, 3, 1]],
   XMLCases[$bareRoot, Sibling[XMLPattern["h2"], XMLPattern["p"]]][[All, 3, 1]],
   XMLFirstCase[$bareRoot, Adjacent[XMLPattern["h2"], x : XMLPattern["p"]] :> x[[3, 1]]]},
  {{"1"}, {"1", "2"}, "1"},
  TestID -> "sibling-relations-under-bare-root"
];

TestCreate[
  {XMLCases[$bareRoot, Child[XMLPattern[_], {___, XMLPattern["h2"], XMLPattern["p"], ___}]][[All,3,1]], XMLCases[$bareRoot, Child[XMLPattern[_], {___, XMLPattern["h2"], ___, XMLPattern["p"], ___}]][[All,3,1]], XMLFirstCase[$bareRoot, Child[XMLPattern[_], {___, XMLPattern["h2"], x:XMLPattern["p"], ___}] :> x[[3,1]]]},
  {{"1"}, {"1", "2"}, "1"},
  TestID -> "sibling-relations-under-bare-root-as-list"
];

(* === The root may be any stage but the last === *)

(* A bare XMLElement root may match a stage, as the root element of a document
   or a list's top-level element does, but is never returned: base XMLCases
   never returns it. *)
$root = XMLElement["body", {}, {XMLElement["div", {}, {"x", XMLElement["p", {}, {"1"}]}]}];

TestCreate[
  {XMLCases[$root, Child[XMLPattern["body"], XMLPattern["div"]]],
   XMLFirstCase[$root, Child[XMLPattern["body"], XMLPattern["div"]]]},
  {{XMLElement["div", {}, {"x", XMLElement["p", {}, {"1"}]}]}, XMLElement["div", {}, {"x", XMLElement["p", {}, {"1"}]}]},
  TestID -> "root-as-child-parent"
];

(* The root has no siblings, so an Adjacent or Sibling stage after it selects
   nothing, alone or in a chain. *)
TestCreate[
  {XMLCases[$root, Adjacent[XMLPattern["body"], XMLPattern[_]]],
   XMLCases[$root, Sibling[XMLPattern["body"], XMLPattern[_]]],
   XMLFirstCase[$root, Sibling[XMLPattern["body"], XMLPattern[_]] :> 1, "none"],
   XMLCases[$root, Child[Sibling[XMLPattern["body"], XMLPattern[_]], XMLPattern[_]]],
   XMLCases[$root, Sibling[XMLPattern["body", "id" -> i_], XMLPattern[_, "id" -> i_]]]},
  {{}, {}, "none", {}, {}},
  TestID -> "root-has-no-siblings"
];

TestCreate[
  {XMLCases[$root, Child[XMLPattern[_], {___, XMLPattern["body"], XMLPattern[_], ___}]], XMLCases[$root, Child[XMLPattern[_], {___, XMLPattern["body"], ___, XMLPattern[_], ___}]], XMLFirstCase[$root, Child[XMLPattern[_], {___, XMLPattern["body"], ___, XMLPattern[_], ___}] :> 1, "none"], XMLCases[$root, Child[XMLPattern[_], Child[{___, XMLPattern["body"], ___, XMLPattern[_], ___}, XMLPattern[_]]]], XMLCases[$root, Child[XMLPattern[_], {___, XMLPattern["body", "id" -> i_], ___, XMLPattern[_, "id" -> i_], ___}]]},
  {{}, {}, "none", {}, {}},
  TestID -> "root-has-no-siblings-as-list"
];

(* As an ancestor, in a nested chain, and bound in a rule body or a combinator
   test; never as the last stage. *)
TestCreate[
  {HTMLTextContent /@ XMLCases[$root, Descendant[XMLPattern["body"], XMLPattern[_]]],
   HTMLTextContent /@ XMLCases[$root, Descendant[XMLPattern["body"], Child[XMLPattern["div"], XMLPattern["p"]]]],
   HTMLTextContent /@ XMLCases[$root, Child[Child[XMLPattern["body"], XMLPattern["div"]], XMLPattern["p"]]],
   XMLCases[$root, Descendant[b : XMLPattern["body"], p : XMLPattern["p"]] :> {First[b], HTMLTextContent[p]}],
   XMLFirstCase[$root, (Child[b : XMLPattern[_], XMLPattern["div"]] /; First[b] === "body") :> First[b]],
   XMLCases[$root, Descendant[XMLPattern[_], b : XMLPattern["body"]]]},
  {{"x1", "1"}, {"1"}, {"1"}, {{"body", "1"}}, "body", {}},
  TestID -> "root-as-ancestor-nested-and-bound"
];

(* Results come in document order of the last-stage elements, as a base
   XMLCases gives them, not grouped by the earlier stages' matches. The first
   h2's next sibling, the section, holds the second h2 and its next sibling, the
   p "2". *)
$treeOrder = ImportString[
  "<div><h2>A</h2><section><h2>B</h2><p>2</p></section><p>3</p></div>",
  {"HTML", "XMLObject"}];

TestCreate[
  {HTMLTextContent /@ XMLCases[$treeOrder, Adjacent[XMLPattern["h2"], XMLPattern[_]]],
   XMLCases[$treeOrder, Sibling[XMLPattern["h2"], x : XMLPattern[_]] :> HTMLTextContent[x]],
   HTMLTextContent @ XMLFirstCase[$treeOrder, Adjacent[XMLPattern["h2"], XMLPattern[_]]],
   XMLFirstCase[$treeOrder, Sibling[XMLPattern["h2"], x : XMLPattern[_]] :> HTMLTextContent[x]]},
  {{"B2", "2"}, {"B2", "2", "3"}, "B2", "B2"},
  TestID -> "combinator-results-in-document-order"
];

TestCreate[
  {HTMLTextContent /@ XMLCases[$treeOrder, Child[XMLPattern[_], {___, XMLPattern["h2"], XMLPattern[_], ___}]], XMLCases[$treeOrder, Child[XMLPattern[_], {___, XMLPattern["h2"], ___, x:XMLPattern[_], ___}] :> HTMLTextContent[x]], HTMLTextContent[XMLFirstCase[$treeOrder, Child[XMLPattern[_], {___, XMLPattern["h2"], XMLPattern[_], ___}]]], XMLFirstCase[$treeOrder, Child[XMLPattern[_], {___, XMLPattern["h2"], ___, x:XMLPattern[_], ___}] :> HTMLTextContent[x]]},
  {{"B2", "2"}, {"B2", "2", "3"}, "B2", "B2"},
  TestID -> "combinator-results-in-document-order-as-list"
];

(* === A test on a whole combinator sees every stage's names === *)

(* As a Condition on {a_, b_} sees a and b, a Condition on a combinator sees the
   names of all its stages, an element or attribute map as it is in the tree. *)
$treeFor = ImportString[
  "<article><div class=\"card\" id=\"k\"><p data-for=\"k\">1</p><p data-for=\"z\">2</p></div></article>",
  {"HTML", "XMLObject"}];

TestCreate[
  {HTMLTextContent /@ XMLCases[$treeFor,
     Descendant[d : XMLPattern["div", "id" -> i_], p : XMLPattern["p", "data-for" -> f_]] /; f === i],
   XMLCases[$treeFor,
     (Descendant[XMLPattern["div", "id" -> i_], p : XMLPattern["p", "data-for" -> f_]] /; f === i) :> HTMLTextContent[p]],
   HTMLTextContent /@ XMLCases[$treeFor,
     Child[d : XMLPattern["div", as : {"classList" -> "card"}], p : XMLPattern["p", "classList" -> {}]] /;
       d[[2]] === as === {"class" -> "card", "id" -> "k"} && p[[2]] === {"data-for" -> "z"}]},
  {{"1"}, {"1"}, {"2"}},
  TestID -> "combinator-test-sees-every-stage"
];

(* On a chain, and on a combinator that is a stage, where it sees only that
   combinator's stages. *)
TestCreate[
  {HTMLTextContent /@ XMLCases[$treeFor,
     Descendant[a : XMLPattern["article"], Child[XMLPattern["div", "id" -> i_], XMLPattern["p", "data-for" -> f_]]] /;
       a[[1]] === "article" && f === i],
   HTMLTextContent /@ XMLCases[$treeFor,
     Descendant[XMLPattern["article"], Child[XMLPattern["div", "id" -> i_], XMLPattern["p", "data-for" -> f_]] /; f =!= i]],
   HTMLTextContent /@ XMLCases[$treeFor,
     Descendant[a : XMLPattern["article"], Child[XMLPattern["div", "classList" -> "card"], XMLPattern["p"]] /; Head[a] === Symbol]]},
  {{"1"}, {"2"}, {"1", "2"}},
  TestID -> "chain-combinator-test"
];

TestCreate[
  {XMLFirstCase[$treeFor,
     (Child[XMLPattern["div", "id" -> i_], p : XMLPattern["p", "data-for" -> f_]] /; f =!= i) :> HTMLTextContent[p]],
   HTMLTextContent /@ XMLCases[
     XMLDeleteCases[$treeFor, Child[XMLPattern["div", "id" -> i_], XMLPattern["p", "data-for" -> f_]] /; f === i],
     XMLPattern["p"]],
   HTMLTextContent @ XMLDeleteCases[$treeFor, Adjacent[XMLPattern["p"], XMLPattern["p"]] /; True]},
  {"2", {"2"}, "1"},
  TestID -> "firstcase-and-deletecases-combinator-test"
];

TestCreate[
  {XMLFirstCase[$treeFor, Child[XMLPattern["div", "id" -> i_], p:XMLPattern["p", "data-for" -> f_]] /; f =!= i :> HTMLTextContent[p]], HTMLTextContent /@ XMLCases[XMLDeleteCases[$treeFor, Child[XMLPattern["div", "id" -> i_], XMLPattern["p", "data-for" -> f_]] /; f === i], XMLPattern["p"]], HTMLTextContent[XMLDeleteCases[$treeFor, Child[XMLPattern[_], {___, XMLPattern["p"], XMLPattern["p"], ___}] /; True]]},
  {"2", {"2"}, "1"},
  TestID -> "firstcase-and-deletecases-combinator-test-as-list"
];

(* === A Condition in a rule's body takes part in choosing === *)

(* As Cases gives the places where a rule gives a value, a combinator rule whose
   body can reject is matched where its body accepts: the ancestor or earlier
   sibling a name binds to is the first with which the body gives a value, as it
   is for a Condition on the combinator. *)
$treeNested = ImportString[
  "<div id=\"outer\"><div id=\"inner\"><p>x</p></div></div>",
  {"HTML", "XMLObject"}];
$treeHeads = ImportString[
  "<div><h2 id=\"a\">A</h2><p id=\"1\">1</p><h2 id=\"b\">B</h2><p id=\"2\">2</p><span>s</span></div>",
  {"HTML", "XMLObject"}];

TestCreate[
  {XMLCases[$treeNested, Descendant[XMLPattern["div", "id" -> i_], XMLPattern["p"]] :> i /; i === "inner"],
   XMLFirstCase[$treeNested, Descendant[XMLPattern["div", "id" -> i_], XMLPattern["p"]] :> i /; i === "inner"],
   XMLCases[$treeNested,
     Descendant[XMLPattern["div", "id" -> i_], XMLPattern["p"]] :> Module[{v = i}, v /; v === "inner"]]},
  {{"inner"}, "inner", {"inner"}},
  TestID -> "descendant-body-condition-chooses-ancestor"
];

TestCreate[
  {XMLCases[$treeHeads, Sibling[XMLPattern["h2", "id" -> i_], XMLPattern["span"]] :> i /; i === "b"],
   XMLFirstCase[$treeHeads, Sibling[XMLPattern["h2", "id" -> i_], XMLPattern["span"]] :> i /; i === "b"],
   XMLCases[$treeHeads,
     Sibling[Adjacent[XMLPattern["h2", "id" -> i_], XMLPattern["p", "id" -> j_]], XMLPattern["span"]] :>
       {i, j} /; i === "b"]},
  {{"b"}, "b", {{"b", "2"}}},
  TestID -> "sibling-body-condition-chooses-sibling"
];

TestCreate[
  {XMLCases[$treeHeads, Child[XMLPattern[_], {___, XMLPattern["h2", "id" -> i_], ___, XMLPattern["span"], ___}] :> i /; i === "b"],
   XMLFirstCase[$treeHeads, Child[XMLPattern[_], {___, XMLPattern["h2", "id" -> i_], ___, XMLPattern["span"], ___}] :> i /; i === "b"],
   XMLCases[$treeHeads,
     Child[XMLPattern[_], {___, XMLPattern["h2", "id" -> i_], XMLPattern["p", "id" -> j_], ___, XMLPattern["span"], ___}] :>
       {i, j} /; i === "b"]},
  {{"b"}, "b", {{"b", "2"}}},
  TestID -> "sibling-body-condition-chooses-sibling-as-list"
];

TestCreate[
  {XMLCases[$treeHeads, Child[XMLPattern[_], {___, XMLPattern["h2", "id" -> i_], ___, XMLPattern["span"], ___}] :> i /; i === "b"], XMLFirstCase[$treeHeads, Child[XMLPattern[_], {___, XMLPattern["h2", "id" -> i_], ___, XMLPattern["span"], ___}] :> i /; i === "b"], XMLCases[$treeHeads, Child[XMLPattern[_], {___, XMLPattern["h2", "id" -> i_], XMLPattern["p", "id" -> j_], ___, XMLPattern["span"], ___}] :> {i, j} /; i === "b"]},
  {{"b"}, "b", {{"b", "2"}}},
  TestID -> "sibling-body-condition-chooses-sibling-as-list"
];

(* The body is evaluated for each result once, as Cases evaluates it: not when
   the query is compiled, and not again once a tuple is chosen. *)
TestCreate[
  {Module[{n = 0},
    {XMLCases[$treeNested, Descendant[XMLPattern["div", "id" -> i_], XMLPattern["p"]] :> (n++; i) /; True], n}],
   Module[{n = 0}, {XMLCases[$treeNested, XMLPattern["div", "id" -> i_] :> (n++; i) /; True], n}]},
  {{{"outer"}, 1}, {{"outer", "inner"}, 2}},
  TestID -> "combinator-body-condition-evaluates-body-once"
];

(* === A PatternTest sees no pattern names === *)

(* As in WL, where Block[{i = "z"}, MatchQ[{"k", "z"}, {i_, _?(Function[v, v === i])}]]
   is True, the function of a PatternTest sees a symbol, never a name's binding. *)
TestCreate[
  {HTMLTextContent /@ XMLCases[$treeFor,
     Child[XMLPattern["div", "id" -> i_], XMLPattern["p", "data-for" -> _?(Function[v, v === i])]]],
   Block[{i = "z"}, HTMLTextContent /@ XMLCases[$treeFor,
     Child[XMLPattern["div", "id" -> i_], XMLPattern["p", "data-for" -> _?(Function[v, v === i])]]]]},
  {{}, {"2"}},
  TestID -> "pattern-test-sees-no-names"
];

(* === A combinator with more than two stages === *)

(* L[s1, s2, ..., sn] is the right-nested chain L[s1, L[s2, ..., L[s(n-1), sn]]].
   On this tree each three-stage form selects something no two-stage form of its
   stages does. *)
$treeChains = ImportString[
  "<body><article id=\"art\"><section id=\"s1\"><p>1</p></section><p>2</p></article>" <>
  "<section id=\"s2\"><p>3</p></section>" <>
  "<div><h2>h</h2><p>4</p><span>a</span><p>5</p><span>b</span></div>" <>
  "<div><span>w</span><p>6</p><span>x</span><h2>h</h2><span>y</span><p>7</p><span>z</span></div></body>",
  {"HTML", "XMLObject"}];

TestCreate[
  Map[HTMLTextContent, #, {2}] & @ {
    XMLCases[$treeChains, Child[XMLPattern["body"], XMLPattern["section"], XMLPattern["p"]]],
    XMLCases[$treeChains, Child[XMLPattern["body"], Child[XMLPattern["section"], XMLPattern["p"]]]],
    XMLCases[$treeChains, Descendant[XMLPattern["article"], XMLPattern["section"], XMLPattern["p"]]],
    XMLCases[$treeChains, Descendant[XMLPattern["article"], Descendant[XMLPattern["section"], XMLPattern["p"]]]],
    XMLCases[$treeChains, Adjacent[XMLPattern["h2"], XMLPattern["p"], XMLPattern["span"]]],
    XMLCases[$treeChains, Adjacent[XMLPattern["h2"], Adjacent[XMLPattern["p"], XMLPattern["span"]]]],
    XMLCases[$treeChains, Sibling[XMLPattern["h2"], XMLPattern["p"], XMLPattern["span"]]],
    XMLCases[$treeChains, Sibling[XMLPattern["h2"], Sibling[XMLPattern["p"], XMLPattern["span"]]]]},
  {{"3"}, {"3"}, {"1"}, {"1"}, {"a"}, {"a"}, {"a", "b", "z"}, {"a", "b", "z"}},
  TestID -> "many-stage-combinator-is-right-nested-chain"
];

TestCreate[
  (Map[HTMLTextContent, #1, {2}] & )[{XMLCases[$treeChains, Child[XMLPattern["body"], XMLPattern["section"], XMLPattern["p"]]], XMLCases[$treeChains, Child[XMLPattern["body"], Child[XMLPattern["section"], XMLPattern["p"]]]], XMLCases[$treeChains, Descendant[XMLPattern["article"], XMLPattern["section"], XMLPattern["p"]]], XMLCases[$treeChains, Descendant[XMLPattern["article"], Descendant[XMLPattern["section"], XMLPattern["p"]]]], XMLCases[$treeChains, Child[XMLPattern[_], {___, XMLPattern["h2"], XMLPattern["p"], XMLPattern["span"], ___}]], XMLCases[$treeChains, Child[XMLPattern[_], {___, XMLPattern["h2"], XMLPattern["p"], XMLPattern["span"], ___}]], XMLCases[$treeChains, Child[XMLPattern[_], {___, XMLPattern["h2"], ___, XMLPattern["p"], ___, XMLPattern["span"], ___}]], XMLCases[$treeChains, Child[XMLPattern[_], {___, XMLPattern["h2"], ___, XMLPattern["p"], ___, XMLPattern["span"], ___}]]}],
  {{"3"}, {"3"}, {"1"}, {"1"}, {"a"}, {"a"}, {"a", "b", "z"}, {"a", "b", "z"}},
  TestID -> "many-stage-combinator-is-right-nested-chain-as-list"
];

(* Four stages, and a stage that is a combinator of another head. *)
TestCreate[
  Map[HTMLTextContent, #, {2}] & @ {
    XMLCases[$treeChains, Child[XMLPattern["html"], XMLPattern["body"], XMLPattern["section"], XMLPattern["p"]]],
    XMLCases[$treeChains, Descendant[XMLPattern["body"], XMLPattern["article"], XMLPattern["section"], XMLPattern["p"]]],
    XMLCases[$treeChains, Sibling[XMLPattern["span"], XMLPattern["p"], XMLPattern["h2"], XMLPattern["span"]]],
    XMLCases[$treeChains,
      Descendant[XMLPattern["body"], Child[XMLPattern["article"], XMLPattern["section"]], XMLPattern["p"]]],
    XMLCases[$treeChains,
      Descendant[XMLPattern["body"], Descendant[Child[XMLPattern["article"], XMLPattern["section"]], XMLPattern["p"]]]],
    XMLCases[$treeChains, Descendant[XMLPattern["body"], XMLPattern["div"], Adjacent[XMLPattern["p"], XMLPattern["span"]]]]},
  {{"3"}, {"1"}, {"y", "z"}, {"1"}, {"1"}, {"a", "b", "x", "z"}},
  TestID -> "many-stage-four-stages-and-mixed-heads"
];

TestCreate[
  (Map[HTMLTextContent, #1, {2}] & )[{XMLCases[$treeChains, Child[XMLPattern["html"], XMLPattern["body"], XMLPattern["section"], XMLPattern["p"]]], XMLCases[$treeChains, Descendant[XMLPattern["body"], XMLPattern["article"], XMLPattern["section"], XMLPattern["p"]]], XMLCases[$treeChains, Child[XMLPattern[_], {___, XMLPattern["span"], ___, XMLPattern["p"], ___, XMLPattern["h2"], ___, XMLPattern["span"], ___}]], XMLCases[$treeChains, Descendant[XMLPattern["body"], Child[XMLPattern["article"], XMLPattern["section"]], XMLPattern["p"]]], XMLCases[$treeChains, Descendant[XMLPattern["body"], Descendant[Child[XMLPattern["article"], XMLPattern["section"]], XMLPattern["p"]]]], XMLCases[$treeChains, Descendant[XMLPattern["body"], Descendant[XMLPattern["div"], {___, XMLPattern["p"], XMLPattern["span"], ___}]]]}],
  {{"3"}, {"1"}, {"y", "z"}, {"1"}, {"1"}, {"a", "b", "x", "z"}},
  TestID -> "many-stage-four-stages-and-mixed-heads-as-list"
];

(* Names scope as in the nested form: a rule body sees every stage's names, a
   stage's test only its own, a combinator's test all of its stages', and a name
   at two stages is one value. *)
TestCreate[
  {XMLCases[$treeChains,
     Descendant[XMLPattern["article", "id" -> a_], XMLPattern["section", "id" -> s_], p : XMLPattern["p"]] :>
       {a, s, HTMLTextContent[p]}],
   XMLCases[$treeChains,
     Descendant[XMLPattern["article", "id" -> a_], Descendant[XMLPattern["section", "id" -> s_], p : XMLPattern["p"]]] :>
       {a, s, HTMLTextContent[p]}],
   HTMLTextContent /@ XMLCases[$treeChains,
     Descendant[XMLPattern["body"], XMLPattern["section", "id" -> s_], XMLPattern["p"]] /; s === "s2"],
   XMLCases[$treeChains,
     (Descendant[XMLPattern[_, "id" -> a_], XMLPattern["section", "id" -> s_], XMLPattern["p"]] /; a =!= s) :> {a, s}],
   HTMLTextContent /@ XMLCases[$treeChains,
     Descendant[XMLPattern["article", "id" -> a_], XMLPattern["section"] /; Head[a] === Symbol, XMLPattern["p"]]],
   HTMLTextContent /@ XMLCases[$treeChains,
     Sibling[XMLPattern[t_], XMLPattern["h2"], XMLPattern[t_]]]},
  {{{"art", "s1", "1"}}, {{"art", "s1", "1"}}, {"3"}, {{"art", "s1"}}, {"1"}, {"y", "7", "z"}},
  TestID -> "many-stage-names-scope-as-nested"
];

TestCreate[
  {XMLCases[$treeChains, Descendant[XMLPattern["article", "id" -> a_], XMLPattern["section", "id" -> s_], p:XMLPattern["p"]] :> {a, s, HTMLTextContent[p]}], XMLCases[$treeChains, Descendant[XMLPattern["article", "id" -> a_], Descendant[XMLPattern["section", "id" -> s_], p:XMLPattern["p"]]] :> {a, s, HTMLTextContent[p]}], HTMLTextContent /@ XMLCases[$treeChains, Descendant[XMLPattern["body"], XMLPattern["section", "id" -> s_], XMLPattern["p"]] /; s === "s2"], XMLCases[$treeChains, Descendant[XMLPattern[_, "id" -> a_], XMLPattern["section", "id" -> s_], XMLPattern["p"]] /; a =!= s :> {a, s}], HTMLTextContent /@ XMLCases[$treeChains, Descendant[XMLPattern["article", "id" -> a_], XMLPattern["section"] /; Head[a] === Symbol, XMLPattern["p"]]], HTMLTextContent /@ XMLCases[$treeChains, Child[XMLPattern[_], {___, XMLPattern[t_], ___, XMLPattern["h2"], ___, XMLPattern[t_], ___}]]},
  {{{"art", "s1", "1"}}, {{"art", "s1", "1"}}, {"3"}, {{"art", "s1"}}, {"1"}, {"y", "7", "z"}},
  TestID -> "many-stage-names-scope-as-nested-as-list"
];

(* Every consumer reads a combinator of many stages as the nested one. XMLMatchQ and the
   "Roles" and "Constructs" rules test one element, so they refuse it as they
   refuse any combinator. *)
TestCreate[
  {HTMLTextContent @ XMLFirstCase[$treeChains, Sibling[XMLPattern["h2"], XMLPattern["p"], XMLPattern["span"]]],
   XMLFirstCase[$treeChains, Descendant[XMLPattern["article", "id" -> a_], XMLPattern["section"], XMLPattern["p"]] :> a],
   HTMLTextContent @ XMLDeleteCases[$treeChains, Child[XMLPattern["body"], XMLPattern["section"], XMLPattern["p"]]],
   HTMLTextContent @ XMLDeleteCases[$treeChains, Descendant[XMLPattern["body"], XMLPattern["div"], XMLPattern["p"]]]},
  {"a", "art", "12h4a5bw6xhy7z", "123habwxhyz"},
  TestID -> "many-stage-in-firstcase-and-deletecases"
];

TestCreate[
  {HTMLTextContent[XMLFirstCase[$treeChains, Child[XMLPattern[_], {___, XMLPattern["h2"], ___, XMLPattern["p"], ___, XMLPattern["span"], ___}]]], XMLFirstCase[$treeChains, Descendant[XMLPattern["article", "id" -> a_], XMLPattern["section"], XMLPattern["p"]] :> a], HTMLTextContent[XMLDeleteCases[$treeChains, Child[XMLPattern["body"], XMLPattern["section"], XMLPattern["p"]]]], HTMLTextContent[XMLDeleteCases[$treeChains, Descendant[XMLPattern["body"], XMLPattern["div"], XMLPattern["p"]]]]},
  {"a", "art", "12h4a5bw6xhy7z", "123habwxhyz"},
  TestID -> "many-stage-in-firstcase-and-deletecases-as-list"
];

(* Sibling is a list stage (ADR 0016), so XMLDeleteCases deletes what it
   selects at any depth. *)
TestCreate[
  HTMLTextContent @ XMLDeleteCases[$treeChains, Descendant[XMLPattern["body"], XMLPattern["div"], Sibling[XMLPattern["p"], XMLPattern["span"]]]],
  "123h45w6h7",
  TestID -> "many-stage-deletecases-sibling"
];

TestCreate[
  HTMLTextContent[XMLDeleteCases[$treeChains, Descendant[XMLPattern["body"], Descendant[XMLPattern["div"], {___, XMLPattern["p"], ___, XMLPattern["span"], ___}]]]],
  "123h45w6h7",
  TestID -> "many-stage-deletecases-sibling-as-list"
];

TestCreate[
  With[{el = XMLElement["p", {}, {"x"}]},
    {XMLMatchQ[el, Descendant[XMLPattern["div"], XMLPattern["section"], XMLPattern["p"]]],
     XMLMatchQ[Descendant[XMLPattern["div"], XMLPattern["section"], XMLPattern["p"]]][el],
     XMLMatchQ[el, Descendant[XMLPattern["div"], XMLPattern["section"], XMLPattern["p"]] /; True],
     HTMLInnerText[el, "Roles" -> {Child[XMLPattern["div"], XMLPattern["div"], XMLPattern["p"]] -> "Skip"}],
     HTMLToNotebook[el, "Constructs" -> {Child[XMLPattern["div"], XMLPattern["div"], XMLPattern["p"]] -> "Bold"}]}],
  {$Failed, $Failed, $Failed, $Failed, $Failed},
  {XMLMatchQ::combinator, XMLMatchQ::combinator, XMLMatchQ::condcombinator, HTMLInnerText::badpat, HTMLToNotebook::badpat},
  TestID -> "many-stage-refused-where-one-element-is-tested"
];

(* A combinator relates at least two stages; with one or none it is refused,
   wherever it is written. *)
TestCreate[
  With[{el = XMLElement["p", {}, {"x"}]},
    {XMLCases[$treeChains, Descendant[XMLPattern["p"]]],
     XMLFirstCase[$treeChains, Child[]],
     XMLDeleteCases[$treeChains, Descendant[XMLPattern["body"], Child[XMLPattern["p"]]]],
     XMLCases[$treeChains, Sibling[XMLPattern["p"]] :> 1],
     XMLMatchQ[el, Adjacent[XMLPattern["p"]]],
     HTMLInnerText[el, "Roles" -> {Descendant[XMLPattern["p"]] -> "Skip"}],
     HTMLToNotebook[el, "Constructs" -> {Child[XMLPattern["p"]] -> "Bold"}]}],
  ConstantArray[$Failed, 7],
  {XMLCases::stages, XMLFirstCase::stages, XMLDeleteCases::stages, XMLCases::stages, XMLMatchQ::stages,
   HTMLInnerText::stages, HTMLToNotebook::stages},
  TestID -> "one-stage-combinator-refused"
];
