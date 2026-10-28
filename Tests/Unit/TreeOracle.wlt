(* Single-result tree-pattern queries against the XPath oracle, on seeded
   random documents: each query's results equal the elements of the XPath
   node set, in document order. *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[FindFile["MaximilienTirard`HTMLPatterns`"]]], "Tests", "Support", "XPathOracle.wl"}]];

parentOf[l_] := XMLPattern[_, _, l];

$oracleCases = {
  {"//nav//a", XMLPattern["nav", _, Descendant[x : XMLPattern["a"]]] :> x},
  {"//nav[.//a]", XMLPattern["nav", _, Descendant[XMLPattern["a"]]]},
  {"//div/*[1]", XMLPattern["div", _, {x_, ___}] :> x},
  {"//div/*[last()]", XMLPattern["div", _, {___, x_}] :> x},
  {"//div/*[position() mod 2 = 1]", XMLPattern["div", _, {PatternSequence[_, _] ..., x_, ___}] :> x},
  {"//*/li[not(preceding-sibling::li)]", parentOf[{Except[XMLPattern["li"]] ..., x : XMLPattern["li"], ___}] :> x},
  {"//*/p[preceding-sibling::h2]", parentOf[{___, XMLPattern["h2"], ___, x : XMLPattern["p"], ___}] :> x},
  {"//*/p[following-sibling::*[1][self::a]]", parentOf[{___, x : XMLPattern["p"], XMLPattern["a"], ___}] :> x},
  {"//*/*[preceding-sibling::*[1][self::p]]", parentOf[{___, XMLPattern["p"], x_, ___}] :> x},
  {"//*/td[last()]", parentOf[{___, x : XMLPattern["td"], Except[XMLPattern["td"]] ...}] :> x},
  {"//ul//li//a", XMLPattern["ul", _, Descendant[XMLPattern["li", _, Descendant[x : XMLPattern["a"]]]]] :> x},
  {"//div[p][span]/a", XMLPattern["div", _, {___, XMLPattern["p"], ___}, {___, XMLPattern["span"], ___}, {___, x : XMLPattern["a"], ___}] :> x},
  {"//div/*/a", XMLPattern["div", _, Descendant[x : XMLPattern["a"], {2}]] :> x},
  {"//div/*/*/*", XMLPattern["div", _, Descendant[x : XMLPattern[_], {3}]] :> x},
  {"//div//*[a]", XMLPattern["div", _, Descendant[x : XMLPattern[_, _, {___, XMLPattern["a"], ___}]]] :> x},
  {"//nav[a and not(div)]", XMLPattern["nav", _, {___, XMLPattern["a"], ___}, {Except[XMLPattern["div"]] ...}]},
  {"//*[a][nav]/li", XMLPattern[_, _, Descendant[XMLPattern["a"], {1}], Descendant[XMLPattern["nav"], {1}], {___, x : XMLPattern["li"], ___}] :> x},
  {"//div/p | //nav/a", (XMLPattern["div", _, {___, x : XMLPattern["p"], ___}] | XMLPattern["nav", _, {___, x : XMLPattern["a"], ___}]) :> x},
  {"//li[count(*) = 2]", XMLPattern["li", _, {_, _}]},
  {"//p[not(*)]", XMLPattern["p", _, {}]},
  (* Context above an element: XMLDocument roots and path tests. *)
  {"//a[not(ancestor::nav)]", XMLDocument[Descendant[x : XMLPattern["a"]]?(NoneTrue[XMLMatchQ["nav"]])] :> x},
  {"//a[ancestor::nav and ancestor::li]", XMLDocument[Descendant[x : XMLPattern["a"]]?(AnyTrue[XMLMatchQ["nav"]][#] && AnyTrue[XMLMatchQ["li"]][#] &)] :> x},
  {"//p[count(ancestor::div) = 1]", XMLDocument[Descendant[x : XMLPattern["p"]]?(Count[#, _?(XMLMatchQ["div"])] == 1 &)] :> x},
  (* some div above the a with no ul between: a div below the nearest ul *)
  {"//a[ancestor::div and (not(ancestor::ul) or count(ancestor::div) > count(ancestor::ul[1]/ancestor::div))]", XMLPattern["div", _, Descendant[x : XMLPattern["a"]]?(NoneTrue[XMLMatchQ["ul"]])] :> x},
  {"//*[not(parent::*)]", XMLDocument[{x_}] :> x},
  {"/*/*/span", XMLDocument[Descendant[x : XMLPattern["span"], {3}]] :> x},
  {"//nav//a", XMLPattern["nav", _, Shortest@Descendant[x : XMLPattern["a"]]] :> x},
  (* the nearest and the outermost nav above an a *)
  {"//a/ancestor::nav[1]", n : XMLPattern["nav", _, Shortest@Descendant[XMLPattern["a"]]] :> n},
  {"//a/ancestor::nav[last()]", n : XMLPattern["nav", _, Longest@Descendant[XMLPattern["a"]]] :> n},
  {"//li/ancestor::div[span][1]", n : XMLPattern["div", _, {___, XMLPattern["span"], ___}, Shortest@Descendant[XMLPattern["li"]]] :> n}
};

$oracleInputs = oracleTrees[20261028, 12];

$oracleAnswers = xpathElements[#, $oracleCases[[All, 1]]] & /@ $oracleInputs;

TestCreate[
  Count[$oracleAnswers, _Association],
  Length[$oracleInputs],
  TestID -> "oracle-ran"
];

(* Most queries select something on these inputs, so agreement is not vacuous. *)
TestCreate[
  Count[Transpose[Values /@ $oracleAnswers], l_ /; Total[Length /@ l] > 0] >= Length[$oracleCases] - 2,
  True,
  TestID -> "oracle-nonvacuous"
];

Function[{case},
  TestCreate[
    MemoryConstrained[XMLCases[#, case[[2]]] & /@ $oracleInputs, 4*^9],
    Lookup[#, case[[1]]] & /@ $oracleAnswers,
    TestID -> "oracle " <> case[[1]]]] /@ $oracleCases;
