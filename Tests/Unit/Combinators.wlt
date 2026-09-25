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
  {XMLCases[$treeTwice, Sibling[e : XMLPattern["p", "classList" -> "a"], e : XMLPattern["p"]] :> e],
   HTMLTextContent /@ XMLCases[$treeTwice,
     Adjacent[XMLPattern["p", as : {"classList" -> _}], XMLPattern["p", as : {"class" -> _}]]],
   XMLFirstCase[$treeTwice,
     Adjacent[XMLPattern["p", as : {"classList" -> _}], XMLPattern["p", as : {"class" -> _}]] :> as]},
  {{XMLElement["p", {"class" -> "a"}, {"1"}]}, {"2", "1"}, {"class" -> "a"}},
  TestID -> "element-and-attrs-name-at-two-stages-is-one-value"
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

(* Results come in the order a base XMLCases gives the last-stage elements,
   not grouped by the earlier stages' matches. The first h2's next sibling, the
   section, holds the second h2 and its next sibling, the p "2". *)
$treeOrder = ImportString[
  "<div><h2>A</h2><section><h2>B</h2><p>2</p></section><p>3</p></div>",
  {"HTML", "XMLObject"}];

TestCreate[
  {HTMLTextContent /@ XMLCases[$treeOrder, Adjacent[XMLPattern["h2"], XMLPattern[_]]],
   XMLCases[$treeOrder, Sibling[XMLPattern["h2"], x : XMLPattern[_]] :> HTMLTextContent[x]],
   HTMLTextContent @ XMLFirstCase[$treeOrder, Adjacent[XMLPattern["h2"], XMLPattern[_]]],
   XMLFirstCase[$treeOrder, Sibling[XMLPattern["h2"], x : XMLPattern[_]] :> HTMLTextContent[x]]},
  {{"2", "B2"}, {"2", "B2", "3"}, "2", "2"},
  TestID -> "combinator-results-in-document-order"
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
   XMLDeleteCases[$treeFor, Adjacent[XMLPattern["p"], XMLPattern["p"]] /; True]},
  {"2", {"2"}, $Failed},
  {XMLDeleteCases::unsupported},
  TestID -> "firstcase-and-deletecases-combinator-test"
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
