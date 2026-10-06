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
