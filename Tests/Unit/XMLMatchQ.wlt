(* XMLMatchQ (ADR 0013): a whole-element test, as StringMatchQ is a whole-string
   test beside a family that searches. All fixtures here are local to this file. *)

$lead = XMLElement["p", {"class" -> "lead promo"}, {"x", XMLElement["b", {"class" -> "ad"}, {"y"}]}];

TestCreate[
  {XMLMatchQ[$lead, XMLPattern["p"]], XMLMatchQ[$lead, XMLPattern["b"]]},
  {True, False},
  TestID -> "xmlmatchq-tag"
];

TestCreate[
  {XMLMatchQ[$lead, XMLPattern["p", "classList" -> "promo"]],
   XMLMatchQ[$lead, XMLPattern["p", "classList" -> "ad"]]},
  {True, False},
  TestID -> "xmlmatchq-classlist"
];

(* The whole element, not a search: a matching child does not count. *)
TestCreate[
  XMLMatchQ[$lead, XMLPattern["b"]],
  False,
  TestID -> "xmlmatchq-is-not-a-search"
];

TestCreate[
  XMLMatchQ[$lead, XMLPattern["b"] | XMLPattern["p", "classList" -> {"lead", ___}]],
  True,
  TestID -> "xmlmatchq-alternatives"
];

(* A condition's test sees the original element. *)
TestCreate[
  XMLMatchQ[$lead, e : XMLPattern["p", "classList" -> {_, _}] /; e === $lead],
  True,
  TestID -> "xmlmatchq-condition-sees-original"
];

(* A condition on the whole pattern sees every attribute name, not only the
   first constraint's. *)
TestCreate[
  XMLMatchQ[XMLElement["a", {"href" -> "/buy", "data-id" -> "buy"}, {}],
    XMLPattern["a", {"href" -> h_, "data-id" -> i_}] /; StringContainsQ[h, i]],
  True,
  TestID -> "xmlmatchq-condition-sees-every-attribute-name"
];

TestCreate[
  Select[{$lead, XMLElement["p", {}, {}], "text"}, XMLMatchQ[XMLPattern["p", "classList" -> {}]]],
  {XMLElement["p", {}, {}]},
  TestID -> "xmlmatchq-operator-form"
];

(* The operator form keeps its compiled query between calls (issue #2), and
   follows a change to $AttributeReadings between them. Without the reading,
   "relList" is warned about once, when the kept query is first compiled. *)
TestCreate[
  With[{op = XMLMatchQ[XMLPattern["a", "relList" -> "next"]], a = XMLElement["a", {"rel" -> "next"}, {}]},
    {op[a], Block[{$AttributeReadings = Append[$AttributeReadings, "rel" -> <||>]}, op[a]], op[a]}],
  {False, True, False},
  {XMLPattern::nolistreading},
  TestID -> "xmlmatchq-operator-form-follows-readings"
];

(* The "AttributeReadings" option is read by value on each call, so a delayed
   option follows a change to what it names. *)
TestCreate[
  Module[{r = <|"rel" -> <||>|>, op, a = XMLElement["a", {"rel" -> "next"}, {}]},
    op = XMLMatchQ[XMLPattern["a", "relList" -> "next"], "AttributeReadings" :> r];
    {op[a], r = <||>; op[a]}],
  {True, False},
  TestID -> "xmlmatchq-operator-form-reads-delayed-option"
];

(* A refused pattern gives its message on each element, and the operator form
   stays unevaluated, as MatchQ[pattern] does. *)
TestCreate[
  Quiet[
    {Select[{$lead, $lead}, XMLMatchQ[_String]], Length[$MessageList]},
    {XMLMatchQ::blank}],
  {{}, 2},
  TestID -> "xmlmatchq-operator-form-messages-on-each-call"
];

TestCreate[
  XMLMatchQ[_String],
  XMLMatchQ[_String],
  TestID -> "xmlmatchq-operator-form-is-inert"
];

TestCreate[
  XMLMatchQ[$lead, XMLPattern["p", "a"]["b"]],
  $Failed,
  {XMLPattern::constraint},
  TestID -> "xmlmatchq-xmlpattern-refusal"
];

TestCreate[
  {XMLMatchQ[$lead, _String], XMLMatchQ[$lead, 42]},
  {$Failed, $Failed},
  {XMLMatchQ::blank, XMLMatchQ::badpat},
  TestID -> "xmlmatchq-refuses-non-xml-pattern"
];

(* A rule gives a value, not a test, whether -> or :> *)
TestCreate[
  {XMLMatchQ[$lead, XMLPattern["p"] -> 1], XMLMatchQ[$lead, XMLPattern["p"] :> 1]},
  {$Failed, $Failed},
  {XMLMatchQ::badpat, XMLMatchQ::badpat},
  TestID -> "xmlmatchq-refuses-rule"
];

(* === Tree patterns === *)

nav = doc[e["nav", "o", e["a", "a1"], e["nav", "i", e["a", "a2"]], e["a", "a3"]]];
row = doc[el["tr", el["th", "a"], el["td", "a"], el["td", "b"]]];

(* The element is the pattern root; constraints look below it. *)
TestCreate[
  {XMLMatchQ[nav[[2]], XMLPattern["nav"][Descendant[XMLPattern["a"], {2}]]],
    XMLMatchQ[nav[[2]], XMLPattern["nav"][Descendant[XMLPattern["a"], {3}]]]},
  {True, False},
  TestID -> "xmlmatchq-tree-pattern-root"
];

(* An XMLElement pattern is matched whole, contents included. *)
TestCreate[
  {XMLMatchQ[nav[[2, 3, 2]], XMLElement["nav", _, {XMLElement["a", {"id" -> "a2"}, {}]}]],
    XMLMatchQ[nav[[2, 3, 2]], XMLElement["nav", _, {XMLElement["a", {"id" -> "a1"}, {}]}]]},
  {True, False},
  TestID -> "xmlmatchq-xmlelement-pattern"
];

(* An XMLDocument pattern tests a document; an element is not one. *)
TestCreate[
  {XMLMatchQ[nav, XMLDocument[{XMLPattern["nav"]}]], XMLMatchQ[nav, XMLDocument[{XMLPattern["a"]}]],
    XMLMatchQ[nav[[2]], XMLDocument[{XMLPattern["nav"]}]], XMLMatchQ[nav[[2]], XMLDocument[]]},
  {True, False, False, False},
  TestID -> "xmlmatchq-document-pattern"
];

(* A kind mismatch is False: a document or a list against an element
   pattern. *)
TestCreate[
  {XMLMatchQ[nav, XMLPattern["nav"]], XMLMatchQ[nav, XMLPattern[_][Descendant[XMLPattern["a"]]]],
    XMLMatchQ[{el["a"]}, XMLPattern["a"]], XMLMatchQ[{el["a"]}, XMLDocument[{XMLPattern["a"]}]]},
  {False, False, False, False},
  TestID -> "xmlmatchq-kind-mismatch"
];

(* The same in the operator form, for each kind of pattern root. *)
TestCreate[
  {XMLMatchQ[XMLPattern["nav"]] /@ {nav, {nav[[2]]}},
    XMLMatchQ[XMLDocument[{XMLPattern["nav"]}]] /@ {nav[[2]], {nav[[2]]}},
    XMLMatchQ[{___}] /@ {nav[[2]], nav}},
  {{False, False}, {False, False}, {False, False}},
  TestID -> "xmlmatchq-operator-form-kind-mismatch"
];

(* An input that is not a tree is not refused: it matches nothing, as in
   MatchQ. *)
TestCreate[
  {XMLMatchQ[42, XMLPattern["nav"]], XMLMatchQ[{el["a"], 5}, XMLPattern["a"]], XMLMatchQ[{el["a"], 5}, {___}],
    XMLMatchQ[XMLPattern["nav"]][42], XMLMatchQ[{___}][{el["a"], 5}], XMLMatchQ[XMLDocument[]]["x"]},
  {False, False, False, False, False, False},
  TestID -> "xmlmatchq-non-tree-is-false"
];

(* A list of elements against a list pattern, in the contents-list grammar:
   strings are skipped. An element is not a list. *)
TestCreate[
  {XMLMatchQ[row[[2, 3]], {XMLPattern["th"], ___}], XMLMatchQ[row[[2, 3]], {XMLPattern["td"], ___}],
    XMLMatchQ[{" ", el["a"], "x", el["b"]}, {XMLPattern["a"], XMLPattern["b"]}],
    XMLMatchQ[{}, {}], XMLMatchQ[row[[2]], {___}], XMLMatchQ[row, {___}]},
  {True, False, True, True, False, False},
  TestID -> "xmlmatchq-list-pattern"
];

(* Named, conditioned, tested and alternative list patterns, as constraints
   take them. *)
TestCreate[
  {XMLMatchQ[row[[2, 3]], l : {__} /; Length[l] == 3], XMLMatchQ[row[[2, 3]], l : {__} /; Length[l] == 2],
    XMLMatchQ[row[[2, 3]], {___, XMLPattern["th"]} | {___, XMLPattern["td"]}],
    XMLMatchQ[row[[2, 3]], {__}?(Length[#] == 3 &)],
    XMLMatchQ[{el["a"]}, {XMLPattern["a"]}]},
  {True, False, True, True, True},
  TestID -> "xmlmatchq-list-pattern-forms"
];

(* Lists over the path a named Descendant matches. *)
TestCreate[
  {XMLCases[nav, XMLDocument[p : Descendant[x : XMLPattern["a"]] /; XMLMatchQ[p, {___, XMLPattern["nav", "id" -> "i"], ___}]] :> x[[2]]],
    XMLCases[nav, XMLDocument[Descendant[x : XMLPattern["a"]]?(NoneTrue[XMLMatchQ["nav#i"]])] :> x[[2]]]},
  {{{"id" -> "a2"}}, {{"id" -> "a1"}, {"id" -> "a3"}}},
  TestID -> "xmlmatchq-path-tests"
];

(* A list entry that is not one element child is refused under XMLMatchQ. *)
TestCreate[
  XMLMatchQ[{el["a"]}, {Descendant[XMLPattern["a"]]}],
  $Failed,
  {XMLMatchQ::listentry},
  TestID -> "xmlmatchq-list-entry-refused"
];

(* A rule, and a context selector, which looks above the element, are
   refused; so is Descendant, which is a constraint, not a pattern. *)
TestCreate[
  {XMLMatchQ[el["a"], x : XMLPattern["a"] :> x], XMLMatchQ[el["a"], "nav a"], XMLMatchQ[el["a"], Descendant[XMLPattern["a"]]]},
  {$Failed, $Failed, $Failed},
  {XMLMatchQ::badpat, XMLMatchQ::badpat, Descendant::place},
  TestID -> "xmlmatchq-refusals"
];

TestCreate[
  XMLMatchQ[el["a"], "a" | "nav a"],
  $Failed,
  {XMLMatchQ::badpat},
  TestID -> "xmlmatchq-refuses-context-selector-in-alternatives"
];

(* The operator form takes tree patterns and list patterns. *)
TestCreate[
  {Select[{nav[[2]], nav[[2, 3, 2]], nav}, XMLMatchQ[XMLPattern[_][Descendant[XMLPattern["a"]]]]],
    Select[{row[[2, 3]], {}}, XMLMatchQ[{___, XMLPattern["td"]}]]},
  {{nav[[2]], nav[[2, 3, 2]]}, {row[[2, 3]]}},
  TestID -> "xmlmatchq-operator-form-tree-patterns"
];

(* A list pattern at a list key, in a tree pattern, gives no message. *)
TestCreate[
  With[{p = XMLPattern["div", "classList" -> {t_, ___}][{___}] /; t == "a"},
    {XMLMatchQ[XMLElement["div", {"class" -> "a b"}, {XMLElement["p", {}, {}]}], p],
      XMLMatchQ[p][XMLElement["div", {"class" -> "b a"}, {XMLElement["p", {}, {}]}]]}],
  {True, False},
  {},
  TestID -> "xmlmatchq-token-list-in-tree-pattern"
];

(* Such a list pattern is compiled while the test runs; a mistake in it is
   still refused under XMLMatchQ, in both forms. *)
TestCreate[
  With[{p = XMLPattern["div", "classList" -> {___, (x_ | y_ ..)?StringQ, ___}][{___}]},
    {XMLMatchQ[XMLElement["div", {"class" -> "a b"}, {XMLElement["p", {}, {}]}], p],
      XMLMatchQ[p][XMLElement["div", {"class" -> "a b"}, {XMLElement["p", {}, {}]}]]}],
  {$Failed, $Failed},
  {XMLMatchQ::badpat, XMLMatchQ::badpat},
  TestID -> "xmlmatchq-token-list-refused-while-running"
];

(* A search in a Condition searches all of the element it is given, however
   little of it the test itself reads. *)
TestCreate[
  Module[{found = {}, deep = XMLElement["div", {}, {XMLElement["p", {}, {XMLElement["b", {}, {XMLElement["span", {}, {"x"}]}]}]}]},
    {XMLMatchQ[deep, x : XMLPattern["div"][{___}] /; (AppendTo[found, Length[XMLCases[x, "span"]]]; True)],
      XMLMatchQ[x : XMLPattern["div"][{___}] /; (AppendTo[found, Length[XMLCases[x, "span"]]]; True)][deep],
      found}],
  {True, True, {1, 1}},
  TestID -> "xmlmatchq-search-in-condition"
];
