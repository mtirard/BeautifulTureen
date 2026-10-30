(* Tree patterns and the result rule in XMLCases and XMLFirstCase: the
   nesting of patterns (ADR 0023), and one result per tuple of positions of
   the counted names, in result order (ADR 0024). The fixtures are literal
   trees, so positions are exact. *)

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
  XMLCases[holiday, XMLPattern["tr"][{XMLPattern["th"][{XMLPattern["time", "datetime" -> d_]}], ___, n : XMLPattern["td"]}] :>
    {d, HTMLInnerText[n]}],
  {{"2026-12-25", "Christmas Day"}},
  TestID -> "tree-holiday-row"
];

(* A list constraint means what the same list means to MatchQ, over the
   element children. *)
TestCreate[
  XMLCases[links, XMLPattern["p"][{x : XMLPattern["a"], ___}] :> id[x]],
  {"1"},
  TestID -> "tree-first-child"
];

TestCreate[
  XMLCases[links, XMLPattern["p"][{___, x : XMLPattern["a"]}] :> id[x]],
  {"3"},
  TestID -> "tree-last-child"
];

TestCreate[
  XMLCases[links, XMLPattern["p"][{PatternSequence[_, _] ..., x : XMLPattern["a"], ___}] :> id[x]],
  {"1", "3"},
  TestID -> "tree-odd-children"
];

(* Descendant counts DOM depth: {1} is a child. a2 is a child of the inner
   nav; one counted name gives document order. *)
TestCreate[
  XMLCases[nav, XMLPattern["nav"][Descendant[x : XMLPattern["a"], {1}]] :> id[x]],
  {"a1", "a2", "a3"},
  TestID -> "tree-descendant-level-one"
];

(* Rooting higher: each link once, nested navs included. *)
TestCreate[
  XMLCases[nav, XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> id[x]],
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
  XMLCases[links, XMLPattern["p"][{___, x : XMLPattern["a"], ___, y : XMLPattern["a"], ___}] :> {id[x], id[y]}],
  {{"1", "2"}, {"1", "3"}, {"2", "3"}},
  TestID -> "result-pairs"
];

(* A name the right-hand side does not use is a test. *)
TestCreate[
  XMLCases[links, XMLPattern["p"][{___, x : XMLPattern["a"], ___, y : XMLPattern["a"], ___}] :> id[x]],
  {"1", "2"},
  TestID -> "result-uncounted-name-is-a-test"
];

(* A Condition relating two names filters, in the pattern or in the
   right-hand side; the uncounted y needs one passing position. *)
TestCreate[
  XMLCases[ranks, (XMLPattern["ul"][Descendant[x : XMLPattern["li"]], Descendant[y : XMLPattern["li"]]] /; num[x] < num[y]) :> id[x]],
  {"1", "2"},
  TestID -> "result-pattern-condition"
];

TestCreate[
  XMLCases[ranks, XMLPattern["ul"][Descendant[x : XMLPattern["li"]], Descendant[y : XMLPattern["li"]]] :> id[x] /; num[x] < num[y]],
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
  XMLCases[paras, XMLPattern["div"][{___, XMLPattern["p"], g___, XMLPattern["p"], ___}] :> {g}],
  {{}, {e["p", "2"]}, {}},
  TestID -> "result-gaps-and-runs"
];

(* A sequence as the whole right-hand side is spliced into the results, as in
   Cases: an empty gap adds nothing, but is still a result for the count. *)
TestCreate[
  With[{q = XMLPattern["div"][{___, XMLPattern["p"], g___, XMLPattern["p"], ___}] :> g},
    {XMLCases[paras, q], XMLCases[paras, q, 1], XMLCases[paras, q, 2],
      XMLCases[doc[el["div", el["p"], el["b"], el["i"], el["p"]]], q]}],
  {{e["p", "2"]}, {}, {e["p", "2"]}, {el["b"], el["i"]}},
  TestID -> "result-sequence-spliced"
];

(* XMLFirstCase gives the first result as FirstCase does: an empty gap is
   Sequence[]. *)
TestCreate[
  {XMLFirstCase[paras, XMLPattern["div"][{___, XMLPattern["p"], g___, XMLPattern["p"], ___}] :> g]},
  {},
  TestID -> "first-sequence-spliced"
];

(* A name in a branch that did not match is Sequence[]. *)
TestCreate[
  XMLCases[alt, XMLPattern["li"][{___, (x : XMLPattern["a"]) | (y : XMLPattern["span"]), ___}] :> {x, y}],
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
  XMLCases[links, XMLPattern["p"][{Except[x : XMLPattern["a"]] ..., ___}] :> x],
  $Failed,
  {XMLCases::exceptname},
  TestID -> "result-except-name-in-rhs"
];

(* A bare pattern gives each match, as Cases does. *)
TestCreate[
  XMLCases[nav, XMLPattern["nav"][Descendant[XMLPattern["a"]]]],
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

(* === Condition scope ===

   A Condition sees only the names bound inside the pattern it wraps, as in
   WL, where MatchQ[{1, {2}}, {a_, {b_} /; b > a}] is False. A name it
   cannot see is an unbound symbol: bound[x] is False for it, with no
   message. A test relating names bound in different places goes on a
   pattern that contains them, or in the rule's body. *)

bound[v_] := !MatchQ[v, _Symbol];

scoped = doc[XMLElement["ul", {"class" -> "a"}, {e["li", "1"], e["li", "2"]}]];

(* Not a name bound in an ancestor, its attributes or its name. *)
TestCreate[
  {XMLCases[scoped, XMLPattern["ul", "class" -> c_][Child[x : XMLPattern["li"] /; bound[c]]] :> id[x]],
    XMLCases[scoped, u : XMLPattern["ul"][Child[x : XMLPattern["li"] /; bound[u]]] :> id[x]],
    XMLCases[scoped, XMLPattern["ul", "class" -> c_][Child[x : XMLPattern["li"]] /; bound[c]] :> id[x]]},
  {{}, {}, {}},
  TestID -> "condition-scope-not-ancestor"
];

TestCreate[
  {XMLCases[scoped, (XMLPattern["ul", "class" -> c_][Child[x : XMLPattern["li"]]] /; bound[c]) :> id[x]],
    XMLCases[scoped, (u : XMLPattern["ul"][Child[x : XMLPattern["li"]]]) /; bound[u] && bound[x] :> id[x]],
    XMLCases[scoped, XMLPattern["ul", "class" -> c_][Child[x : XMLPattern["li"]]] :> id[x] /; bound[c]]},
  {{"1", "2"}, {"1", "2"}, {"1", "2"}},
  TestID -> "condition-scope-containing-pattern"
];

(* Not a name bound in a sibling constraint, on a pattern inside the
   constraint or on the constraint; a constraint's Condition sees its own. *)
TestCreate[
  {XMLCases[scoped, XMLPattern["ul"][Descendant[x : XMLPattern["li"]], Descendant[y : XMLPattern["li"] /; bound[x]]] :> id[y]],
    XMLCases[scoped, XMLPattern["ul"][Descendant[x : XMLPattern["li"]], Descendant[y : XMLPattern["li"]] /; bound[x]] :> id[y]],
    XMLCases[scoped, XMLPattern["ul"][{x : XMLPattern["li"], ___}, {___, y : XMLPattern["li"]} /; bound[x]] :> id[y]],
    XMLCases[scoped, XMLPattern["ul"][Descendant[x : XMLPattern["li"]], Descendant[y : XMLPattern["li"]] /; bound[y]] :> id[y]],
    XMLCases[scoped, XMLPattern["ul"][Descendant[x : XMLPattern["li"]], (p : Descendant[y : XMLPattern["li"]]) /; bound[p] && bound[y]] :> id[y]]},
  {{}, {}, {}, {"1", "2"}, {"1", "2"}},
  TestID -> "condition-scope-not-sibling-constraint"
];

TestCreate[
  XMLCases[scoped, (XMLPattern["ul"][Descendant[x : XMLPattern["li"]], Descendant[y : XMLPattern["li"]]] /; bound[x]) :> id[y]],
  {"1", "2"},
  TestID -> "condition-scope-sibling-constraint-on-containing"
];

(* Not a name bound in an earlier entry of the same list, on an entry or on
   a sequence; a Condition on the list sees both. *)
TestCreate[
  {XMLCases[scoped, XMLPattern["ul"][{x : XMLPattern["li"], y : XMLPattern["li"] /; bound[x]}] :> id[y]],
    XMLCases[scoped, XMLPattern["ul"][{x : XMLPattern["li"], s__ /; bound[x]}] :> 1],
    XMLCases[scoped, XMLPattern["ul"][{x : XMLPattern["li"], y : XMLPattern["li"]} /; bound[x]] :> id[y]],
    XMLCases[scoped, XMLPattern["ul"][{x : XMLPattern["li"], y : XMLPattern["li"]}] :> id[y] /; bound[x]]},
  {{}, {}, {"2"}, {"2"}},
  TestID -> "condition-scope-not-earlier-entry"
];

(* The same in an element test, and in a "Roles" key, whose element tests
   are plain WL patterns. *)
TestCreate[
  {XMLMatchQ[scoped[[2]], XMLPattern["ul", "class" -> c_][Child[XMLPattern["li"] /; bound[c]]]],
    XMLMatchQ[scoped[[2]], XMLPattern["ul", "class" -> c_][Child[XMLPattern["li"]]] /; bound[c]],
    XMLFreeQ[scoped, XMLPattern["ul"][{x : XMLPattern["li"], XMLPattern["li"] /; bound[x]}]],
    XMLFreeQ[scoped, XMLPattern["ul"][{x : XMLPattern["li"], XMLPattern["li"]} /; bound[x]]]},
  {False, True, True, False},
  TestID -> "condition-scope-element-tests"
];

TestCreate[
  With[{page = doc[el["body", XMLElement["nav", {"class" -> "a", "role" -> "menu"}, {el["a", "Home"]}], el["p", "Text"]]]},
    HTMLInnerText[page, "Roles" -> {#}] & /@ {
      XMLPattern["nav", "class" -> c_][Child[XMLPattern["a"] /; bound[c]]] -> "Skip",
      (XMLPattern["nav", "class" -> c_][Child[XMLPattern["a"]]] /; bound[c]) -> "Skip",
      XMLPattern["nav", {"class" -> c_ /; bound[r], "role" -> r_}] -> "Skip",
      (XMLPattern["nav", {"class" -> c_, "role" -> r_}] /; bound[r]) -> "Skip"}],
  {"Home\nText", "Text", "Home\nText", "Text"},
  TestID -> "condition-scope-roles-keys"
];

(* "Constructs" keys too: a test on the inner pattern leaves p a plain
   paragraph, one on the containing pattern makes it a Section. *)
TestCreate[
  With[{page = doc[el["body", XMLElement["p", {"class" -> "a"}, {el["b", "Hi"]}]]]},
    ExportString[HTMLToNotebook[page, "Constructs" -> {#}], "Markdown"] & /@ {
      XMLPattern["p", "class" -> c_][Child[XMLPattern["b"] /; bound[c]]] -> "Section",
      (XMLPattern["p", "class" -> c_][Child[XMLPattern["b"]]] /; bound[c]) -> "Section"}],
  {"**Hi**", "### **Hi**"},
  TestID -> "condition-scope-constructs-keys"
];

(* Inside an Except, as in WL: a test there does not see a name bound
   before the Except, but sees one bound inside it, and a test on the list
   sees the names of its entries. *)
TestCreate[
  {XMLCases[scoped, XMLPattern["ul"][{x : XMLPattern["li"], Except[XMLPattern["li"] /; bound[x]]}] :> id[x]],
    XMLCases[scoped, XMLPattern["ul"][{x : XMLPattern["li"], Except[y : XMLPattern["li"] /; bound[y]]}] :> id[x]],
    XMLCases[scoped, XMLPattern["ul"][{x : XMLPattern["li"], Except[XMLPattern["p"]]} /; bound[x]] :> id[x]],
    MatchQ[{1, 2}, #] & /@ {{x_, Except[_ /; bound[x]]}, {x_, Except[y_ /; bound[y]]}, {x_, Except[_String]} /; bound[x]}},
  {{"1"}, {}, {"1"}, {True, False, True}},
  TestID -> "condition-scope-except"
];

(* The same through the other query functions and HTMLToTree. *)
TestCreate[
  {XMLFirstCase[scoped, XMLPattern["ul", "class" -> c_][Child[x : XMLPattern["li"] /; bound[c]]] :> id[x]],
    XMLFirstCase[scoped, (XMLPattern["ul", "class" -> c_][Child[x : XMLPattern["li"]]] /; bound[c]) :> id[x]],
    XMLPosition[scoped, XMLPattern["ul", "class" -> c_][Child[XMLPattern["li"] /; bound[c]]]],
    XMLPosition[scoped, XMLPattern["ul", "class" -> c_][Child[XMLPattern["li"]]] /; bound[c]]},
  {Missing["NotFound"], "1", {}, {{1}}},
  TestID -> "condition-scope-first-case-position"
];

TestCreate[
  {XMLDeleteCases[scoped, XMLPattern["ul", "class" -> c_][Child[x : XMLPattern["li"] /; bound[c]]] :> x],
    XMLDeleteCases[scoped, (XMLPattern["ul", "class" -> c_][Child[x : XMLPattern["li"]]] /; bound[c]) :> x],
    XMLReplace[scoped, XMLPattern["ul", "class" -> c_][Child[x : XMLPattern["li"] /; bound[c]]] :> (x -> el["li"])],
    XMLReplace[scoped, (XMLPattern["ul", "class" -> c_][Child[x : XMLPattern["li"]]] /; bound[c]) :> (x -> el["li"])]},
  {scoped, doc[XMLElement["ul", {"class" -> "a"}, {}]],
    scoped, doc[XMLElement["ul", {"class" -> "a"}, {el["li"], el["li"]}]]},
  TestID -> "condition-scope-delete-replace"
];

TestCreate[
  shape[HTMLToTree[scoped[[2]], #]] & /@ {
    "Hide" -> (XMLPattern["ul", "class" -> c_][Child[x : XMLPattern["li"] /; bound[c]]] :> x),
    "Hide" -> ((XMLPattern["ul", "class" -> c_][Child[x : XMLPattern["li"]]] /; bound[c]) :> x),
    "Focus" -> (XMLPattern["ul", "class" -> c_][Child[x : XMLPattern["li"] /; bound[c]]] :> x),
    "Focus" -> ((XMLPattern["ul", "class" -> c_][Child[x : XMLPattern["li"]]] /; bound[c]) :> x)},
  {shell["ul", {"class" -> "a"}] -> {shell["li", {"id" -> "1"}], shell["li", {"id" -> "2"}]},
    shell["ul", {"class" -> "a"}],
    shell["ul", {"class" -> "a"}] -> {Missing["Collapsed", 2]},
    shell["ul", {"class" -> "a"}] -> {shell["li", {"id" -> "1"}], shell["li", {"id" -> "2"}]}},
  TestID -> "condition-scope-html-to-tree"
];

(* Laws: an XML pattern's verdict is MatchQ's on the same list pattern, the
   list {1, {2}} standing for ul[li, ol[li]]. *)
TestCreate[
  With[{tree = XMLElement["ul", {}, {el["li"], el["ol", el["li"]]}]},
    {XMLMatchQ[tree, #] & /@ {
        XMLPattern["ul"][{x : XMLPattern["li"], XMLPattern["ol"][{y : XMLPattern["li"]}] /; bound[x]}],
        XMLPattern["ul"][{x : XMLPattern["li"], XMLPattern["ol"][{y : XMLPattern["li"] /; bound[x]}]}],
        XMLPattern["ul"][{x : XMLPattern["li"], XMLPattern["ol"][{y : XMLPattern["li"] /; bound[y]}]}],
        XMLPattern["ul"][{x : XMLPattern["li"], XMLPattern["ol"][{y : XMLPattern["li"]}]}] /; bound[x] && bound[y],
        XMLPattern["ul"][{x : XMLPattern["li"], y : XMLPattern["ol"] /; bound[x]}]},
      MatchQ[{1, {2}}, #] & /@ {
        {x_, {y_} /; bound[x]},
        {x_, {y_ /; bound[x]}},
        {x_, {y_ /; bound[y]}},
        {x_, {y_}} /; bound[x] && bound[y],
        {x_, y_ /; bound[x]}}}],
  {{False, False, True, True, False}, {False, False, True, True, False}},
  TestID -> "condition-scope-laws"
];

(* === Section 5: order === *)

(* Grouped by the first counted name in pattern order, whatever the order in
   the right-hand side. *)
TestCreate[
  XMLCases[nav, n : XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> {id[x], id[n]}],
  {{"a1", "o"}, {"a2", "o"}, {"a3", "o"}, {"a2", "i"}},
  TestID -> "order-grouped-by-first-name"
];

(* The branches of one Alternatives share a slot. *)
TestCreate[
  XMLCases[alt, XMLPattern["li"][{___, (y : XMLPattern["span"]) | (x : XMLPattern["a"]), ___}] :> {x, y}],
  {{el["a"]}, {el["span"]}},
  TestID -> "order-alternatives-one-slot"
];

TestCreate[
  XMLCases[alt2, XMLPattern["li"][{___, (x : XMLPattern["a"]) | XMLPattern["span"], ___}] :> {x}],
  {{}, {el["a"]}},
  TestID -> "order-absent-tuple-where-alternatives-matched"
];

(* An uncounted name takes its first passing position. *)
TestCreate[
  Block[{seen}, {XMLCases[cells, XMLPattern["tr"][{x : XMLPattern["th"], ___}, Descendant[y : XMLPattern["td"]]] :> x /; (seen = y; True)], id[seen]}],
  {{el["th"]}, "a"},
  TestID -> "order-uncounted-first-passing"
];

TestCreate[
  XMLCases[nav, n : XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> {id[n], id[x]}, 2],
  {{"o", "a1"}, {"o", "a2"}},
  TestID -> "order-count"
];

TestCreate[
  XMLFirstCase[nav, n : XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> {id[n], id[x]}],
  {"o", "a1"},
  TestID -> "order-first-case"
];

TestCreate[
  {XMLFirstCase[nav, XMLPattern["table"] :> 1], XMLFirstCase[nav, XMLPattern["table"] :> 1, "none"],
    XMLFirstCase[links, XMLPattern["p"][{___, x : XMLPattern["a"]}]]},
  {Missing["NotFound"], "none", links[[2]]},
  TestID -> "order-first-case-default"
];

(* === Input kinds === *)

(* A list's elements are the top elements; a bare element is under a virtual
   document, and its own position is never counted. *)
TestCreate[
  {XMLCases[{e["a", "1"], " ", e["a", "2"]}, x : XMLPattern["a"] :> id[x]],
    XMLCases[links[[2]], x : XMLPattern[_] :> id[x]],
    XMLCases[links[[2]], XMLPattern["p"][{___, x : XMLPattern["a"]}] :> id[x]],
    XMLCases[links[[2]], XMLPattern["p"] -> 1]},
  {{"1", "2"}, {"1", "2", "3"}, {"3"}, {1}},
  TestID -> "input-kinds"
];

(* Text is not a child: a list constraint sees element children only. *)
TestCreate[
  XMLCases[doc[el["p", "text", e["a", "1"], " ", e["a", "2"]]], XMLPattern["p"][{x : XMLPattern["a"], _}] :> id[x]],
  {"1"},
  TestID -> "list-constraint-skips-text"
];

(* Several constraints hold independently, and _ is any one child. *)
TestCreate[
  {XMLCases[links, XMLPattern["p"][{_, _, _}, Descendant[XMLPattern["a", "id" -> "2"]]] :> 1],
    XMLCases[links, XMLPattern["p"][{_, _}] :> 1],
    XMLCases[links, XMLPattern["p"][{x_, ___}, {___, y_}] :> {id[x], id[y]}]},
  {{1}, {}, {{"1", "3"}}},
  TestID -> "constraints-independent"
];

(* A CSS string that is one element is an entry or a pattern. *)
TestCreate[
  XMLCases[doc[el["ul", XMLElement["li", {"class" -> "x", "id" -> "1"}, {}], e["li", "2"]]],
    XMLPattern["ul"][{___, x : "li.x", ___}] :> id[x]],
  {"1"},
  TestID -> "css-string-entry"
];

(* Level specs in DOM depth. *)
TestCreate[
  {XMLCases[nav, XMLPattern["nav"][Descendant[x : XMLPattern["a"], {2}]] :> id[x]],
    XMLCases[nav, XMLPattern["nav"][Descendant[x : XMLPattern["a"], 1]] :> id[x]],
    XMLCases[nav, XMLPattern["nav"][Descendant[x : XMLPattern["a"], {1, Infinity}]] :> id[x]]},
  {{"a2"}, {"a1", "a2", "a3"}, {"a1", "a2", "a3"}},
  TestID -> "descendant-level-specs"
];

(* Names on tags, attribute maps and token runs. *)
TestCreate[
  {XMLCases[links, XMLPattern[t_][{_, _, _}] :> t],
    XMLCases[hrefs, XMLPattern["a", a_] :> a],
    XMLCases[doc[XMLElement["p", {"class" -> "a b c"}, {}]], XMLPattern["p", "classList" -> {___, "a", r___}] :> {r}]},
  {{"p"}, {{"href" -> "/x"}, {"href" -> "/x"}}, {{"b", "c"}}},
  TestID -> "names-on-tags-attributes-tokens"
];

(* === Constraints in a second bracket ===

   XMLPattern[tag, attrs][c...] takes the constraints in a bracket of their
   own, so the attribute argument can be left out: XMLPattern[tag][c...].
   Each test gives what the same constraints after the attributes give. *)

TestCreate[
  XMLCases[links, XMLPattern["p"][{x : XMLPattern["a"], ___}] :> id[x]],
  {"1"},
  TestID -> "bracket-list-constraint"
];

TestCreate[
  {XMLCases[nav, XMLPattern["nav"][Descendant[x : XMLPattern["a"], {1}]] :> id[x]],
    XMLCases[hrefs, XMLPattern["p", _][{___, x : XMLPattern["a", "href" -> "/x"]}] :> First[x]]},
  {{"a1", "a2", "a3"}, {"a"}},
  TestID -> "bracket-descendant-and-attributes"
];

TestCreate[
  {XMLCases[links, XMLPattern["p"][{_, _, _}, Descendant[XMLPattern["a", "id" -> "2"]]] :> 1],
    XMLCases[links, XMLPattern["p"][{x_, ___}, {___, y_}] :> {id[x], id[y]}]},
  {{1}, {{"1", "3"}}},
  TestID -> "bracket-several-constraints"
];

(* Alternatives of constraints, and of patterns in the bracket form. *)
TestCreate[
  {XMLCases[alt, XMLPattern["li"][{___, (y : XMLPattern["span"]) | (x : XMLPattern["a"]), ___}] :> {x, y}],
    XMLCases[links, XMLPattern["p"][{_, _} | {_, _, _}] :> 1],
    XMLCases[nav, (n : XMLPattern["nav"][{___, XMLPattern["nav"], ___}]) | (n : XMLPattern["p"][{}]) :> id[n]]},
  {{{el["a"]}, {el["span"]}}, {1}, {"o"}},
  TestID -> "bracket-alternatives"
];

(* A name in two constraints names one place. *)
TestCreate[
  XMLCases[cells, XMLPattern["tr"][{x : XMLPattern[_], ___}, Descendant[x : XMLPattern["th"], {1}]] :> First[x]],
  {"th"},
  TestID -> "bracket-name-in-two-constraints"
];

(* Named, conditioned and tested constraints, and bracket patterns nested in
   list constraints and in Descendant. *)
TestCreate[
  {XMLCases[links, XMLPattern["p"][l : {___}] :> Length[l]],
    XMLCases[links, XMLPattern["p"][{___} /; True, {___}?(Length[#] == 3 &)] :> 1],
    XMLCases[holiday, XMLPattern["tr"][{XMLPattern["th"][{XMLPattern["time", "datetime" -> d_]}], ___}] :> d],
    XMLCases[nav, XMLPattern["nav"][Descendant[n : XMLPattern["nav"][{x : XMLPattern["a"]}]]] :> {id[n], id[x]}]},
  {{3}, {1}, {"2026-12-25"}, {{"i", "a2"}}},
  TestID -> "bracket-named-tested-nested"
];

(* The whole pattern named, conditioned and tested, and an XMLDocument
   branch beside it. *)
TestCreate[
  {XMLCases[links, (p : XMLPattern["p"][{___}]) /; Length[p[[3]]] == 3 :> 1],
    XMLCases[links, XMLPattern["p"][{___}]?(Length[#[[3]]] == 3 &) :> 1],
    XMLCases[links, XMLDocument[{XMLPattern["ul"]}] | (x : XMLPattern["p"][{___, XMLPattern["a"]}]) :> First[x]]},
  {{1}, {1}, {"p"}},
  TestID -> "bracket-whole-pattern-wrapped"
];

(* An empty bracket is the pattern without it. *)
TestCreate[
  {XMLCases[hrefs, x : XMLPattern["a"][] :> First[x]], XMLCases[hrefs, XMLPattern["a", "href" -> "/y"][] :> 1],
    XMLMatchQ[links[[2]], XMLPattern["p"][]], XMLMatchQ[XMLPattern["a", "href" -> "/x"][]][hrefs[[2, 3, 1]]]},
  {{"a", "a"}, {}, True, True},
  TestID -> "bracket-empty"
];

TestCreate[
  {XMLMatchQ[links[[2]], XMLPattern["p"][{_, _, _}]], XMLMatchQ[XMLPattern["p"][{_, _}]][links[[2]]],
    XMLFreeQ[nav, XMLPattern["nav"][{XMLPattern["a"], ___}]], XMLFreeQ[XMLPattern["nav"][{}]][nav]},
  {True, False, False, True},
  TestID -> "bracket-matchq-freeq"
];

TestCreate[
  With[{page = doc[el["body", el["nav", el["a", "Home"], el["a", "News"]], el["p", "Text"]]]},
    {HTMLInnerText[page, "Roles" -> {XMLPattern["nav"][{___}] -> "Skip"}],
      HTMLInnerText[page, "Roles" -> {(XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> x) -> "Block"}]}],
  {"Text", "Home\nNews\nText"},
  TestID -> "bracket-roles-keys"
];

(* === Messages === *)

TestCreate[
  XMLCases[links, XMLPattern["div"][XMLPattern["p"]]],
  $Failed,
  {XMLPattern::constraint},
  TestID -> "message-constraint"
];

TestCreate[
  XMLCases[links, XMLPattern["ul"][{Descendant[XMLPattern["a"]]}]],
  $Failed,
  {XMLPattern::listentry},
  TestID -> "message-listentry-descendant"
];

TestCreate[
  XMLCases[links, XMLPattern["ul"][{{XMLPattern["a"]}}]],
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
  {XMLCases[links, XMLPattern["p"][Descendant[XMLPattern["a"], XMLPattern["b"]]]],
    XMLCases[links, XMLPattern["p"][Descendant[XMLPattern["a"], {0}]]]},
  {$Failed, $Failed},
  {Descendant::level, Descendant::level},
  TestID -> "message-descendant-level"
];

(* A blank is refused as the whole query and as Descendant's pattern, not as
   a list entry. *)
TestCreate[
  {XMLCases[links, _], XMLCases[links, XMLPattern["p"][Descendant[_]]], XMLCases[links, XMLPattern["p"][{_, x_, _}] :> id[x]]},
  {$Failed, $Failed, {"2"}},
  {XMLCases::blank, Descendant::blank},
  TestID -> "message-blank-narrowed"
];


