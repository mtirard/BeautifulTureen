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
