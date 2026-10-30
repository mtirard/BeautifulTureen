(* The index of the last document queried is kept for the next query of it.
   An element test on other, small inputs in between does not replace it.
   Times on a 2026 laptop: the query below takes about 45 ms on a document
   it must index again and 7 ms on one whose index is kept. The bound
   compares the two, so it holds on a slower machine. *)

$cacheDoc = ImportString[
  "<div>" <> StringJoin @ Table["<p class='a'><b>t</b></p>", {5000}] <> "<span>z</span></div>",
  {"HTML", "XMLObject"}];
$cacheSmall = XMLElement["p", {"class" -> "a"}, {XMLElement["b", {}, {"t"}]}];

(* The least of three times of XMLCases on the document, each after f[]. *)
cacheTime[f_] := Min @ Table[f[]; First @ AbsoluteTiming[XMLCases[$cacheDoc, XMLPattern["span"]]], 3];

TestCreate[
  With[{
      fresh = cacheTime[XMLCases[XMLElement["div", {}, {XMLElement["p", {}, {}]}], "p"] &],
      tested = cacheTime[(XMLMatchQ[$cacheSmall, XMLPattern["p"][{XMLPattern["b"]}]];
        Select[{$cacheSmall, $cacheSmall}, XMLMatchQ[XMLPattern["p"][{XMLPattern["b"]}]]];
        XMLFreeQ[$cacheSmall, XMLPattern["b"][{___}]]) &]},
    tested < fresh / 2],
  True,
  TestID -> "perf-element-tests-keep-document-index"
];

(* What a query computes from the index for every element, as which elements
   pass its tag and attribute test, is kept with the index, so the same query
   again does not compute it. Each p has its own id, so the test is run on
   each of 5,000 elements: about 10 ms, against about 1 ms when it is kept.
   The bound compares the query with one whose test is new each time, which
   costs as much the first time; element tests on small inputs between two
   runs do not replace what is kept. *)
$vectorDoc = ImportString[
  "<div>" <> StringJoin @ Table["<p class='a' id='p" <> ToString[k] <> "'><b>t</b></p>", {k, 5000}] <> "</div>",
  {"HTML", "XMLObject"}];

vectorTime[q_] := First @ AbsoluteTiming[XMLCases[$vectorDoc, q]];

TestCreate[
  With[{
      fresh = Min @ Table[vectorTime[XMLPattern["p", "class" -> "y" <> ToString[k]]], {k, 3}],
      same = Min @ Table[
        vectorTime[XMLPattern["p", "class" -> "y"]];
        Select[{$cacheSmall, $cacheSmall}, XMLMatchQ[XMLPattern["p"][{XMLPattern["b"]}]]];
        vectorTime[XMLPattern["p", "class" -> "y"]], 3]},
    same < fresh / 3],
  True,
  TestID -> "perf-same-query-keeps-element-tests"
];
