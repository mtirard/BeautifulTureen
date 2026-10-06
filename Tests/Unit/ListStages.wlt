(* List stages (ADR 0016): a WL list pattern after a Child or Descendant link,
   matched against one parent's element children. The selected entry is the
   last top-level entry that is an XML pattern, and names scope as the list
   nested in ADR 0014's tuple pattern. Fixtures are local to this file, and most
   have text between sibling elements, which a list does not see. *)

html[s_] := ImportString["<html><body>" <> s <> "</body></html>", {"HTML", "XMLObject"}];
ids[es_] := Lookup[#[[2]], "id", None] & /@ es;

li = XMLPattern["li"];
p = XMLPattern["p"];
tr = XMLPattern["tr"];
ul = XMLPattern["ul"];
any = XMLPattern[_];

(* Five li, the second and fourth of class a, with text between them. Built
   as an expression, since the HTML importer moves text out of a ul. *)
$five = XMLObject["Document"][{}, XMLElement["html", {}, {XMLElement["body", {}, {
    XMLElement["ul", {"id" -> "u"}, {"x",
      XMLElement["li", {"id" -> "1"}, {"a"}], "x",
      XMLElement["li", {"class" -> "a", "id" -> "2"}, {"b"}], "y",
      XMLElement["li", {"id" -> "3"}, {"c"}],
      XMLElement["li", {"class" -> "a", "id" -> "4"}, {"d"}], "z",
      XMLElement["li", {"id" -> "5"}, {"e"}], "w"}],
    XMLElement["ol", {}, {"o", XMLElement["li", {"id" -> "only"}, {"o"}]}]}]}], {}];

(* Seven rows. *)
$rows = html["<table>" <> StringJoin[Table["<tr id=\"r" <> ToString[k] <> "\"><td>" <> ToString[k] <> "</td></tr>", {k, 7}]] <> "</table>"];

(* === First, last, only === *)

TestCreate[
  {ids @ XMLCases[$five, Child[ul, {x : li, ___}]],
   ids @ XMLCases[$five, Child[ul, {___, li}]],
   ids @ XMLCases[$five, Child[any, {li}]]},
  {{"1"}, {"5"}, {"only"}},
  TestID -> "list-first-last-only"
];

(* === :nth-child(An+B) === *)

TestCreate[
  {ids @ XMLCases[$rows, Child[any, {PatternSequence[_, _] ..., tr, ___}]],
   ids @ XMLCases[$rows, Child[any, {___, tr, Repeated[_, {0, 2}]}]],
   ids @ XMLCases[$rows, Child[any, {Repeated[_, {4}], tr, ___}]],
   ids @ XMLCases[$rows, Child[any, {Repeated[_, {9}], tr, ___}]]},
  {{"r1", "r3", "r5", "r7"}, {"r5", "r6", "r7"}, {"r5"}, {}},
  TestID -> "list-nth-child"
];

(* === -of-type: Except[p] ... is context, not the selected entry === *)

TestCreate[
  ids @ XMLCases[html["<div><span></span><p id=\"p1\"></p> t <span></span><p id=\"p2\"></p><p id=\"p3\"></p></div>"],
    Child[any, {Except[p] ..., p, Except[p] ..., x : p, ___}]],
  {"p2"},
  TestID -> "list-nth-of-type"
];

(* === Identical siblings stay distinct === *)

$same = XMLElement["table", {}, {"a", XMLElement["tr", {}, {XMLElement["td", {}, {"x"}]}], "b",
   XMLElement["tr", {}, {XMLElement["td", {}, {"x"}]}], "c", XMLElement["tr", {}, {XMLElement["td", {}, {"x"}]}], "d"}];

TestCreate[
  {Length @ XMLCases[{$same}, Child[any, {___, tr}]],
   Length @ XMLCases[{$same}, Child[any, {tr, ___}]],
   XMLDeleteCases[$same, Child[any, {___, tr}]][[3]],
   XMLDeleteCases[$same, Child[any, {tr, ___}]][[3]]},
  {1, 1,
   {"a", XMLElement["tr", {}, {XMLElement["td", {}, {"x"}]}], "b", XMLElement["tr", {}, {XMLElement["td", {}, {"x"}]}], "c", "d"},
   {"a", "b", XMLElement["tr", {}, {XMLElement["td", {}, {"x"}]}], "c", XMLElement["tr", {}, {XMLElement["td", {}, {"x"}]}], "d"}},
  TestID -> "list-identical-siblings-distinct"
];

(* === Descendant lists each parent's children === *)

TestCreate[
  ids @ XMLCases[html["<div><p id=\"a\"></p><section><p id=\"b\"></p><p id=\"c\"></p></section></div>"],
    Descendant[XMLPattern["div"], {x : p, ___}]],
  {"a", "b"},
  TestID -> "list-descendant-each-parent"
];

(* === Chaining after a list stage === *)

$links = html["<ul><li><a id=\"x1\"></a></li><li><a id=\"x2\"></a></li></ul><ol><li><a id=\"x3\"></a></li></ol>"];

TestCreate[
  {ids @ XMLCases[$links, Descendant[Child[any, {li, ___}], XMLPattern["a"]]],
   ids @ XMLCases[$links, Child[ul, {li, ___}, XMLPattern["a"]]],
   ids @ XMLCases[$links, Child[ul, Child[{li, ___}, XMLPattern["a"]]]]},
  {{"x1", "x3"}, {"x1"}, {"x1"}},
  TestID -> "list-chaining"
];

(* === Small fixtures with the traps of the soupsieve rows ===
   Hacker News: identical rows, where tr:nth-child(2n+1) and
   tr:nth-last-child(-n+3) count rows by position; Selectors 4: div
   p:first-child over nested parents; CSS: p:nth-of-type(2) with text and other
   tags between. Counts as soupsieve gives them on these fixtures. *)

$hn = html["<table>" <> StringJoin[ConstantArray["<tr class=\"athing\"><td>t</td></tr><tr><td>s</td></tr><tr class=\"spacer\"></tr>", 3]] <>
  "<tr class=\"more\"><td>m</td></tr></table>"];
$nested = html["<div><p>1</p><div><p>2</p><p>3</p><div>t<p>4</p></div></div><span></span><p>5</p></div>"];

TestCreate[
  {Length @ XMLCases[$hn, Child[any, {PatternSequence[_, _] ..., tr, ___}]],
   Length @ XMLCases[$hn, Child[any, {___, tr, Repeated[_, {0, 2}]}]],
   HTMLTextContent /@ XMLCases[$nested, Descendant[XMLPattern["div"], {x : p, ___}]],
   HTMLTextContent /@ XMLCases[$nested, Child[any, {Except[p] ..., p, Except[p] ..., x : p, ___}]]},
  {5, 3, {"1", "2", "4"}, {"3", "5"}},
  TestID -> "list-soupsieve-traps"
];

(* === The selected entry === *)

TestCreate[
  {ids @ XMLCases[$five, Child[ul, {___, XMLPattern[_]}]],
   ids @ XMLCases[$five, Child[ul, {li, XMLPattern[_, "id" -> "2"], ___}]],
   ids @ XMLCases[$five, Child[ul, {XMLPattern[_, "id" -> "1"], li ...}]],
   ids @ XMLCases[$five, Child[ul, {___, XMLPattern["li", "classList" -> "a"] | XMLPattern["li", "id" -> "1"], ___}]],
   ids @ XMLCases[$five, Child[ul, {___, x : li /; Length[x[[2]]] == 2, ___}]]},
  {{"5"}, {"2"}, {"1"}, {"1", "2", "4"}, {"2", "4"}},
  TestID -> "list-selected-entry"
];

TestCreate[
  {XMLCases[$five, Child[ul, {___, _}]],
   XMLCases[$five, Child[ul, {}]],
   XMLCases[$five, Child[ul, {___}]],
   XMLCases[$five, Child[ul, {_, _}]],
   XMLCases[$five, Child[ul, {___, li | _}]]},
  ConstantArray[$Failed, 5],
  {XMLCases::liststage, XMLCases::liststage, XMLCases::liststage, General::stop},
  TestID -> "list-no-xml-pattern-entry"
];

(* === A combinator entry stands for its first stage === *)

$cards = html["<div id=\"d\"><section><a id=\"a1\"></a></section><p></p><section><b><a id=\"a2\"></a></b></section></div>"];

TestCreate[
  {ids @ XMLCases[$cards, Child[XMLPattern["div"], {___, Descendant[XMLPattern["section"], XMLPattern["a"]], ___}]],
   ids @ XMLCases[$cards, Child[XMLPattern["div"], Descendant[XMLPattern["section"], XMLPattern["a"]]]],
   ids @ XMLCases[$links, Child[ul, {___, li, Child[li, XMLPattern["a"]], ___}]]},
  {{"a1", "a2"}, {"a1", "a2"}, {"x2"}},
  TestID -> "list-combinator-entry-selected"
];

$heads = html["<div><h2><span>s</span></h2> t <p id=\"after-span\"></p><h2>plain</h2><p id=\"after-plain\"></p></div>"];

TestCreate[
  {ids @ XMLCases[$heads, Child[any, {___, Descendant[XMLPattern["h2"], XMLPattern["span"]], p, ___}]],
   ids @ XMLCases[$heads, Child[any, {___, Child[XMLPattern["h2"], XMLPattern["span"]] /; True, p, ___}]],
   ids @ XMLCases[$heads, Child[any, {___, Descendant[XMLPattern["h2"], XMLPattern["em"]], p, ___}]]},
  {{"after-span"}, {"after-span"}, {}},
  TestID -> "list-combinator-entry-context"
];

(* The first stage of an entry Adjacent[a, b] is a child of the parent, so a is
   the first child and the result is the sibling after it. *)
TestCreate[
  {ids @ XMLCases[$five, Child[any, {Adjacent[li, li], ___}]],
   ids @ XMLCases[$five, Child[any, {Sibling[li, XMLPattern["li", "classList" -> "a"]], ___}]]},
  {{"2"}, {"2", "4"}},
  TestID -> "list-combinator-entry-sibling-link"
];

(* === Alternatives of lists === *)

TestCreate[
  {ids @ XMLCases[$five, Child[any, {x : li, ___} | {___, x : li}]],
   XMLCases[$five, Child[any, {x : li, ___} | {___, y : li}] :> {x, y}][[All, All, 2, 1, 2]],
   ids @ XMLCases[$five, Child[any, s : ({li, ___} | {___, li})]],
   XMLCases[$five, Child[any, s : ({li, ___} | {___, li})] :> Length[s]]},
  {{"1", "5", "only"}, {{"1"}, {"5"}, {"only"}}, {"1", "5", "only"}, {5, 5, 1}},
  TestID -> "list-alternatives-of-lists"
];

(* === Conditions === *)

TestCreate[
  {ids @ XMLCases[$five, Child[any, {x : li, y : li, ___} /; First[x] === First[y]]],
   ids @ XMLCases[$five, Child[any, {x : li, y : li /; x === y, ___}]],
   ids @ XMLCases[$five, Child[XMLPattern[_, "id" -> u_], {___, x : li}] /; u === "u"]},
  {{"2"}, {}, {"5"}},
  TestID -> "list-conditions"
];

(* === Names === *)

TestCreate[
  {ids @ XMLCases[html["<div id=\"k\"><p data-p=\"z\" id=\"no\"></p><p data-p=\"k\" id=\"yes\"></p></div>"],
     Child[XMLPattern[_, "id" -> i_], {___, XMLPattern[_, "data-p" -> i_]}]],
   XMLCases[$five, Child[ul, {pre___, XMLPattern["li", "classList" -> "a"], ___}] :> ids[{pre}]],
   XMLCases[$five, Child[ul, s : {___, li}] :> Length[s]],
   XMLCases[$five, Child[ul, {___, e : XMLPattern["li", "classList" -> "a"], ___, f : li}] :> {e, f}]},
  {{"yes"}, {{"1"}, {"1", "2", "3"}}, {5},
   {{XMLElement["li", {"class" -> "a", "id" -> "2"}, {"b"}], XMLElement["li", {"id" -> "5"}, {"e"}]}}},
  TestID -> "list-names"
];

(* The same name at two entries is one value, compared as the original
   elements, though the query names a list key. *)
TestCreate[
  ids @ XMLCases[html["<div><p class=\"a\">1</p><p>2</p><p class=\"a\">1</p></div>"],
    Child[any, {___, e : XMLPattern["p", "classList" -> "a"], ___, e : p}]],
  {None},
  TestID -> "list-name-at-two-entries"
];

(* A test or a body that sees only some of the names, with a list key named:
   each name it sees is the original elements, also inside held code, and the
   names it does not see change nothing. *)
TestCreate[
  {ids @ XMLCases[$five, Child[ul, {g1___, c : XMLPattern["li", "classList" -> "a"], g2___} /;
      {g1} === {XMLElement["li", {"id" -> "1"}, {"a"}], XMLElement["li", {"class" -> "a", "id" -> "2"}, {"b"}],
        XMLElement["li", {"id" -> "3"}, {"c"}]}]],
   ids @ XMLCases[$five, Child[ul, {g1___, c : XMLPattern["li", "classList" -> "a"], g2___} /; c[[2]] === {"class" -> "a", "id" -> "4"}]],
   ids @ XMLCases[$five, Child[ul, {g1___, c : XMLPattern["li", "classList" -> "a"], g2___} /; True]],
   ids @ XMLCases[$five, Child[ul, {g1___, c : XMLPattern["li", "classList" -> "a"], g2___} /;
      ReleaseHold[Hold[c]] === XMLElement["li", {"class" -> "a", "id" -> "2"}, {"b"}]]],
   XMLCases[$five, Child[ul, {g1___, c : XMLPattern["li", "classList" -> "a"], g2___} /; Length[{g1}] == 3] :> ids[{g2}]],
   XMLCases[$five, Child[ul, {g1___, XMLPattern["li", "classList" -> "a"], g2___}] :> ids[{g2}] /; Length[{g2}] == 3]},
  {{"4"}, {"4"}, {"2", "4"}, {"2"}, {{"5"}}, {{"3", "4", "5"}}},
  TestID -> "list-names-a-test-does-not-see"
];

(* === Which match binds === *)

TestCreate[
  {XMLCases[$five, Child[any, {___, x : XMLPattern["li", "classList" -> "a"], ___, y : li, ___}] :> ids[{x, y}]],
   XMLCases[$five, Child[any, {___, x : XMLPattern["li", "classList" -> "a"], ___, y : li, ___}] :>
     ids[{x, y}] /; x[[2]] =!= {"class" -> "a", "id" -> "2"}]},
  {{{"2", "3"}, {"2", "4"}, {"2", "5"}}, {{"4", "5"}}},
  TestID -> "list-which-match-binds"
];

(* The list's match is chosen before the div's, which is the outermost that
   qualifies (ADR 0014). *)
TestCreate[
  XMLCases[html["<div id=\"o\"><div id=\"i\"><p id=\"p\"></p></div></div>"],
    Descendant[XMLPattern["div", "id" -> i_], {___, x : XMLPattern["p", "id" -> j_]}] :> {i, j}],
  {{"o", "p"}},
  TestID -> "list-latest-stage-first"
];

(* === Rules, XMLFirstCase and XMLDeleteCases === *)

TestCreate[
  {XMLCases[$five, Child[ul, {XMLPattern["li", "id" -> i_], ___}] -> i],
   XMLFirstCase[$five, Child[any, {___, XMLPattern["li", {"classList" -> "a", "id" -> i_}], ___}] :> i],
   ids @ {XMLFirstCase[$five, Child[any, {___, li}]]},
   XMLFirstCase[$five, Child[any, {___, XMLPattern["li", "id" -> "none"]}], "none"]},
  {{"1"}, "2", {"5"}, "none"},
  TestID -> "list-rule-and-firstcase"
];

TestCreate[
  {ids @ XMLCases[XMLDeleteCases[$five, Child[ul, {li, ___}]], li],
   ids @ XMLCases[XMLDeleteCases[$links, Descendant[XMLPattern["body"], Child[ul, {___, li}, XMLPattern["a"]]]], XMLPattern["a"]],
   ids @ XMLCases[XMLDeleteCases[$five, Descendant[XMLPattern["body"], {___, x : XMLPattern["li", "classList" -> "a"], ___}]], li],
   XMLDeleteCases[$five, Child[ul, {li, ___}] :> 1]},
  {{"2", "3", "4", "5", "only"}, {"x1", "x3"}, {"1", "3", "5", "only"}, $Failed},
  {XMLDeleteCases::badpat},
  TestID -> "list-deletecases"
];

(* === Refusals === *)

TestCreate[
  {XMLCases[$five, {li, ___}],
   XMLCases[$five, {li, ___} /; True],
   XMLFirstCase[$five, {li, ___} :> 1],
   XMLDeleteCases[$five, {li}]},
  ConstantArray[$Failed, 4],
  {XMLCases::liststage, XMLCases::liststage, XMLFirstCase::liststage, XMLDeleteCases::liststage},
  TestID -> "list-refused-as-query"
];

TestCreate[
  {XMLCases[$five, Child[{li, ___}, XMLPattern["a"]]],
   XMLCases[$five, Adjacent[li, {li, ___}]],
   XMLFirstCase[$five, Sibling[li, s : {li}]]},
  ConstantArray[$Failed, 3],
  {XMLCases::liststage, XMLCases::liststage, XMLFirstCase::liststage},
  TestID -> "list-refused-first-or-after-sibling"
];

TestCreate[
  {XMLCases[$five, Child[ul, {___, {li}}]],
   XMLCases[$five, Child[ul, {___, XMLElement["li", _, _]}]],
   XMLCases[$five, Child[ul, {___, Child[{li}, XMLPattern["a"]]}]],
   XMLDeleteCases[$five, Child[ul, {___, li, 3}]]},
  ConstantArray[$Failed, 4],
  {XMLCases::listentry, XMLCases::listentry, XMLCases::listentry, General::stop, XMLDeleteCases::listentry},
  TestID -> "list-refused-entries"
];

(* A context combinator entry is a test, and the names of its later stages are
   its own: one used elsewhere is refused, and alternatives holding a combinator
   can only be the selected entry. *)
TestCreate[
  {XMLCases[$heads, Child[any, {___, Descendant[XMLPattern["h2"], XMLPattern["span", "id" -> i_]], XMLPattern["p", "id" -> i_], ___}]],
   XMLCases[$heads, Child[any, {___, Descendant[XMLPattern["h2"], XMLPattern["span"]] | XMLPattern["h2"], p, ___}]]},
  {$Failed, $Failed},
  {XMLCases::listentry, XMLCases::listentry},
  TestID -> "list-refused-context-combinator"
];

TestCreate[
  {XMLMatchQ[XMLElement["li", {}, {}], Child[any, {li}]],
   XMLMatchQ[XMLElement["li", {}, {}], {li}],
   HTMLInnerText[$five, "Roles" -> {Child[any, {li}] -> "Skip"}]},
  {$Failed, $Failed, $Failed},
  {XMLMatchQ::combinator, XMLMatchQ::liststage, HTMLInnerText::badpat},
  TestID -> "list-refused-one-element"
];

(* === The root (ADR 0016, "The root") ===
   After an element pattern, a list stage never selects the root: on an
   XMLObject the root element is no element's child, and a bare XMLElement
   input is a parent, not a result. After XMLDocument[] it does (ADR 0018,
   XMLDocument.wlt). *)
TestCreate[
  {XMLCases[$five, Child[any, {x : XMLPattern["html"], ___}]],
   HTMLTextContent /@ XMLCases[XMLElement["body", {}, {"t", XMLElement["p", {}, {"1"}], XMLElement["p", {}, {"2"}]}], Child[any, {p, ___}]]},
  {{}, {"1"}},
  TestID -> "list-root"
];
