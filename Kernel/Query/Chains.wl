(* ::Package:: *)
(* HTMLPatterns: chains and alternatives of chains (ADR 0015) *)

(* Used by Query/Compiler.wl *)
PackageScoped[chainOf]
PackageScoped[selectRule]
PackageScoped[stagesDecideQ]
PackageScoped[tupleRule]
PackageScoped[tupleTest]
PackageScoped[listSlot]

(* Used by Query/Compiler.wl and Query/Run.wl *)
PackageScoped[alternativesOf]
PackageScoped[chainQ]
PackageScoped[unionQ]

(* Used by Query/Compiler.wl and Query/TreePatterns.wl *)
PackageScoped[namesIn]

(* Used by Query/Run.wl *)
PackageScoped[chainCases]
PackageScoped[chainFirst]
PackageScoped[chainDelete]
PackageScoped[chainPositions]
PackageScoped[unionCases]
PackageScoped[unionFirst]
PackageScoped[unionDelete]
PackageScoped[unionPositions]
PackageScoped[documentOrdering]
PackageScoped[$kids]
PackageScoped[$contextMemo]
PackageScoped[$contexts]

(* =========================================================== *)
(* Chains: every combinator query                               *)
(*                                                              *)
(* A combinator reads as a chain, left to right, as a CSS       *)
(* selector does: Descendant[a, Child[b, c]] and                *)
(* Child[Descendant[a, b], c] are both the chain a, Descendant, *)
(* b, Child, c. A chain runs on positions in the one            *)
(* (materialised) tree, so every relation, siblings included,   *)
(* is between sites of that tree. Each stage alone selects the  *)
(* sites related to the last site of a tuple; each tuple of     *)
(* elements is then matched against the stages as one plain WL  *)
(* pattern {s1, ..., sn}, so names scope as they do in WL: a    *)
(* stage's test sees only its own names, a name at two stages   *)
(* is one value, and a rule body sees every name. A list stage   *)
(* is matched against one parent's element children at a time,  *)
(* by the one list matcher, which Adjacent and Sibling links     *)
(* also run on (ADR 0016); its site is the selected child's, and *)
(* in a tuple it is the list of those children, or in a          *)
(* recognised shape the selected child.                          *)
(* =========================================================== *)

(* Every combinator query runs as a chain, nested or not, tested or not. *)
chainQ[q_] := q["Links"] =!= {};

(* A query of alternatives holding a combinator runs as several (ADR 0015). *)
unionQ[q_] := KeyExistsQ[q, "Alternatives"];
alternativesOf[q_] := If[unionQ[q], q["Alternatives"], {q}];

(* The stages and links, alternating, as the chain runner reads them, each
   element stage in its two-step form. *)
chainOf[q_] := Riffle[runStage /@ q["Stages"], q["Links"]];

runStage[ls_listStage] := ls;
runStage[s_] := solvable[s];

(* The pattern a tuple of elements matches: the list of the chain's stages. A
   Condition on the whole combinator wraps the list; one on a combinator that is
   a stage wraps the sequence of its stages, so it sees only theirs. Each
   Condition covers the stages i to j, and an inner one is applied first. *)
tuplePattern[q_] :=
  With[{n = Length[q["Stages"]]},
    Fold[conditionWith[#1, Last[#2]] &,
      Last /@ Fold[coverStages, Transpose[{Transpose[{Range[n], Range[n]}], tupleStage /@ q["Stages"]}],
        Select[q["Conditions"], First[#] =!= {1, n} &]],
      Select[q["Conditions"], First[#] === {1, n} &]]];

(* The items {{i, j}, pattern} inside a Condition's span become one. *)
coverStages[items_, {{i_, j_}, test_}] :=
  With[{in = Flatten @ Position[items, {{a_, b_}, _} /; i <= a && b <= j, {1}, Heads -> False]},
    Join[Take[items, First[in] - 1],
      {{{i, j}, conditionWith[PatternSequence @@ items[[in, 2]], test]}},
      Drop[items, Last[in]]]];

tupleRule[q_] := solvable[RuleDelayed @@ Join[Hold @@ {tuplePattern[q]}, q["Body"]]];

(* A list stage in a tuple. In a recognised shape, the method that selected
   the child has checked its place and its context entries, and only the
   selected entry can name anything seen outside the list (shape 7's other
   names are seen only by its own Condition, which the method has
   evaluated), so the stage is that entry, matched
   against the selected child: the list is not matched again. On the general
   matcher another entry may bind names, so the stage is the list, with the
   selected entry at the child's index, and each context combinator entry's
   chain completing from its child. *)
tupleStage[ls : listStage[a_]] /; recognisedQ[ls] := selectedEntry[a];
tupleStage[listStage[a_]] :=
  With[{par = a["Parent"], i = a["At"], pre = a["Index"]},
    Condition @@ Join[Hold @@ {listSlot[namedPattern[par, _], namedPattern[i, _], a["Pattern"]]},
      heldAnd[Hold[Length[{pre}] + 1 == i], contextChecks[a]]]];
tupleStage[s_] := s;

(* The children a list stage selects, from listSlot[parent, _, children]: each
   child's index. *)
selectRule[listStage[a_]] :=
  With[{par = a["Parent"], pre = a["Index"]}, With[{slot = listSlot[namedPattern[par, _], _, a["Pattern"]]},
    RuleDelayed @@ Join[
      If[a["Checks"] === {}, Hold[slot], Hold @@ {Condition @@ Join[Hold[slot], contextChecks[a]]}],
      Hold[Length[{pre}] + 1]]]];

(* Held: the marks are names the list binds. *)
contextChecks[a_] :=
  With[{par = a["Parent"]},
    Fold[heldAnd, Hold[True], Function[{id, m}, Hold[contextQ[id, par, Length[{m}] + 1]]] @@@ a["Checks"]]];

heldAnd[Hold[True], b_Hold] := b;
heldAnd[Hold[x_], Hold[True]] := Hold[x];
heldAnd[Hold[x_], Hold[y_]] := Hold[x && y];

(* Extract reads {} as no positions, not as the whole tree. *)
at[{}] := $chainTree;
at[p_] := Extract[$chainTree, p];

elementIndices[l_List] := Flatten @ Position[l, _XMLElement, {1}, Heads -> False];

(* The document above the top elements (ADR 0018) is the site {0}, which no
   position in the tree is: Extract gives the tree's head there. Its element
   children are the top elements: the root element of an XMLObject, the
   elements of a list, or a bare XMLElement itself, at {}. *)
$documentSite = {0};

(* The parent of an element's site: an element child is at {..., 3, k}, and
   every other element is a top element. *)
parentOf[p_] := If[Length[p] >= 2 && p[[-2]] === 3, Drop[p, -2], $documentSite];

topSites[XMLObject["Document"][__]] := {{2}};
topSites[_XMLElement] := {{}};
topSites[l_List] := List /@ elementIndices[l];

(* selected[r, p, s]: the sites related to p by r that stage s selects. From
   the document, every element is a descendant, the input included, which is
   never a result (siteTuples). *)
selected[Descendant, {0}, s_] := Position[$chainTree, s, {0, Infinity}, Heads -> False];
selected[Child, {0}, s_] := With[{k = kidsAt[$documentSite]}, Pick[k[[1]], MatchQ[s] /@ k[[2]]]];
selected[Descendant, p_, s_] := Join[p, #] & /@ Position[at[p], s, Infinity, Heads -> False];
selected[Child, p_, s_] := Join[p, {3}, #] & /@ Position[at[p][[3]], s, {1}, Heads -> False];

(* The element children of the element or document at par: their sites, the
   elements, and each site's place among them, found once per parent in a run,
   since a list of children may be long; none when par is not an element. *)
kidsAt[par_] := Replace[$kids[par], _Missing :> ($kids[par] = kidsOf[par])];

kidsOf[{0}] := With[{ss = topSites[$chainTree]}, kidsList[ss, If[ss === {}, {}, atAll[ss]]]];
kidsOf[par_] :=
  With[{e = at[par]},
    If[MatchQ[e, _XMLElement],
      With[{is = elementIndices[Last[e]]}, kidsList[Join[par, {3, #}] & /@ is, Last[e][[is]]]],
      {{}, {}, <||>}]];

kidsList[sites_, els_] := {sites, els, AssociationThread[sites, Range[Length[sites]]]};

(* The one list matcher (ADR 0016): the indices of the children els of par that
   a list stage selects, each once, by the stage's method. The general matcher
   takes them from its rule's matches. Anywhere selects each child s matches,
   which Position finds without building the sequence before each one: over
   5,000 siblings that is 1 ms against 300 ms. A position among all children
   tests only the children at the indices its lengths allow, one at a time
   when no copies are needed, which is cheaper per parent than mapping over
   them. *)
listIndices[anywhere[s_, n_], _, els_] := anywhereIndices[copiedBy[els, n], s];
listIndices[amongChildren[before_, after_, s_, n_], _, els_] := matchedAt[amongIndices[before, after, Length[els]], els, s, n];
listIndices[amongMatching[before_, after_, s_, n_], _, els_] := matchedAt[matchingIndices[before, after, els], els, s, n];
listIndices[ordered[before_, around_, after_, s_, n_], par_, els_] := matchedAt[orderedIndices[before, around, after, par, els], els, s, n];
listIndices[measured[block_, view_, measures_, test_, s_, n_], _, els_] := matchedAt[measuredIndices[block, view, measures, test, els], els, s, n];
listIndices[generalMatcher[rule_, n_], par_, els_] := Union @ ReplaceList[copiedBy[listSlot[par, 0, els], n], rule];

anywhereIndices[els_, s_] := Flatten @ Position[els, s, {1}, Heads -> False];

(* The indices is of the children els that s matches. *)
matchedAt[is_, els_, s_, None] := Select[is, MatchQ[els[[#]], s] &];
matchedAt[is_, els_, s_, n_] := Pick[is, MatchQ[s] /@ copied[els[[is]], n]];

(* The indices among len children with as many children before and after as
   the lengths before and after allow. *)
amongIndices[before_, $anyLength, len_] := lengthsUpTo[before, len - 1] + 1;
amongIndices[$anyLength, after_, len_] := Reverse[len - lengthsUpTo[after, len - 1]];
amongIndices[before_, after_, len_] := Intersection[lengthsUpTo[before, len - 1] + 1, len - lengthsUpTo[after, len - 1]];

(* The indices among the children els with as many children that match t1
   before them, and t2 after them, as the lengths before and after allow: each
   pattern is tested once per child, and the counts are running totals. *)
matchingIndices[counted[t1_, before_], counted[t2_, after_], els_] :=
  With[{marks = AssociationMap[matchMarks[#, els] &, Union[{t1, t2}]]},
    Pick[Range[Length[els]],
      allowedCounts[before, Accumulate[marks[t1]] - marks[t1]] allowedCounts[after, Total[marks[t2]] - Accumulate[marks[t2]]], 1]];

matchMarks[Verbatim[_], els_] := ConstantArray[1, Length[els]];
matchMarks[t_, els_] := Boole[MatchQ[t] /@ els];

(* 1 where a count is one the lengths allow, and 0 where not. *)
allowedCounts[$anyLength, counts_] := ConstantArray[1, Length[counts]];
allowedCounts[lengths_, counts_] :=
  Normal[SparseArray[Thread[(lengthsUpTo[lengths, Length[counts] - 1] + 1) -> 1], Length[counts]]][[counts + 1]];

(* The indices among the children els where the entries next to the selected
   one match around it, and the blocks before and after it fit in order
   between it and the ends: each entry is tested once on each child. *)
orderedIndices[before_, {left_, right_}, after_, par_, els_] :=
  With[{len = Length[els], nl = Length[left], nr = Length[right],
      marks = AssociationMap[testMarks[#, par, els] &, Union @@ Cases[{before, left, right, after}, {__tested}, Infinity]]},
    With[{fromStart = startBounds[before, marks, len], fromEnd = startBounds[after, Reverse /@ marks, len]},
      With[{lo = Max[1, First[fromStart] + nl, len + 1 - nr - Last[fromEnd]], hi = Min[len, Last[fromStart] + nl, len + 1 - nr - First[fromEnd]]},
        Fold[Intersection,
          If[lo <= hi, Range[lo, hi], {}],
          {If[nl == 0, Nothing, blockStarts[left, marks, len] + nl], If[nr == 0, Nothing, blockStarts[right, marks, len] - 1]}]]]];

(* 1 at each child that an entry matches, and 0 elsewhere. The rest of a
   context combinator entry's chain runs only from a child its first stage
   matches. *)
testMarks[tested[p_, None], _, els_] := matchMarks[p, els];
testMarks[tested[p_, id_], par_, els_] := MapIndexed[Boole[MatchQ[#1, p] && contextQ[id, par, First[#2]]] &, els];

(* The indices where each entry of a block matches the child at its offset. *)
blockStarts[block_, marks_, len_] :=
  With[{k = Length[block]},
    If[k > len, {}, Flatten @ Position[Times @@ MapIndexed[marks[#1][[First[#2] ;; len - k + First[#2]]] &, block], 1, {1}]]];

(* Where the entries next to the selected one may start, counted from one end
   of the children, as {lo, hi}: after the blocks of that side, each placed at
   its earliest after the one before it, and the first at the end itself when
   the side is anchored. With no blocks, an anchored side starts at the end.
   {Infinity, Infinity} when the blocks do not fit. *)
startBounds[placed[True, {}], _, _] := {1, 1};
startBounds[placed[False, {}], _, _] := {1, Infinity};
startBounds[placed[anchored_, {first_, rest___}], marks_, len_] :=
  {Fold[placedAfter[marks, len], If[anchored, anchoredEnd[first, marks, len], placedAfter[marks, len][0, first]], {rest}] + 1, Infinity};

(* The last index a block takes at its earliest after index end, Infinity when
   it does not fit. *)
placedAfter[marks_, len_][end_, block_] := SelectFirst[blockStarts[block, marks, len], # > end &, Infinity] + Length[block] - 1;

(* The last index a block takes at index 1, Infinity when it does not match
   there. *)
anchoredEnd[block_, marks_, len_] := If[First[blockStarts[block, marks, len], 0] == 1, Length[block], Infinity];

(* The indices among the children els after the block of entries before the
   selected one, where the test holds of the measures: each pattern is tested
   once on each child, as the test sees it (view), and each measure is read
   from running totals for every index at once. *)
measuredIndices[block_, view_, measures_, test_, els_] :=
  With[{js = blockEnds[block, els]},
    Which[js === {}, {}, measures === {}, If[TrueQ[test[]], js, {}], True,
      With[{marks = measureMarks[measures, view, els]},
        Pick[js, TrueQ /@ MapThread[test, measureValues[#, js, els, marks] & /@ measures]]]]];

(* 1 at each child that a pattern a measure tests matches, as the test sees
   the child, and 0 elsewhere, by pattern: each tested once on each child. *)
measureMarks[measures_, view_, els_] :=
  With[{ps = Union[Cases[measures, countIn[_, t_] :> t], Join @@ Cases[measures, matchIn[_, es_] :> DeleteCases[es, Verbatim[___]]]]},
    If[ps === {}, <||>, With[{seen = view /@ els}, AssociationMap[matchMarks[#, seen] &, ps]]]];

(* The indices j such that the block matches the children just before j. *)
blockEnds[{}, els_] := Range[Length[els]];
blockEnds[block_, els_] :=
  With[{k = Length[block], len = Length[els]},
    If[len <= k, {},
      Pick[Range[k + 1, len], Times @@ MapIndexed[matchMarks[#1, els][[First[#2] ;; len - k - 1 + First[#2]]] &, block], 1]]];

(* The first and last index of a span, for each index js of the selected
   child: an offset from it, or the start or end of the children. *)
spanFirst[None, js_] := ConstantArray[1, Length[js]];
spanFirst[c_, js_] := js + c;
spanLast[None, js_, len_] := ConstantArray[len, Length[js]];
spanLast[c_, js_, _] := js + c;

(* The values of a measure for each index js of the selected child. *)
measureValues[lengthIn[{lo_, hi_}], js_, els_, _] := spanLast[hi, js, Length[els]] - spanFirst[lo, js] + 1;
measureValues[countIn[{lo_, hi_}, t_], js_, els_, marks_] :=
  With[{totals = Prepend[Accumulate[marks[t]], 0]},
    totals[[spanLast[hi, js, Length[els]] + 1]] - totals[[spanFirst[lo, js]]]];
measureValues[tagCountIn[{lo_, hi_}, c_], js_, els_, _] :=
  With[{tags = First /@ els},
    With[{groups = Values @ PositionIndex[tags], len = Length[tags]},
      With[{ranks = Normal @ SparseArray[Flatten[Thread[# -> Range[0, Length[#] - 1]] & /@ groups], len],
          sizes = Normal @ SparseArray[Flatten[Thread[# -> Length[#]] & /@ groups], len]},
        tagsUpTo[hi, c, js, tags, ranks, sizes] - If[lo === None, 0, tagsUpTo[lo - 1, c, js, tags, ranks, sizes]]]]];
measureValues[matchIn[{None, hi_}, es_], js_, els_, marks_] := runFlags[es, marks, Length[els]][[spanLast[hi, js, Length[els]] + 1]];
measureValues[matchIn[{lo_, None}, es_], js_, els_, marks_] :=
  runFlags[Reverse[es], Reverse /@ marks, Length[els]][[Length[els] - spanFirst[lo, js] + 2]];

(* The number of children up to index j + e (or all of them, for None) with
   the tag of the child at j + c: ranks counts those before a child, sizes all
   of them, and the children between the two are compared one offset at a
   time. *)
tagsUpTo[None, c_, js_, _, _, sizes_] := sizes[[js + c]];
tagsUpTo[e_, c_, js_, tags_, ranks_, _] :=
  With[{m = js + c, d = e - c},
    ranks[[m]] + If[d >= 0, 1, -1] Total[Table[Boole[MapThread[SameQ, {tags[[m]], tags[[m + t]]}]], {t, If[d >= 0, Range[0, d], Range[d + 1, -1]]}]]];

(* For each L from 0 to len, whether the first L of len children match {es},
   from each entry's marks on them, where each entry is ___ or matches one
   child: the blocks between the ___ are placed at their earliest, as for
   shape 6, and a last block with no ___ after it ends at L. *)
runFlags[{}, _, len_] := Thread[Range[0, len] == 0];
runFlags[es_, marks_, len_] :=
  With[{blocks = Select[SplitBy[es, MatchQ[Verbatim[___]]], !gapsQ[#] &],
      atStart = !MatchQ[First[es], Verbatim[___]], atEnd = !MatchQ[Last[es], Verbatim[___]]},
    If[!atEnd,
      Thread[Range[0, len] >= First[startBounds[placed[atStart, blocks], marks, len]] - 1],
      With[{last = Last[blocks], bounds = startBounds[placed[atStart, Most[blocks]], marks, len]},
        Normal @ SparseArray[Thread[(Select[blockStarts[last, marks, len], Between[bounds]] + Length[last]) -> True], len + 1, False]]]];

copiedBy[x_, None] := x;
copiedBy[x_, n_] := copied[x, n];

(* The sites a list stage selects below site p, by its method: among the
   children of p, or for Descendant of p and of every element inside it, one
   parent at a time. Below the document, that is the document and every
   element. *)
listSelected[Child, p_, method_] := childrenSelected[p, method];
listSelected[Descendant, {0}, method_] :=
  Join @@ (childrenSelected[#, method] & /@
    Prepend[Position[$chainTree, XMLElement[_, _, {___, _XMLElement, ___}], {0, Infinity}, Heads -> False], $documentSite]);
listSelected[Descendant, p_, method_] :=
  Join @@ (childrenSelected[Join[p, #], method] & /@ Position[at[p], XMLElement[_, _, {___, _XMLElement, ___}], {0, Infinity}, Heads -> False]);

(* A recognised shape selects only children that its selected entry matches,
   so an element with none of them is passed over without listing its children:
   most elements, below an any-element parent stage as in li:first-child. *)
childrenSelected[par_, $recognisedMethods[___, s_, None]] /; par =!= $documentSite && FreeQ[Last[at[par]], s, {1}] := {};
childrenSelected[par_, method_] :=
  With[{k = kidsAt[par]}, If[k[[2]] === {}, {}, k[[1, listIndices[method, par, k[[2]]]]]]];

(* The tuple's elements, a list stage on the general matcher as listSlot[parent,
   index, children], and one of a recognised shape as the selected child (see
   tupleStage). *)
tupleElements[q_] :=
  With[{slots = listSlots[q]}, If[slots === {}, atAll, withListSlots[slots]]];

listSlots[q_] := Flatten @ Position[q["Stages"], ls_listStage /; !recognisedQ[ls], {1}, Heads -> False];

withListSlots[slots_][t_] := ReplacePart[atAll[t], Thread[slots -> (listSlotAt /@ t[[slots]])]];

listSlotAt[site_] :=
  With[{par = parentOf[site]}, With[{k = kidsAt[par]}, listSlot[par, k[[3]][site], k[[2]]]]];

tuplesElements[q_, tuples_] := If[listSlots[q] =!= {}, tupleElements[q] /@ tuples, elementsAt[tuples]];

(* Whether the child at index j of par completes context combinator entry id:
   the rest of its chain run from that child alone, once per child in a run. *)
contextQ[id_, par_, j_] :=
  With[{site = kidsAt[par][[1, j]]},
    Lookup[$contextMemo, Key[{id, site}], $contextMemo[{id, site}] = completesQ[$contexts[id], site]]];

completesQ[q_, site_] := siteTuples[q["Chain"], q["TupleTest"], {site}] =!= {};

(* The test a chain's tuples pass, None when its stages' own matches decide. *)
tupleTest[q_] := If[stagesDecideQ[q], None, MatchQ[solvable[tuplePattern[q]]] @* tupleElements[q]];

(* Adjacent[a, b] is Child[XMLDocument[] | XMLPattern[_], {___, a, b, ___}]
   and Sibling[a, b] is Child[XMLDocument[] | XMLPattern[_], {___, a, ___, b, ___}]
   (ADR 0016, ADR 0018): from an a at index i of its
   parent's children, the list {Repeated[_, {i - 1}], _, b, ___} or
   {Repeated[_, {i - 1}], _, ___, b, ___}, which is {b, ___} or {___, b, ___}
   over the children after it. The parent of a top element is the document,
   so the top elements of a list are siblings (ADR 0018); the document has
   none. *)
siblingSiteQ[p_] := p =!= $documentSite;

followingSelected[p_, s_] /; siblingSiteQ[p] :=
  With[{k = kidsAt[parentOf[p]]},
    With[{i = k[[3]][p]},
      k[[1, i + anywhereIndices[Drop[k[[2]], i], s]]]]];
followingSelected[_, _] := {};

(* Adjacent extends the tuples whose last sites are children of one parent
   together: {b, ___} over the children after a child matches when the next
   one matches b, as ___ matches the rest. *)
adjacentSelected[tuples_, s_] /; siblingSiteQ[Last[First[tuples]]] :=
  Module[{k, next, in, ts, ns, keep},
    k = kidsAt[parentOf[Last[First[tuples]]]];
    next = Lookup[k[[3]], Last /@ tuples] + 1;
    in = UnitStep[Length[k[[2]]] - next];
    ts = Pick[tuples, in, 1];
    ns = Pick[next, in, 1];
    keep = MatchQ[s] /@ k[[2, ns]];
    MapThread[Append, {Pick[ts, keep], k[[1, Pick[ns, keep]]]}]];
adjacentSelected[_, _] := {};

(* Sibling[before, after] matches an element with SOME earlier sibling matching
   before together with it, the whole chain's names and Condition included, and
   gives that element once. So a tuple ending at an after site defers its before
   stage: it holds before[g, k], the choices of group g earlier than the sibling
   at index k, and a runOf mark for each further stage a choice fixes. A choice
   fixes the stages back to the start of its run of Adjacent and Sibling links,
   as they are its siblings; the stages before the run relate to the list, not
   to the sibling, and group the choices. Adjacent needs no choice: an element
   has one previous sibling. A bare XMLElement input, at {}, is the document's
   only child, and the document has no siblings, so a sibling link drops
   both. *)
extend[tuples_, link : {Adjacent | Sibling, _, _}] /; MemberQ[tuples, {___, {} | {0}}] :=
  extend[DeleteCases[tuples, {___, {} | {0}}], link];
extend[tuples_, {Adjacent, s_, _}] := related[Adjacent, tuples, s];
extend[tuples_, {Sibling, s_, run_}] :=
  Join @@ (siblingChoices[#, s, run] & /@ GatherBy[tuples, {Take[#, run - 1], parentOf[Last[#]]} &]);
extend[tuples_, {Descendant, s_listStage, _}] /; $stagesDecide := listRelated[Descendant, outermost[tuples], s];
extend[tuples_, {r_, s_listStage, _}] := listRelated[r, tuples, s];
extend[tuples_, {Descendant, s_, _}] /; $stagesDecide := related[Descendant, outermost[tuples], s];
extend[tuples_, {r_, s_, _}] := related[r, tuples, s];

related[Adjacent, tuples_, s_] := Join @@ (adjacentSelected[#, s] & /@ GatherBy[tuples, parentOf @* Last]);
related[r_, tuples_, s_] := Join @@ (Function[t, Append[t, #] & /@ selected[r, Last[t], s]] /@ tuples);

listRelated[r_, tuples_, listStage[a_]] :=
  With[{m = a["Method"]}, Join @@ (Function[t, Append[t, #] & /@ listSelected[r, Last[t], m]] /@ tuples)];

(* Descendant[ancestor, desc] gives each element once, as querySelectorAll and
   soupsieve's select do. When the stages' own matches decide, any ancestor
   will do, and the first in document order, the outermost, is taken: a name
   bound at the ancestor stage, as in a rule body, sees the outermost ancestor.
   So a site below another tuple's last site is dropped, its descendants being
   the other's too; the subtrees searched are then disjoint. When the stages
   decide, a site is the last of at most one tuple after every link, so the
   dropped tuples are the only duplicates. Every element is below the
   document. *)
outermost[tuples_] /; MemberQ[tuples, {$documentSite}] := {{$documentSite}};
outermost[tuples_] :=
  Module[{cover = None},
    Select[tuples[[documentOrdering[Last /@ tuples]]],
      Function[t, If[cover =!= None && Take[Last[t], UpTo[Length[cover]]] === cover,
        False, cover = Last[t]; True]]]];

(* Document order, as querySelectorAll gives elements: lexicographic, with a
   position before every position below it, so an element comes before the
   elements nested in it and after an earlier sibling's. Ties keep their
   order. The document comes first. *)
documentOrdering[{}] := {};
documentOrdering[ps_] :=
  Ordering @ Join[PadRight[Replace[ps, {0} -> {-1}, {1}], {Length[ps], Max[Length /@ ps]}, 0], List /@ Range[Length[ps]], 2];

(* The choices are a group's tuples from the run on, in document order of their
   last site; the sites the list selects after the first choice are the
   candidates. When the stages' own matches decide the match, the first choice
   is the one taken, and taken at once, as Descendant takes the outermost
   ancestor: Sibling then lists the children once per parent. *)
siblingChoices[tuples_, s_, run_] :=
  With[{sorted = tuples[[Ordering[Last /@ Last /@ tuples]]]},
    With[{sites = followingSelected[Last[First[sorted]], s]},
      If[$stagesDecide,
        Append[First[sorted], #] & /@ sites,
        With[{g = Length[$choices] + 1},
          $choices[g] = sorted[[All, run ;;]];
          Join[Take[First[sorted], run - 1], {before[g, Last[#]]},
              ConstantArray[runOf, Length[First[sorted]] - run], {#}] & /@ sites]]]];

(* For each link, the stage its run of Adjacent and Sibling links starts at. *)
runStarts[links_] :=
  FoldList[If[MatchQ[First[#2], Adjacent | Sibling], #1, Last[#2]] &, 1,
    Transpose[{Most[links], Range[2, Length[links]]}]];

(* The first site tuple t stands for that test accepts, or Nothing. The latest
   deferred stage is chosen first, earliest sibling first: a name bound at the
   before stage, as in a rule body, sees the first earlier sibling, in document
   order, with which the element matches the whole pattern. *)
resolved[t_, test_] := Catch[choose[t, test]; Nothing, $chosen];

choose[t_, test_] :=
  Replace[FirstPosition[Reverse[t], _before, None, {1}, Heads -> False], {
    None :> If[test[t], Throw[t, $chosen]],
    {r_} :> chooseAt[t, Length[t] + 1 - r, test]}];

(* A loop by index: Do over a long list of choices costs its length at once. *)
chooseAt[t_, p_, test_] :=
  With[{cs = $choices[t[[p, 1]]], k = t[[p, 2]]},
    Module[{i = 1},
      While[i <= Length[cs] && Last[Last[cs[[i]]]] < k,
        choose[Join[Take[t, p - 1], cs[[i]], Drop[t, p - 1 + Length[cs[[i]]]]], test];
        i++]]];

(* The site tuples of a chain that test accepts, test None when the stages'
   own matches decide, in document order of their last sites, as a base
   XMLCases gives its elements. The first stage's sites include the document
   and the root, which a bare XMLElement tree makes an element. The root can
   be a later stage below the document, but is never a result, as it is never
   one of a base XMLCases (ADR 0018). *)
siteTuples[chain_, test_, starts_ : All] :=
  With[{links = chain[[2 ;; ;; 2]]},
    Block[{$choices = <||>, $stagesDecide = test === None},
      If[$stagesDecide, Identity, firstPerSite[#, test] &] @ byLastSite @ DeleteCases[Fold[extend,
        List /@ firstSites[First[chain], starts],
        Transpose[{links, chain[[3 ;; ;; 2]], runStarts[links]}]], {__, {}}]]];

(* The sites of the first stage, or those of starts that it matches. *)
firstSites[s_, All] :=
  Join[If[MatchQ[Head[$chainTree], s], {$documentSite}, {}], Position[$chainTree, s, {0, Infinity}, Heads -> False]];
firstSites[s_, starts_] := Select[starts, MatchQ[at[#], s] &];

(* Each element once: of the tuples ending at one site, which are adjacent
   once ordered by their last sites, the first that test accepts, by their
   stages in document order, the latest stage first, as a Sibling choice is
   made. So a name bound at a Descendant's ancestor stage sees the outermost
   ancestor with which the element matches the whole pattern. A tuple with a
   deferred Sibling stage is ordered once its choices are made. *)
firstPerSite[tuples_, test_] := firstAccepted[#, test] & /@ SplitBy[tuples, Last];

firstAccepted[ts_, test_] /; FreeQ[ts, _before] := SelectFirst[inDocumentOrder[ts], test, Nothing];
firstAccepted[ts_, test_] := Replace[resolved[#, test] & /@ ts, {{} -> Nothing, rs_ :> First[inDocumentOrder[rs]]}];

inDocumentOrder[{t_}] := {t};
inDocumentOrder[ts_] :=
  With[{n = Max[Map[Length, ts, {2}]]},
    ts[[documentOrdering[Flatten[PadRight[Reverse[Most[#]], {Automatic, n}]] & /@ ts]]]];

(* Tuples in document order of their last sites; tuples ending at one site
   keep their order. *)
byLastSite[tuples_] := tuples[[documentOrdering[Last /@ tuples]]];

(* The elements at a list of positions, with one Extract. *)
atAll[ps_] := Extract[$chainTree, ps];

(* The element tuples of site tuples, which have one length. *)
elementsAt[{}] := {};
elementsAt[tuples_] := Partition[atAll[Join @@ tuples], Length[First[tuples]]];

(* The site tuples whose elements match the tuple pattern. The stages' own
   matches, which selected the sites, decide it unless a Condition wraps a
   combinator or a name is bound at two stages. *)
matchedSites[q_] := siteTuples[q["Chain"], q["TupleTest"]];

stagesDecideQ[q_] :=
  q["Conditions"] === {} && DuplicateFreeQ[Join @@ (stageNames /@ q["Stages"])];

(* A Condition in the body can reject a tuple. *)
bodyRejectsQ[q_] := bodyConditionQ[q["Body"]];

namesIn[s_] :=
  DeleteDuplicates @ Cases[s, Verbatim[Pattern][n_Symbol, _] :> Hold[n], {0, Infinity}, Heads -> True];

(* The plain form picks the last element of a matching tuple rather than binding
   the tuple: a rule's right-hand side re-evaluates what it is given, and a
   tuple may hold a large element. *)
chainCases[tree_, q_, n_] /; bodyRejectsQ[q] := Block[{$chainTree = tree}, Take[ruleValues[q], UpTo[n]]];
chainCases[tree_, q_, n_] /; q["Body"] =!= None :=
  Block[{$chainTree = tree}, Cases[tuplesElements[q, matchedSites[q]], q["TupleRule"], {1}, n]];
chainCases[tree_, q_, n_] :=
  Block[{$chainTree = tree}, atAll[Last /@ Take[matchedSites[q], UpTo[n]]]];

chainFirst[tree_, q_, default_] /; bodyRejectsQ[q] :=
  Block[{$chainTree = tree}, Replace[ruleValues[q], {{v_, ___} :> v, {} -> default}]];
chainFirst[tree_, q_, default_] /; q["Body"] =!= None :=
  Block[{$chainTree = tree},
    FirstCase[tuplesElements[q, matchedSites[q]], q["TupleRule"], default, {1}]];
chainFirst[tree_, q_, default_] :=
  Block[{$chainTree = tree},
    Replace[matchedSites[q], {{t_, ___} :> at[Last[t]], {} -> default}]];

(* A Condition in a rule's body can reject a tuple, so it takes part in
   choosing one, as a Condition on the combinator does: as Cases gives the
   places where a rule gives a value, a tuple is accepted when the rule gives
   it one. The value is kept, so the body is not evaluated again once the tuple
   is chosen. The accepted tuples are given with their values, keyed by tuple,
   as {tuples, values}: a value of Nothing or Sequence[] has no place in a
   list. *)
ruleTuples[q_] :=
  Module[{rule = q["TupleRule"], elements = tupleElements[q], values = <||>, tuples},
    tuples = siteTuples[q["Chain"],
      Function[t, With[{v = Replace[elements[t], {rule, _ :> $unmatched}]},
        v =!= $unmatched && (values[t] = v; True)]]];
    {tuples, values}];

ruleValues[q_] := Replace[ruleTuples[q], {tuples_, values_} :> Lookup[values, Key /@ tuples]];

(* The sites chainCases takes its elements from, or its values: the last sites
   of the tuples it accepts. A site whose value is Nothing is a site. *)
chainPositions[tree_, q_, n_] /; bodyRejectsQ[q] :=
  Block[{$chainTree = tree}, Last /@ Take[First[ruleTuples[q]], UpTo[n]]];
chainPositions[tree_, q_, n_] := Block[{$chainTree = tree}, Last /@ Take[matchedSites[q], UpTo[n]]];

(* A chain deletes the elements its last stage selects. Delete removes
   positions nested in one another together. *)
chainDelete[tree_, q_] :=
  Block[{$chainTree = tree},
    deleteAt[tree, DeleteDuplicates[Last /@ matchedSites[q]]]];

(* =========================================================== *)
(* Alternatives of chains (ADR 0015)                            *)
(*                                                              *)
(* Alternatives holding a combinator run as the list of their   *)
(* chains, in disjunctive normal form, over one materialised    *)
(* tree, and are merged per element, as XPath's union merges    *)
(* node sets: each element once, in document order, from the    *)
(* first alternative, in written order, that accepts it. Each   *)
(* chain chooses its own tuple by ADR 0014's rule, so the       *)
(* choice of alternative ranks above every choice of stage. An  *)
(* alternative that is an element pattern is a chain of one     *)
(* stage, and selects what a plain query with it selects, never *)
(* the root.                                                    *)
(* =========================================================== *)

(* The site tuples of alternative a that test accepts, test None when its
   stages decide, in document order of their last sites. *)
alternativeSites[a_, test_] /; a["Links"] === {} :=
  With[{ts = List /@ elementSites[First[a["Chain"]]]}, If[test === None, ts, Select[ts, test]]];
alternativeSites[a_, test_] := siteTuples[a["Chain"], test];

(* The sites below the root that s matches, in document order. *)
elementSites[s_] := positionsInOrder[$chainTree, s];

(* The accepted tuples of alternative a whose last site keep accepts, each
   {tuple}, or {tuple, value} when the body can reject and so is evaluated in
   choosing one. keep is tested first, so a site an earlier alternative took is
   not tried again, and its body not evaluated. *)
acceptedTuples[a_, keep_] /; bodyRejectsQ[a] :=
  Module[{rule = a["TupleRule"], elements = tupleElements[a], values = <||>, tuples},
    tuples = alternativeSites[a,
      Function[t, keep[Last[t]] && With[{v = Replace[elements[t], {rule, _ :> $unmatched}]},
        v =!= $unmatched && (values[t] = v; True)]]];
    {#, values[#]} & /@ tuples];
acceptedTuples[a_, keep_] :=
  With[{test = a["TupleTest"]},
    List /@ Select[alternativeSites[a, If[test === None, None, keep[Last[#]] && test[#] &]], keep @* Last]];

(* For each alternative in order, its accepted entries {k, tuple} or {k, tuple,
   value}, k its index, of the sites no earlier alternative took. *)
unionEntries[q_] :=
  Module[{taken = <||>},
    Join @@ MapIndexed[
      Function[{a, k}, With[{es = acceptedTuples[a, !KeyExistsQ[taken, #] &]},
        Scan[(taken[Last[First[#]]] = True) &, es];
        Prepend[#, First[k]] & /@ es]],
      q["Alternatives"]]];

(* What an entry gives: its element, or its value, the body evaluated now when
   it was not in choosing the entry. *)
entryResult[q_, rules_][{k_, t_}] :=
  If[q["Body"] === None, at[Last[t]], Replace[tupleElements[q["Alternatives"][[k]]][t], rules[[k]]]];
entryResult[_, _][{_, _, v_}] := v;

inSiteOrder[es_] := es[[documentOrdering[es[[All, 2, -1]]]]];

entryRules[q_] := Lookup[q["Alternatives"], "TupleRule"];

unionCases[tree_, q_, n_] :=
  Block[{$chainTree = tree},
    With[{es = Take[inSiteOrder[unionEntries[q]], UpTo[n]]},
      If[q["Body"] === None, atAll[es[[All, 2, -1]]], entryResult[q, entryRules[q]] /@ es]]];

(* The sites unionCases takes its elements or values from. *)
unionPositions[tree_, q_, n_] :=
  Block[{$chainTree = tree}, Take[inSiteOrder[unionEntries[q]], UpTo[n]][[All, 2, -1]]];

(* Each alternative stops at its first accepted entry before the best so far:
   the answer is the earliest, ties going to the earlier alternative, as one
   element can only tie with itself. *)
unionFirst[tree_, q_, default_] :=
  Block[{$chainTree = tree},
    Module[{best = None},
      MapIndexed[
        Function[{a, k}, With[{keep = If[best === None, True &, With[{b = best[[2, -1]]}, beforeQ[#, b] &]]},
          Replace[firstAcceptedTuple[a, keep], {e_} :> (best = Prepend[e, First[k]])]]],
        q["Alternatives"]];
      If[best === None, default, entryResult[q, entryRules[q]][best]]]];

(* An element pattern's first match in document order is found without the
   others; it is a candidate only if keep takes it, and no later match is. *)
firstAcceptedTuple[a_, keep_] /; a["Links"] === {} && a["StagesDecide"] && !bodyRejectsQ[a] :=
  Select[{{#}} & /@ firstMatchPositions[$chainTree, First[a["Chain"]], 1], keep[#[[1, -1]]] &];
firstAcceptedTuple[a_, keep_] := Take[acceptedTuples[a, keep], UpTo[1]];

(* Whether site p comes before site s in document order. *)
beforeQ[p_, s_] := p =!= s && documentOrdering[{p, s}] === {1, 2};

unionDelete[tree_, q_] :=
  Block[{$chainTree = tree},
    deleteAt[tree, DeleteDuplicates[Join @@ (Last @* First /@ acceptedTuples[#, True &] & /@ q["Alternatives"])]]];

(* A document keeps its root element, which an XMLObject needs (ADR 0018). *)
deleteAt[tree : XMLObject["Document"][_, _, _], ps_] /; MemberQ[ps, {2}] :=
  (Message[XMLDeleteCases::root]; deleteAt[tree, DeleteCases[ps, {2}]]);
deleteAt[tree_, {}] := tree;
deleteAt[tree_, ps_] := Delete[tree, ps];

