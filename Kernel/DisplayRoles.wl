(* ::Package:: *)
(* HTMLPatterns: the display-role substrate (ADR 0002's Layer 1), shared by
   HTMLInnerText, HTMLToNotebook and HTMLToTree, and the inner-text walk over it *)

(* Used by Notebook.wl, Text.wl and Tree.wl *)
PackageScoped[ruleLookups]
PackageScoped[roleOf]
PackageScoped[innerText]

(* Used by Notebook.wl *)
PackageScoped[normWS]
PackageScoped[noRule]

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

(* ---- Role rules: an Association sugars to an ordered rule list; first
   match wins. A string left-hand side is a CSS selector, as anywhere an XML
   pattern goes. ---- *)
$displayRoles = {"Block", "Inline", "Preformatted", "LineBreak", "Skip"};
validRoleQ[r_] := MemberQ[$displayRoles, r];

(* Each rule's left-hand side is compiled like a query, and must be an element
   pattern: a rule is tried against one element at a time. compileRule gives
   {rule, readings}, the readings being those of the list keys it names, or
   $Failed for an entry that is refused, a non-rule among them. *)
compileRule[Verbatim[Rule][lhs_, r_], head_, readings_] :=
  Replace[elementQuery[compileWith[lhs, head, readings], lhs, head, "badpat"],
    c_Association :> {c["Plain"] -> r, c["Readings"]}];
compileRule[rule_RuleDelayed, head_, readings_] :=
  Replace[
    elementQuery[
      compileWith[RuleDelayed @@ Join[Hold @@ {rule[[1]]}, Extract[rule, {2}, Hold]], head, readings],
      rule[[1]], head, "badpat"],
    c_Association :> {c["Plain"], c["Readings"]}];
compileRule[x_, head_, _] := With[{h = head}, Message[MessageName[h, "notrule"], x]; $Failed];

(* ruleLookups[{rules1, rules2, ...}, head, tree]: for each rule set, a
   function from an element of tree to the value of the first rule that matches
   it, or noRule; $Failed if any set is refused. The readings table is resolved
   once for them all. A rule naming a list key is matched on the element with
   its token lists attached, each distinct raw value on the tree split once;
   the element itself is never changed, so a caller walks the tree as it is. *)
ruleLookups[sets_List, head_, tree_] :=
  With[{readings = readingsInForce[]},
    If[readings === $Failed, $Failed,
      With[{lookups = ruleLookup[#, head, readings, tree] & /@ sets},
        If[MemberQ[lookups, $Failed], $Failed, lookups]]]];

ruleLookup[rules_, head_, readings_, tree_] :=
  With[{cs = compileRule[#, head, readings] & /@ If[AssociationQ[rules], Normal[rules], Flatten[{rules}]]},
    If[MemberQ[cs, $Failed], $Failed,
      With[{rs = Append[cs[[All, 1]], _ -> noRule], attach = materialiser[tree, Union @@ cs[[All, 2]]]},
        Replace[attach[#], rs] &]]];

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
