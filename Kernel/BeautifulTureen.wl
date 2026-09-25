(* ::Package:: *)
(* BeautifulTureen: XML patterns + the XML* consumers *)

BeginPackage["MaximilienTirard`BeautifulTureen`"];

(* === Public symbols === *)

XMLPattern::usage = "XMLPattern[tag] is an XML pattern matching any element with the given tag. XMLPattern[tag, attrs] additionally constrains the element's attribute map, where attrs is what KeyValuePattern takes: a list of \"key\" -> value rules, a single rule, or a bare \"key\" (meaning \"key\" -> _), optionally named and tested as a whole. Keys are literal: a string, a {namespace, name} pair, or Alternatives of those. Values are ordinary WL patterns. A key with a reading also has a list key, \"classList\" for \"class\", matched against the element's token list; at a list key, a literal string or Alternatives of strings means \"contains this token\". XMLPattern is inert: only XMLCases, XMLFirstCase, XMLDeleteCases, XMLMatchQ and the Roles and Constructs options interpret it; MatchQ and Cases do not.";
CSSClass::usage = "CSSClass is obsolete. Match an element's class list with the \"classList\" key of XMLPattern instead: XMLPattern[tag, \"classList\" -> \"cls\"].";
$AttributeReadings::usage = "$AttributeReadings is an Association from a literal attribute key to its reading: how the key's value is split into a token list, and the list key under which an XML pattern reaches that list. Each entry has the fields Method (\"SpaceSeparated\" or \"CommaSeparated\"), Delimiters, \"TrimWhitespace\" and \"ListKey\" (Automatic means key <> \"List\"). It ships with one entry, class, whose list key is \"classList\".";
HTMLWhitespace::usage = "HTMLWhitespace is a string pattern matching a run of one or more HTML ASCII whitespace characters (space, tab, line feed, form feed, carriage return): the delimiter HTML splits a class attribute on. Use it as StringSplit[value, HTMLWhitespace]. Unlike StringSplit's default, it does not treat no-break space or other Unicode whitespace as a delimiter, so it splits as a browser does.";
HTMLClassList::usage = "HTMLClassList[element] gives the class list of an XMLElement: the tokens of its class attribute, split on HTMLWhitespace, in document order and with duplicates kept. An element with no class attribute, class=\"\", or a whitespace-only class gives {}. It takes a single element; use HTMLClassList /@ XMLCases[tree, pattern] for many.";
XMLCases::usage = "XMLCases[tree, pattern] gives a list of all elements of the XML tree that match pattern, searched at any depth. pattern can be an XMLPattern, an Alternatives of them, a Child, Descendant, Adjacent, or Sibling combinator, a conditioned pattern pat /; test, or a rule pattern :> body. A name bound to a whole element, e : XMLPattern[...], always sees the element as it is in tree.";
XMLFirstCase::usage = "XMLFirstCase[tree, pattern] gives the first element of tree matching pattern, or Missing[\"NotFound\"] if there is none. XMLFirstCase[tree, pattern, default] gives default instead. It accepts the same patterns as XMLCases and short-circuits on the first match.";
XMLDeleteCases::usage = "XMLDeleteCases[tree, pattern] gives tree with every element matching pattern removed, at any depth. It accepts XMLPattern, Alternatives of them, conditioned patterns pat /; test, and Child or Descendant combinators; Adjacent and Sibling are not supported.";
XMLMatchQ::usage = "XMLMatchQ[element, pattern] gives True if element matches pattern, an XMLPattern, an Alternatives of them, or a conditioned pattern pat /; test, and False otherwise. XMLMatchQ[pattern] is an operator form. It tests the whole element, as StringMatchQ tests a whole string; use XMLCases to search a tree.";
Child::usage = "Child[parentPat, childPat] is a combinator for XMLCases matching elements that satisfy childPat and occur as direct children of an element satisfying parentPat. Both arguments are XMLPattern element patterns.";
Adjacent::usage = "Adjacent[beforePat, afterPat] is a combinator for XMLCases matching an element that satisfies afterPat and immediately follows a sibling satisfying beforePat. Both arguments are XMLPattern element patterns.";
Sibling::usage = "Sibling[beforePat, afterPat] is a combinator for XMLCases matching elements that satisfy afterPat and follow a sibling satisfying beforePat. Both arguments are XMLPattern element patterns.";
Descendant::usage = "Descendant[ancestorPat, descPat] is a combinator for XMLCases matching elements that satisfy descPat and are nested anywhere below an element satisfying ancestorPat. Both arguments are XMLPattern element patterns.";
HTMLTextContent::usage = "HTMLTextContent[tree] gives the text content of an XML tree: the lossless concatenation, in document order, of every descendant string. It inserts and removes no whitespace, so source indentation and <pre> whitespace survive unchanged. tree may be an XMLElement, an XMLObject document, a list, or a string.";
HTMLInnerText::usage = "HTMLInnerText[tree] gives the readable text of an XML tree: internal whitespace is collapsed, block-level tags are placed on their own lines, <br> becomes a newline, <pre> content is preserved verbatim, non-rendered tags such as script and style are dropped, and the result is trimmed. Each element is classified by tag alone using a frozen user-agent stylesheet. HTMLInnerText[tree, \"Roles\" -> rules] overrides the classification, where each rule's left-hand side is an XMLPattern or a tag string; \"BlockSeparator\" -> sep sets the string joining block boundaries (default \"\\n\"). tree may be an XMLElement, an XMLObject document, a list, or a string.";
HTMLToNotebook::usage = "HTMLToNotebook[tree] converts an HTML/XML tree into a Notebook[...] expression, from which Markdown, PDF, RTF, and display follow via Export. Block-level tags become cells (headings -> Title/Chapter/Section/..., p -> Text, li -> Item/Subitem/..., blockquote -> a framed quote, pre -> a Program cell, table -> Dataset or Grid) and inline tags become boxes inside the surrounding cell (b -> bold, i -> italic, code -> inline code, a -> hyperlink, ...). Classification is by tag alone using a frozen user-agent stylesheet. HTMLToNotebook[tree, \"Roles\" -> rules] overrides the block/inline classification; \"Constructs\" -> rules overrides the form each element takes (an inline token, a cell-style string, or a constructor function element :> Cell/boxes). Each rule's left-hand side is an XMLPattern or a tag string. tree may be an XMLElement, an XMLObject document, a list, or a string.";

(* === Messages === *)

CSSClass::obs = "CSSClass is obsolete. Match the class list with the \"classList\" key instead: XMLPattern[tag, \"classList\" -> \"cls\"] for .cls, or \"classList\" -> _?(FreeQ[\"cls\"]) for :not(.cls).";
XMLPattern::badtag = "Tag should be a string, a {namespace, name} pair, Alternatives, or pattern (e.g. _). Got `1`.";
XMLPattern::nargs = "XMLPattern takes a tag and at most one attribute argument; got `1` arguments. Give several attribute constraints as one list: XMLPattern[tag, {c1, c2, ...}].";
XMLPattern::badattrs = "The attribute argument should be a list of key -> value rules, a single rule, or a bare key, optionally named (attrs : ...) or tested (...?test) as a whole. Got `1`.";
XMLPattern::badkey = "Attribute key should be a string, a {namespace, name} pair of strings, or Alternatives of those. Got `1`. To ask a question of the keys, name and test the whole attribute map: XMLPattern[tag, attrs_?test].";
XMLPattern::dupkey = "Attribute key `1` is constrained more than once, which KeyValuePattern can never satisfy. Combine the constraints into one value pattern.";
XMLPattern::strpat = "`1` is a string pattern, and a string pattern is never matched against a string by an ordinary pattern. Write _?(StringMatchQ[`1`]) instead.";
XMLCases::badtree = "First argument should be an XMLObject, XMLElement, or list thereof. Got head `1`.";
XMLCases::badpat = "Second argument should be an XMLPattern, Alternatives of XMLPatterns, or combinator (Child, Adjacent, Sibling, Descendant). Got `1`.";
XMLCases::condcombinator = "A condition (/;) may wrap an XMLPattern or an Alternatives of them, but not a combinator (Child, Adjacent, Sibling, Descendant). Got `1`.";
XMLFirstCase::badtree = "First argument should be an XMLObject, XMLElement, or list thereof. Got head `1`.";
XMLFirstCase::badpat = "Second argument should be an XMLPattern, Alternatives of XMLPatterns, or combinator (Child, Adjacent, Sibling, Descendant). Got `1`.";
XMLFirstCase::condcombinator = "A condition (/;) may wrap an XMLPattern or an Alternatives of them, but not a combinator (Child, Adjacent, Sibling, Descendant). Got `1`.";
XMLDeleteCases::badtree = "First argument should be an XMLObject, XMLElement, or list thereof. Got head `1`.";
XMLDeleteCases::badpat = "Second argument should be an XMLPattern, Alternatives of XMLPatterns, or Child/Descendant combinator. Got `1`.";
XMLDeleteCases::condcombinator = "A condition (/;) may wrap an XMLPattern or an Alternatives of them, but not a combinator (Child, Adjacent, Sibling, Descendant). Got `1`.";
XMLDeleteCases::unsupported = "Adjacent and Sibling combinators are not supported by XMLDeleteCases. Use XMLCases for filtering semantics instead.";
XMLMatchQ::badpat = "Pattern should be an XMLPattern, an Alternatives of them, or a conditioned pattern pat /; test. Got `1`.";
XMLMatchQ::condcombinator = "A condition (/;) may wrap an XMLPattern or an Alternatives of them, but not a combinator (Child, Adjacent, Sibling, Descendant). Got `1`.";
XMLMatchQ::combinator = "`1` relates an element to its parent or siblings, which a lone element does not have. Use XMLCases or XMLFirstCase to search a tree with it.";
HTMLTextContent::badtree = "First argument should be an XMLObject, XMLElement, or list thereof. Got head `1`.";
HTMLClassList::notelement = "Argument should be a single XMLElement; for a list of elements, use HTMLClassList /@ elements. Got head `1`.";
HTMLInnerText::badtree = "First argument should be an XMLObject, XMLElement, or list thereof. Got head `1`.";
HTMLInnerText::badrole = "Role rule produced `1`, which is not one of \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\", or \"Skip\"; ignoring it and deferring to the frozen user-agent table.";
HTMLInnerText::badpat = "A rule's left-hand side should be a tag string, an XMLPattern, an Alternatives of them, or a conditioned pattern pat /; test. Got `1`.";
HTMLInnerText::condcombinator = "A condition (/;) may wrap an XMLPattern or an Alternatives of them, but not a combinator (Child, Adjacent, Sibling, Descendant). Got `1`.";
HTMLToNotebook::badtree = "First argument should be an XMLObject, XMLElement, or list thereof. Got head `1`.";
HTMLToNotebook::badrole = "Role rule produced `1`, which is not one of \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\", or \"Skip\"; ignoring it and deferring to the frozen user-agent table.";
HTMLToNotebook::badpat = "A rule's left-hand side should be a tag string, an XMLPattern, an Alternatives of them, or a conditioned pattern pat /; test. Got `1`.";
HTMLToNotebook::condcombinator = "A condition (/;) may wrap an XMLPattern or an Alternatives of them, but not a combinator (Child, Adjacent, Sibling, Descendant). Got `1`.";

Begin["`Private`"];

(* =========================================================== *)
(* Validation helpers                                           *)
(* =========================================================== *)

(* Valid tag: a string, a {namespace, name} pair, or any ordinary pattern matched
   against the element's tag \[LongDash] Alternatives, Blank(Sequence), a named Pattern,
   or a predicate-bearing PatternTest (_?f) / Condition (t_ /; test). *)
validTagQ[_String] := True;
validTagQ[{_, _}] := True;
validTagQ[_Alternatives] := True;
validTagQ[_Blank] := True;
validTagQ[_BlankSequence] := True;
validTagQ[_Pattern] := True;
validTagQ[_PatternTest] := True;
validTagQ[_Condition] := True;
validTagQ[_] := False;

(* A literal attribute key: a plain name, an imported {namespace, name} pair (WL
   imports a namespaced attribute such as xlink:href with a two-element list key
   {namespaceURI, localName}), or Alternatives of those. *)
literalKeyQ[_String] := True;
literalKeyQ[{_String, _String}] := True;
literalKeyQ[Verbatim[Alternatives][ks__]] := AllTrue[{ks}, literalKeyQ];
literalKeyQ[_] := False;

keyLiterals[Verbatim[Alternatives][ks__]] := Join @@ (keyLiterals /@ {ks});
keyLiterals[k_] := {k};

combinatorQ[_Child | _Adjacent | _Sibling | _Descendant] := True;
combinatorQ[_] := False;

(* A leading name on a Condition's left-hand side never changes what it is. *)
condLHSBase[Verbatim[Pattern][_, x_]] := x;
condLHSBase[x_] := x;

(* Valid tree for XMLCases *)
validTreeQ[XMLObject["Document"][_, _XMLElement, _]] := True;
validTreeQ[_XMLElement] := True;
validTreeQ[expr_List] := AllTrue[expr, MatchQ[#, _XMLElement | _String] &];
validTreeQ[_] := False;

(* Input surface for the text extractors: the selector surface, plus a bare
   string (text-of-a-string is meaningful, unlike for the selectors). *)
validTextInputQ[_String] := True;
validTextInputQ[t_] := validTreeQ[t];

(* The bare string patterns written where a pattern is matched. A StringExpression
   inside a PatternTest's test or a Condition's test is an argument to a string
   function, not a pattern, and neither is anything under Verbatim. *)
SetAttributes[barePatterns, HoldAllComplete];
barePatterns[s_StringExpression] := {s};
barePatterns[Verbatim[PatternTest][p_, _]] := barePatterns[p];
barePatterns[Verbatim[Condition][p_, _]] := barePatterns[p];
barePatterns[Verbatim[Verbatim][___]] := {};
barePatterns[_[args___]] := Join @@ (barePatterns /@ Unevaluated[{args}]);
barePatterns[_] := {};

(* =========================================================== *)
(* HTMLWhitespace                                               *)
(* The delimiter of the space-separated microsyntax.            *)
(* =========================================================== *)

(* A run, not one character, mirroring Whitespace rather than
   WhitespaceCharacter: splitting "a  b" on it gives no phantom empty token. *)
HTMLWhitespace = (" " | "\t" | "\n" | "\f" | "\r") ..;

(* =========================================================== *)
(* HTMLClassList                                                *)
(* The extraction form of the class reading. Shares classList   *)
(* with the class reading's split, so extracting and matching   *)
(* agree on the same element.                                   *)
(* =========================================================== *)

(* The class list: the tokens of the class attribute, split on HTMLWhitespace
   as a browser splits them. Splitting gives the empty list for "", for
   whitespace-only values, and (via the "" default in classValue) for a missing
   attribute \[LongDash] the three ways an element ends up carrying no classes, which
   must be indistinguishable here. *)
classList[val_String] := StringSplit[val, HTMLWhitespace];

(* Absent class reads as "", the same value a present-but-empty class="" carries. *)
classValue[attrs_] := Lookup[attrs, "class", ""];

HTMLClassList[XMLElement[_, attrs_List, _]] := classList[classValue[attrs]];

(* A list, a document or a bare string is refused, not interpreted: a list is a
   forest elsewhere in the paclet (one answer), where concatenated class lists
   mean nothing, and a bare string is a text node, not an attribute value. *)
HTMLClassList[other_] :=
  (Message[HTMLClassList::notelement, Head[other]]; $Failed);

(* =========================================================== *)
(* CSSClass                                                     *)
(* Obsolete (ADR 0011): the class list is the "classList" key.  *)
(* =========================================================== *)

CSSClass[___] := (Message[CSSClass::obs]; $Failed);

(* =========================================================== *)
(* Readings (ADR 0012)                                          *)
(* A reading fixes a microsyntax to a literal attribute key and *)
(* names the list key an XML pattern reaches its token list by. *)
(* =========================================================== *)

$AttributeReadings = <|
  "class" -> <|Method -> "SpaceSeparated", Delimiters -> Automatic,
    "TrimWhitespace" -> Automatic, "ListKey" -> Automatic|>|>;

(* Method is shorthand defining the other two fields. *)
$methodDefaults = <|
  "SpaceSeparated" -> <|Delimiters -> HTMLWhitespace, "TrimWhitespace" -> False|>,
  "CommaSeparated" -> <|Delimiters -> ",", "TrimWhitespace" -> True|>|>;

splitter[delim_, False] := Function[v, StringSplit[v, delim]];
splitter[delim_, True] := Function[v, StringTrim /@ StringSplit[v, delim]];

(* A readings table resolved for the compiler: list key -> {raw key, split}. *)
resolveReading[key_String -> spec_Association] :=
  With[{defaults = $methodDefaults[Lookup[spec, Method, "SpaceSeparated"]]},
    Replace[Lookup[spec, "ListKey", Automatic], Automatic -> key <> "List"] ->
      {key, splitter[
        Replace[Lookup[spec, Delimiters, Automatic], Automatic -> defaults[Delimiters]],
        Replace[Lookup[spec, "TrimWhitespace", Automatic], Automatic -> defaults["TrimWhitespace"]]]}];

resolveReadings[readings_Association] := Association[resolveReading /@ Normal[readings]];

(* =========================================================== *)
(* Materialisation (ADR 0012)                                   *)
(* A query naming a list key runs on a tree whose elements each *)
(* carry the token list beside the raw value, under the private *)
(* key head tok (inert: no definitions). strip is the exact     *)
(* inverse: strip[materialise[e, ...]] === e.                   *)
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

stripAttrs[a_] := DeleteCases[a, _tok -> _];

strip[x_] :=
  Replace[x, XMLElement[t_, a_List, c_] :> XMLElement[t, stripAttrs[a], c], {0, Infinity}];

(* =========================================================== *)
(* The query compiler                                           *)
(*                                                              *)
(* compileQuery[query, head, readings] -> {pattern, readings}:  *)
(* the plain WL pattern every consumer runs, and the readings   *)
(* of the list keys it names ({} when it names none, in which   *)
(* case the pattern runs on the tree as it is). Refusals message*)
(* under XMLPattern (an XML pattern's own shape) or under head  *)
(* (the consumer's query shape) and give $Failed.               *)
(*                                                              *)
(* When a list key is named, every binding that can see an      *)
(* element's attributes \[LongDash] an element binding e : XMLPattern[...],  *)
(* or a name or test on the attribute argument \[LongDash] is renamed to a   *)
(* fresh symbol, and each place that can see the name (a rule   *)
(* body, a Condition's test) is wrapped in                      *)
(* With[{e = strip[e$]}, ...], so it sees the original element. *)
(* A query is compiled once to learn its list keys and, only if *)
(* it names one, again with the renaming on.                    *)
(* =========================================================== *)

compileQuery[q_, head_, readings_Association] :=
  Catch[
    Module[{pattern, keys},
      {pattern, keys} = compilePass[q, head, readings, False];
      If[keys =!= {}, pattern = First @ compilePass[q, head, readings, True]];
      {pattern, Lookup[readings, keys]}],
    $refusal];

compileQuery[q_, head_] := compileQuery[q, head, resolveReadings[$AttributeReadings]];

compilePass[q_, head_, readings_, mat_] :=
  Block[{$head = head, $readings = readings, $mat = mat, $fresh = <||>},
    MapAt[Union @@ # &, Reap[First @ Reap[cQuery[q], $bindTag], $listKeyTag], 2]];

(* Held, since a MessageName evaluates to its text. *)
SetAttributes[refuse, HoldFirst];
refuse[msg_, args___] := (Message[msg, args]; Throw[$Failed, $refusal]);
(* An upstream failure (CSSClass::obs) has already said what went wrong. *)
refuseQuietly[] := Throw[$Failed, $refusal];

(* MessageName holds its first argument, so the consumer head is injected. *)
refuseAtHead[tag_, args___] := With[{h = $head}, refuse[MessageName[h, tag], args]];
badpat[q_] := refuseAtHead["badpat", Short[q]];

(* ---- Queries: a rule over a pattern, or a pattern ---- *)

cQuery[r_RuleDelayed] :=
  Module[{lhs, binds},
    {lhs, binds} = reapBinds[cStage[r[[1]]]];
    With[{l = lhs}, RuleDelayed @@ Join[Hold[l], wrapBinds[binds, Extract[r, {2}, Hold]]]]];
cQuery[q_] := cStage[q];

(* A combinator's stages are element patterns. *)
cStage[(h : Child | Descendant | Adjacent | Sibling)[a_, b_]] := h[cElem[a], cElem[b]];
cStage[q_] := cElem[q];

(* ---- Element patterns ---- *)

cElem[XMLPattern[args___]] := cXMLPattern[{args}];
cElem[alts_Alternatives] := Alternatives @@ (cElem /@ List @@ alts);
cElem[Verbatim[Pattern][s_Symbol, p_]] :=
  If[combinatorQ[p], badpat[namedPattern[s, p]], bindAs[s, cElem[p], strip]];
cElem[c_Condition] :=
  Module[{lhs, binds},
    If[combinatorQ[condLHSBase[c[[1]]]],
      refuseAtHead["condcombinator", Short[c[[1]]]]];
    {lhs, binds} = reapBinds[cElem[c[[1]]]];
    Scan[Sow[#, $bindTag] &, binds];
    With[{l = lhs}, Condition @@ Join[Hold[l], wrapBinds[binds, Extract[c, {2}, Hold]]]]];
(* A plain XMLElement pattern is already what the consumers run. *)
cElem[x_XMLElement] := x;
cElem[q_] := badpat[q];

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
cAttrs[Verbatim[Pattern][s_Symbol, inner_]] := bindAs[s, cAttrs[inner], stripAttrs];
(* A test on the whole attribute map sees the original map. *)
cAttrs[Verbatim[PatternTest][inner_, test_]] :=
  With[{p = cAttrs[inner]},
    If[$mat, PatternTest[p, Function[a, test[stripAttrs[a]]]], PatternTest[p, test]]];
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
   silent False however each would match alone. *)
noDuplicateKeys[rules_] :=
  Replace[
    Select[Tally[Join @@ (keyLiterals[Replace[#, Verbatim[Rule][k_, _] :> k]] & /@ rules)],
      Last[#] > 1 &],
    {{k_, _}, ___} :> refuse[XMLPattern::dupkey, k]];

(* ---- Bindings ---- *)

(* The same name gets the same fresh symbol throughout a query, so that
   (e : XMLPattern["a"]) | (e : XMLPattern["b"]) still binds one name. *)
SetAttributes[bindAs, HoldFirst];
bindAs[s_, p_, inverse_] :=
  If[!$mat,
    namedPattern[s, p],
    With[{fresh = If[KeyExistsQ[$fresh, Hold[s]], $fresh[Hold[s]],
        $fresh[Hold[s]] = freshSymbol[]]},
      Sow[{Hold[s], fresh, inverse}, $bindTag];
      namedPattern[fresh, p]]];

(* A temporary private symbol, so nothing is left in the caller's context. *)
freshSymbol[] := Module[{bound}, bound];

(* s : p, built without a literal Pattern on a right-hand side. *)
SetAttributes[namedPattern, HoldFirst];
namedPattern[s_, p_] := Pattern @@ Hold[s, p];

(* Held, so that the bindings its argument sows are reaped here. *)
SetAttributes[reapBinds, HoldFirst];
reapBinds[expr_] :=
  MapAt[DeleteDuplicates[Join @@ #] &, Reap[expr, $bindTag], 2];

(* Hold[body] -> Hold[With[{e = strip[e$], ...}, body]] *)
wrapBinds[{}, held_Hold] := held;
wrapBinds[binds_, held_Hold] :=
  With[{spec = Replace[
      Join @@ (Replace[#, {Hold[s_], fresh_, inverse_} :> Hold[s = inverse[fresh]]] & /@ binds),
      Hold[sets___] :> Hold[{sets}]]},
    Replace[Join[spec, held], Hold[vars_, body_] :> Hold[With[vars, body]]]];

(* =========================================================== *)
(* Running a compiled query                                     *)
(* =========================================================== *)

(* Materialise once per query, over the union of the list keys all its stages
   name; strip once, at the output. *)
runCompiled[run_, tree_, {pattern_, {}}, rest___] := run[tree, pattern, rest];
runCompiled[run_, tree_, {pattern_, readings_}, rest___] :=
  strip @ run[materialise[tree, readings], pattern, rest];

(* =========================================================== *)
(* XMLCases                                                     *)
(* =========================================================== *)

XMLCases[tree_, q_] :=
  With[{c = compileQuery[q, XMLCases]},
    Which[
      c === $Failed, $Failed,
      !validTreeQ[tree], Message[XMLCases::badtree, Head[tree]]; $Failed,
      True, runCompiled[casesC, tree, c]]];

(* Base: a pattern, a Condition, or a rule over either \[LongDash] just Cases *)
casesC[tree_, pat_] := Cases[tree, pat, Infinity];

(* Descendant: chained Cases *)
casesC[tree_, Descendant[outerPat_, innerPat_]] :=
  Flatten[casesC[#, innerPat] & /@ casesC[tree, outerPat], 1];

(* Descendant with rule \[LongDash] nested Cases keeps outer bindings in scope *)
casesC[tree_, Verbatim[RuleDelayed][Descendant[outerPat_, innerPat_], body_]] :=
  Flatten[Cases[tree,
    parent:outerPat :> casesC[parent, innerPat :> body],
    Infinity], 1];

(* Child: find parents, then direct children of each *)
casesC[tree_, Child[parentPat_, childPat_]] :=
  Flatten[Cases[#, childPat, {2}] & /@ casesC[tree, parentPat], 1];

(* Child with rule \[LongDash] nested Cases keeps parent bindings in scope *)
casesC[tree_, Verbatim[RuleDelayed][Child[parentPat_, childPat_], body_]] :=
  Flatten[Cases[tree,
    parent:parentPat :> Cases[parent, childPat :> body, {2}],
    Infinity], 1];

(* Adjacent sibling: find parents containing beforePat,
   then for each, find afterPat immediately after *)
casesC[tree_, Adjacent[beforePat_, afterPat_]] :=
  Module[{allParents},
    allParents = Cases[tree,
      el:XMLElement[_, _, children_List] /; MemberQ[children, beforePat] :> el,
      Infinity
    ];
    Flatten[
      Function[parent,
        Module[{elems = Select[parent[[3]], MatchQ[#, _XMLElement] &], pairs},
          pairs = Partition[elems, 2, 1];
          Cases[pairs, {beforePat, after:afterPat} :> after]
        ]
      ] /@ allParents,
      1
    ]
  ];

(* Adjacent with rule *)
casesC[tree_, Verbatim[RuleDelayed][Adjacent[beforePat_, afterPat_], body_]] :=
  Module[{allParents},
    allParents = Cases[tree,
      el:XMLElement[_, _, children_List] /; MemberQ[children, beforePat] :> el,
      Infinity
    ];
    Flatten[
      Function[parent,
        Module[{elems = Select[parent[[3]], MatchQ[#, _XMLElement] &], pairs},
          pairs = Partition[elems, 2, 1];
          Cases[pairs, {beforePat, afterPat} :> body]
        ]
      ] /@ allParents,
      1
    ]
  ];

(* General sibling: find parents containing beforePat,
   then for each, find all afterPat that come after *)
casesC[tree_, Sibling[beforePat_, afterPat_]] :=
  Module[{allParents},
    allParents = Cases[tree,
      el:XMLElement[_, _, children_List] /; MemberQ[children, beforePat] :> el,
      Infinity
    ];
    Flatten[
      Function[parent,
        Module[{elems = Select[parent[[3]], MatchQ[#, _XMLElement] &], idx},
          idx = FirstPosition[elems, beforePat, None, {1}];
          If[idx =!= None,
            Cases[elems[[idx[[1]] + 1 ;;]], afterPat],
            {}
          ]
        ]
      ] /@ allParents,
      1
    ]
  ];

(* Sibling with rule \[LongDash] outer Cases keeps beforePat bindings in scope *)
casesC[tree_, Verbatim[RuleDelayed][Sibling[beforePat_, afterPat_], body_]] :=
  Flatten[Cases[tree,
    el:XMLElement[_, _, children_List] /; MemberQ[children, beforePat] :>
      Module[{elems = Select[el[[3]], MatchQ[#, _XMLElement] &], idx},
        idx = FirstPosition[elems, beforePat, None, {1}];
        If[idx =!= None,
          Cases[elems[[idx[[1]] + 1 ;;]], afterPat :> body],
          {}
        ]
      ],
    Infinity], 1];

(* =========================================================== *)
(* XMLFirstCase                                                 *)
(* Short-circuits on the first match; same combinator surface   *)
(* as XMLCases. Default (3rd arg) returned when nothing found.  *)
(* =========================================================== *)

XMLFirstCase[tree_, q_, default_:Missing["NotFound"]] :=
  With[{c = compileQuery[q, XMLFirstCase]},
    Which[
      c === $Failed, $Failed,
      !validTreeQ[tree], Message[XMLFirstCase::badtree, Head[tree]]; $Failed,
      True, runCompiled[firstC, tree, c, default]]];

(* Base: FirstCase short-circuits natively *)
firstC[tree_, pat_, default_] := FirstCase[tree, pat, default, Infinity];

(* Descendant: short-circuit via Catch/Throw on first inner hit *)
firstC[tree_, Descendant[outerPat_, innerPat_], default_] :=
  Module[{tag},
    Catch[
      Cases[tree, o:outerPat :>
        With[{r = firstC[o, innerPat, tag]},
          If[r =!= tag, Throw[r, tag]]
        ], Infinity];
      default,
      tag
    ]
  ];

(* Descendant with rule *)
firstC[tree_, Verbatim[RuleDelayed][Descendant[outerPat_, innerPat_], body_], default_] :=
  Module[{tag},
    Catch[
      Cases[tree, parent:outerPat :>
        With[{r = firstC[parent, innerPat :> body, tag]},
          If[r =!= tag, Throw[r, tag]]
        ], Infinity];
      default,
      tag
    ]
  ];

(* Child: first parent match's first direct child match *)
firstC[tree_, Child[parentPat_, childPat_], default_] :=
  Module[{tag},
    Catch[
      Cases[tree, p:parentPat :>
        With[{r = FirstCase[p, childPat, tag, {2}]},
          If[r =!= tag, Throw[r, tag]]
        ], Infinity];
      default,
      tag
    ]
  ];

(* Child with rule *)
firstC[tree_, Verbatim[RuleDelayed][Child[parentPat_, childPat_], body_], default_] :=
  Module[{tag},
    Catch[
      Cases[tree, parent:parentPat :>
        With[{r = FirstCase[parent, childPat :> body, tag, {2}]},
          If[r =!= tag, Throw[r, tag]]
        ], Infinity];
      default,
      tag
    ]
  ];

(* Adjacent: first parent containing beforePat, first afterPat immediately after *)
firstC[tree_, Adjacent[beforePat_, afterPat_], default_] :=
  Module[{tag},
    Catch[
      Cases[tree,
        el:XMLElement[_, _, children_List] /; MemberQ[children, beforePat] :>
          Module[{elems = Select[el[[3]], MatchQ[#, _XMLElement] &], hit},
            hit = FirstCase[Partition[elems, 2, 1],
              {beforePat, after:afterPat} :> after, tag];
            If[hit =!= tag, Throw[hit, tag]]
          ],
        Infinity];
      default,
      tag
    ]
  ];

(* Adjacent with rule *)
firstC[tree_, Verbatim[RuleDelayed][Adjacent[beforePat_, afterPat_], body_], default_] :=
  Module[{tag},
    Catch[
      Cases[tree,
        el:XMLElement[_, _, children_List] /; MemberQ[children, beforePat] :>
          Module[{elems = Select[el[[3]], MatchQ[#, _XMLElement] &], hit},
            hit = FirstCase[Partition[elems, 2, 1],
              {beforePat, afterPat} :> body, tag];
            If[hit =!= tag, Throw[hit, tag]]
          ],
        Infinity];
      default,
      tag
    ]
  ];

(* Sibling: first parent containing beforePat, first afterPat after it *)
firstC[tree_, Sibling[beforePat_, afterPat_], default_] :=
  Module[{tag},
    Catch[
      Cases[tree,
        el:XMLElement[_, _, children_List] /; MemberQ[children, beforePat] :>
          Module[{elems = Select[el[[3]], MatchQ[#, _XMLElement] &], idx, hit},
            idx = FirstPosition[elems, beforePat, None, {1}];
            If[idx =!= None,
              hit = FirstCase[elems[[idx[[1]] + 1 ;;]], afterPat, tag];
              If[hit =!= tag, Throw[hit, tag]]
            ]
          ],
        Infinity];
      default,
      tag
    ]
  ];

(* Sibling with rule *)
firstC[tree_, Verbatim[RuleDelayed][Sibling[beforePat_, afterPat_], body_], default_] :=
  Module[{tag},
    Catch[
      Cases[tree,
        el:XMLElement[_, _, children_List] /; MemberQ[children, beforePat] :>
          Module[{elems = Select[el[[3]], MatchQ[#, _XMLElement] &], idx, hit},
            idx = FirstPosition[elems, beforePat, None, {1}];
            If[idx =!= None,
              hit = FirstCase[elems[[idx[[1]] + 1 ;;]], afterPat :> body, tag];
              If[hit =!= tag, Throw[hit, tag]]
            ]
          ],
        Infinity];
      default,
      tag
    ]
  ];

(* =========================================================== *)
(* XMLDeleteCases                                               *)
(* Base: native DeleteCases with Infinity levelspec.            *)
(* Combinators: bottom-up walk so nested matching parents are   *)
(* processed correctly (ReplaceAll does not re-scan RHS).       *)
(* =========================================================== *)

(* Bottom-up walker: applies f to each XMLElement *after* recursing children.
   Preserves XMLObject["Document"] envelope and non-XMLElement leaves. *)
xmlWalk[XMLObject["Document"][decls_, root_, misc_], f_] :=
  XMLObject["Document"][decls, xmlWalk[root, f], misc];
xmlWalk[XMLElement[tag_, attrs_, children_List], f_] :=
  f[XMLElement[tag, attrs, xmlWalk[#, f] & /@ children]];
xmlWalk[list_List, f_] := xmlWalk[#, f] & /@ list;
xmlWalk[x_, _] := x;

(* A rule has nothing to delete with; deletion by relative position (Adjacent,
   Sibling) is a niche operation, documented as unsupported here. *)
XMLDeleteCases[tree_, q_RuleDelayed] :=
  (Message[XMLDeleteCases::badpat, Short[q]]; $Failed);

XMLDeleteCases[tree_, q_] :=
  With[{c = compileQuery[q, XMLDeleteCases]},
    Which[
      c === $Failed, $Failed,
      !validTreeQ[tree], Message[XMLDeleteCases::badtree, Head[tree]]; $Failed,
      MatchQ[q, _Adjacent | _Sibling], Message[XMLDeleteCases::unsupported]; $Failed,
      True, runCompiled[deleteC, tree, c]]];

(* Base: a pattern or a Condition *)
deleteC[tree_, pat_] := DeleteCases[tree, pat, Infinity];

(* Child: at every matching parent, filter direct children *)
deleteC[tree_, Child[parentPat_, childPat_]] :=
  xmlWalk[tree,
    Replace[#, p:parentPat :>
      XMLElement[p[[1]], p[[2]], DeleteCases[p[[3]], childPat]]
    ] &
  ];

(* Descendant: at every matching ancestor, DeleteCases innerPat across its subtree *)
deleteC[tree_, Descendant[outerPat_, innerPat_]] :=
  xmlWalk[tree,
    Replace[#, p:outerPat :>
      XMLElement[p[[1]], p[[2]], DeleteCases[p[[3]], innerPat, Infinity]]
    ] &
  ];

(* =========================================================== *)
(* XMLMatchQ (ADR 0013)                                         *)
(* A whole-element test, as StringMatchQ is a whole-string one. *)
(* =========================================================== *)

XMLMatchQ[_, q_?combinatorQ] := (Message[XMLMatchQ::combinator, Short[q]]; $Failed);
XMLMatchQ[_, q_RuleDelayed] := (Message[XMLMatchQ::badpat, Short[q]]; $Failed);

(* Only the element itself is materialised: its children cannot be reached. *)
XMLMatchQ[el_, q_] :=
  Replace[compileQuery[q, XMLMatchQ], {
    $Failed -> $Failed,
    {pattern_, {}} :> MatchQ[el, pattern],
    {pattern_, readings_} :> MatchQ[materialise[el, readings, {0}], pattern]}];

XMLMatchQ[q_][el_] := XMLMatchQ[el, q];

(* =========================================================== *)
(* HTMLTextContent                                             *)
(* Lossless tree-fold: concatenate every descendant string in  *)
(* document order, inserting/removing no whitespace.           *)
(*                                                              *)
(* Public arm validates with validTreeQ (same input surface as *)
(* XMLCases) and delegates to the internal total walk; the      *)
(* walk never messages, so stray non-element/non-string nodes   *)
(* (comments, declarations) silently contribute "" mid-tree.    *)
(* =========================================================== *)

HTMLTextContent[tree_] := textContentWalk[tree] /; validTextInputQ[tree];

HTMLTextContent[tree_] :=
  (Message[HTMLTextContent::badtree, Head[tree]]; $Failed) /; !validTextInputQ[tree];

(* Internal total recursion \[LongDash] every node contributes a string *)
textContentWalk[XMLObject["Document"][_, root_, _]] := textContentWalk[root];
textContentWalk[XMLElement[_, _, children_List]] :=
  StringJoin[textContentWalk /@ children];
textContentWalk[s_String] := s;
textContentWalk[l_List] := StringJoin[textContentWalk /@ l];
textContentWalk[_] := "";

(* =========================================================== *)
(* Display-role substrate (shared Layer 1)                     *)
(*                                                              *)
(* The classification that both readable-text extraction        *)
(* (HTMLInnerText) and notebook conversion (HTMLToNotebook)     *)
(* build on. Each element is classified by tag alone (the       *)
(* frozen user-agent stylesheet) into one of five display       *)
(* roles \[LongDash] Block, Inline, Preformatted, LineBreak, Skip \[LongDash] with   *)
(* a user "Roles" override layer (compileRules + roleOf). The  *)
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
$htmlPreTags = {"pre", "listing", "plaintext", "xmp", "textarea"};
$htmlSkipTags = {"script", "style", "head", "title", "template", "datalist",
  "link", "meta", "base", "noscript"};

(* Collapse every run of whitespace to a single space \[LongDash] the Normal-whitespace
   primitive shared by both emitters. *)
normWS[s_String] := StringReplace[s, Whitespace .. -> " "];

defaultRole[tag_String] := Which[
  MemberQ[$htmlSkipTags, tag], "Skip",
  tag === "br",               "LineBreak",
  MemberQ[$htmlPreTags, tag],  "Preformatted",
  MemberQ[$htmlBlockTags, tag], "Block",
  True,                        "Inline"];
defaultRole[_] := "Inline";

(* ---- Role rules: string LHS sugars to XMLPattern; Association sugars to
   an ordered rule list; first match wins. ---- *)
$displayRoles = {"Block", "Inline", "Preformatted", "LineBreak", "Skip"};
validRoleQ[r_] := MemberQ[$displayRoles, r];

sugarRoleLHS[s_String] := XMLPattern[s];
sugarRoleLHS[lhs_] := lhs;

(* Each rule's left-hand side is compiled like a query, and must be an element
   pattern: a rule is tried against one element at a time. compileRules gives
   {rules, readings}, the readings being those of every list key any rule
   names, so the caller materialises the tree once, at entry. *)
compileRule[Verbatim[Rule][lhs_, r_], head_, readings_] :=
  If[combinatorQ[lhs], refuseRule[head, lhs],
    Replace[compileQuery[sugarRoleLHS[lhs], head, readings], {p_, rd_} :> {p -> r, rd}]];
compileRule[rule_RuleDelayed, head_, readings_] :=
  If[combinatorQ[rule[[1]]], refuseRule[head, rule[[1]]],
    compileQuery[
      RuleDelayed @@ Join[Hold @@ {sugarRoleLHS[rule[[1]]]}, Extract[rule, {2}, Hold]],
      head, readings]];
compileRule[x_, _, _] := {x, {}};

refuseRule[head_, lhs_] := (Message[MessageName[head, "badpat"], Short[lhs]]; $Failed);

compileRules[rules_, head_] :=
  With[{readings = resolveReadings[$AttributeReadings]},
    With[{cs = compileRule[#, head, readings] & /@
        If[AssociationQ[rules], Normal[rules], Flatten[{rules}]]},
      If[MemberQ[cs, $Failed], $Failed, {cs[[All, 1]], Union @@ cs[[All, 2]]}]]];

materialiseFor[tree_, {}] := tree;
materialiseFor[tree_, readings_] := materialise[tree, readings];

(* roleOf: first matching rule wins; a non-role RHS messages (under the caller's
   own ::badrole) and defers to the frozen table; no match defers to the table;
   unknown tag -> Inline. *)
roleOf[el : XMLElement[tag_, _, _], rules_, msgHead_] :=
  With[{r = Replace[el, rules]},
    Which[
      MatchQ[r, _XMLElement], defaultRole[tag],
      validRoleQ[r],          r,
      True, (Message[MessageName[msgHead, "badrole"], r]; defaultRole[tag])
    ]];

(* =========================================================== *)
(* HTMLInnerText                                               *)
(* Readable text over the display-role substrate. A two-pass    *)
(* fold turns the classified tree into text:                    *)
(*   Pass A (itToks): tree -> flat token stream; the preserve   *)
(*     whitespace flag is threaded down, box/skip/break are     *)
(*     decided locally.                                         *)
(*   Pass B (itSerialize): tokens -> string; collapse runs,     *)
(*     strongest-glue-wins between content, coalesce breaks,    *)
(*     trim both ends (glue is gated on a non-empty accumulator).*)
(* Public arms validate (validTextInputQ) and message on bad    *)
(* input; the internal walk is total so stray nodes contribute  *)
(* nothing mid-tree.                                            *)
(* =========================================================== *)

(* ---- Pass A: tree -> token stream (itV = verbatim text; itNl = <br>;
   itBr = block boundary). The preserve flag rides down the recursion. ---- *)
itToks[s_String, False, _] := {s};
itToks[s_String, True, _] := {itV[s]};
itToks[l_List, pre_, rules_] := Flatten[itToks[#, pre, rules] & /@ l];
itToks[el : XMLElement[_, _, ch_], pre_, rules_] :=
  Switch[roleOf[el, rules, HTMLInnerText],
    "Skip",         {},
    "LineBreak",    {itNl},
    "Preformatted", Join[{itBr}, Flatten[itToks[#, True, rules] & /@ ch], {itBr}],
    "Block",        Join[{itBr}, Flatten[itToks[#, pre, rules] & /@ ch], {itBr}],
    _,              Flatten[itToks[#, pre, rules] & /@ ch]];
itToks[_, _, _] := {};

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

glueStr[1, _] := " ";
glueStr[2, _] := "\n";
glueStr[3, bsep_] := bsep;
glueStr[_, _] := "";

itSerialize[toks_, bsep_] :=
  First @ Fold[
    Function[{state, a},
      With[{out = First[state], glue = Last[state]},
        If[contentQ[a],
          {out <> If[out =!= "", glueStr[glue, bsep], ""] <> contentText[a], 0},
          {out, Max[glue, atomRank[a]]}
        ]]],
    {"", 0},
    Flatten[atomize /@ toks]];

(* ---- Public interface ---- *)
Options[HTMLInnerText] = {"Roles" -> {}, "BlockSeparator" -> "\n"};

HTMLInnerText[XMLObject["Document"][_, root_, _], opts : OptionsPattern[]] :=
  HTMLInnerText[root, opts];

HTMLInnerText[tree_, opts : OptionsPattern[]] :=
  With[{roles = compileRules[OptionValue["Roles"], HTMLInnerText]},
    If[roles === $Failed, $Failed,
      itSerialize[
        Flatten[itToks[materialiseFor[tree, Last[roles]], False, First[roles]]],
        OptionValue["BlockSeparator"]]]
  ] /; validTextInputQ[tree];

HTMLInnerText[tree_, OptionsPattern[]] :=
  (Message[HTMLInnerText::badtree, Head[tree]]; $Failed) /; !validTextInputQ[tree];

(* =========================================================== *)
(* HTMLToNotebook                                              *)
(* The notebook emitter \[LongDash] the second function over the display- *)
(* role substrate. Layer 1 (roleOf) decides block-vs-inline    *)
(* placement; Layer 2 (the construct map) decides the form each *)
(* placed element takes: an inline box for an inline element, a *)
(* cell-style for a block. The walk recurses-and-flattens \[LongDash]      *)
(* block children become their own cells, nesting surviving     *)
(* only through style-name depth (Item/Subitem/...). The leaf-  *)
(* collapsing exceptions (pre, blockquote, table) collapse a    *)
(* whole subtree into one cell instead of recursing.            *)
(*                                                              *)
(* Threaded context (ctx) carries: the ambient block cell-style *)
(* ("blk", default "Text") that buffered inline runs land in;   *)
(* the list "depth"/"ord"ered flags; the blockquote "qd" depth; *)
(* and the normalized "roles"/"constructs" override rules.      *)
(* =========================================================== *)

(* ---- Construct map (Layer 2) ---- *)

(* The closed set of inline construct tokens. A construct RHS that is a string
   is an inline token when it is in this set, otherwise a block cell-style. *)
$inlineConstructs = {"Bold", "Italic", "Underline", "StrikeThrough", "Code",
  "Hyperlink", "Plain"};
(* Tokens that wrap their inner boxes in a StyleBox (Hyperlink/Plain differ). *)
$styleTokens = {"Bold", "Italic", "Underline", "StrikeThrough", "Code"};

(* A construct value that is neither a string nor None is a constructor
   function, applied to the matched element (the universal escape hatch). *)
functionConstructQ[c_] := c =!= None && !StringQ[c];
(* A string construct destined for a block cell-style (not an inline token). *)
blockStyleQ[c_String] := !MemberQ[$inlineConstructs, c];
blockStyleQ[_] := False;

(* Default construct map: the frozen UA stylesheet read for font rendering
   (inline) plus the structural block styles. Tried after the user rules,
   first match wins; an unmatched element gets no construct (None). table/hr
   are themselves built-in constructor-function rules. *)
(* Plain XMLElement patterns: an XMLPattern is inert, and these name no list
   key, so they are what compiling XMLPattern[tag] would give. *)
$defaultConstructRules = {
  XMLElement["h1", _, _] -> "Title",
  XMLElement["h2", _, _] -> "Chapter",
  XMLElement["h3", _, _] -> "Section",
  XMLElement["h4", _, _] -> "Subsection",
  XMLElement["h5", _, _] -> "Subsubsection",
  XMLElement["h6", _, _] -> "Subsubsubsection",
  XMLElement["p", _, _] -> "Text",
  XMLElement["li", _, _] -> "Item",
  XMLElement["b" | "strong", _, _] -> "Bold",
  XMLElement["i" | "em" | "cite" | "var" | "dfn", _, _] -> "Italic",
  XMLElement["u" | "ins", _, _] -> "Underline",
  XMLElement["s" | "del" | "strike", _, _] -> "StrikeThrough",
  XMLElement["code" | "kbd" | "samp" | "tt", _, _] -> "Code",
  XMLElement["a", _, _] -> "Hyperlink",
  XMLElement["img", _, _] -> "Hyperlink",
  XMLElement["span" | "mark" | "small" | "q" | "abbr" | "sub" | "sup" |
    "time" | "label" | "bdi" | "bdo" | "data" | "ruby" | "rt" | "rp" |
    "wbr", _, _] -> "Plain",
  XMLElement["table", _, _] :> tableConstruct,
  XMLElement["hr", _, _] :> hrConstruct
};

(* First user rule wins, else the default map, else None. *)
constructOf[el_XMLElement, ctx_] :=
  With[{r = Replace[el, Join[ctx["constructs"], $defaultConstructRules]]},
    If[MatchQ[r, _XMLElement], None, r]];

(* ---- Inline emission: node -> list of box atoms (strings + boxes) ---- *)

boxRow[{}] := "";
boxRow[{x_}] := x;
boxRow[xs_List] := RowBox[xs];

(* Trim whitespace-only string atoms at both ends, then trim the inner edges of
   the surviving boundary strings; meaningful internal spacing is kept. *)
trimAtoms[a0_List] :=
  Module[{a = DeleteCases[a0, ""]},
    While[a =!= {} && StringQ[First[a]] && StringMatchQ[First[a], Whitespace ..],
      a = Rest[a]];
    While[a =!= {} && StringQ[Last[a]] && StringMatchQ[Last[a], Whitespace ..],
      a = Most[a]];
    If[a =!= {} && StringQ[First[a]],
      a = MapAt[StringReplace[#, StartOfString ~~ Whitespace .. -> ""] &, a, 1]];
    If[a =!= {} && StringQ[Last[a]],
      a = MapAt[StringReplace[#, Whitespace .. ~~ EndOfString -> ""] &, a, -1]];
    a];

(* Does an atom list carry real content (a box, or non-blank text)? *)
realQ[a_List] := AnyTrue[a, (! StringQ[#] || StringTrim[#] =!= "") &];

styleBox["Bold", inner_] := StyleBox[boxRow[inner], FontWeight -> Bold];
styleBox["Italic", inner_] := StyleBox[boxRow[inner], FontSlant -> Italic];
styleBox["Underline", inner_] :=
  StyleBox[boxRow[inner], FontVariations -> {"Underline" -> True}];
styleBox["StrikeThrough", inner_] :=
  StyleBox[boxRow[inner], FontVariations -> {"StrikeThrough" -> True}];
styleBox["Code", inner_] := FrameBox[StyleBox[boxRow[inner], "Code"]];

(* Hyperlink reads href, falling back to src (img); the label is the inner
   boxes, or the alt text / URL when there are none. No usable href -> Plain. *)
linkHref[XMLElement[_, attrs_, _]] :=
  With[{a = Association[attrs]}, Lookup[a, "href", Lookup[a, "src", None]]];
linkLabel[XMLElement[_, attrs_, _], href_] :=
  With[{a = Association[attrs]}, Lookup[a, "alt", href]];

hyperResult[el_, inner_] :=
  With[{href = linkHref[el]},
    If[href === None || href === "",
      inner,
      {ButtonBox[
        If[inner === {}, linkLabel[el, href], boxRow[inner]],
        BaseStyle -> "Hyperlink", ButtonData -> {URL[href], None}]}]];

inlineForm[c_, el_, inner_] :=
  Which[
    functionConstructQ[c], {c[el]},
    c === "Hyperlink",     hyperResult[el, inner],
    inner === {},          {},
    MemberQ[$styleTokens, c], {styleBox[c, inner]},
    True,                  inner   (* "Plain", None, or a block style placed inline *)
  ];

inlineBoxes[s_String, _] := {normWS[s]};
inlineBoxes[el : XMLElement[_, _, ch_], ctx_] :=
  Switch[roleOf[el, ctx["roles"], HTMLToNotebook],
    "Skip",      {},
    "LineBreak", {"\n"},
    _,           inlineForm[constructOf[el, ctx], el,
                   trimAtoms@Flatten[inlineBoxes[#, ctx] & /@ ch]]];
inlineBoxes[_, _] := {};

(* ---- Block emission: walk children, buffering inline runs into cells of the
   ambient block style and recursing on block children. ---- *)

nodeRole[_String, _] := "Inline";
nodeRole[el_XMLElement, ctx_] := roleOf[el, ctx["roles"], HTMLToNotebook];
nodeRole[_, _] := "Skip";

flushBuf[cells_, buf_, ctx_] :=
  With[{run = trimAtoms[buf]},
    If[realQ[run], Append[cells, Cell[TextData[run], ctx["blk"]]], cells]];

blockEmit[children_List, ctx_] :=
  Module[{res},
    res = Fold[
      Function[{acc, node},
        With[{cells = acc[[1]], buf = acc[[2]]},
          Switch[nodeRole[node, ctx],
            "Skip",                acc,
            "Inline" | "LineBreak", {cells, Join[buf, inlineBoxes[node, ctx]]},
            _,                     {Join[flushBuf[cells, buf, ctx],
                                       emitBlock[node, ctx]], {}}]]],
      {{}, {}}, children];
    flushBuf[res[[1]], res[[2]], ctx]];

(* List context: descending into a <ul>/<ol> deepens the list and records
   whether it is ordered; the style name is derived at each <li>. *)
listCtx[ctx_, tag_] :=
  <|ctx, "depth" -> ctx["depth"] + 1, "ord" -> (tag === "ol")|>;
listStyleName[ctx_] :=
  With[{base = Switch[ctx["depth"], 0 | 1, "Item", 2, "Subitem", _, "Subsubitem"]},
    If[TrueQ[ctx["ord"]], base <> "Numbered", base]];

(* Verbatim text for a <pre>: lossless descendant text, less the one leading
   newline browsers ignore right after the tag. *)
preText[el_] :=
  StringReplace[textContentWalk[el], StartOfString ~~ "\n" -> ""];

(* Normalize a constructor-function result to a list of cells. *)
wrapCells[c_Cell] := {c};
wrapCells[l_List] := l;
wrapCells[b_] := {Cell[BoxData[b], "Output"]};

emitBlock[el : XMLElement[tag_, _, ch_], ctx_] :=
  With[{role = roleOf[el, ctx["roles"], HTMLToNotebook],
        c = constructOf[el, ctx]},
    Which[
      functionConstructQ[c],         wrapCells[c[el]],
      blockStyleQ[c],                blockStyleEmit[el, c, ctx],
      role === "Preformatted",       {Cell[preText[el], "Program"]},
      tag === "blockquote",          quoteCells[el, ctx],
      MemberQ[{"ul", "ol"}, tag],    blockEmit[ch, listCtx[ctx, tag]],
      True,                          blockEmit[ch, ctx]]];
emitBlock[_, _] := {};

(* A block cell-style: recurse with it as the ambient style. An all-inline body
   (heading, paragraph, list item) collapses to one cell; a body with block
   children flattens them into their own cells. <li>'s "Item" is resolved to a
   depth-aware list style. *)
blockStyleEmit[XMLElement[_, _, ch_], style_, ctx_] :=
  blockEmit[ch,
    <|ctx, "blk" -> If[style === "Item", listStyleName[ctx], style]|>];

(* ---- Blockquote (leaf-collapsing, nesting-aware) ----
   A <blockquote> becomes one Cell[BoxData[FrameBox[...]], "Text"]; the Markdown
   exporter prefixes every line of the frame with "> ". The interior is rendered
   to boxes (inline formatting preserved), one paragraph per block descendant,
   paragraphs joined by "\n". A nested <blockquote> cannot carry its own frame
   (frames do not nest), so each of its paragraphs is prefixed with a literal
   "> " box \[LongDash] which composes with the outer frame's "> " to "> > ", threading
   quote depth through the text itself. Lists inside a quote flatten to one
   paragraph (line) per item. *)

flushPara[paras_, buf_] :=
  With[{run = trimAtoms[buf]},
    If[realQ[run], Append[paras, boxRow[run]], paras]];

(* Walk a child list, buffering inline runs into paragraph boxes and recursing
   on block descendants \[LongDash] the cell-free analogue of blockEmit. *)
quoteCollect[children_List, ctx_] :=
  Module[{res},
    res = Fold[
      Function[{acc, node},
        With[{paras = acc[[1]], buf = acc[[2]]},
          Switch[nodeRole[node, ctx],
            "Skip",                acc,
            "Inline" | "LineBreak", {paras, Join[buf, inlineBoxes[node, ctx]]},
            _,                     {Join[flushPara[paras, buf],
                                       quoteBlockParas[node, ctx]], {}}]]],
      {{}, {}}, children];
    flushPara[res[[1]], res[[2]]]];

quoteBlockParas[XMLElement["blockquote", _, ch_], ctx_] :=
  (RowBox[{"> ", #}] &) /@ quoteCollect[ch, ctx];
quoteBlockParas[XMLElement[_, _, ch_], ctx_] := quoteCollect[ch, ctx];
quoteBlockParas[_, _] := {};

joinParas[{}] := "";
joinParas[{p_}] := p;
joinParas[ps_List] := RowBox[Riffle[ps, "\n"]];

quoteCells[XMLElement[_, _, ch_], ctx_] :=
  {Cell[BoxData[FrameBox[joinParas[quoteCollect[ch, ctx]]]], "Text"]};

(* ---- Built-in constructor-function constructs ---- *)

hrConstruct[_] := Cell["", "Text", CellFrame -> {{0, 0}, {0, 1}}];

(* <table> -> Dataset when a leading all-<th> row gives unique column labels (an
   idiomatic GFM header), else Grid (positional, blank header, every row kept).
   Dataset/Grid over Tabular because the paclet floor is WL 12+. Cells degrade
   to plain text. See ADR 0003. *)
cellText[XMLElement[_, _, c_]] := StringTrim[normWS[StringJoin[textContentWalk /@ c]]];

tableCellsOf[tr_] := Cases[tr[[3]], e : XMLElement["th" | "td", _, _] :> cellText[e]];
tableHeaderRowQ[tr_] :=
  With[{cs = Cases[tr[[3]], XMLElement["th" | "td", _, _]]},
    cs =!= {} && AllTrue[cs, MatchQ[#, XMLElement["th", _, _]] &]];

padRow[row_, n_] := PadRight[row, n, ""];
rectangular[rows_] := With[{n = Max[Length /@ rows]}, padRow[#, n] & /@ rows];

datasetCell[headers_, bodyRows_] :=
  Cell[BoxData[ToBoxes[
    Dataset[AssociationThread[headers, padRow[#, Length[headers]]] & /@ bodyRows]]],
    "Output"];
gridCell[rows_] := Cell[BoxData[ToBoxes[Grid[rectangular[rows]]]], "Output"];

tableConstruct[el_XMLElement] :=
  Module[{trs = Cases[el, _XMLElement?(MatchQ[#, XMLElement["tr", _, _]] &), Infinity],
          rows, hasHeader, headers},
    rows = tableCellsOf /@ trs;
    rows = DeleteCases[rows, {}];
    If[rows === {}, Return[gridCell[{{""}}]]];
    hasHeader = trs =!= {} && tableHeaderRowQ[First[trs]];
    If[hasHeader,
      headers = First[rows];
      If[DuplicateFreeQ[headers] && headers =!= {},
        datasetCell[headers, Rest[rows]],
        gridCell[rows]],
      gridCell[rows]]];

(* ---- Public interface ---- *)

initCtx[roleRules_, conRules_] :=
  <|"blk" -> "Text", "depth" -> 0, "ord" -> False, "qd" -> 0,
    "roles" -> roleRules, "constructs" -> conRules|>;

toChildList[s_String] := {s};
toChildList[l_List] := l;
toChildList[e_XMLElement] := {e};

Options[HTMLToNotebook] = {"Roles" -> {}, "Constructs" -> {}};

HTMLToNotebook[XMLObject["Document"][_, root_, _], opts : OptionsPattern[]] :=
  HTMLToNotebook[root, opts];

HTMLToNotebook[tree_, opts : OptionsPattern[]] :=
  With[{roles = compileRules[OptionValue["Roles"], HTMLToNotebook],
        cons = compileRules[OptionValue["Constructs"], HTMLToNotebook]},
    If[roles === $Failed || cons === $Failed, $Failed,
      Notebook[
        blockEmit[toChildList[materialiseFor[tree, Union[Last[roles], Last[cons]]]],
          initCtx[First[roles], First[cons]]]]]
  ] /; validTextInputQ[tree];

HTMLToNotebook[tree_, OptionsPattern[]] :=
  (Message[HTMLToNotebook::badtree, Head[tree]]; $Failed) /; !validTextInputQ[tree];

End[];
EndPackage[];
