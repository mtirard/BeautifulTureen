(* The XMLPattern surface (ADR 0011): an inert XML pattern with a tag and at most one
   attribute argument, which only the XML* functions interpret. All fixtures here
   are local to this file. *)

$links = ImportString[
  "<div>\
<a href=\"/a\" rel=\"next\">a</a>\
<a href=\"/b\">b</a>\
<a name=\"top\">c</a>\
<input type=\"text\" required>\
<input type=\"text\">\
</div>",
  {"HTML", "XMLObject"}];

(* === Inertness === *)

(* An XML pattern is not a WL pattern: MatchQ treats it as a literal expression,
   as it treats a string pattern. *)
TestCreate[
  MatchQ[XMLElement["p", {}, {}], XMLPattern["p"]],
  False,
  TestID -> "xmlpattern-inert-under-matchq"
];

TestCreate[
  XMLPattern["p", "href" -> _],
  XMLPattern["p", "href" -> _],
  TestID -> "xmlpattern-evaluates-to-itself"
];

(* === The attribute argument is what KeyValuePattern takes === *)

TestCreate[
  XMLCases[$links, XMLPattern["a", {"href" -> h_, "rel" -> "next"}] :> h],
  {"/a"},
  TestID -> "xmlpattern-attrs-rule-list"
];

TestCreate[
  XMLCases[$links, XMLPattern["a", "href" -> h_] :> h],
  {"/a", "/b"},
  TestID -> "xmlpattern-attrs-single-rule"
];

(* A bare key means key -> _: the attribute is present, whatever its value. *)
TestCreate[
  HTMLTextContent /@ XMLCases[$links, XMLPattern["a", "name"]],
  {"c"},
  TestID -> "xmlpattern-attrs-bare-key"
];

TestCreate[
  Length @ XMLCases[$links, XMLPattern["input", {"type" -> "text", "required"}]],
  1,
  TestID -> "xmlpattern-attrs-list-with-bare-key"
];

(* Alternatives of literal keys *)
TestCreate[
  XMLCases[$links, XMLPattern["a", ("href" | "name") -> v_] :> v],
  {"/a", "/b", "top"},
  TestID -> "xmlpattern-attrs-alternative-keys"
];

(* A question about the whole attribute map is asked by naming and testing it.
   (The importer gives every <a> a shape attribute.) *)
TestCreate[
  XMLCases[$links, XMLPattern["a", attrs_?(Length[#] > 2 &)] :> attrs],
  {{"shape" -> "rect", "href" -> "/a", "rel" -> "next"}},
  TestID -> "xmlpattern-attrs-named-and-tested"
];

(* === Refusals: each an exactly-decidable silent wrong answer === *)

(* Refusals fire when a consumer compiles the pattern, so the XMLPattern itself
   stays inert and composes. *)

(* Varargs are gone: several constraints are one list. *)
TestCreate[
  XMLCases[$links, XMLPattern["a", "href" -> _, "rel" -> _]],
  $Failed,
  {XMLPattern::nargs},
  TestID -> "xmlpattern-refuses-third-argument"
];

TestCreate[
  XMLCases[$links, XMLPattern[37]],
  $Failed,
  {XMLPattern::badtag},
  TestID -> "xmlpattern-refuses-bad-tag"
];

TestCreate[
  XMLCases[$links, XMLPattern["a", 37]],
  $Failed,
  {XMLPattern::badattrs},
  TestID -> "xmlpattern-refuses-bad-attribute-argument"
];

(* A key is literal; a question about keys is asked of the whole map. *)
TestCreate[
  XMLCases[$links, XMLPattern["a", _String -> "/a"]],
  $Failed,
  {XMLPattern::badkey},
  TestID -> "xmlpattern-refuses-blank-key"
];

TestCreate[
  XMLCases[$links, XMLPattern["a", ("data-" ~~ __) -> _]],
  $Failed,
  {XMLPattern::badkey},
  TestID -> "xmlpattern-refuses-string-pattern-key"
];

(* KeyValuePattern demands distinct elements, so the same key twice is a silent
   False however each rule would hold alone. *)
TestCreate[
  XMLCases[$links, XMLPattern["a", {"href" -> _String, "href" -> "/a"}]],
  $Failed,
  {XMLPattern::dupkey},
  TestID -> "xmlpattern-refuses-duplicate-key"
];

(* An Alternatives key that shares a key with another constraint can match: each
   constraint takes a different attribute, as with KeyValuePattern. *)
TestCreate[
  XMLMatchQ[XMLElement["p", {"a" -> "2", "b" -> "1"}, {}], XMLPattern["p", {("a" | "b") -> "1", "a" -> "2"}]],
  True,
  TestID -> "xmlpattern-accepts-overlapping-alternative-keys"
];

TestCreate[
  XMLCases[$links, XMLPattern["a", {("href" | "name") -> _, "href"}]],
  {},
  TestID -> "xmlpattern-overlapping-alternative-keys-need-two-attributes"
];

(* Overlapping keys match whatever the order of the constraints: the
   Alternatives key takes whichever attribute the other constraint leaves. *)
$xy = XMLElement["p", {"x" -> "1", "y" -> "2"}, {}];

TestCreate[
  {XMLMatchQ[$xy, XMLPattern["p", {("x" | "y") -> v_, "x" -> w_}]],
    XMLMatchQ[$xy, XMLPattern["p", {"x" -> w_, ("x" | "y") -> v_}]]},
  {True, True},
  TestID -> "xmlpattern-overlapping-keys-any-order"
];

TestCreate[
  {XMLCases[{$xy}, XMLPattern["p", {("x" | "y") -> v_, "x" -> w_}] :> {v, w}],
    XMLCases[{$xy}, XMLPattern["p", {"x" -> w_, ("x" | "y") -> v_}] :> {v, w}]},
  {{{"2", "1"}}, {{"2", "1"}}},
  TestID -> "xmlpattern-overlapping-keys-rule-body"
];

TestCreate[
  {XMLMatchQ[$xy, XMLPattern["p", {("x" | "y") -> v_, "x" -> w_}] /; v === "2"],
    XMLCases[{$xy}, XMLPattern["p", {("x" | "y") -> v_, "x" -> w_}] :> v /; w === "1"]},
  {True, {"2"}},
  TestID -> "xmlpattern-overlapping-keys-condition"
];

TestCreate[
  {XMLFirstCase[{$xy}, XMLPattern["p", {("x" | "y") -> v_, "x" -> w_}] :> {v, w}],
    XMLDeleteCases[{$xy}, XMLPattern["p", {("x" | "y") -> _, "x" -> _}]]},
  {{"2", "1"}, {}},
  TestID -> "xmlpattern-overlapping-keys-first-and-delete"
];

TestCreate[
  XMLCases[XMLElement["div", {}, {$xy}],
    Child[XMLPattern["div"], XMLPattern["p", {("x" | "y") -> v_, "x" -> w_}]] :> {v, w}],
  {{"2", "1"}},
  TestID -> "xmlpattern-overlapping-keys-combinator-stage"
];

TestCreate[
  HTMLInnerText[XMLElement["div", {}, {XMLElement["span", {"x" -> "1", "y" -> "2"}, {"gone"}], "kept"}],
    "Roles" -> {XMLPattern["span", {("x" | "y") -> _, "x" -> "1"}] -> "Skip"}],
  "kept",
  TestID -> "xmlpattern-overlapping-keys-roles"
];

(* Two Alternatives keys on one shared key, and a list key among them. *)
TestCreate[
  {XMLCases[{$xy}, XMLPattern["p", {("x" | "y") -> w_, ("x" | "y") -> "1"}] :> w],
    XMLCases[{XMLElement["p", {"title" -> "t", "class" -> "a b"}, {}]},
      XMLPattern["p", {("classList" | "title") -> v_, "title" -> w_}] :> {v, w}]},
  {{"2"}, {{{"a", "b"}, "t"}}},
  TestID -> "xmlpattern-overlapping-keys-two-alternatives-and-list-key"
];

(* Each constraint still takes a different attribute. *)
TestCreate[
  XMLMatchQ[XMLElement["p", {"x" -> "1"}, {}], XMLPattern["p", {("x" | "y") -> _, "x" -> _}]],
  False,
  TestID -> "xmlpattern-overlapping-keys-one-attribute-for-two-constraints"
];

(* A bare string pattern is never matched against a string by MatchQ, so it
   would fail forever: refused in the tag, a value, and a list element. *)
TestCreate[
  XMLCases[$links, XMLPattern["h" ~~ DigitCharacter]],
  $Failed,
  {XMLPattern::strpat},
  TestID -> "xmlpattern-strpat-in-tag"
];

TestCreate[
  XMLCases[$links, XMLPattern["a", "href" -> "/" ~~ __]],
  $Failed,
  {XMLPattern::strpat},
  TestID -> "xmlpattern-strpat-in-value"
];

TestCreate[
  XMLCases[$links, XMLPattern["a", "classList" -> {"col-" ~~ __, ___}]],
  $Failed,
  {XMLPattern::strpat},
  TestID -> "xmlpattern-strpat-in-list-element"
];

(* A string pattern handed to a string function is not a bare one. *)
TestCreate[
  XMLCases[$links, XMLPattern["a", "href" -> _?(StringMatchQ["/" ~~ __])] :> "hit"],
  {"hit", "hit"},
  TestID -> "xmlpattern-string-pattern-inside-test-accepted"
];

(* An inert pattern composes before any consumer sees it. *)
TestCreate[
  Length @ XMLCases[$links, XMLPattern["a", "rel"] | XMLPattern["input", "required"]],
  2,
  TestID -> "xmlpattern-composes-with-alternatives"
];
