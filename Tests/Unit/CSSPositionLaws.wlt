(* Laws of the CSS child-indexed pseudo-classes, on the children of each
   random tree's root (Support/RandomTrees.wl), as the children of an ol, a
   tag random trees do not use. Each law relates the translations of two
   selectors, so it checks the contents lists FromCSSSelector writes for
   counted positions against each other, with no oracle. These were the
   laws of the recognised-shape tests of 3.0.0 (ADR 0020). *)

$trees = randomTrees[20261006, 12];

$siblings = XMLElement["ol", {}, Last[#]] & /@ $trees;

ids[l_] := Sort[Lookup[#[[2]], "id"] & /@ l];

TestCreate[
  AllTrue[$siblings, Function[t,
    With[{even = ids @ XMLCases[t, "ol > :nth-child(2n)"], odd = ids @ XMLCases[t, "ol > :nth-child(2n+1)"]},
      !IntersectingQ[even, odd] && Union[even, odd] === ids[XMLCases[t, "ol > *"]]]]],
  True,
  TestID -> "shape-positions-law-even-odd-partition"
];

TestCreate[
  AllTrue[$siblings, Function[t,
    With[{len = Count[Last[t], _XMLElement]},
      AllTrue[Range[len], Function[k,
        With[{r = XMLCases[t, "ol > :nth-child(" <> ToString[k] <> ")"]},
          Length[r] == 1 && r === XMLCases[t, "ol > :nth-last-child(" <> ToString[len - k + 1] <> ")"]]]]]]],
  True,
  TestID -> "shape-positions-law-from-start-is-from-end"
];

TestCreate[
  AllTrue[$trees, ids[XMLCases[#, ":only-child"]] === Intersection[ids[XMLCases[#, ":first-child"]], ids[XMLCases[#, ":last-child"]]] &],
  True,
  TestID -> "shape-positions-law-only-child"
];

(* Position-set laws: :nth-child(k of S) is :nth-child(k) when S is the
   universal selector, and :nth-of-type(k) is :nth-child(k of T) for the type
   T, and the same from the end. *)
TestCreate[
  AllTrue[$siblings, Function[t,
    AllTrue[Range[6], Function[k, With[{n = ToString[k]},
      ids[XMLCases[t, "ol > :nth-child(" <> n <> " of *)"]] === ids[XMLCases[t, "ol > :nth-child(" <> n <> ")"]] &&
      ids[XMLCases[t, "ol > :nth-last-child(" <> n <> " of *)"]] === ids[XMLCases[t, "ol > :nth-last-child(" <> n <> ")"]] &&
      AllTrue[$randomTags, Function[T,
        ids[XMLCases[t, "ol > " <> T <> ":nth-of-type(" <> n <> ")"]] === ids[XMLCases[t, "ol > :nth-child(" <> n <> " of " <> T <> ")"]] &&
        ids[XMLCases[t, "ol > " <> T <> ":nth-last-of-type(" <> n <> ")"]] === ids[XMLCases[t, "ol > :nth-last-child(" <> n <> " of " <> T <> ")"]]]]]]]]],
  True,
  TestID -> "shape-counted-laws"
];

(* Laws: .x:nth-of-type(k) is .x among the union over the tags T of
   T:nth-of-type(k), on lists of the random trees' tags, and
   *:first-of-type is *:nth-of-type(1), and the same from the end. *)
TestCreate[
  AllTrue[$siblings, Function[t,
    AllTrue[Range[4], Function[k, With[{n = ToString[k]},
      ids[XMLCases[t, "ol > .a:nth-of-type(" <> n <> ")"]] ===
        ids[Intersection[XMLCases[t, "ol > .a"], Join @@ (XMLCases[t, "ol > " <> # <> ":nth-of-type(" <> n <> ")"] & /@ $randomTags)]] &&
      ids[XMLCases[t, "ol > .a:nth-last-of-type(" <> n <> ")"]] ===
        ids[Intersection[XMLCases[t, "ol > .a"], Join @@ (XMLCases[t, "ol > " <> # <> ":nth-last-of-type(" <> n <> ")"] & /@ $randomTags)]]]]] &&
    ids[XMLCases[t, "ol > *:first-of-type"]] === ids[XMLCases[t, "ol > *:nth-of-type(1)"]] &&
    ids[XMLCases[t, "ol > *:last-of-type"]] === ids[XMLCases[t, "ol > *:nth-last-of-type(1)"]]]],
  True,
  TestID -> "shape-split-laws"
];
