(* Alternatives holding a combinator (ADR 0015): read as WL's Alternatives over
   the combinators' list patterns, as the query or as a stage, conditioned or
   not. Each element is given once, in document order, and the first
   alternative, in written order, that accepts an element binds its names.
   Fixtures are local to this file. *)

html[s_] := ImportString["<html><body>" <> s <> "</body></html>", {"HTML", "XMLObject"}];
ids[es_] := Lookup[es[[All, 2]], "id", None];

$unionDoc = html["<nav id=\"n\"><a id=\"a1\"></a><ul id=\"u\"><li id=\"l1\"></li><li id=\"l2\"><a id=\"a2\"></a></li></ul></nav>\
<ul id=\"u2\"><li id=\"l3\"></li></ul><a id=\"a3\"></a>"];

(* === As the query === *)

TestCreate[
  ids @ XMLCases[$unionDoc, Child[XMLPattern["ul"], XMLPattern["li"]] | Descendant[XMLPattern["nav"], XMLPattern["a"]]],
  {"a1", "l1", "l2", "a2", "l3"},
  TestID -> "union-as-query"
];

(* Joining two queries lost elements the alternatives share (17 identical
   elements on the CSS page). Two identical siblings, each selected by both
   alternatives, are both given, each once. *)
$twins = html["<div><p class=\"x\">t</p><p class=\"x\">t</p></div>"];

TestCreate[
  With[{r = XMLCases[$twins, Child[XMLPattern["div"], XMLPattern["p"]] | Descendant[XMLPattern["body"], XMLPattern["p", "classList" -> "x"]]]},
    {Length[r], SameQ @@ r}],
  {2, True},
  TestID -> "union-shared-elements-kept-once"
];

(* === Mixed with an element pattern === *)

TestCreate[
  {First /@ XMLCases[html["<p>1</p><div><span>2</span><b><span>3</span></b></div><p>4</p>"],
     XMLPattern["p"] | Child[XMLPattern["div"], XMLPattern["span"]]],
   XMLCases[XMLElement["p", {}, {XMLElement["p", {}, {}]}], XMLPattern["p"] | Child[XMLPattern["div"], XMLPattern["span"]]]},
  {{"p", "span", "p"}, {XMLElement["p", {}, {}]}},
  TestID -> "union-mixed-with-element-pattern-no-root"
];

(* === As a stage === *)

$stageDoc = html["<div id=\"d\"><section id=\"s\"><b><a id=\"x\"></a></b></section><a id=\"y\"></a><i><a id=\"z\"></a></i></div>"];

TestCreate[
  {ids @ XMLCases[$stageDoc, Child[XMLPattern["div"], Descendant[XMLPattern["section"], XMLPattern["a"]] | XMLPattern["a"]]],
   ids @ XMLCases[$stageDoc, Child[XMLPattern["div"], Descendant[XMLPattern["section"], XMLPattern["a"]]]],
   ids @ XMLCases[$stageDoc, Child[XMLPattern["div"], XMLPattern["a"]]]},
  {{"x", "y"}, {"x"}, {"y"}},
  TestID -> "union-as-stage"
];

(* Two stages that are alternatives run the four chains a Child d, a Child e
   Child f, b Child c Child d, b Child c Child e Child f. *)
$fourDoc = html["<a><d id=\"1\"></d><e><f id=\"2\"></f></e></a><b><c><d id=\"3\"></d><e><f id=\"4\"></f></e></c></b><e><f id=\"5\"></f></e>"];

TestCreate[
  ids @ XMLCases[$fourDoc,
    Child[XMLPattern["a"] | Child[XMLPattern["b"], XMLPattern["c"]], XMLPattern["d"] | Child[XMLPattern["e"], XMLPattern["f"]]]],
  {"1", "2", "3", "4"},
  TestID -> "union-two-stages-of-alternatives"
];

(* === Names === *)

$nameDoc = html["<section id=\"s\"><div id=\"d\"><p></p></div></section>"];

TestCreate[
  XMLCases[$nameDoc,
    Child[XMLPattern["div", "id" -> i_], XMLPattern["p"]] | Descendant[XMLPattern["section", "id" -> j_], XMLPattern["p"]] :> {i, j}],
  {{"d"}},
  TestID -> "union-unbound-name-is-empty-sequence"
];

TestCreate[
  XMLCases[$nameDoc,
    Child[XMLPattern["div", "id" -> i_], XMLPattern["p"]] | Descendant[XMLPattern["section", "id" -> i_], XMLPattern["p"]] :> i],
  {"d"},
  TestID -> "union-first-alternative-binds"
];

(* A test that rejects the first alternative's tuples moves on to the next:
   on the alternatives, on a combinator holding them, and in the body. In the
   second, i is unbound in the first alternative, so {i} is {}. *)
TestCreate[
  With[{a = Child[XMLPattern["div", "id" -> i_], XMLPattern["p"]], b = Descendant[XMLPattern["section", "id" -> i_], XMLPattern["p"]]},
    {XMLCases[$nameDoc, ((a | b) /; i === "s") :> i],
     XMLCases[$nameDoc, Descendant[XMLPattern["body"], Child[XMLPattern["div"], XMLPattern["p"]] | Descendant[XMLPattern["section", "id" -> i_], XMLPattern["p"]]] /; {i} === {"s"} :> i],
     XMLCases[$nameDoc, Descendant[XMLPattern["body"], (Child[XMLPattern["div", "id" -> i_], XMLPattern["p"]] | Descendant[XMLPattern["section", "id" -> i_], XMLPattern["p"]]) /; i === "s"] :> i],
     XMLCases[$nameDoc, (a | b) :> (i /; i === "s")]}],
  {{"s"}, {"s"}, {"s"}, {"s"}},
  TestID -> "union-rejection-moves-to-next-alternative"
];

(* The choice of alternative ranks above the choice of an earlier stage
   (ADR 0015's example). *)
TestCreate[
  XMLCases[html["<div id=\"x\"><div id=\"y\"><p><a id=\"y\"></a></p></div></div>"],
    Descendant[XMLPattern["div", "id" -> i_], XMLPattern["a", "id" -> i_] | Child[XMLPattern["p"], XMLPattern["a"]]] :> i],
  {"y"},
  TestID -> "union-alternative-ranks-above-stage-choice"
];

(* A name of an alternative that did not match is empty in a Condition on the
   alternatives, but a Condition inside one alternative sees only its own
   names, as in WL. *)
TestCreate[
  Block[{j = "global"},
    {XMLCases[$nameDoc, (Child[XMLPattern["div", "id" -> i_], XMLPattern["p"]] | Descendant[XMLPattern["section", "id" -> j_], XMLPattern["p"]]) /; {i, j} === {"d"} :> i],
     XMLCases[$nameDoc, (Child[XMLPattern["div", "id" -> i_], XMLPattern["p"]] /; j === "global") | Descendant[XMLPattern["section", "id" -> j_], XMLPattern["p"]] :> i]}],
  {{"d"}, {"d"}},
  TestID -> "union-condition-scoping"
];

(* -> rhs: rhs is evaluated once, and the names replaced in its value. *)
TestCreate[
  Module[{count = 0},
    {XMLCases[$nameDoc,
       Child[XMLPattern["div", "id" -> i_], XMLPattern["p"]] | Descendant[XMLPattern["section", "id" -> j_], XMLPattern["p"]] -> (count++; {i, j})],
     count}],
  {{{"d"}}, 1},
  TestID -> "union-literal-rule"
];

(* With list keys renamed (an element name and a class list), an unbound
   element name is empty too. *)
TestCreate[
  XMLCases[html["<div class=\"k\"><p id=\"1\"></p></div><section><p id=\"2\"></p></section>"],
    Child[e : XMLPattern["div", "classList" -> "k"], XMLPattern["p", "id" -> n_]] |
      Child[f : XMLPattern["section"], XMLPattern["p", "id" -> n_]] :> {n, First /@ {e, f}}],
  {{"1", {"div"}}, {"2", {"section"}}},
  TestID -> "union-unbound-element-name-with-list-keys"
];

(* A body that is only an unbound name gives Sequence[], which Cases drops. *)
TestCreate[
  XMLCases[$nameDoc,
    Child[XMLPattern["div"], XMLPattern["p"]] | Descendant[XMLPattern["section", "id" -> j_], XMLPattern["p"]] :> j],
  {},
  TestID -> "union-body-of-only-an-unbound-name"
];

(* === XMLFirstCase === *)

(* The second alternative's match comes first in the document. *)
TestCreate[
  {XMLFirstCase[$unionDoc, Child[XMLPattern["ul"], XMLPattern["li", "id" -> k_]] | Descendant[XMLPattern["nav"], XMLPattern["a", "id" -> k_]] :> k],
   XMLFirstCase[$unionDoc, Child[XMLPattern["ul"], XMLPattern["li"]] | XMLPattern["a", "id" -> "a3"]][[2, -1]],
   XMLFirstCase[$nameDoc, Child[XMLPattern["div", "id" -> i_], XMLPattern["p"]] | Descendant[XMLPattern["section", "id" -> i_], XMLPattern["p"]] :> i],
   XMLFirstCase[$nameDoc, Child[XMLPattern["div", "id" -> i_], XMLPattern["p"]] | Descendant[XMLPattern["section", "id" -> i_], XMLPattern["p"]] :> (i /; i === "s")],
   XMLFirstCase[$nameDoc, Child[XMLPattern["div"], XMLPattern["i"]] | Child[XMLPattern["p"], XMLPattern["b"]], "none"]},
  {"a1", "id" -> "l1", "d", "s", "none"},
  TestID -> "union-first-case"
];

(* A rule body is evaluated for the match XMLFirstCase gives only. *)
TestCreate[
  Module[{seen = {}},
    {XMLFirstCase[$unionDoc, Child[XMLPattern["ul"], XMLPattern["li", "id" -> k_]] | Descendant[XMLPattern["nav"], XMLPattern["a", "id" -> k_]] :> (AppendTo[seen, k]; k)],
     seen}],
  {"a1", {"a1"}},
  TestID -> "union-first-case-evaluates-one-body"
];

(* === XMLDeleteCases === *)

TestCreate[
  {ids @ XMLCases[XMLDeleteCases[$unionDoc, Child[XMLPattern["ul"], XMLPattern["li"]] | Descendant[XMLPattern["nav"], XMLPattern["a"]]], XMLPattern[_, "id" -> _]],
   ids @ XMLCases[XMLDeleteCases[$unionDoc, XMLPattern["ul"] | Descendant[XMLPattern["nav"], XMLPattern["a"]]], XMLPattern[_, "id" -> _]]},
  {{"n", "u", "u2", "a3"}, {"n", "a3"}},
  TestID -> "union-delete-cases"
];

TestCreate[
  {XMLDeleteCases[$unionDoc, Child[XMLPattern["ul"], XMLPattern["li"]] | Sibling[XMLPattern["nav"], XMLPattern["a"]]],
   XMLDeleteCases[$unionDoc, Child[XMLPattern["ul"], XMLPattern["li"] | Descendant[XMLPattern["b"], Adjacent[XMLPattern["a"], XMLPattern["i"]]]]],
   XMLDeleteCases[$unionDoc, Child[XMLPattern["ul"], XMLPattern["li"]] | XMLPattern["a"] :> 1]},
  {$Failed, $Failed, $Failed},
  {XMLDeleteCases::unsupported, XMLDeleteCases::unsupported, XMLDeleteCases::badpat},
  TestID -> "union-delete-cases-refusals"
];

(* === List keys across alternatives === *)

TestCreate[
  With[{doc = html["<div class=\"a\"><p id=\"1\"></p></div><nav><b><a id=\"2\" rel=\"next prev\"></a></b><a id=\"3\" rel=\"up\"></a></nav>"]},
    {XMLCases[doc,
       Child[XMLPattern["div", "classList" -> "a"], XMLPattern["p"]] | Descendant[XMLPattern["nav"], XMLPattern["a", "relList" -> "next"]],
       "AttributeReadings" -> <|"rel" -> <||>|>],
     XMLCases[doc,
       Child[e : XMLPattern["div", "classList" -> "a"], XMLPattern["p"]] | Descendant[XMLPattern["nav"], e : XMLPattern["a", "relList" -> "next"]] :> e,
       "AttributeReadings" -> <|"rel" -> <||>|>]}],
  {{XMLElement["p", {"id" -> "1"}, {}], XMLElement["a", {"shape" -> "rect", "id" -> "2", "rel" -> "next prev"}, {}]},
   {XMLElement["div", {"class" -> "a"}, {XMLElement["p", {"id" -> "1"}, {}]}], XMLElement["a", {"shape" -> "rect", "id" -> "2", "rel" -> "next prev"}, {}]}},
  TestID -> "union-list-keys-across-alternatives"
];

(* === Refusals that stay === *)

TestCreate[
  {XMLCases[$unionDoc, u : (Child[XMLPattern["ul"], XMLPattern["li"]] | XMLPattern["a"])],
   XMLFirstCase[$unionDoc, Child[XMLPattern["nav"], u : (Child[XMLPattern["ul"], XMLPattern["li"]] | XMLPattern["a"])]]},
  {$Failed, $Failed},
  {XMLCases::badpat, XMLFirstCase::badpat},
  TestID -> "union-named-refused"
];

TestCreate[
  XMLCases[$unionDoc, (u : Child[XMLPattern["ul"], XMLPattern["li"]]) | XMLPattern["a"]],
  $Failed,
  {XMLCases::badpat},
  TestID -> "union-named-combinator-inside-refused"
];

(* XMLMatchQ and the Roles and Constructs rules test one element, and refuse
   alternatives holding a combinator as they refuse a combinator. *)
TestCreate[
  With[{el = XMLElement["p", {}, {"x"}], u = Child[XMLPattern["div"], XMLPattern["p"]] | XMLPattern["p"]},
    {XMLMatchQ[el, u], XMLMatchQ[u][el], XMLMatchQ[el, u /; True],
     HTMLInnerText[el, "Roles" -> {u -> "Skip"}], HTMLToNotebook[el, "Constructs" -> {u -> "Bold"}]}],
  {$Failed, $Failed, $Failed, $Failed, $Failed},
  {XMLMatchQ::combinator, XMLMatchQ::combinator, XMLMatchQ::condcombinator, HTMLInnerText::badpat, HTMLToNotebook::badpat},
  TestID -> "union-refused-where-one-element-is-tested"
];

TestCreate[
  XMLCases[$unionDoc, (Child[XMLPattern["ul"], XMLPattern["li"]] | XMLPattern["a"])?(True &)],
  $Failed,
  {XMLCases::testcombinator},
  TestID -> "union-test-refused"
];

(* === Unchanged === *)

(* Alternatives of element patterns as a stage are one stage of one chain. *)
TestCreate[
  ids @ XMLCases[$unionDoc, Child[XMLPattern["nav"] | XMLPattern["li"], XMLPattern["a"]]],
  {"a1", "a2"},
  TestID -> "union-element-alternatives-stage-unchanged"
];
