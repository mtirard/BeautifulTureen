(* XMLDeleteCases over tree patterns: what a rule deletes, and one test per
   kind of position a name can delete. The fixtures are literal trees, so
   positions are exact. *)

nav     = doc[e["nav", "o", e["a", "a1"], e["nav", "i", e["a", "a2"]], e["a", "a3"]]];
links   = doc[el["p", e["a", "1"], e["a", "2"], e["a", "3"]]];
hrefs   = doc[el["p", XMLElement["a", {"href" -> "/x"}, {}], XMLElement["a", {"href" -> "/x"}, {}]]];

(* === Examples === *)

TestCreate[
  XMLDeleteCases[nav, XMLPattern["nav"][Descendant[a : XMLPattern["a"]]] :> a],
  doc[e["nav", "o", e["nav", "i"]]],
  TestID -> "delete-rule-element"
];

(* Several names: the union of their positions over all results. *)
TestCreate[
  XMLDeleteCases[doc[el["h1", el["b"], el["i"], el["u"], el["s"]]], XMLPattern["h1"][{x_, _, y_, ___}] :> {x, y}],
  doc[el["h1", el["i"], el["s"]]],
  TestID -> "delete-rule-names"
];

TestCreate[
  XMLDeleteCases[hrefs, XMLPattern["a", "href" -> h_] :> h],
  doc[el["p", el["a"], el["a"]]],
  TestID -> "delete-rule-attribute"
];

TestCreate[
  XMLDeleteCases[doc[XMLElement["p", {"class" -> "lead x lead"}, {}]], XMLPattern["p", "classList" -> {___, c : "lead", ___}] :> c],
  doc[XMLElement["p", {"class" -> "x"}, {}]],
  TestID -> "delete-rule-tokens"
];

(* A bare pattern deletes its pattern roots. *)
TestCreate[
  XMLDeleteCases[links, XMLPattern["a"]],
  doc[el["p"]],
  TestID -> "delete-bare-pattern"
];

TestCreate[
  XMLDeleteCases[links, XMLPattern["a"] :> "x"],
  $Failed,
  {XMLDeleteCases::delrhs},
  TestID -> "delete-rhs-not-names"
];

TestCreate[
  XMLDeleteCases[links, XMLPattern[t_] :> t],
  $Failed,
  {XMLDeleteCases::target},
  TestID -> "delete-tag-refused"
];

(* === One test per kind === *)

(* An element is removed; the root of an XMLObject is kept, with a message,
   and the other targets are deleted. *)
TestCreate[
  XMLDeleteCases[nav, XMLPattern["nav" | "a"]],
  doc[e["nav", "o"]],
  {XMLDeleteCases::root},
  TestID -> "delete-kind-root-kept"
];

TestCreate[
  XMLDeleteCases[doc[XMLElement["p", {"id" -> "i", "class" -> "c"}, {"t"}]], XMLPattern["p", a_] :> a],
  doc[XMLElement["p", {}, {"t"}]],
  TestID -> "delete-kind-attribute-map"
];

(* A list key removes the whole attribute. *)
TestCreate[
  XMLDeleteCases[doc[XMLElement["p", {"id" -> "i", "class" -> "a b"}, {}]], XMLPattern["p", "classList" -> c_] :> c],
  doc[XMLElement["p", {"id" -> "i"}, {}]],
  TestID -> "delete-kind-list-key"
];

(* A token run is removed; the attribute is kept even when empty. *)
TestCreate[
  {XMLDeleteCases[doc[XMLElement["p", {"class" -> "a b c d"}, {}]], XMLPattern["p", "classList" -> {_, r__, _}] :> r],
    XMLDeleteCases[doc[XMLElement["p", {"class" -> "a"}, {}]], XMLPattern["p", "classList" -> {c_}] :> c]},
  {doc[XMLElement["p", {"class" -> "a d"}, {}]], doc[XMLElement["p", {"class" -> ""}, {}]]},
  TestID -> "delete-kind-token-run"
];

(* Tokens are written back through the reading: "," for the comma-separated
   microsyntax. *)
TestCreate[
  XMLDeleteCases[doc[XMLElement["img", {"srcset" -> "a.png 1x, b.png 2x, c.png 3x"}, {}]],
    XMLPattern["img", "srcsetList" -> {_, s_, ___}] :> s,
    "AttributeReadings" -> <|"srcset" -> <|Method -> "CommaSeparated"|>|>],
  doc[XMLElement["img", {"srcset" -> "a.png 1x,c.png 3x"}, {}]],
  TestID -> "delete-kind-comma-tokens"
];

(* A run of element children is removed; the text between them is not an
   element child, and stays. *)
TestCreate[
  XMLDeleteCases[doc[el["div", e["p", "1"], "x", e["p", "2"], "y", e["p", "3"]]], XMLPattern["div"][{_, r__}] :> r],
  doc[el["div", e["p", "1"], "x", "y"]],
  TestID -> "delete-kind-run"
];

(* A gap, of children or of tokens, deletes nothing. *)
TestCreate[
  {XMLDeleteCases[links, XMLPattern["p"][{___, XMLPattern["a"], g : PatternSequence[], ___}] :> g],
    XMLDeleteCases[doc[XMLElement["p", {"class" -> "a b"}, {}]], XMLPattern["p", "classList" -> {___, g : PatternSequence[], ___}] :> g]},
  {links, doc[XMLElement["p", {"class" -> "a b"}, {}]]},
  TestID -> "delete-kind-gaps"
];

(* All, a name on an XMLElement pattern's contents, empties the contents. *)
TestCreate[
  XMLDeleteCases[doc[el["div", el["p", "x", el["b"]], "y"]], XMLElement["p", _, c_] :> c],
  doc[el["div", el["p"], "y"]],
  TestID -> "delete-kind-contents"
];

TestCreate[
  XMLDeleteCases[links, d : XMLDocument[{XMLPattern["p"]}] :> d],
  $Failed,
  {XMLDeleteCases::target},
  TestID -> "delete-kind-document-refused"
];

TestCreate[
  XMLDeleteCases[nav, XMLPattern["nav"][p : Descendant[XMLPattern["a"]]] :> p],
  $Failed,
  {XMLDeleteCases::pathtarget},
  TestID -> "delete-kind-path-refused"
];

(* === Around the kinds === *)

(* No match deletes nothing, though no positions would also read as the
   document. *)
TestCreate[
  XMLDeleteCases[links, XMLPattern["table"]],
  links,
  TestID -> "delete-no-match-nothing"
];

(* A target inside another deleted target goes with it, whichever order the
   results give them in. *)
TestCreate[
  {XMLDeleteCases[nav, n : XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> {n, x}],
    XMLDeleteCases[doc[el["div", e["p", "1"], e["p", "2"], e["p", "3"]]], XMLPattern["div"][{___, r__, ___}] :> r],
    XMLDeleteCases[doc[el["div", XMLElement["p", {"class" -> "a"}, {}]]], XMLPattern["div"][{p : XMLPattern["p", "classList" -> {c_}]}] :> {c, p}]},
  {doc[e["nav", "o"]], doc[el["div"]], doc[el["div"]]},
  {XMLDeleteCases::root},
  TestID -> "delete-nested-targets"
];

(* A Condition on the right-hand side filters the results. *)
TestCreate[
  XMLDeleteCases[links, x : XMLPattern["a"] :> x /; Lookup[x[[2]], "id"] =!= "2"],
  doc[el["p", e["a", "2"]]],
  TestID -> "delete-rhs-condition"
];

(* A list input's top elements can be deleted; a bare element input's own
   position is never counted. *)
TestCreate[
  {XMLDeleteCases[{e["a", "1"], " ", el["b", e["a", "2"]]}, XMLPattern["a"]],
    XMLDeleteCases[el["b", e["a", "2"], "t"], x : XMLPattern[_] :> x]},
  {{" ", el["b"]}, el["b", "t"]},
  TestID -> "delete-list-and-bare-inputs"
];

(* A right-hand side that is not names, or names one the pattern does not
   bind, is refused. *)
TestCreate[
  {XMLDeleteCases[links, x : XMLPattern["a"] -> 1], XMLDeleteCases[links, x : XMLPattern["a"] :> {x, y}]},
  {$Failed, $Failed},
  {XMLDeleteCases::delrhs, XMLDeleteCases::delrhs},
  TestID -> "delete-rhs-refusals"
];

TestCreate[
  XMLDeleteCases[links, x : XMLPattern["a"] -> x],
  doc[el["p"]],
  TestID -> "delete-rule-arrow"
];
