(* XMLPosition and XMLExtract: positions of every kind, position order and
   the round trip through XMLExtract. The fixtures are literal trees, so
   positions are exact. *)

nav     = doc[e["nav", "o", e["a", "a1"], e["nav", "i", e["a", "a2"]], e["a", "a3"]]];
tokens  = doc[XMLElement["p", {"class" -> "lead lead"}, {}]];
listing = doc[XMLElement["ul", {"class" -> "a b"}, {el["li"], " ", el["li", XMLElement["a", {"href" -> "/x"}, {}]]}]];

(* === XMLPosition === *)

(* A bare pattern gives the positions of its pattern root's matches. *)
TestCreate[
  XMLPosition[nav, XMLPattern["nav"][Descendant[XMLPattern["a"]]]],
  {{1}, {1, 2}},
  TestID -> "position-bare"
];

(* A rule gives its right-hand side with each counted name replaced by its
   position, one per result, in result order. *)
TestCreate[
  XMLPosition[nav, n : XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> {n, x}],
  {{{1}, {1, 1}}, {{1}, {1, 2, 1}}, {{1}, {1, 3}}, {{1, 2}, {1, 2, 1}}},
  TestID -> "position-rule-tuples"
];

TestCreate[
  {XMLPosition[listing, XMLPattern["a", "href" -> h_] :> h],
    XMLPosition[tokens, XMLPattern["p", "classList" -> {___, c_, ___}] :> c]},
  {{{1, 2, 1, Key["href"]}}, {{1, Key["classList"], 1}, {1, Key["classList"], 2}}},
  TestID -> "position-attribute-and-token"
];

(* A counted path is replaced by its span upper ;; lower. *)
TestCreate[
  XMLPosition[nav, XMLPattern["nav"][p : Descendant[XMLPattern["a"]]] :> p],
  {{1} ;; {1, 1}, {1} ;; {1, 2, 1}, {1, 2} ;; {1, 2, 1}, {1} ;; {1, 3}},
  TestID -> "position-path-span"
];

(* A Condition on the right-hand side tests the values; the result gives the
   positions. A name in an Alternatives branch that did not match is absent. *)
TestCreate[
  {XMLPosition[nav, XMLPattern["a", "id" -> i_] :> i /; i =!= "a2"],
    XMLPosition[nav, XMLPattern["nav"][{___, (x : XMLPattern["nav"]) | (y : XMLPattern["a", "id" -> "a3"]), ___}] :> {x, y}]},
  {{{1, 1, Key["id"]}, {1, 3, Key["id"]}}, {{{1, 2}}, {{1, 3}}}},
  TestID -> "position-rhs-condition-and-alternatives"
];

(* === Position order === *)

(* The reference order, pinned through one query: each branch of an
   Alternatives at the pattern root binds one kind of position, and the
   branches share one slot, ordered by the position each binds. The contents
   positions {1, All} and {1, 1, All} are bound by an XMLElement pattern's
   contents slot. *)
TestCreate[
  Join @@ XMLPosition[doc[XMLElement["p", {"id" -> "i", "class" -> "a b"}, {el["b"]}]],
    (x : XMLPattern["p"]) | XMLPattern[t : "p", _] | XMLPattern["p", a_] | XMLPattern["p", "id" -> v_] |
      XMLPattern["p", "class" -> w_] | XMLPattern["p", "classList" -> l_] |
      XMLPattern["p", "classList" -> {___, k___, ___}] | XMLPattern["p", "classList" -> {___, tk_, ___}] |
      XMLElement["p", _, ct_] | XMLPattern["p"][{___, g___, ___}] | XMLPattern["p"][{c_}] |
      XMLPattern["p"][{XMLPattern[bt : "b", _]}] | XMLPattern["p"][{XMLPattern["b", ba_]}] |
      XMLPattern["p"][{XMLElement["b", _, bc_]}] | XMLPattern["p"][{XMLPattern["b"][{bg___}]}] :>
      {x, t, a, v, w, l, k, tk, ct, g, c, bt, ba, bc, bg}],
  {{1}, {1, 0}, {1, Key[All]}, {1, Key["id"]}, {1, Key["class"]}, {1, Key["classList"]},
    {1, Key["classList"], 1 ;; 0}, {1, Key["classList"], 1 ;; 2}, {1, Key["classList"], 1 ;; 1}, {1, Key["classList"], 1},
    {1, Key["classList"], 2 ;; 1}, {1, Key["classList"], 2 ;; 2}, {1, Key["classList"], 2}, {1, Key["classList"], 3 ;; 2},
    {1, All}, {1, 1 ;; 0}, {1, 1 ;; 1},
    {1, 1}, {1, 1, 0}, {1, 1, Key[All]}, {1, 1, All}, {1, 1, 1 ;; 0},
    {1, 2 ;; 1}},
  TestID -> "position-reference-order"
];

(* === Names in the tag and attributes === *)

(* Elements that share a tag and attributes, at different depths and one
   inside another, bind the same values at positions of their own. *)
shared = doc[XMLElement["div", {"class" -> "a b", "id" -> "x"}, {
  XMLElement["div", {"class" -> "a b", "id" -> "x"}, {XMLElement["div", {"class" -> "a b", "id" -> "x"}, {}]}],
  XMLElement["div", {"class" -> "b", "id" -> "b"}, {}]}]];

TestCreate[
  {XMLCases[shared, XMLPattern["div", "classList" -> {___, c_, ___}] :> c],
    XMLPosition[shared, XMLPattern["div", "classList" -> {___, c_, ___}] :> c]},
  {{"a", "b", "a", "b", "a", "b", "b"},
    {{1, Key["classList"], 1}, {1, Key["classList"], 2}, {1, 1, Key["classList"], 1}, {1, 1, Key["classList"], 2},
      {1, 1, 1, Key["classList"], 1}, {1, 1, 1, Key["classList"], 2}, {1, 2, Key["classList"], 1}}},
  TestID -> "position-head-tokens-shared-heads"
];

TestCreate[
  {XMLCases[shared, XMLPattern["div", "classList" -> c_] :> c],
    XMLPosition[shared, XMLPattern[t_, a_] :> {t, a}]},
  {{{"a", "b"}, {"a", "b"}, {"a", "b"}, {"b"}},
    {{{1, 0}, {1, Key[All]}}, {{1, 1, 0}, {1, 1, Key[All]}}, {{1, 1, 1, 0}, {1, 1, 1, Key[All]}}, {{1, 2, 0}, {1, 2, Key[All]}}}},
  TestID -> "position-head-tag-and-attributes-shared-heads"
];

(* A name on the element beside one in its attributes; a name repeated over
   two attributes, which has a position in each. *)
TestCreate[
  {XMLCases[shared, x : XMLPattern["div", {"id" -> "x", "class" -> c_}] :> {Length[x[[3]]], c}],
    XMLPosition[shared, x : XMLPattern["div", {"id" -> "x", "class" -> c_}] :> {x, c}],
    XMLPosition[shared, XMLPattern["div", {"class" -> v_, "id" -> v_}] :> v]},
  {{{2, "a b"}, {1, "a b"}, {0, "a b"}},
    {{{1}, {1, Key["class"]}}, {{1, 1}, {1, 1, Key["class"]}}, {{1, 1, 1}, {1, 1, 1, Key["class"]}}},
    {{{1, 2, Key["class"]}, {1, 2, Key["id"]}}}},
  TestID -> "position-head-element-and-repeated-names"
];

(* A Condition on the attribute names, and a count. *)
TestCreate[
  {XMLCases[shared, XMLPattern["div", {"classList" -> c_, "id" -> i_}] /; MemberQ[c, "b"] && i =!= "x" :> i],
    XMLCases[shared, XMLPattern["div", "classList" -> {___, c_, ___}] :> c, 3]},
  {{"b"}, {"a", "b", "a"}},
  TestID -> "head-names-condition-and-count"
];

(* A query in a right-hand side indexes its own input; what the outer query
   read of its input is not kept for that one. *)
TestCreate[
  Module[{p2 = XMLElement["p", {"class" -> "b"}, {el["i"], XMLElement["b", {"class" -> "r"}, {}]}]},
    XMLCases[doc[el["body", el["div", XMLElement["p", {"class" -> "a"}, {XMLElement["b", {"class" -> "q"}, {}]}], p2]]],
      e : XMLPattern["p", "class" -> c_] :> XMLPosition[e, XMLPattern["b", "class" -> k_] :> k]];
    XMLPosition[p2, XMLPattern["b"]]],
  {{1, 2}},
  TestID -> "position-after-nested-query"
];

(* === XMLExtract === *)

TestCreate[
  {XMLExtract[listing, {}], XMLExtract[listing, {1}], XMLExtract[listing, {1, 0}],
    XMLExtract[listing, {1, Key["class"]}], XMLExtract[listing, {1, Key["classList"], 2}],
    XMLExtract[listing, {1, 2}], XMLExtract[listing, {1, 2, 1, Key["href"]}],
    {XMLExtract[listing, {1, 2 ;; 1}]}, XMLExtract[listing, {1, All}],
    XMLExtract[listing, {{1, 0}, {1, Key["class"]}}]},
  {listing, listing[[2]], "ul", "a b", "b", el["li", XMLElement["a", {"href" -> "/x"}, {}]], "/x",
    {}, {el["li"], " ", el["li", XMLElement["a", {"href" -> "/x"}, {}]]}, {"ul", "a b"}},
  TestID -> "extract-kinds"
];

TestCreate[XMLExtract[listing, {1, 3}], $Failed, {XMLExtract::nopos}, TestID -> "extract-nopos"];
TestCreate[XMLExtract[listing, {0}], $Failed, {XMLExtract::pos}, TestID -> "extract-pos"];

(* At the document only contents, runs and gaps apply; nothing follows a
   terminal except the tail after a list key. *)
TestCreate[
  {XMLExtract[listing, {Key[All]}], XMLExtract[listing, {Key["class"]}], XMLExtract[listing, {1, 0, 1}],
    XMLExtract[listing, {1, Key["class"], 1}], XMLExtract[listing, {1, 2 ;; 0}], XMLExtract[listing, {-1}],
    XMLExtract[listing, {1, Key[3]}], XMLExtract[listing, 1 ;; 2], XMLExtract[listing, {{1}, 2}]},
  ConstantArray[$Failed, 9],
  {XMLExtract::pos, XMLExtract::pos, XMLExtract::pos, General::stop},
  TestID -> "extract-pos-grammar"
];

TestCreate[
  {XMLExtract[listing, {1, Key["classList"], 3}], XMLExtract[listing, {1, Key["id"]}], XMLExtract[listing, {1, 4 ;; 3}],
    XMLExtract[listing, {{1}, {2}}]},
  ConstantArray[$Failed, 4],
  {XMLExtract::nopos, XMLExtract::nopos, XMLExtract::nopos, General::stop},
  TestID -> "extract-nopos-kinds"
];

(* The document of a bare element e is {e}, with e at {1}; a list input is
   its own document, with text in its contents. Runs, gaps and the token
   tails after a list key. *)
TestCreate[
  {XMLExtract[listing[[2]], {}], XMLExtract[listing[[2]], {1}], XMLExtract[{" ", el["a"], el["b"]}, {}],
    XMLExtract[{" ", el["a"], el["b"]}, {All}], {XMLExtract[{" ", el["a"], el["b"]}, {1 ;; 2}]},
    XMLExtract[{" ", el["a"], el["b"]}, {2, 0}], XMLExtract[listing, {1, Key["classList"]}],
    {XMLExtract[listing, {1, Key["classList"], 1 ;; 2}]}, {XMLExtract[listing, {1, Key["classList"], 3 ;; 2}]},
    XMLExtract[listing, {1, Key[All]}], XMLExtract[listing, {1, 1, Key["classList"]}]},
  {{listing[[2]]}, listing[[2]], {" ", el["a"], el["b"]}, {" ", el["a"], el["b"]}, {el["a"], el["b"]},
    "b", {"a", "b"}, {"a", "b"}, {}, {"class" -> "a b"}, {}},
  TestID -> "extract-documents-runs-and-tokens"
];

(* The "AttributeReadings" option reads list keys, as in XMLCases. *)
TestCreate[
  With[{t = doc[XMLElement["a", {"rel" -> "x y"}, {}]], r = <|"rel" -> <||>|>},
    {XMLPosition[t, XMLPattern["a", "relList" -> {___, k_}] :> k, "AttributeReadings" -> r],
      XMLExtract[t, {1, Key["relList"], 2}, "AttributeReadings" -> r]}],
  {{{1, Key["relList"], 2}}, "y"},
  TestID -> "attribute-readings"
];

TestCreate[
  {XMLExtract[5, {}], XMLPosition[5, XMLPattern["a"]], XMLExtract[{el["a"], 5}, {}]},
  {$Failed, $Failed, $Failed},
  {XMLExtract::badtree, XMLPosition::badtree, XMLExtract::badmember},
  TestID -> "bad-tree"
];

TestCreate[
  {XMLPosition[nav], XMLExtract[nav, {}, 3]},
  {XMLPosition[nav], XMLExtract[nav, {}, 3]},
  {XMLExtract::argrx},
  TestID -> "argument-count"
];

(* A path span gives the elements strictly between its ends, outermost first. *)
TestCreate[
  {XMLExtract[nav, {1} ;; {1, 2, 1}], XMLExtract[nav, {1} ;; {1, 1}], XMLExtract[nav, {} ;; {1, 2, 1}],
    XMLExtract[nav, {{1, 3}, {1} ;; {1, 2, 1}}]},
  {{nav[[2, 3, 2]]}, {}, {nav[[2]], nav[[2, 3, 2]]}, {nav[[2, 3, 3]], {nav[[2, 3, 2]]}}},
  TestID -> "extract-path-span"
];

TestCreate[
  {XMLExtract[nav, {1, 1} ;; {1, 2, 1}], XMLExtract[nav, {1, 0} ;; {1, 2, 1}], XMLExtract[nav, {1} ;; {1, 4}]},
  {$Failed, $Failed, $Failed},
  {XMLExtract::pos, XMLExtract::pos, XMLExtract::nopos},
  TestID -> "extract-path-span-refused"
];

(* XMLExtract at the positions XMLPosition gives is what XMLCases gives. *)
TestCreate[
  {With[{q = XMLPattern["nav"][p : Descendant[XMLPattern["a"]]] :> p}, (XMLExtract[nav, #] &) /@ XMLPosition[nav, q] === XMLCases[nav, q]],
    With[{p = XMLPattern["nav"][Descendant[XMLPattern["a"]]]}, XMLExtract[nav, XMLPosition[nav, p]] === XMLCases[nav, p]]},
  {True, True},
  TestID -> "extract-round-trip-examples"
];

(* === Round trips on random trees === *)

(* Each random tree as a bare element, whose own position {1} is never a
   result and whose document's value is {tree}, and as a document, whose root
   element can be. Most elements below the root have no children, so the
   root is where most contents-list and path queries match. *)
$roundTripTrees = Join[#, doc /@ #] & @ randomTrees[10, 2];

(* Bare patterns, and rules whose right-hand side is one counted name or
   path. *)
$roundTripPatterns = {XMLPattern["p"], "li.b", XMLPattern["div", "classList" -> {___, "a", ___}],
  XMLPattern["div"][{___, XMLPattern["p"], ___}], XMLPattern["p"][{}],
  XMLPattern["div"][Descendant[XMLPattern["span", "classList" -> "c"]]],
  XMLPattern["li"] | XMLPattern["span"][{_, ___}], XMLDocument[{___, XMLPattern["div"], ___}]};

$roundTripRules = {XMLPattern["div"][p : Descendant[XMLPattern["span"]]] :> p,
  XMLDocument[p : Descendant[XMLPattern["li", "classList" -> "a"]]] :> p,
  XMLPattern["div"][{___, x : XMLPattern["p"], ___}] :> x,
  n : XMLPattern["div"][Shortest @ Descendant[XMLPattern["li"]]] :> n,
  XMLPattern["li", "class" -> c_] :> c,
  XMLPattern["div", "classList" -> {___, c_, ___}] :> c,
  XMLPattern[t_][{}] :> t,
  XMLPattern["span", a_] :> a,
  XMLPattern["div", "id" -> i_][Descendant[XMLPattern["p"], {2}]] :> i};

(* A bare pattern's positions extract to its matches. No positions, {}, is
   the document's position, as Extract[expr, {}] is expr, so it is compared
   as such. *)
TestCreate[
  Table[With[{ps = XMLPosition[t, p]}, If[ps === {}, {}, XMLExtract[t, ps]] === XMLCases[t, p]],
    {t, $roundTripTrees}, {p, $roundTripPatterns}],
  ConstantArray[True, {4, 8}],
  TestID -> "extract-round-trip-bare"
];

(* A rule's positions each extract to its result. *)
TestCreate[
  Table[(XMLExtract[t, #] &) /@ XMLPosition[t, q] === XMLCases[t, q],
    {t, $roundTripTrees}, {q, $roundTripRules}],
  ConstantArray[True, {4, 9}],
  TestID -> "extract-round-trip-rules"
];

(* XMLFirstCase gives the first result XMLCases gives, whenever there is
   one. *)
TestCreate[
  Table[With[{r = XMLCases[t, q, 1]}, r === {} || XMLFirstCase[t, q] === First[r]],
    {t, $roundTripTrees}, {q, Join[$roundTripPatterns, $roundTripRules]}],
  ConstantArray[True, {4, 17}],
  TestID -> "first-case-is-first-result"
];
