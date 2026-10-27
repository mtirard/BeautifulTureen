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

(* Each Kernel file has its own private context, so a helper defined in one file
   and used in another must be declared PackageScoped. If it is not, the using
   file gets its own symbol of that name, and a call to it stays unevaluated
   with no message. After loading, no short name may have definitions in one
   file's private context and also exist in another's. A pattern variable or a
   local that shares its name across files has no definitions, so it is not
   flagged; nor is a local renamed by nested scoping (x$), whose one attribute
   is Temporary. Each entry is {short name, private contexts where it has
   definitions, other private contexts where it exists}. *)

missedScopes[] := ToExpression @ RunProcess[{"wolframscript", "-code",
    "PacletDirectoryLoad[" <> ToString[$loadingRepo, InputForm] <> "];
     Needs[\"MaximilienTirard`HTMLPatterns`\"];
     definedQ[name_] := ToExpression[name, InputForm, Function[s,
       AnyTrue[{OwnValues[s], DownValues[s], UpValues[s], SubValues[s], DeleteCases[Attributes[s], Temporary]}, # =!= {} &],
       HoldAll]];
     byShortName = GroupBy[Names[\"MaximilienTirard`HTMLPatterns`*`Private`*\"],
       Last[StringSplit[#, \"`\"]] &,
       GroupBy[#, definedQ, Map[Context]] &];
     ToString[KeyValueMap[{#1, #2[True], Lookup[#2, False, {}]} &,
       Select[byShortName, KeyExistsQ[#, True] && Length[Union @@ Values[#]] > 1 &]],
       InputForm]"},
  "StandardOutput"];

TestCreate[
  missedScopes[],
  {},
  TestID -> "loading-every-helper-used-in-another-file-is-scoped"
];
