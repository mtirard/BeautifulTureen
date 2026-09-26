(* Result order: XMLCases and XMLFirstCase give matches in document order, as
   querySelectorAll and soupsieve's select do: an element before the elements
   nested in it, an earlier sibling before a later one. All fixtures here are
   local to this file. *)

$nested = XMLElement["body", {}, {
  XMLElement["div", {"id" -> "outer"}, {
    XMLElement["div", {"id" -> "inner"}, {XMLElement["p", {}, {}]}]}]}];

(* An element comes before the elements nested in it *)
TestCreate[
  XMLCases[$nested, XMLPattern["div", "id" -> id_] :> id],
  {"outer", "inner"},
  TestID -> "order-nested-outer-first"
];

(* The same without a rule: the elements themselves *)
TestCreate[
  XMLCases[XMLElement["body", {}, {XMLElement["div", {}, {XMLElement["div", {}, {XMLElement["p", {}, {}]}]}]}],
    XMLPattern["div"]],
  {XMLElement["div", {}, {XMLElement["div", {}, {XMLElement["p", {}, {}]}]}],
    XMLElement["div", {}, {XMLElement["p", {}, {}]}]},
  TestID -> "order-nested-plain-outer-first"
];

(* An earlier sibling comes before a later one *)
TestCreate[
  XMLCases[XMLElement["ul", {}, {XMLElement["li", {}, {"a"}], XMLElement["li", {}, {"b"}], XMLElement["li", {}, {"c"}]}],
    li : XMLPattern["li"] :> HTMLTextContent[li]],
  {"a", "b", "c"},
  TestID -> "order-siblings"
];

(* Nested and sibling matches together: pre-order, as the tags are written *)
$mixed = ImportString[
  "<html><body><section id='1'><div id='2'><p id='3'></p><p id='4'><b id='5'></b></p></div><p id='6'></p></section><div id='7'></div></body></html>",
  {"HTML", "XMLObject"}];

TestCreate[
  XMLCases[$mixed, XMLPattern[_, "id" -> id_] :> id],
  {"1", "2", "3", "4", "5", "6", "7"},
  TestID -> "order-nested-and-siblings"
];

(* An Alternatives and a conditioned pattern keep the same order *)
TestCreate[
  XMLCases[$mixed, (XMLPattern["div", "id" -> id_] | XMLPattern["p", "id" -> id_]) /; id != "4" :> id],
  {"2", "3", "6", "7"},
  TestID -> "order-alternatives-condition"
];

(* A combinator gives its last stage's elements in the same order *)
TestCreate[
  XMLCases[$mixed, Descendant[XMLPattern["body"], XMLPattern[_, "id" -> id_]] :> id],
  {"1", "2", "3", "4", "5", "6", "7"},
  TestID -> "order-combinator"
];

(* A nested chain too *)
TestCreate[
  XMLCases[$mixed, Child[Descendant[XMLPattern["body"], XMLPattern["section" | "div" | "p"]], XMLPattern[_, "id" -> id_]] :> id],
  {"2", "3", "4", "5", "6"},
  TestID -> "order-nested-chain"
];

(* === XMLFirstCase: the first in document order === *)

(* Of nested matches, the outermost, as querySelector gives *)
TestCreate[
  XMLFirstCase[$nested, XMLPattern["div", "id" -> id_] :> id],
  "outer",
  TestID -> "first-nested-outer"
];

(* The same without a rule *)
TestCreate[
  XMLFirstCase[$nested, XMLPattern["div"]],
  XMLElement["div", {"id" -> "outer"}, {XMLElement["div", {"id" -> "inner"}, {XMLElement["p", {}, {}]}]}],
  TestID -> "first-nested-plain-outer"
];

(* The first element in document order, nested matches and siblings together *)
TestCreate[
  XMLFirstCase[$mixed, XMLPattern["div" | "p", "id" -> id_] :> id],
  "2",
  TestID -> "first-nested-and-siblings"
];

(* A rule's body is evaluated for the match given, and for no other *)
TestCreate[
  Reap[XMLFirstCase[$mixed, XMLPattern[_, "id" -> id_] :> (Sow[id]; id)]],
  {"1", {{"1"}}},
  TestID -> "first-rule-body-evaluated-once"
];

(* XMLCases evaluates a rule's body once per match, in document order *)
TestCreate[
  Reap[XMLCases[$mixed, XMLPattern["p", "id" -> id_] :> (Sow[id]; id)]],
  {{"3", "4", "6"}, {{"3", "4", "6"}}},
  TestID -> "cases-rule-body-evaluated-in-order"
];

(* A Condition on a rule's body that rejects the first match moves on to the
   next in document order *)
TestCreate[
  XMLFirstCase[$mixed, XMLPattern[_, "id" -> id_] :> id /; ToExpression[id] > 3],
  "4",
  TestID -> "first-rule-body-condition-moves-on"
];

(* A combinator: the first in document order of its last stage's elements *)
TestCreate[
  XMLFirstCase[$mixed, Descendant[XMLPattern["body"], XMLPattern["p" | "div", "id" -> id_]] :> id],
  "2",
  TestID -> "first-combinator"
];
