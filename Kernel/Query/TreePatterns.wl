(* ::Package:: *)
(* HTMLPatterns: tree patterns, the result rule and positions *)

(* Used by Query/Compiler.wl *)
PackageScoped[constraintFormQ]

(* Used by XMLFunctions.wl *)
PackageScoped[treeQueryQ]
PackageScoped[treeCases]

(* =========================================================== *)
(* Tree patterns (ADR 0023, 0024, 0025)                         *)
(*                                                              *)
(* XMLPattern[tag, attrs, c...] takes constraints on what is    *)
(* below the element: list patterns over its element children,  *)
(* Descendant[p, levelspec], and alternatives of these; a named  *)
(* Descendant binds its path. XMLDocument[c...] takes the same  *)
(* constraints on the document. A query gives one result for    *)
(* each distinct tuple of positions of its counted names, the   *)
(* names its right-hand side uses; a bare pattern p is first    *)
(* r$ : p :> r$.                                                *)
(*                                                              *)
(* This engine runs beside the combinator chains: a query that  *)
(* holds no combinator or list stage goes here (treeQueryQ),    *)
(* any other keeps the chain runners until the combinators go.  *)
(*                                                              *)
(* The input is indexed once: node 0 is the document, elements  *)
(* are numbered in preorder from 1. The query compiles to a     *)
(* tree of nodes. Matching a node at a document node gives its  *)
(* solutions, each an Association name -> binding, projected    *)
(* onto the names something above it needs ("Keep"), so an      *)
(* unnamed part, or a name nothing uses, costs a test and never  *)
(* an enumeration. The element's tag and attributes are tested  *)
(* by today's compiled XMLPattern; everything below it is this  *)
(* engine's own: contents lists are walked as reachability over *)
(* 0/1 vectors of the places between children, branching only   *)
(* at entries that bind a needed name, so ___ gaps and ordered  *)
(* entries stay linear.                                         *)
(* =========================================================== *)

(* ---- Which engine a query goes to ---- *)

(* A query with a combinator or a list stage anywhere a stage can be keeps
   the chain runners. A CSS string counts as its translation, which holds
   XMLDocument[] only as a combinator's first stage. *)
treeQueryQ[q_] := !chainStageQ[queryLHS[q]];

queryLHS[(Rule | RuleDelayed)[l_, _]] := l;
queryLHS[q_] := q;

chainStageQ[s_String] := With[{t = Quiet[FromCSSSelector[s]]}, t =!= $Failed && (!FreeQ[t, XMLDocument] || chainStageQ[t])];
chainStageQ[(Child | Adjacent | Sibling)[___]] := True;
(* Descendant[p, levelspec] is a constraint, which is refused as a query by
   this engine; Descendant of patterns is the combinator. *)
chainStageQ[Descendant[_, s_]] := !levelSpecFormQ[s];
chainStageQ[Descendant[_, _, __]] := True;
chainStageQ[_List] := True;
chainStageQ[Verbatim[Pattern][_, p_]] := chainStageQ[p];
chainStageQ[Verbatim[Condition][p_, _]] := chainStageQ[p];
chainStageQ[Verbatim[PatternTest][p_, _]] := chainStageQ[p];
chainStageQ[alts_Alternatives] := AnyTrue[List @@ alts, chainStageQ];
chainStageQ[_] := False;

(* What reads as a level spec, valid or not, rather than a list stage. *)
levelSpecFormQ[s_] := MatchQ[s, _Integer | DirectedInfinity[1] | {(_Integer | DirectedInfinity[1]) ..}];

(* A constraint as written: a list pattern, a Descendant, or alternatives of
   these, any of them named, conditioned or tested. Also read by the chain
   compiler, which takes none. *)
constraintFormQ[c_] := MatchQ[c, _List | _Descendant | _Shortest | _Longest] ||
  MatchQ[c, Verbatim[Pattern][_, x_] | Verbatim[Condition][x_, _] | Verbatim[PatternTest][x_, _] /; constraintFormQ[x]] ||
  MatchQ[c, _Alternatives] && AllTrue[List @@ c, constraintFormQ];

(* =========================================================== *)
(* Running a query                                              *)
(* =========================================================== *)

(* The results of q on tree, the first n of them in result order, or $Failed
   after a message under head. *)
treeCases[head_, tree_, q_, n_] :=
  Catch[
    Block[{$head = head, $nodeId = 0, $memo = <||>, $order, $seen = <||>, $slotOf = <||>, $readings,
        $elem, $parent, $depth, $kids, $index, $end, $wlPos, $tops, $posMemo = <||>, $keyMemo = <||>,
        $matElems = <||>, $keyLength, $local = False, $place = "query", $owner = XMLPattern, $namedPaths = False},
      Module[{lhs, rhs, all, counted, testNames, need, root},
        {lhs, rhs} = splitQuery[q];
        $readings = Replace[readingsInForce[], $Failed :> Throw[$Failed, $refusal]];
        all = namesIn[lhs];
        $order = patternOrder[lhs];
        {counted, testNames} = rhsNames[rhs, all];
        checkExcept[lhs, counted];
        need = Union[counted, testNames, conditionNames[lhs, all]];
        root = compileRoot[lhs, need];
        If[!validTreeQ[tree], messageTreeRefusal[head, tree]; Throw[$Failed, $refusal]];
        indexTree[tree];
        results[root, rhs, all, counted, testNames, MatchQ[tree, _XMLElement], n]]],
    $refusal];

(* query -> {Hold[lhs], Hold[rhs]}. A bare pattern is erased to r$ : p :> r$.
   A Rule's right-hand side was evaluated when the query was given, as in
   Cases; a Condition in its value is part of it, not a test. *)
splitQuery[r_RuleDelayed] := {Extract[r, {1}, Hold], Extract[r, {2}, Hold]};
splitQuery[r : Verbatim[Rule][_, _]] :=
  {Extract[r, {1}, Hold], Replace[Extract[r, {2}, Hold], Hold[c_Condition] :> Hold[Identity[c]]]};
splitQuery[p_] := Module[{r}, {Hold @@ {Pattern @@ {r, p}}, Hold[r]}];

(* namesIn (Query/Chains.wl) gives the names a held pattern binds, each
   Hold[name]. *)

(* Those of names that held code mentions. *)
mentioned[held_, names_] := Select[names, !FreeQ[held, Replace[#, Hold[s_] :> HoldPattern[s]]] &];

(* Pattern order: the order names first appear, reading the pattern as written. *)
patternOrder[held_] :=
  With[{ps = LexicographicSort @ Position[held, Verbatim[Pattern][_Symbol, _], {0, Infinity}, Heads -> True]},
    Association @ MapIndexed[#1 -> First[#2] &,
      DeleteDuplicates[Extract[held, Append[#, 1], Hold] & /@ ps]]];

(* The names a Condition anywhere in the pattern tests. They are kept up to
   where the test can run, which for a test that sees names bound outside its
   own pattern is above it. *)
conditionNames[held_, all_] :=
  mentioned[Cases[held, Verbatim[Condition][_, t_] :> Hold[t], {0, Infinity}, Heads -> True], all];

(* ---- Counted names (spec section 3) ---- *)

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

(* A name bound inside Except has no value outside it (spec section 3). In
   Except[c, p] the names in p are bound, as in WL; those in c are not. *)
checkExcept[lhs_, counted_] :=
  Replace[Intersection[namesIn[Cases[lhs, Verbatim[Except][c_, ___] :> Hold[c], {0, Infinity}, Heads -> True]], counted],
    {Hold[s_], ___} :> refuseHere["exceptname", HoldForm[s]]];

(* MessageName holds its first argument, so the consumer head is injected. *)
refuseHere[tag_, args___] := With[{h = $head}, refuse[MessageName[h, tag], args]];

(* =========================================================== *)
(* The index                                                    *)
(* =========================================================== *)

(* The top elements, numbered with the rest in preorder. Built with
   whole-tree operations rather than a walk. A bare element is the one top
   element, {1}, under a virtual document whose value is {e}. *)
indexTree[input_] :=
  Module[{ps, n, pid, groups},
    $tops = Replace[input, {XMLObject["Document"][_, r_, _] :> {r}, l_List :> l, x_ :> {x}}];
    ps = Position[$tops, _XMLElement, Heads -> False];
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
   materialised once per set, over the whole input, which moves no element. *)
materialElems[{}] := Rest[$elem];
materialElems[r_] := Lookup[$matElems, Key[r], $matElems[r] = Extract[materialise[$tops, r], $wlPos]];

(* =========================================================== *)
(* Position order (spec section 5)                              *)
(*                                                              *)
(* Each position has a key, a list of integers; keys padded to  *)
(* one length with $pad, below every entry, compare as the      *)
(* positions sort, a container before what it holds. An element *)
(* step is {4, n, 2}; within an element, its tag is {0}, its    *)
(* attribute map {1}, its j-th attribute {2, j, 0}, a list key  *)
(* read from it {2, j, 1} and that list's tails {2, j, 1, 2,    *)
(* ...},                                                        *)
(* its contents {3}, and among its children the gap before n    *)
(* {4, n, 0}, a run n ;; k {4, n, 1, -k} (longest first), then  *)
(* child n. Tails order as children do, with 2 for the 4.       *)
(* =========================================================== *)

$pad = -10^9;

elemKey[i_] := Lookup[$keyMemo, i, $keyMemo[i] = If[i == 0, {}, Join[elemKey[$parent[[i + 1]]], {4, $index[[i + 1]], 2}]]];
spanKey[s_, e_] := If[e == s, {s + 1, 0}, {s + 1, 1, -e}];

(* A named path's key is its lower end's then its upper end's, so when a query
   names a path every key takes two lengths. *)
padded[pathKey[lower_, upper_]] := Join[PadRight[lower, $keyLength, $pad], PadRight[upper, $keyLength, $pad]];
padded[k_] := PadRight[k, If[$namedPaths, 2, 1] $keyLength, $pad];

(* A binding: the positions (more than one for a repeated name), the value,
   and the order key. A sequence's value is seq[list]. *)
bnd[pos_, val_, key_] := {pos, val, key};
bindPos[b_] := b[[1]];
bindVal[b_] := b[[2]];
bindKey[b_] := b[[3]];

elemBinding[i_] := bnd[{posOf[i]}, elemOf[i], elemKey[i]];

(* =========================================================== *)
(* Compilation                                                  *)
(* =========================================================== *)

(* A node is an Association: "Kind", "Id", "Names" (every name bound below
   it, with Alternatives slots), "Keep" (those something above needs), and
   the kind's own fields. *)
treeNode[kind_, names_, need_, rest___] :=
  <|"Kind" -> kind, "Id" -> ++$nodeId, "Names" -> names, "Keep" -> Intersection[names, need], rest|>;

markSeen[names_] := Scan[($seen[#] = True) &, names];

compileRoot[Hold[lhs_], need_] := cRoot[lhs, need];

(* ---- Pattern roots ---- *)

cRoot[Verbatim[Pattern][s_Symbol, p_], need_] :=
  With[{name = Hold[s]}, markSeen[{name}];
    With[{sub = cRoot[p, need]}, treeNode["Named", Union[sub["Names"], {name}], need, "Name" -> name, "Sub" -> sub]]];

(* A Condition sees the names bound inside its pattern and the names bound
   before it (spec section 3). One that sees a name bound outside its own
   pattern is pending: the node above that binds it runs it. *)
cRoot[c_Condition, need_] :=
  With[{test = Extract[c, {2}, Hold]},
    With[{sub = cRoot[c[[1]], need]}, conditionNode["Cond", sub, test, need]]];

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

cRoot[XMLPattern[tag_], need_] := cRoot[XMLPattern[tag, _], need];
cRoot[x : XMLPattern[tag_, attrs_, cs___], need_] := cTreePattern[x, need];
cRoot[x_XMLPattern, _] := refuseHere["badpat", x];

(* An XMLElement pattern keeps WL's literal meaning, matched whole. *)
cRoot[x_XMLElement, need_] :=
  With[{names = namesIn[Hold[x]]},
    refuseDocumentIn[x];
    markSeen[names]; treeNode["Literal", names, need, "Pattern" -> x]];

refuseDocumentIn[x_] := If[!FreeQ[x, _XMLDocument], refuse[XMLDocument::place, FirstCase[x, _XMLDocument, Null, {0, Infinity}]]];

(* A string is a one-element CSS selector, and means its translation. *)
cRoot[s_String, need_] :=
  With[{t = Replace[FromCSSSelector[s], $Failed :> Throw[$Failed, $refusal]]},
    If[chainStageQ[t] || !FreeQ[t, XMLDocument], refuseHere["badpat", s],
      (* the translation's own names are needed only by its own Conditions *)
      cRoot[t, Union[need, conditionNames[Hold[t], namesIn[Hold[t]]]]]]];

(* A blank is any one element child in a contents list; as the whole query,
   or as Descendant's pattern, it is refused, as it reads as matching text. *)
cRoot[b : Verbatim[Blank][h___], need_] :=
  If[$place === "entry", treeNode["Blank", {}, need, "Head" -> {h}], refuseBlank[b]];
cRoot[b : (_BlankSequence | _BlankNullSequence), _] := refuseBlank[b];

cRoot[d_Descendant, _] :=
  Switch[$place,
    "entry", refuseListEntry[d, "descendant"],
    "query", refuse[Descendant::place, d],
    _, refuseHere["badpat", d]];
cRoot[l_List, _] /; $place === "entry" := refuseListEntry[l, "list"];
cRoot[x_, _] := refuseHere["badpat", x];

refuseBlank[b_] := If[$place === "descendant", refuse[Descendant::blank, b], refuseHere["blank", b]];

(* The message is the list's owner's: XMLPattern's or XMLDocument's. *)
refuseListEntry[x_, reason_] := With[{h = $owner}, refuse[MessageName[h, "listentry"], x, $listEntryReasons[reason]]];

$listEntryReasons = <|
  "document" -> "An entry is one element child or a sequence of them, and XMLDocument[...] is the document above every element. It can only be the pattern root, as in XMLDocument[{___, x : p, ___}].",
  "descendant" -> "An entry is one element child or a sequence of them, and Descendant[...] says what is somewhere below an element. A child containing x is XMLPattern[_, _, Descendant[x]].",
  "list" -> "An entry is one element child or a sequence of them, not a list. Several constraints on one element are separate arguments of XMLPattern."|>;

conditionNode[kind_, sub_, test_, need_] :=
  With[{tested = mentioned[test, Keys[$seen]]},
    treeNode[kind, sub["Names"], need, "Sub" -> sub, "Test" -> test, "Sees" -> tested,
      "Pending" -> !$local && !SubsetQ[sub["Names"], tested]]];

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
cTreePattern[XMLPattern[tag_, attrs_, cs___], need_] :=
  Module[{c, headNames, cons, plainRules},
    If[!FreeQ[attrs, _Descendant], refuse[Descendant::place, FirstCase[attrs, _Descendant, Null, {0, Infinity}]]];
    refuseDocumentIn[{tag, attrs}];
    c = Replace[compileWith[XMLPattern[tag, attrs], $head, $readings], $Failed :> Throw[$Failed, $refusal]];
    headNames = namesIn[Hold[{tag, attrs}]];
    markSeen[headNames];
    cons = Block[{$owner = XMLPattern}, cConstraints[{cs}, need]];
    plainRules = plainHeadRules[tag, attrs, Intersection[headNames, need]];
    treeNode["XMLPattern", Union[headNames, Union @@ Prepend[#["Names"] & /@ cons, {}]], need,
      "Plain" -> c["Plain"], "Readings" -> c["Readings"], "Tag" -> tag, "Attrs" -> attrs,
      "HeadNames" -> Intersection[headNames, need], "Constraints" -> cons,
      "MinKids" -> Max[0, minKids /@ cons], "PlainRules" -> plainRules]];

(* {key, name} for each rule of the attribute argument that binds a needed
   name, when headBindings can bind them directly (plainAttributeBindings),
   or None. *)
plainHeadRules[tag_, attrs_, need_] :=
  With[{rules = Replace[attrs, {r_Rule :> {r}, l_List :> l, _ -> None}]},
    If[ListQ[rules] && FreeQ[rules, Verbatim[Rule][_Alternatives, _]] && !IntersectingQ[namesIn[Hold[tag]], need],
      Replace[Cases[rules, Verbatim[Rule][_, v_] /; IntersectingQ[namesIn[Hold[v]], need]], {
        r_ /; !AllTrue[r, plainRuleQ] -> None,
        r_ :> Replace[r, Verbatim[Rule][k_, Verbatim[Pattern][s_, _]] :> {k, Hold[s]}, {1}]}],
      None]];

(* ---- Constraints ---- *)

(* The constraints of an XMLPattern or XMLDocument, $owner, which names the
   messages. *)
cConstraints[cs_List, need_] :=
  With[{h = $owner},
    Scan[If[!constraintFormQ[#], refuse[MessageName[h, "constraint"], #]] &, cs];
    Block[{$place = "constraint"}, cConstraint[#, need] & /@ cs]];

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

(* ---- Paths (spec section 2) ---- *)

(* A Descendant constraint under a name, a test, a Condition, Shortest or
   Longest. Its value is the path: the elements strictly between the pattern
   root, its upper end, and the match, its lower end. *)
pathFormQ[c_] := MatchQ[c, _Descendant] ||
  MatchQ[c, Verbatim[Pattern][_, x_] | Verbatim[PatternTest][x_, _] | Verbatim[Condition][x_, _] | (Shortest | Longest)[x_] /; pathFormQ[x]];

(* Every node of a path keeps key, which the wrappers read and the pattern
   root's node projects away. *)
cPath[d_Descendant, need_, key_] := cDescendant[d, need, key];
cPath[Verbatim[Pattern][s_Symbol, x_], need_, key_] :=
  With[{name = Hold[s]}, markSeen[{name}]; $namedPaths = True;
    With[{sub = cPath[x, need, key]},
      treeNode["PathNamed", Union[sub["Names"], {name}], need, "Name" -> name, "Sub" -> sub, "Key" -> key]]];
cPath[Verbatim[PatternTest][x_, f_], need_, key_] :=
  With[{sub = cPath[x, need, key]}, treeNode["PathTest", sub["Names"], need, "Sub" -> sub, "F" -> f, "Key" -> key]];
cPath[c_Condition, need_, key_] :=
  With[{test = Extract[c, {2}, Hold]},
    With[{sub = cPath[c[[1]], need, key]}, Append[conditionNode["PathCond", sub, test, need], "Key" -> key]]];
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
  With[{name = Hold[s]}, markSeen[{name}];
    With[{sub = cListConstraint[l, need]},
      treeNode["ListNamed", Union[sub["Names"], {name}], need, "Name" -> name, "Sub" -> sub]]];
cListConstraint[c_Condition, need_] :=
  With[{test = Extract[c, {2}, Hold]},
    With[{sub = cListConstraint[c[[1]], need]}, conditionNode["ListCond", sub, test, need]]];
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
  With[{name = Hold[s]}, markSeen[{name}];
    With[{inner = cItem[p, need]},
      {treeNode["Run", Union[{name}, Union @@ Prepend[#["Names"] & /@ inner, {}]], need, "Name" -> name, "Items" -> inner]}]];
cItem[r : (_Repeated | _RepeatedNull), need_] :=
  With[{inner = cItem[r[[1]], need], bounds = repeatBounds[r]},
    If[AnyTrue[inner, capQ], refuseHere["badpat", r]];
    {treeNode["Repeat", Union @@ Prepend[#["Names"] & /@ inner, {}], need, "Items" -> inner, "Min" -> bounds[[1]], "Max" -> bounds[[2]]]}];
(* A name inside Except binds nothing outside it; tests inside it run there. *)
cItem[Verbatim[Except][p_], need_] :=
  With[{sub = Block[{$local = True}, $single[p, conditionTestNames[p]]]}, {treeNode["Not", sub["Names"], need, "Sub" -> sub, "Base" -> None]}];
cItem[Verbatim[Except][p_, q_], need_] :=
  With[{sub = Block[{$local = True}, $single[p, conditionTestNames[p]]], base = $single[q, need]},
    {treeNode["Not", Union[sub["Names"], base["Names"]], need, "Sub" -> sub, "Base" -> base]}];
cItem[alts_Alternatives, need_] /; AnyTrue[List @@ alts, sequenceQ] :=
  With[{branches = cItem[#, need] & /@ List @@ alts},
    {alternativesNode["Branches", branches, (Union @@ Prepend[#["Names"] & /@ #, {}]) & /@ branches, need]}];
cItem[Verbatim[Optional][p_, ___], need_] := cItem[Alternatives[p, PatternSequence[]], need];
(* Shortest and Longest choose which match WL's matcher tries first; every
   tuple is found here, so they change no result. *)
cItem[(Shortest | Longest)[p_, ___], need_] := cItem[p, need];
cItem[c_Condition, need_] /; sequenceQ[c[[1]]] :=
  With[{test = Extract[c, {2}, Hold]},
    With[{inner = cItem[c[[1]], need]},
      With[{sub = treeNode["Seq", Union @@ Prepend[#["Names"] & /@ inner, {}], need, "Items" -> inner]},
        {conditionNode["SeqCond", sub, test, need]}]]];
(* A test on a sequence tests each of its items, as in WL. *)
cItem[Verbatim[PatternTest][p_, f_], need_] /; sequenceQ[p] := cItem[testedEach[p, f], need];
cItem[x_, need_] := With[{sub = $single[x, need]}, {treeNode["One", sub["Names"], need, "Sub" -> sub]}];

testedEach[Verbatim[Pattern][s_, p_], f_] := Pattern @@ {s, testedEach[p, f]};
testedEach[Verbatim[BlankNullSequence][h___], f_] := RepeatedNull[PatternTest[Blank[h], f]];
testedEach[Verbatim[BlankSequence][h___], f_] := Repeated[PatternTest[Blank[h], f]];
testedEach[p_, _] := refuseHere["badpat", p];

conditionTestNames[p_] := conditionNames[Hold[p], namesIn[Hold[p]]];

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
    If[MemberQ[nd["Keep"], nd["Name"]], joinAll[sols, <|nd["Name"] -> elemBinding[i]|>], sols]];

matchKind["Cond", nd_, i_] := conditionFiltered[nd, match[nd["Sub"], i]];

matchKind["Test", nd_, i_] :=
  With[{sols = match[nd["Sub"], i]}, If[sols =!= {} && TrueQ[nd["F"][elemOf[i]]], sols, {}]];

matchKind["Alt", nd_, i_] :=
  project[Join @@ (With[{s = match[#, i]},
      If[nd["Slot"] === None, s, Append[#, nd["Slot"] -> elemBinding[i]] & /@ s]] & /@ nd["Subs"]), nd["Keep"]];

matchKind["Blank", nd_, i_] := If[MatchQ[elemOf[i], Blank @@ nd["Head"]], {<||>}, {}];

matchKind["Literal", nd_, i_] :=
  If[MatchQ[elemOf[i], nd["Pattern"]],
    If[nd["Keep"] === {}, {<||>}, {Map[bnd[{Missing["Literal"]}, #, {}] &, firstBindings[elemOf[i], nd["Pattern"], nd["Keep"]]]}],
    {}];

(* The document, node 0, is matched only by XMLDocument, which matches
   nothing else. *)
matchKind["XMLPattern" | "Literal" | "Blank", _, 0] := {};
matchKind["XMLDocument", nd_, i_] :=
  If[i == 0 && Length[childrenOf[0]] >= nd["MinKids"],
    project[pending[nd, product[matchConstraint[#, 0] & /@ nd["Constraints"]]], nd["Keep"]],
    {}];

matchKind["XMLPattern", nd_, i_] :=
  If[headVector[nd][[i]] == 1 && Length[childrenOf[i]] >= nd["MinKids"],
    project[pending[nd, product[Prepend[constraintSolutions[nd, #, i] & /@ nd["Constraints"], headBindings[nd, i]]]], nd["Keep"]],
    {}];

constraintSolutions[nd_, c_, i_] := If[nearestOf[c] === None, matchConstraint[c, i], nearestFiltered[nd, c, i]];

(* A Condition filters, unless it is pending, then a node above runs it. *)
conditionFiltered[nd_, sols_] :=
  If[nd["Pending"], project[sols, nd["Keep"]], project[Select[sols, passesQ[nd["Test"], nd["Sees"], #] &], nd["Keep"]]];

(* The pending Conditions below a node whose names it binds, run on its
   solutions. *)
pending[nd_, sols_] :=
  With[{tests = Lookup[$pendingAt, nd["Id"], {}]},
    If[tests === {}, sols, Select[sols, Function[s, AllTrue[tests, passesQ[#["Test"], #["Sees"], s] &]]]]];

(* ---- Tag and attributes ---- *)

(* Whether each element passes the compiled tag and attribute test, once per
   query for all elements. *)
headVector[nd_] :=
  memoised[{"Head", nd["Id"]},
    With[{p = nd["Plain"]}, Developer`ToPackedArray @ Boole[MatchQ[#, p] & /@ materialElems[nd["Readings"]]]]];

(* The bindings of the needed names in the tag and attribute slots: the tag
   is {p, 0}, a name on the attribute argument {p, Key[All]}, a value
   {p, Key[k]}, a list key's value {p, Key[listKey]} and the tokens in it the
   tails after that. *)
headBindings[nd_, i_] /; nd["HeadNames"] === {} := {<||>};
headBindings[nd_, i_] /; nd["PlainRules"] =!= None := plainAttributeBindings[nd["PlainRules"], elemOf[i], i];
headBindings[nd_, i_] :=
  With[{x = elemOf[i], need = nd["HeadNames"]},
    product[{tagBindings[nd["Tag"], x, i, need], attributeBindings[nd["Attrs"], x, i, need]}]];

tagBindings[tag_, x_, i_, need_] :=
  With[{names = Intersection[namesIn[Hold[tag]], need]},
    If[names === {}, {<||>},
      {Map[bnd[{Append[posOf[i], 0]}, #, Append[elemKey[i], 0]] &, firstBindings[x[[1]], tag, names]]}]];

attributeBindings[Verbatim[Pattern][s_Symbol, a_], x_, i_, need_] :=
  If[MemberQ[need, Hold[s]],
    joinAll[attributeBindings[a, x, i, need], <|Hold[s] -> bnd[{Append[posOf[i], Key[All]]}, x[[2]], Append[elemKey[i], 1]]|>],
    attributeBindings[a, x, i, need]];
attributeBindings[Verbatim[PatternTest][a_, _], x_, i_, need_] := attributeBindings[a, x, i, need];
attributeBindings[r_Rule, x_, i_, need_] := attributeBindings[{r}, x, i, need];
(* With no Alternatives key, the keys are distinct (the compiler refuses a
   duplicate), so each rule has its one attribute, and only the rules that
   bind a needed name are read. *)
attributeBindings[rules_List, x_, i_, need_] /; FreeQ[rules, Verbatim[Rule][_Alternatives, _]] :=
  With[{named = Cases[rules, r : Verbatim[Rule][_, v_] /; IntersectingQ[namesIn[Hold[v]], need]]},
    With[{slots = attributeSlots[x, i, Union @@ (keyLiterals[First[#]] & /@ named)]},
      project[product[MapIndexed[ruleBindings[#1, First[#2], slots, need] &, named]], need]]];
(* KeyValuePattern gives each rule a different attribute, so with an
   Alternatives key every rule is placed, those that bind nothing too, and a
   placement that gives two rules one attribute is dropped. *)
attributeBindings[rules_List, x_, i_, need_] :=
  With[{slots = attributeSlots[x, i, Union @@ (keyLiterals[First[Replace[#, k_?literalKeyQ :> (k -> _)]]] & /@ rules)]},
    project[
      Select[product[MapIndexed[ruleBindings[Replace[#1, k_?literalKeyQ :> (k -> _)], First[#2], slots, need] &, rules]],
        DuplicateFreeQ[Values[KeySelect[#, MatchQ[{"Taken", _}]]]] &],
      need]];
attributeBindings[_, _, _, _] := {<||>};

(* The common case: each rule is "key" -> name_ on a key that is not a list
   key, and the element passed the compiled test, so has the attribute. *)
plainRuleQ[r_] := MatchQ[r, Verbatim[Rule][k_String, Verbatim[Pattern][_Symbol, Verbatim[Blank][]]] /; !KeyExistsQ[$readings, k]];

plainAttributeBindings[pairs_, x_, i_] :=
  With[{attrs = x[[2]], p = posOf[i], k = elemKey[i]},
    With[{js = First @ FirstPosition[attrs[[All, 1]], #, {0}, {1}] & /@ pairs[[All, 1]]},
      {AssociationThread[pairs[[All, 2]],
        MapThread[bnd[{Append[p, Key[#1]]}, attrs[[#2, 2]], Join[k, {2, #2, 0}]] &, {pairs[[All, 1]], js}]]}]];

(* The places a rule on one of keys can take: each attribute so named, at
   {p, Key[k]}, and the token list of each list key among them, at
   {p, Key[listKey]}. *)
attributeSlots[x_, i_, keys_] :=
  With[{attrs = x[[2]], p = posOf[i], k = elemKey[i]},
    Join[
      <|"Key" -> attrs[[#, 1]], "Value" -> attrs[[#, 2]], "Pos" -> Append[p, Key[attrs[[#, 1]]]],
        "OrderKey" -> Join[k, {2, #, 0}], "List" -> False|> & /@ Select[Range[Length[attrs]], MemberQ[keys, attrs[[#, 1]]] &],
      KeyValueMap[Function[{listKey, reading},
          <|"Key" -> listKey, "Value" -> Last[reading][Lookup[attrs, First[reading], ""]], "Pos" -> Append[p, Key[listKey]],
            "OrderKey" -> Join[k, {2, Replace[FirstPosition[attrs[[All, 1]], First[reading], {Length[attrs] + 1}, {1}], {j_} :> j], 1}],
            "List" -> True|>],
        KeyTake[$readings, keys]]]];

(* The solutions of rule r at each slot it can take, each marked with the
   slot, as {"Taken", r} -> slot. A list key's value is read as the compiler
   reads it: a string, or alternatives of strings, is a token in the list
   (ADR 0011). *)
ruleBindings[k_ -> v_, r_, slots_, need_] :=
  With[{listValue = If[AllTrue[keyLiterals[k], KeyExistsQ[$readings, #] &], desugared[v], v],
      names = Intersection[namesIn[Hold[v]], need]},
    Join @@ MapIndexed[Function[{slot, j},
        Map[Append[#, {"Taken", r} -> First[j]] &,
          Which[
            !MatchQ[slot["Key"], k] || !slot["List"] && KeyExistsQ[$readings, slot["Key"]], {},
            slot["List"],
              Block[{$tokens = slot["Value"], $tokenPos = slot["Pos"], $tokenKey = slot["OrderKey"]},
                tokenValueBindings[listValue, need]],
            !MatchQ[slot["Value"], v], {},
            names === {}, {<||>},
            True, {Map[bnd[{slot["Pos"]}, #, slot["OrderKey"]] &, firstBindings[slot["Value"], v, names]]}]]],
      slots]];
ruleBindings[___] := {};

(* As the compiler reads a list key's value (ADR 0011). *)
desugared[s : (_String | Verbatim[Alternatives][__String])] := {___, s, ___};
desugared[v_] := v;

(* The values the first match of pat against val gives names. A name in a
   branch that did not match is absent. *)
firstBindings[val_, Verbatim[Pattern][s_Symbol, Verbatim[Blank][]], {Hold[s_Symbol]}] := <|Hold[s] -> val|>;
firstBindings[val_, pat_, names_] :=
  With[{rule = memoised[{"Rule", pat, names},
      RuleDelayed @@ Join[Hold[pat], Replace[Join @@ (Replace[#, Hold[s_] :> Hold[{s}]] & /@ names), Hold[a___] :> Hold[{a}]]]]},
    Replace[First[ReplaceList[val, rule], None], {
      None -> <||>,
      vs_List :> Association @ MapThread[If[#2 === {}, Nothing, #1 -> Replace[#2, {{v_} :> v, l_ :> seq[l]}]] &, {names, vs}]}]];

(* ---- The token list of a list key ---- *)

tokenValueBindings[Verbatim[Pattern][s_Symbol, p_], need_] :=
  If[MemberQ[need, Hold[s]], joinAll[tokenValueBindings[p, need], <|Hold[s] -> bnd[{$tokenPos}, $tokens, $tokenKey]|>],
    tokenValueBindings[p, need]];
tokenValueBindings[c_Condition, need_] :=
  With[{test = Extract[c, {2}, Hold], inner = namesIn[Hold[c]]},
    project[Select[tokenValueBindings[c[[1]], Union[need, mentioned[test, inner]]], passesQ[test, inner, #] &],
      Intersection[inner, need]]];
tokenValueBindings[Verbatim[PatternTest][p_, _], need_] := tokenValueBindings[p, need];
tokenValueBindings[l_List, need_] :=
  Block[{$place = "token", $single = cToken},
    With[{items = cItems[l, need]},
      walkTokens[items]]];
tokenValueBindings[p_, need_] :=
  With[{names = Intersection[namesIn[Hold[p]], need]},
    Which[!MatchQ[$tokens, p], {}, names === {}, {<||>},
      True, {Map[bnd[{$tokenPos}, #, $tokenKey] &, firstBindings[$tokens, p, names]]}]];

(* One token: any WL pattern, each name in it binding the token. *)
cToken[p_, need_] := With[{names = namesIn[Hold[p]]}, treeNode["Token", names, need, "Pattern" -> p]];

walkTokens[items_] :=
  Block[{$n = Length[$tokens], $walkId = {"Tokens", $tokenPos}, $oneVector = tokenVector, $oneSolutions = tokenSolutions,
      $runBinding = tokenRun},
    project[Last /@ enumerate[items, 0, delta[$n]], Union @@ Prepend[#["Keep"] & /@ items, {}]]];

tokenVector[sub_] := Boole[MatchQ[#, sub["Pattern"]] & /@ $tokens];
tokenSolutions[sub_, k_] :=
  If[!MatchQ[$tokens[[k]], sub["Pattern"]], {},
    If[sub["Keep"] === {}, {<||>},
      {Map[bnd[{Append[$tokenPos, k]}, #, Join[$tokenKey, {2, k, 2}]] &, firstBindings[$tokens[[k]], sub["Pattern"], sub["Keep"]]]}]];
tokenRun[s_, e_] := bnd[{Append[$tokenPos, s + 1 ;; e]}, seq[$tokens[[s + 1 ;; e]]], Join[$tokenKey, {2}, spanKey[s, e]]];

(* ---- Constraints ---- *)

matchConstraint[c_, i_] := memoised[{c["Id"], i}, constraintKind[c["Kind"], c, i]];

constraintKind["ConstraintAlt", c_, i_] := project[Join @@ (matchConstraint[#, i] & /@ c["Subs"]), c["Keep"]];

(* A named list binds the run of all element children, its value their list. *)
constraintKind["ListNamed", c_, i_] :=
  With[{sols = matchConstraint[c["Sub"], i], n = Length[childrenOf[i]]},
    If[MemberQ[c["Keep"], c["Name"]],
      joinAll[sols, <|c["Name"] -> bnd[{Append[posOf[i], 1 ;; n]}, elemOf /@ childrenOf[i], Join[elemKey[i], {4}, spanKey[0, n]]]|>],
      sols]];
constraintKind["ListCond", c_, i_] := conditionFiltered[c, matchConstraint[c["Sub"], i]];
constraintKind["ListTest", c_, i_] :=
  With[{sols = matchConstraint[c["Sub"], i]}, If[sols =!= {} && TrueQ[c["F"][elemOf /@ childrenOf[i]]], sols, {}]];

constraintKind["List", c_, i_] /; Length[childrenOf[i]] < c["Min"] := {};
constraintKind["List", c_, i_] :=
  Block[{$n = Length[childrenOf[i]], $walkId = i, $kidIds = childrenOf[i], $oneVector = childVector, $oneSolutions = childSolutions,
      $runBinding = childRun},
    project[pending[c, If[oneCaptureQ[c], oneCapture[c], Last /@ enumerate[c["Items"], 0, delta[$n]]]], c["Keep"]]];

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
  With[{sols = If[directQ[sub], {<|sub["Name"] -> elemBinding[j]|>}, match[sub, j]]},
    If[key === None, sols, Append[#, key -> bnd[{posOf[j]}, j, elemKey[j]]] & /@ sols]];

(* ---- Paths ---- *)

(* The lower end of a path solution. *)
lowerEnd[c_, sol_] := bindVal[sol[c["Key"]]];

(* The elements strictly between i and j, a node below it, outermost first. *)
pathIds[i_, j_] := Reverse @ Most @ NestWhileList[$parent[[# + 1]] &, $parent[[j + 1]], # != i &];

(* A path's position is the span of its ends, upper ;; lower; it sorts by its
   lower end, then its upper end (pathKey, padded). *)
pathBinding[i_, j_] := bnd[{posOf[i] ;; posOf[j]}, elemOf /@ pathIds[i, j], pathKey[elemKey[j], elemKey[i]]];

constraintKind["PathNamed", c_, i_] :=
  With[{sols = matchConstraint[c["Sub"], i]},
    project[If[MemberQ[c["Keep"], c["Name"]],
        DeleteCases[joined[#, <|c["Name"] -> pathBinding[i, lowerEnd[c, #]]|>] & /@ sols, $Failed], sols],
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

(* Whether each element can match a pattern root: a vector over the elements
   that is 1 at every match, for skipping the rest. *)
candidateVector[nd_] := memoised[{"Candidates", nd["Id"]}, candidates[nd]];
candidates[nd_] := Switch[nd["Kind"],
  "Named" | "Cond" | "Test", candidateVector[nd["Sub"]],
  "Alt", Unitize[Total[candidateVector /@ nd["Subs"]]],
  "XMLPattern", headVector[nd] UnitStep[(Length /@ Rest[$kids]) - nd["MinKids"]],
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
(* $oneSolutions and $runBinding read them.                     *)
(* =========================================================== *)

delta[p_] := UnitVector[$n + 1, p + 1];

childVector[sub_] :=
  memoised[{"Vector", sub["Id"], $walkId},
    Developer`ToPackedArray @ If[exactCandidatesQ[sub],
      candidateVector[sub][[$kidIds]],
      Boole[match[sub, #] =!= {} & /@ $kidIds]]];

(* Whether a pattern root's candidates are exactly its matches: it tests only
   an element's tag and attributes, which the compiled test decides. *)
exactCandidatesQ[nd_] := Switch[nd["Kind"],
  "XMLPattern", nd["Constraints"] === {},
  "Named", exactCandidatesQ[nd["Sub"]],
  "Alt", AllTrue[nd["Subs"], exactCandidatesQ],
  _, False];
childSolutions[sub_, k_] := match[sub, $kidIds[[k]]];
childRun[s_, e_] :=
  bnd[{Append[posOf[$walkId], s + 1 ;; e]}, seq[elemOf /@ $kidIds[[s + 1 ;; e]]], Join[elemKey[$walkId], {4}, spanKey[s, e]]];

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

notVector[it_] := (1 - itemVector[it["Sub"]]) If[it["Base"] === None, 1, itemVector[it["Base"]]];

shift[s_, t_, 1] := Prepend[Most[s] t, 0];
shift[s_, t_, -1] := Append[Rest[s] t, 0];

anyFrom[s_, 0, 1] := Unitize[Accumulate[s]];
anyFrom[s_, 0, -1] := Reverse[Unitize[Accumulate[Reverse[s]]]];
anyFrom[s_, m_, dir_] := anyFrom[Nest[shift[#, ConstantArray[1, $n], dir] &, s, m], 0, dir];

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
   can still reach the end. *)
enumerate[items_, s0_, endOK_] :=
  Module[{back, caps, frontier = {{s0, <||>}}, prev = 0},
    back = Reverse @ FoldList[reachOne[#2, #1, -1] &, endOK, Reverse[items]];
    caps = Flatten @ Position[capQ /@ items, True];
    Do[
      frontier = Join @@ Function[f,
          With[{r = reach[items[[prev + 1 ;; c - 1]], delta[f[[1]]], 1] back[[c]]},
            Join @@ (Function[s,
                With[{m = joined[f[[2]], #[[2]]]}, If[m === $Failed, Nothing, {#[[1]], m}]] & /@
                  entrySpans[items[[c]], s, back[[c + 1]]]] /@ (Flatten @ Position[r, 1] - 1))]] /@ frontier;
      prev = c,
      {c, caps}];
    Join @@ Function[f,
        {# - 1, f[[2]]} & /@ Flatten @ Position[reach[items[[prev + 1 ;;]], delta[f[[1]]], 1] endOK, 1]] /@ frontier];

entrySpans[it_, s_, next_] := Switch[it["Kind"],
  "One",
    If[s < $n && next[[s + 2]] == 1, {s + 1, #} & /@ $oneSolutions[it["Sub"], s + 1], {}],
  "Not",
    If[s < $n && next[[s + 2]] == 1 && itemVector[it["Sub"]][[s + 1]] == 0, {s + 1, #} & /@ $oneSolutions[it["Base"], s + 1], {}],
  "Run",
    With[{inner = enumerate[it["Items"], s, next]},
      projectSpans[If[MemberQ[it["Keep"], it["Name"]], {#[[1]], Append[#[[2]], it["Name"] -> $runBinding[s, #[[1]]]]} & /@ inner, inner], it["Keep"]]],
  "SeqCond",
    projectSpans[If[it["Pending"], #, Select[#, passesQ[it["Test"], it["Sees"], #[[2]]] &]] & @ enumerate[it["Sub"]["Items"], s, next], it["Keep"]],
  "Branches",
    projectSpans[Join @@ (Function[b, With[{inner = enumerate[b, s, next]},
      If[it["Slot"] === None, inner, {#[[1]], Append[#[[2]], it["Slot"] -> $runBinding[s, #[[1]]]]} & /@ inner]]] /@ it["Subs"]), it["Keep"]],
  "Repeat",
    {#, <||>} & /@ (Flatten @ Position[repeatReach[it, delta[s], 1] next, 1] - 1)];

projectSpans[sps_, keep_] := DeleteDuplicatesBy[{#[[1]], KeyTake[#[[2]], keep]} & /@ sps, {#[[1]], identity[#[[2]], keep]} &];

(* One needed name on one entry that is one child, and nothing else to
   branch at: the children it binds are where the entries before it can end,
   it matches, and the entries after it can match the rest. *)
oneCaptureQ[c_] :=
  With[{caps = Select[c["Items"], capQ]}, Length[caps] == 1 && caps[[1]]["Kind"] === "One"];

oneCapture[c_] :=
  With[{k = First @ FirstPosition[capQ /@ c["Items"], True], items = c["Items"]},
    With[{f = reach[Take[items, k - 1], delta[0], 1], b = reach[Drop[items, k], delta[$n], -1], sub = items[[k]]["Sub"]},
      Join @@ (hitSolutions[sub, #] & /@ Flatten @ Position[Most[f] itemVector[sub] Rest[b], 1])]];

(* The solutions of an item known to match. A name on an element pattern
   with nothing else to bind, which the item's vector has already tested, is
   bound without matching again. *)
hitSolutions[sub_, k_] /; $oneSolutions === childSolutions && directQ[sub] := {<|sub["Name"] -> elemBinding[$kidIds[[k]]]|>};
hitSolutions[sub_, k_] := $oneSolutions[sub, k];

directQ[nd_] := nd["Kind"] === "Named" && With[{s = nd["Sub"]}, s["Kind"] === "XMLPattern" && s["Constraints"] === {} && s["Keep"] === {}];

(* =========================================================== *)
(* Solutions                                                    *)
(* =========================================================== *)

(* Two solutions join when a name they share has one value; the joined
   binding keeps both positions. *)
joined[a_, b_] /; Length[a] == 0 := b;
joined[a_, b_] /; Length[b] == 0 := a;
joined[a_, b_] :=
  With[{shared = Intersection[Keys[a], Keys[b]]},
    If[AllTrue[shared, bindVal[a[#]] === bindVal[b[#]] &],
      Join[b, a, Association[(# -> ReplacePart[a[#], 1 -> DeleteDuplicates @ Join[bindPos[a[#]], bindPos[b[#]]]]) & /@ shared]],
      $Failed]];

joinAll[sols_, extra_] := DeleteCases[joined[#, extra] & /@ sols, $Failed];

product[lists_] := Fold[Function[{acc, l},
    Which[acc === {} || l === {}, {},
      l === {<||>}, acc,
      acc === {<||>}, l,
      True, DeleteCases[Flatten[Outer[joined, acc, l, 1], 1], $Failed]]], {<||>}, lists];

(* The distinct solutions on keep. *)
project[{}, _] := {};
project[{s_}, keep_] := {KeyTake[s, keep]};
project[sols_, keep_] := DeleteDuplicatesBy[KeyTake[#, keep] & /@ sols, identity[#, keep] &];

(* A binding is identified by its positions; one without, by its value. *)
identity[sol_, names_] := identityOf /@ Lookup[sol, names, None];
identityOf[None] := None;
identityOf[b_] := If[MatchQ[bindPos[b], {_Missing}], {"Value", bindVal[b]}, bindPos[b]];

(* Held code with each name replaced by its value; an absent name is
   Sequence[], as a name in an Alternatives branch that did not match is in
   WL. *)
substituted[held_, names_, sol_] :=
  held /. (Replace[#, Hold[s_] :> (HoldPattern[s] -> valueOf[Lookup[sol, Key[#], None]])] & /@ names);

valueOf[None] := Sequence[];
valueOf[b_] := Replace[bindVal[b], seq[l_] :> Sequence @@ l];

passesQ[test_Hold, names_, sol_] := TrueQ[ReleaseHold[substituted[test, names, sol]]];

(* =========================================================== *)
(* Results (spec sections 3 and 5)                              *)
(* =========================================================== *)

$noResult = Unique["noResult"];

(* One result for each distinct tuple of positions of the counted names, in
   result order: a nested loop over the counted names in pattern order, the
   first slowest, each in position order. The names in one Alternatives share
   its slot, keyed by the first of them the tuple binds, or by where the
   Alternatives matched when it binds none. The bare input's own position is
   never counted. *)
results[root_, rhs_, all_, counted_, {}, bare_, n_] /; root["Kind"] === "Named" && counted === {root["Name"]} :=
  Block[{$pendingAt = pendingTests[root]}, rootMatches[root, rhs, all, bare, n] /; !KeyExistsQ[$pendingAt, "Top"]];
results[root_, rhs_, all_, counted_, testNames_, bare_, n_] :=
  Module[{sols, groups, slots, keys, count = 0, k = 1, r},
    Block[{$pendingAt = pendingTests[root]},
      sols = rootSolutions[root, counted === {} && testNames === {}]];
    If[bare, sols = Select[sols, NoneTrue[Lookup[#, counted, None], MatchQ[{{___, {1} | Verbatim[Span][{1}, _], ___}, _, _}]] &]];
    groups = Values @ GroupBy[sols, identity[#, counted] &];
    slots = DeleteDuplicates[Lookup[$slotOf, counted, Null] /. Null -> Nothing];
    slots = SortBy[Join[slots, Select[counted, !KeyExistsQ[$slotOf, #] &]], $order];
    keys = First[Sort[resultKey[#, slots, counted] & /@ #]] & /@ groups;
    groups = groups[[Ordering[keys]]];
    reapedResults[
      While[count < n && k <= Length[groups],
        r = groupResult[rhs, all, testNames, groups[[k++]]];
        If[r =!= $noResult, count++; Sow[r, $resultTag]]]]];

(* The results a loop sows, in order. *)
SetAttributes[reapedResults, HoldFirst];
reapedResults[loop_] := Replace[Reap[loop, $resultTag][[2]], {{l_} :> l, {} -> {}}];

(* The one counted name is on the pattern root, as in a bare pattern: the
   results are the root's matches, each once, and the elements are numbered
   in document order, so nothing is grouped or sorted, and the right-hand side
   is evaluated only until there are n. *)
rootMatches[root_, rhs_, all_, bare_, n_] :=
  Module[{cands = rootCandidates[root], sub = root["Sub"], name = root["Name"], count = 0, k = 1, i, r},
    With[{exactQ = sub["Kind"] === "XMLPattern" && sub["Constraints"] === {} && sub["Keep"] === {}},
      If[bare, cands = DeleteCases[cands, 1]];
      reapedResults[
        While[count < n && k <= Length[cands],
          i = cands[[k++]];
          If[exactQ || match[sub, i] =!= {},
            r = If[rhs === Hold @@ name, elemOf[i], evaluated[substituted[rhs, all, <|name -> elemBinding[i]|>]]];
            If[r =!= $noResult, count++; Sow[r, $resultTag]]]]]]];

(* Every solution of the pattern root, at each element that can match it.
   With nothing counted or tested, one is enough. *)
rootSolutions[root_, oneQ_] :=
  With[{cands = rootCandidates[root]},
    If[oneQ,
      Catch[Scan[With[{s = pending[<|"Id" -> "Top"|>, match[root, #]]}, If[s =!= {}, Throw[s, $one]]] &, cands]; {}, $one],
      pending[<|"Id" -> "Top"|>, Join @@ (match[root, #] & /@ cands)]]];

(* The nodes a pattern root can match, in document order: the document first
   when the root can be an XMLDocument, then the elements. *)
rootCandidates[root_] := Join[If[documentRootQ[root], {0}, {}], Flatten @ Position[candidateVector[root], 1]];

documentRootQ[nd_] := Switch[nd["Kind"],
  "XMLDocument", True,
  "Named" | "Cond" | "Test", documentRootQ[nd["Sub"]],
  "Alt", AnyTrue[nd["Subs"], documentRootQ],
  _, False];

resultKey[sol_, slots_, counted_] :=
  Join @@ (Function[s, padded[bindKeyOrPad[Lookup[sol,
      If[StringQ[s], First[Select[SortBy[Keys[Select[$slotOf, # === s &]], $order], MemberQ[counted, #] && KeyExistsQ[sol, #] &], s], s],
      None]]]] /@ slots);
bindKeyOrPad[None] := {};
bindKeyOrPad[b_] := bindKey[b];

(* The result of one tuple: the right-hand side with the counted names from
   it, and the names only its tests use from the first of its solutions, in
   position order, that passes them. *)
groupResult[rhs_, all_, testNames_, group_] :=
  With[{ordered = If[testNames === {}, group,
      With[{names = SortBy[testNames, $order]},
        SortBy[group, Function[sol, Join @@ (padded[bindKeyOrPad[Lookup[sol, Key[#], None]]] & /@ names)]]]]},
    FirstCase[ordered, sol_ :> With[{v = evaluated[substituted[rhs, all, sol]]}, v /; v =!= $noResult], $noResult]];

(* Held code evaluated as a rule's right-hand side: a Condition that fails
   gives $noResult. *)
evaluated[Hold[code_]] := Replace[$noResult, _ :> code];

(* ---- Pending Conditions ---- *)

(* Each pending Condition runs at the lowest node above it that binds every
   name it sees, or at the top. *)
pendingTests[root_] :=
  Module[{hosts = <||>},
    Scan[Function[{c}, With[{host = hostOf[root, c]}, hosts[host] = Append[Lookup[hosts, host, {}], c]]], pendingNodes[root]];
    hosts];

pendingNodes[nd_] := Join[If[TrueQ[nd["Pending"]], {nd}, {}], Join @@ (pendingNodes /@ subNodes[nd])];

subNodes[nd_] := DeleteCases[Flatten[{Lookup[nd, "Sub", {}], Lookup[nd, "Subs", {}], Lookup[nd, "Constraints", {}],
  Lookup[nd, "Items", {}], Lookup[nd, "Base", {}]}], None];

(* The node that runs c: the lowest XMLPattern, XMLDocument or list above c whose names
   hold every name c sees. *)
hostOf[root_, c_] :=
  Replace[Last[Select[pathTo[root, c["Id"]], MatchQ[#["Kind"], "XMLPattern" | "XMLDocument" | "List"] && SubsetQ[#["Names"], c["Sees"]] &], None],
    {None -> "Top", h_ :> h["Id"]}];

pathTo[nd_, id_] :=
  If[nd["Id"] === id, {},
    Catch[Scan[With[{p = pathTo[#, id]}, If[p =!= None, Throw[Prepend[p, nd], $path]]] &, subNodes[nd]]; None, $path]];
