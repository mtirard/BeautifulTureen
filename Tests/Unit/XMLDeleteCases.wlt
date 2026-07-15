(* XMLDeleteCases: tag/Alternatives removal, envelope preservation, scoped
   deletion via Child/Descendant, and the unsupported-combinator/bad-pattern
   fallbacks. All fixtures here are local to this file. *)

$treeNoise = ImportString["<html><body>
  <script>alert(1)</script>
  <style>body{color:red}</style>
  <p>visible</p>
  <noscript>fallback</noscript>
  <div><script>nested</script><p>inside</p></div>
</body></html>", {"HTML", "XMLObject"}];

(* Base: single tag removed *)
TestCreate[
  XMLCases[XMLDeleteCases[$treeNoise, XMLPattern["script"]], XMLPattern["script"]],
  {},
  TestID -> "delete-base-single"
];

(* Base: Alternatives of XMLElement patterns *)
TestCreate[
  XMLCases[
    XMLDeleteCases[$treeNoise, XMLPattern["script"] | XMLPattern["style"] | XMLPattern["noscript"]],
    XMLPattern["script" | "style" | "noscript"]
  ],
  {},
  TestID -> "delete-base-alternatives"
];

(* Surviving elements unchanged *)
TestCreate[
  HTMLTextContent /@ XMLCases[
    XMLDeleteCases[$treeNoise, XMLPattern["script"] | XMLPattern["style"] | XMLPattern["noscript"]],
    XMLPattern["p"]
  ],
  {"visible", "inside"},
  TestID -> "delete-base-preserves"
];

(* Tree envelope preserved: XMLObject["Document"] root survives *)
TestCreate[
  Head @ XMLDeleteCases[$treeNoise, XMLPattern["script"]],
  XMLObject["Document"],
  TestID -> "delete-envelope-preserved"
];

(* No-match: tree returned unchanged *)
TestCreate[
  XMLDeleteCases[$treeNoise, XMLPattern["nonexistent"]] === $treeNoise,
  True,
  TestID -> "delete-no-match"
];

(* Child: scope deletion to direct children of parents *)
$treeScoped = ImportString["<html><body>
  <div class=\"article\">
    <p>keep</p>
    <p class=\"ad\">remove me</p>
  </div>
  <p class=\"ad\">keep me (not inside article)</p>
</body></html>", {"HTML", "XMLObject"}];

TestCreate[
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
$treeNested = ImportString["<html><body>
  <article>
    <section>
      <p class=\"ad\">deep ad</p>
      <p>body</p>
    </section>
  </article>
  <p class=\"ad\">outside \[LongDash] keep</p>
</body></html>", {"HTML", "XMLObject"}];

TestCreate[
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

TestCreate[
  XMLDeleteCases[$htmlNestedSame,
    Descendant[XMLPattern["div"], XMLPattern["div"]]
  ],
  XMLElement["div", {}, {"A"}],
  TestID -> "delete-descendant-nested-same-tag"
];

(* Adjacent/Sibling emit unsupported message *)
TestCreate[
  XMLDeleteCases[$treeNoise, Adjacent[XMLPattern["p"], XMLPattern["p"]]],
  $Failed,
  {XMLDeleteCases::unsupported},
  TestID -> "delete-adjacent-unsupported"
];

(* Bad pattern fallback *)
TestCreate[
  XMLDeleteCases[$treeNoise, "not-a-pattern"],
  $Failed,
  {XMLDeleteCases::badpat},
  TestID -> "delete-bad-pattern"
];
