(* FromCSSSelector to tree patterns (tree-pattern spec section 7): one-element
   selectors are patterns; a context selector is a pattern only once its
   subject is named, FromCSSSelector[n : s], rooted at its first compound.
   Consumers name the subject of an unnamed context selector themselves. The
   fixtures are the spec's, local to this file. *)

doc[root_] := XMLObject["Document"][{}, root, {}];
e[tag_, id_String, c___] := XMLElement[tag, {"id" -> id}, {c}];
id[x_XMLElement] := Lookup[x[[2]], "id"];
el[tag_, c___] := XMLElement[tag, {}, {c}];

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
  {$Failed, XMLPattern["nav", _, Descendant[n : XMLPattern["a"]]]},
  {FromCSSSelector::name},
  TestID -> "css-tree-table-descendant"
];

TestCreate[
  {FromCSSSelector["nav > a"], FromCSSSelector[n : "nav > a"]},
  {$Failed, XMLPattern["nav", _, {___, n : XMLPattern["a"], ___}]},
  {FromCSSSelector::name},
  TestID -> "css-tree-table-child"
];

(* Pattern holds the name, so a value of it does not leak in. *)
TestCreate[
  Block[{n = 5}, FromCSSSelector[n : "nav a"]] === XMLPattern["nav", _, Descendant[n : XMLPattern["a"]]],
  True,
  TestID -> "css-tree-name-held"
];

TestCreate[
  {FromCSSSelector["div:has(> table)"], FromCSSSelector[n : "div:has(> table)"]},
  {XMLPattern["div", _, {___, XMLPattern["table"], ___}], n : XMLPattern["div", _, {___, XMLPattern["table"], ___}]},
  TestID -> "css-tree-table-has-child"
];

TestCreate[
  {FromCSSSelector["ul:has(ul li)"], FromCSSSelector[n : "ul:has(ul li)"]},
  {XMLPattern["ul", _, Descendant[XMLPattern["ul", _, Descendant[XMLPattern["li"]]]]],
    n : XMLPattern["ul", _, Descendant[XMLPattern["ul", _, Descendant[XMLPattern["li"]]]]]},
  TestID -> "css-tree-table-has-descendant"
];

TestCreate[
  {FromCSSSelector["h1, h2"], FromCSSSelector[n : "h1, h2"]},
  {XMLPattern["h1" | "h2"], n : XMLPattern["h1" | "h2"]},
  TestID -> "css-tree-table-list-merged"
];

TestCreate[
  {FromCSSSelector["li:first-child"], FromCSSSelector[n : "li:first-child"]},
  {$Failed, XMLPattern[_, _, {n : XMLPattern["li"], ___}] | XMLDocument[{n : XMLPattern["li"], ___}]},
  {FromCSSSelector::name},
  TestID -> "css-tree-table-first-child"
];

(* The tag name is fresh, and shared into Except. *)
TestCreate[
  MatchQ[FromCSSSelector[n : ":first-of-type"],
    With[{l = {Verbatim[RepeatedNull][Verbatim[Except][XMLPattern[Verbatim[Pattern][t_Symbol, Verbatim[_]]]]],
        Verbatim[Pattern][n, XMLPattern[Verbatim[Pattern][t_Symbol, Verbatim[_]]]], Verbatim[___]}},
      Verbatim[Alternatives][XMLPattern[Verbatim[_], Verbatim[_], l], XMLDocument[l]]]],
  True,
  TestID -> "css-tree-table-first-of-type"
];

TestCreate[
  With[{L = {Except[XMLPattern["li"]] ..., XMLPattern["li"], Except[XMLPattern["li"]] ..., XMLPattern["p"], n : XMLPattern["li"], ___}},
    FromCSSSelector[n : "p + li:nth-of-type(2)"] === (XMLPattern[_, _, L] | XMLDocument[L])],
  True,
  TestID -> "css-tree-table-adjacent-of-type"
];

TestCreate[
  FromCSSSelector[n : ":root > p"],
  XMLDocument[{XMLPattern[_, _, {___, n : XMLPattern["p"], ___}]}],
  TestID -> "css-tree-table-root"
];

TestCreate[
  FromCSSSelector[n : "a, b > c"],
  (n : XMLPattern["a"]) | XMLPattern["b", _, {___, n : XMLPattern["c"], ___}],
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
