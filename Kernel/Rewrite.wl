(* ::Package:: *)
(* HTMLPatterns: rewriting a tree at positions, and XMLDeleteCases and XMLReplace over tree patterns *)

(* Used by XMLFunctions.wl *)
PackageScoped[treeDelete]

(* =========================================================== *)
(* Rewriting at positions (ADR 0025)                            *)
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

(* Edits go in position order, as positionOrdering gives it (Positions.wl). *)
rewritten[input_, edits_] :=
  Block[{$input = input, $nodes = <||>, $originalKids = <||>, $replaced = <||>, $allReplaced = <||>,
      $before = <||>, $after = <||>, $atEnd = <||>, $tokens = <||>, $originalTokens = <||>,
      $readings = readingsInForce[], $joiners = listKeyJoiners[]},
    If[$readings === $Failed, $Failed,
      Scan[rewriteAt[#[[1]], #[[2]]] &, Reverse[edits[[positionOrdering[edits[[All, 1]], original[#][[2]] &, $readings]]]]];
      assembled[]]];

(* ---- The original input ---- *)

inputContents[] := topItems[$input];

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
nodesOf[Splice[l_List]] := l;
nodesOf[l_List] := l;
nodesOf[x_] := {x};

(* ---- One rewrite ---- *)

(* f may Throw to $unchanged to leave the part as it is: it is called before
   anything is set. *)
rewriteAt[pos_, f_] :=
  With[{k = LengthWhile[pos, elementStepQ]},
    With[{steps = Take[pos, k]}, If[aliveQ[steps], Catch[rewriteTerminal[steps, Drop[pos, k], f], $unchanged]]]];

(* An element. *)
rewriteTerminal[steps_, {}, f_] /; steps =!= {} :=
  (opened[Most[steps]]; $replaced[steps] = nodesOf[f[current[steps]]]);

rewriteTerminal[steps_, {0}, f_] := $nodes[steps] = ReplacePart[opened[steps], 1 -> f[opened[steps][[1]]]];
rewriteTerminal[steps_, {Key[All]}, f_] := $nodes[steps] = ReplacePart[opened[steps], 2 -> f[opened[steps][[2]]]];

(* A list key's token list, or a token, run or gap of it. *)
rewriteTerminal[steps_, {Key[k_], tail___}, f_] /; KeyExistsQ[$readings, k] :=
  With[{raw = rawKeyOf[$readings[k]]},
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

splitTokens[steps_, k_] := splitterOf[$readings[k]][Lookup[opened[steps][[2]], Key[rawKeyOf[$readings[k]]], ""]];

currentTokens[steps_, k_] := If[KeyExistsQ[$tokens, {steps, k}], tokenValues[steps, k, $tokens[{steps, k}]], splitTokens[steps, k]];

tokenValues[steps_, k_, items_] := Replace[items, tokenRef[i_] :> $originalTokens[{steps, k}][[i]], {1}];

(* The tokens are written back through the reading at once, the attribute
   kept even when empty. *)
setTokens[steps_, k_, items_] := (
  $tokens[{steps, k}] = items;
  setAttribute[steps, rawKeyOf[$readings[k]], StringRiffle[tokenValues[steps, k, items], $joiners[k]]]);

(* =========================================================== *)
(* XMLDeleteCases over tree patterns                            *)
(*                                                              *)
(* The right-hand side is a name or a list of names, with an    *)
(* optional Condition; the union of the positions of the        *)
(* counted names over all results is deleted. A bare pattern    *)
(* deletes its pattern roots.                                   *)
(* =========================================================== *)

XMLDeleteCases::delrhs = "The right-hand side of `1` should be a name of the pattern, or a list of names, optionally with a condition (/;): XMLDeleteCases deletes what those names match, as in x : XMLPattern[\"a\"] :> x. Use :> so that the names are not evaluated.";
XMLDeleteCases::target = "`1` is the position of the document or of a tag, which cannot be deleted. Name an element, an attribute, a token, a run of children or the contents instead.";
XMLDeleteCases::pathtarget = "`1` is a named path, the elements between two others, which cannot be deleted. Name the elements to delete instead.";

treeDelete[tree_, q_] :=
  Catch[
    checkDeletion[q];
    With[{counted = treeCountedPositions[XMLDeleteCases, tree, q]},
      If[counted === $Failed, $Failed, deleted[tree, DeleteDuplicates[Join @@ counted]]]],
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
   a gap filled with nothing. A name with no position, one in an XMLElement
   pattern that binds part of a tag, an attribute value or an item, deletes
   nothing. The root of an XMLObject is kept. *)
deleted[tree_, counted_] :=
  Module[{ps = DeleteCases[counted, _Missing]},
    Replace[SelectFirst[ps, MatchQ[#, _Span] &], s_Span :> refuse[XMLDeleteCases::pathtarget, s]];
    Replace[SelectFirst[ps, MatchQ[#, {} | {__Integer?Positive, 0}] &], p_List :> refuse[XMLDeleteCases::target, p]];
    If[MatchQ[tree, XMLObject[_][___]] && MemberQ[ps, {1}], Message[XMLDeleteCases::root]; ps = DeleteCases[ps, {1}]];
    If[AllTrue[ps, MatchQ[{_Integer?Positive, __Integer?Positive}]],
      Delete[tree, wlPositions[tree, outermostPositions[ps]]],
      rewritten[tree, (# -> If[MatchQ[Last[#], Key[All] | All], {} &, Nothing &]) & /@ ps]]];

(* Elements below the top ones, deleted with Delete at their positions in
   the input: rewriting each through the opened nodes costs about 0.1 ms an
   element, five times the query that finds them. An element inside another
   deleted one goes with it. *)
outermostPositions[ps_] := With[{set = AssociationThread[ps -> True]}, Select[ps, NoneTrue[Range[Length[#] - 1], Function[k, KeyExistsQ[set, Take[#, k]]]] &]];


(* =========================================================== *)
(* XMLReplace over tree patterns                                *)
(*                                                              *)
(* A right-hand side that is a rule or a list of rules whose    *)
(* left sides are all names of the pattern, the targets form,  *)
(* replaces what those names match, and only they count; any   *)
(* other right-hand side replaces the pattern root, the root   *)
(* form, which counts only the root. A query is matched once,  *)
(* on the original input; rewritten then applies the           *)
(* replacements, each evaluated when its target is rewritten,  *)
(* with every name it uses read at its position in the tree    *)
(* rewritten so far. A list of queries gives each position the *)
(* replacement of the first that targets it.                   *)
(* =========================================================== *)

PackageExported[XMLReplace]
XMLReplace::usage = "XMLReplace[tree, pattern :> {x -> new, ...}] replaces what each name x of pattern matches by new, for every result of pattern in tree, and gives the rewritten tree. XMLReplace[tree, pattern :> new] replaces each match of pattern by new. XMLReplace[tree, {rule1, rule2, ...}] gives each place the replacement of the first rule that names it. A name can match an element, its tag, its attribute list, an attribute value, a list key's tokens, its contents, or a run or gap of its element children, and each takes a replacement of its own kind: an element takes an element, a string, Splice[list] or Nothing, and a gap takes the nodes to insert. Replacements are made inside out, contents before their container, and each new reads the names it uses from the tree as rewritten so far. The \"AttributeReadings\" option adds readings to $AttributeReadings, as in XMLCases.";
XMLReplace::bare = "`1` is a pattern with no replacement, which would replace each match by itself. Name what to replace and give its replacement, as in x : p :> {x -> new}, or replace the match itself, as in p :> new.";
XMLReplace::target = "`1` is the position of the document, which cannot be replaced. Name an element, a tag, an attribute, a token, a run or gap of children, or the contents instead.";
XMLReplace::pathtarget = "`1` is a named path, the elements between two others, which cannot be replaced. Name the elements to replace instead.";
XMLReplace::kind = "The replacement `2` for position `1` is not of a kind that position takes, and the position is left unchanged. An element takes an element, a string, Splice[list] or Nothing; a tag a string; an attribute list a list of rules; an attribute value a string or Nothing; a list key a list of strings; a token a string, and a run of tokens a list of strings; contents a list of nodes; a run of children Splice[list], a list or Nothing; a gap the nodes to insert.";
XMLReplace::conflict = "Position `1` is given different replacements by different results; the replacement of the first result is used.";
XMLReplace::stale = "The position `2` of `1` was removed by an earlier replacement, so `1` has its original value.";

Options[XMLReplace] = {"AttributeReadings" -> <||>};

XMLReplace[tree_, q : Except[_?(optionRuleQ[XMLReplace])], opts : OptionsPattern[]] :=
  withReadings[OptionValue["AttributeReadings"], treeReplace[tree, q]];

XMLReplace[args___] /; (countMessage[XMLReplace, {args}, {2, 2}]; False) := Null;

SyntaxInformation[XMLReplace] = {"ArgumentsPattern" -> {_, _, OptionsPattern[]}, "OptionNames" -> Keys[Options[XMLReplace]]};

treeReplace[tree_, q_] :=
  Catch[
    With[{qs = If[ListQ[q], q, {q}]},
      Scan[checkReplacement, qs];
      With[{edits = Join[<||>, Sequence @@ Reverse[replacementEdits[tree, #] & /@ qs]]},
        Replace[SelectFirst[Keys[edits], MatchQ[#, _Span] &], s_Span :> refuse[XMLReplace::pathtarget, s]];
        If[KeyExistsQ[edits, {}], refuse[XMLReplace::target, {}]];
        rewritten[tree, KeyValueMap[#1 -> replacer[#1, #2] &, edits]]]],
    $refusal];

checkReplacement[_Rule | _RuleDelayed] := Null;
checkReplacement[p_] := refuse[XMLReplace::bare, p];

(* For one query, position -> {Hold[replacement], names, solution}: what
   replaces the position and the matches of the names it may use, from the
   first result, in result order, that targets it. A later result whose
   replacement differs, by its code or by the positions of the names it
   uses, is XMLReplace::conflict. A repeated name targets every position it
   is bound at, as treeCountedPositions gives them. *)
replacementEdits[tree_, q : (Rule | RuleDelayed)[lhs_, _]] :=
  Module[{r, names = namesIn[Hold[lhs]], rhs = heldRHS[q], targets, query = q, sols, edits = <||>, ids = <||>},
    targets = targetRules[unguarded[rhs], names];
    If[targets === None,
      targets = {{Hold[r], unguarded[rhs]}};
      (* Pattern @@ and Apply, so that Module renames r here too, and the
         right-hand side stays held. *)
      query = RuleDelayed @@ Join[Hold @@ {Pattern @@ {r, lhs}}, rhs];
      names = Prepend[names, Hold[r]]];
    sols = treeSolutions[XMLReplace, tree, query, DeleteDuplicates[targets[[All, 1]]]];
    If[sols === $Failed, Throw[$Failed, $refusal]];
    Do[
      With[{b = Lookup[sol, Key[First[t]], None], id = replacementId[Last[t], sol]},
        If[b =!= None,
          Scan[
            Which[
              !KeyExistsQ[edits, #], edits[#] = {Last[t], names, sol}; ids[#] = id,
              ids[#] =!= id, Message[XMLReplace::conflict, #]] &,
            DeleteCases[First[b], _Missing]]]],
      {sol, sols}, {t, targets}];
    edits];

(* A query's right-hand side, held. A Rule's was evaluated when the query was
   given, as in Cases; a Condition in its value is part of it, not a test. *)
heldRHS[q_RuleDelayed] := Extract[q, {2}, Hold];
heldRHS[q_Rule] := Replace[Extract[q, {2}, Hold], Hold[c_Condition] :> Hold[Identity[c]]];

(* Without a Condition at the top, which the match tests. *)
unguarded[held_] := Replace[held, Hold[Verbatim[Condition][b_, _]] :> Hold[b]];

(* {Hold[name], Hold[replacement]} for each rule of the targets form, or None
   when the right-hand side is not one. *)
targetRules[held_, names_] :=
  With[{targets = Replace[Replace[held, {Hold[l_List] :> Thread[Hold[l]], h_ :> {h}}],
      {Hold[(Rule | RuleDelayed)[s_Symbol, v_]] /; MemberQ[names, Hold[s]] :> {Hold[s], Hold[v]}, _ -> None}, {1}]},
    If[targets =!= {} && FreeQ[targets, None, {1}], targets, None]];

replacementId[code_, sol_] := code /. KeyValueMap[Replace[#1, Hold[s_] :> (HoldPattern[s] -> boundAt[First[#2]])] &, sol];

(* What rewritten applies at pos: the replacement evaluated with each name it
   uses read from the tree rewritten so far, or the part left unchanged after
   XMLReplace::kind. A name that is not bound, in an Alternatives branch that
   did not match, is Sequence[]. *)
replacer[pos_, {code_, names_, sol_}] := Function[Null, replacement[pos, code, names, sol]];

replacement[pos_, code_, names_, sol_] :=
  With[{held = code /. (Replace[#, Hold[s_] :> (HoldPattern[s] -> Replace[nameValue[#, Lookup[sol, Key[#], None], pos], {{v_} :> v, l_ :> Sequence @@ l}])] & /@
      Select[names, !FreeQ[code, Replace[#, Hold[s_] :> HoldPattern[s]]] &])},
    With[{v = If[Length[held] == 1, ReleaseHold[held], $several[List @@ held]]},
      If[replacementKindQ[pos, v], v,
        Message[XMLReplace::kind, pos, Replace[v, $several[l_] :> HoldForm[Sequence @@ l]]]; Throw[Null, $unchanged]]]];

(* What a name splices in at position pos: its value at its position now, or,
   when an earlier rewrite removed that position, its original value, with
   XMLReplace::stale. A repeated name with several positions, its values
   equal when matched, reads the one being rewritten, or else its first; a
   name with no position, one in an XMLElement pattern that binds part of a
   tag, an attribute value or an item, its original value. *)
nameValue[_, None, _] := {};
nameValue[name_, {ps_, vals_}, pos_] :=
  With[{p = If[MemberQ[ps, pos], pos, First[ps]]},
    If[MatchQ[p, _Missing], vals,
      Replace[valueAt[p], $stale :> (Message[XMLReplace::stale, Replace[name, Hold[s_] :> HoldForm[s]], p]; vals)]]];

(* ---- The tree rewritten so far ---- *)

(* The value at a position, as the list of what a name there splices in, or
   $stale when an earlier rewrite removed it. An element replaced by one
   element is that element; replaced by anything else, or inside a part that
   was replaced, it is removed. *)
valueAt[{}] := {assembled[]};
valueAt[Span[upper_, lower_]] :=
  With[{es = elementNow /@ (Take[lower, #] & /@ Range[Length[upper] + 1, Length[lower] - 1])},
    If[MemberQ[es, $stale], $stale, {es}]];
valueAt[pos_] := With[{k = LengthWhile[pos, elementStepQ]}, valueIn[Take[pos, k], Drop[pos, k]]];

valueIn[steps_, {}] := Replace[elementNow[steps], x_XMLElement :> {x}];
valueIn[steps_, _] /; !aliveQ[steps] := $stale;
valueIn[steps_, {0}] := {currentNode[steps][[1]]};
valueIn[steps_, {Key[All]}] := {currentNode[steps][[2]]};
valueIn[steps_, {Key[k_], tail___}] /; KeyExistsQ[$readings, k] :=
  If[MemberQ[currentNode[steps][[2]], Verbatim[Rule][rawKeyOf[$readings[k]], _]], tokensAt[steps, k, tail], $stale];
valueIn[steps_, {Key[k_]}] := Replace[Lookup[currentNode[steps][[2]], Key[k], $stale], v : Except[$stale] :> {v}];
valueIn[steps_, {All}] := {currentContents[steps]};
valueIn[steps_, {Span[m_, n_]}] :=
  With[{es = elementNow[Append[steps, #]] & /@ Range[m, n]}, If[MemberQ[es, $stale], $stale, es]];

elementNow[steps_] :=
  If[aliveQ[Most[steps]] && !KeyExistsQ[$allReplaced, Most[steps]],
    Replace[Lookup[$replaced, Key[steps], {current[steps]}], {{x_XMLElement} :> x, _ -> $stale}],
    $stale];

(* The tag and attributes of the element at steps, as rewritten so far. *)
currentNode[steps_] := Lookup[$nodes, Key[steps], original[steps]];

(* A list key's tokens, or a token, run or gap of them by original index; a
   token that a rewrite replaced is removed. *)
tokensAt[steps_, k_] := {currentTokens[steps, k]};
tokensAt[steps_, k_, tail_] :=
  With[{items = openedTokens[steps, k], is = Replace[tail, {i_Integer :> {i}, Span[m_, n_] :> Range[m, n]}]},
    If[SubsetQ[items, tokenRef /@ is], $originalTokens[{steps, k}][[is]], $stale]];

(* ---- What each kind of position takes ---- *)

$node = _XMLElement | _String | XMLObject[_][___];

replacementKindQ[pos_, v_] := With[{k = LengthWhile[pos, elementStepQ]}, kindQ[Take[pos, k], Drop[pos, k], v]];

(* An XMLObject's root element stays an element. *)
kindQ[{1}, {}, v_] /; MatchQ[$input, XMLObject[_][___]] := MatchQ[v, _XMLElement];
kindQ[_, {}, v_] := MatchQ[v, $node | Splice[{$node ...}] | Nothing];
kindQ[_, {0}, v_] := StringQ[v];
kindQ[_, {Key[All]}, v_] := MatchQ[v, {((_String | {_String, _String}) -> _String) ...}];
kindQ[_, {Key[k_]}, v_] /; KeyExistsQ[$readings, k] := MatchQ[v, {___String}];
kindQ[_, {Key[_]}, v_] := MatchQ[v, _String | Nothing];
kindQ[_, {Key[_], Span[m_, n_]}, v_] /; n == m - 1 := MatchQ[v, _String | {___String}];
kindQ[_, {Key[_], _Span}, v_] := MatchQ[v, {___String}];
kindQ[_, {Key[_], _Integer}, v_] := StringQ[v];
kindQ[_, {All}, v_] := MatchQ[v, {$node ...}];
kindQ[_, {Span[m_, n_]}, v_] /; n == m - 1 := MatchQ[v, $node | {$node ...} | Splice[{$node ...}]];
kindQ[_, {_Span}, v_] := MatchQ[v, Splice[{$node ...}] | {$node ...} | Nothing];
