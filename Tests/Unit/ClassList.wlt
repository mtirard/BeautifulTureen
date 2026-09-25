(* The classList list key (ADR 0011, ADR 0012): the class reading's token list,
   reached by name beside the raw class attribute. Values are plain WL patterns
   matched against the list, with one desugaring. All fixtures here are local to
   this file.

   The fixture covers the three ways a class list can be empty (no attribute,
   class="", whitespace only). *)

$mixed = ImportString[
  "<div>\
<p class=\"lead\">lead</p>\
<p class=\"promo card\">promo</p>\
<p class=\"x\">single</p>\
<p class=\"\">empty</p>\
<p class=\"   \">spaces</p>\
<p>none</p>\
<p id=\"x\">idonly</p>\
</div>",
  {"HTML", "XMLObject"}];

texts[pat_] := HTMLTextContent /@ XMLCases[$mixed, pat];

(* === The one desugaring: a literal string at a list key means "contains" === *)

TestCreate[
  texts[XMLPattern["p", "classList" -> "card"]],
  {"promo"},
  TestID -> "classlist-literal-string-is-contains"
];

TestCreate[
  texts[XMLPattern["p", "classList" -> "lead" | "card"]],
  {"lead", "promo"},
  TestID -> "classlist-alternatives-of-strings-is-contains"
];

(* The desugaring stops at literal strings: Except["lead"] can match a list, so it
   keeps its plain meaning and matches every class list. *)
TestCreate[
  texts[XMLPattern["p", "classList" -> Except["lead"]]],
  {"lead", "promo", "single", "empty", "spaces", "none", "idonly"},
  TestID -> "classlist-except-is-plain-wl"
];

(* :not(.lead) is a list predicate, and absence reads as {}, so an element with no
   class attribute satisfies it, as CSS p:not(.lead) does. *)
TestCreate[
  texts[XMLPattern["p", "classList" -> _?(FreeQ["lead"])]],
  {"promo", "single", "empty", "spaces", "none", "idonly"},
  TestID -> "classlist-freeq-is-not"
];

(* The desugaring applies at the top of a value only, never inside a list pattern:
   {"card"} is the exact class list {"card"}. *)
TestCreate[
  texts[XMLPattern["p", "classList" -> {"card"}]],
  {},
  TestID -> "classlist-desugaring-top-level-only"
];

(* === Lists are positional === *)

TestCreate[
  texts[XMLPattern["p", "classList" -> {"promo", "card"}]],
  {"promo"},
  TestID -> "classlist-exact-positional-list"
];

TestCreate[
  texts[XMLPattern["p", "classList" -> {"card", "promo"}]],
  {},
  TestID -> "classlist-positional-list-order-counts"
];

(* Order-free questions use WL's list predicates. *)
TestCreate[
  texts[XMLPattern["p", "classList" -> _?(ContainsAll[{"card", "promo"}])]],
  {"promo"},
  TestID -> "classlist-order-free-via-containsall"
];

TestCreate[
  texts[XMLPattern["p", "classList" -> {_}]],
  {"lead", "single"},
  TestID -> "classlist-cardinality"
];

(* A token-level string question is a predicate on an element of the list. *)
TestCreate[
  texts[XMLPattern["p", "classList" -> {___, _?(StringStartsQ["car"]), ___}]],
  {"promo"},
  TestID -> "classlist-token-predicate-in-list"
];

(* === Absence, and the raw key === *)

(* A missing class, class="" and a whitespace-only class all read as {}. *)
TestCreate[
  texts[XMLPattern["p", "classList" -> {}]],
  {"empty", "spaces", "none", "idonly"},
  TestID -> "classlist-absent-and-empty-read-as-empty-list"
];

(* The raw key keeps its presence semantics and sees class="". *)
TestCreate[
  texts[XMLPattern["p", "class"]],
  {"lead", "promo", "single", "empty", "spaces"},
  TestID -> "classlist-raw-key-is-presence"
];

(* The raw key is the raw string, matched exactly. *)
TestCreate[
  {texts[XMLPattern["p", "class" -> "promo"]], texts[XMLPattern["p", "class" -> "promo card"]]},
  {{}, {"promo"}},
  TestID -> "classlist-raw-key-is-exact"
];

(* A negated raw rule keeps KeyValuePattern semantics: the key must be present. *)
TestCreate[
  texts[XMLPattern["p", "class" -> Except["lead"]]],
  {"promo", "single", "empty", "spaces"},
  TestID -> "classlist-raw-rule-negation-requires-key"
];

TestCreate[
  texts[XMLPattern["p", {"id" -> "x", "classList" -> _?(FreeQ["lead"])}]],
  {"idonly"},
  TestID -> "classlist-with-other-attribute"
];

(* The list key is resolved by name, so a real attribute spelled like one (only
   possible in a hand-built or XML tree) is not reached through it; it stays
   reachable through the whole attribute map. *)
$fake = XMLElement["div", {}, {XMLElement["p", {"classList" -> "lead"}, {"fake"}]}];
TestCreate[
  {XMLCases[$fake, XMLPattern["p", "classList" -> "lead"]],
   XMLCases[$fake, XMLPattern["p", attrs_?(MemberQ["classList" -> "lead"])] :> "real"]},
  {{}, {"real"}},
  TestID -> "classlist-real-attribute-not-reached-by-list-key"
];

(* The class list splits on HTMLWhitespace: the importer decodes &nbsp; to U+00A0,
   which a browser does not split on, so .btn does not apply. *)
TestCreate[
  XMLCases[
    ImportString["<div><p class=\"btn&nbsp;btn-primary\">nbsp</p></div>", {"HTML", "XMLObject"}],
    XMLPattern["p", "classList" -> "btn"]],
  {},
  TestID -> "classlist-nbsp-is-not-a-delimiter"
];

(* Hand-built, since the importer already normalises whitespace in values. *)
TestCreate[
  XMLCases[XMLElement["div", {}, {XMLElement["p", {"class" -> " \tcard\n\f\ractive  "}, {}]}],
    XMLPattern["p", "classList" -> c_] :> c],
  {{"card", "active"}},
  TestID -> "classlist-ascii-whitespace-runs"
];

(* === Bindings === *)

(* A bare blank binds the whole token list. *)
TestCreate[
  XMLCases[$mixed, XMLPattern["p", "classList" -> c : {_, __}] :> c],
  {{"promo", "card"}},
  TestID -> "classlist-binds-token-list"
];

(* An element binding sees the element as it is in the tree, while cls_ binds the
   token list from the same match. *)
TestCreate[
  XMLCases[$mixed, e : XMLPattern["p", "classList" -> cls_] /; Length[cls] == 2 :> {e, cls}],
  {{XMLElement["p", {"class" -> "promo card"}, {"promo"}], {"promo", "card"}}},
  TestID -> "classlist-element-binding-is-original"
];

(* The element a query returns is the original, too. *)
TestCreate[
  XMLCases[$mixed, XMLPattern["p", "classList" -> "lead"]],
  {XMLElement["p", {"class" -> "lead"}, {"lead"}]},
  TestID -> "classlist-result-is-original"
];

(* A top-level Condition's test sees the original element. *)
TestCreate[
  texts[e : XMLPattern["p", "classList" -> {}] /; e[[2]] === {}],
  {"none"},
  TestID -> "classlist-condition-test-sees-original"
];

(* A binding or test on the attribute argument sees the original attribute map. *)
TestCreate[
  {XMLCases[$mixed, XMLPattern["p", attrs : {"classList" -> "card"}] :> attrs],
   texts[XMLPattern["p", {"classList" -> {}}?(# === {} &)]]},
  {{{"class" -> "promo card"}}, {"none"}},
  TestID -> "classlist-attribute-argument-sees-original-map"
];

(* The same name in two alternatives is one binding. *)
TestCreate[
  XMLCases[$mixed,
    (e : XMLPattern["p", "classList" -> "lead"]) | (e : XMLPattern["p", "id" -> "x"]) :> e[[2]]],
  {{"class" -> "lead"}, {"id" -> "x"}},
  TestID -> "classlist-shared-name-across-alternatives"
];

(* XMLFirstCase agrees. *)
TestCreate[
  XMLFirstCase[$mixed, e : XMLPattern["p", "classList" -> "card"] :> e],
  XMLElement["p", {"class" -> "promo card"}, {"promo"}],
  TestID -> "classlist-firstcase-binding-is-original"
];

(* === CSSClass is obsolete === *)

TestCreate[
  CSSClass["lead"],
  $Failed,
  {CSSClass::obs},
  TestID -> "cssclass-is-obsolete"
];

(* Inside a pattern it says so once, and the consumer fails quietly after it. *)
TestCreate[
  XMLCases[$mixed, XMLPattern["p", CSSClass["lead"]]],
  $Failed,
  {CSSClass::obs},
  TestID -> "cssclass-is-obsolete-inside-xmlpattern"
];
