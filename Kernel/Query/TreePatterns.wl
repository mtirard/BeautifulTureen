(* ::Package:: *)
(* HTMLPatterns: tree patterns, the result rule and positions *)

(* Used by DisplayRoles.wl, Query/Compiler.wl and Rewrite.wl *)
PackageScoped[namesIn]

(* Used by XMLFunctions.wl, for XMLMatchQ and XMLFreeQ *)
PackageScoped[plainRootQ]

(* Used by DisplayRoles.wl, Positions.wl, Rewrite.wl, Tree.wl and
   XMLFunctions.wl, which each name the output mode they run in *)
PackageScoped[compileQuery]
PackageScoped[runQuery]

(* Used by DisplayRoles.wl, Positions.wl, Rewrite.wl, Tree.wl and
   XMLFunctions.wl, to join the results of runQuery *)
PackageScoped[joinedResults]
PackageScoped[distinctPositions]

(* Used by Query/Columnar.wl, the query engine, which reads the index, the
   compiled nodes' vectors and the run's globals, and gives each result as
   resultOf makes it *)
PackageScoped[$elem]
PackageScoped[$parent]
PackageScoped[$kids]
PackageScoped[$depth]
PackageScoped[$end]
PackageScoped[$keyLength]
PackageScoped[$vectors]
PackageScoped[$readings]
PackageScoped[$slotOf]
PackageScoped[$order]
PackageScoped[$noResult]
PackageScoped[elemOf]
PackageScoped[childrenOf]
PackageScoped[posOf]
PackageScoped[nameMatch]
PackageScoped[candidateCounts]
PackageScoped[candidateVector]
PackageScoped[passesQ]
PackageScoped[resultOf]
PackageScoped[rhsNames]
PackageScoped[guardedBody]
PackageScoped[subNodes]
PackageScoped[seq]
PackageScoped[pathIds]
PackageScoped[nearestOf]
PackageScoped[refuseHere]
PackageScoped[desugared]

(* =========================================================== *)
(* Tree patterns (ADR 0023, 0024, 0025)                         *)
(*                                                              *)
(* XMLPattern[tag, attrs][c...] takes constraints on what is    *)
(* below the element (read by xmlPatternParts, Compiler.wl):    *)
(* list patterns over its element children, Child[p], which is  *)
(* the list {___, p, ___}, Descendant[p, levelspec], and        *)
(* alternatives of these; a named Descendant binds its path.    *)
(* XMLDocument[c...] takes the same constraints on the          *)
(* document. A query gives one result for each distinct tuple   *)
(* of positions of its counted names, the names its right-hand  *)
(* side uses; a bare pattern p is first r$ : p :> r$.           *)
(*                                                              *)
(* The input is indexed once: node 0 is the document, elements  *)
(* are numbered in preorder from 1. The query compiles to a     *)
(* tree of nodes, each projected onto the names something above *)
(* it needs ("Keep"), so an unnamed part, or a name nothing     *)
(* uses, costs a test and never an enumeration. The element's   *)
(* tag and attributes are tested by a plain WL pattern          *)
(* (Query/Compiler.wl). The query engine (Query/Columnar.wl)    *)
(* matches each node at every element at once, over the index   *)
(* and the vectors kept with it (keptVector).                   *)
(* =========================================================== *)

(* ---- The pattern as written ---- *)

(* What reads as a level spec, valid or not. *)
levelSpecFormQ[s_] := MatchQ[s, _Integer | DirectedInfinity[1] | {(_Integer | DirectedInfinity[1]) ..}];

(* A constraint as written: a list pattern, a Descendant, or alternatives of
   these, any of them named, conditioned or tested. *)
constraintFormQ[c_] := MatchQ[c, _List | _Descendant | _Shortest | _Longest] ||
  MatchQ[c, Verbatim[Pattern][_, x_] | Verbatim[Condition][x_, _] | Verbatim[PatternTest][x_, _] /; constraintFormQ[x]] ||
  MatchQ[c, _Alternatives] && AllTrue[List @@ c, constraintFormQ];

(* The names a held pattern binds, each Hold[name]. *)
namesIn[s_] :=
  DeleteDuplicates @ Cases[s, Verbatim[Pattern][n_Symbol, _] :> Hold[n], {0, Infinity}, Heads -> True];

(* Adjacent and Sibling were removed in 4.0.0 (ADR 0023). A query that
   still uses one holds it unevaluated, in the caller's context, so it is
   found by name; it is badpat, whose text gives the tree forms. Child is a
   constraint now, with messages of its own. *)
removedCombinatorQ[held_] :=
  !FreeQ[held, (h_Symbol /; MemberQ[{"Adjacent", "Sibling"}, SymbolName[Unevaluated[h]]])[___]];

(* =========================================================== *)
(* Running a query                                              *)
(*                                                              *)
(* A query is compiled once, from the query alone               *)
(* (compileQuery), then run on a tree in an output mode         *)
(* (runQuery), so a mistake in the query is reported before one *)
(* in the tree.                                                 *)
(* =========================================================== *)

(* The compiled query of q under head, an Association of all the run
   reads, or $Failed after a message under head. It reads the query, counted
   and the readings in force, never a tree. counted is None for the names
   the right-hand side uses (rhsNames), or else the counted names, each
   Hold[name], and the other names the right-hand side mentions are test
   names; or "Test", for an element test as XMLMatchQ and XMLFreeQ give one:
   the pattern itself, with nothing counted, so a run gives at most the
   empty tuple and stops at the first solution. A test refuses a rule, which
   gives results, and a context selector, which looks above the element.
   lists "Lists" lets a list pattern, in the contents-list grammar, be the
   root (XMLMatchQ's lists). Every node, a list key's value too
   (tokenListForms), is compiled here, so its id is fixed. *)
compileQuery[head_, q_, counted_ : None, lists_ : None] :=
  Catch[
    Block[{$head = head, $nodeId = 0, $order, $slotOf = <||>, $readings, $place = "query", $owner = XMLPattern,
        $exceptRefs, $records, $countedNames, $contextOK = counted =!= "Test"},
      Module[{lhs, rhs, all, names, root, listQ = lists === "Lists" && listRootQ[q]},
        If[counted === "Test",
          If[MatchQ[q, _Rule | _RuleDelayed], refuseHere["badpat", q]];
          {lhs, rhs} = {Hold[q], Hold[]},
          If[namedContextQ[q], refuseHere["badpat", q]];
          {lhs, rhs} = splitQuery[q]];
        If[removedCombinatorQ[lhs], refuseHere["badpat", q]];
        $readings = Replace[readingsInForce[], $Failed :> Throw[$Failed, $refusal]];
        all = namesIn[lhs];
        $order = patternOrder[lhs];
        names = Switch[counted,
          None, rhsNames[rhs, all],
          "Test", {{}, {}},
          _, {counted, Complement[mentioned[rhs, all], counted]}];
        $exceptRefs = exceptRefs[lhs];
        $countedNames = First[names];
        checkExcept[lhs, If[counted === None, First[names], Union @@ names]];
        $records = $exceptRefs =!= {};
        With[{need = Union[First[names], Last[names], comparedNames[lhs]]},
          root = If[listQ, listRoot[q, need], compileRoot[lhs, need]]];
        <|"Head" -> head, "Test" -> counted === "Test", "Root" -> root, "Rhs" -> rhs, "Names" -> all, "Counted" -> First[names],
          "TestNames" -> Last[names], "Readings" -> $readings, "Order" -> $order, "Slots" -> $slotOf,
          "Records" -> $records, "Lists" -> listQ, "Reach" -> reachBelow[root]|>]],
    $refusal];

(* The results of compiled query cq on tree, the first n of them in result
   order, each the list of what it splices in, or $Failed after a message
   under its head; a refused compile, $Failed, passes through. mode is what
   each result is (resultOf). roots is which nodes may be the pattern root:
   All, every node, as the searching consumers ask; "Input", the input
   itself, as XMLMatchQ tests it; or {lo, hi}, the nodes at relative DOM
   depths lo to hi, as XMLFreeQ tests them. Only All reads and writes the
   one-slot index cache: an element test applied to many small inputs would
   otherwise replace the index of the document being searched. *)
runQuery[$Failed, ___] := $Failed;
runQuery[cq_Association, tree_, mode_, n_ : Infinity, roots_ : All] :=
  Catch[
    With[{top = topNode[cq, tree, roots]},
      If[top === None, {},
        Block[{$head = cq["Head"], $readings = cq["Readings"], $order = cq["Order"], $slotOf = cq["Slots"],
            $indexDepth = indexDepth[roots, top, cq["Reach"]], $memo = <||>,
            $elem, $parent, $depth, $kids, $index, $end, $wlPos, $tops, $posMemo = <||>,
            $matElems = <||>, $vectors = <||>, $keyLength},
          onIndex[roots, tree, columnarResults[mode, cq, bareQ[roots, tree], n, rootNodes[cq["Root"], roots, top, tree]] &]]]],
    $refusal];

(* The results of a run joined, each spliced in, as in Cases; $Failed
   passes through. *)
joinedResults[rs_List] := Catenate[rs];
joinedResults[$Failed] := $Failed;

(* The distinct positions of a run in "CountedPositions", over all its
   results; $Failed passes through. *)
distinctPositions[rs_List] := DeleteDuplicates[Catenate[Catenate[rs]]];
distinctPositions[$Failed] := $Failed;

(* f[] run on the index of tree: for All, read from the one-slot cache and
   written back to it; otherwise indexed afresh, the cache untouched. *)
onIndex[All, tree_, f_] := (cachedIndexTree[tree]; With[{r = f[]}, keptIndex[tree]; r]);
onIndex[_, tree_, f_] := (indexTree[tree]; f[]);

(* Whether the input is a bare element whose own position is never counted
   (results): only when every node may be the root. *)
bareQ[All, tree_] := MatchQ[tree, _XMLElement];
bareQ[_, _] := False;

(* The node of tree the run is rooted at: the element, 1, or the document or
   the virtual document above a list's elements, 0; None, for "Input", when
   the pattern cannot take the input. For All and {lo, hi} a tree that is
   not one is refused. Only a list pattern takes a list, and it takes
   nothing else. *)
topNode[cq_, x_, "Input"] :=
  Which[
    cq["Lists"], If[ListQ[x] && validTreeQ[x], 0, None],
    MatchQ[x, _XMLElement], 1,
    MatchQ[x, XMLObject["Document"][_, _XMLElement, _]], 0,
    True, None];
topNode[cq_, x_, _] :=
  If[validTreeQ[x], If[MatchQ[x, _XMLElement], 1, 0], messageTreeRefusal[cq["Head"], x]; Throw[$Failed, $refusal]];

(* The DOM depth the input is indexed to: the node it is rooted at, 1 for an
   element, plus how far below it the pattern root may be, plus how far
   below that the pattern reads. It is bound for each run, so that a query
   in a Condition indexes its own input in full. *)
indexDepth[All, _, _] := Infinity;
indexDepth["Input", top_, reach_] := top + reach;
indexDepth[{_, hi_}, top_, reach_] := top + hi + reach;

(* The nodes tried as the pattern root (rootCandidates), in document order,
   or All for every candidate. A node of a depth range is tried only if the
   root can match it (candidateVector); the input is at depth 0, but a list
   is not a node: its elements are at depth 1. *)
rootNodes[_, All, _, _] := All;
rootNodes[_, "Input", top_, _] := {top};
rootNodes[root_, {lo_, hi_}, top_, x_] :=
  Select[Range[If[ListQ[x], 1, top], $end[[top + 1]]],
    lo <= $depth[[# + 1]] - top <= hi && (# == 0 || candidateVector[root][[#]] == 1) &];

(* query -> {Hold[lhs], Hold[rhs]}. A bare pattern is erased to r$ : p :> r$.
   A Rule's right-hand side was evaluated when the query was given, as in
   Cases; a Condition in its value is part of it, not a test. *)
splitQuery[r_RuleDelayed] := {Extract[r, {1}, Hold], Extract[r, {2}, Hold]};
splitQuery[r : Verbatim[Rule][_, _]] :=
  {Extract[r, {1}, Hold], Replace[Extract[r, {2}, Hold], Hold[c_Condition] :> Hold[Identity[c]]]};
splitQuery[p_] := Module[{r}, {Hold @@ {Pattern @@ {r, p}}, Hold[r]}];

(* A named context selector as the whole query: erased, it would give the
   elements it is rooted at, not its subjects (ADR 0026). *)
namedContextQ[Verbatim[Pattern][_, p_]] := AnyTrue[rootStrings[p], cssContextQ];
namedContextQ[(Verbatim[Condition] | Verbatim[PatternTest])[p_, _]] := namedContextQ[p];
namedContextQ[alts_Alternatives] := AnyTrue[List @@ alts, namedContextQ];
namedContextQ[_] := False;

(* The strings at the root of a pattern, under its names, Conditions, tests
   and Alternatives. *)
rootStrings[s_String] := {s};
rootStrings[(Verbatim[Pattern][_, p_]) | (Verbatim[Condition] | Verbatim[PatternTest])[p_, _]] := rootStrings[p];
rootStrings[alts_Alternatives] := Join @@ (rootStrings /@ List @@ alts);
rootStrings[_] := {};

cssContextQ[s_] := MatchQ[Quiet[cssTree[s]], {"context", _}];

(* Those of names that held code mentions. *)
mentioned[held_, names_] := Select[names, !FreeQ[held, Replace[#, Hold[s_] :> HoldPattern[s]]] &];

(* Pattern order: the order names first appear, reading the pattern as written. *)
patternOrder[held_] :=
  With[{ps = LexicographicSort @ Position[held, Verbatim[Pattern][_Symbol, _], {0, Infinity}, Heads -> True]},
    Association @ MapIndexed[#1 -> First[#2] &,
      DeleteDuplicates[Extract[held, Append[#, 1], Hold] & /@ ps]]];

(* ---- Counted names (ADR 0024) ---- *)

(* {counted, test names}: the names in the right-hand side outside the tests
   of its Conditions, and the names only in those tests. *)
rhsNames[rhs_Hold, all_] :=
  With[{parts = rhsParts[rhs]},
    With[{counted = mentioned[parts[[1]], all]}, {counted, Complement[mentioned[parts[[2]], all], counted]}]];

(* {body, tests}: the held code whose names count, and the held tests. A
   Condition is a test where Replace takes it as one: at the top, or at the
   top of a With, Module or Block. Through With, a name in an initialiser is
   where the variable it initialises is, followed to a fixed point. In a
   Module or Block that has a test every name counts. *)
rhsParts[Hold[Verbatim[Condition][b_, t_]]] := {Hold[b], Hold[t]};
rhsParts[Hold[With[vs_List, b_]]] :=
  With[{inner = rhsParts[Hold[b]], inits = Cases[Hold[vs], (Set | SetDelayed)[v_Symbol, i_] :> {Hold[v], Hold[i]}, {2}]},
    With[{inBody = varsReached[inner[[1]], inits]},
      {Join[inner[[1]], initsOf[inits, inBody]],
        Join[inner[[2]], initsOf[inits, Complement[varsReached[inner[[2]], inits], inBody]]]}]];
rhsParts[h : Hold[(Module | Block)[_, b_]]] /; bodyConditionQ[Hold[b]] := {h, Hold[]};
rhsParts[h_Hold] := {h, Hold[]};

(* The With variables held code reaches, directly or through initialisers. *)
varsReached[held_, inits_] :=
  FixedPoint[Union[#, mentioned[initsOf[inits, #], inits[[All, 1]]]] &, mentioned[held, inits[[All, 1]]]];

initsOf[inits_, vars_] := Join[Hold[], Sequence @@ Cases[inits, {v_, i_} /; MemberQ[vars, v] :> i]];

(* A name bound only inside Except has no value outside it.
   In Except[c, p] the names in p are bound, as in WL; those in c are not,
   unless they are also bound outside every Except's c, and then they refer
   to that match (exceptRefs). *)
checkExcept[lhs_, counted_] :=
  Replace[Complement[Intersection[namesIn[exceptTests[lhs]], counted], $exceptRefs],
    {Hold[s_], ___} :> refuseHere["exceptname", HoldForm[s]]];

(* The c of each Except[c, ...] in a held pattern, held together. *)
exceptTests[held_] := Join @@ Cases[held, Verbatim[Except][c_, ___] :> Hold[c], {0, Infinity}, Heads -> True];

(* The held pattern without the c of any Except: where names are bound. *)
outsideExcept[held_] := held /. Verbatim[Except][_, r___] :> Except[Null, r];

(* The names inside an Except's c that are also bound outside every
   Except's c. *)
exceptRefs[held_] := Intersection[namesIn[exceptTests[held]], namesIn[outsideExcept[held]]];

(* The names the engine needs whatever the right-hand side uses: a repeated
   name, to compare its matches; a name an Except refers to, and the record
   of each such Except, to settle it. *)
comparedNames[held_] :=
  With[{refs = exceptRefs[held]},
    Union[repeatedNames[held], refs,
      DeleteCases[exceptKey[Intersection[namesIn[Hold[#]], refs]] & /@ List @@ (Hold /@ exceptTests[held]), exceptKey[{}]]]];

(* The names bound more than once: at two places not in different branches
   of one Alternatives, or inside Repeated, which binds at each repeat. *)
repeatedNames[held_] :=
  With[{h = outsideExcept[held]},
    Keys @ Select[
      GroupBy[Position[h, Verbatim[Pattern][_Symbol, _], {0, Infinity}, Heads -> True], Extract[h, Append[#, 1], Hold] &],
      Length[#] > 1 && AnyTrue[Subsets[#, {2}], !alternativeBranchesQ[h, #] &] || AnyTrue[#, repeatedInsideQ[h, #] &] &]];

alternativeBranchesQ[h_, {p_, q_}] :=
  MatchQ[Extract[h, Take[p, LengthWhile[Transpose[{Take[p, Min[Length[p], Length[q]]], Take[q, Min[Length[p], Length[q]]]}], Apply[SameQ]]], Hold],
    Hold[_Alternatives]];

repeatedInsideQ[h_, p_] :=
  AnyTrue[Range[Length[p] - 1], MatchQ[Extract[h, Take[p, #], Hold], Hold[_Repeated | _RepeatedNull]] && p[[# + 1]] == 1 &];

(* MessageName holds its first argument, so the consumer head is injected. *)
refuseHere[tag_, args___] := With[{h = $head}, refuse[MessageName[h, tag], args]];
(* A query of HTMLToTree's "Focus" or "Hide" that is not a pattern is the
   option's mistake, badquery. *)
refuseHere["badpat" | "blank", x_] /; $queryOption =!= None := (badQuery[$queryOption, x]; Throw[$Failed, $refusal]);

(* =========================================================== *)
(* The index                                                    *)
(* =========================================================== *)

(* The top elements, numbered with the rest in preorder. Built with
   whole-tree operations rather than a walk. A bare element is the one top
   element, {1}, under a virtual document whose value is {e}. Only the
   elements to DOM depth $indexDepth are indexed: an element test reads no
   deeper than its pattern reaches. *)
$indexDepth = Infinity;

indexTree[input_] :=
  Module[{ps, n, pid, groups},
    $tops = topItems[input];
    ps = Position[$tops, _XMLElement, {1, 2 $indexDepth - 1}, Heads -> False];
    ps = ps[[Ordering[PadRight[ps, Automatic, 0]]]];
    n = Length[ps];
    pid = AssociationThread[ps -> Range[n]];
    $wlPos = ps;
    $elem = Prepend[Extract[$tops, ps], Replace[input, x_XMLElement :> {x}]];
    $parent = Prepend[Lookup[pid, Key /@ (If[Length[#] == 1, {}, Drop[#, -2]] & /@ ps), 0], -1];
    $depth = Prepend[(Length /@ ps + 1)/2, 0];
    groups = GroupBy[Range[n], $parent[[# + 1]] &];
    $kids = Prepend[Lookup[groups, Range[n], {}], Lookup[groups, 0, {}]];
    $index = ConstantArray[0, n + 1];
    Scan[($index[[# + 1]] = Range[Length[#]]) &, Values[groups]];
    $end = Prepend[subtreeEnds[Rest[$depth]], n];
    $keyLength = 3 Max[$depth] + 8];

(* The index of the input of the last query, the elements it
   materialised for each set of readings, the positions and order keys
   of the elements it read, and the vectors over the elements its compiled
   nodes computed (keptVector), are kept for the next: a
   document is often queried many times, and indexing it costs about 50 ms
   at 8,000 elements. An input that is the same expression, which SameQ
   tells at once when it is the one given before, reuses them. *)
$indexCache = {None, None, {}};

(* The vectors kept are dropped together once there are more than this, so
   that many different queries of one large document do not hold a vector
   of its size each. *)
$keptVectors = 200;

(* A vector over the elements that depends only on the index and on what a
   node is, its static key (keyed): kept with the index, so that the same
   node in another query, or the same query again, finds it. For a node
   with no key it is kept for this run only, as other memos are. *)
SetAttributes[keptVector, HoldRest];
keptVector[{tag_, id_, None}, v_] := memoised[{tag, id}, v];
keptVector[{tag_, id_, key_}, v_] := memoised[{tag, id}, Lookup[$vectors, Key[{tag, key}], $vectors[{tag, key}] = v]];

cachedIndexTree[input_] :=
  If[cachedQ[input],
    {$tops, $wlPos, $elem, $parent, $depth, $kids, $index, $end, $keyLength, $matElems, $posMemo, $vectors} = $indexCache[[3]],
    indexTree[input];
    keepIndex[input]];

cachedQ[input_] := $indexCache[[2]] === $indexDepth && $indexCache[[1]] === input;

keepIndex[input_] :=
  $indexCache = {input, $indexDepth, {$tops, $wlPos, $elem, $parent, $depth, $kids, $index, $end, $keyLength, $matElems, $posMemo,
    If[Length[$vectors] > $keptVectors, <||>, $vectors]}};

(* What a query read is kept when it ends, unless a query in its right-hand
   side, on another input, has replaced the cache meanwhile. *)
keptIndex[input_] := If[cachedQ[input], keepIndex[input]];

(* A bare element with nothing below it read, as an element test of an
   XMLPattern without constraints is: its index, set directly. *)
indexTree[x_XMLElement] /; $indexDepth == 1 :=
  ($tops = {x}; $wlPos = {{1}}; $elem = {{x}, x}; $parent = {-1, 0}; $depth = {0, 1};
    $kids = {{1}, {}}; $index = {0, 1}; $end = {1, 1}; $keyLength = 11);

(* The last node of each subtree: the node before the next one, in preorder,
   that is no deeper. *)
subtreeEnds[{}] := {};
subtreeEnds[d_] :=
  Module[{n = Length[d], end},
    end = ConstantArray[n, n];
    Do[
      With[{s = Flatten @ Position[UnitStep[k - d], 1]},
        With[{next = Append[Rest[s] - 1, n], hosts = Flatten @ Position[d[[s]], k]},
          end[[s[[hosts]]]] = next[[hosts]]]],
      {k, Union[d]}];
    end];

elemOf[i_] := $elem[[i + 1]];
childrenOf[i_] := $kids[[i + 1]];

(* The element's position: element-child indices from the document. *)
posOf[0] := {};
posOf[i_] := Lookup[$posMemo, i, $posMemo[i] = Append[posOf[$parent[[i + 1]]], $index[[i + 1]]]];

(* The elements as the compiled tests of one set of readings see them:
   materialised once per set, over the indexed input, which moves no element. *)
materialElems[{}] := Rest[$elem];
materialElems[r_] := Lookup[$matElems, Key[r], $matElems[r] = Extract[materialise[$tops, r, {1, 2 $indexDepth - 1}], $wlPos]];

(* =========================================================== *)
(* Matches                                                      *)
(* =========================================================== *)

(* A name's match, as resultOf reads it: its positions and its value. A
   repeated name compared by value has several positions, in position
   order. A sequence's value is seq[list]. *)
nameMatch[pos_, val_] := {pos, val};
matchPos[b_] := b[[1]];
matchVal[b_] := b[[2]];

(* =========================================================== *)
(* Compilation                                                  *)
(* =========================================================== *)

(* A node is an Association: "Kind", "Id", "Names" (every name bound below
   it, with Alternatives slots), "Keep" (those something above needs), the
   kind's own fields, and the facts about it that do not depend on the tree
   (withFacts). *)
treeNode[kind_, names_, need_, rest___] :=
  withFacts @ <|"Kind" -> kind, "Id" -> ++$nodeId, "Names" -> names, "Keep" -> Intersection[names, need], rest|>;

(* The facts, computed once, as the node is compiled, from those of the
   nodes below it, so that matching reads them instead of working them out
   at each element:
   - "Captures": whether the walk of a list must branch at an entry: it
     binds a needed name, or tests a span;
   - "MinItems": the fewest items an entry, or a list of entries, can match;
   - "MinKids": the fewest element children an element needs to meet a
     constraint, or all the constraints of a pattern root;
   - "Exact": whether a pattern root's candidates are exactly its matches:
     it tests only an element's tag and attributes, which the compiled test
     decides;
   - "CandidateKey" and "FilterKey": what a pattern root's candidates, and a
     constraint's filter on them, are computed from, under which the
     vectors over the elements are kept with the index (keptVector); None
     when a test in it may give another result in another query.
   Each is computed with those before it on the node. *)
withFacts[nd_] :=
  Fold[Append[#1, #2[[1]] -> #2[[2]][#1]] &, nd,
    {{"Captures", capturesQ}, {"MinItems", minItems}, {"MinKids", minKids}, {"Exact", exactQ},
      {"FilterKey", filterKey}, {"CandidateKey", candidateKey}}];

capturesQ[nd_] := nd["Keep"] =!= {} || nd["Kind"] === "SeqCond" ||
  MatchQ[nd["Kind"], "Run" | "Repeat"] && AnyTrue[nd["Items"], #["Captures"] &] ||
  nd["Kind"] === "Branches" && AnyTrue[Flatten[nd["Subs"]], #["Captures"] &];

minItems[nd_] := Switch[nd["Kind"],
  "One" | "Not", 1,
  "Any", nd["Min"],
  "Run" | "Seq" | "List" | "ContentsList" | "TokenList", itemsMin[nd["Items"]],
  "SeqCond", nd["Sub"]["MinItems"],
  "Repeat", nd["Min"] itemsMin[nd["Items"]],
  "Branches", Min[itemsMin /@ nd["Subs"]],
  _, 0];

itemsMin[items_List] := Total[#["MinItems"] & /@ items];

minKids[nd_] := Switch[nd["Kind"],
  "List", nd["MinItems"],
  "ListNamed" | "ListCond" | "ListTest" | "PathNamed" | "PathTest" | "PathCond" | "PathNearest", nd["Sub"]["MinKids"],
  "Descendant", 1,
  "ConstraintAlt", Min[#["MinKids"] & /@ nd["Subs"]],
  "XMLPattern" | "XMLDocument", Max[0, #["MinKids"] & /@ nd["Constraints"]],
  _, 0];

exactQ[nd_] := Switch[nd["Kind"],
  "XMLPattern", nd["Constraints"] === {},
  "Blank", nd["Head"] === {},
  "Named", nd["Sub"]["Exact"],
  "Alt", AllTrue[nd["Subs"], #["Exact"] &],
  _, False];

(* As candidates and constraintFilter compute the vectors. *)
candidateKey[nd_] := Switch[nd["Kind"],
  "Named" | "Cond" | "Test", nd["Sub"]["CandidateKey"],
  "Alt", keyed[{"Alt", #["CandidateKey"] & /@ nd["Subs"]}],
  "XMLPattern", keyed[{"XMLPattern", nd["HeadKey"], nd["MinKids"], #["FilterKey"] & /@ nd["Constraints"]}],
  "XMLDocument", {"Document"},
  _, {"All"}];

filterKey[nd_] := Switch[nd["Kind"],
  "List", keyed[{"Parents", #["Sub"]["CandidateKey"] & /@ Select[nd["Items"], #["Kind"] === "One" &]}],
  "ListNamed" | "ListCond" | "ListTest" | "PathNamed" | "PathTest" | "PathCond" | "PathNearest", nd["Sub"]["FilterKey"],
  "Descendant", keyed[{"Below", nd["Sub"]["CandidateKey"]}],
  _, {"All"}];

keyed[k_] := If[FreeQ[k, None], k, None];

(* The key of the test of an XMLPattern's tag and attributes: its compiled
   pattern, with the names numbered in the order they appear, as a selector
   names its own afresh each time it is compiled, and its readings. None
   when the pattern holds a symbol of the caller's, as a test or Condition
   can, whose meaning may change between two queries. *)
headKey[plain_, readings_] :=
  With[{names = DeleteDuplicates @ Cases[Hold[plain], Verbatim[Pattern][s_Symbol, _] :> Hold[s], {0, Infinity}, Heads -> True]},
    With[{key = Hold[plain] /. MapIndexed[Replace[#1, Hold[s_] :> (HoldPattern[s] -> nameNumber[First[#2]])] &, names]},
      If[AllTrue[Cases[key /. (b : Verbatim[Blank] | Verbatim[BlankSequence] | Verbatim[BlankNullSequence])[_Symbol] :> b[],
            s_Symbol :> Hold[s], {0, Infinity}, Heads -> True], ownSymbolQ],
        {key, readings}, None]]];

(* A symbol of the language or of this paclet. A blank's head is only
   compared, so it is left out above. *)
ownSymbolQ[Hold[s_]] := StringStartsQ[Context[Unevaluated[s]], {"System`", "MaximilienTirard`HTMLPatterns`"}];

compileRoot[Hold[lhs_], need_] := cRoot[lhs, need];

(* ---- Pattern roots ---- *)

cRoot[Verbatim[Pattern][s_Symbol, p_], need_] :=
  With[{name = Hold[s]}, If[$place === "literal", refuseText[name, p]];
    With[{sub = cRoot[p, need]}, treeNode["Named", Union[sub["Names"], {name}], need, "Name" -> name, "Sub" -> sub]]];

cRoot[c_Condition, need_] :=
  With[{test = Extract[c, {2}, Hold]},
    With[{sub = cRoot[c[[1]], conditionNeed[c, test, need]]}, conditionNode["Cond", sub, test, need]]];

cRoot[Verbatim[PatternTest][p_, f_], need_] :=
  With[{sub = cRoot[p, need]}, treeNode["Test", sub["Names"], need, "Sub" -> sub, "F" -> f]];

(* The branches of one Alternatives share a slot in the result order, a
   hidden name that binds where the Alternatives matched. *)
cRoot[alts_Alternatives, need_] :=
  With[{subs = cRoot[#, need] & /@ List @@ alts}, alternativesNode["Alt", subs, #["Names"] & /@ subs, need]];

(* XMLDocument[c...] matches only the document, node 0, and is a pattern
   root only: alone, or under the names, Conditions, tests and Alternatives
   above it. *)
cRoot[XMLDocument[cs___], need_] /; $place === "query" :=
  Block[{$owner = XMLDocument},
    With[{cons = cConstraints[{cs}, need]},
      treeNode["XMLDocument", Union @@ Prepend[#["Names"] & /@ cons, {}], need, "Constraints" -> cons]]];
cRoot[x_XMLDocument, _] := If[$place === "entry", refuseListEntry[x, "document"], refuse[XMLDocument::place, x]];

cRoot[x_ /; xmlPatternFormQ[x], need_] := cTreePattern[xmlPatternPartsOrRefuse[x, refuseHere["badpat", #] &], need];

cRoot[x_XMLElement, need_] := cLiteral[x, need];

refuseDocumentIn[x_] := If[!FreeQ[x, _XMLDocument], refuse[XMLDocument::place, FirstCase[x, _XMLDocument, Null, {0, Infinity}]]];

(* A string is a CSS selector, and means its translation (ADR 0026); in
   an XMLElement pattern's contents it is literal text. A one-element
   selector is its pattern wherever a pattern goes. A context selector is a
   pattern only with its subject named, so it is taken only named, as the
   pattern root of a query that searches: the erasure of a bare query names
   it there, and on the left of a rule the user names it. *)
cRoot[s_String, need_] /; $place === "literal" := plainNode[s, need];
cRoot[s_String, need_] :=
  Replace[cssTree[s], {
    $Failed :> Throw[$Failed, $refusal],
    {"context", _} :> refuseHere["badpat", s],
    {"one", t_} :> translationRoot[t, need]}];

(* A selector string with constraints, "sel"[c...] (bracketedTree,
   CSSSelector.wl), is a pattern wherever a selector string is. *)
cRoot[x_ /; bracketedFormQ[x], need_] /; $place =!= "literal" :=
  Replace[bracketedTree[x], {$Failed :> Throw[$Failed, $refusal], {"one", t_} :> translationRoot[t, need]}];

cRoot[Verbatim[Pattern][n_Symbol, s_String], need_] /; $place === "query" && $contextOK :=
  translationRoot[Replace[cssNamedTree[s, n], $Failed :> Throw[$Failed, $refusal]], need];

(* A name on alternatives is the name on each, so that each context selector
   among them is named. *)
cRoot[Verbatim[Pattern][n_Symbol, alts_Alternatives], need_] /;
    $place === "query" && $contextOK && AnyTrue[List @@ alts, StringQ[#] && cssContextQ[#] &] :=
  cRoot[Pattern @@ Hold[n, #] & /@ alts, need];

(* The translation's own names are needed only by its own repeats and
   Excepts; its Conditions keep the names they test themselves. *)
translationRoot[t_, need_] :=
  Block[{$exceptRefs = Union[$exceptRefs, exceptRefs[Hold[t]]]}, $records = $records || $exceptRefs =!= {};
    cRoot[t, Union[need, comparedNames[Hold[t]]]]];

(* Whether a context selector can be the pattern root: in a query that
   searches, not in an element test. *)
$contextOK = False;

(* A blank is any one element child in a contents list; as the whole query,
   or as Descendant's pattern, it is refused, as it reads as matching text. *)
cRoot[b : Verbatim[Blank][h___], need_] :=
  If[MatchQ[$place, "entry" | "literal"], treeNode["Blank", {}, need, "Head" -> {h}], refuseBlank[b]];
cRoot[b : (_BlankSequence | _BlankNullSequence), _] := refuseBlank[b];

(* The old two-pattern form, Descendant[a, b], is a level spec that is not
   one, wherever it is. *)
cRoot[d : Descendant[_, s_, ___], _] /; Length[d] > 2 || !levelSpecFormQ[s] :=
  refuse[Descendant::level, If[Length[d] == 2, s, d]];
cRoot[d_Descendant, _] :=
  Switch[$place,
    "entry", refuseListEntry[d, "descendant"],
    "query" | "literal", refuse[Descendant::place, d],
    _, refuseHere["badpat", d]];
(* Child is a constraint only, an argument of a constraint bracket, which
   cConstraints expands before this. *)
cRoot[c_Child, _] := If[$place === "entry", refuseListEntry[c, "child"], refuse[Child::place, c]];
cRoot[l_List, _] /; $place === "entry" := refuseListEntry[l, "list"];
(* Any other pattern in an XMLElement pattern's contents is WL's, over one
   item: an element or text. *)
cRoot[x_, need_] /; $place === "literal" := (Scan[Apply[refuseText], wholeItemNames[x]]; plainNode[x, need]);
cRoot[x_, _] := refuseHere["badpat", x];

refuseBlank[b_] := If[$place === "descendant", refuse[Descendant::blank, b], refuseHere["blank", b]];

(* The message is the list's owner's: XMLPattern's or XMLDocument's. *)
refuseListEntry[x_, reason_] := With[{h = $owner}, refuse[MessageName[h, "listentry"], x, $listEntryReasons[reason]]];

$listEntryReasons = <|
  "document" -> "An entry is one element child or a sequence of them, and XMLDocument[...] is the document above every element. It can only be the outermost pattern, as in XMLDocument[Child[x : p]].",
  "descendant" -> "An entry is one element child or a sequence of them, and Descendant[...] is a constraint on what is somewhere below an element. A child containing x is XMLPattern[_][Descendant[x]].",
  "child" -> "An entry is one element child or a sequence of them, and Child[...] requires some child of an element to match. A child with a child x is XMLPattern[_][Child[x]].",
  "list" -> "An entry is one element child or a sequence of them, not a list. Several constraints on one element are separate arguments of its bracket, as in XMLPattern[tag][c1, c2]."|>;

(* What a Condition sees: the names bound inside its sub-pattern, not those
   bound above it or before it in the pattern, nor a name on the Condition
   itself, as in WL. Another name it mentions stays an unbound symbol. The
   names it tests are kept up to it (conditionNeed), and no further. *)
conditionNode[kind_, sub_, test_, need_] :=
  treeNode[kind, sub["Names"], need, "Sub" -> sub, "Test" -> test, "Sees" -> mentioned[test, Cases[sub["Names"], _Hold]]];

conditionNeed[c_, test_, need_] := Union[need, mentioned[test, namesIn[Extract[c, {1}, Hold]]]];

alternativesNode[kind_, subs_, namesBy_, need_] :=
  With[{names = Union @@ Prepend[namesBy, {}], slot = "Slot" <> ToString[$nodeId + 1]},
    With[{slotted = IntersectingQ[names, need]},
      If[slotted, Scan[($slotOf[#] = slot) &, names]; $order[slot] = Min[Lookup[$order, names, Infinity]] - 1/2];
      treeNode[kind, If[slotted, Append[names, slot], names], If[slotted, Append[need, slot], need],
        "Subs" -> subs, "Slot" -> If[slotted, slot, None]]]];

(* ---- XMLPattern ---- *)

(* The tag and attributes are tested by today's compiled XMLPattern, on the
   elements materialised for its readings; the names in them that something
   needs are bound here, from the original element. *)
cTreePattern[{{tag_}, cs_}, need_] := cTreePattern[{{tag, _}, cs}, need];
cTreePattern[{{tag_, attrs_}, {cs___}}, need_] :=
  Module[{c, headNames, tokenLists, cons},
    If[!FreeQ[attrs, _Descendant], refuse[Descendant::place, FirstCase[attrs, _Descendant, Null, {0, Infinity}]]];
    refuseDocumentIn[{tag, attrs}];
    c = Replace[compileWith[XMLPattern[tag, attrs], $head, $readings], $Failed :> Throw[$Failed, $refusal]];
    headNames = namesIn[Hold[{tag, attrs}]];
    tokenLists = tokenListForms[attrs, Intersection[headNames, need]];
    cons = Block[{$owner = XMLPattern}, cConstraints[{cs}, need]];
    treeNode["XMLPattern", Union[headNames, Union @@ Prepend[#["Names"] & /@ cons, {}]], need,
      "Plain" -> c["Plain"], "Readings" -> c["Readings"], "Tag" -> tag, "Attrs" -> attrs,
      "HeadNames" -> Intersection[headNames, need], "Constraints" -> cons,
      "TokenLists" -> tokenLists, "HeadKey" -> headKey[c["Plain"], c["Readings"]]]];


(* ---- The token list of a list key ----

   The value of each rule on a list key, read as the matcher reads it at a
   token list (desugared, ADR 0011), compiled with the rest of the query: an
   Association from the value to its node. A mistake in it is so refused
   whatever the tree holds, and whether or not a name in it is needed. *)
tokenListForms[attrs_, need_] :=
  Association[# -> cTokenList[#, need] & /@ DeleteDuplicates[listKeyValues[attrs]]];

listKeyValues[Verbatim[Pattern][_, a_] | Verbatim[PatternTest][a_, _]] := listKeyValues[a];
listKeyValues[r_Rule] := listKeyValues[{r}];
listKeyValues[rules_List] :=
  Cases[Replace[rules, k_?literalKeyQ :> (k -> _), {1}],
    Verbatim[Rule][k_, v_] /; AnyTrue[keyLiterals[k], KeyExistsQ[$readings, #] &] :>
      If[AllTrue[keyLiterals[k], KeyExistsQ[$readings, #] &], desugared[v], v]];
listKeyValues[_] := {};

(* A string, or alternatives of strings, is a token in the list (ADR 0011). *)
desugared[s : (_String | Verbatim[Alternatives][__String])] := {___, s, ___};
desugared[v_] := v;

cTokenList[Verbatim[Pattern][s_Symbol, p_], need_] :=
  With[{name = Hold[s]},
    With[{sub = cTokenList[p, need]}, treeNode["TokenNamed", Union[sub["Names"], {name}], need, "Name" -> name, "Sub" -> sub]]];
(* The test sees every name in the Condition. *)
cTokenList[c_Condition, need_] :=
  With[{test = Extract[c, {2}, Hold], inner = namesIn[Hold[c]]},
    With[{sub = cTokenList[c[[1]], conditionNeed[c, test, need]]},
      treeNode["TokenCond", inner, need, "Sub" -> sub, "Test" -> test, "Sees" -> inner]]];
(* The compiled XMLPattern has already run the test. *)
cTokenList[Verbatim[PatternTest][p_, _], need_] := cTokenList[p, need];
cTokenList[l_List, need_] :=
  With[{items = Block[{$place = "token", $single = cToken}, cItems[l, need]]},
    treeNode["TokenList", Union @@ Prepend[#["Names"] & /@ items, {}], need, "Items" -> items]];
cTokenList[p_, need_] := treeNode["TokenPlain", namesIn[Hold[p]], need, "Pattern" -> p];

(* One token: any WL pattern, each name in it matching the token. *)
cToken[p_, need_] := With[{names = namesIn[Hold[p]]}, treeNode["Token", names, need, "Pattern" -> p]];

(* ---- XMLElement patterns (ADR 0023) ----

   An XMLElement pattern keeps WL's literal meaning: its contents are every
   item, elements and text, and its attributes the raw rule list. One with
   no XMLPattern in it and no name anything needs is matched whole. Any
   other is matched by its parts: the tag and attributes as WL patterns, and
   a contents list walked over the items as a contents list is over element
   children, its entries patterns over one item ($place "literal"), so that
   XMLPatterns nested in it are matched as anywhere else, every way it
   matches is found, and a name in it has the position of what it binds. *)
cLiteral[x : XMLElement[t_, a_, c_], need_] :=
  With[{names = namesIn[Hold[x]]},
    refuseDocumentIn[x];
    If[!FreeQ[x, _Descendant], refuse[Descendant::place, FirstCase[x, _Descendant, Null, {0, Infinity}]]];
    If[FreeQ[x, _XMLPattern] && !IntersectingQ[names, need],
      treeNode["Literal", names, need, "Pattern" -> x],
      With[{sub = Block[{$place = "literal"}, cContents[c, need]], headNames = namesIn[outsideExcept[Hold[{t, a}]]]},
        treeNode["LiteralParts", Union[headNames, sub["Names"]], need, "Tag" -> t, "Attrs" -> a, "Slots" -> literalSlots[x],
          "TagNames" -> Intersection[namesIn[outsideExcept[Hold[t]]], need],
          "AttrsNames" -> Intersection[namesIn[outsideExcept[Hold[a]]], need], "Sub" -> sub]]]];
cLiteral[x_XMLElement, _] := refuseHere["badpat", x];

(* The names on the slots of an XMLElement pattern: 0 the tag, Key[All] the
   attributes, All the contents (ADR 0025). *)
literalSlots[XMLElement[t_, a_, c_]] :=
  Association @ Cases[{{Hold[t], 0}, {Hold[a], Key[All]}, {Hold[c], All}}, {Hold[Verbatim[Pattern][s_Symbol, _]], k_} :> (Hold[s] -> k)];
literalSlots[_] := <||>;

(* The contents slot: a list is walked over the items when it holds an
   XMLPattern or a needed name; anything else is matched whole. *)
cContents[Verbatim[Pattern][s_Symbol, p_], need_] :=
  With[{name = Hold[s]},
    With[{sub = cContents[p, need]}, treeNode["ContentsNamed", Union[sub["Names"], {name}], need, "Name" -> name, "Sub" -> sub]]];
cContents[c_Condition, need_] :=
  With[{test = Extract[c, {2}, Hold]},
    With[{sub = cContents[c[[1]], conditionNeed[c, test, need]]}, conditionNode["ContentsCond", sub, test, need]]];
cContents[Verbatim[PatternTest][p_, f_], need_] :=
  With[{sub = cContents[p, need]}, treeNode["ContentsTest", sub["Names"], need, "Sub" -> sub, "F" -> f]];
cContents[l_List, need_] /; !FreeQ[l, _XMLPattern] || IntersectingQ[namesIn[outsideExcept[Hold[l]]], need] :=
  With[{items = Block[{$single = cRoot}, cItems[l, need]]},
    treeNode["ContentsList", Union @@ Prepend[#["Names"] & /@ items, {}], need, "Items" -> items]];
cContents[p_, need_] := plainNode[p, need];

(* A WL pattern matched whole against one value: an item, or a literal's
   contents. Names inside an Except in it are its own (outsideExcept). *)
plainNode[p_, need_] :=
  With[{names = namesIn[outsideExcept[Hold[p]]]}, treeNode["Plain", names, need, "Pattern" -> p]];

(* A counted name that can bind text is refused: text has no position. It is
   decided from the pattern, where a name is on an entry of a literal's
   contents list or binds the whole item inside another WL pattern on one
   (wholeItemNames), so that a query is refused on every tree, also on one
   with no text there. A name deeper in a WL pattern binds part of a
   compound expression, never a string, so no case is left to the run. *)
refuseText[name_, p_] :=
  If[MemberQ[$countedNames, name] && admitsTextQ[p], refuseHere["text", Replace[name, Hold[s_] :> HoldForm[s]]]];

(* The forms other than a name that match only what their pattern q
   matches, and those that match what one of their arguments matches. *)
transparentForm[q_] :=
  Verbatim[PatternTest][q, _] | Verbatim[Condition][q, _] |
    (Verbatim[Repeated] | Verbatim[RepeatedNull] | Verbatim[Optional] | Shortest | Longest)[q, ___] |
    Verbatim[Except][_, q] | Verbatim[HoldPattern][q] | Verbatim[IgnoringInactive][q];
$itemAlternatives = _Alternatives | Verbatim[PatternSequence][__] | Verbatim[OrderlessPatternSequence][__];

(* Whether an entry of a literal's contents list can match text: a string,
   a blank or sequence with no head or the head String, an Except of one
   item, or a Verbatim string; through names, tests, Conditions, repeats
   and alternatives. An XMLPattern, an XMLElement pattern, a blank with
   another head, or any other expression with a head, matches no string. *)
admitsTextQ[p_] :=
  MatchQ[p, _String | (Verbatim[Blank] | Verbatim[BlankSequence] | Verbatim[BlankNullSequence])[] | (Verbatim[Blank] | Verbatim[BlankSequence] | Verbatim[BlankNullSequence])[String] |
    Verbatim[Except][_] | Verbatim[Verbatim][_String]] ||
  MatchQ[p, (Verbatim[Pattern][_, q_] | transparentForm[q_]) /; admitsTextQ[q]] ||
  MatchQ[p, $itemAlternatives] && AnyTrue[List @@ p, admitsTextQ];

(* The names inside a WL pattern on one item that bind the whole item when
   bound, each {name, its pattern}: through the forms that match what their
   pattern matches, and alternatives. *)
wholeItemNames[Verbatim[Pattern][s_Symbol, q_]] := Prepend[wholeItemNames[q], {Hold[s], q}];
wholeItemNames[p : $itemAlternatives] := Join @@ (wholeItemNames /@ List @@ p);
wholeItemNames[transparentForm[q_]] := wholeItemNames[q];
wholeItemNames[_] := {};

(* The counted names, for refuseText; none for an element test. *)
$countedNames = {};

(* ---- Constraints ---- *)

(* The constraints of an XMLPattern or XMLDocument, $owner, which names the
   messages. *)
cConstraints[cs_List, need_] :=
  With[{h = $owner, expanded = childExpanded /@ cs},
    Scan[If[!constraintFormQ[#], refuse[MessageName[h, "constraint"], #]] &, expanded];
    Block[{$place = "constraint"}, cConstraint[#, need] & /@ expanded]];

(* Child[p] is the list constraint {___, p, ___}, and compiles as that list,
   wherever it is a constraint: alone, or inside alternatives, a name, a
   test, a Condition, Shortest or Longest, which keep their meaning. Only a
   name or a test on Child itself would have no value: between an element
   and its child there is nothing. *)
childExpanded[Child[p_]] := {___, p, ___};
childExpanded[c_Child] := refuse[Child::args, c];
childExpanded[c : Verbatim[Pattern][_, _Child]] := refuse[Child::name, c];
childExpanded[c : Verbatim[PatternTest][_Child, _]] := refuse[Child::test, c];
(* MapAt rewrites the pattern in place, without evaluating a test. *)
childExpanded[c : (h : Verbatim[Pattern] | Verbatim[PatternTest] | Verbatim[Condition] | Alternatives | Shortest | Longest)[___]] :=
  MapAt[childExpanded, c, Replace[h, {Verbatim[Pattern] -> 2, Alternatives -> All, _ -> 1}]];
childExpanded[c_] := c;

cConstraint[d_Descendant, need_] := cDescendant[d, need, None];
cConstraint[c_, need_] /; pathFormQ[c] :=
  With[{key = "Path" <> ToString[$nodeId + 1]}, cPath[c, Append[need, key], key]];
cConstraint[c : (Shortest | Longest)[___], _] := With[{h = $owner}, refuse[MessageName[h, "shortest"], c]];

(* key: the hidden name that binds a path's lower end, the match, as the
   node's index; None when nothing above needs it. *)
cDescendant[d : Descendant[p_, spec___], need_, key_] :=
  With[{levels = levelSpec[d, spec]},
    With[{sub = Block[{$place = "descendant"}, cRoot[p, need]]},
      treeNode["Descendant", If[key === None, sub["Names"], Union[sub["Names"], {key}]], need,
        "Sub" -> sub, "Levels" -> levels, "Key" -> key]]];
cConstraint[alts_Alternatives, need_] :=
  With[{subs = cConstraint[#, need] & /@ List @@ alts},
    treeNode["ConstraintAlt", Union @@ (#["Names"] & /@ subs), need, "Subs" -> subs]];
cConstraint[c_, need_] := cListConstraint[c, need];

(* ---- Paths ---- *)

(* A Descendant constraint under a name, a test, a Condition, Shortest or
   Longest. Its value is the path: the elements strictly between the pattern
   root, its upper end, and the match, its lower end. *)
pathFormQ[c_] := MatchQ[c, _Descendant] ||
  MatchQ[c, Verbatim[Pattern][_, x_] | Verbatim[PatternTest][x_, _] | Verbatim[Condition][x_, _] | (Shortest | Longest)[x_] /; pathFormQ[x]];

(* Every node of a path keeps key, which the wrappers read and the pattern
   root's node projects away. *)
cPath[d_Descendant, need_, key_] := cDescendant[d, need, key];
cPath[Verbatim[Pattern][s_Symbol, x_], need_, key_] :=
  With[{name = Hold[s]},
    With[{sub = cPath[x, need, key]},
      treeNode["PathNamed", Union[sub["Names"], {name}], need, "Name" -> name, "Sub" -> sub, "Key" -> key]]];
cPath[Verbatim[PatternTest][x_, f_], need_, key_] :=
  With[{sub = cPath[x, need, key]}, treeNode["PathTest", sub["Names"], need, "Sub" -> sub, "F" -> f, "Key" -> key]];
cPath[c_Condition, need_, key_] :=
  With[{test = Extract[c, {2}, Hold]},
    With[{sub = cPath[c[[1]], conditionNeed[c, test, need], key]}, Append[conditionNode["PathCond", sub, test, need], "Key" -> key]]];
(* Shortest and Longest are filters the pattern root's node runs
   (nearestFiltered); one is enough. *)
cPath[c : (h : Shortest | Longest)[x_], need_, key_] :=
  If[!FreeQ[x, Shortest | Longest], refuseHere["badpat", c],
    With[{sub = cPath[x, need, key]}, treeNode["PathNearest", sub["Names"], need, "Sub" -> sub, "Which" -> h, "Key" -> key]]];

(* Shortest or Longest on a constraint, or None. *)
nearestOf[c_] := Switch[c["Kind"],
  "PathNearest", c["Which"],
  "PathNamed" | "PathTest" | "PathCond", nearestOf[c["Sub"]],
  _, None];

levelSpec[_] := {1, Infinity};
levelSpec[_, n_Integer?Positive] := {1, n};
levelSpec[_, DirectedInfinity[1]] := {1, Infinity};
levelSpec[_, {n_Integer?Positive}] := {n, n};
levelSpec[_, {m_Integer?Positive, n : (_Integer | DirectedInfinity[1])}] /; m <= n := {m, n};
levelSpec[d_, s___] := refuse[Descendant::level, If[Length[{s}] == 1, s, d]];

cListConstraint[Verbatim[Pattern][s_Symbol, l_], need_] :=
  With[{name = Hold[s]},
    With[{sub = cListConstraint[l, need]},
      treeNode["ListNamed", Union[sub["Names"], {name}], need, "Name" -> name, "Sub" -> sub]]];
cListConstraint[c_Condition, need_] :=
  With[{test = Extract[c, {2}, Hold]},
    With[{sub = cListConstraint[c[[1]], conditionNeed[c, test, need]]}, conditionNode["ListCond", sub, test, need]]];
cListConstraint[Verbatim[PatternTest][l_, f_], need_] :=
  With[{sub = cListConstraint[l, need]}, treeNode["ListTest", sub["Names"], need, "Sub" -> sub, "F" -> f]];
cListConstraint[x_, _] /; !ListQ[x] := refuse[XMLPattern::constraint, x];
cListConstraint[l_List, need_] :=
  With[{items = Block[{$place = "entry", $single = cRoot}, cItems[l, need]]},
    treeNode["List", Union @@ Prepend[#["Names"] & /@ items, {}], need, "Items" -> items]];

(* ---- List entries ---- *)

(* The entries of a list, over children or over tokens: $single compiles an
   entry that is one item. An unnamed PatternSequence is spliced. *)
cItems[l_List, need_] := Join @@ (cItem[#, need] & /@ l);

cItem[Verbatim[BlankNullSequence][], need_] := {treeNode["Any", {}, need, "Min" -> 0]};
cItem[Verbatim[BlankSequence][], need_] := {treeNode["Any", {}, need, "Min" -> 1]};
cItem[Verbatim[BlankNullSequence][h_], need_] := cItem[RepeatedNull[Blank[h]], need];
cItem[Verbatim[BlankSequence][h_], need_] := cItem[Repeated[Blank[h]], need];
cItem[Verbatim[PatternSequence][ps___], need_] := cItems[{ps}, need];
cItem[Verbatim[Pattern][s_Symbol, p_], need_] /; sequenceQ[p] :=
  With[{name = Hold[s]}, If[$place === "literal", refuseText[name, p]];
    With[{inner = cItem[p, need]},
      {treeNode["Run", Union[{name}, Union @@ Prepend[#["Names"] & /@ inner, {}]], need, "Name" -> name, "Items" -> inner]}]];
cItem[r : (_Repeated | _RepeatedNull), need_] :=
  With[{inner = cItem[r[[1]], need], bounds = repeatBounds[r]},
    {treeNode["Repeat", Union @@ Prepend[#["Names"] & /@ inner, {}], need, "Items" -> inner, "Min" -> bounds[[1]], "Max" -> bounds[[2]]]}];
(* A name inside Except binds nothing outside it; tests inside it run there.
   A name also bound outside it refers to that match: the Except records
   what its pattern binds the name to, its "Record" key (settled). *)
cItem[Verbatim[Except][p_], need_] := {notNode[p, None, need]};
cItem[Verbatim[Except][p_, q_], need_] := {notNode[p, $single[q, need], need]};

notNode[p_, base_, need_] :=
  With[{refs = Intersection[namesIn[Hold[p]], $exceptRefs]},
    With[{sub = $single[p, refs], key = exceptKey[refs]},
      treeNode["Not", Union[Complement[sub["Names"], refs], If[base === None, {}, base["Names"]], If[refs === {}, {}, {key}]], need,
        "Sub" -> sub, "Base" -> base, "Record" -> If[refs === {}, None, key]]]];
cItem[alts_Alternatives, need_] /; AnyTrue[List @@ alts, sequenceQ] :=
  With[{branches = cItem[#, need] & /@ List @@ alts},
    {alternativesNode["Branches", branches, (Union @@ Prepend[#["Names"] & /@ #, {}]) & /@ branches, need]}];
cItem[Verbatim[Optional][p_, ___], need_] := cItem[Alternatives[p, PatternSequence[]], need];
(* Shortest and Longest choose which match WL's matcher tries first; every
   tuple is found here, so they change no result. *)
cItem[(Shortest | Longest)[p_, ___], need_] := cItem[p, need];
cItem[c_Condition, need_] /; sequenceQ[c[[1]]] :=
  With[{test = Extract[c, {2}, Hold]},
    With[{subNeed = conditionNeed[c, test, need]},
      With[{inner = cItem[c[[1]], subNeed]},
        With[{sub = treeNode["Seq", Union @@ Prepend[#["Names"] & /@ inner, {}], subNeed, "Items" -> inner]},
          {conditionNode["SeqCond", sub, test, need]}]]]];
(* A test on a sequence tests each of its items, as in WL. *)
cItem[Verbatim[PatternTest][p_, f_], need_] /; sequenceQ[p] := cItem[testedEach[p, f], need];
cItem[x_, need_] := With[{sub = $single[x, need]}, {treeNode["One", sub["Names"], need, "Sub" -> sub]}];

testedEach[Verbatim[Pattern][s_, p_], f_] := Pattern @@ {s, testedEach[p, f]};
testedEach[Verbatim[BlankNullSequence][h___], f_] := RepeatedNull[PatternTest[Blank[h], f]];
testedEach[Verbatim[BlankSequence][h___], f_] := Repeated[PatternTest[Blank[h], f]];
testedEach[p_, _] := refuseHere["badpat", p];

(* An entry that can match other than one item. *)
sequenceQ[p_] := MatchQ[p, _BlankSequence | _BlankNullSequence | _PatternSequence | _Repeated | _RepeatedNull | _Optional] ||
  MatchQ[p, Verbatim[Pattern][_, x_] | Verbatim[Condition][x_, _] | Verbatim[PatternTest][x_, _] | (Shortest | Longest)[x_, ___] /; sequenceQ[x]] ||
  MatchQ[p, _Alternatives] && AnyTrue[List @@ p, sequenceQ];

repeatBounds[(Verbatim[Repeated] | Verbatim[RepeatedNull])[_, {n_Integer}]] := {n, n};
repeatBounds[(Verbatim[Repeated] | Verbatim[RepeatedNull])[_, {m_Integer, n_}]] := {m, n};
repeatBounds[Verbatim[Repeated][_, n_]] := {1, n};
repeatBounds[Verbatim[RepeatedNull][_, n_]] := {0, n};
repeatBounds[Verbatim[Repeated][_]] := {1, Infinity};
repeatBounds[Verbatim[RepeatedNull][_]] := {0, Infinity};

(* =========================================================== *)
(* Vectors over the elements                                    *)
(*                                                              *)
(* Which elements a compiled node can match, tested before any  *)
(* name is bound: 0/1 vectors over the elements, kept with the  *)
(* index (keptVector), which the query engine reads as the      *)
(* candidates of its pattern roots (Query/Columnar.wl).         *)
(* =========================================================== *)

SetAttributes[memoised, HoldRest];
memoised[k_, v_] := Lookup[$memo, Key[k], $memo[k] = v];

(* Whether each element passes the compiled tag and attribute test, once per
   query for all elements. *)
(* The test reads only the tag and attributes, so it is run once for each
   distinct pair: a page repeats a few class strings over thousands of
   elements, and a long token list costs a scan per element. *)
headVector[nd_] :=
  keptVector[{"Head", nd["Id"], nd["HeadKey"]},
    With[{p = nd["Plain"], els = materialElems[nd["Readings"]]},
      Developer`ToPackedArray @ Which[
        MatchQ[p, XMLElement[_, Verbatim[_], Verbatim[_]]], distinctTested[els[[All, 1]], MatchQ[#, First[p]] &],
        MatchQ[p, XMLElement[_, _, Verbatim[_]]], distinctTested[els[[All, 1 ;; 2]], MatchQ[Append[#, {}], p] &],
        True, Boole[MatchQ[#, p] & /@ els]]]];

(* f applied once to each distinct one of xs, as 0 or 1 for each. A pattern
   on the tag alone reads only the tags, which a page has few of; taking
   each element's tag and attributes with Take cost about 1 µs an element. *)
distinctTested[xs_, f_] := With[{u = DeleteDuplicates[xs]}, Lookup[AssociationThread[u, Boole[f /@ u]], xs]];

(* Whether each element can match a pattern root: a vector over the elements
   that is 1 at every match, for skipping the rest. *)
candidateVector[nd_] := keptVector[{"Candidates", nd["Id"], nd["CandidateKey"]}, candidates[nd]];
candidates[nd_] := Switch[nd["Kind"],
  "Named" | "Cond" | "Test", candidateVector[nd["Sub"]],
  "Alt", Unitize[Total[candidateVector /@ nd["Subs"]]],
  "XMLPattern", headVector[nd] UnitStep[(Length /@ Rest[$kids]) - nd["MinKids"]] Times @@ Prepend[constraintFilter /@ nd["Constraints"], 1],
  "XMLDocument", ConstantArray[0, Length[$elem] - 1],
  _, ConstantArray[1, Length[$elem] - 1]];

(* The number of candidates up to each node, from the document, 0, and the
   candidates. *)
candidateCounts[nd_] :=
  keptVector[{"Counts", nd["Id"], nd["CandidateKey"]},
    With[{v = candidateVector[nd]}, {Accumulate[Prepend[v, 0]], Flatten @ Position[v, 1]}]];

(* The elements with some candidate of a pattern root below them, at any
   depth, a vector over the elements. *)
hasCandidateBelow[nd_] :=
  keptVector[{"Below", nd["Id"], nd["CandidateKey"]},
    With[{counts = First[candidateCounts[nd]]}, Unitize[counts[[Rest[$end] + 1]] - Rest[counts]]]];

(* A list constraint holds only at an element with a child that can match
   each of its one-child entries, so the elements without are not walked:
   a CSS translation's list is tried at every element with children, and
   walking each costs about a tenth of a millisecond. A Descendant, or a
   path, holds only at an element with a candidate of its pattern somewhere
   below. *)
constraintFilter[c_] := Switch[c["Kind"],
  "List", Times @@ Prepend[parentsWith /@ Select[c["Items"], #["Kind"] === "One" &], 1],
  "ListNamed" | "ListCond" | "ListTest", constraintFilter[c["Sub"]],
  "Descendant", hasCandidateBelow[c["Sub"]],
  "PathNamed" | "PathTest" | "PathCond" | "PathNearest", constraintFilter[c["Sub"]],
  _, 1];

parentsWith[it_] :=
  keptVector[{"Parents", it["Id"], it["Sub"]["CandidateKey"]},
    Module[{v = ConstantArray[0, Length[$elem] - 1]},
      v[[DeleteCases[$parent[[Flatten[Position[candidateVector[it["Sub"]], 1]] + 1]], 0]]] = 1;
      v]];

(* The elements strictly between i and j, a node below it, outermost first. *)
pathIds[i_, j_] := Reverse @ Most @ NestWhileList[$parent[[# + 1]] &, $parent[[j + 1]], # != i &];

(* =========================================================== *)
(* Results (ADR 0024)                                           *)
(* =========================================================== *)

$noResult = Unique["noResult"];

(* The result of one solution, in each output mode:
   - "Values": the right-hand side's value, as XMLCases gives it;
   - "Positions": the same, with each name replaced by its position, as
     XMLPosition gives it. Its Conditions are run as for XMLCases, on the
     values, and then the code they guard is evaluated with the positions,
     so a right-hand side with a test is evaluated twice. A repeated name
     with several positions gives the list of them (positionOf); a name that
     is absent, Sequence[];
   - "CountedPositions": the positions of the counted names, whatever the
     right-hand side does with them, as XMLDeleteCases, Hide and Focus act
     on them. A no-match is {}, never read as {} the document. A repeated
     name compared by value gives every position it is bound at, since each
     is in the tuple;
   - "Solutions": the solution, an Association name -> {positions, {value}},
     the value a list of what the name splices in, as XMLReplace acts on it,
     evaluating its replacements later, on the tree as rewritten. Compiled
     with counted names given, the names the right-hand side mentions beyond
     them take their first passing match. The slot of an Alternatives at the
     root, which is not a name, is left out.
   A result its Conditions refuse gives none, in every mode. *)
resultOf["Values", rhs_, all_, sol_] := evaluated[substituted[rhs, all, sol]];
resultOf["Solutions", rhs_, all_, sol_] :=
  If[guardedBody[rhs] =!= rhs && evaluated[substituted[rhs, all, sol]] === $noResult, $noResult,
    {{matchPos[#], {valueOf[#]}} & /@ KeySelect[sol, MatchQ[_Hold]]}];
resultOf["CountedPositions", rhs_, all_, sol_] :=
  If[guardedBody[rhs] =!= rhs && evaluated[substituted[rhs, all, sol]] === $noResult, $noResult,
    {positionOf["CountedPositions", Lookup[sol, Key[#], None]] & /@ First[rhsNames[rhs, all]]}];
resultOf["Positions", rhs_, all_, sol_] :=
  With[{body = guardedBody[rhs]},
    If[body =!= rhs && evaluated[substituted[rhs, all, sol]] === $noResult, $noResult,
      evaluated[body /. (Replace[#, Hold[s_] :> (HoldPattern[s] -> positionOf["Positions", Lookup[sol, Key[#], None]])] & /@ all)]]];

(* A name with several positions, a repeated name compared by value, is the
   list of them; for "CountedPositions", each of them. *)
positionOf[_, None] := Sequence[];
positionOf["CountedPositions", b_] := Sequence @@ matchPos[b];
positionOf["Positions", b_] := If[Length[matchPos[b]] == 1, First[matchPos[b]], matchPos[b]];

(* Held code without the Conditions a rule's right-hand side tests: at the
   top, or at the top of a With, Module or Block (rhsParts). *)
guardedBody[Hold[Verbatim[Condition][b_, _]]] := guardedBody[Hold[b]];
guardedBody[Hold[(h : With | Module | Block)[vs_, b_]]] := Replace[guardedBody[Hold[b]], Hold[c_] :> Hold[h[vs, c]]];
guardedBody[held_] := held;

(* Held code evaluated as a rule's right-hand side, as the list of what it
   gives, so that a sequence, such as an empty gap, is spliced in as in Cases;
   a Condition that fails gives $noResult. Several expressions are a sequence
   substituted for a name, and hold no Condition. *)
evaluated[Hold[code_]] := Replace[{Replace[$noResult, _ :> code]}, {$noResult} -> $noResult];
evaluated[Hold[code___]] := {code};

(* The nodes directly below a node. *)
subNodes[nd_] := DeleteCases[Flatten[{Lookup[nd, "Sub", {}], Lookup[nd, "Subs", {}], Lookup[nd, "Constraints", {}],
  Lookup[nd, "Items", {}], Lookup[nd, "Base", {}]}], None];

(* Held code with each name replaced by its value; an absent name is
   Sequence[], as a name in an Alternatives branch that did not match is in
   WL. *)
substituted[held_, names_, sol_] :=
  held /. (Replace[#, Hold[s_] :> (HoldPattern[s] -> valueOf[Lookup[sol, Key[#], None]])] & /@ names);

valueOf[None] := Sequence[];
valueOf[b_] := Replace[matchVal[b], seq[l_] :> Sequence @@ l];

passesQ[test_Hold, names_, sol_] := TrueQ[ReleaseHold[substituted[test, names, sol]]];

(* =========================================================== *)
(* Element tests                                                *)
(*                                                              *)
(* XMLMatchQ and XMLFreeQ test a node of their input as the     *)
(* pattern root; names select nothing, so only the names that   *)
(* Conditions see are bound. A test is compiled once, as a      *)
(* query with nothing counted, which the operator forms keep    *)
(* (ADR 0013), and run (runQuery) on an index of the input that *)
(* reaches no deeper than the pattern does.                     *)
(* =========================================================== *)

(* A pattern root of XMLPatterns without constraints, which XMLMatchQ tests
   with one MatchQ of a plain WL pattern (Query/Compiler.wl), about a
   hundred times faster per element than a query run; that matters in the
   operator form, applied to every element. A selector that is not
   translated, or a context selector, is left to a query run, which gives
   its message. *)
plainRootQ[x_ /; xmlPatternFormQ[x]] :=
  MatchQ[xmlPatternParts[x], {_, {}}] && FreeQ[x, _Descendant | _XMLDocument] && !removedCombinatorQ[Hold[x]];
plainRootQ[s_String] := MatchQ[Quiet[cssTree[s]], {"one", t_} /; plainRootQ[t]];
plainRootQ[Verbatim[Pattern][_, p_] | Verbatim[Condition][p_, _] | Verbatim[PatternTest][p_, _]] := plainRootQ[p];
plainRootQ[alts_Alternatives] := AllTrue[List @@ alts, plainRootQ];
plainRootQ[_] := False;

(* A list pattern, named, conditioned or tested, or alternatives of these. *)
listRootQ[q_] := MatchQ[q, _List] ||
  MatchQ[q, Verbatim[Pattern][_, x_] | Verbatim[Condition][x_, _] | Verbatim[PatternTest][x_, _] /; listRootQ[x]] ||
  MatchQ[q, _Alternatives] && AllTrue[List @@ q, listRootQ];

(* A list pattern matches the top elements of a list, the children of the
   virtual document above them, as XMLDocument's contents list does. *)
listRoot[q_, need_] :=
  Block[{$owner = XMLMatchQ, $place = "constraint"},
    With[{c = cConstraint[q, need]},
      treeNode["XMLDocument", c["Names"], need, "Constraints" -> {c}]]];

(* How many DOM levels below its root node a pattern reads. *)
reachBelow[nd_] := Switch[nd["Kind"],
  "List" | "ContentsList", 1 + Max[0, reachBelow /@ subNodes[nd]],
  "Descendant", nd["Levels"][[2]] + reachBelow[nd["Sub"]],
  _, Max[0, reachBelow /@ subNodes[nd]]];
