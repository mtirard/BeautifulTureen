(* ::Package:: *)

(* The paclet is written in the Structured Package Format: PackageInitialize
   loads every other .wl file under Kernel/, each in its own private context.
   That format is new in Wolfram 15.0, which is why the paclet requires 15.0.
   Keep this file to the one call: code here would run in the caller's context.
   Files load in alphabetical order, except SyntaxInformation.wl, which
   loads last: it reads every public function's Options. A misspelt name in
   "LoadLastFiles" loads no file at all.
   "FileOrderingFunction" -> Order gives the same order for these file names as
   the default AlphabeticSort, which takes ~0.2 s the first time in a session. *)

PackageInitialize["MaximilienTirard`HTMLPatterns`",
  <|"LoadLastFiles" -> {"SyntaxInformation.wl"},
    "FileOrderingFunction" -> Order|>]
