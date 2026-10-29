(* ::Package:: *)
(* HTMLPatterns: XMLPosition and XMLExtract, and the position helpers the
   query engine and the rewriting share *)

(* Used by Query/TreePatterns.wl, Rewrite.wl and Tree.wl *)
PackageScoped[elementStepQ]
PackageScoped[topItems]
PackageScoped[$keyPad]
PackageScoped[sequenceKey]
PackageScoped[tagKey]
PackageScoped[attributeMapKey]
PackageScoped[attributeKey]
PackageScoped[tokenListKey]
PackageScoped[contentsKey]
PackageScoped[textItemKey]
PackageScoped[positionOrdering]
PackageScoped[wlPositions]

(* =========================================================== *)
(* Positions (ADR 0025)                                         *)
(*                                                              *)
(* A position counts element children only, from the document:  *)
(* {} is the document, {i1, ..., ik} an element, and at most one *)
(* terminal step may follow: 0 the tag, Key[All] the attribute   *)
(* map, Key[k] an attribute value or a list key's token list,    *)
(* then a token, run or gap of that list; All the contents; a    *)
(* run m ;; n or gap n ;; n-1 of element children. A named path  *)
(* is the span upper ;; lower of its two ends.                   *)
(* =========================================================== *)

(* ---- Shared helpers ---- *)

(* An element step of a position: an element child's index. *)
elementStepQ[i_] := IntegerQ[i] && i > 0;

(* The items at the top of an input, the contents of its document: an
   XMLObject's root element, a list's items, or a bare element itself. *)
topItems[input_] := Replace[input, {XMLObject["Document"][_, r_, _] :> {r}, l_List :> l, x_ :> {x}}];

(* ---- Position order (ADR 0024) ---- *)

(* Each position has an order key, a list of integers; keys padded to one
   length with $keyPad, below every entry, compare as the positions sort, a
   container before what it holds. An element's key is its element steps',
   each {4, n, 2}; a terminal step appends the suffix its key function gives,
   from the indices that locate it in that element:
   - tagKey, the tag, {0}
   - attributeMapKey, the attribute map, {1}
   - attributeKey[j], the j-th attribute's value, {2, j, 0}
   - tokenListKey[j], the token list read from the j-th attribute (j one past
     the last attribute when it is absent), {2, j, 1}, followed by a token,
     run or gap of that list as sequenceKey[2, ...] gives it
   - contentsKey, the contents, {3}
   - textItemKey[m, k], the k-th item of the contents when it is text or
     another item that is not an element, with m - 1 element children before
     it: the gap before element child m, then k, {4, m, 0, k}. Text is not a
     position (ADR 0025), so this orders only names a query uses in its tests,
     in the order of the source: after element child m - 1's subtree and the
     gap, before the runs that start at element child m and before element
     child m itself. Text after the last element child is in the gap at the
     end
   - an element child, run or gap of the children, as sequenceKey[4, ...]
     gives it.
   Among the element children (h 4) or tokens (h 2) of one list, sequenceKey
   gives item n {h, n, 2}, the gap before it {h, n, 0}, and a run n ;; k
   {h, n, 1, -k}, longest first. *)
$keyPad = -10^9;

tagKey[] := {0};
attributeMapKey[] := {1};
attributeKey[j_] := {2, j, 0};
tokenListKey[j_] := {2, j, 1};
contentsKey[] := {3};
textItemKey[m_, k_] := Append[sequenceKey[4, m ;; m - 1], k];

sequenceKey[h_, i_Integer] := {h, i, 2};
sequenceKey[h_, Span[m_, n_]] := If[n == m - 1, {h, m, 0}, {h, m, 1, -n}];

(* The order of positions given on their own, as Ordering gives it.
   attributesOf gives the original attribute list of the element at element
   steps, and readings are the readings in force, which tell a list key's
   token list from an attribute. *)
positionOrdering[ps_, attributesOf_, readings_] :=
  With[{keys = positionKey[#, attributesOf, readings] & /@ ps},
    Ordering[PadRight[#, Max[0, Length /@ keys], $keyPad] & /@ keys]];

positionKey[pos_, attributesOf_, readings_] :=
  With[{k = LengthWhile[pos, elementStepQ]},
    Join[Join @@ (sequenceKey[4, #] & /@ Take[pos, k]), terminalKey[Take[pos, k], Drop[pos, k], attributesOf, readings]]];

terminalKey[_, {}, _, _] := {};
terminalKey[_, {0}, _, _] := tagKey[];
terminalKey[_, {Key[All]}, _, _] := attributeMapKey[];
terminalKey[_, {All}, _, _] := contentsKey[];
terminalKey[_, {s_Span}, _, _] := sequenceKey[4, s];
terminalKey[steps_, {Key[k_], tail___}, attributesOf_, readings_] :=
  With[{listQ = KeyExistsQ[readings, k], attrs = attributesOf[steps]},
    With[{j = Replace[FirstPosition[attrs, Verbatim[Rule][If[listQ, rawKeyOf[readings[k]], k], _], {Length[attrs] + 1}, {1}, Heads -> False], {j_} :> j]},
      Join[If[listQ, tokenListKey[j], attributeKey[j]], Replace[{tail}, {{} -> {}, {t_} :> sequenceKey[2, t]}]]]];

(* The WL positions in tree of the elements at lists of element steps, each
   step the n-th element among the contents of the one before: an XMLObject's
   root is {2}, a list's n-th element is at its index among the items, and a
   bare element is {}. The element children of each element are found once. *)
wlPositions[tree_, stepsList_] :=
  Module[{kids = <||>, elementSlots, tops = If[ListQ[tree], Flatten[Position[tree, _XMLElement, {1}, Heads -> False]], {}]},
    elementSlots[p_] := Lookup[kids, Key[p], kids[p] = Flatten @ Position[If[p === {}, tree, Extract[tree, p]][[3]], _XMLElement, {1}, Heads -> False]];
    Function[steps,
      Fold[Join[#1, {3, elementSlots[#1][[#2]]}] &,
        Switch[tree,
          XMLObject[_][___], {2},
          _List, {tops[[First[steps]]]},
          _, {}],
        Rest[steps]]] /@ stepsList];

PackageExported[XMLPosition]
XMLPosition::usage = "XMLPosition[tree, pattern :> rhs] gives rhs for each result that XMLCases[tree, pattern :> rhs] gives, in the same order, with each name that counts replaced by its position in tree instead of its value. XMLPosition[tree, pattern] gives the positions of the elements that pattern matches. A position is a list of indices that count element children only, from the document: {} is the document, and an XMLObject's root element or a bare XMLElement tree is {1}. A position can end in 0 for a tag, Key[All] for the attribute list, Key[key] for an attribute value or a list key such as \"classList\", All for the contents, or m ;; n for a run of element children. A named path is given as upper ;; lower, the positions of its two ends. XMLExtract gives the parts of tree at positions. The \"AttributeReadings\" option adds readings to $AttributeReadings, as in XMLCases.";

Options[XMLPosition] = {"AttributeReadings" -> <||>};

XMLPosition[tree_, q : Except[_?(optionRuleQ[XMLPosition])], opts : OptionsPattern[]] :=
  withReadings[OptionValue["AttributeReadings"],
    treePositions[XMLPosition, tree, q]];

XMLPosition[args___] /; (countMessage[XMLPosition, {args}, {2, 2}]; False) := Null;

PackageExported[XMLExtract]
XMLExtract::usage = "XMLExtract[tree, pos] gives the part of tree at position pos, as XMLPosition gives positions. XMLExtract[tree, {pos1, pos2, ...}] gives a list of the parts at each pos. A run m ;; n gives the element children m to n as a sequence, and a gap n ;; n-1 gives Sequence[]. A named path upper ;; lower gives the list of the elements strictly between its two ends, outermost first. The \"AttributeReadings\" option adds readings to $AttributeReadings, for list keys such as \"classList\".";
XMLExtract::pos = "`1` is not a position in an XML tree. A position is {} for the document or a list of element-child indices, optionally followed by 0, Key[All], Key[key] (then, for a list key, a token index, run or gap), All, or a run m ;; n or gap n ;; n-1 of element children; a named path is upper ;; lower, where upper is {} or an element above the element lower.";
XMLExtract::nopos = "There is no position `1` in the tree.";

Options[XMLExtract] = {"AttributeReadings" -> <||>};

XMLExtract[tree_, pos : Except[_?(optionRuleQ[XMLExtract])], opts : OptionsPattern[]] :=
  withReadings[OptionValue["AttributeReadings"], extracted[tree, pos]];

XMLExtract[args___] /; (countMessage[XMLExtract, {args}, {2, 2}]; False) := Null;


(* The front end colours a call with a wrong argument count. *)
Scan[Function[f, SyntaxInformation[f] = {"ArgumentsPattern" -> {_, _, OptionsPattern[]}, "OptionNames" -> Keys[Options[f]]}],
  {XMLPosition, XMLExtract}];

(* =========================================================== *)
(* XMLExtract                                                   *)
(* =========================================================== *)

(* A list whose entries are all positions is several positions; any other
   list, {} included, is one. A path span is never a list, so the two cannot
   be confused. *)
extracted[tree_, pos_] :=
  Which[
    !validTreeQ[tree], messageTreeRefusal[XMLExtract, tree]; $Failed,
    True,
      With[{readings = readingsInForce[]},
        If[readings === $Failed, $Failed,
          Catch[
            If[positionsQ[pos], extractedAt[tree, readings, #] & /@ pos, extractedAt[tree, readings, pos]],
            $refusal]]]];

positionsQ[l_] := MatchQ[l, {(_List | Span[_List, _List]) ..}];

(* The value at {} is the input, and {e} for a bare element e; its contents
   are its top elements, with the text between them for a list. *)
documentValue[x_XMLElement] := {x};
documentValue[t_] := t;

elementKids[l_List] := Cases[l, _XMLElement];
elementKids[x_XMLElement] := Cases[x[[3]], _XMLElement];

(* A path span: the elements strictly between its ends, outermost first. *)
extractedAt[tree_, _, s : Span[upper_List, lower_List]] :=
  If[AllTrue[Join[upper, lower], elementStepQ] && Length[upper] < Length[lower] && Take[lower, Length[upper]] === upper,
    elementAt[tree, lower, s];
    elementAt[tree, Take[lower, #], s] & /@ Range[Length[upper] + 1, Length[lower] - 1],
    refuse[XMLExtract::pos, s]];

(* Element steps, then at most one terminal. *)
extractedAt[tree_, readings_, pos_List] :=
  With[{k = LengthWhile[pos, elementStepQ]},
    terminalAt[tree, readings, If[k == 0, None, elementAt[tree, Take[pos, k], pos]], Drop[pos, k], pos]];

extractedAt[_, _, pos_] := refuse[XMLExtract::pos, pos];

(* The element at element steps, or XMLExtract::nopos for whole, the position
   asked for. *)
elementAt[tree_, steps_, whole_] :=
  Fold[With[{kids = elementKids[#1]}, If[#2 <= Length[kids], kids[[#2]], refuse[XMLExtract::nopos, whole]]] &,
    topItems[tree], steps];

(* x is the element, or None for the document. *)
terminalAt[tree_, _, None, {}, _] := documentValue[tree];
terminalAt[tree_, _, None, {All}, _] := topItems[tree];
terminalAt[tree_, _, None, {s_Span}, whole_] := runOrGap[elementKids[topItems[tree]], s, whole];
terminalAt[_, _, x_XMLElement, {}, _] := x;
terminalAt[_, _, x_XMLElement, {0}, _] := x[[1]];
terminalAt[_, _, x_XMLElement, {Key[All]}, _] := x[[2]];
terminalAt[_, _, x_XMLElement, {All}, _] := x[[3]];
terminalAt[_, _, x_XMLElement, {s_Span}, whole_] := runOrGap[elementKids[x], s, whole];
(* A list key's token list, as the readings in force split its attribute;
   an absent attribute reads as "", as when matching (ADR 0011). *)
terminalAt[_, readings_, x_XMLElement, {Key[k_], tail___}, whole_] /; KeyExistsQ[readings, k] :=
  With[{tokens = splitterOf[readings[k]][attributeValue[x, rawKeyOf[readings[k]], ""]]},
    Replace[{tail}, {
      {} -> tokens,
      {i_Integer?Positive} :> If[i <= Length[tokens], tokens[[i]], refuse[XMLExtract::nopos, whole]],
      {s_Span} :> runOrGap[tokens, s, whole],
      _ :> refuse[XMLExtract::pos, whole]}]];
terminalAt[_, _, x_XMLElement, {Key[k : (_String | {_String, _String})]}, whole_] :=
  attributeValue[x, k, refuse[XMLExtract::nopos, whole]];
terminalAt[_, _, _, _, whole_] := refuse[XMLExtract::pos, whole];

SetAttributes[attributeValue, HoldRest];
attributeValue[x_, k_, absent_] := FirstCase[x[[2]], Verbatim[Rule][k, v_] :> v, absent];

(* A run m ;; n of items, or the gap n ;; n-1 before item n, as a sequence. *)
runOrGap[items_, s : Span[m_Integer?Positive, n_Integer], whole_] /; n >= m - 1 :=
  If[n <= Length[items], Sequence @@ items[[m ;; n]], refuse[XMLExtract::nopos, whole]];
runOrGap[_, _, whole_] := refuse[XMLExtract::pos, whole];
