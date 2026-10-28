(* ::Package:: *)
(* HTMLPatterns: XML patterns + the XML* consumers *)

(* Used by CSSSelector.wl *)
PackageScoped[conditionWith]
PackageScoped[mirrored]
PackageScoped[spliced]

(* Used by DisplayRoles.wl *)
PackageScoped[compileWith]
PackageScoped[elementQuery]

(* Used by Readings.wl *)
PackageScoped[refuse]
PackageScoped[$refusal]

(* Used by Tree.wl *)
PackageScoped[compileQuery]
PackageScoped[queryPositions]
PackageScoped[badQuery]
PackageScoped[$queryOption]

(* Used by XMLFunctions.wl *)
PackageScoped[queryCases]
PackageScoped[queryFirst]
PackageScoped[queryDelete]
PackageScoped[elementMatcher]
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

(* =========================================================== *)
(* Running a compiled query                                     *)
(*                                                              *)
(* The operations the XML* functions are: each takes a compiled *)
(* query (or $Failed, having messaged) and a tree, refuses what *)
(* it cannot run under the query's head, and gives the elements *)
(* as they are in the tree. elementMatcher instead gives a      *)
(* function that tests one element.                            *)
(* =========================================================== *)

(* At most the first n of the elements, in document order. *)
queryCases[$Failed, _, _] := $Failed;
queryCases[c_, tree_, n_] :=
  If[treeRefusedQ[c, tree], $Failed, runCompiled[runnerOf[c, unionCases, chainCases, casesC], tree, c, n]];

queryFirst[$Failed, _, _] := $Failed;
queryFirst[c_, tree_, default_] :=
  If[treeRefusedQ[c, tree], $Failed, runCompiled[runnerOf[c, unionFirst, chainFirst, firstC], tree, c, default]];

(* A rule has nothing to delete with. *)
queryDelete[$Failed, _] := $Failed;
queryDelete[c_, tree_] :=
  With[{h = c["Head"]},
    Which[
      c["Body"] =!= None, Message[MessageName[h, "badpat"], c["Query"]]; $Failed,
      treeRefusedQ[c, tree], $Failed,
      True, runCompiled[runnerOf[c, unionDelete, chainDelete, deleteC], tree, c]]];

(* The sites the query selects, at most the first n, in document order: the
   positions in the tree of the elements queryCases gives, a rule's values
   aside. Equal elements at two sites are two sites, so these are not found
   from the elements. Materialising moves no element, so the positions in the
   materialised tree are positions in the tree. *)
queryPositions[$Failed, _, _] := $Failed;
queryPositions[c_, tree_, n_] :=
  If[treeRefusedQ[c, tree], $Failed, runCompiled[runnerOf[c, unionPositions, chainPositions, plainPositions], tree, c, n]];

(* A query of alternatives holding a combinator runs as their chains, any
   other combinator as one chain. *)
runnerOf[c_, onUnion_, onChain_, onPlain_] := Which[unionQ[c], onUnion, chainQ[c], onChain, True, onPlain];

(* A function that tests one element, or $Failed if the query is refused. Only
   the element itself is materialised: its children cannot be reached. *)
elementMatcher[$Failed] := $Failed;
elementMatcher[c_] :=
  With[{h = c["Head"]},
    Which[
      elementQuery[c, c["Query"], h, "combinator"] === $Failed, $Failed,
      c["Body"] =!= None, Message[MessageName[h, "badpat"], c["Query"]]; $Failed,
      True, With[{p = c["Plain"], r = c["Readings"]},
        If[r === {}, MatchQ[p], Function[el, MatchQ[materialise[el, r, {0}], p]]]]]];

treeRefusedQ[c_, tree_] :=
  !validTreeQ[tree] && (messageTreeRefusal[c["Head"], tree]; True);

(* A query tested on one element at a time takes no links: a combinator is
   refused under tag, and a combinator with a Condition under condcombinator.
   q is the query as written; a CSS selector string has no Condition of the
   caller's, whatever its translation holds. *)
elementQuery[$Failed, _, _, _] := $Failed;
elementQuery[c_, q_, head_, tag_] :=
  With[{h = head},
    Which[
      !unionQ[c] && c["Links"] === {}, c,
      AllTrue[alternativesOf[c], #["Conditions"] === {} &] || StringQ[q], Message[MessageName[h, tag], q]; $Failed,
      True, Message[MessageName[h, "condcombinator"], patternBase[q]]; $Failed]];

(* Materialise once per query, over the union of the list keys all its stages
   name; undo it once, at the output. A chain runner is given the normal form,
   a plain runner the pattern or rule it runs. *)
runCompiled[run_, tree_, q_, rest___] :=
  With[{p = Lookup[q, "Plain", q]},
    Block[{$kids = <||>, $contextMemo = <||>, $contexts = q["ContextEntries"]},
      If[q["Readings"] === {}, run[tree, p, rest],
        unmaterialised @ run[materialise[tree, q["Readings"]], p, rest]]]];

(* The pattern a plain query runs, or its rule, in its two-step form. *)
plainQuery[q_] :=
  solvable @ Replace[q["Body"], {None -> First[q["Stages"]],
    body_Hold :> RuleDelayed @@ Join[Hold @@ {First[q["Stages"]]}, body]}];

(* =========================================================== *)
(* Chains: every combinator query                               *)
(*                                                              *)
(* A combinator reads as a chain, left to right, as a CSS       *)
(* selector does: Descendant[a, Child[b, c]] and                *)
(* Child[Descendant[a, b], c] are both the chain a, Descendant, *)
(* b, Child, c. A chain runs on positions in the one            *)
(* (materialised) tree, so every relation, siblings included,   *)
(* is between sites of that tree. Each stage alone selects the  *)
(* sites related to the last site of a tuple; each tuple of     *)
(* elements is then matched against the stages as one plain WL  *)
(* pattern {s1, ..., sn}, so names scope as they do in WL: a    *)
(* stage's test sees only its own names, a name at two stages   *)
(* is one value, and a rule body sees every name. A list stage   *)
(* is matched against one parent's element children at a time,  *)
(* by the one list matcher, which Adjacent and Sibling links     *)
(* also run on (ADR 0016); its site is the selected child's, and *)
(* in a tuple it is the list of those children, or in a          *)
(* recognised shape the selected child.                          *)
(* =========================================================== *)

(* Every combinator query runs as a chain, nested or not, tested or not. *)
chainQ[q_] := q["Links"] =!= {};

(* A query of alternatives holding a combinator runs as several (ADR 0015). *)
unionQ[q_] := KeyExistsQ[q, "Alternatives"];
alternativesOf[q_] := If[unionQ[q], q["Alternatives"], {q}];

(* The stages and links, alternating, as the chain runner reads them, each
   element stage in its two-step form. *)
chainOf[q_] := Riffle[runStage /@ q["Stages"], q["Links"]];

runStage[ls_listStage] := ls;
runStage[s_] := solvable[s];

(* The pattern a tuple of elements matches: the list of the chain's stages. A
   Condition on the whole combinator wraps the list; one on a combinator that is
   a stage wraps the sequence of its stages, so it sees only theirs. Each
   Condition covers the stages i to j, and an inner one is applied first. *)
tuplePattern[q_] :=
  With[{n = Length[q["Stages"]]},
    Fold[conditionWith[#1, Last[#2]] &,
      Last /@ Fold[coverStages, Transpose[{Transpose[{Range[n], Range[n]}], tupleStage /@ q["Stages"]}],
        Select[q["Conditions"], First[#] =!= {1, n} &]],
      Select[q["Conditions"], First[#] === {1, n} &]]];

(* The items {{i, j}, pattern} inside a Condition's span become one. *)
coverStages[items_, {{i_, j_}, test_}] :=
  With[{in = Flatten @ Position[items, {{a_, b_}, _} /; i <= a && b <= j, {1}, Heads -> False]},
    Join[Take[items, First[in] - 1],
      {{{i, j}, conditionWith[PatternSequence @@ items[[in, 2]], test]}},
      Drop[items, Last[in]]]];

tupleRule[q_] := solvable[RuleDelayed @@ Join[Hold @@ {tuplePattern[q]}, q["Body"]]];

(* A list stage in a tuple. In a recognised shape, the method that selected
   the child has checked its place and its context entries, and only the
   selected entry can name anything seen outside the list (shape 7's other
   names are seen only by its own Condition, which the method has
   evaluated), so the stage is that entry, matched
   against the selected child: the list is not matched again. On the general
   matcher another entry may bind names, so the stage is the list, with the
   selected entry at the child's index, and each context combinator entry's
   chain completing from its child. *)
tupleStage[ls : listStage[a_]] /; recognisedQ[ls] := selectedEntry[a];
tupleStage[listStage[a_]] :=
  With[{par = a["Parent"], i = a["At"], pre = a["Index"]},
    Condition @@ Join[Hold @@ {listSlot[namedPattern[par, _], namedPattern[i, _], a["Pattern"]]},
      heldAnd[Hold[Length[{pre}] + 1 == i], contextChecks[a]]]];
tupleStage[s_] := s;

(* The children a list stage selects, from listSlot[parent, _, children]: each
   child's index. *)
selectRule[listStage[a_]] :=
  With[{par = a["Parent"], pre = a["Index"]}, With[{slot = listSlot[namedPattern[par, _], _, a["Pattern"]]},
    RuleDelayed @@ Join[
      If[a["Checks"] === {}, Hold[slot], Hold @@ {Condition @@ Join[Hold[slot], contextChecks[a]]}],
      Hold[Length[{pre}] + 1]]]];

(* Held: the marks are names the list binds. *)
contextChecks[a_] :=
  With[{par = a["Parent"]},
    Fold[heldAnd, Hold[True], Function[{id, m}, Hold[contextQ[id, par, Length[{m}] + 1]]] @@@ a["Checks"]]];

heldAnd[Hold[True], b_Hold] := b;
heldAnd[Hold[x_], Hold[True]] := Hold[x];
heldAnd[Hold[x_], Hold[y_]] := Hold[x && y];

(* Extract reads {} as no positions, not as the whole tree. *)
at[{}] := $chainTree;
at[p_] := Extract[$chainTree, p];

elementIndices[l_List] := Flatten @ Position[l, _XMLElement, {1}, Heads -> False];

(* The document above the top elements (ADR 0018) is the site {0}, which no
   position in the tree is: Extract gives the tree's head there. Its element
   children are the top elements: the root element of an XMLObject, the
   elements of a list, or a bare XMLElement itself, at {}. *)
$documentSite = {0};

(* The parent of an element's site: an element child is at {..., 3, k}, and
   every other element is a top element. *)
parentOf[p_] := If[Length[p] >= 2 && p[[-2]] === 3, Drop[p, -2], $documentSite];

topSites[XMLObject["Document"][__]] := {{2}};
topSites[_XMLElement] := {{}};
topSites[l_List] := List /@ elementIndices[l];

(* selected[r, p, s]: the sites related to p by r that stage s selects. From
   the document, every element is a descendant, the input included, which is
   never a result (siteTuples). *)
selected[Descendant, {0}, s_] := Position[$chainTree, s, {0, Infinity}, Heads -> False];
selected[Child, {0}, s_] := With[{k = kidsAt[$documentSite]}, Pick[k[[1]], MatchQ[s] /@ k[[2]]]];
selected[Descendant, p_, s_] := Join[p, #] & /@ Position[at[p], s, Infinity, Heads -> False];
selected[Child, p_, s_] := Join[p, {3}, #] & /@ Position[at[p][[3]], s, {1}, Heads -> False];

(* The element children of the element or document at par: their sites, the
   elements, and each site's place among them, found once per parent in a run,
   since a list of children may be long; none when par is not an element. *)
kidsAt[par_] := Replace[$kids[par], _Missing :> ($kids[par] = kidsOf[par])];

kidsOf[{0}] := With[{ss = topSites[$chainTree]}, kidsList[ss, If[ss === {}, {}, atAll[ss]]]];
kidsOf[par_] :=
  With[{e = at[par]},
    If[MatchQ[e, _XMLElement],
      With[{is = elementIndices[Last[e]]}, kidsList[Join[par, {3, #}] & /@ is, Last[e][[is]]]],
      {{}, {}, <||>}]];

kidsList[sites_, els_] := {sites, els, AssociationThread[sites, Range[Length[sites]]]};

(* The one list matcher (ADR 0016): the indices of the children els of par that
   a list stage selects, each once, by the stage's method. The general matcher
   takes them from its rule's matches. Anywhere selects each child s matches,
   which Position finds without building the sequence before each one: over
   5,000 siblings that is 1 ms against 300 ms. A position among all children
   tests only the children at the indices its lengths allow, one at a time
   when no copies are needed, which is cheaper per parent than mapping over
   them. *)
listIndices[anywhere[s_, n_], _, els_] := anywhereIndices[copiedBy[els, n], s];
listIndices[amongChildren[before_, after_, s_, n_], _, els_] := matchedAt[amongIndices[before, after, Length[els]], els, s, n];
listIndices[amongMatching[before_, after_, s_, n_], _, els_] := matchedAt[matchingIndices[before, after, els], els, s, n];
listIndices[ordered[before_, around_, after_, s_, n_], par_, els_] := matchedAt[orderedIndices[before, around, after, par, els], els, s, n];
listIndices[measured[block_, view_, measures_, test_, s_, n_], _, els_] := matchedAt[measuredIndices[block, view, measures, test, els], els, s, n];
listIndices[generalMatcher[rule_, n_], par_, els_] := Union @ ReplaceList[copiedBy[listSlot[par, 0, els], n], rule];

anywhereIndices[els_, s_] := Flatten @ Position[els, s, {1}, Heads -> False];

(* The indices is of the children els that s matches. *)
matchedAt[is_, els_, s_, None] := Select[is, MatchQ[els[[#]], s] &];
matchedAt[is_, els_, s_, n_] := Pick[is, MatchQ[s] /@ copied[els[[is]], n]];

(* The indices among len children with as many children before and after as
   the lengths before and after allow. *)
amongIndices[before_, $anyLength, len_] := lengthsUpTo[before, len - 1] + 1;
amongIndices[$anyLength, after_, len_] := Reverse[len - lengthsUpTo[after, len - 1]];
amongIndices[before_, after_, len_] := Intersection[lengthsUpTo[before, len - 1] + 1, len - lengthsUpTo[after, len - 1]];

(* The indices among the children els with as many children that match t1
   before them, and t2 after them, as the lengths before and after allow: each
   pattern is tested once per child, and the counts are running totals. *)
matchingIndices[counted[t1_, before_], counted[t2_, after_], els_] :=
  With[{marks = AssociationMap[matchMarks[#, els] &, Union[{t1, t2}]]},
    Pick[Range[Length[els]],
      allowedCounts[before, Accumulate[marks[t1]] - marks[t1]] allowedCounts[after, Total[marks[t2]] - Accumulate[marks[t2]]], 1]];

matchMarks[Verbatim[_], els_] := ConstantArray[1, Length[els]];
matchMarks[t_, els_] := Boole[MatchQ[t] /@ els];

(* 1 where a count is one the lengths allow, and 0 where not. *)
allowedCounts[$anyLength, counts_] := ConstantArray[1, Length[counts]];
allowedCounts[lengths_, counts_] :=
  Normal[SparseArray[Thread[(lengthsUpTo[lengths, Length[counts] - 1] + 1) -> 1], Length[counts]]][[counts + 1]];

(* The indices among the children els where the entries next to the selected
   one match around it, and the blocks before and after it fit in order
   between it and the ends: each entry is tested once on each child. *)
orderedIndices[before_, {left_, right_}, after_, par_, els_] :=
  With[{len = Length[els], nl = Length[left], nr = Length[right],
      marks = AssociationMap[testMarks[#, par, els] &, Union @@ Cases[{before, left, right, after}, {__tested}, Infinity]]},
    With[{fromStart = startBounds[before, marks, len], fromEnd = startBounds[after, Reverse /@ marks, len]},
      With[{lo = Max[1, First[fromStart] + nl, len + 1 - nr - Last[fromEnd]], hi = Min[len, Last[fromStart] + nl, len + 1 - nr - First[fromEnd]]},
        Fold[Intersection,
          If[lo <= hi, Range[lo, hi], {}],
          {If[nl == 0, Nothing, blockStarts[left, marks, len] + nl], If[nr == 0, Nothing, blockStarts[right, marks, len] - 1]}]]]];

(* 1 at each child that an entry matches, and 0 elsewhere. The rest of a
   context combinator entry's chain runs only from a child its first stage
   matches. *)
testMarks[tested[p_, None], _, els_] := matchMarks[p, els];
testMarks[tested[p_, id_], par_, els_] := MapIndexed[Boole[MatchQ[#1, p] && contextQ[id, par, First[#2]]] &, els];

(* The indices where each entry of a block matches the child at its offset. *)
blockStarts[block_, marks_, len_] :=
  With[{k = Length[block]},
    If[k > len, {}, Flatten @ Position[Times @@ MapIndexed[marks[#1][[First[#2] ;; len - k + First[#2]]] &, block], 1, {1}]]];

(* Where the entries next to the selected one may start, counted from one end
   of the children, as {lo, hi}: after the blocks of that side, each placed at
   its earliest after the one before it, and the first at the end itself when
   the side is anchored. With no blocks, an anchored side starts at the end.
   {Infinity, Infinity} when the blocks do not fit. *)
startBounds[placed[True, {}], _, _] := {1, 1};
startBounds[placed[False, {}], _, _] := {1, Infinity};
startBounds[placed[anchored_, {first_, rest___}], marks_, len_] :=
  {Fold[placedAfter[marks, len], If[anchored, anchoredEnd[first, marks, len], placedAfter[marks, len][0, first]], {rest}] + 1, Infinity};

(* The last index a block takes at its earliest after index end, Infinity when
   it does not fit. *)
placedAfter[marks_, len_][end_, block_] := SelectFirst[blockStarts[block, marks, len], # > end &, Infinity] + Length[block] - 1;

(* The last index a block takes at index 1, Infinity when it does not match
   there. *)
anchoredEnd[block_, marks_, len_] := If[First[blockStarts[block, marks, len], 0] == 1, Length[block], Infinity];

(* The indices among the children els after the block of entries before the
   selected one, where the test holds of the measures: each pattern is tested
   once on each child, as the test sees it (view), and each measure is read
   from running totals for every index at once. *)
measuredIndices[block_, view_, measures_, test_, els_] :=
  With[{js = blockEnds[block, els]},
    Which[js === {}, {}, measures === {}, If[TrueQ[test[]], js, {}], True,
      With[{marks = measureMarks[measures, view, els]},
        Pick[js, TrueQ /@ MapThread[test, measureValues[#, js, els, marks] & /@ measures]]]]];

(* 1 at each child that a pattern a measure tests matches, as the test sees
   the child, and 0 elsewhere, by pattern: each tested once on each child. *)
measureMarks[measures_, view_, els_] :=
  With[{ps = Union[Cases[measures, countIn[_, t_] :> t], Join @@ Cases[measures, matchIn[_, es_] :> DeleteCases[es, Verbatim[___]]]]},
    If[ps === {}, <||>, With[{seen = view /@ els}, AssociationMap[matchMarks[#, seen] &, ps]]]];

(* The indices j such that the block matches the children just before j. *)
blockEnds[{}, els_] := Range[Length[els]];
blockEnds[block_, els_] :=
  With[{k = Length[block], len = Length[els]},
    If[len <= k, {},
      Pick[Range[k + 1, len], Times @@ MapIndexed[matchMarks[#1, els][[First[#2] ;; len - k - 1 + First[#2]]] &, block], 1]]];

(* The first and last index of a span, for each index js of the selected
   child: an offset from it, or the start or end of the children. *)
spanFirst[None, js_] := ConstantArray[1, Length[js]];
spanFirst[c_, js_] := js + c;
spanLast[None, js_, len_] := ConstantArray[len, Length[js]];
spanLast[c_, js_, _] := js + c;

(* The values of a measure for each index js of the selected child. *)
measureValues[lengthIn[{lo_, hi_}], js_, els_, _] := spanLast[hi, js, Length[els]] - spanFirst[lo, js] + 1;
measureValues[countIn[{lo_, hi_}, t_], js_, els_, marks_] :=
  With[{totals = Prepend[Accumulate[marks[t]], 0]},
    totals[[spanLast[hi, js, Length[els]] + 1]] - totals[[spanFirst[lo, js]]]];
measureValues[tagCountIn[{lo_, hi_}, c_], js_, els_, _] :=
  With[{tags = First /@ els},
    With[{groups = Values @ PositionIndex[tags], len = Length[tags]},
      With[{ranks = Normal @ SparseArray[Flatten[Thread[# -> Range[0, Length[#] - 1]] & /@ groups], len],
          sizes = Normal @ SparseArray[Flatten[Thread[# -> Length[#]] & /@ groups], len]},
        tagsUpTo[hi, c, js, tags, ranks, sizes] - If[lo === None, 0, tagsUpTo[lo - 1, c, js, tags, ranks, sizes]]]]];
measureValues[matchIn[{None, hi_}, es_], js_, els_, marks_] := runFlags[es, marks, Length[els]][[spanLast[hi, js, Length[els]] + 1]];
measureValues[matchIn[{lo_, None}, es_], js_, els_, marks_] :=
  runFlags[Reverse[es], Reverse /@ marks, Length[els]][[Length[els] - spanFirst[lo, js] + 2]];

(* The number of children up to index j + e (or all of them, for None) with
   the tag of the child at j + c: ranks counts those before a child, sizes all
   of them, and the children between the two are compared one offset at a
   time. *)
tagsUpTo[None, c_, js_, _, _, sizes_] := sizes[[js + c]];
tagsUpTo[e_, c_, js_, tags_, ranks_, _] :=
  With[{m = js + c, d = e - c},
    ranks[[m]] + If[d >= 0, 1, -1] Total[Table[Boole[MapThread[SameQ, {tags[[m]], tags[[m + t]]}]], {t, If[d >= 0, Range[0, d], Range[d + 1, -1]]}]]];

(* For each L from 0 to len, whether the first L of len children match {es},
   from each entry's marks on them, where each entry is ___ or matches one
   child: the blocks between the ___ are placed at their earliest, as for
   shape 6, and a last block with no ___ after it ends at L. *)
runFlags[{}, _, len_] := Thread[Range[0, len] == 0];
runFlags[es_, marks_, len_] :=
  With[{blocks = Select[SplitBy[es, MatchQ[Verbatim[___]]], !gapsQ[#] &],
      atStart = !MatchQ[First[es], Verbatim[___]], atEnd = !MatchQ[Last[es], Verbatim[___]]},
    If[!atEnd,
      Thread[Range[0, len] >= First[startBounds[placed[atStart, blocks], marks, len]] - 1],
      With[{last = Last[blocks], bounds = startBounds[placed[atStart, Most[blocks]], marks, len]},
        Normal @ SparseArray[Thread[(Select[blockStarts[last, marks, len], Between[bounds]] + Length[last]) -> True], len + 1, False]]]];

copiedBy[x_, None] := x;
copiedBy[x_, n_] := copied[x, n];

(* The sites a list stage selects below site p, by its method: among the
   children of p, or for Descendant of p and of every element inside it, one
   parent at a time. Below the document, that is the document and every
   element. *)
listSelected[Child, p_, method_] := childrenSelected[p, method];
listSelected[Descendant, {0}, method_] :=
  Join @@ (childrenSelected[#, method] & /@
    Prepend[Position[$chainTree, XMLElement[_, _, {___, _XMLElement, ___}], {0, Infinity}, Heads -> False], $documentSite]);
listSelected[Descendant, p_, method_] :=
  Join @@ (childrenSelected[Join[p, #], method] & /@ Position[at[p], XMLElement[_, _, {___, _XMLElement, ___}], {0, Infinity}, Heads -> False]);

(* A recognised shape selects only children that its selected entry matches,
   so an element with none of them is passed over without listing its children:
   most elements, below an any-element parent stage as in li:first-child. *)
childrenSelected[par_, $recognisedMethods[___, s_, None]] /; par =!= $documentSite && FreeQ[Last[at[par]], s, {1}] := {};
childrenSelected[par_, method_] :=
  With[{k = kidsAt[par]}, If[k[[2]] === {}, {}, k[[1, listIndices[method, par, k[[2]]]]]]];

(* The tuple's elements, a list stage on the general matcher as listSlot[parent,
   index, children], and one of a recognised shape as the selected child (see
   tupleStage). *)
tupleElements[q_] :=
  With[{slots = listSlots[q]}, If[slots === {}, atAll, withListSlots[slots]]];

listSlots[q_] := Flatten @ Position[q["Stages"], ls_listStage /; !recognisedQ[ls], {1}, Heads -> False];

withListSlots[slots_][t_] := ReplacePart[atAll[t], Thread[slots -> (listSlotAt /@ t[[slots]])]];

listSlotAt[site_] :=
  With[{par = parentOf[site]}, With[{k = kidsAt[par]}, listSlot[par, k[[3]][site], k[[2]]]]];

tuplesElements[q_, tuples_] := If[listSlots[q] =!= {}, tupleElements[q] /@ tuples, elementsAt[tuples]];

(* Whether the child at index j of par completes context combinator entry id:
   the rest of its chain run from that child alone, once per child in a run. *)
contextQ[id_, par_, j_] :=
  With[{site = kidsAt[par][[1, j]]},
    Lookup[$contextMemo, Key[{id, site}], $contextMemo[{id, site}] = completesQ[$contexts[id], site]]];

completesQ[q_, site_] := siteTuples[q["Chain"], q["TupleTest"], {site}] =!= {};

(* The test a chain's tuples pass, None when its stages' own matches decide. *)
tupleTest[q_] := If[stagesDecideQ[q], None, MatchQ[solvable[tuplePattern[q]]] @* tupleElements[q]];

(* Adjacent[a, b] is Child[XMLDocument[] | XMLPattern[_], {___, a, b, ___}]
   and Sibling[a, b] is Child[XMLDocument[] | XMLPattern[_], {___, a, ___, b, ___}]
   (ADR 0016, ADR 0018): from an a at index i of its
   parent's children, the list {Repeated[_, {i - 1}], _, b, ___} or
   {Repeated[_, {i - 1}], _, ___, b, ___}, which is {b, ___} or {___, b, ___}
   over the children after it. The parent of a top element is the document,
   so the top elements of a list are siblings (ADR 0018); the document has
   none. *)
siblingSiteQ[p_] := p =!= $documentSite;

followingSelected[p_, s_] /; siblingSiteQ[p] :=
  With[{k = kidsAt[parentOf[p]]},
    With[{i = k[[3]][p]},
      k[[1, i + anywhereIndices[Drop[k[[2]], i], s]]]]];
followingSelected[_, _] := {};

(* Adjacent extends the tuples whose last sites are children of one parent
   together: {b, ___} over the children after a child matches when the next
   one matches b, as ___ matches the rest. *)
adjacentSelected[tuples_, s_] /; siblingSiteQ[Last[First[tuples]]] :=
  Module[{k, next, in, ts, ns, keep},
    k = kidsAt[parentOf[Last[First[tuples]]]];
    next = Lookup[k[[3]], Last /@ tuples] + 1;
    in = UnitStep[Length[k[[2]]] - next];
    ts = Pick[tuples, in, 1];
    ns = Pick[next, in, 1];
    keep = MatchQ[s] /@ k[[2, ns]];
    MapThread[Append, {Pick[ts, keep], k[[1, Pick[ns, keep]]]}]];
adjacentSelected[_, _] := {};

(* Sibling[before, after] matches an element with SOME earlier sibling matching
   before together with it, the whole chain's names and Condition included, and
   gives that element once. So a tuple ending at an after site defers its before
   stage: it holds before[g, k], the choices of group g earlier than the sibling
   at index k, and a runOf mark for each further stage a choice fixes. A choice
   fixes the stages back to the start of its run of Adjacent and Sibling links,
   as they are its siblings; the stages before the run relate to the list, not
   to the sibling, and group the choices. Adjacent needs no choice: an element
   has one previous sibling. A bare XMLElement input, at {}, is the document's
   only child, and the document has no siblings, so a sibling link drops
   both. *)
extend[tuples_, link : {Adjacent | Sibling, _, _}] /; MemberQ[tuples, {___, {} | {0}}] :=
  extend[DeleteCases[tuples, {___, {} | {0}}], link];
extend[tuples_, {Adjacent, s_, _}] := related[Adjacent, tuples, s];
extend[tuples_, {Sibling, s_, run_}] :=
  Join @@ (siblingChoices[#, s, run] & /@ GatherBy[tuples, {Take[#, run - 1], parentOf[Last[#]]} &]);
extend[tuples_, {Descendant, s_listStage, _}] /; $stagesDecide := listRelated[Descendant, outermost[tuples], s];
extend[tuples_, {r_, s_listStage, _}] := listRelated[r, tuples, s];
extend[tuples_, {Descendant, s_, _}] /; $stagesDecide := related[Descendant, outermost[tuples], s];
extend[tuples_, {r_, s_, _}] := related[r, tuples, s];

related[Adjacent, tuples_, s_] := Join @@ (adjacentSelected[#, s] & /@ GatherBy[tuples, parentOf @* Last]);
related[r_, tuples_, s_] := Join @@ (Function[t, Append[t, #] & /@ selected[r, Last[t], s]] /@ tuples);

listRelated[r_, tuples_, listStage[a_]] :=
  With[{m = a["Method"]}, Join @@ (Function[t, Append[t, #] & /@ listSelected[r, Last[t], m]] /@ tuples)];

(* Descendant[ancestor, desc] gives each element once, as querySelectorAll and
   soupsieve's select do. When the stages' own matches decide, any ancestor
   will do, and the first in document order, the outermost, is taken: a name
   bound at the ancestor stage, as in a rule body, sees the outermost ancestor.
   So a site below another tuple's last site is dropped, its descendants being
   the other's too; the subtrees searched are then disjoint. When the stages
   decide, a site is the last of at most one tuple after every link, so the
   dropped tuples are the only duplicates. Every element is below the
   document. *)
outermost[tuples_] /; MemberQ[tuples, {$documentSite}] := {{$documentSite}};
outermost[tuples_] :=
  Module[{cover = None},
    Select[tuples[[documentOrdering[Last /@ tuples]]],
      Function[t, If[cover =!= None && Take[Last[t], UpTo[Length[cover]]] === cover,
        False, cover = Last[t]; True]]]];

(* Document order, as querySelectorAll gives elements: lexicographic, with a
   position before every position below it, so an element comes before the
   elements nested in it and after an earlier sibling's. Ties keep their
   order. The document comes first. *)
documentOrdering[{}] := {};
documentOrdering[ps_] :=
  Ordering @ Join[PadRight[Replace[ps, {0} -> {-1}, {1}], {Length[ps], Max[Length /@ ps]}, 0], List /@ Range[Length[ps]], 2];

(* The choices are a group's tuples from the run on, in document order of their
   last site; the sites the list selects after the first choice are the
   candidates. When the stages' own matches decide the match, the first choice
   is the one taken, and taken at once, as Descendant takes the outermost
   ancestor: Sibling then lists the children once per parent. *)
siblingChoices[tuples_, s_, run_] :=
  With[{sorted = tuples[[Ordering[Last /@ Last /@ tuples]]]},
    With[{sites = followingSelected[Last[First[sorted]], s]},
      If[$stagesDecide,
        Append[First[sorted], #] & /@ sites,
        With[{g = Length[$choices] + 1},
          $choices[g] = sorted[[All, run ;;]];
          Join[Take[First[sorted], run - 1], {before[g, Last[#]]},
              ConstantArray[runOf, Length[First[sorted]] - run], {#}] & /@ sites]]]];

(* For each link, the stage its run of Adjacent and Sibling links starts at. *)
runStarts[links_] :=
  FoldList[If[MatchQ[First[#2], Adjacent | Sibling], #1, Last[#2]] &, 1,
    Transpose[{Most[links], Range[2, Length[links]]}]];

(* The first site tuple t stands for that test accepts, or Nothing. The latest
   deferred stage is chosen first, earliest sibling first: a name bound at the
   before stage, as in a rule body, sees the first earlier sibling, in document
   order, with which the element matches the whole pattern. *)
resolved[t_, test_] := Catch[choose[t, test]; Nothing, $chosen];

choose[t_, test_] :=
  Replace[FirstPosition[Reverse[t], _before, None, {1}, Heads -> False], {
    None :> If[test[t], Throw[t, $chosen]],
    {r_} :> chooseAt[t, Length[t] + 1 - r, test]}];

(* A loop by index: Do over a long list of choices costs its length at once. *)
chooseAt[t_, p_, test_] :=
  With[{cs = $choices[t[[p, 1]]], k = t[[p, 2]]},
    Module[{i = 1},
      While[i <= Length[cs] && Last[Last[cs[[i]]]] < k,
        choose[Join[Take[t, p - 1], cs[[i]], Drop[t, p - 1 + Length[cs[[i]]]]], test];
        i++]]];

(* The site tuples of a chain that test accepts, test None when the stages'
   own matches decide, in document order of their last sites, as a base
   XMLCases gives its elements. The first stage's sites include the document
   and the root, which a bare XMLElement tree makes an element. The root can
   be a later stage below the document, but is never a result, as it is never
   one of a base XMLCases (ADR 0018). *)
siteTuples[chain_, test_, starts_ : All] :=
  With[{links = chain[[2 ;; ;; 2]]},
    Block[{$choices = <||>, $stagesDecide = test === None},
      If[$stagesDecide, Identity, firstPerSite[#, test] &] @ byLastSite @ DeleteCases[Fold[extend,
        List /@ firstSites[First[chain], starts],
        Transpose[{links, chain[[3 ;; ;; 2]], runStarts[links]}]], {__, {}}]]];

(* The sites of the first stage, or those of starts that it matches. *)
firstSites[s_, All] :=
  Join[If[MatchQ[Head[$chainTree], s], {$documentSite}, {}], Position[$chainTree, s, {0, Infinity}, Heads -> False]];
firstSites[s_, starts_] := Select[starts, MatchQ[at[#], s] &];

(* Each element once: of the tuples ending at one site, which are adjacent
   once ordered by their last sites, the first that test accepts, by their
   stages in document order, the latest stage first, as a Sibling choice is
   made. So a name bound at a Descendant's ancestor stage sees the outermost
   ancestor with which the element matches the whole pattern. A tuple with a
   deferred Sibling stage is ordered once its choices are made. *)
firstPerSite[tuples_, test_] := firstAccepted[#, test] & /@ SplitBy[tuples, Last];

firstAccepted[ts_, test_] /; FreeQ[ts, _before] := SelectFirst[inDocumentOrder[ts], test, Nothing];
firstAccepted[ts_, test_] := Replace[resolved[#, test] & /@ ts, {{} -> Nothing, rs_ :> First[inDocumentOrder[rs]]}];

inDocumentOrder[{t_}] := {t};
inDocumentOrder[ts_] :=
  With[{n = Max[Map[Length, ts, {2}]]},
    ts[[documentOrdering[Flatten[PadRight[Reverse[Most[#]], {Automatic, n}]] & /@ ts]]]];

(* Tuples in document order of their last sites; tuples ending at one site
   keep their order. *)
byLastSite[tuples_] := tuples[[documentOrdering[Last /@ tuples]]];

(* The elements at a list of positions, with one Extract. *)
atAll[ps_] := Extract[$chainTree, ps];

(* The element tuples of site tuples, which have one length. *)
elementsAt[{}] := {};
elementsAt[tuples_] := Partition[atAll[Join @@ tuples], Length[First[tuples]]];

(* The site tuples whose elements match the tuple pattern. The stages' own
   matches, which selected the sites, decide it unless a Condition wraps a
   combinator or a name is bound at two stages. *)
matchedSites[q_] := siteTuples[q["Chain"], q["TupleTest"]];

stagesDecideQ[q_] :=
  q["Conditions"] === {} && DuplicateFreeQ[Join @@ (stageNames /@ q["Stages"])];

(* A Condition in the body can reject a tuple. *)
bodyRejectsQ[q_] := bodyConditionQ[q["Body"]];

namesIn[s_] :=
  DeleteDuplicates @ Cases[s, Verbatim[Pattern][n_Symbol, _] :> Hold[n], {0, Infinity}, Heads -> True];

(* The plain form picks the last element of a matching tuple rather than binding
   the tuple: a rule's right-hand side re-evaluates what it is given, and a
   tuple may hold a large element. *)
chainCases[tree_, q_, n_] /; bodyRejectsQ[q] := Block[{$chainTree = tree}, Take[ruleValues[q], UpTo[n]]];
chainCases[tree_, q_, n_] /; q["Body"] =!= None :=
  Block[{$chainTree = tree}, Cases[tuplesElements[q, matchedSites[q]], q["TupleRule"], {1}, n]];
chainCases[tree_, q_, n_] :=
  Block[{$chainTree = tree}, atAll[Last /@ Take[matchedSites[q], UpTo[n]]]];

chainFirst[tree_, q_, default_] /; bodyRejectsQ[q] :=
  Block[{$chainTree = tree}, Replace[ruleValues[q], {{v_, ___} :> v, {} -> default}]];
chainFirst[tree_, q_, default_] /; q["Body"] =!= None :=
  Block[{$chainTree = tree},
    FirstCase[tuplesElements[q, matchedSites[q]], q["TupleRule"], default, {1}]];
chainFirst[tree_, q_, default_] :=
  Block[{$chainTree = tree},
    Replace[matchedSites[q], {{t_, ___} :> at[Last[t]], {} -> default}]];

(* A Condition in a rule's body can reject a tuple, so it takes part in
   choosing one, as a Condition on the combinator does: as Cases gives the
   places where a rule gives a value, a tuple is accepted when the rule gives
   it one. The value is kept, so the body is not evaluated again once the tuple
   is chosen. The accepted tuples are given with their values, keyed by tuple,
   as {tuples, values}: a value of Nothing or Sequence[] has no place in a
   list. *)
ruleTuples[q_] :=
  Module[{rule = q["TupleRule"], elements = tupleElements[q], values = <||>, tuples},
    tuples = siteTuples[q["Chain"],
      Function[t, With[{v = Replace[elements[t], {rule, _ :> $unmatched}]},
        v =!= $unmatched && (values[t] = v; True)]]];
    {tuples, values}];

ruleValues[q_] := Replace[ruleTuples[q], {tuples_, values_} :> Lookup[values, Key /@ tuples]];

(* The sites chainCases takes its elements from, or its values: the last sites
   of the tuples it accepts. A site whose value is Nothing is a site. *)
chainPositions[tree_, q_, n_] /; bodyRejectsQ[q] :=
  Block[{$chainTree = tree}, Last /@ Take[First[ruleTuples[q]], UpTo[n]]];
chainPositions[tree_, q_, n_] := Block[{$chainTree = tree}, Last /@ Take[matchedSites[q], UpTo[n]]];

(* A chain deletes the elements its last stage selects. Delete removes
   positions nested in one another together. *)
chainDelete[tree_, q_] :=
  Block[{$chainTree = tree},
    deleteAt[tree, DeleteDuplicates[Last /@ matchedSites[q]]]];

(* =========================================================== *)
(* Alternatives of chains (ADR 0015)                            *)
(*                                                              *)
(* Alternatives holding a combinator run as the list of their   *)
(* chains, in disjunctive normal form, over one materialised    *)
(* tree, and are merged per element, as XPath's union merges    *)
(* node sets: each element once, in document order, from the    *)
(* first alternative, in written order, that accepts it. Each   *)
(* chain chooses its own tuple by ADR 0014's rule, so the       *)
(* choice of alternative ranks above every choice of stage. An  *)
(* alternative that is an element pattern is a chain of one     *)
(* stage, and selects what a plain query with it selects, never *)
(* the root.                                                    *)
(* =========================================================== *)

(* The site tuples of alternative a that test accepts, test None when its
   stages decide, in document order of their last sites. *)
alternativeSites[a_, test_] /; a["Links"] === {} :=
  With[{ts = List /@ elementSites[First[a["Chain"]]]}, If[test === None, ts, Select[ts, test]]];
alternativeSites[a_, test_] := siteTuples[a["Chain"], test];

(* The sites below the root that s matches, in document order. *)
elementSites[s_] := positionsInOrder[$chainTree, s];

(* The accepted tuples of alternative a whose last site keep accepts, each
   {tuple}, or {tuple, value} when the body can reject and so is evaluated in
   choosing one. keep is tested first, so a site an earlier alternative took is
   not tried again, and its body not evaluated. *)
acceptedTuples[a_, keep_] /; bodyRejectsQ[a] :=
  Module[{rule = a["TupleRule"], elements = tupleElements[a], values = <||>, tuples},
    tuples = alternativeSites[a,
      Function[t, keep[Last[t]] && With[{v = Replace[elements[t], {rule, _ :> $unmatched}]},
        v =!= $unmatched && (values[t] = v; True)]]];
    {#, values[#]} & /@ tuples];
acceptedTuples[a_, keep_] :=
  With[{test = a["TupleTest"]},
    List /@ Select[alternativeSites[a, If[test === None, None, keep[Last[#]] && test[#] &]], keep @* Last]];

(* For each alternative in order, its accepted entries {k, tuple} or {k, tuple,
   value}, k its index, of the sites no earlier alternative took. *)
unionEntries[q_] :=
  Module[{taken = <||>},
    Join @@ MapIndexed[
      Function[{a, k}, With[{es = acceptedTuples[a, !KeyExistsQ[taken, #] &]},
        Scan[(taken[Last[First[#]]] = True) &, es];
        Prepend[#, First[k]] & /@ es]],
      q["Alternatives"]]];

(* What an entry gives: its element, or its value, the body evaluated now when
   it was not in choosing the entry. *)
entryResult[q_, rules_][{k_, t_}] :=
  If[q["Body"] === None, at[Last[t]], Replace[tupleElements[q["Alternatives"][[k]]][t], rules[[k]]]];
entryResult[_, _][{_, _, v_}] := v;

inSiteOrder[es_] := es[[documentOrdering[es[[All, 2, -1]]]]];

entryRules[q_] := Lookup[q["Alternatives"], "TupleRule"];

unionCases[tree_, q_, n_] :=
  Block[{$chainTree = tree},
    With[{es = Take[inSiteOrder[unionEntries[q]], UpTo[n]]},
      If[q["Body"] === None, atAll[es[[All, 2, -1]]], entryResult[q, entryRules[q]] /@ es]]];

(* The sites unionCases takes its elements or values from. *)
unionPositions[tree_, q_, n_] :=
  Block[{$chainTree = tree}, Take[inSiteOrder[unionEntries[q]], UpTo[n]][[All, 2, -1]]];

(* Each alternative stops at its first accepted entry before the best so far:
   the answer is the earliest, ties going to the earlier alternative, as one
   element can only tie with itself. *)
unionFirst[tree_, q_, default_] :=
  Block[{$chainTree = tree},
    Module[{best = None},
      MapIndexed[
        Function[{a, k}, With[{keep = If[best === None, True &, With[{b = best[[2, -1]]}, beforeQ[#, b] &]]},
          Replace[firstAcceptedTuple[a, keep], {e_} :> (best = Prepend[e, First[k]])]]],
        q["Alternatives"]];
      If[best === None, default, entryResult[q, entryRules[q]][best]]]];

(* An element pattern's first match in document order is found without the
   others; it is a candidate only if keep takes it, and no later match is. *)
firstAcceptedTuple[a_, keep_] /; a["Links"] === {} && a["StagesDecide"] && !bodyRejectsQ[a] :=
  Select[{{#}} & /@ firstMatchPositions[$chainTree, First[a["Chain"]], 1], keep[#[[1, -1]]] &];
firstAcceptedTuple[a_, keep_] := Take[acceptedTuples[a, keep], UpTo[1]];

(* Whether site p comes before site s in document order. *)
beforeQ[p_, s_] := p =!= s && documentOrdering[{p, s}] === {1, 2};

unionDelete[tree_, q_] :=
  Block[{$chainTree = tree},
    deleteAt[tree, DeleteDuplicates[Join @@ (Last @* First /@ acceptedTuples[#, True &] & /@ q["Alternatives"])]]];

(* A document keeps its root element, which an XMLObject needs (ADR 0018). *)
deleteAt[tree : XMLObject["Document"][_, _, _], ps_] /; MemberQ[ps, {2}] :=
  (Message[XMLDeleteCases::root]; deleteAt[tree, DeleteCases[ps, {2}]]);
deleteAt[tree_, {}] := tree;
deleteAt[tree_, ps_] := Delete[tree, ps];

(* =========================================================== *)
(* Plain runners of XMLCases, XMLFirstCase and XMLDeleteCases  *)
(* and the position helpers                                     *)
(* =========================================================== *)

(* Base: a pattern, a Condition, or a rule over either, in document order. Cases
   and Position visit an element after the elements nested in it, so the
   positions of the matches are put in document order; a rule is then applied
   to the matched elements in that order, its body evaluated once for each it
   gives a value for, up to n. A Condition in the body can reject a match, so
   then every match is a candidate. *)
casesC[tree_, r : Verbatim[RuleDelayed][lhs_, _], n_] :=
  Cases[If[bodyConditionQ[Extract[r, {2}, Hold]], matchesInOrder[tree, lhs], firstMatches[tree, lhs, n]],
    r, {1}, n];
casesC[tree_, pat_, n_] := firstMatches[tree, pat, n];

(* The sites casesC takes its elements from: those of a rule's left-hand side,
   less those its body rejects, the body evaluated as casesC evaluates it. *)
plainPositions[tree_, r : Verbatim[RuleDelayed][lhs_, _], n_] /; bodyConditionQ[Extract[r, {2}, Hold]] :=
  Select[positionsInOrder[tree, lhs], Replace[Extract[tree, #], {r, _ :> $unmatched}] =!= $unmatched &, n];
plainPositions[tree_, Verbatim[RuleDelayed][lhs_, _], n_] := plainPositions[tree, lhs, n];
plainPositions[tree_, pat_, Infinity] := positionsInOrder[tree, pat];
plainPositions[tree_, pat_, n_] := firstMatchPositions[tree, pat, n];

(* The first n elements of tree, below its root, that match pat, in document
   order, the search stopping early. *)
firstMatches[tree_, pat_, Infinity] := matchesInOrder[tree, pat];
firstMatches[tree_, pat_, n_] := Extract[tree, firstMatchPositions[tree, pat, n]];

(* Position stops at the nth match in Cases order, which visits an element
   after the elements nested in it. A match earlier in document order that it
   has not visited is visited after one it has, so it is an element that one is
   nested in: the first n in document order are among the matches found and the
   matches on the way down to them. Each of these is tested once. *)
firstMatchPositions[tree_, pat_, n_] :=
  With[{ps = Position[tree, pat, Infinity, n, Heads -> False]},
    Take[#[[documentOrdering[#]]], UpTo[n]] & @ Join[ps, Select[
      Complement[Join @@ (Table[Take[#, k], {k, Length[#] - 1}] &) /@ ps, ps],
      MatchQ[Extract[tree, #], pat] &]]];

(* The elements of tree, below its root, that match pat, in document order.
   Extract reads {} as the whole tree, not as no positions. *)
matchesInOrder[tree_, pat_] :=
  Replace[positionsInOrder[tree, pat], {{} -> {}, ps_ :> Extract[tree, ps]}];

(* The positions of those elements. *)
positionsInOrder[tree_, pat_] :=
  Replace[Position[tree, pat, Infinity, Heads -> False], {{} -> {}, ps_ :> fromCasesOrder[ps]}];

(* Positions in Cases order, as Position gives them, put in document order.
   Cases visits an element right after the elements nested in it, so the
   matches nested in a match m come as one block right before it; moving m to
   the start of its block gives document order. So the positions are ordered
   by the start of their block, and at one start the outer, the later in Cases
   order, first. A match with others nested in it is one right after a position
   below it; without such a match the order is already document order. A sort
   of the padded positions would cost their depth for every match. *)
fromCasesOrder[ps_] :=
  With[{outer = 1 + Select[Pick[Range[Length[ps] - 1], UnitStep[Differences[Length /@ ps]], 0],
      belowQ[ps[[#]], ps[[# + 1]]] &]},
    If[outer === {}, ps,
      Module[{starts = Range[Length[ps]]},
        starts[[outer]] = blockStart[ps, #] & /@ outer;
        ps[[Ordering @ Transpose[{starts, -Range[Length[ps]]}]]]]]];

belowQ[p_, q_] := Length[p] > Length[q] && Take[p, Length[q]] === q;

(* The first position of the block of matches nested in the match at i: the
   positions before it that are below it end right before it. A binary search,
   as whether a position is below it changes once, from False to True. *)
blockStart[ps_, i_] :=
  Module[{lo = 1, hi = i - 1, mid},
    While[lo < hi,
      mid = Quotient[lo + hi, 2];
      If[belowQ[ps[[mid]], ps[[i]]], hi = mid, lo = mid + 1]];
    lo];

(* Base: the first match in document order, the search stopping early. A rule's
   body is evaluated for that match only, unless a Condition on the body
   rejects it and the search goes on. *)
firstC[tree_, r : Verbatim[RuleDelayed][lhs_, _], default_] :=
  Replace[firstMatchPosition[tree, lhs], {
    None -> default,
    p_ :> Replace[Extract[tree, p], {r,
      _ :> FirstCase[Drop[matchesInOrder[tree, lhs], UpTo[1]], r, default, {1}]}]}];
firstC[tree_, pat_, default_] :=
  Replace[firstMatchPosition[tree, pat], {None -> default, p_ :> Extract[tree, p]}];

(* The first match in document order, or None. *)
firstMatchPosition[tree_, pat_] :=
  Replace[firstMatchPositions[tree, pat, 1], {{p_} :> p, {} -> None}];

(* Base: a pattern or a Condition *)
deleteC[tree : XMLObject["Document"][_, root_, _], pat_] /; MatchQ[root, pat] :=
  (Message[XMLDeleteCases::root]; ReplacePart[tree, 2 -> DeleteCases[root, pat, Infinity]]);
deleteC[tree_, pat_] := DeleteCases[tree, pat, Infinity];
