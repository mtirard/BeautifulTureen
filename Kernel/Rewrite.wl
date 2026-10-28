(* ::Package:: *)
(* HTMLPatterns: rewriting a tree at positions, and XMLDeleteCases over tree patterns *)

(* Used by XMLFunctions.wl *)
PackageScoped[treeDelete]

(* =========================================================== *)
(* Rewriting at positions (spec sections 4 and 6)               *)
(*                                                              *)
(* rewritten[input, {pos -> f, ...}] sets the part at each      *)
(* position to f of its current value, in reverse position      *)
(* order: contents before their container, later before        *)
(* earlier. Positions are those of the original input, and      *)
(* stay so however earlier rewrites shift indices: an element    *)
(* that is rewritten inside, or holds a rewritten one, is        *)
(* opened, its element children replaced by references ref[p]   *)
(* to their original positions, and a list key's tokens by      *)
(* tokenRef[i]; the tree is put together at the end. A part     *)
(* that an earlier rewrite replaced or removed, itself or a     *)
(* container, is stale, and is not rewritten.                   *)
(*                                                              *)
(* What f gives, by kind: an element, a run or a gap, the nodes *)
(* in its place (Nothing for none, Splice[list] for several); a *)
(* tag, a string; Key[All], the attribute list; Key[k], the     *)
(* value, Nothing to remove the attribute; Key[listKey], the   *)
(* token list, Nothing to remove the attribute; a token, a run  *)
(* or a gap of tokens, the tokens in its place, written back    *)
(* through the reading; All, the contents.                      *)
(* =========================================================== *)

rewritten[input_, edits_] :=
  Block[{$input = input, $nodes = <||>, $originalKids = <||>, $replaced = <||>, $allReplaced = <||>,
      $before = <||>, $after = <||>, $atEnd = <||>, $tokens = <||>, $originalTokens = <||>,
      $readings = readingsInForce[], $joiners = listKeyJoiners[]},
    If[$readings === $Failed, $Failed,
      Scan[rewriteAt[#[[1]], #[[2]]] &, Reverse[edits[[positionOrdering[edits[[All, 1]]]]]]];
      assembled[]]];

(* ---- Position order (spec section 5) ---- *)

(* Each position has a key, a list of integers, that sorts as the positions
   do once padded with $keyPad, below every entry: an element step is {4, n, 2};
   within an element its tag is {0}, its attribute map {1}, its j-th
   attribute {2, j, 0}, a list key read from it {2, j, 1}, followed by that
   list's tails, its contents {3}, and among its children the gap before n
   {4, n, 0}, a run n ;; k {4, n, 1, -k} (longest first), then child n.
   Tails order as children do, with 2 for the 4. This is the order of
   Query/TreePatterns.wl's binding keys, for positions given on their own. *)
$keyPad = -10^9;

positionOrdering[ps_] :=
  With[{keys = positionKey /@ ps}, Ordering[PadRight[#, Max[0, Length /@ keys], $keyPad] & /@ keys]];

positionKey[pos_] :=
  With[{k = LengthWhile[pos, IntegerQ[#] && # > 0 &]},
    Join[Join @@ ({4, #, 2} & /@ Take[pos, k]), terminalKey[Take[pos, k], Drop[pos, k]]]];

terminalKey[_, {}] := {};
terminalKey[_, {0}] := {0};
terminalKey[_, {Key[All]}] := {1};
terminalKey[_, {All}] := {3};
terminalKey[_, {s_Span}] := sequenceKey[4, s];
terminalKey[steps_, {Key[k_], tail___}] :=
  With[{raw = If[KeyExistsQ[$readings, k], $readings[k][[1]], k], attrs = original[steps][[2]]},
    Join[{2, Replace[FirstPosition[attrs, Verbatim[Rule][raw, _], {Length[attrs] + 1}, {1}, Heads -> False], {j_} :> j],
        If[KeyExistsQ[$readings, k], 1, 0]},
      Replace[{tail}, {{} -> {}, {t_} :> sequenceKey[2, t]}]]];

sequenceKey[h_, i_Integer] := {h, i, 2};
sequenceKey[h_, Span[m_, n_]] := If[n == m - 1, {h, m, 0}, {h, m, 1, -n}];

(* ---- The original input ---- *)

inputContents[] := Replace[$input, {XMLObject["Document"][_, r_, _] :> {r}, l_List :> l, x_ :> {x}}];

(* The original element at element steps ({} the document's contents), and
   the element children of either. *)
original[{}] := inputContents[];
original[steps_] := originalKids[Most[steps]][[Last[steps]]];

originalKids[steps_] :=
  Lookup[$originalKids, Key[steps], $originalKids[steps] = Cases[Replace[original[steps], x_XMLElement :> x[[3]]], _XMLElement]];

(* ---- Opened nodes ---- *)

(* The node at element steps, opened with its ancestors: {} is the document's
   contents, any other an element. *)
opened[steps_] :=
  Lookup[$nodes, Key[steps],
    If[steps =!= {}, opened[Most[steps]]];
    $nodes[steps] = Replace[original[steps], {
      x_XMLElement :> XMLElement[x[[1]], x[[2]], referenced[steps, x[[3]]]],
      c_ :> referenced[steps, c]}]];

referenced[steps_, c_] :=
  With[{ks = Flatten @ Position[c, _XMLElement, {1}, Heads -> False]},
    ReplacePart[c, Thread[ks -> (ref[Append[steps, #]] & /@ Range[Length[ks]])]]];

contentsOf[steps_] := If[steps === {}, opened[{}], opened[steps][[3]]];

(* A reference stays in its contents list, so that rewriting one child costs
   the same however many siblings it has: what replaces child p is
   $replaced[p], and what a gap inserts is $before[p], before child p, or
   $after[p], after the last child p, or $atEnd[steps], when there is no
   child. Only All replaces a contents list, and its references with it
   ($allReplaced). *)
setContents[steps_, c_] := (
  $allReplaced[steps] = True; $atEnd[steps] = {};
  If[steps === {}, $nodes[{}] = c, $nodes[steps] = ReplacePart[opened[steps], 3 -> c]]);

(* An element is alive while no rewrite has replaced it or a container. *)
aliveQ[steps_] :=
  NoneTrue[Range[Length[steps]], KeyExistsQ[$replaced, Take[steps, #]] || KeyExistsQ[$allReplaced, Take[steps, # - 1]] &];

(* The current value at element steps. *)
current[steps_] :=
  If[KeyExistsQ[$nodes, steps],
    Replace[$nodes[steps], XMLElement[t_, a_, _] :> XMLElement[t, a, currentContents[steps]]],
    original[steps]];

currentContents[steps_] :=
  Join[
    Replace[contentsOf[steps],
      ref[p_] :> Sequence @@ Join[Lookup[$before, Key[p], {}], Lookup[$replaced, Key[p], {current[p]}], Lookup[$after, Key[p], {}]],
      {1}],
    Lookup[$atEnd, Key[steps], {}]];

assembled[] :=
  With[{c = If[KeyExistsQ[$nodes, {}], currentContents[{}], inputContents[]]},
    Replace[$input, {
      XMLObject["Document"][pro_, _, epi_] :> XMLObject["Document"][pro, Sequence @@ c, epi],
      _List :> c,
      _ :> Replace[c, {x_} :> x]}]];

(* The nodes a value stands for in a contents list. *)
nodesOf[Nothing] := {};
nodesOf[s_Splice] := List @@ s;
nodesOf[l_List] := l;
nodesOf[x_] := {x};

(* ---- One rewrite ---- *)

rewriteAt[pos_, f_] :=
  With[{k = LengthWhile[pos, IntegerQ[#] && # > 0 &]},
    With[{steps = Take[pos, k]}, If[aliveQ[steps], rewriteTerminal[steps, Drop[pos, k], f]]]];

(* An element. *)
rewriteTerminal[steps_, {}, f_] /; steps =!= {} :=
  (opened[Most[steps]]; $replaced[steps] = nodesOf[f[current[steps]]]);

rewriteTerminal[steps_, {0}, f_] := $nodes[steps] = ReplacePart[opened[steps], 1 -> f[opened[steps][[1]]]];
rewriteTerminal[steps_, {Key[All]}, f_] := $nodes[steps] = ReplacePart[opened[steps], 2 -> f[opened[steps][[2]]]];

(* A list key's token list, or a token, run or gap of it. *)
rewriteTerminal[steps_, {Key[k_], tail___}, f_] /; KeyExistsQ[$readings, k] :=
  With[{raw = $readings[k][[1]]},
    If[{tail} === {},
      setAttribute[steps, raw, Replace[f[currentTokens[steps, k]], l_List :> StringRiffle[l, $joiners[k]]]],
      setTokens[steps, k, tokensRewritten[openedTokens[steps, k], tail, f, tokenValues[steps, k, #] &]]]];

rewriteTerminal[steps_, {Key[k_]}, f_] := setAttribute[steps, k, f[Lookup[opened[steps][[2]], Key[k]]]];

rewriteTerminal[steps_, {All}, f_] := setContents[steps, f[currentContents[steps]]];

(* A run of element children: what f gives for the children still there
   replaces the first of them, and the others go. *)
rewriteTerminal[steps_, {Span[m_, n_]}, f_] /; n >= m :=
  With[{live = Select[Append[steps, #] & /@ Range[m, n], aliveQ]},
    If[live =!= {},
      opened[steps];
      With[{new = nodesOf[f[Sequence @@ current /@ live]]},
        Scan[($replaced[#] = {}) &, Rest[live]];
        $replaced[First[live]] = new]]];

(* A gap: before child n, after the last child when n is one past it, or at
   the end of contents with no element child. *)
rewriteTerminal[steps_, {Span[n_, _]}, f_] :=
  With[{new = nodesOf[f[]], len = Length[originalKids[steps]]},
    opened[steps];
    Which[
      new === {}, Null,
      n <= len, $before[Append[steps, n]] = Join[new, Lookup[$before, Key[Append[steps, n]], {}]],
      len > 0, $after[Append[steps, len]] = Join[new, Lookup[$after, Key[Append[steps, len]], {}]],
      True, $atEnd[steps] = Join[new, Lookup[$atEnd, Key[steps], {}]]]];

(* A token, a run of tokens or a gap between them, among the token
   references: as for children, but on a short list rewritten whole. cur
   gives a list's current values. *)
tokensRewritten[items_, Span[m_, n_], f_, cur_] /; n == m - 1 :=
  With[{new = nodesOf[f[]], i = FirstPosition[items, tokenRef[m], None, {1}, Heads -> False]},
    Which[
      new === {}, items,
      i =!= None, Insert[items, Splice[new], i],
      True, With[{last = FirstPosition[Reverse[items], tokenRef[_], None, {1}, Heads -> False]},
        If[last === None, Join[items, new], Insert[items, Splice[new], Length[items] - First[last] + 2]]]]];
tokensRewritten[items_, Span[m_, n_], f_, cur_] :=
  With[{here = Flatten @ Position[items, Alternatives @@ (tokenRef /@ Range[m, n]), {1}, Heads -> False]},
    If[here === {}, items,
      ReplacePart[Delete[items, List /@ Rest[here]], First[here] -> Splice[nodesOf[f[Sequence @@ cur[items[[here]]]]]]]]];
tokensRewritten[items_, i_Integer, f_, cur_] := tokensRewritten[items, Span[i, i], f, cur];

setAttribute[steps_, k_, v_] :=
  $nodes[steps] = ReplacePart[opened[steps], 2 -> With[{a = opened[steps][[2]]},
    Which[
      v === Nothing, DeleteCases[a, Verbatim[Rule][k, _]],
      MemberQ[a, Verbatim[Rule][k, _]], Replace[a, Verbatim[Rule][k, _] :> k -> v, {1}],
      True, Append[a, k -> v]]]];

(* A list key's tokens, opened as references to their original indices from
   the attribute's current value; an absent attribute reads as "". *)
openedTokens[steps_, k_] :=
  Lookup[$tokens, Key[{steps, k}],
    $originalTokens[{steps, k}] = splitTokens[steps, k];
    $tokens[{steps, k}] = tokenRef /@ Range[Length[$originalTokens[{steps, k}]]]];

splitTokens[steps_, k_] := $readings[k][[2]][Lookup[opened[steps][[2]], Key[$readings[k][[1]]], ""]];

currentTokens[steps_, k_] := If[KeyExistsQ[$tokens, {steps, k}], tokenValues[steps, k, $tokens[{steps, k}]], splitTokens[steps, k]];

tokenValues[steps_, k_, items_] := Replace[items, tokenRef[i_] :> $originalTokens[{steps, k}][[i]], {1}];

(* The tokens are written back through the reading at once, the attribute
   kept even when empty. *)
setTokens[steps_, k_, items_] := (
  $tokens[{steps, k}] = items;
  setAttribute[steps, $readings[k][[1]], StringRiffle[tokenValues[steps, k, items], $joiners[k]]]);

(* =========================================================== *)
(* XMLDeleteCases over tree patterns (spec section 6)           *)
(*                                                              *)
(* The right-hand side is a name or a list of names, with an    *)
(* optional Condition; the union of the positions of the        *)
(* counted names over all results is deleted. A bare pattern    *)
(* deletes its pattern roots.                                   *)
(* =========================================================== *)

XMLDeleteCases::delrhs = "The right-hand side of `1` should be a name of the pattern, or a list of names, optionally with a condition (/;): XMLDeleteCases deletes what those names match, as in x : XMLPattern[\"a\"] :> x. Use :> so that the names are not evaluated.";
XMLDeleteCases::target = "`1` is the position of the document or of a tag, which cannot be deleted. Name an element, an attribute, a token, a run of children or the contents instead.";
XMLDeleteCases::pathtarget = "`1` is a named path, the elements between two others, which cannot be deleted. Name the elements to delete instead.";
XMLDeleteCases::exceptname = "The name `1` is bound inside Except, which matches only where its pattern does not, so it has no value in the right-hand side. A name inside Except can be used only by tests inside that Except.";

treeDelete[tree_, q_] :=
  Catch[
    checkDeletion[q];
    With[{targets = treeTargets[XMLDeleteCases, tree, q]},
      If[targets === $Failed, $Failed, deleted[tree, DeleteDuplicates[Join @@ targets]]]],
    $refusal];

(* A rule's right-hand side names what is deleted: a name of the pattern or a
   list of them, with an optional Condition. *)
checkDeletion[q : (Rule | RuleDelayed)[lhs_, _]] :=
  Replace[Extract[q, {2}, Hold], {
    Hold[Verbatim[Condition][b_, _]] | Hold[b_] /; deletedNamesQ[Hold[b], namesIn[Hold[lhs]]] :> Null,
    _ :> refuse[XMLDeleteCases::delrhs, HoldForm[q]]}];
checkDeletion[_] := Null;

deletedNamesQ[Hold[s_Symbol], names_] := MemberQ[names, Hold[s]];
deletedNamesQ[Hold[l_List], names_] := l =!= {} && AllTrue[Thread[Hold[l]], deletedNamesQ[#, names] &];
deletedNamesQ[_, _] := False;

(* Each kind deleted: Key[All] and All are emptied; anything else is removed,
   a gap filled with nothing. A name deeper inside an XMLElement pattern
   than its slots has no position yet (ticket 16), and deletes nothing. The root of an XMLObject is
   kept. *)
deleted[tree_, targets_] :=
  Module[{ps = DeleteCases[targets, _Missing]},
    Replace[SelectFirst[ps, MatchQ[#, _Span] &], s_Span :> refuse[XMLDeleteCases::pathtarget, s]];
    Replace[SelectFirst[ps, MatchQ[#, {} | {__Integer?Positive, 0}] &], p_List :> refuse[XMLDeleteCases::target, p]];
    If[MatchQ[tree, XMLObject[_][___]] && MemberQ[ps, {1}], Message[XMLDeleteCases::root]; ps = DeleteCases[ps, {1}]];
    rewritten[tree, (# -> If[MatchQ[Last[#], Key[All] | All], {} &, Nothing &]) & /@ ps]];
