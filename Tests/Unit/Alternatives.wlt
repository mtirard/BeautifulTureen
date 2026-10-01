(* Alternatives of XMLElement patterns: heterogeneous tag/attribute constraints,
   rules over alternatives, nested composition, and the bad-pattern fallback.
   Fixture $treeAlts is local to this file. *)

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
