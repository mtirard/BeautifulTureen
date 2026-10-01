(* Integration: real-world page. Exercises XMLCases/XMLPattern at document scale
   against Tests/assets/wolfram-language.html. Fixture $realTree comes from
   Tests/Support/Fixtures.wl. *)

(* OG meta tags via prefix pattern test *)
TestCreate[
  Length @ XMLCases[$realTree,
    XMLPattern["meta", {"property" -> _?(StringStartsQ["og:"]), "content" -> _}]
  ],
  5,
  TestID -> "real-og-count"
];

(* OG title is extractable via named slot *)
TestCreate[
  First @ XMLCases[$realTree,
    XMLPattern["meta", {"property" -> "og:title", "content" -> c_}] :> c
  ],
  "Wolfram Language: Programming Language + Built-In Knowledge",
  TestID -> "real-og-title"
];

(* Heading alternation preserves document order *)
TestCreate[
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
TestCreate[
  Length @ XMLCases[$realTree, XMLPattern["h1" | "h2" | "h3"]],
  43,
  TestID -> "real-heading-count"
];

(* Absolute hrefs \[LongDash] named-slot extraction with pattern-test on value *)
TestCreate[
  Length @ XMLCases[$realTree,
    XMLPattern["a", "href" -> _?(StringStartsQ[#, {"http://", "https://"}] &)]
  ],
  290,
  TestID -> "real-absolute-href-count"
];

(* JSON-LD: match on attribute *value*, not just existence *)
TestCreate[
  Length @ XMLCases[$realTree,
    XMLPattern["script", "type" -> "application/ld+json"]
  ],
  2,
  TestID -> "real-jsonld-count"
];
