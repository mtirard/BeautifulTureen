(* Constraints on a CSS selector string: "sel"[c...] is the translation of a
   one-element selector with c... added to each of its pattern roots, in
   their one constraint bracket. The fixtures are literal trees, so results
   and positions are exact. *)

lists = doc[el["body",
  XMLElement["ul", {"id" -> "u1", "class" -> "c"}, {e["li", "f1"], e["li", "m1"], e["li", "l1"]}],
  XMLElement["ul", {"id" -> "u2", "class" -> "c"}, {e["li", "o2"]}],
  XMLElement["ul", {"id" -> "u3"}, {e["li", "f3"], e["li", "l3"]}],
  e["ol", "o1", e["li", "x1"], e["p", "p1", e["a", "a1"]]]]];

(* === Queries === *)

TestCreate[
  Map[id, XMLCases[lists, "ul.c"[{a : "li", ___, b : "li"}] :> {a, b}], {2}],
  {{"f1", "l1"}},
  TestID -> "css-constraints-plain"
];

(* The same results, in the same order, as the translation with the
   constraint written into its bracket. *)
TestCreate[
  XMLCases[lists, "ul.c"[{a : "li", ___, b : "li"}] :> {a, b}] ===
    XMLCases[lists, XMLPattern["ul", "classList" -> "c"][{a : XMLPattern["li"], ___, b : XMLPattern["li"]}] :> {a, b}],
  True,
  TestID -> "css-constraints-plain-hand-merged"
];

(* An empty bracket is the selector alone. *)
TestCreate[
  id /@ XMLCases[lists, "ul.c"[]],
  {"u1", "u2"},
  TestID -> "css-constraints-empty-bracket"
];

(* On a selector list, each selector of the list takes the constraints,
   whether the translation merges the tags or not. *)
TestCreate[
  {id /@ XMLCases[lists, "ul, ol"[{x : "li", ___}] :> x], id /@ XMLCases[lists, "ul.c, #o1"[{_, _}]]},
  {{"f1", "o2", "f3", "x1"}, {"o1"}},
  TestID -> "css-constraints-selector-list"
];

(* On a selector with :has(), its own constraint and the bracket's both hold. *)
TestCreate[
  {id /@ XMLCases[lists, "ul:has(#o2)"[{_}]], id /@ XMLCases[lists, "ul:has(#f1)"[{_}]],
    id /@ XMLCases[lists, "ul:has(> #f3)"[{x_, _}] :> x]},
  {{"u2"}, {}, {"f3"}},
  TestID -> "css-constraints-has"
];

(* Through a test the translation puts on the element. *)
TestCreate[
  id /@ XMLCases[lists, ":not(:has(a))"[{___, "li", ___}]],
  {"u1", "u2", "u3"},
  TestID -> "css-constraints-through-test"
];

(* A name on the whole, and names in the constraints, as anywhere. *)
TestCreate[
  Map[id, XMLCases[lists, u : "ul"[{x : "li"}] :> {u, x}], {2}],
  {{"u2", "o2"}},
  TestID -> "css-constraints-names"
];

(* Nested: as Descendant's pattern and as an entry of a list. *)
TestCreate[
  {id /@ XMLCases[lists, "body"[Descendant[x : "ol"[{___, "p", ___}]]] :> x],
    id /@ XMLCases[lists, "body"[{___, x : "ul"[{_}], ___}] :> x]},
  {{"o1"}, {"u2"}},
  TestID -> "css-constraints-nested"
];

TestCreate[
  {XMLPosition[lists, "ul.c"[{_}]], XMLMatchQ[lists[[2, 3, 2]], "ul.c"[{_}]], XMLMatchQ[lists[[2, 3, 1]], "ul.c"[{_}]],
    XMLFreeQ[lists, "ol"[{_, _, _}]]},
  {{{1, 2}}, True, False, True},
  TestID -> "css-constraints-other-functions"
];

(* FromCSSSelector gives an ordinary XMLPattern, which takes a bracket when
   it has none. *)
TestCreate[
  id /@ XMLCases[lists, FromCSSSelector["ul.c"][{_}]],
  {"u2"},
  TestID -> "css-constraints-fromcssselector-bracket"
];

(* === Random trees === *)

(* "sel"[c...] gives what the translation with c... in the bracket of each
   of its XMLPatterns gives, in the same order. *)
$trees = randomTrees[20261029, 12];

TestCreate[
  AllTrue[$trees, Function[t,
    XMLCases[t, "p.a"[{___, x : "span", ___}] :> x] ===
      XMLCases[t, XMLPattern["p", "classList" -> "a"][{___, x : XMLPattern["span"], ___}] :> x] &&
    XMLCases[t, r : "li.b"[{___, x : "p", ___}, {___, y : "span", ___}] :> {r, x, y}] ===
      XMLCases[t, r : XMLPattern["li", "classList" -> "b"][{___, x : XMLPattern["p"], ___}, {___, y : XMLPattern["span"], ___}] :> {r, x, y}] &&
    XMLCases[t, "p, li.b"[{x : "span", ___}] :> x] ===
      XMLCases[t, (XMLPattern["p"][{x : XMLPattern["span"], ___}] | XMLPattern["li", "classList" -> "b"][{x : XMLPattern["span"], ___}]) :> x] &&
    XMLCases[t, "div:has(> p.c)"[{___, x : "li", ___}] :> x] ===
      XMLCases[t, XMLPattern["div"][{___, XMLPattern["p", "classList" -> "c"], ___}, {___, x : XMLPattern["li"], ___}] :> x] &&
    XMLCases[t, "div:not(:has(span))"[{x : "p", ___}] :> x] ===
      XMLCases[t, XMLPattern["div"][{x : XMLPattern["p"], ___}]?(XMLFreeQ[#, XMLPattern["span"], {1, Infinity}] &) :> x]]],
  True,
  TestID -> "css-constraints-random-hand-merged"
];

(* === Messages === *)

(* The text of a message as it is issued, its arguments in InputForm. *)
SetAttributes[cssMessageTexts, HoldFirst];
cssMessageTexts[expr_] := Module[{texts = {}},
  Internal`HandlerBlock[
    {"Message", Function[m,
      Replace[m, Hold[Message[mn : MessageName[_, _], args___], _] :>
        AppendTo[texts, ToString[
          StringForm[mn, Sequence @@ (List @@ Map[Function[a, ToString[Unevaluated[a], InputForm], HoldAllComplete], Hold[args]])],
          OutputForm, PageWidth -> Infinity]]]]},
    Quiet[expr]];
  texts];

(* A context selector's pattern is rooted at another element than the one it
   selects, so it takes no constraints. *)
TestCreate[
  {XMLCases[lists, "body ul"[{_}]], XMLMatchQ[lists[[2]], "body"[Descendant["body ul"[{_}]]]]},
  {$Failed, $Failed},
  {FromCSSSelector::constraints, FromCSSSelector::constraints},
  TestID -> "css-constraints-message-context"
];

TestCreate[
  cssMessageTexts[XMLCases[lists, "body ul"[{_}]]],
  {"\"body ul\"[{_}] gives constraints to \"body ul\", which depends on what is above or beside its element. Only a selector for one element takes constraints. Nest the selectors as the tree is, as in \"nav\"[Descendant[x : \"a\"[c]]] :> x."},
  TestID -> "css-constraints-message-context-text"
];

(* Several constraints are the arguments of one bracket. *)
TestCreate[
  {XMLCases[lists, "ul"[{_}][Descendant["a"]]], XMLCases[lists, FromCSSSelector["ul:has(#o2)"][{_}]]},
  {$Failed, $Failed},
  {XMLPattern::chain, XMLPattern::chain},
  TestID -> "css-constraints-message-chain"
];

TestCreate[
  cssMessageTexts[XMLCases[lists, "ul"[{_}][][Descendant["a"]]]],
  {"\"ul\"[{_}][][Descendant[\"a\"]] gives constraints in more than one bracket. Several constraints are the arguments of one bracket: \"ul\"[{_}, Descendant[\"a\"]]."},
  TestID -> "css-constraints-message-chain-text"
];

(* A bracket on the FromCSSSelector result of a selector list, alternatives,
   or on one with a test, would constrain no one XMLPattern. *)
TestCreate[
  {XMLCases[lists, FromCSSSelector["ul.c, #o1"][{_}]], XMLMatchQ[lists[[2]], FromCSSSelector[":not(:has(a))"][{_}]]},
  {$Failed, $Failed},
  {XMLPattern::bracket, XMLPattern::bracket},
  TestID -> "css-constraints-message-bracket"
];

TestCreate[
  cssMessageTexts[XMLCases[lists, FromCSSSelector["ul.c, #o1"][{_}]]],
  {"(XMLPattern[\"ul\", \"classList\" -> \"c\"] | XMLPattern[_, \"id\" -> \"o1\"])[{_}] gives constraints to alternatives or a test, not to an XMLPattern. Constraints go in the bracket of each XMLPattern: XMLPattern[\"ul\", \"classList\" -> \"c\"][{_}] | XMLPattern[_, \"id\" -> \"o1\"][{_}]. For a pattern from FromCSSSelector[\"selector\"], give them to the selector string instead, as in \"selector\"[c1, c2, ...]."},
  TestID -> "css-constraints-message-bracket-text"
];
