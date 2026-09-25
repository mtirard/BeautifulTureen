(* HTMLToNotebook: HTML -> Notebook[...] -> Markdown (via Export). Covers block
   and inline constructs, lists, quotes, tables, and the Roles/Constructs
   override layers. The nbmd/nbmd2 helpers are local to this file. *)

(* The contract is judged by I/O: HTML in, Markdown (via Export) out. *)
nbmd[h_String] := ExportString[
  HTMLToNotebook[ImportString[h, {"HTML", "XMLObject"}]], "Markdown"];
nbmd2[h_String, opts___] := ExportString[
  HTMLToNotebook[ImportString[h, {"HTML", "XMLObject"}], opts], "Markdown"];

(* Returns a Notebook[...] expression *)
TestCreate[
  Head @ HTMLToNotebook[XMLElement["p", {}, {"hi"}]],
  Notebook,
  TestID -> "htn-returns-notebook"
];

(* Paragraph -> a single Text cell -> plain line *)
TestCreate[
  nbmd["<p>Hello</p>"],
  "Hello",
  TestID -> "htn-paragraph"
];

(* All six headings map 1:1 to Title/Chapter/Section/Subsection/...  *)
TestCreate[
  nbmd["<h1>A</h1><h2>B</h2><h3>C</h3><h4>D</h4><h5>E</h5><h6>F</h6>"],
  "# A\n\n## B\n\n### C\n\n#### D\n\n##### E\n\n###### F",
  TestID -> "htn-headings"
];

(* Inline constructs: bold, italic, inline code, hyperlink *)
TestCreate[
  nbmd["<p>plain <b>bold</b> <i>it</i> <code>c</code> <a href=\"http://x\">l</a></p>"],
  "plain **bold** *it* `c` [l](http://x)",
  TestID -> "htn-inline-formatting"
];

(* StrikeThrough survives; Underline has no Markdown form and drops to plain *)
TestCreate[
  nbmd["<p><s>x</s> <u>y</u></p>"],
  "~~x~~ y",
  TestID -> "htn-strike-underline"
];

(* Inline synonyms fold to the same construct (em/cite -> Italic, del -> Strike) *)
TestCreate[
  nbmd["<p><em>e</em> <cite>c</cite> <del>d</del></p>"],
  "*e* *c* ~~d~~",
  TestID -> "htn-inline-synonyms"
];

(* Internal whitespace collapses; the inline run trims at the cell edges *)
TestCreate[
  nbmd["<p>Hi   <em>there</em>,\n   world</p>"],
  "Hi *there*, world",
  TestID -> "htn-collapse-inline"
];

(* A bare string becomes a single Text cell, whitespace-collapsed and trimmed *)
TestCreate[
  ExportString[HTMLToNotebook["  hi   there  "], "Markdown"],
  "hi there",
  TestID -> "htn-bare-string"
];

(* Top-level inline content is wrapped in a Text cell *)
TestCreate[
  ExportString[HTMLToNotebook[XMLElement["b", {}, {"bold"}]], "Markdown"],
  "**bold**",
  TestID -> "htn-toplevel-inline"
];

(* Consecutive block siblings become separate cells (no merging) *)
TestCreate[
  nbmd["<div><p>one</p><p>two</p></div>"],
  "one\n\ntwo",
  TestID -> "htn-block-separation"
];

(* script/style and their subtrees are skipped *)
TestCreate[
  nbmd["<section><script>var x=1</script><p>Visible</p></section>"],
  "Visible",
  TestID -> "htn-skip-script"
];

(* An <a> with no usable href degrades to plain text *)
TestCreate[
  nbmd["<p><a>nolink</a></p>"],
  "nolink",
  TestID -> "htn-no-href-plain"
];

(* Bad input messages and returns $Failed, mirroring the siblings *)
TestCreate[
  HTMLToNotebook[37],
  $Failed,
  {HTMLToNotebook::badtree},
  TestID -> "htn-badtree"
];

(* Unordered list -> bullet items *)
TestCreate[
  nbmd["<ul><li>one</li><li>two</li></ul>"],
  "- one\n\n- two",
  TestID -> "htn-ul"
];

(* Ordered list -> numbered items (GFM emits 1. per item) *)
TestCreate[
  nbmd["<ol><li>first</li><li>second</li></ol>"],
  "1. first\n\n1. second",
  TestID -> "htn-ol"
];

(* Nested list: depth carried by the style name (Item -> Subitem) -> indent *)
TestCreate[
  nbmd["<ul><li>a<ul><li>a1</li><li>a2</li></ul></li><li>b</li></ul>"],
  "- a\n\n    - a1\n\n    - a2\n\n- b",
  TestID -> "htn-nested-list"
];

(* Mixed ordered-then-unordered nesting *)
TestCreate[
  nbmd["<ol><li>n1<ul><li>bullet</li></ul></li></ol>"],
  "1. n1\n\n    - bullet",
  TestID -> "htn-mixed-list"
];

(* Inline formatting survives inside a list item *)
TestCreate[
  nbmd["<ul><li>has <b>bold</b> in it</li></ul>"],
  "- has **bold** in it",
  TestID -> "htn-list-item-inline"
];

(* <hr> -> a horizontal rule *)
TestCreate[
  nbmd["<p>above</p><hr><p>below</p>"],
  "above\n\n---\n\nbelow",
  TestID -> "htn-hr"
];

(* <pre> -> a verbatim fenced code block, whitespace preserved *)
TestCreate[
  nbmd["<pre>for x:\n  print x</pre>"],
  "```\nfor x:\n  print x\n```",
  TestID -> "htn-pre"
];

(* <pre><code> collapses to one verbatim block (leaf-collapsing, not inline) *)
TestCreate[
  nbmd["<pre><code>x = 1\ny = 2</code></pre>"],
  "```\nx = 1\ny = 2\n```",
  TestID -> "htn-pre-code"
];

(* <blockquote> -> a framed Text cell -> "> " prefixed lines (the lone
   trailing "> " is an inherent artifact of the framed-cell Markdown export) *)
TestCreate[
  nbmd["<blockquote>hello world</blockquote>"],
  "> hello world\n>\n>",
  TestID -> "htn-blockquote"
];

(* Multiple paragraphs in a quote are separated by a blank quote line *)
TestCreate[
  nbmd["<blockquote><p>one</p><p>two</p></blockquote>"],
  "> one\n>\n> two",
  TestID -> "htn-blockquote-multipara"
];

(* Inline formatting survives inside a quote *)
TestCreate[
  nbmd["<blockquote><p>a <b>bold</b> c</p></blockquote>"],
  "> a **bold** c\n>\n>",
  TestID -> "htn-blockquote-inline"
];

(* Nested quotes compose: the inner line carries its own "> ", the outer frame
   adds another -> "> > " *)
TestCreate[
  nbmd["<blockquote><p>outer</p><blockquote><p>inner</p></blockquote></blockquote>"],
  "> outer\n>\n> > inner",
  TestID -> "htn-blockquote-nested"
];

(* A list inside a quote flattens to one line per item *)
TestCreate[
  nbmd["<blockquote><ul><li>x</li><li>y</li></ul></blockquote>"],
  "> x\n>\n> y",
  TestID -> "htn-blockquote-list-flatten"
];

(* <table> with a <thead> of unique labels -> Dataset -> GFM header row *)
TestCreate[
  nbmd["<table><thead><tr><th>Name</th><th>Age</th></tr></thead><tbody><tr><td>Ann</td><td>30</td></tr><tr><td>Bob</td><td>25</td></tr></tbody></table>"],
  "| Name | Age |\n| - | - |\n| Ann | 30 |\n| Bob | 25 |",
  TestID -> "htn-table-header"
];

(* A leading all-<th> row (no <thead>) is also treated as the header *)
TestCreate[
  nbmd["<table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table>"],
  "| A | B |\n| - | - |\n| 1 | 2 |",
  TestID -> "htn-table-th-firstrow"
];

(* No header row -> Grid -> blank GFM header, every row preserved (lossless) *)
TestCreate[
  nbmd["<table><tr><td>r1c1</td><td>r1c2</td></tr><tr><td>r2c1</td><td>r2c2</td></tr></table>"],
  "|  |  |\n| - | - |\n| r1c1 | r1c2 |\n| r2c1 | r2c2 |",
  TestID -> "htn-table-no-header"
];

(* Duplicate header labels would collapse a Dataset column -> fall back to the
   lossless Grid, keeping the header row as data (no silent column loss) *)
TestCreate[
  nbmd["<table><tr><th>X</th><th>X</th></tr><tr><td>1</td><td>2</td></tr></table>"],
  "|  |  |\n| - | - |\n| X | X |\n| 1 | 2 |",
  TestID -> "htn-table-dup-header-lossless"
];

(* === HTMLToNotebook: Roles + Constructs overrides === *)

(* "Roles" (Layer 1) shares HTMLInnerText's machinery: skip a block by class *)
TestCreate[
  ExportString[
    HTMLToNotebook[
      ImportString["<div><p>keep</p><p class=\"ad\">drop</p></div>", {"HTML", "XMLObject"}],
      "Roles" -> {XMLPattern["p", "classList" -> "ad"] -> "Skip"}],
    "Markdown"],
  "keep",
  TestID -> "htn-roles-skip"
];

(* "Roles": force a normally-inline tag onto its own block (cells, not flow) *)
TestCreate[
  nbmd2["<p>a<em>b</em>c</p>", "Roles" -> {"em" -> "Block"}],
  "a\n\nb\n\nc",
  TestID -> "htn-roles-block"
];

(* "Constructs" block cell-style string RHS: render <p> as a Section heading *)
TestCreate[
  nbmd2["<p>hi</p>", "Constructs" -> {"p" -> "Section"}],
  "### hi",
  TestID -> "htn-constructs-block-style"
];

(* "Constructs" inline token RHS: render an inline tag as bold *)
TestCreate[
  nbmd2["<p>see <abbr>WL</abbr></p>", "Constructs" -> {"abbr" -> "Bold"}],
  "see **WL**",
  TestID -> "htn-constructs-inline-token"
];

(* "Constructs" constructor-function RHS: the universal escape hatch *)
TestCreate[
  nbmd2["<p>x</p><foo>y</foo>",
    "Constructs" -> {"foo" :> Function[el, Cell["custom!", "Text"]]}],
  "x\n\ncustom!",
  TestID -> "htn-constructs-function"
];

(* "Constructs" rules are tried in order, first match wins *)
TestCreate[
  nbmd2["<p>x<b>y</b></p>", "Constructs" -> {"b" -> "Italic", "b" -> "Bold"}],
  "x*y*",
  TestID -> "htn-constructs-first-match"
];

(* "Constructs" delayed RHS can compute the construct from the matched element *)
TestCreate[
  nbmd2["<p><tag data-x=\"1\"></tag></p>",
    "Constructs" -> {XMLPattern["tag"] :>
      Function[el, "[" <> Lookup[Association[el[[2]]], "data-x", "?"] <> "]"]}],
  "[1]",
  TestID -> "htn-constructs-delayed-attr"
];

(* The built-in <table> default is itself a construct rule, so it is overridable *)
TestCreate[
  nbmd2["<table><tr><td>a</td></tr></table>",
    "Constructs" -> {"table" :> Function[el, Cell["TABLE", "Text"]]}],
  "TABLE",
  TestID -> "htn-constructs-table-override"
];

(* === Rules naming the classList key === *)

(* A rule naming a list key materialises the tree once, at entry; the output is
   the same as on the tree as it is. The fixture carries a link, an image, a table
   and classes, the parts that read attributes. *)
$rich = ImportString[
  "<div class=\"main\"><h2 class=\"t\">T</h2><p class=\"lead\">see <a href=\"/x\" class=\"ext\">x</a> \
<img src=\"i.png\" alt=\"pic\"></p><table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table>\
<ul class=\"menu\"><li>one</li></ul></div>",
  {"HTML", "XMLObject"}];

TestCreate[
  HTMLToNotebook[$rich,
    "Roles" -> {XMLPattern["p", "classList" -> "nomatch"] -> "Skip"},
    "Constructs" -> {XMLPattern["b", "classList" -> "nomatch"] -> "Italic"}] === HTMLToNotebook[$rich],
  True,
  TestID -> "htn-materialised-output-identical"
];

TestCreate[
  nbmd2["<p>a <span class=\"kw hot\">b</span></p>",
    "Constructs" -> {XMLPattern["span", "classList" -> "kw"] -> "Bold"}],
  "a **b**",
  TestID -> "htn-constructs-classlist"
];

TestCreate[
  nbmd2["<p class=\"x\">keep</p><p>drop</p>",
    "Roles" -> {XMLPattern["p", "classList" -> {}] -> "Skip"}],
  "keep",
  TestID -> "htn-roles-classlist-absent"
];

(* A rule is tried against one element, so a combinator is refused. *)
TestCreate[
  HTMLToNotebook[XMLElement["p", {}, {"x"}],
    "Roles" -> {Child[XMLPattern["div"], XMLPattern["p"]] -> "Skip"}],
  $Failed,
  {HTMLToNotebook::badpat},
  TestID -> "htn-rule-combinator-refused"
];
