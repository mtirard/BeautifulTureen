(* The compiled query says how it runs (ADR 0020): the two-step matching
   rewrite, the tuple pattern and test of each chain, and whether its stages
   decide are built when the query is compiled, and running it builds none of
   them. These tests reach inside, as no public function keeps a compiled query:
   each query is compiled once, and the calls of the rewrite (solvable) are
   counted while the compiled query runs several times, under each runner.
   Every result is checked against the public function, so that the count is
   not of a run that did nothing. *)

$compiledTree = XMLElement["body", {}, {
  XMLElement["div", {"class" -> "c3", "href" -> "xay", "data-id" -> "a"}, {XMLElement["p", {}, {"1"}]}],
  XMLElement["div", {"class" -> "c1"}, {XMLElement["span", {}, {"2"}]}],
  XMLElement["div", {"class" -> "c3"}, {XMLElement["p", {"href" -> "b"}, {"3"}]}]}];

(* A two-step Condition (a later name), a Condition on a combinator, a name at
   two stages, a rule body with a Condition, alternatives of chains, and a list
   stage with a context entry. *)
$compiledQueries = {
  XMLPattern["div", {"href" -> h_, "data-id" -> i_}] /; StringContainsQ[h, i],
  Child[XMLPattern["body"], XMLPattern["div", {"href" -> h_, "data-id" -> i_}] /; StringContainsQ[h, i]],
  Child[XMLPattern["div"], XMLPattern["p"]] /; True,
  Child[d : XMLPattern["div"], XMLPattern["p"]] :> (Length[d[[3]]] /; True),
  Child[XMLPattern["div"], XMLPattern["p"]] | Child[XMLPattern["div"], XMLPattern["span"]],
  (Child[XMLPattern["div"], p : XMLPattern["p"]] | Child[XMLPattern["div"], p : XMLPattern["span"]]) :> p[[3]],
  Child[XMLPattern["body"], {___, Child["div", "p"], ___, "div.c3", ___}]};

SetAttributes[withRewriteCount, HoldFirst];
withRewriteCount[expr_] :=
  Module[{n = 0},
    Internal`InheritedBlock[{MaximilienTirard`BeautifulTureen`Private`solvable},
      PrependTo[DownValues[MaximilienTirard`BeautifulTureen`Private`solvable],
        HoldPattern[MaximilienTirard`BeautifulTureen`Private`solvable[_]] /; (n++; False) :> Null];
      {expr, n}]];

TestCreate[
  Module[{compiled, runs},
    compiled = MaximilienTirard`BeautifulTureen`Private`compileQuery[#, XMLCases] & /@ $compiledQueries;
    runs = withRewriteCount @ Table[
      MapThread[
        {MaximilienTirard`BeautifulTureen`Private`queryCases[#2, $compiledTree, Infinity],
         MaximilienTirard`BeautifulTureen`Private`queryFirst[#2, $compiledTree, None],
         If[MatchQ[#1, _RuleDelayed], None, MaximilienTirard`BeautifulTureen`Private`queryDelete[#2, $compiledTree]]} &,
        {$compiledQueries, compiled}],
      3];
    {Last[runs],
     First[runs] === ConstantArray[
       {XMLCases[$compiledTree, #], XMLFirstCase[$compiledTree, #, None],
        If[MatchQ[#, _RuleDelayed], None, XMLDeleteCases[$compiledTree, #]]} & /@ $compiledQueries, 3],
     FreeQ[First[runs], $Failed] && !FreeQ[First[runs], XMLElement]}],
  {0, True, True},
  TestID -> "compiled-query-runs-without-rewriting"
];

(* The per-element matcher behind XMLMatchQ, from a query compiled once. *)
TestCreate[
  With[{c = MaximilienTirard`BeautifulTureen`Private`compileQuery[First[$compiledQueries], XMLMatchQ]},
    withRewriteCount[
      MaximilienTirard`BeautifulTureen`Private`elementMatcher[c] /@ Table[$compiledTree[[3, 1]], 3]]],
  {{True, True, True}, 0},
  TestID -> "compiled-query-element-matcher-without-rewriting"
];
