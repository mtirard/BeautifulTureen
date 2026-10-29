(* ::Package:: *)
(* HTMLPatterns: syntax information. Loaded last: it reads every public
   function's Options. *)

(* =========================================================== *)
(* Syntax information                                           *)
(* The front end colours a call with a wrong argument count.   *)
(* XMLPattern and Descendant are inert, but their counts are    *)
(* fixed too: a tag and attributes, the constraints being in   *)
(* a second bracket, which cannot be described here; a pattern *)
(* and a level spec. The query of XMLCases, XMLFirstCase and    *)
(* XMLDeleteCases is required: in an optional position the     *)
(* front end reads a query pattern :> rhs as an option and     *)
(* colours its pattern red, as it does not for Cases.          *)
(* =========================================================== *)

Scan[
  Apply[Function[{f, args},
    SyntaxInformation[f] = Join[{"ArgumentsPattern" -> args},
      If[Options[f] === {}, {}, {"OptionNames" -> Keys[Options[f]]}]]]],
  {XMLCases -> {_, _, _., OptionsPattern[]}, XMLFirstCase -> {_, _, _., OptionsPattern[]},
    XMLDeleteCases -> {_, _, OptionsPattern[]}, XMLMatchQ -> {_, _., OptionsPattern[]},
    XMLFreeQ -> {_, _., _., OptionsPattern[]},
    HTMLInnerText -> {_, OptionsPattern[]}, HTMLTextContent -> {_},
    HTMLToNotebook -> {_, OptionsPattern[]}, HTMLClassList -> {_}, FromCSSSelector -> {_},
    XMLPattern -> {_, _.}, Descendant -> {_, _.}}];

(* HTMLToTree takes Tree's options as well as its own, as TreeForm takes a
   depth. *)
SyntaxInformation[HTMLToTree] = {"ArgumentsPattern" -> {_, _., OptionsPattern[]},
  "OptionNames" -> Join[Keys[Options[HTMLToTree]], ToString /@ Keys[Options[Tree]]]};
