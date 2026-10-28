(* ::Package:: *)
(* HTMLPatterns: XMLPosition and XMLExtract *)

(* =========================================================== *)
(* Positions (spec sections 4 and 6)                            *)
(*                                                              *)
(* A position counts element children only, from the document:  *)
(* {} is the document, {i1, ..., ik} an element, and at most one *)
(* terminal step may follow: 0 the tag, Key[All] the attribute   *)
(* map, Key[k] an attribute value or a list key's token list,    *)
(* then a token, run or gap of that list; All the contents; a    *)
(* run m ;; n or gap n ;; n-1 of element children. A named path  *)
(* is the span upper ;; lower of its two ends.                   *)
(* =========================================================== *)

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

Scan[Function[h,
    MessageName[h, "badtree"] = "The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head `1`.";
    MessageName[h, "badmember"] = "A list given as the first argument should hold only XMLElement expressions and strings. The member at position `1` has head `2`."],
  {XMLPosition, XMLExtract}];
XMLPosition::exceptname = "The name `1` is bound inside Except, which matches only where its pattern does not, so it has no value in the right-hand side. A name inside Except can be used only by tests inside that Except.";
XMLPosition::text = "The name `1` binds text inside an XMLElement pattern, and text has no position, so the name cannot be a result. Name the element that holds the text instead, or use the name only in a test.";
XMLPosition::blank = "`1` is a blank, which is not an XML pattern. Any element is XMLPattern[_]. An XML pattern matches elements only; for the text inside an element, use HTMLTextContent or HTMLInnerText.";

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
documentContents[XMLObject["Document"][_, r_, _]] := {r};
documentContents[t_] := Flatten[{t}];

elementKids[l_List] := Cases[l, _XMLElement];
elementKids[x_XMLElement] := Cases[x[[3]], _XMLElement];

positionQ[i_] := IntegerQ[i] && i > 0;

(* A path span: the elements strictly between its ends, outermost first. *)
extractedAt[tree_, _, s : Span[upper_List, lower_List]] :=
  If[AllTrue[Join[upper, lower], positionQ] && Length[upper] < Length[lower] && Take[lower, Length[upper]] === upper,
    elementAt[tree, lower, s];
    elementAt[tree, Take[lower, #], s] & /@ Range[Length[upper] + 1, Length[lower] - 1],
    refuse[XMLExtract::pos, s]];

(* Element steps, then at most one terminal. *)
extractedAt[tree_, readings_, pos_List] :=
  With[{k = LengthWhile[pos, positionQ]},
    terminalAt[tree, readings, If[k == 0, None, elementAt[tree, Take[pos, k], pos]], Drop[pos, k], pos]];

extractedAt[_, _, pos_] := refuse[XMLExtract::pos, pos];

(* The element at element steps, or XMLExtract::nopos for whole, the position
   asked for. *)
elementAt[tree_, steps_, whole_] :=
  Fold[With[{kids = elementKids[#1]}, If[#2 <= Length[kids], kids[[#2]], refuse[XMLExtract::nopos, whole]]] &,
    documentContents[tree], steps];

(* x is the element, or None for the document. *)
terminalAt[tree_, _, None, {}, _] := documentValue[tree];
terminalAt[tree_, _, None, {All}, _] := documentContents[tree];
terminalAt[tree_, _, None, {s_Span}, whole_] := runOrGap[elementKids[documentContents[tree]], s, whole];
terminalAt[_, _, x_XMLElement, {}, _] := x;
terminalAt[_, _, x_XMLElement, {0}, _] := x[[1]];
terminalAt[_, _, x_XMLElement, {Key[All]}, _] := x[[2]];
terminalAt[_, _, x_XMLElement, {All}, _] := x[[3]];
terminalAt[_, _, x_XMLElement, {s_Span}, whole_] := runOrGap[elementKids[x], s, whole];
(* A list key's token list, as the readings in force split its attribute;
   an absent attribute reads as "", as when matching (ADR 0011). *)
terminalAt[_, readings_, x_XMLElement, {Key[k_], tail___}, whole_] /; KeyExistsQ[readings, k] :=
  With[{tokens = readings[k][[2]][attributeValue[x, readings[k][[1]], ""]]},
    Replace[{tail}, {
      {} -> tokens,
      {i_?positionQ} :> If[i <= Length[tokens], tokens[[i]], refuse[XMLExtract::nopos, whole]],
      {s_Span} :> runOrGap[tokens, s, whole],
      _ :> refuse[XMLExtract::pos, whole]}]];
terminalAt[_, _, x_XMLElement, {Key[k : (_String | {_String, _String})]}, whole_] :=
  attributeValue[x, k, refuse[XMLExtract::nopos, whole]];
terminalAt[_, _, _, _, whole_] := refuse[XMLExtract::pos, whole];

SetAttributes[attributeValue, HoldRest];
attributeValue[x_, k_, absent_] := FirstCase[x[[2]], Verbatim[Rule][k, v_] :> v, absent];

(* A run m ;; n of items, or the gap n ;; n-1 before item n, as a sequence. *)
runOrGap[items_, s : Span[m_?positionQ, n_Integer], whole_] /; n >= m - 1 :=
  If[n <= Length[items], Sequence @@ items[[m ;; n]], refuse[XMLExtract::nopos, whole]];
runOrGap[_, _, whole_] := refuse[XMLExtract::pos, whole];
