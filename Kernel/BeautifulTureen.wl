(* ::Package:: *)
(* BeautifulTureen: XML patterns + the XML* consumers *)

BeginPackage["MaximilienTirard`BeautifulTureen`"];

(* === Public symbols === *)

XMLPattern::usage = "XMLPattern[tag] is an XML pattern that matches any XMLElement whose tag matches tag. XMLPattern[tag, attrs] also requires the element's attributes to match attrs. MatchQ and Cases treat XMLPattern as a literal expression; use it with XMLCases, XMLFirstCase, XMLDeleteCases, XMLMatchQ and the \"Roles\" and \"Constructs\" options. attrs is a \"key\" -> value rule, a bare \"key\" (any value), or a list of these, and can be named or tested as a whole. The element may have other attributes as well. A key is a string, a {namespace, name} pair, or alternatives of these. A value is any pattern, matched against the whole attribute value. The list key \"classList\" gives the element's classes as a list of strings, and \"classList\" -> \"cls\" matches an element that has the class cls. $AttributeReadings can add list keys for other attributes.";
CSSClass::usage = "CSSClass is obsolete. Match an element's class list with the \"classList\" key of XMLPattern instead: XMLPattern[tag, \"classList\" -> \"cls\"].";
$AttributeReadings::usage = "$AttributeReadings is an Association that gives, for each attribute it names, how the attribute value is split into a list of tokens and the list key that gives that list in an XMLPattern. Each entry is an Association with the fields Method, Delimiters, \"TrimWhitespace\" and \"ListKey\", any of which can be omitted. Method \"SpaceSeparated\" (the default) splits on HTMLWhitespace and does not trim tokens. Method \"CommaSeparated\" splits on \",\" and trims HTML whitespace from each token. Delimiters (a string pattern) and \"TrimWhitespace\" (True or False) override the setting that Method gives. \"ListKey\" -> Automatic gives the attribute name followed by \"List\". Keys are attribute names given as strings; a {namespace, name} attribute cannot have an entry. By default, $AttributeReadings has one entry, for \"class\", with the list key \"classList\". The \"AttributeReadings\" option of functions such as XMLCases adds entries for one call, and an entry for an attribute already present replaces it. Block[{$AttributeReadings = ...}, ...] replaces the whole Association, including the \"class\" entry.";
HTMLWhitespace::usage = "HTMLWhitespace is a string pattern that matches a run of one or more HTML whitespace characters: space, tab, line feed, form feed and carriage return. Use StringSplit[value, HTMLWhitespace] to split a class attribute as a browser does. HTMLWhitespace does not match no-break space or other Unicode whitespace, which StringSplit splits on by default.";
HTMLClassList::usage = "HTMLClassList[element] gives the classes of an XMLElement as a list of strings: its class attribute split on HTMLWhitespace, in the order written and with duplicates kept. An element with no class attribute, or with a class attribute that is empty or only whitespace, gives {}. HTMLClassList takes a single element; for many elements, use HTMLClassList /@ XMLCases[tree, pattern].";
XMLCases::usage = "XMLCases[tree, pattern] gives a list of the elements of tree, at any depth, that match pattern. The elements are in document order: an element comes before the elements nested in it, and an earlier sibling before a later one. tree itself is never included. pattern can be an XMLPattern, alternatives of them, a Child, Descendant, Adjacent or Sibling combinator, or any of these with a condition pat /; test. XMLCases[tree, pattern :> body] gives the value of body for each match, evaluated in document order. A combinator gives each element that its last stage matches once. If tree is an XMLElement, tree can match any stage of a combinator except the last. A name for a whole element, as in e : XMLPattern[...], gives the element as it appears in tree, without list keys such as \"classList\". XMLCases[tree, pattern, \"AttributeReadings\" -> readings] adds readings to $AttributeReadings for this call.";
XMLFirstCase::usage = "XMLFirstCase[tree, pattern] gives the first element of tree that matches pattern, in document order, or Missing[\"NotFound\"] if there is none. Of nested matches, it gives the outermost. XMLFirstCase[tree, pattern, default] gives default if there is no match. XMLFirstCase accepts the same patterns as XMLCases and gives the first element of the list that XMLCases gives. With pattern :> body, body is evaluated only for the match that XMLFirstCase returns. The \"AttributeReadings\" option adds readings to $AttributeReadings, as in XMLCases.";
XMLDeleteCases::usage = "XMLDeleteCases[tree, pattern] gives tree with every element that matches pattern removed, at any depth. pattern can be an XMLPattern, alternatives of them, a Child or Descendant combinator, or any of these with a condition pat /; test. Combinators can be nested, and each stage can have a condition. A combinator removes the elements that its last stage matches. As in XMLCases, if tree is an XMLElement, tree can match any stage of a combinator except the last. Adjacent and Sibling cannot be used, even as a stage of another combinator. The \"AttributeReadings\" option adds readings to $AttributeReadings, as in XMLCases.";
XMLMatchQ::usage = "XMLMatchQ[element, pattern] gives True if element matches pattern, and False otherwise. XMLMatchQ[pattern] is an operator form. pattern can be an XMLPattern, alternatives of them, or either with a condition pat /; test. XMLMatchQ tests the element itself, not the elements nested in it; use XMLCases to search a tree. The \"AttributeReadings\" option adds readings to $AttributeReadings, in both XMLMatchQ[element, pattern, opts] and XMLMatchQ[pattern, opts].";
Child::usage = "Child[parentPat, childPat] is a combinator for XMLCases, XMLFirstCase and XMLDeleteCases that matches elements that match childPat and are direct children of an element that matches parentPat. Each argument is a stage: an XMLPattern, alternatives of them, or another combinator. Stages chain left to right, as in a CSS selector, so Descendant[a, Child[b, c]] and Child[Descendant[a, b], c] select the same elements. A condition on a stage can use the names bound in that stage. A condition on the whole combinator can use the names bound in all its stages.";
Adjacent::usage = "Adjacent[beforePat, afterPat] is a combinator for XMLCases and XMLFirstCase that matches elements that match afterPat and immediately follow a sibling that matches beforePat. Each argument is a stage: an XMLPattern, alternatives of them, or another combinator. Stages chain left to right, as in a CSS selector, so Descendant[a, Child[b, c]] and Child[Descendant[a, b], c] select the same elements. A condition on a stage can use the names bound in that stage. A condition on the whole combinator can use the names bound in all its stages.";
Sibling::usage = "Sibling[beforePat, afterPat] is a combinator for XMLCases and XMLFirstCase that matches elements that match afterPat and follow a sibling that matches beforePat, at any distance. Each such element is given once. A name bound in beforePat, as used in a rule body, gives the first matching earlier sibling in document order. Each argument is a stage: an XMLPattern, alternatives of them, or another combinator. Stages chain left to right, as in a CSS selector, so Descendant[a, Child[b, c]] and Child[Descendant[a, b], c] select the same elements. A condition on a stage can use the names bound in that stage. A condition on the whole combinator can use the names bound in all its stages.";
Descendant::usage = "Descendant[ancestorPat, descPat] is a combinator for XMLCases, XMLFirstCase and XMLDeleteCases that matches elements that match descPat and are nested at any depth inside an element that matches ancestorPat. Each such element is given once, however many of its ancestors match. A name bound in ancestorPat, as used in a rule body, gives the outermost matching ancestor. Each argument is a stage: an XMLPattern, alternatives of them, or another combinator. Stages chain left to right, as in a CSS selector, so Descendant[a, Child[b, c]] and Child[Descendant[a, b], c] select the same elements. A condition on a stage can use the names bound in that stage. A condition on the whole combinator can use the names bound in all its stages.";
HTMLTextContent::usage = "HTMLTextContent[tree] gives the text of an XML tree: all the strings it contains, joined in document order. No whitespace is added or removed, so source indentation and the whitespace in <pre> are kept. tree can be an XMLElement, an XMLObject document, a list, or a string.";
HTMLInnerText::usage = "HTMLInnerText[tree] gives the readable text of an XML tree. Runs of whitespace are collapsed, block-level elements go on their own lines, <br> becomes a newline, <pre> content is kept as written, tags such as script and style are dropped, and the result is trimmed. How each element is treated depends only on its tag, as given by the built-in user-agent stylesheet. HTMLInnerText[tree, \"Roles\" -> rules] changes this, with rules of the form pattern -> role, where pattern is an XMLPattern or a tag string and role is \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\" or \"Skip\". \"BlockSeparator\" -> sep sets the string inserted between blocks (default \"\\n\"). \"AttributeReadings\" -> readings adds readings to $AttributeReadings for the patterns in the rules. tree can be an XMLElement, an XMLObject document, a list, or a string.";
HTMLToNotebook::usage = "HTMLToNotebook[tree] converts an HTML or XML tree to a Notebook expression, which can be displayed or exported with Export to Markdown, PDF, RTF, etc. Block-level tags become cells, such as headings -> Title, Chapter, Section, etc., p -> Text, li -> Item, Subitem, etc., blockquote -> a framed quote, pre -> a Program cell, and table -> a Dataset or Grid. Inline tags become boxes in the surrounding cell, such as b -> bold, i -> italic, code -> inline code and a -> a hyperlink. How each element is treated depends only on its tag, as given by the built-in user-agent stylesheet. HTMLToNotebook[tree, \"Roles\" -> rules] changes the role of elements, such as block or inline. \"Constructs\" -> rules changes what an element becomes: an inline style such as \"Bold\", a cell style, or a function that is applied to the element and gives a Cell or boxes. The left-hand side of each rule is an XMLPattern or a tag string. \"AttributeReadings\" -> readings adds readings to $AttributeReadings for the patterns in the rules. tree can be an XMLElement, an XMLObject document, a list, or a string.";

(* === Messages === *)

CSSClass::obs = "CSSClass is obsolete. Match the class list with the \"classList\" key instead: XMLPattern[tag, \"classList\" -> \"cls\"] for .cls, or \"classList\" -> _?(FreeQ[\"cls\"]) for :not(.cls).";
XMLPattern::badtag = "The tag should be a string, a {namespace, name} pair, alternatives of these, or a pattern such as _. Got `1`.";
XMLPattern::nargs = "XMLPattern was given `1` arguments, but takes a tag and at most one attribute argument. Put several attribute constraints in one list: XMLPattern[tag, {c1, c2, ...}].";
XMLPattern::badattrs = "The attribute argument should be a key -> value rule, a key, or a list of these, optionally named (attrs : ...) or tested (...?test) as a whole. Got `1`.";
XMLPattern::badkey = "An attribute key should be a string, a {namespace, name} pair of strings, or alternatives of these. Got `1`. To test the keys, test the attributes as a whole: XMLPattern[tag, attrs_?test].";
XMLPattern::dupkey = "The attribute key `1` appears in more than one constraint, so the pattern can never match. Combine the constraints into one value pattern.";
XMLPattern::strpat = "`1` is a string pattern, and in an XMLPattern it does not match any string. Write _?(StringMatchQ[`1`]) instead.";
XMLCases::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of these. Got head `1`.";
XMLCases::badpat = "The second argument should be an XMLPattern, alternatives of them, a Child, Descendant, Adjacent or Sibling combinator, or a rule pattern :> body with one of these. Each can have a condition (/;), and an XMLPattern or alternatives of them can be named. Got `1`.";
XMLFirstCase::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of these. Got head `1`.";
XMLFirstCase::badpat = "The second argument should be an XMLPattern, alternatives of them, a Child, Descendant, Adjacent or Sibling combinator, or a rule pattern :> body with one of these. Each can have a condition (/;), and an XMLPattern or alternatives of them can be named. Got `1`.";
XMLDeleteCases::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of these. Got head `1`.";
XMLDeleteCases::badpat = "The second argument should be an XMLPattern, alternatives of them, or a Child or Descendant combinator. Each can have a condition (/;), and an XMLPattern or alternatives of them can be named. A rule pattern :> body cannot be used. Got `1`.";
XMLDeleteCases::unsupported = "XMLDeleteCases cannot use Adjacent or Sibling, either as the pattern or as a stage of another combinator.";
XMLMatchQ::badpat = "The pattern should be an XMLPattern, alternatives of them, or either with a condition pat /; test. Got `1`.";
XMLMatchQ::condcombinator = "A condition (/;) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Got `1`.";
$AttributeReadings::badkey = "Each key in the readings should be an attribute name given as a string. Got `1`.";
$AttributeReadings::notassoc = "$AttributeReadings and the \"AttributeReadings\" option should be an Association from attribute names to readings. Got `1`.";
$AttributeReadings::badentry = "The reading for `1` should be an Association with any of the fields Method, Delimiters, \"TrimWhitespace\" and \"ListKey\". Got `2`.";
$AttributeReadings::badfield = "The reading for `1` has the unknown field `2`. The fields of a reading are Method, Delimiters, \"TrimWhitespace\" and \"ListKey\".";
$AttributeReadings::badmethod = "The reading for `1` has Method `2`. Method should be \"SpaceSeparated\" or \"CommaSeparated\".";
$AttributeReadings::badvalue = "The reading for `1` has `2` -> `3`. Delimiters should be a string pattern, \"TrimWhitespace\" should be True or False, and \"ListKey\" should be a string. Any of them can also be Automatic.";
$AttributeReadings::duplistkey = "More than one reading has the list key `1`. Give each reading a different \"ListKey\".";
$AttributeReadings::listkeyisreading = "The list key `1` is also an attribute with a reading, so `1` in an XMLPattern would be ambiguous. Choose a different \"ListKey\".";
XMLMatchQ::combinator = "`1` relates an element to its parent or siblings, which a lone element does not have. Use XMLCases or XMLFirstCase to search a tree with it.";
HTMLTextContent::badtree = "The first argument should be an XMLObject, an XMLElement, a string, or a list of these. Got head `1`.";
HTMLClassList::notelement = "The argument should be a single XMLElement. Got head `1`. For a list of elements, use HTMLClassList /@ elements.";
HTMLInnerText::badtree = "The first argument should be an XMLObject, an XMLElement, a string, or a list of these. Got head `1`.";
HTMLInnerText::badrole = "A \"Roles\" rule gave `1`, which is not \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\" or \"Skip\". The element gets its role from the built-in user-agent stylesheet instead.";
HTMLInnerText::badpat = "The left-hand side of a rule should be a tag string, an XMLPattern, alternatives of them, or either with a condition pat /; test. Got `1`.";
HTMLInnerText::notrule = "Each \"Roles\" entry should be a rule pattern -> value or pattern :> value. Got `1`.";
HTMLInnerText::condcombinator = "A condition (/;) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Got `1`.";
HTMLToNotebook::badtree = "The first argument should be an XMLObject, an XMLElement, a string, or a list of these. Got head `1`.";
HTMLToNotebook::badrole = "A \"Roles\" rule gave `1`, which is not \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\" or \"Skip\". The element gets its role from the built-in user-agent stylesheet instead.";
HTMLToNotebook::badpat = "The left-hand side of a rule should be a tag string, an XMLPattern, alternatives of them, or either with a condition pat /; test. Got `1`.";
HTMLToNotebook::notrule = "Each \"Roles\" or \"Constructs\" entry should be a rule pattern -> value or pattern :> value. Got `1`.";
HTMLToNotebook::condcombinator = "A condition (/;) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Got `1`.";

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

(* A name or a Condition around a pattern never changes what it is. *)
patternBase[Verbatim[Pattern][_, x_]] := patternBase[x];
patternBase[Verbatim[Condition][x_, _]] := patternBase[x];
patternBase[x_] := x;

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

(* A consumer's AttributeReadings option adds to the global; an entry for a key
   the global already has replaces that key's entry whole. A table that fails
   validation has said why, and gives $Failed. *)
readingsWith[extra_] :=
  Catch[resolveReadings[validReadings[Join @@ (validTable /@ {$AttributeReadings, extra})]], $refusal];

validTable[t_Association] := t;
validTable[t_] := refuse[$AttributeReadings::notassoc, t];

validReadings[readings_] :=
  (KeyValueMap[validReading, readings]; validListKeys[readings]; readings);

listKeyOf[key_, spec_] := Replace[Lookup[spec, "ListKey", Automatic], Automatic -> key <> "List"];

validListKeys[readings_] :=
  With[{listKeys = KeyValueMap[listKeyOf, readings]},
    Replace[Select[Tally[listKeys], Last[#] > 1 &],
      {{k_, _}, ___} :> refuse[$AttributeReadings::duplistkey, k]];
    Replace[Intersection[listKeys, Keys[readings]],
      {k_, ___} :> refuse[$AttributeReadings::listkeyisreading, k]]];

$readingFields = {Method, Delimiters, "TrimWhitespace", "ListKey"};

validReading[key_, _] /; !StringQ[key] := refuse[$AttributeReadings::badkey, key];
validReading[key_, spec_] /; !AssociationQ[spec] := refuse[$AttributeReadings::badentry, key, spec];
validReading[key_, spec_] := (
  Replace[Complement[Keys[spec], $readingFields],
    {f_, ___} :> refuse[$AttributeReadings::badfield, key, f]];
  If[!KeyExistsQ[$methodDefaults, Lookup[spec, Method, "SpaceSeparated"]],
    refuse[$AttributeReadings::badmethod, key, spec[Method]]];
  KeyValueMap[
    If[!validFieldQ[#1, #2], refuse[$AttributeReadings::badvalue, key, #1, #2]] &,
    KeyDrop[spec, Method]]);

(* Whether a value is a string pattern is the string functions' own judgement. *)
validFieldQ[Delimiters, d_] := d === Automatic || Quiet[Check[StringFreeQ["", d]; True, False]];
validFieldQ["TrimWhitespace", t_] := MatchQ[t, Automatic | True | False];
validFieldQ["ListKey", k_] := MatchQ[k, Automatic | _String];

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

(* An element materialised when it is asked for, the distinct raw values on
   tree split once, up front: for rules tried on one element at a time. *)
materialiser[_, {}] := Identity;
materialiser[tree_, readings_] :=
  With[{maps = {First[#], tokenMap[tree, #, {0, Infinity}]} & /@ readings},
    attachTokens[maps, #] &];

attachTokens[maps_, XMLElement[t_, a_List, c_]] :=
  XMLElement[t, Join[a, Function[{key, map}, tok[key] -> Lookup[map, Lookup[a, key, None], {}]] @@@ maps], c];

stripAttrs[a_] := DeleteCases[a, _tok -> _];

strip[x_] :=
  Replace[x, XMLElement[t_, a_List, c_] :> XMLElement[t, stripAttrs[a], c], {0, Infinity}];

(* =========================================================== *)
(* The query compiler                                           *)
(*                                                              *)
(* compileQuery[query, head, opt] -> the query's normal form,   *)
(* opt being the consumer's "AttributeReadings" option: an      *)
(* Association every decision about the query reads:           *)
(*   "Stages"     the compiled element patterns, in chain order *)
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
(* With[{e = strip[e$]}, ...], so it sees the original element. *)
(* A query is compiled once to learn its list keys and, only if *)
(* it names one, again with the renaming on.                    *)
(* =========================================================== *)

compileQuery[q_, head_, opt_] := compileWith[q, head, readingsWith[opt]];

(* With the readings table resolved, for a caller that compiles several queries
   against one table. *)
compileWith[_, _, $Failed] := $Failed;
compileWith[q_, head_, readings_Association] :=
  Catch[
    Module[{query, keys},
      {query, keys} = compilePass[q, head, readings, False];
      If[keys =!= {}, query = First @ compilePass[q, head, readings, True]];
      Join[query, <|"Readings" -> Lookup[readings, keys], "Head" -> head, "Query" -> q|>]],
    $refusal];

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
badpat[q_] := refuseAtHead["badpat", q];

(* ---- Queries: a rule over a pattern, or a pattern ---- *)

cQuery[r_RuleDelayed] :=
  Module[{lhs, binds},
    {lhs, binds} = reapBinds[cStage[r[[1]]]];
    normalForm[lhs, wrapBinds[binds, Extract[r, {2}, Hold]]]];
cQuery[q_] := normalForm[cStage[q], None];

normalForm[chain[stages_, links_, conditions_], body_] :=
  <|"Stages" -> stages, "Links" -> links, "Conditions" -> conditions, "Body" -> body|>;

(* A combinator's stages are element patterns or combinators, compiled to
   chain[stages, links, conditions]. A Condition on a combinator sees the names
   of all its stages, and covers them. *)
cStage[(h : Child | Descendant | Adjacent | Sibling)[a_, b_]] := joinChains[cStage[a], h, cStage[b]];
cStage[c_Condition] /; combinatorQ[patternBase[c]] := conditioned[cStage, c, coverChain];
cStage[q_] := chain[{cElem[q]}, {}, {}];

joinChains[chain[s1_, l1_, c1_], link_, chain[s2_, l2_, c2_]] :=
  chain[Join[s1, s2], Join[l1, {link}, l2],
    Join[c1, Replace[c2, {span_, test_} :> {span + Length[s1], test}, {1}]]];

coverChain[chain[s_, l_, c_], test_] := chain[s, l, Append[c, {{1, Length[s]}, test}]];

(* ---- Element patterns ---- *)

cElem[XMLPattern[args___]] := cXMLPattern[{args}];
(* A combinator is not an element pattern; the whole Alternatives is named. *)
cElem[alts_Alternatives] /; AnyTrue[List @@ alts, combinatorQ] := badpat[alts];
cElem[alts_Alternatives] := Alternatives @@ (cElem /@ List @@ alts);
cElem[Verbatim[Pattern][s_Symbol, p_]] :=
  If[combinatorQ[p], badpat[namedPattern[s, p]], bindAs[s, cElem[p], strip]];
cElem[c_Condition] := conditioned[cElem, c, conditionWith];
(* A plain XMLElement pattern is already what the consumers run. *)
cElem[x_XMLElement] := x;
cElem[q_] := badpat[q];

(* A Condition's test sees the names bound in its left-hand side, compiled by
   comp; attach puts the held test on the compiled left-hand side. *)
conditioned[comp_, c_, attach_] :=
  Module[{lhs, binds},
    {lhs, binds} = reapBinds[comp[c[[1]]]];
    Scan[Sow[#, $bindTag] &, binds];
    attach[lhs, wrapBinds[binds, Extract[c, {2}, Hold]]]];

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
   on equal elements. *)
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

(* Hold[body] -> Hold[With[{e = strip[e$], ...}, body]]

   The two-step match (restored, below) renames an element name a second time
   and wraps what this gives, so the two compose as
   With[{e$ = uncopied[e$$]}, With[{e = strip[e$]}, body]]. The order is
   required: strip removes token lists from an attribute list, not from a list
   of copies of one, so an element is uncopied before it is stripped. Issue #3
   proposes one module for both renamings. *)
wrapBinds[{}, held_Hold] := held;
wrapBinds[binds_, held_Hold] :=
  With[{spec = Replace[
      Join @@ (Replace[#, {Hold[s_], fresh_, inverse_} :> Hold[s = inverse[fresh]]] & /@ binds),
      Hold[sets___] :> Hold[{sets}]]},
    Replace[Join[spec, held], Hold[vars_, body_] :> Hold[With[vars, body]]]];

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
    brokenConditionsQ[lhs] || overlappingKeysQ[lhs] || (laterNamesQ[lhs] && bodyConditionQ[Extract[r, {2}, Hold]]) :=
  Module[{v = freshSymbol[], n = copyCount[lhs]},
    Replace[copiedRule[lhs, Extract[r, {2}, Hold]],
      Hold[rule_] :> RuleDelayed @@ Join[Hold @@ {namedPattern[v, skeleton[lhs]]},
        Hold[With[{s = {Replace[copied[v, n], {rule, _ :> $unmatched}]}}, Sequence @@ s /; s =!= {$unmatched}]]]]];
solvable[p_] /; brokenConditionsQ[p] || overlappingKeysQ[p] :=
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
  Replace[x, XMLElement[t_, a_List, c_] :> XMLElement[t, ConstantArray[a, n], c], {0, 1}];

uncopied[x_] := Replace[x, XMLElement[t_, {a_, ___}, c_] :> XMLElement[t, a, c]];

copyCount[p_] := 1 + Max[0, Cases[p, Verbatim[KeyValuePattern][r_List] :> Length[r], {0, Infinity}]];

copiedPattern[p_] := Block[{$renamed = renaming[p]}, copiedIn[p]];

copiedRule[lhs_, body_Hold] :=
  Block[{$renamed = renaming[lhs]},
    Hold @@ {RuleDelayed @@ Join[Hold @@ {copiedIn[lhs]}, restored[lhs, body]]}];

(* Each name that binds an element is renamed, and is the uncopied element in
   each test and body that can see it. When the query names a list key, the
   name was already renamed for materialisation; see wrapBinds for how the two
   compose. *)
renaming[p_] := Association[# -> freshSymbol[] & /@ elementNames[p]];

restored[l_, held_Hold] :=
  wrapBinds[{#, $renamed[#], uncopied} & /@ Select[elementNames[l], KeyExistsQ[$renamed, #] &], held];

copiedIn[Verbatim[Pattern][s_, p_]] /; KeyExistsQ[$renamed, Hold[s]] :=
  With[{f = $renamed[Hold[s]]}, namedPattern[f, copiedIn[p]]];
copiedIn[Verbatim[Pattern][s_, p_]] := namedPattern[s, copiedIn[p]];
copiedIn[c : Verbatim[Condition][l_, _]] :=
  Condition @@ Join[Hold @@ {copiedIn[l]}, restored[l, Extract[c, {2}, Hold]]];
copiedIn[XMLElement[t_, a_, c_]] := XMLElement[t, copiedAttributes[a], c];
copiedIn[Verbatim[PatternTest][p_, f_]] := PatternTest[copiedIn[p], f];
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

(* =========================================================== *)
(* Running a compiled query                                     *)
(*                                                              *)
(* The operations the XML* functions are: each takes a compiled *)
(* query (or $Failed, having messaged) and a tree, refuses what *)
(* it cannot run under the query's head, and gives the elements *)
(* as they are in the tree. elementMatcher instead gives a      *)
(* function that tests one element.                            *)
(* =========================================================== *)

queryCases[$Failed, _] := $Failed;
queryCases[c_, tree_] :=
  If[treeRefusedQ[c, tree], $Failed, runCompiled[If[chainQ[c], chainCases, casesC], tree, c]];

queryFirst[$Failed, _, _] := $Failed;
queryFirst[c_, tree_, default_] :=
  If[treeRefusedQ[c, tree], $Failed, runCompiled[If[chainQ[c], chainFirst, firstC], tree, c, default]];

(* A rule has nothing to delete with; deletion by relative position (Adjacent,
   Sibling) is a niche operation, documented as unsupported. *)
queryDelete[$Failed, _] := $Failed;
queryDelete[c_, tree_] :=
  With[{h = c["Head"]},
    Which[
      c["Body"] =!= None, Message[MessageName[h, "badpat"], c["Query"]]; $Failed,
      MemberQ[c["Links"], Adjacent | Sibling], Message[MessageName[h, "unsupported"]]; $Failed,
      treeRefusedQ[c, tree], $Failed,
      True, runCompiled[If[chainQ[c], chainDelete, deleteC], tree, c]]];

(* A function that tests one element, or $Failed if the query is refused. Only
   the element itself is materialised: its children cannot be reached. *)
elementMatcher[$Failed] := $Failed;
elementMatcher[c_] :=
  With[{h = c["Head"]},
    Which[
      elementQuery[c, c["Query"], h, "combinator"] === $Failed, $Failed,
      c["Body"] =!= None, Message[MessageName[h, "badpat"], c["Query"]]; $Failed,
      True, With[{p = plainQuery[c], r = c["Readings"]},
        If[r === {}, MatchQ[p], Function[el, MatchQ[materialise[el, r, {0}], p]]]]]];

treeRefusedQ[c_, tree_] :=
  !validTreeQ[tree] && With[{h = c["Head"]}, Message[MessageName[h, "badtree"], Head[tree]]; True];

(* A query tested on one element at a time takes no links: a combinator is
   refused under tag, and a combinator with a Condition under condcombinator.
   q is the query as written. *)
elementQuery[$Failed, _, _, _] := $Failed;
elementQuery[c_, q_, head_, tag_] :=
  With[{h = head},
    Which[
      c["Links"] === {}, c,
      c["Conditions"] === {}, Message[MessageName[h, tag], q]; $Failed,
      True, Message[MessageName[h, "condcombinator"], patternBase[q]]; $Failed]];

(* Materialise once per query, over the union of the list keys all its stages
   name; strip once, at the output. A chain runner is given the normal form, a
   plain runner the pattern or rule it runs. *)
runCompiled[run_, tree_, q_, rest___] :=
  With[{p = If[chainQ[q], q, plainQuery[q]]},
    If[q["Readings"] === {}, run[tree, p, rest],
      strip @ run[materialise[tree, q["Readings"]], p, rest]]];

(* The pattern a plain query runs, or its rule. *)
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
(* is one value, and a rule body sees every name.               *)
(* =========================================================== *)

(* Every combinator query runs as a chain, nested or not, tested or not. *)
chainQ[q_] := q["Links"] =!= {};

(* The stages and links, alternating, as the chain runner reads them. *)
chainOf[q_] := Riffle[solvable /@ q["Stages"], q["Links"]];

(* The pattern a tuple of elements matches: the list of the chain's stages. A
   Condition on the whole combinator wraps the list; one on a combinator that is
   a stage wraps the sequence of its stages, so it sees only theirs. Each
   Condition covers the stages i to j, and an inner one is applied first. *)
tuplePattern[q_] :=
  With[{n = Length[q["Stages"]]},
    Fold[conditionWith[#1, Last[#2]] &,
      Last /@ Fold[coverStages, Transpose[{Transpose[{Range[n], Range[n]}], q["Stages"]}],
        Select[q["Conditions"], First[#] =!= {1, n} &]],
      Select[q["Conditions"], First[#] === {1, n} &]]];

(* The items {{i, j}, pattern} inside a Condition's span become one. *)
coverStages[items_, {{i_, j_}, test_}] :=
  With[{in = Flatten @ Position[items, {{a_, b_}, _} /; i <= a && b <= j, {1}, Heads -> False]},
    Join[Take[items, First[in] - 1],
      {{{i, j}, conditionWith[PatternSequence @@ items[[in, 2]], test]}},
      Drop[items, Last[in]]]];

tupleRule[q_] := solvable[RuleDelayed @@ Join[Hold @@ {tuplePattern[q]}, q["Body"]]];

(* Extract reads {} as no positions, not as the whole tree. *)
at[{}] := $chainTree;
at[p_] := Extract[$chainTree, p];

elementIndices[l_List] := Flatten @ Position[l, _XMLElement, {1}, Heads -> False];

(* selected[r, p, s]: the sites related to p by r that stage s selects, in
   document order. *)
selected[Descendant, p_, s_] := Join[p, #] & /@ Position[at[p], s, Infinity, Heads -> False];
selected[Child, p_, s_] := Join[p, {3}, #] & /@ Position[at[p][[3]], s, {1}, Heads -> False];
selected[Sibling, p_, s_] := selectedAt[laterSiblings[p], s];

(* The sites at positions ps that stage s selects, with one Extract. *)
selectedAt[ps_, s_] := Pick[ps, selects[ps, s]];
selects[ps_, s_] := MatchQ[s] /@ atAll[ps];

(* Siblings are children of one element. For the children list at position
   kids: its element indices, and each index's next element index (0 for none),
   found once per list in a run, since a sibling list may be long; {} when kids
   is not an element's children. *)
siblingsAt[kids_] := Replace[$siblings[kids], _Missing :> ($siblings[kids] = siblingsOf[kids])];

siblingsOf[kids_] /; Length[kids] >= 1 && Last[kids] === 3 && MatchQ[at[Most[kids]], _XMLElement] :=
  Module[{is = elementIndices[at[kids]], next = ConstantArray[0, Length[at[kids]]]},
    next[[Most[is]]] = Rest[is];
    {is, next}];
siblingsOf[_] := {};

laterSiblings[p_] :=
  Replace[siblingsAt[Most[p]],
    {{is_, _} :> (Append[Most[p], #] & /@ Select[is, # > Last[p] &]), _ -> {}}];

(* Adjacent extends the tuples ending in one list of siblings together. *)
nextSiblings[tuples_, s_] :=
  With[{kids = Most[Last[First[tuples]]]},
    Replace[siblingsAt[kids],
      {{_, next_} :> pairedNext[tuples, kids, next[[Last /@ Last /@ tuples]], s], _ -> {}}]];

pairedNext[tuples_, kids_, is_, s_] :=
  With[{sites = Append[kids, #] & /@ DeleteCases[is, 0]},
    Pick[MapThread[Append, {Pick[tuples, Unitize[is], 1], sites}], selects[sites, s]]];

(* Sibling[before, after] matches an element with SOME earlier sibling matching
   before together with it, the whole chain's names and Condition included, and
   gives that element once. So a tuple ending at an after site defers its before
   stage: it holds before[g, k], the choices of group g earlier than the sibling
   at index k, and a runOf mark for each further stage a choice fixes. A choice
   fixes the stages back to the start of its run of Adjacent and Sibling links,
   as they are its siblings; the stages before the run relate to the list, not
   to the sibling, and group the choices. Adjacent needs no choice: an element
   has one previous sibling. The root has no siblings: only a first stage can
   be the root, and a sibling link drops it. *)
extend[tuples_, link : {Adjacent | Sibling, _, _}] /; MemberQ[tuples, {{}}] :=
  extend[DeleteCases[tuples, {{}}], link];
extend[tuples_, {Adjacent, s_, _}] :=
  Join @@ (nextSiblings[#, s] & /@ GatherBy[tuples, Most @* Last]);
extend[tuples_, {Sibling, s_, run_}] :=
  Join @@ (laterThanChoices[#, s, run] & /@ GatherBy[tuples, {Take[#, run - 1], Most[Last[#]]} &]);
extend[tuples_, {Descendant, s_, _}] /; $stagesDecide := related[Descendant, outermost[tuples], s];
extend[tuples_, {r_, s_, _}] := related[r, tuples, s];

related[r_, tuples_, s_] := Join @@ (Function[t, Append[t, #] & /@ selected[r, Last[t], s]] /@ tuples);

(* Descendant[ancestor, desc] gives each element once, as querySelectorAll and
   soupsieve's select do. When the stages' own matches decide, any ancestor
   will do, and the first in document order, the outermost, is taken: a name
   bound at the ancestor stage, as in a rule body, sees the outermost ancestor.
   So a site below another tuple's last site is dropped, its descendants being
   the other's too; the subtrees searched are then disjoint. When the stages
   decide, a site is the last of at most one tuple after every link, so the
   dropped tuples are the only duplicates. *)
outermost[tuples_] :=
  Module[{cover = None},
    Select[tuples[[documentOrdering[Last /@ tuples]]],
      Function[t, If[cover =!= None && Take[Last[t], UpTo[Length[cover]]] === cover,
        False, cover = Last[t]; True]]]];

(* Document order, as querySelectorAll gives elements: lexicographic, with a
   position before every position below it, so an element comes before the
   elements nested in it and after an earlier sibling's. Ties keep their
   order. *)
documentOrdering[{}] := {};
documentOrdering[ps_] :=
  Ordering @ Join[PadRight[ps, {Length[ps], Max[Length /@ ps]}, 0], List /@ Range[Length[ps]], 2];

(* The choices are a group's tuples from the run on, in document order of their
   last site; s selects the sites after the first. When the stages' own matches
   decide the match, the first choice is the one taken, and taken at once. *)
laterThanChoices[tuples_, s_, run_] :=
  With[{sorted = tuples[[Ordering[Last /@ Last /@ tuples]]]},
    With[{sites = selected[Sibling, Last[First[sorted]], s]},
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
   XMLCases gives its elements. The first stage's sites include the root, which
   a bare XMLElement tree makes an element; only a first stage can be the
   root, as every later one is below or beside an earlier one, so the root is
   never a result, as it is never one of a base XMLCases. *)
siteTuples[chain_, test_] :=
  With[{links = chain[[2 ;; ;; 2]]},
    Block[{$siblings = <||>, $choices = <||>, $stagesDecide = test === None},
      If[$stagesDecide, Identity, firstPerSite[#, test] &] @ byLastSite @ Fold[extend,
        List /@ Position[$chainTree, First[chain], {0, Infinity}, Heads -> False],
        Transpose[{links, chain[[3 ;; ;; 2]], runStarts[links]}]]]];

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
matchedSites[q_] :=
  siteTuples[chainOf[q], If[stagesDecideQ[q], None, MatchQ[solvable[tuplePattern[q]]] @* atAll]];

stagesDecideQ[q_] :=
  q["Conditions"] === {} && DuplicateFreeQ[Join @@ (namesIn /@ q["Stages"])];

(* A Condition in the body can reject a tuple. *)
bodyRejectsQ[q_] := bodyConditionQ[q["Body"]];

namesIn[s_] :=
  DeleteDuplicates @ Cases[s, Verbatim[Pattern][n_Symbol, _] :> Hold[n], {0, Infinity}, Heads -> True];

(* The plain form picks the last element of a matching tuple rather than binding
   the tuple: a rule's right-hand side re-evaluates what it is given, and a
   tuple may hold a large element. *)
chainCases[tree_, q_] /; bodyRejectsQ[q] := Block[{$chainTree = tree}, ruleValues[q]];
chainCases[tree_, q_] /; q["Body"] =!= None :=
  Block[{$chainTree = tree}, Cases[elementsAt @ matchedSites[q], tupleRule[q], {1}]];
chainCases[tree_, q_] :=
  Block[{$chainTree = tree}, atAll[Last /@ matchedSites[q]]];

chainFirst[tree_, q_, default_] /; bodyRejectsQ[q] :=
  Block[{$chainTree = tree}, Replace[ruleValues[q], {{v_, ___} :> v, {} -> default}]];
chainFirst[tree_, q_, default_] /; q["Body"] =!= None :=
  Block[{$chainTree = tree},
    FirstCase[elementsAt @ matchedSites[q], tupleRule[q], default, {1}]];
chainFirst[tree_, q_, default_] :=
  Block[{$chainTree = tree},
    Replace[matchedSites[q], {{t_, ___} :> at[Last[t]], {} -> default}]];

(* A Condition in a rule's body can reject a tuple, so it takes part in
   choosing one, as a Condition on the combinator does: as Cases gives the
   places where a rule gives a value, a tuple is accepted when the rule gives
   it one. The value is kept, so the body is not evaluated again once the tuple
   is chosen. *)
ruleValues[q_] :=
  Module[{rule = tupleRule[q], values = <||>, tuples},
    tuples = siteTuples[chainOf[q],
      Function[t, With[{v = Replace[atAll[t], {rule, _ :> $unmatched}]},
        v =!= $unmatched && (values[t] = v; True)]]];
    Lookup[values, Key /@ tuples]];

(* A chain deletes the elements its last stage selects. Delete removes
   positions nested in one another together. *)
chainDelete[tree_, q_] :=
  Block[{$chainTree = tree},
    deleteAt[tree, DeleteDuplicates[Last /@ matchedSites[q]]]];

deleteAt[tree_, {}] := tree;
deleteAt[tree_, ps_] := Delete[tree, ps];

(* =========================================================== *)
(* XMLCases                                                     *)
(* =========================================================== *)

Options[XMLCases] = {"AttributeReadings" -> <||>};

XMLCases[tree_, q_, opts : OptionsPattern[]] :=
  queryCases[compileQuery[q, XMLCases, OptionValue["AttributeReadings"]], tree];

(* Base: a pattern, a Condition, or a rule over either, in document order. Cases
   and Position visit an element after the elements nested in it, so the
   positions of the matches are put in document order; a rule is then applied
   to the matched elements in that order, its body evaluated once for each. *)
casesC[tree_, r : Verbatim[RuleDelayed][lhs_, _]] := Cases[matchesInOrder[tree, lhs], r, {1}];
casesC[tree_, pat_] := matchesInOrder[tree, pat];

(* The elements of tree, below its root, that match pat, in document order.
   Extract reads {} as the whole tree, not as no positions. *)
matchesInOrder[tree_, pat_] :=
  Replace[Position[tree, pat, Infinity, Heads -> False], {
    {} -> {},
    ps_ :> Extract[tree, fromCasesOrder[ps]]}];

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

(* =========================================================== *)
(* XMLFirstCase                                                 *)
(* The first of what XMLCases gives; the base form short-      *)
(* circuits. Default (3rd arg) returned when nothing found.     *)
(* =========================================================== *)

Options[XMLFirstCase] = {"AttributeReadings" -> <||>};

(* Only a rule naming an option is read as one: any other default, a rule
   included, stays the default. *)
optionRuleQ[f_][(Rule | RuleDelayed)[name_, _]] :=
  MemberQ[Keys[Options[f]], ToString[name]];
optionRuleQ[_][_] := False;

XMLFirstCase[tree_, q_, default : Except[_?(optionRuleQ[XMLFirstCase])] : Missing["NotFound"],
    opts : OptionsPattern[]] :=
  queryFirst[compileQuery[q, XMLFirstCase, OptionValue["AttributeReadings"]], tree, default];

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

(* FirstPosition stops at the first match Cases would visit, which is visited
   after the elements nested in it. The first match in document order is that
   one or an element it is nested in: any other earlier in document order would
   have been visited earlier. So it is the outermost match on the way down to
   the one FirstPosition finds. *)
firstMatchPosition[tree_, pat_] :=
  Replace[FirstPosition[tree, pat, None, Infinity, Heads -> False],
    p_List :> SelectFirst[Take[p, #] & /@ Range[Length[p]], MatchQ[Extract[tree, #], pat] &]];

(* =========================================================== *)
(* XMLDeleteCases                                               *)
(* Base: native DeleteCases with Infinity levelspec.            *)
(* Combinators: the chain's last-stage elements are deleted.    *)
(* =========================================================== *)

Options[XMLDeleteCases] = {"AttributeReadings" -> <||>};

XMLDeleteCases[tree_, q_, opts : OptionsPattern[]] :=
  queryDelete[compileQuery[q, XMLDeleteCases, OptionValue["AttributeReadings"]], tree];

(* Base: a pattern or a Condition *)
deleteC[tree_, pat_] := DeleteCases[tree, pat, Infinity];

(* =========================================================== *)
(* XMLMatchQ (ADR 0013)                                         *)
(* A whole-element test, as StringMatchQ is a whole-string one. *)
(* =========================================================== *)

Options[XMLMatchQ] = {"AttributeReadings" -> <||>};

(* An option rule is never a pattern, so XMLMatchQ[pattern, opts] is the operator form. *)
XMLMatchQ[q_, opts : Longest[__?(optionRuleQ[XMLMatchQ])]][el_] :=
  matchWith[cachedMatcher[q, OptionValue[XMLMatchQ, {opts}, "AttributeReadings"]], el];
XMLMatchQ[q_][el_] := matchWith[cachedMatcher[q, <||>], el];

XMLMatchQ[el_, q : Except[_?(optionRuleQ[XMLMatchQ])], opts : OptionsPattern[]] :=
  matchWith[matcherOf[q, OptionValue["AttributeReadings"]], el];

matchWith[$Failed, _] := $Failed;
matchWith[m_, el_] := m[el];

matcherOf[q_, opt_] := elementMatcher[compileQuery[q, XMLMatchQ, opt]];

(* The operator form stays unevaluated, as MatchQ[pattern] does, and is applied
   to each element in turn, so its matcher is kept, keyed on everything the
   compiled query depends on: the pattern, the value of the "AttributeReadings"
   option, and $AttributeReadings (issue #2). A refused pattern is not kept: it
   gives its message on each call, as the two-argument form does. The cache is
   emptied when it is full. *)
$matcherCache = <||>;
$matcherCacheSize = 256;

cachedMatcher[q_, opt_] :=
  With[{key = {q, opt, $AttributeReadings}},
    Lookup[$matcherCache, Key[key],
      With[{m = matcherOf[q, opt]},
        If[m =!= $Failed,
          If[Length[$matcherCache] >= $matcherCacheSize, $matcherCache = <||>];
          $matcherCache[key] = m];
        m]]];

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
   pattern: a rule is tried against one element at a time. compileRule gives
   {rule, readings}, the readings being those of the list keys it names, or
   $Failed for an entry that is refused, a non-rule among them. *)
compileRule[Verbatim[Rule][lhs_, r_], head_, readings_] :=
  Replace[elementQuery[compileWith[sugarRoleLHS[lhs], head, readings], lhs, head, "badpat"],
    c_Association :> {plainQuery[c] -> r, c["Readings"]}];
compileRule[rule_RuleDelayed, head_, readings_] :=
  Replace[
    elementQuery[
      compileWith[RuleDelayed @@ Join[Hold @@ {sugarRoleLHS[rule[[1]]]}, Extract[rule, {2}, Hold]], head, readings],
      rule[[1]], head, "badpat"],
    c_Association :> {plainQuery[c], c["Readings"]}];
compileRule[x_, head_, _] := With[{h = head}, Message[MessageName[h, "notrule"], x]; $Failed];

(* ruleLookups[{rules1, rules2, ...}, head, opt, tree]: for each rule set, a
   function from an element of tree to the value of the first rule that matches
   it, or noRule; $Failed if any set is refused. The readings table is resolved
   once for them all. A rule naming a list key is matched on the element with
   its token lists attached, each distinct raw value on the tree split once;
   the element itself is never changed, so a caller walks the tree as it is. *)
ruleLookups[sets_List, head_, opt_, tree_] :=
  With[{readings = readingsWith[opt]},
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
Options[HTMLInnerText] = {"Roles" -> {}, "BlockSeparator" -> "\n", "AttributeReadings" -> <||>};

HTMLInnerText[XMLObject["Document"][_, root_, _], opts : OptionsPattern[]] :=
  HTMLInnerText[root, opts];

HTMLInnerText[tree_, opts : OptionsPattern[]] :=
  Replace[ruleLookups[{OptionValue["Roles"]}, HTMLInnerText, OptionValue["AttributeReadings"], tree], {
    $Failed -> $Failed,
    {roles_} :> itSerialize[Flatten[itToks[tree, False, roles]], OptionValue["BlockSeparator"]]}
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
   function, applied to the matched element (the universal escape hatch) as it
   is in the tree: the element is stripped of any materialised token lists. *)
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
  With[{r = Replace[ctx["constructs"][el], noRule :> Replace[el, $defaultConstructRules]]},
    If[MatchQ[r, _XMLElement], None, r]];

(* ---- Inline emission: node -> list of box atoms (strings + boxes) ---- *)

boxRow[{}] := "";
boxRow[{x_}] := x;
boxRow[xs_List] := RowBox[xs];

(* Collapse whitespace across atom boundaries, as HTMLInnerText does: a string's
   leading spaces go when the atom before it ends in a space or is a line break
   ("\n"), and the spaces before a line break go. Empty strings are dropped. *)
joinSpaces[a_List] := Fold[joinAtom, {}, a];
joinAtom[acc_, ""] := acc;
joinAtom[{}, x_] := {x};
joinAtom[acc_, "\n"] :=
  Append[DeleteCases[MapAt[stripSpaces[#, " " .. ~~ EndOfString] &, acc, -1], "", {1}], "\n"];
joinAtom[acc_, s_String] /; spaceEndQ[Last[acc]] :=
  DeleteCases[Append[acc, stripSpaces[s, StartOfString ~~ " " ..]], "", {1}];
joinAtom[acc_, x_] := Append[acc, x];

spaceEndQ[s_String] := StringEndsQ[s, " " | "\n"];
spaceEndQ[_] := False;
stripSpaces[s_String, p_] := StringDelete[s, p];
stripSpaces[x_, _] := x;

(* Split a joined atom list into its leading edge, core and trailing edge. An
   edge is the whitespace-only strings (spaces, line breaks) at that end, plus
   the spaces at that end of the outermost string of the core. *)
blankQ[s_String] := StringMatchQ[s, Whitespace ..];
blankQ[_] := False;
splitEdges[a_List] :=
  With[{i = LengthWhile[a, blankQ]},
    If[i === Length[a], {a, {}, {}},
      With[{j = LengthWhile[Reverse[a], blankQ]},
        peelSpaces[Take[a, i], a[[i + 1 ;; -j - 1]], Take[a, -j]]]]];
peelSpaces[lead_, core_, trail_] :=
  With[{l = edgeSpace[First[core], StartOfString ~~ " " ..],
        t = edgeSpace[Last[core], " " .. ~~ EndOfString]},
    {Join[lead, l],
     MapAt[stripSpaces[#, " " .. ~~ EndOfString] &,
       MapAt[stripSpaces[#, StartOfString ~~ " " ..] &, core, 1], -1],
     Join[t, trail]}];
(* {" "} when a string has spaces where p looks for them, else {} *)
edgeSpace[s_String, p_] := If[StringContainsQ[s, p], {" "}, {}];
edgeSpace[_, _] := {};

(* The core of an inline run: boundary whitespace collapsed, edges trimmed. *)
trimAtoms[a_List] := splitEdges[joinSpaces[a]][[2]];

(* Does an atom list carry real content (a box, or non-blank text)? *)
realQ[a_List] := AnyTrue[a, (! StringQ[#] || StringTrim[#] =!= "") &];

styleBox["Bold", inner_] := StyleBox[boxRow[inner], FontWeight -> Bold];
styleBox["Italic", inner_] := StyleBox[boxRow[inner], FontSlant -> Italic];
styleBox["Underline", inner_] :=
  StyleBox[boxRow[inner], FontVariations -> {"Underline" -> True}];
styleBox["StrikeThrough", inner_] :=
  StyleBox[boxRow[inner], FontVariations -> {"StrikeThrough" -> True}];
styleBox["Code", inner_] := inlineCell@FrameBox[StyleBox[boxRow[inner], "Code"]];

(* An inline atom that is boxes, not text, goes into TextData as an inline
   Cell[BoxData[...]]; placed bare, the front end shows it as its box text. A
   string, a Cell, a ButtonBox or a StyleBox of text is text already. *)
textAtomQ[_String | _Cell | _ButtonBox] := True;
textAtomQ[StyleBox[x_, ___]] := textAtomQ[x];
textAtomQ[RowBox[xs_List]] := AllTrue[xs, textAtomQ];
textAtomQ[_] := False;
inlineCell[b_] := If[textAtomQ[b], b, Cell[BoxData[b]]];

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
    functionConstructQ[c], inlineCell /@ Flatten[{c[el]}],
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
    _,           edgedForm[constructOf[el, ctx], el,
                   splitEdges[joinSpaces@Flatten[inlineBoxes[#, ctx] & /@ ch]]]];
inlineBoxes[_, _] := {};

(* An element's edge whitespace goes outside its form, so that formatting does
   not cover it and it can collapse with its neighbours'. *)
edgedForm[c_, el_, {lead_, core_, trail_}] := Join[lead, inlineForm[c, el, core], trail];

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

Options[HTMLToNotebook] = {"Roles" -> {}, "Constructs" -> {}, "AttributeReadings" -> <||>};

HTMLToNotebook[XMLObject["Document"][_, root_, _], opts : OptionsPattern[]] :=
  HTMLToNotebook[root, opts];

HTMLToNotebook[tree_, opts : OptionsPattern[]] :=
  Replace[
    ruleLookups[{OptionValue["Roles"], OptionValue["Constructs"]}, HTMLToNotebook, OptionValue["AttributeReadings"], tree], {
    $Failed -> $Failed,
    {roles_, cons_} :> Notebook[blockEmit[toChildList[tree], initCtx[roles, cons]]]}
  ] /; validTextInputQ[tree];

HTMLToNotebook[tree_, OptionsPattern[]] :=
  (Message[HTMLToNotebook::badtree, Head[tree]]; $Failed) /; !validTextInputQ[tree];

End[];
EndPackage[];
