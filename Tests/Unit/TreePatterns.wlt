(* Tree patterns and the result rule in XMLCases and XMLFirstCase: the
   examples of the tree-pattern spec, sections 1, 3 and 5, on its fixtures.
   The fixtures are literal trees, so positions are exact. They are local to
   this file. *)

doc[root_] := XMLObject["Document"][{}, root, {}];
e[tag_, id_String, c___] := XMLElement[tag, {"id" -> id}, {c}];
id[x_XMLElement] := Lookup[x[[2]], "id"];
el[tag_, c___] := XMLElement[tag, {}, {c}];
num[x_] := ToExpression[id[x]];

nav     = doc[e["nav", "o", e["a", "a1"], e["nav", "i", e["a", "a2"]], e["a", "a3"]]];
links   = doc[el["p", e["a", "1"], e["a", "2"], e["a", "3"]]];
hrefs   = doc[el["p", XMLElement["a", {"href" -> "/x"}, {}], XMLElement["a", {"href" -> "/x"}, {}]]];
ranks   = doc[el["ul", e["li", "3"], e["li", "1"], e["li", "2"]]];
holiday = doc[el["table", el["tr",
            el["th", XMLElement["time", {"datetime" -> "2026-12-25"}, {"25 December"}]],
            el["td", "Friday"], el["td", "Christmas Day"]]]];
tokens  = doc[XMLElement["p", {"class" -> "lead lead"}, {}]];
paras   = doc[el["div", e["p", "1"], e["p", "2"], e["p", "3"]]];
alt     = doc[el["li", el["a"], el["span"]]];
alt2    = doc[el["li", el["span"], el["a"], el["span"]]];
cells   = doc[el["tr", el["th"], e["td", "a"], e["td", "b"]]];

(* === Section 1: the tree syntax === *)

TestCreate[
  XMLCases[holiday, XMLPattern["tr", _, {XMLPattern["th", _, {XMLPattern["time", "datetime" -> d_]}], ___, n : XMLPattern["td"]}] :>
    {d, HTMLInnerText[n]}],
  {{"2026-12-25", "Christmas Day"}},
  TestID -> "tree-holiday-row"
];

(* A list constraint means what the same list means to MatchQ, over the
   element children. *)
TestCreate[
  XMLCases[links, XMLPattern["p", _, {x : XMLPattern["a"], ___}] :> id[x]],
  {"1"},
  TestID -> "tree-first-child"
];

TestCreate[
  XMLCases[links, XMLPattern["p", _, {___, x : XMLPattern["a"]}] :> id[x]],
  {"3"},
  TestID -> "tree-last-child"
];

TestCreate[
  XMLCases[links, XMLPattern["p", _, {PatternSequence[_, _] ..., x : XMLPattern["a"], ___}] :> id[x]],
  {"1", "3"},
  TestID -> "tree-odd-children"
];

(* Descendant counts DOM depth: {1} is a child. a2 is a child of the inner
   nav; one counted name gives document order. *)
TestCreate[
  XMLCases[nav, XMLPattern["nav", _, Descendant[x : XMLPattern["a"], {1}]] :> id[x]],
  {"a1", "a2", "a3"},
  TestID -> "tree-descendant-level-one"
];

(* Rooting higher: each link once, nested navs included. *)
TestCreate[
  XMLCases[nav, XMLPattern["nav", _, Descendant[x : XMLPattern["a"]]] :> id[x]],
  {"a1", "a2", "a3"},
  TestID -> "tree-descendant-each-once"
];

(* === Section 3: the result rule === *)

(* Equal values at different positions are different results. *)
TestCreate[
  XMLCases[hrefs, XMLPattern["a", "href" -> h_] :> h],
  {"/x", "/x"},
  TestID -> "result-equal-values-different-places"
];

(* Two counted names give every pair. *)
TestCreate[
  XMLCases[links, XMLPattern["p", _, {___, x : XMLPattern["a"], ___, y : XMLPattern["a"], ___}] :> {id[x], id[y]}],
  {{"1", "2"}, {"1", "3"}, {"2", "3"}},
  TestID -> "result-pairs"
];

(* A name the right-hand side does not use is a test. *)
TestCreate[
  XMLCases[links, XMLPattern["p", _, {___, x : XMLPattern["a"], ___, y : XMLPattern["a"], ___}] :> id[x]],
  {"1", "2"},
  TestID -> "result-uncounted-name-is-a-test"
];

(* A Condition relating two names filters, in the pattern or in the
   right-hand side; the uncounted y needs one passing position. *)
TestCreate[
  XMLCases[ranks, (XMLPattern["ul", _, Descendant[x : XMLPattern["li"]], Descendant[y : XMLPattern["li"]]] /; num[x] < num[y]) :> id[x]],
  {"1", "2"},
  TestID -> "result-pattern-condition"
];

TestCreate[
  XMLCases[ranks, XMLPattern["ul", _, Descendant[x : XMLPattern["li"]], Descendant[y : XMLPattern["li"]]] :> id[x] /; num[x] < num[y]],
  {"1", "2"},
  TestID -> "result-rhs-condition"
];

(* Duplicate tokens at different places are different results. *)
TestCreate[
  XMLCases[tokens, XMLPattern["p", "classList" -> {___, c_, ___}] :> c],
  {"lead", "lead"},
  TestID -> "result-duplicate-tokens"
];

(* A named sequence binds a run or a gap: gap 2;;1, run 2;;2, gap 3;;2. *)
TestCreate[
  XMLCases[paras, XMLPattern["div", _, {___, XMLPattern["p"], g___, XMLPattern["p"], ___}] :> {g}],
  {{}, {e["p", "2"]}, {}},
  TestID -> "result-gaps-and-runs"
];

(* A sequence as the whole right-hand side is spliced into the results, as in
   Cases: an empty gap adds nothing, but is still a result for the count. *)
TestCreate[
  With[{q = XMLPattern["div", _, {___, XMLPattern["p"], g___, XMLPattern["p"], ___}] :> g},
    {XMLCases[paras, q], XMLCases[paras, q, 1], XMLCases[paras, q, 2],
      XMLCases[doc[el["div", el["p"], el["b"], el["i"], el["p"]]], q]}],
  {{e["p", "2"]}, {}, {e["p", "2"]}, {el["b"], el["i"]}},
  TestID -> "result-sequence-spliced"
];

(* XMLFirstCase gives the first result as FirstCase does: an empty gap is
   Sequence[]. *)
TestCreate[
  {XMLFirstCase[paras, XMLPattern["div", _, {___, XMLPattern["p"], g___, XMLPattern["p"], ___}] :> g]},
  {},
  TestID -> "first-sequence-spliced"
];

(* A name in a branch that did not match is Sequence[]. *)
TestCreate[
  XMLCases[alt, XMLPattern["li", _, {___, (x : XMLPattern["a"]) | (y : XMLPattern["span"]), ___}] :> {x, y}],
  {{el["a"]}, {el["span"]}},
  TestID -> "result-alternatives-absent-name"
];

(* Through With, an initialiser counts if its variable does. *)
TestCreate[
  XMLCases[hrefs, XMLPattern["a", "href" -> h_] :> With[{u = h}, u]],
  {"/x", "/x"},
  TestID -> "result-with-initialiser-counts"
];

TestCreate[
  XMLCases[hrefs, XMLPattern["a", "href" -> h_] :> With[{u = h}, 1]],
  {1},
  TestID -> "result-with-unused-initialiser-does-not-count"
];

TestCreate[
  XMLCases[links, XMLPattern["p", _, {Except[x : XMLPattern["a"]] ..., ___}] :> x],
  $Failed,
  {XMLCases::exceptname},
  TestID -> "result-except-name-in-rhs"
];

(* A bare pattern gives each match, as Cases does. *)
TestCreate[
  XMLCases[nav, XMLPattern["nav", _, Descendant[XMLPattern["a"]]]],
  {nav[[2]], nav[[2, 3, 2]]},
  TestID -> "result-bare-pattern-each-match"
];

(* No counted names: at most one result. *)
TestCreate[
  {XMLCases[links, XMLPattern["a"] -> 1], XMLCases[doc[el["p"]], XMLPattern["a"] -> 1],
    XMLCases[links, x : XMLPattern["a"] :> 1], XMLCases[links, x : XMLPattern["a"] :> x], XMLCases[links, XMLPattern["a"]]},
  {{1}, {}, {1}, {e["a", "1"], e["a", "2"], e["a", "3"]}, {e["a", "1"], e["a", "2"], e["a", "3"]}},
  TestID -> "result-no-counted-names-one-result"
];

(* The same contrast on a CSS string: naming it does not multiply. *)
TestCreate[
  {XMLCases[hrefs, "a[href]" :> 1], XMLCases[hrefs, n : "a[href]" :> 1], XMLCases[hrefs, n : "a[href]" :> n], XMLCases[hrefs, "a[href]"]},
  {{1}, {1}, hrefs[[2, 3]], hrefs[[2, 3]]},
  TestID -> "result-css-no-counted-names-one-result"
];

(* === Section 5: order === *)

(* Grouped by the first counted name in pattern order, whatever the order in
   the right-hand side. *)
TestCreate[
  XMLCases[nav, n : XMLPattern["nav", _, Descendant[x : XMLPattern["a"]]] :> {id[x], id[n]}],
  {{"a1", "o"}, {"a2", "o"}, {"a3", "o"}, {"a2", "i"}},
  TestID -> "order-grouped-by-first-name"
];

(* The branches of one Alternatives share a slot. *)
TestCreate[
  XMLCases[alt, XMLPattern["li", _, {___, (y : XMLPattern["span"]) | (x : XMLPattern["a"]), ___}] :> {x, y}],
  {{el["a"]}, {el["span"]}},
  TestID -> "order-alternatives-one-slot"
];

TestCreate[
  XMLCases[alt2, XMLPattern["li", _, {___, (x : XMLPattern["a"]) | XMLPattern["span"], ___}] :> {x}],
  {{}, {el["a"]}},
  TestID -> "order-absent-tuple-where-alternatives-matched"
];

(* An uncounted name takes its first passing position. *)
TestCreate[
  Block[{seen}, {XMLCases[cells, XMLPattern["tr", _, {x : XMLPattern["th"], ___}, Descendant[y : XMLPattern["td"]]] :> x /; (seen = y; True)], id[seen]}],
  {{el["th"]}, "a"},
  TestID -> "order-uncounted-first-passing"
];

TestCreate[
  XMLCases[nav, n : XMLPattern["nav", _, Descendant[x : XMLPattern["a"]]] :> {id[n], id[x]}, 2],
  {{"o", "a1"}, {"o", "a2"}},
  TestID -> "order-count"
];

TestCreate[
  XMLFirstCase[nav, n : XMLPattern["nav", _, Descendant[x : XMLPattern["a"]]] :> {id[n], id[x]}],
  {"o", "a1"},
  TestID -> "order-first-case"
];

TestCreate[
  {XMLFirstCase[nav, XMLPattern["table"] :> 1], XMLFirstCase[nav, XMLPattern["table"] :> 1, "none"],
    XMLFirstCase[links, XMLPattern["p", _, {___, x : XMLPattern["a"]}]]},
  {Missing["NotFound"], "none", links[[2]]},
  TestID -> "order-first-case-default"
];

(* === Input kinds === *)

(* A list's elements are the top elements; a bare element is under a virtual
   document, and its own position is never counted. *)
TestCreate[
  {XMLCases[{e["a", "1"], " ", e["a", "2"]}, x : XMLPattern["a"] :> id[x]],
    XMLCases[links[[2]], x : XMLPattern[_] :> id[x]],
    XMLCases[links[[2]], XMLPattern["p", _, {___, x : XMLPattern["a"]}] :> id[x]],
    XMLCases[links[[2]], XMLPattern["p"] -> 1]},
  {{"1", "2"}, {"1", "2", "3"}, {"3"}, {1}},
  TestID -> "input-kinds"
];

(* Text is not a child: a list constraint sees element children only. *)
TestCreate[
  XMLCases[doc[el["p", "text", e["a", "1"], " ", e["a", "2"]]], XMLPattern["p", _, {x : XMLPattern["a"], _}] :> id[x]],
  {"1"},
  TestID -> "list-constraint-skips-text"
];

(* Several constraints hold independently, and _ is any one child. *)
TestCreate[
  {XMLCases[links, XMLPattern["p", _, {_, _, _}, Descendant[XMLPattern["a", "id" -> "2"]]] :> 1],
    XMLCases[links, XMLPattern["p", _, {_, _}] :> 1],
    XMLCases[links, XMLPattern["p", _, {x_, ___}, {___, y_}] :> {id[x], id[y]}]},
  {{1}, {}, {{"1", "3"}}},
  TestID -> "constraints-independent"
];

(* A CSS string that is one element is an entry or a pattern. *)
TestCreate[
  XMLCases[doc[el["ul", XMLElement["li", {"class" -> "x", "id" -> "1"}, {}], e["li", "2"]]],
    XMLPattern["ul", _, {___, x : "li.x", ___}] :> id[x]],
  {"1"},
  TestID -> "css-string-entry"
];

(* Level specs in DOM depth. *)
TestCreate[
  {XMLCases[nav, XMLPattern["nav", _, Descendant[x : XMLPattern["a"], {2}]] :> id[x]],
    XMLCases[nav, XMLPattern["nav", _, Descendant[x : XMLPattern["a"], 1]] :> id[x]],
    XMLCases[nav, XMLPattern["nav", _, Descendant[x : XMLPattern["a"], {1, Infinity}]] :> id[x]]},
  {{"a2"}, {"a1", "a2", "a3"}, {"a1", "a2", "a3"}},
  TestID -> "descendant-level-specs"
];

(* Names on tags, attribute maps and token runs. *)
TestCreate[
  {XMLCases[links, XMLPattern[t_, _, {_, _, _}] :> t],
    XMLCases[hrefs, XMLPattern["a", a_] :> a],
    XMLCases[doc[XMLElement["p", {"class" -> "a b c"}, {}]], XMLPattern["p", "classList" -> {___, "a", r___}] :> {r}]},
  {{"p"}, {{"href" -> "/x"}, {"href" -> "/x"}}, {{"b", "c"}}},
  TestID -> "names-on-tags-attributes-tokens"
];

(* === Messages === *)

TestCreate[
  XMLCases[links, XMLPattern["div", _, XMLPattern["p"]]],
  $Failed,
  {XMLPattern::constraint},
  TestID -> "message-constraint"
];

TestCreate[
  XMLCases[links, XMLPattern["ul", _, {Descendant[XMLPattern["a"]]}]],
  $Failed,
  {XMLPattern::listentry},
  TestID -> "message-listentry-descendant"
];

TestCreate[
  XMLCases[links, XMLPattern["ul", _, {{XMLPattern["a"]}}]],
  $Failed,
  {XMLPattern::listentry},
  TestID -> "message-listentry-list"
];

TestCreate[
  {XMLCases[links, Descendant[XMLPattern["a"]]], XMLCases[links, XMLPattern["a", Descendant[XMLPattern["b"]]]]},
  {$Failed, $Failed},
  {Descendant::place, Descendant::place},
  TestID -> "message-descendant-place"
];

TestCreate[
  {XMLCases[links, XMLPattern["p", _, Descendant[XMLPattern["a"], XMLPattern["b"]]]],
    XMLCases[links, XMLPattern["p", _, Descendant[XMLPattern["a"], {0}]]]},
  {$Failed, $Failed},
  {Descendant::level, Descendant::level},
  TestID -> "message-descendant-level"
];

(* A blank is refused as the whole query and as Descendant's pattern, not as
   a list entry. *)
TestCreate[
  {XMLCases[links, _], XMLCases[links, XMLPattern["p", _, Descendant[_]]], XMLCases[links, XMLPattern["p", _, {_, x_, _}] :> id[x]]},
  {$Failed, $Failed, {"2"}},
  {XMLCases::blank, Descendant::blank},
  TestID -> "message-blank-narrowed"
];


