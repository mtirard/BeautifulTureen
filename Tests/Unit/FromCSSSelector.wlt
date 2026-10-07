(* FromCSSSelector (ADR 0017): the translation table, the grammar, the
   messages, and a CSS selector string where an XML pattern goes. Each row of
   the translation is checked by what it selects, through XMLCases; rows with
   no generated names are also checked as expressions. *)

(* The ids of what a selector selects, run through its translation. *)
ids[tree_, sel_String, opts___] := Lookup[#[[2]], "id", None] & /@ XMLCases[tree, FromCSSSelector[sel], opts];

(* The output holds no symbol of the paclet's private context. *)
privateFreeQ[x_] :=
  FreeQ[x, s_Symbol /; Context[s] === "MaximilienTirard`BeautifulTureen`Private`", {0, Infinity}, Heads -> True];

element[html_String] := XMLFirstCase[ImportString[html, {"HTML", "XMLObject"}], XMLPattern["div"]];

$attrs = element["<div id='root'>
<a id='a1' href='https://x.org/a.svg' hreflang='en' lang='en-US' rel='nofollow'>1</a>
<a id='a2' href='#top' lang='en' class='btn primary'>2</a>
<a id='a3' class='btn' title='Bar baz'>3</a>
<a id='a4' href='http://w3.org/x' title='bAR' data-x=''>4</a>
<span id='s1' title='\[CapitalEAcute]'></span>
<span id='s2' title='\[EAcute]'></span>
</div>"];

$chain = element["<div id='d'><section id='s'><h2 id='h'>t</h2><p id='p1'>x</p><p id='p2'><span id='sp'>y</span></p></section><p id='p3'>z</p></div>"];

(* === Simple selectors === *)

TestCreate[
  {FromCSSSelector["a"], FromCSSSelector["*"], FromCSSSelector[".btn"], FromCSSSelector[".btn.primary"],
    FromCSSSelector["#a3"], FromCSSSelector["[href]"], FromCSSSelector["[lang=en]"]},
  {XMLPattern["a"], XMLPattern[_], XMLPattern[_, "classList" -> "btn"],
    XMLPattern[_, "classList" -> _?(ContainsAll[{"btn", "primary"}])], XMLPattern[_, "id" -> "a3"],
    XMLPattern[_, "href"], XMLPattern[_, "lang" -> "en"]},
  TestID -> "css-simple-exact"
];

TestCreate[
  ids[$attrs, #] & /@ {"a", "span", ".btn", ".btn.primary", "#a3", "[href]", "[lang=en]", "[data-x]"},
  {{"a1", "a2", "a3", "a4"}, {"s1", "s2"}, {"a2", "a3"}, {"a2"}, {"a3"}, {"a1", "a2", "a4"}, {"a2"}, {"a4"}},
  TestID -> "css-simple-selects"
];

TestCreate[
  Length[XMLCases[$attrs, FromCSSSelector["*"]]],
  6,
  TestID -> "css-universal-selects-every-element"
];

TestCreate[
  {FromCSSSelector["[rel~=nofollow]"], FromCSSSelector["[class~=btn]"], FromCSSSelector["[lang|=en]"],
    FromCSSSelector["[href^=https]"], FromCSSSelector["[href$='.svg']"], FromCSSSelector["[href*=w3]"]},
  {XMLPattern[_, "relList" -> "nofollow"], XMLPattern[_, "classList" -> "btn"],
    XMLPattern[_, "lang" -> "en" | _?(StringStartsQ["en-"])], XMLPattern[_, "href" -> _?(StringStartsQ["https"])],
    XMLPattern[_, "href" -> _?(StringEndsQ[".svg"])], XMLPattern[_, "href" -> _?(StringContainsQ["w3"])]},
  TestID -> "css-attribute-operators-exact"
];

TestCreate[
  {ids[$attrs, "[rel~=nofollow]", "AttributeReadings" -> <|"rel" -> <||>|>], ids[$attrs, "[class~=btn]"],
    ids[$attrs, "[lang|=en]"], ids[$attrs, "[href^=https]"], ids[$attrs, "[href$='.svg']"], ids[$attrs, "[href*=w3]"]},
  {{"a1"}, {"a2", "a3"}, {"a1", "a2"}, {"a1"}, {"a1"}, {"a4"}},
  TestID -> "css-attribute-operators-select"
];

(* An empty value of ^=, $= or *= never matches; ~= with an empty value or a
   space needs no special case. *)
TestCreate[
  {FromCSSSelector["[href^='']"], ids[$attrs, "[href^='']"], ids[$attrs, "[href$='']"], ids[$attrs, "[href*='']"],
    FromCSSSelector["[title~='']"], ids[$attrs, "[title~='']", "AttributeReadings" -> <|"title" -> <||>|>],
    ids[$attrs, "[title~='Bar baz']", "AttributeReadings" -> <|"title" -> <||>|>]},
  {XMLPattern[_, "href" -> Except[_]], {}, {}, {}, XMLPattern[_, "titleList" -> ""], {}, {}},
  TestID -> "css-empty-substring-never-matches"
];

(* The i flag folds A-Z only, on both sides; s is the default. *)
TestCreate[
  {ids[$attrs, "[title='bar' i]"], ids[$attrs, "[title='BAR' I]"], ids[$attrs, "[title='\[EAcute]' i]"],
    ids[$attrs, "[title^=b i]"], ids[$attrs, "[title$=AZ i]"], ids[$attrs, "[title*=R\\ B i]"],
    ids[$attrs, "[lang|=EN i]"], ids[$attrs, "[title='Bar baz' s]"], ids[$attrs, "[title=bar s]"],
    ids[$attrs, "[class~=BTN i]"]},
  {{"a4"}, {"a4"}, {"s2"}, {"a3", "a4"}, {"a3"}, {"a3"}, {"a1", "a2"}, {"a3"}, {}, {"a2", "a3"}},
  TestID -> "css-case-flags"
];

(* === Merging the constraints on one key === *)

TestCreate[
  {FromCSSSelector["[id]#a3"], FromCSSSelector["#a1#a2"], FromCSSSelector["[lang=en][lang=en]"],
    FromCSSSelector["[lang=en][lang=fr]"], FromCSSSelector[".btn[class~=primary]"]},
  {XMLPattern[_, "id" -> "a3"], XMLPattern[_, "id" -> Except[_]], XMLPattern[_, "lang" -> "en"],
    XMLPattern[_, "lang" -> Except[_]], XMLPattern[_, "classList" -> _?(ContainsAll[{"btn", "primary"}])]},
  TestID -> "css-merge-exact"
];

TestCreate[
  {ids[$attrs, "[href^=http][href$=x]"], ids[$attrs, "[href^=http][href$=y]"], ids[$attrs, ".btn[class~=primary]"],
    ids[$attrs, "#a1#a2"], ids[$attrs, "[lang=en][lang|=en]"], ids[$attrs, "[lang=en][lang^=f]"],
    ids[$attrs, "[title=bAR][title=bar i]"], ids[$attrs, "a[title][title*=a]"]},
  {{"a4"}, {}, {"a2"}, {}, {"a2"}, {}, {"a4"}, {"a3"}},
  TestID -> "css-merge-selects"
];

TestCreate[
  FromCSSSelector["[href^=x][href$=y]"],
  XMLPattern[_, "href" -> _?(StringStartsQ[#, "x"] && StringEndsQ[#, "y"] &)],
  TestID -> "css-merge-two-tests"
];

(* === Combinators === *)

TestCreate[
  {FromCSSSelector["a b"], FromCSSSelector["a > b"], FromCSSSelector["a + b"], FromCSSSelector["a ~ b"],
    FromCSSSelector["a b c"], FromCSSSelector["a b > c"], FromCSSSelector["a>b+c~d"]},
  {Descendant[XMLPattern["a"], XMLPattern["b"]], Child[XMLPattern["a"], XMLPattern["b"]],
    Adjacent[XMLPattern["a"], XMLPattern["b"]], Sibling[XMLPattern["a"], XMLPattern["b"]],
    Descendant[XMLPattern["a"], XMLPattern["b"], XMLPattern["c"]],
    Descendant[XMLPattern["a"], Child[XMLPattern["b"], XMLPattern["c"]]],
    Child[XMLPattern["a"], Adjacent[XMLPattern["b"], Sibling[XMLPattern["c"], XMLPattern["d"]]]]},
  TestID -> "css-combinators-exact"
];

TestCreate[
  ids[$chain, #] & /@ {"section p", "div > p", "h2 + p", "h2 ~ p", "div section p", "div p > span", "section > p + p"},
  {{"p1", "p2"}, {"p3"}, {"p1"}, {"p1", "p2"}, {"p1", "p2"}, {"sp"}, {"p2"}},
  TestID -> "css-combinators-select"
];

(* === Pseudo-classes === *)

$classes = element["<div><p id='p1' class='a b'>1</p><p id='p2' class='a'>2</p><p id='p3'>3</p><span id='s1' class='a'>4</span></div>"];

TestCreate[
  {FromCSSSelector["p:not(.b)"], FromCSSSelector["p:not(.a):not(.b)"], FromCSSSelector["p.a:not(.b)"],
    FromCSSSelector["p:not(div)"], FromCSSSelector["p:not(p)"], FromCSSSelector[":not(p)"]},
  {XMLPattern["p", "classList" -> _?(FreeQ["b"])], XMLPattern["p", "classList" -> _?(ContainsNone[{"a", "b"}])],
    XMLPattern["p", "classList" -> _?(ContainsAll[#, {"a"}] && ContainsNone[#, {"b"}] &)],
    XMLPattern["p"], XMLPattern["p"] /; False, XMLPattern[_?(# =!= "p" &)]},
  TestID -> "css-not-merged-exact"
];

(* A classless element has none of the classes, as in CSS. *)
TestCreate[
  ids[$classes, #] & /@ {"p:not(.b)", "p:not(.a):not(.b)", "p.a:not(.b)", "p:not(div)", "p:not(p)", ":not(p)",
    ".a:not(.a)", ":not(p):not(span)"},
  {{"p2", "p3"}, {"p3"}, {"p2"}, {"p1", "p2", "p3"}, {}, {"s1"}, {}, {}},
  TestID -> "css-not-merged-selects"
];

(* Otherwise :not is a condition, never an Except at a raw key, which would
   require the attribute: a3 has no href. *)
TestCreate[
  {ids[$attrs, "a:not([href^='#'])"], ids[$attrs, "a:not(#a1, .primary)"], ids[$attrs, "a:not(.btn.primary)"],
    ids[$attrs, ":not(a, span)"], ids[$attrs, "a:not(:is(.btn))"]},
  {{"a1", "a3", "a4"}, {"a3", "a4"}, {"a1", "a3", "a4"}, {}, {"a1", "a4"}},
  TestID -> "css-not-condition-selects"
];

TestCreate[
  MatchQ[FromCSSSelector["a:not([href])"],
    Verbatim[Condition][Verbatim[Pattern][e_Symbol, XMLPattern["a"]], HoldPattern[! XMLMatchQ[XMLPattern[_, "href"]][e_]]]],
  True,
  TestID -> "css-not-condition-shape"
];

TestCreate[
  {FromCSSSelector[":is(h1, h2)"], FromCSSSelector["a:is(.x, .y)"], FromCSSSelector["p:is(p, ::before)"],
    FromCSSSelector[":is()"], FromCSSSelector[":where(h1, .x)"]},
  {XMLPattern["h1"] | XMLPattern["h2"], XMLPattern["a", "classList" -> "x"] | XMLPattern["a", "classList" -> "y"],
    XMLPattern["p"], XMLPattern[_] /; False, XMLPattern["h1"] | XMLPattern[_, "classList" -> "x"]},
  TestID -> "css-is-exact"
];

TestCreate[
  {ids[$attrs, ":is(#a1, .primary)"], ids[$attrs, "a:is(.btn, [rel])"], ids[$attrs, "a:where(.btn)"],
    ids[$attrs, ":is()"], ids[$attrs, "a:is(span)"], ids[$attrs, ".btn:is(.primary, #a3):not(#a2)"],
    ids[$attrs, "a:is(.btn, :not([href]))"], ids[$attrs, "a:is(:not(.btn), #a3)"]},
  {{"a1", "a2"}, {"a1", "a2", "a3"}, {"a2", "a3"}, {}, {}, {"a3"}, {"a2", "a3"}, {"a1", "a3", "a4"}},
  TestID -> "css-is-selects"
];

$has = XMLElement["body", {}, {XMLElement["div", {"id" -> "root"}, {
  XMLElement["div", {"id" -> "d1"}, {XMLElement["a", {}, {}], XMLElement["b", {}, {}]}],
  XMLElement["div", {"id" -> "d2"}, {XMLElement["a", {}, {}], XMLElement["i", {}, {}], XMLElement["b", {}, {}]}],
  XMLElement["div", {"id" -> "d3"}, {XMLElement["p", {"id" -> "p1"}, {XMLElement["span", {}, {}]}]}],
  XMLElement["section", {"id" -> "x1"}, {XMLElement["h2", {}, {}], XMLElement["p", {}, {}]}],
  XMLElement["section", {"id" -> "x2"}, {XMLElement["h2", {}, {}], XMLElement["div", {"id" -> "d5"}, {XMLElement["p", {}, {}]}]}],
  XMLElement["div", {"id" -> "d4"}, {"text", XMLElement["p", {"id" -> "p2"}, {}]}]}]}];

TestCreate[
  {ids[$has, "div:has(span)"], ids[$has, "div:has(> span)"], ids[$has, "div:has(> p)"], ids[$has, "div:has(a + b)"],
    ids[$has, "div:has(a ~ b)"], ids[$has, "section:has(> h2 + p)"], ids[$has, "div:has(> p span)"],
    ids[$has, "div:has(> p > span)"], ids[$has, "div:has(> a, > p)"], ids[$has, "p:has(span)"],
    ids[$has, "div:has(> p:only-child)"], ids[$has, "div:has(p):not(:has(span))"]},
  {{"root", "d3"}, {}, {"d3", "d5", "d4"}, {"root", "d1"}, {"root", "d1", "d2"}, {"x1"}, {"d3"}, {"d3"},
    {"d1", "d2", "d3", "d5", "d4"}, {"p1"}, {"d3", "d5", "d4"}, {"d5", "d4"}},
  TestID -> "css-has-selects"
];

TestCreate[
  {MatchQ[FromCSSSelector["div:has(p)"],
      Verbatim[Condition][Verbatim[Pattern][e_Symbol, XMLPattern["div"]],
        HoldPattern[! MissingQ[XMLFirstCase[Cases[Last[e_], Verbatim[_XMLElement]], XMLPattern["p"]]]]]],
    MatchQ[FromCSSSelector["div:has(> p)"],
      Verbatim[Condition][Verbatim[Pattern][e_Symbol, XMLPattern["div"]], HoldPattern[AnyTrue[Last[e_], XMLMatchQ[XMLPattern["p"]]]]]],
    MatchQ[FromCSSSelector["div:has(a + b)"],
      Verbatim[Condition][Verbatim[Pattern][e_Symbol, XMLPattern["div"]],
        HoldPattern[! MissingQ[XMLFirstCase[XMLElement[{"urn:x-beautifultureen:anchor", "anchor"}, {}, Last[e_]],
          Descendant[XMLPattern[{"urn:x-beautifultureen:anchor", "anchor"}], Adjacent[XMLPattern["a"], XMLPattern["b"]]]]]]]]},
  {True, True, True},
  TestID -> "css-has-shapes"
];

(* An XML document's children can hold comments, which a list given to
   XMLFirstCase cannot. *)
TestCreate[
  XMLMatchQ[XMLElement["div", {}, {XMLObject["Comment"]["c"], XMLElement["p", {}, {}]}], FromCSSSelector["div:has(p)"]],
  True,
  TestID -> "css-has-children-with-a-comment"
];

$empty = XMLElement["div", {}, {
  XMLElement["p", {"id" -> "e1"}, {}], XMLElement["p", {"id" -> "e2"}, {" \n\t"}],
  XMLElement["p", {"id" -> "e3"}, {XMLObject["Comment"]["c"], ""}], XMLElement["p", {"id" -> "e4"}, {"x"}],
  XMLElement["p", {"id" -> "e5"}, {XMLElement["b", {}, {}]}], XMLElement["p", {"id" -> "e6"}, {"\[NonBreakingSpace]"}]}];

TestCreate[
  {ids[$empty, "p:empty"], ids[$empty, ":empty"]},
  {{"e1", "e2", "e3"}, {"e1", "e2", "e3", None}},
  TestID -> "css-empty-selects"
];

$links = element["<div><a id='l1' href='x'>1</a><a id='l2'>2</a><map><area id='l3' href='y'></map><link id='l4' href='z'><span id='l5' href='w'>5</span></div>"];

TestCreate[
  {FromCSSSelector[":link"], FromCSSSelector["a:any-link"], FromCSSSelector["div:link"], FromCSSSelector["area:link"]},
  {XMLPattern["a" | "area", "href"], XMLPattern["a", "href"], XMLPattern["div"] /; False, XMLPattern["area", "href"]},
  TestID -> "css-link-exact"
];

TestCreate[
  {ids[$links, ":link"], ids[$links, ":any-link"], ids[$links, "span:link"], ids[$links, ":not(a):link"]},
  {{"l1", "l3"}, {"l1", "l3"}, {}, {"l3"}},
  TestID -> "css-link-selects"
];

$forms = element["<div><input id='i1' type='checkbox' checked><input id='i2' type='CHECKBOX' checked><input id='i3' type='radio' checked class='x'><input id='i4' type='text' checked><input id='i5' type='checkbox'><select><option id='o1' selected>a</option><option id='o2'>b</option></select></div>"];

TestCreate[
  {ids[$forms, ":checked"], ids[$forms, "input:checked"], ids[$forms, "option:checked"], ids[$forms, ".x:checked"],
    ids[$forms, "p:checked"], ids[$forms, "[type=radio]:checked"]},
  {{"i1", "i2", "i3", "o1"}, {"i1", "i2", "i3"}, {"o1"}, {"i3"}, {}, {"i3"}},
  TestID -> "css-checked-selects"
];

TestCreate[
  {FromCSSSelector[":checked"], FromCSSSelector["option:checked"]},
  {XMLPattern["input", {"type" -> _?(StringMatchQ["checkbox" | "radio", IgnoreCase -> True]), "checked"}] |
      XMLPattern["option", "selected"],
    XMLPattern["option", "selected"]},
  TestID -> "css-checked-exact"
];

$only = XMLElement["div", {"id" -> "root"}, {
  XMLElement["ul", {"id" -> "u1"}, {"\n", XMLElement["li", {"id" -> "l1"}, {XMLElement["a", {"id" -> "a1"}, {"x"}]}], "\n"}],
  XMLElement["ul", {"id" -> "u2"}, {XMLElement["li", {"id" -> "l2"}, {"y"}], XMLElement["li", {"id" -> "l3"}, {"z"}]}],
  XMLElement["ol", {"id" -> "o1"}, {XMLElement["li", {"id" -> "l4"}, {"w"}], XMLElement["p", {"id" -> "p1"}, {"v"}]}]}];

TestCreate[
  {ids[$only, "li:only-child"], ids[$only, "ul > li:only-child"], ids[$only, "li:only-child a"],
    ids[$only, "li:only-of-type"], ids[$only, "li:only-child:only-of-type"], ids[$only, "ol > li:only-of-type"],
    ids[$only, "ul:only-of-type"], ids[$only, "li:only-of-type + p"], ids[$only, "ul > li:only-child > a:only-child"],
    ids[$only, "ul > li:only-child, ol > li:only-child"], ids[$only, "ul > li:only-of-type, ol > li:only-of-type"]},
  {{"l1"}, {"l1"}, {"a1"}, {"l1", "l4"}, {"l1"}, {"l4"}, {}, {"p1"}, {"a1"}, {"l1"}, {"l1", "l4"}},
  TestID -> "css-only-selects"
];

TestCreate[
  {FromCSSSelector["li:only-child"], FromCSSSelector["li:only-child a"], FromCSSSelector["ul li:only-child"],
    FromCSSSelector["li:only-of-type"],
    MatchQ[FromCSSSelector["ul > li:only-child:only-of-type"],
      Child[XMLPattern["ul"], Verbatim[Condition][{Verbatim[Pattern][_Symbol, Verbatim[___]],
        Verbatim[Pattern][_Symbol, XMLPattern["li"]], Verbatim[Pattern][_Symbol, Verbatim[___]]}, _And]]]},
  {Child[XMLDocument[] | XMLPattern[_], {XMLPattern["li"]}], Child[XMLDocument[] | XMLPattern[_], Descendant[{XMLPattern["li"]}, XMLPattern["a"]]],
    Descendant[XMLPattern["ul"], {XMLPattern["li"]}],
    Child[XMLDocument[] | XMLPattern[_], {Except[XMLPattern["li"]] ..., XMLPattern["li"], Except[XMLPattern["li"]] ...}], True},
  TestID -> "css-only-exact"
];

(* :only-child after a descendant combinator, + or ~ translates (ADR 0016). *)
TestCreate[
  {ids[$only, "div li:only-child"], ids[$only, "div li:only-child > a"], ids[$only, "ul + ul > li:only-of-type"],
    ids[$only, "ul ~ ol:only-of-type"], ids[$only, "li ~ p:only-of-type"]},
  {{"l1"}, {"a1"}, {}, {"o1"}, {"p1"}},
  TestID -> "css-only-after-any-link"
];

(* === Child-indexed pseudo-classes === *)

(* Six children, three of them p, two with class a. *)
$kids = element["<div id='root'><p id='p1'>1</p><span id='s1'></span><p id='p2'>2</p><p id='p3' class='a'>3</p>" <>
  "<b id='b1'><i id='i1'></i></b><p id='p4' class='a'>4</p></div>"];

TestCreate[
  {FromCSSSelector["li:first-child"], FromCSSSelector["li:last-child"], FromCSSSelector["div > p:nth-child(3)"],
    FromCSSSelector["tr:nth-child(2n+1)"], FromCSSSelector["tr:nth-child(odd)"], FromCSSSelector["tr:nth-last-child(-n+3)"],
    FromCSSSelector["p:nth-of-type(2)"],
    FromCSSSelector["p:last-of-type"], FromCSSSelector["a + b:last-child"],
    FromCSSSelector["a:first-child ~ b"], FromCSSSelector["p:nth-child(0)"]},
  {Child[XMLDocument[] | XMLPattern[_], {XMLPattern["li"], ___}], Child[XMLDocument[] | XMLPattern[_], {___, XMLPattern["li"]}],
    Child[XMLPattern["div"], {Repeated[_, {2}], XMLPattern["p"], ___}],
    Child[XMLDocument[] | XMLPattern[_], {PatternSequence[_, _] ..., XMLPattern["tr"], ___}],
    Child[XMLDocument[] | XMLPattern[_], {PatternSequence[_, _] ..., XMLPattern["tr"], ___}],
    Child[XMLDocument[] | XMLPattern[_], {___, XMLPattern["tr"], Repeated[_, {0, 2}]}],
    Child[XMLDocument[] | XMLPattern[_], {Except[XMLPattern["p"]] ..., PatternSequence[XMLPattern["p"], Except[XMLPattern["p"]] ...], XMLPattern["p"], ___}],
    Child[XMLDocument[] | XMLPattern[_], {___, XMLPattern["p"], Except[XMLPattern["p"]] ...}],
    Child[XMLDocument[] | XMLPattern[_], {___, XMLPattern["a"], XMLPattern["b"]}],
    Child[XMLDocument[] | XMLPattern[_], {XMLPattern["a"], ___, XMLPattern["b"], ___}],
    Child[XMLDocument[] | XMLPattern[_], {Except[_], XMLPattern["p"], ___}]},
  TestID -> "css-child-indexed-exact"
];

(* Each An+B branch: a = 0, a > 0, a < 0, b < 1, and an index past the end. *)
TestCreate[
  ids[$kids, #] & /@ {"p:nth-child(3)", "p:nth-child(0)", "p:nth-child(-3)", "p:nth-child(7)", ":nth-child(2n+1)",
    ":nth-child(3n-1)", ":nth-child(2n-4)", ":nth-child(n+5)", ":nth-child(-n+2)", ":nth-child(-2n+5)", ":nth-child(-n)",
    ":nth-child(-n-1)", ":nth-last-child(2n)", ":nth-last-child(-n+2)", "p:nth-of-type(3)", "p:nth-last-of-type(2n+1)",
    "p:nth-of-type(-n+2)", "div > :first-child", "div > :last-child"},
  {{"p2"}, {}, {}, {}, {"p1", "p2", "b1", "i1"}, {"s1", "b1"}, {"s1", "p3", "p4"}, {"b1", "p4"}, {"p1", "s1", "i1"},
    {"p1", "p2", "b1", "i1"}, {}, {}, {"p1", "p2", "b1"}, {"b1", "i1", "p4"}, {"p3"}, {"p2", "p4"}, {"p1", "p2"},
    {"p1"}, {"p4"}},
  TestID -> "css-child-indexed-an-plus-b"
];

TestCreate[
  ids[$kids, #] & /@ {":nth-child(2 of .a)", "p:nth-child(2n+1 of .a)", ":nth-last-child(1 of :has(i))",
    ":nth-child(2 of :has(i), .a)", ".a:first-of-type", ".a:last-of-type", ":first-of-type", "span + p:nth-child(3)",
    "span ~ p:nth-of-type(4)", "p:first-child ~ b:has(i)", "p:first-child:last-of-type", "p:nth-child(2):nth-last-child(1)"},
  {{"p4"}, {"p3"}, {"b1"}, {"b1"}, {}, {"p4"}, {"p1", "s1", "b1", "i1"}, {"p2"}, {"p4"}, {"b1"}, {}, {}},
  TestID -> "css-child-indexed-selects"
];

(* The general form is a condition on the list, named apart from the user's
   names, and keeps a compound's own name. The compounds of a run before the
   last are tested on the siblings before it. *)
TestCreate[
  {MatchQ[FromCSSSelector[".x:first-of-type"],
      Child[Verbatim[XMLDocument[] | XMLPattern[_]], Verbatim[Condition][{_Pattern, Verbatim[Pattern][_Symbol, XMLPattern[_, "classList" -> "x"]], _Pattern}, _]]],
    MatchQ[FromCSSSelector["b:has(i) ~ p:nth-child(4)"],
      Child[Verbatim[XMLDocument[] | XMLPattern[_]], Verbatim[Condition][{_Pattern, Verbatim[Pattern][_Symbol, XMLPattern["p"]], _Pattern}, _And]]],
    MatchQ[FromCSSSelector[":has(i):nth-of-type(1)"],
      Child[Verbatim[XMLDocument[] | XMLPattern[_]], Verbatim[Condition][{_Pattern, Verbatim[Condition][Verbatim[Pattern][_Symbol, XMLPattern[_]], _], _Pattern}, _]]],
    Lookup[XMLCases[$kids, Child[":has(i):nth-child(5):first-of-type", e : XMLPattern["i"]] :> e][[All, 2]], "id"]},
  {True, True, True, {"i1"}},
  TestID -> "css-child-indexed-general-form"
];

(* A position among the siblings that match S, of a compound alone in its run,
   is written with plain entries (ADR 0017, shapes 4 and 5 of ADR 0020): the
   siblings that do not match S, then one group for each earlier sibling that
   does, PatternSequence[S, Except[S] ...], and the mirror from the end. The
   compound already matches S: of S is intersected into it, and -of-type
   counts its own type. *)
With[{p = XMLPattern["p"], a = XMLPattern[_, "classList" -> "a"], any = XMLDocument[] | XMLPattern[_]},
  TestCreate[
    FromCSSSelector /@ {"p:nth-of-type(3)", "p:nth-of-type(2n+1)", "p:nth-of-type(2n)", "p:nth-of-type(-n+3)",
      "p:nth-of-type(0)", "p:nth-last-of-type(2)", "p:nth-last-of-type(-n+2)", "tr:nth-child(2n+1 of .a)",
      ":nth-last-child(n+2 of .a)", "p:nth-of-type(2):last-child", "p:only-of-type", ":nth-child(1 of *)", "div > p:nth-of-type(2)"},
    {Child[any, {Except[p] ..., Repeated[PatternSequence[p, Except[p] ...], {2}], p, ___}],
      Child[any, {Except[p] ..., PatternSequence[p, Except[p] ..., p, Except[p] ...] ..., p, ___}],
      Child[any, {Except[p] ..., PatternSequence[p, Except[p] ...], PatternSequence[p, Except[p] ..., p, Except[p] ...] ..., p, ___}],
      Child[any, {Except[p] ..., Repeated[PatternSequence[p, Except[p] ...], {0, 2}], p, ___}],
      Child[any, {Except[_], p, ___}],
      Child[any, {___, p, PatternSequence[Except[p] ..., p], Except[p] ...}],
      Child[any, {___, p, Repeated[PatternSequence[Except[p] ..., p], {0, 1}], Except[p] ...}],
      Child[any, {Except[a] ..., PatternSequence[a, Except[a] ..., a, Except[a] ...] ..., XMLPattern["tr", "classList" -> "a"], ___}],
      Child[any, {___, a, PatternSequence[Except[a] ..., a] ..., PatternSequence[Except[a] ..., a], Except[a] ...}],
      Child[any, {Except[p] ..., PatternSequence[p, Except[p] ...], p}],
      Child[any, {Except[p] ..., p, Except[p] ...}],
      Child[any, {Except[XMLPattern[_]] ..., XMLPattern[_], ___}],
      Child[XMLPattern["div"], {Except[p] ..., PatternSequence[p, Except[p] ...], p, ___}]},
    TestID -> "css-child-indexed-counted-exact"
  ]
];

(* A selector S that names its element is tested whole, so that the entries
   bind no name. *)
TestCreate[
  MatchQ[FromCSSSelector[":nth-child(2 of :has(i))"],
    Child[Verbatim[XMLDocument[] | XMLPattern[_]], {Verbatim[RepeatedNull][Verbatim[Except][s : Verbatim[PatternTest][Verbatim[_], _XMLMatchQ]]],
      Verbatim[PatternSequence][s_, Verbatim[RepeatedNull][Verbatim[Except][s_]]], Verbatim[Condition][Verbatim[Pattern][_Symbol, XMLPattern[_]], _], Verbatim[___]}]],
  True,
  TestID -> "css-child-indexed-counted-named-selector"
];

(* A position of a compound joined to the first of its run by + alone, with no
   position of its own on that side, moves to the first, less the compounds
   between, and is written with plain entries; the same from the end. *)
TestCreate[
  FromCSSSelector /@ {".b + .a:nth-child(5)", ".b + .a:nth-child(2n+1)", "a:nth-last-child(2) + b", "a + b + c:nth-child(n+4)",
    "div > .b + .a:nth-child(-n+3)", "a + b:nth-child(2):nth-last-child(2)", "a:nth-last-child(odd) + b + c",
    "a + b:nth-child(1)", "a + b:nth-child(-n+1)", "a:nth-child(3) + b:nth-last-child(2) + c", "a + b:nth-child(2n+1) ~ c"},
  {Child[XMLDocument[] | XMLPattern[_], {Repeated[_, {3}], XMLPattern[_, "classList" -> "b"], XMLPattern[_, "classList" -> "a"], ___}],
    Child[XMLDocument[] | XMLPattern[_], {_, PatternSequence[_, _] ..., XMLPattern[_, "classList" -> "b"], XMLPattern[_, "classList" -> "a"], ___}],
    Child[XMLDocument[] | XMLPattern[_], {___, XMLPattern["a"], XMLPattern["b"]}],
    Child[XMLDocument[] | XMLPattern[_], {_, _ ..., XMLPattern["a"], XMLPattern["b"], XMLPattern["c"], ___}],
    Child[XMLPattern["div"], {Repeated[_, {0, 1}], XMLPattern[_, "classList" -> "b"], XMLPattern[_, "classList" -> "a"], ___}],
    Child[XMLDocument[] | XMLPattern[_], {XMLPattern["a"], XMLPattern["b"], _}],
    Child[XMLDocument[] | XMLPattern[_], {___, XMLPattern["a"], XMLPattern["b"], XMLPattern["c"], PatternSequence[_, _] ...}],
    Child[XMLDocument[] | XMLPattern[_], {Except[_], XMLPattern["a"], XMLPattern["b"], ___}],
    Child[XMLDocument[] | XMLPattern[_], {Except[_], XMLPattern["a"], XMLPattern["b"], ___}],
    Child[XMLDocument[] | XMLPattern[_], {Repeated[_, {2}], XMLPattern["a"], XMLPattern["b"], XMLPattern["c"]}],
    Child[XMLDocument[] | XMLPattern[_], {_, PatternSequence[_, _] ..., XMLPattern["a"], XMLPattern["b"], ___, XMLPattern["c"], ___}]},
  TestID -> "css-child-indexed-shifted-exact"
];

(* A position reached across ~, one counted among a type or a selector in a run
   of more than one compound, one among the element's own type, and two
   positions landing on one end keep the general form. A counted position of a
   compound alone in its run is written with plain entries
   (css-child-indexed-counted-exact). *)
TestCreate[
  MatchQ[FromCSSSelector[#], Child[_, _Condition]] & /@ {"a ~ b:nth-child(3)", "a ~ b + c:nth-child(3)", "a + b:nth-of-type(2)",
    "a + b:first-of-type", "a + b:nth-child(2 of .x)", "a:nth-of-type(2) + b", "a:nth-last-child(2 of .x) ~ b",
    ".x:nth-of-type(2)", "a:first-child + b:nth-child(2)", "a:nth-last-child(2) + b:last-child",
    "a + b:nth-child(odd) + c:nth-child(3)", "b:nth-of-type(2)", "b:nth-child(2 of .x)", "b:nth-last-of-type(odd)"},
  Join[ConstantArray[True, 11], ConstantArray[False, 3]],
  TestID -> "css-child-indexed-shifted-general"
];

TestCreate[
  {Lookup[XMLDeleteCases[$kids, ":nth-child(odd)"][[3, All, 2]], "id"], ids[$kids, "b:has(> i:last-child)"],
    ids[$kids, "div:has(b:first-child)"], XMLMatchQ[XMLElement["li", {}, {}], "li:first-child"]},
  {{"s1", "p3", "p4"}, {"b1"}, {}, $Failed},
  {XMLMatchQ::combinator},
  TestID -> "css-child-indexed-in-the-consumers"
];

(* Several pseudo-classes in one compound give one name and one condition. *)
TestCreate[
  With[{t = FromCSSSelector["div:has(p):empty"]},
    {MatchQ[t, Verbatim[Condition][Verbatim[Pattern][_Symbol, XMLPattern["div"]], _And]],
      Length[DeleteDuplicates[Cases[t, Verbatim[Pattern][s_Symbol, _] :> Hold[s], {0, Infinity}]]]}],
  {True, 1},
  TestID -> "css-one-name-one-condition"
];

(* === Selector lists === *)

TestCreate[
  {FromCSSSelector["a > b, a > c"], FromCSSSelector["div p, section p"], FromCSSSelector["h1, h2, .x"],
    FromCSSSelector["h1, h1"], FromCSSSelector["a b, a b, a c"], FromCSSSelector["[x='y'] > b, [x=\"y\"] > c"],
    MatchQ[FromCSSSelector["p:Empty a, p:empty a"], Descendant[Verbatim[Condition][_, _], XMLPattern["a"]]], FromCSSSelector["a[x='y'], a[x=\"y\"]"]},
  {Child[XMLPattern["a"], XMLPattern["b"] | XMLPattern["c"]],
    Descendant[XMLPattern["div"] | XMLPattern["section"], XMLPattern["p"]],
    XMLPattern["h1"] | XMLPattern["h2"] | XMLPattern[_, "classList" -> "x"], XMLPattern["h1"],
    Descendant[XMLPattern["a"], XMLPattern["b"] | XMLPattern["c"]],
    Child[XMLPattern[_, "x" -> "y"], XMLPattern["b"] | XMLPattern["c"]], True, XMLPattern["a", "x" -> "y"]},
  TestID -> "css-selector-list-exact"
];

TestCreate[
  {ids[$chain, "section > h2, section > p"], ids[$chain, "div > p, section > p"], ids[$chain, "#p3, #h, #sp"]},
  {{"h", "p1", "p2"}, {"p1", "p2", "p3"}, {"h", "sp", "p3"}},
  TestID -> "css-selector-list-selects"
];

(* Selectors of different shapes are the alternatives of their translations,
   in written order (ADR 0015). *)
TestCreate[
  {FromCSSSelector["a > b, c > d"], FromCSSSelector["a b, c > d, e"], FromCSSSelector["a > b, a > c > d, a > b"],
    FromCSSSelector["ul > li:only-child, ul > li"]},
  {Child[XMLPattern["a"], XMLPattern["b"]] | Child[XMLPattern["c"], XMLPattern["d"]],
    Descendant[XMLPattern["a"], XMLPattern["b"]] | Child[XMLPattern["c"], XMLPattern["d"]] | XMLPattern["e"],
    Child[XMLPattern["a"], XMLPattern["b"]] | Child[XMLPattern["a"], XMLPattern["c"], XMLPattern["d"]],
    Child[XMLPattern["ul"], {XMLPattern["li"]}] | Child[XMLPattern["ul"], XMLPattern["li"]]},
  TestID -> "css-selector-list-of-shapes-exact"
];

(* a > b, c > d must not match c > b; an element both select is given once. *)
$shapes = element["<div id='d'><a id='a'><b id='b1'></b></a><c id='c'><b id='b2'></b><d id='d1'></d></c><e id='e'><b id='b3'></b></e></div>"];

TestCreate[
  {ids[$shapes, "a > b, c > d"], ids[$shapes, "a > b, div b"], ids[$shapes, "div > a > b, c > d, e > b"]},
  {{"b1", "d1"}, {"b1", "b2", "b3"}, {"b1", "d1", "b3"}},
  TestID -> "css-selector-list-of-shapes-selects"
];

(* :is() with complex arguments, in the only compound of a selector, reads as
   a selector list there, with the rest of the compound merged into the last
   compound of each argument. *)
TestCreate[
  {FromCSSSelector[":is(a b, c > d)"], FromCSSSelector["b:is(a b)"], FromCSSSelector[".x:where(a b, c > d)"],
    FromCSSSelector["b:is(a b, .y)"], FromCSSSelector[":is(div p, section p)"]},
  {Descendant[XMLPattern["a"], XMLPattern["b"]] | Child[XMLPattern["c"], XMLPattern["d"]],
    Descendant[XMLPattern["a"], XMLPattern["b"]],
    Descendant[XMLPattern["a"], XMLPattern["b", "classList" -> "x"]] | Child[XMLPattern["c"], XMLPattern["d", "classList" -> "x"]],
    Descendant[XMLPattern["a"], XMLPattern["b"]] | XMLPattern["b", "classList" -> "y"],
    Descendant[XMLPattern["div"] | XMLPattern["section"], XMLPattern["p"]]},
  TestID -> "css-is-complex-exact"
];

TestCreate[
  {ids[$shapes, ":is(a b, c > d)"], ids[$shapes, "b:is(c b, e > *)"], ids[$shapes, ":where(a > b, c d)"]},
  {{"b1", "d1"}, {"b2", "b3"}, {"b1", "d1"}},
  TestID -> "css-is-complex-selects"
];

(* A selector list of n selectors of different shapes runs n chains, and a
   compound before :is() with a combinator inside is not translated: x
   :is(a b) is an element with ancestors x and a in either order. *)
TestCreate[
  {Length[FromCSSSelector["a > b, c d, e + f"]], kindOf["x :is(a b)"]},
  {3, "unsupported"},
  TestID -> "css-selector-list-possible-issues"
];

(* A string giving alternatives of combinators is refused where one element is
   tested, as a combinator is. *)
TestCreate[
  {XMLMatchQ[XMLElement["d", {}, {}], "a > b, c > d"], HTMLInnerText[XMLElement["d", {}, {}], "Roles" -> {"a > b, c" -> "Skip"}]},
  {$Failed, $Failed},
  {XMLMatchQ::combinator, HTMLInnerText::badpat},
  TestID -> "css-selector-list-of-shapes-refused-for-one-element"
];

(* === Names === *)

(* A translation's names are its own, so it can sit next to the user's. *)
TestCreate[
  {Lookup[XMLCases[$chain, Child["section:not([id=q])", e : XMLPattern["p"]] :> e][[All, 2]], "id"],
    Lookup[XMLCases[$chain, Child[FromCSSSelector["section:has(h2)"], e : XMLPattern["p"]] :> e][[All, 2]], "id"]},
  {{"p1", "p2"}, {"p1", "p2"}},
  TestID -> "css-names-splice-beside-the-users"
];

TestCreate[
  With[{t = FromCSSSelector["div:empty p:empty"]},
    Length[DeleteDuplicates[Cases[t, Verbatim[Pattern][s_Symbol, _] :> Hold[s], {0, Infinity}]]]],
  2,
  TestID -> "css-names-one-per-compound"
];

TestCreate[
  AllTrue[{"a", ".a.b", "[a|=v]", "a:not([href^='#'])", "a:is(.x, [y])", "div:has(a + b)", ":empty", ":checked",
      "ul > li:only-child", "li:only-of-type a", "[title=b i]", "[a~=b i][a~=c]", "div:has(> p:only-child)", ":not(a):not(b)"},
    privateFreeQ[FromCSSSelector[#]] &],
  True,
  TestID -> "css-output-holds-no-private-symbol"
];

(* === The grammar === *)

(* A selector that is not valid CSS gives ::invalid and $Failed. *)
invalidQ[sel_String] := Quiet[Check[FromCSSSelector[sel]; False, True, FromCSSSelector::invalid], FromCSSSelector::invalid];

(* The kind of refusal a selector gets, or None. *)
kindOf[sel_String] :=
  SelectFirst[{"invalid", "unsupported", "impossible"},
    Quiet[Check[FromCSSSelector[sel]; False, True, MessageName[FromCSSSelector, #]]] &,
    None];

TestCreate[
  {FromCSSSelector["#\\31 23"], FromCSSSelector[".a\\.b"], FromCSSSelector["#foo\\>a"], FromCSSSelector["\\64 iv"],
    FromCSSSelector[".a\\a0 b"], FromCSSSelector["#x\\"]},
  {XMLPattern[_, "id" -> "123"], XMLPattern[_, "classList" -> "a.b"], XMLPattern[_, "id" -> "foo>a"], XMLPattern["div"],
    XMLPattern[_, "classList" -> "a\[NonBreakingSpace]b"], XMLPattern[_, "id" -> "x\:fffd"]},
  TestID -> "css-grammar-escapes"
];

TestCreate[
  FromCSSSelector["a\\\nb"],
  $Failed,
  {FromCSSSelector::invalid},
  TestID -> "css-grammar-backslash-newline-outside-string"
];

TestCreate[
  {FromCSSSelector["[a=\"x\"]"], FromCSSSelector["[a='x']"], FromCSSSelector["[a='it\\'s']"], FromCSSSelector["[a=\"\\41 b\"]"],
    FromCSSSelector["[a=\"x\\\ny\"]"], FromCSSSelector["[a=\"x"], FromCSSSelector["[a='\"']"]},
  {XMLPattern[_, "a" -> "x"], XMLPattern[_, "a" -> "x"], XMLPattern[_, "a" -> "it's"], XMLPattern[_, "a" -> "Ab"],
    XMLPattern[_, "a" -> "xy"], XMLPattern[_, "a" -> "x"], XMLPattern[_, "a" -> "\""]},
  TestID -> "css-grammar-strings"
];

TestCreate[
  FromCSSSelector["[a=\"x\ny\"]"],
  $Failed,
  {FromCSSSelector::invalid},
  TestID -> "css-grammar-string-with-newline"
];

TestCreate[
  {FromCSSSelector["a[x=\"y"] === FromCSSSelector["a[x=\"y\"]"], FromCSSSelector["a:not(.b"] === FromCSSSelector["a:not(.b)"],
    FromCSSSelector["a[x"], FromCSSSelector["a:is(.b, .c"]},
  {True, True, XMLPattern["a", "x"], XMLPattern["a", "classList" -> "b"] | XMLPattern["a", "classList" -> "c"]},
  TestID -> "css-grammar-open-blocks-close-at-the-end"
];

TestCreate[
  invalidQ /@ {"[a=1]", "[href=#x]", "[a=x.y]", "[a=]", "[a=b c]", "[a i]", "[a=b x]", "[]", "[=b]", "[a^ =b]", "[a~ =b]"},
  ConstantArray[True, 11],
  TestID -> "css-grammar-attribute-values"
];

TestCreate[
  {FromCSSSelector["[a=-x]"], FromCSSSelector["[a=--]"], FromCSSSelector["[ href ^= \"x\" i ]"], FromCSSSelector["[a=\"b\"i]"]},
  {XMLPattern[_, "a" -> "-x"], XMLPattern[_, "a" -> "--"],
    XMLPattern[_, "href" -> _?(StringStartsQ[StringReplace[RegularExpression["[A-Z]"] :> ToLowerCase["$0"]][#], "x"] &)],
    XMLPattern[_, "a" -> _?(StringReplace[RegularExpression["[A-Z]"] :> ToLowerCase["$0"]][#] === "b" &)]},
  TestID -> "css-grammar-attribute-values-valid"
];

TestCreate[
  {invalidQ["a/**/b"], FromCSSSelector["a /**/ b"], FromCSSSelector["a/**/ b"], FromCSSSelector["/* x */a/**/.b/**/"],
    FromCSSSelector["a /* unclosed"]},
  {True, Descendant[XMLPattern["a"], XMLPattern["b"]], Descendant[XMLPattern["a"], XMLPattern["b"]],
    XMLPattern["a", "classList" -> "b"], XMLPattern["a"]},
  TestID -> "css-grammar-comments"
];

TestCreate[
  {Union[FromCSSSelector /@ {"div>p", "div > p", "div  >\n p", "div\t>p"}], FromCSSSelector["div .a"],
    FromCSSSelector["  a  "], FromCSSSelector["a ,b"], FromCSSSelector[":not( .a , .b )"] =!= $Failed, FromCSSSelector["a\n\tb"]},
  {{Child[XMLPattern["div"], XMLPattern["p"]]}, Descendant[XMLPattern["div"], XMLPattern[_, "classList" -> "a"]],
    XMLPattern["a"], XMLPattern["a"] | XMLPattern["b"], FromCSSSelector[":not(.a,.b)"] =!= $Failed,
    Descendant[XMLPattern["a"], XMLPattern["b"]]},
  TestID -> "css-grammar-whitespace"
];

TestCreate[
  invalidQ /@ {"a: hover", "a:not (b)", ":: before", "a > > b", "a + > b", "> a", "a >", "a ~", "div*", "[a]div",
    "", "   ", "a,", ",a", "a,,b", "a > , b"},
  ConstantArray[True, 16],
  TestID -> "css-grammar-whitespace-and-structure-invalid"
];

TestCreate[
  {FromCSSSelector[":NOT(.a)"], FromCSSSelector["p:Empty"] =!= $Failed, FromCSSSelector["[a=B I]"] === FromCSSSelector["[a=b i]"],
    FromCSSSelector["[a=b S]"], FromCSSSelector["DIV.Note"], FromCSSSelector["[DATA-X=Y]"], FromCSSSelector[":IS(A, b)"]},
  {XMLPattern[_, "classList" -> _?(FreeQ["a"])], True, True, XMLPattern[_, "a" -> "b"], XMLPattern["DIV", "classList" -> "Note"],
    XMLPattern[_, "DATA-X" -> "Y"], XMLPattern["A"] | XMLPattern["b"]},
  TestID -> "css-grammar-keywords-ignore-ascii-case-names-keep-it"
];

TestCreate[
  {FromCSSSelector[".caf\[EAcute]"], FromCSSSelector["\:65e5\:672c"], FromCSSSelector[".a\:00b7b"], invalidQ[".a\[NonBreakingSpace]b"],
    invalidQ[".a\:200bb"]},
  {XMLPattern[_, "classList" -> "caf\[EAcute]"], XMLPattern["\:65e5\:672c"], XMLPattern[_, "classList" -> "a\:00b7b"], True, True},
  TestID -> "css-grammar-non-ascii-identifiers"
];

TestCreate[
  {invalidQ["#1a"], invalidQ["#-1"], FromCSSSelector["#-x"], FromCSSSelector["#--"], FromCSSSelector["#a1"], invalidQ[".1a"], invalidQ["1a"]},
  {True, True, XMLPattern[_, "id" -> "-x"], XMLPattern[_, "id" -> "--"], XMLPattern[_, "id" -> "a1"], True, True},
  TestID -> "css-grammar-ids"
];

TestCreate[
  invalidQ /@ {"::before span", "::before.x", "p::before#x", ":not(::before)", "p:not(p::after)", ":has(::before)",
    "a::before > b", "::nonsense"},
  ConstantArray[True, 8],
  TestID -> "css-grammar-pseudo-elements-invalid"
];

TestCreate[
  kindOf /@ {"p::before", "p::BEFORE", "p:before", "::first-letter", "p::before:hover", "::highlight(x)",
    "::-webkit-scrollbar"},
  ConstantArray["impossible", 7],
  TestID -> "css-grammar-pseudo-elements-impossible"
];

TestCreate[
  invalidQ /@ {":foo", ":foo()", ":matches(a)", ":contains(x)", ":-soup-contains(x)", ":not()", ":has()", ":not(a,)",
    ":has(a, )", ":has(:has(a))", ":not", ":has", ":empty()", ":local-link", ":blank", ":nth-col(1)", ":target-within"},
  ConstantArray[True, 17],
  TestID -> "css-grammar-unknown-and-empty-pseudo-classes"
];

(* :is() and :where() are forgiving: an argument that is not valid is dropped. *)
TestCreate[
  {FromCSSSelector[":is(p, ::before)"], FromCSSSelector[":is(p, :foo, a > )"], FromCSSSelector[":where(:foo)"],
    FromCSSSelector[":is(, p,)"], FromCSSSelector[":is(:has(:has(a)), b)"]},
  {XMLPattern["p"], XMLPattern["p"], XMLPattern[_] /; False, XMLPattern["p"], XMLPattern["b"]},
  TestID -> "css-grammar-is-is-forgiving"
];

TestCreate[
  {ids[$kids, ":nth-child(2N+1)"], ids[$kids, ":nth-child( -n+ 2 )"], ids[$kids, ":nth-child(2n + 1)"],
    ids[$kids, ":nth-child(n- 1)"], ids[$kids, ":nth-child(+5)"], ids[$kids, ":nth-child(EVEN)"],
    invalidQ /@ {":nth-child(foo)", ":nth-child(2 n)", ":nth-child(+ 2n)", ":nth-child(2n-)", ":nth-child(1.5)",
      ":nth-child()", ":nth-child(2 of)", ":nth-of-type(2 of p)", ":nth-child(of p)", ":nth-child(2n+-1)", ":nth-child(2of p)"}},
  {{"p1", "p2", "b1", "i1"}, {"p1", "s1", "i1"}, {"p1", "p2", "b1", "i1"}, {"p1", "s1", "p2", "p3", "b1", "i1", "p4"},
    {"b1"}, {"s1", "p3", "p4"}, ConstantArray[True, 11]},
  TestID -> "css-child-indexed-an-plus-b-grammar"
];

(* === The messages === *)


TestCreate[
  kindOf /@ {"body :root", "p > :scope", "a:lang(fr)", ":dir(ltr)", ":enabled", ":disabled", ":required", ":defined",
    "svg|rect", "*|a", "|a", "[xlink|href]", "a || b", "x :is(a b)", "x > p:is(a b)", ":has(+ a)", ":has(~ a)",
    ":not(a b)", ":is(a b):is(c d)", ":not(:only-child)", ":is(li:only-child)", ":not(:nth-child(2))",
    ":where(:first-of-type)", ":nth-child(1 of a b)", ":nth-child(1 of :first-child)", "div:has(:is(a b))"},
  ConstantArray["unsupported", 26],
  TestID -> "css-messages-unsupported"
];

TestCreate[
  kindOf /@ {"a:visited", "a:active", "a:hover", "input:focus", ":focus-visible", ":focus-within",
    ":target", ":host", ":host(.x)", ":host-context(.x)", "video:playing", "dialog:modal", ":fullscreen",
    "input:autofill", ":user-invalid", "p::first-line", "p::first-letter", "p::before", "p::after", "::selection"},
  ConstantArray["impossible", 20],
  TestID -> "css-messages-impossible"
];

TestCreate[
  Quiet[FromCSSSelector[#]] & /@ {"p :root", "a:hover", ":foo"},
  {$Failed, $Failed, $Failed},
  TestID -> "css-messages-give-failed"
];

(* The whole string is parsed first, so a selector that is not valid is
   ::invalid even after a part that cannot be translated. *)
TestCreate[
  kindOf["p :root, a/**/b"],
  "invalid",
  TestID -> "css-messages-invalid-first"
];

TestCreate[
  {FromCSSSelector[1], FromCSSSelector[], FromCSSSelector["a", "b"]},
  {$Failed, $Failed, $Failed},
  {FromCSSSelector::string, FromCSSSelector::argx, FromCSSSelector::argx},
  TestID -> "css-messages-arguments"
];

(* === A CSS selector string where an XML pattern goes === *)

$note = ImportString["<div class='note' id='n1'><p id='q1'>a <span id='t1'>x</span></p><p id='q2'>b</p></div><div id='n2'><p id='q3'>c</p></div><h2 class='x' id='h'>H</h2>",
  {"HTML", "XMLObject"}];

TestCreate[
  {XMLCases[$note, "div.note > p"] === XMLCases[$note, Child[XMLPattern["div", "classList" -> "note"], XMLPattern["p"]]],
    Length[XMLCases[$note, "div.note > p"]],
    XMLCases[$note, "div.note > p" :> 1], XMLCases[$note, "p" -> 2],
    XMLFirstCase[$note, "div:not(.note) p"][[2]], Length[XMLCases[XMLDeleteCases[$note, "div.note"], "p"]],
    XMLMatchQ[XMLElement["p", {"class" -> "a b"}, {}], ".b"], XMLMatchQ[".b"][XMLElement["p", {"class" -> "a"}, {}]]},
  {True, 2, {1, 1}, {2, 2, 2}, {"id" -> "q3"}, 1, True, False},
  TestID -> "css-string-in-the-consumers"
];

(* A string stage that gives a combinator is spliced into the chain. *)
TestCreate[
  {XMLCases[$note, Child["div p", x : XMLPattern["span"]] :> x] ===
      XMLCases[$note, Child[Descendant[XMLPattern["div"], XMLPattern["p"]], x : XMLPattern["span"]] :> x],
    Lookup[XMLCases[$note, Child["div p", x : XMLPattern["span"]] :> x][[All, 2]], "id"],
    Lookup[XMLCases[$note, Descendant["div.note", "span"]][[All, 2]], "id"],
    Lookup[XMLCases[$note, Descendant["body", "div > p" /; True]][[All, 2]], "id"]},
  {True, {"t1"}, {"t1"}, {"q1", "q2", "q3"}},
  TestID -> "css-string-stage-splices"
];

TestCreate[
  {Lookup[XMLCases[$note, "h2.x" | "span"][[All, 2]], "id"], XMLMatchQ[XMLElement["h2", {"class" -> "x"}, {}], "h1" | "h2.x"]},
  {{"t1", "h"}, True},
  TestID -> "css-string-alternatives"
];

TestCreate[
  {XMLMatchQ[XMLElement["p", {}, {}], "div > p"], XMLMatchQ[XMLElement["li", {}, {}], "li:only-child"],
    XMLMatchQ[XMLElement["p", {}, {}], e : "div > p"]},
  {$Failed, $Failed, $Failed},
  {XMLMatchQ::combinator, XMLMatchQ::combinator, XMLMatchQ::badpat},
  TestID -> "css-string-combinator-refused-where-an-element-pattern-goes"
];

TestCreate[
  Lookup[XMLCases[$note, "h2" | "div > p"][[All, 2]], "id"],
  {"q1", "q2", "q3", "h"},
  TestID -> "css-string-combinator-in-alternatives"
];

TestCreate[
  {XMLCases[$note, "a > > b"], XMLMatchQ[XMLElement["p", {}, {}], ":hover"], HTMLInnerText[$note, "Roles" -> {"p :root" -> "Skip"}]},
  {$Failed, $Failed, $Failed},
  {FromCSSSelector::invalid, FromCSSSelector::impossible, FromCSSSelector::unsupported},
  TestID -> "css-string-refused-gives-only-the-translators-message"
];

(* In a Roles or Constructs rule, a string is CSS. *)
TestCreate[
  {HTMLInnerText[$note, "Roles" -> {"div.note" -> "Skip"}], HTMLInnerText[$note, "Roles" -> {"div" -> "Skip"}],
    HTMLInnerText[$note, "Roles" -> {"p:not(#q3)" :> "Skip"}]},
  {"c\nH", "H", "c\nH"},
  TestID -> "css-string-in-roles"
];

TestCreate[
  {HTMLInnerText[$note, "Roles" -> {"div > p" -> "Block"}], HTMLToNotebook[$note, "Constructs" -> {"div > p" -> "Bold"}]},
  {$Failed, $Failed},
  {HTMLInnerText::badpat, HTMLToNotebook::badpat},
  TestID -> "css-string-combinator-refused-in-roles-and-constructs"
];

TestCreate[
  Cases[HTMLToNotebook[$note, "Constructs" -> {"h2.x" -> "Section"}], Cell[_, "Section", ___], Infinity] =!= {},
  True,
  TestID -> "css-string-in-constructs"
];

(* The consumer's readings reach the nested queries of :not and :has. *)
$rel = ImportString["<a id='r1' rel='x y'>1</a><a id='r2' rel='y'>2</a><a id='r3'>3</a><div id='v1'><a rel='x'>4</a></div><div id='v2'></div>",
  {"HTML", "XMLObject"}];

TestCreate[
  {Lookup[XMLCases[$rel, "a:not([rel~=x])", "AttributeReadings" -> <|"rel" -> <||>|>][[All, 2]], "id"],
    Lookup[XMLCases[$rel, "div:has([rel~=x])", "AttributeReadings" -> <|"rel" -> <||>|>][[All, 2]], "id"],
    Block[{$AttributeReadings = Append[$AttributeReadings, "rel" -> <||>]},
      Lookup[XMLCases[$rel, "a[rel~=x]"][[All, 2]], "id", None]]},
  {{"r2", "r3"}, {"v1"}, {"r1", None}},
  TestID -> "css-string-readings-reach-nested-queries"
];


(* === :root and :scope (ADR 0018) ===
   The only top element under the document, with the rest of the compound
   merged into the list's one entry. *)

TestCreate[
  {FromCSSSelector["html:root"], FromCSSSelector[":scope > p"], FromCSSSelector[":root:first-child"],
   FromCSSSelector[":ROOT:only-of-type"], FromCSSSelector[":root:nth-child(2)"], FromCSSSelector[":root:nth-last-child(-n+3)"],
   FromCSSSelector[":root p"]},
  {Child[XMLDocument[], {XMLPattern["html"]}], Child[XMLDocument[], {XMLPattern[_]}, XMLPattern["p"]],
   Child[XMLDocument[], {XMLPattern[_]}], Child[XMLDocument[], {XMLPattern[_]}],
   Child[XMLDocument[], {Except[_], XMLPattern[_]}], Child[XMLDocument[], {XMLPattern[_]}],
   Child[XMLDocument[], Descendant[{XMLPattern[_]}, XMLPattern["p"]]]},
  TestID -> "css-root-exact"
];

$rootDoc = ImportString["<html><head><title>t</title></head><body><p>a</p></body></html>", {"HTML", "XMLObject"}];
tags[tree_, sel_] := First /@ XMLCases[tree, sel];

(* As soupsieve gives them. *)
TestCreate[
  {tags[$rootDoc, ":root"], tags[$rootDoc, ":root > body"], tags[$rootDoc, ":scope > *"],
   tags[$rootDoc, "html:root:first-child"], tags[$rootDoc, ":root:has(> body)"], tags[$rootDoc, "body:root"], tags[$rootDoc, "html:root, body"],
   tags[{XMLElement["p", {}, {"a"}], XMLElement["p", {}, {"b"}]}, ":root"],
   tags[{XMLElement["p", {}, {"a"}]}, ":root"]},
  {{"html"}, {"body"}, {"head", "body"}, {"html"}, {"html"}, {}, {"html", "body"}, {}, {"p"}},
  TestID -> "css-root-selects"
];

(* A bare element is the only top element, and never a result. *)
TestCreate[
  {tags[XMLElement["html", {}, {XMLElement["body", {}, {}]}], ":root"],
   tags[XMLElement["html", {}, {XMLElement["body", {}, {}]}], ":root > body"],
   tags[XMLElement["div", {}, {XMLElement["p", {}, {}], XMLElement["span", {}, {XMLElement["p", {}, {}]}]}], ":scope > p"]},
  {{}, {"body"}, {"p"}},
  TestID -> "css-root-on-bare-element"
];

(* ADR 0018's Possible Issues: top-level text does not stop :root, which
   soupsieve refuses; :scope > p on a list of several top elements gives
   nothing. *)
TestCreate[
  {tags[{"text", XMLElement["p", {}, {}]}, ":root"],
   tags[{XMLElement["p", {}, {}], XMLElement["p", {}, {}]}, ":scope > p"]},
  {{"p"}, {}},
  TestID -> "css-root-possible-issues"
];

TestCreate[
  kindOf /@ {"body :root", "p > :scope", ":root + p", ":root ~ p", "p ~ :scope", ":not(:root)", ":is(:root)",
    ":where(:scope)", ":has(:root)", "div:has(> :scope)", "p:nth-child(1 of :root)"},
  ConstantArray["unsupported", 11],
  TestID -> "css-root-refused"
];

TestCreate[
  {XMLCases[$rootDoc, Child[XMLPattern["html"], ":root"]], XMLCases[$rootDoc, Descendant[XMLPattern["html"], ":scope > p"]],
   XMLMatchQ[XMLElement["html", {}, {}], ":root"]},
  {$Failed, $Failed, $Failed},
  {XMLCases::badpat, XMLCases::badpat, XMLMatchQ::combinator},
  TestID -> "css-root-as-later-stage-refused"
];
