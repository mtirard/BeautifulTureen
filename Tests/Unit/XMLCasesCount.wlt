(* XMLCases[tree, pattern, n]: at most n results, the first n of
   XMLCases[tree, pattern] in document order (issue #14, ADR 0019). *)

(* Nested matches: Cases order would give c before b before a. *)
$countNested = XMLElement["body", {}, {
  XMLElement["div", {"id" -> "a"}, {
    XMLElement["div", {"id" -> "b"}, {XMLElement["div", {"id" -> "c"}, {}]}]}],
  XMLElement["div", {"id" -> "d"}, {}]}];

$countFlat = XMLElement["ul", {}, Table[XMLElement["li", {}, {ToString[i]}], {i, 5}]];

TestCreate[
  Table[XMLCases[$countNested, XMLPattern["div", "id" -> id_] :> id, n], {n, 0, 4}],
  {{}, {"a"}, {"a", "b"}, {"a", "b", "c"}, {"a", "b", "c", "d"}},
  TestID -> "count-first-n-in-document-order"
];

TestCreate[
  XMLCases[$countNested, XMLPattern["div"], 2],
  Take[XMLCases[$countNested, XMLPattern["div"]], 2],
  TestID -> "count-plain-pattern-gives-elements"
];

(* n is a ceiling: fewer matches give all of them. *)
TestCreate[
  {XMLCases[$countNested, XMLPattern["div", "id" -> id_] :> id, 10],
    XMLCases[$countNested, XMLPattern["div", "id" -> id_] :> id, Infinity],
    XMLCases[$countNested, XMLPattern["table"], 3]},
  {{"a", "b", "c", "d"}, {"a", "b", "c", "d"}, {}},
  TestID -> "count-is-a-ceiling"
];

TestCreate[
  XMLCases[$tree, XMLPattern["p"], 0],
  {},
  TestID -> "count-zero-gives-empty-list"
];

(* The body is evaluated only for the returned matches. *)
TestCreate[
  Reap[XMLCases[$countFlat, x : XMLPattern["li"] :> (Sow[HTMLTextContent[x]]; HTMLTextContent[x]), 2]],
  {{"1", "2"}, {{"1", "2"}}},
  TestID -> "count-body-evaluated-only-for-returned-matches"
];

(* The traversal stops at the nth match: a test is not applied past it. *)
TestCreate[
  Reap[XMLCases[$countFlat, XMLPattern["li"]?((Sow[First[Last[#]]]; True) &), 2]][[2]],
  {{"1", "2"}},
  TestID -> "count-traversal-stops-at-nth-match"
];

(* As in Cases, a rule's right-hand side is evaluated once, before any
   matching, even for n = 0. *)
TestCreate[
  Reap[XMLCases[$countFlat, XMLPattern["li"] -> Sow["rhs"], 0]],
  {{}, {{"rhs"}}},
  TestID -> "count-rule-rhs-evaluated-once-for-zero"
];

(* A Condition in the body can reject a match; n counts the values given. *)
TestCreate[
  XMLCases[$countFlat, x : XMLPattern["li"] :> HTMLTextContent[x] /; OddQ[ToExpression[HTMLTextContent[x]]], 2],
  {"1", "3"},
  TestID -> "count-body-condition-counts-values-given"
];

TestCreate[
  XMLCases[$countNested, Descendant[XMLPattern["body"], XMLPattern["div", "id" -> id_]] :> id, 3],
  {"a", "b", "c"},
  TestID -> "count-combinator-first-n"
];

TestCreate[
  XMLCases[$tree, Child[XMLPattern["div"], XMLPattern["p"]], 2],
  Take[XMLCases[$tree, Child[XMLPattern["div"], XMLPattern["p"]]], 2],
  TestID -> "count-combinator-plain-gives-elements"
];

TestCreate[
  Reap[XMLCases[$countFlat, Child[XMLPattern["ul"], x : XMLPattern["li"]] :> (Sow[HTMLTextContent[x]]; HTMLTextContent[x]), 2]],
  {{"1", "2"}, {{"1", "2"}}},
  TestID -> "count-combinator-body-evaluated-only-for-returned-matches"
];

TestCreate[
  XMLCases[$countFlat,
    Child[XMLPattern["ul"], x : XMLPattern["li"]] :> HTMLTextContent[x] /; EvenQ[ToExpression[HTMLTextContent[x]]], 1],
  {"2"},
  TestID -> "count-combinator-body-condition"
];

(* Known issue: a combinator collects every candidate before the first n are
   taken, so a test on a stage still sees the elements past the nth result.
   ADR 0019 records the gap; this passes once combinators stop early. *)
TestCreate[
  Reap[XMLCases[$countFlat,
    Child[XMLPattern["ul"], XMLPattern["li"]?((Sow[First[Last[#]]]; True) &)], 2]][[2]],
  {{"1", "2"}},
  TestID -> "count-combinator-traversal-stops-at-nth-match"
] // TagTest["KnownIssue"];

(* Options come after n. *)
TestCreate[
  XMLCases[
    XMLElement["div", {}, {XMLElement["p", {"rel" -> "x y"}, {"1"}],
      XMLElement["p", {"rel" -> "y"}, {"2"}], XMLElement["p", {"rel" -> "x"}, {"3"}]}],
    XMLPattern["p", "relList" -> "x"] :> 0, 1,
    "AttributeReadings" -> <|"rel" -> <||>|>],
  {0},
  TestID -> "count-options-after-n"
];

TestCreate[
  XMLCases[
    XMLElement["div", {}, {XMLElement["p", {"rel" -> "x y"}, {"1"}],
      XMLElement["p", {"rel" -> "y"}, {"2"}], XMLElement["p", {"rel" -> "x"}, {"3"}]}],
    XMLPattern["p", "relList" -> "x"], 2,
    "AttributeReadings" -> <|"rel" -> <||>|>],
  {XMLElement["p", {"rel" -> "x y"}, {"1"}], XMLElement["p", {"rel" -> "x"}, {"3"}]},
  TestID -> "count-options-after-n-strips-list-keys"
];

TestCreate[
  XMLCases[42, XMLPattern["p"], 2],
  $Failed,
  {XMLCases::badtree},
  TestID -> "count-bad-tree-still-refused"
];

(* ---- Invalid n ----
   A non-negative integer or Infinity; anything else gives innf and the call
   stays unevaluated. UpTo is refused, as in StringCases. *)

TestCreate[
  {Head[#], List @@ #} & /@ Map[XMLCases[$countFlat, XMLPattern["li"], #] &, {-1, 1.5}],
  {XMLCases, {$countFlat, XMLPattern["li"], #}} & /@ {-1, 1.5},
  {XMLCases::innf, XMLCases::innf},
  TestID -> "count-invalid-n-negative-or-real"
];

TestCreate[
  {Head[#], List @@ #} & /@ Map[XMLCases[$countFlat, XMLPattern["li"], #] &, {All, {2}}],
  {XMLCases, {$countFlat, XMLPattern["li"], #}} & /@ {All, {2}},
  {XMLCases::innf, XMLCases::innf},
  TestID -> "count-invalid-n-all-or-levelspec"
];

TestCreate[
  {Head[#], List @@ #} & /@ Map[XMLCases[$countFlat, XMLPattern["li"], #] &, {UpTo[2], "2"}],
  {XMLCases, {$countFlat, XMLPattern["li"], #}} & /@ {UpTo[2], "2"},
  {XMLCases::innf, XMLCases::innf},
  TestID -> "count-invalid-n-upto-or-string"
];
