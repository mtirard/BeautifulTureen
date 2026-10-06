(*
	UnitTestFramework configuration for the BeautifulTureen paclet.

	Run from the repo root with:
		make test
	or directly:
		wolframscript -file Tests/run_tests.wls

	See https://github.com/SjoerdSmitWolfram/UnitTestFramework for the runner.

	BeautifulTureen is a self-contained paclet with no external or local
	dependencies, so this config only needs to point the runner at the paclet
	context; the framework locates PacletInfo.wl above Tests/, PacletDirectoryLoads
	the repo root, and Get-loads the context before the tests run.
*)

BeginPackage["UnitTestFramework`"]

$TestConfig

Begin["`Private`"]

$TestConfig = <|
	(* --- Paclet resolution --- *)
	(* First context is the paclet itself (Get-loaded by PacletInitialization);
	   BeautifulTureenTests` holds the shared fixtures from Support/Fixtures.wl.
	   Both are placed on $ContextPath while the tests evaluate, so tests can call
	   the public symbols (XMLCases, XMLPattern, ...) and reference the fixtures
	   ($tree, $treeSiblings, ...) unqualified. *)
	"PacletContexts" -> {"MaximilienTirard`BeautifulTureen`", "BeautifulTureenTests`"},
	"PacletDirectory" -> Automatic,

	(* Load the paclet, then the shared fixtures used across several test files,
	   and the seeded random-tree generator. *)
	"PacletInitialization" -> Function[cfg,
		Get["MaximilienTirard`BeautifulTureen`"];
		Get[FileNameJoin[{cfg["TestDirectory"], "Support", "Fixtures.wl"}]];
		Get[FileNameJoin[{cfg["TestDirectory"], "Support", "RandomTrees.wl"}]]
	],

	(* --- Test discovery --- *)
	"TestDirectory" -> Automatic,
	"TestFiles" -> All,
	"TestFilePattern" -> Automatic,

	(* --- Run behaviour --- *)
	"AbortOnFail" -> False,
	"OnTestResult" -> Automatic,
	"ReportType" -> "Full",
	"SkipTags" -> None,
	"TestEvaluationFunction" -> Automatic,
	"RandomSeeding" -> 1234,
	"TestCategorizationFunction" -> Automatic,
	"TestReportOptions" -> {},
	"TestFileContext" -> Automatic
|>;

End[]

EndPackage[]

$TestConfig
