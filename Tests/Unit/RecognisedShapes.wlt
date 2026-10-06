(* Recognised shapes (ADR 0020): a list stage in a shape the compiler
   recognises runs by a dedicated method, with the same results as WL's matcher
   on the pattern as written. Each test runs a query with recognition on and
   off, on seeded random trees (Support/RandomTrees.wl), and checks that the
   two agree on every tree and that the query selects something on some tree,
   so that the comparison is not of empty results. *)

(* Recognition off, for one evaluation: every list stage runs on the general
   matcher. *)
SetAttributes[unrecognised, HoldFirst];
unrecognised[expr_] := Block[{MaximilienTirard`BeautifulTureen`Private`$recogniseShapes = False}, expr];

SetAttributes[sameEitherWay, HoldFirst];
sameEitherWay[expr_] := With[{on = expr}, on === unrecognised[expr] && !FreeQ[on, _XMLElement | _String] && FreeQ[on, $Failed]];

(* The tree after deletion, or Nothing when nothing was deleted, so that a
   deletion that never deletes gives no results. *)
deleted[t_, p_] := With[{d = XMLDeleteCases[t, p]}, If[d === t, Nothing, d]];

$trees = randomTrees[20261006, 12];

(* The top elements of a list are siblings below the document (ADR 0018). *)
$lists = Select[Last /@ $trees, MemberQ[#, _XMLElement] &];

li = XMLPattern["li"];
any = XMLPattern[_];

(* === Shape 1: anywhere, {___, C, ___} === *)

TestCreate[
  sameEitherWay[Map[Join[
    XMLCases[#, Child[any, {___, li, ___}]],
    XMLCases[#, Descendant[XMLPattern["div"], {___, XMLPattern["p", "classList" -> "a"], ___}]],
    XMLCases[#, Child[Child[any, {___, XMLPattern["span"], ___}], XMLPattern[_]]]] &, $trees]],
  True,
  TestID -> "shape-anywhere-cases"
];

TestCreate[
  sameEitherWay[Map[{
    XMLFirstCase[#, Child[any, {___, li, ___}], None],
    XMLFirstCase[#, Descendant[XMLPattern["div"], {___, XMLPattern[_, "classList" -> "b"], ___}], None]} &, $trees]],
  True,
  TestID -> "shape-anywhere-first-case"
];

TestCreate[
  sameEitherWay[Map[{
    deleted[#, Child[any, {___, li, ___}]],
    deleted[#, Descendant[XMLPattern["div"], {___, XMLPattern["p", "classList" -> "c"], ___}]]} &, $trees]],
  True,
  TestID -> "shape-anywhere-delete-cases"
];

(* The count stops early (ADR 0019). *)
TestCreate[
  sameEitherWay[Map[Join[
    XMLCases[#, Child[any, {___, li, ___}], 3],
    XMLCases[#, Descendant[any, {___, XMLPattern["span", "classList" -> "a"], ___}], 1]] &, $trees]],
  True,
  TestID -> "shape-anywhere-count"
];

(* A named selected entry seen by a rule body, with and without a list key,
   which renames the element (ADR 0012). *)
TestCreate[
  sameEitherWay[Map[Join[
    XMLCases[#, Child[XMLPattern["div"], {___, c : li, ___}] :> Lookup[c[[2]], "id"]],
    XMLCases[#, Descendant[any, {___, c : XMLPattern["p", "classList" -> "a" | "b"], ___}] :> {c[[1]], c[[2]]}]] &, $trees]],
  True,
  TestID -> "shape-anywhere-named-entry-in-body"
];

(* The two-step match (solvable): a Condition that sees a name after the
   first rule of a KeyValuePattern. *)
TestCreate[
  sameEitherWay[Map[XMLCases[#,
    Child[any, {___, c : XMLPattern[_, {"class" -> k_, "id" -> i_}] /; StringLength[k] < StringLength[i] + 2, ___}] :> Lookup[c[[2]], "id"]] &, $trees]],
  True,
  TestID -> "shape-anywhere-two-step-match"
];

(* The top elements of a list input, listed below the document (ADR 0018). *)
TestCreate[
  sameEitherWay[Map[Join[
    XMLCases[#, Child[XMLDocument[], {___, c : XMLPattern["div" | "p"], ___}] :> Lookup[c[[2]], "id"]],
    XMLCases[#, Child[XMLDocument[], {___, XMLPattern[_, "classList" -> "a"], ___}], 2],
    {XMLFirstCase[#, Child[XMLDocument[], {___, li, ___}], None]},
    {deleted[#, Child[XMLDocument[], {___, li, ___}]]}] &, $lists]],
  True,
  TestID -> "shape-anywhere-below-document"
];

(* A reading added by the option is materialised as the default one is. *)
TestCreate[
  sameEitherWay[Map[XMLCases[# /. ("class" -> v_) :> ("rel" -> v),
    Descendant[any, {___, XMLPattern["li" | "p", "relList" -> "a"], ___}],
    "AttributeReadings" -> <|"rel" -> <||>|>] &, $trees]],
  True,
  TestID -> "shape-anywhere-attribute-readings"
];

(* === Context entries ===

   A list stage with a context entry is no shape and runs on the general
   matcher, but each context entry is compiled once, as a chain of its own, and
   a list stage inside it, or after it in the selected entry's chain, is
   recognised as any other is. *)

TestCreate[
  With[{divWithP = Child[XMLPattern["div"], {___, XMLPattern["p"], ___}]},
  sameEitherWay[Map[Join[
    XMLCases[#, Child[any, {___, divWithP, ___, li, ___}]],
    XMLCases[#, Child[any, {___, Child[XMLPattern["div"], XMLPattern["span"]], Child[li, {___, any, ___}]}]],
    XMLCases[#, Descendant[any, {___, Descendant[XMLPattern["div"], {___, XMLPattern["span", "classList" -> "a"], ___}], ___, XMLPattern["p"], ___}], 4],
    {XMLFirstCase[#, Child[any, {___, Child[XMLPattern["div"], {___, li, ___}], ___, XMLPattern[_], ___}], None]},
    {deleted[#, Child[any, {___, divWithP, ___, li, ___}]]},
    XMLCases[#, Child[any, {___, divWithP, ___, c : li, ___}] :> Lookup[c[[2]], "id"]]] &, $trees]]],
  True,
  TestID -> "shape-context-entry-inside"
];

(* Below the document, and with a reading added by the option, inside the
   context entry. *)
TestCreate[
  sameEitherWay[Join[
    Map[XMLCases[#, Child[XMLDocument[], {___, Child[XMLPattern["div"], {___, XMLPattern["p"], ___}], ___, li, ___}]] &, $lists],
    Map[XMLCases[# /. ("class" -> v_) :> ("rel" -> v),
      Child[any, {___, Child[XMLPattern["div" | "li"], {___, XMLPattern[_, "relList" -> "a"], ___}], ___, XMLPattern[_, "relList" -> "b"], ___}],
      "AttributeReadings" -> <|"rel" -> <||>|>] &, $trees]]],
  True,
  TestID -> "shape-context-entry-inside-document-readings"
];

(* === Shapes 2 and 3: a position among all children, from the start, from the
   end, or both === *)

(* The entries before the selected one in each spelling the translator emits
   (FromCSSSelector of the selector in the comment), and in some written by
   hand. *)
$fromStart = {
  {},                                                   (* :first-child *)
  {_},                                                  (* :nth-child(2) *)
  {Repeated[_, {2}]},                                   (* :nth-child(3) *)
  {Repeated[_, {0, 2}]},                                (* :nth-child(-n+3) *)
  {PatternSequence[_, _]...},                           (* :nth-child(2n+1) *)
  {_, PatternSequence[_, _]...},                        (* :nth-child(2n) *)
  {Repeated[_, {2}], RepeatedNull[_]},                  (* :nth-child(n+3) *)
  {_, PatternSequence[_, _, _]...},                     (* :nth-child(3n-1) *)
  {_, Repeated[PatternSequence[_, _], {0, 1}]},         (* :nth-child(-2n+4) *)
  {Except[_]},                                          (* :nth-child(0n+0), :nth-child(-n) *)
  {_, _, _},
  {__},
  {Repeated[_], _},
  {Repeated[_, 3]},
  {Repeated[PatternSequence[_, _], {1, 2}], _},
  {PatternSequence[_, _], PatternSequence[_, _]..}};

(* The entries after it, counted from the end, as the translator mirrors
   them. *)
$fromEnd = Reverse /@ $fromStart;

TestCreate[
  sameEitherWay[Map[Function[t, Join @@ Table[Join[
      XMLCases[t, Child[any, Join[pre, {li, ___}]]],
      XMLCases[t, Descendant[XMLPattern["div"], Join[pre, {XMLPattern[_, "classList" -> "a"], ___}]]]],
    {pre, $fromStart}]], $trees]],
  True,
  TestID -> "shape-from-start-cases"
];

TestCreate[
  sameEitherWay[Map[Function[t, Join @@ Table[Join[
      XMLCases[t, Child[any, Join[{___, li}, post]]],
      XMLCases[t, Descendant[XMLPattern["div"], Join[{___, XMLPattern[_, "classList" -> "a"]}, post]]]],
    {post, $fromEnd}]], $trees]],
  True,
  TestID -> "shape-from-end-cases"
];

(* :only-child, :root's {Except[_], C}, and positions from both ends. *)
TestCreate[
  sameEitherWay[Map[Function[t, Join[
      XMLCases[t, Child[any, {li}]],
      XMLCases[t, Child[any, {any}]],
      XMLCases[t, Child[any, {Except[_], any}]],
      XMLCases[t, Child[any, {_, any, Repeated[_, {2}]}]],
      XMLCases[t, Child[any, {PatternSequence[_, _]..., XMLPattern["p" | "li"], _, PatternSequence[_, _, _]...}]],
      XMLCases[t, Child[any, {Repeated[_, {0, 3}], any, Repeated[_, {0, 3}]}]]]], $trees]],
  True,
  TestID -> "shape-from-both-ends-cases"
];

TestCreate[
  sameEitherWay[Map[{
    XMLFirstCase[#, Child[any, {_, PatternSequence[_, _]..., li, ___}], None],
    XMLFirstCase[#, Descendant[XMLPattern["div"], {___, XMLPattern[_, "classList" -> "b"], Repeated[_, {2}]}], None],
    XMLFirstCase[#, Child[any, {Repeated[_, {0, 2}], XMLPattern["span"]}], None]} &, $trees]],
  True,
  TestID -> "shape-positions-first-case"
];

TestCreate[
  sameEitherWay[Map[{
    deleted[#, Child[any, {li, ___}]],
    deleted[#, Child[any, {___, XMLPattern["p"], PatternSequence[_, _]...}]],
    deleted[#, Descendant[XMLPattern["div"], {Repeated[_, {3}], XMLPattern[_, "classList" -> "c"], ___}]]} &, $trees]],
  True,
  TestID -> "shape-positions-delete-cases"
];

TestCreate[
  sameEitherWay[Map[Join[
    XMLCases[#, Child[any, {PatternSequence[_, _]..., any, ___}], 3],
    XMLCases[#, Descendant[any, {___, XMLPattern["span"], _}], 1]] &, $trees]],
  True,
  TestID -> "shape-positions-count"
];

TestCreate[
  sameEitherWay[Map[Join[
    XMLCases[#, Child[XMLPattern["div"], {_, c : li, ___}] :> Lookup[c[[2]], "id"]],
    XMLCases[#, Descendant[any, {___, c : XMLPattern["p", "classList" -> "a" | "b"], RepeatedNull[_]}] :> {c[[1]], c[[2]]}],
    XMLCases[#, Child[any, {PatternSequence[_, _]..., c : any, ___}] :> Lookup[c[[2]], "id"]]] &, $trees]],
  True,
  TestID -> "shape-positions-named-entry-in-body"
];

TestCreate[
  sameEitherWay[Map[XMLCases[#,
    Child[any, {_, PatternSequence[_, _]..., c : XMLPattern[_, {"class" -> k_, "id" -> i_}] /; StringLength[k] < StringLength[i] + 2, ___}] :> Lookup[c[[2]], "id"]] &, $trees]],
  True,
  TestID -> "shape-positions-two-step-match"
];

TestCreate[
  sameEitherWay[Map[Join[
    XMLCases[#, Child[XMLDocument[], {_, c : XMLPattern["div" | "p"], ___}] :> Lookup[c[[2]], "id"]],
    XMLCases[#, Child[XMLDocument[], {___, XMLPattern[_, "classList" -> "a"], PatternSequence[_, _]...}], 2],
    XMLCases[#, Child[XMLDocument[], {Except[_], any}]],
    {XMLFirstCase[#, Child[XMLDocument[], {Repeated[_, {0, 2}], li, ___}], None]},
    {deleted[#, Child[XMLDocument[], {___, li, _}]]}] &, $lists]],
  True,
  TestID -> "shape-positions-below-document"
];

TestCreate[
  sameEitherWay[Map[XMLCases[# /. ("class" -> v_) :> ("rel" -> v),
    Descendant[any, {_, PatternSequence[_, _]..., XMLPattern["li" | "p", "relList" -> "a"], ___}],
    "AttributeReadings" -> <|"rel" -> <||>|>] &, $trees]],
  True,
  TestID -> "shape-positions-attribute-readings"
];

(* The CSS selectors that translate to shapes 2 and 3 mean their translations,
   with recognition on and off. Some select nothing on any tree, as :root
   does below a bare element, which is never a result. *)
$positionSelectors = {"li:first-child", "li:last-child", ":only-child", "p:nth-child(3)", "div > :nth-child(-n+3)",
  "li:nth-child(2n+1)", ".a:nth-child(2n)", ":nth-child(3n-1)", ":nth-child(-2n+4) span", "li:nth-last-child(2)",
  ":nth-last-child(2n+1)", ":nth-last-child(-n+2)", ":nth-child(2):nth-last-child(3)", "li:nth-child(0n+0)", ":root"};

TestCreate[
  sameEitherWay[Map[Function[css, With[{r = XMLCases[#, css] & /@ $trees},
      If[r === (XMLCases[#, FromCSSSelector[css]] & /@ $trees), r, $Failed]]],
    $positionSelectors]],
  True,
  TestID -> "shape-positions-css-means-translation"
];

(* Position-set laws, on the children of each tree's root, as the children of
   an ol, a tag random trees do not use. *)
$siblings = XMLElement["ol", {}, Last[#]] & /@ $trees;

ids[l_] := Sort[Lookup[#[[2]], "id"] & /@ l];

TestCreate[
  AllTrue[$siblings, Function[t,
    With[{even = ids @ XMLCases[t, "ol > :nth-child(2n)"], odd = ids @ XMLCases[t, "ol > :nth-child(2n+1)"]},
      !IntersectingQ[even, odd] && Union[even, odd] === ids[XMLCases[t, "ol > *"]]]]],
  True,
  TestID -> "shape-positions-law-even-odd-partition"
];

TestCreate[
  AllTrue[$siblings, Function[t,
    With[{len = Count[Last[t], _XMLElement]},
      AllTrue[Range[len], Function[k,
        With[{r = XMLCases[t, "ol > :nth-child(" <> ToString[k] <> ")"]},
          Length[r] == 1 && r === XMLCases[t, "ol > :nth-last-child(" <> ToString[len - k + 1] <> ")"]]]]]]],
  True,
  TestID -> "shape-positions-law-from-start-is-from-end"
];

TestCreate[
  AllTrue[$trees, ids[XMLCases[#, ":only-child"]] === Intersection[ids[XMLCases[#, ":first-child"]], ids[XMLCases[#, ":last-child"]]] &],
  True,
  TestID -> "shape-positions-law-only-child"
];

(* Just outside the shapes, by a name on an entry, a Condition on the list, a
   second XML pattern entry, or repeats of two different lengths: the same
   results as a recognised spelling of the same positions, which select
   something on some tree. *)
TestCreate[
  With[{r = Map[Function[t, {
    XMLCases[t, Child[any, {x_, li, ___}]],
    XMLCases[t, Child[any, {_, li, ___} /; True]],
    XMLCases[t, Child[any, {_, any, li, ___}]],
    XMLCases[t, Child[any, {___, li, y : PatternSequence[_, _]...}]],
    XMLCases[t, Child[any, {Repeated[_, {0, 1}], PatternSequence[_, _]..., li, ___}]]}], $trees]},
    r === Map[Function[t, {
    XMLCases[t, Child[any, {_, li, ___}]],
    XMLCases[t, Child[any, {_, li, ___}]],
    XMLCases[t, Child[any, {Repeated[_, {2}], li, ___}]],
    XMLCases[t, Child[any, {___, li, PatternSequence[_, _]...}]],
    XMLCases[t, Child[any, {___, li, ___}]]}], $trees] && AllTrue[Transpose[r], !FreeQ[#, _XMLElement] &]],
  True,
  TestID -> "shape-positions-unrecognised-still-correct"
];

(* === Shapes 4 and 5: a position among the children that match a pattern t,
   from the start, from the end, or both === *)

(* With recognition off, WL's matcher backtracks on these plain entries when t
   is not a literal: a repeat of units over the random trees' lists of up to 40
   children takes seconds per spelling. The comparisons use the same trees
   with each list of children cut to its first 12. *)
$smallTrees = Replace[#, XMLElement[tag_, as_, c_] :> XMLElement[tag, as, Take[c, UpTo[12]]], {0, Infinity}] & /@ $trees;
$smallLists = Select[Last /@ $smallTrees, MemberQ[#, _XMLElement] &];

(* The entries before the selected one, counting the children that match t,
   in each spelling the translator emits (FromCSSSelector of the selector in
   the comment, with t the type) and in some written by hand. *)
counting[t_] := {
  {Except[t]...},                                                     (* :first-of-type *)
  {Except[t]..., PatternSequence[t, Except[t]...]},                   (* :nth-of-type(2) *)
  {Except[t]..., Repeated[PatternSequence[t, Except[t]...], {2}]},    (* :nth-of-type(3) *)
  {Except[t]..., Repeated[PatternSequence[t, Except[t]...], {0, 2}]}, (* :nth-of-type(-n+3) *)
  {Except[t]..., PatternSequence[t, Except[t]..., t, Except[t]...]...},                                  (* :nth-of-type(2n+1) *)
  {Except[t]..., PatternSequence[t, Except[t]...], PatternSequence[t, Except[t]..., t, Except[t]...]...}, (* :nth-of-type(2n) *)
  {Except[t]..., t, Except[t]...},
  {Except[t]..., t, Except[t]..., PatternSequence[t, Except[t]...]...},
  {Except[t]..., Repeated[PatternSequence[t, Except[t]...], {1, 2}]},
  {Except[t]..., Except[_]}};

(* As the translator writes them: an XML pattern, a selector list, and a
   selector tested whole. *)
$counted = {XMLPattern["p"], XMLPattern[_, "classList" -> "a"], XMLPattern["li"] | XMLPattern[_, "classList" -> "b"],
  _?(XMLMatchQ[XMLPattern[_, "classList" -> "c"]])};

TestCreate[
  sameEitherWay[Map[Function[t, Join @@ Table[Join[
      XMLCases[t, Child[any, Join[pre, {li, ___}]]],
      XMLCases[t, Descendant[XMLPattern["div"], Join[pre, {XMLPattern["p", "classList" -> "a"], ___}]]]],
    {pre, Join @@ (counting /@ $counted)}]], $smallTrees]],
  True,
  TestID -> "shape-counted-from-start-cases"
];

(* The mirror after the selected one: each PatternSequence reversed too. *)
mirror[es_List] := Reverse[Replace[es, Verbatim[PatternSequence][ps___] :> PatternSequence @@ Reverse[{ps}], {1, Infinity}]];

TestCreate[
  sameEitherWay[Map[Function[t, Join @@ Table[Join[
      XMLCases[t, Child[any, Join[{___, li}, post]]],
      XMLCases[t, Descendant[XMLPattern["div"], Join[{___, XMLPattern["p", "classList" -> "a"]}, post]]]],
    {post, mirror /@ Join @@ (counting /@ $counted)}]], $smallTrees]],
  True,
  TestID -> "shape-counted-from-end-cases"
];

(* :only-of-type, counted positions at both ends, a different t at each, and
   one end among all children. *)
TestCreate[
  With[{p = XMLPattern["p"], a = XMLPattern[_, "classList" -> "a"]},
  sameEitherWay[Map[Function[t, Join[
      XMLCases[t, Child[any, {Except[p]..., p, Except[p]...}]],
      XMLCases[t, Child[any, {Except[p]..., PatternSequence[p, Except[p]...], any, PatternSequence[Except[a]..., a]..., Except[a]...}]],
      XMLCases[t, Child[any, {Except[a]..., Repeated[PatternSequence[a, Except[a]...], {0, 1}], li, Except[a]...}]],
      XMLCases[t, Child[any, {_, any, PatternSequence[Except[p]..., p], Except[p]...}]],
      XMLCases[t, Child[any, {Except[p]..., PatternSequence[p, Except[p]..., p, Except[p]...]..., p, PatternSequence[_, _]...}]]]], $smallTrees]]],
  True,
  TestID -> "shape-counted-from-both-ends-cases"
];

TestCreate[
  sameEitherWay[Map[{
    XMLFirstCase[#, Child[any, {Except[li]..., PatternSequence[li, Except[li]...], li, ___}], None],
    XMLFirstCase[#, Descendant[XMLPattern["div"], {___, XMLPattern["p"], PatternSequence[Except[XMLPattern["p"]]..., XMLPattern["p"]], Except[XMLPattern["p"]]...}], None]} &, $smallTrees]],
  True,
  TestID -> "shape-counted-first-case"
];

TestCreate[
  sameEitherWay[Map[{
    deleted[#, Child[any, {Except[li]..., PatternSequence[li, Except[li]...], li, ___}]],
    deleted[#, Descendant[XMLPattern["div"], {___, XMLPattern["span"], PatternSequence[Except[XMLPattern["span"]]..., XMLPattern["span"]]..., Except[XMLPattern["span"]]...}]]} &, $smallTrees]],
  True,
  TestID -> "shape-counted-delete-cases"
];

TestCreate[
  sameEitherWay[Map[Join[
    XMLCases[#, Child[any, {Except[li]..., PatternSequence[li, Except[li]..., li, Except[li]...]..., li, ___}], 3],
    XMLCases[#, Descendant[any, {___, XMLPattern["span"], Except[XMLPattern["span"]]...}], 1]] &, $smallTrees]],
  True,
  TestID -> "shape-counted-count"
];

TestCreate[
  With[{a = XMLPattern[_, "classList" -> "a"]},
  sameEitherWay[Map[Join[
    XMLCases[#, Child[XMLPattern["div"], {Except[li]..., PatternSequence[li, Except[li]...], c : li, ___}] :> Lookup[c[[2]], "id"]],
    XMLCases[#, Descendant[any, {___, c : XMLPattern["p", "classList" -> "a" | "b"], Repeated[PatternSequence[Except[a]..., a], {0, 1}], Except[a]...}] :> {c[[1]], c[[2]]}]] &, $smallTrees]]],
  True,
  TestID -> "shape-counted-named-entry-in-body"
];

TestCreate[
  sameEitherWay[Map[XMLCases[#,
    Child[any, {Except[li]..., PatternSequence[li, Except[li]...]..., c : XMLPattern[_, {"class" -> k_, "id" -> i_}] /; StringLength[k] < StringLength[i] + 2, ___}] :> Lookup[c[[2]], "id"]] &, $smallTrees]],
  True,
  TestID -> "shape-counted-two-step-match"
];

TestCreate[
  sameEitherWay[Map[Join[
    XMLCases[#, Child[XMLDocument[], {Except[li]..., PatternSequence[li, Except[li]...], c : li, ___}] :> Lookup[c[[2]], "id"]],
    XMLCases[#, Child[XMLDocument[], {___, XMLPattern["div"], PatternSequence[Except[XMLPattern["div"]]..., XMLPattern["div"]]..., Except[XMLPattern["div"]]...}], 2],
    {XMLFirstCase[#, Child[XMLDocument[], {Except[XMLPattern["p"]]..., Repeated[PatternSequence[XMLPattern["p"], Except[XMLPattern["p"]]...], {0, 2}], XMLPattern["p"], ___}], None]},
    {deleted[#, Child[XMLDocument[], {Except[li]..., li, Except[li]...}]]}] &, $smallLists]],
  True,
  TestID -> "shape-counted-below-document"
];

(* t names a list key, which is materialised for t as for the selected entry. *)
TestCreate[
  With[{t = XMLPattern[_, "relList" -> "a"]},
  sameEitherWay[Map[XMLCases[# /. ("class" -> v_) :> ("rel" -> v),
    Descendant[any, {Except[t]..., PatternSequence[t, Except[t]...]..., XMLPattern["li" | "p", "relList" -> "a"], ___}],
    "AttributeReadings" -> <|"rel" -> <||>|>] &, $smallTrees]]],
  True,
  TestID -> "shape-counted-attribute-readings"
];

(* The CSS selectors that translate to shapes 4 and 5 mean their
   translations, with recognition on and off. *)
$countedSelectors = {"li:first-of-type", "p:last-of-type", "span:only-of-type", "li:nth-of-type(2)", "p:nth-of-type(2n+1)",
  "div > li:nth-of-type(-n+2)", "li:nth-last-of-type(2)", "span:nth-last-of-type(2n)", ":nth-child(2 of .a)",
  "p:nth-child(2n+1 of .a)", ":nth-last-child(-n+2 of li, .b)", ":nth-child(2 of :has(span))", "p:nth-of-type(2):last-child",
  "li:nth-child(2 of *)"};

TestCreate[
  sameEitherWay[Map[Function[css, With[{r = XMLCases[#, css] & /@ $smallTrees},
      If[r === (XMLCases[#, FromCSSSelector[css]] & /@ $smallTrees), r, $Failed]]],
    $countedSelectors]],
  True,
  TestID -> "shape-counted-css-means-translation"
];

(* The translation as it was, a Count in a condition on the list, means what
   the plain entries do, both on WL's matcher. *)
TestCreate[
  With[{a = XMLPattern[_, "classList" -> "a"], small = $smallTrees},
    unrecognised @ Map[Function[t, {
      XMLCases[t, Child[any, {g___, c : li, ___} /; Count[{g}, XMLElement["li", _, _]] + 1 == 2]],
      XMLCases[t, Child[any, {g___, c : XMLPattern["p", "classList" -> "a"], ___} /; With[{i = Count[{g}, _?(XMLMatchQ[a])] + 1}, i >= 1 && Mod[i - 1, 2] == 0]]],
      XMLCases[t, Child[any, {___, c : XMLPattern["span"], g___} /; Count[{g}, XMLElement["span", _, _]] + 1 <= 2]]}], small] ===
    unrecognised @ Map[Function[t, {
      XMLCases[t, Child[any, {Except[li]..., PatternSequence[li, Except[li]...], li, ___}]],
      XMLCases[t, Child[any, {Except[a]..., PatternSequence[a, Except[a]..., a, Except[a]...]..., XMLPattern["p", "classList" -> "a"], ___}]],
      XMLCases[t, Child[any, {___, XMLPattern["span"], Repeated[PatternSequence[Except[XMLPattern["span"]]..., XMLPattern["span"]], {0, 1}], Except[XMLPattern["span"]]...}]]}], small]],
  True,
  TestID -> "shape-counted-count-form-is-plain-form"
];

(* Position-set laws: :nth-child(k of S) is :nth-child(k) when S is the
   universal selector, and :nth-of-type(k) is :nth-child(k of T) for the type
   T, and the same from the end. *)
TestCreate[
  AllTrue[$siblings, Function[t,
    AllTrue[Range[6], Function[k, With[{n = ToString[k]},
      ids[XMLCases[t, "ol > :nth-child(" <> n <> " of *)"]] === ids[XMLCases[t, "ol > :nth-child(" <> n <> ")"]] &&
      ids[XMLCases[t, "ol > :nth-last-child(" <> n <> " of *)"]] === ids[XMLCases[t, "ol > :nth-last-child(" <> n <> ")"]] &&
      AllTrue[$randomTags, Function[T,
        ids[XMLCases[t, "ol > " <> T <> ":nth-of-type(" <> n <> ")"]] === ids[XMLCases[t, "ol > :nth-child(" <> n <> " of " <> T <> ")"]] &&
        ids[XMLCases[t, "ol > " <> T <> ":nth-last-of-type(" <> n <> ")"]] === ids[XMLCases[t, "ol > :nth-last-child(" <> n <> " of " <> T <> ")"]]]]]]]]],
  True,
  TestID -> "shape-counted-laws"
];

(* Just outside the shapes, by a name on t, a Condition on the list, or the
   two-argument Except: the same results as a recognised spelling of the same
   positions, which select something on some tree. *)
TestCreate[
  With[{p = XMLPattern["p"]},
  With[{r = Map[Function[t, {
    XMLCases[t, Child[any, {Except[p]..., x : p, Except[p]..., li, ___}]],
    XMLCases[t, Child[any, {Except[p]..., PatternSequence[x : p, Except[p]...], li, ___}]],
    XMLCases[t, Child[any, {Except[p]..., PatternSequence[p, Except[p]...], li, ___} /; True]],
    XMLCases[t, Child[any, {___, li, PatternSequence[Except[p, _]..., p], Except[p, _]...}]]}], $smallTrees]},
    r === Map[Function[t, {
    XMLCases[t, Child[any, {Except[p]..., PatternSequence[p, Except[p]...], li, ___}]],
    XMLCases[t, Child[any, {Except[p]..., PatternSequence[p, Except[p]...], li, ___}]],
    XMLCases[t, Child[any, {Except[p]..., PatternSequence[p, Except[p]...], li, ___}]],
    XMLCases[t, Child[any, {___, li, PatternSequence[Except[p]..., p], Except[p]...}]]}], $smallTrees] &&
      AllTrue[Transpose[r], !FreeQ[#, _XMLElement] &]]],
  True,
  TestID -> "shape-counted-unrecognised-still-correct"
];

(* A t that can match a sequence of children is not counted once per child:
   these lists run on the general matcher, with the results it gives. *)
TestCreate[
  With[{p = XMLPattern["p"]},
  sameEitherWay[Map[Function[t, Join[
    XMLCases[t, Child[any, {Except[__]..., PatternSequence[__, Except[__]...], li, ___}]],
    XMLCases[t, Child[any, {Except[p | __]..., PatternSequence[p | __, Except[p | __]...], li, ___}]],
    XMLCases[t, Child[any, {Except[p..]..., PatternSequence[p.., Except[p..]...], li, ___}]]]], $smallTrees]]],
  True,
  TestID -> "shape-counted-sequence-not-counted"
];

(* === Shape 6: ordered entries, {___, e1, ___, e2, e3, ___, C, ___} ===

   Entries that each match one child, element patterns or context combinator
   entries, with ___ or nothing between them and at each end. With recognition
   off, WL's matcher tries every placement of the entries, so these too use
   the trees with each list of children cut to its first 12. *)

para = XMLPattern["p"];
dv = XMLPattern["div"];
spn = XMLPattern["span"];

(* Element-pattern entries before and after the selected one, in blocks of
   adjacent entries, anchored at either end or both, alternatives of element
   patterns, several entries that match one child, blocks that hold the
   selected entry, and entries that are not XML patterns but match one
   child. *)
$ordered = {
  {___, para, ___, li, ___},
  {___, para | spn, ___, li | dv, ___},
  {___, para, li, ___, dv, ___},
  {___, any, ___, any, ___, li, ___},
  {___, li, ___, li, ___},
  {___, li, li, ___, li},
  {para, ___, li, ___},
  {para, ___, li},
  {___, dv, ___, li},
  {li, li, ___, li, ___, li, li},
  {___, para, ___, li, _, ___},
  {___, li, ___, Except[para], ___},
  {___, li, _, ___, Except[spn], Except[para], ___},
  {_, ___, li, ___, XMLPattern[_, "classList" -> "a"], ___},
  {___, XMLPattern[_, "classList" -> "a"], ___, XMLPattern[_, "classList" -> "b"], any, ___, XMLPattern[_, "classList" -> "c"]},
  {___, para, ___, _?(XMLMatchQ[XMLPattern[_, "classList" -> "a"]]), ___, li, ___}};

TestCreate[
  sameEitherWay[Map[Function[t, Join @@ Table[Join[
      XMLCases[t, Child[any, l]],
      XMLCases[t, Descendant[dv, l /. li -> XMLPattern["li" | "p", "classList" -> "a" | "b"]]]],
    {l, $ordered}]], $smallTrees]],
  True,
  TestID -> "shape-ordered-cases"
];

(* Context combinator entries: alone, beside an element pattern, next to the
   selected entry, at an anchored end, two of them, and with a list stage of
   their own. *)
TestCreate[
  With[{divWithSpan = Child[dv, spn], pInDiv = Descendant[dv, para]},
  sameEitherWay[Map[Function[t, Join[
      XMLCases[t, Child[any, {___, divWithSpan, ___, li, ___}]],
      XMLCases[t, Child[any, {___, divWithSpan, ___, pInDiv, ___, any, ___}]],
      XMLCases[t, Child[any, {___, para, ___, divWithSpan, li, ___}]],
      XMLCases[t, Child[any, {divWithSpan, ___, li | para}]],
      XMLCases[t, Child[any, {___, Child[dv, {___, spn, ___}], ___, li, _, ___}]],
      XMLCases[t, Descendant[any, {___, divWithSpan, ___, Child[li | para, spn], ___}]]]], $smallTrees]]],
  True,
  TestID -> "shape-ordered-context-entries"
];

TestCreate[
  sameEitherWay[Map[{
    XMLFirstCase[#, Child[any, {___, para, ___, li, ___}], None],
    XMLFirstCase[#, Descendant[dv, {___, Child[dv, spn], ___, XMLPattern[_, "classList" -> "b"], ___}], None],
    XMLFirstCase[#, Child[any, {para, ___, li}], None]} &, $smallTrees]],
  True,
  TestID -> "shape-ordered-first-case"
];

TestCreate[
  sameEitherWay[Map[{
    deleted[#, Child[any, {___, para, ___, li, ___}]],
    deleted[#, Child[any, {___, Child[dv, spn], ___, li, ___}]],
    deleted[#, Descendant[dv, {___, spn, para, ___, XMLPattern[_, "classList" -> "c"]}]]} &, $smallTrees]],
  True,
  TestID -> "shape-ordered-delete-cases"
];

TestCreate[
  sameEitherWay[Map[Join[
    XMLCases[#, Child[any, {___, para, ___, li, ___}], 3],
    XMLCases[#, Descendant[any, {___, Child[dv, spn], ___, any, ___}], 1]] &, $smallTrees]],
  True,
  TestID -> "shape-ordered-count"
];

TestCreate[
  sameEitherWay[Map[Join[
    XMLCases[#, Child[dv, {___, para, ___, c : li, ___}] :> Lookup[c[[2]], "id"]],
    XMLCases[#, Descendant[any, {___, Child[dv, spn], ___, c : XMLPattern["p", "classList" -> "a" | "b"], ___}] :> {c[[1]], c[[2]]}],
    XMLCases[#, Child[any, {para, ___, c : any, li, ___}] :> Lookup[c[[2]], "id"]]] &, $smallTrees]],
  True,
  TestID -> "shape-ordered-named-entry-in-body"
];

TestCreate[
  sameEitherWay[Map[XMLCases[#,
    Child[any, {___, para, ___, c : XMLPattern[_, {"class" -> k_, "id" -> i_}] /; StringLength[k] < StringLength[i] + 2, ___}] :> Lookup[c[[2]], "id"]] &, $smallTrees]],
  True,
  TestID -> "shape-ordered-two-step-match"
];

TestCreate[
  sameEitherWay[Map[Join[
    XMLCases[#, Child[XMLDocument[], {___, para, ___, c : XMLPattern["div" | "li"], ___}] :> Lookup[c[[2]], "id"]],
    XMLCases[#, Child[XMLDocument[], {___, Child[dv, spn], ___, any, ___}], 2],
    {XMLFirstCase[#, Child[XMLDocument[], {___, li, li, ___}], None]},
    {deleted[#, Child[XMLDocument[], {___, para, ___, li}]]}] &, $smallLists]],
  True,
  TestID -> "shape-ordered-below-document"
];

(* A reading added by the option, in an element-pattern entry, a context
   combinator entry and the selected entry. *)
TestCreate[
  sameEitherWay[Map[XMLCases[# /. ("class" -> v_) :> ("rel" -> v),
    Descendant[any, {___, XMLPattern[_, "relList" -> "a"], ___, Child[dv, XMLPattern[_, "relList" -> "b"]], ___, XMLPattern["li" | "p", "relList" -> "c"], ___}],
    "AttributeReadings" -> <|"rel" -> <||>|>] &, $smallTrees]],
  True,
  TestID -> "shape-ordered-attribute-readings"
];

(* The CSS selectors whose translations are ordered entries, positions moved
   along a + or ~ run (ADR 0017), mean their translations, with recognition on
   and off. *)
$orderedSelectors = {"li:first-child + p", "p + li:last-child", "li:first-child ~ p", "p ~ li:last-child",
  "li + li + li:first-child", "p:nth-child(2) + li"};

TestCreate[
  sameEitherWay[Map[Function[css, With[{r = XMLCases[#, css] & /@ $smallTrees},
      If[r === (XMLCases[#, FromCSSSelector[css]] & /@ $smallTrees), r, $Failed]]],
    $orderedSelectors]],
  True,
  TestID -> "shape-ordered-css-means-translation"
];

(* Just outside the shape, by a name on a context entry or inside a context
   combinator entry, a Condition on the list, __ as a gap, or a position among
   all children before the entries: the same results as a recognised spelling
   of the same meaning, which select something on some tree. *)
TestCreate[
  With[{r = Map[Function[t, {
    XMLCases[t, Child[any, {___, x : para, ___, li, ___}]],
    XMLCases[t, Child[any, {___, para, ___, li, ___} /; True]],
    XMLCases[t, Child[any, {___, para, __, li, ___}]],
    XMLCases[t, Child[any, {PatternSequence[_, _]..., ___, para, ___, li, ___}]],
    XMLCases[t, Child[any, {___, Child[x : dv, spn], ___, li, ___}]]}], $smallTrees]},
    r === Map[Function[t, {
    XMLCases[t, Child[any, {___, para, ___, li, ___}]],
    XMLCases[t, Child[any, {___, para, ___, li, ___}]],
    XMLCases[t, Child[any, {___, para, _, ___, li, ___}]],
    XMLCases[t, Child[any, {___, para, ___, li, ___}]],
    XMLCases[t, Child[any, {___, Child[dv, spn], ___, li, ___}]]}], $smallTrees] &&
      AllTrue[Transpose[r], !FreeQ[#, _XMLElement] &]],
  True,
  TestID -> "shape-ordered-unrecognised-still-correct"
];

(* === Shape 7: split conditions, {g___, b1, ..., C, h___} /; test ===

   A Condition on the list over measures of the runs of children its names
   stand for: Count, Length and MatchQ. The translator writes it for the
   counted positions it cannot write with plain entries. WL's matcher tests
   the Condition once per child that C matches, so these use the full trees. *)

(* The selectors that translate to shape 7 (FromCSSSelector gives a Condition
   on a list for each, css-split-forms), each with its mirror from the end:
   typeless -of-type, two positions on one side, a counted position in a +
   or ~ run, and one on a compound before the last of its run. *)
$splitSelectors = {".a:nth-of-type(2)", ".a:nth-last-of-type(2)", ":nth-of-type(2)", ":nth-last-of-type(2)",
  "*:first-of-type", "*:last-of-type", "*:only-of-type", ":nth-of-type(2n+1)", ":nth-last-of-type(-n+2)",
  ":nth-child(1 of .a):nth-child(2)", ":nth-last-child(1 of .a):nth-last-child(2)",
  "p:nth-of-type(2):nth-child(3)", "p:nth-last-of-type(2):nth-last-child(3)",
  "p + li:nth-of-type(2)", "p + li:nth-last-of-type(2)", "p ~ li:nth-child(3)", "p ~ li:nth-last-of-type(2)",
  "li:nth-of-type(2) + p", "li:nth-last-of-type(2) + p", ".a:nth-of-type(2) + p", ".a:nth-last-of-type(2) + p",
  "p + span + li:nth-of-type(2)", "p + span + li:nth-last-of-type(2)", "p ~ span + li:nth-child(3)",
  "p + li:nth-child(2 of .a)", "p + li:nth-last-child(2 of .a)", "li:nth-of-type(2) + p + span"};

TestCreate[
  MatchQ[FromCSSSelector[#], Child[Verbatim[XMLDocument[] | XMLPattern[_]], _Condition]] & /@ $splitSelectors,
  ConstantArray[True, Length[$splitSelectors]],
  TestID -> "css-split-forms"
];

(* Each selector selects something on some tree, and the same with
   recognition on and off. *)
TestCreate[
  With[{r = Map[Function[css, XMLCases[#, css] & /@ $trees], $splitSelectors]},
    AllTrue[r, !FreeQ[#, _XMLElement] &] && r === unrecognised[Map[Function[css, XMLCases[#, css] & /@ $trees], $splitSelectors]]],
  True,
  TestID -> "shape-split-css-cases"
];

TestCreate[
  sameEitherWay[Map[Function[t, XMLFirstCase[t, #, None] & /@ $splitSelectors], $trees]],
  True,
  TestID -> "shape-split-first-case"
];

TestCreate[
  sameEitherWay[Map[Function[t, deleted[t, #] & /@ $splitSelectors], $trees]],
  True,
  TestID -> "shape-split-delete-cases"
];

TestCreate[
  sameEitherWay[Map[Function[t, Join @@ (Join[XMLCases[t, #, 1], XMLCases[t, #, 3]] & /@ $splitSelectors)], $trees]],
  True,
  TestID -> "shape-split-count"
];

(* Written by hand: other comparisons and logic, an unnamed run, a named and
   an unnamed entry before the selected one, a run of names over the
   selected entry, the tag of an entry before it, and ordered entries in
   MatchQ, anchored at either end. *)
$splitLists = {
  {g___, c : li, h___} /; Count[{g}, XMLElement[First[c], _, _]] + 1 == 2,
  {g___, c : any, ___} /; Length[{g}] >= 2 && Count[{g}, XMLElement["p", _, _]] < 3,
  {___, c : XMLPattern["p" | "li"], h___} /; Mod[Length[{h}], 3] == 1 || MatchQ[{h}, {XMLElement["span", _, _], ___}],
  {g___, x : para, c : li, h___} /; Count[{x, c, h}, XMLElement["p", _, _]] == 1 && !MatchQ[{g}, {___, XMLElement["div", _, _], ___}],
  {g___, any, c : li, h___} /; Count[{g}, XMLElement[First[c], _, _]] == Count[{h}, XMLElement[First[c], _, _]],
  {g___, b : any, c : any, h___} /; Count[{b, c, h}, XMLElement[First[b], _, _]] >= 2 && Count[{g, b}, _?(XMLMatchQ[XMLPattern[_, "classList" -> "a"]])] == 1,
  {g___, c : XMLPattern[_, "classList" -> "a" | "b"], h___} /; MatchQ[{g}, {XMLElement["p", _, _], ___, XMLElement["li", _, _], _}] || MatchQ[{c, h}, {___, XMLElement["div", _, _]}],
  {g___, c : li, h___} /; True};

TestCreate[
  sameEitherWay[Map[Function[t, Join @@ Table[Join[
      XMLCases[t, Child[any, l]],
      XMLCases[t, Descendant[dv, l]],
      {XMLFirstCase[t, Child[any, l], None]},
      XMLCases[t, Child[any, l], 2]],
    {l, $splitLists}]], $trees]],
  True,
  TestID -> "shape-split-hand-written"
];

TestCreate[
  sameEitherWay[Map[Function[t, Join @@ Table[Join[
      XMLCases[t, Child[any, l] :> Lookup[c[[2]], "id"]],
      XMLCases[t, Child[XMLPattern["div"], l] :> {c[[1]], c[[2]]}]],
    {l, $splitLists}]], $trees]],
  True,
  TestID -> "shape-split-named-entry-in-body"
];

(* A list that needs the two-step match: the selected entry names two
   attribute values, with or without a Condition that sees the later one, or
   has overlapping keys. The test seeing one of the entry's attribute values,
   k == "a", is outside the shape. The general matcher is the reference here,
   checked against WL alone in ListStages.wlt. *)
twoValues = XMLPattern[_, {"class" -> k_, "id" -> i_}];
$twoStepSplitLists = {
  {g___, c : twoValues /; StringLength[k] < StringLength[i] + 2, ___} /; Length[{g}] == 1,
  {g___, c : twoValues, h___} /; Count[{g}, XMLElement[First[c], _, _]] + 1 == 2,
  {g___, c : twoValues, h___} /; Length[{h}] < Length[{g}] && MatchQ[{g}, {___, XMLElement["p", _, _]}],
  {g___, c : twoValues, ___} /; Length[{g}] == 1 && k == "a",
  {g___, c : XMLPattern[_, {("class" | "id") -> _, "id" -> i_}], h___} /; Mod[Length[{h}], 2] == 1};

TestCreate[
  sameEitherWay[Map[Function[t, Join @@ Table[Join[
      XMLCases[t, Child[any, l] :> {i, Lookup[c[[2]], "id"]}],
      {XMLFirstCase[t, Child[any, l], None]},
      {deleted[t, Child[any, l]]},
      XMLCases[t, Child[any, l], 2],
      XMLCases[t, Child[any, l], "AttributeReadings" -> <|"rel" -> <||>|>]],
    {l, $twoStepSplitLists}]], $smallTrees]],
  True,
  TestID -> "shape-split-two-step-match"
];

TestCreate[
  sameEitherWay[Map[Join[
    XMLCases[#, Child[XMLDocument[], {g___, c : XMLPattern["div" | "p"], h___} /; Count[{h}, XMLElement[First[c], _, _]] + 1 == 2] :> Lookup[c[[2]], "id"]],
    Join @@ Function[css, XMLCases[#, css]] /@ $splitSelectors,
    {XMLFirstCase[#, "*:last-of-type", None]}, {deleted[#, ".a:nth-of-type(2)"]}] &, $lists]],
  True,
  TestID -> "shape-split-below-document"
];

(* A reading added by the option, in the selected entry and in a test inside
   the Condition, which sees the original elements, and the selectors with
   the option given. *)
TestCreate[
  sameEitherWay[Map[Join[
    XMLCases[# /. ("class" -> v_) :> ("rel" -> v),
      Descendant[any, {g___, c : XMLPattern["li" | "p", "relList" -> "a"], h___} /;
        Count[{g}, XMLElement[First[c], _, _]] + 1 == 2 || Count[{h}, _?(XMLMatchQ[XMLPattern[_, "relList" -> "b"]])] == 1],
      "AttributeReadings" -> <|"rel" -> <||>|>],
    Join @@ Function[css, XMLCases[#, css, "AttributeReadings" -> <|"rel" -> <||>|>]] /@ $splitSelectors] &, $trees]],
  True,
  TestID -> "shape-split-attribute-readings"
];

(* Laws: .x:nth-of-type(k) is .x among the union over the tags T of
   T:nth-of-type(k), on lists of the random trees' tags, and
   *:first-of-type is *:nth-of-type(1), and the same from the end. *)
TestCreate[
  AllTrue[$siblings, Function[t,
    AllTrue[Range[4], Function[k, With[{n = ToString[k]},
      ids[XMLCases[t, "ol > .a:nth-of-type(" <> n <> ")"]] ===
        ids[Intersection[XMLCases[t, "ol > .a"], Join @@ (XMLCases[t, "ol > " <> # <> ":nth-of-type(" <> n <> ")"] & /@ $randomTags)]] &&
      ids[XMLCases[t, "ol > .a:nth-last-of-type(" <> n <> ")"]] ===
        ids[Intersection[XMLCases[t, "ol > .a"], Join @@ (XMLCases[t, "ol > " <> # <> ":nth-last-of-type(" <> n <> ")"] & /@ $randomTags)]]]]] &&
    ids[XMLCases[t, "ol > *:first-of-type"]] === ids[XMLCases[t, "ol > *:nth-of-type(1)"]] &&
    ids[XMLCases[t, "ol > *:last-of-type"]] === ids[XMLCases[t, "ol > *:nth-last-of-type(1)"]]]],
  True,
  TestID -> "shape-split-laws"
];

(* Just outside the shape, so on the general matcher: a run's name used in a
   rule body, a test that is not arithmetic, a counted pattern that binds a
   name, a name seen by the selected entry, a name twice, an entry apart from
   the selected one, and __ as a run. The same results either way, and the
   same as a recognised spelling of the same meaning, where there is one. *)
TestCreate[
  With[{outside = Function[t, {
      XMLCases[t, Child[any, {g___, c : li, ___} /; Length[{g}] < 3] :> Length[{g}]],
      XMLCases[t, Child[any, {g___, c : li, ___} /; EvenQ[Length[{g}]]]],
      XMLCases[t, Child[any, {g___, c : li, ___} /; Count[{g}, x : XMLElement["li", _, _]] == 1]],
      XMLCases[t, Child[any, {g___, c : li /; Length[{g}] > 1, h___} /; Length[{h}] < 4]],
      XMLCases[t, Child[any, {g___, c : li, g___} /; Length[{g}] < 3]],
      XMLCases[t, Child[any, {g___, para, ___, c : li, ___} /; Length[{g}] == 1]],
      XMLCases[t, Child[any, {g__, c : li, ___} /; Length[{g}] == 2]]}],
    inside = Function[t, {
      XMLCases[t, Child[any, {g___, c : li, ___} /; Mod[Length[{g}], 2] == 0]],
      XMLCases[t, Child[any, {g___, c : li, ___} /; Count[{g}, XMLElement["li", _, _]] == 1]],
      XMLCases[t, Child[any, {g___, c : li, ___} /; Length[{g}] == 2]]}]},
    With[{r = Map[outside, $trees]},
      r === unrecognised[Map[outside, $trees]] && r[[All, {2, 3, 7}]] === Map[inside, $trees] &&
        AllTrue[Transpose[r][[{1, 2, 3, 6, 7}]], !FreeQ[#, _XMLElement | _Integer] &]]],
  True,
  TestID -> "shape-split-unrecognised-still-correct"
];

(* === Rule bodies over a recognised shape ===

   In a recognised shape only the selected entry can be named (in shape 7,
   other names are seen only by the list's own Condition), so a rule body,
   a Condition in it and a Condition on the combinator see the selected child
   and the other stages, and are evaluated from them, not by matching the list
   again. Shapes 4 to 6 are slow on WL's matcher, so these use the trees with
   each list of children cut to its first 12. *)

idOf[e_] := Lookup[e[[2]], "id"];
oddIdQ[e_] := OddQ[ToExpression[idOf[e]]];

(* The list with its selected entry c : x made c : f[x]. *)
selectedAs[l_, f_] := l /. Verbatim[Pattern][c, x_] :> With[{y = f[x]}, c : y];

(* One spelling of each shape, the selected entry named c. *)
$namedShapes = {
  {___, c : li, ___},                                                 (* 1 *)
  {_, PatternSequence[_, _]..., c : li, ___},                         (* 2 *)
  {___, c : li, _},                                                   (* 3 *)
  {Except[li]..., PatternSequence[li, Except[li]...], c : li, ___},   (* 4 *)
  {___, c : any, PatternSequence[Except[para]..., para], Except[para]...}, (* 5 *)
  {___, para, ___, c : li, ___},                                      (* 6 *)
  {___, Child[dv, spn], ___, c : any, ___},                           (* 6, a context combinator entry *)
  {g___, c : li, h___} /; Count[{g}, XMLElement[First[c], _, _]] + 1 == 2 || Length[{h}] == 1,  (* 7 *)
  {g___, x : para, c : any, h___} /; Count[{x, h}, XMLElement["p", _, _]] <= 2 && !MatchQ[{g}, {___, XMLElement["div", _, _], ___}]}; (* 7, an entry before *)

TestCreate[
  sameEitherWay[Map[Function[t, Join @@ Table[Join[
      XMLCases[t, Child[any, l] :> idOf[c]],
      XMLCases[t, Child[any, l] :> idOf[c] /; oddIdQ[c]],
      XMLCases[t, Child[any, l] :> idOf[c], 2],
      XMLCases[t, Child[any, l] :> idOf[c] /; oddIdQ[c], 1],
      {XMLFirstCase[t, Child[any, l] :> idOf[c], None]},
      {XMLFirstCase[t, Child[any, l] :> idOf[c] /; oddIdQ[c], None]}],
    {l, $namedShapes}]], $smallTrees]],
  True,
  TestID -> "shape-body-named-entry"
];

(* A rule body and a Condition in it that see the names of other stages, the
   parent's and a later stage's, and a Condition on the combinator that spans
   the list stage, with and without a body. *)
TestCreate[
  sameEitherWay[Map[Function[t, Join @@ Table[Join[
      XMLCases[t, Child[p : any, l] :> {idOf[p], idOf[c]}],
      XMLCases[t, Child[p : any, l] :> {idOf[p], idOf[c]} /; oddIdQ[p] =!= oddIdQ[c]],
      XMLCases[t, Child[Child[any, l], d : any] :> {idOf[c], idOf[d]} /; oddIdQ[d]],
      XMLCases[t, Child[p : any, l] /; oddIdQ[p] === oddIdQ[c]],
      XMLCases[t, (Child[p : any, l] /; oddIdQ[p] === oddIdQ[c]) :> idOf[c]]],
    {l, $namedShapes}]], $smallTrees]],
  True,
  TestID -> "shape-body-other-stages"
];

(* A body Condition takes part in choosing an ancestor (ADR 0014), in
   XMLFirstCase as in XMLCases, and a name at two stages is one value. *)
TestCreate[
  sameEitherWay[Map[Function[t, Join @@ Table[Join[
      XMLCases[t, Descendant[d : dv, l] :> {idOf[d], idOf[c]} /; oddIdQ[d]],
      {XMLFirstCase[t, Descendant[d : dv, l] :> {idOf[d], idOf[c]} /; oddIdQ[d] && !oddIdQ[c], None]},
      XMLCases[t, Child[XMLPattern[_, "class" -> k_], selectedAs[l, XMLPattern[#[[1]], "class" -> k_] &]] :> {k, idOf[c]}]],
    {l, $namedShapes}]], $smallTrees]],
  True,
  TestID -> "shape-body-chooses"
];

(* Alternatives of chains, a name bound only in the other alternative being
   Sequence[], below the document, the two-step match, and a reading added by
   the option. *)
TestCreate[
  sameEitherWay[Join[
    Map[Function[t, Join @@ Table[Join[
        XMLCases[t, Child[dv, l] | Child[XMLPattern["p"], {e : any, ___}] :> {c, e}],
        {XMLFirstCase[t, Child[dv, l] | Child[para, {e : any, ___}] :> {c, idOf[e]} /; oddIdQ[e], None]},
        XMLCases[t, Child[any, selectedAs[l, XMLPattern[_, {"class" -> k_, "id" -> i_}] /; StringLength[k] < StringLength[i] + 2 &]] :> idOf[c]],
        XMLCases[t /. ("class" -> v_) :> ("rel" -> v), Child[any, l /. li -> XMLPattern["li" | "p", "relList" -> "a"]] :> {c[[1]], c[[2]]} /; oddIdQ[c],
          "AttributeReadings" -> <|"rel" -> <||>|>]],
      {l, $namedShapes}]], $smallTrees],
    Map[Function[t, Join @@ Table[Join[
        XMLCases[t, Child[XMLDocument[], l] :> idOf[c] /; oddIdQ[c]],
        {XMLFirstCase[t, Child[XMLDocument[], l] :> idOf[c], None]}],
      {l, $namedShapes}]], $smallLists]]],
  True,
  TestID -> "shape-body-alternatives-document-two-step-readings"
];

(* A selected entry of named alternatives: the name bound only in the
   alternative that did not match is Sequence[] (ADR 0015). *)
TestCreate[
  sameEitherWay[Map[Function[t, Join @@ Table[Join[
      XMLCases[t, Child[any, l] :> {Length[{c}], Length[{d}]}],
      XMLCases[t, Child[any, l] :> {c, d} /; Length[{d}] == 1],
      {XMLFirstCase[t, Descendant[x : dv, l] :> {idOf[x], c, d} /; Length[{d}] == 1, None]}],
    {l, Take[$namedShapes, 6] /. Verbatim[Pattern][c, x_] :> (c : x) | (d : para)}]], $smallTrees]],
  True,
  TestID -> "shape-body-selected-alternatives"
];
