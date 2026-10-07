(* Canaries for WL's own matcher, bug(479398). These test the Wolfram
   Language, not the paclet: no paclet function is called. Each canary passes
   while WL's MatchQ is slow on a list pattern that a recognised shape
   (ADR 0020) runs by a dedicated method, and fails when WL becomes fast on it.
   A failure here is not a paclet regression. It means the shapes the canary
   names may no longer be needed on that WL version: measure them against the
   general matcher (Block[{MaximilienTirard`BeautifulTureen`Private`$recogniseShapes
   = False}, ...]) and decide whether
   to keep them, or to let WL's matcher run them from that $VersionNumber on.

   Each canary compares the time of one MatchQ at two list lengths, four times
   apart, and asserts that the time grows much faster than the length. Ratios,
   not absolute times, so the canaries hold on slower or faster machines. Each
   time is the minimum of three runs, each cut off at 5 s, so a run that
   times out counts as 5 s and caps the growth. Each test returns the
   measured growth and passes when it is above the threshold (SameTest ->
   Greater), so a failure shows the growth. The thresholds sit between the growth a
   fixed WL would show and the growth measured here, with a wide margin to
   each. Measured on 15.0.0 for Mac OS X ARM (64-bit), on a 2026 laptop. *)

SetAttributes[wlMatcherTime, HoldAll];
wlMatcherTime[expr_] := Min @ Table[First @ AbsoluteTiming[TimeConstrained[expr, 5]], 3];

(* How much longer MatchQ[list[large], pattern] takes than
   MatchQ[list[small], pattern]. *)
wlMatcherGrowth[pattern_, list_, {small_, large_}] := With[
  {s = list[small], l = list[large]},
  wlMatcherTime[MatchQ[l, pattern]] / wlMatcherTime[MatchQ[s, pattern]]
];

(* 1. One slot, {___, z | w, ___}, guards shape 1 (anywhere), and the reason
   the list matcher finds the children C matches by Position. On a list with
   no z or w, the time is quadratic in its length: about 12 ms at 2,000 and
   0.2 s at 8,000, growth 13 to 20 over three runs (linear gives 4,
   quadratic 16). The literal {___, z, ___} takes a few microseconds at both
   lengths, growth about 4, and fails this test. If it fails: WL runs Alternatives of literals
   in linear time; measure shape 1 against the general matcher. *)
TestCreate[
  wlMatcherGrowth[{___, z | w, ___}, ConstantArray[y, #] &, {2000, 8000}],
  8,
  SameTest -> Greater,
  TimeConstraint -> 30,
  TestID -> "wl-matcher-479398-one-slot-quadratic"
];

(* 2. Two slots, {___, z | w, ___, z | w, ___}, guards shape 6 (ordered
   entries, GitHub #38, planned). The time is about cubic in the list length:
   about 4 ms at 150 and 0.24 s at 600, growth 44 to 51 over three runs
   (linear gives 4, quadratic 16, cubic 64). The literal
   {___, z, ___, z, ___} takes a few microseconds at both lengths, growth
   about 1, and fails this test. The threshold also fails
   on a quadratic fix, which still deserves a look at shape 6. If it fails:
   WL no longer retries placements of the slots to the right of a failing
   slot; measure lists of ordered entries against the general matcher. *)
TestCreate[
  wlMatcherGrowth[{___, z | w, ___, z | w, ___}, ConstantArray[y, #] &, {150, 600}],
  16,
  SameTest -> Greater,
  TimeConstraint -> 30,
  TestID -> "wl-matcher-479398-two-slots-cubic"
];

(* The structural counted form of shapes 4 and 5 (counted positions, GitHub
   #37), for the 5th child matching p, with p = h[1 | 3], an Alternatives and
   so not a literal. *)
wlMatcherCounted[p_] := {Except[p] ..., Repeated[PatternSequence[p, Except[p] ...], {4}], p, ___};

(* 3. Counted form on a list with no 5th match: three h[1], then n h[2]. The
   time grows about as n^4: growth from 15 to 60 about 270 over three runs
   (3 ms at 20, 0.93 s at 80). With the literal p = h[1] the growth from 15
   to 60 is about 9 (7 to 60 microseconds from 20 to 80), and it fails this
   test. If it fails: WL runs
   the counted form with Alternatives of literals in about linear time;
   measure shapes 4 and 5 against the general matcher, and check canary 4. *)
TestCreate[
  wlMatcherGrowth[wlMatcherCounted[h[1 | 3]], Join[{h[1], h[1], h[1]}, ConstantArray[h[2], #]] &, {15, 60}],
  64,
  SameTest -> Greater,
  TimeConstraint -> 30,
  TestID -> "wl-matcher-479398-counted-no-match"
];

(* 4. Counted form on a random list of h[1] and h[2], where the 5th match
   exists near the front (9th element at both lengths), as in the measurements
   that led to shapes 4 and 5 (0.0014 s at 20, 0.89 s at 80, 17.6 s at 160). About 0.5 ms
   at 15 and 0.36 s at 60, growth about 670. Unlike canary 3, the literal
   p = h[1] is slow here too (0.13 s at 60), so this slowness goes beyond what bug(479398) reports, and a fix of
   the bug alone may leave this canary passing; shapes 4 and 5 are then still
   needed. The anchored {Except[h[1 | 3]] ..., h[1 | 3], ___}, the 1st match,
   takes microseconds at both lengths, growth about 2, and fails this test. If it fails:
   measure shapes 4 and 5 against the general matcher. *)
TestCreate[
  wlMatcherGrowth[wlMatcherCounted[h[1 | 3]], BlockRandom[RandomChoice[{h[1], h[2]}, #], RandomSeeding -> 1] &, {15, 60}],
  64,
  SameTest -> Greater,
  TimeConstraint -> 30,
  TestID -> "wl-matcher-479398-counted-random"
];

(* 5. A probe, not a timing: what the matcher tries. A test that records each
   element it is given and always fails is called, for two slots on
   {1, 2, 3, 4, 5}, once per placement of the slots, Binomial[5, 2] = 10
   times: element 1 once for each position of the second slot, and so on. It
   uses PatternTest, which bug(479398) leaves out of its fix (a test can
   depend on global state), so this probe may keep passing after the fix. If
   it fails: the matcher no longer retries placements of the slots to the
   right of a failing slot; check canaries 2 to 4. *)
TestCreate[
  Module[{record},
    record[e_] := (Sow[e]; False);
    Reap[MatchQ[{1, 2, 3, 4, 5}, {___, _?record, ___, _?record, ___}]][[2, 1]]
  ],
  {1, 1, 1, 1, 2, 2, 2, 3, 3, 4},
  TestID -> "wl-matcher-479398-probe-retried-placements"
];
