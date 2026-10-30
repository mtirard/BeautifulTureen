(* A Descendant constraint at each element tried as the pattern root. The
   bound catches a return to reading the whole subtree below each element,
   which costs the depth times the elements when the elements nest and do
   not match, so outermost-match pruning never applies; not a benchmark. *)

(* 100 nested div, each with 20 span children, and no table. *)
$nestedDivs = XMLElement["body", {}, {
  Nest[XMLElement["div", {}, Append[Table[XMLElement["span", {}, {"x"}], 20], #]] &, XMLElement["p", {}, {}], 100]}];

(* About 45 ms on a 2026 laptop, most of it indexing; 120 ms reading each
   subtree. *)
TestCreate[
  Length @ XMLCases[$nestedDivs, "div"[Descendant["table"]]],
  0,
  TimeConstraint -> 0.08,
  TestID -> "perf-descendant-100-nested-non-matching"
];
