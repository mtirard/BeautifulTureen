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
  HTMLText /@ XMLCases[$tree, Child[XMLPattern["div", CSSClass["main"]], XMLPattern["p"]]],
  {"Hello", "World"},
  TestID -> "child-basic"
];

VerificationTest[
  XMLCases[$tree, Child[XMLPattern["div", CSSClass["main"]], XMLPattern["p"]] :> "found"],
  {"found", "found"},
  TestID -> "child-rule-constant"
];

VerificationTest[
  XMLCases[$tree, Child[XMLPattern["div", CSSClass["main"]], x:XMLPattern["p"]] :> HTMLText[x]],
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
  HTMLText /@ XMLCases[$treeSiblings, Adjacent[XMLPattern["h2"], XMLPattern["p"]]],
  {"First"},
  TestID -> "adjacent-basic"
];

VerificationTest[
  XMLCases[$treeSiblings, Adjacent[XMLPattern["h2"], x:XMLPattern["p"]] :> HTMLText[x]],
  {"First"},
  TestID -> "adjacent-rule-named"
];

(* Adjacent: p immediately after p *)
VerificationTest[
  XMLCases[$treeSiblings, Adjacent[XMLPattern["p", CSSClass["lead"]], x:XMLPattern["p"]] :> HTMLText[x]],
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
    Adjacent[h:XMLPattern["h2"], p:XMLPattern["p"]] :> {HTMLText[h], HTMLText[p]}
  ],
  {{"Title", "First"}},
  TestID -> "adjacent-rule-both-bindings"
];

(* === General sibling combinator === *)

VerificationTest[
  HTMLText /@ XMLCases[$treeSiblings, Sibling[XMLPattern["h2"], XMLPattern["p"]]],
  {"First", "Second", "Fourth"},
  TestID -> "sibling-all-after"
];

VerificationTest[
  XMLCases[$treeSiblings, Sibling[XMLPattern["h2"], x:XMLPattern["p"]] :> HTMLText[x]],
  {"First", "Second", "Fourth"},
  TestID -> "sibling-rule-named"
];

(* Sibling: span after h2 \[LongDash] not adjacent, but still a sibling *)
VerificationTest[
  HTMLText /@ XMLCases[$treeSiblings, Sibling[XMLPattern["h2"], XMLPattern["span"]]],
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
  HTMLText /@ XMLCases[$tree, Descendant[XMLPattern["div", CSSClass["main"]], XMLPattern["p"]]],
  {"Hello", "World"},
  TestID -> "descendant-basic"
];

VerificationTest[
  XMLCases[$tree, Descendant[XMLPattern["div", CSSClass["main"]], x:XMLPattern["p"]] :> HTMLText[x]],
  {"Hello", "World"},
  TestID -> "descendant-rule-named"
];

(* === Base XMLCases with rule === *)

VerificationTest[
  XMLCases[$tree, x:XMLPattern["p"] :> HTMLText[x]],
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
    Child[XMLPattern["div", CSSClass["on-sale"]], el:XMLPattern["a", "href" -> href_]] :> {HTMLText[el], href}
  ],
  {{"Sale Item", "/sale"}},
  TestID -> "child-rule-full-extraction"
];

(* Cross-level: parent AND child bindings in the same rule *)
VerificationTest[
  XMLCases[$treeProducts,
    Child[XMLPattern["div", CSSClass["product"], "data-price" -> price_], el:XMLPattern["a"]] :> {price, HTMLText[el]}
  ],
  {{"19.99", "Sale Item"}, {"49.99", "Regular Item"}},
  TestID -> "child-rule-cross-level"
];

(* Cross-level with Descendant *)
VerificationTest[
  XMLCases[$treeProducts,
    Descendant[XMLPattern["div", "data-price" -> price_], el:XMLPattern["a"]] :> {price, HTMLText[el]}
  ],
  {{"19.99", "Sale Item"}, {"49.99", "Regular Item"}},
  TestID -> "descendant-rule-cross-level"
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
    h:XMLPattern["h1" | "h2" | "h3"] :> {h[[1]], StringTrim @ HTMLText[h]}
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
  HTMLText @ XMLFirstCase[$tree, XMLPattern["p"]],
  "Hello",
  TestID -> "firstcase-base"
];

(* Base with rule *)
VerificationTest[
  XMLFirstCase[$tree, x:XMLPattern["p"] :> HTMLText[x]],
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
  HTMLText @ XMLFirstCase[$tree,
    Child[XMLPattern["div", CSSClass["main"]], XMLPattern["p"]]
  ],
  "Hello",
  TestID -> "firstcase-child"
];

(* Child with rule *)
VerificationTest[
  XMLFirstCase[$tree,
    Child[XMLPattern["div", CSSClass["main"]], x:XMLPattern["p"]] :> HTMLText[x]
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
  HTMLText @ XMLFirstCase[$tree,
    Descendant[XMLPattern["div", CSSClass["main"]], XMLPattern["p"]]
  ],
  "Hello",
  TestID -> "firstcase-descendant"
];

(* Descendant with rule *)
VerificationTest[
  XMLFirstCase[$treeProducts,
    Descendant[XMLPattern["div", "data-price" -> price_], el:XMLPattern["a"]] :>
      {price, HTMLText[el]}
  ],
  {"19.99", "Sale Item"},
  TestID -> "firstcase-descendant-rule-cross-level"
];

(* Adjacent *)
VerificationTest[
  HTMLText @ XMLFirstCase[$treeSiblings,
    Adjacent[XMLPattern["h2"], XMLPattern["p"]]
  ],
  "First",
  TestID -> "firstcase-adjacent"
];

(* Adjacent with rule \[LongDash] both bindings *)
VerificationTest[
  XMLFirstCase[$treeSiblings,
    Adjacent[h:XMLPattern["h2"], p:XMLPattern["p"]] :> {HTMLText[h], HTMLText[p]}
  ],
  {"Title", "First"},
  TestID -> "firstcase-adjacent-rule-both"
];

(* Sibling *)
VerificationTest[
  HTMLText @ XMLFirstCase[$treeSiblings,
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
  HTMLText /@ XMLCases[
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
  HTMLText /@ XMLCases[
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
