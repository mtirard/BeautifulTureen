(* HTMLToTree: an HTML/XML tree drawn as a Tree. The result is judged as data,
   not as pixels: shape turns a Tree into nested data (data -> {children} for a
   node with children, the bare data for a leaf), and the options handed to Tree
   are read with Options. Exact ImageSize numbers and label boxes are not
   compared. The helpers are local to this file. *)

shape[t_Tree] := Replace[TreeChildren[t], {None -> TreeData[t], cs_ :> TreeData[t] -> (shape /@ cs)}];

(* An element shell, as an element node's data *)
e[tag_, attrs_ : {}] := XMLElement[tag, attrs, {}];

htmlBody[h_String] := FirstCase[ImportString[h, {"HTML", "XMLObject"}],
  XMLElement["body", __], Missing[], Infinity];

(* ---- Inputs ---- *)

(* A document gets a "#document" root above its root element. *)
TestCreate[
  shape[HTMLToTree[ImportString["<p>Hi</p>", {"HTML", "XMLObject"}]]],
  "#document" -> {e["html", {{"http://www.w3.org/2000/xmlns/", "xmlns"} -> "http://www.w3.org/1999/xhtml"}] -> {
    e["body"] -> {e["p"] -> {"Hi"}}}},
  TestID -> "htt-document-root"
];

(* A bare element is its own root. An element with no contents is a leaf, and
   whitespace-only strings are left out. *)
TestCreate[
  shape[HTMLToTree[XMLElement["ul", {}, {"\n  ", XMLElement["li", {}, {"a"}], " ", XMLElement["li", {}, {}], "\n"}]]],
  e["ul"] -> {e["li"] -> {"a"}, e["li"]},
  TestID -> "htt-element-root"
];

(* A list gets a "#document" root with its elements and strings as children. *)
TestCreate[
  shape[HTMLToTree[{XMLElement["p", {}, {"x"}], "tail", "  "}]],
  "#document" -> {e["p"] -> {"x"}, "tail"},
  TestID -> "htt-list-root"
];

TestCreate[
  shape[HTMLToTree[{}]],
  "#document",
  TestID -> "htt-empty-list-root"
];

(* An element node's data is the element shell: tag and attributes, no
   contents. A text node's data is the raw string, not its label. *)
TestCreate[
  TreeData /@ TreeChildren[HTMLToTree[
    XMLElement["p", {}, {"  Some\n  text  ", XMLElement["a", {"href" -> "x"}, {"link"}]}]]],
  {"  Some\n  text  ", XMLElement["a", {"href" -> "x"}, {}]},
  TestID -> "htt-node-data"
];

(* CDATA is text; comments, processing instructions and the prolog and epilog
   are dropped. *)
TestCreate[
  shape[HTMLToTree[XMLObject["Document"][{XMLObject["Comment"]["c"]},
    XMLElement["p", {}, {XMLObject["CDATASection"]["a<b"], XMLObject["Comment"]["d"],
      XMLObject["ProcessingInstruction"]["x", "y"], "c"}],
    {XMLObject["Comment"]["e"]}]]],
  "#document" -> {e["p"] -> {"a<b", "c"}},
  TestID -> "htt-cdata-text-comments-dropped"
];

(* ---- Whitespace ---- *)

$wsTree = XMLElement["div", {}, {"\n  ", XMLElement["pre", {}, {"\n\t"}], "\[NonBreakingSpace]", " x "}];

(* HTML whitespace only is dropped everywhere, pre included; a no-break space
   is not HTML whitespace. *)
TestCreate[
  shape[HTMLToTree[$wsTree]],
  e["div"] -> {e["pre"], "\[NonBreakingSpace]", " x "},
  TestID -> "htt-whitespace-dropped"
];

TestCreate[
  shape[HTMLToTree[$wsTree, "IncludeWhitespace" -> True]],
  e["div"] -> {"\n  ", e["pre"] -> {"\n\t"}, "\[NonBreakingSpace]", " x "},
  TestID -> "htt-include-whitespace"
];

TestCreate[
  shape[HTMLToTree[$wsTree, "IncludeWhitespace" -> False]],
  shape[HTMLToTree[$wsTree]],
  TestID -> "htt-include-whitespace-false-is-default"
];

(* ---- The default tree for the comparison input ----
   Configuration 1 of the prototype's comparison. *)

$cmpBody = htmlBody["<body>
  <nav><a>Home</a> <a>About</a></nav>
  <main>
    <h1>Title</h1>
    <section id=\"a\">
      <h2>Intro</h2>
      <p>Some <b>bold</b> text</p>
      <div>
        <aside><section id=\"b\"><h2>Note</h2></section></aside>
        <p>More</p>
      </div>
    </section>
    <div class=\"ad\"><p>Buy</p></div>
  </main>
  <footer><p>Fine print</p></footer>
</body>"];

(* The HTML importer gives an a element a default shape attribute. *)
$rect = {"shape" -> "rect"};

TestCreate[
  shape[HTMLToTree[$cmpBody]],
  e["body"] -> {
    e["nav"] -> {e["a", $rect] -> {"Home"}, e["a", $rect] -> {"About"}},
    e["main"] -> {
      e["h1"] -> {"Title"},
      e["section", {"id" -> "a"}] -> {
        e["h2"] -> {"Intro"},
        e["p"] -> {"Some ", e["b"] -> {"bold"}, " text"},
        e["div"] -> {
          e["aside"] -> {e["section", {"id" -> "b"}] -> {e["h2"] -> {"Note"}}},
          e["p"] -> {"More"}}},
      e["div", {"class" -> "ad"}] -> {e["p"] -> {"Buy"}}},
    e["footer"] -> {e["p"] -> {"Fine print"}}},
  TestID -> "htt-comparison-defaults"
];

(* A real page: one element node per element. *)
TestCreate[
  Length[TreeCases[HTMLToTree[$realTree], _XMLElement]],
  Count[$realTree, _XMLElement, Infinity],
  TestID -> "htt-real-page-element-count"
];

(* ---- Options ---- *)

TestCreate[
  Options[HTMLToTree],
  {"Focus" -> Automatic, "Hide" -> Automatic, "MergeText" -> Automatic,
    "IncludeWhitespace" -> Automatic, "CollapsePaths" -> Automatic, "Roles" -> Automatic,
    "AttributeReadings" -> Automatic},
  TestID -> "htt-options"
];

TestCreate[
  Lookup[SyntaxInformation[HTMLToTree], {"ArgumentsPattern", "OptionNames"}],
  {{_, _., OptionsPattern[]},
    Join[Keys[Options[HTMLToTree]], ToString /@ Keys[Options[Tree]]]},
  TestID -> "htt-syntax-information"
];

(* A Tree option is passed through as given. *)
TestCreate[
  Lookup[Options[HTMLToTree[XMLElement["p", {}, {}], TreeElementStyle -> Red, ParentEdgeStyle -> Dashed]],
    {TreeElementStyle, ParentEdgeStyle}],
  {Red, Dashed},
  TestID -> "htt-tree-options-pass-through"
];

(* A depth with Tree options after it: the options are not counted as
   arguments. *)
TestCreate[
  Head[HTMLToTree[XMLElement["p", {}, {}], Infinity, TreeLayout -> Top, ImageSize -> 100]],
  Tree,
  TestID -> "htt-depth-and-tree-options"
];

(* Accepted values of the options checked so far *)
TestCreate[
  Head /@ {HTMLToTree[$wsTree, "MergeText" -> HTMLInnerText], HTMLToTree[$wsTree, "MergeText" -> None],
    HTMLToTree[$wsTree, "CollapsePaths" -> False], HTMLToTree[$wsTree, "IncludeWhitespace" -> Automatic]},
  {Tree, Tree, Tree, Tree},
  TestID -> "htt-accepted-option-values"
];

(* ---- Tree options handed to Tree ---- *)

treeOption[t_Tree, name_] := Lookup[Options[t], name, Missing[]];

TestCreate[
  treeOption[HTMLToTree[$cmpBody], TreeLayout],
  Left,
  TestID -> "htt-layout-left"
];

TestCreate[
  Cases[Options[HTMLToTree[$cmpBody, TreeLayout -> Automatic]], _[TreeLayout, _]],
  {TreeLayout -> Automatic},
  TestID -> "htt-user-layout-wins"
];

TestCreate[
  treeOption[HTMLToTree[$cmpBody, MaxDisplayedChildren -> 3], MaxDisplayedChildren],
  {All -> 3},
  TestID -> "htt-max-displayed-children-bare"
];

TestCreate[
  treeOption[#, MaxDisplayedChildren] & /@ {
    HTMLToTree[$cmpBody, MaxDisplayedChildren -> {{1} -> 2, All -> 3}],
    HTMLToTree[$cmpBody, MaxDisplayedChildren -> (All -> 4)]},
  {{{1} -> 2, All -> 3}, All -> 4},
  TestID -> "htt-max-displayed-children-as-given"
];

(* A computed ImageSize, {width, height} for the Left layout *)
TestCreate[
  MatchQ[treeOption[HTMLToTree[$cmpBody], ImageSize], {_?Positive, _?Positive}],
  True,
  TestID -> "htt-image-size-computed"
];

(* The computed size comes with its aspect ratio, so that the layout fills it. *)
TestCreate[
  Lookup[Options[HTMLToTree[$cmpBody]], {ImageSize, AspectRatio}] /. {{w_, h_}, r_} :> r == h/w,
  True,
  TestID -> "htt-image-size-aspect-ratio"
];

TestCreate[
  Cases[Options[HTMLToTree[$cmpBody, ImageSize -> 300]], _[ImageSize | AspectRatio, _]],
  {ImageSize -> 300},
  TestID -> "htt-user-image-size-wins"
];

TestCreate[
  Cases[Options[HTMLToTree[$cmpBody, AspectRatio -> 1]], _[AspectRatio, _]],
  {AspectRatio -> 1},
  TestID -> "htt-user-aspect-ratio-wins"
];

(* Top-down: a width only. Another layout sizes itself. *)
TestCreate[
  {NumericQ[treeOption[HTMLToTree[$cmpBody, TreeLayout -> Top], ImageSize]],
    treeOption[HTMLToTree[$cmpBody, TreeLayout -> "RadialEmbedding"], ImageSize]},
  {True, Missing[]},
  TestID -> "htt-image-size-other-layouts"
];

(* Only displayed leaves count: 30 items shown 10 at a time, with the
   "30 total" node, are as tall as 11 items shown in full. *)
$items[k_] := XMLElement["ul", {}, Table[XMLElement["li", {}, {}], k]];

TestCreate[
  Last[treeOption[HTMLToTree[$items[30]], ImageSize]],
  Last[treeOption[HTMLToTree[$items[11], MaxDisplayedChildren -> Infinity], ImageSize]],
  TestID -> "htt-image-size-counts-displayed-leaves"
];

TestCreate[
  Last[treeOption[HTMLToTree[$items[30], MaxDisplayedChildren -> 3], ImageSize]] <
    Last[treeOption[HTMLToTree[$items[30]], ImageSize]] <
    Last[treeOption[HTMLToTree[$items[30], MaxDisplayedChildren -> Infinity], ImageSize]],
  True,
  TestID -> "htt-image-size-follows-max-displayed-children"
];

(* ---- Labels ----
   The default is one All rule after the user's rules, so that any rule the
   user gives wins for the nodes it covers. *)

labelRules[t_Tree] := treeOption[t, TreeElementLabelFunction];
defaultLabel[t_Tree] := Last[labelRules[t]][[2]];

TestCreate[
  First /@ labelRules[HTMLToTree[$cmpBody]],
  {All},
  TestID -> "htt-labels-one-all-rule"
];

TestCreate[
  First /@ labelRules[HTMLToTree[{XMLElement["p", {}, {}]}]],
  {{}, All},
  TestID -> "htt-labels-document-root"
];

TestCreate[
  Most[labelRules[HTMLToTree[$cmpBody,
    TreeElementLabelFunction -> {"Leaves" -> ToUpperCase, TreeCases[_String] -> f}]]],
  {"Leaves" -> ToUpperCase, TreeCases[_String] -> f},
  TestID -> "htt-labels-user-rules-first"
];

TestCreate[
  Most[labelRules[HTMLToTree[$cmpBody, TreeElementLabelFunction -> All -> g]]],
  {All -> g},
  TestID -> "htt-labels-user-all-first"
];

(* A bare function labels the root only, as in Tree; None and Automatic apply
   to every node. *)
TestCreate[
  Most[labelRules[HTMLToTree[$cmpBody, TreeElementLabelFunction -> #]]] & /@ {g, None, Automatic},
  {{{} -> g}, {All -> None}, {All -> Automatic}},
  TestID -> "htt-labels-user-bare-none-automatic"
];

(* TreeElementLabel is kept: a label function would override it. *)
TestCreate[
  Through[Map[Last, Most[labelRules[HTMLToTree[$cmpBody, TreeElementLabel -> {"Leaves" -> "X"}]]]][0]],
  {"X"},
  TestID -> "htt-labels-tree-element-label-kept"
];

(* Element: the tag name, with the compound selector and attributes in a
   tooltip. *)
$labelled = XMLElement["div", {"id" -> "main", "class" -> "note  wide"}, {}];

TestCreate[
  Replace[defaultLabel[HTMLToTree[$cmpBody]][$labelled],
    Tooltip[Style[tag_, ___], Column[{sel_, _}]] :> {tag, sel}],
  {"div", "div#main.note.wide"},
  TestID -> "htt-label-element"
];

TestCreate[
  Replace[defaultLabel[HTMLToTree[$cmpBody]][XMLElement["br", {}, {}]],
    Tooltip[_, Column[{sel_, attrs_}]] :> {sel, attrs}],
  {"br", "no attributes"},
  TestID -> "htt-label-element-no-attributes"
];

(* The selector is CSS-escaped, so that it selects the element. *)
$escaped = XMLElement["p", {"id" -> "1a", "class" -> "a:b -2"}, {}];

TestCreate[
  With[{sel = Replace[defaultLabel[HTMLToTree[$cmpBody]][$escaped], Tooltip[_, Column[{s_, _}]] :> s]},
    {sel, XMLMatchQ[$escaped, sel]}],
  {"p#\\31 a.a\\:b.-\\32 ", True},
  TestID -> "htt-label-selector-escaped"
];

(* Text: whitespace collapsed and trimmed, cut to 40 characters, quoted, with
   the full string in the tooltip. A no-break space is kept. *)
textLabelParts[s_String] := Replace[defaultLabel[HTMLToTree[$cmpBody]][s],
  Tooltip[Style[label_, ___], tip_] :> {label, tip}];

TestCreate[
  textLabelParts["\n  Some\t\ttext \n"],
  {"\"Some text\"", "\n  Some\t\ttext \n"},
  TestID -> "htt-label-text-collapsed"
];

TestCreate[
  First[textLabelParts[StringRepeat["abcde", 9]]],
  "\"" <> StringRepeat["abcde", 8] <> "\[Ellipsis]\"",
  TestID -> "htt-label-text-truncated"
];

TestCreate[
  First[textLabelParts[StringRepeat["abcde", 8]]],
  "\"" <> StringRepeat["abcde", 8] <> "\"",
  TestID -> "htt-label-text-forty-kept"
];

TestCreate[
  First[textLabelParts["\[NonBreakingSpace]x "]],
  "\"\[NonBreakingSpace]x\"",
  TestID -> "htt-label-text-keeps-no-break-space"
];

(* Collapsed leaf: a plain ellipsis, with the count in the tooltip *)
TestCreate[
  defaultLabel[HTMLToTree[$cmpBody]] /@ {Missing["Collapsed", 3], Missing["Collapsed", 1]},
  {Tooltip["\[Ellipsis]", "3 elements"], Tooltip["\[Ellipsis]", "1 element"]},
  TestID -> "htt-label-collapsed"
];

(* ---- Messages ----
   Captured as a reader sees them, as in Messages.wlt. *)

SetAttributes[capturedMessages, HoldFirst];
capturedMessages[expr_] := Module[{texts = {}},
  Internal`HandlerBlock[
    {"Message", Function[m,
      Replace[m, Hold[Message[mn : MessageName[_, _], args___], _] :>
        AppendTo[texts, ToString[
          StringForm[messageText[mn], Sequence @@ (List @@ Map[
            Function[a, ToString[Unevaluated[a], InputForm], HoldAllComplete],
            Hold[args]])],
          OutputForm, PageWidth -> Infinity]]]]},
    Quiet[expr]];
  texts];

SetAttributes[messageText, HoldFirst];
messageText[MessageName[s_, tag_]] :=
  Replace[MessageName[s, tag], _MessageName :> MessageName[General, tag]];

SetAttributes[withMessages, HoldFirst];
withMessages[expr_] := Module[{r}, {capturedMessages[r = expr], r}];

$p = XMLElement["p", {}, {}];

TestCreate[
  withMessages[HTMLToTree["<p>x</p>"]],
  {{"The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head String."}, $Failed},
  TestID -> "htt-message-badtree-string"
];

TestCreate[
  withMessages[HTMLToTree[{$p, 3}]],
  {{"A list given as the first argument should hold only XMLElement expressions and strings. The member at position 2 has head Integer."}, $Failed},
  TestID -> "htt-message-badmember"
];

TestCreate[
  Replace[withMessages[HTMLToTree[$p, Foo -> 1]], {m_, r_} :> {m, Head[r], List @@ r}],
  {{"Unknown option Foo in HTMLToTree[XMLElement[\"p\", {}, {}], Foo -> 1]."}, HTMLToTree, {$p, Foo -> 1}},
  TestID -> "htt-message-optx"
];

TestCreate[
  {Head[#], Length[#]} &[HTMLToTree[$p, Infinity, "Fokus" -> "p", TreeLayout -> Top]],
  {HTMLToTree, 4},
  {HTMLToTree::optx},
  TestID -> "htt-message-optx-unevaluated"
];

TestCreate[
  withMessages[HTMLToTree[$p, #1 -> #2]] & @@@ {
    {"IncludeWhitespace", 1}, {"CollapsePaths", "yes"}, {"MergeText", ToUpperCase}},
  {{{"The value of the \"IncludeWhitespace\" option should be True | False | Automatic. Got 1."}, $Failed},
    {{"The value of the \"CollapsePaths\" option should be True | False | Automatic. Got \"yes\"."}, $Failed},
    {{"The value of the \"MergeText\" option should be None | HTMLInnerText | HTMLTextContent | Automatic. Got ToUpperCase."}, $Failed}},
  TestID -> "htt-message-optval"
];

TestCreate[
  capturedMessages[HTMLToTree[]],
  {"HTMLToTree called with 0 arguments; 1 or 2 arguments are expected."},
  TestID -> "htt-message-count-none"
];

TestCreate[
  {capturedMessages[HTMLToTree[$p, 1, 2, TreeLayout -> Top]], Head[Quiet[HTMLToTree[$p, 1, 2]]]},
  {{"HTMLToTree called with 3 arguments; 1 or 2 arguments are expected."}, HTMLToTree},
  TestID -> "htt-message-count-tree-options-not-counted"
];
