# XMLPosition

   ``XMLPosition[tree$, pattern$]`` gives the positions in ``tree$`` of the elements that ``pattern$`` matches.
   ``XMLPosition[tree$, pattern$ :> rhs$]`` gives ``rhs$`` for each result of ``XMLCases[tree$, pattern$ :> rhs$]``, with each name it uses replaced by its position.

## Details and Options

A position is a list of indices among element children, starting at the document. Text is not counted, so whitespace between elements does not change the indices.

The position of the document is ``{}``. The root element of an ``XMLObject``, and an ``XMLElement`` given as the tree, are at ``{1}``. The ``i$``-th element of a list is at ``{i$}``.

``XMLPosition[tree$, pattern$]`` gives the positions of the elements that ``pattern$`` matches, in document order. When nothing matches, it gives ``{}``, which ``XMLExtract`` reads as the position of the document.

``XMLPosition[tree$, pattern$ :> rhs$]`` gives one result for each result of ``XMLCases[tree$, pattern$ :> rhs$]``, in the same order, with each name that ``rhs$`` uses replaced by its position. Give ``rhs$`` as a name, or a list of names, to get the positions themselves.

``tree$`` and ``pattern$`` can have the same forms as in ``XMLCases``.

A position for an element is a list of indices ``{i$1, i$2, $$}``. A name bound to another part of the tree gives a position that ends in one of the following:

| end | part |
| :--- | :--- |
| ``0`` | the tag |
| ``Key[All]`` | the attribute list |
| ``Key["key$"]`` | the value of an attribute, or of a list key such as ``"classList"``, whose value is a list of tokens taken from an attribute |
| ``Key["key$"], i$`` | the ``i$``-th token of a list key |
| ``All`` | the contents, text included |
| ``m$;;n$`` | the run of element children ``m$`` to ``n$`` |
| ``n$;;n$-1`` | the gap before element child ``n$`` |

A name on a ``Descendant`` constraint, as in ``path:Descendant[p$]``, gives ``upper$;;lower$``, the positions of its two ends. Its value is the elements strictly between them.

A name used twice whose two values must be equal, such as a name used twice in one list, gives a list of its two positions. A name inside the attribute list of an ``XMLElement`` pattern, as ``h`` in ``XMLElement["a", {"href" -> h_}, _]``, gives ``Missing["Literal"]``, as two attributes can have its value.

``XMLPosition`` issues a message and returns ``$Failed`` when ``tree$`` or ``pattern$`` has none of the forms that ``XMLCases`` accepts, when an ``XMLPattern`` in ``pattern$`` is malformed, or when a name that ``rhs$`` uses has no position, such as a name for text.

The following option can be given:

| option | default | description |
| :--- | :--- | :--- |
| ``"AttributeReadings"`` | ``<\|\|>`` | attributes to split into lists of tokens for this call, in addition to ``$AttributeReadings`` |

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Give the positions of the links in a paragraph:

```wl
In[1]:= links = ImportString["<p><a href=\"/a\">A</a> and <a href=\"/b\">B</a></p>", {"HTML", "XMLObject"}];
XMLPosition[links, XMLPattern["a"]]

Out[1]= {{1, 1, 1, 1}, {1, 1, 1, 2}}
```

Give the parts at those positions with ``XMLExtract``:

```wl
In[2]:= XMLExtract[links, XMLPosition[links, XMLPattern["a"]]]

Out[2]= {XMLElement["a", {"shape" -> "rect", "href" -> "/a"}, {"A"}], XMLElement["a", {"shape" -> "rect", "href" -> "/b"}, {"B"}]}
```

---

Give the position of each nav and of each link inside it:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav></nav>", {"HTML", "XMLObject"}];
XMLPosition[navs, n : XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> {n, x}]

Out[1]= {{{1}, {1, 1}}, {{1}, {1, 2, 1}}, {{1, 2}, {1, 2, 1}}}
```

### Scope

---

Give the position of an attribute value:

```wl
In[1]:= links = ImportString["<p><a href=\"/a\">A</a> and <a href=\"/b\">B</a></p>", {"HTML", "XMLObject"}];
XMLPosition[links, XMLPattern["a", "href" -> h_] :> h]

Out[1]= {{1, 1, 1, 1, Key["href"]}, {1, 1, 1, 2, Key["href"]}}
```

---

Give the position of each class token, including equal tokens:

```wl
In[1]:= para = XMLElement["p", {"class" -> "lead note lead"}, {}];
XMLPosition[{para}, XMLPattern["p", "classList" -> {___, c : "lead", ___}] :> c]

Out[1]= {{1, Key["classList"], 1}, {1, Key["classList"], 3}}
```

---

Give the positions of a tag and of an attribute list:

```wl
In[1]:= link = XMLElement["div", {}, {XMLElement["a", {"href" -> "/x"}, {"x"}]}];
XMLPosition[{link}, XMLPattern[t : "a", attrs_] :> {t, attrs}]

Out[1]= {{{1, 1, 0}, {1, 1, Key[All]}}}
```

---

Give the position of the contents of an element, with a name in an ``XMLElement`` pattern:

```wl
In[1]:= XMLPosition[{XMLElement["p", {}, {"Some ", XMLElement["b", {}, {"bold"}], " text"}]}, XMLElement["p", _, c_] :> c]

Out[1]= {{1, All}}
```

---

Give the position of a run of children, and of the gap between two children:

```wl
In[1]:= paras = XMLElement["div", {}, {XMLElement["p", {}, {"1"}], XMLElement["p", {}, {"2"}], XMLElement["p", {}, {"3"}]}];
XMLPosition[{paras}, XMLPattern["div"][{___, XMLPattern["p"], g___, XMLPattern["p"], ___}] :> g]

Out[1]= {{1, 2 ;; 1}, {1, 2 ;; 2}, {1, 3 ;; 2}}
```

---

Give the positions of the two ends of a name on a ``Descendant`` constraint:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav></nav>", {"HTML", "XMLObject"}];
XMLPosition[navs, XMLPattern["nav"][path : Descendant[XMLPattern["a"]]] :> path]

Out[1]= {{1} ;; {1, 1}, {1} ;; {1, 2, 1}, {1, 2} ;; {1, 2, 1}}
```

---

Give the position of the document itself:

```wl
In[1]:= XMLPosition[{XMLElement["p", {}, {}]}, d : XMLDocument[{XMLPattern["p"]}] :> d]

Out[1]= {{}}
```

---

Give positions in an ``XMLElement`` given as the tree, which is at ``{1}``:

```wl
In[1]:= XMLPosition[XMLElement["ul", {}, {XMLElement["li", {}, {"a"}], XMLElement["li", {}, {"b"}]}], XMLPattern["li"]]

Out[1]= {{1, 1}, {1, 2}}
```

Give positions in a list of elements, which are at ``{1}``, ``{2}``, etc.:

```wl
In[2]:= XMLPosition[{XMLElement["li", {}, {"a"}], XMLElement["li", {}, {XMLElement["a", {}, {"b"}]}]}, XMLPattern["li" | "a"]]

Out[2]= {{1}, {2}, {2, 1}}
```

---

Give a CSS selector string as the pattern:

```wl
In[1]:= page = ImportString["<body><nav><a href=\"/\">Home</a></nav><a href=\"/about\">About</a></body>", {"HTML", "XMLObject"}];
XMLPosition[page, "nav a"]

Out[1]= {{1, 1, 1, 1}}
```

---

Use a name twice in one list to require equal values, and get both its positions:

```wl
In[1]:= rows = XMLElement["tbody", {}, {XMLElement["tr", {}, {"a"}], XMLElement["tr", {}, {"b"}], XMLElement["tr", {}, {"a"}]}];
XMLPosition[{rows}, XMLPattern["tbody"][{___, x : XMLPattern["tr"], ___, x : XMLPattern["tr"], ___}] :> x]

Out[1]= {{{1, 1}, {1, 3}}}
```

### Options

#### AttributeReadings

---

Split rel into tokens, and give the position of one of them:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow noopener\" href=\"/x\">x</a></p>", {"HTML", "XMLObject"}];
XMLPosition[links, XMLPattern["a", "relList" -> {___, r : "noopener", ___}] :> r, "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= {{1, 1, 1, 1, Key["relList"], 2}}
```

### Applications

---

Find where each link of a page is, and read the link text back at those positions:

```wl
In[1]:= tree = ImportString["<ul><li><a href=\"/miso\">Miso</a></li><li><a href=\"/pho\">Pho</a></li></ul>", {"HTML", "XMLObject"}];
positions = XMLPosition[tree, XMLPattern["a"]];
Thread[positions -> HTMLTextContent /@ XMLExtract[tree, positions]]

Out[1]= {{1, 1, 1, 1, 1} -> "Miso", {1, 1, 1, 2, 1} -> "Pho"}
```

### Properties & Relations

---

For a bare pattern, ``XMLExtract`` at the positions gives what ``XMLCases`` gives:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav></nav>", {"HTML", "XMLObject"}];
XMLExtract[navs, XMLPosition[navs, XMLPattern["nav"][Descendant[XMLPattern["a"]]]]] === XMLCases[navs, XMLPattern["nav"][Descendant[XMLPattern["a"]]]]

Out[1]= True
```

---

With a rule, ``XMLExtract`` at each position gives the value that ``XMLCases`` gives:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav></nav>", {"HTML", "XMLObject"}];
query = XMLPattern["nav"][path : Descendant[XMLPattern["a"]]] :> path;
Map[XMLExtract[navs, #] &, XMLPosition[navs, query]] === XMLCases[navs, query]

Out[1]= True
```

---

``Position`` counts every part of the tree, and ``XMLPosition`` only element children:

```wl
In[1]:= tree = ImportString["<div><p>a</p>\n<p>b</p></div>", {"HTML", "XMLObject"}];
{Position[tree, XMLElement["p", __]], XMLPosition[tree, XMLPattern["p"]]}

Out[1]= {{{2, 3, 1, 3, 1, 3, 1}, {2, 3, 1, 3, 1, 3, 3}}, {{1, 1, 1, 1}, {1, 1, 1, 2}}}
```

### Possible Issues

---

``Position`` gives one position for each match:

```wl
In[1]:= Position[{a, a}, a]

Out[1]= {{1}, {2}}
```

``XMLPosition`` gives at most one result for a rule that uses no name:

```wl
In[2]:= links = ImportString["<p><a href=\"/a\">A</a><a href=\"/b\">B</a></p>", {"HTML", "XMLObject"}];
XMLPosition[links, x : XMLPattern["a"] :> 1]

Out[2]= {1}
```

Use the name to get the position of each link:

```wl
In[3]:= XMLPosition[links, x : XMLPattern["a"] :> x]

Out[3]= {{1, 1, 1, 1}, {1, 1, 1, 2}}
```

A bare pattern also gives the position of each link:

```wl
In[4]:= XMLPosition[links, XMLPattern["a"]]

Out[4]= {{1, 1, 1, 1}, {1, 1, 1, 2}}
```

---

A name inside an expression on the right-hand side is replaced by its position, not by the element:

```wl
In[1]:= links = ImportString["<p><a href=\"/a\">A</a><a href=\"/b\">B</a></p>", {"HTML", "XMLObject"}];
XMLPosition[links, x : XMLPattern["a"] :> Length[x]]

Out[1]= {4, 4}
```

---

With no match, ``XMLPosition`` gives ``{}``, which ``XMLExtract`` reads as the document:

```wl
In[1]:= links = ImportString["<p><a href=\"/a\">A</a></p>", {"HTML", "XMLObject"}];
XMLExtract[links, XMLPosition[links, XMLPattern["table"]]] === links

Out[1]= True
```

Check for no match before extracting:

```wl
In[2]:= With[{positions = XMLPosition[links, XMLPattern["table"]]}, If[positions === {}, {}, XMLExtract[links, positions]]]

Out[2]= {}
```

---

``Extract`` counts text and the parts of an ``XMLObject``, so it gives another part:

```wl
In[1]:= links = ImportString["<p><a href=\"/a\">A</a></p>", {"HTML", "XMLObject"}];
Extract[links, First@XMLPosition[links, XMLPattern["a"]]]

Out[1]= "Version"
```

Use ``XMLExtract``:

```wl
In[2]:= XMLExtract[links, First@XMLPosition[links, XMLPattern["a"]]]

Out[2]= XMLElement["a", {"shape" -> "rect", "href" -> "/a"}, {"A"}]
```

## See Also

* [XMLExtract](paclet:MaximilienTirard/HTMLPatterns/ref/XMLExtract)

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [XMLDeleteCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDeleteCases)

* [XMLReplace](paclet:MaximilienTirard/HTMLPatterns/ref/XMLReplace)

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [Descendant](paclet:MaximilienTirard/HTMLPatterns/ref/Descendant)

* [Child](paclet:MaximilienTirard/HTMLPatterns/ref/Child)

* [XMLDocument](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDocument)

* [Position](paclet:ref/Position)

* [Extract](paclet:ref/Extract)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
