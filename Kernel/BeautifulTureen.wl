(* ::Package:: *)
(* BeautifulTureen: pattern constructors + XMLCases *)

BeginPackage["MaximilienTirard`BeautifulTureen`"];

(* === Public symbols === *)

XMLPattern::usage = "XMLPattern[tag] constructs an XMLElement pattern matching any element with the given tag. XMLPattern[tag, constraints...] additionally constrains attributes, where each constraint is \"attr\" -> value, a bare \"attr\" for existence, or CSSClass[...].";
CSSClass::usage = "CSSClass[cls] gives an attribute constraint, for use in XMLPattern, matching elements whose class attribute contains cls. CSSClass[cls1, cls2, ...] requires all of the given classes; use Alternatives for or-semantics and Except[cls] to negate.";
XMLCases::usage = "XMLCases[tree, pattern] gives a list of all elements of the XML tree that match pattern, searched at any depth. pattern can be an XMLElement pattern (see XMLPattern), an Alternatives of them, a Child, Descendant, Adjacent, or Sibling combinator, or a rule pattern :> body.";
XMLFirstCase::usage = "XMLFirstCase[tree, pattern] gives the first element of tree matching pattern, or Missing[\"NotFound\"] if there is none. XMLFirstCase[tree, pattern, default] gives default instead. It accepts the same patterns as XMLCases and short-circuits on the first match.";
XMLDeleteCases::usage = "XMLDeleteCases[tree, pattern] gives tree with every element matching pattern removed, at any depth. It accepts XMLElement patterns, Alternatives of them, and Child or Descendant combinators; Adjacent and Sibling are not supported.";
Child::usage = "Child[parentPat, childPat] is a combinator for XMLCases matching elements that satisfy childPat and occur as direct children of an element satisfying parentPat.";
Adjacent::usage = "Adjacent[beforePat, afterPat] is a combinator for XMLCases matching an element that satisfies afterPat and immediately follows a sibling satisfying beforePat.";
Sibling::usage = "Sibling[beforePat, afterPat] is a combinator for XMLCases matching elements that satisfy afterPat and follow a sibling satisfying beforePat.";
Descendant::usage = "Descendant[ancestorPat, descPat] is a combinator for XMLCases matching elements that satisfy descPat and are nested anywhere below an element satisfying ancestorPat.";
HTMLTextContent::usage = "HTMLTextContent[tree] gives the text content of an XML tree: the lossless concatenation, in document order, of every descendant string. It inserts and removes no whitespace, so source indentation and <pre> whitespace survive unchanged. tree may be an XMLElement, an XMLObject document, a list, or a string.";
HTMLInnerText::usage = "HTMLInnerText[tree] gives the readable text of an XML tree: internal whitespace is collapsed, block-level tags are placed on their own lines, <br> becomes a newline, <pre> content is preserved verbatim, non-rendered tags such as script and style are dropped, and the result is trimmed. Each element is classified by tag alone using a frozen user-agent stylesheet. HTMLInnerText[tree, \"Roles\" -> rules] overrides the classification; \"BlockSeparator\" -> sep sets the string joining block boundaries (default \"\\n\"). tree may be an XMLElement, an XMLObject document, a list, or a string.";
HTMLToNotebook::usage = "HTMLToNotebook[tree] converts an HTML/XML tree into a Notebook[...] expression, from which Markdown, PDF, RTF, and display follow via Export. Block-level tags become cells (headings -> Title/Chapter/Section/..., p -> Text, li -> Item/Subitem/..., blockquote -> a framed quote, pre -> a Program cell, table -> Dataset or Grid) and inline tags become boxes inside the surrounding cell (b -> bold, i -> italic, code -> inline code, a -> hyperlink, ...). Classification is by tag alone using a frozen user-agent stylesheet. HTMLToNotebook[tree, \"Roles\" -> rules] overrides the block/inline classification; \"Constructs\" -> rules overrides the form each element takes (an inline token, a cell-style string, or a constructor function element :> Cell/boxes). tree may be an XMLElement, an XMLObject document, a list, or a string.";

(* === Messages === *)

CSSClass::badarg = "Expected a string, string pattern, Alternatives, or Except. Got `1`.";
XMLPattern::badtag = "Tag should be a string, Alternatives, or pattern (e.g. _). Got `1`.";
XMLPattern::badconstraint = "Constraint should be a Rule (key -> val, where key is an attribute name or a {namespace, name} pair), string (attribute existence), or CSSClass[...]. Got `1`.";
XMLCases::badtree = "First argument should be an XMLObject, XMLElement, or list thereof. Got head `1`.";
XMLCases::badpat = "Second argument should be an XMLElement pattern, Alternatives of XMLElement patterns, or combinator (Child, Adjacent, Sibling, Descendant). Got `1`.";
XMLFirstCase::badtree = "First argument should be an XMLObject, XMLElement, or list thereof. Got head `1`.";
XMLFirstCase::badpat = "Second argument should be an XMLElement pattern, Alternatives of XMLElement patterns, or combinator (Child, Adjacent, Sibling, Descendant). Got `1`.";
XMLDeleteCases::badtree = "First argument should be an XMLObject, XMLElement, or list thereof. Got head `1`.";
XMLDeleteCases::badpat = "Second argument should be an XMLElement pattern, Alternatives of XMLElement patterns, or Child/Descendant combinator. Got `1`.";
XMLDeleteCases::unsupported = "Adjacent and Sibling combinators are not supported by XMLDeleteCases. Use XMLCases for filtering semantics instead.";
HTMLTextContent::badtree = "First argument should be an XMLObject, XMLElement, or list thereof. Got head `1`.";
HTMLInnerText::badtree = "First argument should be an XMLObject, XMLElement, or list thereof. Got head `1`.";
HTMLInnerText::badrole = "Role rule produced `1`, which is not one of \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\", or \"Skip\"; ignoring it and deferring to the frozen user-agent table.";
HTMLToNotebook::badtree = "First argument should be an XMLObject, XMLElement, or list thereof. Got head `1`.";
HTMLToNotebook::badrole = "Role rule produced `1`, which is not one of \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\", or \"Skip\"; ignoring it and deferring to the frozen user-agent table.";

Begin["`Private`"];

(* =========================================================== *)
(* Validation helpers                                           *)
(* =========================================================== *)

(* Valid class constraint: string, StringExpression, Alternatives, Except, PatternTest, Blank *)
validCSSClassQ[_String] := True;
validCSSClassQ[_StringExpression] := True;
validCSSClassQ[_Alternatives] := True;
validCSSClassQ[Verbatim[Except][_]] := True;
validCSSClassQ[_Blank] := True;
validCSSClassQ[_PatternTest] := True;
validCSSClassQ[_Pattern] := True;
validCSSClassQ[_] := False;

(* Valid tag: a string, or any ordinary pattern matched against the element's
   tag \[LongDash] Alternatives, Blank(Sequence), a named Pattern, or a predicate-bearing
   PatternTest (_?f) / Condition (t_ /; test). *)
validTagQ[_String] := True;
validTagQ[_Alternatives] := True;
validTagQ[_Blank] := True;
validTagQ[_BlankSequence] := True;
validTagQ[_Pattern] := True;
validTagQ[_PatternTest] := True;
validTagQ[_Condition] := True;
validTagQ[_] := False;

(* Valid attribute key: a plain name, or an imported {namespace, name} pair
   (WL imports a namespaced attribute such as xlink:href with a two-element
   list key {namespaceURI, localName}). Both positions may be patterns. *)
validAttrKeyQ[_String] := True;
validAttrKeyQ[{_, _}] := True;
validAttrKeyQ[_] := False;

(* Valid constraint for XMLPattern *)
validConstraintQ[Rule[k_, _]] := validAttrKeyQ[k];  (* key -> val *)
validConstraintQ[_String] := True;                  (* "attr" \[LongDash] existence shorthand *)
validConstraintQ[_] := False;

(* Valid pattern for XMLCases: XMLElement pattern, combinator, Alternatives of
   XMLElement patterns (including nested Alternatives built via composition),
   or rule *)

(* Collect leaves of a possibly-nested Alternatives. Alternatives has no Flat
   attribute, so `(a|b) | (c|d)` stays as 2-arg nested \[LongDash] we flatten manually.
   Note: `Alternatives[args___]` in pattern position is the OR pattern, not a
   head match, so we use `alts_Alternatives` to bind a literal Alternatives. *)
altLeaves[alts_Alternatives] := Join @@ (altLeaves /@ List @@ alts);
altLeaves[x_] := {x};

altOfXMLElementsQ[alts_Alternatives] :=
  AllTrue[altLeaves[alts], MatchQ[#, _XMLElement] &];

validPatternQ[_XMLElement] := True;
validPatternQ[_Child] := True;
validPatternQ[_Adjacent] := True;
validPatternQ[_Sibling] := True;
validPatternQ[_Descendant] := True;
validPatternQ[_RuleDelayed] := True;
validPatternQ[alts_Alternatives] := altOfXMLElementsQ[alts];
validPatternQ[_] := False;

(* Valid tree for XMLCases *)
validTreeQ[XMLObject["Document"][_, _XMLElement, _]] := True;
validTreeQ[_XMLElement] := True;
validTreeQ[expr_List] := AllTrue[expr, MatchQ[#, _XMLElement | _String] &];
validTreeQ[_] := False;

(* Input surface for the text extractors: the selector surface, plus a bare
   string (text-of-a-string is meaningful, unlike for the selectors). *)
validTextInputQ[_String] := True;
validTextInputQ[t_] := validTreeQ[t];

(* =========================================================== *)
(* CSSClass                                                     *)
(* Produces a rule for use in KeyValuePattern.                  *)
(* Uses StringMatchQ with a whitespace-bounded string pattern.  *)
(* Multiple arguments = AND. Use Alternatives for OR.           *)
(* =========================================================== *)

(* String pattern that matches cls as a whitespace-delimited token *)
classPattern[cls_] :=
  (___ ~~ Whitespace)... ~~ cls ~~ (Whitespace ~~ ___)...;

(* Single positive constraint *)
CSSClass[cls_] :=
  "class" -> _?(StringMatchQ[classPattern[cls]]) /;
    validCSSClassQ[cls] && !MatchQ[cls, _Except];

(* Single negation: CSSClass[Except["x"]] = does not have class x *)
CSSClass[Verbatim[Except][cls_]] :=
  "class" -> _?(!StringMatchQ[#, classPattern[cls]] &) /;
    validCSSClassQ[cls];

(* List -> treat as sequence: CSSClass[{"a","b"}] = CSSClass["a","b"] *)
CSSClass[cls_List] := CSSClass @@ cls;

(* Multiple constraints: AND semantics *)
CSSClass[constraints__] :=
  "class" -> _?(Function[val,
    AllTrue[{constraints}, classConstraint[val, #] &]
  ]) /; Length[{constraints}] > 1 && AllTrue[{constraints}, validCSSClassQ];

(* Bad arguments *)
CSSClass[cls_] := (Message[CSSClass::badarg, cls]; $Failed) /;
  !validCSSClassQ[cls];

classConstraint[val_String, Verbatim[Except][cls_]] :=
  !StringMatchQ[val, classPattern[cls]];
classConstraint[val_String, cls_] :=
  StringMatchQ[val, classPattern[cls]];

(* =========================================================== *)
(* XMLPattern                                                   *)
(* Produces an XMLElement pattern for use with Cases/XMLCases   *)
(* =========================================================== *)

XMLPattern[tag_] :=
  XMLElement[tag, _, _] /; validTagQ[tag];

(* Convert bare strings to existence rules, pass Rules through *)
normalizeConstraint[key_String] := key -> _;
normalizeConstraint[r_Rule] := r;

XMLPattern[tag_, constraints__] :=
  XMLElement[tag, KeyValuePattern[normalizeConstraint /@ Flatten[{constraints}]], _] /;
    validTagQ[tag] && AllTrue[{constraints}, validConstraintQ];

(* Bad tag *)
XMLPattern[tag_, ___] :=
  (Message[XMLPattern::badtag, tag]; $Failed) /; !validTagQ[tag];

(* Bad constraint \[LongDash] find the first invalid one *)
XMLPattern[tag_, constraints__] :=
  Module[{bad = SelectFirst[{constraints}, !validConstraintQ[#] &]},
    Message[XMLPattern::badconstraint, bad]; $Failed
  ] /; validTagQ[tag] && !AllTrue[{constraints}, validConstraintQ];

(* =========================================================== *)
(* XMLCases                                                     *)
(* =========================================================== *)

(* Base: simple pattern \[LongDash] just Cases *)
XMLCases[tree_, pat_XMLElement] :=
  Cases[tree, pat, Infinity] /; validTreeQ[tree];

(* Base: Alternatives of XMLElement patterns (heterogeneous constraints).
   Flat-check of leaves so composed patterns like (a|b) | (c|d) work. *)
XMLCases[tree_, pat_Alternatives] :=
  Cases[tree, pat, Infinity] /;
    validTreeQ[tree] && altOfXMLElementsQ[pat];

(* Base with rule \[LongDash] catches any RuleDelayed not handled by combinators.
   Also handles (pat1 | pat2) :> body since the lhs is an Alternatives. *)
XMLCases[tree_, rule_RuleDelayed] :=
  Cases[tree, rule, Infinity] /; validTreeQ[tree];

(* Descendant: chained Cases *)
XMLCases[tree_, Descendant[outerPat_, innerPat_]] :=
  Flatten[XMLCases[#, innerPat] & /@ XMLCases[tree, outerPat], 1] /;
    validTreeQ[tree];

(* Descendant with rule \[LongDash] nested Cases keeps outer bindings in scope *)
XMLCases[tree_, Verbatim[RuleDelayed][Descendant[outerPat_, innerPat_], body_]] :=
  Flatten[Cases[tree,
    parent:outerPat :> XMLCases[parent, innerPat :> body],
    Infinity], 1
  ] /; validTreeQ[tree];

(* Child: find parents, then direct children of each *)
XMLCases[tree_, Child[parentPat_, childPat_]] :=
  Flatten[
    Cases[#, childPat, {2}] & /@ XMLCases[tree, parentPat],
    1
  ] /; validTreeQ[tree];

(* Child with rule \[LongDash] nested Cases keeps parent bindings in scope *)
XMLCases[tree_, Verbatim[RuleDelayed][Child[parentPat_, childPat_], body_]] :=
  Flatten[Cases[tree,
    parent:parentPat :> Cases[parent, childPat :> body, {2}],
    Infinity], 1
  ] /; validTreeQ[tree];

(* Adjacent sibling: find parents containing beforePat,
   then for each, find afterPat immediately after *)
XMLCases[tree_, Adjacent[beforePat_, afterPat_]] :=
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
  ] /; validTreeQ[tree];

(* Adjacent with rule *)
XMLCases[tree_, Verbatim[RuleDelayed][Adjacent[beforePat_, afterPat_], body_]] :=
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
  ] /; validTreeQ[tree];

(* General sibling: find parents containing beforePat,
   then for each, find all afterPat that come after *)
XMLCases[tree_, Sibling[beforePat_, afterPat_]] :=
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
  ] /; validTreeQ[tree];

(* Sibling with rule \[LongDash] outer Cases keeps beforePat bindings in scope *)
XMLCases[tree_, Verbatim[RuleDelayed][Sibling[beforePat_, afterPat_], body_]] :=
  Flatten[Cases[tree,
    el:XMLElement[_, _, children_List] /; MemberQ[children, beforePat] :>
      Module[{elems = Select[el[[3]], MatchQ[#, _XMLElement] &], idx},
        idx = FirstPosition[elems, beforePat, None, {1}];
        If[idx =!= None,
          Cases[elems[[idx[[1]] + 1 ;;]], afterPat :> body],
          {}
        ]
      ],
    Infinity], 1
  ] /; validTreeQ[tree];

(* Bad tree *)
XMLCases[tree_, pat_] :=
  (Message[XMLCases::badtree, Head[tree]]; $Failed) /;
    !validTreeQ[tree] && validPatternQ[pat];

(* Bad pattern *)
XMLCases[tree_, pat_] :=
  (Message[XMLCases::badpat, Short[pat]]; $Failed) /;
    validTreeQ[tree] && !validPatternQ[pat];

(* =========================================================== *)
(* XMLFirstCase                                                 *)
(* Short-circuits on the first match; same combinator surface   *)
(* as XMLCases. Default (3rd arg) returned when nothing found.  *)
(* =========================================================== *)

(* Base: simple pattern \[LongDash] FirstCase short-circuits natively *)
XMLFirstCase[tree_, pat_XMLElement, default_:Missing["NotFound"]] :=
  FirstCase[tree, pat, default, Infinity] /; validTreeQ[tree];

(* Base: Alternatives of XMLElement patterns (heterogeneous constraints).
   Flat-check of leaves so composed patterns like (a|b) | (c|d) work. *)
XMLFirstCase[tree_, pat_Alternatives, default_:Missing["NotFound"]] :=
  FirstCase[tree, pat, default, Infinity] /;
    validTreeQ[tree] && altOfXMLElementsQ[pat];

(* Base with rule.
   Also handles (pat1 | pat2) :> body since the lhs is an Alternatives. *)
XMLFirstCase[tree_, rule_RuleDelayed, default_:Missing["NotFound"]] :=
  FirstCase[tree, rule, default, Infinity] /; validTreeQ[tree];

(* Descendant: short-circuit via Catch/Throw on first inner hit *)
XMLFirstCase[tree_, Descendant[outerPat_, innerPat_],
    default_:Missing["NotFound"]] :=
  Module[{tag},
    Catch[
      Cases[tree, o:outerPat :>
        With[{r = XMLFirstCase[o, innerPat, tag]},
          If[r =!= tag, Throw[r, tag]]
        ], Infinity];
      default,
      tag
    ]
  ] /; validTreeQ[tree];

(* Descendant with rule *)
XMLFirstCase[tree_, Verbatim[RuleDelayed][Descendant[outerPat_, innerPat_], body_],
    default_:Missing["NotFound"]] :=
  Module[{tag},
    Catch[
      Cases[tree, parent:outerPat :>
        With[{r = XMLFirstCase[parent, innerPat :> body, tag]},
          If[r =!= tag, Throw[r, tag]]
        ], Infinity];
      default,
      tag
    ]
  ] /; validTreeQ[tree];

(* Child: first parent match's first direct child match *)
XMLFirstCase[tree_, Child[parentPat_, childPat_],
    default_:Missing["NotFound"]] :=
  Module[{tag},
    Catch[
      Cases[tree, p:parentPat :>
        With[{r = FirstCase[p, childPat, tag, {2}]},
          If[r =!= tag, Throw[r, tag]]
        ], Infinity];
      default,
      tag
    ]
  ] /; validTreeQ[tree];

(* Child with rule *)
XMLFirstCase[tree_, Verbatim[RuleDelayed][Child[parentPat_, childPat_], body_],
    default_:Missing["NotFound"]] :=
  Module[{tag},
    Catch[
      Cases[tree, parent:parentPat :>
        With[{r = FirstCase[parent, childPat :> body, tag, {2}]},
          If[r =!= tag, Throw[r, tag]]
        ], Infinity];
      default,
      tag
    ]
  ] /; validTreeQ[tree];

(* Adjacent: first parent containing beforePat, first afterPat immediately after *)
XMLFirstCase[tree_, Adjacent[beforePat_, afterPat_],
    default_:Missing["NotFound"]] :=
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
  ] /; validTreeQ[tree];

(* Adjacent with rule *)
XMLFirstCase[tree_, Verbatim[RuleDelayed][Adjacent[beforePat_, afterPat_], body_],
    default_:Missing["NotFound"]] :=
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
  ] /; validTreeQ[tree];

(* Sibling: first parent containing beforePat, first afterPat after it *)
XMLFirstCase[tree_, Sibling[beforePat_, afterPat_],
    default_:Missing["NotFound"]] :=
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
  ] /; validTreeQ[tree];

(* Sibling with rule *)
XMLFirstCase[tree_, Verbatim[RuleDelayed][Sibling[beforePat_, afterPat_], body_],
    default_:Missing["NotFound"]] :=
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
  ] /; validTreeQ[tree];

(* Bad tree *)
XMLFirstCase[tree_, pat_, ___] :=
  (Message[XMLFirstCase::badtree, Head[tree]]; $Failed) /;
    !validTreeQ[tree] && validPatternQ[pat];

(* Bad pattern *)
XMLFirstCase[tree_, pat_, ___] :=
  (Message[XMLFirstCase::badpat, Short[pat]]; $Failed) /;
    validTreeQ[tree] && !validPatternQ[pat];

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

(* Base: single XMLElement pattern *)
XMLDeleteCases[tree_, pat_XMLElement] :=
  DeleteCases[tree, pat, Infinity] /; validTreeQ[tree];

(* Base: Alternatives of XMLElement patterns (e.g. XMLPattern["script"] | XMLPattern["style"]).
   Flat-check of leaves so composed patterns like (a|b) | (c|d) work. *)
XMLDeleteCases[tree_, pat_Alternatives] :=
  DeleteCases[tree, pat, Infinity] /;
    validTreeQ[tree] && altOfXMLElementsQ[pat];

(* Child: at every matching parent, filter direct children *)
XMLDeleteCases[tree_, Child[parentPat_, childPat_]] :=
  xmlWalk[tree,
    Replace[#, p:parentPat :>
      XMLElement[p[[1]], p[[2]], DeleteCases[p[[3]], childPat]]
    ] &
  ] /; validTreeQ[tree];

(* Descendant: at every matching ancestor, DeleteCases innerPat across its subtree *)
XMLDeleteCases[tree_, Descendant[outerPat_, innerPat_]] :=
  xmlWalk[tree,
    Replace[#, p:outerPat :>
      XMLElement[p[[1]], p[[2]], DeleteCases[p[[3]], innerPat, Infinity]]
    ] &
  ] /; validTreeQ[tree];

(* Adjacent / Sibling: unsupported \[LongDash] deletion by relative position is a niche
   operation and the combinator API is documented as unsupported here. *)
XMLDeleteCases[tree_, _Adjacent | _Sibling] :=
  (Message[XMLDeleteCases::unsupported]; $Failed) /; validTreeQ[tree];

(* Bad tree *)
XMLDeleteCases[tree_, pat_] :=
  (Message[XMLDeleteCases::badtree, Head[tree]]; $Failed) /;
    !validTreeQ[tree] &&
    (MatchQ[pat, _XMLElement | _Child | _Descendant | _Adjacent | _Sibling] ||
     (MatchQ[pat, _Alternatives] && altOfXMLElementsQ[pat]));

(* Bad pattern *)
XMLDeleteCases[tree_, pat_] :=
  (Message[XMLDeleteCases::badpat, Short[pat]]; $Failed) /;
    validTreeQ[tree] &&
    !MatchQ[pat, _XMLElement | _Child | _Descendant | _Adjacent | _Sibling] &&
    !(MatchQ[pat, _Alternatives] && altOfXMLElementsQ[pat]);

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
(* a user "Roles" override layer (normRoleRules + roleOf). The  *)
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

normRoleRules[rules_] :=
  Replace[
    If[AssociationQ[rules], Normal[rules], Flatten[{rules}]],
    {Verbatim[Rule][lhs_, r_] :> (sugarRoleLHS[lhs] -> r),
     Verbatim[RuleDelayed][lhs_, r_] :> RuleDelayed[sugarRoleLHS[lhs], r]},
    {1}];

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
  itSerialize[
    Flatten[itToks[tree, False, normRoleRules[OptionValue["Roles"]]]],
    OptionValue["BlockSeparator"]
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
$defaultConstructRules := {
  XMLPattern["h1"] -> "Title",
  XMLPattern["h2"] -> "Chapter",
  XMLPattern["h3"] -> "Section",
  XMLPattern["h4"] -> "Subsection",
  XMLPattern["h5"] -> "Subsubsection",
  XMLPattern["h6"] -> "Subsubsubsection",
  XMLPattern["p"] -> "Text",
  XMLPattern["li"] -> "Item",
  XMLPattern["b" | "strong"] -> "Bold",
  XMLPattern["i" | "em" | "cite" | "var" | "dfn"] -> "Italic",
  XMLPattern["u" | "ins"] -> "Underline",
  XMLPattern["s" | "del" | "strike"] -> "StrikeThrough",
  XMLPattern["code" | "kbd" | "samp" | "tt"] -> "Code",
  XMLPattern["a"] -> "Hyperlink",
  XMLPattern["img"] -> "Hyperlink",
  XMLPattern["span" | "mark" | "small" | "q" | "abbr" | "sub" | "sup" |
    "time" | "label" | "bdi" | "bdo" | "data" | "ruby" | "rt" | "rp" |
    "wbr"] -> "Plain",
  XMLPattern["table"] :> tableConstruct,
  XMLPattern["hr"] :> hrConstruct
};

(* sugarRoleLHS (string -> XMLPattern) is shared with the role rules. *)
normConstructRules[rules_] :=
  Replace[
    If[AssociationQ[rules], Normal[rules], Flatten[{rules}]],
    {Verbatim[Rule][lhs_, r_] :> (sugarRoleLHS[lhs] -> r),
     Verbatim[RuleDelayed][lhs_, r_] :> RuleDelayed[sugarRoleLHS[lhs], r]},
    {1}];

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
  Notebook[
    blockEmit[toChildList[tree],
      initCtx[normRoleRules[OptionValue["Roles"]],
        normConstructRules[OptionValue["Constructs"]]]]
  ] /; validTextInputQ[tree];

HTMLToNotebook[tree_, OptionsPattern[]] :=
  (Message[HTMLToNotebook::badtree, Head[tree]]; $Failed) /; !validTextInputQ[tree];

End[];
EndPackage[];
