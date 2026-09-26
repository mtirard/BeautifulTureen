(* XMLPattern matching semantics: namespaced attribute keys, tag predicates
   (PatternTest / Condition on the tag), and top-level Condition patterns
   (pat /; test). All fixtures here are local to this file. *)

(* === Namespaced attribute keys ({namespace, name} pairs) === *)

(* WL imports a namespaced attribute such as xlink:href with a two-element
   {namespaceURI, localName} key rather than a plain string. *)
$svg = ImportString[
  "<svg xmlns:xlink=\"http://www.w3.org/1999/xlink\"><use xlink:href=\"#a\"/></svg>",
  {"XML", "XMLObject"}];

(* A plain-string constraint does not match a namespaced key *)
TestCreate[
  XMLCases[$svg, XMLPattern["use", "href" -> _]],
  {},
  TestID -> "nskey-plain-string-misses"
];

(* A key is literal, so the local name in any namespace is a question about the
   whole attribute map, asked by naming it. *)
TestCreate[
  XMLCases[$svg,
    XMLPattern["use", attrs_?(Keys /* MemberQ[{_, "href"}])] :>
      FirstCase[attrs, ({_, "href"} -> href_) :> href]],
  {"#a"},
  TestID -> "nskey-pair-any-namespace"
];

(* Match an exact {namespace, name} pair (with a literal value) *)
TestCreate[
  XMLCases[$svg,
    XMLPattern["use", {"http://www.w3.org/1999/xlink", "href"} -> "#a"] :> "hit"],
  {"hit"},
  TestID -> "nskey-pair-exact"
];

(* Alternatives of literal pair keys *)
TestCreate[
  XMLCases[$svg,
    XMLPattern["use",
      ({"http://www.w3.org/1999/xlink", "href"} | {"http://www.w3.org/1999/xlink", "src"}) -> href_] :> href],
  {"#a"},
  TestID -> "nskey-alternatives-of-pairs"
];

(* A pair with a pattern in it is not a literal key *)
TestCreate[
  XMLCases[$svg, XMLPattern["use", {_, "href"} -> _]],
  $Failed,
  {XMLPattern::badkey},
  TestID -> "nskey-pattern-pair-refused"
];

(* A three-element list is not a valid attribute key *)
TestCreate[
  XMLCases[$svg, XMLPattern["p", {"a", "b", "c"} -> _]],
  $Failed,
  {XMLPattern::badkey},
  TestID -> "nskey-bad-triple-list"
];

(* === Tag predicate patterns (PatternTest / Condition) === *)

$treeHeadings = ImportString[
  "<section><h1>A</h1><h2>B</h2><p>C</p><h3>D</h3></section>",
  {"HTML", "XMLObject"}];

(* PatternTest with a pure function predicate on the tag *)
TestCreate[
  XMLCases[$treeHeadings, XMLPattern[t_?(StringMatchQ[#, "h" ~~ DigitCharacter] &)] :> t],
  {"h1", "h2", "h3"},
  TestID -> "tagpred-patterntest-function"
];

(* PatternTest with the operator form of StringMatchQ (parenthesized) *)
TestCreate[
  XMLCases[$treeHeadings, XMLPattern[_?(StringMatchQ["h" ~~ DigitCharacter])]][[All, 1]],
  {"h1", "h2", "h3"},
  TestID -> "tagpred-patterntest-operator"
];

(* Condition on the tag *)
TestCreate[
  XMLCases[$treeHeadings, XMLPattern[t_ /; StringMatchQ[t, "h" ~~ DigitCharacter]] :> t],
  {"h1", "h2", "h3"},
  TestID -> "tagpred-condition"
];

(* Predicate composes with attribute constraints *)
TestCreate[
  XMLCases[
    ImportString["<div><a rel=\"x\">1</a><b rel=\"y\">2</b><a>3</a></div>",
      {"HTML", "XMLObject"}],
    XMLPattern[_?(StringMatchQ[#, "a" | "b"] &), "rel" -> r_] :> r],
  {"x", "y"},
  TestID -> "tagpred-with-constraint"
];

(* === Top-level Condition patterns (pat /; test) === *)

$treeCond = ImportString[
  "<section><h1>A</h1><h2>B</h2><p>C</p><div><span>x</span><span>y</span></div></section>",
  {"HTML", "XMLObject"}];

(* Condition on the whole element, testing the tag binding *)
TestCreate[
  XMLCases[$treeCond, XMLPattern[t_] /; StringMatchQ[t, "h" ~~ DigitCharacter]][[All, 1]],
  {"h1", "h2"},
  TestID -> "cond-tag"
];

(* Condition on a whole-part capture (element-child count) \[LongDash] the unique power
   of a top-level condition, not expressible via XMLPattern constraints *)
TestCreate[
  XMLCases[$treeCond, XMLElement[tag_, _, kids_] /; Count[kids, _XMLElement] >= 2][[All, 1]],
  {"section", "div"},
  TestID -> "cond-childcount"
];

(* Whole-attrs capture lets a condition relate two attributes *)
TestCreate[
  XMLCases[
    ImportString["<div><a href=\"/buy\" data-id=\"buy\">x</a><a href=\"/z\" data-id=\"q\">y</a></div>",
      {"HTML", "XMLObject"}],
    (XMLElement["a", attrs_, _] /;
       With[{a = Association[attrs]}, StringContainsQ[a["href"], a["data-id"]]]) :> "hit"],
  {"hit"},
  TestID -> "cond-wholeattrs-crossfield"
];

(* Condition short-circuits in XMLFirstCase; deletes in XMLDeleteCases *)
TestCreate[
  XMLFirstCase[$treeCond, XMLPattern[t_] /; StringMatchQ[t, "h" ~~ DigitCharacter]][[1]],
  "h1",
  TestID -> "cond-firstcase"
];
TestCreate[
  FreeQ[
    XMLDeleteCases[$treeCond, XMLPattern[t_] /; StringMatchQ[t, "h" ~~ DigitCharacter]],
    XMLElement["h1" | "h2", _, _]],
  True,
  TestID -> "cond-deletecases"
];

(* A Condition may wrap a combinator where the consumer takes one; its test sees
   every stage's names. XMLMatchQ and the Roles take an element pattern, and
   refuse it. *)
TestCreate[
  XMLCases[$treeCond, Child[XMLPattern["div"], s : XMLPattern["span"]] /; HTMLTextContent[s] === "y"],
  {XMLElement["span", {}, {"y"}]},
  TestID -> "cond-combinator"
];

TestCreate[
  {XMLMatchQ[XMLElement["span", {}, {}], Child[XMLPattern["div"], XMLPattern["span"]] /; True],
   HTMLInnerText[$treeCond, "Roles" -> {(Child[XMLPattern["div"], XMLPattern["span"]] /; True) -> "Block"}]},
  {$Failed, $Failed},
  {XMLMatchQ::condcombinator, HTMLInnerText::condcombinator},
  TestID -> "cond-combinator-refused-for-an-element-pattern"
];

(* An Alternatives of combinators, or a combinator inside an Alternatives, is not
   a query, tested or not. *)
TestCreate[
  {XMLCases[$treeCond, (Child[XMLPattern["div"], XMLPattern["span"]] | Child[XMLPattern["section"], XMLPattern["p"]]) /; True],
   XMLCases[$treeCond, Child[XMLPattern["section"], XMLPattern["p"] | Child[XMLPattern["div"], XMLPattern["span"]]] /; True]},
  {$Failed, $Failed},
  {XMLCases::badpat, XMLCases::badpat},
  TestID -> "cond-combinator-alternatives-refused"
];

(* === Named whole-element conditions (el : pat /; test) === *)

(* Binding the matched element by name lets the predicate address the whole
   element \[LongDash] most importantly via the text extractors, which have no
   XMLPattern-constraint equivalent. This is the natural form for HTML scraping
   ("keep/drop elements whose rendered text says X") and mirrors native WL,
   where name:patt /; test is ordinary. *)
$treeMenu = ImportString[
  "<ul><li>Miso</li><li>Pho (sold out)</li><li>Ramen</li></ul>",
  {"HTML", "XMLObject"}];

(* XMLCases: bind the <li>, filter on its rendered text *)
TestCreate[
  XMLCases[$treeMenu, (li : XMLPattern["li"]) /; StringContainsQ[HTMLTextContent[li], "sold out"]],
  {XMLElement["li", {}, {"Pho (sold out)"}]},
  TestID -> "cond-named-xmlcases"
];

(* XMLFirstCase: same predicate, first match *)
TestCreate[
  XMLFirstCase[$treeMenu, (li : XMLPattern["li"]) /; StringContainsQ[HTMLTextContent[li], "sold out"]],
  XMLElement["li", {}, {"Pho (sold out)"}],
  TestID -> "cond-named-firstcase"
];

(* XMLDeleteCases: drop the element whose text says sold out *)
TestCreate[
  XMLCases[
    XMLDeleteCases[$treeMenu, (li : XMLPattern["li"]) /; StringContainsQ[HTMLTextContent[li], "sold out"]],
    XMLPattern["li"]][[All, 3, 1]],
  {"Miso", "Ramen"},
  TestID -> "cond-named-deletecases"
];

(* A named Alternatives-of-XMLElements is accepted just like the bare form *)
TestCreate[
  XMLCases[$treeCond,
    (el : (XMLPattern["h1"] | XMLPattern["h2"])) /; StringLength[HTMLTextContent[el]] === 1][[All, 1]],
  {"h1", "h2"},
  TestID -> "cond-named-alternatives"
];

(* A combinator binds no name: a named combinator is refused, tested or not. *)
TestCreate[
  XMLCases[$treeCond, (x : Child[XMLPattern["div"], XMLPattern["span"]]) /; True],
  $Failed,
  {XMLCases::badpat},
  TestID -> "cond-named-combinator-rejected"
];

(* KNOWN ISSUE (bug 477310 / family of 472952): a /; test that references two or
   more attribute captures from XMLPattern's (nested) KeyValuePattern silently
   drops all but one binding, so both h and d are lost and this yields {} instead
   of {{"/buy", "buy"}}. Tagged KnownIssue: it is expected to fail on today's
   kernel (reported as a Known Issue, not a CI failure) and will flip to "Fixed"
   the moment the upstream fix reaches our kernel \[LongDash] the signal to promote
   attribute cross-field conditions to supported. *)
TestCreate[
  XMLCases[
    ImportString["<div><a href=\"/buy\" data-id=\"buy\">x</a></div>", {"HTML", "XMLObject"}],
    (XMLPattern["a", {"href" -> h_, "data-id" -> d_}] /; StringContainsQ[h, d]) :> {h, d}],
  {{"/buy", "buy"}},
  TestID -> "cond-cross-field-known-issue-477310"
] // TagTest["KnownIssue"]
