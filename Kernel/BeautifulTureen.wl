(* ::Package:: *)
(* BeautifulTureen: pattern constructors + XMLCases *)

BeginPackage["MaximilienTirard`BeautifulTureen`"];

(* === Public symbols === *)

XMLPattern::usage = "XMLPattern[tag, constraints...] produces an XMLElement pattern.";
CSSClass::usage = "CSSClass[cls, ...] constraint for CSS class membership.";
XMLCases::usage = "XMLCases[tree, pattern] finds matching elements. Accepts XMLElement patterns, Alternatives thereof (heterogeneous attribute constraints), rules, and combinators.";
XMLFirstCase::usage = "XMLFirstCase[tree, pattern] returns the first matching element (or Missing[\"NotFound\"]). XMLFirstCase[tree, pattern, default] returns default instead. Same pattern surface as XMLCases; short-circuits on first match.";
XMLDeleteCases::usage = "XMLDeleteCases[tree, pattern] returns tree with all matching elements removed at any depth. Accepts XMLElement patterns, Alternatives thereof, Child[parent, child], and Descendant[outer, inner].";
Child::usage = "Child[parentPat, childPat] \[LongDash] direct child combinator.";
Adjacent::usage = "Adjacent[beforePat, afterPat] \[LongDash] adjacent sibling combinator.";
Sibling::usage = "Sibling[beforePat, afterPat] \[LongDash] general sibling combinator.";
Descendant::usage = "Descendant[ancestorPat, descPat] \[LongDash] descendant combinator.";
HTMLText::usage = "HTMLText[element] extracts text content recursively.";

(* === Messages === *)

CSSClass::badarg = "Expected a string, string pattern, Alternatives, or Except. Got `1`.";
XMLPattern::badtag = "Tag should be a string, Alternatives, or pattern (e.g. _). Got `1`.";
XMLPattern::badconstraint = "Constraint should be a Rule (key -> val), string (attribute existence), or CSSClass[...]. Got `1`.";
XMLCases::badtree = "First argument should be an XMLObject, XMLElement, or list thereof. Got head `1`.";
XMLCases::badpat = "Second argument should be an XMLElement pattern, Alternatives of XMLElement patterns, or combinator (Child, Adjacent, Sibling, Descendant). Got `1`.";
XMLFirstCase::badtree = "First argument should be an XMLObject, XMLElement, or list thereof. Got head `1`.";
XMLFirstCase::badpat = "Second argument should be an XMLElement pattern, Alternatives of XMLElement patterns, or combinator (Child, Adjacent, Sibling, Descendant). Got `1`.";
XMLDeleteCases::badtree = "First argument should be an XMLObject, XMLElement, or list thereof. Got head `1`.";
XMLDeleteCases::badpat = "Second argument should be an XMLElement pattern, Alternatives of XMLElement patterns, or Child/Descendant combinator. Got `1`.";
XMLDeleteCases::unsupported = "Adjacent and Sibling combinators are not supported by XMLDeleteCases. Use XMLCases for filtering semantics instead.";

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

(* Valid tag: string, Alternatives, Blank, Pattern, StringExpression *)
validTagQ[_String] := True;
validTagQ[_Alternatives] := True;
validTagQ[_Blank] := True;
validTagQ[_BlankSequence] := True;
validTagQ[_Pattern] := True;
validTagQ[_] := False;

(* Valid constraint for XMLPattern *)
validConstraintQ[Rule[_String, _]] := True;     (* "attr" -> val *)
validConstraintQ[_String] := True;              (* "attr" \[LongDash] existence shorthand *)
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
(* HTMLText                                                     *)
(* Naive recursive StringJoin. Does not insert whitespace at    *)
(* block boundaries or handle <br> as newlines.                 *)
(* =========================================================== *)

HTMLText[XMLElement[_, _, children_List]] := StringJoin[HTMLText /@ children];
HTMLText[s_String] := s;
HTMLText[_] := "";

End[];
EndPackage[];
