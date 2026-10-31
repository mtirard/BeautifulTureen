(* Queries with many results on a page of about 15,000 elements, which the
   query engine matches at every element at once, as columns of integers.
   Times on a 2026 laptop for the first run of each query, its index kept:
   the query engine's, then 4.0.0's, which matched each element in turn.
   The bounds are about three times the first, to catch a return to
   matching element by element, not to benchmark. *)

(* 400 sections, each a div holding three p of four links, a ul of six li
   and a table of three rows. *)
$largePage = ImportString[
  "<body>" <> StringJoin @ Table[
    "<div class='s'>" <>
      StringJoin @ Table["<p>" <> StringJoin @ Table["<a href='/p" <> ToString[i] <> "-" <> ToString[j] <> "-" <> ToString[k] <> "'>x</a>", {k, 4}] <> "</p>", {j, 3}] <>
      "<ul>" <> StringJoin @ Table["<li>" <> ToString[k] <> "</li>", {k, 6}] <> "</ul>" <>
      "<table>" <> StringJoin @ Table["<tr><th>h</th><td><time datetime='2026-0" <> ToString[k] <> "'>d</time></td><td>v</td></tr>", {k, 3}] <> "</table>" <>
    "</div>", {i, 400}] <> "</body>",
  {"HTML", "XMLObject"}];

(* Indexed once, before the tests. *)
XMLCases[$largePage, "zzz"];

(* 17 ms; 113 ms. *)
TestCreate[
  Length @ XMLCases[$largePage, "div a"],
  4800,
  TimeConstraint -> 0.06,
  TestID -> "perf-large-page-selector-descendants"
];

(* 21 ms; 327 ms. *)
TestCreate[
  Length @ XMLCases[$largePage, "div"[Descendant[p : "p"[Descendant[a : "a"]]]] :> {p, a}],
  4800,
  TimeConstraint -> 0.07,
  TestID -> "perf-large-page-nested-descendant-names"
];

(* 20 ms; 299 ms. *)
TestCreate[
  Length @ XMLCases[$largePage, "ul"[{___, a : "li", b : "li", ___}] :> {a, b}],
  2000,
  TimeConstraint -> 0.06,
  TestID -> "perf-large-page-adjacent-list-names"
];

(* 35 ms; 220 ms. *)
TestCreate[
  Length @ XMLCases[$largePage, "tr"[Descendant[XMLPattern["time", "datetime" -> d_]], {___, n : "td"}] :> {d, n}],
  1200,
  TimeConstraint -> 0.1,
  TestID -> "perf-large-page-rows-attribute-and-list"
];

(* 14 ms; 338 ms. *)
TestCreate[
  Length @ XMLCases[$largePage, n : "div"[Shortest[Descendant[x : "a"]]] :> {n, x}],
  4800,
  TimeConstraint -> 0.05,
  TestID -> "perf-large-page-shortest-path"
];
