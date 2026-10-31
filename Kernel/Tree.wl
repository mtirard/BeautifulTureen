(* ::Package:: *)
(* HTMLPatterns: HTMLToTree *)

(* Used by Common.wl *)
PackageScoped[treeOptionNameQ]

(* Used by Query/Compiler.wl *)
PackageScoped[$treeQueryOff]

(* =========================================================== *)
(* HTMLToTree                                                  *)
(* A lossy projection of a tree into a Tree for display: one   *)
(* node per element (its shell as data) and per text string.   *)
(* Customisation goes through Tree's own options, which pass   *)
(* through apart from the label, layout and size defaults.     *)
(* =========================================================== *)

PackageExported[HTMLToTree]
HTMLToTree::usage = "HTMLToTree[tree] draws an HTML or XML tree as a Tree, with one node per element and per text string. A document or a list is drawn under a \"#document\" root, and an XMLElement is its own root. Each element is labelled with its tag name, and its tooltip gives its compound selector, such as div#main.note, and its attributes. Each text string is a leaf, labelled with its text, whitespace collapsed and cut to 40 characters. Whitespace-only strings are left out unless \"IncludeWhitespace\" -> True is given. The data of an element node is the element with no contents, XMLElement[tag, attrs, {}], and the data of a text node is the string. Options of Tree, such as TreeElementLabelFunction, TreeLayout, MaxDisplayedChildren and ImageSize, can be given and are passed to Tree. The default layout is TreeLayout -> Left, and MaxDisplayedChildren -> m limits the children of every node. tree can be an XMLElement, an XMLObject document, or a list. HTMLToTree[tree, n] draws elements down to depth n, where the root is at depth 0 and its children at depth 1; n is a non-negative integer or Infinity, the default. An element at depth n with element children has a single \[Ellipsis] child in place of all its contents, with data Missing[\"Collapsed\", k], where k is the number of elements not drawn. \"Focus\" -> query draws only the elements the query selects, as XMLCases does, with their contents: each hangs from its nearest drawn ancestor, by a dashed edge whose tooltip gives the skipped path when there is one, and each run of other siblings is a single \[Ellipsis] leaf. With focus, depth counts from each Focused element, and a Focused element below the depth limit is still drawn. \"CollapsePaths\" -> False draws the elements on the path to each Focused element as nodes, which do not count towards depth. \"Hide\" -> query removes the elements it selects, with their contents, and leaves no mark; hiding wins over focus. Both queries are matched against the tree as given and take \"AttributeReadings\". \"MergeText\" -> HTMLInnerText draws an element whose contents hold elements, all of them inline, with a single text leaf in place of its contents, holding the text HTMLInnerText gives for it; \"MergeText\" -> HTMLTextContent gives its raw text instead. \"Roles\" -> rules sets which elements are inline, as in HTMLInnerText, and the text is the one HTMLInnerText gives with the same \"Roles\" and \"AttributeReadings\". Hidden elements are left out of the text, and an element that holds a Focused element is not merged.";
HTMLToTree::optval = "The value of the `1` option should be `2`. Got `3`.";
HTMLToTree::root = "The root element cannot be hidden; it was kept.";
HTMLToTree::hidetarget = "The \"Hide\" query selects the position `1`. Hide removes only elements, runs of element children, and the contents of an element.";
HTMLToTree::focustarget = "The \"Focus\" query selects the position `1`. Focus draws only elements and runs of element children.";

Options[HTMLToTree] = {"Focus" -> Automatic, "Hide" -> Automatic, "MergeText" -> Automatic,
  "IncludeWhitespace" -> Automatic, "CollapsePaths" -> Automatic, "Roles" -> Automatic,
  "AttributeReadings" -> Automatic};

(* ---- Settings ----
   Every Automatic is resolved here and only here, since the defaults are
   provisional. "Roles" is checked when the tree is drawn. A value that is refused
   gives optval, or badquery for a query, and $Failed. *)

$treeDefaults = <|"Focus" -> All, "Hide" -> None, "MergeText" -> None,
  "IncludeWhitespace" -> False, "CollapsePaths" -> True, "Roles" -> {},
  "AttributeReadings" -> <||>|>;

(* The value that turns each query off; the other's is refused *)
$treeQueryOff = <|"Focus" -> All, "Hide" -> None|>;

(* The values an option can take, written as the message shows them *)
$treeOptionValues = <|"MergeText" -> None | HTMLInnerText | HTMLTextContent | Automatic,
  "IncludeWhitespace" -> True | False | Automatic, "CollapsePaths" -> True | False | Automatic|>;

treeSettings[values_Association] :=
  Catch[Association[KeyValueMap[#1 -> treeSetting[#1, #2] &, values]], treeSettings];

treeSetting[name_, Automatic] := $treeDefaults[name];
treeSetting[name : "Focus" | "Hide", v : All | None] /; v =!= $treeQueryOff[name] :=
  (badQuery[name, v]; Throw[$Failed, treeSettings]);
treeSetting[name_, v_] /; KeyExistsQ[$treeOptionValues, name] :=
  If[MatchQ[v, $treeOptionValues[name]], v,
    Message[HTMLToTree::optval, name, $treeOptionValues[name], v];
    Throw[$Failed, treeSettings]];
treeSetting[_, v_] := v;

(* ---- Telling options apart ----
   HTMLToTree's names are strings and Tree's are symbols, so they cannot
   collide. Options[Tree] is read at call time, not stored. *)

treeOptionNameQ[name_Symbol] := MemberQ[Keys[Options[Tree]], name];
treeOptionNameQ[_] := False;

unknownTreeOptions[opts_List] := Select[Flatten[opts], !optionRuleQ[HTMLToTree][#] &];

(* ---- Hidden and focused sites ----
   Both queries are matched against the original input, as XMLCases matches,
   so that context in a pattern sees the page as it is. Removing the hidden
   elements first (XMLDeleteCases, then draw) would be simpler, but it changes
   what a query matches: a sibling or descendant that is hidden would no
   longer be there for the focus query to see. Focus is run first, so a focus
   query that is refused gives $Failed before hide is matched.

   A tree pattern or rule runs on the query engine, which gives positions
   (ADR 0025); they are turned into the walk's WL positions here. *)

(* The sites the walk reads: "Hidden", the positions of Hidden items;
   "Focused", those of Focused elements, or All; and "FocusPaths", every
   position above a Focused element. Each is an Association to True. Hiding
   wins: a site that is hidden, or inside a Hidden element, is not focused. *)
treeSites[tree_, s_] := Catch[
  With[{focus = queryItemPositions["Focus", tree, s["Focus"]], hidden = siteSet[queryItemPositions["Hide", tree, s["Hide"]]]},
    With[{focused = If[focus === All, All, Select[focus, NoneTrue[prefixes[#], KeyExistsQ[hidden, #] &] &]]},
      <|"Hidden" -> hidden, "Focused" -> Replace[focused, l_List :> siteSet[l]],
        "FocusPaths" -> If[focused === All, <||>, siteSet[Join @@ (Most[prefixes[#]] & /@ focused)]]|>]],
  treeSites];

siteSet[ps_List] := AssociationThread[ps -> True];

prefixes[pos_] := FoldList[Append, {}, pos];

(* The WL positions a query selects, All for no focus, or a throw of $Failed *)
queryItemPositions["Focus", _, All] := All;
queryItemPositions["Hide", _, None] := {};
queryItemPositions[name_, tree_, q_] := countedItemPositions[name, tree, q];

(* The WL positions of the items a tree query selects: those at the
   positions of its counted names, over all its results. A position of a
   kind the option cannot act on is hidetarget or focustarget. For Hide, a
   bare element is matched in a list around it, at the same positions, so
   that its root can be selected, and kept with root. *)
countedItemPositions[name_, tree_, q_] :=
  With[{counted = Replace[
      distinctPositions[runQuery[Block[{$queryOption = name}, compileQuery[HTMLToTree, q]],
        If[name === "Hide" && MatchQ[tree, _XMLElement], {tree}, tree], "CountedPositions", Infinity]],
      $Failed :> Throw[$Failed, treeSites]]},
    Replace[SelectFirst[counted, !actsOnQ[name, #] &], t : Except[_Missing] :>
      (refusedPosition[name, t]; Throw[$Failed, treeSites])];
    keptRoot[name, tree, DeleteDuplicates[Join @@ (itemPositions[tree, #] & /@ counted)]]];

refusedPosition["Hide", t_] := Message[HTMLToTree::hidetarget, t];
refusedPosition["Focus", t_] := Message[HTMLToTree::focustarget, t];

(* Hide takes an element, a run of element children, or an element's
   contents; Focus the first two. *)
actsOnQ[_, {__?elementStepQ}] := True;
actsOnQ[_, {___?elementStepQ, Span[m_?elementStepQ, n_Integer]}] := n >= m;
actsOnQ["Hide", {__?elementStepQ, All}] := True;
actsOnQ[_, _] := False;

(* The WL positions of the items at a position, as the walk numbers them *)
itemPositions[tree_, steps : {__?elementStepQ}] := wlPositions[tree, {steps}];
itemPositions[tree_, {steps___, Span[m_, n_]}] := wlPositions[tree, {steps, #} & /@ Range[m, n]];
itemPositions[tree_, {steps__, All}] :=
  With[{p = First[wlPositions[tree, {{steps}}]]}, Join[p, {3, #}] & /@ Range[Length[tree[[Sequence @@ p, 3]]]]];

(* A bare element's root is never hidden: it is kept, with root. *)
keptRoot["Hide", _XMLElement, ps_] /; MemberQ[ps, {}] := (Message[HTMLToTree::root]; DeleteCases[ps, {}]);
keptRoot[_, _, ps_] := ps;

(* ---- The tree that is built ----
   The walk carries each item's position in the input, as the queries give
   them, and each element's DOM depth d: the generations of elements from the
   root, not WL levels. A site is an item with its position. contentNodes
   gives the nodes an item is drawn as: none, one, or (later) several. *)

(* A node's data is the element without its contents, not the whole element,
   so a label function cannot read an element's text from its data. The node's
   children already hold the contents, and an output cell serialises each node's
   data separately: with whole elements, every ancestor carried the page again
   (a 17-node overview was 1 MB of boxes, 49 KB with shells). The shell is part
   of the result's contract, since a computation on the Tree reads it. *)
treeShell[XMLElement[tag_, attrs_, _]] := XMLElement[tag, attrs, {}];

(* The sites of items whose positions start with pos; a Hidden element leaves
   no mark, so it is not one of them. *)
contentSites[items_List, pos_, s_] := visibleSites[MapIndexed[{#1, Join[pos, #2]} &, items], s];

visibleSites[sites_, s_] := Select[sites, !KeyExistsQ[s["Hidden"], Last[#]] &];

childSites[XMLElement[_, _, ch_], pos_, s_] := contentSites[ch, Join[pos, {3}], s];

elementNode[el_XMLElement, pos_, d_, s_] := With[{sites = childSites[el, pos, s]},
  Tree[treeShell[el], Replace[mergedChildren[el, pos, sites, s],
    _Missing :> nodeChildren[sites, pos, d, s, childNodes[sites, d + 1, s] &]]]];

(* The children of a node at position pos and depth d with contents sites. A
   Cut element, at the depth limit with element children, has one Collapsed
   leaf for all its contents, text included, counting the elements in them.
   If they hold a Focused element, they are drawn as the root's are with
   focus: the Focused elements, with the path to them, among Collapsed runs.
   Contents that are only text are kept, since nothing is cut. *)
nodeChildren[sites_, pos_, d_, s_, draw_] := Replace[
  Which[
    d < s["DOMDepth"] || FreeQ[sites, {_XMLElement, _}, {1}], draw[],
    onFocusPathQ[pos, s], nodesOutsideFocus[sites, s],
    True, {Tree[Missing["Collapsed", elementCount[sites, s]], None]}],
  {} -> None];

(* The elements in sites, descendants included and Hidden elements not *)
elementCount[sites_, s_] :=
  Total[Cases[sites, {el_XMLElement, pos_} :> 1 + elementCount[childSites[el, pos, s], s]]];

childNodes[sites_, d_, s_] := Join @@ (contentNodes[#1, #2, d, s] & @@@ sites);

(* A Focused element counts depth from itself, inside another one too *)
contentNodes[el_XMLElement, pos_, d_, s_] := {elementNode[el, pos, If[focusedQ[pos, s], 0, d], s]};
contentNodes[str_String, _, _, s_] := If[drawnTextQ[str, s], {Tree[str, None]}, {}];
contentNodes[XMLObject["CDATASection"][str_String], pos_, d_, s_] := contentNodes[str, pos, d, s];
contentNodes[_, _, _, _] := {};

(* Whether an item is text that is drawn: whitespace-only strings are not,
   unless "IncludeWhitespace" is on. *)
drawnTextQ[str_String, s_] := s["IncludeWhitespace"] || !StringMatchQ[str, "" | HTMLWhitespace];
drawnTextQ[XMLObject["CDATASection"][str_String], s_] := drawnTextQ[str, s];
drawnTextQ[_, _] := False;

(* ---- Merged text ----
   With "MergeText" on, an element whose contents hold at least one element,
   every element in them Inline by Display role, has one Merged text leaf in
   place of its contents; it is decided before depth, so a merged element is
   never a Cut element. An element on a path to a Focused element is not
   merged, so that no Focused element is lost. The text is the chosen
   function's, on the element with its Hidden elements removed. *)

(* The children of a merged element, or Missing[] for one that is not merged.
   Merged text that would not be drawn, empty or whitespace only, is not
   merged either, so that the inline elements keep their nodes. *)
mergedChildren[el_, pos_, sites_, s_] /;
    s["MergeText"] === None || onFocusPathQ[pos, s] || FreeQ[sites, {_XMLElement, _}, {1}] := Missing[];
mergedChildren[el_, pos_, _, s_] := With[{v = visibleElement[markedAt[pos, s], pos, s]},
  If[AllTrue[Cases[Last[v], _XMLElement, Infinity], treeRole[#, s] === "Inline" &],
    Replace[mergedText[s["MergeText"], v, s], {
      text_ /; text =!= "" && drawnTextQ[text, s] :> {Tree[text, None]},
      _ -> Missing[]}],
    Missing[]]];

(* The element at pos as the "Roles" lookup reads it, with the marks of the
   rules that select it and its descendants (ruleLookups). Marks are
   attributes, so its contents are at the same positions. *)
markedAt[pos_, s_] := s["Marked"][[Sequence @@ pos]];

(* The text HTMLInnerText or HTMLTextContent gives for el under the call's
   "Roles" and readings. HTMLInnerText's own walk is run here with HTMLToTree's
   role lookup, so that a roles message is not issued again under
   HTMLInnerText. HTMLToTree has no "BlockSeparator", so HTMLInnerText's is
   used, as a call to it would. *)
mergedText[HTMLInnerText, el_, s_] := innerText[el, treeRole[#, s] &, OptionValue[HTMLInnerText, "BlockSeparator"]];
mergedText[HTMLTextContent, el_, _] := textContentWalk[el];

(* An element's Display role under "Roles", looked up once per call, so that a
   badrole is issued once for an element however often it is asked for. *)
$treeRoles = <||>;
treeRole[el_, s_] := Lookup[$treeRoles, Key[el], $treeRoles[el] = roleOf[el, s["RoleLookup"], HTMLToTree]];

(* el with its Hidden elements removed, at any depth *)
visibleElement[el_, _, s_] /; s["Hidden"] === <||> := el;
visibleElement[el : XMLElement[tag_, attrs_, _], pos_, s_] := XMLElement[tag, attrs,
  Replace[childSites[el, pos, s], {{x_XMLElement, p_} :> visibleElement[x, p, s], {x_, _} :> x}, {1}]];

(* ---- Focus ----
   Outside every Focused element, only the Focused elements are drawn, each
   with its contents and DOM depth counted from it, hung from the nearest drawn
   ancestor by a Collapsed edge when elements were skipped. Everything else
   becomes Collapsed runs, in their places: a run can join elements from
   several depths, and a run of text only counts 0. With "CollapsePaths" ->
   False, the elements on a path to a Focused element are drawn as ordinary
   nodes, at no depth, with their own runs, so a run is of one depth. *)

nodesOutsideFocus[sites_, s_] := collapseRuns[Join @@ (itemsOutsideFocus[#1, #2, {}, s] & @@@ sites)];

(* The items a site gives: a Focused element's node, the node of an element
   on the path to one (or, with collapsed paths, the items below it),
   collapsedRun[k] for k undrawn elements, or none. path holds the undrawn
   elements above. *)
itemsOutsideFocus[el_XMLElement, pos_, path_, s_] := Which[
  focusedQ[pos, s], {collapsedEdge[elementNode[el, pos, 0, s], path]},
  !onFocusPathQ[pos, s], {collapsedRun[elementCount[{{el, pos}}, s]]},
  s["CollapsePaths"],
    Join @@ (itemsOutsideFocus[#1, #2, Append[path, el], s] & @@@ childSites[el, pos, s]),
  True, {Tree[treeShell[el], nodesOutsideFocus[childSites[el, pos, s], s]]}];
itemsOutsideFocus[item_, _, _, s_] := If[drawnTextQ[item, s], {collapsedRun[0]}, {}];

focusedQ[pos_, s_] := AssociationQ[s["Focused"]] && KeyExistsQ[s["Focused"], pos];

(* Whether pos is above a Focused element *)
onFocusPathQ[pos_, s_] := KeyExistsQ[s["FocusPaths"], pos];

collapseRuns[items_] := Replace[SplitBy[items, MatchQ[_collapsedRun]], {
  run : {__collapsedRun} :> Tree[Missing["Collapsed", Total[First /@ run]], None],
  nodes_ :> Sequence @@ nodes}, {1}];

collapsedEdge[t_, {}] := t;
collapsedEdge[t_, path_] := Tree[TreeData[t], TreeChildren[t], ParentEdgeStyle -> Dashed,
  ParentEdgeLabel -> Placed[StringRiffle[compoundSelector /@ path, " > "], Tooltip]];

(* A document or a list is drawn under a "#document" root (ADR 0018), whose
   children are its top elements and top-level strings, at depth 1. The root
   is always drawn, and with focus its contents are outside every Focused
   element. *)
rootNode[XMLObject["Document"][_, root_, _], s_] :=
  Tree["#document", rootChildren[visibleSites[{{root, {2}}}, s], s]];
rootNode[el_XMLElement, s_] /; s["Focused"] === All := elementNode[el, {}, 0, s];
rootNode[el_XMLElement, s_] := Tree[treeShell[el], rootChildren[childSites[el, {}, s], s]];
rootNode[l_List, s_] := Tree["#document", rootChildren[contentSites[l, {}, s], s]];

rootChildren[sites_, s_] /; s["Focused"] === All := nodeChildren[sites, {}, 0, s, childNodes[sites, 1, s] &];
rootChildren[sites_, s_] := Replace[nodesOutsideFocus[sites, s], {} -> None];

(* ---- Labels ----
   One label function for every node, given as All -> treeLabel after the
   user's rules, so that any rule the user gives wins for the nodes it covers.
   A "#document" root is labelled by a {} rule, so that a text leaf that reads
   "#document" is still drawn as text. *)

treeLabel[el : XMLElement[tag_, attrs_, _]] :=
  Tooltip[Style[localName[tag], FontFamily -> "Source Code Pro"],
    Column[{compoundSelector[el],
      If[attrs === {}, "no attributes",
        Grid[{localName[#1], #2} & @@@ attrs, Alignment -> Left]]}]];
treeLabel[str_String] := Tooltip[Style["\"" <> textLabel[str] <> "\"", Italic], str];
treeLabel[Missing["Collapsed", n_]] := Tooltip["\[Ellipsis]", collapsedCount[n]];
treeLabel[x_] := x;

documentLabel[_] := Style["#document", Bold];

localName[{_, name_String}] := name;
localName[name_] := name;

collapsedCount[0] := "text only";
collapsedCount[1] := "1 element";
collapsedCount[n_] := ToString[n] <> " elements";

$textLabelLength = 40;

(* Runs of HTML whitespace collapsed and the ends trimmed, then cut to 40
   characters; a no-break space is not HTML whitespace, so it is kept. *)
textLabel[str_String] :=
  With[{t = StringTrim[StringReplace[str, HTMLWhitespace -> " "], HTMLWhitespace]},
    If[StringLength[t] > $textLabelLength,
      StringTrim[StringTake[t, $textLabelLength], HTMLWhitespace] <> "\[Ellipsis]", t]];

(* tag#id.class..., each part escaped as CSS.escape does, so that the result
   is a selector for the element. *)
compoundSelector[XMLElement[tag_, attrs_, _]] := StringJoin[
  cssEscape[localName[tag]],
  Replace[Lookup[attrs, "id", ""], {"" -> "", id_String :> "#" <> cssEscape[id], _ -> ""}],
  "." <> cssEscape[#] & /@ classList[Replace[Lookup[attrs, "class", ""], Except[_String] -> ""]]];

cssEscape[s_String] := StringJoin[MapIndexed[cssEscapeChar[#1, First[#2], s] &, Characters[s]]];

cssEscapeChar[c_, _, _] /; c === FromCharacterCode[0] := "\:fffd";
cssEscapeChar[c_, i_, s_] := Which[
  StringMatchQ[c, RegularExpression["[\\x01-\\x1f\\x7f]"]] ||
    (StringMatchQ[c, DigitCharacter] && (i == 1 || (i == 2 && StringTake[s, 1] == "-"))),
    "\\" <> IntegerString[ToCharacterCode[c][[1]], 16] <> " ",
  i == 1 && c == "-" && StringLength[s] == 1, "\\-",
  ToCharacterCode[c][[1]] >= 128 || StringMatchQ[c, RegularExpression["[A-Za-z0-9_-]"]], c,
  True, "\\" <> c];

(* The user's label settings, as one rule list that the default is appended
   to. A bare function applies to the root only, which {} -> f says in a list.
   TreeElementLabel is read as constant functions after the user's functions,
   since a label function overrides TreeElementLabel. *)
labelRules[None] := {All -> None};
labelRules[Automatic] := {All -> Automatic};
labelRules[r : (_Rule | _RuleDelayed)] := {r};
labelRules[l_List] := l;
labelRules[f_] := {{} -> f};

constantLabels[rules_List] := Replace[rules,
  (h : Rule | RuleDelayed)[k_, v : Except[None | Automatic]] :> h[k, Function[v]], {1}];

(* ---- Sizing ----
   An ImageSize computed from the tree as displayed: only the children that
   MaxDisplayedChildren shows count, plus the "N total" node for the rest.
   For Left, the height comes from the displayed leaves and the width from the
   number of levels and the widest label at each; for a top-down layout, the
   width is about 60 points per displayed leaf (Bottom too). Any other layout sizes itself. *)

$leafHeight = 24;
$charWidth = 7;
$levelGap = 24;
$topDownLeafWidth = 60;

treeImageSize[t_, Left, mdc_] :=
  With[{widths = $charWidth Values[KeySort[GroupBy[displayedNodes[t, {}, mdc], First -> Last, Max]]]},
    {Round[levelSpacing[widths] (Length[widths] - 1) + (First[widths] + Last[widths])/2 + $levelGap],
      $leafHeight displayedLeaves[t, {}, mdc]}];

(* Tree spaces the levels evenly, so the space between two levels must fit the
   widest pair of neighbouring labels. *)
levelSpacing[{_}] := 0;
levelSpacing[widths_] := Max[MovingAverage[widths, 2]] + $levelGap;
treeImageSize[t_, Automatic | Top | Bottom, mdc_] := $topDownLeafWidth displayedLeaves[t, {}, mdc];
treeImageSize[_, _, _] := Automatic;

(* The number of children shown at position pos: TreeCases rules first, then
   position rules (All among them), the first that applies winning, as in Tree. *)
displayedCount[t_, pos_, rules_] := Replace[
  FirstCase[rules, _[TreeCases[p_], m_] /; MatchQ[TreeData[t], p] :> m,
    FirstCase[rules, _[k : Except[_TreeCases], m_] /; k === All || MatchQ[pos, k] :> m,
      $MaxDisplayedChildren]],
  All -> Infinity];

(* The children shown, with their positions, and whether some are not *)
shownChildren[t_, pos_, rules_] :=
  With[{cs = Replace[TreeChildren[t], None -> {}], m = displayedCount[t, pos, rules]},
    {Take[MapIndexed[{#1, Join[pos, #2]} &, cs], UpTo[m]], Length[cs] > m}];

displayedLeaves[t_, pos_, rules_] := Replace[shownChildren[t, pos, rules], {
  {{}, False} -> 1,
  {shown_, more_} :> Total[displayedLeaves[#1, #2, rules] & @@@ shown] + Boole[more]}];

(* {level, label width in characters} for each displayed node *)
displayedNodes[t_, pos_, rules_] := With[{sc = shownChildren[t, pos, rules], d = Length[pos]},
  Join[{{d, labelWidth[TreeData[t]]}},
    Join @@ (displayedNodes[#1, #2, rules] & @@@ First[sc]),
    If[Last[sc], {{d + 1, $totalLabelWidth}}, {}]]];

$totalLabelWidth = 8;

labelWidth[XMLElement[tag_, _, _]] := StringLength[localName[tag]];
labelWidth[str_String] := StringLength[textLabel[str]] + 2;
labelWidth[_] := 1;

(* ---- Tree options ----
   A bare MaxDisplayedChildren -> m becomes {All -> m}, so that it limits every
   node; a rule or a list is passed as given. The user's label settings and
   the default become one TreeElementLabelFunction. TreeLayout -> Left and the computed ImageSize are
   added when the user gives none. A computed {width, height} comes with its
   AspectRatio: Tree keeps the layout's own one otherwise, and draws it in the
   middle of the image. *)

maxDisplayedSetting[m : Except[_List | _Rule | _RuleDelayed]] := {All -> m};
maxDisplayedSetting[m_] := m;

treeOptions[t_, opts_List] := Module[{given, mdc, layout, labels},
  given = Select[Flatten[opts], treeOptionNameQ[First[#]] &];
  mdc = Flatten[Cases[given, _[MaxDisplayedChildren, m_] :> maxDisplayedSetting[m]]];
  layout = FirstCase[given, _[TreeLayout, l_] :> l, Left];
  labels = Join[
    Join @@ Cases[given, _[TreeElementLabelFunction, f_] :> labelRules[f]],
    Join @@ Cases[given, _[TreeElementLabel, l_] :> constantLabels[labelRules[l]]],
    If[TreeData[t] === "#document", {{} -> documentLabel}, {}],
    {All -> treeLabel}];
  Join[
    Replace[DeleteCases[given, _[TreeElementLabelFunction | TreeElementLabel, _]],
      _[MaxDisplayedChildren, m_] :> (MaxDisplayedChildren -> maxDisplayedSetting[m]), {1}],
    {TreeElementLabelFunction -> labels},
    If[MemberQ[Keys[given], TreeLayout], {}, {TreeLayout -> Left}],
    If[MemberQ[Keys[given], ImageSize], {},
      Replace[treeImageSize[t, layout, mdc], {
        Automatic -> {},
        {w_, h_} :> {ImageSize -> {w, h},
          If[MemberQ[Keys[given], AspectRatio], Nothing, AspectRatio -> h/w]},
        w_ :> {ImageSize -> w}}]]]];

(* ---- Public interface ----
   A depth is never a rule, so a rule after the tree is always an option. An
   option neither HTMLToTree's nor Tree's gives optx, and the call stays
   unevaluated, as a wrong argument count does. *)

notRuleQ[a_] := !MatchQ[a, _Rule | _RuleDelayed | {(_Rule | _RuleDelayed) ..}];

HTMLToTree[tree_, n : _?notRuleQ : Infinity, opts : OptionsPattern[]] /;
    countQ[n] && unknownTreeOptions[{opts}] === {} :=
  If[!validTreeQ[tree], messageTreeRefusal[HTMLToTree, tree]; $Failed,
    Replace[treeSettings[AssociationThread[Keys[Options[HTMLToTree]], OptionValue[HTMLToTree,
        FilterRules[{opts}, Options[HTMLToTree]], Keys[Options[HTMLToTree]]]]], {
      $Failed -> $Failed,
      settings_ :> withReadings[settings["AttributeReadings"], drawnTree[tree, n, settings, {opts}]]}]];

HTMLToTree[args___] /; (treeCallMessage[{args}]; False) := Null;

(* The Tree for settings s, under the readings in force. "Roles" is checked on
   every call, merging or not, then both queries. *)
drawnTree[tree_, n_, s_, opts_] := Replace[ruleLookups[{s["Roles"]}, HTMLToTree, tree], {
  $Failed -> $Failed,
  {marked_, {roles_}} :> Replace[treeSites[tree, s], {
    $Failed -> $Failed,
    sites_ :> Block[{$treeRoles = <||>},
      With[{drawn = rootNode[tree, Join[s, sites, <|"DOMDepth" -> n, "RoleLookup" -> roles, "Marked" -> marked|>]]},
        Tree[TreeData[drawn], TreeChildren[drawn], Sequence @@ treeOptions[drawn, opts]]]]}]}];

(* A depth that is not valid gives innf, as XMLCases's count does (ADR 0019),
   before any unknown option after it. *)
treeCallMessage[{tree_, n_?notRuleQ, opts___}] /; !countQ[n] && NoneTrue[{opts}, notRuleQ] :=
  Message[HTMLToTree::innf, Unevaluated[HTMLToTree[tree, n, opts]], 2];
treeCallMessage[args : {tree_, rest___}] :=
  Replace[unknownTreeOptions[Select[{rest}, !notRuleQ[#] &]], {
    {} :> countMessage[HTMLToTree, args, {1, 2}],
    {first_, ___} :> Message[HTMLToTree::optx, First[first], Unevaluated[HTMLToTree[tree, rest]]]}];
treeCallMessage[args_] := countMessage[HTMLToTree, args, {1, 2}];
