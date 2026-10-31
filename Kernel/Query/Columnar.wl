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
(* in a branch of Alternatives that did not match. A place not  *)
(* on one element, as a run of children or a token, has a code  *)
(* below -1 (extraCode).                                        *)
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
   Child and list constraints, named and tested paths, Shortest and Longest,
   Alternatives, Condition and PatternTest, XMLDocument, and XMLElement
   patterns with their contents lists. It is
   decided from the compiled query alone, when it is compiled. *)

(* "Columnar", or why the engine does not run compiled query cq. *)
columnarCoverage[cq_Association] :=
  Which[
    cq["Records"], "an Except refers to a name bound outside it",
    True, Replace[DeleteDuplicates[uncovered[cq["Root"]]], {{} -> "Columnar", r_ :> StringRiffle[r, ", "]}]];

(* Why a node, or a node below it, is not covered: the empty list when it
   is. *)
uncovered[nd_] :=
  Switch[nd["Kind"],
    "XMLPattern", Join[headUncovered[nd], constraintsUncovered[nd["Constraints"], nd["HeadNames"]]],
    "XMLDocument", constraintsUncovered[nd["Constraints"], {}],
    "Named", If[MemberQ[nd["Sub"]["Names"], nd["Name"]], {"a name compared by value"}, uncovered[nd["Sub"]]],
    "Cond" | "Test" | "ListCond" | "ListTest" | "ContentsCond" | "ContentsTest", uncovered[nd["Sub"]],
    "ListNamed" | "ContentsNamed", If[MemberQ[nd["Sub"]["Names"], nd["Name"]], {"a name compared by value"}, uncovered[nd["Sub"]]],
    "Alt" | "ConstraintAlt", Join @@ (uncovered /@ nd["Subs"]),
    "Literal" | "Blank", {},
    "Plain", If[nd["Keep"] === {}, {}, {"a name inside a WL pattern on one value"}],
    "Token", If[nd["Keep"] === {} || {wholeName[nd["Pattern"]]} === nd["Keep"], {}, {"a name inside a WL pattern on one value"}],
    "Descendant" | "PathTest" | "PathCond" | "PathNearest", uncovered[nd["Sub"]],
    "PathNamed", If[MemberQ[nd["Sub"]["Names"], nd["Name"]], {"a name compared by value"}, uncovered[nd["Sub"]]],
    "List", entriesUncovered[nd["Items"], "Children"],
    "ContentsList", entriesUncovered[nd["Items"], "Contents"],
    "LiteralParts", literalUncovered[nd],
    _, {nd["Kind"]}];

(* The entries of a list over the items reader reads. A name a list binds
   twice is compared by value. *)
entriesUncovered[items_, reader_] :=
  Join[Join @@ (entryUncovered[#, reader] & /@ items),
    If[DuplicateFreeQ[Join @@ (listBound /@ items)], {}, {"a name compared by value"}]];

entryUncovered[it_, reader_] :=
  Switch[it["Kind"],
    "Any", {},
    "One", uncovered[it["Sub"]],
    "Not", Join[uncovered[it["Sub"]], If[it["Base"] === None, {}, uncovered[it["Base"]]]],
    "Run", Join @@ (entryUncovered[#, reader] & /@ it["Items"]),
    "SeqCond", Join @@ (entryUncovered[#, reader] & /@ it["Sub"]["Items"]),
    "Branches", Join @@ (Join @@ (entryUncovered[#, reader] & /@ #) & /@ it["Subs"]),
    "Repeat", If[!it["Captures"], Join @@ (entryUncovered[#, reader] & /@ it["Items"]),
      If[reader === "Children" && repeatedNameQ[it], {}, {"a name inside Repeated"}]]];

(* A repeat of one element child that binds a name to the child and nothing
   else, as (x : "li").. does: the name binds every child of the repeat, as
   a name bound twice in WL compares its values. *)
repeatedNameQ[it_] :=
  MatchQ[it["Items"], {e_} /; e["Kind"] === "One" && With[{sub = e["Sub"]},
    sub["Kind"] === "Named" && sub["Keep"] === {sub["Name"]} && sub["Sub"]["Keep"] === {} && uncovered[sub] === {}]];

(* The names an entry binds in the list, each as often as the walk binds
   it: a repeat that binds a name binds it once, every child of the repeat
   at once; each branch of an Alternatives binds its own. *)
listBound[it_] :=
  Switch[it["Kind"],
    "One", it["Keep"],
    "Not", If[it["Base"] === None, {}, it["Base"]["Keep"]],
    "Run", Join[If[MemberQ[it["Keep"], it["Name"]], {it["Name"]}, {}], Join @@ (listBound /@ it["Items"])],
    "SeqCond", Join @@ (listBound /@ it["Sub"]["Items"]),
    "Branches", Union @@ (Join @@ (listBound /@ #) & /@ it["Subs"]),
    "Repeat", If[repeatedNameQ[it], it["Keep"], Join @@ (listBound /@ it["Items"])],
    _, {}];

(* A literal matched by its parts: a name in its tag or attributes is on the
   tag or the attribute list itself, and no name is in two of its parts,
   which would compare values. *)
literalUncovered[nd_] :=
  With[{slots = nd["Slots"], sub = nd["Sub"]},
    Join[
      If[SubsetQ[Keys[Select[slots, # === 0 &]], nd["TagNames"]] && SubsetQ[Keys[Select[slots, # === Key[All] &]], nd["AttrsNames"]] &&
          !IntersectingQ[nd["TagNames"], nd["AttrsNames"]] && !IntersectingQ[Join[nd["TagNames"], nd["AttrsNames"]], sub["Names"]],
        {}, {"a name in a literal's tag or attributes without a place of its own"}],
      uncovered[sub]]];

(* Each name an element's tag and attributes bind must have a place of its
   own: the whole tag, the whole attribute map, one attribute's whole
   value, on a literal key that is not a list key, or the token list of a
   list key or a token or run of tokens in it. *)
headUncovered[nd_] :=
  With[{need = nd["HeadNames"]},
    If[need === {} || headPlaces[nd] =!= None, {}, {"a name in a tag or attributes without a place of its own"}]];

(* {{"Tag" | All | key | {"Tokens", listKey, node}, name}, ...} for the
   needed names of an XMLPattern's tag and attributes, the token list of a
   list key taking every name its value binds; or None when one has no place
   of its own, or two names one place, or one name two. *)
headPlaces[nd_] :=
  With[{need = nd["HeadNames"], tag = tagPlaces[nd["Tag"], nd["HeadNames"]], attrs = attrPlaces[nd["Attrs"], nd["HeadNames"], nd["TokenLists"]]},
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

attrPlaces[Verbatim[Pattern][s_Symbol, a_], need_, lists_] :=
  With[{inner = attrPlaces[a, need, lists]},
    If[inner === None, None, If[MemberQ[need, Hold[s]], Prepend[inner, {All, Hold[s]}], inner]]];
attrPlaces[Verbatim[PatternTest][a_, _], need_, lists_] := attrPlaces[a, need, lists];
attrPlaces[r_Rule, need_, lists_] := attrPlaces[{r}, need, lists];
attrPlaces[rules_List, need_, lists_] :=
  With[{named = Select[rules, IntersectingQ[namesIn[Hold[#]], need] &]},
    If[FreeQ[rules, Verbatim[Rule][_Alternatives, _]] && AllTrue[named, MatchQ[#, Verbatim[Rule][_String, _]] &],
      Replace[Join @@ (rulePlaces[#, need, lists] & /@ named), l_ /; MemberQ[l, None] -> None],
      None]];
attrPlaces[a_, need_, _] := If[IntersectingQ[namesIn[Hold[a]], need], None, {}];

(* The places of the names one rule binds. *)
rulePlaces[k_ -> v_, need_, lists_] :=
  Which[
    !KeyExistsQ[$readings, k], If[wholeName[v] =!= None, {{k, wholeName[v]}}, {None}],
    KeyExistsQ[lists, v] && tokensUncovered[lists[v]] === {},
      {{"Tokens", k, lists[v]}, #} & /@ Intersection[lists[v]["Keep"], need],
    True, {None}];

(* Why the compiled value of a list key (cTokenList) is not covered. *)
tokensUncovered[nd_] :=
  Switch[nd["Kind"],
    "TokenNamed", If[MemberQ[nd["Sub"]["Names"], nd["Name"]], {"a name compared by value"}, tokensUncovered[nd["Sub"]]],
    "TokenCond", tokensUncovered[nd["Sub"]],
    "TokenList", entriesUncovered[nd["Items"], "Tokens"],
    "TokenPlain", If[nd["Keep"] === {}, {}, {"a name inside a WL pattern on one value"}]];

(* The constraints of one element are joined on it, and a name two of them
   bind names one place, compared by position (ADR 0023, joinedAcross),
   which elements and runs of them have here; a name bound to a tag,
   attribute, token or contents item in either, or in the element's own tag
   and attributes, would be compared by value. *)
constraintsUncovered[cons_, headNames_] :=
  With[{keeps = #["Keep"] & /@ cons, strings = stringNames /@ cons},
    Join[
      Join @@ (uncovered /@ cons),
      If[IntersectingQ[headNames, Union @@ Prepend[keeps, {}]] ||
          AnyTrue[Subsets[Range[Length[cons]], {2}],
            IntersectingQ[Intersection @@ keeps[[#]], Union @@ strings[[#]]] &],
        {"a name compared by value"}, {}]]];

(* The names bound below a node to what is not an element or a run of
   elements: a tag, an attribute, a token, a literal's contents or an item
   of them. *)
stringNames[nd_] :=
  Switch[nd["Kind"],
    "XMLPattern", Union[nd["HeadNames"], Union @@ Prepend[stringNames /@ subNodes[nd], {}]],
    "LiteralParts", nd["Names"],
    _, Union @@ Prepend[stringNames /@ subNodes[nd], {}]];

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
   queries. A run computes it only when it makes a code (columnarResults):
   an element test of a pattern with no names makes none. *)
placeBase[] := Lookup[$vectors, Key[{"PlaceBase"}], $vectors[{"PlaceBase"}] = Max[0, Length /@ $elem[[2 ;;, 2]]] + 3];

codePosition[c_] /; c < -1 := First[First[extraMatch[c]]];
codePosition[c_] :=
  With[{i = Quotient[c, $K], s = Mod[c, $K]},
    Switch[s, 0, posOf[i], 1, Append[posOf[i], 0], 2, Append[posOf[i], Key[All]], _, Append[posOf[i], Key[elemOf[i][[2, s - 2, 1]]]]]];

codeValue[c_] :=
  With[{i = Quotient[c, $K], s = Mod[c, $K]},
    Switch[s, 0, elemOf[i], 1, elemOf[i][[1]], 2, elemOf[i][[2]], _, elemOf[i][[2, s - 2, 2]]]];

(* The values of codes, all at once. *)
codeValues[{}] := {};
codeValues[codes_] /; Min[codes] < -1 :=
  Module[{vs = ConstantArray[Null, Length[codes]], ex = Flatten @ Position[UnitStep[codes], 0], el = Flatten @ Position[UnitStep[codes], 1]},
    If[el =!= {}, vs[[el]] = codeValues[codes[[el]]]];
    vs[[ex]] = extraValues[codes[[ex]]];
    vs];
codeValues[codes_] :=
  With[{ids = Quotient[codes, $K] + 1, ss = Mod[codes, $K]},
    If[Max[ss] == 0, $elem[[ids]],
      Extract[$elem, MapThread[Switch[#2, 0, {#1}, 1, {#1, 1}, 2, {#1, 2}, _, {#1, 2, #2 - 2, 2}] &, {ids, ss}]]]];

(* A name's match as resultOf reads it: its positions and its value. *)
codeMatch[c_] := If[c < -1, extraMatch[c], nameMatch[{codePosition[c]}, codeValue[c], {}]];

(* ---- Matching a pattern root ----

   tab[nd, allowed, rootQ]: the table of a pattern root node at the nodes
   allowed (All, or marks over the nodes), on the node's Keep. Its roots
   are read above only when rootQ. *)

tab[nd_, allowed_, rootQ_] := tabKind[nd["Kind"], nd, allowed, rootQ];

(* The candidates of a pattern root, its vector's ids (candidateVector),
   kept with the index. *)
candidateIds[nd_] := Last[candidateCounts[nd]];

tabKind["XMLPattern", nd_, All, rootQ_] := treeTable[nd, candidateIds[nd], rootQ];
tabKind["XMLPattern", nd_, allowed_, rootQ_] := treeTable[nd, packed @ Flatten @ Position[Rest[allowed] candidateVector[nd], 1], rootQ];

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
    t = headTable[nd, p];
    Which[
      named === {}, t,
      p === {}, emptyTable[nd["Keep"]],
      !rootQ && Length[named] == 1 && Lookup[nd, "HeadNames", {}] === {} && coverableQ[First[named]], covered[First[named], p],
      True,
        distinctRows[
          KeyDrop[Fold[If[rowCount[#1] == 0, #1, joinTables[#1, rootConstraintTable[nd, #2, DeleteDuplicates[#1["Root"]]]]] &, t, named], pathKeys[nd]],
          rootQ]]];

(* The table of the names in the tag and attributes, at elements ps: a
   column for each name on the tag, the attribute map or an attribute, and
   the rows of each list key's token list joined to them. *)
headTable[nd_, ps_] /; Lookup[nd, "HeadNames", {}] === {} := <|"Root" -> packed[ps]|>;
headTable[nd_, ps_] :=
  With[{places = headPlaces[nd]},
    Fold[If[rowCount[#1] == 0, #1, joinTables[#1, tokenTable[#2[[2]], #2[[3]], ps]]] &,
      Join[<|"Root" -> packed[ps]|>, Association[#[[2]] -> headCodes[ps, #[[1]]] & /@ Select[places, !ListQ[#[[1]]] &]]],
      DeleteDuplicates[Cases[places[[All, 1]], {"Tokens", _, _}]]]];

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
    "List" /; childListQ[c],
      If[filteredQ && childEntry[c]["Exact"], ps,
        With[{kids = tab[childEntry[c], childMarks[ps], True]["Root"]}, restricted[ps, idMarks[$parent[[kids + 1]]]]]],
    "List" | "ListNamed" | "ListCond" | "ListTest",
      restricted[ps, idMarks[listConstraintTable[c, ps]["Root"]]],
    "PathNamed" | "PathTest" | "PathCond" | "PathNearest",
      restricted[ps, idMarks[pathTable[c, ps]["Root"]]],
    "ConstraintAlt",
      restricted[ps, idMarks[Union @@ (holding[#, ps, False] & /@ c["Subs"])]]];

(* The table of a constraint that keeps names, at elements ps. *)
constraintTable[c_, ps_] :=
  projected[c["Keep"], True] @ Switch[c["Kind"],
    "Descendant", descendantPairs[withLowerEnds[c, tab[c["Sub"], belowMarks[ps], True]], ps, c["Levels"]],
    "PathNamed" | "PathTest" | "PathCond" | "PathNearest", pathTable[c, ps],
    "List" /; childListQ[c], childTable[c, ps],
    "List" | "ListNamed" | "ListCond" | "ListTest", listConstraintTable[c, ps],
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

(* A list constraint that is Child[p], as compiled: {___, p, ___}. It needs
   no walk: its rows are those of p at the children. *)
childListQ[c_] :=
  MatchQ[#["Kind"] & /@ c["Items"], {"Any", "One", "Any"}] && c["Items"][[1]]["Min"] == 0 && c["Items"][[3]]["Min"] == 0;

(* The pattern root of the one entry of Child[p]. *)
childEntry[c_] := c["Items"][[2]]["Sub"];

(* Child[p]: the rows of p at the children of ps, each at its parent. *)
childTable[c_, ps_] :=
  With[{s = tab[childEntry[c], childMarks[ps], True]},
    sortedByRoot @ Append[s, "Root" -> packed[$parent[[s["Root"] + 1]]]]];

coverableQ[c_] := c["Kind"] === "Descendant" && c["Levels"] === {1, Infinity};

(* The rows of the constraint's pattern below some candidate; their roots
   are not read. *)
covered[c_, ps_] := projected[c["Keep"], False] @ tab[c["Sub"], belowMarks[ps], True];

(* ---- Paths ----

   A Descendant under a name, a test, a Condition, Shortest or Longest is a
   path: every node of it keeps a hidden column, its "Key", holding the id
   of the element its pattern matched, the lower end; the root of a row is
   its upper end. A name on it binds a place code of both ends (pathCodes),
   whose position is upper ;; lower and whose value the elements strictly
   between, outermost first. *)

(* The table of a Descendant with its lower ends, when it is a path. *)
withLowerEnds[c_, s_] := If[c["Key"] === None, s, Append[s, c["Key"] -> s["Root"]]];

(* The hidden columns of the paths among an element's constraints, which
   it does not keep. *)
pathKeys[nd_] := DeleteCases[Lookup[nd["Constraints"], "Key", None], None];

pathTable[c_, ps_] :=
  With[{s = constraintTable[c["Sub"], ps]},
    Switch[c["Kind"],
      "PathNamed", If[MemberQ[c["Keep"], c["Name"]], Append[s, c["Name"] -> pathCodes[s["Root"], s[c["Key"]]]], s],
      "PathTest", pickRows[s, pathsPassing[c["F"], s["Root"], s[c["Key"]]]],
      "PathCond", passingRows[c, s],
      "PathNearest", s]];

(* A path test runs once for each distinct pair of ends, as 0 or 1. *)
pathsPassing[f_, is_, js_] :=
  With[{pairs = Transpose[{is, js}]},
    packed @ Lookup[AssociationMap[Boole[TrueQ[f[$elem[[pathIds @@ # + 1]]]]] &, DeleteDuplicates[pairs]], pairs]];

(* The codes of the paths from is to js: the lower end is the owner, so
   that codes of paths sort by lower end, then upper end, as positions of
   paths do. *)
pathCodes[is_, js_] :=
  (If[Max[0, is] >= $B^2, fallBack["more elements than a path's code holds"]];
   extraCode["Path", js, Quotient[is, $B], Mod[is, $B]]);

(* Whether each code is not on the bare input, which is never counted: its
   element, code K, or a path from it. *)
notBare[col_] :=
  If[Min[col, 0] >= -1, Unitize[col - $K],
    With[{f = extraFields[col]},
      Unitize[col - $K] (1 - UnitStep[-2 - col] (1 - Unitize[f[[1]] - $extraKinds["Path"]]) (1 - Unitize[f[[3]] $B + f[[4]] - 1]))]];

(* The table of constraint c of pattern root nd at elements ps. Under
   XMLDocument, the one root, Shortest and Longest have no effect. *)
rootConstraintTable[nd_, c_, ps_] :=
  If[nd["Kind"] === "XMLPattern" && nearestOf[c] =!= None, nearestTable[nd, c, ps, nearestOf[c]], constraintTable[c, ps]];

(* Shortest and Longest on a path, as the solutions engine's nearestFiltered
   and shadowsQ decide them: a row with upper end i and lower end j is
   dropped when some element k shadows it, strictly between i and j for
   Shortest, strictly above i, below the document, for Longest. k shadows
   when it is a candidate of nd (its tag and attributes pass, and it has
   the children nd needs), every other constraint of nd has a solution at
   k, and c has one with lower end j; nd's own Conditions, and whatever is around it, are not
   compared. The elements that shadow some row ending at j are all above
   j, so a row survives Shortest when none of them is deeper than i, and
   Longest when none is shallower. The rows at the elements that are not
   among ps are dropped by the join. *)
nearestTable[nd_, c_, ps_, which_] :=
  Module[{ks = candidateIds[nd], t, d, js, best},
    ks = If[which === Shortest,
      restricted[ks, Unitize[belowMarks[ps] + idMarks[ps]]],
      With[{cum = countsUpTo[ps]}, Pick[ks, Unitize[cum[[$end[[ks + 1]] + 1]] - cum[[ks + 1]] + idMarks[ps][[ks + 1]]], 1]]];
    ks = Fold[If[#1 === {}, #1, holdingAt[#2, #1]] &, ks, Select[nd["Constraints"], #["Id"] =!= c["Id"] &]];
    t = constraintTable[c, ks];
    If[rowCount[t] == 0, Return[t, Module]];
    d = $depth[[t["Root"] + 1]];
    js = t[c["Key"]];
    best = ConstantArray[0, Length[$elem]];
    (* At repeated parts, the last assignment wins. *)
    With[{o = If[which === Shortest, Ordering[d], Reverse[Ordering[d]]]}, best[[js[[o]] + 1]] = d[[o]]];
    pickRows[t, If[which === Shortest, UnitStep[d - best[[js + 1]]], UnitStep[best[[js + 1]] - d]]]];

(* The elements among ps, an XMLPattern's candidates, at which constraint c
   has a solution. *)
holdingAt[c_, ps_] := If[c["Keep"] === {}, holding[c, ps, True], Sort @ DeleteDuplicates[constraintTable[c, ps]["Root"]]];

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
  With[{s = tab[nd["Sub"], allowed, rootQ]},
    If[rowCount[s] == 0, emptyTable[nd["Keep"]], distinctRows[KeyTake[passingRows[nd, s], Prepend[nd["Keep"], "Root"]], rootQ]]];

(* The rows of a table, or of a list walk's frontier, that pass the
   Condition of node nd. *)
passingRows[nd_, s_] :=
  With[{sees = nd["Sees"], n = Length[First[s]]},
    If[n == 0, s,
      With[{seen = If[sees === {}, ConstantArray[{}, n], Transpose[Lookup[s, sees, ConstantArray[-1, n]]]]},
        With[{passes = AssociationThread[#, conditionPasses[nd, sees, #]] &[DeleteDuplicates[seen]]},
          pickRows[s, Lookup[passes, seen]]]]]];

(* Whether each distinct tuple of the seen names passes the test, as 0 or
   1. With every name bound, the test is a function of their values,
   applied to columns of values; otherwise to each tuple's solution, where
   a name the tuple leaves unbound is Sequence[] and a run is spliced in,
   as passesQ makes them. *)
conditionPasses[nd_, sees_, tuples_] :=
  If[sees =!= {} && Min[tuples] >= 0,
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

(* A WL pattern on one item of a literal's contents, at the items that are
   elements; it binds no name (coverage). *)
tabKind["Plain", nd_, allowed_, _] := elementsMatching[nd["Pattern"], allowed];

(* f applied once to each distinct one of xs, as 0 or 1 for each: a page
   repeats a few tags, attribute lists, strings and tokens many times. *)
testedOnce[xs_, f_] := With[{u = DeleteDuplicates[xs]}, packed @ Lookup[AssociationThread[u, Boole[f /@ u]], xs]];

(* ---- XMLElement patterns by their parts ----

   The tag and the attributes are WL patterns on the element's own, each
   tested once for each distinct one; a name on the tag or the attribute
   list is at that place, and the contents slot is matched over the
   element's contents (contentsTable). The names of the three parts are
   apart (coverage), so the parts are joined on the element. *)
tabKind["LiteralParts", nd_, allowed_, _] :=
  Module[{ids = restricted[Range[Length[$elem] - 1], allowed]},
    ids = Pick[ids, testedOnce[$elem[[ids + 1, 1]], MatchQ[#, nd["Tag"]] &], 1];
    ids = Pick[ids, testedOnce[$elem[[ids + 1, 2]], MatchQ[#, nd["Attrs"]] &], 1];
    If[ids === {}, emptyTable[nd["Keep"]],
      distinctRows[KeyTake[
          joinTables[
            Join[<|"Root" -> packed[ids]|>,
              AssociationThread[nd["TagNames"], ConstantArray[packed[$K ids + 1], Length[nd["TagNames"]]]],
              AssociationThread[nd["AttrsNames"], ConstantArray[packed[$K ids + 2], Length[nd["AttrsNames"]]]]],
            contentsTable[nd["Sub"], ids]],
          Prepend[nd["Keep"], "Root"]], True]]];

(* The table of a literal's contents slot at elements ids. *)
contentsTable[c_, ids_] :=
  Switch[c["Kind"],
    "ContentsList",
      listRows[contentsSequence[Pick[ids, UnitStep[(Length /@ $elem[[ids + 1, 3]]) - c["MinItems"]], 1]], c["Items"], c["Keep"]],
    "ContentsNamed",
      With[{s = contentsTable[c["Sub"], ids]}, If[MemberQ[c["Keep"], c["Name"]], Append[s, c["Name"] -> extraCode["Contents", s["Root"]]], s]],
    "ContentsCond", KeyTake[passingRows[c, contentsTable[c["Sub"], ids]], Prepend[c["Keep"], "Root"]],
    "ContentsTest",
      With[{s = contentsTable[c["Sub"], ids]},
        pickRows[s, idMarks[Select[DeleteDuplicates[s["Root"]], TrueQ[c["F"][elemOf[#][[3]]]] &]][[s["Root"] + 1]]]],
    "Plain", <|"Root" -> packed @ Pick[ids, MatchQ[#, c["Pattern"]] & /@ $elem[[ids + 1, 3]]]|>];

(* ---- Lists ----

   A list constraint is matched at all its owners at once: the elements the
   pattern root's candidates leave, each with its items, its element
   children. A literal's contents list is matched so over the items of the
   elements its tag and attributes pass, text included, and a list key's
   token list over the tokens of the elements an XMLPattern's test passes.

   The owners' items are laid end to end in a sequence, each owner taking
   its n items and n + 1 places, numbered from 1 over the whole sequence. A
   set of places is a 0/1 vector over them. An entry that is one item is a
   0/1 vector over the places too, 1 at place q when the item after q
   passes it, and 0 at each owner's last place, so that no step from one
   place to the next leaves an owner: the reach of one item, of ___ and of
   a repeat of one item over one owner's places is the same operation over
   the whole sequence. A list that binds nothing holds where its entries
   reach an owner's last place from its first. One that binds names is
   walked as a frontier table, a row for each partial solution: its place,
   "Place", and a column for each name bound so far. Between the entries
   that bind, rows move on by reach; at each such entry, every way it
   matches from a row's place makes a row; after the last, the backward
   reach of the entries left decides. Distinct rows are distinct tuples
   (ADR 0024).

   What a list reads, children, contents items or tokens, is its reader,
   which the sequence carries and every list operator is given: how an
   entry tests each item ("Test"), the table of the names an entry binds at
   each item it matches, by item ("Table"), and the code of a run of items
   ("Run"). *)

(* The owner, numbered from 1, of each of Total[lens] items, the i-th owner
   having lens[[i]]. *)
ownerIndex[lens_] :=
  With[{nz = Pick[Range[Length[lens]], Unitize[lens], 1]},
    If[nz === {}, packed[{}],
      Module[{marks = ConstantArray[0, Total[lens]]},
        marks[[Most[Accumulate[Prepend[lens[[nz]], 0]]] + 1]] = Differences[Prepend[nz, 0]];
        Accumulate[marks]]]];

(* {i, k} for k from 0 to lens[[i]] - 1, for each i in order, as two
   columns: how a row is repeated lens[[i]] times, without a loop. *)
spread[lens_] :=
  With[{i = ownerIndex[lens]},
    If[i === {}, {packed[{}], packed[{}]}, {i, Range[0, Length[i] - 1] - Most[Accumulate[Prepend[lens, 0]]][[i]]}]];

(* For each of keys, the values equal to it, in order: {indices into keys,
   indices into values}, a pair for each. Keys and values count from 1. *)
keyPairs[keys_, values_] :=
  If[keys === {} || values === {}, {packed[{}], packed[{}]},
    Module[{cum, row, off},
      cum = Prepend[Accumulate[valueCounts[values, Max[keys, values]]], 0];
      {row, off} = spread[cum[[keys + 1]] - cum[[keys]]];
      {row, Ordering[values][[cum[[keys[[row]]]] + 1 + off]]}]];

valueCounts[vs_, size_] := Module[{c = ConstantArray[0, size]}, With[{t = Tally[vs]}, c[[t[[All, 1]]]] = t[[All, 2]]]; c];

$sequenceCount = 0;

(* The sequence of the items of owners, lens[[i]] for the i-th, read by
   reader. "ItemPlace" is the place before each item, "ItemAt" the item
   after each place, 0 at an owner's last; "ItemOwner" and "ItemK" are the
   owner of each item and its index there. *)
sequenceOf[reader_, owners_, lens0_] :=
  Module[{lens = packed[lens0], n, first, item, itemPlace, itemAt},
    n = Total[lens];
    first = Most[Accumulate[Prepend[lens + 1, 0]]] + 1;
    item = ownerIndex[lens];
    itemPlace = packed[Range[n] + item - 1];
    itemAt = ConstantArray[0, n + Length[owners]];
    If[n > 0, itemAt[[itemPlace]] = Range[n]];
    Join[reader, <|"Id" -> ++$sequenceCount, "Owners" -> packed[owners], "Lens" -> lens, "Places" -> n + Length[owners],
      "First" -> first, "Last" -> first + lens, "OwnerOf" -> ownerIndex[lens + 1], "ItemPlace" -> itemPlace, "ItemAt" -> itemAt,
      "ItemOwner" -> packed[owners][[item]], "ItemK" -> packed[Range[n] - Most[Accumulate[Prepend[lens, 0]]][[item]]]|>]];

(* What a list operator computes once per sequence, for the run. *)
SetAttributes[listMemo, HoldRest];
listMemo[k_, v_] := Lookup[$listMemo, Key[k], $listMemo[k] = v];

(* A 0/1 vector over the items as one over the places, 0 at each owner's
   last place. *)
overPlaces[cx_, v_] := Module[{e = ConstantArray[0, cx["Places"]]}, If[Length[v] > 0, e[[cx["ItemPlace"]]] = v]; e];

passVector[cx_, sub_] := listMemo[{"Pass", cx["Id"], sub["Id"]}, overPlaces[cx, cx["Test"][cx, sub]]];
anyItem[cx_] := listMemo[{"Any", cx["Id"]}, overPlaces[cx, ConstantArray[1, Length[cx["ItemPlace"]]]]];
itemTable[cx_, sub_] := listMemo[{"Table", cx["Id"], sub["Id"]}, cx["Table"][cx, sub]];

(* 1 at each of the items given. *)
itemMarks[cx_, items_] := Module[{v = ConstantArray[0, Length[cx["ItemPlace"]]]}, If[items =!= {}, v[[items]] = 1]; v];

(* The vector of an entry that is one item: its pattern's, or for Except
   the items its pattern fails, and its second argument passes. *)
oneVector[cx_, it_] :=
  If[it["Kind"] === "One", passVector[cx, it["Sub"]],
    (anyItem[cx] - passVector[cx, it["Sub"]]) If[it["Base"] === None, 1, passVector[cx, it["Base"]]]];

(* -- Readers -- *)

(* Element children: the owners' children, in order. An entry tests each
   child as a pattern root (tab), from its candidates alone when they are
   exactly its matches. *)
childSequence[owners_] :=
  With[{kids = $kids[[owners + 1]]}, Append[sequenceOf[$childReader, owners, Length /@ kids], "Items" -> packed[Flatten[kids]]]];

$childReader = <|
  "Test" -> Function[{cx, sub},
    If[sub["Exact"], candidateVector[sub][[cx["Items"]]], itemMarks[cx, itemTable[cx, sub]["Item"]]]],
  "Table" -> Function[{cx, sub}, elementItemRows[cx["Items"], Range[Length[cx["Items"]]], sub]],
  "Run" -> Function[{cx, o, m, n}, extraCode["Run", o, m, n]]|>;

(* The table of pattern root sub at the elements ids, the items items, by
   item. *)
elementItemRows[ids_, items_, sub_] :=
  Module[{s = tab[sub, idMarks[ids], True], at = ConstantArray[0, Length[$elem]]},
    If[ids =!= {}, at[[ids + 1]] = items];
    Join[<|"Item" -> packed[at[[s["Root"] + 1]]]|>, KeyDrop[s, "Root"]]];

(* A literal's contents: every item, elements, which an entry tests as it
   tests children, and text, which only a WL pattern matches (textRows). *)
contentsSequence[owners_] :=
  With[{lists = $elem[[owners + 1, 3]]},
    Module[{values = Join @@ lists, child},
      child = ConstantArray[0, Length[values]];
      If[values =!= {}, child[[Flatten @ Position[values, _XMLElement, {1}, Heads -> False]]] = Flatten[$kids[[owners + 1]]]];
      Join[sequenceOf[$contentsReader, owners, Length /@ lists], <|"Values" -> values, "Child" -> child|>]]];

$contentsReader = <|
  "Test" -> Function[{cx, sub}, itemMarks[cx, DeleteDuplicates[itemTable[cx, sub]["Item"]]]],
  "Table" -> Function[{cx, sub},
    With[{el = Flatten @ Position[Unitize[cx["Child"]], 1], tx = Flatten @ Position[Unitize[cx["Child"]], 0]},
      With[{ts = {elementItemRows[cx["Child"][[el]], el, sub], textRows[cx, sub, tx]}}, stacked[ts, DeleteDuplicates[Join @@ (Keys /@ ts)]]]]],
  "Run" -> Function[{cx, o, m, n}, extraCode["ContentsRun", o, m, n]]|>;

(* The rows of pattern node nd at the text items tx of contents sequence
   cx, by item: what textKind (Query/TreePatterns.wl) gives there. *)
textRows[cx_, nd_, tx_] :=
  Switch[nd["Kind"],
    "Plain", <|"Item" -> packed @ Pick[tx, testedOnce[cx["Values"][[tx]], MatchQ[#, nd["Pattern"]] &], 1]|>,
    "Blank", <|"Item" -> packed @ Pick[tx, testedOnce[cx["Values"][[tx]], MatchQ[#, Blank @@ nd["Head"]] &], 1]|>,
    "Named",
      With[{s = textRows[cx, nd["Sub"], tx]}, If[MemberQ[nd["Keep"], nd["Name"]], Append[s, nd["Name"] -> textCodes[cx, s["Item"]]], s]],
    "Cond", KeyTake[passingRows[nd, textRows[cx, nd["Sub"], tx]], Prepend[nd["Keep"], "Item"]],
    "Test", With[{s = textRows[cx, nd["Sub"], tx]}, pickRows[s, testedOnce[cx["Values"][[s["Item"]]], TrueQ[nd["F"][#]] &]]],
    "Alt",
      uniqueRows @ stacked[
        With[{s = textRows[cx, #, tx]}, If[nd["Slot"] === None, s, Append[s, nd["Slot"] -> textCodes[cx, s["Item"]]]]] & /@ nd["Subs"],
        Prepend[nd["Keep"], "Item"]],
    _, <|"Item" -> packed[{}]|>];

textCodes[cx_, items_] := extraCode["Text", cx["ItemOwner"][[items]], cx["ItemK"][[items]]];

(* The tokens of the list key key at owners, as a list key's reading splits
   the attribute it reads; an entry is a WL pattern on one token. *)
tokenSequence[owners_, key_] :=
  With[{lists = tokensOf[#, key] & /@ owners},
    If[Max[0, Length /@ lists] > $B - 2, fallBack["a token list longer than a place code holds"]];
    Join[sequenceOf[$tokenReader, owners, Length /@ lists], <|"Values" -> Join @@ lists, "Key" -> keyIndex[key]|>]];

tokensOf[o_, key_] := With[{r = $readings[key]}, splitterOf[r][Lookup[$elem[[o + 1, 2]], rawKeyOf[r], ""]]];

keyIndex[key_] := First @ FirstPosition[Keys[$readings], key, {0}, {1}, Heads -> False];

$tokenReader = <|
  "Test" -> Function[{cx, sub}, testedOnce[cx["Values"], MatchQ[#, sub["Pattern"]] &]],
  "Table" -> Function[{cx, sub},
    With[{items = Flatten @ Position[cx["Test"][cx, sub], 1]},
      Join[<|"Item" -> packed[items]|>,
        AssociationThread[sub["Keep"], ConstantArray[extraCode["Token", cx["ItemOwner"][[items]], cx["Key"], cx["ItemK"][[items]]], Length[sub["Keep"]]]]]]],
  "Run" -> Function[{cx, o, m, n}, extraCode["TokenRun", o, cx["Key"], m, n]]|>;

(* The table of the compiled value of list key key (cTokenList) at the
   elements ps, which its compiled test has passed. *)
tokenTable[key_, nd_, ps_] :=
  Switch[nd["Kind"],
    "TokenList", If[nd["Keep"] === {}, <|"Root" -> packed[ps]|>, listRows[tokenSequence[ps, key], nd["Items"], nd["Keep"]]],
    "TokenNamed",
      With[{s = tokenTable[key, nd["Sub"], ps]},
        If[MemberQ[nd["Keep"], nd["Name"]], Append[s, nd["Name"] -> extraCode["TokenList", s["Root"], keyIndex[key]]], s]],
    "TokenCond", KeyTake[passingRows[nd, tokenTable[key, nd["Sub"], ps]], Prepend[nd["Keep"], "Root"]],
    "TokenPlain", <|"Root" -> packed[ps]|>];

(* -- Reach over all owners at once -- *)

(* From the places of s over one item that passes t: dir 1 forward, dir -1
   backward. *)
stepped[s_, t_, 1] := Prepend[Most[s t], 0];
stepped[s_, t_, -1] := Append[Rest[s] Most[t], 0];

(* ___ with at least m items: the places at or after (before) one of s, in
   its owner. *)
anyReach[cx_, s_, m_, dir_] := gapReach[cx, Nest[stepped[#, anyItem[cx], dir] &, s, m], dir];
gapReach[cx_, s_, 1] := With[{c = Accumulate[s]}, Unitize[c - (c - s)[[cx["First"]]][[cx["OwnerOf"]]]]];
gapReach[cx_, s_, -1] := With[{c = Reverse[Accumulate[Reverse[s]]]}, Unitize[c - (c - s)[[cx["Last"]]][[cx["OwnerOf"]]]]];

reachOver[cx_, items_List, s_, dir_] := Fold[reachEntry[cx, #2, #1, dir] &, s, If[dir == 1, items, Reverse[items]]];

(* A Condition on a span is passed over here, so the reach is a superset;
   the walk tests it at each span. *)
reachEntry[cx_, it_, s_, dir_] :=
  Switch[it["Kind"],
    "One" | "Not", stepped[s, oneVector[cx, it], dir],
    "Any", anyReach[cx, s, it["Min"], dir],
    "Run", reachOver[cx, it["Items"], s, dir],
    "SeqCond", reachOver[cx, it["Sub"]["Items"], s, dir],
    "Branches", Unitize[Total[reachOver[cx, #, s, dir] & /@ it["Subs"]]],
    "Repeat", repeatsReach[cx, it, s, dir]];

(* A repeat of a block of l one-item entries, as PatternSequence[_, _]..,
   moves by whole blocks: along each class of places mod l it is a repeat
   of one item, the block from each place. Stepping one repeat at a time
   costs a pass over the places per repeat, quadratic in the siblings for
   li:nth-child(2n+1). A repeat of one item reaches a place from the last
   place of s before it, lo items back or more, with every item between
   passing (runsReach); the item vector's 0 at each owner's last place ends
   every run there. *)
repeatsReach[cx_, it_, s_, dir_] /; AllTrue[it["Items"], MatchQ[#["Kind"], "One" | "Not"] &] :=
  Module[{l = Length[it["Items"]], ok = blockVector[cx, it["Items"]], out = 0 s},
    Do[With[{idx = Range[r, Length[s], l]},
        out[[idx]] = If[dir == 1, runsReach[s[[idx]], Most[ok[[idx]]], it["Min"], it["Max"]],
          Reverse @ runsReach[Reverse[s[[idx]]], Reverse[Most[ok[[idx]]]], it["Min"], it["Max"]]]],
      {r, Min[l, Length[s]]}];
    out];

(* 1 at each place from which the block of one-item entries items passes. *)
blockVector[cx_, items_] := Times @@ MapIndexed[Join[Drop[oneVector[cx, #1], First[#2] - 1], ConstantArray[0, First[#2] - 1]] &, items];

repeatsReach[cx_, it_, s_, dir_] :=
  Module[{acc = If[it["Min"] == 0, s, 0 s], cur = s, k = 0},
    While[k < it["Max"] && Total[cur] > 0,
      k++;
      cur = reachOver[cx, it["Items"], cur, dir];
      If[k >= it["Min"], cur = cur (1 - acc); acc = Unitize[acc + cur]]];
    acc];

(* The places reached from s over lo to hi items that each pass v: a
   running maximum of the places of s, and a count of the items that fail,
   which two places with none failing between share. *)
runsReach[s_, v_, lo_, hi_] :=
  With[{places = Range[0, Length[v]], blocks = Prepend[Accumulate[1 - v], 0], k = Min[lo, Length[s]]},
    With[{last = Join[ConstantArray[-1, k], Drop[FoldList[Max, places s - (1 - s)], -k]]},
      UnitStep[last] (1 - Unitize[blocks[[Clip[last, {0, Infinity}] + 1]] - blocks]) If[hi === Infinity, 1, UnitStep[hi - (places - last)]]]];

(* Where each entry of items may start, to reach endOK. *)
backVectors[cx_, items_, endOK_] := Reverse @ FoldList[reachEntry[cx, #2, #1, -1] &, endOK, Reverse[items]];

(* -- The walk -- *)

frontierRows[t_] := Length[t["Place"]];

(* The distinct rows of a table. *)
uniqueRows[t_] := If[Length[First[t]] <= 1, t, AssociationThread[Keys[t], packed /@ Transpose[DeleteDuplicates[Transpose[Values[t]]]]]];

(* The rows of tables ts, one after the other, on columns cols, a column one
   lacks unbound. *)
stacked[ts_, cols_] :=
  AssociationThread[cols, Function[k, packed[Join @@ (Lookup[#, Key[k], ConstantArray[-1, Length[First[#]]]] & /@ ts)]] /@ cols];

(* The rows of the branches of Alternatives it from the rows of t, on
   columns cols, f[u, b] the rows of branch b from the rows u, in the order
   of the solutions: by the row of t they come from, and from one row the
   first branch's first. So an Optional, the branches of its pattern and of
   nothing, gives both at one row before either at the next. *)
branchRows[t_, it_, f_, cols_] :=
  With[{key = {"Row", it["Id"]}},
    With[{s = stacked[f[Append[t, key -> packed[Range[frontierRows[t]]]], #] & /@ it["Subs"], Append[cols, key]]},
      KeyDrop[takeRows[s, Ordering[s[key]]], key]]];

(* The rows of the walk of items over sequence cx from the rows of t, to the
   places of endOK. top: items are the whole list, and its rows need only
   their owners. *)
walkedRows[cx_, items_, t0_, endOK_, top_] :=
  Module[{back = backVectors[cx, items, endOK], caps = Flatten @ Position[#["Captures"] & /@ items, True], prev = 0, t = t0},
    Do[
      If[frontierRows[t] == 0, Break[]];
      t = segmentRows[cx, items[[prev + 1 ;; c - 1]], t, back[[c]]];
      t = spanRows[cx, items[[c]], t, back[[c + 1]]];
      prev = c,
      {c, caps}];
    Which[
      frontierRows[t] == 0, t,
      top, pickRows[t, back[[prev + 1]][[t["Place"]]]],
      True, segmentRows[cx, items[[prev + 1 ;;]], t, endOK]]];

(* The rows of t moved on over entries that bind nothing, to the places of
   target. A fixed number of one-item entries, and ___ gaps, whose rows are
   the places of target from the row's on, are read off vectors directly;
   so are any entries when each owner's rows are at one place, by one reach
   from all of them. Otherwise entry by entry, each step pruned by what the
   entries after it can reach. Rows come out in the order of the solutions:
   by the row they come from, and from one row by place. *)
segmentRows[cx_, {}, t_, target_] := pickRows[t, target[[t["Place"]]]];
segmentRows[cx_, seg_, t_, target_] /; AllTrue[seg, MatchQ[#["Kind"], "One" | "Not"] &] :=
  With[{l = Length[seg], q = t["Place"], p = cx["Places"]},
    With[{u = pickRows[t, Times @@ Append[MapIndexed[oneVector[cx, #1][[Clip[q + First[#2] - 1, {1, p}]]] &, seg], target[[Clip[q + l, {1, p}]]]]]},
      Append[u, "Place" -> u["Place"] + l]]];
segmentRows[cx_, seg_, t_, target_] /; AllTrue[seg, #["Kind"] === "Any" &] :=
  Module[{q = t["Place"], lo, hi, before, row, off},
    lo = q + Total[#["Min"] & /@ seg];
    hi = cx["Last"][[cx["OwnerOf"][[q]]]];
    before = Prepend[Accumulate[target], 0];
    {row, off} = spread[UnitStep[hi - lo] (before[[hi + 1]] - before[[Clip[lo, {1, cx["Places"]}]]])];
    Append[takeRows[t, row], "Place" -> packed[Flatten[Position[target, 1]][[before[[lo[[row]]]] + 1 + off]]]]];
segmentRows[cx_, seg_, t_, target_] /; DuplicateFreeQ[cx["OwnerOf"][[DeleteDuplicates[t["Place"]]]]] :=
  Module[{start = ConstantArray[0, cx["Places"]], ends, pairs},
    start[[t["Place"]]] = 1;
    ends = Flatten @ Position[reachOver[cx, seg, start, 1] target, 1];
    pairs = keyPairs[cx["OwnerOf"][[ends]], cx["OwnerOf"][[t["Place"]]]];
    pairs = pairs[[All, Ordering[pairs[[2]]]]];
    Append[takeRows[t, pairs[[2]]], "Place" -> packed[ends[[pairs[[1]]]]]]];
segmentRows[cx_, seg_, t_, target_] :=
  With[{backs = backVectors[cx, seg, target], key = {"Row", "Segment"}},
    With[{u = Fold[uniqueRows[stepRows[cx, seg[[#2]], #1, backs[[#2 + 1]]]] &, Append[t, key -> packed[Range[frontierRows[t]]]], Range[Length[seg]]]},
      uniqueRows @ KeyDrop[takeRows[u, Ordering[Transpose[{u[key], u["Place"]}]]], key]]];

stepRows[cx_, it_, t_, next_] :=
  Switch[it["Kind"],
    "One" | "Not" | "Any", segmentRows[cx, {it}, t, next],
    "Run", segmentRows[cx, it["Items"], t, next],
    "Branches", stacked[segmentRows[cx, #, t, next] & /@ it["Subs"], Keys[t]],
    "Repeat", If[AllTrue[it["Items"], MatchQ[#["Kind"], "One" | "Not"] &], blockRows[cx, it, t, next], perStartRows[cx, {it}, t, next]]];

(* A repeat of a block of l one-item entries: from place q, k whole blocks
   for k from the minimum to the number of blocks in a row that pass from q,
   counted once for all places (blockRuns). *)
blockRows[cx_, it_, t_, next_] :=
  Module[{l = Length[it["Items"]], q = t["Place"], ok, row, off, ends, keep},
    ok = blockVector[cx, it["Items"]];
    {row, off} = spread[Clip[Clip[blockRuns[ok, l][[q]], {0, it["Max"]}] - it["Min"] + 1, {0, Infinity}]];
    ends = q[[row]] + l (it["Min"] + off);
    keep = Flatten @ Position[next[[ends]], 1];
    Append[takeRows[t, row[[keep]]], "Place" -> packed[ends[[keep]]]]];

(* At each place q, how many of q, q + l, q + 2 l, ... in a row ok is 1 at. *)
blockRuns[ok_, l_] :=
  Module[{runs = 0 ok},
    Do[With[{idx = Range[r, Length[ok], l]},
        With[{b = Reverse[ok[[idx]]]},
          With[{c = Accumulate[b]}, runs[[idx]] = Reverse[c - Rest[FoldList[Max, 0, c (1 - b)]]]]]],
      {r, Min[l, Length[ok]]}];
    runs];

(* Any other entries: a reach from each distinct place of the rows. *)
perStartRows[cx_, seg_, t_, target_] :=
  Module[{ends, row, off},
    ends = AssociationMap[Flatten @ Position[reachOver[cx, seg, UnitVector[cx["Places"], #], 1] target, 1] &, DeleteDuplicates[t["Place"]]];
    {row, off} = spread[Length /@ Lookup[ends, t["Place"]]];
    Append[takeRows[t, row], "Place" -> packed @ MapThread[ends[#1][[#2 + 1]] &, {t["Place"][[row]], off}]]];

(* The rows of an entry that binds a needed name, from the rows' places,
   ending where next is 1, with the columns of the rows and of the names the
   entry keeps. *)
spanRows[cx_, it_, t_, next_] :=
  Switch[it["Kind"],
    "One", oneSpans[cx, it["Sub"], passVector[cx, it["Sub"]], t, next],
    "Not", oneSpans[cx, it["Base"], oneVector[cx, it], t, next],
    "Run",
      With[{key = {"Start", it["Id"]}},
        With[{inner = walkedRows[cx, it["Items"], Append[t, key -> t["Place"]], next, False]},
          uniqueRows @ KeyTake[
            If[MemberQ[it["Keep"], it["Name"]], Append[inner, it["Name"] -> runCodes[cx, inner[key], inner["Place"]]], inner],
            spanColumns[t, it]]]],
    "Branches",
      With[{key = {"Start", it["Id"]}, slotQ = MemberQ[it["Keep"], it["Slot"]]},
        uniqueRows @ branchRows[t, it,
          Function[{u, b}, With[{inner = walkedRows[cx, b, Append[u, key -> u["Place"]], next, False]},
            If[slotQ, Append[inner, it["Slot"] -> runCodes[cx, inner[key], inner["Place"]]], inner]]],
          spanColumns[t, it]]],
    "SeqCond", uniqueRows @ KeyTake[passingRows[it, walkedRows[cx, it["Sub"]["Items"], t, next, False]], spanColumns[t, it]],
    "Repeat", namedRepeatRows[cx, it, t, next]];

spanColumns[t_, it_] := DeleteDuplicates[Join[Keys[t], it["Keep"]]];

(* One item: the rows whose next item passes vec, each joined to the rows of
   sub's table at that item, the names it binds there. *)
oneSpans[cx_, sub_, vec_, t_, next_] :=
  With[{q = t["Place"]},
    With[{u = pickRows[t, vec[[q]] next[[Clip[q + 1, {1, cx["Places"]}]]]]},
      If[sub === None || sub["Keep"] === {}, Append[u, "Place" -> u["Place"] + 1],
        With[{s = itemTable[cx, sub]},
          With[{pairs = keyPairs[cx["ItemAt"][[u["Place"]]], s["Item"]]},
            Join[takeRows[Append[u, "Place" -> u["Place"] + 1], pairs[[1]]], takeRows[KeyDrop[s, "Item"], pairs[[2]]]]]]]]];

(* A repeat of one child that binds a name to it (repeatedNameQ): from place
   q, k children for k from the minimum to the number in a row that pass
   and are each equal to the next, the name bound to all k at once, or
   unbound for none. Bound to one child, it is that child's place. *)
namedRepeatRows[cx_, it_, t_, next_] :=
  Module[{q = t["Place"], name, runs, same, most, row, off, k, ends, keep, starts, g},
    name = it["Items"][[1]]["Sub"]["Name"];
    runs = blockRuns[passVector[cx, it["Items"][[1]]["Sub"]], 1];
    same = blockRuns[equalNext[cx], 1] + 1;
    most = runs - (runs - same) UnitStep[runs - same - 1];
    {row, off} = spread[Clip[Clip[most[[q]], {0, it["Max"]}] - it["Min"] + 1, {0, Infinity}]];
    k = it["Min"] + off;
    ends = q[[row]] + k;
    keep = Flatten @ Position[next[[ends]], 1];
    {k, starts} = {k[[keep]], q[[row[[keep]]]]};
    g = cx["OwnerOf"][[starts]];
    Join[takeRows[t, row[[keep]]],
      <|"Place" -> packed[ends[[keep]]],
        name -> packed @ Switch[Max[k, 0],
          0, ConstantArray[-1, Length[k]],
          1, With[{one = $K cx["Items"][[Clip[cx["ItemAt"][[starts]], {1, Infinity}]]]}, (one + 1) Unitize[k] - 1],
          _, With[{one = $K cx["Items"][[Clip[cx["ItemAt"][[starts]], {1, Infinity}]]],
              many = extraCode["Repeat", cx["Owners"][[g]], starts - cx["First"][[g]] + 1, starts - cx["First"][[g]] + k]},
            (one + 1) Unitize[k] (1 - Unitize[k - 1]) + (many + 1) UnitStep[k - 2] - 1]]|>]];

(* 1 at each place whose next item and the one after it are equal, in one
   owner. *)
equalNext[cx_] :=
  listMemo[{"Equal", cx["Id"]},
    With[{vs = $elem[[cx["Items"] + 1]], own = cx["ItemOwner"]},
      overPlaces[cx, If[Length[vs] < 2, ConstantArray[0, Length[vs]],
        Append[Boole[MapThread[SameQ, {Most[vs], Rest[vs]}]] (1 - Unitize[Differences[own]]), 0]]]]];

(* The codes of the runs from places starts to places ends. *)
runCodes[cx_, starts_, ends_] :=
  With[{g = cx["OwnerOf"][[starts]]}, cx["Run"][cx, cx["Owners"][[g]], starts - cx["First"][[g]] + 1, ends - cx["First"][[g]]]];

(* The table of a list's items over sequence cx: a row for each solution, at
   its owner, on the names keep. *)
listRows[cx_, items_, keep_] :=
  If[cx["Places"] == 0, emptyTable[keep],
    Module[{start = ConstantArray[0, cx["Places"]], endOK = ConstantArray[0, cx["Places"]], t},
      start[[cx["First"]]] = 1;
      endOK[[cx["Last"]]] = 1;
      If[NoneTrue[items, #["Captures"] &],
        <|"Root" -> packed @ Pick[cx["Owners"], reachOver[cx, items, start, 1][[cx["Last"]]], 1]|>,
        t = walkedRows[cx, items, <|"Place" -> cx["First"]|>, endOK, True];
        distinctRows[KeyTake[Join[<|"Root" -> packed[cx["Owners"][[cx["OwnerOf"][[t["Place"]]]]]]|>, KeyDrop[t, "Place"]], Prepend[keep, "Root"]], True]]]];

(* The table of a list constraint at the elements ps: a named list binds the
   run of all the children, its value their list. *)
listConstraintTable[c_, ps_] :=
  Switch[c["Kind"],
    "List", listRows[childSequence[Pick[ps, UnitStep[(Length /@ $kids[[ps + 1]]) - c["MinItems"]], 1]], c["Items"], c["Keep"]],
    "ListNamed",
      With[{s = listConstraintTable[c["Sub"], ps]}, If[MemberQ[c["Keep"], c["Name"]], Append[s, c["Name"] -> extraCode["List", s["Root"]]], s]],
    "ListCond", KeyTake[passingRows[c, listConstraintTable[c["Sub"], ps]], Prepend[c["Keep"], "Root"]],
    "ListTest",
      With[{s = listConstraintTable[c["Sub"], ps]},
        pickRows[s, idMarks[Select[DeleteDuplicates[s["Root"]], TrueQ[c["F"][elemOf /@ childrenOf[#]]] &]][[s["Root"] + 1]]]]];

(* ---- Places that are not on one element ----

   A run or gap of children, a name bound to every child of a repeat, a
   contents item or run of them, a literal's whole contents, a token or run
   of tokens, a list key's token list, and an element's list of children
   each have a code too, below -1, from the kind, the owner and up to three
   indices, each below $B. Code order is not position order for them:
   results sort them by their order keys (ranked). *)

$extraKinds = <|"Run" -> 1, "Repeat" -> 2, "Text" -> 3, "ContentsRun" -> 4, "Contents" -> 5, "Token" -> 6, "TokenRun" -> 7, "TokenList" -> 8,
  "List" -> 9, "Path" -> 10|>;

(* The owner is the most significant, then the indices in turn, so that the
   codes of one kind, of one list key, are in position order, backwards. *)
extraCode[kind_, o_, a_ : 0, b_ : 0, c_ : 0] := packed[-2 - ($extraKinds[kind] + 16 (((o $B + a) $B + b) $B + c))];

(* {kind, owner, a, b, c} of extra codes, each a column. *)
extraFields[codes_] :=
  With[{y = -2 - codes}, With[{x = Quotient[y, 16]}, {Mod[y, 16], Quotient[x, $B^3], Mod[Quotient[x, $B^2], $B], Mod[Quotient[x, $B], $B], Mod[x, $B]}]];

(* The kinds whose value is one value and whose position is one position,
   which results can make from codes directly (directResults), and whose
   codes of one kind and list key are in position order. *)
$plainKinds = {3, 5, 6, 8, 9, 10};

(* $B, kept with the index: more than the most items of any element's
   contents, and room for tokens. *)
placeRadix[] := Lookup[$vectors, Key[{"PlaceRadix"}], $vectors[{"PlaceRadix"}] = Max[1024, 2 + Max[0, Length /@ $elem[[2 ;;, 3]]]]];

(* The match of an extra code as resultOf reads it: its positions and its
   value. Its order key is apart (extraKey), as building the value of a run
   costs more than its key. *)
extraMatch[code_] := With[{f = extraFields[code]}, Append[extraPlace[Keys[$extraKinds][[First[f]]], Sequence @@ Rest[f]], {}]];

extraKey[code_] := With[{f = extraFields[code]}, extraKeyOf[Keys[$extraKinds][[First[f]]], Sequence @@ Rest[f]]];

(* The values of extra codes of the plain kinds, all at once, each token
   list split once. *)
extraValues[codes_] :=
  Module[{tokens},
    tokens[o_, j_] := tokens[o, j] = tokensOf[o, Keys[$readings][[j]]];
    MapThread[
      Switch[#1, 3, $elem[[#2 + 1, 3, #3]], 5, $elem[[#2 + 1, 3]], 6, tokens[#2, #3][[#4]], 8, tokens[#2, #3], 9, $elem[[$kids[[#2 + 1]] + 1]],
        10, $elem[[pathIds[#3 $B + #4, #2] + 1]]] &,
      Take[extraFields[codes], 4]]];

extraPlace["Run", o_, m_, n_, _] := {{Append[posOf[o], m ;; n]}, seq[$elem[[$kids[[o + 1, m ;; n]] + 1]]]};
(* A name compared by value keeps every position (mergedMatch); its order
   key is its first one's. *)
extraPlace["Repeat", o_, m_, n_, _] := With[{ids = $kids[[o + 1, m ;; n]]}, {posOf /@ ids, elemOf[First[ids]]}];
extraPlace["List", o_, __] := {{Append[posOf[o], 1 ;; Length[$kids[[o + 1]]]]}, $elem[[$kids[[o + 1]] + 1]]};
extraPlace["Contents", o_, __] := {{Append[posOf[o], All]}, $elem[[o + 1, 3]]};
extraPlace["Text", o_, k_, _, _] := With[{item = $elem[[o + 1, 3, k]]}, {{missingItem[item]}, item}];
(* A run of items: the run of the element children in it, or, if it holds
   text, no position. An empty run is the gap before the next element. *)
extraPlace["ContentsRun", o_, m_, n_, _] :=
  With[{items = $elem[[o + 1, 3]]},
    With[{run = items[[m ;; n]], e = Count[Take[items, m - 1], _XMLElement] + 1},
      {{If[Count[run, _XMLElement] == Length[run], Append[posOf[o], e ;; e + Length[run] - 1], missingItem[run]]}, seq[run]}]];
extraPlace["Path", j_, a_, b_, _] := With[{i = a $B + b}, {{posOf[i] ;; posOf[j]}, $elem[[pathIds[i, j] + 1]]}];
extraPlace["Token", o_, j_, k_, _] := With[{key = Keys[$readings][[j]]}, {{Join[posOf[o], {Key[key], k}]}, tokensOf[o, key][[k]]}];
extraPlace["TokenRun", o_, j_, m_, n_] := With[{key = Keys[$readings][[j]]}, {{Join[posOf[o], {Key[key], m ;; n}]}, seq[tokensOf[o, key][[m ;; n]]]}];
extraPlace["TokenList", o_, j_, __] := With[{key = Keys[$readings][[j]]}, {{Append[posOf[o], Key[key]]}, tokensOf[o, key]}];

extraKeyOf["Run", o_, m_, n_, _] := Join[elementKey[o], sequenceKey[4, m ;; n]];
extraKeyOf["Repeat", o_, m_, __] := elementKey[$kids[[o + 1, m]]];
extraKeyOf["List", o_, __] := Join[elementKey[o], sequenceKey[4, 1 ;; Length[$kids[[o + 1]]]]];
extraKeyOf["Contents", o_, __] := Join[elementKey[o], contentsKey[]];
extraKeyOf["Text", o_, k_, _, _] := Join[elementKey[o], textItemKey[Count[Take[$elem[[o + 1, 3]], k - 1], _XMLElement] + 1, k]];
extraKeyOf["ContentsRun", o_, m_, n_, _] :=
  With[{items = $elem[[o + 1, 3]]},
    With[{e = Count[Take[items, m - 1], _XMLElement] + 1}, Join[elementKey[o], sequenceKey[4, e ;; e + Count[items[[m ;; n]], _XMLElement] - 1]]]];
(* A path sorts by its lower end, then its upper end; its lower end's key
   is padded to the longest an element's can be, so that an element sorts
   before the paths that end at it, as the solutions engine's keys do once
   a query names a path (padded, Query/TreePatterns.wl). *)
extraKeyOf["Path", j_, a_, b_, _] := Join[PadRight[elementKey[j], $keyLength, $keyPad], elementKey[a $B + b]];
extraKeyOf["Token", o_, j_, k_, _] := Join[elementKey[o], tokenListKey[listAttribute[o, Keys[$readings][[j]]]], sequenceKey[2, k]];
extraKeyOf["TokenRun", o_, j_, m_, n_] := Join[elementKey[o], tokenListKey[listAttribute[o, Keys[$readings][[j]]]], sequenceKey[2, m ;; n]];
extraKeyOf["TokenList", o_, j_, __] := Join[elementKey[o], tokenListKey[listAttribute[o, Keys[$readings][[j]]]]];

(* What has no position: text, or another item that is not an element. *)
missingItem[v_] := Missing[If[!FreeQ[v, _String, {0, 1}], "Text", "Literal"]];

listAttribute[o_, key_] := attributeIndex[$elem[[o + 1, 2]], rawKeyOf[$readings[key]]];

(* The order key of an element's position (elemKey, Query/TreePatterns.wl). *)
elementKey[i_] := listMemo[{"Key", i}, Join @@ (sequenceKey[4, #] & /@ posOf[i])];

(* The order key of a code's position. *)
orderKey[c_] :=
  If[c < -1, extraKey[c],
    With[{i = Quotient[c, $K], s = Mod[c, $K]}, Join[elementKey[i], Switch[s, 0, {}, 1, tagKey[], 2, attributeMapKey[], _, attributeKey[s - 2]]]]];

(* Rows of codes, compared column by column, with the codes of a column
   that are not all on elements replaced by numbers in position order, -1,
   unbound, first. Codes on elements are in position order already, and so,
   backwards, are those of one plain kind and list key. *)
ranked[rows_] := If[Flatten[rows] === {} || Min[rows] >= -1, rows, Transpose[rankedColumn /@ Transpose[rows]]];

rankedColumn[col_] :=
  With[{extras = Select[col, # < -1 &]},
    Which[
      extras === {}, col,
      Max[col] < 0 && MatchQ[Union /@ Take[extraFields[extras], 3], {{k_}, _, a_} /; MemberQ[$plainKinds, k] && (Length[a] == 1 || !MemberQ[{6, 8}, k])],
        -col Unitize[col + 1],
      True,
        With[{u = DeleteCases[DeleteDuplicates[col], -1]},
          With[{keys = packed[With[{ks = orderKey /@ u}, PadRight[ks, {Length[ks], Max[Length /@ ks]}, $keyPad]]]},
            With[{order = Ordering[keys]},
              Lookup[
                Append[AssociationThread[u[[order]], Accumulate[Prepend[Unitize[Total /@ Abs[Differences[keys[[order]]]]], 1]]], -1 -> 0],
                col]]]]]];

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
  Block[{$K, $B, $t, $listMemo = <||>},
    $K := ($K = placeBase[]);
    $B := ($B = placeRadix[]);
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
      If[bare, $t = pickRows[$t, Times @@ Prepend[notBare /@ Lookup[$t, $counted], ConstantArray[1, rowCount[$t]]]]];
      If[rowCount[$t] == 0 || n < 1, Return[{}, Module]];
      If[directRowsQ[mode, rhs, all, testNames], Return[directResults[mode, rhs, n], Module]];
      $cols = Rest[Keys[$t]];
      $data = rowsOf[$cols];
      slots = DeleteDuplicates[Lookup[$slotOf, $counted, Null] /. Null -> Nothing];
      slots = SortBy[Join[slots, Select[$counted, !KeyExistsQ[$slotOf, #] &]], $order];
      keyRows = rowsOf[$counted];
      groups = GatherBy[Ordering[ranked[slotKeys[slots]]], keyRows[[#]] &];
      $testRows = ranked[rowsOf[SortBy[testNames, $order]]];
      reapedRows[
        While[count < n && k <= Length[groups],
          r = rowGroupResult[mode, rhs, all, testNames, groups[[k++]]];
          If[r =!= $noResult, count++; Sow[r, $rowTag]]]]]];

(* The results a loop sows, in order. *)
SetAttributes[reapedRows, HoldFirst];
reapedRows[loop_] := Replace[Reap[loop, $rowTag][[2]], {{l_} :> l, {} -> {}}];

$rowTag = Unique["row"];

(* The right-hand side is a counted name, or a list of them, none in an
   Alternatives slot, none tested, each always bound to one value at one
   position (plainCodesQ), and no Condition: each distinct tuple of codes
   is one result, in position order (ranked), and each result is made from
   codes, with no evaluation. *)
directRowsQ[mode_, rhs_, all_, testNames_] :=
  MatchQ[mode, "Values" | "Positions" | "CountedPositions"] && testNames === {} && guardedBody[rhs] === rhs &&
    !IntersectingQ[$counted, Keys[$slotOf]] && AllTrue[$counted, plainCodesQ[$t[#]] &] &&
    If[mode === "CountedPositions", First[rhsNames[rhs, all]] === $counted,
      MatchQ[$counted, {nm_} /; rhs === Hold @@ nm] || MatchQ[rhs, Hold[l_List] /; Sort[Thread[Hold[l]]] === Sort[$counted]]];

(* Codes of places on elements, or of plain kinds, never unbound. *)
plainCodesQ[col_] := Min[col] >= 0 || FreeQ[col, -1] && SubsetQ[$plainKinds, Union[First[extraFields[Select[col, # < -1 &]]]]];

(* Each result as resultOf makes it: the value or position of the name, the
   list of those of the names, or the list of the counted names'
   positions. *)
directResults[mode_, rhs_, n_] :=
  Module[{order = SortBy[$counted, $order], tuples, made},
    tuples = With[{u = DeleteDuplicates[rowsOf[order]]}, Take[u[[Ordering[ranked[u]]]], UpTo[n]]];
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
