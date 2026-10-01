(* HTMLWhitespace and HTMLClassList (ADR 0009, as amended by ADR 0012).

   HTMLWhitespace is the delimiter of the space-separated microsyntax: a run of
   one or more of HTML's five ASCII whitespace characters, narrower than
   StringSplit's Unicode default. HTMLClassList is the extraction form of the
   class reading: the element's class list, split on that delimiter. *)

(* === HTMLWhitespace is the delimiter === *)

(* A run, like Whitespace: a double space yields no phantom empty token. *)
TestCreate[
  StringSplit["a  b", HTMLWhitespace],
  {"a", "b"},
  TestID -> "htmlwhitespace-is-a-run"
];

TestCreate[
  StringSplit["a b\tc\nd\fe\rf", HTMLWhitespace],
  {"a", "b", "c", "d", "e", "f"},
  TestID -> "htmlwhitespace-five-ascii-characters"
];

(* Narrower than StringSplit's Unicode default: no-break space and the other
   Unicode whitespace characters are part of a token, as in a browser. *)
TestCreate[
  Length[StringSplit["a" <> FromCharacterCode[#] <> "b", HTMLWhitespace]] & /@
    {16^^A0, 16^^2028, 16^^2029, 16^^0B, 16^^85, 16^^2003, 16^^3000},
  {1, 1, 1, 1, 1, 1, 1},
  TestID -> "htmlwhitespace-excludes-unicode-whitespace"
];

(* === HTMLClassList is the class list of one element === *)

$doc = ImportString[
  "<div>\
<p class=\"lead lead promo\">dup</p>\
<p class=\"btn&nbsp;btn-primary\">nbsp</p>\
<p class=\"\">empty</p>\
<p class=\"   \">spaces</p>\
<p>none</p>\
</div>",
  {"HTML", "XMLObject"}];

$p[text_] := XMLFirstCase[$doc, e : XMLPattern["p"] /; HTMLTextContent[e] === text];

(* The document keeps duplicate tokens, so the class list does too. *)
TestCreate[
  HTMLClassList[$p["dup"]],
  {"lead", "lead", "promo"},
  TestID -> "htmlclasslist-keeps-duplicates"
];

(* Leading, trailing and interior runs of ASCII whitespace are delimiters only.
   Hand-built, because the importer already normalises whitespace in attribute
   values. *)
TestCreate[
  HTMLClassList[XMLElement["p", {"class" -> " \tcard\n\f\ractive  "}, {}]],
  {"card", "active"},
  TestID -> "htmlclasslist-ascii-whitespace-runs"
];

(* The importer decodes &nbsp; to U+00A0, which a browser does not split on:
   the element carries one class, not btn and btn-primary. *)
TestCreate[
  HTMLClassList[$p["nbsp"]],
  {"btn\:00a0btn-primary"},
  TestID -> "htmlclasslist-nbsp-is-not-a-delimiter"
];

(* A missing class, class="" and a whitespace-only class all give the empty
   class list, as a browser's classList does (ADR 0012). *)
TestCreate[
  HTMLClassList /@ {$p["empty"], $p["spaces"], $p["none"]},
  {{}, {}, {}},
  TestID -> "htmlclasslist-empty-class-lists"
];

(* A namespaced {ns, "class"} key is foreign vocabulary, not the class attribute. *)
TestCreate[
  HTMLClassList[XMLElement["svg", {{"http://example.com/ns", "class"} -> "a b"}, {}]],
  {},
  TestID -> "htmlclasslist-ignores-namespaced-class"
];

(* === HTMLClassList takes one element, and only an element === *)

(* A list is a forest elsewhere in the paclet, given one answer; concatenating
   class lists would be meaningless, so a list is refused rather than mapped. *)
TestCreate[
  HTMLClassList[{$p["dup"], $p["nbsp"]}],
  $Failed,
  {HTMLClassList::notelement},
  TestID -> "htmlclasslist-refuses-list"
];

TestCreate[
  HTMLClassList[$doc],
  $Failed,
  {HTMLClassList::notelement},
  TestID -> "htmlclasslist-refuses-document"
];

(* A bare string means a text node in this paclet, not an attribute value. *)
TestCreate[
  HTMLClassList["lead promo"],
  $Failed,
  {HTMLClassList::notelement},
  TestID -> "htmlclasslist-refuses-string"
];
