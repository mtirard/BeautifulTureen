(* ::Package:: *)
(* HTMLPatterns: running a compiled query, the plain runners and the position helpers *)

(* Used by DisplayRoles.wl *)
PackageScoped[elementQuery]

(* Used by Query/Chains.wl *)
PackageScoped[firstMatchPositions]
PackageScoped[positionsInOrder]

(* Used by Query/Compiler.wl *)
PackageScoped[plainQuery]

(* Used by Tree.wl *)
PackageScoped[queryPositions]

(* Used by XMLFunctions.wl *)
PackageScoped[queryCases]
PackageScoped[queryFirst]
PackageScoped[queryDelete]
PackageScoped[elementMatcher]

(* =========================================================== *)
(* Running a compiled query                                     *)
(*                                                              *)
(* The operations the XML* functions are: each takes a compiled *)
(* query (or $Failed, having messaged) and a tree, refuses what *)
(* it cannot run under the query's head, and gives the elements *)
(* as they are in the tree. elementMatcher instead gives a      *)
(* function that tests one element.                            *)
(* =========================================================== *)

(* At most the first n of the elements, in document order. *)
queryCases[$Failed, _, _] := $Failed;
queryCases[c_, tree_, n_] :=
  If[treeRefusedQ[c, tree], $Failed, runCompiled[runnerOf[c, unionCases, chainCases, casesC], tree, c, n]];

queryFirst[$Failed, _, _] := $Failed;
queryFirst[c_, tree_, default_] :=
  If[treeRefusedQ[c, tree], $Failed, runCompiled[runnerOf[c, unionFirst, chainFirst, firstC], tree, c, default]];

(* A rule has nothing to delete with. *)
queryDelete[$Failed, _] := $Failed;
queryDelete[c_, tree_] :=
  With[{h = c["Head"]},
    Which[
      c["Body"] =!= None, Message[MessageName[h, "badpat"], c["Query"]]; $Failed,
      treeRefusedQ[c, tree], $Failed,
      True, runCompiled[runnerOf[c, unionDelete, chainDelete, deleteC], tree, c]]];

(* The sites the query selects, at most the first n, in document order: the
   positions in the tree of the elements queryCases gives, a rule's values
   aside. Equal elements at two sites are two sites, so these are not found
   from the elements. Materialising moves no element, so the positions in the
   materialised tree are positions in the tree. *)
queryPositions[$Failed, _, _] := $Failed;
queryPositions[c_, tree_, n_] :=
  If[treeRefusedQ[c, tree], $Failed, runCompiled[runnerOf[c, unionPositions, chainPositions, plainPositions], tree, c, n]];

(* A query of alternatives holding a combinator runs as their chains, any
   other combinator as one chain. *)
runnerOf[c_, onUnion_, onChain_, onPlain_] := Which[unionQ[c], onUnion, chainQ[c], onChain, True, onPlain];

(* A function that tests one element, or $Failed if the query is refused. Only
   the element itself is materialised: its children cannot be reached. *)
elementMatcher[$Failed] := $Failed;
elementMatcher[c_] :=
  With[{h = c["Head"]},
    Which[
      elementQuery[c, c["Query"], h, "combinator"] === $Failed, $Failed,
      c["Body"] =!= None, Message[MessageName[h, "badpat"], c["Query"]]; $Failed,
      True, With[{p = c["Plain"], r = c["Readings"]},
        If[r === {}, MatchQ[p], Function[el, MatchQ[materialise[el, r, {0}], p]]]]]];

treeRefusedQ[c_, tree_] :=
  !validTreeQ[tree] && (messageTreeRefusal[c["Head"], tree]; True);

(* A query tested on one element at a time takes no links: a combinator is
   refused under tag, and a combinator with a Condition under condcombinator.
   q is the query as written; a CSS selector string has no Condition of the
   caller's, whatever its translation holds. *)
elementQuery[$Failed, _, _, _] := $Failed;
elementQuery[c_, q_, head_, tag_] :=
  With[{h = head},
    Which[
      !unionQ[c] && c["Links"] === {}, c,
      AllTrue[alternativesOf[c], #["Conditions"] === {} &] || StringQ[q], Message[MessageName[h, tag], q]; $Failed,
      True, Message[MessageName[h, "condcombinator"], patternBase[q]]; $Failed]];

(* Materialise once per query, over the union of the list keys all its stages
   name; undo it once, at the output. A chain runner is given the normal form,
   a plain runner the pattern or rule it runs. *)
runCompiled[run_, tree_, q_, rest___] :=
  With[{p = Lookup[q, "Plain", q]},
    Block[{$kids = <||>, $contextMemo = <||>, $contexts = q["ContextEntries"]},
      If[q["Readings"] === {}, run[tree, p, rest],
        unmaterialised @ run[materialise[tree, q["Readings"]], p, rest]]]];

(* The pattern a plain query runs, or its rule, in its two-step form. *)
plainQuery[q_] :=
  solvable @ Replace[q["Body"], {None -> First[q["Stages"]],
    body_Hold :> RuleDelayed @@ Join[Hold @@ {First[q["Stages"]]}, body]}];

(* =========================================================== *)
(* Plain runners of XMLCases, XMLFirstCase and XMLDeleteCases  *)
(* and the position helpers                                     *)
(* =========================================================== *)

(* Base: a pattern, a Condition, or a rule over either, in document order. Cases
   and Position visit an element after the elements nested in it, so the
   positions of the matches are put in document order; a rule is then applied
   to the matched elements in that order, its body evaluated once for each it
   gives a value for, up to n. A Condition in the body can reject a match, so
   then every match is a candidate. *)
casesC[tree_, r : Verbatim[RuleDelayed][lhs_, _], n_] :=
  Cases[If[bodyConditionQ[Extract[r, {2}, Hold]], matchesInOrder[tree, lhs], firstMatches[tree, lhs, n]],
    r, {1}, n];
casesC[tree_, pat_, n_] := firstMatches[tree, pat, n];

(* The sites casesC takes its elements from: those of a rule's left-hand side,
   less those its body rejects, the body evaluated as casesC evaluates it. *)
plainPositions[tree_, r : Verbatim[RuleDelayed][lhs_, _], n_] /; bodyConditionQ[Extract[r, {2}, Hold]] :=
  Select[positionsInOrder[tree, lhs], Replace[Extract[tree, #], {r, _ :> $unmatched}] =!= $unmatched &, n];
plainPositions[tree_, Verbatim[RuleDelayed][lhs_, _], n_] := plainPositions[tree, lhs, n];
plainPositions[tree_, pat_, Infinity] := positionsInOrder[tree, pat];
plainPositions[tree_, pat_, n_] := firstMatchPositions[tree, pat, n];

(* The first n elements of tree, below its root, that match pat, in document
   order, the search stopping early. *)
firstMatches[tree_, pat_, Infinity] := matchesInOrder[tree, pat];
firstMatches[tree_, pat_, n_] := Extract[tree, firstMatchPositions[tree, pat, n]];

(* Position stops at the nth match in Cases order, which visits an element
   after the elements nested in it. A match earlier in document order that it
   has not visited is visited after one it has, so it is an element that one is
   nested in: the first n in document order are among the matches found and the
   matches on the way down to them. Each of these is tested once. *)
firstMatchPositions[tree_, pat_, n_] :=
  With[{ps = Position[tree, pat, Infinity, n, Heads -> False]},
    Take[#[[documentOrdering[#]]], UpTo[n]] & @ Join[ps, Select[
      Complement[Join @@ (Table[Take[#, k], {k, Length[#] - 1}] &) /@ ps, ps],
      MatchQ[Extract[tree, #], pat] &]]];

(* The elements of tree, below its root, that match pat, in document order.
   Extract reads {} as the whole tree, not as no positions. *)
matchesInOrder[tree_, pat_] :=
  Replace[positionsInOrder[tree, pat], {{} -> {}, ps_ :> Extract[tree, ps]}];

(* The positions of those elements. *)
positionsInOrder[tree_, pat_] :=
  Replace[Position[tree, pat, Infinity, Heads -> False], {{} -> {}, ps_ :> fromCasesOrder[ps]}];

(* Positions in Cases order, as Position gives them, put in document order.
   Cases visits an element right after the elements nested in it, so the
   matches nested in a match m come as one block right before it; moving m to
   the start of its block gives document order. So the positions are ordered
   by the start of their block, and at one start the outer, the later in Cases
   order, first. A match with others nested in it is one right after a position
   below it; without such a match the order is already document order. A sort
   of the padded positions would cost their depth for every match. *)
fromCasesOrder[ps_] :=
  With[{outer = 1 + Select[Pick[Range[Length[ps] - 1], UnitStep[Differences[Length /@ ps]], 0],
      belowQ[ps[[#]], ps[[# + 1]]] &]},
    If[outer === {}, ps,
      Module[{starts = Range[Length[ps]]},
        starts[[outer]] = blockStart[ps, #] & /@ outer;
        ps[[Ordering @ Transpose[{starts, -Range[Length[ps]]}]]]]]];

belowQ[p_, q_] := Length[p] > Length[q] && Take[p, Length[q]] === q;

(* The first position of the block of matches nested in the match at i: the
   positions before it that are below it end right before it. A binary search,
   as whether a position is below it changes once, from False to True. *)
blockStart[ps_, i_] :=
  Module[{lo = 1, hi = i - 1, mid},
    While[lo < hi,
      mid = Quotient[lo + hi, 2];
      If[belowQ[ps[[mid]], ps[[i]]], hi = mid, lo = mid + 1]];
    lo];

(* Base: the first match in document order, the search stopping early. A rule's
   body is evaluated for that match only, unless a Condition on the body
   rejects it and the search goes on. *)
firstC[tree_, r : Verbatim[RuleDelayed][lhs_, _], default_] :=
  Replace[firstMatchPosition[tree, lhs], {
    None -> default,
    p_ :> Replace[Extract[tree, p], {r,
      _ :> FirstCase[Drop[matchesInOrder[tree, lhs], UpTo[1]], r, default, {1}]}]}];
firstC[tree_, pat_, default_] :=
  Replace[firstMatchPosition[tree, pat], {None -> default, p_ :> Extract[tree, p]}];

(* The first match in document order, or None. *)
firstMatchPosition[tree_, pat_] :=
  Replace[firstMatchPositions[tree, pat, 1], {{p_} :> p, {} -> None}];

(* Base: a pattern or a Condition *)
deleteC[tree : XMLObject["Document"][_, root_, _], pat_] /; MatchQ[root, pat] :=
  (Message[XMLDeleteCases::root]; ReplacePart[tree, 2 -> DeleteCases[root, pat, Infinity]]);
deleteC[tree_, pat_] := DeleteCases[tree, pat, Infinity];
