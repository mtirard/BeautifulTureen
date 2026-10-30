(* ::Package:: *)
(* HTMLPatterns: tree patterns, the result rule and positions *)

(* Used by DisplayRoles.wl, Query/Compiler.wl and Rewrite.wl *)
PackageScoped[namesIn]

(* Used by XMLFunctions.wl, for XMLMatchQ and XMLFreeQ *)
PackageScoped[plainRootQ]
PackageScoped[treeMatcher]
PackageScoped[treeMatchQ]
PackageScoped[treeFreeQ]

(* Used by XMLFunctions.wl *)
PackageScoped[treeCases]
PackageScoped[treeResults]

(* Used by Positions.wl *)
PackageScoped[treePositions]

(* Used by DisplayRoles.wl, Rewrite.wl and Tree.wl *)
PackageScoped[treeCountedPositions]

(* Used by DisplayRoles.wl and Rewrite.wl *)
PackageScoped[treeSolutions]

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
(* tree of nodes. Matching a node at a document node gives its  *)
(* solutions, each an Association name -> match, projected onto *)
(* the names something above it needs ("Keep"), so an unnamed   *)
(* part, or a name nothing uses, costs a test and never an      *)
(* enumeration. The element's tag and attributes are tested by  *)
(* a plain WL pattern (Query/Compiler.wl); everything below it  *)
(* is this engine's own: contents lists are walked as           *)
(* reachability over 0/1 vectors of the places between          *)
(* children, branching only at entries that bind a needed name, *)
(* so ___ gaps and ordered entries stay linear.                 *)
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

(* The results of q on tree, the first n of them in result order, or $Failed
   after a message under head. A result that is a sequence is spliced in, as
   in Cases. *)
treeCases[head_, tree_, q_, n_] := joined[treeResults[head, tree, q, n]];

(* The same, each result as the list of what it splices in. *)
treeResults[head_, tree_, q_, n_] := runQuery[compileQuery[head, q], tree, "Values", n];

(* What XMLPosition gives: the results of q with each counted name replaced
   by its position (resultOf). *)
treePositions[head_, tree_, q_] := joined[runQuery[compileQuery[head, q], tree, "Positions", Infinity]];

(* What Hide and Focus act on: for each result of q, the positions of its
   counted names, whatever the right-hand side does with them. A result its
   Conditions refuse gives none. A no-match is {}, never read as {} the
   document. A repeated name compared by value gives every position it is
   bound at, since each is in the tuple. *)
treeCountedPositions[head_, tree_, q_] := joined[runQuery[compileQuery[head, q], tree, "CountedPositions", Infinity]];

(* What XMLReplace acts on: for each result of q, its solution, an
   Association name -> {positions, {value}}, the value a list of what the
   name splices in. The counted names are those given, not those the
   right-hand side uses; every other name it mentions is uncounted, and takes
   its first passing match. A result its Conditions refuse
   gives none. *)
treeSolutions[head_, tree_, q_, counted_] := joined[runQuery[compileQuery[head, q, counted], tree, "Solutions", Infinity]];

joined[r_] := Replace[r, l_List :> Join @@ l];

(* The compiled query of q under head, or $Failed after a message under
   head. It reads the query, counted and the readings in force, never a
   tree. counted is None for the names the right-hand side uses (rhsNames),
   or else the counted names, each Hold[name]; the other names the
   right-hand side mentions are then test names.
   The compiled query is an Association of all the run reads: "Head";
   "Root", the compiled pattern; "Rhs", the held right-hand side; "Names",
   the names the pattern binds; "Counted"; "TestNames"; "Readings"; "Order"
   and "Slots", the pattern order and the Alternatives slots, which
   compiling extends; "NamedPaths"; "ExceptRefs"; "Records"; and
   "LastNodeId", the last node id compiled. A list pattern at a list key is
   compiled while matching (tokenListMatches), so the run numbers its nodes
   on from there: they never share an id, nor so a memo entry, with a
   compiled node. *)
compileQuery[head_, q_, counted_ : None] :=
  Catch[
    Block[{$head = head, $nodeId = 0, $order, $slotOf = <||>, $readings, $place = "query", $owner = XMLPattern,
        $namedPaths = False, $exceptRefs, $records, $countedNames, $contextOK = True},
      Module[{lhs, rhs, all, names, root},
        If[namedContextQ[q], refuseHere["badpat", q]];
        {lhs, rhs} = splitQuery[q];
        If[removedCombinatorQ[lhs], refuseHere["badpat", q]];
        $readings = Replace[readingsInForce[], $Failed :> Throw[$Failed, $refusal]];
        all = namesIn[lhs];
        $order = patternOrder[lhs];
        names = If[counted === None, rhsNames[rhs, all], {counted, Complement[mentioned[rhs, all], counted]}];
        $exceptRefs = exceptRefs[lhs];
        $countedNames = First[names];
        checkExcept[lhs, If[counted === None, First[names], Union @@ names]];
        $records = $exceptRefs =!= {};
        root = compileRoot[lhs, Union[First[names], Last[names], comparedNames[lhs]]];
        <|"Head" -> head, "Root" -> root, "Rhs" -> rhs, "Names" -> all, "Counted" -> First[names],
          "TestNames" -> Last[names], "Readings" -> $readings, "Order" -> $order, "Slots" -> $slotOf,
          "NamedPaths" -> $namedPaths, "ExceptRefs" -> $exceptRefs, "Records" -> $records, "LastNodeId" -> $nodeId|>]],
    $refusal];

(* The results of compiled query cq on tree, the first n of them in result
   order, each the list of what it splices in, or $Failed after a message
   under its head; a refused compile, $Failed, passes through. The tree is
   checked, indexed, the index kept for the next query (cachedIndexTree),
   and searched with fresh memos. mode is what each result is: "Values", the
   right-hand side's value; "Positions", "CountedPositions" or "Solutions",
   as treePositions, treeCountedPositions and treeSolutions describe. The
   compiler's context flag and counted names stay as they were compiling,
   for an element test that a Condition compiles during the run. *)
runQuery[$Failed, ___] := $Failed;
runQuery[cq_Association, tree_, mode_, n_] :=
  Catch[
    Block[{$head = cq["Head"], $readings = cq["Readings"], $order = cq["Order"], $slotOf = cq["Slots"],
        $namedPaths = cq["NamedPaths"], $exceptRefs = cq["ExceptRefs"], $records = cq["Records"],
        $nodeId = cq["LastNodeId"], $countedNames = cq["Counted"], $contextOK = True, $memo = <||>,
        $elem, $parent, $depth, $kids, $index, $end, $wlPos, $tops, $posMemo = <||>, $keyMemo = <||>,
        $matElems = <||>, $keyLength},
      If[!validTreeQ[tree], messageTreeRefusal[$head, tree]; Throw[$Failed, $refusal]];
      cachedIndexTree[tree];
      With[{r = results[mode, cq["Root"], cq["Rhs"], cq["Names"], cq["Counted"], cq["TestNames"], MatchQ[tree, _XMLElement], n]},
        keptIndex[tree];
        r]],
    $refusal];

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
   materialised for each set of readings, and the positions and order keys
   of the elements it read, are kept for the next: a
   document is often queried many times, and indexing it costs about 50 ms
   at 8,000 elements. An input that is the same expression, which SameQ
   tells at once when it is the one given before, reuses them. *)
$indexCache = {None, None, {}};

cachedIndexTree[input_] :=
  If[cachedQ[input],
    {$tops, $wlPos, $elem, $parent, $depth, $kids, $index, $end, $keyLength, $matElems, $posMemo, $keyMemo} = $indexCache[[3]],
    indexTree[input];
    keepIndex[input]];

cachedQ[input_] := $indexCache[[2]] === $indexDepth && $indexCache[[1]] === input;

keepIndex[input_] :=
  $indexCache = {input, $indexDepth, {$tops, $wlPos, $elem, $parent, $depth, $kids, $index, $end, $keyLength, $matElems, $posMemo, $keyMemo}};

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
(* Position order (ADR 0024): order keys as Positions.wl builds *)
(* them, from the indices the matcher holds.                    *)
(* =========================================================== *)

elemKey[i_] := Lookup[$keyMemo, i, $keyMemo[i] = If[i == 0, {}, Join[elemKey[$parent[[i + 1]]], sequenceKey[4, $index[[i + 1]]]]]];

(* A named path's key is its lower end's then its upper end's, so when a query
   names a path every key takes two lengths. *)
padded[pathKey[lower_, upper_]] := Join[PadRight[lower, $keyLength, $keyPad], PadRight[upper, $keyLength, $keyPad]];
padded[k_] := PadRight[k, If[$namedPaths, 2, 1] $keyLength, $keyPad];

(* A name's match: the positions, the value, and the order key of each
   position.
   A repeated name compared by value has several positions, in position
   order (joined); its order key is its first one's. A sequence's value is
   seq[list]. *)
nameMatch[pos_, val_, key_] := {pos, val, {key}};
matchPos[b_] := b[[1]];
matchVal[b_] := b[[2]];
matchKey[b_] := First[b[[3]]];

elemMatch[i_] := nameMatch[{posOf[i]}, elemOf[i], elemKey[i]];

(* =========================================================== *)
(* Compilation                                                  *)
(* =========================================================== *)

(* A node is an Association: "Kind", "Id", "Names" (every name bound below
   it, with Alternatives slots), "Keep" (those something above needs), and
   the kind's own fields. *)
treeNode[kind_, names_, need_, rest___] :=
  <|"Kind" -> kind, "Id" -> ++$nodeId, "Names" -> names, "Keep" -> Intersection[names, need], rest|>;

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
      treeNode["XMLDocument", Union @@ Prepend[#["Names"] & /@ cons, {}], need,
        "Constraints" -> cons, "MinKids" -> Max[0, minKids /@ cons]]]];
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
cRoot[x_, need_] /; $place === "literal" := plainNode[x, need];
cRoot[x_, _] := refuseHere["badpat", x];

refuseBlank[b_] := If[$place === "descendant", refuse[Descendant::blank, b], refuseHere["blank", b]];

(* The message is the list's owner's: XMLPattern's or XMLDocument's. *)
refuseListEntry[x_, reason_] := With[{h = $owner}, refuse[MessageName[h, "listentry"], x, $listEntryReasons[reason]]];

$listEntryReasons = <|
  "document" -> "An entry is one element child or a sequence of them, and XMLDocument[...] is the document above every element. It can only be the pattern root, as in XMLDocument[Child[x : p]].",
  "descendant" -> "An entry is one element child or a sequence of them, and Descendant[...] says what is somewhere below an element. A child containing x is XMLPattern[_][Descendant[x]].",
  "child" -> "An entry is one element child or a sequence of them, and Child[...] says that some child of an element matches. A child with a child x is XMLPattern[_][Child[x]].",
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
  Module[{c, headNames, cons, plainRules},
    If[!FreeQ[attrs, _Descendant], refuse[Descendant::place, FirstCase[attrs, _Descendant, Null, {0, Infinity}]]];
    refuseDocumentIn[{tag, attrs}];
    c = Replace[compileWith[XMLPattern[tag, attrs], $head, $readings], $Failed :> Throw[$Failed, $refusal]];
    headNames = namesIn[Hold[{tag, attrs}]];
    cons = Block[{$owner = XMLPattern}, cConstraints[{cs}, need]];
    plainRules = plainHeadRules[tag, attrs, Intersection[headNames, need]];
    treeNode["XMLPattern", Union[headNames, Union @@ Prepend[#["Names"] & /@ cons, {}]], need,
      "Plain" -> c["Plain"], "Readings" -> c["Readings"], "Tag" -> tag, "Attrs" -> attrs,
      "HeadNames" -> Intersection[headNames, need], "Constraints" -> cons,
      "MinKids" -> Max[0, minKids /@ cons], "PlainRules" -> plainRules]];

(* The rules of an attribute argument that is a rule or a list of them,
   or None. *)
ruleList[attrs_] := Replace[attrs, {r_Rule :> {r}, l_List :> l, _ -> None}];

(* {key, name} for each rule of the attribute argument that binds a needed
   name, when headMatches can bind them directly (plainAttributeMatches),
   or None. A name repeated over two rules has a position at each, which
   the general way merges. *)
plainHeadRules[tag_, attrs_, need_] :=
  With[{rules = ruleList[attrs]},
    If[ListQ[rules] && FreeQ[rules, Verbatim[Rule][_Alternatives, _]] && !IntersectingQ[namesIn[Hold[tag]], need],
      Replace[Cases[rules, Verbatim[Rule][_, v_] /; IntersectingQ[namesIn[Hold[v]], need]], {
        r_ /; !AllTrue[r, plainRuleQ] -> None,
        r_ :> Replace[Replace[r, Verbatim[Rule][k_, Verbatim[Pattern][s_, _]] :> {k, Hold[s]}, {1}],
          pairs_ /; !DuplicateFreeQ[pairs[[All, 2]]] -> None]}],
      None]];

(* ---- XMLElement patterns (ADR 0023) ----

   An XMLElement pattern keeps WL's literal meaning: its contents are every
   item, elements and text, and its attributes the raw rule list. One with
   no XMLPattern in it and no name anything needs is matched whole. Any
   other is matched by its parts: the tag and attributes as WL patterns, and
   a contents list walked over the items as a contents list is over element
   children, its entries patterns over one item ($place "literal"), so that
   XMLPatterns nested in it are this engine's, every way it matches is found,
   and a name in it has the position of what it binds. *)
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
    treeNode["ContentsList", Union @@ Prepend[#["Names"] & /@ items, {}], need, "Items" -> items, "Min" -> minLength[items]]];
cContents[p_, need_] := plainNode[p, need];

(* A WL pattern matched whole against one value: an item, or a literal's
   contents. Names inside an Except in it are its own (outsideExcept). *)
plainNode[p_, need_] :=
  With[{names = namesIn[outsideExcept[Hold[p]]]}, treeNode["Plain", names, need, "Pattern" -> p]];

(* A counted name that binds text is refused: text has no
   position. Here, where the pattern shows it; a sequence that binds text
   while matching is refused by the results (refuseBoundText). *)
refuseText[name_, p_] :=
  If[MemberQ[$countedNames, name] && textPatternQ[p], refuseHere["text", Replace[name, Hold[s_] :> HoldForm[s]]]];

textPatternQ[p_] :=
  MatchQ[p, _String | Verbatim[Blank][String] | Verbatim[BlankSequence][String]] ||
  MatchQ[p, Verbatim[Pattern][_, q_] | Verbatim[PatternTest][q_, _] | Verbatim[Condition][q_, _] | Verbatim[Repeated][q_, ___] /; textPatternQ[q]] ||
  MatchQ[p, _Alternatives] && AllTrue[List @@ p, textPatternQ];

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
  With[{name = Hold[s]}, $namedPaths = True;
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
    treeNode["List", Union @@ Prepend[#["Names"] & /@ items, {}], need, "Items" -> items, "Min" -> minLength[items]]];

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

(* An entry the walk must branch at: it binds a needed name, or tests a span. *)
capQ[it_] := it["Keep"] =!= {} || MatchQ[it["Kind"], "SeqCond"] ||
  MatchQ[it["Kind"], "Run" | "Repeat"] && AnyTrue[it["Items"], capQ] ||
  it["Kind"] === "Branches" && AnyTrue[Flatten[it["Subs"]], capQ];

(* The fewest items a list of entries can match. *)
minLength[items_List] := Total[minItems /@ items];
minItems[it_] := Switch[it["Kind"],
  "One" | "Not", 1,
  "Any", it["Min"],
  "Run", minLength[it["Items"]],
  "SeqCond", minLength[it["Sub"]["Items"]],
  "Repeat", it["Min"] minLength[it["Items"]],
  "Branches", Min[minLength /@ it["Subs"]],
  _, 0];

(* The fewest element children an element needs to meet a constraint. *)
minKids[c_] := Switch[c["Kind"],
  "List", c["Min"],
  "ListNamed" | "ListCond" | "ListTest" | "PathNamed" | "PathTest" | "PathCond" | "PathNearest", minKids[c["Sub"]],
  "Descendant", 1,
  "ConstraintAlt", Min[minKids /@ c["Subs"]],
  _, 0];

(* =========================================================== *)
(* Matching                                                     *)
(* match[node, i]: the solutions of a pattern root at document  *)
(* node i, projected onto the node's Keep.                      *)
(* =========================================================== *)

SetAttributes[memoised, HoldRest];
memoised[k_, v_] := Lookup[$memo, Key[k], $memo[k] = v];

match[nd_, i_] := memoised[{nd["Id"], i}, matchKind[nd["Kind"], nd, i]];

matchKind["Named", nd_, i_] :=
  With[{sols = match[nd["Sub"], i]},
    If[MemberQ[nd["Keep"], nd["Name"]], joinAll[sols, <|nd["Name"] -> elemMatch[i]|>], sols]];

matchKind["Cond", nd_, i_] := conditionFiltered[nd, match[nd["Sub"], i]];

matchKind["Test", nd_, i_] :=
  With[{sols = match[nd["Sub"], i]}, If[sols =!= {} && TrueQ[nd["F"][elemOf[i]]], sols, {}]];

matchKind["Alt", nd_, i_] :=
  distinctJoin[With[{s = match[#, i]},
      If[nd["Slot"] === None, s, Append[#, nd["Slot"] -> elemMatch[i]] & /@ s]] & /@ nd["Subs"], nd["Keep"]];

(* The solutions of several parts joined and projected on keep. Each part's
   solutions are distinct, and their names among keep, so the projection is
   needed only where two parts have solutions; as a CSS translation is
   XMLPattern[_][L] | XMLDocument[L], at most one part has, and projecting
   every solution again costs a few microseconds each. *)
distinctJoin[parts_, keep_] := If[Count[parts, Except[{}]] <= 1, Join @@ parts, project[Join @@ parts, keep]];

matchKind["Blank", nd_, i_] := If[MatchQ[elemOf[i], Blank @@ nd["Head"]], {<||>}, {}];

(* An XMLElement pattern that binds nothing needed, matched whole. *)
matchKind["Literal", nd_, i_] := If[MatchQ[elemOf[i], nd["Pattern"]], {<||>}, {}];

(* One matched by its parts: the tag and attributes as WL patterns, the
   contents by cContents. Names compare values across the parts, as in WL. *)
matchKind["LiteralParts", nd_, i_] :=
  With[{x = elemOf[i]},
    If[!MatchQ[x[[1]], nd["Tag"]] || !MatchQ[x[[2]], nd["Attrs"]], {},
      project[product[{slotMatches[nd, "Tag", x, i], slotMatches[nd, "Attrs", x, i], contentsSolutions[nd["Sub"], i]}],
        nd["Keep"]]]];

slotMatches[nd_, slot_, x_, i_] :=
  With[{names = nd[slot <> "Names"], v = x[[If[slot === "Tag", 1, 2]]]},
    If[names === {}, {<||>},
      {Association @ KeyValueMap[#1 -> literalPosition[nd, slot, #1, #2, x, i] &, firstMatchValues[v, nd[slot], names]]}]];

(* The match of a name in a literal's tag or attributes. A name on a slot
   of the literal itself is at that slot: 0 the tag, Key[All] the attributes
   (ADR 0025). A name deeper in the tag that binds the whole tag is at
   0; one deeper in the attributes that binds an attribute's value is at
   Key[k] of the first attribute with that value. Any other has no position,
   and is compared by its value. *)
literalPosition[nd_, slot_, name_, v_, x_, i_] :=
  Replace[{Lookup[nd["Slots"], Key[name], None], slot},
    {
      {k : Except[None], _} :> nameMatch[{Append[posOf[i], k]}, v, Join[elemKey[i], If[k === 0, tagKey[], attributeMapKey[]]]],
      {_, "Tag"} /; v === x[[1]] :> nameMatch[{Append[posOf[i], 0]}, v, Join[elemKey[i], tagKey[]]],
      {_, "Attrs"} :>
        Replace[FirstPosition[x[[2]], _[_, v], None, {1}, Heads -> False], {
          {j_} :> nameMatch[{Append[posOf[i], Key[x[[2, j, 1]]]]}, v, Join[elemKey[i], attributeKey[j]]],
          None :> nameMatch[{Missing["Literal"]}, v, Join[elemKey[i], attributeMapKey[]]]}],
      _ :> nameMatch[{Missing["Literal"]}, v, Join[elemKey[i], tagKey[]]]}];

literalSlots[XMLElement[t_, a_, c_]] :=
  Association @ Cases[{{Hold[t], 0}, {Hold[a], Key[All]}, {Hold[c], All}}, {Hold[Verbatim[Pattern][s_Symbol, _]], k_} :> (Hold[s] -> k)];
literalSlots[_] := <||>;

(* The solutions of a literal's contents slot at element i. *)
contentsSolutions[c_, i_] := memoised[{c["Id"], i}, contentsKind[c["Kind"], c, i]];

contentsKind["ContentsNamed", c_, i_] :=
  With[{sols = contentsSolutions[c["Sub"], i]},
    If[MemberQ[c["Keep"], c["Name"]],
      joinAll[sols, <|c["Name"] -> nameMatch[{Append[posOf[i], All]}, elemOf[i][[3]], Join[elemKey[i], contentsKey[]]]|>], sols]];
contentsKind["ContentsCond", c_, i_] := conditionFiltered[c, contentsSolutions[c["Sub"], i]];
contentsKind["ContentsTest", c_, i_] :=
  With[{sols = contentsSolutions[c["Sub"], i]}, If[sols =!= {} && TrueQ[c["F"][elemOf[i][[3]]]], sols, {}]];
contentsKind["Plain", c_, i_] := plainSolutions[c, elemOf[i][[3]], Append[posOf[i], All], Join[elemKey[i], contentsKey[]]];
contentsKind["ContentsList", c_, i_] /; Length[elemOf[i][[3]]] < c["Min"] := {};
contentsKind["ContentsList", c_, i_] :=
  With[{items = elemOf[i][[3]]},
    Block[{$n = Length[items], $walkId = {"Contents", i}, $contentOf = i, $contentIds = contentIds[i, items], $elementsBefore = elementsBefore[items],
        $oneVector = itemVectorOf, $oneSolutions = itemSolutions, $runMatch = itemRun},
      project[Last /@ enumerate[c["Items"], 0, delta[$n]], c["Keep"]]]];

(* The node of each item that is an element, None for text. *)
contentIds[i_, items_] :=
  ReplacePart[ConstantArray[None, Length[items]], Thread[Flatten[Position[items, _XMLElement, {1}, Heads -> False]] -> childrenOf[i]]];

(* At s + 1, the number of element children among the first s items. *)
elementsBefore[items_] := Prepend[Accumulate[Boole[MatchQ[#, _XMLElement] & /@ items]], 0];

itemVectorOf[sub_] := Boole[itemSolutions[sub, #] =!= {} & /@ Range[$n]];
itemSolutions[sub_, k_] := With[{j = $contentIds[[k]]}, If[j === None, textMatch[sub, $contentOf, k], match[sub, j]]];

(* A run of items: the run of the element children in it, or, if it holds
   text, no position. An empty run is the gap before the next element. *)
itemRun[s_, e_] :=
  With[{items = elemOf[$contentOf][[3]]},
    With[{m = $elementsBefore[[s + 1]] + 1, n = $elementsBefore[[e + 1]] - $elementsBefore[[s + 1]], run = items[[s + 1 ;; e]]},
      nameMatch[{If[n == Length[run], Append[posOf[$contentOf], m ;; m + n - 1], itemMissing[run]]}, seq[run],
        Join[elemKey[$contentOf], sequenceKey[4, m ;; m + n - 1]]]]];

(* What has no position: text, or another item that is not an element. *)
itemMissing[v_] := Missing[If[!FreeQ[v, _String, {0, 1}], "Text", "Literal"]];

(* The solutions of an entry at item k of element i that is not an element:
   only WL's patterns can match it. *)
textMatch[nd_, i_, k_] := memoised[{"Text", nd["Id"], i, k}, textKind[nd["Kind"], nd, i, k]];

textItemMatch[i_, k_] :=
  With[{items = elemOf[i][[3]]},
    nameMatch[{itemMissing[items[[k]]]}, items[[k]], Join[elemKey[i], textItemKey[$elementsBefore[[k]] + 1, k]]]];

textKind["Named", nd_, i_, k_] :=
  With[{sols = textMatch[nd["Sub"], i, k]},
    If[MemberQ[nd["Keep"], nd["Name"]], joinAll[sols, <|nd["Name"] -> textItemMatch[i, k]|>], sols]];
textKind["Cond", nd_, i_, k_] := conditionFiltered[nd, textMatch[nd["Sub"], i, k]];
textKind["Test", nd_, i_, k_] :=
  With[{sols = textMatch[nd["Sub"], i, k]}, If[sols =!= {} && TrueQ[nd["F"][elemOf[i][[3, k]]]], sols, {}]];
textKind["Alt", nd_, i_, k_] :=
  project[Join @@ (With[{s = textMatch[#, i, k]},
      If[nd["Slot"] === None, s, Append[#, nd["Slot"] -> textItemMatch[i, k]] & /@ s]] & /@ nd["Subs"]), nd["Keep"]];
textKind["Blank", nd_, i_, k_] := If[MatchQ[elemOf[i][[3, k]], Blank @@ nd["Head"]], {<||>}, {}];
textKind["Plain", nd_, i_, k_] := With[{b = textItemMatch[i, k]}, plainSolutions[nd, matchVal[b], First[matchPos[b]], matchKey[b]]];
textKind[_, _, _, _] := {};

(* A WL pattern on one value: a name that binds the whole value is at pos,
   any other has no position. *)
matchKind["Plain", nd_, i_] := plainSolutions[nd, elemOf[i], posOf[i], elemKey[i]];

plainSolutions[nd_, v_, pos_, key_] :=
  Which[
    !MatchQ[v, nd["Pattern"]], {},
    nd["Keep"] === {}, {<||>},
    True, {Association @ KeyValueMap[#1 -> nameMatch[{If[#2 === v, pos, Missing["Literal"]]}, #2, key] &,
      firstMatchValues[v, nd["Pattern"], nd["Keep"]]]}];

(* The document, node 0, is matched only by XMLDocument, which matches
   nothing else. *)
matchKind["XMLPattern" | "Literal" | "LiteralParts" | "Plain" | "Blank", _, 0] := {};
matchKind["XMLDocument", nd_, i_] :=
  If[i == 0 && Length[childrenOf[0]] >= nd["MinKids"],
    project[product[matchConstraint[#, 0] & /@ nd["Constraints"], joinedAcross], nd["Keep"]],
    {}];

matchKind["XMLPattern", nd_, i_] :=
  If[headVector[nd][[i]] == 1 && Length[childrenOf[i]] >= nd["MinKids"],
    If[oneConstraintQ[nd], constraintSolutions[nd, First[nd["Constraints"]], i],
      project[product[{headMatches[nd, i], product[constraintSolutions[nd, #, i] & /@ nd["Constraints"], joinedAcross]}], nd["Keep"]]],
    {}];

(* One constraint and no names in the tag or attributes: the constraint's
   solutions are distinct and their names among the node's, so they are its
   solutions, unless the constraint keeps a path's hidden name, which the
   node projects away. *)
oneConstraintQ[nd_] := nd["HeadNames"] === {} && Length[nd["Constraints"]] == 1 && Lookup[First[nd["Constraints"]], "Key", None] === None;

constraintSolutions[nd_, c_, i_] := If[nearestOf[c] === None, matchConstraint[c, i], nearestFiltered[nd, c, i]];

conditionFiltered[nd_, sols_] := project[Select[sols, passesQ[nd["Test"], nd["Sees"], #] &], nd["Keep"]];

(* ---- Tag and attributes ---- *)

(* Whether each element passes the compiled tag and attribute test, once per
   query for all elements. *)
(* The test reads only the tag and attributes, so it is run once for each
   distinct pair: a page repeats a few class strings over thousands of
   elements, and a long token list costs a scan per element. *)
headVector[nd_] :=
  memoised[{"Head", nd["Id"]},
    With[{p = nd["Plain"], els = materialElems[nd["Readings"]]},
      Developer`ToPackedArray @ If[MatchQ[p, XMLElement[_, _, Verbatim[_]]],
        With[{heads = Take[#, 2] & /@ els},
          With[{u = DeleteDuplicates[heads]}, Lookup[AssociationThread[u, Boole[MatchQ[Append[#, {}], p] & /@ u]], heads]]],
        Boole[MatchQ[#, p] & /@ els]]]];

(* The matches of the needed names in the tag and attribute slots: the tag
   is {p, 0}, a name on the attribute argument {p, Key[All]}, a value
   {p, Key[k]}, a list key's value {p, Key[listKey]} and the tokens in it the
   tails after that. *)
headMatches[nd_, i_] /; nd["HeadNames"] === {} := {<||>};
headMatches[nd_, i_] /; nd["PlainRules"] =!= None := plainAttributeMatches[nd["PlainRules"], elemOf[i], i];
headMatches[nd_, i_] :=
  With[{x = elemOf[i], need = nd["HeadNames"]},
    product[{tagMatches[nd["Tag"], x, i, need], attributeMatches[nd["Attrs"], x, i, need]}]];

tagMatches[tag_, x_, i_, need_] :=
  With[{names = Intersection[namesIn[Hold[tag]], need]},
    If[names === {}, {<||>},
      {Map[nameMatch[{Append[posOf[i], 0]}, #, Join[elemKey[i], tagKey[]]] &, firstMatchValues[x[[1]], tag, names]]}]];

attributeMatches[Verbatim[Pattern][s_Symbol, a_], x_, i_, need_] :=
  If[MemberQ[need, Hold[s]],
    joinAll[attributeMatches[a, x, i, need], <|Hold[s] -> nameMatch[{Append[posOf[i], Key[All]]}, x[[2]], Join[elemKey[i], attributeMapKey[]]]|>],
    attributeMatches[a, x, i, need]];
attributeMatches[Verbatim[PatternTest][a_, _], x_, i_, need_] := attributeMatches[a, x, i, need];
attributeMatches[r_Rule, x_, i_, need_] := attributeMatches[{r}, x, i, need];
(* With no Alternatives key, the keys are distinct (the compiler refuses a
   duplicate), so each rule has its one attribute, and only the rules that
   bind a needed name are read. *)
attributeMatches[rules_List, x_, i_, need_] /; FreeQ[rules, Verbatim[Rule][_Alternatives, _]] :=
  With[{named = Cases[rules, r : Verbatim[Rule][_, v_] /; IntersectingQ[namesIn[Hold[v]], need]]},
    With[{slots = attributeSlots[x, i, Union @@ (keyLiterals[First[#]] & /@ named)]},
      project[product[MapIndexed[ruleMatches[#1, First[#2], slots, need] &, named]], need]]];
(* KeyValuePattern gives each rule a different attribute, so with an
   Alternatives key every rule is placed, those that bind nothing too, and a
   placement that gives two rules one attribute is dropped. *)
attributeMatches[rules_List, x_, i_, need_] :=
  With[{slots = attributeSlots[x, i, Union @@ (keyLiterals[First[Replace[#, k_?literalKeyQ :> (k -> _)]]] & /@ rules)]},
    project[
      Select[product[MapIndexed[ruleMatches[Replace[#1, k_?literalKeyQ :> (k -> _)], First[#2], slots, need] &, rules]],
        DuplicateFreeQ[Values[KeySelect[#, MatchQ[{"Taken", _}]]]] &],
      need]];
attributeMatches[_, _, _, _] := {<||>};

(* The common case: each rule is "key" -> name_ on a key that is not a list
   key, and the element passed the compiled test, so has the attribute. *)
plainRuleQ[r_] := MatchQ[r, Verbatim[Rule][k_String, Verbatim[Pattern][_Symbol, Verbatim[Blank][]]] /; !KeyExistsQ[$readings, k]];

plainAttributeMatches[pairs_, x_, i_] :=
  With[{attrs = x[[2]], p = posOf[i], k = elemKey[i]},
    With[{js = First @ FirstPosition[attrs[[All, 1]], #, {0}, {1}] & /@ pairs[[All, 1]]},
      {AssociationThread[pairs[[All, 2]],
        MapThread[nameMatch[{Append[p, Key[#1]]}, attrs[[#2, 2]], Join[k, attributeKey[#2]]] &, {pairs[[All, 1]], js}]]}]];

(* The places a rule on one of keys can take: each attribute so named, at
   {p, Key[k]}, and the token list of each list key among them, at
   {p, Key[listKey]}. *)
attributeSlots[x_, i_, keys_] :=
  With[{attrs = x[[2]], p = posOf[i], k = elemKey[i]},
    Join[
      <|"Key" -> attrs[[#, 1]], "Value" -> attrs[[#, 2]], "Pos" -> Append[p, Key[attrs[[#, 1]]]],
        "OrderKey" -> Join[k, attributeKey[#]], "List" -> False|> & /@ Select[Range[Length[attrs]], MemberQ[keys, attrs[[#, 1]]] &],
      KeyValueMap[Function[{listKey, reading},
          <|"Key" -> listKey, "Value" -> splitterOf[reading][Lookup[attrs, rawKeyOf[reading], ""]], "Pos" -> Append[p, Key[listKey]],
            "OrderKey" -> Join[k, tokenListKey[attributeIndex[attrs, rawKeyOf[reading]]]],
            "List" -> True|>],
        KeyTake[$readings, keys]]]];

(* The solutions of rule r at each slot it can take, each marked with the
   slot, as {"Taken", r} -> slot. A list key's value is read as the compiler
   reads it: a string, or alternatives of strings, is a token in the list
   (ADR 0011). *)
ruleMatches[k_ -> v_, r_, slots_, need_] :=
  With[{listValue = If[AllTrue[keyLiterals[k], KeyExistsQ[$readings, #] &], desugared[v], v],
      names = Intersection[namesIn[Hold[v]], need]},
    Join @@ MapIndexed[Function[{slot, j},
        Map[Append[#, {"Taken", r} -> First[j]] &,
          Which[
            !MatchQ[slot["Key"], k] || !slot["List"] && KeyExistsQ[$readings, slot["Key"]], {},
            slot["List"],
              Block[{$tokens = slot["Value"], $tokenPos = slot["Pos"], $tokenKey = slot["OrderKey"]},
                tokenListMatches[listValue, need]],
            !MatchQ[slot["Value"], v], {},
            names === {}, {<||>},
            True, {Map[nameMatch[{slot["Pos"]}, #, slot["OrderKey"]] &, firstMatchValues[slot["Value"], v, names]]}]]],
      slots]];
ruleMatches[___] := {};

(* As the compiler reads a list key's value (ADR 0011). *)
desugared[s : (_String | Verbatim[Alternatives][__String])] := {___, s, ___};
desugared[v_] := v;

(* The values the first match of pat against val gives names. A name in a
   branch that did not match is absent. *)
firstMatchValues[val_, Verbatim[Pattern][s_Symbol, Verbatim[Blank][]], {Hold[s_Symbol]}] := <|Hold[s] -> val|>;
firstMatchValues[val_, pat_, names_] :=
  With[{rule = memoised[{"Rule", pat, names},
      RuleDelayed @@ Join[Hold[pat], Replace[Join @@ (Replace[#, Hold[s_] :> Hold[{s}]] & /@ names), Hold[a___] :> Hold[{a}]]]]},
    Replace[First[ReplaceList[val, rule], None], {
      None -> <||>,
      vs_List :> Association @ MapThread[If[#2 === {}, Nothing, #1 -> Replace[#2, {{v_} :> v, l_ :> seq[l]}]] &, {names, vs}]}]];

(* ---- The token list of a list key ---- *)

tokenListMatches[Verbatim[Pattern][s_Symbol, p_], need_] :=
  If[MemberQ[need, Hold[s]], joinAll[tokenListMatches[p, need], <|Hold[s] -> nameMatch[{$tokenPos}, $tokens, $tokenKey]|>],
    tokenListMatches[p, need]];
tokenListMatches[c_Condition, need_] :=
  With[{test = Extract[c, {2}, Hold], inner = namesIn[Hold[c]]},
    project[Select[tokenListMatches[c[[1]], conditionNeed[c, test, need]], passesQ[test, inner, #] &],
      Intersection[inner, need]]];
tokenListMatches[Verbatim[PatternTest][p_, _], need_] := tokenListMatches[p, need];
tokenListMatches[l_List, need_] :=
  Block[{$place = "token", $single = cToken},
    With[{items = cItems[l, need]},
      walkTokens[items]]];
tokenListMatches[p_, need_] :=
  With[{names = Intersection[namesIn[Hold[p]], need]},
    Which[!MatchQ[$tokens, p], {}, names === {}, {<||>},
      True, {Map[nameMatch[{$tokenPos}, #, $tokenKey] &, firstMatchValues[$tokens, p, names]]}]];

(* One token: any WL pattern, each name in it matching the token. *)
cToken[p_, need_] := With[{names = namesIn[Hold[p]]}, treeNode["Token", names, need, "Pattern" -> p]];

walkTokens[items_] :=
  Block[{$n = Length[$tokens], $walkId = {"Tokens", $tokenPos}, $oneVector = tokenVector, $oneSolutions = tokenSolutions,
      $runMatch = tokenRun},
    project[Last /@ enumerate[items, 0, delta[$n]], Union @@ Prepend[#["Keep"] & /@ items, {}]]];

tokenVector[sub_] := Boole[MatchQ[#, sub["Pattern"]] & /@ $tokens];
tokenSolutions[sub_, k_] :=
  If[!MatchQ[$tokens[[k]], sub["Pattern"]], {},
    If[sub["Keep"] === {}, {<||>},
      {Map[nameMatch[{Append[$tokenPos, k]}, #, Join[$tokenKey, sequenceKey[2, k]]] &, firstMatchValues[$tokens[[k]], sub["Pattern"], sub["Keep"]]]}]];
tokenRun[s_, e_] := nameMatch[{Append[$tokenPos, s + 1 ;; e]}, seq[$tokens[[s + 1 ;; e]]], Join[$tokenKey, sequenceKey[2, s + 1 ;; e]]];

(* ---- Constraints ---- *)

matchConstraint[c_, i_] := memoised[{c["Id"], i}, constraintKind[c["Kind"], c, i]];

constraintKind["ConstraintAlt", c_, i_] := project[Join @@ (matchConstraint[#, i] & /@ c["Subs"]), c["Keep"]];

(* A named list binds the run of all element children, its value their list. *)
constraintKind["ListNamed", c_, i_] :=
  With[{sols = matchConstraint[c["Sub"], i], n = Length[childrenOf[i]]},
    If[MemberQ[c["Keep"], c["Name"]],
      joinAll[sols, <|c["Name"] -> nameMatch[{Append[posOf[i], 1 ;; n]}, elemOf /@ childrenOf[i], Join[elemKey[i], sequenceKey[4, 1 ;; n]]]|>],
      sols]];
constraintKind["ListCond", c_, i_] := conditionFiltered[c, matchConstraint[c["Sub"], i]];
constraintKind["ListTest", c_, i_] :=
  With[{sols = matchConstraint[c["Sub"], i]}, If[sols =!= {} && TrueQ[c["F"][elemOf /@ childrenOf[i]]], sols, {}]];

constraintKind["List", c_, i_] /; Length[childrenOf[i]] < c["Min"] := {};
constraintKind["List", c_, i_] :=
  Block[{$n = Length[childrenOf[i]], $walkId = i, $kidIds = childrenOf[i], $oneVector = childVector, $oneSolutions = childSolutions,
      $runMatch = childRun},
    If[oneCaptureQ[c] && boundChildQ[c], oneCapture[c],
      project[If[oneCaptureQ[c], oneCapture[c], walked[c["Items"]]], c["Keep"]]]];

(* Whether the one entry that binds a needed name binds the child itself, so
   that the solutions at two children differ, and need no projection. *)
boundChildQ[c_] := With[{sub = SelectFirst[c["Items"], capQ]["Sub"]}, sub["Kind"] === "Named" && MemberQ[sub["Keep"], sub["Name"]]];

(* The solutions of a list of entries over the children. An Except that
   refers to a name the list binds later records, at each child, what it
   would exclude, and the walk branches on those records: one branch per
   place, a pass over the children each, so -of-type on a compound with no
   type grew as the square of the siblings. When every such name is bound by
   a one-child entry of the list itself to a value that is not a place, the
   list is walked once for each value it can take there instead, with the
   name bound beforehand, so that the Excepts are vectors and nothing
   branches; a solution counts only where the list binds the name to that
   value. That is one walk per distinct tag among the siblings. *)
walked[items_] :=
  With[{refs = prebindable[items]},
    With[{values = refValues[items, #] & /@ refs},
      If[refs === {} || AnyTrue[Flatten[values, 1], placeQ],
        Last /@ enumerate[items, 0, delta[$n]],
        Join @@ Function[bs,
            Block[{$bound = Join[$bound, AssociationThread[refs, bs]]},
              Select[boundWalk[items],
                Function[sol, AllTrue[Range[Length[refs]], matchVal[sol[refs[[#]]]] === matchVal[bs[[#]]] &]]]]] /@
          Tuples[values]]]];

(* The walk with the names bound. Its Excepts are vectors then, so when the
   one entry left that binds a name is one child, it is taken as oneCapture
   takes it, by three vectors, without a walk. *)
boundWalk[items_] :=
  With[{caps = Flatten @ Position[capQ[#] && !boundOnlyQ[#] & /@ items, True]},
    If[Length[caps] == 1 && items[[First[caps]]]["Kind"] === "One", oneCaptureAt[items, First[caps]],
      Last /@ enumerate[items, 0, delta[$n]]]];

(* An Except, or a repeat of Excepts, whose names are all bound, and that
   binds nothing else: the walk reads it as a vector (entrySpans). *)
boundOnlyQ[it_] := Switch[it["Kind"],
  "Not", boundRecordQ[it] && it["Keep"] === {it["Record"]},
  "Repeat", AllTrue[it["Items"], !capQ[#] || boundOnlyQ[#] &],
  _, False];

(* The names the Excepts among items refer to that a one-child entry of items
   binds, and that are not bound already. A name an Except inside an entry's
   own pattern refers to is left out: that entry's matches are memoised
   whatever is bound. *)
prebindable[items_] := Select[prebindableNames[items], !KeyExistsQ[$bound, #] &];

prebindableNames[items_] :=
  memoised[{"Prebindable", #["Id"] & /@ items},
    With[{entries = Flatten[entriesIn /@ items]},
      With[{inner = recordRefs[Flatten[subNodes /@ Select[entries, MatchQ[#["Kind"], "One" | "Not"] &]]]},
        Select[recordRefs[entries],
          !MemberQ[inner, #] && AnyTrue[items, Function[it, it["Kind"] === "One" && MemberQ[it["Keep"], #]]] &]]]];

(* An entry and the entries inside it, not inside the patterns they test. *)
entriesIn[it_] := Prepend[Flatten[entriesIn /@ Switch[it["Kind"],
  "Run" | "Repeat", it["Items"],
  "Branches", Flatten[it["Subs"]],
  "SeqCond", it["Sub"]["Items"],
  _, {}]], it];

(* The names the Excepts among nodes, and every node below them, refer to. *)
recordRefs[nodes_] :=
  Union @@ Prepend[First[#["Record"]] & /@ Select[Flatten[allNodes /@ nodes], #["Kind"] === "Not" && #["Record"] =!= None &], {}];
allNodes[nd_] := Prepend[Flatten[allNodes /@ subNodes[nd]], nd];

(* The distinct values the one-child entries of items bind ref to, each as a
   match with no position, as an Except compares it; a place keeps its
   match, and is not walked for. *)
refValues[items_, ref_] :=
  If[placeQ[#], #, nameMatch[{Missing["Except"]}, matchVal[#], {}]] & /@ DeleteDuplicatesBy[
    Join @@ Function[it,
        With[{ks = Flatten[Position[itemVector[it["Sub"]], 1]]},
          If[tagNameQ[it["Sub"], ref], nameMatch[{Missing["Except"]}, #, {}] & /@ DeleteDuplicates[kidTags[][[ks]]],
            Join @@ (Function[k, Cases[$oneSolutions[it["Sub"], k], s_ /; KeyExistsQ[s, ref] :> s[ref]]] /@ ks)]]] /@
      Select[items, #["Kind"] === "One" && MemberQ[#["Keep"], ref] &],
    matchVal];

(* Whether a pattern root binds ref to the tag of the element it matches, as
   XMLPattern[ref_, ...] does. *)
tagNameQ[nd_, ref_] := Switch[nd["Kind"],
  "Named", tagNameQ[nd["Sub"], ref],
  "XMLPattern", MatchQ[nd["Tag"], Verbatim[Pattern][s_, Verbatim[Blank][]] /; Hold[s] === ref],
  _, False];

(* The tags of the children walked. *)
kidTags[] := memoised[{"Tags", $walkId}, elemOf[#][[1]] & /@ $kidIds];

(* Some element strictly below, at DOM depths in the level spec, matches. *)
constraintKind["Descendant", c_, i_] :=
  Module[{lo, hi, d0 = $depth[[i + 1]], below, cands, sub = c["Sub"]},
    {lo, hi} = c["Levels"];
    below = Range[i + 1, $end[[i + 1]]];
    cands = Pick[below, candidateVector[sub][[below]] UnitStep[$depth[[below + 1]] - d0 - lo] UnitStep[hi - ($depth[[below + 1]] - d0)], 1];
    If[c["Keep"] === {},
      If[AnyTrue[cands, match[sub, #] =!= {} &], {<||>}, {}],
      project[Join @@ (descendantSolutions[sub, #, c["Key"]] & /@ cands), c["Keep"]]]];

descendantSolutions[sub_, j_, key_] :=
  With[{sols = If[directQ[sub], {<|sub["Name"] -> elemMatch[j]|>}, match[sub, j]]},
    If[key === None, sols, Append[#, key -> nameMatch[{posOf[j]}, j, elemKey[j]]] & /@ sols]];

(* ---- Paths ---- *)

(* The lower end of a path solution. *)
lowerEnd[c_, sol_] := matchVal[sol[c["Key"]]];

(* The elements strictly between i and j, a node below it, outermost first. *)
pathIds[i_, j_] := Reverse @ Most @ NestWhileList[$parent[[# + 1]] &, $parent[[j + 1]], # != i &];

(* A path's position is the span of its ends, upper ;; lower; it sorts by its
   lower end, then its upper end (pathKey, padded). *)
pathMatch[i_, j_] := nameMatch[{posOf[i] ;; posOf[j]}, elemOf /@ pathIds[i, j], pathKey[elemKey[j], elemKey[i]]];

constraintKind["PathNamed", c_, i_] :=
  With[{sols = matchConstraint[c["Sub"], i]},
    project[If[MemberQ[c["Keep"], c["Name"]],
        DeleteCases[joined[#, <|c["Name"] -> pathMatch[i, lowerEnd[c, #]]|>] & /@ sols, $Failed], sols],
      c["Keep"]]];
constraintKind["PathTest", c_, i_] :=
  Select[matchConstraint[c["Sub"], i], TrueQ[c["F"][elemOf /@ pathIds[i, lowerEnd[c, #]]]] &];
constraintKind["PathCond", c_, i_] := conditionFiltered[c, matchConstraint[c["Sub"], i]];
constraintKind["PathNearest", c_, i_] := matchConstraint[c["Sub"], i];

(* Shortest keeps a (root, match) pair only if no element strictly between
   matches the whole root pattern with that match: its tag and attributes,
   every other constraint, and this one with the same lower end. Longest
   keeps it only if no element above the root does. The Conditions the root's
   node runs, and those around it, are not part of the comparison. *)
nearestFiltered[nd_, c_, i_] :=
  With[{sols = matchConstraint[c, i], within = If[nearestOf[c] === Shortest, pathIds[i, #] &, ancestorsOf[i] &]},
    Select[sols, With[{j = lowerEnd[c, #]}, NoneTrue[within[j], shadowsQ[nd, c, #, j] &]] &]];

ancestorsOf[i_] := Most @ NestWhileList[$parent[[# + 1]] &, $parent[[i + 1]], # != 0 &];

shadowsQ[nd_, c_, k_, j_] :=
  memoised[{"Shadow", c["Id"], k, j},
    headVector[nd][[k]] == 1 && Length[childrenOf[k]] >= nd["MinKids"] &&
      MemberQ[lowerEnd[c, #] & /@ matchConstraint[c, k], j] &&
      AllTrue[DeleteCases[nd["Constraints"], c], matchConstraint[#, k] =!= {} &]];

(* A Condition on an XMLPattern without constraints that sees only names
   its attribute rules bind as "key" -> name_, on keys that are not list
   keys: each name has one value, the attribute's, so the test is a function
   of the attribute values, applied to each element that passes the compiled
   test, several times faster than matching each element. *)
flatConditionQ[nd_] :=
  With[{s = nd["Sub"]},
    s["Kind"] === "XMLPattern" && s["Constraints"] === {} && s["Readings"] === {} && ListQ[s["PlainRules"]] && DuplicateFreeQ[s["PlainRules"][[All, 2]]] &&
      SubsetQ[s["PlainRules"][[All, 2]], nd["Sees"]]];

(* The candidates of a flat Condition that pass it. *)
conditionPassing[nd_, cands_] :=
  With[{rules = nd["Sub"]["PlainRules"]},
    With[{f = Replace[{Join @@ rules[[All, 2]], nd["Test"]}, {Hold[v___], Hold[b_]} :> Function[{v}, b]], keys = rules[[All, 1]]},
      Select[cands, TrueQ[f @@ Lookup[elemOf[#][[2]], keys]] &]]];

(* Whether each element can match a pattern root: a vector over the elements
   that is 1 at every match, for skipping the rest. *)
candidateVector[nd_] := memoised[{"Candidates", nd["Id"]}, candidates[nd]];
candidates[nd_] := Switch[nd["Kind"],
  "Named" | "Cond" | "Test", candidateVector[nd["Sub"]],
  "Alt", Unitize[Total[candidateVector /@ nd["Subs"]]],
  "XMLPattern", headVector[nd] UnitStep[(Length /@ Rest[$kids]) - nd["MinKids"]] Times @@ Prepend[constraintFilter /@ nd["Constraints"], 1],
  "XMLDocument", ConstantArray[0, Length[$elem] - 1],
  _, ConstantArray[1, Length[$elem] - 1]];

(* =========================================================== *)
(* Contents lists                                               *)
(*                                                              *)
(* The places between the n items are 0..n; a set of places is  *)
(* a 0/1 vector of length n + 1. An entry that binds no needed  *)
(* name is a vector operation on the places it can start from;  *)
(* the walk branches only at the others. The items are a node's *)
(* element children or a list key's tokens: $oneVector,         *)
(* $oneSolutions and $runMatch read them.                     *)
(* =========================================================== *)

delta[p_] := UnitVector[$n + 1, p + 1];

childVector[sub_] :=
  memoised[{"Vector", sub["Id"], $walkId},
    Developer`ToPackedArray @ If[exactCandidatesQ[sub],
      candidateVector[sub][[$kidIds]],
      Boole[match[sub, #] =!= {} & /@ $kidIds]]];

(* A list constraint holds only at an element with a child that can match
   each of its one-child entries, so the elements without are not walked:
   a CSS translation's list is tried at every element with children, and
   walking each costs about a tenth of a millisecond. *)
constraintFilter[c_] := Switch[c["Kind"],
  "List", Times @@ Prepend[parentsWith /@ Select[c["Items"], #["Kind"] === "One" &], 1],
  "ListNamed" | "ListCond" | "ListTest", constraintFilter[c["Sub"]],
  _, 1];

parentsWith[it_] :=
  memoised[{"Parents", it["Id"]},
    Module[{v = ConstantArray[0, Length[$elem] - 1]},
      v[[DeleteCases[$parent[[Flatten[Position[candidateVector[it["Sub"]], 1]] + 1]], 0]]] = 1;
      v]];

(* Whether a pattern root's candidates are exactly its matches: it tests only
   an element's tag and attributes, which the compiled test decides. *)
exactCandidatesQ[nd_] := Switch[nd["Kind"],
  "XMLPattern", nd["Constraints"] === {},
  "Blank", nd["Head"] === {},
  "Named", exactCandidatesQ[nd["Sub"]],
  "Alt", AllTrue[nd["Subs"], exactCandidatesQ],
  _, False];
childSolutions[sub_, k_] := match[sub, $kidIds[[k]]];
childRun[s_, e_] :=
  nameMatch[{Append[posOf[$walkId], s + 1 ;; e]}, seq[elemOf /@ $kidIds[[s + 1 ;; e]]], Join[elemKey[$walkId], sequenceKey[4, s + 1 ;; e]]];

itemVector[sub_] := memoised[{"ItemVector", sub["Id"], $walkId}, $oneVector[sub]];

(* dir 1: forward, from the places items may start to where they may end;
   dir -1: backward, from where they must end to where they may start. *)
reach[items_List, s_, dir_] := Fold[reachOne[#2, #1, dir] &, s, If[dir == 1, items, Reverse[items]]];

(* A Condition on a span is passed over here, so the reach is a superset;
   the walk tests it at each span. *)
reachOne[it_, s_, dir_] := Switch[it["Kind"],
  "One", shift[s, itemVector[it["Sub"]], dir],
  "Not", shift[s, notVector[it], dir],
  "Any", anyFrom[s, it["Min"], dir],
  "Run", reach[it["Items"], s, dir],
  "SeqCond", reach[it["Sub"]["Items"], s, dir],
  "Branches", Unitize[Total[reach[#, s, dir] & /@ it["Subs"]]],
  "Repeat", repeatReach[it, s, dir]];

(* An Except that refers to a name matched outside it may match any child,
   until that match is known (settled). When the walk has already bound it, in
   $bound, the children it excludes are known. *)
notVector[it_] :=
  Which[
    it["Record"] === None, 1 - itemVector[it["Sub"]],
    boundRecordQ[it], 1 - excludedVector[it],
    True, 1] If[it["Base"] === None, 1, itemVector[it["Base"]]];

$bound = <||>;

boundRecordQ[it_] := it["Kind"] === "Not" && it["Record"] =!= None && AllTrue[First[it["Record"]], KeyExistsQ[$bound, #] &];

excludedVector[it_] :=
  With[{refs = First[it["Record"]]},
    With[{b = KeyTake[$bound, refs]},
      memoised[{"Excluded", it["Id"], $walkId, matchVal /@ Values[b]},
        If[$oneSolutions === childSolutions && Length[refs] == 1 && tagNameQ[it["Sub"], First[refs]],
          itemVector[it["Sub"]] Boole[SameQ[#, matchVal[First[b]]] & /@ kidTags[]],
        Boole[Table[
          AnyTrue[forbiddenAt[$oneSolutions[it["Sub"], k], refs], joined[#, KeyTake[b, Keys[#]]] =!= $Failed &],
          {k, $n}]]]]]];

shift[s_, t_, 1] := Prepend[Most[s] t, 0];
shift[s_, t_, -1] := Append[Rest[s] t, 0];

anyFrom[s_, 0, 1] := Unitize[Accumulate[s]];
anyFrom[s_, 0, -1] := Reverse[Unitize[Accumulate[Reverse[s]]]];
anyFrom[s_, m_, dir_] := anyFrom[Nest[shift[#, ConstantArray[1, $n], dir] &, s, m], 0, dir];

(* A repeat of entries that each match any one child, as
   PatternSequence[_, _] ..., moves by whole blocks: it is read off the places
   in rows of the block's length, a running total down each column. Stepping
   one repeat at a time costs a pass over the children per repeat, which is
   quadratic in the siblings for li:nth-child(2n+1). *)
repeatReach[it_, s_, dir_] /; it["Items"] =!= {} && AllTrue[it["Items"], vectorEntryQ[#] && Min[entryVector[#]] == 1 &] :=
  If[dir == 1, blockReach[s, Length[it["Items"]], it["Min"], it["Max"]], Reverse @ blockReach[Reverse[s], Length[it["Items"]], it["Min"], it["Max"]]];

(* A repeat of one entry that is one child tested by a vector, as
   Except[XMLPattern[t_]] ... once t is bound, reaches a place from the last
   place before it, lo children back or more, from which every child between
   passes: a running maximum, and a count of the children that fail, which
   two places with none failing between share. Stepping one repeat at a time
   costs a pass over the children per repeat. *)
repeatReach[it_, s_, dir_] /; MatchQ[it["Items"], {e_} /; vectorEntryQ[e] || boundRecordQ[e]] :=
  With[{v = entryVector[First[it["Items"]]]},
    If[dir == 1, runReach[s, v, it["Min"], it["Max"]], Reverse @ runReach[Reverse[s], Reverse[v], it["Min"], it["Max"]]]];

runReach[s_, v_, lo_, hi_] :=
  With[{places = Range[0, Length[v]], blocks = Prepend[Accumulate[1 - v], 0], k = Min[lo, Length[s]]},
    With[{last = Join[ConstantArray[-1, k], Drop[FoldList[Max, places s - (1 - s)], -k]]},
      UnitStep[last] (1 - Unitize[blocks[[Clip[last, {0, Infinity}] + 1]] - blocks]) If[hi === Infinity, 1, UnitStep[hi - (places - last)]]]];

blockReach[s_, l_, lo_, hi_] :=
  With[{rows = Accumulate[Partition[PadRight[s, l Ceiling[Length[s]/l]], l]]},
    Take[Flatten @ Unitize[rowsDown[rows, lo] - If[hi === Infinity, 0, rowsDown[rows, hi + 1]]], Length[s]]];

rowsDown[rows_, k_] := If[k >= Length[rows], 0 rows, Join[ConstantArray[0, {k, Last[Dimensions[rows]]}], Drop[rows, -k]]];

repeatReach[it_, s_, dir_] :=
  Module[{acc = If[it["Min"] == 0, s, 0 s], cur = s, k = 0},
    While[k < it["Max"] && Total[cur] > 0,
      k++;
      cur = reach[it["Items"], cur, dir];
      If[k >= it["Min"], cur = cur (1 - acc); acc = Unitize[acc + cur]]];
    acc];

(* The spans of items from place s0 that end where endOK is 1, each with its
   solution: a list of {end, solution}. Between the entries the walk branches
   at, boolean reachability; at each of them, its spans from each place that
   can still reach the end. An entry sees the names bound before it, $bound.
   back: where each entry may start, which a repeat computes once for all its
   repeats. *)
enumerate[items_, s0_, endOK_] := enumerate[items, s0, endOK, backReach[items, endOK]];
enumerate[items_, s0_, endOK_, back_] :=
  Module[{caps, frontier = {{s0, <||>}}, prev = 0, ends},
    caps = Flatten @ Position[capQ /@ items, True];
    Do[
      ends = segmentEnds[items[[prev + 1 ;; c - 1]], back[[c]]];
      frontier = Join @@ Function[f,
          Join @@ (Function[s,
              With[{m = joined[f[[2]], #[[2]]]}, If[m === $Failed, Nothing, {#[[1]], m}]] & /@
                boundIn[f[[2]], entrySpans[items[[c]], s, back[[c + 1]]]]] /@ ends[f[[1]]])] /@ frontier;
      prev = c,
      {c, caps}];
    ends = segmentEnds[items[[prev + 1 ;;]], endOK];
    Join @@ Function[f, {#, f[[2]]} & /@ ends[f[[1]]]] /@ frontier];

(* The places each place s can reach over a run of entries the walk does not
   branch at, where target is 1, as a function of s. Reaching from each place
   of the frontier by vectors costs a pass over the children per place, which
   is quadratic when the frontier holds a place per child, as after a repeat
   that branches. So the common runs are read off target directly: none, a
   fixed number of one-child entries, or ___ gaps, whose ends are the places
   of target from s + their minimum on, in one Take of a list built once. *)
segmentEnds[{}, target_] := Function[s, If[target[[s + 1]] == 1, {s}, {}]];
segmentEnds[seg_, target_] /; AllTrue[seg, vectorEntryQ] :=
  With[{l = Length[seg], vs = entryVector /@ seg},
    Function[s, If[s + l <= $n && target[[s + l + 1]] == 1 && AllTrue[Range[l], vs[[#, s + #]] == 1 &], {s + l}, {}]]];
segmentEnds[seg_, target_] /; AllTrue[seg, #["Kind"] === "Any" &] :=
  With[{m = Total[#["Min"] & /@ seg], places = Flatten @ Position[target, 1] - 1, before = Prepend[Accumulate[target], 0]},
    Function[s, If[s + m > $n, {}, Drop[places, before[[s + m + 1]]]]]];
segmentEnds[seg_, target_] := Function[s, Flatten @ Position[reach[seg, delta[s], 1] target, 1] - 1];

(* An entry that is one child tested by a vector. *)
vectorEntryQ[it_] := it["Kind"] === "One" || it["Kind"] === "Not" && it["Record"] === None;
entryVector[it_] := If[it["Kind"] === "One", itemVector[it["Sub"]], notVector[it]];

entrySpans[it_, s_, next_] := Switch[it["Kind"],
  "One",
    If[s < $n && next[[s + 2]] == 1, {s + 1, #} & /@ $oneSolutions[it["Sub"], s + 1], {}],
  "Not",
    If[s < $n && next[[s + 2]] == 1 && (it["Record"] =!= None || itemVector[it["Sub"]][[s + 1]] == 0),
      {s + 1, #} & /@ notSolutions[it, s + 1], {}],
  "Run",
    With[{inner = enumerate[it["Items"], s, next]},
      projectSpans[If[MemberQ[it["Keep"], it["Name"]], {#[[1]], Append[#[[2]], it["Name"] -> $runMatch[s, #[[1]]]]} & /@ inner, inner], it["Keep"]]],
  "SeqCond",
    projectSpans[Select[enumerate[it["Sub"]["Items"], s, next], passesQ[it["Test"], it["Sees"], #[[2]]] &], it["Keep"]],
  "Branches",
    projectSpans[Join @@ (Function[b, With[{inner = enumerate[b, s, next]},
      If[it["Slot"] === None, inner, {#[[1]], Append[#[[2]], it["Slot"] -> $runMatch[s, #[[1]]]]} & /@ inner]]] /@ it["Subs"]), it["Keep"]],
  "Repeat",
    If[capQ[it] && !AllTrue[it["Items"], !capQ[#] || boundRecordQ[#] && #["Keep"] === {#["Record"]} &],
      repeatSpans[it, s, next],
      {#, <||>} & /@ (Flatten @ Position[repeatReach[it, delta[s], 1] next, 1] - 1)]];

(* An Except entry's solutions at item k: the base's, or one with no names,
   and, when it refers to names matched outside it, the record of what its
   pattern binds them to there. *)
notSolutions[it_, k_] :=
  With[{sols = If[it["Base"] === None, {<||>}, $oneSolutions[it["Base"], k]]},
    Which[
      it["Record"] === None, sols,
      boundRecordQ[it], If[excludedVector[it][[k]] == 1, {}, sols],
      True,
        With[{rec = forbiddenAt[$oneSolutions[it["Sub"], k], First[it["Record"]]]},
          If[rec === {}, sols, DeleteCases[settled[False, Append[#, it["Record"] -> forbidden[rec]]] & /@ sols, $Failed]]]]];

(* A repeat that binds a needed name, one repeat at a time: each binds the
   names again, and a repeated name compares its values, as in WL. A repeat
   that matches nothing ends the walk once the minimum is met. *)
repeatSpans[it_, s_, next_] :=
  Module[{again = repeatReach[Append[it, "Min" -> 0], next, -1], back, states = {{s, <||>}}, k = 0},
    back = backReach[it["Items"], again];
    projectSpans[Select[Join @@ Flatten[Last @ Reap[
        If[it["Min"] == 0, Sow[states]];
        While[states =!= {} && k < it["Max"],
          k++;
          states = DeleteDuplicatesBy[
            Join @@ Function[st,
                With[{m = joined[st[[2]], #[[2]]]}, If[m === $Failed || #[[1]] == st[[1]] && k > it["Min"], Nothing, {#[[1]], m}]] & /@
                  boundIn[st[[2]], repeatOnce[it["Items"], st[[1]], again, back]]] /@ states,
            {#[[1]], identity[#[[2]], Keys[#[[2]]]]} &];
          If[k >= it["Min"], Sow[states]]]], 1],
      next[[#[[1]] + 1]] == 1 &], it["Keep"]]];

(* One repeat from place s: a repeat of one entry that is one item is that
   entry's spans, without a walk. *)
repeatOnce[{it_}, s_, again_, _] /; MatchQ[it["Kind"], "One" | "Not"] := entrySpans[it, s, again];
repeatOnce[items_, s_, again_, back_] := enumerate[items, s, again, back];

(* What the entries of a walk see as bound before them, when an Except may
   refer to it. *)
SetAttributes[boundIn, HoldRest];
boundIn[sol_, code_] := If[$records, Block[{$bound = Join[$bound, sol]}, code], code];

backReach[items_, endOK_] := Reverse @ FoldList[reachOne[#2, #1, -1] &, endOK, Reverse[items]];

projectSpans[sps_, keep_] := DeleteDuplicatesBy[{#[[1]], KeyTake[#[[2]], keep]} & /@ sps, {#[[1]], identity[#[[2]], keep]} &];

(* One needed name on one entry that is one child, and nothing else to
   branch at: the children it binds are where the entries before it can end,
   it matches, and the entries after it can match the rest. *)
oneCaptureQ[c_] :=
  With[{caps = Select[c["Items"], capQ]}, Length[caps] == 1 && caps[[1]]["Kind"] === "One"];

oneCapture[c_] := oneCaptureAt[c["Items"], First @ FirstPosition[capQ /@ c["Items"], True]];

oneCaptureAt[items_, k_] :=
  With[{f = reach[Take[items, k - 1], delta[0], 1], b = reach[Drop[items, k], delta[$n], -1], sub = items[[k]]["Sub"]},
    hitSolutions[sub, Flatten @ Position[Most[f] itemVector[sub] Rest[b], 1]]];

(* The solutions of the items ks, known to match. A name on an element
   pattern with nothing else to bind, which the item's vector has already
   tested, is bound without matching again, each child's match built from
   its parent's. *)
hitSolutions[sub_, ks_] /; $oneSolutions === childSolutions && directQ[sub] :=
  With[{name = sub["Name"], p = posOf[$walkId], key = elemKey[$walkId]},
    MapThread[<|name -> nameMatch[{Append[p, #1]}, elemOf[#2], Join[key, sequenceKey[4, #1]]]|> &, {ks, $kidIds[[ks]]}]];
hitSolutions[sub_, ks_] := Join @@ ($oneSolutions[sub, #] & /@ ks);

directQ[nd_] := nd["Kind"] === "Named" && With[{s = nd["Sub"]}, s["Kind"] === "XMLPattern" && s["Constraints"] === {} && s["Keep"] === {}];

(* =========================================================== *)
(* Solutions                                                    *)
(* =========================================================== *)

(* ---- Repeated names ----

   A name used twice compares its matches by what they are and where they
   sit. A place (an element, a run or gap, a named path or list) bound in
   two constraints of one tree pattern must be the same position: both
   constraints range over the same children, so naming one in both pins it,
   which is how a query intersects two positional tests
   (li:nth-child(3):nth-last-child(2) is {_, _, n : li, ___} and
   {___, n : li, _}). Everywhere else the matches must be equal values, as
   in WL: two slots of one list, which can never be one place, so that
   {___, x : tr, ___, x : tr, ___} finds duplicates; an ancestor and a
   descendant, likewise; and every string (tag, attribute value, token,
   text), which a test such as "the same tag as n" compares wherever it is
   bound. Value equality everywhere would leave the intersection without a
   plain pattern; position equality everywhere would lose the duplicates
   idiom. So joins inside one constraint compare values (joined), and the
   join of a tree pattern's constraints compares the positions of places
   (joinedAcross). A name compared by value keeps all its positions, each in
   the tuple; compared by position it has one. The branches of one
   Alternatives are not a repeat: their names are bound once, by the branch
   that matched (repeatedNames). *)

joined[a_, b_] /; Length[a] == 0 := b;
joined[a_, b_] /; Length[b] == 0 := a;
joined[a_, b_] := joinedIn[False, a, b];
joinedAcross[a_, b_] /; Length[a] == 0 := b;
joinedAcross[a_, b_] /; Length[b] == 0 := a;
joinedAcross[a_, b_] := joinedIn[True, a, b];

joinedIn[across_, a_, b_] :=
  With[{shared = Intersection[Keys[a], Keys[b]]},
    Which[
      shared === {}, If[$records, settled[across, Join[b, a]], Join[b, a]],
      AllTrue[shared, sameMatchQ[across, a[#], b[#]] &],
        settled[across, Join[b, a, Association[(# -> mergedMatch[across, a[#], b[#]]) & /@ shared]]],
      True, $Failed]];

sameMatchQ[_, _forbidden, _forbidden] := True;
sameMatchQ[True, x_, y_] /; placeQ[x] && placeQ[y] := Union[matchPos[x]] === Union[matchPos[y]];
sameMatchQ[_, x_, y_] := matchVal[x] === matchVal[y];

mergedMatch[_, forbidden[x_], forbidden[y_]] := forbidden[Union[x, y]];
mergedMatch[True, x_, y_] /; placeQ[x] := x;
mergedMatch[_, x_, y_] :=
  With[{ps = SortBy[DeleteDuplicatesBy[Join[Transpose[{matchPos[x], x[[3]]}], Transpose[{matchPos[y], y[[3]]}]], First], padded @* Last]},
    {ps[[All, 1]], matchVal[x], ps[[All, 2]]}];

(* A match of a place: an element, a run or gap of children, a named path
   or the document; not a tag, attribute, token, text or contents. *)
placeQ[b_] := AllTrue[matchPos[b], MatchQ[#, _Span | {___Integer?Positive} | {___Integer?Positive, _Span}] &];

joinAll[sols_, extra_] := DeleteCases[joined[#, extra] & /@ sols, $Failed];

product[lists_] := product[lists, joined];
product[lists_, join_] := Fold[Function[{acc, l},
    Which[acc === {} || l === {}, {},
      l === {<||>}, acc,
      acc === {<||>}, l,
      True, DeleteCases[Flatten[Outer[join, acc, l, 1], 1], $Failed]]], {<||>}, lists];

(* ---- Except over a name matched outside it ----

   A name inside Except that is also bound outside it, anywhere in the rule,
   refers to that match (exceptRefs). The Except cannot test the child
   until that match is known, which in WL's left-to-right reading may be
   later in the list or above it. So the entry matches any child, and the
   solution records what the Except's pattern binds those names to there,
   exceptKey[names] -> forbidden[{match, ...}]. Once the names are bound,
   at the join that brings them (settled), the solution fails if a recorded
   match is what a second match of the name there would have to equal:
   the same value, or the same child when the join is across constraints. A
   record left at the pattern root, its names bound nowhere in the branch
   that matched, excludes as a local Except does (unsettled). *)

(* $records: whether the query has such an Except, set when it is compiled. *)
$records = False;

settled[across_, sol_] :=
  With[{ks = Cases[Keys[sol], _exceptKey]},
    If[ks === {}, sol,
      Fold[Function[{s, k},
          Which[
            s === $Failed || !AllTrue[First[k], KeyExistsQ[s, #] &], s,
            AnyTrue[First[s[k]], joinedIn[across, #, KeyTake[s, Keys[#]]] =!= $Failed &], $Failed,
            True, KeyDrop[s, Key[k]]]],
        sol, ks]]];

unsettled[sols_] := Select[sols, FreeQ[Keys[#], _exceptKey] &];

(* What the Except's pattern binds its outside names to at one child. A
   string is compared by value only, so its position is dropped and equal
   values are recorded once. *)
forbiddenAt[sols_, refs_] :=
  DeleteDuplicates[Map[If[placeQ[#], #, {{Missing["Except"]}, matchVal[#], {{}}}] &, KeyTake[#, refs]] & /@ sols];

(* The distinct solutions on keep. *)
project[{}, _] := {};
project[{s_}, keep_] := {KeyTake[s, keep]};
project[sols_, keep_] := DeleteDuplicatesBy[KeyTake[#, keep] & /@ sols, identity[#, keep] &];

(* A match is identified by its positions; one without, by its value. *)
identity[sol_, names_] := identityOf /@ Lookup[sol, names, None];
identityOf[None] := None;
identityOf[forbidden[l_]] := l;
identityOf[b_] := If[MatchQ[matchPos[b], {_Missing}], {"Value", matchVal[b]}, matchPos[b]];

(* Held code with each name replaced by its value; an absent name is
   Sequence[], as a name in an Alternatives branch that did not match is in
   WL. *)
substituted[held_, names_, sol_] :=
  held /. (Replace[#, Hold[s_] :> (HoldPattern[s] -> valueOf[Lookup[sol, Key[#], None]])] & /@ names);

valueOf[None] := Sequence[];
valueOf[b_] := Replace[matchVal[b], seq[l_] :> Sequence @@ l];

passesQ[test_Hold, names_, sol_] := TrueQ[ReleaseHold[substituted[test, names, sol]]];

(* =========================================================== *)
(* Results (ADR 0024)                                           *)
(* =========================================================== *)

$noResult = Unique["noResult"];

(* One result for each distinct tuple of positions of the counted names, in
   result order: a nested loop over the counted names in pattern order, the
   first slowest, each in position order. The names in one Alternatives share
   its slot, keyed by the first of them the tuple binds, or by where the
   Alternatives matched when it binds none. The bare input's own position is
   never counted. Each result is what the output mode makes of its tuple
   (resultOf). *)
results[mode_, root_, rhs_, all_, counted_, {}, bare_, n_] /;
    root["Kind"] === "Named" && counted === {root["Name"]} && !MemberQ[root["Sub"]["Names"], root["Name"]] && FreeQ[root["Sub"]["Keep"], _exceptKey] :=
  rootMatches[mode, root, rhs, all, bare, n];
(* The right-hand side is the one counted name: each result is the value of
   a distinct match, so the solutions are neither grouped nor evaluated,
   only their matches deduplicated and sorted. A name in an Alternatives
   slot is keyed by its own position when it is bound, so a solution without
   the name keeps the general way. *)
results[mode_, root_, rhs_, all_, {name_}, {}, bare_, n_] /; mode === "Values" && rhs === Hold @@ name :=
  Module[{sols, bs},
    sols = rootSolutions[root, False];
    refuseBoundText[sols, {name}];
    bs = Lookup[#, Key[name], None] & /@ sols;
    If[bare, bs = Select[bs, !MatchQ[#, {{___, {1} | Verbatim[Span][{1}, _], ___}, _, _}] &]];
    bs = DeleteDuplicatesBy[bs, identityOf];
    {valueOf[#]} & /@ Take[bs[[Ordering[padded[matchKey[#]] & /@ bs]]], UpTo[n]] /; FreeQ[bs, None, {1}]];
results[mode_, root_, rhs_, all_, counted_, testNames_, bare_, n_] :=
  Module[{sols, groups, slots, keys, count = 0, k = 1, r},
    sols = rootSolutions[root, counted === {} && testNames === {}];
    refuseBoundText[sols, counted];
    If[bare, sols = Select[sols, NoneTrue[Lookup[#, counted, None], MatchQ[{{___, {1} | Verbatim[Span][{1}, _], ___}, _, _}]] &]];
    groups = Values @ GroupBy[sols, identity[#, counted] &];
    slots = DeleteDuplicates[Lookup[$slotOf, counted, Null] /. Null -> Nothing];
    slots = SortBy[Join[slots, Select[counted, !KeyExistsQ[$slotOf, #] &]], $order];
    keys = First[Sort[resultKey[#, slots, counted] & /@ #]] & /@ groups;
    groups = groups[[Ordering[keys]]];
    reapedResults[
      While[count < n && k <= Length[groups],
        r = groupResult[mode, rhs, all, testNames, groups[[k++]]];
        If[r =!= $noResult, count++; Sow[r, $resultTag]]]]];

(* A counted name bound to text, or to a run holding text, in some solution
   is refused, as refuseText refuses one whose pattern shows
   it. *)
refuseBoundText[sols_, counted_] :=
  Replace[FirstCase[counted, n_ /; AnyTrue[sols, MemberQ[matchPos[Lookup[#, Key[n], {{}}]], Missing["Text"]] &]],
    Hold[s_] :> refuseHere["text", HoldForm[s]]];

(* The results a loop sows, in order, each a list (resultOf). *)
SetAttributes[reapedResults, HoldFirst];
reapedResults[loop_] := Replace[Reap[loop, $resultTag][[2]], {{l_} :> l, {} -> {}}];

(* The one counted name is on the pattern root, as in a bare pattern: the
   results are the root's matches, each once, and the elements are numbered
   in document order, so nothing is grouped or sorted, and the right-hand side
   is evaluated only until there are n. *)
rootMatches[mode_, root_, rhs_, all_, bare_, n_] :=
  Module[{cands = rootCandidates[root], sub = root["Sub"], name = root["Name"], count = 0, k = 1, i, r},
    With[{exactQ = sub["Kind"] === "XMLPattern" && sub["Constraints"] === {} && sub["Keep"] === {} ||
        n === Infinity && sub["Kind"] === "Cond" && flatConditionQ[sub]},
      If[bare, cands = DeleteCases[cands, 1]];
      If[exactQ && sub["Kind"] === "Cond", cands = conditionPassing[sub, cands]];
      reapedResults[
        While[count < n && k <= Length[cands],
          i = cands[[k++]];
          If[exactQ || match[sub, i] =!= {},
            r = If[mode === "Values" && rhs === Hold @@ name, {elemOf[i]}, resultOf[mode, rhs, all, <|name -> elemMatch[i]|>]];
            If[r =!= $noResult, count++; Sow[r, $resultTag]]]]]]];

(* Every solution of the pattern root, at each element that can match it.
   With nothing counted or tested, one is enough. *)
rootSolutions[root_, oneQ_] :=
  With[{cands = rootCandidates[root]},
    If[oneQ,
      Catch[Scan[With[{s = unsettled @ match[root, #]}, If[s =!= {}, Throw[s, $one]]] &, cands]; {}, $one],
      unsettled @
        Which[
          nestingRootQ[root], Join @@ (match[root, #] & /@ outermostMatches[root, cands]),
          headRootQ[root], headRootSolutions[root, cands],
          True, Join @@ (match[root, #] & /@ cands)]]];

(* A pattern root that reads only its element's tag and attributes: an
   XMLPattern without constraints, perhaps named. What the names in its tag
   and attributes bind is a function of those, which a page repeats over
   thousands of elements; only their positions and order keys differ, each
   the element's own followed by the same steps. So each distinct tag and
   attributes is matched once, and its solutions are moved to the other
   elements that have it: matching each element cost about 40 µs for a name
   on an attribute, 95 µs for one on a list key. *)
headRootQ[root_] := !$records && With[{x = headPatternOf[root]}, x =!= None && x["Constraints"] === {} && x["HeadNames"] =!= {}];

(* The XMLPattern node of such a root, or None. A name on the root that is
   also bound inside it is compared, so the root is matched as usual. *)
headPatternOf[nd_] := Switch[nd["Kind"],
  "XMLPattern", nd,
  "Named", If[nd["Sub"]["Kind"] === "XMLPattern" && !MemberQ[nd["Sub"]["Names"], nd["Name"]], nd["Sub"], None],
  _, None];

(* The solutions of match[root, #] & /@ cands, joined. *)
headRootSolutions[root_, cands_] :=
  With[{x = headPatternOf[root],
      name = If[root["Kind"] === "Named" && MemberQ[root["Keep"], root["Name"]], root["Name"], None]},
    With[{heads = headReads[x["Attrs"], elemOf /@ cands]},
      With[{templates = headTemplate[x, #, name] & /@ GroupBy[Transpose[{heads, cands}], First -> Last, First]},
        Join @@ MapThread[templates[#1][posOf[#2], elemKey[#2], If[name === None, None, elemMatch[#2]]] &, {heads, cands}]]]];

(* What the names in the tag and attributes read of each element: its tag,
   and the index and value of each attribute the rules name, which an id or
   href on each element does not change. An attribute index past the last is
   read for a list key without its attribute, so the count is part of it.
   Under a name on the attribute argument, or a key that is not literal, the
   whole attribute list. Read for all the elements at once: one at a time it
   cost about 5 µs each. *)
headReads[attrs_, els_] :=
  With[{rules = ruleList[attrs]},
    If[ListQ[rules] && AllTrue[rules, MatchQ[Verbatim[Rule][_?literalKeyQ, _]]],
      With[{keys = Alternatives @@ Union[#, Cases[Lookup[$readings, #], {k_, _} :> k]] &[Union @@ (keyLiterals[First[#]] & /@ rules)],
          as = els[[All, 2]]},
        With[{js = Lookup[GroupBy[Position[as[[All, All, 1]], keys, {2}, Heads -> False], First -> Last], Range[Length[els]], {}]},
          Transpose[{els[[All, 1]], Length /@ as, js, MapThread[Part, {as, js}]}]]],
      Take[#, 2] & /@ els]];

(* The solutions at element i, as a function of an element's position, its
   order key and its own match that gives the solutions at that element:
   each position and order key starts with the element's instead of i's,
   and the element's match is first, as name, unless name is None, as the
   Named node joins it. A match with no position keeps its Missing. The body
   holds Association[...] unevaluated, as the function could not put its
   arguments into an Association that is already built. *)
headTemplate[x_, i_, name_] :=
  Module[{p, k, e, afterP, afterK, association},
    With[{n = Length[posOf[i]], m = Length[elemKey[i]]},
      Function @@ (Hold @@ {{p, k, e},
          Map[association[Join[If[name === None, {}, {name -> e}],
              Normal @ Map[{If[ListQ[#], afterP[Drop[#, n]], #] & /@ matchPos[#], matchVal[#], afterK[Drop[#, m]] & /@ #[[3]]} &, #]]] &,
            match[x, i]]} /.
        {afterP[s_] :> Join[p, s], afterK[s_] :> Join[k, s], association -> Association})]];

(* A pattern root whose every constraint is a Descendant at any depth, and
   that binds nothing itself, has at an element inside another it matches a
   subset of the solutions it has there, as what is below the inner one is
   below the outer one. So only the outermost of nested matches are taken:
   taking every one costs the depth times the elements, about 4 s for
   "div p" over 50 nested div of 100 p each. *)
nestingRootQ[root_] :=
  root["Kind"] === "XMLPattern" && root["HeadNames"] === {} && root["Constraints"] =!= {} &&
    AllTrue[root["Constraints"], #["Kind"] === "Descendant" && #["Levels"] === {1, Infinity} && #["Key"] === None &];

(* The candidates that match and are not inside an earlier one that does, in
   document order. *)
outermostMatches[root_, cands_] :=
  Module[{end = -1}, Select[cands, # > end && match[root, #] =!= {} && (end = $end[[# + 1]]; True) &]];

(* The nodes a pattern root can match, in document order: the document first
   when the root can be an XMLDocument, then the elements. *)
rootCandidates[root_] := Join[If[documentRootQ[root], {0}, {}], Flatten @ Position[candidateVector[root], 1]];

documentRootQ[nd_] := Switch[nd["Kind"],
  "XMLDocument", True,
  "Named" | "Cond" | "Test", documentRootQ[nd["Sub"]],
  "Alt", AnyTrue[nd["Subs"], documentRootQ],
  _, False];

resultKey[sol_, slots_, counted_] :=
  Join @@ (Function[s, padded[matchKeyOrPad[Lookup[sol,
      If[StringQ[s], First[Select[SortBy[Keys[Select[$slotOf, # === s &]], $order], MemberQ[counted, #] && KeyExistsQ[sol, #] &], s], s],
      None]]]] /@ slots);
matchKeyOrPad[None] := {};
matchKeyOrPad[b_] := matchKey[b];

(* The result of one tuple: the right-hand side with the counted names from
   it, and the names only its tests use from the first of its solutions, in
   position order, that passes them. *)
groupResult[mode_, rhs_, all_, testNames_, group_] :=
  With[{ordered = If[testNames === {}, group,
      With[{names = SortBy[testNames, $order]},
        SortBy[group, Function[sol, Join @@ (padded[matchKeyOrPad[Lookup[sol, Key[#], None]]] & /@ names)]]]]},
    FirstCase[ordered, sol_ :> With[{v = resultOf[mode, rhs, all, sol]}, v /; v =!= $noResult], $noResult]];

(* The right-hand side evaluated for one solution, in an output mode. For
   XMLPosition, its Conditions are run as for XMLCases, on the values, and
   then the code they guard is evaluated with each name replaced by its
   position instead, so a right-hand side with a test is evaluated twice. A
   repeated name with several positions gives the list of them (positionOf);
   a name that is absent, Sequence[]. For XMLReplace, the Conditions are run
   in the same way and the solution itself is given, for its replacements to
   be evaluated later, on the tree as rewritten. *)
resultOf["Values", rhs_, all_, sol_] := evaluated[substituted[rhs, all, sol]];
resultOf["Solutions", rhs_, all_, sol_] :=
  If[guardedBody[rhs] =!= rhs && evaluated[substituted[rhs, all, sol]] === $noResult, $noResult,
    {{matchPos[#], {valueOf[#]}} & /@ sol}];
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

(* =========================================================== *)
(* Element tests                                                *)
(*                                                              *)
(* XMLMatchQ and XMLFreeQ test a node of their input as the     *)
(* pattern root; names select nothing, so only the names that   *)
(* Conditions see are bound. A test is compiled once, which the *)
(* operator forms keep (ADR 0013), and run on an index of the   *)
(* input that reaches no deeper than the pattern does.          *)
(* =========================================================== *)

(* A pattern root of XMLPatterns without constraints, which XMLMatchQ tests
   with one MatchQ of a plain WL pattern (Query/Compiler.wl), about a
   hundred times faster per element than this engine; that matters in the
   operator form, applied to every element. A selector that is not
   translated, or a context selector, is left to this engine, which gives
   its message. *)
plainRootQ[x_ /; xmlPatternFormQ[x]] :=
  MatchQ[xmlPatternParts[x], {_, {}}] && FreeQ[x, _Descendant | _XMLDocument] && !removedCombinatorQ[Hold[x]];
plainRootQ[s_String] := MatchQ[Quiet[cssTree[s]], {"one", t_} /; plainRootQ[t]];
plainRootQ[Verbatim[Pattern][_, p_] | Verbatim[Condition][p_, _] | Verbatim[PatternTest][p_, _]] := plainRootQ[p];
plainRootQ[alts_Alternatives] := AllTrue[List @@ alts, plainRootQ];
plainRootQ[_] := False;

(* The test of pattern q under head, or $Failed after a message. A rule is
   refused: it gives a value, not a test. listsQ: whether a list pattern, in
   the contents-list grammar, can be the root (XMLMatchQ's lists). *)
treeMatcher[head_, q_, listsQ_] :=
  Catch[
    Block[{$head = head, $nodeId = 0, $order, $slotOf = <||>, $readings,
        $place = "query", $owner = XMLPattern, $namedPaths = False, $exceptRefs = exceptRefs[Hold[q]], $records},
      Module[{lhs = Hold[q], need, root, listQ = listsQ && listRootQ[q]},
        If[MatchQ[q, _Rule | _RuleDelayed] || removedCombinatorQ[lhs], refuseHere["badpat", q]];
        $readings = Replace[readingsInForce[], $Failed :> Throw[$Failed, $refusal]];
        $order = patternOrder[lhs];
        need = comparedNames[lhs];
        $records = $exceptRefs =!= {};
        root = If[listQ, listRoot[q, need], compileRoot[lhs, need]];
        <|"Head" -> head, "Root" -> root, "Lists" -> listQ, "Readings" -> $readings,
          "Reach" -> reachBelow[root], "Records" -> $records|>]],
    $refusal];

(* A list pattern, named, conditioned or tested, or alternatives of these. *)
listRootQ[q_] := MatchQ[q, _List] ||
  MatchQ[q, Verbatim[Pattern][_, x_] | Verbatim[Condition][x_, _] | Verbatim[PatternTest][x_, _] /; listRootQ[x]] ||
  MatchQ[q, _Alternatives] && AllTrue[List @@ q, listRootQ];

(* A list pattern matches the top elements of a list, the children of the
   virtual document above them, as XMLDocument's contents list does. *)
listRoot[q_, need_] :=
  Block[{$owner = XMLMatchQ, $place = "constraint"},
    With[{c = cConstraint[q, need]},
      treeNode["XMLDocument", c["Names"], need, "Constraints" -> {c}, "MinKids" -> minKids[c]]]];

(* How many DOM levels below its root node a pattern reads. *)
reachBelow[nd_] := Switch[nd["Kind"],
  "List" | "ContentsList", 1 + Max[0, reachBelow /@ subNodes[nd]],
  "Descendant", nd["Levels"][[2]] + reachBelow[nd["Sub"]],
  _, Max[0, reachBelow /@ subNodes[nd]]];

(* The node of x the test is rooted at: the element, the document, or the
   virtual document above a list's elements; None for any other input. Only
   a list pattern takes a list, and it takes nothing else. *)
testNode[m_, x_] :=
  Which[
    m["Lists"], If[ListQ[x] && validTreeQ[x], 0, None],
    MatchQ[x, _XMLElement], 1,
    MatchQ[x, XMLObject["Document"][_, _XMLElement, _]], 0,
    True, None];

(* f[] run on the index of x to DOM depth, with the test's compiled state. *)
withIndex[m_, x_, depth_, f_] :=
  Block[{$head = m["Head"], $readings = m["Readings"], $memo = <||>, $indexDepth = depth,
      $elem, $parent, $depth, $kids, $index, $end, $wlPos, $tops, $posMemo = <||>, $keyMemo = <||>, $matElems = <||>,
      $keyLength, $namedPaths = False, $records = m["Records"]},
    indexTree[x];
    f[]];

rootMatchQ[m_, i_] := unsettled @ match[m["Root"], i] =!= {};

(* XMLMatchQ: whether x, as the pattern root, matches. A kind the pattern
   cannot match is not an error: the document under an element pattern, an
   element under an XMLDocument pattern, matches nothing. *)
treeMatchQ[$Failed, _] := $Failed;
treeMatchQ[m_, x_] :=
  With[{i = testNode[m, x]},
    i =!= None && withIndex[m, x, i + m["Reach"], rootMatchQ[m, i] &]];

(* XMLFreeQ: whether no node at relative DOM depths lo to hi matches, x
   itself at depth 0. A list is not a node: its elements are at depth 1. *)
treeFreeQ[$Failed, _, _] := $Failed;
treeFreeQ[m_, x_, {lo_, hi_}] :=
  With[{b = If[MatchQ[x, _XMLElement], 1, 0]},
    withIndex[m, x, b + hi + m["Reach"],
      Function[
        NoneTrue[
          Select[Range[If[ListQ[x], 1, b], $end[[b + 1]]],
            lo <= $depth[[# + 1]] - b <= hi && (# == 0 || candidateVector[m["Root"]][[#]] == 1) &],
          rootMatchQ[m, #] &]]]];
