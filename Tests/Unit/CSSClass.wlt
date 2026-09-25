(* CSSClass semantics: each argument is a string pattern matched against one
   class token of the element's class list. All fixtures here are local to this
   file.

   The fixture covers the three ways a class list can be empty (no attribute,
   class="", whitespace only) and carries a one-character class, since a bare _
   is a string pattern matching exactly one character. *)

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

(* === Each argument is a string pattern, matched against one class token === *)

(* Sequence blanks mean what StringsAndCharacters says: __ is one or more
   characters, ___ is zero or more. Against a single token, both come to "any
   class at all", since a class token is never empty. *)
TestCreate[
  HTMLTextContent /@ XMLCases[$mixed, XMLPattern["p", CSSClass[__]]],
  {"lead", "promo", "single"},
  TestID -> "cssclass-blanksequence-any-class"
];

TestCreate[
  HTMLTextContent /@ XMLCases[$mixed, XMLPattern["p", CSSClass[___]]],
  {"lead", "promo", "single"},
  TestID -> "cssclass-blanknullsequence-any-class"
];

(* A bare _ is one character, so it asks for a one-character class \[LongDash] no Blank is
   reinterpreted as "any class". *)
TestCreate[
  HTMLTextContent /@ XMLCases[$mixed, XMLPattern["p", CSSClass[_]]],
  {"single"},
  TestID -> "cssclass-blank-is-one-character"
];

(* A composite string pattern is confined to one token: no class token is "promo"
   followed by more characters, even though the attribute value continues. *)
TestCreate[
  HTMLTextContent /@ XMLCases[$mixed, XMLPattern["p", CSSClass["promo" ~~ __]]],
  {},
  TestID -> "cssclass-pattern-confined-to-one-token"
];

TestCreate[
  HTMLTextContent /@ XMLCases[$mixed, XMLPattern["p", CSSClass["car" ~~ __]]],
  {"promo"},
  TestID -> "cssclass-prefix-pattern-on-a-token"
];

(* === Negation is absence-tolerant === *)

(* An element carrying no class attribute has no classes, so it satisfies
   "does not have class lead" \[LongDash] as CSS p:not(.lead) does. *)
TestCreate[
  HTMLTextContent /@ XMLCases[$mixed, XMLPattern["p", CSSClass[Except["lead"]]]],
  {"promo", "single", "empty", "spaces", "none", "idonly"},
  TestID -> "cssclass-negation-matches-classless"
];

(* Absent and present-but-empty carry the same (empty) class list, so a negation
   cannot tell them apart. *)
TestCreate[
  HTMLTextContent /@ XMLCases[$mixed, XMLPattern["p", CSSClass[Except["card"]]]],
  {"lead", "single", "empty", "spaces", "none", "idonly"},
  TestID -> "cssclass-negation-absent-equals-empty"
];

(* Negating a sequence blank expresses "carries no classes at all", whatever the
   class names would have been \[LongDash] only meaningful because negation is
   absence-tolerant. All three empty class lists answer alike. *)
TestCreate[
  HTMLTextContent /@ XMLCases[$mixed, XMLPattern["p", CSSClass[Except[___]]]],
  {"empty", "spaces", "none", "idonly"},
  TestID -> "cssclass-negated-sequence-means-no-classes"
];

(* === Negation combined with positive constraints (AND) === *)

(* The positive part still selects on the class list; only the negation is
   absence-tolerant, so a classless element fails the positive half. *)
TestCreate[
  HTMLTextContent /@ XMLCases[$mixed, XMLPattern["p", CSSClass["card", Except["lead"]]]],
  {"promo"},
  TestID -> "cssclass-and-positive-and-negation"
];

(* Two negations: neither class present, on any element including classless ones *)
TestCreate[
  HTMLTextContent /@ XMLCases[$mixed,
    XMLPattern["p", CSSClass[Except["lead"], Except["card"]]]],
  {"single", "empty", "spaces", "none", "idonly"},
  TestID -> "cssclass-and-two-negations"
];

(* A negation alongside another attribute constraint *)
TestCreate[
  HTMLTextContent /@ XMLCases[$mixed, XMLPattern["p", "id" -> "x", CSSClass[Except["lead"]]]],
  {"idonly"},
  TestID -> "cssclass-negation-with-other-attribute"
];

(* === Positive constraints remain presence-requiring === *)

(* A positive constraint is presence-requiring, so an empty class list fails it
   however it arose. *)
TestCreate[
  HTMLTextContent /@ XMLCases[$mixed, XMLPattern["p", CSSClass[___]]],
  {"lead", "promo", "single"},
  TestID -> "cssclass-positive-needs-a-class"
];

(* The bare-attribute shorthand is the presence test, and does see class="" *)
TestCreate[
  HTMLTextContent /@ XMLCases[$mixed, XMLPattern["p", "class"]],
  {"lead", "promo", "single", "empty", "spaces"},
  TestID -> "cssclass-attribute-shorthand-is-presence"
];

TestCreate[
  HTMLTextContent /@ XMLCases[$mixed, XMLPattern["p", CSSClass["lead"]]],
  {"lead"},
  TestID -> "cssclass-positive-single"
];

TestCreate[
  HTMLTextContent /@ XMLCases[$mixed, XMLPattern["p", CSSClass["lead" | "card"]]],
  {"lead", "promo"},
  TestID -> "cssclass-positive-alternatives"
];

(* A raw negated attribute rule keeps KeyValuePattern semantics: the key must be
   present for the value pattern to be consulted at all. Only CSSClass, which
   models the class list rather than the raw attribute, is absence-tolerant. *)
TestCreate[
  HTMLTextContent /@ XMLCases[$mixed, XMLPattern["p", "class" -> Except["lead"]]],
  {"promo", "single", "empty", "spaces"},
  TestID -> "cssclass-raw-rule-negation-requires-key"
];

(* === Negation composes with the rest of the pattern surface === *)

$nested = ImportString[
  "<div class=\"main\"><p class=\"ad\">ad</p><p>keep</p></div>",
  {"HTML", "XMLObject"}];

TestCreate[
  HTMLTextContent /@ XMLCases[$nested,
    Child[XMLPattern["div", CSSClass["main"]], XMLPattern["p", CSSClass[Except["ad"]]]]],
  {"keep"},
  TestID -> "cssclass-negation-under-combinator"
];

TestCreate[
  XMLDeleteCases[$nested, XMLPattern["p", CSSClass[Except["ad"]]]],
  ImportString["<div class=\"main\"><p class=\"ad\">ad</p></div>", {"HTML", "XMLObject"}],
  TestID -> "cssclass-negation-in-deletecases"
];

(* === The class list splits on HTMLWhitespace === *)

(* The importer decodes &nbsp; to U+00A0, which a browser does not split on, so
   the element carries the single class btn\:00a0btn-primary and .btn does not
   apply to it. CSSClass must agree with the browser. *)
TestCreate[
  XMLCases[
    ImportString["<div><p class=\"btn&nbsp;btn-primary\">nbsp</p></div>", {"HTML", "XMLObject"}],
    XMLPattern["p", CSSClass["btn"]]],
  {},
  TestID -> "cssclass-nbsp-is-not-a-delimiter"
];
