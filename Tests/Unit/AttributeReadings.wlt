(* Readings (ADR 0012): the AttributeReadings option on the consumers, the
   fields of a reading, and what a reading never changes. *)

$links = XMLElement["div", {}, {
  XMLElement["a", {"rel" -> "nofollow noopener", "href" -> "/x"}, {"x"}],
  XMLElement["a", {"rel" -> "author"}, {"y"}],
  XMLElement["a", {"href" -> "/z"}, {"z"}]}];

(* === The option adds a reading === *)

(* A registered key gets a list key, key <> "List", read as {} where the raw
   attribute is absent. *)
TestCreate[
  XMLCases[$links, XMLPattern["a", "relList" -> r_] :> r,
    "AttributeReadings" -> <|"rel" -> <||>|>],
  {{"nofollow", "noopener"}, {"author"}, {}},
  TestID -> "readings-option-registers-rel"
];

(* XMLFirstCase takes the option after its optional default. *)
TestCreate[
  {XMLFirstCase[$links, XMLPattern["a", "relList" -> "author"] :> "hit",
     "AttributeReadings" -> <|"rel" -> <||>|>],
   XMLFirstCase[$links, XMLPattern["a", "relList" -> "me"], "none",
     "AttributeReadings" -> <|"rel" -> <||>|>]},
  {"hit", "none"},
  TestID -> "readings-option-firstcase-with-and-without-default"
];

TestCreate[
  XMLDeleteCases[$links, XMLPattern["a", "relList" -> "nofollow"],
    "AttributeReadings" -> <|"rel" -> <||>|>],
  XMLElement["div", {}, {
    XMLElement["a", {"rel" -> "author"}, {"y"}],
    XMLElement["a", {"href" -> "/z"}, {"z"}]}],
  TestID -> "readings-option-deletecases"
];

(* The operator form carries the option too: an option rule is never a pattern. *)
TestCreate[
  {XMLMatchQ[$links[[3, 2]], XMLPattern["a", "relList" -> "author"],
     "AttributeReadings" -> <|"rel" -> <||>|>],
   XMLMatchQ[XMLPattern["a", "relList" -> {}], "AttributeReadings" -> <|"rel" -> <||>|>] /@
     $links[[3]]},
  {True, {False, False, True}},
  TestID -> "readings-option-matchq-and-operator-form"
];

(* The text emitters compile their rules with the option's readings. *)
TestCreate[
  HTMLInnerText[$links, "Roles" -> {XMLPattern["a", "relList" -> "nofollow"] -> "Skip"},
    "AttributeReadings" -> <|"rel" -> <||>|>],
  "yz",
  TestID -> "readings-option-innertext-roles"
];

TestCreate[
  HTMLToNotebook[XMLElement["p", {}, {XMLElement["a", {"rel" -> "tag"}, {"t"}], XMLElement["a", {}, {"u"}]}],
    "Roles" -> {XMLPattern["a", "relList" -> {}] -> "Skip"},
    "Constructs" -> {XMLPattern["a", "relList" -> "tag"] -> "Bold"},
    "AttributeReadings" -> <|"rel" -> <||>|>],
  Notebook[{Cell[TextData[{StyleBox["t", FontWeight -> Bold]}], "Text"]}],
  TestID -> "readings-option-tonotebook-roles-and-constructs"
];

(* === The option holds for the whole call (#34) === *)

(* The option is Block[{$AttributeReadings = Join[$AttributeReadings, option]}, call],
   so a nested XML* call in a condition sees it, as it would the global. *)
$rel = XMLElement["div", {}, {XMLElement["a", {"rel" -> "x"}, {"1"}], XMLElement["a", {}, {"2"}]}];

TestCreate[
  XMLCases[$rel, e : XMLPattern["a"] /; !XMLMatchQ[e, XMLPattern["a", "relList" -> "x"]],
    "AttributeReadings" -> <|"rel" -> <||>|>],
  {XMLElement["a", {}, {"2"}]},
  TestID -> "readings-option-reaches-nested-matchq"
];

(* The usual way to write "has a descendant matching ...". *)
TestCreate[
  XMLCases[XMLElement["body", {}, {XMLElement["p", {}, {$rel}], XMLElement["p", {}, {"3"}]}],
    e : XMLPattern["p"] /; !MissingQ[XMLFirstCase[e, XMLPattern["a", "relList" -> "x"]]] :> "has",
    "AttributeReadings" -> <|"rel" -> <||>|>],
  {"has"},
  TestID -> "readings-option-reaches-nested-firstcase"
];

(* A function called from a rule body sees it too, and the global is unchanged after. *)
relsOf[e_] := XMLCases[e, XMLPattern["a", "relList" -> r_] :> r];
TestCreate[
  {XMLCases[XMLElement["body", {}, {$rel}], d : XMLPattern["div"] :> relsOf[d],
     "AttributeReadings" -> <|"rel" -> <||>|>],
   Keys[$AttributeReadings]},
  {{{{"x"}, {}}}, {"class"}},
  TestID -> "readings-option-reaches-function-called-from-body"
];

TestCreate[
  {XMLDeleteCases[$rel, e : XMLPattern["a"] /; XMLMatchQ[e, XMLPattern["a", "relList" -> "x"]],
     "AttributeReadings" -> <|"rel" -> <||>|>],
   XMLFirstCase[$rel, e : XMLPattern["a"] /; XMLMatchQ[e, XMLPattern["a", "relList" -> {}]] :> e,
     "AttributeReadings" -> <|"rel" -> <||>|>]},
  {XMLElement["div", {}, {XMLElement["a", {}, {"2"}]}], XMLElement["a", {}, {"2"}]},
  TestID -> "readings-option-reaches-nested-call-deletecases-firstcase"
];

(* In XMLMatchQ, both forms; in the operator form, for each call of the operator. *)
TestCreate[
  With[{q = e : XMLPattern["a"] /; XMLMatchQ[e, XMLPattern["a", "relList" -> "x"]]},
    {XMLMatchQ[$rel[[3, 1]], q, "AttributeReadings" -> <|"rel" -> <||>|>],
     XMLMatchQ[q, "AttributeReadings" -> <|"rel" -> <||>|>] /@ $rel[[3]],
     XMLMatchQ[q] /@ $rel[[3]]}],
  {True, {True, False}, {False, False}},
  TestID -> "readings-option-reaches-nested-call-matchq"
];

(* A Constructs function is called inside the call. *)
TestCreate[
  HTMLToNotebook[XMLElement["p", {}, {XMLElement["a", {"rel" -> "tag"}, {"t"}]}],
    "Constructs" -> {XMLPattern["a"] -> Function[e, If[XMLMatchQ[e, XMLPattern["a", "relList" -> "tag"]], "TAG", "none"]]},
    "AttributeReadings" -> <|"rel" -> <||>|>],
  Notebook[{Cell[TextData[{"TAG"}], "Text"]}],
  TestID -> "readings-option-reaches-constructs-function"
];

(* === Merging with the global === *)

$cls = XMLElement["div", {}, {XMLElement["p", {"class" -> "a b"}, {"1"}], XMLElement["p", {}, {"2"}]}];

(* An option entry for a key the global has replaces that key's entry whole:
   here an explicit list key, so "classList" is no longer one. *)
TestCreate[
  XMLCases[$cls, XMLPattern["p", "classes" -> c_] :> c,
    "AttributeReadings" -> <|"class" -> <|"ListKey" -> "classes"|>|>],
  {{"a", "b"}, {}},
  TestID -> "readings-option-entry-replaces-global-entry"
];

TestCreate[
  XMLCases[$cls, XMLPattern["p", "classList" -> _],
    "AttributeReadings" -> <|"class" -> <|"ListKey" -> "classes"|>|>],
  {},
  TestID -> "readings-option-replaced-entry-drops-its-list-key"
];

(* The option adds: the built-in class reading survives a caller's rel entry. *)
TestCreate[
  XMLCases[$cls, XMLPattern["p", "classList" -> "a"] :> "hit",
    "AttributeReadings" -> <|"rel" -> <||>|>],
  {"hit"},
  TestID -> "readings-option-keeps-builtin"
];

(* Block replaces the global, and drops the built-in with it. *)
TestCreate[
  Block[{$AttributeReadings = <|"rel" -> <||>|>},
    {XMLCases[$links, XMLPattern["a", "relList" -> "author"] :> "rel"],
     XMLCases[$cls, XMLPattern["p", "classList" -> _]]}],
  {{"rel"}, {}},
  TestID -> "readings-block-replaces-global"
];

(* === The fields of a reading === *)

$accept = <|"accept" -> <|Method -> "CommaSeparated"|>|>;
acceptList[v_String] :=
  XMLCases[XMLElement["form", {}, {XMLElement["input", {"accept" -> v}, {}]}],
    XMLPattern["input", "acceptList" -> t_] :> t, "AttributeReadings" -> $accept];

(* The comma microsyntax trims each token, the outer edges included (ADR 0009). *)
TestCreate[
  {acceptList[" image/png, image/jpeg "], acceptList["a ,b,,d d"], acceptList["a, ,b"]},
  {{{"image/png", "image/jpeg"}}, {{"a", "b", "", "d d"}}, {{"a", "", "b"}}},
  TestID -> "readings-comma-separated-trims-tokens"
];

(* It trims HTML whitespace only: a no-break space is part of the token. *)
TestCreate[
  acceptList["\:00a0a , b\t"],
  {{"\:00a0a", "b"}},
  TestID -> "readings-comma-trim-is-html-whitespace"
];

(* Explicit Delimiters and "TrimWhitespace" override the Method's. *)
tagsList[v_String, spec_] :=
  XMLCases[XMLElement["body", {}, {XMLElement["div", {"data-tags" -> v}, {}]}], XMLPattern["div", "data-tagsList" -> t_] :> t,
    "AttributeReadings" -> <|"data-tags" -> spec|>];

TestCreate[
  {tagsList["a; b", <|Delimiters -> ";"|>],
   tagsList["a; b", <|Delimiters -> ";", "TrimWhitespace" -> True|>],
   tagsList["a , b", <|Method -> "CommaSeparated", "TrimWhitespace" -> False|>],
   tagsList["a|b c", <|Method -> "CommaSeparated", Delimiters -> "|" | " "|>]},
  {{{"a", " b"}}, {{"a", "b"}}, {{"a ", " b"}}, {{"a", "b", "c"}}},
  TestID -> "readings-explicit-fields-override-method"
];

(* === What a reading never changes === *)

(* Registering rel leaves "rel" the raw string, matched exactly and as presence. *)
TestCreate[
  With[{q = XMLPattern["a", "rel" -> "nofollow noopener"] | XMLPattern["a", "rel" -> "author"]},
    {XMLCases[$links, q], XMLCases[$links, q, "AttributeReadings" -> <|"rel" -> <||>|>],
     Length @ XMLCases[$links, XMLPattern["a", "rel"], "AttributeReadings" -> <|"rel" -> <||>|>]}],
  {Take[$links[[3]], 2], Take[$links[[3]], 2], 2},
  TestID -> "readings-never-change-raw-key"
];

(* A namespaced key never carries a reading, even when its local name has one. *)
$ns = XMLElement["svg", {}, {XMLElement["use", {{"http://www.w3.org/1999/xlink", "class"} -> "a b"}, {}]}];
TestCreate[
  {XMLCases[$ns, XMLPattern["use", {{"http://www.w3.org/1999/xlink", "class"} -> "a b"}] :> "raw"],
   XMLCases[$ns, XMLPattern["use", "classList" -> "a"]]},
  {{"raw"}, {}},
  TestID -> "readings-namespaced-key-has-none"
];

(* === Refusals === *)

(* A reading key is a literal string: the list key must be computable from it. *)
TestCreate[
  XMLCases[$links, XMLPattern["a"], "AttributeReadings" -> <|("data-" ~~ __) -> <||>|>],
  $Failed,
  {$AttributeReadings::badkey},
  TestID -> "readings-key-must-be-string"
];

(* The table and each entry are Associations; an entry's fields are the four named. *)
TestCreate[
  {XMLCases[$links, XMLPattern["a"], "AttributeReadings" -> {"rel" -> <||>}],
   XMLCases[$links, XMLPattern["a"], "AttributeReadings" -> <|"rel" -> "SpaceSeparated"|>],
   XMLCases[$links, XMLPattern["a"], "AttributeReadings" -> <|"rel" -> <|"Delimiter" -> ","|>|>]},
  {$Failed, $Failed, $Failed},
  {$AttributeReadings::notassoc, $AttributeReadings::badentry, $AttributeReadings::badfield},
  TestID -> "readings-table-and-entry-shapes"
];

(* Each field's value is checked: Method is one of two, Delimiters a string
   pattern, "TrimWhitespace" a Boolean, "ListKey" a string (or Automatic). *)
TestCreate[
  XMLCases[$links, XMLPattern["a"], "AttributeReadings" -> <|"rel" -> <|Method -> "Semicolon"|>|>],
  $Failed,
  {$AttributeReadings::badmethod},
  TestID -> "readings-unknown-method"
];

TestCreate[
  XMLCases[$links, XMLPattern["a"], "AttributeReadings" -> #] & /@ {
    <|"rel" -> <|Delimiters -> 5|>|>,
    <|"rel" -> <|"TrimWhitespace" -> "yes"|>|>,
    <|"rel" -> <|"ListKey" -> {"rels"}|>|>},
  {$Failed, $Failed, $Failed},
  {$AttributeReadings::badvalue, $AttributeReadings::badvalue, $AttributeReadings::badvalue,
   General::stop},
  TestID -> "readings-bad-field-values"
];

(* A list key names one token list, and is never a key that has a reading
   itself: either would make a query's key mean two things. *)
TestCreate[
  {XMLCases[$links, XMLPattern["a"], "AttributeReadings" -> <|"rel" -> <|"ListKey" -> "classList"|>|>],
   XMLCases[$links, XMLPattern["a"], "AttributeReadings" -> <|"rel" -> <|"ListKey" -> "class"|>|>]},
  {$Failed, $Failed},
  {$AttributeReadings::duplistkey, $AttributeReadings::listkeyisreading},
  TestID -> "readings-list-key-collisions"
];

(* A Block of $AttributeReadings, the option's or a caller's, keeps the
   messages' texts. *)
SetAttributes[messageText, HoldAll];
messageText[expr_] :=
  With[{s = OpenWrite[]},
    Block[{$Messages = {s}}, expr];
    With[{f = Close[s]}, (DeleteFile[f]; #) & @ ReadString[f]]];

TestCreate[
  StringContainsQ[#, "The reading for rel should be an Association"] & /@ {
    messageText[XMLCases[$links, XMLPattern["a"], "AttributeReadings" -> <|"rel" -> 5|>]],
    messageText[Block[{$AttributeReadings = <|"rel" -> 5|>}, XMLCases[$links, XMLPattern["a"]]]]},
  {True, True},
  {$AttributeReadings::badentry, $AttributeReadings::badentry},
  TestID -> "readings-messages-keep-their-text-under-block"
];

(* The emitters refuse a bad table once, whatever rules they are given. *)
TestCreate[
  {HTMLInnerText[$links, "AttributeReadings" -> <|"rel" -> 1|>],
   HTMLToNotebook[$links, "AttributeReadings" -> <|"rel" -> 1|>]},
  {$Failed, $Failed},
  {$AttributeReadings::badentry, $AttributeReadings::badentry},
  TestID -> "readings-emitters-refuse-bad-table"
];
