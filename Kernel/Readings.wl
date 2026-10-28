(* ::Package:: *)
(* HTMLPatterns: readings and materialisation (ADR 0012) *)

(* Used by DisplayRoles.wl *)
PackageScoped[materialiser]

(* Used by DisplayRoles.wl and Query/Compiler.wl *)
PackageScoped[readingsInForce]

(* Used by Notebook.wl, Text.wl, Tree.wl and XMLFunctions.wl *)
PackageScoped[withReadings]

(* Used by Query/Compiler.wl *)
PackageScoped[$warnedListKeys]
PackageScoped[tok]

(* Used by Query/Compiler.wl and Query/Run.wl *)
PackageScoped[unmaterialised]

(* Used by Query/Run.wl *)
PackageScoped[materialise]

(* Used by XMLFunctions.wl *)
PackageScoped[withListKeyWarnings]

(* =========================================================== *)
(* Readings (ADR 0012)                                          *)
(* A reading fixes a microsyntax to a literal attribute key and *)
(* names the list key an XML pattern reaches its token list by. *)
(* =========================================================== *)

PackageExported[$AttributeReadings]
$AttributeReadings::usage = "$AttributeReadings is an Association that gives, for each attribute it names, how the attribute value is split into a list of tokens and the list key that gives that list in an XMLPattern. Each entry is an Association with the fields Method, Delimiters, \"TrimWhitespace\" and \"ListKey\", any of which can be omitted. Method \"SpaceSeparated\" (the default) splits on HTMLWhitespace and does not trim tokens. Method \"CommaSeparated\" splits on \",\" and trims HTML whitespace from each token. Delimiters (a string pattern) and \"TrimWhitespace\" (True or False) override the setting that Method gives. \"ListKey\" -> Automatic gives the attribute name followed by \"List\". Keys are attribute names given as strings; a {namespace, name} attribute cannot have an entry. By default, $AttributeReadings has one entry, for \"class\", with the list key \"classList\". The \"AttributeReadings\" option of functions such as XMLCases adds entries for one call, and an entry for an attribute already present replaces it. Block[{$AttributeReadings = ...}, ...] replaces the whole Association, including the \"class\" entry.";
$AttributeReadings::badkey = "Each key in the readings should be an attribute name given as a string. Got `1`.";
$AttributeReadings::notassoc = "$AttributeReadings and the \"AttributeReadings\" option should be an Association from attribute names to readings. Got `1`.";
$AttributeReadings::badentry = "The reading for `1` should be an Association with any of the fields Method, Delimiters, \"TrimWhitespace\" and \"ListKey\". Got `2`.";
$AttributeReadings::badfield = "The reading for `1` has the unknown field `2`. The fields of a reading are Method, Delimiters, \"TrimWhitespace\" and \"ListKey\".";
$AttributeReadings::badmethod = "The reading for `1` has Method `2`. Method should be \"SpaceSeparated\" or \"CommaSeparated\".";
$AttributeReadings::badvalue = "The reading for `1` has `2` -> `3`. Delimiters should be a string pattern, \"TrimWhitespace\" should be True or False, and \"ListKey\" should be a string. Any of them can also be Automatic.";
$AttributeReadings::duplistkey = "More than one reading has the list key `1`. Give each reading a different \"ListKey\".";
$AttributeReadings::listkeyisreading = "The list key `1` is also an attribute with a reading, so `1` in an XMLPattern would be ambiguous. Choose a different \"ListKey\".";

$AttributeReadings = <|
  "class" -> <|Method -> "SpaceSeparated", Delimiters -> Automatic,
    "TrimWhitespace" -> Automatic, "ListKey" -> Automatic|>|>;

(* Method is shorthand defining the other two fields. *)
$methodDefaults = <|
  "SpaceSeparated" -> <|Delimiters -> HTMLWhitespace, "TrimWhitespace" -> False|>,
  "CommaSeparated" -> <|Delimiters -> ",", "TrimWhitespace" -> True|>|>;

splitter[delim_, False] := Function[v, StringSplit[v, delim]];
(* Trimming strips HTML whitespace, as the comma microsyntax does: a no-break
   space is part of a token. *)
splitter[delim_, True] := Function[v, StringTrim[#, HTMLWhitespace] & /@ StringSplit[v, delim]];

(* A readings table resolved for the compiler: list key -> {raw key, split}. *)
resolveReading[key_String -> spec_Association] :=
  With[{defaults = $methodDefaults[Lookup[spec, Method, "SpaceSeparated"]]},
    listKeyOf[key, spec] ->
      {key, splitter[
        Replace[Lookup[spec, Delimiters, Automatic], Automatic -> defaults[Delimiters]],
        Replace[Lookup[spec, "TrimWhitespace", Automatic], Automatic -> defaults["TrimWhitespace"]]]}];

resolveReadings[readings_Association] := Association[resolveReading /@ Normal[readings]];

(* The readings table in force, $AttributeReadings, resolved. A table that
   fails validation has said why, and gives $Failed. *)
readingsInForce[] :=
  Catch[resolveReadings[validReadings[validTable[$AttributeReadings]]], $refusal];

(* A consumer's AttributeReadings option is shorthand for a Block of the global
   over the whole call (#34), so a nested XML* call in a condition or a rule
   body, and any function it calls, sees it. It adds to the global; an entry
   for a key the global already has replaces that key's entry whole. Only the
   two tables' shapes are checked here, as Join needs them; each query compiled
   in the call validates the joined table. *)
SetAttributes[withReadings, HoldRest];
withReadings[opt_, call_] :=
  Replace[Catch[Join @@ (validTable /@ {$AttributeReadings, opt}), $refusal], {
    $Failed -> $Failed,
    t_ :> Block[{$AttributeReadings = t}, withListKeyWarnings[call]]}];

(* The list keys already warned about in this call (#24). The outermost call
   sets up the set and every nested call shares it, so each key is warned
   about once per call, however many queries the call compiles, and again on
   the next call. Outside any call it is None, and every warning is issued. *)
$warnedListKeys = None;

SetAttributes[withListKeyWarnings, HoldAll];
withListKeyWarnings[call_] := If[$warnedListKeys === None, Block[{$warnedListKeys = <||>}, call], call];

(* A Block of $AttributeReadings, the option's or a caller's, hides the
   symbol's message texts too, so a refusal gives its text back for the
   Block's duration. *)
$readingMessages = AssociationMap[MessageName[$AttributeReadings, #] &,
  {"notassoc", "badkey", "badentry", "badfield", "badmethod", "badvalue", "duplistkey", "listkeyisreading"}];

refuseReading[tag_String, args___] := (
  If[!StringQ[MessageName[$AttributeReadings, tag]],
    MessageName[$AttributeReadings, tag] = $readingMessages[tag]];
  refuse[MessageName[$AttributeReadings, tag], args]);

validTable[t_Association] := t;
validTable[t_] := refuseReading["notassoc", t];

validReadings[readings_] :=
  (KeyValueMap[validReading, readings]; validListKeys[readings]; readings);

listKeyOf[key_, spec_] := Replace[Lookup[spec, "ListKey", Automatic], Automatic -> key <> "List"];

validListKeys[readings_] :=
  With[{listKeys = KeyValueMap[listKeyOf, readings]},
    Replace[Select[Tally[listKeys], Last[#] > 1 &],
      {{k_, _}, ___} :> refuseReading["duplistkey", k]];
    Replace[Intersection[listKeys, Keys[readings]],
      {k_, ___} :> refuseReading["listkeyisreading", k]]];

$readingFields = {Method, Delimiters, "TrimWhitespace", "ListKey"};

validReading[key_, _] /; !StringQ[key] := refuseReading["badkey", key];
validReading[key_, spec_] /; !AssociationQ[spec] := refuseReading["badentry", key, spec];
validReading[key_, spec_] := (
  Replace[Complement[Keys[spec], $readingFields],
    {f_, ___} :> refuseReading["badfield", key, f]];
  If[!KeyExistsQ[$methodDefaults, Lookup[spec, Method, "SpaceSeparated"]],
    refuseReading["badmethod", key, spec[Method]]];
  KeyValueMap[
    If[!validFieldQ[#1, #2], refuseReading["badvalue", key, #1, #2]] &,
    KeyDrop[spec, Method]]);

(* Whether a value is a string pattern is the string functions' own judgement. *)
validFieldQ[Delimiters, d_] := d === Automatic || Quiet[Check[StringFreeQ["", d]; True, False]];
validFieldQ["TrimWhitespace", t_] := MatchQ[t, Automatic | True | False];
validFieldQ["ListKey", k_] := MatchQ[k, Automatic | _String];

(* =========================================================== *)
(* Materialisation (ADR 0012)                                   *)
(* A query naming a list key runs on a tree whose elements each *)
(* carry the token list beside the raw value, under the private *)
(* key head tok (inert: no definitions). unmaterialised is the  *)
(* exact inverse: unmaterialised[materialise[e, ...]] === e.    *)
(* =========================================================== *)

(* Only the distinct raw values on the tree are split: a page has a handful of
   distinct class strings across thousands of elements. An absent attribute
   reads as {}, as a browser's classList does. *)
tokenMap[tree_, {key_, split_}, level_] :=
  With[{vals = DeleteDuplicates @
      Cases[tree, XMLElement[_, a_List, _] :> Lookup[a, key, Nothing], level]},
    AssociationThread[vals, split /@ vals]];

(* One pass per list key: nearly every query names one. *)
materialise[tree_, readings_List, level_ : {0, Infinity}] :=
  Fold[materialiseKey[#1, #2, level] &, tree, readings];

materialiseKey[tree_, reading : {key_, _}, level_] :=
  With[{map = tokenMap[tree, reading, level]},
    Replace[tree,
      XMLElement[t_, a_List, c_] :>
        XMLElement[t, Append[a, tok[key] -> Lookup[map, Lookup[a, key, None], {}]], c],
      level]];

(* An element materialised when it is asked for, the distinct raw values on
   tree split once, up front: for rules tried on one element at a time. *)
materialiser[_, {}] := Identity;
materialiser[tree_, readings_] :=
  With[{maps = {First[#], tokenMap[tree, #, {0, Infinity}]} & /@ readings},
    attachTokens[maps, #] &];

attachTokens[maps_, XMLElement[t_, a_List, c_]] :=
  XMLElement[t, Join[a, Function[{key, map}, tok[key] -> Lookup[map, Lookup[a, key, None], {}]] @@@ maps], c];

(* Every token list removed, at any depth, from whatever a name or a test can
   see: an element, an attribute list, a list of copied attribute lists, or a
   sequence of these (a name on a run of children binds a Sequence). It is
   exact because nothing else in a tree has the head tok. *)
unmaterialised[xs___] := Sequence @@ DeleteCases[{xs}, _tok -> _, Infinity];
