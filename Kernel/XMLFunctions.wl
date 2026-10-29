(* ::Package:: *)
(* HTMLPatterns: XMLCases, XMLFirstCase, XMLDeleteCases, XMLMatchQ and XMLFreeQ *)

(* Used by Tree.wl *)
PackageScoped[countQ]

(* =========================================================== *)
(* XMLCases                                                     *)
(* =========================================================== *)

PackageExported[XMLCases]
XMLCases::usage = "XMLCases[tree, pattern] gives a list of the elements of tree, at any depth, that match pattern, in document order: an element comes before the elements nested in it, and an earlier sibling before a later one. A bare XMLElement given as tree is never itself included. pattern can be an XMLPattern, which can take constraints on the elements below it, as in XMLPattern[\"ul\"][{___, XMLPattern[\"li\"], ___}], an XMLElement pattern, which matches as written, an XMLDocument pattern, or a CSS selector string, or alternatives of these, any of them named, with a condition pat /; test or a test pat?f. A CSS selector string, such as \"nav a\", gives the elements it selects. XMLCases[tree, pattern :> rhs] gives the value of rhs once for each distinct combination of the positions of the names that rhs uses, outside its conditions: XMLCases[tree, XMLPattern[\"nav\"][Descendant[x : XMLPattern[\"a\"]]] :> x] gives each link inside a nav once, however many navs it is inside. A name that rhs does not use is a test, which needs one match, and an rhs that uses no name gives at most one result. The results are in document order of the first name used, then of the next. A CSS selector that looks above or beside its element is named on the left of a rule, as in n : \"nav a\" :> n. XMLCases[tree, pattern -> rhs] evaluates rhs once, before any matching, as Cases does. XMLCases[tree, pattern, n] gives the first n results, or all of them if there are fewer; n is a non-negative integer or Infinity. A name for an element gives the element as it appears in tree, without list keys such as \"classList\". XMLCases[tree, pattern, \"AttributeReadings\" -> readings] adds readings to $AttributeReadings for this call.";

Options[XMLCases] = {"AttributeReadings" -> <||>};

(* The count n is a ceiling, as in StringCases (ADR 0019). A third argument
   that is not an option is a count, and one that is not valid gives innf.
   Every query is a tree pattern (Query/TreePatterns.wl). *)
XMLCases[tree_, q_, n : Except[_?(optionQ[XMLCases])] : Infinity, opts : OptionsPattern[]] /; countQ[n] :=
  withReadings[OptionValue["AttributeReadings"], treeCases[XMLCases, tree, q, n]];

XMLCases[tree_, q_, n : Except[_?(optionQ[XMLCases])], opts : OptionsPattern[]] /;
    (Message[XMLCases::innf, Unevaluated[XMLCases[tree, q, n, opts]], 3]; False) := Null;

XMLCases[args___] /; (countMessage[XMLCases, {args}, {2, 3}]; False) := Null;

countQ[n_] := MatchQ[n, Infinity | _Integer?NonNegative];

(* =========================================================== *)
(* XMLFirstCase                                                 *)
(* The first of what XMLCases gives; the base form short-      *)
(* circuits. Default (3rd arg) returned when nothing found.     *)
(* =========================================================== *)

PackageExported[XMLFirstCase]
XMLFirstCase::usage = "XMLFirstCase[tree, pattern] gives the first element of tree that matches pattern, in document order, or Missing[\"NotFound\"] if there is none. Of nested matches, it gives the outermost. XMLFirstCase[tree, pattern, default] gives default if there is no match. XMLFirstCase accepts the same patterns and rules as XMLCases, including a CSS selector string, and gives the first result that XMLCases gives. With pattern :> rhs, rhs is evaluated only for the result that XMLFirstCase returns. With pattern -> rhs, rhs is evaluated once, before any matching, as in FirstCase, and the names in pattern are replaced in its value by what they matched. The \"AttributeReadings\" option adds readings to $AttributeReadings, as in XMLCases.";

Options[XMLFirstCase] = {"AttributeReadings" -> <||>};

XMLFirstCase[tree_, q_, default : Except[_?(optionRuleQ[XMLFirstCase])] : Missing["NotFound"],
    opts : OptionsPattern[]] :=
  withReadings[OptionValue["AttributeReadings"],
    Replace[treeResults[XMLFirstCase, tree, q, 1], {{r_} :> Sequence @@ r, {} :> default}]];

XMLFirstCase[args___] /; (countMessage[XMLFirstCase, {args}, {2, 3}]; False) := Null;

(* =========================================================== *)
(* XMLDeleteCases                                               *)
(* The positions of the counted names deleted (Rewrite.wl).     *)
(* =========================================================== *)

PackageExported[XMLDeleteCases]
XMLDeleteCases::usage = "XMLDeleteCases[tree, pattern] gives tree with every element that matches pattern removed, at any depth. XMLDeleteCases[tree, pattern :> x] removes what the name x matches, for every result of pattern, and pattern :> {x, y, ...} what each of the names matches: an element, a run of element children, an attribute, the attribute list, a token of a list key such as \"classList\", or the contents of an element. pattern can be any pattern that XMLCases takes, so XMLDeleteCases[tree, XMLPattern[\"ul\"][{x : XMLPattern[\"li\"], ___}] :> x] removes the first li of each list and no other. The root element of an XMLObject is never removed: XMLDeleteCases issues a message and removes the other targets. The \"AttributeReadings\" option adds readings to $AttributeReadings, as in XMLCases.";
XMLDeleteCases::root = "The root element of an XMLObject cannot be deleted; it was kept.";

Options[XMLDeleteCases] = {"AttributeReadings" -> <||>};

XMLDeleteCases[tree_, q_, opts : OptionsPattern[]] :=
  withReadings[OptionValue["AttributeReadings"], treeDelete[tree, q]];

XMLDeleteCases[args___] /; (countMessage[XMLDeleteCases, {args}, {2, 2}]; False) := Null;

(* =========================================================== *)
(* XMLMatchQ (ADR 0013)                                         *)
(* A whole-element test, as StringMatchQ is a whole-string one. *)
(* =========================================================== *)

PackageExported[XMLMatchQ]
XMLMatchQ::usage = "XMLMatchQ[element, pattern] gives True if element matches pattern, and False otherwise. XMLMatchQ[pattern] is an operator form. pattern can be an XMLPattern, with constraints on what is below the element, an XMLElement pattern, or a CSS selector string that describes one element, such as \"a.external\", or alternatives of these, any of them named, with a condition pat /; test or a test pat?f. XMLMatchQ tests the element itself as the pattern root, not the elements nested in it; use XMLCases to search a tree, or XMLFreeQ to test whether any element in it matches. XMLMatchQ[document, XMLDocument[c...]] tests a document. XMLMatchQ[list, listpattern] tests a list of elements against a list pattern, such as {XMLPattern[\"th\"], ___}, ignoring the strings in the list. An element against a document or list pattern, or a document or list against an element pattern, gives False. The \"AttributeReadings\" option adds readings to $AttributeReadings, in both XMLMatchQ[element, pattern, opts] and XMLMatchQ[pattern, opts].";

Options[XMLMatchQ] = {"AttributeReadings" -> <||>};

(* An option rule is never a pattern, so XMLMatchQ[pattern, opts] is the
   operator form. Its option is a Block for each call of the operator. *)
XMLMatchQ[q_, opts : Longest[__?(optionRuleQ[XMLMatchQ])]][el_] :=
  withReadings[OptionValue[XMLMatchQ, {opts}, "AttributeReadings"], matchWith[cachedMatcher[q], el]];
(* Each call of the operator is a call of its own, so the XML* calls in its
   condition share one set of warned list keys. *)
XMLMatchQ[q_][el_] := withListKeyWarnings[matchWith[cachedMatcher[q], el]];

XMLMatchQ[el_, q : Except[_?(optionRuleQ[XMLMatchQ])], opts : OptionsPattern[]] :=
  withReadings[OptionValue["AttributeReadings"], matchWith[matcherOf[q], el]];

XMLMatchQ[args___] /; (countMessage[XMLMatchQ, {args}, {1, 2}]; False) := Null;

matchWith[$Failed, _] := $Failed;
matchWith[m_, el_] := m[el];

(* A pattern root of XMLPatterns without constraints is tested with one
   MatchQ (plainRootQ, Query/Compiler.wl); any other pattern is a tree
   pattern (Query/TreePatterns.wl). *)
matcherOf[q_] :=
  If[plainRootQ[q], elementMatcher[q, XMLMatchQ],
    Replace[treeMatcher[XMLMatchQ, q, True], m : Except[$Failed] :> (treeMatchQ[m, #] &)]];

(* The operator form stays unevaluated, as MatchQ[pattern] does, and is applied
   to each element in turn, so its matcher is kept, keyed on everything the
   compiled query depends on: the function that compiles it, XMLMatchQ's or
   XMLFreeQ's, the pattern, and $AttributeReadings, which the
   "AttributeReadings" option joins to (issue #2). A refused pattern is not
   kept: it gives its message on each call, as the two-argument form does. The
   cache is emptied when it is full. *)
$matcherCache = <||>;
$matcherCacheSize = 256;

cachedMatcher[q_, compile_ : matcherOf] :=
  With[{key = {compile, q, $AttributeReadings}},
    Lookup[$matcherCache, Key[key],
      With[{m = compile[q]},
        If[m =!= $Failed,
          If[Length[$matcherCache] >= $matcherCacheSize, $matcherCache = <||>];
          $matcherCache[key] = m];
        m]]];

(* =========================================================== *)
(* XMLFreeQ (#32)                                               *)
(* The XML-pattern counterpart of FreeQ: no element at the      *)
(* DOM depths given matches, the input itself at depth 0.       *)
(* =========================================================== *)

PackageExported[XMLFreeQ]
XMLFreeQ::usage = "XMLFreeQ[tree, pattern] gives True if no element of tree, tree itself included, matches pattern, and False otherwise. XMLFreeQ[tree, pattern, levelspec] tests only the elements at the DOM depths in levelspec, where tree itself is at depth 0, its children at depth 1, and so on; levelspec is n (depths 1 to n), {n}, {m, n} or Infinity, and the default is {0, Infinity}, as in FreeQ. XMLFreeQ[pattern] is an operator form, which takes no level spec. Each element is tested as XMLMatchQ tests it: pattern can be an XMLPattern, an XMLElement pattern, an XMLDocument pattern, which matches only a document at depth 0, or a CSS selector string that describes one element, or alternatives of these, any of them named, with a condition or a test. The \"AttributeReadings\" option adds readings to $AttributeReadings, as in XMLCases.";
XMLFreeQ::level = "Level specification `1` should be a DOM depth: n, {n}, {m, n} or Infinity, with 0 <= m <= n.";

Options[XMLFreeQ] = {"AttributeReadings" -> <||>};

XMLFreeQ[q_, opts : Longest[__?(optionRuleQ[XMLFreeQ])]][tree_] :=
  withReadings[OptionValue[XMLFreeQ, {opts}, "AttributeReadings"], freeWith[cachedMatcher[q, freeMatcher], tree, {0, Infinity}]];
XMLFreeQ[q_][tree_] := withListKeyWarnings[freeWith[cachedMatcher[q, freeMatcher], tree, {0, Infinity}]];

XMLFreeQ[tree_, q : Except[_?(optionRuleQ[XMLFreeQ])], levels : Except[_?(optionRuleQ[XMLFreeQ])] : {0, Infinity},
    opts : OptionsPattern[]] :=
  With[{l = domLevels[levels]},
    If[l === $Failed, Message[XMLFreeQ::level, levels]; $Failed,
      withReadings[OptionValue["AttributeReadings"], freeWith[freeMatcher[q], tree, l]]]];

XMLFreeQ[args___] /; (countMessage[XMLFreeQ, {args}, {1, 3}]; False) := Null;

freeMatcher[q_] := treeMatcher[XMLFreeQ, q, False];

freeWith[$Failed, _, _] := $Failed;
freeWith[m_, tree_, l_] := If[validTreeQ[tree], treeFreeQ[m, tree, l], messageTreeRefusal[XMLFreeQ, tree]; $Failed];

(* A level spec in DOM depth, in FreeQ's forms, as {lo, hi}, or $Failed. *)
domLevels[n : (_Integer?NonNegative | DirectedInfinity[1])] := {1, n};
domLevels[{n_Integer?NonNegative}] := {n, n};
domLevels[{m_Integer?NonNegative, n : (_Integer | DirectedInfinity[1])}] /; m <= n := {m, n};
domLevels[_] := $Failed;
