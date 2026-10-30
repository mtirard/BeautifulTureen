(* HTMLToTree: an HTML/XML tree drawn as a Tree. The result is judged as data,
   not as pixels: shape turns a Tree into nested data (data -> {children} for a
   node with children, the bare data for a leaf), and the options handed to Tree
   are read with Options. Exact ImageSize numbers and label boxes are not
   compared. shape and shell are in Support/Fixtures.wl. *)

htmlBody[h_String] := FirstCase[ImportString[h, {"HTML", "XMLObject"}],
  XMLElement["body", __], Missing[], Infinity];

(* Messages captured as a reader sees them, as in Messages.wlt *)
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

(* ---- Inputs ---- *)

(* A document gets a "#document" root above its root element. *)
TestCreate[
  shape[HTMLToTree[ImportString["<p>Hi</p>", {"HTML", "XMLObject"}]]],
  "#document" -> {shell["html", {{"http://www.w3.org/2000/xmlns/", "xmlns"} -> "http://www.w3.org/1999/xhtml"}] -> {
    shell["body"] -> {shell["p"] -> {"Hi"}}}},
  TestID -> "htt-document-root"
];

(* A bare element is its own root. An element with no contents is a leaf, and
   whitespace-only strings are left out. *)
TestCreate[
  shape[HTMLToTree[XMLElement["ul", {}, {"\n  ", XMLElement["li", {}, {"a"}], " ", XMLElement["li", {}, {}], "\n"}]]],
  shell["ul"] -> {shell["li"] -> {"a"}, shell["li"]},
  TestID -> "htt-element-root"
];

(* A list gets a "#document" root with its elements and strings as children. *)
TestCreate[
  shape[HTMLToTree[{XMLElement["p", {}, {"x"}], "tail", "  "}]],
  "#document" -> {shell["p"] -> {"x"}, "tail"},
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
  "#document" -> {shell["p"] -> {"a<b", "c"}},
  TestID -> "htt-cdata-text-comments-dropped"
];

(* ---- Whitespace ---- *)

$wsTree = XMLElement["div", {}, {"\n  ", XMLElement["pre", {}, {"\n\t"}], "\[NonBreakingSpace]", " x "}];

(* HTML whitespace only is dropped everywhere, pre included; a no-break space
   is not HTML whitespace. *)
TestCreate[
  shape[HTMLToTree[$wsTree]],
  shell["div"] -> {shell["pre"], "\[NonBreakingSpace]", " x "},
  TestID -> "htt-whitespace-dropped"
];

TestCreate[
  shape[HTMLToTree[$wsTree, "IncludeWhitespace" -> True]],
  shell["div"] -> {"\n  ", shell["pre"] -> {"\n\t"}, "\[NonBreakingSpace]", " x "},
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
  shell["body"] -> {
    shell["nav"] -> {shell["a", $rect] -> {"Home"}, shell["a", $rect] -> {"About"}},
    shell["main"] -> {
      shell["h1"] -> {"Title"},
      shell["section", {"id" -> "a"}] -> {
        shell["h2"] -> {"Intro"},
        shell["p"] -> {"Some ", shell["b"] -> {"bold"}, " text"},
        shell["div"] -> {
          shell["aside"] -> {shell["section", {"id" -> "b"}] -> {shell["h2"] -> {"Note"}}},
          shell["p"] -> {"More"}}},
      shell["div", {"class" -> "ad"}] -> {shell["p"] -> {"Buy"}}},
    shell["footer"] -> {shell["p"] -> {"Fine print"}}},
  TestID -> "htt-comparison-defaults"
];

(* A real page: one element node per element. *)
TestCreate[
  Length[TreeCases[HTMLToTree[$realTree], _XMLElement]],
  Count[$realTree, _XMLElement, Infinity],
  TestID -> "htt-real-page-element-count"
];

(* ---- Depth ----
   DOM depth counts generations of elements from the root. A Cut element (at
   depth n, with element children) has one Collapsed leaf for all its
   contents, counting the elements not drawn. *)

collapsed[k_] := Missing["Collapsed", k];

(* Configuration 2 of the prototype's comparison: depth 1 *)
TestCreate[
  shape[HTMLToTree[$cmpBody, 1]],
  shell["body"] -> {shell["nav"] -> {collapsed[2]}, shell["main"] -> {collapsed[12]}, shell["footer"] -> {collapsed[1]}},
  TestID -> "htt-depth-one-comparison"
];

(* Text has its element's depth: an element at the limit whose contents are
   only text keeps them, and one with an element among them is cut, its text
   with it. The count is of every element below, not just the children. *)
$depthTree = XMLElement["div", {}, {
  XMLElement["h1", {}, {"Title"}],
  XMLElement["p", {}, {"Some ", XMLElement["b", {}, {XMLElement["i", {}, {"x"}]}], " text"}],
  XMLElement["hr", {}, {}],
  "tail"}];

TestCreate[
  shape[HTMLToTree[$depthTree, 1]],
  shell["div"] -> {shell["h1"] -> {"Title"}, shell["p"] -> {collapsed[2]}, shell["hr"], "tail"},
  TestID -> "htt-depth-text-kept-cut-counted"
];

TestCreate[
  shape[HTMLToTree[$depthTree, 2]],
  shell["div"] -> {shell["h1"] -> {"Title"}, shell["p"] -> {"Some ", shell["b"] -> {collapsed[1]}, " text"}, shell["hr"], "tail"},
  TestID -> "htt-depth-two"
];

(* Depth 0: the root with one Collapsed leaf, for an element, a document and a
   list. A root whose contents are only text keeps them. *)
TestCreate[
  shape /@ {HTMLToTree[$depthTree, 0],
    HTMLToTree[ImportString["<p>Hi</p>", {"HTML", "XMLObject"}], 0],
    HTMLToTree[{XMLElement["p", {}, {"x"}], "tail"}, 0],
    HTMLToTree[XMLElement["p", {}, {"x"}], 0],
    HTMLToTree[{"x"}, 0]},
  {shell["div"] -> {collapsed[5]}, "#document" -> {collapsed[3]}, "#document" -> {collapsed[1]},
    shell["p"] -> {"x"}, "#document" -> {"x"}},
  TestID -> "htt-depth-zero"
];

(* Infinity, as when n is omitted, draws everything; so does a depth beyond the
   deepest element. *)
TestCreate[
  SameQ @@ shape /@ {HTMLToTree[$cmpBody], HTMLToTree[$cmpBody, Infinity], HTMLToTree[$cmpBody, 6]},
  True,
  TestID -> "htt-depth-infinity-everything"
];

(* ---- Hide ----
   Hidden elements are removed with their contents and leave no mark. The
   query is matched against the original input. *)

(* Configuration 3 of the prototype's comparison *)
TestCreate[
  shape[HTMLToTree[$cmpBody, "Hide" -> ".ad"]],
  shell["body"] -> {
    shell["nav"] -> {shell["a", $rect] -> {"Home"}, shell["a", $rect] -> {"About"}},
    shell["main"] -> {
      shell["h1"] -> {"Title"},
      shell["section", {"id" -> "a"}] -> {
        shell["h2"] -> {"Intro"},
        shell["p"] -> {"Some ", shell["b"] -> {"bold"}, " text"},
        shell["div"] -> {
          shell["aside"] -> {shell["section", {"id" -> "b"}] -> {shell["h2"] -> {"Note"}}},
          shell["p"] -> {"More"}}}},
    shell["footer"] -> {shell["p"] -> {"Fine print"}}},
  TestID -> "htt-hide-comparison"
];

(* Queries see the original input: hiding each li after another hides the
   second and third, not just the second, as it would if the second were
   removed first; and :has() sees a b that is itself hidden. *)
$list3 = XMLElement["ul", {}, {XMLElement["li", {}, {"1"}], XMLElement["li", {}, {"2"}],
  XMLElement["li", {}, {"3"}]}];

TestCreate[
  shape[HTMLToTree[$list3, "Hide" -> (XMLPattern["ul"][{___, XMLPattern["li"], x : XMLPattern["li"], ___}] :> x)]],
  shell["ul"] -> {shell["li"] -> {"1"}},
  TestID -> "htt-hide-adjacent-original-input"
];

TestCreate[
  shape[HTMLToTree[XMLElement["div", {}, {XMLElement["p", {}, {XMLElement["b", {}, {}], "x"}],
      XMLElement["p", {}, {"y"}]}], "Hide" -> "b, p:has(b)"]],
  shell["div"] -> {shell["p"] -> {"y"}},
  TestID -> "htt-hide-has-original-input"
];

(* A Hidden element leaves no mark, in a Cut element's count too *)
TestCreate[
  shape[HTMLToTree[$depthTree, 1, "Hide" -> "i"]],
  shell["div"] -> {shell["h1"] -> {"Title"}, shell["p"] -> {collapsed[1]}, shell["hr"], "tail"},
  TestID -> "htt-hide-not-counted-at-cut"
];

TestCreate[
  shape[HTMLToTree[$depthTree, 1, "Hide" -> "b"]],
  shell["div"] -> {shell["h1"] -> {"Title"}, shell["p"] -> {"Some ", " text"}, shell["hr"], "tail"},
  TestID -> "htt-hide-cut-element-text-only-left"
];

(* A bare element root that hide selects is kept, with root; hide still
   applies below it. *)
TestCreate[
  withMessages[shape[HTMLToTree[$list3, "Hide" -> "ul, li:first-child"]]],
  {{"The root element cannot be hidden; it was kept."}, shell["ul"] -> {shell["li"] -> {"2"}, shell["li"] -> {"3"}}},
  TestID -> "htt-hide-bare-root-kept"
];

(* A document's root element is an element like any other, and hiding
   everything below the root gives no message. *)
$hiDoc = ImportString["<p>Hi</p>", {"HTML", "XMLObject"}];

TestCreate[
  withMessages[shape[HTMLToTree[$hiDoc, "Hide" -> "html"]]],
  {{}, "#document"},
  TestID -> "htt-hide-document-root-element"
];

(* ---- Focus ----
   Only the Focused elements and their contents are drawn. A Focused element
   hangs from its nearest drawn ancestor, by a Collapsed edge when elements
   were skipped; runs of undrawn siblings become Collapsed leaves in place. *)

(* The options that make a Collapsed edge, on a subtree *)
edge[t_Tree] := Lookup[Options[t], {ParentEdgeStyle, ParentEdgeLabel}, None];

$focusSections = HTMLToTree[$cmpBody, "Focus" -> "section"];

(* Configuration 5 of the prototype's comparison. A run joins elements from
   several depths: nav and its two a, then h1 inside main. *)
TestCreate[
  shape[$focusSections],
  shell["body"] -> {
    collapsed[4],
    shell["section", {"id" -> "a"}] -> {
      shell["h2"] -> {"Intro"},
      shell["p"] -> {"Some ", shell["b"] -> {"bold"}, " text"},
      shell["div"] -> {
        shell["aside"] -> {shell["section", {"id" -> "b"}] -> {shell["h2"] -> {"Note"}}},
        shell["p"] -> {"More"}}},
    collapsed[4]},
  TestID -> "htt-focus-comparison"
];

TestCreate[
  edge[TreeExtract[$focusSections, {2}]],
  {Dashed, Placed["main", Tooltip]},
  TestID -> "htt-focus-collapsed-edge"
];

(* A Focused element nested in another is part of its contents: no Collapsed
   edge, and nothing collapsed around it. *)
TestCreate[
  edge[TreeExtract[$focusSections, {2, 3, 1, 1}]],
  {None, None},
  TestID -> "htt-focus-nested-part-of-contents"
];

(* The path is the skipped elements' compound selectors, joined by " > " *)
$deep = XMLElement["div", {}, {XMLElement["main", {"id" -> "m"}, {
  XMLElement["article", {"class" -> "x y"}, {XMLElement["p", {}, {"deep"}]}]}]}];

TestCreate[
  With[{t = HTMLToTree[$deep, "Focus" -> "p"]}, {shape[t], edge[First[TreeChildren[t]]]}],
  {shell["div"] -> {shell["p"] -> {"deep"}}, {Dashed, Placed["main#m > article.x.y", Tooltip]}},
  TestID -> "htt-focus-path-selectors"
];

(* A Focused element whose parent is drawn hangs from it by an ordinary edge.
   Equal siblings are told apart: li:first-child focuses only the first. *)
$twins = XMLElement["ul", {}, {XMLElement["li", {}, {"same"}], XMLElement["li", {}, {"same"}]}];

TestCreate[
  With[{t = HTMLToTree[$twins, "Focus" -> "li:first-child"]}, {shape[t], edge[First[TreeChildren[t]]]}],
  {shell["ul"] -> {shell["li"] -> {"same"}, collapsed[1]}, {None, None}},
  TestID -> "htt-focus-equal-siblings"
];

(* A run of text only is still drawn, counting 0; text and elements together
   count the elements. *)
TestCreate[
  shape[HTMLToTree[XMLElement["div", {}, {"intro ", XMLElement["p", {}, {"x"}], " and ",
    XMLElement["span", {}, {XMLElement["i", {}, {}]}], "\n"}], "Focus" -> "p"]],
  shell["div"] -> {collapsed[0], shell["p"] -> {"x"}, collapsed[2]},
  TestID -> "htt-focus-text-only-run"
];

(* Matching is on the original input, for rules, CSS and alternatives *)
TestCreate[
  shape[HTMLToTree[$list3, "Focus" -> (XMLPattern["ul"][{___, XMLPattern["li"], x : XMLPattern["li"], ___}] :> x)]],
  shell["ul"] -> {collapsed[1], shell["li"] -> {"2"}, shell["li"] -> {"3"}},
  TestID -> "htt-focus-adjacent"
];

TestCreate[
  shape[HTMLToTree[$cmpBody, "Focus" -> "p:has(b)" | XMLPattern["footer"]]],
  shell["body"] -> {collapsed[5], shell["p"] -> {"Some ", shell["b"] -> {"bold"}, " text"}, collapsed[7],
    shell["footer"] -> {shell["p"] -> {"Fine print"}}},
  TestID -> "htt-focus-css-has-and-alternatives"
];

(* A document: the root element is under "#document", and can be focused *)
TestCreate[
  With[{t = HTMLToTree[ImportString["<p>Hi</p><p>Bye</p>", {"HTML", "XMLObject"}], "Focus" -> "p:last-child"]},
    {shape[t], edge[TreeChildren[t][[2]]]}],
  {"#document" -> {collapsed[1], shell["p"] -> {"Bye"}}, {Dashed, Placed["html > body", Tooltip]}},
  TestID -> "htt-focus-document"
];

TestCreate[
  shape[HTMLToTree[{XMLElement["p", {}, {"x"}], "tail", XMLElement["b", {}, {}]}, "Focus" -> "b"]],
  "#document" -> {collapsed[1], shell["b"]},
  TestID -> "htt-focus-list"
];

(* A focus that matches nothing gives the root and collapsed content, with no
   message. *)
TestCreate[
  withMessages[shape[HTMLToTree[$cmpBody, "Focus" -> "table"]]],
  {{}, shell["body"] -> {collapsed[18]}},
  TestID -> "htt-focus-nothing"
];

TestCreate[
  shape[HTMLToTree[$cmpBody, "Focus" -> All]],
  shape[HTMLToTree[$cmpBody]],
  TestID -> "htt-focus-all-everything"
];

(* A real page: the Focused elements are those XMLCases gives, each drawn
   with its contents, and nothing else is drawn as an element. *)
TestCreate[
  Length[TreeCases[HTMLToTree[$realTree, "Focus" -> "h2"], _XMLElement]],
  Total[1 + Count[#, _XMLElement, Infinity] & /@ XMLCases[$realTree, "h2"]],
  TestID -> "htt-real-page-focus"
];

(* ---- Hide and focus ----
   Hiding wins over focus, and a Hidden element inside a Focused one is
   removed from its contents. *)

(* Configuration 13 of the prototype's comparison *)
TestCreate[
  shape[HTMLToTree[$cmpBody, "Focus" -> "section", "Hide" -> ".ad"]],
  shell["body"] -> {
    collapsed[4],
    shell["section", {"id" -> "a"}] -> {
      shell["h2"] -> {"Intro"},
      shell["p"] -> {"Some ", shell["b"] -> {"bold"}, " text"},
      shell["div"] -> {
        shell["aside"] -> {shell["section", {"id" -> "b"}] -> {shell["h2"] -> {"Note"}}},
        shell["p"] -> {"More"}}},
    collapsed[2]},
  TestID -> "htt-focus-hide-comparison"
];

TestCreate[
  shape[HTMLToTree[$cmpBody, "Focus" -> "section", "Hide" -> "aside"]],
  shell["body"] -> {
    collapsed[4],
    shell["section", {"id" -> "a"}] -> {
      shell["h2"] -> {"Intro"},
      shell["p"] -> {"Some ", shell["b"] -> {"bold"}, " text"},
      shell["div"] -> {shell["p"] -> {"More"}}},
    collapsed[4]},
  TestID -> "htt-hide-inside-focus"
];

(* A Focused element inside a Hidden one is not focused, and Hidden elements
   do not count in a Collapsed run. *)
TestCreate[
  shape[HTMLToTree[$cmpBody, "Focus" -> "#b", "Hide" -> "aside"]],
  shell["body"] -> {collapsed[15]},
  TestID -> "htt-hide-wins-over-focus"
];

TestCreate[
  shape[HTMLToTree[$cmpBody, "Focus" -> "section", "Hide" -> "section"]],
  shell["body"] -> {collapsed[9]},
  TestID -> "htt-hide-wins-over-focus-same-element"
];

(* ---- Rules ----
   Both queries take tree patterns and rules, matched against the input as
   given; they act on the positions of the names the right-hand side uses
   (ADR 0024). The inputs are built literally. *)

$hidetarget[pos_] := "The \"Hide\" query names the position " <> pos <>
  ". Hide removes only elements, runs of element children, and the contents of an element.";
$focustarget[pos_] := "The \"Focus\" query names the position " <> pos <>
  ". Focus draws only elements and runs of element children.";

TestCreate[
  shape[HTMLToTree[doc[el["div", el["pre", "code"], el["p"]]], "Hide" -> (XMLElement["pre", _, c_] :> c)]],
  "#document" -> {shell["div"] -> {shell["pre"], shell["p"]}},
  TestID -> "htt-rule-hide-contents"
];

$body6 = doc[el["body", e["nav", "n", e["a", "in"]], e["a", "out"]]];

TestCreate[
  shape[HTMLToTree[$body6, "Focus" -> (XMLDocument[Descendant[x : XMLPattern["a"]]?(NoneTrue[XMLMatchQ["nav"]])] :> x)]],
  "#document" -> {collapsed[2], shell["a", {"id" -> "out"}]},
  TestID -> "htt-rule-focus-context"
];

$hrefs6 = doc[el["p", XMLElement["a", {"href" -> "/x"}, {}], XMLElement["a", {"href" -> "/x"}, {}]]];

TestCreate[
  withMessages[HTMLToTree[$hrefs6, "Focus" -> (XMLPattern["a", "href" -> h_] :> h)]],
  {{$focustarget["{1, 1, Key[\"href\"]}"]}, $Failed},
  TestID -> "htt-rule-focus-attribute-refused"
];

(* Which kinds of position Hide and Focus act on, one test per kind *)
$nav6 = doc[e["nav", "o", e["a", "a1"], e["nav", "i", e["a", "a2"]], e["a", "a3"]]];

TestCreate[
  shape /@ {HTMLToTree[$nav6, "Hide" -> (XMLPattern["nav"][{___, x : XMLPattern["nav"], ___}] :> x)],
    HTMLToTree[$nav6, "Focus" -> (XMLPattern["nav"][{___, x : XMLPattern["nav"], ___}] :> x)]},
  {"#document" -> {shell["nav", {"id" -> "o"}] -> {shell["a", {"id" -> "a1"}], shell["a", {"id" -> "a3"}]}},
    "#document" -> {collapsed[1], shell["nav", {"id" -> "i"}] -> {shell["a", {"id" -> "a2"}]}, collapsed[1]}},
  TestID -> "htt-rule-target-element"
];

TestCreate[
  shape /@ {HTMLToTree[$nav6, "Hide" -> (XMLPattern["nav"][{_, s__}] :> s)],
    HTMLToTree[$nav6, "Focus" -> (XMLPattern["nav"][{_, s__}] :> s)]},
  {"#document" -> {shell["nav", {"id" -> "o"}] -> {shell["a", {"id" -> "a1"}]}},
    "#document" -> {collapsed[1], shell["nav", {"id" -> "i"}] -> {shell["a", {"id" -> "a2"}]}, shell["a", {"id" -> "a3"}]}},
  TestID -> "htt-rule-target-run"
];

TestCreate[
  {shape[HTMLToTree[$nav6, "Hide" -> (XMLElement["nav", {"id" -> "i"}, c_] :> c)]],
    withMessages[HTMLToTree[$nav6, "Focus" -> (XMLElement["nav", {"id" -> "i"}, c_] :> c)]]},
  {"#document" -> {shell["nav", {"id" -> "o"}] -> {shell["a", {"id" -> "a1"}], shell["nav", {"id" -> "i"}], shell["a", {"id" -> "a3"}]}},
    {{$focustarget["{1, 2, All}"]}, $Failed}},
  TestID -> "htt-rule-target-contents"
];

(* Every other kind is refused by both, the first target found named *)
$refusedTargets = {
  XMLPattern[t_] :> t,
  XMLPattern["a", a_] :> a,
  XMLPattern["a", "href" -> h_] :> h,
  XMLPattern["p", "classList" -> c_] :> c,
  XMLPattern["p", "classList" -> {___, c : "lead", ___}] :> c,
  XMLPattern["p"][{_, g___, _}] :> g,
  XMLPattern["body"][p : Descendant[XMLPattern["a"]]] :> p};
$refusedInput = doc[el["body", XMLElement["p", {"class" -> "lead"}, {XMLElement["a", {"href" -> "/x"}, {}], el["b"]}]]];

$refusedPositions = {"{1, 0}", "{1, 1, 1, Key[All]}", "{1, 1, 1, Key[\"href\"]}", "{1, 1, Key[\"classList\"]}",
  "{1, 1, Key[\"classList\"], 1}", "{1, 1, 2 ;; 1}", "{1} ;; {1, 1, 1}"};

TestCreate[
  {withMessages[HTMLToTree[$refusedInput, "Hide" -> #]] & /@ $refusedTargets,
    withMessages[HTMLToTree[$refusedInput, "Focus" -> #]] & /@ $refusedTargets},
  {{{$hidetarget[#]}, $Failed} & /@ $refusedPositions, {{$focustarget[#]}, $Failed} & /@ $refusedPositions},
  TestID -> "htt-rule-target-refused"
];

(* {} names the document, but a query with no match names nothing *)
TestCreate[
  {withMessages[HTMLToTree[$nav6, "Hide" -> (x : XMLPattern["table"] :> x)]] // MapAt[shape, 2],
    withMessages[HTMLToTree[$nav6, "Focus" -> (x : XMLPattern["table"] :> x)]] // MapAt[shape, 2],
    withMessages[HTMLToTree[$nav6, "Hide" -> (d : XMLDocument[] :> d)]]},
  {{{}, shape[HTMLToTree[$nav6]]}, {{}, "#document" -> {collapsed[5]}}, {{$hidetarget["{}"]}, $Failed}},
  TestID -> "htt-rule-no-match"
];

(* A bare element's root is kept, with root, when a rule names it *)
TestCreate[
  withMessages[shape[HTMLToTree[$list3, "Hide" -> (x : XMLPattern["ul"] :> x)]]],
  {{"The root element cannot be hidden; it was kept."}, shell["ul"] -> {shell["li"] -> {"1"}, shell["li"] -> {"2"}, shell["li"] -> {"3"}}},
  TestID -> "htt-rule-hide-bare-root-kept"
];

(* ---- Focus with depth ----
   Depth counts from the nearest Focused element above. A Focused element
   inside a Cut element is still drawn, with its own depth, under a Collapsed
   edge from the Cut element; the rest of the contents become Collapsed runs. *)

$focusDepth1 = HTMLToTree[$cmpBody, 1, "Focus" -> "section"];

(* Configuration 9 of the prototype's comparison. div is a Cut element that
   holds section#b, which skips aside; p and its text are one run. *)
TestCreate[
  shape[$focusDepth1],
  shell["body"] -> {
    collapsed[4],
    shell["section", {"id" -> "a"}] -> {
      shell["h2"] -> {"Intro"},
      shell["p"] -> {collapsed[1]},
      shell["div"] -> {shell["section", {"id" -> "b"}] -> {shell["h2"] -> {"Note"}}, collapsed[1]}},
    collapsed[4]},
  TestID -> "htt-focus-depth-comparison"
];

TestCreate[
  edge /@ {TreeExtract[$focusDepth1, {2}], TreeExtract[$focusDepth1, {2, 3, 1}]},
  {{Dashed, Placed["main", Tooltip]}, {Dashed, Placed["aside", Tooltip]}},
  TestID -> "htt-focus-depth-edge-from-cut-element"
];

(* Depth 0: each Focused element with one Collapsed leaf. One that holds a
   Focused element is a Cut element like any other: the inner one is drawn
   from it, past div and aside, with runs around it. *)
TestCreate[
  shape /@ {HTMLToTree[$cmpBody, 0, "Focus" -> "nav, footer"], HTMLToTree[$cmpBody, 0, "Focus" -> "section"]},
  {shell["body"] -> {shell["nav"] -> {collapsed[2]}, collapsed[13], shell["footer"] -> {collapsed[1]}},
    shell["body"] -> {
      collapsed[4],
      shell["section", {"id" -> "a"}] -> {collapsed[3], shell["section", {"id" -> "b"}] -> {collapsed[1]}, collapsed[1]},
      collapsed[4]}},
  TestID -> "htt-focus-depth-zero"
];

(* A Focused element drawn inside another counts depth from itself too, so it
   shows the same detail however deep it is in the outer one: section#b, at
   depth 3 in section#a, keeps its h2 at depths 2, 3 and 4. *)
TestCreate[
  shape[TreeExtract[HTMLToTree[$cmpBody, #, "Focus" -> "section"], {2, 3, 1, 1}]] & /@ {2, 3, 4},
  ConstantArray[shell["section", {"id" -> "b"}] -> {shell["h2"] -> {"Note"}}, 3],
  TestID -> "htt-focus-depth-nested"
];

TestCreate[
  edge[TreeExtract[HTMLToTree[$cmpBody, 0, "Focus" -> "section"], {2, 2}]],
  {Dashed, Placed["div > aside", Tooltip]},
  TestID -> "htt-focus-depth-zero-edge"
];

(* ---- Paths drawn in full ----
   With "CollapsePaths" -> False, the elements on the path to each Focused
   element are drawn as ordinary nodes, with Collapsed runs under them in
   place, so a run no longer joins elements from several depths. Path elements
   do not count towards depth. *)

(* Configuration 7 of the prototype's comparison: nav and h1 are now runs at
   their own depths, and no edge is dashed. *)
$fullPaths = HTMLToTree[$cmpBody, "Focus" -> "section", "CollapsePaths" -> False];

TestCreate[
  shape[$fullPaths],
  shell["body"] -> {
    collapsed[3],
    shell["main"] -> {
      collapsed[1],
      shell["section", {"id" -> "a"}] -> {
        shell["h2"] -> {"Intro"},
        shell["p"] -> {"Some ", shell["b"] -> {"bold"}, " text"},
        shell["div"] -> {
          shell["aside"] -> {shell["section", {"id" -> "b"}] -> {shell["h2"] -> {"Note"}}},
          shell["p"] -> {"More"}}},
      collapsed[2]},
    collapsed[2]},
  TestID -> "htt-full-paths-comparison"
];

TestCreate[
  Union[edge /@ TreeLevel[$fullPaths, {1, Infinity}]],
  {{None, None}},
  TestID -> "htt-full-paths-no-collapsed-edges"
];

(* Configuration 11: with depth 1, the path from the Cut element div to
   section#b is drawn, aside, and p beside it is a run. *)
TestCreate[
  shape[HTMLToTree[$cmpBody, 1, "Focus" -> "section", "CollapsePaths" -> False]],
  shell["body"] -> {
    collapsed[3],
    shell["main"] -> {
      collapsed[1],
      shell["section", {"id" -> "a"}] -> {
        shell["h2"] -> {"Intro"},
        shell["p"] -> {collapsed[1]},
        shell["div"] -> {shell["aside"] -> {shell["section", {"id" -> "b"}] -> {shell["h2"] -> {"Note"}}}, collapsed[1]}},
      collapsed[2]},
    collapsed[2]},
  TestID -> "htt-full-paths-depth-comparison"
];

(* Path elements do not count towards depth: at depth 0, article is still
   drawn with one Collapsed leaf, two path elements below the root; and so is
   section#b, below a path from its Cut element. *)
$deeper = XMLElement["div", {}, {XMLElement["main", {"id" -> "m"}, {
  XMLElement["article", {}, {XMLElement["p", {}, {"deep"}]}], XMLElement["hr", {}, {}]}]}];

TestCreate[
  shape /@ {HTMLToTree[$deeper, 0, "Focus" -> "article", "CollapsePaths" -> False],
    HTMLToTree[$cmpBody, 0, "Focus" -> "section", "CollapsePaths" -> False]},
  {shell["div"] -> {shell["main", {"id" -> "m"}] -> {shell["article"] -> {collapsed[1]}, collapsed[1]}},
    shell["body"] -> {
      collapsed[3],
      shell["main"] -> {
        collapsed[1],
        shell["section", {"id" -> "a"}] -> {
          collapsed[3],
          shell["div"] -> {shell["aside"] -> {shell["section", {"id" -> "b"}] -> {collapsed[1]}}, collapsed[1]}},
        collapsed[2]},
      collapsed[2]}},
  TestID -> "htt-full-paths-not-counted"
];

(* A document's path starts at its root element *)
TestCreate[
  shape[HTMLToTree[ImportString["<p>Hi</p><p>Bye</p>", {"HTML", "XMLObject"}],
    "Focus" -> "p:last-child", "CollapsePaths" -> False]],
  "#document" -> {shell["html", {{"http://www.w3.org/2000/xmlns/", "xmlns"} -> "http://www.w3.org/1999/xhtml"}] -> {
    shell["body"] -> {collapsed[1], shell["p"] -> {"Bye"}}}},
  TestID -> "htt-full-paths-document"
];

(* True is the default *)
TestCreate[
  shape[HTMLToTree[$cmpBody, 1, "Focus" -> "section", "CollapsePaths" -> True]],
  shape[$focusDepth1],
  TestID -> "htt-collapse-paths-true-is-default"
];

(* ---- Merged text ----
   A drawn element whose contents hold at least one element, every element in
   them Inline by Display role, gets one Merged text leaf; it keeps its node. *)

(* Configuration 4 of the prototype's comparison. h1 and the p elements with
   only text are not merged: there is nothing to merge. *)
TestCreate[
  shape[HTMLToTree[$cmpBody, "MergeText" -> HTMLInnerText]],
  shell["body"] -> {
    shell["nav"] -> {"Home About"},
    shell["main"] -> {
      shell["h1"] -> {"Title"},
      shell["section", {"id" -> "a"}] -> {
        shell["h2"] -> {"Intro"},
        shell["p"] -> {"Some bold text"},
        shell["div"] -> {
          shell["aside"] -> {shell["section", {"id" -> "b"}] -> {shell["h2"] -> {"Note"}}},
          shell["p"] -> {"More"}}},
      shell["div", {"class" -> "ad"}] -> {shell["p"] -> {"Buy"}}},
    shell["footer"] -> {shell["p"] -> {"Fine print"}}},
  TestID -> "htt-merge-comparison"
];

(* HTMLInnerText collapses whitespace; HTMLTextContent keeps the raw text *)
$mergeP = XMLElement["p", {}, {"Some\n  ", XMLElement["b", {}, {"bold"}], "  text "}];

TestCreate[
  shape /@ {HTMLToTree[$mergeP, "MergeText" -> HTMLInnerText], HTMLToTree[$mergeP, "MergeText" -> HTMLTextContent]},
  {shell["p"] -> {"Some bold text"}, shell["p"] -> {"Some\n  bold  text "}},
  TestID -> "htt-merge-both-functions"
];

(* None, the default, keeps separate text leaves *)
TestCreate[
  SameQ @@ shape /@ {HTMLToTree[$mergeP], HTMLToTree[$mergeP, "MergeText" -> None]},
  True,
  TestID -> "htt-merge-none-is-default"
];

(* Contents that are only text are not merged: there is nothing to merge, and
   the strings stay as they are. *)
TestCreate[
  shape[HTMLToTree[XMLElement["p", {}, {"  a  ", XMLObject["CDATASection"]["b"]}], "MergeText" -> HTMLInnerText]],
  shell["p"] -> {"  a  ", "b"},
  TestID -> "htt-merge-text-only-not-merged"
];

(* "Inline" is decided by Display role under "Roles": a div is Block, unless a
   rule makes it Inline, and a rule can make a b Block. *)
$mergeDiv = XMLElement["p", {}, {"a", XMLElement["div", {}, {"b"}], "c"}];

TestCreate[
  shape /@ {HTMLToTree[$mergeDiv, "MergeText" -> HTMLInnerText],
    HTMLToTree[$mergeDiv, "MergeText" -> HTMLInnerText, "Roles" -> {"div" -> "Inline"}],
    HTMLToTree[$mergeDiv, "MergeText" -> HTMLTextContent, "Roles" -> {"div" -> "Inline"}],
    HTMLToTree[$mergeP, "MergeText" -> HTMLInnerText, "Roles" -> {"b" -> "Block"}]},
  {shell["p"] -> {"a", shell["div"] -> {"b"}, "c"}, shell["p"] -> {"abc"}, shell["p"] -> {"abc"},
    shell["p"] -> {"Some\n  ", shell["b"] -> {"bold"}, "  text "}},
  TestID -> "htt-merge-roles-decide-inline"
];

(* Elements that are not Inline, such as br (LineBreak) and script (Skip),
   are not merged. *)
TestCreate[
  shape /@ {HTMLToTree[XMLElement["p", {}, {"a", XMLElement["br", {}, {}], "b"}], "MergeText" -> HTMLInnerText],
    HTMLToTree[XMLElement["p", {}, {"a", XMLElement["script", {}, {"x"}]}], "MergeText" -> HTMLInnerText]},
  {shell["p"] -> {"a", shell["br"], "b"}, shell["p"] -> {"a", shell["script"] -> {"x"}}},
  TestID -> "htt-merge-not-inline"
];

(* The text is the function's own result with the same "Roles" and
   "AttributeReadings": here a role rule naming a list key makes the div
   Preformatted, so its whitespace is kept. *)
$mergePre = XMLElement["div", {"data-k" -> "x y"}, {"a  ", XMLElement["b", {}, {"b"}], "  c"}];
$mergePreOpts = {"Roles" -> {XMLPattern["div", "data-kList" -> "x"] -> "Preformatted"},
  "AttributeReadings" -> <|"data-k" -> <||>|>};

TestCreate[
  {shape[HTMLToTree[$mergePre, "MergeText" -> HTMLInnerText, Sequence @@ $mergePreOpts]],
    HTMLInnerText[$mergePre, Sequence @@ $mergePreOpts]},
  {shell["div", {"data-k" -> "x y"}] -> {"a  b  c"}, "a  b  c"},
  TestID -> "htt-merge-roles-and-readings-passed"
];

(* Hidden elements are left out of the merged text, and a Hidden element that
   is not Inline does not stop the merge. *)
TestCreate[
  shape /@ {HTMLToTree[XMLElement["p", {}, {"a ", XMLElement["b", {}, {"x"}], " ", XMLElement["i", {}, {"y"}]}],
      "MergeText" -> HTMLInnerText, "Hide" -> "i"],
    HTMLToTree[$mergeDiv, "MergeText" -> HTMLTextContent, "Hide" -> "div"],
    HTMLToTree[XMLElement["p", {}, {"a", XMLElement["div", {}, {"z"}], XMLElement["b", {}, {"x"}]}],
      "MergeText" -> HTMLInnerText, "Hide" -> "div"]},
  {shell["p"] -> {"a x"}, shell["p"] -> {"a", "c"}, shell["p"] -> {"ax"}},
  TestID -> "htt-merge-hidden-left-out"
];

(* Merged text that would not be drawn, whitespace only (unless
   "IncludeWhitespace" is on) or empty, is not merged, so that the inline
   elements keep their nodes. *)
$mergeBlank = XMLElement["p", {}, {" ", XMLElement["b", {}, {}], " "}];

TestCreate[
  shape /@ {HTMLToTree[$mergeBlank, "MergeText" -> HTMLTextContent],
    HTMLToTree[$mergeBlank, "MergeText" -> HTMLTextContent, "IncludeWhitespace" -> True],
    HTMLToTree[XMLElement["p", {}, {XMLElement["img", {"alt" -> "A"}, {}]}], "MergeText" -> HTMLInnerText, "IncludeWhitespace" -> True]},
  {shell["p"] -> {shell["b"]}, shell["p"] -> {"  "}, shell["p"] -> {shell["img", {"alt" -> "A"}]}},
  TestID -> "htt-merge-not-drawn-not-merged"
];

(* A merged element at the depth limit is not a Cut element: it has its text. *)
TestCreate[
  shape /@ {HTMLToTree[$depthTree, 1, "MergeText" -> HTMLInnerText], HTMLToTree[$mergeP, 0, "MergeText" -> HTMLInnerText]},
  {shell["div"] -> {shell["h1"] -> {"Title"}, shell["p"] -> {"Some x text"}, shell["hr"], "tail"}, shell["p"] -> {"Some bold text"}},
  TestID -> "htt-merge-not-cut"
];

(* A Focused element can be merged; an element holding one, or on a drawn
   path to one, is not, so that no Focused element is lost. *)
$mergeInDiv = XMLElement["div", {}, {$mergeP}];

TestCreate[
  shape /@ {HTMLToTree[$mergeInDiv, "Focus" -> "p", "MergeText" -> HTMLInnerText],
    HTMLToTree[$mergeInDiv, "Focus" -> "p, b", "MergeText" -> HTMLInnerText],
    HTMLToTree[$mergeInDiv, 0, "Focus" -> "p, b", "MergeText" -> HTMLInnerText],
    HTMLToTree[$mergeInDiv, "Focus" -> "b", "CollapsePaths" -> False, "MergeText" -> HTMLInnerText]},
  {shell["div"] -> {shell["p"] -> {"Some bold text"}},
    shell["div"] -> {shell["p"] -> {"Some\n  ", shell["b"] -> {"bold"}, "  text "}},
    shell["div"] -> {shell["p"] -> {collapsed[0], shell["b"] -> {"bold"}, collapsed[0]}},
    shell["div"] -> {shell["p"] -> {collapsed[0], shell["b"] -> {"bold"}, collapsed[0]}}},
  TestID -> "htt-merge-not-on-focus-path"
];

(* ---- Readings ----
   "AttributeReadings" applies to both queries. *)
$tokens = XMLElement["ul", {}, {XMLElement["li", {"data-k" -> "a b"}, {"1"}],
  XMLElement["li", {"data-k" -> "b c"}, {"2"}], XMLElement["li", {"data-k" -> "c"}, {"3"}]}];

TestCreate[
  shape[HTMLToTree[$tokens, "Focus" -> XMLPattern["li", "data-kList" -> "b"],
    "Hide" -> XMLPattern["li", "data-kList" -> "a"], "AttributeReadings" -> <|"data-k" -> <||>|>]],
  shell["ul"] -> {shell["li", {"data-k" -> "b c"}] -> {"2"}, collapsed[1]},
  TestID -> "htt-readings-both-queries"
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
    NumericQ[treeOption[HTMLToTree[$cmpBody, TreeLayout -> Bottom], ImageSize]],
    treeOption[HTMLToTree[$cmpBody, TreeLayout -> "RadialEmbedding"], ImageSize]},
  {True, True, Missing[]},
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

(* The computed size counts the cut tree: three leaves at depth 1 are as tall
   as three items. *)
TestCreate[
  Last[treeOption[HTMLToTree[$cmpBody, 1], ImageSize]],
  Last[treeOption[HTMLToTree[$items[3]], ImageSize]],
  TestID -> "htt-depth-image-size"
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

(* ---- Messages ---- *)

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

(* A bad query, "Focus" -> None or "Hide" -> All gives badquery,
   naming the option, and $Failed. *)
$badquery[name_, off_, got_] := "The value of the \"" <> name <> "\" option should be " <> off <>
  ", Automatic, a pattern, or a rule pattern -> rhs or pattern :> rhs, which applies to the elements bound to the names that rhs uses. A pattern is an XMLPattern, which can take constraints on the elements below it, an XMLDocument pattern, an XMLElement pattern, or a CSS selector string, or alternatives of these, any of them named, with a condition pat /; test or a test pat?f. Got " <> got <> ".";

TestCreate[
  withMessages[HTMLToTree[$p, #1 -> #2]] & @@@ {{"Focus", 1}, {"Focus", None}, {"Hide", All}},
  {{{$badquery["Focus", "All", "1"]}, $Failed}, {{$badquery["Focus", "All", "None"]}, $Failed},
    {{$badquery["Hide", "None", "All"]}, $Failed}},
  TestID -> "htt-message-badquery"
];

(* A rule is a query; one with a bad left-hand side gives badquery, and one
   whose right-hand side uses no name acts on nothing. *)
TestCreate[
  {withMessages[HTMLToTree[$p, "Focus" -> (1 :> 1)]],
    withMessages[shape[HTMLToTree[$list3, "Hide" -> (XMLPattern["li"] :> 1)]]]},
  {{{$badquery["Focus", "All", "1"]}, $Failed}, {{}, shape[HTMLToTree[$list3]]}},
  TestID -> "htt-message-badquery-rule"
];

(* A mistake at the query's top level is the option's (ADR 0022). *)
TestCreate[
  {withMessages[HTMLToTree[$p, "Hide" -> _]], withMessages[HTMLToTree[$p, "Focus" -> {XMLPattern["a"]}]]},
  {{{$badquery["Hide", "None", "_"]}, $Failed}, {{$badquery["Focus", "All", "{XMLPattern[\"a\"]}"]}, $Failed}},
  TestID -> "htt-message-badquery-top-level"
];

(* Both queries are refused before either is matched: no root message from a
   hide query when the focus query is bad. *)
TestCreate[
  withMessages[HTMLToTree[$p, "Hide" -> "p", "Focus" -> 2]],
  {{$badquery["Focus", "All", "2"]}, $Failed},
  TestID -> "htt-message-badquery-before-root"
];

(* Bad readings give the $AttributeReadings messages and $Failed. *)
TestCreate[
  {withMessages[HTMLToTree[$p, "AttributeReadings" -> 3]],
    withMessages[HTMLToTree[$p, "Focus" -> "p", "AttributeReadings" -> <|"k" -> 1|>]]},
  {{{"$AttributeReadings and the \"AttributeReadings\" option should be an Association from attribute names to readings. Got 3."}, $Failed},
    {{"The reading for \"k\" should be an Association with any of the fields Method, Delimiters, \"TrimWhitespace\" and \"ListKey\". Got 1."}, $Failed}},
  TestID -> "htt-message-readings"
];

(* A depth that is not Infinity or an integer >= 0 gives innf at position 2,
   and the call stays unevaluated, as XMLCases does for its count. *)
TestCreate[
  Replace[withMessages[HTMLToTree[$p, -1, TreeLayout -> Top]], {m_, r_} :> {m, Head[r], List @@ r}],
  {{"Non-negative integer or Infinity expected at position 2 in HTMLToTree[XMLElement[\"p\", {}, {}], -1, TreeLayout -> Top]."},
    HTMLToTree, {$p, -1, TreeLayout -> Top}},
  TestID -> "htt-message-innf"
];

(* Two at a time, since a third innf in one evaluation is stopped *)
TestCreate[
  Head /@ {HTMLToTree[$p, 1.5], HTMLToTree[$p, All]},
  {HTMLToTree, HTMLToTree},
  {HTMLToTree::innf, HTMLToTree::innf},
  TestID -> "htt-message-innf-values"
];

TestCreate[
  Head /@ {HTMLToTree[$p, {2}], HTMLToTree[$p, UpTo[2]]},
  {HTMLToTree, HTMLToTree},
  {HTMLToTree::innf, HTMLToTree::innf},
  TestID -> "htt-message-innf-more-values"
];

(* An invalid depth with an unknown option: innf, not optx *)
TestCreate[
  Head[HTMLToTree[$p, "1", Foo -> 1]],
  HTMLToTree,
  {HTMLToTree::innf},
  TestID -> "htt-message-innf-before-optx"
];

(* "MergeText" takes HTMLInnerText and HTMLTextContent as tokens: any other
   function gives optval. *)
TestCreate[
  withMessages[HTMLToTree[$p, "MergeText" -> #]] & /@ {StringJoin[#] &, HTMLToNotebook},
  {{{"The value of the \"MergeText\" option should be None | HTMLInnerText | HTMLTextContent | Automatic. Got StringJoin[#1] & ."}, $Failed},
    {{"The value of the \"MergeText\" option should be None | HTMLInnerText | HTMLTextContent | Automatic. Got HTMLToNotebook."}, $Failed}},
  TestID -> "htt-message-optval-merge-function"
];

(* Bad "Roles" give HTMLToTree's own copies of HTMLInnerText's messages, once,
   on every call, whether merging is on or not, and $Failed. *)
$badRoles = {{3}, {5 -> "Block"}};
$badRolesMessages = {
  "Each \"Roles\" entry should be a rule pattern -> value or pattern :> value. Got 3.",
  "The key of a rule should be an element test or a query. An element test is an XMLPattern, an XMLElement pattern, or a CSS selector string that describes one element, or alternatives of these, any of them named, with a condition pat /; test or a test pat?f; each element is tested by itself, and its names can be used in the value. A query is a rule such as XMLPattern[\"nav\"][Descendant[x : XMLPattern[\"a\"]]] :> x, or a CSS selector string such as \"nav a\"; the elements it selects get the value. An XMLDocument pattern tests no element: name the elements it finds and give the rule, as in (XMLDocument[Descendant[x : XMLPattern[\"a\"]]] :> x) -> value. Got 5."};

TestCreate[
  Table[withMessages[HTMLToTree[$mergeP, "Roles" -> r, "MergeText" -> m]], {m, {Automatic, HTMLInnerText}}, {r, $badRoles}],
  ConstantArray[{{#}, $Failed} & /@ $badRolesMessages, 2],
  TestID -> "htt-message-roles"
];

TestCreate[
  First /@ Table[withMessages[HTMLToTree[$mergeP, "Roles" -> r, "MergeText" -> HTMLInnerText]], {r, $badRoles}],
  First /@ Table[withMessages[HTMLInnerText[$mergeP, "Roles" -> r]], {r, $badRoles}],
  TestID -> "htt-message-roles-as-html-inner-text"
];

TestCreate[
  {HTMLToTree[$mergeP, "Roles" -> {3}], HTMLToTree[$mergeP, "Roles" -> {3}, "MergeText" -> HTMLTextContent]},
  {$Failed, $Failed},
  {HTMLToTree::notrule, HTMLToTree::notrule},
  TestID -> "htt-message-roles-head"
];

(* A rule giving a value that is not a role gives badrole once, when merging
   looks the role up, and the element keeps its own role. *)
TestCreate[
  withMessages[shape[HTMLToTree[$mergeInDiv, "Roles" -> {"b" -> "Bold"}, "MergeText" -> HTMLInnerText]]],
  {{"A \"Roles\" rule gave \"Bold\", which is not \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\" or \"Skip\". The element gets its role from the built-in user-agent stylesheet instead."},
    shell["div"] -> {shell["p"] -> {"Some bold text"}}},
  TestID -> "htt-message-badrole-once"
];
