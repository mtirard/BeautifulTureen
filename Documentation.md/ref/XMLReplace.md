# XMLReplace

   ``XMLReplace[tree$, pattern$ :> new$]`` replaces each element that ``pattern$`` matches, at any depth, by ``new$``.
   ``XMLReplace[tree$, pattern$ :> {x$ -> new$, $$}]`` replaces, for every match of ``pattern$``, the part that each name ``x$`` is bound to by its ``new$``.
   ``XMLReplace[tree$, {rule$1, rule$2, $$}]`` tries the rules in order, and replaces each part by the first rule that matches it.

## Details and Options

With ``pattern$ :> new$``, each element that ``pattern$`` matches is replaced by ``new$``, unless ``new$`` is a list of rules for names in ``pattern$``.

With ``pattern$ :> {x$ -> new$, $$}``, only the parts bound to the names on the left of the rules are replaced. A name used only in ``new$`` must match, but adds no replacements.

``tree$`` can be an ``XMLObject``, an ``XMLElement``, or a list of elements and strings.

``pattern$`` can have any of the forms that ``XMLCases`` takes, such as an ``XMLPattern`` or a CSS selector string.

A **list key** is a key such as ``"classList"``, whose value is a list of tokens taken from an attribute.

A replacement must be of a kind that suits what the name is bound to:

| name for | replacement |
| :--- | :--- |
| an element | an element, a string, ``Splice[list$]``, or ``Nothing`` to remove it |
| a tag | a string |
| a run of element children, such as ``run___`` | ``Splice[list$]``, a list, or ``Nothing`` |
| a gap between children | the nodes to insert |
| the attribute list | a list of rules |
| an attribute value | a string, or ``Nothing`` to remove the attribute |
| the tokens of a list key | a list of strings |
| one token of a list key | a string |
| a run of tokens of a list key | a list of strings |
| the contents of an element | a list of nodes |

Matches are found in the original ``tree$``, and replacements are made from the inside out. A name for an element is bound to the element with the replacements inside it already made.

When ``tree$`` is an ``XMLElement``, it is never itself replaced.

The document, and a name on a ``Descendant`` constraint, as in ``path : Descendant[XMLPattern["a"]]``, cannot be replaced, and give a message.

``XMLReplace`` issues a message and returns ``$Failed`` when ``tree$`` or ``pattern$`` has none of the forms above, when the second argument is a pattern with no replacement, when an ``XMLPattern`` in ``pattern$`` is malformed, or when a name to be replaced has no position, such as a name for text.

The following option can be given:

| option | default | description |
| :--- | :--- | :--- |
| ``"AttributeReadings"`` | ``<\|\|>`` | attributes to split into lists of tokens for this call, in addition to ``$AttributeReadings`` |

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Replace each ``b`` element by a ``strong`` element with the same contents:

```wl
In[1]:= tree = ImportString["<p>Some <b>bold</b> and <b>more</b> text.</p>", {"HTML", "XMLObject"}];
XMLCases[XMLReplace[tree, x : XMLPattern["b"] :> XMLElement["strong", {}, x[[3]]]], XMLPattern["p"]]

Out[1]= {XMLElement["p", {}, {"Some ", XMLElement["strong", {}, {"bold"}], " and ", XMLElement["strong", {}, {"more"}], " text."}]}
```

---

Name the parts to replace, and give their replacements as rules:

```wl
In[1]:= page = {XMLElement["div", {"class" -> "note"}, {XMLElement["p", {}, {"x"}], XMLElement["span", {}, {"y"}]}]};
XMLReplace[page, XMLPattern["div", "class" -> c_][Child[p : XMLPattern["p"]]] :> {p -> XMLElement["p", {"class" -> c}, p[[3]]]}]

Out[1]= {XMLElement["div", {"class" -> "note"}, {XMLElement["p", {"class" -> "note"}, {"x"}], XMLElement["span", {}, {"y"}]}]}
```

### Scope

---

Replace an attribute value:

```wl
In[1]:= links = {XMLElement["a", {"href" -> "http://example.com"}, {"x"}]};
XMLReplace[links, XMLPattern["a", "href" -> h_] :> {h -> StringReplace[h, "http:" -> "https:"]}]

Out[1]= {XMLElement["a", {"href" -> "https://example.com"}, {"x"}]}
```

Remove an attribute with ``Nothing``:

```wl
In[2]:= XMLReplace[links, XMLPattern["a", "href" -> h_] :> {h -> Nothing}]

Out[2]= {XMLElement["a", {}, {"x"}]}
```

---

Rename the tag of each element:

```wl
In[1]:= XMLReplace[{XMLElement["div", {}, {XMLElement["b", {}, {"x"}]}]}, XMLPattern[t : "b"] :> {t -> "strong"}]

Out[1]= {XMLElement["div", {}, {XMLElement["strong", {}, {"x"}]}]}
```

---

Replace a class token, keeping the others:

```wl
In[1]:= XMLReplace[{XMLElement["p", {"class" -> "lead old"}, {}]}, XMLPattern["p", "classList" -> {___, c : "old", ___}] :> {c -> "new"}]

Out[1]= {XMLElement["p", {"class" -> "lead new"}, {}]}
```

---

Replace the contents of an element:

```wl
In[1]:= XMLReplace[{XMLElement["pre", {}, {"long code"}]}, XMLElement["pre", _, c_] :> {c -> {"(code)"}}]

Out[1]= {XMLElement["pre", {}, {"(code)"}]}
```

---

Insert an element into an empty ``ul`` by naming the gap after its children:

```wl
In[1]:= XMLReplace[{XMLElement["ul", {}, {}]}, XMLPattern["ul"][{___, g : PatternSequence[]}] :> {g -> XMLElement["li", {}, {"new"}]}]

Out[1]= {XMLElement["ul", {}, {XMLElement["li", {}, {"new"}]}]}
```

Insert an element into the gap after the first child:

```wl
In[2]:= XMLReplace[{XMLElement["ul", {}, {XMLElement["li", {}, {"a"}], XMLElement["li", {}, {"c"}]}]}, XMLPattern["ul"][{_, g : PatternSequence[], ___}] :> {g -> XMLElement["li", {}, {"b"}]}]

Out[2]= {XMLElement["ul", {}, {XMLElement["li", {}, {"a"}], XMLElement["li", {}, {"b"}], XMLElement["li", {}, {"c"}]}]}
```

---

Replace an element by several with ``Splice``:

```wl
In[1]:= XMLReplace[{XMLElement["div", {}, {XMLElement["br", {}, {}]}]}, x : XMLPattern["br"] :> Splice[{"line one", XMLElement["br", {}, {}], "line two"}]]

Out[1]= {XMLElement["div", {}, {"line one", XMLElement["br", {}, {}], "line two"}]}
```

---

Replace a run of children:

```wl
In[1]:= section = {XMLElement["section", {}, {XMLElement["h2", {}, {"A"}], XMLElement["p", {}, {"a1"}], XMLElement["p", {}, {"a2"}]}]};
XMLReplace[section, XMLPattern["section"][{XMLPattern["h2"], run__}] :> {run -> {XMLElement["p", {}, {"summary"}]}}]

Out[1]= {XMLElement["section", {}, {XMLElement["h2", {}, {"A"}], XMLElement["p", {}, {"summary"}]}]}
```

---

Unwrap each ``span``, replacing it by its contents:

```wl
In[1]:= tree = {XMLElement["p", {}, {"a ", XMLElement["span", {}, {"b"}], " c"}]};
XMLReplace[tree, x : XMLPattern["span"] :> Splice[x[[3]]]]

Out[1]= {XMLElement["p", {}, {"a ", "b", " c"}]}
```

---

Replace nested elements in one call, the inner one first:

```wl
In[1]:= XMLReplace[{XMLElement["p", {}, {XMLElement["i", {}, {XMLElement["b", {}, {"x"}]}]}]}, x : XMLPattern["i" | "b"] :> {x -> ReplacePart[x, 1 -> (x[[1]] /. {"i" -> "em", "b" -> "strong"})]}]

Out[1]= {XMLElement["p", {}, {XMLElement["em", {}, {XMLElement["strong", {}, {"x"}]}]}]}
```

---

Give several rules, and replace each element by the first rule that matches it:

```wl
In[1]:= links = {XMLElement["p", {}, {XMLElement["a", {"id" -> "1"}, {}], XMLElement["a", {"id" -> "2"}, {}]}]};
XMLReplace[links, {XMLPattern["a", "id" -> "2"] :> "two", XMLPattern["a"] :> "other"}]

Out[1]= {XMLElement["p", {}, {"other", "two"}]}
```

---

Name the element that a CSS selector string matches, and replace it:

```wl
In[1]:= page = ImportString["<body><nav><a href=\"/\">Home</a></nav><a href=\"/about\">About</a></body>", {"HTML", "XMLObject"}];
HTMLTextContent[XMLReplace[page, n : "nav a" :> {n -> "(link)"}]]

Out[1]= "(link)About"
```

### Options

#### AttributeReadings

---

Split ``rel`` into tokens, and replace one of them:

```wl
In[1]:= links = {XMLElement["a", {"rel" -> "nofollow noopener"}, {}]};
XMLReplace[links, XMLPattern["a", "relList" -> {___, r : "nofollow", ___}] :> {r -> "ugc"}, "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= {XMLElement["a", {"rel" -> "ugc noopener"}, {}]}
```

### Applications

---

Make every relative link absolute:

```wl
In[1]:= page = ImportString["<p><a href=\"/about\">About</a> <a href=\"https://w3.org\">W3C</a></p>", {"HTML", "XMLObject"}];
XMLCases[XMLReplace[page, XMLPattern["a", "href" -> h_?(StringStartsQ["/"])] :> {h -> "https://example.com" <> h}], XMLPattern["a", "href" -> h_] :> h]

Out[1]= {"https://example.com/about", "https://w3.org"}
```

---

Number the items of each list, keeping their attributes:

```wl
In[1]:= lists = {XMLElement["ol", {}, {XMLElement["li", {"class" -> "special"}, {"Miso"}], XMLElement["li", {}, {"Pho"}]}]};
XMLReplace[lists, XMLPattern["ol"][{before___, XMLElement["li", _, c_], ___}] :> {c -> Prepend[c, ToString[Length[{before}] + 1] <> ". "]}]

Out[1]= {XMLElement["ol", {}, {XMLElement["li", {"class" -> "special"}, {"1. ", "Miso"}], XMLElement["li", {}, {"2. ", "Pho"}]}]}
```

### Properties & Relations

---

Replace an element by ``Nothing`` to remove it, as ``XMLDeleteCases`` does:

```wl
In[1]:= page = ImportString["<div><p>a</p><b>b</b></div>", {"HTML", "XMLObject"}];
XMLReplace[page, XMLPattern["p"] :> Nothing] === XMLDeleteCases[page, XMLPattern["p"]]

Out[1]= True
```

---

Replace the parts at the positions that ``XMLPosition`` gives for the same names:

```wl
In[1]:= links = {XMLElement["p", {}, {XMLElement["a", {"href" -> "/a"}, {}], XMLElement["a", {"href" -> "/b"}, {}]}]};
{XMLPosition[links, XMLPattern["a", "href" -> h_] :> h], XMLReplace[links, XMLPattern["a", "href" -> h_] :> {h -> "#"}]}

Out[1]= {{{1, 1, Key["href"]}, {1, 2, Key["href"]}}, {XMLElement["p", {}, {XMLElement["a", {"href" -> "#"}, {}], XMLElement["a", {"href" -> "#"}, {}]}]}}
```

### Possible Issues

---

A pattern with no replacement gives a message:

```wl
In[1]:= XMLReplace[{XMLElement["a", {}, {}]}, XMLPattern["a"]]

During evaluation of In[1]:= XMLReplace::bare: XMLPattern["a"] is a pattern with no replacement, which would replace each match by itself. Name what to replace and give its replacement, as in x : p :> {x -> new}, or replace the match itself, as in p :> new.

Out[1]= $Failed
```

---

A replacement of the wrong kind leaves its part unchanged:

```wl
In[1]:= XMLReplace[{XMLElement["a", {"href" -> "/x"}, {}]}, XMLPattern["a", "href" -> h_] :> {h -> 5}]

During evaluation of In[1]:= XMLReplace::kind: The replacement 5 for position {1, Key["href"]} is not of a kind that position takes, and the position is left unchanged. An element takes an element, a string, Splice[list] or Nothing; a tag a string; an attribute list a list of rules; an attribute value a string or Nothing; a list key a list of strings; a token a string, and a run of tokens a list of strings; contents a list of nodes; a run of children Splice[list], a list or Nothing; a gap the nodes to insert.

Out[1]= {XMLElement["a", {"href" -> "/x"}, {}]}
```

Give a string for an attribute value:

```wl
In[2]:= XMLReplace[{XMLElement["a", {"href" -> "/x"}, {}]}, XMLPattern["a", "href" -> h_] :> {h -> "5"}]

Out[2]= {XMLElement["a", {"href" -> "5"}, {}]}
```

---

When two matches give one part different replacements, the first match is used:

```wl
In[1]:= XMLReplace[{XMLElement["ul", {}, {XMLElement["li", {}, {}], XMLElement["li", {}, {}], XMLElement["li", {}, {}]}]}, XMLPattern["ul"][{___, x : XMLPattern["li"], ___, y : XMLPattern["li"], ___}] :> {x -> "first", y -> "second"}]

During evaluation of In[1]:= XMLReplace::conflict: Position {1, 2} is given different replacements by different results; the replacement of the first result is used.

Out[1]= {XMLElement["ul", {}, {"first", "second", "second"}]}
```

---

A name whose part an earlier replacement removed keeps its original value:

```wl
In[1]:= XMLReplace[{XMLElement["div", {}, {XMLElement["p", {"id" -> "1"}, {}], XMLElement["p", {"id" -> "2"}, {}]}]}, XMLPattern["div"][{x : XMLPattern["p"], y : XMLPattern["p"]}] :> {x -> y, y -> Nothing}]

During evaluation of In[1]:= XMLReplace::stale: The position {1, 2} of y was removed by an earlier replacement, so y has its original value.

Out[1]= {XMLElement["div", {}, {XMLElement["p", {"id" -> "2"}, {}]}]}
```

---

A rule whose right-hand side is not a list of rules for names replaces the whole match:

```wl
In[1]:= links = {XMLElement["a", {"href" -> "/x"}, {"x"}]};
{XMLReplace[links, XMLPattern["a", "href" -> h_] :> h], XMLReplace[links, XMLPattern["a", "href" -> h_] :> {h -> h}]}

Out[1]= {{"/x"}, {XMLElement["a", {"href" -> "/x"}, {"x"}]}}
```

---

With ``ReplaceAll``, an ``XMLPattern`` is a literal expression, so nothing is replaced:

```wl
In[1]:= tree = {XMLElement["b", {}, {"x"}]};
{tree /. XMLPattern["b"] -> "y", XMLReplace[tree, XMLPattern["b"] :> "y"]}

Out[1]= {{XMLElement["b", {}, {"x"}]}, {"y"}}
```

---

A list pattern leaves out text, so a name in it is bound to element children only:

```wl
In[1]:= XMLReplace[{XMLElement["li", {}, {"Miso"}]}, XMLPattern["li"][{c___}] :> {c -> "1. "}]

Out[1]= {XMLElement["li", {}, {"Miso", "1. "}]}
```

Name the contents with an ``XMLElement`` pattern to include the text:

```wl
In[2]:= XMLReplace[{XMLElement["li", {}, {"Miso"}]}, XMLElement["li", _, c_] :> {c -> Prepend[c, "1. "]}]

Out[2]= {XMLElement["li", {}, {"1. ", "Miso"}]}
```

## See Also

* [XMLDeleteCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDeleteCases)

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [XMLFirstCase](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFirstCase)

* [XMLPosition](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPosition)

* [XMLExtract](paclet:MaximilienTirard/HTMLPatterns/ref/XMLExtract)

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [Replace](paclet:ref/Replace)

* [ReplaceAll](paclet:ref/ReplaceAll)

* [ReplacePart](paclet:ref/ReplacePart)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
