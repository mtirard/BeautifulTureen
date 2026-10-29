(* The messages of tree patterns, new, changed or removed in 4.0.0: one test
   per message, each checking the message name and the return value. A
   message shared by several heads is checked for each of them in one test.
   The fixtures are literal trees, so positions are exact. *)

nav     = doc[e["nav", "o", e["a", "a1"], e["nav", "i", e["a", "a2"]], e["a", "a3"]]];
links   = doc[el["p", e["a", "1"], e["a", "2"], e["a", "3"]]];
hrefs   = doc[el["p", XMLElement["a", {"href" -> "/x"}, {}], XMLElement["a", {"href" -> "/x"}, {}]]];
row     = doc[el["tr", el["th", "a"], el["td", "a"], el["td", "b"]]];
listing = doc[XMLElement["ul", {"class" -> "a b"}, {el["li"], " ", el["li", XMLElement["a", {"href" -> "/x"}, {}]]}]];

(* The text of a message as it is issued, its arguments in InputForm. *)
SetAttributes[messageTexts, HoldFirst];
messageTexts[expr_] := Module[{texts = {}},
  Internal`HandlerBlock[
    {"Message", Function[m,
      Replace[m, Hold[Message[mn : MessageName[_, _], args___], _] :>
        AppendTo[texts, ToString[
          StringForm[mn, Sequence @@ (List @@ Map[Function[a, ToString[Unevaluated[a], InputForm], HoldAllComplete], Hold[args]])],
          OutputForm, PageWidth -> Infinity]]]]},
    Quiet[expr]];
  texts];

(* === New === *)

TestCreate[
  XMLCases[links, XMLPattern["div", _, XMLPattern["p"]]],
  $Failed,
  {XMLPattern::constraint},
  TestID -> "tree-message-constraint"
];

TestCreate[
  {XMLCases[links, XMLPattern["ul", _, {Descendant[XMLPattern["a"]]}]],
    XMLCases[links, XMLDocument[{XMLDocument[]}]],
    XMLMatchQ[{el["a"]}, {{XMLPattern["a"]}}]},
  {$Failed, $Failed, $Failed},
  {XMLPattern::listentry, XMLDocument::listentry, XMLMatchQ::listentry},
  TestID -> "tree-message-listentry"
];

TestCreate[
  XMLCases[links, Descendant[XMLPattern["a"]]],
  $Failed,
  {Descendant::place},
  TestID -> "tree-message-descendant-place"
];

(* The old two-pattern form is a level spec that is not one. *)
TestCreate[
  {XMLCases[links, XMLPattern["p", _, Descendant[XMLPattern["a"], XMLPattern["b"]]]],
    XMLCases[links, XMLPattern["p", _, Descendant[XMLPattern["a"], {0}]]]},
  {$Failed, $Failed},
  {Descendant::level, Descendant::level},
  TestID -> "tree-message-descendant-level"
];

TestCreate[
  {XMLCases[links, XMLPattern["ul", _, Shortest[{___, XMLPattern["li"]}]]],
    XMLCases[links, XMLDocument[Longest[{___, XMLPattern["p"]}]]]},
  {$Failed, $Failed},
  {XMLPattern::shortest, XMLDocument::shortest},
  TestID -> "tree-message-shortest"
];

TestCreate[
  With[{q = XMLPattern["tr", _, {XMLElement["th", _, {t_String}], ___}] :> t},
    {XMLCases[row, q], XMLFirstCase[row, q], XMLPosition[row, q], XMLDeleteCases[row, q]}],
  {$Failed, $Failed, $Failed, $Failed},
  {XMLCases::text, XMLFirstCase::text, XMLPosition::text, XMLDeleteCases::text},
  TestID -> "tree-message-text"
];

TestCreate[
  With[{q = XMLPattern["p", _, {Except[x : XMLPattern["b"]] ..., ___}] :> x},
    {XMLCases[links, q], XMLFirstCase[links, q], XMLPosition[links, q], XMLDeleteCases[links, q]}],
  {$Failed, $Failed, $Failed, $Failed},
  {XMLCases::exceptname, XMLFirstCase::exceptname, XMLPosition::exceptname, XMLDeleteCases::exceptname},
  TestID -> "tree-message-exceptname"
];

TestCreate[
  XMLDeleteCases[links, XMLPattern["a"] :> "x"],
  $Failed,
  {XMLDeleteCases::delrhs},
  TestID -> "tree-message-delrhs"
];

TestCreate[
  {XMLDeleteCases[links, XMLPattern[t_] :> t], XMLReplace[links, d : XMLDocument[] :> {d -> el["p"]}]},
  {$Failed, $Failed},
  {XMLDeleteCases::target, XMLReplace::target},
  TestID -> "tree-message-target"
];

TestCreate[
  {XMLDeleteCases[nav, XMLPattern["nav", _, p : Descendant[XMLPattern["a"]]] :> p],
    XMLReplace[nav, XMLPattern["nav", _, p : Descendant[XMLPattern["a"]]] :> {p -> el["b"]}]},
  {$Failed, $Failed},
  {XMLDeleteCases::pathtarget, XMLReplace::pathtarget},
  TestID -> "tree-message-pathtarget"
];

TestCreate[
  XMLReplace[links, XMLPattern["a"]],
  $Failed,
  {XMLReplace::bare},
  TestID -> "tree-message-bare"
];

(* A warning: the position is left unchanged. *)
TestCreate[
  XMLReplace[hrefs, XMLPattern["a", "href" -> h_] :> {h -> 5}],
  hrefs,
  {XMLReplace::kind, XMLReplace::kind},
  TestID -> "tree-message-kind"
];

TestCreate[
  XMLReplace[doc[el["ul", el["li"], el["li"], el["li"]]],
    XMLPattern["ul", _, {___, x : XMLPattern["li"], ___, y : XMLPattern["li"], ___}] :> {x -> "first", y -> "second"}],
  doc[el["ul", "first", "second", "second"]],
  {XMLReplace::conflict},
  TestID -> "tree-message-conflict"
];

TestCreate[
  XMLReplace[doc[el["div", e["p", "1"], e["p", "2"]]],
    XMLPattern["div", _, {x : XMLPattern["p"], y : XMLPattern["p"]}] :> {x -> y, y -> Nothing}],
  doc[el["div", e["p", "2"]]],
  {XMLReplace::stale},
  TestID -> "tree-message-stale"
];

TestCreate[
  {XMLExtract[listing, {0}], XMLExtract[listing, {1} ;; {1}]},
  {$Failed, $Failed},
  {XMLExtract::pos, XMLExtract::pos},
  TestID -> "tree-message-pos"
];

TestCreate[
  XMLExtract[listing, {1, 3}],
  $Failed,
  {XMLExtract::nopos},
  TestID -> "tree-message-nopos"
];

TestCreate[
  FromCSSSelector["nav a"],
  $Failed,
  {FromCSSSelector::name},
  TestID -> "tree-message-css-name"
];

TestCreate[
  {HTMLToTree[hrefs, "Focus" -> (XMLPattern["a", "href" -> h_] :> h)],
    HTMLToTree[hrefs, "Hide" -> (XMLPattern["a", "href" -> h_] :> h)]},
  {$Failed, $Failed},
  {HTMLToTree::focustarget, HTMLToTree::hidetarget},
  TestID -> "tree-message-focustarget-hidetarget"
];

TestCreate[
  With[{roles = {(XMLPattern["a", "href" -> h_] :> h) -> "Block"}},
    {HTMLInnerText[hrefs, "Roles" -> roles], HTMLToNotebook[hrefs, "Roles" -> roles]}],
  {$Failed, $Failed},
  {HTMLInnerText::keytarget, HTMLToNotebook::keytarget},
  TestID -> "tree-message-keytarget"
];

TestCreate[
  {XMLFreeQ[links, x : XMLPattern["a"] :> x], XMLFreeQ[links, "p a"]},
  {$Failed, $Failed},
  {XMLFreeQ::badpat, XMLFreeQ::badpat},
  TestID -> "tree-message-xmlfreeq-badpat"
];

(* === Changed === *)

(* ::badpat fires for a named context selector as a whole query, a context
   selector on the left of a query arrow, a context selector as an element
   test, and a document-rooted Roles key. *)
TestCreate[
  {XMLCases[nav, n : "nav a"], XMLCases[nav, "nav a" :> 1], XMLPosition[nav, n : "nav a"],
    HTMLInnerText[nav, "Roles" -> {(n : "nav a") -> "Block"}],
    HTMLInnerText[nav, "Roles" -> {XMLDocument[Descendant[XMLPattern["a"]]] -> "Block"}]},
  {$Failed, $Failed, $Failed, $Failed, $Failed},
  {XMLCases::badpat, XMLCases::badpat, XMLPosition::badpat, HTMLInnerText::badpat, HTMLInnerText::badpat},
  TestID -> "tree-message-badpat-fires"
];

(* The text lists the accepted forms, and none that was removed. *)
TestCreate[
  With[{texts = Join @@ {messageTexts[XMLCases[links, 5]], messageTexts[XMLFirstCase[links, 5]],
      messageTexts[XMLDeleteCases[links, 5]], messageTexts[XMLPosition[links, 5]], messageTexts[XMLReplace[links, 5 :> 6]],
      messageTexts[XMLMatchQ[el["a"], 5]], messageTexts[XMLFreeQ[links, 5]], messageTexts[HTMLInnerText[links, "Roles" -> {5 -> "Block"}]]}},
    {Length[texts], AllTrue[texts, StringContainsQ["XMLPattern"]], AllTrue[texts, StringContainsQ["XMLDocument"]],
      AllTrue[texts, StringContainsQ["CSS selector"]], NoneTrue[texts, StringContainsQ["combinator" | "Child[" | "list stage"]]}],
  {8, True, True, True, True},
  TestID -> "tree-message-badpat-text"
];

TestCreate[
  {XMLMatchQ[el["a"], x : XMLPattern["a"] :> x], XMLMatchQ[el["a"], "nav a"]},
  {$Failed, $Failed},
  {XMLMatchQ::badpat, XMLMatchQ::badpat},
  TestID -> "tree-message-xmlmatchq-badpat"
];

TestCreate[
  {XMLCases[links, XMLPattern["p", _, Descendant[XMLDocument[]]]],
    XMLCases[links, XMLPattern["p", "id" -> XMLDocument[]]],
    XMLCases[links, XMLElement["p", _, {XMLDocument[]}]]},
  {$Failed, $Failed, $Failed},
  {XMLDocument::place, XMLDocument::place, XMLDocument::place, General::stop},
  TestID -> "tree-message-document-place"
];

(* A blank as the whole query or as Descendant's pattern; any one child as a
   contents-list entry. *)
TestCreate[
  {XMLCases[links, _], XMLCases[links, XMLPattern["p", _, Descendant[_]]],
    XMLCases[links, XMLPattern["p", _, {_, x : XMLPattern["a"], ___}] :> x[[2, 1, 2]]]},
  {$Failed, $Failed, {"2"}},
  {XMLCases::blank, Descendant::blank},
  TestID -> "tree-message-blank"
];

TestCreate[
  With[{text = First[messageTexts[HTMLToTree[links, "Focus" -> 5]]]},
    {StringContainsQ[text, "rule"], StringContainsQ[text, "XMLDocument"], StringContainsQ[text, "combinator"]}],
  {True, True, False},
  TestID -> "tree-message-badquery-text"
];

(* === Removed === *)

TestCreate[
  {Names["MaximilienTirard`HTMLPatterns`" <> #] & /@ {"Child", "Adjacent", "Sibling"},
    Cases[{XMLCases::stages, XMLCases::testcombinator, XMLFirstCase::condcombinator, XMLMatchQ::combinator,
      XMLMatchQ::condcombinator, HTMLInnerText::stages, XMLCases::liststage, XMLMatchQ::liststage, XMLPattern::nargs,
      Descendant::stages, Descendant::liststage}, _String]},
  {{{}, {}, {}}, {}},
  TestID -> "tree-message-removed"
];

(* Child, Adjacent and Sibling stay unevaluated in a consumer, which gives
   ::badpat, whose text names the tree form. *)
TestCreate[
  With[{texts = Join[messageTexts[XMLCases[links, Child[XMLPattern["p"], XMLPattern["a"]]]],
      messageTexts[XMLFirstCase[links, Sibling[XMLPattern["a"], XMLPattern["a"]]]],
      messageTexts[XMLDeleteCases[links, XMLPattern["p", _, {___, Adjacent[XMLPattern["a"], XMLPattern["a"]], ___}]]]]},
    {Length[texts], AllTrue[texts, StringContainsQ["Child, Adjacent and Sibling were removed"]],
      AllTrue[texts, StringContainsQ["x : XMLPattern[\"li\"]"]]}],
  {3, True, True},
  TestID -> "tree-message-combinator-badpat"
];

TestCreate[
  {XMLCases[links, Child[XMLPattern["p"], XMLPattern["a"]]], XMLMatchQ[el["a"], Child[XMLPattern["p"], XMLPattern["a"]]],
    XMLPosition[links, Sibling[XMLPattern["a"], XMLPattern["a"]]], XMLReplace[links, Adjacent[XMLPattern["a"], XMLPattern["a"]] :> "z"],
    HTMLInnerText[links, "Roles" -> {Child[XMLPattern["p"], XMLPattern["a"]] -> "Block"}]},
  {$Failed, $Failed, $Failed, $Failed, $Failed},
  {XMLCases::badpat, XMLMatchQ::badpat, XMLPosition::badpat, XMLReplace::badpat, HTMLInnerText::badpat},
  TestID -> "tree-message-combinator-badpat-heads"
];
