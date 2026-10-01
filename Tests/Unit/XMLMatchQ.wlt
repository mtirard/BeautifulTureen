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
   follows a change to $AttributeReadings between them. *)
TestCreate[
  With[{op = XMLMatchQ[XMLPattern["a", "relList" -> "next"]], a = XMLElement["a", {"rel" -> "next"}, {}]},
    {op[a], Block[{$AttributeReadings = Append[$AttributeReadings, "rel" -> <||>]}, op[a]], op[a]}],
  {False, True, False},
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
    {XMLMatchQ::badpat}],
  {{}, 2},
  TestID -> "xmlmatchq-operator-form-messages-on-each-call"
];

TestCreate[
  XMLMatchQ[_String],
  XMLMatchQ[_String],
  TestID -> "xmlmatchq-operator-form-is-inert"
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
