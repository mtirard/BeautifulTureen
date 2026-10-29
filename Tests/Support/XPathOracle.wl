(*
	The XPath oracle: XPath 1.0 run by the JDK bundled with Wolfram, as an
	independent reference for single-result queries. A node set comes back
	deduplicated and in document order, which is the result order of a query
	with one counted name that binds elements.

	The tree is exported with each element carrying data-p, its position in
	the expression, and the oracle gives the elements it selects by those
	positions. XPathOracle.java beside this file runs the queries.

	Loaded by the test files that use it, on the HTMLPatternsTests` context.
*)

BeginPackage["HTMLPatternsTests`"];

xpathElements::usage = "xpathElements[tree, queries] gives an Association from each XPath query to the elements of tree it selects, in document order, or $Failed if the JDK did not run.";
oracleTrees::usage = "oracleTrees[seed, n] is a list of n random documents, the same for the same seed, over the tags the oracle queries name.";

Begin["`Private`"];

$java = FileNameJoin[{$InstallationDirectory, "SystemFiles", "Java", $SystemID, "bin", "java"}];
$source = FileNameJoin[{DirectoryName[$InputFileName], "XPathOracle.java"}];

annotated[tree_] :=
  MapIndexed[
    Function[{x, pos}, If[MatchQ[x, XMLElement[_String, _List, _List]],
      XMLElement[x[[1]], Append[x[[2]], "data-p" -> ToString[pos, InputForm]], x[[3]]], x]],
    tree, {0, Infinity}];

xpathElements[tree_, queries_List] :=
  Module[{dir = CreateDirectory[], xml, qf, out},
    xml = FileNameJoin[{dir, "doc.xml"}];
    qf = FileNameJoin[{dir, "q.txt"}];
    Export[xml, annotated[tree], "XML"];
    Export[qf, StringRiffle[queries, "\n"], "Text"];
    out = RunProcess[{$java, $source, xml, qf, "1"}];
    DeleteDirectory[dir, DeleteContents -> True];
    If[out["ExitCode"] =!= 0, $Failed,
      Association[#[[1]] -> Replace[#[[3]], {"e", _, p_} :> Extract[tree, p], {1}] & /@
        ToExpression /@ Rest[StringSplit[out["StandardOutput"], "\n"]]]]];

$tags = {"div", "nav", "a", "p", "ul", "li", "h2", "span", "td", "tr"};

element[depth_] :=
  XMLElement[RandomChoice[$tags], {"id" -> ToString[++$id]},
    If[depth == 0 || RandomReal[] > 0.45, {},
      Table[If[RandomReal[] < 0.15, " ", element[depth - 1]], RandomInteger[{1, 6}]]]];

oracleTrees[seed_Integer, n_Integer] :=
  BlockRandom[SeedRandom[seed];
    Table[Block[{$id = 0}, XMLObject["Document"][{}, XMLElement["body", {}, Table[element[5], 4]], {}]], n]];

End[];

EndPackage[];
