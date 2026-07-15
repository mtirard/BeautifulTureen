Get[FileNameJoin[{ParentDirectory[DirectoryName[$TestFileName]], "Kernel", "BeautifulTureen.wl"}]];

(* --- Test HTML --- *)

$html = "<html><body>
  <div class=\"main\">
    <p>Hello</p>
    <p class=\"special\">World</p>
    <span>Ignored</span>
  </div>
  <div class=\"sidebar\">
    <p>Nav</p>
  </div>
</body></html>";

$tree = ImportString[$html, {"HTML", "XMLObject"}];

(* === Child combinator === *)

VerificationTest[
  HTMLTextContent /@ XMLCases[$tree, Child[XMLPattern["div", CSSClass["main"]], XMLPattern["p"]]],
  {"Hello", "World"},
  TestID -> "child-basic"
];

VerificationTest[
  XMLCases[$tree, Child[XMLPattern["div", CSSClass["main"]], XMLPattern["p"]] :> "found"],
  {"found", "found"},
  TestID -> "child-rule-constant"
];

VerificationTest[
  XMLCases[$tree, Child[XMLPattern["div", CSSClass["main"]], x:XMLPattern["p"]] :> HTMLTextContent[x]],
  {"Hello", "World"},
  TestID -> "child-rule-named"
];

(* Child does not match grandchildren *)
VerificationTest[
  XMLCases[$tree, Child[XMLPattern["body"], XMLPattern["p"]]],
  {},
  TestID -> "child-not-grandchild"
];

(* Child with named attribute on child *)
VerificationTest[
  XMLCases[$tree, Child[XMLPattern["div", CSSClass["main"]], XMLPattern["p", "class" -> cls_]] :> cls],
  {"special"},
  TestID -> "child-rule-attr"
];

(* === Adjacent sibling combinator === *)

$htmlSiblings = "<html><body>
  <div>
    <h2>Title</h2>
    <p class=\"lead\">First</p>
    <p>Second</p>
    <span>Third</span>
    <p>Fourth</p>
  </div>
</body></html>";

$treeSiblings = ImportString[$htmlSiblings, {"HTML", "XMLObject"}];

VerificationTest[
  HTMLTextContent /@ XMLCases[$treeSiblings, Adjacent[XMLPattern["h2"], XMLPattern["p"]]],
  {"First"},
  TestID -> "adjacent-basic"
];

VerificationTest[
  XMLCases[$treeSiblings, Adjacent[XMLPattern["h2"], x:XMLPattern["p"]] :> HTMLTextContent[x]],
  {"First"},
  TestID -> "adjacent-rule-named"
];

(* Adjacent: p immediately after p *)
VerificationTest[
  XMLCases[$treeSiblings, Adjacent[XMLPattern["p", CSSClass["lead"]], x:XMLPattern["p"]] :> HTMLTextContent[x]],
  {"Second"},
  TestID -> "adjacent-p-after-p"
];

(* Adjacent: span is not immediately after h2 *)
VerificationTest[
  XMLCases[$treeSiblings, Adjacent[XMLPattern["h2"], XMLPattern["span"]]],
  {},
  TestID -> "adjacent-not-adjacent"
];

(* Adjacent rule can reference both before and after bindings *)
VerificationTest[
  XMLCases[$treeSiblings,
    Adjacent[h:XMLPattern["h2"], p:XMLPattern["p"]] :> {HTMLTextContent[h], HTMLTextContent[p]}
  ],
  {{"Title", "First"}},
  TestID -> "adjacent-rule-both-bindings"
];

(* === General sibling combinator === *)

VerificationTest[
  HTMLTextContent /@ XMLCases[$treeSiblings, Sibling[XMLPattern["h2"], XMLPattern["p"]]],
  {"First", "Second", "Fourth"},
  TestID -> "sibling-all-after"
];

VerificationTest[
  XMLCases[$treeSiblings, Sibling[XMLPattern["h2"], x:XMLPattern["p"]] :> HTMLTextContent[x]],
  {"First", "Second", "Fourth"},
  TestID -> "sibling-rule-named"
];

(* Sibling: span after h2 \[LongDash] not adjacent, but still a sibling *)
VerificationTest[
  HTMLTextContent /@ XMLCases[$treeSiblings, Sibling[XMLPattern["h2"], XMLPattern["span"]]],
  {"Third"},
  TestID -> "sibling-non-adjacent"
];

(* Sibling: nothing before h2 *)
VerificationTest[
  XMLCases[$treeSiblings, Sibling[XMLPattern["p"], XMLPattern["h2"]]],
  {},
  TestID -> "sibling-wrong-order"
];

(* === Descendant combinator === *)

VerificationTest[
  HTMLTextContent /@ XMLCases[$tree, Descendant[XMLPattern["div", CSSClass["main"]], XMLPattern["p"]]],
  {"Hello", "World"},
  TestID -> "descendant-basic"
];

VerificationTest[
  XMLCases[$tree, Descendant[XMLPattern["div", CSSClass["main"]], x:XMLPattern["p"]] :> HTMLTextContent[x]],
  {"Hello", "World"},
  TestID -> "descendant-rule-named"
];

(* === Base XMLCases with rule === *)

VerificationTest[
  XMLCases[$tree, x:XMLPattern["p"] :> HTMLTextContent[x]],
  {"Hello", "World", "Nav"},
  TestID -> "base-rule-named"
];

(* === Named attribute extraction (benchmark 04 style) === *)

$htmlProducts = "<html><body>
  <div class=\"products\">
    <div class=\"product on-sale\" data-price=\"19.99\">
      <a href=\"/sale\">Sale Item</a>
    </div>
    <div class=\"product\" data-price=\"49.99\">
      <a href=\"/regular\">Regular Item</a>
    </div>
  </div>
</body></html>";

$treeProducts = ImportString[$htmlProducts, {"HTML", "XMLObject"}];

(* Named attribute flows through XMLPattern *)
VerificationTest[
  XMLCases[$treeProducts, XMLPattern["a", "href" -> href_] :> href],
  {"/sale", "/regular"},
  TestID -> "attr-extraction-href"
];

(* Child with named extraction from child *)
VerificationTest[
  XMLCases[$treeProducts,
    Child[XMLPattern["div", CSSClass["on-sale"]], el:XMLPattern["a", "href" -> href_]] :> {HTMLTextContent[el], href}
  ],
  {{"Sale Item", "/sale"}},
  TestID -> "child-rule-full-extraction"
];

(* Cross-level: parent AND child bindings in the same rule *)
VerificationTest[
  XMLCases[$treeProducts,
    Child[XMLPattern["div", CSSClass["product"], "data-price" -> price_], el:XMLPattern["a"]] :> {price, HTMLTextContent[el]}
  ],
  {{"19.99", "Sale Item"}, {"49.99", "Regular Item"}},
  TestID -> "child-rule-cross-level"
];

(* Cross-level with Descendant *)
VerificationTest[
  XMLCases[$treeProducts,
    Descendant[XMLPattern["div", "data-price" -> price_], el:XMLPattern["a"]] :> {price, HTMLTextContent[el]}
  ],
  {{"19.99", "Sale Item"}, {"49.99", "Regular Item"}},
  TestID -> "descendant-rule-cross-level"
];

(* === Namespaced attribute keys ({namespace, name} pairs) === *)

(* WL imports a namespaced attribute such as xlink:href with a two-element
   {namespaceURI, localName} key rather than a plain string. *)
$svg = ImportString[
  "<svg xmlns:xlink=\"http://www.w3.org/1999/xlink\"><use xlink:href=\"#a\"/></svg>",
  {"XML", "XMLObject"}];

(* A plain-string constraint does not match a namespaced key *)
VerificationTest[
  XMLCases[$svg, XMLPattern["use", "href" -> _]],
  {},
  TestID -> "nskey-plain-string-misses"
];

(* Match the local name in any namespace with a {_, name} pair key *)
VerificationTest[
  XMLCases[$svg, XMLPattern["use", {_, "href"} -> href_] :> href],
  {"#a"},
  TestID -> "nskey-pair-any-namespace"
];

(* Match an exact {namespace, name} pair (with a literal value) *)
VerificationTest[
  XMLCases[$svg,
    XMLPattern["use", {"http://www.w3.org/1999/xlink", "href"} -> "#a"] :> "hit"],
  {"hit"},
  TestID -> "nskey-pair-exact"
];

(* A pair key with a pattern local name (Alternatives) is accepted *)
VerificationTest[
  XMLCases[$svg, XMLPattern["use", {_, "href" | "src"} -> href_] :> href],
  {"#a"},
  TestID -> "nskey-pair-alternatives"
];

(* A three-element list is not a valid attribute key -> badconstraint *)
VerificationTest[
  XMLPattern["p", {"a", "b", "c"} -> _],
  $Failed,
  {XMLPattern::badconstraint},
  TestID -> "nskey-bad-triple-list"
];

(* === Integration: real-world page === *)

$realPage = FileNameJoin[{DirectoryName[$TestFileName], "assets", "wolfram-language.html"}];
$realTree = Import[$realPage, {"HTML", "XMLObject"}];

(* OG meta tags via prefix pattern test *)
VerificationTest[
  Length @ XMLCases[$realTree,
    XMLPattern["meta", "property" -> _?(StringStartsQ["og:"]), "content" -> _]
  ],
  5,
  TestID -> "real-og-count"
];

(* OG title is extractable via named slot *)
VerificationTest[
  First @ XMLCases[$realTree,
    XMLPattern["meta", "property" -> "og:title", "content" -> c_] :> c
  ],
  "Wolfram Language: Programming Language + Built-In Knowledge",
  TestID -> "real-og-title"
];

(* Heading alternation preserves document order *)
VerificationTest[
  XMLCases[$realTree,
    h:XMLPattern["h1" | "h2" | "h3"] :> {h[[1]], StringTrim @ HTMLTextContent[h]}
  ][[;; 4]],
  {{"h1", "WOLFRAM"},
   {"h2", "Core Technologies of Wolfram Products"},
   {"h2", "Deployment Options"},
   {"h2", "From the Community"}},
  TestID -> "real-heading-outline"
];

(* Total h1/h2/h3 count *)
VerificationTest[
  Length @ XMLCases[$realTree, XMLPattern["h1" | "h2" | "h3"]],
  43,
  TestID -> "real-heading-count"
];

(* Absolute hrefs \[LongDash] named-slot extraction with pattern-test on value *)
VerificationTest[
  Length @ XMLCases[$realTree,
    XMLPattern["a", "href" -> _?(StringStartsQ[#, {"http://", "https://"}] &)]
  ],
  290,
  TestID -> "real-absolute-href-count"
];

(* JSON-LD: match on attribute *value*, not just existence *)
VerificationTest[
  Length @ XMLCases[$realTree,
    XMLPattern["script", "type" -> "application/ld+json"]
  ],
  2,
  TestID -> "real-jsonld-count"
];

(* === XMLFirstCase === *)

(* Base: returns first match *)
VerificationTest[
  HTMLTextContent @ XMLFirstCase[$tree, XMLPattern["p"]],
  "Hello",
  TestID -> "firstcase-base"
];

(* Base with rule *)
VerificationTest[
  XMLFirstCase[$tree, x:XMLPattern["p"] :> HTMLTextContent[x]],
  "Hello",
  TestID -> "firstcase-base-rule"
];

(* No match \[LongDash] default Missing["NotFound"] *)
VerificationTest[
  XMLFirstCase[$tree, XMLPattern["table"]],
  Missing["NotFound"],
  TestID -> "firstcase-no-match-default"
];

(* No match \[LongDash] explicit default *)
VerificationTest[
  XMLFirstCase[$tree, XMLPattern["table"], "fallback"],
  "fallback",
  TestID -> "firstcase-no-match-explicit"
];

(* Child *)
VerificationTest[
  HTMLTextContent @ XMLFirstCase[$tree,
    Child[XMLPattern["div", CSSClass["main"]], XMLPattern["p"]]
  ],
  "Hello",
  TestID -> "firstcase-child"
];

(* Child with rule *)
VerificationTest[
  XMLFirstCase[$tree,
    Child[XMLPattern["div", CSSClass["main"]], x:XMLPattern["p"]] :> HTMLTextContent[x]
  ],
  "Hello",
  TestID -> "firstcase-child-rule"
];

(* Child miss returns default *)
VerificationTest[
  XMLFirstCase[$tree,
    Child[XMLPattern["body"], XMLPattern["p"]],
    None
  ],
  None,
  TestID -> "firstcase-child-miss"
];

(* Descendant *)
VerificationTest[
  HTMLTextContent @ XMLFirstCase[$tree,
    Descendant[XMLPattern["div", CSSClass["main"]], XMLPattern["p"]]
  ],
  "Hello",
  TestID -> "firstcase-descendant"
];

(* Descendant with rule *)
VerificationTest[
  XMLFirstCase[$treeProducts,
    Descendant[XMLPattern["div", "data-price" -> price_], el:XMLPattern["a"]] :>
      {price, HTMLTextContent[el]}
  ],
  {"19.99", "Sale Item"},
  TestID -> "firstcase-descendant-rule-cross-level"
];

(* Adjacent *)
VerificationTest[
  HTMLTextContent @ XMLFirstCase[$treeSiblings,
    Adjacent[XMLPattern["h2"], XMLPattern["p"]]
  ],
  "First",
  TestID -> "firstcase-adjacent"
];

(* Adjacent with rule \[LongDash] both bindings *)
VerificationTest[
  XMLFirstCase[$treeSiblings,
    Adjacent[h:XMLPattern["h2"], p:XMLPattern["p"]] :> {HTMLTextContent[h], HTMLTextContent[p]}
  ],
  {"Title", "First"},
  TestID -> "firstcase-adjacent-rule-both"
];

(* Sibling *)
VerificationTest[
  HTMLTextContent @ XMLFirstCase[$treeSiblings,
    Sibling[XMLPattern["h2"], XMLPattern["p"]]
  ],
  "First",
  TestID -> "firstcase-sibling"
];

(* Sibling miss *)
VerificationTest[
  XMLFirstCase[$treeSiblings,
    Sibling[XMLPattern["p"], XMLPattern["h2"]]
  ],
  Missing["NotFound"],
  TestID -> "firstcase-sibling-miss"
];

(* Real-world: OG title via rule + base *)
VerificationTest[
  XMLFirstCase[$realTree,
    XMLPattern["meta", "property" -> "og:title", "content" -> c_] :> c
  ],
  "Wolfram Language: Programming Language + Built-In Knowledge",
  TestID -> "firstcase-real-og-title"
];

(* === Alternatives of XMLElement patterns (heterogeneous constraints) === *)

$htmlAlts = "<html><body>
  <a href=\"/foo\">link</a>
  <img src=\"pic.png\" alt=\"x\">
  <p>text</p>
  <iframe src=\"ads.example/banner\"></iframe>
  <div class=\"sponsored\">ad</div>
  <div class=\"content\">article</div>
</body></html>";
$treeAlts = ImportString[$htmlAlts, {"HTML", "XMLObject"}];

(* XMLCases with heterogeneous Alternatives: different tags AND different
   attribute constraints at once *)
VerificationTest[
  Sort[First /@ XMLCases[$treeAlts,
    XMLPattern["a", "href" -> _] | XMLPattern["img", "src" -> _]
  ]],
  {"a", "img"},
  TestID -> "alts-cases-heterogeneous"
];

(* Rule over Alternatives: (pat1 | pat2) :> body *)
VerificationTest[
  Sort @ XMLCases[$treeAlts,
    (XMLPattern["a", "href" -> h_] | XMLPattern["img", "src" -> h_]) :> h
  ],
  {"/foo", "pic.png"},
  TestID -> "alts-cases-rule-over-alternatives"
];

(* Alternatives mixing tag-only and attribute-constrained patterns *)
VerificationTest[
  Length @ XMLCases[$treeAlts,
    XMLPattern["iframe"] | XMLPattern["div", CSSClass["sponsored"]]
  ],
  2,
  TestID -> "alts-cases-tag-and-attr"
];

(* XMLFirstCase with Alternatives *)
VerificationTest[
  First @ XMLFirstCase[$treeAlts,
    XMLPattern["iframe"] | XMLPattern["div", CSSClass["sponsored"]]
  ],
  "iframe",
  TestID -> "alts-firstcase-heterogeneous"
];

(* XMLFirstCase with Alternatives, no match, default fires *)
VerificationTest[
  XMLFirstCase[$treeAlts,
    XMLPattern["video"] | XMLPattern["audio"],
    None
  ],
  None,
  TestID -> "alts-firstcase-no-match-default"
];

(* Bad Alternatives: contains a non-XMLElement \[LongDash] falls through to badpat *)
VerificationTest[
  XMLCases[$treeAlts, XMLPattern["a"] | _String],
  $Failed,
  {XMLCases::badpat},
  TestID -> "alts-cases-bad-non-xmlelement"
];

(* Nested Alternatives from composition: (a|b) | (c|d) stays 2-arg because
   Alternatives has no Flat attribute. Library flattens for validation. *)
VerificationTest[
  Module[{chrome, extras},
    chrome = XMLPattern["a"] | XMLPattern["img"];
    extras = XMLPattern["p"] | XMLPattern["iframe"];
    Sort[First /@ XMLCases[$treeAlts, chrome | extras]]
  ],
  {"a", "iframe", "img", "p"},
  TestID -> "alts-nested-composition"
];

(* XMLDeleteCases with nested Alternatives: same semantics as a single flat one *)
VerificationTest[
  Module[{chrome, extras, flat},
    chrome = XMLPattern["a"] | XMLPattern["img"];
    extras = XMLPattern["iframe"] | XMLPattern["div", CSSClass["sponsored"]];
    flat = XMLPattern["a"] | XMLPattern["img"] | XMLPattern["iframe"] |
      XMLPattern["div", CSSClass["sponsored"]];
    XMLDeleteCases[$treeAlts, chrome | extras] === XMLDeleteCases[$treeAlts, flat]
  ],
  True,
  TestID -> "alts-nested-delete-composition"
];

(* === HTMLTextContent === *)

(* Tracer: lossless concatenation of nested strings, in document order *)
VerificationTest[
  HTMLTextContent[
    XMLElement["p", {}, {"Hi ", XMLElement["em", {}, {"there"}], ", world"}]
  ],
  "Hi there, world",
  TestID -> "textcontent-concat"
];

(* Bug fix: descend into a whole XMLObject["Document"] (old HTMLTextContent returned "") *)
VerificationTest[
  HTMLTextContent[
    ImportString["<p>Hello</p>", {"HTML", "XMLObject"}]
  ],
  "Hello",
  TestID -> "textcontent-document-descends"
];

(* List input (the XMLCases surface): concatenate each element's text content *)
VerificationTest[
  HTMLTextContent[{
    XMLElement["p", {}, {"a"}],
    XMLElement["p", {}, {"b"}]
  }],
  "ab",
  TestID -> "textcontent-list"
];

(* Bad argument: a non-tree messages and returns $Failed (mirrors XMLCases::badtree) *)
VerificationTest[
  HTMLTextContent[37],
  $Failed,
  {HTMLTextContent::badtree},
  TestID -> "textcontent-badtree"
];

(* Internal totality: a stray comment node contributes "" mid-walk, no message *)
VerificationTest[
  HTMLTextContent[
    XMLElement["p", {}, {"a", XMLObject["Comment"]["ignore me"], "b"}]
  ],
  "ab",
  TestID -> "textcontent-stray-node-total"
];

(* === HTMLInnerText === *)

(* Tracer: collapse internal whitespace, flow inline children, trim ends *)
VerificationTest[
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

VerificationTest[
  HTMLInnerText[$itBlocks],
  "Title\nFirst para.\nSecond bold para.",
  TestID -> "innertext-block-breaks"
];

(* BlockSeparator option widens the gap between block boundaries *)
VerificationTest[
  HTMLInnerText[$itBlocks, "BlockSeparator" -> "\n\n"],
  "Title\n\nFirst para.\n\nSecond bold para.",
  TestID -> "innertext-block-separator"
];

(* <pre> content is preserved verbatim, on its own block line *)
VerificationTest[
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
VerificationTest[
  HTMLInnerText[
    XMLElement["p", {}, {"line1", XMLElement["br", {}, {}], "line2"}],
    "BlockSeparator" -> "\n\n"
  ],
  "line1\nline2",
  TestID -> "innertext-br-newline"
];

(* Skip: script/style and their subtrees are dropped *)
VerificationTest[
  HTMLInnerText[
    XMLElement["section", {}, {
      XMLElement["script", {}, {"var x=1;"}],
      XMLElement["p", {}, {"Visible."}]}]
  ],
  "Visible.",
  TestID -> "innertext-skip-script"
];

(* Roles override: drop a screenreader-only span by class, reusing CSSClass *)
VerificationTest[
  HTMLInnerText[
    XMLElement["div", {}, {
      "keep ",
      XMLElement["span", {"class" -> "sr-only"}, {"screenreader"}],
      "this"}],
    "Roles" -> {XMLPattern["span", CSSClass["sr-only"]] -> "Skip"}
  ],
  "keep this",
  TestID -> "innertext-roles-cssclass-skip"
];

(* Roles: a bare string LHS sugars to XMLPattern[string] (exact tag match) *)
VerificationTest[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLElement["em", {}, {"b"}], "c"}],
    "Roles" -> {"em" -> "Block"}
  ],
  "a\nb\nc",
  TestID -> "innertext-roles-string-sugar"
];

(* Roles: an Association sugars to an ordered rule list *)
VerificationTest[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLElement["em", {}, {"b"}], "c"}],
    "Roles" -> <|"em" -> "Block"|>
  ],
  "a\nb\nc",
  TestID -> "innertext-roles-association-sugar"
];

(* badrole: a literal non-role RHS messages and defers to the frozen table
   (em falls back to Inline, so "abc") *)
VerificationTest[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLElement["em", {}, {"b"}], "c"}],
    "Roles" -> {"em" -> "Bogus"}
  ],
  "abc",
  {HTMLInnerText::badrole},
  TestID -> "innertext-badrole-literal"
];

(* badrole: a delayed rule's RHS validates at runtime, too *)
VerificationTest[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLElement["em", {}, {"b"}], "c"}],
    "Roles" -> {"em" :> StringJoin["Not", "ARole"]}
  ],
  "abc",
  {HTMLInnerText::badrole},
  TestID -> "innertext-badrole-delayed"
];

(* A delayed rule producing a valid role works (em -> Block via :>) *)
VerificationTest[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLElement["em", {}, {"b"}], "c"}],
    "Roles" -> {XMLPattern["em"] :> "Block"}
  ],
  "a\nb\nc",
  TestID -> "innertext-roles-delayed-valid"
];

(* Bad argument: a non-tree messages and returns $Failed *)
VerificationTest[
  HTMLInnerText[37],
  $Failed,
  {HTMLInnerText::badtree},
  TestID -> "innertext-badtree"
];

(* Bare string input: collapse and trim *)
VerificationTest[
  HTMLInnerText["  hi   there  "],
  "hi there",
  TestID -> "innertext-bare-string"
];

(* List input: each top-level element joined at block boundaries *)
VerificationTest[
  HTMLInnerText[{
    XMLElement["p", {}, {"a"}],
    XMLElement["p", {}, {"b"}]}],
  "a\nb",
  TestID -> "innertext-list"
];

(* Unknown tag defaults to Inline (flows, no break) *)
VerificationTest[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLElement["custom-thing", {}, {"b"}], "c"}]
  ],
  "abc",
  TestID -> "innertext-unknown-tag-inline"
];

(* Internal totality: a stray comment node contributes nothing, no message *)
VerificationTest[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLObject["Comment"]["ignore me"], "b"}]
  ],
  "ab",
  TestID -> "innertext-stray-node-total"
];

(* Block boundaries at the very ends are trimmed (no leading/trailing newline) *)
VerificationTest[
  HTMLInnerText[
    XMLElement["div", {}, {XMLElement["p", {}, {"only"}]}]
  ],
  "only",
  TestID -> "innertext-trim-ends"
];

(* Roles are tried in order, first match wins (Replace convention, not specificity) *)
VerificationTest[
  HTMLInnerText[
    XMLElement["p", {}, {"a", XMLElement["em", {}, {"b"}], "c"}],
    "Roles" -> {"em" -> "Skip", "em" -> "Block"}
  ],
  "ac",
  TestID -> "innertext-roles-first-match"
];

(* === XMLDeleteCases === *)

$htmlNoise = "<html><body>
  <script>alert(1)</script>
  <style>body{color:red}</style>
  <p>visible</p>
  <noscript>fallback</noscript>
  <div><script>nested</script><p>inside</p></div>
</body></html>";
$treeNoise = ImportString[$htmlNoise, {"HTML", "XMLObject"}];

(* Base: single tag removed *)
VerificationTest[
  XMLCases[XMLDeleteCases[$treeNoise, XMLPattern["script"]], XMLPattern["script"]],
  {},
  TestID -> "delete-base-single"
];

(* Base: Alternatives of XMLElement patterns *)
VerificationTest[
  XMLCases[
    XMLDeleteCases[$treeNoise, XMLPattern["script"] | XMLPattern["style"] | XMLPattern["noscript"]],
    XMLPattern["script" | "style" | "noscript"]
  ],
  {},
  TestID -> "delete-base-alternatives"
];

(* Surviving elements unchanged *)
VerificationTest[
  HTMLTextContent /@ XMLCases[
    XMLDeleteCases[$treeNoise, XMLPattern["script"] | XMLPattern["style"] | XMLPattern["noscript"]],
    XMLPattern["p"]
  ],
  {"visible", "inside"},
  TestID -> "delete-base-preserves"
];

(* Tree envelope preserved: XMLObject["Document"] root survives *)
VerificationTest[
  Head @ XMLDeleteCases[$treeNoise, XMLPattern["script"]],
  XMLObject["Document"],
  TestID -> "delete-envelope-preserved"
];

(* No-match: tree returned unchanged *)
VerificationTest[
  XMLDeleteCases[$treeNoise, XMLPattern["nonexistent"]] === $treeNoise,
  True,
  TestID -> "delete-no-match"
];

(* Child: scope deletion to direct children of parents *)
$htmlScoped = "<html><body>
  <div class=\"article\">
    <p>keep</p>
    <p class=\"ad\">remove me</p>
  </div>
  <p class=\"ad\">keep me (not inside article)</p>
</body></html>";
$treeScoped = ImportString[$htmlScoped, {"HTML", "XMLObject"}];

VerificationTest[
  Length @ XMLCases[
    XMLDeleteCases[$treeScoped,
      Child[XMLPattern["div", CSSClass["article"]], XMLPattern[_, CSSClass["ad"]]]
    ],
    XMLPattern[_, CSSClass["ad"]]
  ],
  1,
  TestID -> "delete-child-scoped"
];

(* Descendant: scope deletion inside an ancestor *)
$htmlNested = "<html><body>
  <article>
    <section>
      <p class=\"ad\">deep ad</p>
      <p>body</p>
    </section>
  </article>
  <p class=\"ad\">outside \[LongDash] keep</p>
</body></html>";
$treeNested = ImportString[$htmlNested, {"HTML", "XMLObject"}];

VerificationTest[
  HTMLTextContent /@ XMLCases[
    XMLDeleteCases[$treeNested,
      Descendant[XMLPattern["article"], XMLPattern[_, CSSClass["ad"]]]
    ],
    XMLPattern[_, CSSClass["ad"]]
  ],
  {"outside \[LongDash] keep"},
  TestID -> "delete-descendant-scoped"
];

(* Nested matching parents: Descendant[div, div] \[LongDash] outer div survives, inner divs removed *)
$htmlNestedSame = XMLElement["div", {},
  {"A", XMLElement["div", {}, {"B", XMLElement["div", {}, {"C"}]}]}
];

VerificationTest[
  XMLDeleteCases[$htmlNestedSame,
    Descendant[XMLPattern["div"], XMLPattern["div"]]
  ],
  XMLElement["div", {}, {"A"}],
  TestID -> "delete-descendant-nested-same-tag"
];

(* Adjacent/Sibling emit unsupported message *)
VerificationTest[
  XMLDeleteCases[$treeNoise, Adjacent[XMLPattern["p"], XMLPattern["p"]]],
  $Failed,
  {XMLDeleteCases::unsupported},
  TestID -> "delete-adjacent-unsupported"
];

(* Bad pattern fallback *)
VerificationTest[
  XMLDeleteCases[$treeNoise, "not-a-pattern"],
  $Failed,
  {XMLDeleteCases::badpat},
  TestID -> "delete-bad-pattern"
];

(* === HTMLToNotebook === *)

(* The contract is judged by I/O: HTML in, Markdown (via Export) out. *)
nbmd[h_String] := ExportString[
  HTMLToNotebook[ImportString[h, {"HTML", "XMLObject"}]], "Markdown"];
nbmd2[h_String, opts___] := ExportString[
  HTMLToNotebook[ImportString[h, {"HTML", "XMLObject"}], opts], "Markdown"];

(* Returns a Notebook[...] expression *)
VerificationTest[
  Head @ HTMLToNotebook[XMLElement["p", {}, {"hi"}]],
  Notebook,
  TestID -> "htn-returns-notebook"
];

(* Paragraph -> a single Text cell -> plain line *)
VerificationTest[
  nbmd["<p>Hello</p>"],
  "Hello",
  TestID -> "htn-paragraph"
];

(* All six headings map 1:1 to Title/Chapter/Section/Subsection/...  *)
VerificationTest[
  nbmd["<h1>A</h1><h2>B</h2><h3>C</h3><h4>D</h4><h5>E</h5><h6>F</h6>"],
  "# A\n\n## B\n\n### C\n\n#### D\n\n##### E\n\n###### F",
  TestID -> "htn-headings"
];

(* Inline constructs: bold, italic, inline code, hyperlink *)
VerificationTest[
  nbmd["<p>plain <b>bold</b> <i>it</i> <code>c</code> <a href=\"http://x\">l</a></p>"],
  "plain **bold** *it* `c` [l](http://x)",
  TestID -> "htn-inline-formatting"
];

(* StrikeThrough survives; Underline has no Markdown form and drops to plain *)
VerificationTest[
  nbmd["<p><s>x</s> <u>y</u></p>"],
  "~~x~~ y",
  TestID -> "htn-strike-underline"
];

(* Inline synonyms fold to the same construct (em/cite -> Italic, del -> Strike) *)
VerificationTest[
  nbmd["<p><em>e</em> <cite>c</cite> <del>d</del></p>"],
  "*e* *c* ~~d~~",
  TestID -> "htn-inline-synonyms"
];

(* Internal whitespace collapses; the inline run trims at the cell edges *)
VerificationTest[
  nbmd["<p>Hi   <em>there</em>,\n   world</p>"],
  "Hi *there*, world",
  TestID -> "htn-collapse-inline"
];

(* A bare string becomes a single Text cell, whitespace-collapsed and trimmed *)
VerificationTest[
  ExportString[HTMLToNotebook["  hi   there  "], "Markdown"],
  "hi there",
  TestID -> "htn-bare-string"
];

(* Top-level inline content is wrapped in a Text cell *)
VerificationTest[
  ExportString[HTMLToNotebook[XMLElement["b", {}, {"bold"}]], "Markdown"],
  "**bold**",
  TestID -> "htn-toplevel-inline"
];

(* Consecutive block siblings become separate cells (no merging) *)
VerificationTest[
  nbmd["<div><p>one</p><p>two</p></div>"],
  "one\n\ntwo",
  TestID -> "htn-block-separation"
];

(* script/style and their subtrees are skipped *)
VerificationTest[
  nbmd["<section><script>var x=1</script><p>Visible</p></section>"],
  "Visible",
  TestID -> "htn-skip-script"
];

(* An <a> with no usable href degrades to plain text *)
VerificationTest[
  nbmd["<p><a>nolink</a></p>"],
  "nolink",
  TestID -> "htn-no-href-plain"
];

(* Bad input messages and returns $Failed, mirroring the siblings *)
VerificationTest[
  HTMLToNotebook[37],
  $Failed,
  {HTMLToNotebook::badtree},
  TestID -> "htn-badtree"
];

(* Unordered list -> bullet items *)
VerificationTest[
  nbmd["<ul><li>one</li><li>two</li></ul>"],
  "- one\n\n- two",
  TestID -> "htn-ul"
];

(* Ordered list -> numbered items (GFM emits 1. per item) *)
VerificationTest[
  nbmd["<ol><li>first</li><li>second</li></ol>"],
  "1. first\n\n1. second",
  TestID -> "htn-ol"
];

(* Nested list: depth carried by the style name (Item -> Subitem) -> indent *)
VerificationTest[
  nbmd["<ul><li>a<ul><li>a1</li><li>a2</li></ul></li><li>b</li></ul>"],
  "- a\n\n    - a1\n\n    - a2\n\n- b",
  TestID -> "htn-nested-list"
];

(* Mixed ordered-then-unordered nesting *)
VerificationTest[
  nbmd["<ol><li>n1<ul><li>bullet</li></ul></li></ol>"],
  "1. n1\n\n    - bullet",
  TestID -> "htn-mixed-list"
];

(* Inline formatting survives inside a list item *)
VerificationTest[
  nbmd["<ul><li>has <b>bold</b> in it</li></ul>"],
  "- has **bold** in it",
  TestID -> "htn-list-item-inline"
];

(* <hr> -> a horizontal rule *)
VerificationTest[
  nbmd["<p>above</p><hr><p>below</p>"],
  "above\n\n---\n\nbelow",
  TestID -> "htn-hr"
];

(* <pre> -> a verbatim fenced code block, whitespace preserved *)
VerificationTest[
  nbmd["<pre>for x:\n  print x</pre>"],
  "```\nfor x:\n  print x\n```",
  TestID -> "htn-pre"
];

(* <pre><code> collapses to one verbatim block (leaf-collapsing, not inline) *)
VerificationTest[
  nbmd["<pre><code>x = 1\ny = 2</code></pre>"],
  "```\nx = 1\ny = 2\n```",
  TestID -> "htn-pre-code"
];

(* <blockquote> -> a framed Text cell -> "> " prefixed lines (the lone
   trailing "> " is an inherent artifact of the framed-cell Markdown export) *)
VerificationTest[
  nbmd["<blockquote>hello world</blockquote>"],
  "> hello world\n>\n>",
  TestID -> "htn-blockquote"
];

(* Multiple paragraphs in a quote are separated by a blank quote line *)
VerificationTest[
  nbmd["<blockquote><p>one</p><p>two</p></blockquote>"],
  "> one\n>\n> two",
  TestID -> "htn-blockquote-multipara"
];

(* Inline formatting survives inside a quote *)
VerificationTest[
  nbmd["<blockquote><p>a <b>bold</b> c</p></blockquote>"],
  "> a **bold** c\n>\n>",
  TestID -> "htn-blockquote-inline"
];

(* Nested quotes compose: the inner line carries its own "> ", the outer frame
   adds another -> "> > " *)
VerificationTest[
  nbmd["<blockquote><p>outer</p><blockquote><p>inner</p></blockquote></blockquote>"],
  "> outer\n>\n> > inner",
  TestID -> "htn-blockquote-nested"
];

(* A list inside a quote flattens to one line per item *)
VerificationTest[
  nbmd["<blockquote><ul><li>x</li><li>y</li></ul></blockquote>"],
  "> x\n>\n> y",
  TestID -> "htn-blockquote-list-flatten"
];

(* <table> with a <thead> of unique labels -> Dataset -> GFM header row *)
VerificationTest[
  nbmd["<table><thead><tr><th>Name</th><th>Age</th></tr></thead><tbody><tr><td>Ann</td><td>30</td></tr><tr><td>Bob</td><td>25</td></tr></tbody></table>"],
  "| Name | Age |\n| - | - |\n| Ann | 30 |\n| Bob | 25 |",
  TestID -> "htn-table-header"
];

(* A leading all-<th> row (no <thead>) is also treated as the header *)
VerificationTest[
  nbmd["<table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table>"],
  "| A | B |\n| - | - |\n| 1 | 2 |",
  TestID -> "htn-table-th-firstrow"
];

(* No header row -> Grid -> blank GFM header, every row preserved (lossless) *)
VerificationTest[
  nbmd["<table><tr><td>r1c1</td><td>r1c2</td></tr><tr><td>r2c1</td><td>r2c2</td></tr></table>"],
  "|  |  |\n| - | - |\n| r1c1 | r1c2 |\n| r2c1 | r2c2 |",
  TestID -> "htn-table-no-header"
];

(* Duplicate header labels would collapse a Dataset column -> fall back to the
   lossless Grid, keeping the header row as data (no silent column loss) *)
VerificationTest[
  nbmd["<table><tr><th>X</th><th>X</th></tr><tr><td>1</td><td>2</td></tr></table>"],
  "|  |  |\n| - | - |\n| X | X |\n| 1 | 2 |",
  TestID -> "htn-table-dup-header-lossless"
];

(* === HTMLToNotebook: Roles + Constructs overrides === *)

(* "Roles" (Layer 1) shares HTMLInnerText's machinery: skip a block by class *)
VerificationTest[
  ExportString[
    HTMLToNotebook[
      ImportString["<div><p>keep</p><p class=\"ad\">drop</p></div>", {"HTML", "XMLObject"}],
      "Roles" -> {XMLPattern["p", CSSClass["ad"]] -> "Skip"}],
    "Markdown"],
  "keep",
  TestID -> "htn-roles-skip"
];

(* "Roles": force a normally-inline tag onto its own block (cells, not flow) *)
VerificationTest[
  nbmd2["<p>a<em>b</em>c</p>", "Roles" -> {"em" -> "Block"}],
  "a\n\nb\n\nc",
  TestID -> "htn-roles-block"
];

(* "Constructs" block cell-style string RHS: render <p> as a Section heading *)
VerificationTest[
  nbmd2["<p>hi</p>", "Constructs" -> {"p" -> "Section"}],
  "### hi",
  TestID -> "htn-constructs-block-style"
];

(* "Constructs" inline token RHS: render an inline tag as bold *)
VerificationTest[
  nbmd2["<p>see <abbr>WL</abbr></p>", "Constructs" -> {"abbr" -> "Bold"}],
  "see **WL**",
  TestID -> "htn-constructs-inline-token"
];

(* "Constructs" constructor-function RHS: the universal escape hatch *)
VerificationTest[
  nbmd2["<p>x</p><foo>y</foo>",
    "Constructs" -> {"foo" :> Function[el, Cell["custom!", "Text"]]}],
  "x\n\ncustom!",
  TestID -> "htn-constructs-function"
];

(* "Constructs" rules are tried in order, first match wins *)
VerificationTest[
  nbmd2["<p>x<b>y</b></p>", "Constructs" -> {"b" -> "Italic", "b" -> "Bold"}],
  "x*y*",
  TestID -> "htn-constructs-first-match"
];

(* "Constructs" delayed RHS can compute the construct from the matched element *)
VerificationTest[
  nbmd2["<p><tag data-x=\"1\"></tag></p>",
    "Constructs" -> {XMLPattern["tag"] :>
      Function[el, "[" <> Lookup[Association[el[[2]]], "data-x", "?"] <> "]"]}],
  "[1]",
  TestID -> "htn-constructs-delayed-attr"
];

(* The built-in <table> default is itself a construct rule, so it is overridable *)
VerificationTest[
  nbmd2["<table><tr><td>a</td></tr></table>",
    "Constructs" -> {"table" :> Function[el, Cell["TABLE", "Text"]]}],
  "TABLE",
  TestID -> "htn-constructs-table-override"
];
