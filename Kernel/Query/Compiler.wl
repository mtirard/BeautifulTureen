(* ::Package:: *)
(* HTMLPatterns: the query compiler *)

(* Used by CSSSelector.wl *)
PackageScoped[mirrored]
PackageScoped[spliced]

(* Used by CSSSelector.wl and Query/Chains.wl *)
PackageScoped[conditionWith]

(* Used by DisplayRoles.wl *)
PackageScoped[compileWith]

(* Used by Query/Chains.wl *)
PackageScoped[copied]
PackageScoped[gapsQ]
PackageScoped[lengthsUpTo]
PackageScoped[namedPattern]
PackageScoped[recognisedQ]
PackageScoped[selectedEntry]
PackageScoped[stageNames]
PackageScoped[$anyLength]
PackageScoped[$recognisedMethods]
PackageScoped[listStage]
PackageScoped[anywhere]
PackageScoped[amongChildren]
PackageScoped[amongMatching]
PackageScoped[ordered]
PackageScoped[measured]
PackageScoped[generalMatcher]
PackageScoped[counted]
PackageScoped[tested]
PackageScoped[placed]
PackageScoped[lengthIn]
PackageScoped[tagCountIn]
PackageScoped[countIn]
PackageScoped[matchIn]

(* Used by Query/Chains.wl and Query/Run.wl *)
PackageScoped[bodyConditionQ]
PackageScoped[solvable]
PackageScoped[$unmatched]

(* Used by Readings.wl *)
PackageScoped[refuse]
PackageScoped[$refusal]

(* Used by Tree.wl *)
PackageScoped[badQuery]
PackageScoped[$queryOption]

(* Used by Tree.wl and XMLFunctions.wl *)
PackageScoped[compileQuery]

(* Used by XMLFunctions.wl *)
PackageScoped[$recogniseShapes]

(* =========================================================== *)
(* The query compiler                                           *)
(*                                                              *)
(* compileQuery[query, head] -> the query's normal form under  *)
(* the readings in force: an Association every decision about  *)
(* the query reads:                                             *)
(*   "Stages"     the compiled element patterns, in chain order, *)
(*                and list stages, listStage[...] (see List      *)
(*                stages), which only follow a Child or          *)
(*                Descendant link                                *)
(*   "Links"      the combinator heads between them ({} for a   *)
(*                plain query, which has one stage)             *)
(*   "Conditions" {{i, j}, Hold[test]} for each Condition on a  *)
(*                combinator, over its stages i to j, innermost *)
(*                first                                         *)
(*   "Body"       the rule's held body, or None                 *)
(*   "Readings"   the readings of the list keys it names ({}    *)
(*                when it names none, in which case it runs on  *)
(*                the tree as it is)                            *)
(*   "Head"       the consumer, whose messages refusals use     *)
(*   "Query"      the query as written, for messages            *)
(*   "ContextEntries" the normal forms of the context combinator *)
(*                entries of its list stages, by key            *)
(*   "Recognition" whether shapes were recognised when it was    *)
(*                compiled ($recogniseShapes)                    *)
(* Each list stage in "Stages" also carries how it runs, its     *)
(* "Method" (see List stage methods): a recognised shape with    *)
(* its parameters, or the general matcher with its rule. The     *)
(* runners read it and do not inspect the list's pattern.        *)
(* How the rest runs is decided once too, and the runners read  *)
(* it (see runnable); the two-step match (solvable) is applied  *)
(* here and never by a runner. A plain query, one stage and no  *)
(* link, has                                                    *)
(*   "Plain"      the pattern or rule it runs                   *)
(* and a chain, each alternative of a query of "Alternatives"   *)
(* and each compiled query in "ContextEntries" has              *)
(*   "Chain"      the stages and links, alternating, as the     *)
(*                chain runner reads them                       *)
(*   "StagesDecide" whether the stages' own matches decide a    *)
(*                tuple (see Chains)                            *)
(*   "TupleTest"  the test a tuple of sites passes, or None     *)
(*                when the stages decide                        *)
(*   "TupleRule"  the rule a tuple of elements is given to, or  *)
(*                None when there is no body                    *)
(* Refusals message under XMLPattern (an XML pattern's own      *)
(* shape) or under head and give $Failed. Which query shapes an *)
(* operation can run is the operation's to check, on the normal *)
(* form (see Running a compiled query).                         *)
(*                                                              *)
(* When a list key is named, every binding that can see an      *)
(* element's attributes \[LongDash] an element binding e : XMLPattern[...],  *)
(* or a name or test on the attribute argument \[LongDash] is renamed to a   *)
(* fresh symbol, and each place that can see the name (a rule   *)
(* body, a Condition's test) is wrapped in                      *)
(* With[{e = unmaterialised[e$]}, ...], so it sees the original *)
(* element.                                                     *)
(* A query is compiled once to learn its list keys and, only if *)
(* it names one, again with the renaming on.                    *)
(* =========================================================== *)

compileQuery[q_, head_] := compileWith[q, head, readingsInForce[]];

(* Whether the compiler recognises shapes (ADR 0020). Block it to False to run
   every list stage on the general matcher, as WL's matcher runs the pattern as
   written, to check a recognised method against it. *)
$recogniseShapes = True;

(* With the readings table resolved, for a caller that compiles several queries
   against one table. *)
compileWith[_, _, $Failed] := $Failed;
compileWith[q_, head_, readings_Association] :=
  Catch[
    Module[{query, keys, contexts, stringKeys},
      {query, keys, contexts, stringKeys} = compilePass[q, head, readings, False];
      If[keys =!= {}, {query, contexts} = compilePass[q, head, readings, True][[{1, 3}]]];
      Scan[warnLookalikeListKey[readings], stringKeys];
      Join[runnable[withMethods[query]], <|"Readings" -> Lookup[readings, keys], "Head" -> head, "Query" -> q,
        "ContextEntries" -> runnableChain @* withMethods /@ contexts, "Recognition" -> $recogniseShapes|>]],
    $refusal];

compilePass[q_, head_, readings_, mat_] :=
  Block[{$head = head, $holder = head, $readings = readings, $mat = mat, $fresh = <||>, $listSources = <||>,
      $atStart = True, $firstOfLink = False},
    With[{r = Reap[First @ Reap[cQuery[q], $bindTag], {$listKeyTag, $contextTag, $stringKeyTag}]},
      {First[r], Union @@ r[[2, 1]], contextEntries[First[r], Join @@ r[[2, 2]]], Join @@ r[[2, 3]]}]];

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

(* The compiled query with the fields that say how it runs (see the header). *)
runnable[q_] /; unionQ[q] := MapAt[runnableChain, q, {Key["Alternatives"], All}];
runnable[q_] /; chainQ[q] := runnableChain[q];
runnable[q_] := Append[q, "Plain" -> plainQuery[q]];

runnableChain[q_] :=
  Join[q, <|"Chain" -> chainOf[q], "StagesDecide" -> stagesDecideQ[q], "TupleTest" -> tupleTest[q],
    "TupleRule" -> If[q["Body"] === None, None, tupleRule[q]]|>];

(* Held, since a MessageName evaluates to its text. *)
SetAttributes[refuse, HoldFirst];
refuse[msg_, args___] := (Message[msg, args]; Throw[$Failed, $refusal]);
(* An upstream failure (CSSClass::obs) has already said what went wrong. *)
refuseQuietly[] := Throw[$Failed, $refusal];

(* MessageName holds its first argument, so the consumer head is injected. *)
refuseAtHead[tag_, args___] := refuseAt[$head, tag, args];
badpat[q_] := refuseAtHead["badpat", q];

(* A message goes on the innermost symbol the mistake is in (ADR 0022): a
   combinator used wrongly, or the combinator whose argument is wrong, which is
   $holder while that argument is compiled. A consumer that takes only an
   element pattern refuses any combinator, so there the message stays its own. *)
refuseAt[h_, tag_, args___] /; h === $head && $queryOption =!= None :=
  (badQuery[$queryOption, First[{args}]]; Throw[$Failed, $refusal]);
refuseAt[h_, tag_, args___] := refuse[MessageName[h, tag], args];
holderFor[h_] := If[MatchQ[$head, XMLCases | XMLFirstCase | XMLDeleteCases] || $queryOption =!= None, h, $head];

(* The option a query of HTMLToTree is compiled for, or None. Such a query is
   searched with, as XMLCases's is, so a mistake in a combinator is the
   combinator's; a mistake at its top level is the option's, as badquery. *)
$queryOption = None;

(* The message for a query that is refused, from the settings or the compiler *)
badQuery[name_, v_] := Message[HTMLToTree::badquery, name, $treeQueryOff[name], v];

(* The first combinator in a tested pattern, as written. *)
firstCombinator[s_String] := firstCombinator[cssPattern[s]];
firstCombinator[(h : $links)[___]] := h;
firstCombinator[alts_Alternatives] := FirstCase[firstCombinator /@ List @@ alts, $links, None];
firstCombinator[p_] := With[{b = patternBase[p]}, If[b === p, None, firstCombinator[b]]];

(* Alternatives of list stages hold no combinator; their test is the holder's. *)
refuseTestedCombinator[t : Verbatim[PatternTest][x_, _]] :=
  refuseAt[holderFor[Replace[firstCombinator[x], None -> $holder]], "testcombinator", t];

(* ---- Queries: a rule over a pattern, or a pattern ---- *)

cQuery[r_RuleDelayed] := ruleQuery[r[[1]], Extract[r, {2}, Hold]];
(* A Rule's right-hand side was evaluated when the query was given, as in
   Cases, and its value is the body. A Condition in the value is part of it,
   not a test on the match, as in Cases. *)
cQuery[r : Verbatim[Rule][_, _]] := ruleQuery[r[[1]], literalBody[Extract[r, {2}, Hold]]];
cQuery[q_] := normalForm[cStage[q], None];

ruleQuery[lhs_, body_Hold] :=
  Module[{stages, binds},
    {stages, binds} = reapBinds[cStage[lhs]];
    normalForm[stages, wrapBinds[unmaterialised, binds, body]]];

(* Identity keeps a Condition from being the top of the body, where it would
   be a test. *)
literalBody[Hold[c_Condition]] := Hold[Identity[c]];
literalBody[body_Hold] := body;

(* A list stage needs a parent: as the whole query or as a first stage it has
   none. *)
normalForm[chain[{ls_listStage, rest___}, _, _], _] :=
  refuseList[If[{rest} === {}, "query", "first"], ls];
normalForm[chain[stages_, links_, conditions_], body_] :=
  <|"Stages" -> stages, "Links" -> links, "Conditions" -> conditions, "Body" -> body|>;
(* Alternatives holding a combinator are the list of their chains, each with
   the body in which the names the query binds and it does not are Sequence[]
   (ADR 0015). *)
normalForm[union[cs_], body_] :=
  <|"Alternatives" -> perAlternative[cs, body, normalForm], "Body" -> body|>;

(* A combinator's stages are element patterns or combinators, compiled to
   chain[stages, links, conditions]. A Condition on a combinator sees the names
   of all its stages, and covers them. L[s1, s2, ..., sn] is the right-nested
   chain L[s1, L[s2, ..., sn]]; one stage or none is refused. *)
(* A string is a CSS selector, and means its translation (ADR 0017): one that
   gives a combinator is spliced into the chain, as any combinator stage is. *)
cStage[s_String] := cStage[stageTranslation[s]];
cStage[c : Verbatim[Condition][_String, _]] := cStage[conditionWith[stageTranslation[c[[1]]], Extract[c, {2}, Hold]]];

(* After the start of a chain no stage is the document, so a translation that
   starts with any parent, the document or an element, starts with an element;
   one that needs the document, as :root does, cannot stand there. *)
stageTranslation[s_] :=
  With[{t = cssPattern[s]},
    If[$atStart, t,
      Replace[t /. Verbatim[XMLDocument[] | XMLPattern[_]] -> XMLPattern[_], u_ /; documentQ[u] :> badpat[s]]]];
(* A list, named, conditioned or tested, is a list stage (ADR 0016), one chain
   for each alternative of its selected entry. A name on alternatives of lists
   is the name on each. *)
cStage[l_] /; listFormQ[l] := Block[{$atStart = False}, toUnion[listChains[l]]];
cStage[Verbatim[Pattern][s_Symbol, alts_Alternatives]] /; AllTrue[List @@ alts, listFormQ] :=
  cStage[Alternatives @@ (namedPattern[s, #] & /@ List @@ alts)];
(* The document can be only the first stage of a chain (ADR 0018): $atStart
   while a stage at the start of the query is compiled, $firstOfLink while it is the
   first argument of a combinator. *)
cStage[(h : $links)[a_, b_]] :=
  Block[{$holder = holderFor[h]},
    joinChains[noFirstList[Block[{$firstOfLink = True}, cStage[a]]], h, Block[{$atStart = False}, cStage[b]]]];
cStage[(h : $links)[a_, b_, rest__]] := cStage[h[a, h[b, rest]]];
cStage[q : $links[RepeatedNull[_, 1]]] := refuseAt[holderFor[Head[q]], "stages", q];
cStage[c_Condition] /; multiStageQ[patternBase[c]] := conditioned[cStage, c, coverChain];
(* A test on a combinator would only restate a test on its last stage, so it is
   refused until a CSS selector string can be a combinator (ADR 0014). *)
cStage[t : Verbatim[PatternTest][x_, _]] /; multiStageQ[patternBase[x]] := refuseTestedCombinator[t];
(* Alternatives holding a combinator are union[{chain, ...}], one chain per
   alternative, in written order (ADR 0015). Alternatives of element patterns
   stay one stage. *)
cStage[alts_Alternatives] /; AnyTrue[List @@ alts, multiStageQ] := toUnion[Join @@ (chainsOf[cStage[#]] & /@ List @@ alts)];
cStage[q_] := chain[{cElem[q]}, {}, {}];

(* A list stage needs a parent, so it cannot start the query's chain. Refused
   here, in the combinator, rather than in normalForm. *)
noFirstList[c_] :=
  (If[$atStart, Replace[chainsOf[c], {___, chain[{ls_listStage, ___}, _, _], ___} :> refuseList["first", ls]]]; c);

chainsOf[union[cs_]] := cs;
chainsOf[c_chain] := {c};

toUnion[{c_}] := c;
toUnion[cs_] := union[cs];

(* A list stage lists the children of the element before it, so a sibling link
   cannot lead to one. *)
joinChains[_chain, Adjacent | Sibling, chain[{ls_listStage, ___}, _, _]] := refuseList["sibling", ls];
joinChains[chain[s1_, l1_, c1_], link_, chain[s2_, l2_, c2_]] :=
  chain[Join[s1, s2], Join[l1, {link}, l2],
    Join[c1, Replace[c2, {span_, test_} :> {span + Length[s1], test}, {1}]]];
(* A stage that is alternatives distributes: the chains of the product, the
   leftmost alternative most significant. *)
joinChains[a_, link_, b_] :=
  toUnion[Flatten[Outer[joinChains[#1, link, #2] &, chainsOf[a], chainsOf[b], 1]]];

coverChain[chain[s_, l_, c_], test_] := chain[s, l, Append[c, {{1, Length[s]}, test}]];
(* A Condition on alternatives covers each of their chains, and a name bound
   only in another alternative is Sequence[] in it, as in WL. *)
coverChain[union[cs_], test_] := union[perAlternative[cs, test, coverChain]];

(* f[chain, held] for each chain, with the names the other chains bind and it
   does not replaced by Sequence[] in held. *)
perAlternative[cs_, held_, f_] :=
  With[{names = unionNames[cs]}, f[#, unboundEmpty[held, Complement[names, chainNames[#]]]] & /@ cs];

(* The names a chain's stages bind, after any renaming, each Hold[name]. *)
chainNames[chain[s_, _, _]] := Union @@ (stageNames /@ s);
unionNames[cs_] := Union @@ (chainNames /@ cs);

(* Held code with each of names replaced by Sequence[]. A body or test that is
   only such a name would become Hold[], so it is kept as one expression,
   Sequence @@ {}, which evaluates to Sequence[]. *)
unboundEmpty[held_, {}] := held;
unboundEmpty[None, _] := None;
unboundEmpty[held_, names_] :=
  Replace[held /. Replace[names, Hold[n_] :> (HoldPattern[n] :> Sequence[]), {1}], Hold[] -> Hold[Sequence @@ {}]];

(* ---- Element patterns ---- *)

cElem[XMLPattern[args___]] := cXMLPattern[{args}];

(* The document above the top elements (ADR 0018), featureless. A chain site
   {0} stands for it, where the tree has its head, which this matches. *)
cElem[XMLDocument[]] /; documentAllowedQ[] := $documentStage;
cElem[d_XMLDocument] := refuseDocument[d];
documentAllowedQ[] := $atStart && $firstOfLink;
(* Misplaced, the document is its own message (ADR 0022), except where only an
   element pattern can stand, which it is not. *)
refuseDocument[x_] := With[{h = holderFor[XMLDocument]}, If[h === XMLDocument, refuseAt[h, "place", x], badpat[x]]];
$documentStage = List | XMLElement | XMLObject["Document"];
documentQ[p_] := !FreeQ[p, XMLDocument];
(* A string that gives a combinator is not an element pattern, and is named as
   written. *)
cElem[s_String] := With[{t = cssPattern[s]}, If[multiStageQ[t], badpat[s], cElem[t]]];
(* An XML pattern of several stages: a combinator or alternatives holding one,
   with any name, Condition or test, or a CSS selector string that gives one. *)
multiStageQ[s_String] := multiStageQ[cssPattern[s]];
multiStageQ[p_] :=
  With[{b = patternBase[p]}, combinatorQ[b] || ListQ[b] || MatchQ[b, _Alternatives] && AnyTrue[List @@ b, multiStageQ]];
(* A combinator is not an element pattern; the whole Alternatives is named. *)
cElem[alts_Alternatives] /; AnyTrue[List @@ alts, multiStageQ] := badpat[alts];
cElem[alts_Alternatives] /; !documentAllowedQ[] && documentQ[alts] := refuseDocument[alts];
cElem[alts_Alternatives] := Alternatives @@ (cElem /@ List @@ alts);
(* A named combinator, or named alternatives holding one, would bind a Sequence
   of elements, which says nothing of how they relate (ADR 0015). *)
cElem[Verbatim[Pattern][s_Symbol, p_]] :=
  Which[
    multiStageQ[p], badpat[namedPattern[s, p]],
    documentQ[p], refuseDocument[namedPattern[s, p]],
    True, bindAs[s, cElem[p]]];
(* The document has no element for a name, a Condition or a test to see. *)
cElem[c_Condition] := If[documentQ[patternBase[c]], refuseDocument[c], conditioned[cElem, c, conditionWith]];
(* The same refusal, for a tested combinator inside Alternatives or a name. *)
cElem[t : Verbatim[PatternTest][x_, _]] /; multiStageQ[patternBase[x]] := refuseTestedCombinator[t];
(* pat?f is n : pat /; f[n]: f sees the original element, as a name does. *)
cElem[t : Verbatim[PatternTest][p_, test_]] /; documentQ[p] := refuseDocument[t];
cElem[Verbatim[PatternTest][p_, test_]] := testAs[cElem[p], test];
(* A plain XMLElement pattern is already what the consumers run. *)
cElem[x_XMLElement] := x;
cElem[l_List] := refuseEntry["list", l];
(* A blank would be a second spelling of XMLPattern[_] (ADR 0018), and reads as
   matching text too. *)
cElem[b : _Blank | _BlankSequence | _BlankNullSequence] := refuseAt[$holder, "blank", b];
cElem[q_] := badpat[q];

(* ---- List stages (ADR 0016) ---- *)

(* A list stage is listStage[a], a holding:
     "Id"      the key of the list as written, for messages
     "Pattern" the compiled list, with the user's names, Conditions and tests
     "Index"   the name of the entries before the selected one, matched as one
               PatternSequence: the selected child's index is its length + 1
     "Checks"  {id, mark} for each context combinator entry: the rest of its
               chain is run from the child whose index is Length[{mark}] + 1
     "Parent", "At"  the names of the parent's position and the index in the
               tuple pattern
   Its site in a tuple is the selected child's. On the general matcher the
   stage is listSlot[parent, index, children] in a tuple, the parent's element
   children; in a recognised shape it is the selected child (tupleStage). *)
listFormQ[p_] := ListQ[patternBase[p]];

(* A refusal names the list or the entry as written. *)
refuseList[reason_, ls_listStage] := refuseList[reason, $listSources[ls[[1, "Id"]]]];
refuseList[reason_, l_] := refuseAt[$holder, "liststage", l, $listReasons[reason]];
refuseEntry[reason_, e_] := refuseAt[$holder, "listentry", e, $listReasons[reason]];

stageNames[listStage[a_]] := namesIn[a["Pattern"]];
stageNames[s_] := namesIn[s];

(* The names a pattern, or a list of stages, binds, outside the tests in it,
   which bind nothing the pattern sees. *)
boundNames[x_] := namesIn[x //. {listStage[a_] :> a["Pattern"], Verbatim[PatternTest][p_, _] :> p, Verbatim[Condition][p_, _] :> p}];

$listReasons = <|
  "query" -> "It can only follow Child or Descendant, as in Child[XMLPattern[_], {XMLPattern[\"li\"], ___}], and is not a pattern on its own. For alternatives, use p1 | p2.",
  "first" -> "It can only follow Child or Descendant, as in Child[XMLPattern[_], {XMLPattern[\"li\"], ___}], and cannot be the first stage, which has no parent whose children it would list.",
  "sibling" -> "It can only follow Child or Descendant, not Adjacent or Sibling.",
  "noentry" -> "It needs an entry that is an XML pattern, which selects the child in its place, as XMLPattern[_] does in {___, XMLPattern[_]}. Entries such as _, ___, Repeated and Except only describe the other children. A list sees element children only; for the text inside an element, use HTMLTextContent or HTMLInnerText.",
  "list" -> "An entry is an XML pattern, a combinator, or a pattern such as _, ___, Repeated, Except or PatternSequence over these, but not a list.",
  "element" -> "An entry is an XML pattern, a combinator, or a pattern such as _, ___, Repeated, Except or PatternSequence over these. Write an element pattern as XMLPattern[tag, attrs].",
  "entry" -> "An entry is an XML pattern, a combinator, or a pattern such as _, ___, Repeated, Except or PatternSequence over these.",
  "firstlist" -> "A combinator in a list stands for its first stage, which is a child of the parent, so its first stage cannot be a list.",
  "contextalternatives" -> "Alternatives that hold a combinator can be the last XML pattern in the list, but not an entry before it.",
  "contextname" -> "A combinator before the last XML pattern in the list is a test below or beside that child, and a name bound in its later stages cannot be used elsewhere in the pattern."|>;

(* The selected entry is the last top-level entry that is an XML pattern. *)
xmlEntryQ[e_] :=
  With[{b = patternBase[e]},
    MatchQ[b, _XMLPattern | _String] || combinatorQ[b] || MatchQ[b, _Alternatives] && AllTrue[List @@ b, xmlEntryQ]];

(* The chains of a list as written: one for each alternative of its selected
   entry, each starting with the list stage. *)
listChains[l_] :=
  With[{id = Length[$listSources] + 1},
    $listSources[id] = l;
    Function[form, chain[Prepend[form[[2, 1]], listStage[Append[form[[1]], "Id" -> id]]], form[[2, 2]], form[[2, 3]]]] /@
      listForms[l]];

(* Each form is {stage, chain}: the list stage's Association so far, and the
   rest of the chain its selected entry continues with, as chain[stages after
   the first, links, conditions]. A name, a Condition or a test on the list
   applies to its pattern. *)
listForms[Verbatim[Pattern][s_Symbol, p_]] := mapListPattern[bindAs[s, #] &, listForms[p]];
listForms[c_Condition] :=
  conditioned[listForms, c, Function[{forms, test}, mapListPattern[conditionWith[#, test] &, forms]]];
listForms[Verbatim[PatternTest][p_, f_]] := mapListPattern[testAs[#, f] &, listForms[p]];
listForms[entries_List] :=
  With[{s = Replace[Flatten @ Position[xmlEntryQ /@ entries, True],
      {{} :> (Scan[cEntry, entries]; refuseList["noentry", entries]), is_ :> Last[is]}]},
    With[{context = MapIndexed[If[First[#2] === s, Null, contextEntry[#1]] &, entries],
        chains = chainsOf[cStage[entries[[s]]]]},
      If[MemberQ[chains, chain[{_listStage, ___}, _, _]], refuseEntry["firstlist", entries[[s]]]];
      selectedForm[context, s, #] & /@ chains]];

mapListPattern[f_, forms_] := MapAt[f, forms, {All, 1, Key["Pattern"]}];

(* The selected entry's first stage takes its place in the list; the rest of
   its chain follows the list stage. *)
selectedForm[context_, s_, chain[{first_, rest___}, links_, conditions_]] :=
  Module[{pre = freshSymbol[], checks},
    checks = Cases[MapIndexed[{First[#2], #1} &, context], {k_, entry[_, id_Integer]} :> {k, id, freshSymbol[]}];
    {<|"Pattern" -> prefixed[ReplacePart[Replace[context, entry[p_, _] :> p, {1}], s -> first],
          Association[s -> pre, Rule @@@ checks[[All, {1, 3}]]]],
        "Index" -> pre, "Checks" -> checks[[All, {2, 3}]], "Parent" -> freshSymbol[], "At" -> freshSymbol[]|>,
      chain[{rest}, links, conditions]}];

(* A context entry is entry[pattern, check]: check is None, or for a combinator
   the key of the rest of its chain, run from the child in its place. *)
contextEntry[e_] /; xmlEntryQ[e] && multiStageQ[e] := contextCombinator[e];
contextEntry[e_] := entry[cEntry[e], None];

(* Only the names of the first stage reach the list; those of the later stages
   are the test's own. *)
contextCombinator[e_] :=
  Module[{ch, binds},
    {ch, binds} = reapBinds[cStage[e]];
    Which[
      !MatchQ[ch, _chain], refuseEntry["contextalternatives", e],
      MatchQ[First[ch[[1]]], _listStage], refuseEntry["firstlist", e]];
    With[{first = First[ch[[1]]], id = ++$contextCount},
      Scan[Sow[#, $bindTag] &, Select[binds, !FreeQ[first, #[[2]]] &]];
      Sow[{id, normalForm[ch, None], Complement[Union @@ (stageNames /@ Rest[ch[[1]]]), stageNames[first]], e, $holder}, $contextTag];
      entry[first, id]]];

$contextCount = 0;

(* The rests of the context combinator entries, by key. A name bound in one
   and used elsewhere would need the test to bind it, which it does not. *)
contextEntries[$Failed, _] := <||>;
contextEntries[query_, sown_] :=
  With[{outer = Union @@ (Union @@ (stageNames /@ #["Stages"]) & /@ alternativesOf[query])},
    Scan[If[IntersectingQ[#[[3]], outer], Block[{$holder = #[[5]]}, refuseEntry["contextname", #[[4]]]]] &, sown];
    Association[#[[1]] -> #[[2]] & /@ sown]];

(* ---- List stage methods (ADR 0020) ---- *)

(* How each list stage of a normal form runs, decided once, from the list stage
   alone: its "Method" is
     anywhere[s, n]        {___, s, ___} with no other entry: each child s
                           matches
     amongChildren[before, after, s, n]
                           {e1, ..., s, f1, ...} where the entries e and f
                           are blanks, repeats of them and Except[_]: each
                           child s matches with as many children before and
                           after it as the lengths before and after allow
     amongMatching[counted[t1, before], counted[t2, after], s, n]
                           {Except[t1] ..., PatternSequence[t1, Except[t1]
                           ...] ..., s, ___} and the mirror after s: each
                           child s matches with as many children that match
                           t1 before it, and t2 after it, as the lengths
                           allow (t = _ counts all children)
     ordered[before, {left, right}, after, s, n]
                           {___, e1, ___, e2, e3, ___, s, ___} where each
                           entry e matches one child and the gaps are ___:
                           each child s matches with the entries next to it
                           (left, right) matching around it and the blocks
                           of adjacent entries before and after it placed in
                           order, each side as placed[anchored, blocks], the
                           blocks after s mirrored
     measured[block, view, measures, test, s, n]
                           {g___, b1, ..., s, h___} /; test where the
                           entries b each match one child and test is
                           arithmetic over measures (counts, lengths,
                           matches) of runs of the list's names: each child
                           s matches that follows the block and whose
                           measures, read from running totals over the
                           children as view gives them to the test, pass
                           test
     generalMatcher[r, n]  any other list: the children r's matches select
   where n is the number of copies of each child's attributes the two-step
   match needs (solvable), or None. *)
withMethods[q_] /; KeyExistsQ[q, "Alternatives"] := MapAt[withMethods, q, {Key["Alternatives"], All}];
withMethods[q_] /; KeyExistsQ[q, "Stages"] :=
  Block[{$methodQuery = q},
    MapAt[Replace[#, listStage[a_] :> listStage[Append[a, "Method" -> listMethod[listStage[a]]]], {1}] &, q, Key["Stages"]]];
withMethods[q_] := q;

(* Shape 1, anywhere: the selected entry between two ___, with no context
   entry, name, Condition or test on the list. *)
listMethod[listStage[a_]] /; $recogniseShapes && a["Checks"] === {} &&
    MatchQ[a["Pattern"], {Verbatim[Pattern][a["Index"], Verbatim[PatternSequence][Verbatim[___]]], _, Verbatim[___]}] :=
  anywhere @@ twoStep[selectedEntry[a]];
(* Shapes 2 and 3, a position among all children from the start, the end or
   both: the selected entry with only blanks, repeats of them and Except[_]
   around it, unnamed, and no context entry, name, Condition or test on the
   list. :first-child is {s, ___}, :nth-child(2n+1) {PatternSequence[_, _]...,
   s, ___}, :nth-last-child(2) {___, s, _} and :only-child {s}. *)
listMethod[listStage[a_]] /; $recogniseShapes && a["Checks"] === {} :=
  With[{around = lengthsAround[a]}, amongChildren[Sequence @@ around, Sequence @@ twoStep[selectedEntry[a]]] /; FreeQ[around, None]];
(* Shapes 4 and 5, a position among the children that match a pattern t, from
   the start, the end or both, or among all children on one side: the
   selected entry with, before it, Except[t] ... then units PatternSequence[t,
   Except[t] ...] or repeats of them, and the mirror after it, t binding no
   name. :nth-of-type(2) is {Except[t] ..., PatternSequence[t, Except[t] ...],
   s, ___} and :only-of-type {Except[t] ..., s, Except[t] ...}. *)
listMethod[listStage[a_]] /; $recogniseShapes && a["Checks"] === {} :=
  With[{around = countsAround[a]}, amongMatching[Sequence @@ around, Sequence @@ twoStep[selectedEntry[a]]] /; FreeQ[around, None]];
(* Shape 6, ordered entries: the selected entry among entries that each match
   one child, by a pattern or as a context combinator entry, with ___ or
   nothing between two of them, and a ___ or nothing at each end; no entry but
   the selected one names anything, and there is no Condition or test on the
   list. Sibling[a, b] is {___, a, ___, b, ___}, Adjacent[a, b] {___, a, b,
   ___}. *)
listMethod[listStage[a_]] /; $recogniseShapes :=
  With[{around = orderedAround[a]}, ordered[Sequence @@ around, Sequence @@ twoStep[selectedEntry[a]]] /; around =!= None];
(* Shape 7, split conditions: {g___, b1, ..., c : C, h___} /; test, where the
   entries b each match one child and the test is arithmetic and logic over
   measures of runs of adjacent names that start at g or end at h, or name one
   child: Count[{g}, S], with S counted on each child alone or written
   XMLElement[First[x], _, _] for the children with the tag of child x,
   Length[{g}] and MatchQ[{g}, {___, X, ___, Y}]. The translator writes it for
   the counted positions it cannot write with plain entries: .x:nth-of-type(2)
   is {g___, c : XMLPattern[_, "classList" -> "x"], h___} /; Count[{g},
   XMLElement[First[c], _, _]] + 1 == 2. The selected entry may need the
   two-step match (solvable), which the method applies to it alone, as in the
   other shapes. *)
listMethod[listStage[a_]] /; $recogniseShapes && a["Checks"] === {} :=
  With[{split = splitAround[a]}, measured[Sequence @@ split, Sequence @@ twoStep[selectedEntry[a]]] /; split =!= None];
listMethod[ls_] := generalMatcher @@ listMatcher[ls];

(* The heads of the recognised shapes' methods, and whether a list stage runs
   by one. Defined before childrenSelected, whose definition reads it. *)
$recognisedMethods = anywhere | amongChildren | amongMatching | ordered | measured;
recognisedQ[listStage[a_]] := MatchQ[a["Method"], $recognisedMethods[___]];

(* The selected entry of a list stage run as a recognised shape, whose list
   has the form {pre : PatternSequence[...], s, ...}, under a Condition for
   shape 7. *)
selectedEntry[a_] := Replace[a["Pattern"], Verbatim[Condition][l_, _] :> l][[2]];

(* ---- Shape 7: the parts of a split condition ---- *)

(* The query whose list stages withMethods gives methods, for a shape whose
   names must not be used elsewhere in it. *)
$methodQuery = <||>;

(* {block, view, measures, test} for a list {g___, b1, ..., s, h___} /; test,
   or None when it is not of that form: the entries b, how the test sees a
   child (unmaterialised, when its names are restored around it, or
   Identity), the measures it takes, and the test as a function of their
   values. g and h may be unnamed, and each b is a pattern of one child that
   binds no name, or one named. A name the list binds other than the selected
   entry's is used only in the test, and the test sees no name bound
   elsewhere. *)
splitAround[a_] :=
  Replace[a["Pattern"], {
    Verbatim[Condition][{Verbatim[Pattern][a["Index"], Verbatim[PatternSequence][g_, b___]], s_, h_}, _] :>
      With[{seq = Join[{runName[g]}, entryName /@ {b}, {selectedName[s], runName[h]}], block = entryPattern /@ {b}},
        splitParts[a, seq, block, s] /; FreeQ[{seq, block}, $Failed] && DuplicateFreeQ[DeleteCases[seq, None]]],
    _ -> None}];

(* g___ or ___ before and after, by its name, None when unnamed. *)
runName[Verbatim[Pattern][x_Symbol, Verbatim[___]]] := Hold[x];
runName[Verbatim[___]] := None;
runName[_] := $Failed;

entryName[Verbatim[Pattern][x_Symbol, _]] := Hold[x];
entryName[_] := None;

entryPattern[Verbatim[Pattern][_Symbol, p_]] := entryPattern[p];
entryPattern[p_] := If[countableQ[p], p, $Failed];

selectedName[Verbatim[Pattern][x_Symbol, _]] := Hold[x];
selectedName[Verbatim[Condition][Verbatim[Pattern][x_Symbol, _], _]] := Hold[x];
selectedName[_] := None;

splitParts[a_, seq_, block_, s_] :=
  With[{own = DeleteCases[Delete[seq, -2], None]},
    With[{test = restoredTest[Extract[a["Pattern"], {2}, Hold]]},
      splitTest[seq, block, test, namesPattern[Join[seq, boundNames[$methodQuery["Stages"]]]]] /;
        test =!= None && FreeQ[{block, s, otherStages[$methodQuery["Stages"], listStage[a]], $methodQuery["Body"], $methodQuery["Conditions"]},
          namesPattern[own]]]];
splitParts[___] := None;

(* The stages but the first that is ls: an identical stage elsewhere in the
   chain is another stage, whose names the list's would have to equal. *)
otherStages[stages_, ls_] := Delete[stages, FirstPosition[stages, Verbatim[ls], {}, {1}, Heads -> False]];

namesPattern[names_] := Alternatives @@ (HoldPattern @@@ DeleteCases[names, None]);

(* {test, view}: the held test with each name restored around it (wrapBinds)
   read as the name it restores, seen through unmaterialised; None when it
   binds anything else. Any restore is accepted: the list's pattern is read
   before the two-step match copies its selected entry, so only restores of
   materialisation reach here. A name that is not of a child, such as an
   attribute list, is then left to the checks of the measures, which refuse
   it. *)
restoredTest[Hold[With[{bs___}, body_]]] :=
  If[MatchQ[Hold[bs], Hold[HoldPattern[_Symbol = restore[_, _Symbol]] ...]],
    {Hold[body] /. (restoredAs /@ List @@ Map[Hold, Hold[bs]]), unmaterialised},
    None];
restoredTest[held_] := {held, Identity};

(* A rule from a name restored around a test to the name it restores. Rules
   are built here, not in a rule inside restoredTest, since there one over the
   test's patterns is renamed on its left-hand side alone. *)
restoredAs[Hold[v_Symbol = restore[_, x_Symbol]]] := HoldPattern[v] -> x;

(* The measures of runs of children a test takes, each replaced by a variable
   of the test, which is then a function of their values; None when the rest
   of the test is more than arithmetic and logic on integers, or a measure is
   of a run that is not of adjacent names, or sees a name. *)
splitTest[seq_, block_, {held_, view_}, names_] :=
  With[{ms = DeleteDuplicates @ Cases[held, m : $measureForms :> Hold[m], {0, Infinity}], spans = seqSpans[Length[block]]},
    With[{vars = Table[freshSymbol[], Length[ms]], measures = measureOf[#, seq, spans, names] & /@ ms},
      With[{rest = replacedMeasures[held, ms, vars]},
        {block, view, measures, testFunction[vars, rest]} /;
          FreeQ[measures, $Failed] && arithmeticQ[rest, vars]]]];
splitTest[___] := None;

(* The held test with each measure, held, replaced by its variable, and the
   test as a function of the variables. *)
replacedMeasures[held_, ms_, vars_] := held /. Thread[(Map[Verbatim, #] & /@ Apply[HoldPattern, ms, {1}]) -> vars];
testFunction[vars_, held_Hold] := Function @@ Join[Hold[vars], held];

$measureForms = HoldPattern[Count[{___Symbol}, _]] | HoldPattern[Length[{___Symbol}]] | HoldPattern[MatchQ[{___Symbol}, _List]];

(* Integers, the variables, and the heads of arithmetic, comparison and logic,
   with Hold, which holds the test; a Mod by a nonzero integer, so that no
   message differs. *)
arithmeticQ[rest_, vars_] :=
  Complement[Cases[rest, s_Symbol :> Hold[s], {0, Infinity}, Heads -> True], Hold /@ Join[$arithmeticHeads, vars]] === {} &&
    FreeQ[rest, x_ /; AtomQ[Unevaluated[x]] && !MatchQ[Unevaluated[x], _Symbol | _Integer]] &&
    FreeQ[rest, HoldPattern[Mod[_, d_, ___]] /; !TrueQ[With[{v = d}, IntegerQ[v] && v != 0]]];

$arithmeticHeads = {Hold, Plus, Times, Mod, Equal, Unequal, Less, LessEqual, Greater, GreaterEqual, And, Or, Not, True, False};

(* Where each name of {g___, b1, ..., bk, s, h___} stands, from the selected
   child's index j, as {first, last}: an offset from j, or None for the start
   or the end of the children. *)
seqSpans[k_] := Join[{{None, -k - 1}}, {#, #} & /@ Range[-k, -1], {{0, 0}, {1, None}}];

(* A measure of a run of adjacent names; $Failed for any other. *)
measureOf[Hold[Length[{xs__Symbol}]], seq_, spans_, _] :=
  With[{sp = spanOf[Thread[Hold[{xs}]], seq, spans]}, If[sp === $Failed, $Failed, lengthIn[sp]]];
measureOf[Hold[Count[{xs__Symbol}, XMLElement[First[x_Symbol], Verbatim[_], Verbatim[_]]]], seq_, spans_, _] :=
  With[{sp = spanOf[Thread[Hold[{xs}]], seq, spans], place = spanOf[{Hold[x]}, seq, spans]},
    If[sp === $Failed || place === $Failed || First[place] =!= Last[place], $Failed, tagCountIn[sp, First[place]]]];
measureOf[Hold[Count[{xs__Symbol}, t_]], seq_, spans_, names_] :=
  With[{sp = spanOf[Thread[Hold[{xs}]], seq, spans]},
    If[sp === $Failed || !FreeQ[Hold[t], names] || !countableQ[t], $Failed, countIn[sp, t]]];
measureOf[Hold[MatchQ[{xs__Symbol}, es_List]], seq_, spans_, names_] :=
  With[{sp = spanOf[Thread[Hold[{xs}]], seq, spans]},
    If[sp === $Failed || FreeQ[sp, None] || !FreeQ[Hold[es], names] || !AllTrue[es, MatchQ[#, Verbatim[___]] || countableQ[#] &], $Failed,
      matchIn[sp, es]]];
measureOf[___] := $Failed;

(* The span of names that are adjacent in seq, in order, or $Failed. *)
spanOf[hs_, seq_, spans_] :=
  With[{ps = Flatten[Position[seq, #, {1}, Heads -> False] & /@ hs]},
    If[Length[ps] == Length[hs] && ps === Range[First[ps], Last[ps]], {spans[[First[ps], 1]], spans[[Last[ps], 2]]}, $Failed]];

(* The entries on each side of the selected one, as {before, {left, right},
   after}: left and right are the entries next to it, before and after are
   placed[anchored, blocks], the blocks of adjacent entries beyond them, from
   the far end of the list inwards, with anchored saying there is no ___ at
   that end. The side after the selected entry is mirrored, each block
   reversed, to be placed on the children in reverse. Each entry is tested[p,
   id], with id the key of a context combinator entry's test or None. None
   when the list is not of that form. *)
orderedAround[a_] :=
  Replace[entriesAround[a], {
    {b_List, f_List} :> With[{
        before = orderedSide[Reverse @ entryTests @ unmarked[b, Association[#2 -> #1 & @@@ a["Checks"]]]],
        after = orderedSide[entryTests @ spliced[f]]},
      {First[before], {Reverse @ Last[before], Last[after]}, First[after]} /; FreeQ[{before, after}, untested]],
    _ -> None}];

(* The entries with the PatternSequence before each context combinator entry,
   named by its mark, spliced in, and checkedBy[id] in front of that entry. *)
unmarked[es_List, ids_] :=
  Join @@ Replace[spliced[es], {
    Verbatim[Pattern][m_Symbol, Verbatim[PatternSequence][ps___]] /; KeyExistsQ[ids, m] :> Append[unmarked[{ps}, ids], checkedBy[ids[m]]],
    e_ :> {e}}, {1}];

(* Each entry as ___, as tested[p, id] when it is tested on one child alone,
   or as untested. *)
entryTests[es_List] :=
  Replace[SequenceReplace[es, {checkedBy[id_], p_} :> tested[p, id]], {
    g : Verbatim[___] :> g,
    tested[p_, id_] :> If[countableQ[p], tested[p, id], untested],
    p_ :> If[countableQ[p], tested[p, None], untested]}, {1}];

(* One side of the selected entry, read outwards from it, as {placed[anchored,
   blocks], next}: the entries next to it, then the blocks beyond them. *)
orderedSide[es_List] :=
  With[{runs = SplitBy[es, MatchQ[Verbatim[___]]]},
    With[{next = If[runs =!= {} && !gapsQ[First[runs]], First[runs], {}]},
      {placed[runs === {} || !gapsQ[Last[runs]], Reverse[Reverse /@ Select[If[next === {}, runs, Rest[runs]], !gapsQ[#] &]]], next}]];

(* A run of ___ entries, a gap. *)
gapsQ[run_] := MatchQ[run, {Verbatim[___] ..}];

(* The children each side counts, and how many of them it allows, as
   counted[t, lengths], with t = _ for all children; None when a side is not
   of that form. *)
countsAround[a_] := Replace[entriesAround[a], {b_List, f_List} :> {countedOf[b], countedOf[spliced[mirrored[f]]]}];

countedOf[es_] := With[{l = lengthsOf[PatternSequence @@ es]}, counted[_, l] /; l =!= None];
countedOf[{Verbatim[RepeatedNull][Verbatim[Except][t_]], es___}] /; countableQ[t] :=
  With[{l = lengthsOf[PatternSequence @@ unitsAsBlanks[{es}, t]]}, counted[t, l] /; l =!= None];
countedOf[_] := None;

(* The entries after the leading Except[t] ..., with each unit t, Except[t] ...
   as a _, so that lengthsOf counts the children that match t; a None in place
   of an entry of another form. *)
unitsAsBlanks[{}, _] := {};
unitsAsBlanks[{t_, Verbatim[RepeatedNull][Verbatim[Except][t_]], es___}, t_] := Prepend[unitsAsBlanks[{es}, t], _];
unitsAsBlanks[{Verbatim[Except][Verbatim[_]], es___}, t_] := Prepend[unitsAsBlanks[{es}, t], Except[_]];
unitsAsBlanks[{(h : Repeated | RepeatedNull)[Verbatim[PatternSequence][ps__], r___], es___}, t_] :=
  Prepend[unitsAsBlanks[{es}, t], h[PatternSequence @@ unitsAsBlanks[{ps}, t], r]];
unitsAsBlanks[_, _] := {None};

(* A pattern counted on its own, once per child: it matches one child, not a
   sequence of them, binds no name, has no Condition that could see one, and
   needs no two-step match. A test's function is not a pattern, so names in
   it bind nothing. *)
countableQ[t_] :=
  oneChildQ[t] && FreeQ[t //. Verbatim[PatternTest][p_, _] :> p, Verbatim[Pattern] | Verbatim[Condition]] && !twoStepQ[t];

(* Whether a pattern matches one element of a list, not a sequence: the
   sequence heads count at its top, outside an element pattern's parts. *)
oneChildQ[Verbatim[Alternatives][ps___]] := AllTrue[{ps}, oneChildQ];
oneChildQ[Verbatim[PatternTest][p_, _]] := oneChildQ[p];
oneChildQ[Verbatim[Except][_, p_]] := oneChildQ[p];
oneChildQ[_BlankSequence | _BlankNullSequence | Verbatim[Repeated][___] | Verbatim[RepeatedNull][___] | Verbatim[PatternSequence][___] |
    Verbatim[OrderlessPatternSequence][___] | Verbatim[Longest][___] | Verbatim[Shortest][___] | Verbatim[Optional][___]] := False;
oneChildQ[_] := True;

(* The entries with each PatternSequence among them spliced in. *)
spliced[es_List] := Replace[es, Verbatim[PatternSequence][ps___] :> Sequence @@ spliced[{ps}], {1}];

(* The entries in reverse order, each PatternSequence in them reversed too,
   so that the entries after the selected one read as the entries before it
   do. *)
mirrored[es_List] := Reverse[mirroredEntry /@ es];
mirroredEntry[Verbatim[PatternSequence][ps___]] := PatternSequence @@ mirrored[{ps}];
mirroredEntry[(h : Repeated | RepeatedNull)[p_, r___]] := h[mirroredEntry[p], r];
mirroredEntry[e_] := e;

(* The lengths of the entries before and after the selected one. *)
lengthsAround[a_] := Replace[entriesAround[a], {b_List, f_List} :> {lengthsOf[PatternSequence @@ b], lengthsOf[PatternSequence @@ f]}];

(* The entries before the selected one, each PatternSequence among them
   spliced in, and the entries after it; None when the list has another
   form. *)
entriesAround[a_] :=
  Replace[a["Pattern"], {{Verbatim[Pattern][a["Index"], before_], _, after___} :> {spliced[{before}], {after}}, _ -> None}];

(* The numbers of children a sequence of entries matches, as lengths[lo,
   step, hi]: lo, lo + step, lo + 2 step, ... up to hi, which may be Infinity
   and is less than lo when there are none. None when they are not of that
   form, or an entry is not a blank, a repeat of blanks or Except[_]. A
   sequence's lengths are the sums of its entries': a fixed length shifts the
   others, and two with the same step add their bounds; other sums are not of
   the form. *)
lengthsOf[Verbatim[PatternSequence][es___]] := Fold[addLengths, $zeroLength, lengthsOf /@ {es}];
lengthsOf[Verbatim[_]] := lengths[1, 1, 1];
lengthsOf[Verbatim[__]] := lengths[1, 1, Infinity];
lengthsOf[Verbatim[___]] := $anyLength;
lengthsOf[Verbatim[Except][Verbatim[_]]] := $noLengths;
lengthsOf[Verbatim[Repeated][p_]] := repeatedLengths[lengthsOf[p], 1, Infinity];
lengthsOf[Verbatim[Repeated][p_, {k_Integer}]] /; k >= 0 := repeatedLengths[lengthsOf[p], k, k];
lengthsOf[Verbatim[Repeated][p_, {lo_Integer, hi : (_Integer | Infinity)}]] /; 0 <= lo <= hi :=
  repeatedLengths[lengthsOf[p], lo, hi];
lengthsOf[Verbatim[Repeated][p_, hi_Integer]] /; hi >= 1 := repeatedLengths[lengthsOf[p], 1, hi];
lengthsOf[Verbatim[RepeatedNull][p_]] := repeatedLengths[lengthsOf[p], 0, Infinity];
lengthsOf[_] := None;

$anyLength = lengths[0, 1, Infinity];
$zeroLength = lengths[0, 1, 0];
$noLengths = lengths[0, 1, -1];

(* lo to hi repeats of a sequence of one length k > 0. *)
repeatedLengths[lengths[k_, _, k_], lo_, hi_] /; k > 0 := lengths[k lo, k, k hi];
repeatedLengths[_, _, _] := None;

addLengths[None, _] := None;
addLengths[_, None] := None;
addLengths[lengths[lo_, _, hi_], _] /; hi < lo := $noLengths;
addLengths[_, lengths[lo_, _, hi_]] /; hi < lo := $noLengths;
addLengths[lengths[k_, _, k_], lengths[lo_, step_, hi_]] := lengths[k + lo, step, k + hi];
addLengths[lengths[lo_, step_, hi_], lengths[k_, _, k_]] := lengths[lo + k, step, hi + k];
addLengths[lengths[lo1_, step_, hi1_], lengths[lo2_, step_, hi2_]] := lengths[lo1 + lo2, step, hi1 + hi2];
addLengths[_, _] := None;

(* An+B membership, the one place it is decided: the lengths up to m, in
   increasing order. *)
lengthsUpTo[lengths[k_, _, k_], m_] := If[k <= m, {k}, {}];
lengthsUpTo[lengths[lo_, step_, hi_], m_] := Range[lo, Min[m, hi], step];

(* The select rule, or, when a Condition would see a KeyValuePattern's later
   names unbound, its two-step form (solvable) over copied children, with the
   number of copies. *)
listMatcher[ls_] :=
  With[{r = selectRule[ls]},
    If[twoStepQ[First[r]],
      {First @ copiedRule[First[r], Extract[r, {2}, Hold]], copyCount[First[r]]},
      {r, None}]];

twoStep[p_] := If[twoStepQ[p], {copiedPattern[p], copyCount[p]}, {p, None}];

twoStepQ[p_] := brokenConditionsQ[p] || overlappingKeysQ[p];

(* An entry that is not an XML pattern is a WL pattern over the children:
   blanks, and the pattern heads over entries. A name on it binds a sequence of
   children, each the original element. *)
cEntry[e_] /; xmlEntryQ[e] := cElem[e];
cEntry[b : (_Blank | _BlankSequence | _BlankNullSequence)] := b;
cEntry[Verbatim[Pattern][s_Symbol, p_]] := bindAs[s, cEntry[p]];
cEntry[c_Condition] := conditioned[cEntry, c, conditionWith];
cEntry[Verbatim[PatternTest][p_, f_]] := testAs[cEntry[p], f];
cEntry[(h : Repeated | RepeatedNull)[p_, spec___]] := h[cEntry[p], spec];
cEntry[Verbatim[Except][p_, q___]] := Except @@ (cEntry /@ {p, q});
cEntry[Verbatim[PatternSequence][ps___]] := PatternSequence @@ (cEntry /@ {ps});
cEntry[Verbatim[Alternatives][ps__]] := Alternatives @@ (cEntry /@ {ps});
cEntry[Verbatim[Optional][p_, d___]] := Optional[cEntry[p], d];
cEntry[l_List] := refuseEntry["list", l];
cEntry[e_] /; documentQ[e] := refuseDocument[e];
cEntry[x_XMLElement] := refuseEntry["element", x];
cEntry[e_] := refuseEntry["entry", e];

(* The entries in order, with the entries before each marked one matched as one
   named PatternSequence. *)
prefixed[es_, marks_] :=
  Fold[Function[{acc, k},
      Append[If[KeyExistsQ[marks, k], With[{m = marks[k]}, {namedPattern[m, PatternSequence @@ acc]}], acc], es[[k]]]],
    {}, Range[Length[es]]];

(* A Condition's test sees the names bound in its left-hand side, compiled by
   comp; attach puts the held test on the compiled left-hand side. *)
(* A selector that is not translated has given FromCSSSelector's message. *)
cssPattern[s_] := Replace[FromCSSSelector[s], $Failed :> refuseQuietly[]];

conditioned[comp_, c_, attach_] :=
  Module[{lhs, binds},
    {lhs, binds} = reapBinds[comp[c[[1]]]];
    Scan[Sow[#, $bindTag] &, binds];
    attach[lhs, wrapBinds[unmaterialised, binds, Extract[c, {2}, Hold]]]];

(* p /; test, from a held test. *)
conditionWith[p_, test_Hold] := Condition @@ Join[Hold[p], test];

cXMLPattern[{tag_}] := XMLElement[cTag[tag], _, _];
cXMLPattern[{tag_, attrs_}] := With[{t = cTag[tag]}, XMLElement[t, cAttrs[attrs], _]];
cXMLPattern[args_] := refuse[XMLPattern::nargs, Length[args]];

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
slotKey[k_String] /; KeyExistsQ[$readings, k] := tok[First[$readings[k]]];
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

(* The same name gets the same fresh symbol throughout a query, so that
   (e : XMLPattern["a"]) | (e : XMLPattern["b"]) still binds one name, and a name
   at two stages of a combinator is still one value: materialisation is the same
   on equal elements. A record is the name and its fresh symbol, whatever the
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
   within it: unmaterialised is linear in an element's subtree, and a list
   stage's test runs once per split of the list, often seeing none of the
   siblings after the selected one. With replaces a name only where it is
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
   as in WL, and stays so when restored (issue #18). restore also marks a
   restored name for restoredTest. *)
restore[_] := Sequence[];
restore[inverse_, xs__] := inverse[xs];

(* ---- Conditions over a KeyValuePattern ---- *)

(* WL tests a Condition around a nested KeyValuePattern as soon as the first of
   its rules is matched, with the names of the later rules bound to nothing, and
   a False then is final: XMLPattern["a", {"href" -> h_, "data-id" -> i_}] /;
   StringContainsQ[h, i] never matches. A body condition, lhs :> body /; test,
   is tested the same way, and ReplaceList binds only the first rule's names.
   {OrderlessPatternSequence[rules..., ___]} binds them all but costs the
   factorial of the attribute count (ADR 0007: seconds at six rules).

   So a pattern or rule with such a Condition is matched in two steps. Its
   skeleton, with no names and no Conditions, finds the candidates as fast as a
   plain query. Each candidate is then matched with plain list patterns only:
   each element's attribute list is repeated, and each rule of a
   KeyValuePattern is matched, as {___, rule, ___}, in a copy of its own, the
   first copy keeping the KeyValuePattern as a test with no names. Each rule
   matches a different attribute, as KeyValuePattern requires. An element name
   sees the element with one attribute list, restored around each test and
   body that can see it. A rule's body is evaluated once, for that match. Any
   other pattern is left as it is. *)
solvable[r : Verbatim[RuleDelayed][lhs_, _]] /;
    twoStepQ[lhs] || (laterNamesQ[lhs] && bodyConditionQ[Extract[r, {2}, Hold]]) :=
  Module[{v = freshSymbol[], n = copyCount[lhs]},
    Replace[copiedRule[lhs, Extract[r, {2}, Hold]],
      Hold[rule_] :> RuleDelayed @@ Join[Hold @@ {namedPattern[v, skeleton[lhs]]},
        Hold[With[{s = {Replace[copied[v, n], {rule, _ :> $unmatched}]}}, Sequence @@ s /; s =!= {$unmatched}]]]]];
solvable[p_] /; twoStepQ[p] :=
  With[{v = freshSymbol[], n = copyCount[p], c = copiedPattern[p]},
    Condition @@ Join[Hold @@ {namedPattern[v, skeleton[p]]}, Hold[MatchQ[copied[v, n], c]]]];
solvable[x_] := x;

(* A KeyValuePattern with a name after its first rule. Held, since a Condition
   in a rule's body holds the caller's code. *)
SetAttributes[laterNamesQ, HoldFirst];
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

(* The candidate, the element or each element of a tuple, with its attribute
   list repeated n times. *)
copied[x_, n_] :=
  Replace[x, {XMLElement[t_, a_List, c_] :> XMLElement[t, ConstantArray[a, n], c],
    listSlot[p_, i_, els_] :> listSlot[p, i, copied[els, n]]}, {0, 1}];

(* An element, or each of a sequence of them, or of a list of them. *)
uncopied[xs___] := Sequence @@ Replace[{xs}, XMLElement[t_, {a_, ___}, c_] :> XMLElement[t, a, c], {1, 2}];

copyCount[p_] := 1 + Max[0, Cases[p, Verbatim[KeyValuePattern][r_List] :> Length[r], {0, Infinity}]];

copiedPattern[p_] := Block[{$renamed = renaming[p]}, copiedIn[p]];

copiedRule[lhs_, body_Hold] :=
  Block[{$renamed = renaming[lhs]},
    Hold @@ {RuleDelayed @@ Join[Hold @@ {copiedIn[lhs]}, restored[lhs, body]]}];

(* Each name that binds an element is renamed, and is the uncopied element in
   each test and body that can see it. When the query names a list key, the
   name was already renamed for materialisation; see wrapBinds for how the two
   compose.

   A test or body is restored for every renamed name its left-hand side binds.
   Whether a name binds elements is decided once, over the whole pattern: a
   name on a list stage's entry, g in {g___, c, ___} /; Length[{g}] == 1,
   binds them only as an entry of the listSlot it is in, which the list's own
   Condition does not see, so deciding again from the Condition's left-hand
   side would leave g renamed in the copy and unbound in the test (issue #39). *)
renaming[p_] := Association[# -> freshSymbol[] & /@ elementNames[p]];

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
(* In a list stage every name on an entry binds elements, or a sequence or list
   of them; the parent and index names do not. *)
sowElementNames[listSlot[_, _, l_]] := sowEntryNames[l];
sowElementNames[_[args___]] := Scan[sowElementNames, {args}];
sowElementNames[_] := Null;

sowEntryNames[Verbatim[Pattern][s_Symbol, p_]] := (Sow[Hold[s]]; sowEntryNames[p]);
sowEntryNames[Verbatim[Condition][l_, _]] := sowEntryNames[l];
sowEntryNames[Verbatim[PatternTest][p_, _]] := sowEntryNames[p];
sowEntryNames[x_XMLElement] := sowElementNames[x];
sowEntryNames[_[args___]] := Scan[sowEntryNames, {args}];
sowEntryNames[_] := Null;

