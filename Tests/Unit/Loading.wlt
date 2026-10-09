(* Loading the paclet makes public only the symbols it documents: every name in
   its context has a usage message. The test kernel has the paclet loaded
   already, so the check loads this checkout into a fresh kernel. *)

$loadingRepo = ParentDirectory[DirectoryName[FindFile["MaximilienTirard`HTMLPatterns`"]]];

publicNamesWithoutUsage[] := ToExpression @ RunProcess[{"wolframscript", "-code",
    "PacletDirectoryLoad[" <> ToString[$loadingRepo, InputForm] <> "];
     Needs[\"MaximilienTirard`HTMLPatterns`\"];
     ToString[Select[Names[\"MaximilienTirard`HTMLPatterns`*\"],
       !StringQ[ToExpression[#, InputForm, Function[s, MessageName[s, \"usage\"], HoldFirst]]] &],
       InputForm]"},
  "StandardOutput"];

TestCreate[
  publicNamesWithoutUsage[],
  {},
  TestID -> "loading-makes-public-only-documented-symbols"
];
