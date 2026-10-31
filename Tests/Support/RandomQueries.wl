(*
	Seeded random queries over the alphabet of random trees (RandomTrees.wl),
	for the test that runs each query on both query engines and compares
	what they give.

	The queries stay within what the columnar engine runs: pattern roots that
	are XMLPatterns, class selectors, XMLElement patterns or alternatives of
	these, or XMLDocument at the top; names on elements, tags, attribute maps
	and whole attribute values, tested or conditioned; WL patterns on
	attribute values;
	Descendant with and without level specs, Child and list constraints,
	several to an element and nested, and alternatives of them; a name now
	and then used again by a later constraint of the same element, which
	pins one place, and a name for an element or a tag now and then bound
	again anywhere; Conditions and PatternTests. A list's entries are blanks
	and sequences, element patterns, named or not, named runs and gaps,
	repeats, a name inside a repeat of one entry or of two, optional
	entries, alternatives, a Condition on a sequence and Except. XMLElement patterns are matched whole or by their
	parts, with a contents list over the items, text included, and an
	XMLPattern's class may be matched as a token list, a token named. A right-hand side uses some of the names,
	and may test another. The generator grows as the columnar engine covers
	more.

	Loaded by the tests that need it, on the HTMLPatternsTests` context.
*)

BeginPackage["HTMLPatternsTests`", {"MaximilienTirard`HTMLPatterns`"}];

randomQuery::usage = "randomQuery[seed] is a random query, held, the same for the same seed.";
randomQueries::usage = "randomQueries[seed, n] is a list of n random queries, each held.";
randomInputs::usage = "randomInputs[seed, n] is a list of n random inputs: bare elements, lists of elements and documents.";
underEngine::usage = "underEngine[engine, f, args] is f[args] with the query engine forced to engine, \"Solutions\" or \"Columnar\".";

Begin["`Private`"];

randomQueries[seed_Integer, n_Integer] := BlockRandom[SeedRandom[seed]; Table[query[], n]];
randomQuery[seed_Integer] := First @ randomQueries[seed, 1];

(* Each input is a random tree as it is, the list of its element children,
   or a document holding it, in turn. *)
randomInputs[seed_Integer, n_Integer] :=
  MapIndexed[
    Switch[Mod[First[#2], 3],
      1, #1,
      2, Cases[#1[[3]], _XMLElement],
      0, XMLObject["Document"][{}, #1, {}]] &,
    randomTrees[seed, n]];

SetAttributes[underEngine, HoldRest];
underEngine[engine_, f_[args___]] := Block[{MaximilienTirard`HTMLPatterns`PackageScope`$engine = engine}, f[args]];

$names = Unique["v"] & /@ Range[10];

(* Building with Hold throughout keeps the Conditions and tests
   unevaluated. *)
query[] :=
  Block[{$used = {}, $pools = <|"element" -> {}, "tag" -> {}|>},
    With[{lhs = If[RandomReal[] < 0.15, document[], pattern[RandomInteger[{1, 3}]]]},
      With[{bound = $used},
        If[bound === {}, Hold @@ {lhs},
          With[{counted = RandomSample[bound, RandomInteger[{1, Min[3, Length[bound]]}]],
              tested = RandomChoice[{0.8, 0.2} -> {None, RandomChoice[bound]}]},
            rule[lhs, counted, tested]]]]]];

(* ReplaceAll, not With, which would rename the names of the rule. *)
rule[lhs_, counted_, tested_] :=
  If[tested === None, Hold[l :> b], Hold[l :> b /; Mod[Hash[{t}], 2] == 0]] /.
    {l -> lhs, b -> If[Length[counted] == 1 && RandomReal[] < 0.7, First[counted], counted], t -> tested};

room[] := Length[$used] < Length[$names];

fresh[] := With[{n = $names[[Length[$used] + 1]]}, AppendTo[$used, n]; n];

(* A name for an element or a tag: now and then one bound already to the
   same kind of thing, which then compares values or positions (ADR
   0023). *)
named[pool_] :=
  If[$pools[pool] =!= {} && RandomReal[] < 0.3, RandomChoice[$pools[pool]],
    With[{n = fresh[]}, AppendTo[$pools[pool], n]; n]];

tag[] := RandomChoice[{"div", "p", "li", "span"}];

oddIdQ[s_String] := OddQ[ToExpression[s]];

(* The head of an element pattern, and whether it takes constraints. One
   branch is built, so a name is taken only when it is used. *)
head[] :=
  Switch[RandomChoice[{6, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1} -> Range[15]],
    1, {XMLPattern[tag[]], True},
    2, {tag[] <> RandomChoice[{"", "." <> RandomChoice[{"a", "b", "c"}]}], True},
    3, {If[room[], XMLPattern[tag[], "id" -> Pattern[Evaluate[fresh[]], Blank[]]], XMLPattern[tag[]]], True},
    4, {If[room[], XMLPattern[Pattern[Evaluate[named["tag"]], Blank[]]], XMLPattern[_]], True},
    5, {If[room[], XMLPattern[tag[], Pattern[Evaluate[fresh[]], Blank[]]], XMLPattern[tag[]]], True},
    6, {XMLPattern[Alternatives @@ RandomSample[{"div", "p", "li", "span"}, 2]], True},
    7, {XMLPattern[_], True},
    8, {If[room[], XMLPattern[tag[], "class" -> Pattern[Evaluate[fresh[]], Blank[]]], XMLPattern[tag[]]], True},
    9, {XMLPattern[tag[], "id" -> _?oddIdQ], True},
    10, {If[room[], XMLPattern[Pattern[Evaluate[fresh[]], "div" | "li"], "id" -> _String], XMLPattern["div"]], True},
    11, {XMLElement[tag[], _, RandomChoice[{{}, _}]], False},
    12, {If[room[], XMLPattern[tag[], "id" -> PatternTest[Pattern[Evaluate[fresh[]], Blank[]], oddIdQ]], XMLPattern[tag[]]], True},
    13, {If[room[], With[{t = fresh[]}, XMLPattern[Condition @@ Hold[Pattern[t, Blank[]], StringLength[t] < 3]]], XMLPattern[_]], True},
    14, {XMLElement[tag[], If[room[] && RandomReal[] < 0.3, Pattern[Evaluate[fresh[]], Blank[]], _], contents[]], False},
    15, {XMLPattern[tag[], "classList" -> tokens[]], True}];

(* A literal's contents: a list over its items, elements and text. A name
   binds only an element or a run of elements, as a counted name that can
   bind text is refused. *)
contents[] :=
  Table[
    Switch[RandomChoice[{3, 2, 1, 1, 2, 1, 1, 1} -> Range[8]],
      1, ___,
      2, XMLPattern[tag[]],
      3, "t",
      4, _String,
      5, If[room[], Pattern[Evaluate[named["element"]], XMLPattern[tag[]]], _XMLElement],
      6, __,
      7, If[room[], Pattern[Evaluate[fresh[]], Repeated[_XMLElement]], _XMLElement..],
      8, Except[_String]],
    RandomInteger[{1, 4}]];

(* A token list at the class list key. *)
tokens[] :=
  With[{l = Table[
      Switch[RandomChoice[{3, 2, 2, 1, 1, 1} -> Range[6]],
        1, ___,
        2, If[room[], Pattern[Evaluate[fresh[]], RandomChoice[{"a", "b", "c"}]], "a"],
        3, RandomChoice[{"a", "b", "c", "a" | "b"}],
        4, Except["c"],
        5, If[room[], Pattern[Evaluate[fresh[]], BlankNullSequence[]], ___],
        6, _],
      RandomInteger[{1, 3}]]},
    If[room[] && RandomReal[] < 0.2, Pattern[Evaluate[fresh[]], l], l]];

pattern[depth_] :=
  Module[{h, takesQ, cons, p},
    {h, takesQ} = head[];
    cons = If[depth == 0 || !takesQ, {}, Table[constraint[depth - 1], RandomInteger[{0, 2}]]];
    cons = pinned[cons];
    p = If[cons === {}, h, h @@ cons];
    If[RandomReal[] < 0.1, p = p?(Length[#[[3]]] > 2 &)];
    If[room[] && RandomReal[] < 0.5, p = Pattern[Evaluate[named["element"]], p]];
    If[RandomReal[] < 0.1, p = condition[p]];
    If[RandomReal[] < 0.08, p = Alternatives[p, pattern[0]]];
    p];

(* A Condition sees only the names inside the pattern it wraps. *)
condition[p_] :=
  With[{inside = Intersection[$used, Cases[Hold[p], Verbatim[Pattern][s_Symbol, _] :> s, {0, Infinity}, Heads -> True]]},
    If[inside === {}, p,
      With[{n = RandomChoice[inside]}, Condition @@ Hold[p, Mod[Hash[{n}], 3] =!= 0]]]];

(* A later constraint that names again the element an earlier one named,
   which pins both to one element. *)
pinned[cons_] :=
  With[{named = Cases[cons, (Descendant | Child)[Verbatim[Pattern][s_Symbol, _XMLPattern | _String], ___] :> s]},
    If[named =!= {} && RandomReal[] < 0.3,
      Append[cons, Descendant[Pattern[Evaluate[RandomChoice[named]], XMLPattern[_]]]], cons]];

constraint[depth_] :=
  Switch[RandomChoice[{4, 1, 1, 3, 1, 4, 1} -> Range[7]],
    1, Descendant[pattern[depth]],
    2, Descendant[pattern[depth], RandomChoice[{2, {1}, {2}, {1, 2}, {2, Infinity}}]],
    3, Descendant[pattern[depth], {2, Infinity}],
    4, Child[pattern[depth]],
    5, Alternatives[Descendant[pattern[depth]], Child[pattern[depth]]],
    6, list[depth],
    7, Alternatives[list[depth], Descendant[pattern[depth]]]];

(* A list constraint over the element children. *)
list[depth_] :=
  With[{l = Table[entry[depth], RandomInteger[{1, 4}]]},
    Switch[RandomChoice[{8, 1, 1} -> Range[3]],
      1, l,
      2, If[room[], Pattern[Evaluate[fresh[]], l], l],
      3, condition[l]]];

entry[depth_] :=
  Switch[RandomChoice[{4, 2, 1, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1} -> Range[14]],
    1, ___,
    2, __,
    3, _,
    4, pattern[depth],
    5, If[room[], Pattern[Evaluate[fresh[]], BlankSequence[]], __],
    6, If[room[], Pattern[Evaluate[fresh[]], BlankNullSequence[]], ___],
    7, Repeated[RandomChoice[{XMLPattern[tag[]], tag[], tag[] <> ".a", XMLPattern[_]}], RandomChoice[{Infinity, {1, 2}, {2}}]],
    8, If[room[], Pattern[Evaluate[fresh[]], Repeated[tag[]]], tag[]..],
    9, If[room[], Repeated[Pattern[Evaluate[named["element"]], tag[]]], tag[]..],
    10, Optional[pattern[0]],
    11, Alternatives[PatternSequence[tag[], tag[]], pattern[0]],
    12, If[Length[$used] + 2 <= Length[$names],
      With[{a = fresh[], b = fresh[]}, Condition @@ Hold[PatternSequence[Pattern[a, tag[]], Pattern[b, tag[]]], Mod[Hash[{a, b}], 3] =!= 0]],
      PatternSequence[tag[], ___]],
    13, Except[tag[]],
    14, If[room[], Repeated[PatternSequence[Pattern[Evaluate[named["element"]], tag[]], _], RandomChoice[{Infinity, {1, 2}}]], tag[]..]];

document[] :=
  With[{d = XMLDocument @@ Table[constraint[RandomInteger[{0, 2}]], RandomInteger[{1, 2}]]},
    If[room[] && RandomReal[] < 0.4, Pattern[Evaluate[fresh[]], d], d]];

End[];

EndPackage[];
