(* XMLReplace over tree patterns: the root and targets forms, and one test
   per kind of position a name can replace. The fixtures are literal trees,
   so positions are exact. *)

doc[root_] := XMLObject["Document"][{}, root, {}];
e[tag_, id_String, c___] := XMLElement[tag, {"id" -> id}, {c}];
el[tag_, c___] := XMLElement[tag, {}, {c}];

links   = doc[el["p", e["a", "1"], e["a", "2"], e["a", "3"]]];
hrefs   = doc[el["p", XMLElement["a", {"href" -> "/x"}, {}], XMLElement["a", {"href" -> "/x"}, {}]]];

(* === Examples === *)

(* Root form: the pattern root is the target. *)
TestCreate[
  XMLReplace[links, XMLPattern["a"] :> "z"],
  doc[el["p", "z", "z", "z"]],
  TestID -> "replace-root-form-string"
];

TestCreate[
  XMLReplace[links, x : XMLPattern["a"] :> XMLElement["b", {}, x[[3]]]],
  doc[el["p", el["b"], el["b"], el["b"]]],
  TestID -> "replace-root-form-element"
];

TestCreate[
  XMLReplace[links, XMLPattern["a"]],
  $Failed,
  {XMLReplace::bare},
  TestID -> "replace-bare-refused"
];

(* Targets form: a replacement uses a value from elsewhere in the pattern. *)
TestCreate[
  XMLReplace[doc[XMLElement["div", {"class" -> "c"}, {el["p", "x"]}]],
    XMLPattern["div", "class" -> c_, {___, p : XMLPattern["p"], ___}] :> {p -> XMLElement["p", {"class" -> c}, p[[3]]]}],
  doc[XMLElement["div", {"class" -> "c"}, {XMLElement["p", {"class" -> "c"}, {"x"}]}]],
  TestID -> "replace-targets-form"
];

(* Contents are rewritten before their container, and each replacement sees
   the tree as rewritten so far. *)
TestCreate[
  XMLReplace[doc[el["p", el["i", el["b", "x"]]]],
    x : XMLPattern["i" | "b"] :> {x -> ReplacePart[x, 1 -> (x[[1]] /. {"i" -> "em", "b" -> "strong"})]}],
  doc[el["p", el["em", el["strong", "x"]]]],
  TestID -> "replace-inside-out"
];

(* Insertion is replacement at a gap. *)
TestCreate[
  XMLReplace[doc[el["ul"]], XMLPattern["ul", _, {___, g : PatternSequence[]}] :> {g -> el["li", "new"]}],
  doc[el["ul", el["li", "new"]]],
  TestID -> "replace-gap-insert"
];

TestCreate[
  XMLReplace[hrefs, XMLPattern["a", "href" -> h_] :> {h -> 5}],
  hrefs,
  {XMLReplace::kind, XMLReplace::kind},
  TestID -> "replace-wrong-kind"
];

TestCreate[
  XMLReplace[doc[el["ul", el["li"], el["li"], el["li"]]],
    XMLPattern["ul", _, {___, x : XMLPattern["li"], ___, y : XMLPattern["li"], ___}] :> {x -> "first", y -> "second"}],
  doc[el["ul", "first", "second", "second"]],
  {XMLReplace::conflict},
  TestID -> "replace-conflict"
];

TestCreate[
  XMLReplace[doc[el["div", e["p", "1"], e["p", "2"]]],
    XMLPattern["div", _, {x : XMLPattern["p"], y : XMLPattern["p"]}] :> {x -> y, y -> Nothing}],
  doc[el["div", e["p", "2"]]],
  {XMLReplace::stale},
  TestID -> "replace-stale"
];

(* === One test per kind === *)

(* An element takes an element, a string, Splice[list] or Nothing. *)
TestCreate[
  XMLReplace[links, XMLPattern["p", _, {x_, y_, z_}] :> {x -> el["b"], y -> Splice[{"s", el["i"]}], z -> Nothing}],
  doc[el["p", el["b"], "s", el["i"]]],
  TestID -> "replace-kind-element"
];

(* An XMLObject's root stays an element; a list is not an element's kind. *)
TestCreate[
  {XMLReplace[links, x : XMLPattern["p"] :> {x -> "t"}], XMLReplace[links, x : XMLPattern["a", "id" -> "2"] :> {x -> {"t"}}]},
  {links, links},
  {XMLReplace::kind, XMLReplace::kind},
  TestID -> "replace-kind-element-refused"
];

TestCreate[
  XMLReplace[links, XMLPattern[t_, "id" -> "2"] :> {t -> "b"}],
  doc[el["p", e["a", "1"], e["b", "2"], e["a", "3"]]],
  TestID -> "replace-kind-tag"
];

TestCreate[
  XMLReplace[hrefs, XMLPattern["a", a_] :> {a -> {"href" -> "/y", "id" -> "k"}}],
  doc[el["p", XMLElement["a", {"href" -> "/y", "id" -> "k"}, {}], XMLElement["a", {"href" -> "/y", "id" -> "k"}, {}]]],
  TestID -> "replace-kind-attribute-map"
];

(* An attribute value takes a string, or Nothing to remove the attribute. *)
TestCreate[
  {XMLReplace[hrefs, XMLPattern["a", "href" -> h_] :> {h -> h <> "/y"}], XMLReplace[hrefs, XMLPattern["a", "href" -> h_] :> {h -> Nothing}]},
  {doc[el["p", XMLElement["a", {"href" -> "/x/y"}, {}], XMLElement["a", {"href" -> "/x/y"}, {}]]], doc[el["p", el["a"], el["a"]]]},
  TestID -> "replace-kind-attribute"
];

TestCreate[
  XMLReplace[doc[XMLElement["p", {"id" -> "i", "class" -> "a b"}, {}]], XMLPattern["p", "classList" -> c_] :> {c -> Append[c, "z"]}],
  doc[XMLElement["p", {"id" -> "i", "class" -> "a b z"}, {}]],
  TestID -> "replace-kind-list-key"
];

TestCreate[
  XMLReplace[doc[XMLElement["p", {"class" -> "a b"}, {}]], XMLPattern["p", "classList" -> {___, t : "b", ___}] :> {t -> "B"}],
  doc[XMLElement["p", {"class" -> "a B"}, {}]],
  TestID -> "replace-kind-token"
];

TestCreate[
  XMLReplace[doc[XMLElement["p", {"class" -> "a b c d"}, {}]], XMLPattern["p", "classList" -> {_, r__, _}] :> {r -> {"x"}}],
  doc[XMLElement["p", {"class" -> "a x d"}, {}]],
  TestID -> "replace-kind-token-run"
];

(* Tokens are written back through the reading: "," for the comma-separated
   microsyntax. *)
TestCreate[
  XMLReplace[doc[XMLElement["img", {"srcset" -> "a.png 1x, b.png 2x"}, {}]],
    XMLPattern["img", "srcsetList" -> {_, g : PatternSequence[], ___}] :> {g -> {"m.png 3x"}},
    "AttributeReadings" -> <|"srcset" -> <|Method -> "CommaSeparated"|>|>],
  doc[XMLElement["img", {"srcset" -> "a.png 1x,m.png 3x,b.png 2x"}, {}]],
  TestID -> "replace-kind-token-gap"
];

TestCreate[
  XMLReplace[doc[el["div", el["p", "x", el["b"]], "y"]], XMLElement["p", _, c_] :> {c -> Prepend[c, "t"]}],
  doc[el["div", el["p", "t", "x", el["b"]], "y"]],
  TestID -> "replace-kind-contents"
];

(* A run takes Splice[list], a list or Nothing; the text between its
   elements is not element children, and stays, as when a run is deleted. *)
TestCreate[
  {XMLReplace[doc[el["div", e["p", "1"], "x", e["p", "2"], "y", e["p", "3"]]], XMLPattern["div", _, {_, r__}] :> {r -> {el["hr"]}}],
    XMLReplace[links, XMLPattern["p", _, {r__, _}] :> {r -> Splice[{"s"}]}],
    XMLReplace[links, XMLPattern["p", _, {_, r__}] :> {r -> Nothing}]},
  {doc[el["div", e["p", "1"], "x", el["hr"], "y"]], doc[el["p", "s", e["a", "3"]]], doc[el["p", e["a", "1"]]]},
  TestID -> "replace-kind-run"
];

TestCreate[
  XMLReplace[links, XMLPattern["p", _, {_, g : PatternSequence[], ___}] :> {g -> Splice[{"s", el["b"]}]}],
  doc[el["p", e["a", "1"], "s", el["b"], e["a", "2"], e["a", "3"]]],
  TestID -> "replace-kind-gap"
];

TestCreate[
  XMLReplace[links, d : XMLDocument[{XMLPattern["p"]}] :> {d -> "x"}],
  $Failed,
  {XMLReplace::target},
  TestID -> "replace-kind-document-refused"
];

TestCreate[
  XMLReplace[doc[e["nav", "o", e["a", "a1"]]], XMLPattern["nav", _, p : Descendant[XMLPattern["a"]]] :> {p -> {}}],
  $Failed,
  {XMLReplace::pathtarget},
  TestID -> "replace-kind-path-refused"
];

(* === Around the kinds === *)

(* A list of rules: each position takes the first rule that targets it. *)
TestCreate[
  XMLReplace[links, {XMLPattern["a", "id" -> "2"] :> "two", XMLPattern["a"] :> "any"}],
  doc[el["p", "any", "two", "any"]],
  TestID -> "replace-rule-list"
];

(* A Condition on the right-hand side filters the results. *)
TestCreate[
  XMLReplace[links, x : XMLPattern["a"] :> "z" /; Lookup[x[[2]], "id"] =!= "2"],
  doc[el["p", "z", e["a", "2"], "z"]],
  TestID -> "replace-rhs-condition"
];

(* A bare element input's own position is never a target. *)
TestCreate[
  XMLReplace[el["b", e["a", "2"], "t"], XMLPattern[_] :> "z"],
  el["b", "z", "t"],
  TestID -> "replace-bare-input"
];
