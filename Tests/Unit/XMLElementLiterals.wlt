(* XMLElement patterns (ADR 0023): exact WL
   literals accepted wherever a pattern goes, with XMLPatterns nested in
   their contents; names deep inside them have positions; a counted name
   that binds text is ::text, and a name bound only inside Except used in
   the right-hand side is ::exceptname. *)

row     = doc[el["tr", el["th", "a"], el["td", "a"], el["td", "b"]]];
links   = doc[el["p", e["a", "1"], e["a", "2"], e["a", "3"]]];
listing = doc[XMLElement["ul", {"class" -> "a b"}, {el["li"], " ", el["li", XMLElement["a", {"href" -> "/x"}, {}]]}]];

(* === Text === *)

(* t is uncounted and repeated, so the two texts must be equal. *)
TestCreate[
  XMLCases[row, XMLPattern["tr", _, {h : XMLElement["th", _, {t_String}], ___, XMLElement["td", _, {t_String}], ___}] :> h],
  {XMLElement["th", {}, {"a"}]},
  TestID -> "literal-text-repeated-uncounted"
];

TestCreate[
  XMLCases[row, XMLPattern["tr", _, {XMLElement["th", _, {t_String}], ___}] :> t],
  $Failed,
  {XMLCases::text},
  TestID -> "literal-text-counted-static"
];

(* A sequence is known to bind text only while matching. *)
TestCreate[
  XMLCases[row, XMLPattern["tr", _, {XMLElement["th", _, {s___}], ___}] :> {s}],
  $Failed,
  {XMLCases::text},
  TestID -> "literal-text-counted-sequence"
];

TestCreate[
  XMLPosition[row, XMLPattern["tr", _, {XMLElement["th", _, {t_}], ___}] :> t],
  $Failed,
  {XMLPosition::text},
  TestID -> "literal-text-counted-blank-xmlposition"
];

TestCreate[
  {XMLDeleteCases[row, XMLPattern["tr", _, {XMLElement["th", _, {t_String}], ___}] :> t],
    XMLReplace[row, XMLPattern["tr", _, {XMLElement["th", _, {t_String}], ___}] :> {t -> "b"}]},
  {$Failed, $Failed},
  {XMLDeleteCases::text, XMLReplace::text},
  TestID -> "literal-text-counted-rewrite"
];

(* Uncounted, a name may bind text. *)
TestCreate[
  XMLCases[row, (h : XMLPattern["tr", _, {XMLElement["th", _, {s___}], ___}]) /; {s} === {"a"} :> h],
  {row[[2]]},
  TestID -> "literal-text-uncounted-sequence"
];

TestCreate[
  XMLCases[row, XMLElement["tr", _, {x_, ___}] :> x],
  {el["th", "a"]},
  TestID -> "literal-blank-binds-element"
];

(* === Where an XMLElement pattern goes === *)

TestCreate[
  XMLCases[row, XMLElement["tr", _, {XMLPattern["th"], ___}]],
  {row[[2]]},
  TestID -> "literal-whole-query-nested-xmlpattern"
];

TestCreate[
  XMLCases[row, XMLPattern["tr", _, {XMLElement["th", _, {"a"}], x : XMLPattern["td"], ___}] :> x],
  {el["td", "a"]},
  TestID -> "literal-contents-list-entry"
];

TestCreate[
  XMLCases[row, XMLPattern["tr", _, Descendant[x : XMLElement["td", _, {"b"}]]] :> x],
  {el["td", "b"]},
  TestID -> "literal-inside-descendant"
];

TestCreate[
  XMLCases[listing, XMLPattern["ul", _, Descendant[x : XMLElement["li", _, {XMLPattern["a"]}]]] :> x],
  {listing[[2, 3, 3]]},
  TestID -> "literal-inside-descendant-nested-xmlpattern"
];

(* Exact contents: text counts, whitespace included, and a string is text,
   not CSS. *)
TestCreate[
  {XMLCases[listing, XMLElement["ul", _, {XMLPattern["li"], XMLPattern["li"]}]],
    XMLCases[listing, XMLElement["ul", _, {XMLPattern["li"], " ", XMLPattern["li"]}]]},
  {{}, {listing[[2]]}},
  TestID -> "literal-whitespace-counts"
];

TestCreate[
  XMLCases[row, XMLElement["th", _, {"a"}]],
  {el["th", "a"]},
  TestID -> "literal-string-is-text"
];

(* The attributes are the raw rule list, with no list keys. *)
TestCreate[
  {XMLCases[listing, XMLElement["ul", {"class" -> "a b"}, _]], XMLCases[listing, XMLElement["ul", {"classList" -> _}, _]]},
  {{listing[[2]]}, {}},
  TestID -> "literal-raw-attributes"
];

TestCreate[
  XMLMatchQ[row[[2]], XMLElement["tr", _, {XMLPattern["th"], XMLPattern["td"], XMLPattern["td", _, {}]}]],
  True,
  TestID -> "literal-xmlmatchq-nested-xmlpattern"
];

(* === Names deep inside an XMLElement pattern === *)

TestCreate[
  XMLCases[row, XMLElement["tr", _, {___, x : XMLElement["td", _, _], ___}] :> x],
  {el["td", "a"], el["td", "b"]},
  TestID -> "literal-deep-name-every-match"
];

TestCreate[
  XMLPosition[row, XMLElement["tr", _, {___, x : XMLElement["td", _, _], ___}] :> x],
  {{1, 2}, {1, 3}},
  TestID -> "literal-deep-name-positions"
];

(* Positions count element children only, so the " " between is skipped. *)
TestCreate[
  XMLPosition[listing, XMLElement["ul", _, {_, _, x : XMLPattern["li", _, {XMLPattern["a"]}]}] :> x],
  {{1, 2}},
  TestID -> "literal-deep-xmlpattern-position-counts-elements"
];

TestCreate[
  XMLPosition[listing, XMLElement["ul", _, {_, _, XMLElement["li", _, {XMLElement["a", {"href" -> h_}, _]}]}] :> h],
  {{1, 2, 1, Key["href"]}},
  TestID -> "literal-deep-attribute-value-position"
];

TestCreate[
  XMLPosition[links, XMLElement["p", _, {_, r__}] :> r],
  {{1, 2 ;; 3}},
  TestID -> "literal-deep-run-position"
];

TestCreate[
  XMLPosition[listing, XMLElement["ul", _, {_, g___, " ", ___}] :> g],
  {{1, 2 ;; 1}},
  TestID -> "literal-deep-gap-position"
];

TestCreate[
  XMLPosition[row, XMLElement["tr", _, {XMLElement[t_, _, _], ___}] :> t],
  {{1, 1, 0}},
  TestID -> "literal-deep-tag-position"
];

TestCreate[
  XMLDeleteCases[row, XMLElement["tr", _, {___, x : XMLElement["td", _, {"b"}]}] :> x],
  doc[el["tr", el["th", "a"], el["td", "a"]]],
  TestID -> "literal-deep-name-deletes"
];

(* === Descendant is refused in a literal === *)

TestCreate[
  XMLCases[row, XMLElement["tr", _, {Descendant[XMLPattern["td"]], ___}]],
  $Failed,
  {Descendant::place},
  TestID -> "literal-descendant-refused"
];

(* === Except === *)

TestCreate[
  XMLCases[row, XMLElement["tr", _, Except[{x_, y_} /; x === y]]],
  {row[[2]]},
  TestID -> "literal-except-names-used-inside"
];

TestCreate[
  XMLCases[row, XMLPattern["tr", _, {XMLElement["th", _, Except[{x_, y_} /; x =!= y]], ___}] :> x],
  $Failed,
  {XMLCases::exceptname},
  TestID -> "literal-except-name-in-rhs"
];

TestCreate[
  XMLCases[links, XMLPattern["p", _, {Except[x : XMLPattern["a"]] ..., ___}] :> x],
  $Failed,
  {XMLCases::exceptname},
  TestID -> "literal-except-name-in-rhs"
];
