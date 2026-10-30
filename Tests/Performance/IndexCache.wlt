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
