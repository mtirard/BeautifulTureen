(* ::Package:: *)
(* HTMLPatterns: FromCSSSelector, a CSS selector to the XML pattern it says (ADR 0017) *)

(* =========================================================== *)
(* FromCSSSelector (ADR 0017)                                   *)
(*                                                              *)
(* A CSS selector, tokenised by CSS Syntax 3 and read as static *)
(* Selectors Level 4, to the XML pattern it says. The string is *)
(* parsed whole first, so a selector that is not valid CSS is   *)
(* ::invalid wherever the fault is, into a tree:                *)
(*   a selector list   {cx, ...}                                *)
(*   a selector        cx[{compound, ...}, {link, ...}]         *)
(*   a compound        cp[{simple, ...}, its text]              *)
(*   a relative one    rel[link, cx[...]], in :has()            *)
(* The tree is then translated, and what cannot be translated   *)
(* is ::unsupported or ::impossible, naming the workaround.     *)
(* The output holds only public symbols and the names made by   *)
(* cssFreshName, so it can be spliced into a larger pattern.    *)
(* =========================================================== *)

PackageExported[FromCSSSelector]
FromCSSSelector::usage = "FromCSSSelector[\"selector\"] gives the XML pattern that a CSS selector describes, for use in XMLCases, XMLFirstCase, XMLDeleteCases and XMLMatchQ, or as a stage of Child, Descendant, Adjacent or Sibling. A CSS selector string can also be given directly wherever these take a pattern, and means its translation. The selector is matched as written: letter case matters in tag names, attribute names and values, and attributes that the HTML importer adds, such as rowspan=\"1\", count as present. [foo~=\"x\"] becomes \"fooList\" -> \"x\", which needs a reading for foo in $AttributeReadings or in the \"AttributeReadings\" option of the function that runs the query.";
FromCSSSelector::invalid = "`1` is not a valid CSS selector: `2`.";
FromCSSSelector::unsupported = "`1` is valid CSS, but `2` cannot be translated to an XML pattern. `3`";
FromCSSSelector::impossible = "`2` in `1` depends on a browser, such as user input, layout or the page's URL, and cannot be matched in a static document. `3`";

FromCSSSelector[s_String] := cssTranslate[s];
FromCSSSelector[x_] := (Message[FromCSSSelector::string, 1, HoldForm[FromCSSSelector[x]]]; $Failed);
FromCSSSelector[args___] := (argumentCountMessage[FromCSSSelector, Length[{args}], {1, 1}]; $Failed);

(* An invalid selector is caught before any translation, as the whole string
   is parsed first. *)
cssTranslate[s_] :=
  Block[{$cssInput = cssPreprocess[s], $cssArgOf = None, $cssInHas = False},
    Catch[
      Catch[cssListPattern[cssParse[cssTokens[$cssInput]]], $cssRefused,
        Function[{why, tag}, cssRefusal[s, why]]],
      $cssInvalid,
      Function[{why, tag}, Message[FromCSSSelector::invalid, s, why]; $Failed]]];

cssRefusal[s_, {kind_, part_, how_}] := (Message[MessageName[FromCSSSelector, kind], s, part, how]; $Failed);

cssInvalid[why_String, pos_Integer] := Throw[why <> " at character " <> ToString[pos], $cssInvalid];
cssInvalid[why_String, pos_Integer, hint_String] :=
  Throw[why <> " at character " <> ToString[pos] <> "; " <> hint, $cssInvalid];
cssInvalid[why_String] := Throw[why, $cssInvalid];
cssRefuse[kind_, part_, how_] := Throw[{kind, part, how}, $cssRefused];

(* ASCII case-insensitivity, as Selectors requires for keywords: ToLowerCase
   would also fold letters such as \[CapitalEAcute]. *)
$cssFold = StringReplace[RegularExpression["[A-Z]"] :> ToLowerCase["$0"]];
cssLower[s_] := $cssFold[s];

(* ---- Tokens (CSS Syntax 3, sections 3 and 4) ---- *)

cssPreprocess[s_] :=
  StringReplace[s, {"\r\n" -> "\n", "\r" -> "\n", "\f" -> "\n", FromCharacterCode[0] -> "\:fffd"}];

(* The non-ASCII code points an identifier may hold unescaped (the current
   draft's list, after HTML's valid custom element names): U+00A0, for one,
   must be escaped. *)
$cssNonASCII = "\\x{B7}\\x{C0}-\\x{D6}\\x{D8}-\\x{F6}\\x{F8}-\\x{37D}\\x{37F}-\\x{1FFF}\\x{200C}\\x{200D}\\x{203F}\\x{2040}\\x{2070}-\\x{218F}\\x{2C00}-\\x{2FEF}\\x{3001}-\\x{D7FF}\\x{F900}-\\x{FDCF}\\x{FDF0}-\\x{FFFD}\\x{10000}-\\x{10FFFF}";
(* An escape: hex digits and one optional whitespace, or any other code point
   but a newline, or the end of the input. *)
$cssEscape = "\\\\(?:[0-9a-fA-F]{1,6}[ \\t\\n]?|[^\\n0-9a-fA-F]|\\z)";
$cssNameChar = "(?:[a-zA-Z0-9_\\-" <> $cssNonASCII <> "]|" <> $cssEscape <> ")";
$cssIdent = "(?:--|-?(?:[a-zA-Z_" <> $cssNonASCII <> "]|" <> $cssEscape <> "))" <> $cssNameChar <> "*";
cssStringRegex[q_] := q <> "(?:[^" <> q <> "\\\\\\n]|\\\\[\\s\\S]?)*" <> q <> "?";
cssClosedStringRegex[q_] := q <> "(?:[^" <> q <> "\\\\\\n]|\\\\[\\s\\S])*" <> q;

(* In the order consume-token tries them, the first that matches winning: so a
   "-" starts a number, then -->, then an identifier, before it is a delim. *)
$cssTokenKinds = {
  "comment" -> "/\\*[\\s\\S]*?(?:\\*/|\\z)",
  "ws" -> "[ \\t\\n]+",
  "string" -> cssStringRegex["\""] <> "|" <> cssStringRegex["'"],
  "hash" -> "#" <> $cssNameChar <> "+",
  "number" -> "[+-]?(?:[0-9]+(?:\\.[0-9]+)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?(?:%|" <> $cssIdent <> ")?",
  "cdc" -> "-->",
  "function" -> $cssIdent <> "\\(",
  "ident" -> $cssIdent,
  "cdo" -> "<!--",
  "delim" -> "[\\s\\S]"};

$cssTokenRegex = RegularExpression[StringRiffle[("(?:" <> # <> ")") & /@ Values[$cssTokenKinds], "|"]];
$cssTokenTests = MapAt[RegularExpression, $cssTokenKinds, {All, 2}];

(* tk[kind, value, start, end], with escapes resolved; comments are dropped,
   and are not whitespace. *)
cssTokens[s_] := cssToken[s, #] & /@ StringPosition[s, $cssTokenRegex, Overlaps -> False];

cssToken[s_, {i_, j_}] :=
  With[{text = StringTake[s, {i, j}]},
    cssTokenOf[SelectFirst[$cssTokenTests, StringMatchQ[text, Last[#]] &][[1]], text, s, i, j]];

cssTokenOf["comment", __] := Nothing;
cssTokenOf["ws", _, _, i_, j_] := tk["ws", " ", i, j];
cssTokenOf["string", text_, s_, i_, j_] :=
  With[{closed = StringMatchQ[text, RegularExpression[cssClosedStringRegex[StringTake[text, 1]]]]},
    Which[
      closed, tk["string", cssUnescape[StringTake[text, {2, -2}], ""], i, j],
      (* Open at the end of the input, it is closed; open at a newline, bad. *)
      j == StringLength[s], tk["string", cssUnescape[StringDrop[text, 1], ""], i, j],
      True, tk["badstring", text, i, j]]];
cssTokenOf["hash", text_, _, i_, j_] :=
  tk[If[StringMatchQ[StringDrop[text, 1], RegularExpression[$cssIdent]], "hash-id", "hash"],
    cssUnescape[StringDrop[text, 1], "\:fffd"], i, j];
cssTokenOf["number", text_, _, i_, j_] := tk["number", text, i, j];
cssTokenOf["function", text_, _, i_, j_] := tk["function", cssUnescape[StringDrop[text, -1], "\:fffd"], i, j];
cssTokenOf["ident", text_, _, i_, j_] := tk["ident", cssUnescape[text, "\:fffd"], i, j];
cssTokenOf[_, text_, _, i_, j_] := tk["delim", text, i, j];

(* A backslash at the end of the input is U+FFFD in a name, and nothing in a
   string; before a newline, in a string, it continues the line. *)
cssUnescape[s_, atEnd_] :=
  StringReplace[s, {
    RegularExpression["\\\\([0-9a-fA-F]{1,6})[ \\t\\n]?"] :> cssCodePoint[FromDigits["$1", 16]],
    RegularExpression["\\\\\\n"] -> "",
    RegularExpression["\\\\([\\s\\S])"] :> "$1",
    RegularExpression["\\\\\\z"] -> atEnd}];

cssCodePoint[n_] :=
  If[n == 0 || 16^^D800 <= n <= 16^^DFFF || n > 16^^10FFFF, "\:fffd", FromCharacterCode[n]];

(* ---- Blocks (CSS Syntax 3, section 5) ---- *)

(* [ ], ( ) and a function's ( ) become blk[opener, contents, end]. A block
   still open at the end of the input is closed there, without error. *)
cssBlocks[toks_] :=
  With[{stack = Fold[cssBlockStep, {{None, {}}}, toks]},
    Last @ First @ Nest[cssCloseBlock[#, StringLength[$cssInput]] &, stack, Length[stack] - 1]];

cssBlockStep[stack_, t : (tk["delim", "[" | "(", _, _] | tk["function", __])] := Append[stack, {t, {}}];
cssBlockStep[stack_, t : tk["delim", "]" | ")", _, _]] /; cssClosesQ[stack[[-1, 1]], t] :=
  cssCloseBlock[stack, t[[4]]];
cssBlockStep[stack_, t_] := MapAt[Append[t], stack, {-1, 2}];

cssCloseBlock[stack_, end_] :=
  MapAt[Append[blk[stack[[-1, 1]], stack[[-1, 2]], end]], Most[stack], {-1, 2}];

cssClosesQ[tk["delim", "[", __], tk["delim", "]", __]] := True;
cssClosesQ[tk["delim", "(", __] | tk["function", __], tk["delim", ")", __]] := True;
cssClosesQ[_, _] := False;

cssStart[tk[_, _, i_, _]] := i;
cssStart[blk[o_, _, _]] := cssStart[o];
cssEnd[tk[_, _, _, j_]] := j;
cssEnd[blk[_, _, j_]] := j;

(* The source text of a run of items, and of one item as a message shows it. *)
cssText[items_List] := StringTake[$cssInput, {cssStart[First[items]], cssEnd[Last[items]]}];
cssShown[blk[o_, _, _]] := cssShown[o];
cssShown[t_tk] := cssText[{t}];

cssWSQ[tk["ws", __]] := True;
cssWSQ[_] := False;

cssTrimWS[items_] :=
  With[{n = LengthWhile[items, cssWSQ]},
    If[n == Length[items], {}, Drop[Drop[items, n], -LengthWhile[Reverse[items], cssWSQ]]]];

(* ---- The grammar (Selectors Level 4, section 16) ---- *)

cssParse[toks_] := (
  Replace[FirstCase[toks, tk["badstring", __]],
    t_tk :> cssInvalid["a string cannot hold a newline that is not escaped", cssStart[t]]];
  Replace[FirstCase[toks, tk["delim", "\\", __]],
    t_tk :> cssInvalid["\\ before a newline is not an escape outside a string", cssStart[t]]];
  cssSelectorList[cssBlocks[toks]]);

cssSelectorList[items_] :=
  Replace[cssCommaSplit[items], {
    {{{}, _}} :> cssInvalid["the selector is empty"],
    parts_ :> (cssComplex[cssNonEmpty[#, items], False] & /@ parts)}];

(* The items between commas, each with whitespace trimmed, and the index of
   the comma before it (0 for the first). *)
cssCommaSplit[items_] :=
  With[{cs = Flatten[Position[items, tk["delim", ",", _, _], {1}, Heads -> False]]},
    MapThread[{cssTrimWS[items[[#1 + 1 ;; #2 - 1]]], #1} &, {Prepend[cs, 0], Append[cs, Length[items] + 1]}]];

cssNonEmpty[{{}, 0}, items_] :=
  cssInvalid["a selector is missing before ,", cssStart[First[Select[items, MatchQ[tk["delim", ",", _, _]]]]]];
cssNonEmpty[{{}, k_}, items_] := cssInvalid["a selector is missing after ,", cssStart[items[[k]]]];
cssNonEmpty[{seg_, _}, _] := seg;

(* Compounds and the links between them: a run of whitespace alone is a
   descendant combinator, and whitespace around >, +, ~ and || is ignored. A
   relative selector, in :has(), may start with a combinator. *)
cssComplex[items_, relative_] :=
  Module[{runs = SplitBy[cssColumns[items], cssSeparatorQ], lead = Descendant, compounds},
    If[cssSeparatorQ[runs[[1, 1]]],
      If[!relative,
        cssInvalid["a selector cannot start with " <> cssShown[runs[[1, 1]]], cssStart[runs[[1, 1]]]]];
      lead = cssLink[First[runs]];
      runs = Rest[runs];
      If[runs === {}, cssInvalid["a selector is missing after " <> cssShown[Last[items]], cssStart[Last[items]]]]];
    If[cssSeparatorQ[runs[[-1, 1]]],
      With[{c = Last[Select[runs[[-1]], cssCombinatorQ]]},
        cssInvalid["a selector cannot end with " <> cssShown[c], cssStart[c]]]];
    compounds = cssCompound /@ runs[[1 ;; ;; 2]];
    cssPseudoElementsLast[compounds];
    With[{c = cx[compounds, cssLink /@ runs[[2 ;; ;; 2]]]}, If[relative, rel[lead, c], c]]];

cssColumns[items_] :=
  SequenceReplace[items,
    {tk["delim", "|", i_, _], tk["delim", "|", k_, j_]} /; k == i + 1 :> tk["column", "||", i, j]];

cssCombinatorQ[tk["delim", ">" | "+" | "~", _, _] | tk["column", __]] := True;
cssCombinatorQ[_] := False;

cssSeparatorQ[t_] := cssWSQ[t] || cssCombinatorQ[t];

cssLink[run_] :=
  With[{cs = Select[run, cssCombinatorQ]},
    Switch[Length[cs],
      0, Descendant,
      1, cssLinkOf[First[cs]],
      _, cssInvalid["two combinators in a row", cssStart[cs[[2]]]]]];

cssLinkOf[tk["delim", ">", __]] := Child;
cssLinkOf[tk["delim", "+", __]] := Adjacent;
cssLinkOf[tk["delim", "~", __]] := Sibling;
cssLinkOf[tk["column", __]] := cssColumn;

(* A pseudo-element can only end the last compound of a selector, and is
   never valid in a pseudo-class's argument. *)
cssPseudoElementsLast[compounds_] := (
  Scan[Replace[FirstCase[First[#], _sPseudoElement],
      e_sPseudoElement :> cssInvalid[e[[1]] <> " can only end a selector", e[[2]]]] &,
    Most[compounds]];
  If[$cssArgOf =!= None,
    Replace[FirstCase[First[Last[compounds]], _sPseudoElement],
      e_sPseudoElement :> cssInvalid[e[[1]] <> " cannot be used inside " <> $cssArgOf, e[[2]]]]]);

(* A compound: at most one type selector, first, then subclass selectors, with
   only pseudo-classes after a pseudo-element. *)
cssCompound[parts_] :=
  With[{nodes = Replace[cssType[parts], {t_, rest_} :> Join[t, cssSubclasses[rest]]]},
    Replace[FirstPosition[nodes, _sPseudoElement, None, {1}], {k_} :>
      If[!FreeQ[Drop[nodes, k], _sId | _sClass | _sAttr, {1}],
        cssInvalid[nodes[[k, 1]] <> " must come last in its compound", nodes[[k, 2]]]]];
    cp[nodes, cssText[parts]]];

$cssTypeName = tk["ident", __] | tk["delim", "*", __];

cssType[{a : $cssTypeName, tk["delim", "|", __], b : $cssTypeName, r___}] := {{cssNamespaced[{a, b}]}, {r}};
cssType[{a : tk["delim", "|", __], b : $cssTypeName, r___}] := {{cssNamespaced[{a, b}]}, {r}};
cssType[{tk["ident", n_, __], r___}] := {{sType[n]}, {r}};
cssType[{tk["delim", "*", __], r___}] := {{sUniversal[]}, {r}};
cssType[parts_] := {{}, parts};

cssNamespaced[items_] := sRefuse["unsupported", cssText[items], $cssNamespaceHow];

cssSubclasses[{}] := {};
cssSubclasses[parts_] := Replace[cssSubclass[parts], {node_, rest_} :> Prepend[cssSubclasses[rest], node]];

cssSubclass[{tk["hash-id", v_, __], r___}] := {sId[v], {r}};
cssSubclass[{t : tk["hash", __], ___}] := cssInvalid[cssShown[t] <> " is not a valid id selector", cssStart[t]];
cssSubclass[{tk["delim", ".", __], tk["ident", v_, __], r___}] := {sClass[v], {r}};
cssSubclass[{t : tk["delim", ".", __], ___}] := cssInvalid["a class name is missing after .", cssStart[t]];
cssSubclass[{b : blk[tk["delim", "[", __], _, _], r___}] := {cssAttribute[b], {r}};
cssSubclass[{c : tk["delim", ":", __], tk["delim", ":", __], x : (tk["ident", __] | blk[tk["function", __], _, _]), r___}] :=
  {cssPseudoElement[c, x], {r}};
cssSubclass[{c : tk["delim", ":", __], x : tk["ident", __], r___}] := {cssPseudoClass[c, x], {r}};
cssSubclass[{c : tk["delim", ":", __], x : blk[tk["function", __], _, _], r___}] := {cssPseudoFunction[c, x], {r}};
cssSubclass[{c : tk["delim", ":", __], ___}] := cssInvalid["a pseudo-class name is missing after :", cssStart[c]];
cssSubclass[{t_, ___}] := cssInvalid["unexpected " <> cssShown[t], cssStart[t]];

(* ---- Attribute selectors ---- *)

(* The value must be one identifier or one string. No whitespace is allowed
   inside a matcher such as ^=, so its two delims must be adjacent. *)
cssAttribute[b : blk[_, items_, _]] :=
  With[{its = DeleteCases[cssMatchers[items], tk["ws", __]]},
    If[MatchQ[its, {$cssTypeName, tk["delim", "|", __], tk["ident", __], ___} | {tk["delim", "|", __], tk["ident", __], ___}],
      sRefuse["unsupported", cssText[{b}], $cssNamespaceHow],
      cssAttributeOf[its, b]]];

cssMatchers[items_] :=
  SequenceReplace[items, {
    {tk["delim", m : "~" | "|" | "^" | "$" | "*", i_, _], tk["delim", "=", k_, j_]} /; k == i + 1 :>
      tk["matcher", m <> "=", i, j],
    {tk["delim", "=", i_, j_]} :> tk["matcher", "=", i, j]}];

cssAttributeOf[{tk["ident", n_, __]}, _] := sAttr[n];
cssAttributeOf[{tk["ident", n_, __], tk["matcher", m_, __], tk["ident" | "string", v_, __]}, _] := sAttr[n, m, v, None];
cssAttributeOf[{tk["ident", n_, __], tk["matcher", m_, __], tk["ident" | "string", v_, __], f : tk["ident", flag_, __]}, _] :=
  If[MemberQ[{"i", "s"}, cssLower[flag]], sAttr[n, m, v, cssLower[flag]],
    cssInvalid["unknown attribute flag " <> cssShown[f], cssStart[f]]];
cssAttributeOf[{tk["ident", __], tk["matcher", __], tk["ident" | "string", __], t_, ___}, _] :=
  cssInvalid["unexpected " <> cssShown[t] <> " in an attribute selector", cssStart[t]];
cssAttributeOf[{tk["ident", __], tk["matcher", __], v_, ___}, _] :=
  cssInvalid["an attribute value must be an identifier or a string, not " <> cssShown[v], cssStart[v]];
cssAttributeOf[{tk["ident", __], m : tk["matcher", __]}, _] :=
  cssInvalid["an attribute value is missing after " <> cssShown[m], cssStart[m]];
cssAttributeOf[{}, b_] := cssInvalid["an attribute selector is empty", cssStart[b]];
cssAttributeOf[{t : Except[tk["ident", __]], ___}, _] :=
  cssInvalid["an attribute name is missing before " <> cssShown[t], cssStart[t]];
cssAttributeOf[{_, t_, ___}, _] := cssInvalid["unexpected " <> cssShown[t] <> " in an attribute selector", cssStart[t]];

(* ---- Pseudo-classes and pseudo-elements ---- *)

(* Translated. The child-indexed ones are positions among the parent's
   element children (ADR 0016): each is cssPos[fromEnd, a, b, of, text], the
   index a k + b, k >= 0, counted from the start or the end, among all the
   children (of None), those of the compound's type ("type"), or those that
   match a selector ("of", then the pattern). *)
$cssPseudoClasses = {"empty", "checked", "link", "any-link", "only-child", "only-of-type",
  "first-child", "last-child", "first-of-type", "last-of-type", "root", "scope"};

(* The pseudo-classes of the only top element (ADR 0018). *)
$cssRootPseudoClasses = "root" | "scope";

$cssPositions = <|
  "first-child" -> {{False, 0, 1, None}}, "last-child" -> {{True, 0, 1, None}},
  "only-child" -> {{False, 0, 1, None}, {True, 0, 1, None}},
  "first-of-type" -> {{False, 0, 1, "type"}}, "last-of-type" -> {{True, 0, 1, "type"}},
  "only-of-type" -> {{False, 0, 1, "type"}, {True, 0, 1, "type"}}|>;

$cssNth = <|"nth-child" -> {False, None}, "nth-last-child" -> {True, None},
  "nth-of-type" -> {False, "type"}, "nth-last-of-type" -> {True, "type"}|>;

(* Valid Selectors 4 that is not translated, with the workaround. *)
$cssChildIndexedHow = "It needs the element's parent, so it can be in a compound of the selector or of a relative selector in :has(), but not in an argument of :not(), :is() or :where(). Write a list of patterns for the parent's children instead, as in Child[XMLDocument[] | XMLPattern[_], {XMLPattern[\"li\"], ___}].";
$cssFormHow = "Write the test as a condition on an XMLPattern.";
(* :root and :scope are the only top element (ADR 0018), at the start of a
   selector. *)
$cssRootHow = "It matches the only top element, which has no parent or sibling in the tree, so it can only be in the first compound of a selector, followed by > or a descendant combinator, as in :root > body.";
$cssRootInsideHow = "It cannot be in an argument of :not(), :is(), :where(), :has() or :nth-child(). Put it in the first compound of the selector, as in :root > body.";
$cssUnsupported = Join[
  AssociationMap[$cssFormHow &, {"enabled", "disabled", "read-only", "read-write", "placeholder-shown",
    "default", "unchecked", "indeterminate", "valid", "invalid", "in-range", "out-of-range",
    "required", "optional", "defined"}]];
$cssUnsupportedFunctions =
  <|"lang" -> "Use Descendant[XMLPattern[_, \"lang\" -> ...], ...], which takes the lang of any ancestor, not only the nearest.",
    "dir" -> $cssFormHow|>;

(* Valid, but true only in a browser. *)
$cssShadowHow = "A document has no shadow trees.";
$cssStateHow = "Leave it out of the selector to match the elements in any state.";
$cssImpossible = Join[
  AssociationMap[$cssStateHow &, {"visited", "hover", "active", "focus", "focus-visible", "focus-within",
    "playing", "paused", "seeking", "buffering", "stalled", "muted", "volume-locked", "open",
    "popover-open", "modal", "fullscreen", "picture-in-picture", "autofill", "-webkit-autofill",
    "user-valid", "user-invalid"}],
  <|"target" -> "To match the element that a fragment names, use XMLPattern[_, \"id\" -> fragment].",
    "host" -> $cssShadowHow|>];
$cssImpossibleFunctions = <|"host" -> $cssShadowHow, "host-context" -> $cssShadowHow|>;

(* The functional pseudo-classes, for the message on one written without
   parentheses. *)
$cssPseudoFunctions = {"not", "is", "where", "has", "nth-child", "nth-last-child", "nth-of-type",
  "nth-last-of-type", "lang", "dir", "host-context"};

$cssLegacyPseudoElements = {"before", "after", "first-line", "first-letter"};
$cssPseudoElements = {"before", "after", "first-line", "first-letter", "prefix", "suffix", "marker",
  "placeholder", "file-selector-button", "details-content", "selection", "target-text", "search-text",
  "spelling-error", "grammar-error", "backdrop", "cue", "column", "scroll-marker", "scroll-marker-group",
  "view-transition"};
$cssPseudoElementFunctions = {"highlight", "cue", "part", "slotted", "view-transition-group",
  "view-transition-image-pair", "view-transition-old", "view-transition-new", "scroll-button", "picker"};

cssPseudoElementHow["first-letter"] := "To get the first letter of each match, use StringTake[HTMLInnerText[e], UpTo[1]].";
cssPseudoElementHow[_] := "Pseudo-elements are generated or laid out by a browser, and are not elements of the document.";

cssPseudoClass[c_, x : tk["ident", n_, __]] :=
  With[{name = cssLower[n], text = cssText[{c, x}]},
    Which[
      MemberQ[$cssPseudoClasses, name], sPseudo[name, text],
      KeyExistsQ[$cssUnsupported, name], sRefuse["unsupported", text, $cssUnsupported[name]],
      KeyExistsQ[$cssImpossible, name], sRefuse["impossible", text, $cssImpossible[name]],
      MemberQ[$cssLegacyPseudoElements, name], sPseudoElement[text, cssStart[c], name],
      MemberQ[$cssPseudoFunctions, name], cssInvalid[text <> " needs an argument in parentheses", cssStart[c]],
      True, cssInvalid["unknown pseudo-class " <> text, cssStart[c]]]];

cssPseudoFunction[c_, b : blk[tk["function", n_, __], items_, _]] :=
  With[{name = cssLower[n], text = cssText[{c, b}], where = ":" <> n <> "()"},
    Switch[name,
      "not", sNot[cssArguments[items, where, cssStart[c], False, False], text],
      "is" | "where", sIs[cssArguments[items, where, cssStart[c], False, True], text],
      "has",
        If[$cssInHas, cssInvalid[":has() cannot be used inside :has()", cssStart[c]]];
        sHas[Block[{$cssInHas = True}, cssArguments[items, where, cssStart[c], True, False]], text],
      "nth-child" | "nth-last-child" | "nth-of-type" | "nth-last-of-type",
        cssNthOf[$cssNth[name], items, where, cssStart[c], text],
      "matches", cssInvalid["unknown pseudo-class " <> where, cssStart[c], "write :is() instead"],
      "contains" | "-soup-contains" | "-soup-contains-own",
        cssInvalid["unknown pseudo-class " <> where, cssStart[c],
          "soupsieve adds it; test the text in a condition instead, as in e : XMLPattern[...] /; StringContainsQ[HTMLTextContent[e], ...]"],
      _, Which[
        KeyExistsQ[$cssUnsupportedFunctions, name], sRefuse["unsupported", text, $cssUnsupportedFunctions[name]],
        KeyExistsQ[$cssImpossibleFunctions, name], sRefuse["impossible", text, $cssImpossibleFunctions[name]],
        MemberQ[$cssPseudoClasses, name], cssInvalid[":" <> n <> " takes no argument", cssStart[c]],
        True, cssInvalid["unknown pseudo-class " <> where, cssStart[c]]]]];

(* The arguments of :not(), :is(), :where() and :has(). :is() and :where() are
   forgiving: an argument that is not valid is dropped, and none at all is
   valid. *)
cssArguments[items_, where_, pos_, relative_, forgiving_] :=
  Block[{$cssArgOf = where},
    If[forgiving,
      Cases[cssCommaSplit[items], {seg : Except[{}], _} :>
        Catch[cssComplex[seg, relative], $cssInvalid, Nothing &]],
      Replace[cssCommaSplit[items], {
        {{{}, _}} :> cssInvalid[where <> " needs an argument", pos],
        parts_ :> (cssComplex[cssNonEmpty[#, items], relative] & /@ parts)}]]];

(* :nth-child(An+B of S): the An+B, then for the -child forms an optional
   "of" and a selector list. *)
cssNthOf[{fromEnd_, of_}, items_, where_, pos_, text_] :=
  With[{k = FirstPosition[items, tk["ident", o_, __] /; cssLower[o] === "of", None, {1}, Heads -> False]},
    If[k === None,
      sNth[cssPos[fromEnd, Sequence @@ cssAnB[cssTrimWS[items], where, pos], of, text], None],
      If[of =!= None || k === {1} || !cssWSQ[items[[First[k] - 1]]],
        cssInvalid["unexpected \"of\" in " <> where, cssStart[items[[First[k]]]]]];
      sNth[cssPos[fromEnd, Sequence @@ cssAnB[cssTrimWS[Take[items, First[k] - 1]], where, pos], "of", text],
        cssArguments[Drop[items, First[k]], where, pos, False, False]]]];

(* An+B (CSS Syntax 3, section 6), read from its source text: odd, even, an
   integer, or An+B with whitespace only around the sign of B. *)
$cssAnB = RegularExpression["(?i)([+-]?)([0-9]*)n(?:[ \\t\\n]*([+-])[ \\t\\n]*([0-9]+))?"];

cssAnB[{}, where_, pos_] := cssInvalid[where <> " needs an argument", pos];
cssAnB[items_, where_, _] :=
  With[{t = cssText[items]},
    Which[
      StringMatchQ[t, "odd", IgnoreCase -> True], {2, 1},
      StringMatchQ[t, "even", IgnoreCase -> True], {2, 0},
      StringMatchQ[t, RegularExpression["[+-]?[0-9]+"]], {0, ToExpression[StringDelete[t, "+"]]},
      StringMatchQ[t, $cssAnB],
        First @ StringCases[t, $cssAnB :> {
          If["$1" === "-", -1, 1] If["$2" === "", 1, FromDigits["$2"]],
          If["$4" === "", 0, If["$3" === "-", -1, 1] FromDigits["$4"]]}],
      True, cssInvalid[t <> " is not a valid An+B in " <> where, cssStart[First[items]]]]];

cssPseudoElement[c_, x_] :=
  With[{name = cssLower[If[MatchQ[x, _blk], x[[1, 2]], x[[2]]]], text = cssText[{c, x}]},
    If[If[MatchQ[x, _blk], MemberQ[$cssPseudoElementFunctions, name],
        MemberQ[$cssPseudoElements, name] || StringStartsQ[name, "-webkit-"]],
      sPseudoElement[text, cssStart[c], name],
      cssInvalid["unknown pseudo-element " <> text, cssStart[c]]]];

$cssNamespaceHow = "Namespaces are not supported in a CSS selector; give the tag or key as {namespace, name} in an XMLPattern.";
$cssComplexHow = "Its arguments can only be compound selectors, with no combinator.";
$cssComplexIsHow = "Its arguments can hold a combinator only when its compound is the whole selector, as in p:is(div p, section > p), and not inside :not() or :has().";

(* ---- Translation: selector lists ---- *)

(* A selector list whose selectors have the same links and differ, as parsed,
   in at most one compound, which has no position, is the shared chain, with
   the alternatives at that compound. Any other is the alternatives of its
   selectors' chains, in written order (ADR 0015). *)
cssListPattern[cs_] :=
  Replace[DeleteDuplicatesBy[Join @@ (cssSpreadIs /@ cs), cssShape], {
    {c_} :> cssChainPattern[c],
    u_ :> Replace[cssSharedChain[u], None :> cssAlternatives[cssChainPattern /@ u]]}];

cssSharedChain[u_] :=
  With[{comps = First /@ u},
    If[!(SameQ @@ (Last /@ u)), None,
      With[{diff = Select[Range[Length[First[comps]]], !(SameQ @@ cssShape /@ comps[[All, #]]) &]},
        If[Length[diff] > 1 || AnyTrue[comps[[All, First[diff]]], cssPositionedQ], None,
          cssChainPattern[cx[
            ReplacePart[First[comps], First[diff] -> cpAlt[DeleteDuplicatesBy[comps[[All, First[diff]]], cssShape]]],
            Last[First[u]]]]]]]];

cssPositionedQ[cp[nodes_, _]] :=
  MemberQ[nodes, _sNth] || AnyTrue[Cases[nodes, sPseudo[c_, _] :> c], KeyExistsQ[$cssPositions, #] || MatchQ[#, $cssRootPseudoClasses] &];

(* A selector of one compound whose :is() or :where() has an argument with a
   combinator is a selector list: each argument with the rest of the compound
   merged into its last compound, as p:is(div p) is div p.p. With a compound
   before it, x :is(a b) is an element with ancestors x and a in either order,
   whose expansion grows with the chains, so it is not translated (cssApply). *)
cssSpreadIs[cx[{cp[nodes_, text_]}, {}]] /; Count[nodes, _?cssComplexIsQ] == 1 :=
  With[{k = First[FirstPosition[nodes, _?cssComplexIsQ, None, {1}, Heads -> False]]},
    cssMergeInto[#, Delete[nodes, k], text] & /@ First[nodes[[k]]]];
cssSpreadIs[c_] := {c};

cssComplexIsQ[sIs[args_, _]] := !MatchQ[args, {cx[{_}, {}] ...}];
cssComplexIsQ[_] := False;

cssMergeInto[cx[comps_, links_], rest_, text_] :=
  cx[Append[Most[comps], cp[Join[First[Last[comps]], rest], text]], links];

(* A part of the tree without its source text and positions, which only
   messages use: compounds written differently, as with other quotes or
   keyword case, are equal when they parse alike. *)
cssShape[x_] := x //. {cp[n_, _String] :> cp[n], sPseudo[n_, _String] :> sPseudo[n], sNot[a_, _String] :> sNot[a],
  sIs[a_, _String] :> sIs[a], sHas[r_, _String] :> sHas[r], sPseudoElement[_String, _Integer, n_] :> sPseudoElement[n]};

(* ---- Translation: chains ---- *)

(* The stages and the links between them. A run of compounds joined by + or ~
   in which one has a child-indexed pseudo-class is one list stage over their
   parent's children (ADR 0016), as Adjacent and Sibling are shorthands for
   lists: after > or a descendant combinator it follows that link, and at the
   start of a chain it lists the children of any element or of the document
   (ADR 0018), so that it reaches the top elements. *)
cssChainPattern[cx[comps_, links_]] :=
  Module[{ts = cssCompoundT /@ comps, runs},
    If[MemberQ[links, cssColumn], cssRefuse["unsupported", "the column combinator ||", "Columns are not supported."]];
    runs = Split[Transpose[{ts, Prepend[links, None]}], MatchQ[Last[#2], Adjacent | Sibling] &];
    Apply[cssChain, Fold[cssAddRun, {{}, {}}, runs]]];

(* :root and :scope: the first compound, alone in its run, is the only child
   of the document, and its positions among its siblings are each 1 or never
   hold. *)
cssAddRun[{stages_, links_}, run_] /; AnyTrue[run[[All, 1]], MemberQ[Last[#], _cssRoot] &] :=
  If[stages === {} && Length[run] == 1,
    With[{part = run[[1, 1]]},
      {{XMLDocument[], If[AllTrue[Last[part], cssFirstQ], {}, {Except[_]}] ~Append~ First[part]}, {Child}}],
    cssRefuse["unsupported", First[FirstCase[Join @@ run[[All, 1, 3]], _cssRoot]], $cssRootHow]];

cssFirstQ[_cssRoot] := True;
cssFirstQ[cssPos[_, a_, b_, _, _]] :=
  Which[a == 0, b == 1, a > 0, b <= 1 && Mod[1 - b, a] == 0, True, b >= 1 && Mod[b - 1, -a] == 0];

cssAddRun[{stages_, links_}, run_] :=
  With[{lead = run[[1, 2]], parts = run[[All, 1]], within = Rest[run[[All, 2]]]},
    Which[
      AllTrue[parts, Last[#] === {} &],
        {Join[stages, First /@ parts], Join[links, DeleteCases[{lead}, None], within]},
      lead === None,
        {Join[stages, {XMLDocument[] | XMLPattern[_], cssRunList[parts, within]}], Append[links, Child]},
      True,
        {Append[stages, cssRunList[parts, within]], Append[links, lead]}]];

(* A run as a list: its compounds in order, + adding nothing between two and ~
   a ___, with a position of the first compound written as the entries before
   it and one of the last as the entries after it. A position among all the
   siblings of a compound joined to the first by + alone is one of the first,
   less the compounds between (.b + .a:nth-child(5) is .b at 4), and the same
   from the end. Where positions need more than that, the general form names
   every gap and compound, and tests the positions in a condition on the list.
   A position among the siblings of a type or that match a selector is
   written with plain entries too, in a run of one compound, where the
   compiler recognises the list (ADR 0020, shapes 4 and 5); in a longer run
   only the first or the last is, as WL's matcher backtracks without bound on
   repeats of Except[s] ..., s beside other XML patterns (over 20 s for
   tr:nth-of-type(50) among 1,000 rows, against 0.06 s as a condition). The
   siblings of the element's own type, for a compound with no type, are not a
   pattern, and are counted in a condition. *)
cssRunList[parts_, within_] :=
  With[{k = Length[parts]},
    With[{
        forward = Join @@ MapIndexed[cssShifted[#1, First[#2] - 1, Take[within, First[#2] - 1]] &, Select[#[[3]], !First[#] &] & /@ parts],
        backward = Join @@ MapIndexed[cssShifted[#1, k - First[#2], Drop[within, First[#2] - 1]] &, Select[#[[3]], First] & /@ parts]},
      If[Length[forward] <= 1 && Length[backward] <= 1 && FreeQ[{forward, backward}, None, {2}] &&
          FreeQ[{forward, backward}, cssOwnType | (cssPos[_, a_, b_, Except[None], _] /; k > 1 && !(a == 0 && b == 1))],
        Join[cssPositionEntries[forward, False], cssRunEntries[First /@ parts, within], cssPositionEntries[backward, True]],
        cssGeneralList[parts, within]]]];

(* The positions of a compound s compounds from an end of its run, moved to
   that end over the links between, or None when they cannot move. *)
cssShifted[ps_, 0, _] := ps;
cssShifted[{}, _, _] := {};
cssShifted[ps_, s_, links_] /; MatchQ[links, {Adjacent ..}] && MatchQ[ps, {cssPos[_, _, _, None, _] ..}] :=
  Replace[ps, cssPos[e_, a_, b_, None, t_] :> cssPos[e, a, b - s, None, t], {1}];
cssShifted[_, _, _] := {None};

(* Each compound but the last, with the gap after it. *)
cssRunEntries[ps_, within_] := Append[Join @@ MapThread[Prepend[cssGap[#2], #1] &, {Most[ps], within}], Last[ps]];

cssGap[Adjacent] := {};
cssGap[Sibling] := {___};

(* The entries before a compound at index a k + b, k >= 0 among its siblings,
   or after it, as their mirror, when counted from the end. Among all the
   siblings, each one before it is a unit _. Among those that match a
   selector s, which the compound matches too, the siblings before it are
   those that do not, Except[s] ..., then a unit PatternSequence[s, Except[s]
   ...] for each that does (ADR 0020, shapes 4 and 5). An index that no k
   gives never matches. *)
cssPositionEntries[{}, _] := {___};
cssPositionEntries[{cssPos[_, a_, b_, of_, _]}, fromEnd_] :=
  If[fromEnd, mirrored, Identity] @ If[a <= 0 && b < 1, {Except[_]},
    Join[cssLead[of], With[{u = cssUnit[of]}, Which[
      a == 0, cssRepeat[u, b - 1],
      a > 0, Append[cssRepeat[u, If[b >= 1, b - 1, Mod[b - 1, a]]], RepeatedNull[cssUnits[u, a]]],
      True, Append[cssRepeat[u, Mod[b - 1, -a]], Repeated[cssUnits[u, -a], {0, Floor[(b - 1)/-a]}]]]]]];

cssLead[None] := {};
cssLead[of_] := {Except[cssUnnamed[of]] ...};

cssUnit[None] := _;
cssUnit[of_] := With[{s = cssUnnamed[of]}, PatternSequence[s, Except[s] ...]];

(* n units in one PatternSequence. *)
cssUnits[u_, 1] := u;
cssUnits[u_, n_] := PatternSequence @@ Join @@ ConstantArray[spliced[{u}], n];

(* A name inside Except is never bound, so a selector with names is tested whole. *)
cssUnnamed[of_] := If[FreeQ[of, Verbatim[Pattern]], of, With[{m = XMLMatchQ[of]}, _?m]];

cssRepeat[_, 0] := {};
cssRepeat[u_, 1] := {u};
cssRepeat[u_, r_] := {Repeated[u, {r}]};

(* When only the last compound has positions: {g___, c : C, g___} /; tests,
   with the compounds before it tested on the siblings before it as one
   pattern. Naming each compound and gap instead makes WL try every split
   before the test: 640 s for .b ~ .a:nth-child(500) among 1,000 rows. *)
cssGeneralList[parts_, within_] /; AllTrue[Most[parts], Last[#] === {} &] :=
  Module[{pre = cssFreshName["g"], post = cssFreshName["g"], n = Replace[Last[parts][[2]], None :> cssFreshName["c"]]},
    conditionWith[
      {Pattern @@ {pre, BlankNullSequence[]},
        If[Last[parts][[2]] === None, Pattern @@ {n, First[Last[parts]]}, First[Last[parts]]],
        Pattern @@ {post, BlankNullSequence[]}},
      cssAnd[Join[
        cssPositionTest[#, n, If[First[#], {post}, {pre}]] & /@ Last[Last[parts]],
        cssRunTest[Most[parts], within, pre]]]]];

(* The siblings before the last compound end with the others of the run, each
   tested whole, as a name in it could not be bound. *)
cssRunTest[{}, _, _] := {};
cssRunTest[ps_, within_, pre_] :=
  With[{l = pre, run = Join[{___}, Join @@ MapThread[Prepend[cssGap[#2], With[{m = XMLMatchQ[First[#1]]}, _?m]] &, {ps, within}]]},
    {Hold[MatchQ[{l}, run]]}];

(* {g___, c1 : C1, ..., ck : Ck, g___} /; tests, with a named gap before the
   first compound, after the last, and for each ~ between two. A compound
   that already names its element keeps that name. *)
cssGeneralList[parts_, within_] :=
  Module[{names = Replace[parts[[All, 2]], None :> cssFreshName["c"], {1}], entries, seq, places},
    entries = MapThread[If[#2 === None, Pattern @@ {#3, First[#1]}, First[#1]] &, {parts, parts[[All, 2]], names}];
    seq = Join[{cssFreshName["g"]},
      Join @@ MapThread[Prepend[If[#2 === Sibling, {cssFreshName["g"]}, {}], #1] &, {Most[names], within}],
      {Last[names], cssFreshName["g"]}];
    places = Flatten[Position[seq, #, {1}, Heads -> False] & /@ names];
    conditionWith[
      Replace[seq, Join[Thread[names -> entries], {n_Symbol :> Pattern @@ {n, BlankNullSequence[]}}], {1}],
      cssAnd[Join @@ MapThread[
        Function[{part, n, k}, cssPositionTest[#, n, If[First[#], Drop[seq, k], Take[seq, k - 1]]] & /@ Last[part]],
        {parts, names, places}]]]];

(* Whether the element named n is at its position, the siblings on that side
   being the names in side. Held, with no private symbol. *)
cssPositionTest[cssPos[_, a_, b_, of_, _], n_, side_] :=
  Replace[cssIndexHeld[of, n, side], Hold[i_] :> Which[
    a == 0, Hold[i == b],
    a > 0, Hold[i >= b && Mod[i - b, a] == 0],
    True, Hold[i <= b && Mod[b - i, -a] == 0]]];

cssIndexHeld[None, _, side_] := With[{l = side}, Hold[Length[l] + 1]];
cssIndexHeld[cssOwnType, n_, side_] := With[{l = side, e = n}, Hold[Count[l, XMLElement[First[e], _, _]] + 1]];
(* A tag is tested on the elements directly: XMLMatchQ per sibling costs 1.5 s
   for tr:nth-of-type(500) among 1,000 rows, against 0.06 s. *)
cssIndexHeld[XMLPattern[t_String], _, side_] := With[{l = side}, Hold[Count[l, XMLElement[t, _, _]] + 1]];
cssIndexHeld[of_, _, side_] := With[{l = side, m = XMLMatchQ[of]}, Hold[Count[l, _?m] + 1]];

(* Runs of one link use the n-ary form; mixed links are right-nested. *)
cssChain[{s_}, {}] := s;
cssChain[ss_, links_] :=
  With[{k = LengthWhile[links, # === First[links] &]},
    If[k == Length[links], First[links] @@ ss,
      First[links] @@ Append[Take[ss, k], cssChain[Drop[ss, k], Drop[links, k]]]]];

(* ---- Translation: compounds ---- *)

(* A compound is a list of branches, br[tag, attributes, tests], its
   alternatives: :is() and :checked give several. The tag is tg[allowed, or
   All, excluded]; the attributes map each key to its constraints; a test is
   held, with cssSelf for the compound's element. cssCompoundT gives {pattern,
   name or None, its positions among its siblings, each a cssPos, and
   cssRoot[text] for :root or :scope}. *)
cssCompoundT[cpAnchor] := {XMLPattern[$cssAnchor], None, {}};
(* The compounds that differ between the selectors of a list have no position
   (cssSharedChain checks their own nodes; a position inside :is() or :not()
   is refused when its branches are made). *)
cssCompoundT[cpAlt[cps_]] := {cssAlternatives[First @* cssCompoundT /@ cps], None, {}};
cssCompoundT[c : cp[nodes_, _]] :=
  With[{type = FirstCase[nodes, sType[n_] :> n, _]},
    Replace[cssBranches[c], {bs_, counts_} :>
      Append[cssFinish[bs, type], Replace[counts, cssPos[e_, a_, b_, "type", t_] :> cssPos[e, a, b, cssOfType[type], t], {1}]]]];

(* The siblings an -of-type position counts: those of the compound's type, or
   when it has none, those of the element's own tag. *)
cssOfType[type_String] := XMLPattern[type];
cssOfType[_] := cssOwnType;

(* The anchor wraps an element's children in :has(), so that they have a
   parent; its namespaced tag is in no document. *)
$cssAnchor = {"urn:x-htmlpatterns:anchor", "anchor"};

$cssAny = br[tg[All, {}], <||>, {}];

cssBranches[cp[nodes_, _]] :=
  MapAt[DeleteDuplicates[Flatten[#]] &, Reap[Fold[cssApply, {$cssAny}, nodes], cssPosTag], 2];

cssWith[bs_, b_] := cssMerge[#, b] & /@ bs;
cssAttr[k_, c_] := br[tg[All, {}], <|k -> {c}|>, {}];
cssTest[t_Hold] := br[tg[All, {}], <||>, {t}];

cssMerge[br[t1_, a1_, s1_], br[t2_, a2_, s2_]] :=
  br[cssTagMerge[t1, t2], Merge[{a1, a2}, Apply[Join]], Join[s1, s2]];

cssTagMerge[tg[a1_, x1_], tg[a2_, x2_]] :=
  tg[Which[a1 === All, a2, a2 === All, a1, True, Select[a1, MemberQ[a2, #] &]], DeleteDuplicates[Join[x1, x2]]];

cssApply[bs_, sType[n_]] := cssWith[bs, br[tg[{n}, {}], <||>, {}]];
cssApply[bs_, sUniversal[]] := bs;
cssApply[bs_, sId[v_]] := cssWith[bs, cssAttr["id", eq[v]]];
cssApply[bs_, sClass[v_]] := cssWith[bs, cssAttr["classList", has[v]]];
cssApply[bs_, sAttr[n_]] := cssWith[bs, cssAttr[n, present]];
cssApply[bs_, sAttr[n_, m_, v_, f_]] := cssWith[bs, cssAttr[If[m === "~=", n <> "List", n], cssConstraint[m, v, f === "i"]]];
cssApply[bs_, sPseudo["link" | "any-link", _]] := cssWith[bs, br[tg[{"a", "area"}, {}], <|"href" -> {present}|>, {}]];
cssApply[bs_, sPseudo["empty", _]] := cssWith[bs, cssTest[$cssEmptyTest]];
cssApply[bs_, sPseudo["checked", _]] := Flatten[Outer[cssMerge, bs, $cssChecked], 1];
cssApply[bs_, sPseudo[c_, text_]] /; KeyExistsQ[$cssPositions, c] :=
  (Scan[Sow[cssPos[Sequence @@ #, text], cssPosTag] &, $cssPositions[c]]; bs);
(* A place in the tree, as a position is: the compound is a list stage. *)
cssApply[bs_, sPseudo[$cssRootPseudoClasses, text_]] := (Sow[cssRoot[text], cssPosTag]; bs);
(* of S: the element matches S, and is counted among the siblings that do. *)
cssApply[bs_, sNth[p_, None]] := (Sow[p, cssPosTag]; bs);
cssApply[bs_, sNth[cssPos[e_, a_, b_, "of", text_], args_]] := (
  Sow[cssPos[e, a, b, cssAlternatives[cssArgPattern[#, text] & /@ args], text], cssPosTag];
  Flatten[Outer[cssMerge, bs, Join @@ (cssArgBranches[#, text] & /@ args)], 1]);
cssApply[bs_, sNot[args_, text_]] := cssNot[bs, args, text];
cssApply[bs_, sIs[args_, text_]] := Flatten[Outer[cssMerge, bs, Join @@ (cssArgBranches[#, text] & /@ args)], 1];
cssApply[bs_, sHas[rels_, text_]] := cssWith[bs, cssTest[cssOr[cssHasTest[#, text] & /@ rels]]];
cssApply[_, sRefuse[kind_, part_, how_]] := cssRefuse[kind, part, how];
cssApply[_, sPseudoElement[text_, _, name_]] := cssRefuse["impossible", text, cssPseudoElementHow[name]];

(* Whitespace-only text counts as empty, and comments and processing
   instructions are ignored, as in Selectors 4. *)
$cssEmptyTest = Hold[MatchQ[Last[cssSelf],
  {(_String?(StringMatchQ["" | HTMLWhitespace]) | XMLObject["Comment" | "ProcessingInstruction"][___]) ...}]];

(* type is an enumerated attribute, which HTML matches ASCII case-insensitively. *)
$cssChecked = {
  br[tg[{"input"}, {}], <|"type" -> {checkedType}, "checked" -> {present}|>, {}],
  br[tg[{"option"}, {}], <|"selected" -> {present}|>, {}]};

(* An argument of :is() or :where() is merged into the compound. *)
cssArgBranches[cx[{c_}, {}], text_] := cssUnpositioned[cssBranches[c], " inside " <> text, $cssChildIndexedHow];
cssArgBranches[_, text_] := cssRefuse["unsupported", text, $cssComplexIsHow];

(* An argument of :not() or :has() is a pattern of its own, with its own names. *)
cssArgPattern[cx[{c_}, {}], text_] := cssUnpositioned[cssCompoundT[c], " inside " <> text, $cssChildIndexedHow];
cssArgPattern[_, text_] := cssRefuse["unsupported", text, $cssComplexHow];

(* A compound's pattern or branches, which must have no position: a compound
   with one is a list stage, not an element pattern. *)
cssUnpositioned[{x_, {}}, _, _] := x;
cssUnpositioned[{x_, _, {}}, _, _] := x;
cssUnpositioned[{__, counts_List}, where_, how_] :=
  Replace[FirstCase[counts, _cssRoot, None], {
    None :> cssRefuse["unsupported", Last[First[counts]] <> where, how],
    cssRoot[text_] :> cssRefuse["unsupported", text <> where, $cssRootInsideHow]}];

(* :not() of one class or one type merges into the class list or the tag, so a
   classless element matches, as in CSS; otherwise it is a condition, never an
   Except at a raw key, which would require the attribute. The operator form
   keeps its compiled matcher, for the readings in force, so the argument is
   compiled once per query rather than once per candidate. *)
cssNot[bs_, {cx[{cp[{sClass[c_]}, _]}, {}]}, _] := cssWith[bs, cssAttr["classList", lacks[c]]];
cssNot[bs_, {cx[{cp[{sType[n_]}, _]}, {}]}, _] := cssWith[bs, br[tg[All, {n}], <||>, {}]];
cssNot[bs_, args_, text_] :=
  With[{p = cssAlternatives[cssArgPattern[#, text] & /@ args]},
    cssWith[bs, cssTest[Hold[! XMLMatchQ[p][cssSelf]]]]];

(* :has(s) and :has(> s) for one compound test the children; any other
   relative selector runs as a chain from an anchor around the children, so
   that siblings among them are siblings. *)
cssHasTest[rel[Adjacent | Sibling | cssColumn, _], text_] :=
  cssRefuse["unsupported", text, "A relative selector in :has() can only start with a descendant combinator or >."];
cssHasTest[rel[link_, cx[comps_, links_]], _] :=
  Replace[If[links === {}, cssCompoundT[First[comps]], None], {
    {p_, _, {}} :> cssHasChild[link, p],
    _ :> With[{chain = cssChainPattern[cx[Prepend[comps, cpAnchor], Prepend[links, link]]], a = $cssAnchor},
      Hold[! MissingQ[XMLFirstCase[XMLElement[a, {}, Last[cssSelf]], chain]]]]}];

(* The children are filtered to elements, as a list given to XMLFirstCase can
   hold only elements and strings, and an XML document's can hold comments. *)
cssHasChild[Child, p_] := Hold[AnyTrue[Last[cssSelf], XMLMatchQ[p]]];
cssHasChild[Descendant, p_] := Hold[! MissingQ[XMLFirstCase[Cases[Last[cssSelf], _XMLElement], p]]];

cssAnd[{t_}] := t;
cssAnd[ts_] := Replace[Join @@ ts, Hold[xs___] :> Hold[And[xs]]];
cssOr[{t_}] := t;
cssOr[ts_] := Replace[Join @@ ts, Hold[xs___] :> Hold[Or[xs]]];

cssAlternatives[{p_}] := p;
cssAlternatives[ps_] := Alternatives @@ ps;

(* The pattern of a compound, from its branches: a branch whose tag can never
   match is dropped, and with none left the compound is XMLPattern[tag] /;
   False. The tests of a compound are on one name. *)
cssFinish[bs_, type_] :=
  Module[{live = Select[bs, cssTagPattern[First[#]] =!= cssNever &], name},
    name = If[AnyTrue[live, Last[#] =!= {} &], cssFreshName["e"], None];
    {Which[
      live === {}, cssConditioned[XMLPattern[type], name, {Hold[False]}],
      SameQ @@ (Last /@ live), cssConditioned[cssAlternatives[cssElement /@ live], name, Last[First[live]]],
      True, Alternatives @@ (cssConditioned[cssElement[#], name, Last[#]] & /@ live)],
     name}];

cssConditioned[p_, None, {}] := p;
cssConditioned[p_, None, ts_] := conditionWith[p, cssAnd[ts]];
cssConditioned[p_, n_, {}] := Pattern @@ {n, p};
cssConditioned[p_, n_, ts_] := conditionWith[Pattern @@ {n, p}, cssAnd[ts] /. cssSelf -> n];

cssElement[br[t_, a_, _]] :=
  With[{tag = cssTagPattern[t], rules = KeyValueMap[cssRule, a]},
    Switch[Length[rules], 0, XMLPattern[tag], 1, XMLPattern[tag, First[rules]], _, XMLPattern[tag, rules]]];

cssTagPattern[tg[All, {}]] := _;
cssTagPattern[tg[All, {x_}]] := _?(# =!= x &);
cssTagPattern[tg[All, xs_]] := cssPatternTest[_, Function @@ cssAnd[cssNotTag /@ xs]];
cssTagPattern[tg[allowed_, xs_]] :=
  Replace[Select[allowed, !MemberQ[xs, #] &], {{} -> cssNever, {t_} :> t, ts_ :> Alternatives @@ ts}];

cssNotTag[x_] := Hold[# =!= x];

(* PatternTest holds its test, which is built here. *)
cssPatternTest[p_, f_] := PatternTest[p, f];

(* A temporary symbol in the caller's context, as Module makes one: no name
   the caller writes can be it. *)
cssFreshName[base_] :=
  Module[{name},
    While[NameQ[name = $Context <> base <> "$" <> ToString[$ModuleNumber++]]];
    With[{s = Symbol[name]}, SetAttributes[s, Temporary]; s]];

(* ---- Translation: attribute values ---- *)

(* XMLPattern refuses a key given twice, so every constraint on one key is
   merged into one value pattern. A raw key holds present, never, eq, eqI,
   dash, dashI, pre, preI, suf, sufI, sub, subI or checkedType; a list key
   holds has, hasI or lacks. The I forms hold their value folded. *)
cssConstraint["~=", v_, False] := has[v];
cssConstraint["~=", v_, True] := hasI[cssLower[v]];
cssConstraint["=", v_, False] := eq[v];
cssConstraint["=", v_, True] := eqI[cssLower[v]];
cssConstraint["|=", v_, False] := dash[v];
cssConstraint["|=", v_, True] := dashI[cssLower[v]];
(* An empty value of ^=, $= or *= represents nothing (Selectors 4, 6.2). *)
cssConstraint["^=" | "$=" | "*=", "", _] := never;
cssConstraint["^=", v_, i_] := If[i, preI[cssLower[v]], pre[v]];
cssConstraint["$=", v_, i_] := If[i, sufI[cssLower[v]], suf[v]];
cssConstraint["*=", v_, i_] := If[i, subI[cssLower[v]], sub[v]];

cssRule[k_, cs_] := Replace[If[MemberQ[cs, _has | _hasI | _lacks], cssListValue[cs], cssRawValue[cs]], {None -> k, v_ :> k -> v}];

(* A value implies presence, and an exact value decides every other
   constraint at once. *)
cssRawValue[cs_] :=
  With[{c = DeleteDuplicates[DeleteCases[cs, present]]},
    Which[
      MemberQ[c, never], Except[_],
      c === {}, None,
      MemberQ[c, _eq], With[{v = FirstCase[c, eq[v_] :> v]}, If[AllTrue[c, TrueQ[(Function @@ cssSlot[#])[v]] &], v, Except[_]]],
      Length[c] == 1, cssSingle[First[c]],
      True, cssPatternTest[_, Function @@ cssAnd[cssSlot /@ c]]]];

cssListValue[cs_] :=
  With[{h = DeleteDuplicates[Cases[cs, has[v_] :> v]], l = DeleteDuplicates[Cases[cs, lacks[v_] :> v]],
      hi = DeleteDuplicates[Cases[cs, hasI[v_] :> v]]},
    Which[
      IntersectingQ[h, l], Except[_],
      hi === {} && l === {}, If[Length[h] == 1, First[h], _?(ContainsAll[h])],
      hi === {} && h === {}, If[Length[l] == 1, With[{c = First[l]}, _?(FreeQ[c])], _?(ContainsNone[l])],
      True, cssPatternTest[_, Function @@ cssAnd[Join[
        If[h === {}, {}, {Hold[ContainsAll[#, h]]}],
        If[l === {}, {}, {Hold[ContainsNone[#, l]]}],
        cssSlot[hasI[#]] & /@ hi]]]]];

(* A constraint alone, as the value pattern. *)
cssSingle[eq[v_]] := v;
cssSingle[dash[v_]] := With[{w = v <> "-"}, v | _?(StringStartsQ[w])];
cssSingle[pre[v_]] := _?(StringStartsQ[v]);
cssSingle[suf[v_]] := _?(StringEndsQ[v]);
cssSingle[sub[v_]] := _?(StringContainsQ[v]);
cssSingle[checkedType] := _?(StringMatchQ["checkbox" | "radio", IgnoreCase -> True]);
cssSingle[c_] := cssPatternTest[_, Function @@ cssSlot[c]];

(* A constraint as a held test on #, to be joined with others. The i flag
   folds A-Z only, on both sides, as Selectors requires: IgnoreCase would
   also fold letters such as \[CapitalEAcute]. *)
cssSlot[eq[v_]] := Hold[# === v];
cssSlot[eqI[v_]] := With[{f = $cssFold}, Hold[f[#] === v]];
cssSlot[dash[v_]] := With[{w = v <> "-"}, Hold[# === v || StringStartsQ[#, w]]];
cssSlot[dashI[v_]] := With[{f = $cssFold, w = v <> "-"}, Hold[f[#] === v || StringStartsQ[f[#], w]]];
cssSlot[pre[v_]] := Hold[StringStartsQ[#, v]];
cssSlot[preI[v_]] := With[{f = $cssFold}, Hold[StringStartsQ[f[#], v]]];
cssSlot[suf[v_]] := Hold[StringEndsQ[#, v]];
cssSlot[sufI[v_]] := With[{f = $cssFold}, Hold[StringEndsQ[f[#], v]]];
cssSlot[sub[v_]] := Hold[StringContainsQ[#, v]];
cssSlot[subI[v_]] := With[{f = $cssFold}, Hold[StringContainsQ[f[#], v]]];
cssSlot[checkedType] := Hold[StringMatchQ[#, "checkbox" | "radio", IgnoreCase -> True]];
cssSlot[hasI[v_]] := With[{f = $cssFold}, Hold[MemberQ[f[#], v]]];
