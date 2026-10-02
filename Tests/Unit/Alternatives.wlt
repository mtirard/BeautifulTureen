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

(* Bad Alternatives: contains a non-XMLElement \[LongDash] falls through to badpat *)
TestCreate[
  XMLCases[$treeAlts, XMLPattern["a"] | _String],
  $Failed,
  {XMLCases::badpat},
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
