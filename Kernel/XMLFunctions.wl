(* ::Package:: *)
(* HTMLPatterns: XMLCases, XMLFirstCase, XMLDeleteCases and XMLMatchQ *)

(* Used by Tree.wl *)
PackageScoped[countQ]

(* =========================================================== *)
(* XMLCases                                                     *)
(* =========================================================== *)

PackageExported[XMLCases]
XMLCases::usage = "XMLCases[tree, pattern] gives a list of the elements of tree, at any depth, that match pattern. The elements are in document order: an element comes before the elements nested in it, and an earlier sibling before a later one. tree itself is never included. pattern can be an XMLPattern, a Child, Descendant, Adjacent or Sibling combinator, alternatives of any of these, or any of these with a condition pat /; test. An XMLPattern or alternatives of them can also have a test pat?f, which applies f to the element. A CSS selector string, such as \"div.note > p\", can be given wherever a pattern goes, and means FromCSSSelector[string]. XMLCases[tree, pattern :> body] gives the value of body for each match, evaluated in document order. XMLCases[tree, pattern -> rhs] evaluates rhs once, before any matching, as Cases does, and gives its value for each match, with the names in pattern replaced by what they matched. XMLCases[tree, pattern, n] gives the first n of these, in document order, or all of them if there are fewer; n is a non-negative integer or Infinity. With pattern :> body, body is evaluated only for the matches it gives. A combinator gives each element that its last stage matches once. Alternatives that hold a combinator give each element that any of them matches once, and a name bound only in an alternative that did not match is Sequence[], as in Cases. If several alternatives match an element, the first of them that matches binds the names. If tree is an XMLElement, tree can match any stage of a combinator except the last. A name for a whole element, as in e : XMLPattern[...], gives the element as it appears in tree, without list keys such as \"classList\". XMLCases[tree, pattern, \"AttributeReadings\" -> readings] adds readings to $AttributeReadings for this call.";

Options[XMLCases] = {"AttributeReadings" -> <||>};

(* The count n is a ceiling, as in StringCases (ADR 0019). A third argument
   that is not an option is a count, and one that is not valid gives innf. *)
XMLCases[tree_, q_, n : Except[_?(optionQ[XMLCases])] : Infinity, opts : OptionsPattern[]] /; countQ[n] :=
  withReadings[OptionValue["AttributeReadings"], queryCases[compileQuery[q, XMLCases], tree, n]];

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
XMLFirstCase::usage = "XMLFirstCase[tree, pattern] gives the first element of tree that matches pattern, in document order, or Missing[\"NotFound\"] if there is none. Of nested matches, it gives the outermost. XMLFirstCase[tree, pattern, default] gives default if there is no match. XMLFirstCase accepts the same patterns as XMLCases, including a CSS selector string, and gives the first element of the list that XMLCases gives. With pattern :> body, body is evaluated only for the match that XMLFirstCase returns. With pattern -> rhs, rhs is evaluated once, before any matching, as in FirstCase, and the names in pattern are replaced in its value by what they matched. The \"AttributeReadings\" option adds readings to $AttributeReadings, as in XMLCases.";

Options[XMLFirstCase] = {"AttributeReadings" -> <||>};

XMLFirstCase[tree_, q_, default : Except[_?(optionRuleQ[XMLFirstCase])] : Missing["NotFound"],
    opts : OptionsPattern[]] :=
  withReadings[OptionValue["AttributeReadings"], queryFirst[compileQuery[q, XMLFirstCase], tree, default]];

XMLFirstCase[args___] /; (countMessage[XMLFirstCase, {args}, {2, 3}]; False) := Null;

(* =========================================================== *)
(* XMLDeleteCases                                               *)
(* Base: native DeleteCases with Infinity levelspec.            *)
(* Combinators: the chain's last-stage elements are deleted.    *)
(* =========================================================== *)

PackageExported[XMLDeleteCases]
XMLDeleteCases::usage = "XMLDeleteCases[tree, pattern] gives tree with every element that matches pattern removed, at any depth. pattern can be an XMLPattern, a Child, Descendant, Adjacent or Sibling combinator, alternatives of any of these, or any of these with a condition pat /; test. An XMLPattern or alternatives of them can also have a test pat?f, which applies f to the element. A CSS selector string can be given wherever a pattern goes, and means FromCSSSelector[string]. Combinators can be nested, and each stage can have a condition. A combinator removes the elements that its last stage matches, by their position in tree, so Child[XMLPattern[_], {XMLPattern[\"li\"], ___}] removes the first li of each list and no other. As in XMLCases, if tree is an XMLElement, tree can match any stage of a combinator except the last. The root element of an XMLObject is never removed: XMLDeleteCases issues a message and removes the other elements that match. The \"AttributeReadings\" option adds readings to $AttributeReadings, as in XMLCases.";
XMLDeleteCases::root = "The root element of an XMLObject cannot be deleted; it was kept.";

Options[XMLDeleteCases] = {"AttributeReadings" -> <||>};

XMLDeleteCases[tree_, q_, opts : OptionsPattern[]] :=
  withReadings[OptionValue["AttributeReadings"], queryDelete[compileQuery[q, XMLDeleteCases], tree]];

XMLDeleteCases[args___] /; (countMessage[XMLDeleteCases, {args}, {2, 2}]; False) := Null;

(* =========================================================== *)
(* XMLMatchQ (ADR 0013)                                         *)
(* A whole-element test, as StringMatchQ is a whole-string one. *)
(* =========================================================== *)

PackageExported[XMLMatchQ]
XMLMatchQ::usage = "XMLMatchQ[element, pattern] gives True if element matches pattern, and False otherwise. XMLMatchQ[pattern] is an operator form. pattern can be an XMLPattern, alternatives of them, or either with a condition pat /; test or a test pat?f, or a CSS selector string that describes one element, such as \"a.external\". XMLMatchQ tests the element itself, not the elements nested in it; use XMLCases to search a tree. The \"AttributeReadings\" option adds readings to $AttributeReadings, in both XMLMatchQ[element, pattern, opts] and XMLMatchQ[pattern, opts].";
XMLMatchQ::combinator = "`1` relates an element to its parent or siblings, which a lone element does not have. Use XMLCases or XMLFirstCase to search a tree with it.";

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

matcherOf[q_] := elementMatcher[compileQuery[q, XMLMatchQ]];

(* The operator form stays unevaluated, as MatchQ[pattern] does, and is applied
   to each element in turn, so its matcher is kept, keyed on everything the
   compiled query depends on: the pattern, $AttributeReadings, which the
   "AttributeReadings" option joins to (issue #2), and whether shapes are
   recognised, so that a test turning recognition off gets a matcher compiled
   with it off (ADR 0020). A refused pattern is not
   kept: it gives its message on each call, as the two-argument form does. The
   cache is emptied when it is full. *)
$matcherCache = <||>;
$matcherCacheSize = 256;

cachedMatcher[q_] :=
  With[{key = {q, $AttributeReadings, $recogniseShapes}},
    Lookup[$matcherCache, Key[key],
      With[{m = matcherOf[q]},
        If[m =!= $Failed,
          If[Length[$matcherCache] >= $matcherCacheSize, $matcherCache = <||>];
          $matcherCache[key] = m];
        m]]];
