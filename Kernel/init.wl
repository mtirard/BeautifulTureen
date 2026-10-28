(* ::Package:: *)

(* The paclet is written in the Structured Package Format: PackageInitialize
   loads every other .wl file under Kernel/, each in its own private context.
   That format is new in Wolfram 15.0, which is why the paclet requires 15.0.
   Keep this file to the one call: code here would run in the caller's context.
   SyntaxInformation.wl loads last: it reads every public function's Options. A misspelt name in "LoadLastFiles" loads no file at all. *)

PackageInitialize["MaximilienTirard`HTMLPatterns`", <|"LoadLastFiles" -> {"SyntaxInformation.wl"}|>]
