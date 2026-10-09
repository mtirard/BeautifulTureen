(* Text extraction: HTMLTextContent (lossless concatenation) and HTMLInnerText
   (readable text with whitespace collapse, block breaks, Roles overrides).
   The $itBlocks fixture is local to this file. *)

(* === HTMLTextContent === *)

(* Tracer: lossless concatenation of nested strings, in document order *)
TestCreate[
  HTMLTextContent[
    XMLElement["p", {}, {"Hi ", XMLElement["em", {}, {"there"}], ", world"}]
  ],
  "Hi there, world",
  TestID -> "textcontent-concat"
];

(* Bug fix: descend into a whole XMLObject["Document"] (old HTMLTextContent returned "") *)
TestCreate[
  HTMLTextContent[
    ImportString["<p>Hello</p>", {"HTML", "XMLObject"}]
  ],
  "Hello",
  TestID -> "textcontent-document-descends"
];

(* List input (the XMLCases surface): concatenate each element's text content *)
TestCreate[
  HTMLTextContent[{
    XMLElement["p", {}, {"a"}],
    XMLElement["p", {}, {"b"}]
  }],
  "ab",
  TestID -> "textcontent-list"
];

(* Bad argument: a non-tree messages and returns $Failed (mirrors XMLCases::badtree) *)
TestCreate[
  HTMLTextContent[37],
  $Failed,
  {HTMLTextContent::badtree},
  TestID -> "textcontent-badtree"
];

(* Internal totality: a stray comment node contributes "" mid-walk, no message *)
TestCreate[
  HTMLTextContent[
    XMLElement["p", {}, {"a", XMLObject["Comment"]["ignore me"], "b"}]
  ],
  "ab",
  TestID -> "textcontent-stray-node-total"
];

(* === HTMLInnerText === *)

(* Tracer: collapse internal whitespace, flow inline children, trim ends *)
TestCreate[
  HTMLInnerText[
    ImportString["<p>Hi   <em>there</em>,\n   world</p>", {"HTML", "XMLObject"}]
  ],
  "Hi there, world",
  TestID -> "innertext-collapse-inline"
];

(* Block tags land on their own lines; inline children flow within *)
$itBlocks = XMLElement["div", {}, {
  XMLElement["h2", {}, {"Title"}],
  XMLElement["p", {}, {"First para."}],
  XMLElement["p", {}, {"Second ", XMLElement["b", {}, {"bold"}], " para."}]}];

TestCreate[
  HTMLInnerText[$itBlocks],
  "Title\nFirst para.\nSecond bold para.",
  TestID -> "innertext-block-breaks"
];

(* BlockSeparator option widens the gap between block boundaries *)
TestCreate[
  HTMLInnerText[$itBlocks, "BlockSeparator" -> "\n\n"],
  "Title\n\nFirst para.\n\nSecond bold para.",
  TestID -> "innertext-block-separator"
];

(* <pre> content is preserved verbatim, on its own block line *)
TestCreate[
  HTMLInnerText[
    XMLElement["div", {}, {
      "code:",
      XMLElement["pre", {}, {"  for x:\n    print x"}],
      "done"}]
  ],
  "code:\n  for x:\n    print x\ndone",
  TestID -> "innertext-pre-verbatim"
];

(* <br> becomes a single newline, immune to BlockSeparator *)
TestCreate[
  HTMLInnerText[
    XMLElement["p", {}, {"line1", XMLElement["br", {}, {}], "line2"}],
    "BlockSeparator" -> "\n\n"
  ],
  "line1\nline2",
  TestID -> "innertext-br-newline"
];

(* Skip: script/style and their subtrees are dropped *)
TestCreate[
  HTMLInnerText[
    XMLElement["section", {}, {
      XMLElement["script", {}, {"var x=1;"}],
      XMLElement["p", {}, {"Visible."}]}]
  ],
  "Visible.",
  TestID -> "innertext-skip-script"
];

(* Roles override: drop a screenreader-only span by its class list *)
TestCreate[
  HTMLInnerText[
    XMLElement["div", {}, {
      "keep ",
      XMLElement["span", {"class" -> "sr-only"}, {"screenreader"}],
      "this"}],
    "Roles" -> {XMLPattern["span", "classList" -> "sr-only"] -> "Skip"}
  ],
  "keep this",
  TestID -> "innertext-roles-cssclass-skip"
];

(* Roles: a bare string LHS sugars to XMLPattern[string] (exact tag match) *)
TestCreate[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLElement["em", {}, {"b"}], "c"}],
    "Roles" -> {"em" -> "Block"}
  ],
  "a\nb\nc",
  TestID -> "innertext-roles-string-sugar"
];

(* Roles: an Association sugars to an ordered rule list *)
TestCreate[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLElement["em", {}, {"b"}], "c"}],
    "Roles" -> <|"em" -> "Block"|>
  ],
  "a\nb\nc",
  TestID -> "innertext-roles-association-sugar"
];

(* badrole: a literal non-role RHS messages and defers to the frozen table
   (em falls back to Inline, so "abc") *)
TestCreate[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLElement["em", {}, {"b"}], "c"}],
    "Roles" -> {"em" -> "Bogus"}
  ],
  "abc",
  {HTMLInnerText::badrole},
  TestID -> "innertext-badrole-literal"
];

(* badrole: a delayed rule's RHS validates at runtime, too *)
TestCreate[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLElement["em", {}, {"b"}], "c"}],
    "Roles" -> {"em" :> StringJoin["Not", "ARole"]}
  ],
  "abc",
  {HTMLInnerText::badrole},
  TestID -> "innertext-badrole-delayed"
];

(* A delayed rule producing a valid role works (em -> Block via :>) *)
TestCreate[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLElement["em", {}, {"b"}], "c"}],
    "Roles" -> {XMLPattern["em"] :> "Block"}
  ],
  "a\nb\nc",
  TestID -> "innertext-roles-delayed-valid"
];

(* A "Roles" entry that is not a rule is refused once, when the option is read *)
TestCreate[
  HTMLInnerText[
    XMLElement["div", {}, {XMLElement["p", {}, {"a"}], XMLElement["p", {}, {"b"}]}],
    "Roles" -> {"p"}
  ],
  $Failed,
  {HTMLInnerText::notrule},
  TestID -> "innertext-roles-non-rule-refused"
];

(* Bad argument: a non-tree messages and returns $Failed *)
TestCreate[
  HTMLInnerText[37],
  $Failed,
  {HTMLInnerText::badtree},
  TestID -> "innertext-badtree"
];

(* Bare string input: collapse and trim *)
TestCreate[
  HTMLInnerText["  hi   there  "],
  "hi there",
  TestID -> "innertext-bare-string"
];

(* List input: each top-level element joined at block boundaries *)
TestCreate[
  HTMLInnerText[{
    XMLElement["p", {}, {"a"}],
    XMLElement["p", {}, {"b"}]}],
  "a\nb",
  TestID -> "innertext-list"
];

(* Unknown tag defaults to Inline (flows, no break) *)
TestCreate[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLElement["custom-thing", {}, {"b"}], "c"}]
  ],
  "abc",
  TestID -> "innertext-unknown-tag-inline"
];

(* Internal totality: a stray comment node contributes nothing, no message *)
TestCreate[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLObject["Comment"]["ignore me"], "b"}]
  ],
  "ab",
  TestID -> "innertext-stray-node-total"
];

(* Block boundaries at the very ends are trimmed (no leading/trailing newline) *)
TestCreate[
  HTMLInnerText[
    XMLElement["div", {}, {XMLElement["p", {}, {"only"}]}]
  ],
  "only",
  TestID -> "innertext-trim-ends"
];

(* Roles are tried in order, first match wins (Replace convention, not specificity) *)
TestCreate[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLElement["em", {}, {"b"}], "c"}],
    "Roles" -> {"em" -> "Skip", "em" -> "Block"}
  ],
  "ac",
  TestID -> "innertext-roles-first-match"
];

(* === Role rules naming the classList key === *)

$richText = ImportString[
  "<div class=\"main\"><h2 class=\"t\">T</h2><p class=\"lead\">see <a href=\"/x\">x</a></p>\
<pre class=\"code\">  a\n  b</pre><ul><li class=\"i\">one</li><li>two</li></ul></div>",
  {"HTML", "XMLObject"}];

TestCreate[
  HTMLInnerText[$richText, "Roles" -> {XMLPattern["li", "classList" -> "nomatch"] -> "Skip"}] ===
    HTMLInnerText[$richText],
  True,
  TestID -> "innertext-materialised-output-identical"
];

(* A delayed rule's element binding sees the original element. *)
TestCreate[
  HTMLInnerText[$richText,
    "Roles" -> {e : XMLPattern["li", "classList" -> _] :> If[e[[2]] === {}, "Skip", "Block"]}],
  "T\nsee x\n  a\n  b\none",
  TestID -> "innertext-roles-classlist-binding-original"
];

TestCreate[
  HTMLInnerText[$richText, "Roles" -> {XMLPattern["li", {"classList" -> "i"}] -> "Skip"}],
  "T\nsee x\n  a\n  b\ntwo",
  TestID -> "innertext-roles-classlist-skip"
];

TestCreate[
  HTMLInnerText[$richText, "Roles" -> {XMLPattern["li", "a", "b"] -> "Skip"}],
  $Failed,
  {XMLPattern::nargs},
  TestID -> "innertext-roles-xmlpattern-refusal"
];

(* === Spec conformance: the innerText getter and the rendered text collection
   steps (WHATWG HTML, "The innerText and outerText properties") === *)

(* An element that is not being rendered gives its descendant text content
   (getter step 1), so the title passed in gives its text (#41) *)
TestCreate[
  HTMLInnerText[XMLElement["title", {}, {"My page"}]],
  "My page",
  TestID -> "innertext-skip-root-text-content"
];

(* A "Roles" rule stands in for the page's CSS, so a root it skips is not
   being rendered either *)
TestCreate[
  HTMLInnerText[
    XMLElement["span", {"class" -> "sr-only"}, {"screenreader"}],
    "Roles" -> {".sr-only" -> "Skip"}
  ],
  "screenreader",
  TestID -> "innertext-roles-skip-root-text-content"
];

(* Each top element of a list is a root: a skipped one gives its text content *)
TestCreate[
  HTMLInnerText[XMLCases[
    ImportString["<title>My page</title><p>Body</p>", {"HTML", "XMLObject"}],
    "title, p"]],
  "My page\nBody",
  TestID -> "innertext-list-skip-top-element"
];

(* CSS collapses only space, tab and line feed (CSS Text 3, "white space"):
   no-break spaces are kept, each one *)
TestCreate[
  HTMLInnerText[ImportString["<p>a&nbsp;&nbsp;b</p>", {"HTML", "XMLObject"}]],
  "a\[NonBreakingSpace]\[NonBreakingSpace]b",
  TestID -> "innertext-nbsp-kept"
];

(* A br element appends a line feed (rendered text collection steps), so two in
   a row leave a blank line *)
TestCreate[
  HTMLInnerText[ImportString["<p>a<br><br>b</p>", {"HTML", "XMLObject"}]],
  "a\n\nb",
  TestID -> "innertext-consecutive-br"
];

(* The user-agent stylesheet hides rp and noembed (WHATWG HTML 15.3.1),
   so a ruby gives its base and annotation without the fallback parentheses *)
TestCreate[
  HTMLInnerText[ImportString[
    "<p><ruby>\:6f22<rp>(</rp><rt>kan</rt><rp>)</rp></ruby></p><noembed>NE</noembed>",
    {"HTML", "XMLObject"}]],
  "\:6f22kan",
  TestID -> "innertext-ua-hidden-tags"
];

(* A textarea is a replaced element: its content, the control's initial value,
   has no CSS box and gives no rendered text *)
TestCreate[
  HTMLInnerText[ImportString["<p>Comment: <textarea>type here</textarea></p>", {"HTML", "XMLObject"}]],
  "Comment:",
  TestID -> "innertext-textarea-no-text"
];

(* The text of a skipped root is trimmed at both ends, as every result is, and
   kept as written inside *)
TestCreate[
  HTMLInnerText[XMLElement["title", {}, {"\n    My \n  page\n  "}]],
  "My \n  page",
  TestID -> "innertext-skip-root-trimmed"
];

(* A document's root element is a top element too: skipped by a rule, it gives
   the document's text content *)
TestCreate[
  HTMLInnerText[
    ImportString["<title>T</title><p>Body</p>", {"HTML", "XMLObject"}],
    "Roles" -> {"html" -> "Skip"}
  ],
  "TBody",
  TestID -> "innertext-roles-skip-document-root"
];
