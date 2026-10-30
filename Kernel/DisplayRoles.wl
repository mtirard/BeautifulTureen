(* ::Package:: *)
(* HTMLPatterns: the display-role substrate (ADR 0002's Layer 1), shared by
   HTMLInnerText, HTMLToNotebook and HTMLToTree, and the inner-text walk over it *)

(* Used by Notebook.wl, Text.wl and Tree.wl *)
PackageScoped[ruleLookups]
PackageScoped[roleOf]
PackageScoped[innerText]
PackageScoped[documentRoot]

(* Used by Notebook.wl *)
PackageScoped[normWS]
PackageScoped[noRule]
PackageScoped[unmarked]

(* =========================================================== *)
(* Display-role substrate (shared Layer 1)                     *)
(*                                                              *)
(* The classification that both readable-text extraction        *)
(* (HTMLInnerText) and notebook conversion (HTMLToNotebook)     *)
(* build on. Each element is classified by tag alone (the       *)
(* frozen user-agent stylesheet) into one of five display       *)
(* roles \[LongDash] Block, Inline, Preformatted, LineBreak, Skip \[LongDash] with   *)
(* a user "Roles" override layer (ruleLookups + roleOf). The   *)
(* emitters that sit on top of this substrate then decide *what *)
(* form* each placed element takes (HTMLInnerText: text; *)
(* HTMLToNotebook: a Cell or box \[LongDash] its own Layer 2). roleOf is   *)
(* message-head-parameterized so each public function reports   *)
(* a bad role rule under its own ::badrole.                     *)
(* =========================================================== *)

(* ---- Frozen UA tables: WHATWG HTML 15 "Rendering" defaults ---- *)
$htmlBlockTags = {"html", "body", "address", "article", "aside", "blockquote",
  "center", "dd", "details", "summary", "dialog", "dir", "div", "dl", "dt",
  "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3", "h4",
  "h5", "h6", "header", "hgroup", "hr", "legend", "li", "main", "menu", "nav",
  "ol", "p", "section", "search", "table", "caption", "colgroup", "thead",
  "tbody", "tfoot", "tr", "td", "th", "ul"};
$htmlPreTags = {"pre", "listing", "plaintext", "xmp"};
(* 15.3.1's display: none list; noscript, hidden there when scripting is on; and
   textarea, a replaced element whose content has no CSS box *)
$htmlSkipTags = {"area", "base", "basefont", "datalist", "head", "link", "meta",
  "noembed", "noframes", "param", "rp", "script", "style", "template", "title",
  "noscript", "textarea"};

(* Collapse every run of HTML whitespace to a single space \[LongDash] the Normal-whitespace
   primitive shared by both emitters. Not WL's Whitespace: CSS never collapses
   a no-break space. *)
normWS[s_String] := StringReplace[s, HTMLWhitespace -> " "];

defaultRole[tag_String] := Which[
  MemberQ[$htmlSkipTags, tag], "Skip",
  tag === "br",               "LineBreak",
  MemberQ[$htmlPreTags, tag],  "Preformatted",
  MemberQ[$htmlBlockTags, tag], "Block",
  True,                        "Inline"];
defaultRole[_] := "Inline";

(* ---- Role and construct rules: an Association sugars to
   an ordered rule list; the first rule that selects an element wins. A
   string key is a CSS selector, as anywhere an XML pattern goes. ---- *)
$displayRoles = {"Block", "Inline", "Preformatted", "LineBreak", "Skip"};
validRoleQ[r_] := MemberQ[$displayRoles, r];

(* Every rule is run once on the tree engine, against the input as given,
   before the walk. A key that is a rule is a query, whose counted element
   positions get the value; a CSS string is a query when its translation is
   one, a context selector; any other key is an element test, each element
   tested as the pattern root, its names bound for the value from its first
   result. The walk asks about an element, not a position, and equal
   elements at two positions can get different values, so each element a
   rule selects is marked with its position, an attribute keyMark -> pos.
   The walkers read attributes by name, so the mark is unseen, and an
   element given to user code is unmarked first. *)

(* ruleLookups[{rules1, rules2, ...}, head, tree]: {marked, lookups}, tree
   with every element a rule selects marked, and for each rule set a function
   from an element of marked to the value of the first rule that selects it,
   or noRule; $Failed if any set is refused. The readings table is checked
   whatever the rules, so that a bad one is refused once. *)
ruleLookups[sets_List, head_, tree_] :=
  Catch[
    If[readingsInForce[] === $Failed, refuseRule[]];
    With[{tables = ruleTable[#, head, tree] & /@ sets},
      {markedTree[tree, Union @@ (Keys /@ tables)], lookupIn /@ tables}],
    $ruleRefusal];

(* Position -> value for one rule set, the first rule's value where several
   select one element. *)
ruleTable[rules_, head_, tree_] :=
  Join[<||>, Sequence @@ Reverse[rulePositions[#, head, tree] & /@ If[AssociationQ[rules], Normal[rules], Flatten[{rules}]]]];

refuseRule[] := Throw[$Failed, $ruleRefusal];

rulePositions[r : (Rule | RuleDelayed)[key_, _], head_, tree_] :=
  If[queryKeyQ[key], queryKeyPositions, testKeyPositions][key, heldValue[r], head, tree];
rulePositions[x_, head_, _] := (Message[MessageName[head, "notrule"], x]; refuseRule[]);

queryKeyQ[_Rule | _RuleDelayed] := True;
queryKeyQ[s_String] := MatchQ[Quiet[cssTree[s]], {"context", _}];
queryKeyQ[_] := False;

(* A rule's value, held. A Rule's was evaluated when it was given; a
   Condition in it is part of the value, not a test. *)
heldValue[r_RuleDelayed] := Extract[r, {2}, Hold];
heldValue[r_Rule] := Replace[Extract[r, {2}, Hold], Hold[c_Condition] :> Hold[Identity[c]]];

(* A query key's names are not in scope in the value, which is evaluated once
   for all the positions of its counted names. The bare input's root is never
   counted (ADR 0018), so a query cannot select it. A position that is not an
   element is keytarget. *)
queryKeyPositions[key_, value_, head_, tree_] :=
  With[{ps = Replace[runQuery[compileQuery[head, key], Replace[tree, s_String :> {s}], "CountedPositions", Infinity], {
      $Failed :> refuseRule[],
      rs_ :> DeleteDuplicates[Catenate[Catenate[rs]]]}]},
    Replace[SelectFirst[ps, !MatchQ[#, {__Integer?Positive}] &],
      t : Except[_Missing] :> (Message[MessageName[head, "keytarget"], t]; refuseRule[])];
    If[ps === {}, <||>, AssociationThread[ps, ConstantArray[ReleaseHold[value], Length[ps]]]]];

(* An element test is checked as XMLMatchQ checks one, then run as the query
   r : key :> value counting r alone, so that each element it matches is one
   result and the other names take their matches in its first solution
   (its "Solutions"). An XMLDocument root is no test of an element. A bare
   element is matched in a list around it, at the same positions, so that
   its root is tested too. *)
testKeyPositions[key_, value_, head_, tree_] :=
  Module[{r},
    If[documentKeyQ[key], Message[MessageName[head, "badpat"], key]; refuseRule[]];
    If[treeMatcher[head, key, False] === $Failed, refuseRule[]];
    With[{names = Select[namesIn[Hold[key]], !FreeQ[value, Replace[#, Hold[s_] :> HoldPattern[s]]] &],
        sols = Replace[runQuery[compileQuery[head, RuleDelayed @@ Join[Hold @@ {Pattern @@ {r, key}}, value], {Hold[r]}],
          Replace[tree, x : (_XMLElement | _String) :> {x}], "Solutions", Infinity], rs_List :> Catenate[rs]]},
      Which[sols === $Failed, refuseRule[], sols === {}, Return[<||>, Module]];
      With[{constant = If[names === {}, ReleaseHold[value]]},
        Association[(First[First[#[Hold[r]]]] -> If[names === {}, constant, boundValue[value, names, #]]) & /@ sols]]]];

documentKeyQ[_XMLDocument] := True;
documentKeyQ[Verbatim[Pattern][_, p_] | Verbatim[Condition][p_, _] | Verbatim[PatternTest][p_, _]] := documentKeyQ[p];
documentKeyQ[alts_Alternatives] := AnyTrue[List @@ alts, documentKeyQ];
documentKeyQ[_] := False;

(* The value with each name replaced by what it binds; a name that is not
   bound, in an Alternatives branch that did not match, is Sequence[]. *)
boundValue[value_, names_, sol_] :=
  ReleaseHold[value /. (Replace[#, Hold[s_] :> (HoldPattern[s] -> Replace[Lookup[sol, Key[#], None], {None :> Sequence[], {_, vals_} :> Sequence @@ vals}])] & /@ names)];

(* ---- Marks ---- *)

lookupIn[table_] := Function[el, Lookup[table, Key[markOf[el]], noRule]];

markOf[XMLElement[_, attrs_List, _]] := Lookup[attrs, keyMark, None];
markOf[_] := None;

(* The element or tree with its marks removed, as user code is given it. *)
unmarked[x_] := If[FreeQ[x, keyMark], x, DeleteCases[x, HoldPattern[keyMark -> _], Infinity]];

(* tree with the elements at positions ps marked, walking only the parts
   that hold one. Positions count element children from the document. *)
markedTree[tree_, {}] := tree;
markedTree[tree_, ps_] :=
  Block[{$marks = AssociationThread[ps -> True],
      $above = AssociationThread[Union @@ (Most[FoldList[Append, {}, #]] & /@ ps) -> True]},
    markedInput[tree]];

markedInput[XMLObject["Document"][p_, root_, e_]] := XMLObject["Document"][p, markedElement[root, {1}], e];
markedInput[l_List] := markedItems[l, {}];
markedInput[x_XMLElement] := markedElement[x, {1}];
markedInput[x_] := x;

markedItems[items_, pos_] :=
  MapThread[If[MatchQ[#1, _XMLElement], markedElement[#1, Append[pos, #2]], #1] &,
    {items, Accumulate[Boole[MatchQ[#, _XMLElement]] & /@ items]}];

markedElement[XMLElement[t_, a_, c_], pos_] :=
  XMLElement[t, If[KeyExistsQ[$marks, pos], Append[a, keyMark -> pos], a],
    If[KeyExistsQ[$above, pos], markedItems[c, pos], c]];

(* The document's root element, which the walkers start from; any other
   input as it is. *)
documentRoot[XMLObject["Document"][_, root_, _]] := root;
documentRoot[x_] := x;

(* roleOf: first matching rule wins; a non-role RHS messages (under the caller's
   own ::badrole) and defers to the frozen table; no match defers to the table;
   unknown tag -> Inline. *)
roleOf[el : XMLElement[tag_, _, _], lookup_, msgHead_] :=
  With[{r = lookup[el]},
    Which[
      MatchQ[r, noRule | _XMLElement], defaultRole[tag],
      validRoleQ[r],          r,
      True, (Message[MessageName[msgHead, "badrole"], r]; defaultRole[tag])
    ]];

(* ---- Pass A: tree -> token stream (itV = verbatim text; itNl = <br>;
   itBr = block boundary). The preserve flag rides down the recursion. roleFn
   gives an element's role, messaging a bad one under the caller's symbol. ---- *)
itToks[s_String, False, _] := {s};
itToks[s_String, True, _] := {itV[s]};
itToks[l_List, pre_, roleFn_] := Flatten[itToks[#, pre, roleFn] & /@ l];
itToks[el_XMLElement, pre_, roleFn_] := itElToks[el, roleFn[el], pre, roleFn];
itToks[_, _, _] := {};

itElToks[XMLElement[_, _, ch_], role_, pre_, roleFn_] :=
  Switch[role,
    "Skip",         {},
    "LineBreak",    {itNl},
    "Preformatted", Join[{itBr}, Flatten[itToks[#, True, roleFn] & /@ ch], {itBr}],
    "Block",        Join[{itBr}, Flatten[itToks[#, pre, roleFn] & /@ ch], {itBr}],
    _,              Flatten[itToks[#, pre, roleFn] & /@ ch]];

(* A top element that is not being rendered gives its descendant text content,
   as the innerText getter does (step 1): all of it, a "Skip" inside included,
   but trimmed at both ends as every result is. A list's top elements are each
   such an element. *)
itTopToks[el_XMLElement, roleFn_] :=
  With[{role = roleFn[el]},
    If[role === "Skip",
      {itV[StringTrim[textContentWalk[el], HTMLWhitespace]]},
      itElToks[el, role, False, roleFn]]];
itTopToks[l_List, roleFn_] := Flatten[itTopToks[#, roleFn] & /@ l];
itTopToks[x_, roleFn_] := itToks[x, False, roleFn];

(* ---- Pass B: tokens -> atoms -> string. Words and soft spaces from normal
   text; verbatim text is one opaque atom; break markers pass through. ---- *)
atomize[s_String] := StringCases[normWS[s],
  {" " -> itSp, ww : (Except[" "] ..) :> itWd[ww]}];
atomize[itV[s_]] := {itVd[s]};
atomize[x_] := {x};

contentQ[itWd[_] | itVd[_]] := True;
contentQ[_] := False;
contentText[itWd[s_]] := s;
contentText[itVd[s_]] := s;

atomRank[itSp] := 1;
atomRank[itNl] := 2;
atomRank[itBr] := 3;
atomRank[_] := 0;

(* Each <br> in a run of breaks is a newline of its own; a block boundary in the
   run still gives one separator. *)
glueStr[1, _, _] := " ";
glueStr[2, nls_, _] := StringRepeat["\n", nls];
glueStr[3, _, bsep_] := bsep;
glueStr[_, _, _] := "";

itSerialize[toks_, bsep_] :=
  First @ Fold[
    Function[{state, a},
      Replace[state, {out_, glue_, nls_} :>
        If[contentQ[a],
          {out <> If[out =!= "", glueStr[glue, nls, bsep], ""] <> contentText[a], 0, 0},
          {out, Max[glue, atomRank[a]], nls + Boole[a === itNl]}
        ]]],
    {"", 0, 0},
    Flatten[atomize /@ toks]];

(* The inner text of tree, given roleFn, which gives an element's role, and the
   block separator bsep. HTMLToNotebook uses it for a table cell's text. *)
innerText[tree_, roleFn_, bsep_] := itSerialize[itTopToks[tree, roleFn], bsep];
