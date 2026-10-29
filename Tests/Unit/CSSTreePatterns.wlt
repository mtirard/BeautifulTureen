(* FromCSSSelector to tree patterns (ADR 0026): one-element
   selectors are patterns; a context selector is a pattern only once its
   subject is named, FromCSSSelector[n : s], rooted at its first compound.
   Consumers name the subject of an unnamed context selector themselves. *)

nav   = doc[e["nav", "o", e["a", "a1"], e["nav", "i", e["a", "a2"]], e["a", "a3"]]];
links = doc[el["p", e["a", "1"], e["a", "2"], e["a", "3"]]];
paras = doc[el["div", e["p", "1"], e["p", "2"], e["p", "3"]]];
body  = doc[el["body", e["nav", "n", e["a", "in"]], e["a", "out"]]];

(* === The translation table === *)

TestCreate[
  {FromCSSSelector["a.note"], FromCSSSelector[n : "a.note"]},
  {XMLPattern["a", "classList" -> "note"], n : XMLPattern["a", "classList" -> "note"]},
  TestID -> "css-tree-table-one-compound"
];

TestCreate[
  {FromCSSSelector["nav a"], FromCSSSelector[n : "nav a"]},
  {$Failed, XMLPattern["nav"][Descendant[n : XMLPattern["a"]]]},
  {FromCSSSelector::name},
  TestID -> "css-tree-table-descendant"
];

TestCreate[
  {FromCSSSelector["nav > a"], FromCSSSelector[n : "nav > a"]},
  {$Failed, XMLPattern["nav"][{___, n : XMLPattern["a"], ___}]},
  {FromCSSSelector::name},
  TestID -> "css-tree-table-child"
];

(* Pattern holds the name, so a value of it does not leak in. *)
TestCreate[
  Block[{n = 5}, FromCSSSelector[n : "nav a"]] === XMLPattern["nav"][Descendant[n : XMLPattern["a"]]],
  True,
  TestID -> "css-tree-name-held"
];

TestCreate[
  {FromCSSSelector["div:has(> table)"], FromCSSSelector[n : "div:has(> table)"]},
  {XMLPattern["div"][{___, XMLPattern["table"], ___}], n : XMLPattern["div"][{___, XMLPattern["table"], ___}]},
  TestID -> "css-tree-table-has-child"
];

TestCreate[
  {FromCSSSelector["ul:has(ul li)"], FromCSSSelector[n : "ul:has(ul li)"]},
  {XMLPattern["ul"][Descendant[XMLPattern["ul"][Descendant[XMLPattern["li"]]]]],
    n : XMLPattern["ul"][Descendant[XMLPattern["ul"][Descendant[XMLPattern["li"]]]]]},
  TestID -> "css-tree-table-has-descendant"
];

TestCreate[
  {FromCSSSelector["h1, h2"], FromCSSSelector[n : "h1, h2"]},
  {XMLPattern["h1" | "h2"], n : XMLPattern["h1" | "h2"]},
  TestID -> "css-tree-table-list-merged"
];

TestCreate[
  {FromCSSSelector["li:first-child"], FromCSSSelector[n : "li:first-child"]},
  {$Failed, XMLPattern[_][{n : XMLPattern["li"], ___}] | XMLDocument[{n : XMLPattern["li"], ___}]},
  {FromCSSSelector::name},
  TestID -> "css-tree-table-first-child"
];

(* The tag name is fresh, and shared into Except. *)
TestCreate[
  MatchQ[FromCSSSelector[n : ":first-of-type"],
    With[{l = {Verbatim[RepeatedNull][Verbatim[Except][XMLPattern[Verbatim[Pattern][t_Symbol, Verbatim[_]]]]],
        Verbatim[Pattern][n, XMLPattern[Verbatim[Pattern][t_Symbol, Verbatim[_]]]], Verbatim[___]}},
      Verbatim[Alternatives][XMLPattern[Verbatim[_]][l], XMLDocument[l]]]],
  True,
  TestID -> "css-tree-table-first-of-type"
];

TestCreate[
  With[{L = {Except[XMLPattern["li"]] ..., XMLPattern["li"], Except[XMLPattern["li"]] ..., XMLPattern["p"], n : XMLPattern["li"], ___}},
    FromCSSSelector[n : "p + li:nth-of-type(2)"] === (XMLPattern[_][L] | XMLDocument[L])],
  True,
  TestID -> "css-tree-table-adjacent-of-type"
];

TestCreate[
  FromCSSSelector[n : ":root > p"],
  XMLDocument[{XMLPattern[_][{___, n : XMLPattern["p"], ___}]}],
  TestID -> "css-tree-table-root"
];

TestCreate[
  FromCSSSelector[n : "a, b > c"],
  (n : XMLPattern["a"]) | XMLPattern["b"][{___, n : XMLPattern["c"], ___}],
  TestID -> "css-tree-table-list-context"
];

(* === Behaviour === *)

TestCreate[
  {XMLCases[body, "nav a"], XMLCases[body, n : "nav a" :> id[n]]},
  {{e["a", "in"]}, {"in"}},
  TestID -> "css-tree-context-subjects"
];

TestCreate[
  XMLCases[nav, r : FromCSSSelector[n : "nav a"] :> {id[r], id[n]}],
  {{"o", "a1"}, {"o", "a2"}, {"o", "a3"}, {"i", "a2"}},
  TestID -> "css-tree-root-and-subject"
];

TestCreate[
  XMLCases[nav, n : "nav a"],
  $Failed,
  {XMLCases::badpat},
  TestID -> "css-tree-named-context-whole-query-refused"
];

TestCreate[
  XMLCases[body, "nav a" :> 1],
  $Failed,
  {XMLCases::badpat},
  TestID -> "css-tree-unnamed-context-left-of-rule-refused"
];

TestCreate[
  XMLReplace[body, n : "nav a" :> {n -> "x"}],
  doc[el["body", e["nav", "n", "x"], e["a", "out"]]],
  TestID -> "css-tree-xmlreplace"
];

TestCreate[
  XMLDeleteCases[body, n : "nav a" :> n],
  doc[el["body", e["nav", "n"], e["a", "out"]]],
  TestID -> "css-tree-xmldeletecases"
];

TestCreate[
  id /@ XMLCases[paras, "p, div > p"],
  {"1", "2", "3"},
  TestID -> "css-tree-list-each-once"
];

TestCreate[
  {XMLCases[links, "a:first-child"], XMLCases[{e["li", "1"], e["li", "2"]}, "li:first-child"]},
  {{e["a", "1"]}, {e["li", "1"]}},
  TestID -> "css-tree-first-child"
];

TestCreate[
  {XMLCases[{e["a", "1"], e["b", "2"], e["a", "3"], e["c", "4"]}, ":first-of-type"],
    XMLCases[{e["a", "1"], e["b", "2"], e["a", "3"], e["c", "4"]}, ":nth-last-of-type(2)"]},
  {{e["a", "1"], e["b", "2"], e["c", "4"]}, {e["a", "1"]}},
  TestID -> "css-tree-own-type"
];

(* === Where a context selector is refused === *)

TestCreate[
  {XMLMatchQ[el["a"], "nav a"], XMLMatchQ[el["a"], n : "nav a"], XMLFreeQ[nav, "nav a"],
    XMLCases[nav, XMLPattern["nav", _, {___, "nav a", ___}]], XMLCases[nav, XMLPattern["nav", _, Descendant["nav a"]]]},
  {$Failed, $Failed, $Failed, $Failed, $Failed},
  {XMLMatchQ::badpat, XMLMatchQ::badpat, XMLFreeQ::badpat, XMLCases::badpat, XMLCases::badpat},
  TestID -> "css-tree-context-refused-in-element-slots"
];

TestCreate[
  {XMLMatchQ[e["a", "x"], "a.y, a#x"], XMLCases[nav, n : XMLPattern["nav", _, {___, "a", ___}] :> id[n]]},
  {True, {"o", "i"}},
  TestID -> "css-tree-one-element-in-element-slots"
];

(* === Complex :not(), :is(), :where() and :has() === *)

(* Downward :not(:has()) is XMLFreeQ below the element: {1, Infinity} after a
   descendant combinator, {1} after >. *)
TestCreate[
  {FromCSSSelector["p:not(:has(b))"], FromCSSSelector[n : "p:not(:has(b))"], FromCSSSelector["p:not(:has(> b))"]},
  {XMLPattern["p"]?(XMLFreeQ[#, XMLPattern["b"], {1, Infinity}] &), n : XMLPattern["p"]?(XMLFreeQ[#, XMLPattern["b"], {1, Infinity}] &),
    XMLPattern["p"]?(XMLFreeQ[#, XMLPattern["b"], {1}] &)},
  TestID -> "css-tree-table-not-has"
];

TestCreate[
  With[{L = {___, n : XMLPattern["a"], ___, XMLPattern["b"][Descendant[XMLPattern["c"]]], ___}},
    {FromCSSSelector["a:has(~ b c)"], FromCSSSelector[n : "a:has(~ b c)"] === (XMLPattern[_][L] | XMLDocument[L])}],
  {$Failed, True},
  {FromCSSSelector::name},
  TestID -> "css-tree-table-has-sibling"
];

TestCreate[
  {XMLCases[body, "a:not(nav a)"], XMLCases[doc[el["div", e["x", "1"], e["a", "2"], e["b", "3"]]], "a:has(+ b)"]},
  {{e["a", "out"]}, {e["a", "2"]}},
  TestID -> "css-tree-complex-results"
];

(* A test on the path is rooted at the document. The argument's last compound
   implied by the element's own is the test alone. *)
TestCreate[
  {FromCSSSelector["a:not(nav a)"], FromCSSSelector[n : "a:not(nav a)"], FromCSSSelector[n : "a:not(div > p a)"]},
  {$Failed, XMLDocument[Descendant[n : XMLPattern["a"]]?(! XMLMatchQ[{___, XMLPattern["nav"], ___}][#] &)],
    XMLDocument[Descendant[n : XMLPattern["a"]]?(! XMLMatchQ[{___, XMLPattern["div"], XMLPattern["p"], ___}][#] &)]},
  {FromCSSSelector::name},
  TestID -> "css-tree-not-path-alone"
];

(* :is() intersects the last compound into the element's; the compounds
   before it in the selector are a test on the same path. *)
xs = doc[el["body", el["x", el["a", e["b", "1"]]], el["a", el["x", e["b", "2"]]], el["x", e["b", "3"]], el["a", e["b", "4"]],
  el["x", el["a", e["i", "5"]]]]];

TestCreate[
  FromCSSSelector[n : "x :is(a b)"],
  XMLDocument[Descendant[n : XMLPattern["b"]]?(XMLMatchQ[{___, XMLPattern["x"], ___}][#] && XMLMatchQ[{___, XMLPattern["a"], ___}][#] &)],
  TestID -> "css-tree-is-path-intersected"
];

TestCreate[
  {id /@ XMLCases[xs, "x :is(a b)"], id /@ XMLCases[xs, "x :where(a > b)"], id /@ XMLCases[xs, "x > :is(a b, i)"],
    id /@ XMLCases[xs, "b:is(a > *, x > *)"]},
  {{"1", "2"}, {"1"}, {"2"}, {"1", "2", "3", "4"}},
  TestID -> "css-tree-is-path-selects"
];

(* :not() of a last compound the element's does not imply: the element fails
   that compound, or its path fails the rest. *)
zs = doc[el["body", e["nav", "n", e["a", "in"], XMLElement["a", {"id" -> "inz", "class" -> "z"}, {}]],
  XMLElement["a", {"id" -> "outz", "class" -> "z"}, {}]]];

TestCreate[
  {id /@ XMLCases[zs, "a:not(nav .z)"], id /@ XMLCases[zs, "a:not(nav .z, body > *)"], id /@ XMLCases[zs, "body *:not(nav a)"]},
  {{"in", "outz"}, {"in"}, {"n", "outz"}},
  TestID -> "css-tree-not-path-de-morgan"
];

(* A test on the path below another compound, which hangs below it. *)
TestCreate[
  {id /@ XMLCases[zs, "nav:not(div nav) > .z"], FromCSSSelector[n : "nav:not(div nav) > .z"]},
  {{"inz"}, XMLDocument[Descendant[XMLPattern["nav"][{___, n : XMLPattern[_, "classList" -> "z"], ___}]]?(! XMLMatchQ[{___, XMLPattern["div"], ___}][#] &)]},
  TestID -> "css-tree-path-not-on-subject"
];

TestCreate[
  {id /@ XMLCases[doc[el["div", e["a", "1"], e["x", "2"], e["a", "3"], e["b", "4", el["c"]]]], "a:has(~ b c)"],
    id /@ XMLCases[doc[el["div", e["a", "1"], e["b", "2"], e["a", "3", el["c"]]]], "a:has(+ b, > c)"],
    id /@ XMLCases[{e["a", "1"], e["b", "2"]}, "a:has(+ b)"], id /@ XMLCases[doc[el["div", e["a", "1"], e["a", "2"], e["b", "3"]]], "a:first-child:has(~ b)"]},
  {{"1", "3"}, {"1", "3"}, {"1"}, {"1"}},
  TestID -> "css-tree-has-sibling-selects"
];

TestCreate[
  {id /@ XMLCases[doc[el["div", e["p", "1", el["b"]], e["p", "2", el["i", el["b"]]], e["p", "3"]]], "p:not(:has(b))"],
    id /@ XMLCases[doc[el["div", e["p", "1", el["b"]], e["p", "2", el["i", el["b"]]], e["p", "3"]]], "p:not(:has(> b))"],
    id /@ XMLCases[doc[el["div", e["p", "1", el["b"]], e["p", "2", el["i", el["b"]]], e["p", "3"]]], "p:not(:has(> b, i))"]},
  {{"3"}, {"2", "3"}, {"3"}},
  TestID -> "css-tree-not-has-selects"
];

(* + and ~ inside a complex :not(), :is() or :where(), a sibling :has() inside
   one or under :not(), and a test on a path anywhere but one compound linked
   by descendant or > combinators stay unsupported. *)
TestCreate[
  Quiet[Check[FromCSSSelector[n : #]; "translated", "unsupported", FromCSSSelector::unsupported]] & /@
    {"a:not(b + a)", "x :is(a ~ b)", ":not(:has(+ b))", ":not(:has(~ b))", ":is(:has(+ b))", "a:has(+ b) + c",
      "a:has(+ b):has(~ c)", "div:has(:is(a b))", ":not(:is(a b))", "a:not(x a) b:not(y b)", "a:not(x a) + b",
      "a:first-child:not(x a)", "p:nth-child(1 of :is(a b))"},
  ConstantArray["unsupported", 13],
  TestID -> "css-tree-complex-unsupported"
];
