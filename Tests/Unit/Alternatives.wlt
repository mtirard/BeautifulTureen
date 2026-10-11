(* Alternatives of XMLElement patterns: heterogeneous tag/attribute constraints,
   rules over alternatives, nested composition, the bad-pattern fallback, and
   names bound only in the branch that did not match. Fixtures $treeAlts,
   $treeUnbound and $treeUnboundTwoStep are local to this file. *)

$treeAlts = ImportString["<html><body>
  <a href=\"/foo\">link</a>
  <img src=\"pic.png\" alt=\"x\">
  <p>text</p>
  <iframe src=\"ads.example/banner\"></iframe>
  <div class=\"sponsored\">ad</div>
  <div class=\"content\">article</div>
</body></html>", {"HTML", "XMLObject"}];

(* XMLCases with heterogeneous Alternatives: different tags AND different
   attribute constraints at once *)
TestCreate[
  Sort[First /@ XMLCases[$treeAlts,
    XMLPattern["a", "href" -> _] | XMLPattern["img", "src" -> _]
  ]],
  {"a", "img"},
  TestID -> "alts-cases-heterogeneous"
];

(* Rule over Alternatives: (pat1 | pat2) :> body *)
TestCreate[
  Sort @ XMLCases[$treeAlts,
    (XMLPattern["a", "href" -> h_] | XMLPattern["img", "src" -> h_]) :> h
  ],
  {"/foo", "pic.png"},
  TestID -> "alts-cases-rule-over-alternatives"
];

(* Alternatives mixing tag-only and attribute-constrained patterns *)
TestCreate[
  Length @ XMLCases[$treeAlts,
    XMLPattern["iframe"] | XMLPattern["div", "classList" -> "sponsored"]
  ],
  2,
  TestID -> "alts-cases-tag-and-attr"
];

(* XMLFirstCase with Alternatives *)
TestCreate[
  First @ XMLFirstCase[$treeAlts,
    XMLPattern["iframe"] | XMLPattern["div", "classList" -> "sponsored"]
  ],
  "iframe",
  TestID -> "alts-firstcase-heterogeneous"
];

(* XMLFirstCase with Alternatives, no match, default fires *)
TestCreate[
  XMLFirstCase[$treeAlts,
    XMLPattern["video"] | XMLPattern["audio"],
    None
  ],
  None,
  TestID -> "alts-firstcase-no-match-default"
];

(* Bad Alternatives: a blank is not an XML pattern *)
TestCreate[
  XMLCases[$treeAlts, XMLPattern["a"] | _String],
  $Failed,
  {XMLCases::blank},
  TestID -> "alts-cases-bad-non-xmlelement"
];

(* Nested Alternatives from composition: (a|b) | (c|d) stays 2-arg because
   Alternatives has no Flat attribute. Library flattens for validation. *)
TestCreate[
  Module[{chrome, extras},
    chrome = XMLPattern["a"] | XMLPattern["img"];
    extras = XMLPattern["p"] | XMLPattern["iframe"];
    Sort[First /@ XMLCases[$treeAlts, chrome | extras]]
  ],
  {"a", "iframe", "img", "p"},
  TestID -> "alts-nested-composition"
];

(* XMLDeleteCases with nested Alternatives: same semantics as a single flat one *)
TestCreate[
  Module[{chrome, extras, flat},
    chrome = XMLPattern["a"] | XMLPattern["img"];
    extras = XMLPattern["iframe"] | XMLPattern["div", "classList" -> "sponsored"];
    flat = XMLPattern["a"] | XMLPattern["img"] | XMLPattern["iframe"] |
      XMLPattern["div", "classList" -> "sponsored"];
    XMLDeleteCases[$treeAlts, chrome | extras] === XMLDeleteCases[$treeAlts, flat]
  ],
  True,
  TestID -> "alts-nested-delete-composition"
];

(* A name bound only in the branch that did not match is empty, as in WL:
   Cases[{p[1], q[2]}, p[_] | s : q[_] :> {s}] is {{}, {q[2]}}. Issue #18. *)
$treeUnbound = ImportString["<p class='x'>a</p><section>b</section>", {"HTML", "XMLObject"}];
$treeUnboundTwoStep = ImportString[
  "<a href='ab' id='b' class='x'>a</a><section>b</section>", {"HTML", "XMLObject"}];

(* An element name, with a list key named in the other branch *)
TestCreate[
  XMLCases[$treeUnbound,
    (XMLPattern["p", "classList" -> "x"] | s : XMLPattern["section"]) :> {s}],
  {{}, {XMLElement["section", {}, {"b"}]}},
  TestID -> "alts-unbound-element-name"
];

(* A name on the attribute argument *)
TestCreate[
  XMLCases[$treeUnbound,
    (XMLPattern["p", "classList" -> "x"] | XMLPattern["section", a_]) :> {a}],
  {{}, {{}}},
  TestID -> "alts-unbound-attribute-name"
];

(* An element name, the other branch matched in two steps *)
TestCreate[
  XMLCases[$treeUnboundTwoStep,
    ((XMLPattern["a", {"href" -> h_, "id" -> i_}] /; StringContainsQ[h, i]) |
      s : XMLPattern["section"]) :> {s}],
  {{}, {XMLElement["section", {}, {"b"}]}},
  TestID -> "alts-unbound-two-step"
];

(* Both renamings: a list key and a two-step match *)
TestCreate[
  XMLCases[$treeUnboundTwoStep,
    ((XMLPattern["a", {"classList" -> "x", "href" -> h_, "id" -> i_}] /; StringContainsQ[h, i]) |
      s : XMLPattern["section"]) :> {s}],
  {{}, {XMLElement["section", {}, {"b"}]}},
  TestID -> "alts-unbound-stacked"
];

(* In a Condition, as Cases[{p[1], q[2]}, (p[_] | s : q[_]) /; Length[{s}] == 0]
   gives {p[1]} *)
TestCreate[
  XMLCases[$treeUnbound,
    (XMLPattern["p", "classList" -> "x"] | s : XMLPattern["section"]) /; Length[{s}] == 0],
  {XMLElement["p", {"class" -> "x"}, {"a"}]},
  TestID -> "alts-unbound-condition"
];

TestCreate[
  XMLCases[$treeUnbound,
    (XMLPattern["p", "classList" -> "x"] | XMLPattern["section", a_]) /; Length[{a}] == 0],
  {XMLElement["p", {"class" -> "x"}, {"a"}]},
  TestID -> "alts-unbound-attribute-condition"
];

(* A Condition that sees only the bound name, or only the unbound one *)
TestCreate[
  {XMLCases[$treeUnbound,
     ((e : XMLPattern["p", "classList" -> "x"]) | s : XMLPattern["section"]) /; {e} === {XMLElement["p", {"class" -> "x"}, {"a"}]}],
   XMLCases[$treeUnbound,
     ((e : XMLPattern["p", "classList" -> "x"]) | s : XMLPattern["section"]) /; {s} === {} :> {e}],
   XMLCases[$treeUnbound,
     (Child[XMLPattern["body"], e : XMLPattern["p", "classList" -> "x"]] | Child[XMLPattern["body"], s : XMLPattern["section"]]) /;
       Length[{s}] == 0]},
  {{XMLElement["p", {"class" -> "x"}, {"a"}]}, {{XMLElement["p", {"class" -> "x"}, {"a"}]}},
   {XMLElement["p", {"class" -> "x"}, {"a"}]}},
  TestID -> "alts-unbound-condition-sees-one-name"
];

TestCreate[
  XMLCases[$treeUnbound,
    (XMLPattern["p", "classList" -> "x"] | s : XMLPattern["section"]) :> {s} /; Length[{s}] == 0],
  {{}},
  TestID -> "alts-unbound-body-condition"
];

TestCreate[
  XMLFirstCase[$treeUnbound,
    (XMLPattern["p", "classList" -> "x"] | s : XMLPattern["section"]) :> {s}],
  {},
  TestID -> "alts-unbound-firstcase"
];

(* An Alternatives as a combinator stage *)
TestCreate[
  XMLCases[$treeUnbound,
    Child[XMLPattern["body"], XMLPattern["p", "classList" -> "x"] | s : XMLPattern["section"]] :> {s}],
  {{}, {XMLElement["section", {}, {"b"}]}},
  TestID -> "alts-unbound-combinator-stage"
];

(* One name bound as a different kind of thing in each branch: an element, the
   attribute list, or a list entry. A list key named in the query renames each
   name to see the materialised value; the name still binds one value, as in
   WL. Issue #52. *)
$treeKinds = XMLElement["body", {}, {
  XMLElement["div", {"class" -> "c1"}, {}], XMLElement["p", {"id" -> "x"}, {}], XMLElement["span", {}, {}]}];

(* As Cases[$treeKinds, ((a : XMLElement["div", {___, "class" -> "c1", ___}, _]) |
   XMLElement["p", a_, _]) :> {a}, Infinity] *)
TestCreate[
  XMLCases[$treeKinds, ((a : XMLPattern["div", "classList" -> "c1"]) | XMLPattern["p", a_]) :> {a}],
  {{XMLElement["div", {"class" -> "c1"}, {}]}, {{"id" -> "x"}}},
  TestID -> "alts-kinds-element-attributes"
];

(* A name on a list entry. In document order the div's match comes first, as
   with Cases[$treeKinds, ((a : XMLElement["div", {___, "class" -> "c1", ___}, _]) |
   XMLElement["body", _, {___, XMLElement["p", _, _], a_}]) :> {a}, {0, Infinity}] *)
TestCreate[
  XMLCases[$treeKinds,
    ((a : XMLPattern["div", "classList" -> "c1"]) | Child[XMLPattern["body"], {___, XMLPattern["p"], a_}]) :> {a}],
  {{XMLElement["div", {"class" -> "c1"}, {}]}, {XMLElement["span", {}, {}]}},
  TestID -> "alts-kinds-element-entry"
];

(* The div is selected by the list and comes first in document order; Cases on
   XMLElement["p", a_, _] | XMLElement["body", _, {XMLElement["div", {___,
   "class" -> "c1", ___}, _], a_, ___}] gives the same two in the other order. *)
TestCreate[
  XMLCases[$treeKinds,
    (XMLPattern["p", a_] | Child[XMLPattern["body"], {XMLPattern["div", "classList" -> "c1"], a_, ___}]) :> {a}],
  {{XMLElement["p", {"id" -> "x"}, {}]}, {{"id" -> "x"}}},
  TestID -> "alts-kinds-attributes-entry"
];
