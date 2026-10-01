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
      Child[XMLPattern["div", "classList" -> "article"], XMLPattern[_, "classList" -> "ad"]]
    ],
    XMLPattern[_, "classList" -> "ad"]
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
      Descendant[XMLPattern["article"], XMLPattern[_, "classList" -> "ad"]]
    ],
    XMLPattern[_, "classList" -> "ad"]
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

(* A rule has nothing to delete with, whether -> or :> *)
TestCreate[
  {XMLDeleteCases[$treeNoise, XMLPattern["p"] -> 1], XMLDeleteCases[$treeNoise, XMLPattern["p"] :> 1]},
  {$Failed, $Failed},
  {XMLDeleteCases::badpat, XMLDeleteCases::badpat},
  TestID -> "delete-rule-refused"
];

(* === The classList key === *)

(* Deletion runs on the materialised tree and the whole result is stripped, so
   what survives is exactly the original. *)
$treeAds = ImportString[
  "<div class=\"main\"><p class=\"ad promo\">ad</p><p>keep</p><p class=\"note\">note</p></div>",
  {"HTML", "XMLObject"}];

TestCreate[
  XMLDeleteCases[$treeAds, XMLPattern["p", "classList" -> "ad"]],
  ImportString["<div class=\"main\"><p>keep</p><p class=\"note\">note</p></div>", {"HTML", "XMLObject"}],
  TestID -> "delete-classlist-result-is-original"
];

(* Nothing to delete gives the tree back unchanged: strip inverts materialisation
   exactly, including on elements with no class. *)
TestCreate[
  XMLDeleteCases[$treeAds, XMLPattern["p", "classList" -> "zzz"]] === $treeAds,
  True,
  TestID -> "delete-classlist-no-match-is-identity"
];

TestCreate[
  XMLDeleteCases[$treeAds,
    Child[XMLPattern["div", "classList" -> "main"], XMLPattern["p", "classList" -> _?(FreeQ["note"])]]],
  ImportString["<div class=\"main\"><p class=\"note\">note</p></div>", {"HTML", "XMLObject"}],
  TestID -> "delete-child-classlist-both-stages"
];

(* A rule has nothing to delete with. *)
TestCreate[
  XMLDeleteCases[$treeAds, XMLPattern["p"] :> 1],
  $Failed,
  {XMLDeleteCases::badpat},
  TestID -> "delete-rule-refused"
];

(* === Nested Child and Descendant === *)

(* A chain of Child and Descendant stages deletes the elements its last stage
   selects, as XMLCases would give them. *)
$treeNestDel = XMLElement["div", {"class" -> "outer"}, {
  XMLElement["section", {}, {XMLElement["p", {}, {"1"}], XMLElement["div", {}, {XMLElement["p", {}, {"2"}]}]}],
  XMLElement["p", {}, {"3"}]}];

TestCreate[
  {XMLDeleteCases[{$treeNestDel}, Descendant[XMLPattern["div", "classList" -> "outer"], Child[XMLPattern["section"], XMLPattern["p"]]]],
   XMLDeleteCases[{$treeNestDel}, Child[Descendant[XMLPattern["div"], XMLPattern["section"]], XMLPattern["div"]]]},
  {{XMLElement["div", {"class" -> "outer"}, {
     XMLElement["section", {}, {XMLElement["div", {}, {XMLElement["p", {}, {"2"}]}]}],
     XMLElement["p", {}, {"3"}]}]},
   {XMLElement["div", {"class" -> "outer"}, {
     XMLElement["section", {}, {XMLElement["p", {}, {"1"}]}],
     XMLElement["p", {}, {"3"}]}]}},
  TestID -> "delete-nested-child-descendant"
];

(* As unnested, the root may be the first stage. *)
TestCreate[
  XMLDeleteCases[$treeNestDel, Descendant[XMLPattern["div", "classList" -> "outer"], Child[XMLPattern["section"], XMLPattern["p"]]]],
  XMLElement["div", {"class" -> "outer"}, {
    XMLElement["section", {}, {XMLElement["div", {}, {XMLElement["p", {}, {"2"}]}]}],
    XMLElement["p", {}, {"3"}]}],
  TestID -> "delete-nested-root-first-stage"
];

(* Descendant selects an element under any matching ancestor, the pairing
   satisfying a name at two stages or a test on the combinator: the inner div
   for the p "1", the outer for "2" and "3". *)
$treeDeepDel = XMLElement["div", {"id" -> "a"}, {
  XMLElement["div", {"id" -> "b"}, {XMLElement["p", {"data-for" -> "b"}, {"1"}], XMLElement["p", {"data-for" -> "a"}, {"2"}]}],
  XMLElement["p", {"data-for" -> "a"}, {"3"}], XMLElement["p", {"data-for" -> "c"}, {"4"}]}];

TestCreate[
  {HTMLTextContent @ XMLDeleteCases[$treeDeepDel,
     Descendant[XMLPattern["div", "id" -> i_], XMLPattern["p", "data-for" -> i_]]],
   HTMLTextContent @ XMLDeleteCases[$treeDeepDel,
     Descendant[XMLPattern["div", "id" -> i_], XMLPattern["p", "data-for" -> f_]] /; f === i],
   HTMLTextContent @ XMLDeleteCases[$treeDeepDel, Descendant[XMLPattern["div"], XMLPattern["p"]]]},
  {"4", "4", ""},
  TestID -> "delete-descendant-any-matching-ancestor"
];

(* Adjacent and Sibling stay unsupported at any depth. *)
TestCreate[
  {XMLDeleteCases[$treeNestDel, Descendant[XMLPattern["section"], Adjacent[XMLPattern["p"], XMLPattern["div"]]]],
   XMLDeleteCases[$treeNestDel, Child[Sibling[XMLPattern["p"], XMLPattern["div"]], XMLPattern["p"]]]},
  {$Failed, $Failed},
  {XMLDeleteCases::unsupported, XMLDeleteCases::unsupported},
  TestID -> "delete-nested-adjacent-sibling-unsupported"
];
