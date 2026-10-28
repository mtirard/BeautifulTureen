(* ::Package:: *)

(* The paclet is written in the Structured Package Format: PackageInitialize
   loads every other .wl file under Kernel/, each in its own private context.
   That format is new in Wolfram 15.0, which is why the paclet requires 15.0.
   Keep this file to the one call: code here would run in the caller's context.
   Files load in alphabetical order, except:
   - Query/Compiler.wl loads before Query/Chains.wl, whose definitions have
     $anyLength and $recognisedMethods on their left-hand sides; a left-hand
     side is evaluated when the definition is made. Common.wl stays ahead of
     it, for $links on the compiler's left-hand sides.
   - SyntaxInformation.wl loads last: it reads every public function's Options.
   A misspelt name in "LoadFirstFiles" or "LoadLastFiles" loads no file at all. *)

PackageInitialize["MaximilienTirard`HTMLPatterns`",
  <|"LoadFirstFiles" -> {"Common.wl", "Query/Compiler.wl"}, "LoadLastFiles" -> {"SyntaxInformation.wl"}|>]
