(* ::Package:: *)
(* HTMLPatterns: the element-pattern compiler *)

(* Used by CSSSelector.wl *)
PackageScoped[conditionWith]

(* Used by Query/TreePatterns.wl *)
PackageScoped[compileWith]
PackageScoped[xmlPatternFormQ]
PackageScoped[innermostHead]
PackageScoped[xmlPatternParts]
PackageScoped[xmlPatternPartsOrRefuse]
PackageScoped[bodyConditionQ]

(* Used by Positions.wl, Query/TreePatterns.wl, Readings.wl and Rewrite.wl *)
PackageScoped[$refusal]
PackageScoped[refuse]

(* Used by Query/TreePatterns.wl and Tree.wl *)
PackageScoped[badQuery]
PackageScoped[$queryOption]

(* Used by XMLFunctions.wl *)
PackageScoped[elementMatcher]

(* =========================================================== *)
(* The element-pattern compiler                                 *)
(*                                                              *)
(* compileWith[pattern, head, readings] -> the plain WL pattern *)
(* an element pattern is, under the readings: an Association    *)
(*   "Plain"      the pattern, in its two-step form (solvable)  *)
(*   "Readings"   the readings of the list keys it names ({}    *)
(*                when it names none, in which case it runs on  *)
(*                the element as it is)                         *)
(* An element pattern is an XMLPattern[tag] or XMLPattern[tag,  *)
(* attrs], a CSS selector string that gives one, or             *)
(* alternatives of these, any of them named, with a Condition   *)
(* or a test. The tree-pattern engine (Query/TreePatterns.wl)   *)
(* compiles the tag and attributes of each XMLPattern here, and *)
(* XMLMatchQ tests a pattern root of these with one MatchQ      *)
(* (elementMatcher). Refusals message under XMLPattern (an XML  *)
(* pattern's own shape) or under head, and give $Failed.        *)
(*                                                              *)
(* When a list key is named, every binding that can see an      *)
(* element's attributes \[LongDash] an element binding e : XMLPattern[...],  *)
(* or a name or test on the attribute argument \[LongDash] is renamed to a   *)
(* fresh symbol, and each place that can see the name (a        *)
(* Condition's test) is wrapped in                              *)
(* With[{e = unmaterialised[e$]}, ...], so it sees the original *)
(* element.                                                     *)
(* A pattern is compiled once to learn its list keys and, only  *)
(* if it names one, again with the renaming on.                 *)
(* =========================================================== *)

compileWith[_, _, $Failed] := $Failed;
compileWith[q_, head_, readings_Association] :=
  Catch[
    Module[{p, keys, stringKeys},
      {p, keys, stringKeys} = compilePass[q, head, readings, False];
      If[keys =!= {}, p = First @ compilePass[q, head, readings, True]];
      Scan[warnLookalikeListKey[readings], stringKeys];
      <|"Plain" -> solvable[p], "Readings" -> Lookup[readings, keys]|>],
    $refusal];

compilePass[q_, head_, readings_, mat_] :=
  Block[{$head = head, $readings = readings, $mat = mat, $fresh = <||>},
    With[{r = Reap[First @ Reap[cElem[q], $bindTag], {$listKeyTag, $stringKeyTag}]},
      {First[r], Union @@ r[[2, 1]], Join @@ r[[2, 2]]}]];

(* A function that tests one element, or $Failed if the pattern is refused.
   Only the element itself is materialised: its children cannot be reached. *)
elementMatcher[q_, head_] :=
  Replace[compileWith[q, head, readingsInForce[]], {
    $Failed -> $Failed,
    c_ :> With[{p = c["Plain"], r = c["Readings"]},
      If[r === {}, MatchQ[p], Function[el, MatchQ[materialise[el, r, {0}], p]]]]}];

(* A key that looks like a list key but is not one in force is still matched as
   an attribute of that name, as an explicit list key can name a real attribute
   (ADR 0012), so it is only warned about, once the query has compiled, from the
   string keys the first pass sees, and only once per call. *)
warnLookalikeListKey[readings_][k_] /; StringEndsQ[k, "List"] && StringLength[k] > 4 && !KeyExistsQ[readings, k] &&
    firstWarningQ[k] :=
  With[{raw = StringDrop[k, -4]},
    Replace[FirstCase[Normal[readings], (listKey_ -> {raw, _}) :> listKey], {
      Missing[__] :> Message[XMLPattern::nolistreading, k, raw],
      listKey_ :> Message[XMLPattern::otherlistkey, k, raw, listKey]}]];
warnLookalikeListKey[_][_] := Null;

(* True, and the key recorded as warned about, unless the call has warned about it. *)
firstWarningQ[_] /; $warnedListKeys === None := True;
firstWarningQ[k_] := !KeyExistsQ[$warnedListKeys, k] && ($warnedListKeys[k] = True);

(* Held, since a MessageName evaluates to its text. *)
SetAttributes[refuse, HoldFirst];
refuse[msg_, args___] := (Message[msg, args]; Throw[$Failed, $refusal]);
(* An upstream failure has already said what went wrong. *)
refuseQuietly[] := Throw[$Failed, $refusal];

(* A pattern that is not an element pattern is the consumer's badpat, or for
   a query of HTMLToTree the option's, badquery. MessageName holds its first
   argument, so the consumer head is injected. *)
badpat[q_] /; $queryOption =!= None := (badQuery[$queryOption, q]; Throw[$Failed, $refusal]);
badpat[q_] := With[{h = $head}, refuse[MessageName[h, "badpat"], q]];

(* The option a query of HTMLToTree is compiled for, or None. *)
$queryOption = None;

(* The message for a query that is refused, from the settings or the compiler *)
badQuery[name_, v_] := Message[HTMLToTree::badquery, name, $treeQueryOff[name], v];

(* ---- Element patterns ---- *)

(* An XMLPattern with constraints is no element pattern: what is below the
   element is the tree-pattern engine's. *)
cElem[x_ /; xmlPatternFormQ[x]] :=
  Replace[xmlPatternPartsOrRefuse[x, badpat], {{args_, {}} :> cXMLPattern[args], _ :> badpat[x]}];
(* A string is a CSS selector, and means its translation (ADR 0026). *)
cElem[s_String] :=
  Replace[cssTree[s], {$Failed :> refuseQuietly[], {"one", t_} :> cElem[t], _ :> badpat[s]}];
cElem[alts_Alternatives] := Alternatives @@ (cElem /@ List @@ alts);
cElem[Verbatim[Pattern][s_Symbol, p_]] := bindAs[s, cElem[p]];
cElem[c_Condition] := conditioned[cElem, c, conditionWith];
(* pat?f is n : pat /; f[n]: f sees the original element, as a name does. *)
cElem[Verbatim[PatternTest][p_, test_]] := testAs[cElem[p], test];
cElem[q_] := badpat[q];

(* A Condition's test sees the names bound in its left-hand side, compiled by
   comp; attach puts the held test on the compiled left-hand side. *)
conditioned[comp_, c_, attach_] :=
  Module[{lhs, binds},
    {lhs, binds} = reapBinds[comp[c[[1]]]];
    Scan[Sow[#, $bindTag] &, binds];
    attach[lhs, wrapBinds[unmaterialised, binds, Extract[c, {2}, Hold]]]];

(* p /; test, from a held test. *)
conditionWith[p_, test_Hold] := Condition @@ Join[Hold[p], test];

cXMLPattern[{tag_}] := XMLElement[cTag[tag], _, _];
cXMLPattern[{tag_, attrs_}] := With[{t = cTag[tag]}, XMLElement[t, cAttrs[attrs], _]];

(* ---- The parts of an XMLPattern ----

   The one place that reads an XMLPattern's tag, attributes and constraints,
   written XMLPattern[tag, attrs][c...], with attrs optional and the bracket
   possibly empty. xmlPatternParts[x] gives {{tag}, {c...}} or
   {{tag, attrs}, {c...}}: the arguments of XMLPattern itself, and the
   constraints. It gives chained[merged] for a pattern with constraints in
   more than one bracket, p[a][b], merged the one way to write it, p[a, b];
   attrsThen[bracketed] for constraints after the attributes,
   XMLPattern[tag, attrs, c...], which is no pattern, bracketed its bracket
   form; and None for anything else. *)

xmlPatternFormQ[x_] := !AtomQ[x] && innermostHead[x] === XMLPattern;

(* The head that x's heads lead down to, as "sel" for "sel"[a][b]. *)
innermostHead[x_] := NestWhile[Head, x, !AtomQ[#] &];

xmlPatternParts[XMLPattern[args : Repeated[_, {1, 2}]]] := {{args}, {}};
xmlPatternParts[XMLPattern[tag_, attrs_, cs__]] := attrsThen[XMLPattern[tag, attrs][cs]];
xmlPatternParts[(h_)[cs___]] /; xmlPatternFormQ[h] :=
  Replace[xmlPatternParts[h], {
    {head_, {}} /; !MatchQ[h, (_)[___][___]] :> {head, {cs}},
    {head_, prior_} :> chained[(XMLPattern @@ head) @@ Join[prior, {cs}]],
    (chained | attrsThen)[XMLPattern[args__][prior___]] :> chained[XMLPattern[args][prior, cs]],
    _ -> None}];
xmlPatternParts[_] := None;

(* The parts of x, an XMLPattern; a chain is refused with XMLPattern::chain,
   constraints after the attributes with XMLPattern::attrsthen, anything else
   by notOne[x], as the caller's badpat: each package has its own $head. *)
xmlPatternPartsOrRefuse[x_, notOne_] :=
  Replace[xmlPatternParts[x], {
    chained[m_] :> refuse[XMLPattern::chain, x, m],
    attrsThen[b_] :> refuse[XMLPattern::attrsthen, x, b],
    None :> notOne[x]}];

cTag[tag_] := (
  noStringPatterns[tag];
  If[!validTagQ[tag], refuse[XMLPattern::badtag, tag]];
  tag);

noStringPatterns[p_] :=
  Replace[barePatterns[p], {s_, ___} :> refuse[XMLPattern::strpat, s]];

(* ---- The attribute argument ---- *)

cAttrs[$Failed] := refuseQuietly[];
cAttrs[Verbatim[Pattern][s_Symbol, inner_]] := bindAs[s, cAttrs[inner]];
(* A test on the whole attribute map sees the original map. *)
cAttrs[Verbatim[PatternTest][inner_, test_]] := testAs[cAttrs[inner], test];
cAttrs[Verbatim[_]] := _;
cAttrs[rules_List] :=
  With[{kvp = KeyValuePattern[cRule /@ rules]}, noDuplicateKeys[rules]; kvp];
cAttrs[r_Rule] := cAttrs[{r}];
(* A list is always the rule list, so a bare namespaced key is written {{ns, name}}. *)
cAttrs[k : (_String | _Alternatives)] /; literalKeyQ[k] := cAttrs[{k}];
cAttrs[a_] := refuse[XMLPattern::badattrs, a];

cRule[$Failed] := refuseQuietly[];
cRule[Verbatim[Rule][k_, v_]] :=
  Module[{listKeys},
    If[!literalKeyQ[k], refuse[XMLPattern::badkey, k]];
    Scan[Sow[#, $stringKeyTag] &, Select[keyLiterals[k], StringQ]];
    noStringPatterns[v];
    listKeys = Select[keyLiterals[k], StringQ[#] && KeyExistsQ[$readings, #] &];
    Scan[Sow[#, $listKeyTag] &, listKeys];
    slotKey[k] -> If[Length[listKeys] === Length[keyLiterals[k]], desugar[v], v]];
cRule[k_?literalKeyQ] := cRule[k -> _];
cRule[k_] := refuse[XMLPattern::badkey, k];

(* A list key compiles to its private slot; every other key is itself. *)
slotKey[Verbatim[Alternatives][ks__]] := Alternatives @@ (slotKey /@ {ks});
slotKey[k_String] /; KeyExistsQ[$readings, k] := tok[rawKeyOf[$readings[k]]];
slotKey[k_] := k;

(* The one desugaring (ADR 0011): at a list key, a literal string or an
   Alternatives of literal strings can never match a list as written, so it
   means "contains this token". Nothing else is rewritten. *)
desugar[s : (_String | Verbatim[Alternatives][__String])] := {___, s, ___};
desugar[v_] := v;

(* KeyValuePattern demands distinct elements, so two rules on one key are a
   silent False however each would match alone. An Alternatives key may share
   a key with another rule, as each can take a different attribute. *)
noDuplicateKeys[rules_] :=
  Replace[
    Select[Tally[DeleteCases[Replace[#, Verbatim[Rule][k_, _] :> k] & /@ rules, _Alternatives]],
      Last[#] > 1 &],
    {{k_, _}, ___} :> refuse[XMLPattern::dupkey, k]];

(* ---- Bindings ---- *)

(* The same name gets the same fresh symbol throughout a pattern, so that
   (e : XMLPattern["a"]) | (e : XMLPattern["b"]) still binds one name:
   materialisation is the same on equal elements. A record is the name and its fresh symbol, whatever the
   name binds, so one name has one record (issue #52). *)
SetAttributes[bindAs, HoldFirst];
bindAs[s_, p_] :=
  If[!$mat,
    namedPattern[s, p],
    With[{fresh = If[KeyExistsQ[$fresh, Hold[s]], $fresh[Hold[s]],
        $fresh[Hold[s]] = freshSymbol[]]},
      Sow[{Hold[s], fresh}, $bindTag];
      namedPattern[fresh, p]]];

(* p?f, with f seeing the original value, as a name does: on a materialised
   tree, f is given the value with its token lists removed. f is held, as in
   the query, and the choice is made outside PatternTest, which holds its
   test. *)
SetAttributes[testAs, HoldRest];
testAs[p_, f_] := If[$mat, PatternTest[p, Function[x, f[unmaterialised[x]]]], PatternTest[p, f]];

(* A temporary private symbol, so nothing is left in the caller's context. *)
freshSymbol[] := Module[{bound}, bound];

(* s : p, built without a literal Pattern on a right-hand side. *)
SetAttributes[namedPattern, HoldFirst];
namedPattern[s_, p_] := Pattern @@ Hold[s, p];

(* Held, so that the bindings its argument sows are reaped here. *)
SetAttributes[reapBinds, HoldFirst];
reapBinds[expr_] :=
  MapAt[DeleteDuplicates[Join @@ #] &, Reap[expr, $bindTag], 2];

(* Hold[body] -> Hold[With[{e = inverse[e$], ...}, body]]

   The two-step match (restored, below) renames an element name a second time
   and wraps what this gives, so the two compose as
   With[{e$ = uncopied[e$$]}, With[{e = unmaterialised[e$]}, body]]. The two
   inverses commute: unmaterialised removes token lists at any depth, from a
   list of copies of an attribute list as from the list itself, so the order
   the wrappers stack in does not change what the name sees. Issue #3 proposes
   one module for both renamings.

   Only the names written in held are restored, also those inside held code
   within it: unmaterialised is linear in an element's subtree. With replaces a name only where it is
   written, so a name reached otherwise, as Symbol["e"], never saw the restored
   value, and leaving it out changes nothing. *)
wrapBinds[inverse_, binds_, held_Hold] :=
  withBinds[inverse, Select[binds, !FreeQ[held, Replace[First[#], Hold[s_] :> HoldPattern[s]]] &], held];

withBinds[_, {}, held_Hold] := held;
withBinds[inverse_, binds_, held_Hold] :=
  With[{spec = Replace[
      Join @@ (Replace[#, {Hold[s_], fresh_} :> Hold[s = restore[inverse, fresh]]] & /@ binds),
      Hold[sets___] :> Hold[{sets}]]},
    Replace[Join[spec, held], Hold[vars_, body_] :> Hold[With[vars, body]]]];

(* A name bound only in an Alternatives branch that did not match is Sequence[],
   as in WL, and stays so when restored (issue #18). *)
restore[_] := Sequence[];
restore[inverse_, xs__] := inverse[xs];

(* ---- Conditions over a KeyValuePattern ---- *)

(* WL tests a Condition around a nested KeyValuePattern as soon as the first of
   its rules is matched, with the names of the later rules bound to nothing, and
   a False then is final: XMLPattern["a", {"href" -> h_, "data-id" -> i_}] /;
   StringContainsQ[h, i] never matches. {OrderlessPatternSequence[rules..., ___]} binds them all but costs the
   factorial of the attribute count (ADR 0007: seconds at six rules).

   So a pattern with such a Condition is matched in two steps. Its
   skeleton, with no names and no Conditions, finds the candidates as fast as a
   plain query. Each candidate is then matched with plain list patterns only:
   each element's attribute list is repeated, and each rule of a
   KeyValuePattern is matched, as {___, rule, ___}, in a copy of its own, the
   first copy keeping the KeyValuePattern as a test with no names. Each rule
   matches a different attribute, as KeyValuePattern requires. An element name
   sees the element with one attribute list, restored around each test that
   can see it. Any other pattern is left as it is. *)
solvable[p_] /; twoStepQ[p] :=
  With[{v = freshSymbol[], n = copyCount[p], c = copiedPattern[p]},
    Condition @@ Join[Hold @@ {namedPattern[v, skeleton[p]]}, Hold[MatchQ[copied[v, n], c]]]];
solvable[x_] := x;

twoStepQ[p_] := brokenConditionsQ[p] || overlappingKeysQ[p];

(* A KeyValuePattern with a name after its first rule. *)
laterNamesQ[p_] :=
  !FreeQ[Unevaluated[p], Verbatim[KeyValuePattern][{_, rest__}] /; !FreeQ[Unevaluated[{rest}], Verbatim[Pattern][_Symbol, _]]];

brokenConditionsQ[p_] := !FreeQ[p, Verbatim[Condition][l_, _] /; laterNamesQ[l]];

(* A KeyValuePattern with an Alternatives key that shares a key with another of
   its rules. WL does not backtrack over which attribute the Alternatives key
   takes: MatchQ[{"x" -> 1, "y" -> 2}, KeyValuePattern[{("x" | "y") -> _,
   "x" -> _}]] is False. So such a pattern is matched in two steps too, with or
   without a Condition, and its skeleton leaves out those Alternatives rules. *)
overlappingKeysQ[p_] := !FreeQ[p, Verbatim[KeyValuePattern][r_List] /; MemberQ[overlapping[r], True]];

(* For each rule, whether it is an Alternatives rule whose key shares a key with
   another rule. *)
overlapping[rules_List] :=
  With[{keys = Replace[rules, {Verbatim[Rule][k_, _] :> DeleteDuplicates[keyLiterals[k]], _ -> {}}, {1}]},
    MapIndexed[
      MatchQ[rules[[First[#2]]], Verbatim[Rule][_Alternatives, _]] &&
        IntersectingQ[#1, Join @@ Delete[keys, #2]] &, keys]];

(* Whether a held right-hand side is a Condition, which WL reads as a test on
   the match: at its top, or at the top of a With, Module or Block. *)
bodyConditionQ[Hold[_Condition]] := True;
bodyConditionQ[Hold[(With | Module | Block)[_, body_]]] := bodyConditionQ[Hold[body]];
bodyConditionQ[_] := False;

(* The pattern with no names and no Conditions, which every match matches. *)
skeleton[Verbatim[KeyValuePattern][r_List]] /; MemberQ[overlapping[r], True] :=
  KeyValuePattern[skeleton /@ Pick[r, overlapping[r], False]];
skeleton[Verbatim[Pattern][_, p_]] := skeleton[p];
skeleton[Verbatim[Condition][l_, _]] := skeleton[l];
skeleton[Verbatim[PatternTest][p_, f_]] := PatternTest[skeleton[p], f];
skeleton[v_Verbatim] := v;
skeleton[h_[args___]] := skeleton[h] @@ (skeleton /@ {args});
skeleton[x_] := x;

(* The candidate element, with its attribute list repeated n times. *)
copied[XMLElement[t_, a_List, c_], n_] := XMLElement[t, ConstantArray[a, n], c];
copied[x_, _] := x;

(* An element, or each of a sequence of them. *)
uncopied[xs___] := Sequence @@ Replace[{xs}, XMLElement[t_, {a_, ___}, c_] :> XMLElement[t, a, c], {1}];

copyCount[p_] := 1 + Max[0, Cases[p, Verbatim[KeyValuePattern][r_List] :> Length[r], {0, Infinity}]];

copiedPattern[p_] := Block[{$renamed = renaming[p]}, copiedIn[p]];

(* Each name that binds an element is renamed, and is the uncopied element in
   each test that can see it. When the pattern names a list key, the name was
   already renamed for materialisation; see wrapBinds for how the two
   compose. A test is restored for every renamed name its left-hand side
   binds. *)
renaming[p_] := Association[# -> freshSymbol[] & /@ elementNames[p]];

(* The names a pattern binds, outside the tests in it, which bind nothing the
   pattern sees. *)
boundNames[x_] := namesIn[x //. {Verbatim[PatternTest][p_, _] :> p, Verbatim[Condition][p_, _] :> p}];

restored[l_, held_Hold] :=
  wrapBinds[uncopied, {#, $renamed[#]} & /@ Select[boundNames[l], KeyExistsQ[$renamed, #] &], held];

copiedIn[Verbatim[Pattern][s_, p_]] /; KeyExistsQ[$renamed, Hold[s]] :=
  With[{f = $renamed[Hold[s]]}, namedPattern[f, copiedIn[p]]];
copiedIn[Verbatim[Pattern][s_, p_]] := namedPattern[s, copiedIn[p]];
copiedIn[c : Verbatim[Condition][l_, _]] :=
  Condition @@ Join[Hold @@ {copiedIn[l]}, restored[l, Extract[c, {2}, Hold]]];
copiedIn[XMLElement[t_, a_, c_]] := XMLElement[t, copiedAttributes[a], c];
(* copiedIn reaches only tests on an element (copiedAttributes keeps the tests
   on attributes). The first step ran them on the skeleton, but a branch of an
   Alternatives must fail its test here too, on the uncopied element. *)
copiedIn[Verbatim[PatternTest][p_, f_]] := PatternTest[copiedIn[p], Function[e, f[uncopied[e]]]];
copiedIn[h_[args___]] := copiedIn[h] @@ (copiedIn /@ {args});
copiedIn[x_] := x;

(* {first, {___, rule1, ___}, ..., ___}: first is the attribute argument, which
   sees the original list, with its KeyValuePattern made a test. *)
copiedAttributes[a_] :=
  With[{rules = attributeRules[a]},
    With[{marks = Table[freshSymbol[], Length[rules]]},
      With[{list = Join[{firstCopy[a]}, MapThread[{___, namedPattern[#1, #2], ___} &, {marks, rules}], {___}]},
        If[Length[rules] < 2, list, Condition @@ Join[Hold[list], Hold[DuplicateFreeQ[marks]]]]]]];

attributeRules[Verbatim[KeyValuePattern][r_List]] := r;
attributeRules[Verbatim[Pattern][_, p_]] := attributeRules[p];
attributeRules[Verbatim[PatternTest][p_, _]] := attributeRules[p];
attributeRules[_] := {};

firstCopy[k : Verbatim[KeyValuePattern][_List]] := With[{sk = skeleton[k]}, _?(MatchQ[sk])];
firstCopy[Verbatim[Pattern][s_, p_]] := namedPattern[s, firstCopy[p]];
firstCopy[Verbatim[PatternTest][p_, f_]] := PatternTest[firstCopy[p], f];
firstCopy[x_] := x;

(* The names that bind an element, not those in its children or tests. *)
elementNames[p_] := DeleteDuplicates @ Flatten[Last @ Reap[sowElementNames[p]]];
sowElementNames[Verbatim[Pattern][s_Symbol, p_]] :=
  (If[!FreeQ[p, XMLElement], Sow[Hold[s]]]; sowElementNames[p]);
sowElementNames[Verbatim[Condition][l_, _]] := sowElementNames[l];
sowElementNames[Verbatim[PatternTest][p_, _]] := sowElementNames[p];
sowElementNames[_XMLElement] := Null;
sowElementNames[_[args___]] := Scan[sowElementNames, {args}];
sowElementNames[_] := Null;
