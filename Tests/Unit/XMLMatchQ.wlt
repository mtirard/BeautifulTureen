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

TestCreate[
  Select[{$lead, XMLElement["p", {}, {}], "text"}, XMLMatchQ[XMLPattern["p", "classList" -> {}]]],
  {XMLElement["p", {}, {}]},
  TestID -> "xmlmatchq-operator-form"
];

(* A combinator relates an element to a parent or siblings a lone element lacks. *)
TestCreate[
  XMLMatchQ[$lead, Child[XMLPattern["p"], XMLPattern["b"]]],
  $Failed,
  {XMLMatchQ::combinator},
  TestID -> "xmlmatchq-refuses-combinator"
];

TestCreate[
  XMLMatchQ[$lead, XMLPattern["p", "a", "b"]],
  $Failed,
  {XMLPattern::nargs},
  TestID -> "xmlmatchq-xmlpattern-refusal"
];

TestCreate[
  XMLMatchQ[$lead, _String],
  $Failed,
  {XMLMatchQ::badpat},
  TestID -> "xmlmatchq-refuses-non-xml-pattern"
];
