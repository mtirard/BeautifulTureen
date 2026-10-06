(*
	Seeded random trees, for tests that compare two ways of running a query on
	many inputs (a recognised shape against WL's matcher, a CSS selector against
	its translation).

	A tree is an XMLElement whose element children are drawn from a small
	alphabet of tags, each with a random class attribute (absent, empty, or one
	or two tokens) and an id, with text nodes mixed in. Each list of children
	has 0 to 40 entries, and elements nest up to depth 4. Only some children
	have children of their own, so a tree stays at a few hundred elements.

	Loaded by Tests/TestConfig.m's "PacletInitialization", on the
	BeautifulTureenTests` context.
*)

BeginPackage["BeautifulTureenTests`"];

randomTree::usage = "randomTree[seed] is a random XMLElement tree, the same for the same seed.";
randomTrees::usage = "randomTrees[seed, n] is a list of n random trees, the same for the same seed.";
$randomTags::usage = "$randomTags is the alphabet of tags in random trees.";
$randomClasses::usage = "$randomClasses is the alphabet of class tokens in random trees.";

Begin["`Private`"];

$randomTags = {"div", "p", "li", "span"};
$randomClasses = {"a", "b", "c"};

randomTree[seed_Integer] := First @ randomTrees[seed, 1];

randomTrees[seed_Integer, n_Integer] :=
  BlockRandom[SeedRandom[seed]; Table[Block[{$id = 0}, element["div", 4, True]], n]];

(* The root always has children, so that every tree has a list to match. *)
element[tag_, depth_, full_] :=
  XMLElement[tag, attributes[], If[depth == 0 || !full && RandomReal[] > 0.1, {}, children[depth - 1]]];

attributes[] :=
  Append[
    Replace[RandomChoice[{2, 1, 3, 3} -> {None, {}, {1}, {2}}], {
      None -> {},
      {} -> {"class" -> ""},
      {k_} :> {"class" -> StringRiffle[RandomSample[$randomClasses, k]]}}],
    "id" -> ToString[++$id]];

children[depth_] :=
  Table[
    If[RandomReal[] < 0.25, RandomChoice[{"t", " ", "text"}], element[RandomChoice[$randomTags], depth, False]],
    RandomInteger[{0, 40}]];

End[];

EndPackage[];
