(* ::Package:: *)
(* HTMLPatterns: the columnar query engine *)

(* Used by Query/TreePatterns.wl: compileQuery records whether this engine
   covers a query, and runQuery runs it there *)
PackageScoped[columnarCoverage]
PackageScoped[columnarResults]
PackageScoped[$columnarFallback]

(* =========================================================== *)
(* The columnar engine (ADR 0023, 0024, 0025)                   *)
(*                                                              *)
(* It reads the compiled query (compileQuery) and the index as  *)
(* the solutions engine does, but matches each node of the      *)
(* query at every element at once, by operations on columns of  *)
(* integers, never element by element.                          *)
(*                                                              *)
(* The solutions of a node are a solution table: an Association *)
(* of columns, each a packed vector of integers with one entry  *)
(* a row. "Root" is the node the pattern root matched at; each  *)
(* name the node keeps ("Keep"), and each Alternatives slot, has *)
(* a column of place codes. A place code is one integer for a   *)
(* place on an element:                                         *)
(*   id K + s                                                   *)
(* for the node numbered id in preorder (0 the document), with  *)
(* K the most attributes of any element plus 3, and s 0 for the *)
(* element itself, 1 its tag, 2 its attribute map, 2 + j its    *)
(* j-th attribute's value. -1 is a name a row leaves unbound,   *)
(* in a branch of Alternatives that did not match.              *)
(*                                                              *)
(* Code order is position order (ADR 0025, Positions.wl): an    *)
(* element sorts before its tag, attribute map and attributes   *)
(* in order, and those before every element below it, which     *)
(* preorder numbers next. So distinct tuples of positions are   *)
(* distinct rows of integers, and result order is a sort of     *)
(* rows. Positions and values are made from codes only for the  *)
(* results.                                                     *)
(*                                                              *)
(* Every table is in solution order, the order the solutions    *)
(* engine finds solutions in: by its "Root", in document order, *)
(* and at one root as the parts below find them, the branches   *)
(* of an Alternatives in order. Results sort stably, so where   *)
(* two results tie, as two branches binding one place do, they  *)
(* keep that order.                                             *)
(*                                                              *)
(* A table is passed between operators as an Association of     *)
(* packed columns, which a function substitutes into its body   *)
(* at no cost; the rows and values a loop over results reads    *)
(* live in Block variables, never in arguments, as a scoping    *)
(* construct copies an unpacked list into its body at each call.*)
(* =========================================================== *)

(* ---- Coverage ----

   While both engines exist, a query runs here only if every node of it is
   one this engine matches: element pattern roots, their tags and
   attributes, names on elements and on places of one element, Descendant,
   Child, Alternatives, Condition and PatternTest, and XMLDocument. It is
   decided from the compiled query alone, when it is compiled. *)

(* "Columnar", or why the engine does not run compiled query cq. *)
columnarCoverage[cq_Association] :=
  Which[
    cq["Records"], "an Except refers to a name bound outside it",
    cq["NamedPaths"], "a named path",
    True, Replace[DeleteDuplicates[uncovered[cq["Root"]]], {{} -> "Columnar", r_ :> StringRiffle[r, ", "]}]];

(* Why a node, or a node below it, is not covered: the empty list when it
   is. *)
uncovered[nd_] :=
  Switch[nd["Kind"],
    "XMLPattern", Join[headUncovered[nd], constraintsUncovered[nd["Constraints"], nd["HeadNames"]]],
    "XMLDocument", constraintsUncovered[nd["Constraints"], {}],
    "Named", If[MemberQ[nd["Sub"]["Names"], nd["Name"]], {"a name compared by value"}, uncovered[nd["Sub"]]],
    "Cond" | "Test", uncovered[nd["Sub"]],
    "Alt" | "ConstraintAlt", Join @@ (uncovered /@ nd["Subs"]),
    "Literal" | "Blank", {},
    "Descendant", If[nd["Key"] =!= None, {"a path"}, uncovered[nd["Sub"]]],
    "List", If[childListQ[nd], uncovered[childEntry[nd]], {"a list constraint"}],
    _, {nd["Kind"]}];

(* A list constraint that is Child[p], as compiled: {___, p, ___}. *)
childListQ[c_] :=
  MatchQ[#["Kind"] & /@ c["Items"], {"Any", "One", "Any"}] && c["Items"][[1]]["Min"] == 0 && c["Items"][[3]]["Min"] == 0;

(* The pattern root of the one entry of Child[p]. *)
childEntry[c_] := c["Items"][[2]]["Sub"];

(* Each name an element's tag and attributes bind must have a place of its
   own: the whole tag, the whole attribute map, or one attribute's whole
   value, on a literal key that is not a list key. *)
headUncovered[nd_] :=
  With[{need = nd["HeadNames"]},
    If[need === {} || headPlaces[nd] =!= None, {}, {"a name in a tag or attributes without a place of its own"}]];

(* {{"Tag" | All | key, name}, ...} for the needed names of an XMLPattern's
   tag and attributes, or None when one has no place of its own, or two
   names one place, or one name two. *)
headPlaces[nd_] :=
  With[{need = nd["HeadNames"], tag = tagPlaces[nd["Tag"], nd["HeadNames"]], attrs = attrPlaces[nd["Attrs"], nd["HeadNames"]]},
    If[tag === None || attrs === None, None,
      With[{places = Join[tag, attrs]}, If[DuplicateFreeQ[places[[All, 2]]] && Sort[places[[All, 2]]] === Sort[need], places, None]]]];

tagPlaces[t_, need_] :=
  Replace[Intersection[namesIn[Hold[t]], need], {
    {} -> {},
    {n_} /; wholeName[t] === n :> {{"Tag", n}},
    _ -> None}];

(* The name a pattern binds to the whole value it matches, through tests
   and Conditions on it, when it binds no other; else None. *)
wholeName[(Verbatim[PatternTest] | Verbatim[Condition])[p_, _]] := wholeName[p];
wholeName[Verbatim[Pattern][s_Symbol, p_]] := If[FreeQ[Hold[p], Verbatim[Pattern]], Hold[s], None];
wholeName[_] := None;

attrPlaces[Verbatim[Pattern][s_Symbol, a_], need_] :=
  With[{inner = attrPlaces[a, need]},
    If[inner === None, None, If[MemberQ[need, Hold[s]], Prepend[inner, {All, Hold[s]}], inner]]];
attrPlaces[Verbatim[PatternTest][a_, _], need_] := attrPlaces[a, need];
attrPlaces[r_Rule, need_] := attrPlaces[{r}, need];
attrPlaces[rules_List, need_] :=
  With[{named = Select[rules, IntersectingQ[namesIn[Hold[#]], need] &]},
    If[FreeQ[rules, Verbatim[Rule][_Alternatives, _]] &&
        AllTrue[named, MatchQ[#, Verbatim[Rule][k_String, v_] /; !KeyExistsQ[$readings, k] && wholeName[v] =!= None] &],
      Cases[named, Verbatim[Rule][k_, v_] :> {k, wholeName[v]}],
      None]];
attrPlaces[a_, need_] := If[IntersectingQ[namesIn[Hold[a]], need], None, {}];

(* The constraints of one element are joined on it, and a name two of them
   bind names one place, compared by position (ADR 0023, joinedAcross),
   which only elements have here; a name bound to a tag or attribute in
   either, or in the element's own tag and attributes, would be compared
   by value. *)
constraintsUncovered[cons_, headNames_] :=
  With[{keeps = #["Keep"] & /@ cons, strings = stringNames /@ cons},
    Join[
      Join @@ (uncovered /@ cons),
      If[IntersectingQ[headNames, Union @@ Prepend[keeps, {}]] ||
          AnyTrue[Subsets[Range[Length[cons]], {2}],
            IntersectingQ[Intersection @@ keeps[[#]], Union @@ strings[[#]]] &],
        {"a name compared by value"}, {}]]];

(* The names bound below a node to a tag or an attribute. *)
stringNames[nd_] :=
  Union[If[nd["Kind"] === "XMLPattern", nd["HeadNames"], {}], Union @@ Prepend[stringNames /@ subNodes[nd], {}]];

(* ---- Tables ---- *)

packed[l_] := Developer`ToPackedArray[l, Integer];

rowCount[t_] := Length[t["Root"]];
takeRows[t_, idx_] := packed[#[[idx]]] & /@ t;
pickRows[t_, mask_] := packed[Pick[#, mask, 1]] & /@ t;
emptyTable[cols_] := AssociationThread[Prepend[cols, "Root"], ConstantArray[packed[{}], Length[cols] + 1]];

(* The table with exactly the columns cols after "Root", a missing one
   unbound. *)
aligned[t_, cols_] :=
  Join[<|"Root" -> t["Root"]|>, AssociationThread[cols, Lookup[t, cols, ConstantArray[-1, rowCount[t]]]]];

(* The table's rows in order of their roots, rows at one root in the order
   they were. *)
sortedByRoot[t_] := If[OrderedQ[t["Root"]], t, takeRows[t, Ordering[t["Root"]]]];

(* The distinct rows, the first of each kept; with rootQ False the roots are
   not read above, and set to 0. *)
distinctRows[t_, rootQ_] :=
  With[{u = If[rootQ, t, Append[t, "Root" -> ConstantArray[0, rowCount[t]]]]},
    Which[
      rowCount[u] <= 1, u,
      Length[u] == 1, <|"Root" -> packed[DeleteDuplicates[u["Root"]]]|>,
      True, AssociationThread[Keys[u], packed /@ Transpose[DeleteDuplicates[Transpose[Values[u]]]]]]];

(* The rows of tables ts, one after the other, on columns cols, in order of
   their roots: at one root the rows of the first table first. *)
unionTables[ts_, cols_] := sortedByRoot @ Merge[aligned[#, cols] & /@ ts, packed @* Catenate];

(* At x + 1, how many of the node ids vs are at most x, over the nodes. *)
countsUpTo[vs_] :=
  Module[{c = ConstantArray[0, Length[$elem]]},
    With[{t = Tally[vs]}, If[t =!= {}, c[[t[[All, 1]] + 1]] = t[[All, 2]]]];
    Accumulate[c]];

(* Each i of is, lens[[i]] times. *)
repeated[is_, lens_] := packed @ Flatten @ MapThread[ConstantArray, {is, lens}];

(* The rows of b, sorted by root, whose root is in [lo, hi], for each pair:
   {the index of the pair, the index into b} for each. *)
rangeJoin[b_, lo_, hi_] :=
  With[{cum = Prepend[countsUpTo[b["Root"]], 0]},
    With[{firsts = cum[[lo + 1]] + 1, lasts = cum[[hi + 2]]},
      {repeated[Range[Length[lo]], Clip[lasts - firsts + 1, {0, Infinity}]], packed @ Flatten[MapThread[Range, {firsts, lasts}]]}]];

(* The natural join of a and b on the root and the names both bind, each
   row of a with the rows of b at its root in their order. A name one row
   leaves unbound takes the other's. *)
joinTables[a_, b0_] :=
  Module[{b = sortedByRoot[b0], ia, ib, shared, out, ok},
    {ia, ib} = rangeJoin[b, a["Root"], a["Root"]];
    shared = Intersection[Rest[Keys[a]], Rest[Keys[b]]];
    out = Join[takeRows[a, ia], takeRows[KeyDrop[b, Prepend[shared, "Root"]], ib]];
    If[shared === {}, out,
      ok = Times @@ (With[{x = a[#][[ia]], y = b[#][[ib]]}, 1 - Unitize[x - y] Unitize[x + 1] Unitize[y + 1]] & /@ shared);
      Scan[(out[#] = With[{x = a[#][[ia]], y = b[#][[ib]]}, x + (y - x) (1 - Unitize[x + 1])]) &, shared];
      pickRows[out, ok]]];

(* A 0/1 vector over the nodes, 1 at ids. *)
idMarks[ids_] := Module[{m = ConstantArray[0, Length[$elem]]}, m[[ids + 1]] = 1; m];

(* The ids that allowed, All or marks over the nodes, allows. *)
restricted[ids_, All] := ids;
restricted[ids_, marks_] := Pick[ids, marks[[ids + 1]], 1];

(* Marks over the nodes strictly below some node of ps, a difference array
   over the subtrees, so nested ps cost nothing. *)
belowMarks[ps_] :=
  Module[{d = ConstantArray[0, Length[$elem] + 1]},
    With[{t = Tally[ps + 2]}, d[[t[[All, 1]]]] += t[[All, 2]]];
    With[{t = Tally[$end[[ps + 1]] + 2]}, d[[t[[All, 1]]]] -= t[[All, 2]]];
    Unitize[Most[Accumulate[d]]]];

(* Marks over the nodes whose parent is among ps. *)
childMarks[ps_] := With[{m = idMarks[ps]}, Prepend[m[[Rest[$parent] + 1]], 0]];

(* ---- Place codes ---- *)

(* K, kept with the index: a page's elements do not change between
   queries. *)
placeBase[] := Lookup[$vectors, Key[{"PlaceBase"}], $vectors[{"PlaceBase"}] = Max[0, Length /@ $elem[[2 ;;, 2]]] + 3];

codePosition[c_] :=
  With[{i = Quotient[c, $K], s = Mod[c, $K]},
    Switch[s, 0, posOf[i], 1, Append[posOf[i], 0], 2, Append[posOf[i], Key[All]], _, Append[posOf[i], Key[elemOf[i][[2, s - 2, 1]]]]]];

codeValue[c_] :=
  With[{i = Quotient[c, $K], s = Mod[c, $K]},
    Switch[s, 0, elemOf[i], 1, elemOf[i][[1]], 2, elemOf[i][[2]], _, elemOf[i][[2, s - 2, 2]]]];

(* The values of codes, all at once. *)
codeValues[{}] := {};
codeValues[codes_] :=
  With[{ids = Quotient[codes, $K] + 1, ss = Mod[codes, $K]},
    If[Max[ss] == 0, $elem[[ids]],
      Extract[$elem, MapThread[Switch[#2, 0, {#1}, 1, {#1, 1}, 2, {#1, 2}, _, {#1, 2, #2 - 2, 2}] &, {ids, ss}]]]];

(* A name's match as resultOf reads it: its one position and its value. *)
codeMatch[c_] := nameMatch[{codePosition[c]}, codeValue[c], {}];

(* ---- Matching a pattern root ----

   tab[nd, allowed, rootQ]: the table of a pattern root node at the nodes
   allowed (All, or marks over the nodes), on the node's Keep. Its roots
   are read above only when rootQ. *)

tab[nd_, allowed_, rootQ_] := tabKind[nd["Kind"], nd, allowed, rootQ];

(* The candidates of a pattern root, its vector's ids (candidateVector),
   kept with the index. *)
candidateIds[nd_] := Last[candidateCounts[nd]];

tabKind["XMLPattern", nd_, allowed_, rootQ_] := treeTable[nd, restricted[candidateIds[nd], allowed], rootQ];

tabKind["XMLDocument", nd_, allowed_, rootQ_] :=
  treeTable[nd, If[Length[childrenOf[0]] >= nd["MinKids"], restricted[{0}, allowed], {}], rootQ];

(* An element's tag and attributes, then its constraints: those that keep
   no name filter the candidates, then those that do are joined on the
   element. With one that keeps names, a Descendant at any depth, and the
   element not read above, the rows are those of its pattern below some
   candidate, and no pair of element and match is made. *)
treeTable[nd_, cands_, rootQ_] :=
  Module[{p = cands, named, plain, t},
    {named, plain} = {Select[#, #["Keep"] =!= {} &], Select[#, #["Keep"] === {} &]} &[nd["Constraints"]];
    Do[If[p =!= {}, p = holding[c, p, nd["Kind"] === "XMLPattern"]], {c, plain}];
    t = Join[<|"Root" -> packed[p]|>, headColumns[nd, p]];
    Which[
      named === {}, t,
      p === {}, emptyTable[nd["Keep"]],
      !rootQ && Length[named] == 1 && Lookup[nd, "HeadNames", {}] === {} && coverableQ[First[named]], covered[First[named], p],
      True, distinctRows[Fold[If[rowCount[#1] == 0, #1, joinTables[#1, constraintTable[#2, DeleteDuplicates[#1["Root"]]]]] &, t, named], rootQ]]];

(* The columns of the names in the tag and attributes, at elements ps. *)
headColumns[nd_, ps_] /; Lookup[nd, "HeadNames", {}] === {} := <||>;
headColumns[nd_, ps_] := Association[#[[2]] -> headCodes[ps, #[[1]]] & /@ headPlaces[nd]];

headCodes[ps_, "Tag"] := $K ps + 1;
headCodes[ps_, All] := $K ps + 2;
(* The compiled test has passed only elements with the attribute. *)
headCodes[ps_, key_] :=
  Module[{js = ConstantArray[0, Length[ps]], hits},
    hits = DeleteDuplicatesBy[Position[$elem[[ps + 1, 2, All, 1]], key, {2}, Heads -> False], First];
    If[hits =!= {}, js[[hits[[All, 1]]]] = hits[[All, 2]]];
    If[MemberQ[js, 0], fallBack["an element without the attribute its pattern names"]];
    packed[$K ps + 2 + js]];

(* The candidates ps at which a constraint that keeps no name holds. When
   ps are an XMLPattern's candidates, filteredQ, its filter on them
   (constraintFilter) has decided a Descendant at any depth, or a Child,
   whose pattern's candidates are exactly its matches. *)
holding[c_, ps_, filteredQ_] :=
  Switch[c["Kind"],
    "Descendant",
      If[filteredQ && c["Levels"] === {1, Infinity} && c["Sub"]["Exact"], ps,
        With[{js = DeleteDuplicates @ tab[c["Sub"], belowMarks[ps], True]["Root"]},
          If[c["Levels"] === {1, Infinity},
            With[{cum = countsUpTo[js]}, Pick[ps, Unitize[cum[[$end[[ps + 1]] + 1]] - cum[[ps + 1]]], 1]],
            DeleteDuplicates @ descendantPairs[<|"Root" -> js|>, ps, c["Levels"]]["Root"]]]],
    "List",
      If[filteredQ && childEntry[c]["Exact"], ps,
        With[{kids = tab[childEntry[c], childMarks[ps], True]["Root"]}, restricted[ps, idMarks[$parent[[kids + 1]]]]]],
    "ConstraintAlt",
      restricted[ps, idMarks[Union @@ (holding[#, ps, False] & /@ c["Subs"])]]];

(* The table of a constraint that keeps names, at elements ps. *)
constraintTable[c_, ps_] :=
  projected[c["Keep"], True] @ Switch[c["Kind"],
    "Descendant", descendantPairs[tab[c["Sub"], belowMarks[ps], True], ps, c["Levels"]],
    "List", childTable[c, ps],
    "ConstraintAlt", unionTables[If[#["Keep"] === {}, <|"Root" -> packed[holding[#, ps, False]]|>, constraintTable[#, ps]] & /@ c["Subs"], c["Keep"]]];

(* The distinct rows of a table on the names keep, as a node keeps only
   what something above it needs: a slot of an Alternatives below a
   constraint is not kept above it. *)
projected[keep_, rootQ_][t_] := distinctRows[KeyTake[t, Prepend[keep, "Root"]], rootQ];

(* The rows of table s at each of its roots' ancestors among ps, at a depth
   below it in levels: for each of ps in order, the rows below it. *)
descendantPairs[s0_, ps_, {lo_, hi_}] :=
  Module[{s = sortedByRoot[s0], ip, is, t, d},
    {ip, is} = rangeJoin[s, ps + 1, $end[[ps + 1]]];
    t = Join[<|"Root" -> packed[ps[[ip]]]|>, takeRows[KeyDrop[s, "Root"], is]];
    If[{lo, hi} === {1, Infinity}, t,
      d = $depth[[s["Root"][[is]] + 1]] - $depth[[ps[[ip]] + 1]];
      pickRows[t, UnitStep[d - lo] If[hi === Infinity, 1, UnitStep[hi - d]]]]];

(* Child[p]: the rows of p at the children of ps, each at its parent. *)
childTable[c_, ps_] :=
  With[{s = tab[childEntry[c], childMarks[ps], True]},
    sortedByRoot @ Append[s, "Root" -> packed[$parent[[s["Root"] + 1]]]]];

coverableQ[c_] := c["Kind"] === "Descendant" && c["Levels"] === {1, Infinity};

(* The rows of the constraint's pattern below some candidate; their roots
   are not read. *)
covered[c_, ps_] := projected[c["Keep"], False] @ tab[c["Sub"], belowMarks[ps], True];

tabKind["Named", nd_, allowed_, rootQ_] :=
  With[{keepQ = MemberQ[nd["Keep"], nd["Name"]]},
    With[{s = tab[nd["Sub"], allowed, rootQ || keepQ]},
      If[keepQ, Append[s, nd["Name"] -> packed[$K s["Root"]]], s]]];

(* A PatternTest runs once for each distinct element. *)
tabKind["Test", nd_, allowed_, rootQ_] :=
  With[{s = tab[nd["Sub"], allowed, True]},
    With[{ok = Select[DeleteDuplicates[s["Root"]], TrueQ[nd["F"][elemOf[#]]] &]},
      pickRows[s, idMarks[ok][[s["Root"] + 1]]]]];

(* A Condition runs once for each distinct tuple of the names it sees, in
   no promised order, on all rows before any is taken. *)
tabKind["Cond", nd_, allowed_, rootQ_] :=
  With[{s = tab[nd["Sub"], allowed, rootQ], sees = nd["Sees"]},
    If[rowCount[s] == 0, emptyTable[nd["Keep"]],
      With[{seen = If[sees === {}, ConstantArray[{}, rowCount[s]], Transpose[Lookup[s, sees]]]},
        With[{passes = AssociationThread[#, conditionPasses[nd, sees, #]] &[DeleteDuplicates[seen]]},
          distinctRows[KeyTake[pickRows[s, Lookup[passes, seen]], Prepend[nd["Keep"], "Root"]], rootQ]]]]];

(* Whether each distinct tuple of the seen names passes the test, as 0 or
   1. With every name bound, the test is a function of their values,
   applied to columns of values; a name a tuple leaves unbound is
   Sequence[], as passesQ makes it. *)
conditionPasses[nd_, sees_, tuples_] :=
  If[sees =!= {} && FreeQ[tuples, -1],
    With[{f = Replace[{Join @@ sees, nd["Test"]}, {Hold[v___], Hold[b_]} :> Function[{v}, b]]},
      Boole[MapThread[TrueQ[f[##]] &, codeValues /@ Transpose[tuples]]]],
    Boole[passesQ[nd["Test"], sees, rowSolution[sees, #]]] & /@ tuples];

(* The branches of one Alternatives, the slot bound where it matched. *)
tabKind["Alt", nd_, allowed_, rootQ_] :=
  With[{slot = nd["Slot"]},
    With[{u = unionTables[tab[#, allowed, rootQ || slot =!= None] & /@ nd["Subs"], DeleteCases[nd["Keep"], slot]]},
      distinctRows[If[slot === None, u, Append[u, slot -> packed[$K u["Root"]]]], rootQ]]];

(* An XMLElement pattern that binds nothing needed, and a blank, are WL
   patterns on the whole element. *)
tabKind["Literal", nd_, allowed_, _] := elementsMatching[nd["Pattern"], allowed];
tabKind["Blank", nd_, allowed_, _] := elementsMatching[Blank @@ nd["Head"], allowed];

elementsMatching[p_, allowed_] :=
  With[{ids = restricted[Range[Length[$elem] - 1], allowed]},
    <|"Root" -> packed @ Pick[ids, MatchQ[#, p] & /@ $elem[[ids + 1]]]|>];

(* ---- Escape ----

   A covered query that meets, while matching, a case this engine does not
   handle throws the reason, before any right-hand side is evaluated, and
   the solutions engine runs it (engineResults, Query/TreePatterns.wl). *)

$columnarFallback = Unique["columnarFallback"];

fallBack[reason_] := Throw[reason, $columnarFallback];

(* ---- Results (ADR 0024) ---- *)

(* The results of compiled query cq, as the solutions engine's results gives
   them for the same mode, input and nodes. An element test gives the empty
   tuple if the pattern root matches anywhere. *)
columnarResults[mode_, cq_, bare_, n_, nodes_] :=
  Block[{$K = placeBase[], $t},
    $t = tab[cq["Root"], If[nodes === All, All, idMarks[nodes]], False];
    If[cq["Test"], If[n >= 1 && rowCount[$t] > 0, {{}}, {}], orderedResults[mode, cq, bare, n]]];

(* The results of the table $t. Its rows are visited in order of their slot
   keys, ties in row order; a tuple of counted codes is a group, which sorts
   by its first row. The bare input's own position, code K, is never
   counted. *)
orderedResults[mode_, cq_, bare_, n_] :=
  Block[{$cols, $data, $counted = cq["Counted"], $testRows},
    Module[{testNames = cq["TestNames"], rhs = cq["Rhs"], all = cq["Names"], slots, keyRows, groups, count = 0, k = 1, r},
      $t = aligned[$t, Union[Rest[Keys[$t]], $counted, testNames]];
      If[bare, $t = pickRows[$t, Times @@ Prepend[Unitize[$t[#] - $K] & /@ $counted, ConstantArray[1, rowCount[$t]]]]];
      If[rowCount[$t] == 0 || n < 1, Return[{}, Module]];
      If[directRowsQ[mode, rhs, all, testNames], Return[directResults[mode, rhs, n], Module]];
      $cols = Rest[Keys[$t]];
      $data = rowsOf[$cols];
      slots = DeleteDuplicates[Lookup[$slotOf, $counted, Null] /. Null -> Nothing];
      slots = SortBy[Join[slots, Select[$counted, !KeyExistsQ[$slotOf, #] &]], $order];
      keyRows = rowsOf[$counted];
      groups = GatherBy[Ordering[slotKeys[slots]], keyRows[[#]] &];
      $testRows = rowsOf[SortBy[testNames, $order]];
      reapedRows[
        While[count < n && k <= Length[groups],
          r = rowGroupResult[mode, rhs, all, testNames, groups[[k++]]];
          If[r =!= $noResult, count++; Sow[r, $rowTag]]]]]];

(* The results a loop sows, in order. *)
SetAttributes[reapedRows, HoldFirst];
reapedRows[loop_] := Replace[Reap[loop, $rowTag][[2]], {{l_} :> l, {} -> {}}];

$rowTag = Unique["row"];

(* The right-hand side is a counted name, or a list of them, none in an
   Alternatives slot, none tested, none ever unbound, and no Condition:
   each distinct tuple of codes is one result, code order is result order,
   and each result is made from codes, with no evaluation. *)
directRowsQ[mode_, rhs_, all_, testNames_] :=
  MatchQ[mode, "Values" | "Positions" | "CountedPositions"] && testNames === {} && guardedBody[rhs] === rhs &&
    !IntersectingQ[$counted, Keys[$slotOf]] && AllTrue[$counted, FreeQ[$t[#], -1] &] &&
    If[mode === "CountedPositions", First[rhsNames[rhs, all]] === $counted,
      MatchQ[$counted, {nm_} /; rhs === Hold @@ nm] || MatchQ[rhs, Hold[l_List] /; Sort[Thread[Hold[l]]] === Sort[$counted]]];

(* Each result as resultOf makes it: the value or position of the name, the
   list of those of the names, or the list of the counted names'
   positions. *)
directResults[mode_, rhs_, n_] :=
  Module[{order = SortBy[$counted, $order], tuples, made},
    tuples = Take[Union[rowsOf[order]], UpTo[n]];
    made = AssociationThread[order, If[mode === "Values", codeValues, Map[codePosition]] /@ Transpose[tuples]];
    Which[
      mode === "CountedPositions", List /@ MapThread[List, Lookup[made, $counted]],
      MatchQ[rhs, Hold[_List]], List /@ MapThread[List, Lookup[made, List @@ Thread[rhs]]],
      True, List /@ made[First[$counted]]]];

(* The rows of $t on columns cols, a list each. *)
rowsOf[{}] := ConstantArray[{}, rowCount[$t]];
rowsOf[cols_] := Transpose[Lookup[$t, cols]];

(* The order key of each row: for each slot in result order, the code of
   the first counted name of the slot it binds, or, binding none, the code
   of where the slot's Alternatives matched (resultKey). *)
slotKeys[{}] := ConstantArray[{}, rowCount[$t]];
slotKeys[slots_] :=
  Transpose[Function[s,
      If[StringQ[s],
        Fold[Function[{acc, name}, With[{c = $t[name]}, acc + (c - acc) Unitize[c + 1]]],
          Lookup[$t, s, ConstantArray[-1, rowCount[$t]]],
          Reverse @ Select[SortBy[Keys[Select[$slotOf, # === s &]], $order], MemberQ[$counted, #] && KeyExistsQ[$t, #] &]],
        $t[s]]] /@ slots];

(* The result of one group: its rows in position order of the test names,
   the first that the right-hand side gives a result for (groupResult in
   Query/TreePatterns.wl). *)
rowGroupResult[mode_, rhs_, all_, testNames_, group_] :=
  Module[{rows = If[testNames === {}, group, group[[Ordering[$testRows[[group]]]]]], v = $noResult, k = 1},
    While[v === $noResult && k <= Length[rows],
      v = resultOf[mode, rhs, all, rowSolution[$cols, $data[[rows[[k++]]]]]]];
    v];

(* The solution of a row, each name it binds to its match. *)
rowSolution[cols_, row_] := Association @ MapThread[If[#2 == -1, Nothing, #1 -> codeMatch[#2]] &, {cols, row}];
