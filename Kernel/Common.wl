(* ::Package:: *)
(* HTMLPatterns: validation helpers, the inert public symbols the queries
   give meaning to, HTMLWhitespace, HTMLClassList, and argument counts
   and options *)

(* Used by CSSSelector.wl *)
PackageScoped[argumentCountMessage]

(* Used by Notebook.wl and Text.wl *)
PackageScoped[validTextInputQ]

(* Used by Notebook.wl, Positions.wl, Query/TreePatterns.wl, Text.wl, Tree.wl and XMLFunctions.wl *)
PackageScoped[messageTreeRefusal]

(* Used by Notebook.wl, Text.wl, Tree.wl and XMLFunctions.wl *)
PackageScoped[countMessage]

(* Used by Query/Compiler.wl *)
PackageScoped[validTagQ]
PackageScoped[barePatterns]

(* Used by Query/Compiler.wl and Query/TreePatterns.wl *)
PackageScoped[keyLiterals]
PackageScoped[literalKeyQ]

(* Used by Positions.wl, Query/TreePatterns.wl, Tree.wl and XMLFunctions.wl *)
PackageScoped[validTreeQ]

(* Used by Tree.wl *)
PackageScoped[classList]

(* Used by Tree.wl and XMLFunctions.wl *)
PackageScoped[optionRuleQ]

(* Used by XMLFunctions.wl *)
PackageScoped[optionQ]

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

PackageExported[XMLPattern]
XMLPattern::usage = "XMLPattern[tag] is an XML pattern that matches any XMLElement whose tag matches tag. XMLPattern[tag, attrs] also requires the element's attributes to match attrs. XMLPattern[tag][c1, c2, ...] and XMLPattern[tag, attrs][c1, c2, ...] also require what is below the element to meet each constraint ci: a list pattern over its element children, in which text is left out, such as {XMLPattern[\"li\"], ___}, Child[p], which an element child that matches p meets, as {___, p, ___} does, or Descendant[p], which an element anywhere below that matches p meets. Patterns are nested as the document is: XMLPattern[\"ul\"][Child[x : XMLPattern[\"li\"]]] :> x gives the li children of each ul. XMLPattern[tag, attrs][] is XMLPattern[tag, attrs]. MatchQ and Cases treat XMLPattern as a literal expression; use it with XMLCases, XMLFirstCase, XMLPosition, XMLDeleteCases, XMLReplace, XMLMatchQ, XMLFreeQ and the \"Roles\" and \"Constructs\" options. attrs is a \"key\" -> value rule, a bare \"key\" (any value), or a list of these, and can be named or tested as a whole. The element may have other attributes as well. A key is a string, a {namespace, name} pair, or alternatives of these. A value is any pattern, matched against the whole attribute value. The list key \"classList\" gives the element's classes as a list of strings, and \"classList\" -> \"cls\" matches an element that has the class cls. $AttributeReadings can add list keys for other attributes.";
XMLPattern::badtag = "The tag should be a string, a {namespace, name} pair, alternatives of these, or a pattern such as _. Got `1`.";
XMLPattern::constraint = "`1` is not a constraint. The constraints on what is below an element are the arguments of the bracket after XMLPattern[tag, attrs], as in XMLPattern[tag, attrs][c1, c2, ...]: Child[p] for some element child that matches p, a list pattern over its element children, as in {p} for an only child, or Descendant[p] for an element anywhere below. Attribute constraints go in the first bracket, several in one list: XMLPattern[tag, {a1, a2, ...}].";
XMLPattern::chain = "`1` gives constraints in more than one bracket. Several constraints are the arguments of one bracket: `2`.";
XMLPattern::bracket = "`1` gives constraints to alternatives or a test, not to an XMLPattern. Constraints go in the bracket of each XMLPattern: `2`. For a pattern from FromCSSSelector[\"selector\"], give them to the selector string instead, as in \"selector\"[c1, c2, ...].";
XMLPattern::attrsthen = "`1` gives constraints after the attributes. Constraints are the arguments of a second bracket: `2`.";
XMLPattern::listentry = "`1` cannot be an entry in a list of patterns for an element's children. `2`";
XMLPattern::badattrs = "The attribute argument should be a key -> value rule, a key, or a list of these, optionally named (attrs : ...) or tested (...?test) as a whole. Got `1`.";
XMLPattern::badkey = "An attribute key should be a string, a {namespace, name} pair of strings, or alternatives of these. Got `1`. To test the keys, test the attributes as a whole: XMLPattern[tag, attrs_?test].";
XMLPattern::dupkey = "The attribute key `1` appears in more than one constraint, so the pattern can never match. Combine the constraints into one value pattern.";
XMLPattern::nolistreading = "The key `1` looks like a list key, but `2` has no reading, so `1` is matched as an attribute of that name. To match the tokens of `2`, add a reading: $AttributeReadings[`2`] = <||> for the session, or \"AttributeReadings\" -> <|`2` -> <||>|> in the call.";
XMLPattern::otherlistkey = "The key `1` is matched as an attribute of that name, but the reading for `2` gives its tokens under the list key `3`. Use `3`, or set \"ListKey\" -> `1` in the reading.";
XMLPattern::strpat = "`1` is a string pattern, and in an XMLPattern it does not match any string. Write _?(StringMatchQ[`1`]) instead.";

PackageExported[XMLDocument]
XMLDocument::usage = "XMLDocument[c1, c2, ...] is a pattern for the document above the top elements of a tree: the root element of an XMLObject, the elements of a list, or a bare XMLElement. Each ci is a constraint on what is below the document, as in the bracket of XMLPattern[tag][c1, c2, ...]: a list pattern over the top elements, Child[p] for a top element, or Descendant[p]. XMLDocument[] matches any document, and XMLDocument[{XMLPattern[\"html\"], ___}] one whose first top element is html. XMLDocument can only be a pattern root: the whole query, named, with a condition or a test, or a branch of alternatives at the top, as in XMLPattern[_][L] | XMLDocument[L], which gives L the children of any element or the top elements. The position of the document is {}. XMLMatchQ[document, XMLDocument[...]] tests an XMLObject.";
XMLDocument::place = "XMLDocument[...] matches only the document above the top elements, so it can only be a pattern root: the whole query, named, conditioned or tested, or a branch of alternatives at the top, as in XMLPattern[_][L] | XMLDocument[L]. It cannot be inside Descendant, an attribute pattern or an XMLElement pattern. Got `1`.";
XMLDocument::constraint = "`1` is not a constraint. The arguments of XMLDocument are constraints on what is below the document: Child[p] for some top element that matches p, a list pattern over the top elements, as in {p} for an only top element, or Descendant[p] for an element anywhere below.";
XMLDocument::listentry = "`1` cannot be an entry in a list of patterns for the top elements. `2`";
XMLDocument::shortest = "`1` is Shortest or Longest on a constraint that is not Descendant. Shortest and Longest apply only to a Descendant constraint, where they keep the nearest or outermost pattern root; under XMLDocument they have no effect.";
XMLPattern::shortest = "`1` is Shortest or Longest on a constraint that is not Descendant. Shortest@Descendant[p] keeps the nearest element matching the whole pattern with that match below it, and Longest@Descendant[p] the outermost; on a list constraint they have no meaning. Inside a list, as in {___, Shortest[x__], ___}, they keep WL's meaning.";

(* A literal attribute key: a plain name, an imported {namespace, name} pair (WL
   imports a namespaced attribute such as xlink:href with a two-element list key
   {namespaceURI, localName}), or Alternatives of those. *)
literalKeyQ[_String] := True;
literalKeyQ[{_String, _String}] := True;
literalKeyQ[Verbatim[Alternatives][ks__]] := AllTrue[{ks}, literalKeyQ];
literalKeyQ[_] := False;

keyLiterals[Verbatim[Alternatives][ks__]] := Join @@ (keyLiterals /@ {ks});
keyLiterals[k_] := {k};

PackageExported[Descendant]
Descendant::usage = "Descendant[p] is a constraint, an argument of XMLPattern[tag, attrs][...] or XMLDocument[...], which an element anywhere below the pattern root that matches p meets. Descendant[p, levelspec] takes only the elements at the DOM depths in levelspec below the pattern root, where its children are at depth 1: n (depths 1 to n), {n}, {m, n} or Infinity. XMLPattern[\"nav\"][Descendant[x : XMLPattern[\"a\"]]] :> x gives each link inside a nav, once. A name on the constraint, path : Descendant[p], binds the elements strictly between the pattern root and the match, outermost first. Shortest[Descendant[p]] keeps, for each match, only the nearest pattern root above it, and Longest[Descendant[p]] the outermost. Child[p] is the constraint for an element child that matches p.";

Descendant::place = "`1` is a constraint, which can only be an argument of the bracket after XMLPattern[tag, attrs] or of XMLDocument, as in XMLPattern[\"nav\"][Descendant[XMLPattern[\"a\"]]]. To find matching elements at any depth, give the pattern alone.";
Descendant::level = "`1` is not a level specification in DOM depth. Use n, {n}, {m, n} or Infinity, with every level at least 1. For an element inside an element inside another, nest the patterns: XMLPattern[a][Descendant[XMLPattern[b][Descendant[c]]]].";

PackageExported[Child]
Child::usage = "Child[p] is a constraint, an argument of XMLPattern[tag, attrs][...] or XMLDocument[...], which an element child of the pattern root that matches p meets. It is the list constraint {___, p, ___}: XMLPattern[\"ul\"][Child[x : XMLPattern[\"li\"]]] :> x gives each li child of a ul, once. Under XMLDocument, the children are the top elements. Names and tests go inside p, as in Child[x : p] and Child[p?f]. For children that match several patterns, give several constraints, XMLPattern[tag][Child[a], Child[b]], or, for children in an order, a list, {___, a, ___, b, ___}.";

Child::args = "`1` is not a constraint: Child takes one pattern. For children that match several patterns, give several constraints, as in XMLPattern[tag][Child[a], Child[b]], or, for children in an order, a list, as in XMLPattern[tag][{___, a, ___, b, ___}].";
Child::name = "`1` names a Child constraint, which has nothing to bind: between an element and its child there is no element. Name the child instead, as in Child[n : p].";
Child::test = "`1` tests a Child constraint, which has nothing to test. Test the child instead, as in Child[p?f].";
Child::place = "`1` is not a pattern. Child is a constraint, which can only be an argument of the bracket after XMLPattern[tag, attrs] or of XMLDocument: XMLPattern[\"ul\"][Child[x : XMLPattern[\"li\"]]] :> x gives the li children of each ul. In version 3, Child[a, b] gave the children that match b of the elements that match a; in version 4 that is the rule above. Child takes one pattern: for children that match several patterns, give several constraints, Child[a], Child[b], or a list, {___, a, ___, b, ___}.";

(* Valid tree for XMLCases *)
validTreeQ[XMLObject["Document"][_, _XMLElement, _]] := True;
validTreeQ[_XMLElement] := True;
validTreeQ[expr_List] := AllTrue[expr, treeMemberQ];
validTreeQ[_] := False;

(* What a list given as a tree can hold *)
treeMemberQ[_XMLElement | _String] := True;
treeMemberQ[_] := False;

(* Issues head's message for a tree refused by validTreeQ or validTextInputQ:
   badmember with a list's first refused member, otherwise badtree. A list
   given here must have been refused, so it has a member that is not one. *)
messageTreeRefusal[head_, tree_List] :=
  With[{i = LengthWhile[tree, treeMemberQ] + 1},
    Message[MessageName[head, "badmember"], i, Head[tree[[i]]]]];
messageTreeRefusal[head_, tree_] := Message[MessageName[head, "badtree"], Head[tree]];

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

PackageExported[HTMLWhitespace]
HTMLWhitespace::usage = "HTMLWhitespace is a string pattern that matches a run of one or more HTML whitespace characters: space, tab, line feed, form feed and carriage return. Use StringSplit[value, HTMLWhitespace] to split a class attribute as a browser does. HTMLWhitespace does not match no-break space or other Unicode whitespace, which StringSplit splits on by default.";

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

PackageExported[HTMLClassList]
HTMLClassList::usage = "HTMLClassList[element] gives the classes of an XMLElement as a list of strings: its class attribute split on HTMLWhitespace, in the order written and with duplicates kept. An element with no class attribute, or with a class attribute that is empty or only whitespace, gives {}. HTMLClassList takes a single element; for many elements, use HTMLClassList /@ XMLCases[tree, pattern].";
HTMLClassList::notelement = "The argument should be a single XMLElement. Got head `1`. For a list of elements, use HTMLClassList /@ elements.";

HTMLClassList[XMLElement[_, attrs_List, _]] := classList[classValue[attrs]];

(* A list, a document or a bare string is refused, not interpreted: a list is a
   forest elsewhere in the paclet (one answer), where concatenated class lists
   mean nothing, and a bare string is a text node, not an attribute value. *)
HTMLClassList[other_] :=
  (Message[HTMLClassList::notelement, Head[other]]; $Failed);

HTMLClassList[args___] /; (countMessage[HTMLClassList, {args}, {1, 1}]; False) := Null;

(* =========================================================== *)
(* Argument counts and options                                  *)
(* =========================================================== *)

(* Only a rule naming an option of f is read as one: any other rule, such as
   XMLFirstCase's default, is an argument. *)
optionRuleQ[f_][(Rule | RuleDelayed)[name_, _]] :=
  MemberQ[Keys[Options[f]], ToString[name]] || passedOptionQ[f, name];
optionRuleQ[_][_] := False;

(* HTMLToTree also takes Tree's options, which it passes on to Tree *)
passedOptionQ[HTMLToTree, name_] := treeOptionNameQ[name];
passedOptionQ[_, _] := False;

optionQ[f_][a_] := MatchQ[a, _?(optionRuleQ[f]) | {__?(optionRuleQ[f])}];

(* Each public function ends with
   f[args___] /; (countMessage[f, {args}, {min, max}]; False) := Null,
   for a call that no other definition takes. countMessage gives the message a
   built-in gives when the number of positional arguments is outside
   {min, max} (argx, argrx or argt), and the condition fails either way, so the
   call stays unevaluated, as a built-in's does. The options of f at the end of
   args are not counted, but the first min arguments are always positional, so
   a query pattern -> rhs is never read as an option.
   A one-argument call gives no message: for XMLMatchQ it is the operator form,
   and for XMLCases, XMLFirstCase and XMLDeleteCases it has the shape of an
   operator form, as Cases[pattern] has, which they may get. *)
countMessage[_, {_}, _] := Null;
countMessage[f_, args_List, spec : {min_, max_}] :=
  With[{
      optionCount = LengthWhile[Reverse[args], optionQ[f]],
      alwaysPositional = Min[min, Length[args]]},
    With[{n = Max[alwaysPositional, Length[args] - optionCount]},
      If[n < min || n > max, argumentCountMessage[f, n, spec]]]];

argumentCountMessage[f_, n_, {1, 1}] := Message[MessageName[f, "argx"], f, n];
argumentCountMessage[f_, n_, {m_, m_}] := Message[MessageName[f, "argrx"], f, n, m];
argumentCountMessage[f_, n_, {min_, max_}] := Message[MessageName[f, "argt"], f, n, min, max];

