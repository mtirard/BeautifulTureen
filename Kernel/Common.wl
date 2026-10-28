(* ::Package:: *)
(* HTMLPatterns: validation helpers, the inert public symbols the query
   compiler gives meaning to, HTMLWhitespace, HTMLClassList, CSSClass,
   and argument counts and options *)

(* Used by CSSSelector.wl *)
PackageScoped[argumentCountMessage]

(* Used by Notebook.wl, Query/Run.wl, Text.wl and Tree.wl *)
PackageScoped[messageTreeRefusal]

(* Used by Notebook.wl, Text.wl, Tree.wl and XMLFunctions.wl *)
PackageScoped[countMessage]

(* Used by Notebook.wl and Text.wl *)
PackageScoped[validTextInputQ]

(* Used by Query/Compiler.wl *)
PackageScoped[validTagQ]
PackageScoped[literalKeyQ]
PackageScoped[keyLiterals]
PackageScoped[$links]
PackageScoped[combinatorQ]
PackageScoped[barePatterns]

(* Used by Query/Compiler.wl and Query/Run.wl *)
PackageScoped[patternBase]

(* Used by Query/Run.wl and Tree.wl *)
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
XMLPattern::usage = "XMLPattern[tag] is an XML pattern that matches any XMLElement whose tag matches tag. XMLPattern[tag, attrs] also requires the element's attributes to match attrs. MatchQ and Cases treat XMLPattern as a literal expression; use it with XMLCases, XMLFirstCase, XMLDeleteCases, XMLMatchQ and the \"Roles\" and \"Constructs\" options. attrs is a \"key\" -> value rule, a bare \"key\" (any value), or a list of these, and can be named or tested as a whole. The element may have other attributes as well. A key is a string, a {namespace, name} pair, or alternatives of these. A value is any pattern, matched against the whole attribute value. The list key \"classList\" gives the element's classes as a list of strings, and \"classList\" -> \"cls\" matches an element that has the class cls. $AttributeReadings can add list keys for other attributes.";
XMLPattern::badtag = "The tag should be a string, a {namespace, name} pair, alternatives of these, or a pattern such as _. Got `1`.";
XMLPattern::nargs = "XMLPattern was given `1` arguments, but takes a tag and at most one attribute argument. Put several attribute constraints in one list: XMLPattern[tag, {c1, c2, ...}].";
XMLPattern::badattrs = "The attribute argument should be a key -> value rule, a key, or a list of these, optionally named (attrs : ...) or tested (...?test) as a whole. Got `1`.";
XMLPattern::badkey = "An attribute key should be a string, a {namespace, name} pair of strings, or alternatives of these. Got `1`. To test the keys, test the attributes as a whole: XMLPattern[tag, attrs_?test].";
XMLPattern::dupkey = "The attribute key `1` appears in more than one constraint, so the pattern can never match. Combine the constraints into one value pattern.";
XMLPattern::nolistreading = "The key `1` looks like a list key, but `2` has no reading, so `1` is matched as an attribute of that name. To match the tokens of `2`, add a reading: $AttributeReadings[`2`] = <||> for the session, or \"AttributeReadings\" -> <|`2` -> <||>|> in the call.";
XMLPattern::otherlistkey = "The key `1` is matched as an attribute of that name, but the reading for `2` gives its tokens under the list key `3`. Use `3`, or set \"ListKey\" -> `1` in the reading.";
XMLPattern::strpat = "`1` is a string pattern, and in an XMLPattern it does not match any string. Write _?(StringMatchQ[`1`]) instead.";

PackageExported[XMLDocument]
XMLDocument::usage = "XMLDocument[] is a pattern for the parent of the top-level elements of a tree, used as the first stage of a Child or Descendant combinator in XMLCases, XMLFirstCase and XMLDeleteCases. Child[XMLDocument[], pattern] gives the top-level elements that match pattern: the root element of an XMLObject, or the elements of a list. On a bare XMLElement, XMLDocument[] is a parent above it, so Child[XMLDocument[], XMLPattern[_], pattern] gives the children of the element that match pattern. Descendant[XMLDocument[], pattern] gives every element that matches pattern, as pattern alone does. In a list stage, Child[XMLDocument[] | XMLPattern[_], {...}] counts the top-level elements as the children of the document, so Child[XMLDocument[] | XMLPattern[_], {XMLPattern[\"html\"], ___}] matches the root element of a document. XMLDocument[] takes no arguments, and cannot be named, have a condition or test of its own, or be a later stage. The tree given is never a result.";
XMLDocument::place = "XMLDocument[] takes no arguments and stands for the document above the top elements, so it can only be the first stage of a combinator, alone or in alternatives, as in Child[XMLDocument[], XMLPattern[\"html\"]], and it cannot be named or have a condition or test. Got `1`.";

(* A literal attribute key: a plain name, an imported {namespace, name} pair (WL
   imports a namespaced attribute such as xlink:href with a two-element list key
   {namespaceURI, localName}), or Alternatives of those. *)
literalKeyQ[_String] := True;
literalKeyQ[{_String, _String}] := True;
literalKeyQ[Verbatim[Alternatives][ks__]] := AllTrue[{ks}, literalKeyQ];
literalKeyQ[_] := False;

keyLiterals[Verbatim[Alternatives][ks__]] := Join @@ (keyLiterals /@ {ks});
keyLiterals[k_] := {k};

(* The four combinator heads, each a link of a chain. *)
$links = Child | Descendant | Adjacent | Sibling;

PackageExported[Child]
Child::usage = "Child[parentPat, childPat] is a combinator for XMLCases, XMLFirstCase and XMLDeleteCases that matches elements that match childPat and are direct children of an element that matches parentPat. Child[parentPat, {e1, e2, ...}] matches the list of patterns {e1, e2, ...} against the element children of each element that matches parentPat, leaving out text, and selects the child in the place of the last entry that is an XML pattern: Child[XMLPattern[_], {XMLPattern[\"li\"], ___}] matches each li that is the first element child of its parent, and Child[XMLPattern[_], {PatternSequence[_, _] ..., XMLPattern[\"tr\"], ___}] the odd rows. The other entries are patterns such as _, ___, Repeated, Except and PatternSequence over the children. Names in the list are bound as in a WL list pattern, where the first way the list matches binds them, and a name on the list, s : {...}, binds the List of element children. Child[pat1, pat2, pat3, ...] is Child[pat1, Child[pat2, pat3, ...]], so Child[a, b, c] matches each c that is a child of a b that is a child of an a. Each argument is a stage: an XMLPattern, another combinator, a CSS selector string, or alternatives of these. The first argument can also be XMLDocument[], the parent of the top-level elements of the tree, or alternatives that hold it. After Child or Descendant, a stage can also be a list of patterns for the parent's element children. A stage that is alternatives holding a combinator is each of them in turn, so Child[a, Descendant[b, c] | d] matches each c inside a b that is a child of an a, and each d that is a child of an a. Stages chain left to right, as in a CSS selector, so Descendant[a, Child[b, c]] and Child[Descendant[a, b], c] select the same elements. A condition on a stage can use the names bound in that stage. A condition on the whole combinator can use the names bound in all its stages.";

PackageExported[Descendant]
Descendant::usage = "Descendant[ancestorPat, descPat] is a combinator for XMLCases, XMLFirstCase and XMLDeleteCases that matches elements that match descPat and are nested at any depth inside an element that matches ancestorPat. Descendant[ancestorPat, {e1, e2, ...}] matches the list of patterns {e1, e2, ...} against the element children of each element that matches ancestorPat or lies inside one, one parent at a time, as Child does, so Descendant[XMLPattern[\"div\"], {XMLPattern[\"p\"], ___}] matches each p inside a div that is the first element child of its parent. Each such element is given once, however many of its ancestors match. A name bound in ancestorPat, as used in a rule body, gives the outermost matching ancestor. Descendant[pat1, pat2, pat3, ...] is Descendant[pat1, Descendant[pat2, pat3, ...]], so Descendant[a, b, c] matches each c inside a b inside an a. Each argument is a stage: an XMLPattern, another combinator, a CSS selector string, or alternatives of these. The first argument can also be XMLDocument[], the parent of the top-level elements of the tree, or alternatives that hold it. After Child or Descendant, a stage can also be a list of patterns for the parent's element children. A stage that is alternatives holding a combinator is each of them in turn, so Child[a, Descendant[b, c] | d] matches each c inside a b that is a child of an a, and each d that is a child of an a. Stages chain left to right, as in a CSS selector, so Descendant[a, Child[b, c]] and Child[Descendant[a, b], c] select the same elements. A condition on a stage can use the names bound in that stage. A condition on the whole combinator can use the names bound in all its stages.";

PackageExported[Adjacent]
Adjacent::usage = "Adjacent[beforePat, afterPat] is a combinator for XMLCases, XMLFirstCase and XMLDeleteCases that matches elements that match afterPat and immediately follow a sibling that matches beforePat. Only elements count as siblings, not text. Adjacent[beforePat, afterPat] gives the same as Child[XMLDocument[] | XMLPattern[_], {___, beforePat, afterPat, ___}], so the top-level elements of a list are siblings. Adjacent[pat1, pat2, pat3, ...] is Adjacent[pat1, Adjacent[pat2, pat3, ...]], so Adjacent[a, b, c] matches each c that immediately follows a b that immediately follows an a. Each argument is a stage: an XMLPattern, another combinator, a CSS selector string, or alternatives of these. The first argument can also be XMLDocument[], the parent of the top-level elements of the tree, or alternatives that hold it. After Child or Descendant, a stage can also be a list of patterns for the parent's element children. A stage that is alternatives holding a combinator is each of them in turn, so Child[a, Descendant[b, c] | d] matches each c inside a b that is a child of an a, and each d that is a child of an a. Stages chain left to right, as in a CSS selector, so Descendant[a, Child[b, c]] and Child[Descendant[a, b], c] select the same elements. A condition on a stage can use the names bound in that stage. A condition on the whole combinator can use the names bound in all its stages.";

PackageExported[Sibling]
Sibling::usage = "Sibling[beforePat, afterPat] is a combinator for XMLCases, XMLFirstCase and XMLDeleteCases that matches elements that match afterPat and follow a sibling that matches beforePat, at any distance. Only elements count as siblings, not text. Each such element is given once. Sibling[beforePat, afterPat] gives the same as Child[XMLDocument[] | XMLPattern[_], {___, beforePat, ___, afterPat, ___}], so the top-level elements of a list are siblings. A name bound in beforePat, as used in a rule body, gives the first matching earlier sibling in document order. Sibling[pat1, pat2, pat3, ...] is Sibling[pat1, Sibling[pat2, pat3, ...]], so Sibling[a, b, c] matches each c that follows a b that follows an a. Each argument is a stage: an XMLPattern, another combinator, a CSS selector string, or alternatives of these. The first argument can also be XMLDocument[], the parent of the top-level elements of the tree, or alternatives that hold it. After Child or Descendant, a stage can also be a list of patterns for the parent's element children. A stage that is alternatives holding a combinator is each of them in turn, so Child[a, Descendant[b, c] | d] matches each c inside a b that is a child of an a, and each d that is a child of an a. Stages chain left to right, as in a CSS selector, so Descendant[a, Child[b, c]] and Child[Descendant[a, b], c] select the same elements. A condition on a stage can use the names bound in that stage. A condition on the whole combinator can use the names bound in all its stages.";

combinatorQ[$links[___]] := True;
combinatorQ[_] := False;

(* A name, a Condition or a test around a pattern never changes what it is. *)
patternBase[Verbatim[Pattern][_, x_]] := patternBase[x];
patternBase[Verbatim[Condition][x_, _]] := patternBase[x];
patternBase[Verbatim[PatternTest][x_, _]] := patternBase[x];
patternBase[x_] := x;

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
(* CSSClass                                                     *)
(* Obsolete (ADR 0011): the class list is the "classList" key.  *)
(* =========================================================== *)

PackageExported[CSSClass]
CSSClass::usage = "CSSClass is obsolete. Match an element's class list with the \"classList\" key of XMLPattern instead: XMLPattern[tag, \"classList\" -> \"cls\"].";
CSSClass::obs = "CSSClass is obsolete. Match the class list with the \"classList\" key instead: XMLPattern[tag, \"classList\" -> \"cls\"] for .cls, or \"classList\" -> _?(FreeQ[\"cls\"]) for :not(.cls).";

CSSClass[___] := (Message[CSSClass::obs]; $Failed);

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

