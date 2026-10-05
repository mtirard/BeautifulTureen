(* XMLDocument[] (ADR 0018): the document above the top elements of every
   input, matched only as the first stage of a chain. The document of an
   XMLObject is the XMLObject, of a list the list, and of a bare XMLElement a
   virtual parent whose only child is the input. The input itself is never a
   result. Fixtures are local to this file. *)

$doc = ImportString["<html><body><p id=\"a\">a</p><div><p id=\"b\">b</p></div></body></html>", {"HTML", "XMLObject"}];
$list = {XMLElement["p", {"id" -> "1"}, {}], "text",
  XMLElement["div", {}, {XMLElement["p", {"id" -> "3"}, {}]}], XMLElement["p", {"id" -> "2"}, {}]};
$bare = XMLElement["body", {}, {XMLElement["p", {"id" -> "x"}, {}],
  XMLElement["div", {}, {XMLElement["p", {"id" -> "y"}, {}]}]}];

docIds[es_] := Lookup[#[[2]], "id", First[#]] & /@ es;

doc = XMLDocument[];
p = XMLPattern["p"];

(* === The symbol === *)

TestCreate[
  XMLDocument[],
  XMLDocument[],
  TestID -> "document-inert"
];

(* === Child: the top elements === *)

TestCreate[
  {docIds @ XMLCases[$doc, Child[doc, XMLPattern["html"]]],
   XMLCases[$doc, Child[doc, XMLPattern["body"]]]},
  {{"html"}, {}},
  TestID -> "document-child-of-xmlobject"
];

TestCreate[
  docIds @ XMLCases[$list, Child[doc, p]],
  {"1", "2"},
  TestID -> "document-child-of-list"
];

(* bs4's tag.find_all("p", recursive=False). *)
TestCreate[
  {XMLCases[$bare, Child[doc, XMLPattern["body"]]],
   docIds @ XMLCases[$bare, Child[doc, XMLPattern["body"], p]]},
  {{}, {"x"}},
  TestID -> "document-child-of-bare-element"
];

(* === Descendant: every element === *)

TestCreate[
  Table[XMLCases[t, Descendant[doc, p]] === XMLCases[t, p], {t, {$doc, $list, $bare}}],
  {True, True, True},
  TestID -> "document-descendant-is-every-element"
];

TestCreate[
  {docIds @ XMLCases[$bare, Descendant[doc, XMLPattern[_]]],
   docIds @ XMLCases[$doc, Descendant[doc, XMLPattern["html" | "body"]]]},
  {{"x", "div", "y"}, {"html", "body"}},
  TestID -> "document-descendant-never-the-input"
];

(* === As a branch of alternatives === *)

TestCreate[
  XMLCases[{XMLElement["li", {"id" -> "1"}, {}], XMLElement["ul", {}, {XMLElement["li", {"id" -> "2"}, {}]}]},
    Child[doc | XMLPattern["ul"], XMLPattern["li"]]] // docIds,
  {"1", "2"},
  TestID -> "document-in-alternatives"
];

TestCreate[
  {docIds @ XMLCases[$doc, Descendant[doc | XMLPattern["div"], p]],
   docIds @ XMLCases[$bare, Descendant[doc | XMLPattern["div"], q : p] /; True]},
  {{"a", "b"}, {"x", "y"}},
  TestID -> "document-in-alternatives-descendant"
];

(* === A condition on the combinator; rule bodies === *)

TestCreate[
  {XMLCases[$doc, Child[XMLDocument[], x : XMLPattern[_]] :> First[x]],
   docIds @ XMLCases[$list, Child[XMLDocument[], x : p] /; x[[2, 1, 2]] == "2"],
   XMLFirstCase[$bare, Child[XMLDocument[], XMLPattern[_], x : p] :> x[[2, 1, 2]]]},
  {{"html"}, {"2"}, "x"},
  TestID -> "document-condition-and-rule"
];

(* === XMLFirstCase agrees with XMLCases === *)

TestCreate[
  Table[XMLFirstCase[t, q] === First[XMLCases[t, q], Missing["NotFound"]],
    {t, {$doc, $list, $bare}},
    {q, {Child[doc, XMLPattern["html"]], Child[doc, p], Child[doc, XMLPattern["body"], p],
      Descendant[doc, p], Child[doc | XMLPattern["div"], p]}}],
  ConstantArray[True, {3, 5}],
  TestID -> "document-first-case-agrees"
];

(* === Refusals === *)

TestCreate[
  {XMLCases[$doc, XMLDocument[]],
   XMLCases[$doc, XMLDocument[] | p],
   XMLCases[$doc, Child[p, XMLDocument[]]]},
  {$Failed, $Failed, $Failed},
  {XMLCases::badpat, XMLCases::badpat, XMLCases::badpat, General::stop},
  TestID -> "document-refused-alone-and-later"
];

TestCreate[
  {XMLCases[$doc, Child[p, Child[XMLDocument[], p]]],
   XMLCases[$doc, Child[d : XMLDocument[], p]],
   XMLCases[$doc, Child[XMLDocument[] /; True, p]]},
  {$Failed, $Failed, $Failed},
  {XMLCases::badpat, XMLCases::badpat, XMLCases::badpat, General::stop},
  TestID -> "document-refused-nested-named-conditioned"
];

TestCreate[
  {XMLCases[$doc, Child[XMLDocument[]?(True &), p]],
   XMLCases[$doc, Child[XMLDocument["x"], p]],
   XMLCases[$doc, Child[p, {XMLDocument[], ___}]]},
  {$Failed, $Failed, $Failed},
  {XMLCases::badpat, XMLCases::badpat, XMLCases::listentry},
  TestID -> "document-refused-tested-arguments-entry"
];

TestCreate[
  XMLCases[$doc, Child[p, {___, Child[XMLDocument[], p]}]],
  $Failed,
  {XMLCases::badpat},
  TestID -> "document-refused-in-list-combinator"
];

TestCreate[
  {XMLMatchQ[XMLElement["p", {}, {}], XMLDocument[]],
   HTMLInnerText[$doc, "Roles" -> {XMLDocument[] -> "Skip"}]},
  {$Failed, $Failed},
  {XMLMatchQ::badpat, HTMLInnerText::badpat},
  TestID -> "document-refused-one-element"
];

(* === XMLDeleteCases === *)

TestCreate[
  XMLDeleteCases[$list, Child[doc, p]],
  {"text", XMLElement["div", {}, {XMLElement["p", {"id" -> "3"}, {}]}]},
  TestID -> "document-delete-top-of-list"
];

(* A document keeps its root element (#35). *)
TestCreate[
  XMLDeleteCases[$doc, XMLPattern["html"]],
  $doc,
  {XMLDeleteCases::root},
  TestID -> "document-delete-keeps-root"
];

TestCreate[
  {XMLDeleteCases[$doc, XMLPattern["html" | "p"]],
   XMLDeleteCases[$doc, Descendant[doc, XMLPattern["html" | "p"]]]},
  With[{noP = DeleteCases[$doc, XMLElement["p", _, _], Infinity]}, {noP, noP}],
  {XMLDeleteCases::root, XMLDeleteCases::root},
  TestID -> "document-delete-root-kept-others-deleted"
];

TestCreate[
  XMLDeleteCases[$doc, Child[doc, XMLPattern["html"]] | Descendant[XMLPattern["div"], p]],
  DeleteCases[$doc, XMLElement["p", {"id" -> "b"}, _], Infinity],
  {XMLDeleteCases::root},
  TestID -> "document-delete-root-kept-in-alternatives"
];

TestCreate[
  XMLDeleteCases[$bare, XMLPattern["body"]],
  $bare,
  TestID -> "document-delete-never-the-bare-input"
];

(* === List stages under the document, and siblings at the top === *)

top = XMLDocument[] | XMLPattern[_];
html = XMLPattern["html"];

(* html:first-child, html:last-child and html:only-child, as soupsieve gives
   them. *)
TestCreate[
  {docIds @ XMLCases[$doc, Child[top, {x : html, ___}]],
   docIds @ XMLCases[$doc, Child[top, {___, html}]],
   docIds @ XMLCases[$doc, Child[top, {html}]],
   XMLFirstCase[$doc, Child[top, {x : html, ___}] :> First[x]]},
  {{"html"}, {"html"}, {"html"}, "html"},
  TestID -> "document-list-stage-selects-root"
];

TestCreate[
  {First /@ XMLCases[XMLElement["html", {}, {XMLElement["body", {}, {}]}], Child[Child[top, {html, ___}], XMLPattern["body"]]],
   XMLCases[XMLElement["html", {}, {}], Child[top, {html}]]},
  {{"body"}, {}},
  TestID -> "document-list-stage-on-bare-element"
];

$tops = {XMLElement["p", {}, {}], "t", XMLElement["div", {}, {}]};

TestCreate[
  {First /@ XMLCases[$tops, Adjacent[p, XMLPattern["div"]]],
   First /@ XMLCases[$tops, Sibling[p, XMLPattern["div"]]],
   First /@ XMLCases[$tops, Child[top, {___, p, XMLPattern["div"], ___}]],
   XMLCases[$tops, Child[XMLDocument[], {x : XMLPattern[_]}]],
   First /@ XMLCases[$tops, Child[XMLDocument[], {___, XMLPattern[_]}]]},
  {{"div"}, {"div"}, {"div"}, {}, {"div"}},
  TestID -> "document-siblings-at-the-top"
];

TestCreate[
  {XMLDeleteCases[$tops, Adjacent[p, XMLPattern["div"]]],
   XMLFirstCase[$tops, Sibling[a : p, b : XMLPattern["div"]] :> {First[a], First[b]}]},
  {{XMLElement["p", {}, {}], "t"}, {"p", "div"}},
  TestID -> "document-siblings-at-the-top-delete-and-bind"
];

(* Sibling over 1,000 top-level elements costs what it costs over 1,000
   children of one element. *)
$wide = Table[XMLElement[If[OddQ[k], "p", "div"], {}, {}], {k, 1000}];
TestCreate[
  With[{time = First @ RepeatedTiming[XMLCases[#, Sibling[p, XMLPattern["div"]]]] &},
    time[$wide] < 3 time[XMLElement["body", {}, $wide]] + 0.01],
  True,
  TestID -> "document-siblings-at-the-top-cost"
];

(* A CSS string that starts with a child-indexed compound starts with any
   parent, the document included. As a later stage, where no stage is the
   document, it starts with an element. *)
$ul = XMLElement["div", {}, {XMLElement["ul", {}, {XMLElement["li", {"id" -> "1"}, {}], XMLElement["li", {"id" -> "2"}, {}]}]}];
TestCreate[
  {docIds @ XMLCases[$ul, Child[XMLPattern["div"], "li:first-child"]],
   docIds @ XMLCases[$ul, Descendant[XMLPattern["div"], "li:last-child"]],
   docIds @ XMLCases[{XMLElement["li", {"id" -> "t"}, {}]}, "li:first-child"]},
  {{"1"}, {"2"}, {"t"}},
  TestID -> "document-css-child-indexed-as-later-stage"
];
