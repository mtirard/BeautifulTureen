(* The columnar engine against the solutions engine: seeded random queries
   (Support/RandomQueries.wl) on seeded random inputs give the same results,
   in the same order, through XMLCases, XMLCases with a count, and
   XMLPosition. This is the one test that reaches inside the paclet, to force
   each engine; it goes when the solutions engine does. *)

Get[FileNameJoin[{ParentDirectory[DirectoryName[FindFile["MaximilienTirard`HTMLPatterns`"]]], "Tests", "Support", "RandomQueries.wl"}]];

$engineQueries = randomQueries[20261030, 300];
$engineInputs = randomInputs[20261030, 3];

(* Each run is {query, input, consumer}, and differs when the two engines
   give different results. *)
engineDifferences[queries_, inputs_] :=
  Select[
    Flatten[Outer[List, queries, inputs, {XMLCases, XMLCases[##, 2] &, XMLPosition}, 1], 2],
    Function[{run}, run /. {Hold[q_], t_, f_} :> (underEngine["Solutions", f[t, q]] =!= underEngine["Columnar", f[t, q]])]];

TestCreate[
  engineDifferences[$engineQueries, $engineInputs],
  {},
  TestID -> "columnar-equals-solutions-on-random-queries"
]
