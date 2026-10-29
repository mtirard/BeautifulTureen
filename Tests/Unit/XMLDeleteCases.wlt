(* XMLDeleteCases: tag/Alternatives removal, envelope preservation, and the
   bad-pattern fallbacks; deletion by rule is in DeleteTargets.wlt. All
   fixtures here are local to this file. *)

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

(* Nested matching parents: Descendant[div, div] \[LongDash] outer div survives, inner divs removed *)
$htmlNestedSame = XMLElement["div", {},
  {"A", XMLElement["div", {}, {"B", XMLElement["div", {}, {"C"}]}]}
];

(* Bad pattern fallback. A string is a CSS selector (ADR 0017), so the bad
   pattern is a number. *)
TestCreate[
  XMLDeleteCases[$treeNoise, 42],
  $Failed,
  {XMLDeleteCases::badpat},
  TestID -> "delete-bad-pattern"
];

(* A rule's right-hand side names what is deleted, whether -> or :>; one
   that names nothing is refused. *)
TestCreate[
  {XMLDeleteCases[$treeNoise, XMLPattern["p"] -> 1], XMLDeleteCases[$treeNoise, XMLPattern["p"] :> 1]},
  {$Failed, $Failed},
  {XMLDeleteCases::delrhs, XMLDeleteCases::delrhs},
  TestID -> "delete-rule-refused"
];

(* === The classList key === *)

(* Deletion runs on the materialised tree and its token lists are removed from
   the whole result, so what survives is exactly the original. *)
$treeAds = ImportString[
  "<div class=\"main\"><p class=\"ad promo\">ad</p><p>keep</p><p class=\"note\">note</p></div>",
  {"HTML", "XMLObject"}];

TestCreate[
  XMLDeleteCases[$treeAds, XMLPattern["p", "classList" -> "ad"]],
  ImportString["<div class=\"main\"><p>keep</p><p class=\"note\">note</p></div>", {"HTML", "XMLObject"}],
  TestID -> "delete-classlist-result-is-original"
];

(* Nothing to delete gives the tree back unchanged: materialisation is undone
   exactly, including on elements with no class. *)
TestCreate[
  XMLDeleteCases[$treeAds, XMLPattern["p", "classList" -> "zzz"]] === $treeAds,
  True,
  TestID -> "delete-classlist-no-match-is-identity"
];

(* A rule that names nothing is refused. *)
TestCreate[
  XMLDeleteCases[$treeAds, XMLPattern["p"] :> 1],
  $Failed,
  {XMLDeleteCases::delrhs},
  TestID -> "delete-rule-refused"
];

