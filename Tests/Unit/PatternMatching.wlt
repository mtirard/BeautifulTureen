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

(* A Condition on a tree pattern sees the names bound in its constraints. *)
TestCreate[
  XMLCases[$treeCond, XMLPattern["div", _, {___, s : XMLPattern["span"], ___}] /; HTMLTextContent[s] === "y" :> s],
  {XMLElement["span", {}, {"y"}]},
  TestID -> "cond-tree-pattern"
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

(* === A condition sees every attribute name ===
   WL tests a Condition around a nested KeyValuePattern with only the first
   rule's names bound (bug 477310 / family of 472952), and ReplaceList binds
   only those. The compiler matches such a pattern so that every name is bound,
   in every form that takes a condition. *)

$cross = XMLElement["div", {}, {
  XMLElement["a", {"href" -> "/buy", "data-id" -> "buy"}, {"x"}],
  XMLElement["a", {"href" -> "/sell", "data-id" -> "buy"}, {"y"}],
  XMLElement["b", {}, {"z"}]}];

$crossPattern = XMLPattern["a", {"href" -> h_, "data-id" -> d_}];

TestCreate[
  XMLCases[
    ImportString["<div><a href=\"/buy\" data-id=\"buy\">x</a></div>", {"HTML", "XMLObject"}],
    (XMLPattern["a", {"href" -> h_, "data-id" -> d_}] /; StringContainsQ[h, d]) :> {h, d}],
  {{"/buy", "buy"}},
  TestID -> "cond-cross-field-rule"
];

TestCreate[
  XMLCases[$cross, $crossPattern /; StringContainsQ[h, d]][[All, 3]],
  {{"x"}},
  TestID -> "cond-cross-field-cases"
];

TestCreate[
  XMLCases[$cross, $crossPattern :> {h, d} /; StringContainsQ[h, d]],
  {{"/buy", "buy"}},
  TestID -> "cond-cross-field-body-condition"
];

TestCreate[
  XMLFirstCase[$cross, $crossPattern /; !StringContainsQ[h, d]][[3]],
  {"y"},
  TestID -> "cond-cross-field-firstcase"
];

TestCreate[
  XMLDeleteCases[$cross, $crossPattern /; StringContainsQ[h, d]][[3, All, 3]],
  {{"y"}, {"z"}},
  TestID -> "cond-cross-field-deletecases"
];

(* In an Alternatives, the condition applies to its own alternative only. *)
TestCreate[
  XMLCases[$cross, ($crossPattern /; StringContainsQ[h, d]) | XMLPattern["b"]][[All, 3]],
  {{"x"}, {"z"}},
  TestID -> "cond-cross-field-alternatives"
];

(* A rule body is evaluated once for each match. *)
TestCreate[
  Reap[XMLCases[$cross, ($crossPattern /; StringQ[h] && StringQ[d]) :> Sow[h]]],
  {{"/buy", "/sell"}, {{"/buy", "/sell"}}},
  TestID -> "cond-cross-field-body-evaluated-once"
];

(* The match backtracks: another key of the Alternatives is tried when the
   condition fails on the first. *)
TestCreate[
  XMLMatchQ[XMLElement["p", {"x" -> "1", "y" -> "2", "z" -> "3"}, {}],
    XMLPattern["p", {("x" | "y") -> v_, "z" -> w_}] /; v === "2" && StringQ[w]],
  True,
  TestID -> "cond-cross-field-backtracks"
];

(* Each constraint takes a different attribute, with a condition as without. *)
TestCreate[
  XMLMatchQ[XMLElement["p", {"a" -> "1", "b" -> "2"}, {}],
    XMLPattern["p", {("a" | "b") -> "1", ("a" | "b") -> w_}] /; w === "1"],
  False,
  TestID -> "cond-cross-field-distinct-attributes"
];

(* The match backtracks into a value: another token is tried. *)
TestCreate[
  XMLCases[XMLElement["div", {}, {XMLElement["a", {"href" -> "/buy", "class" -> "x buy"}, {}]}],
    XMLPattern["a", {"href" -> h_, "classList" -> {___, c_, ___}}] /; StringContainsQ[h, c] :> c],
  {"buy"},
  TestID -> "cond-cross-field-backtracks-into-value"
];

(* A list key and an element name: the test sees the tokens and the original
   element. *)
TestCreate[
  XMLCases[
    XMLElement["div", {}, {
      XMLElement["p", {"class" -> "a b", "id" -> "b"}, {"1"}],
      XMLElement["p", {"class" -> "a b", "id" -> "c"}, {"2"}]}],
    (e : XMLPattern["p", {"classList" -> c_, "id" -> i_}]) /; MemberQ[c, i] && e[[2, 1]] === ("class" -> "a b")
  ][[All, 3]],
  {{"1"}},
  TestID -> "cond-cross-field-list-key-and-element-name"
];

(* The same, with each name seen by only one of the test and the body, or only
   inside held code. *)
TestCreate[
  With[{t = XMLElement["div", {}, {
      XMLElement["p", {"class" -> "a b", "id" -> "b"}, {"1"}],
      XMLElement["p", {"class" -> "a b", "id" -> "c"}, {"2"}]}]},
    {XMLCases[t, (e : XMLPattern["p", {"classList" -> c_, "id" -> i_}]) /; MemberQ[c, i] :> e],
     XMLCases[t, (e : XMLPattern["p", {"classList" -> c_, "id" -> i_}]) /; ReleaseHold[Hold[e]][[2, 2]] === ("id" -> "c") :> i]}],
  {{XMLElement["p", {"class" -> "a b", "id" -> "b"}, {"1"}]}, {"c"}},
  TestID -> "cond-cross-field-names-used-apart"
];

TestCreate[
  XMLCases[$cross, XMLPattern["div", _, {___, x : $crossPattern, ___}] /; StringContainsQ[h, d] :> x][[All, 3]],
  {{"x"}},
  TestID -> "cond-cross-field-tree-pattern"
];

TestCreate[
  XMLCases[$cross, XMLPattern["div", _, {___, $crossPattern /; StringContainsQ[h, d], ___}] :> h],
  {"/buy"},
  TestID -> "cond-cross-field-contents-entry"
];

TestCreate[
  HTMLInnerText[$cross, "Roles" -> {($crossPattern /; StringContainsQ[h, d]) -> "Skip"}],
  "yz",
  TestID -> "cond-cross-field-roles"
];

TestCreate[
  HTMLToNotebook[XMLElement["p", {}, {
      XMLElement["span", {"title" -> "t", "lang" -> "t"}, {"x"}],
      XMLElement["span", {"title" -> "t", "lang" -> "u"}, {"y"}]}],
    "Constructs" -> {(XMLPattern["span", {"title" -> t_, "lang" -> l_}] /; StringQ[l] && t === l) -> "Bold"}],
  Notebook[{Cell[TextData[{StyleBox["x", FontWeight -> Bold], "y"}], "Text"]}],
  TestID -> "cond-cross-field-constructs"
];

(* === Rule queries (pattern -> rhs) === *)

(* A query pattern -> rhs is read as Cases reads a Rule: rhs is evaluated once,
   when the query is given, and the names the pattern binds are put into the
   value. A value that uses no name gives at most one result: a query gives
   one result for each distinct tuple of positions of the names it uses. *)

$ruleTree = ImportString[
  "<div><p id=\"a\" class=\"x y\">1</p><a href=\"/one\">o</a><p id=\"b\">2</p><a href=\"/two\">t</a></div>",
  {"HTML", "XMLObject"}];

TestCreate[
  XMLCases[$ruleTree, XMLPattern["p"] -> 1],
  {1},
  TestID -> "rule-constant-rhs"
];

(* With no value on h, the rule substitutes the binding. *)
TestCreate[
  XMLCases[$ruleTree, XMLPattern["a", "href" -> h_] -> h],
  {"/one", "/two"},
  TestID -> "rule-binding-rhs"
];

TestCreate[
  XMLCases[$ruleTree, e : XMLPattern["a"] -> e][[All, 3]],
  {{"o"}, {"t"}},
  TestID -> "rule-element-name-rhs"
];

(* The right-hand side is evaluated before any match, so a function of a name
   sees the symbol, as in Cases; :> evaluates it for each match. *)
TestCreate[
  {XMLCases[$ruleTree, e : XMLPattern["a"] -> Length[e]],
   Cases[{{1, 2}, {3, 4}}, e_ -> Length[e]],
   XMLCases[$ruleTree, e : XMLPattern["a"] :> Length[e]]},
  {{0}, {0, 0}, {3, 3}},
  TestID -> "rule-rhs-evaluated-before-matching"
];

(* With a value on the right-hand side's symbol, the value is used, as Cases
   uses it: the plain rule ("id" -> x_) -> x on the id rules gives the same. *)
TestCreate[
  Block[{x = 5},
    {XMLCases[$ruleTree, XMLPattern["p", "id" -> x_] -> x],
     Cases[{"id" -> "a", "id" -> "b"}, ("id" -> x_) -> x]}],
  {{5}, {5, 5}},
  TestID -> "rule-global-value-as-cases"
];

TestCreate[
  Block[{x},
    {XMLCases[$ruleTree, XMLPattern["p", "id" -> x_] -> x],
     Cases[{"id" -> "a", "id" -> "b"}, ("id" -> x_) -> x]}],
  {{"a", "b"}, {"a", "b"}},
  TestID -> "rule-no-global-value-as-cases"
];

(* The right-hand side is evaluated once, when the query is given. *)
TestCreate[
  Module[{n = 0}, {XMLCases[$ruleTree, XMLPattern["p"] -> ++n], n}],
  {{1}, 1},
  TestID -> "rule-rhs-evaluated-once"
];

(* A Condition in the value is part of it, not a test, as in Cases. *)
TestCreate[
  {XMLCases[$ruleTree, XMLPattern["p", "id" -> i_] -> (i /; i == "a")],
   Cases[{"id" -> "a", "id" -> "b"}, ("id" -> i_) -> (i /; i == "a")]},
  {{"a" /; "a" == "a", "b" /; "b" == "a"}, {"a" /; "a" == "a", "b" /; "b" == "a"}},
  TestID -> "rule-condition-in-value-as-cases"
];

(* A name at a list key gives the token list, with -> as with :>. *)
TestCreate[
  {XMLCases[$ruleTree, XMLPattern["p", "classList" -> c_] -> c],
   XMLCases[$ruleTree, XMLPattern["p", "classList" -> c_] :> c]},
  {{{"x", "y"}, {}}, {{"x", "y"}, {}}},
  TestID -> "rule-list-key-name-as-delayed"
];

(* An element name beside a list key is the element as it is in the tree. *)
TestCreate[
  XMLCases[$ruleTree, e : XMLPattern["p", "classList" -> "x"] -> e],
  {XMLElement["p", {"class" -> "x y", "id" -> "a"}, {"1"}]},
  TestID -> "rule-list-key-element-name"
];

TestCreate[
  XMLCases[$ruleTree, (XMLPattern["p", "id" -> i_] /; i == "b") -> i],
  {"b"},
  TestID -> "rule-conditioned-pattern"
];

(* A rule over a tree pattern, with a Condition on the pattern root. A
   right-hand side that uses no name gives at most one result. *)
TestCreate[
  XMLCases[$ruleTree,
    (XMLPattern["div", _, {___, XMLPattern["a", "href" -> h_], ___}] /; StringEndsQ[h, "two"]) -> h],
  {"/two"},
  TestID -> "rule-tree-pattern-condition"
];

TestCreate[
  XMLCases[$ruleTree, XMLPattern[_, _, {___, XMLPattern["p", "id" -> i_], XMLPattern["a", "href" -> h_], ___}] -> {i, h}],
  {{"a", "/one"}, {"b", "/two"}},
  TestID -> "rule-tree-pattern-names"
];

TestCreate[
  XMLCases[$ruleTree, XMLPattern["div", _, {___, XMLPattern["p"], ___}] -> 1],
  {1},
  TestID -> "rule-tree-pattern-constant-rhs"
];

(* === PatternTest over an XML pattern (pat?f), issue #33 === *)

(* pat?f means n : pat /; f[n]: f is given the element as it is in the tree. *)
$testedSup1 = XMLElement["sup", {"class" -> "ref note"}, {XMLElement["a", {"href" -> "#n1"}, {"1"}]}];
$testedSup2 = XMLElement["sup", {"class" -> "note"}, {"2"}];
$testedTree = XMLElement["div", {}, {
  XMLElement["p", {"id" -> "x"}, {"a", $testedSup1}],
  XMLElement["p", {"id" -> "y"}, {"b", $testedSup2}]}];
$testedHasLink = Function[e, !FreeQ[e, XMLElement["a", _, _]]];

TestCreate[
  {XMLMatchQ[$testedSup1, XMLPattern["sup"]?(True &)],
   XMLMatchQ[$testedSup1, XMLPattern["sup"]?(False &)],
   XMLMatchQ[$testedSup2, XMLPattern["sup"]?$testedHasLink],
   XMLMatchQ[XMLPattern["sup"]?$testedHasLink][$testedSup1]},
  {True, False, False, True},
  TestID -> "patterntest-xmlmatchq"
];

TestCreate[
  {XMLCases[$testedTree, XMLPattern["sup"]?$testedHasLink],
   XMLFirstCase[$testedTree, XMLPattern["sup"]?(!$testedHasLink[#] &)],
   XMLDeleteCases[$testedTree, XMLPattern["sup"]?$testedHasLink]},
  {{$testedSup1}, $testedSup2,
   XMLElement["div", {}, {XMLElement["p", {"id" -> "x"}, {"a"}], XMLElement["p", {"id" -> "y"}, {"b", $testedSup2}]}]},
  TestID -> "patterntest-consumers"
];

(* The same result as the Condition form. *)
TestCreate[
  XMLCases[$testedTree, XMLPattern["sup"]?$testedHasLink -> "Plain"] ===
    XMLCases[$testedTree, s : XMLPattern["sup"] /; $testedHasLink[s] -> "Plain"] === {"Plain"},
  True,
  TestID -> "patterntest-same-as-condition"
];

(* With a list key named, f sees the element as it is in the tree. *)
TestCreate[
  Reap[XMLCases[$testedTree, XMLPattern["sup", "classList" -> "note"]?((Sow[#]; True) &)]],
  {{$testedSup1, $testedSup2}, {{$testedSup1, $testedSup2}}},
  TestID -> "patterntest-sees-original-element"
];

TestCreate[
  Reap[XMLCases[$testedTree, XMLPattern["p", _, {___, x : XMLPattern["sup", "classList" -> "ref"]?((Sow[#]; True) &), ___}] :> x]],
  {{$testedSup1}, {{$testedSup1}}},
  TestID -> "patterntest-entry-sees-original-element"
];

(* As a contents-list entry, around alternatives, with names and Conditions. *)
TestCreate[
  {XMLCases[$testedTree, XMLPattern["p", "id" -> i_, {___, XMLPattern["sup"]?$testedHasLink, ___}] :> i],
   XMLCases[$testedTree, (XMLPattern["sup"] | XMLPattern["p"])?$testedHasLink],
   XMLCases[$testedTree, e : XMLPattern["sup"]?$testedHasLink :> e],
   XMLCases[$testedTree, (e : XMLPattern["sup", "classList" -> "note"])?$testedHasLink :> e],
   XMLCases[$testedTree, (XMLPattern["p", "id" -> i_] /; i === "y")?(True &) :> i],
   XMLCases[$testedTree, (XMLPattern["p", "id" -> i_]?$testedHasLink) /; i === "y" :> i]},
  {{"x"}, {XMLElement["p", {"id" -> "x"}, {"a", $testedSup1}], $testedSup1}, {$testedSup1}, {$testedSup1}, {"y"}, {}},
  TestID -> "patterntest-shapes"
];

(* A Condition over a KeyValuePattern with later names sees every name; f is
   run on the element as it is in the tree. How often a test runs is not
   specified; here it runs once. *)
$testedLink = XMLElement["a", {"href" -> "/x/1", "data-id" -> "1"}, {}];
TestCreate[
  Reap[{XMLCases[{$testedLink}, (XMLPattern["a", {"href" -> h_, "data-id" -> i_}] /; StringContainsQ[h, i])?((Sow[#]; True) &)],
    XMLCases[{$testedLink}, (XMLPattern["a", {"href" -> h_, "data-id" -> i_}] /; StringContainsQ[h, i])?(False &)]}],
  {{{$testedLink}, {}}, {{$testedLink}}},
  TestID -> "patterntest-two-step-match"
];

(* A branch whose test fails binds nothing. When both branches match, each
   gives its own tuple of the counted names h, i and j: one result each. *)
$testedXY = XMLPattern["a", {"x" -> h_, "y" -> i_}];
$testedX = XMLPattern["a", {"x" -> j_}];
$testedA = XMLElement["div", {}, {XMLElement["a", {"x" -> "1", "y" -> "2"}, {}]}];
TestCreate[
  {XMLCases[$testedA, (($testedXY?(False &)) | $testedX) /; True :> {h, i, j}],
   XMLCases[$testedA, ((n : $testedXY /; False) | $testedX) /; True :> {h, i, j}],
   XMLCases[$testedA, XMLPattern["div", _, {___, (($testedXY?(False &)) | $testedX) /; True, ___}] :> {h, i, j}],
   XMLCases[$testedA, (($testedXY?(True &)) | $testedX) /; True :> {h, i, j}]},
  {{{"1"}}, {{"1"}}, {{"1"}}, {{"1", "2"}, {"1"}}},
  TestID -> "patterntest-two-step-failed-branch"
];

TestCreate[
  {HTMLInnerText[$testedTree, "Roles" -> {XMLPattern["sup"]?$testedHasLink -> "Skip"}]},
  {"a\nb2"},
  TestID -> "patterntest-role-rule"
];

