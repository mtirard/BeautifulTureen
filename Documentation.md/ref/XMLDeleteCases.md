# XMLDeleteCases

   ``XMLDeleteCases[tree$, pattern$]`` gives ``tree$`` with every element that matches ``pattern$`` removed, at any depth.
   ``XMLDeleteCases[tree$, pattern$ :> x$]`` removes, for every match of ``pattern$``, the part that its name ``x$`` is bound to.
   ``XMLDeleteCases[tree$, pattern$ :> {x$, y$, $$}]`` removes the parts that each of the names is bound to.

## Details and Options

``XMLDeleteCases[tree$, pattern$]`` removes each element that ``pattern$`` matches, at any depth, together with its contents. Text and whitespace between the remaining elements are kept.

``tree$`` can be an ``XMLObject``, an ``XMLElement``, or a list of elements and strings.

``pattern$`` can have any of the forms that ``XMLCases`` takes, such as an ``XMLPattern`` or a CSS selector string.

The right-hand side must be a name in ``pattern$`` or a list of names, and can have a ``Condition``. Use ``:>`` so that the names are not evaluated.

A **list key** is a key such as ``"classList"``, whose value is a list of tokens taken from an attribute.

What is removed depends on what the name is bound to:

| name for | removes |
| :--- | :--- |
| an element | the element and its contents |
| a run of element children, such as ``run___`` | the elements of the run; the text between them is kept |
| a gap between children | nothing |
| the attribute list | every attribute |
| an attribute value | the attribute |
| the tokens of a list key | the whole attribute |
| one token of a list key | the token; the attribute is kept, even when empty |
| a run of tokens of a list key | the tokens |
| the contents of an element | all its contents, text included |

A name for a tag, for the document, or on a ``Descendant`` constraint, as in ``path : Descendant[XMLPattern["a"]]``, cannot be deleted, and gives a message.

Every match is found in the original ``tree$`` before anything is removed, so removing an element does not change whether its parent or an earlier sibling matches.

``tree$`` itself, and the root element of an ``XMLObject``, are never removed.

``XMLDeleteCases`` issues a message and returns ``$Failed`` when ``tree$`` or ``pattern$`` has none of the forms above, when an ``XMLPattern`` in ``pattern$`` is malformed, or when a name on the right-hand side has no position, such as a name for text.

The following option can be given:

| option | default | description |
| :--- | :--- | :--- |
| ``"AttributeReadings"`` | ``<\|\|>`` | attributes to split into lists of tokens for this call, in addition to ``$AttributeReadings`` |

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Remove every ``script`` element and its contents:

```wl
In[1]:= XMLDeleteCases[ImportString["<html><body><p>Visible</p><script>alert(1)</script></body></html>", {"HTML", "XMLObject"}], XMLPattern["script"]]

Out[1]= XMLObject["Document"][{XMLObject["Declaration"]["Version" -> "1.0", "Standalone" -> "yes"]}, XMLElement["html", {{"http://www.w3.org/2000/xmlns/", "xmlns"} -> "http://www.w3.org/1999/xhtml"}, {XMLElement["body", {}, {XMLElement["p", {}, {"Visible"}]}]}], {}]
```

---

Remove several kinds of element at once:

```wl
In[1]:= XMLDeleteCases[ImportString["<html><body><nav>Menu</nav><main><p>Body</p></main><footer>End</footer></body></html>", {"HTML", "XMLObject"}], XMLPattern["nav" | "footer"]]

Out[1]= XMLObject["Document"][{XMLObject["Declaration"]["Version" -> "1.0", "Standalone" -> "yes"]}, XMLElement["html", {{"http://www.w3.org/2000/xmlns/", "xmlns"} -> "http://www.w3.org/1999/xhtml"}, {XMLElement["body", {}, {XMLElement["main", {}, {XMLElement["p", {}, {"Body"}]}]}]}], {}]
```

---

Name a part of the pattern to remove only that part, here the first item of each list:

```wl
In[1]:= lists = ImportString["<ul><li>Miso</li><li>Pho</li></ul><ol><li>Rice</li><li>Bread</li></ol>", {"HTML", "XMLObject"}];
HTMLTextContent /@ XMLCases[XMLDeleteCases[lists, XMLPattern[_][{x : XMLPattern["li"], ___}] :> x], XMLPattern["li"]]

Out[1]= {"Pho", "Bread"}
```

### Scope

---

Remove the elements that have the class ad:

```wl
In[1]:= body = XMLElement["body", {}, {XMLElement["p", {"class" -> "ad wide"}, {"Buy now"}], XMLElement["p", {}, {"Story"}]}];
XMLDeleteCases[body, XMLPattern["p", "classList" -> "ad"]]

Out[1]= XMLElement["body", {}, {XMLElement["p", {}, {"Story"}]}]
```

---

Remove the paragraphs that are children of the main ``div``:

```wl
In[1]:= page = ImportString["<div class=\"main\"><p>direct</p><section><p>nested</p></section></div>", {"HTML", "XMLObject"}];
XMLDeleteCases[page, XMLPattern["div", "classList" -> "main"][Child[x : XMLPattern["p"]]] :> x]

Out[1]= XMLObject["Document"][{XMLObject["Declaration"]["Version" -> "1.0", "Standalone" -> "yes"]}, XMLElement["html", {{"http://www.w3.org/2000/xmlns/", "xmlns"} -> "http://www.w3.org/1999/xhtml"}, {XMLElement["body", {}, {XMLElement["div", {"class" -> "main"}, {XMLElement["section", {}, {XMLElement["p", {}, {"nested"}]}]}]}]}], {}]
```

Remove the paragraphs at any depth inside a ``div``:

```wl
In[2]:= XMLDeleteCases[page, XMLPattern["div"][Descendant[x : XMLPattern["p"]]] :> x]

Out[2]= XMLObject["Document"][{XMLObject["Declaration"]["Version" -> "1.0", "Standalone" -> "yes"]}, XMLElement["html", {{"http://www.w3.org/2000/xmlns/", "xmlns"} -> "http://www.w3.org/1999/xhtml"}, {XMLElement["body", {}, {XMLElement["div", {"class" -> "main"}, {XMLElement["section", {}, {}]}]}]}], {}]
```

---

Remove the links inside a ``nav``, keeping the ``nav``:

```wl
In[1]:= page = ImportString["<body><nav id=\"menu\"><a href=\"/\">Home</a><a href=\"/news\">News</a></nav><a href=\"/about\">About</a></body>", {"HTML", "XMLObject"}];
XMLDeleteCases[page, XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> x]

Out[1]= XMLObject["Document"][{XMLObject["Declaration"]["Version" -> "1.0", "Standalone" -> "yes"]}, XMLElement["html", {{"http://www.w3.org/2000/xmlns/", "xmlns"} -> "http://www.w3.org/1999/xhtml"}, {XMLElement["body", {}, {XMLElement["nav", {"id" -> "menu"}, {}], XMLElement["a", {"shape" -> "rect", "href" -> "/about"}, {"About"}]}]}], {}]
```

---

Remove two named children of each element, here the first and the third:

```wl
In[1]:= heading = XMLElement["h1", {}, {XMLElement["b", {}, {}], XMLElement["i", {}, {}], XMLElement["u", {}, {}], XMLElement["s", {}, {}]}];
XMLDeleteCases[{heading}, XMLPattern["h1"][{x_, _, y_, ___}] :> {x, y}]

Out[1]= {XMLElement["h1", {}, {XMLElement["i", {}, {}], XMLElement["s", {}, {}]}]}
```

---

Remove an attribute by naming its value:

```wl
In[1]:= links = {XMLElement["a", {"href" -> "/x", "target" -> "_blank"}, {"x"}]};
XMLDeleteCases[links, XMLPattern["a", "target" -> t_] :> t]

Out[1]= {XMLElement["a", {"href" -> "/x"}, {"x"}]}
```

Remove every attribute by naming the attribute list:

```wl
In[2]:= XMLDeleteCases[links, XMLPattern["a", attrs_] :> attrs]

Out[2]= {XMLElement["a", {}, {"x"}]}
```

---

Remove one class from the class list, keeping the others:

```wl
In[1]:= para = {XMLElement["p", {"class" -> "lead x lead"}, {}]};
XMLDeleteCases[para, XMLPattern["p", "classList" -> {___, c : "lead", ___}] :> c]

Out[1]= {XMLElement["p", {"class" -> "x"}, {}]}
```

---

Remove the contents of an element, text included, by naming them in an ``XMLElement`` pattern:

```wl
In[1]:= XMLDeleteCases[{XMLElement["div", {}, {XMLElement["pre", {}, {"code"}], XMLElement["p", {}, {"text"}]}]}, XMLElement["pre", _, c_] :> c]

Out[1]= {XMLElement["div", {}, {XMLElement["pre", {}, {}], XMLElement["p", {}, {"text"}]}]}
```

---

Remove a run of children:

```wl
In[1]:= section = {XMLElement["section", {}, {XMLElement["h2", {}, {"A"}], XMLElement["p", {}, {"a1"}], XMLElement["p", {}, {"a2"}], XMLElement["h2", {}, {"B"}]}]};
XMLDeleteCases[section, XMLPattern["section"][{XMLPattern["h2"], run___, XMLPattern["h2"], ___}] :> run]

Out[1]= {XMLElement["section", {}, {XMLElement["h2", {}, {"A"}], XMLElement["h2", {}, {"B"}]}]}
```

---

Name the whole element to test its text in a condition:

```wl
In[1]:= menu = ImportString["<ul><li>Miso</li><li>Pho (sold out)</li><li>Ramen</li></ul>", {"HTML", "XMLObject"}];
HTMLTextContent /@ XMLCases[XMLDeleteCases[menu, (li : XMLPattern["li"]) /; StringContainsQ[HTMLTextContent[li], "sold out"]], XMLPattern["li"]]

Out[1]= {"Miso", "Ramen"}
```

---

Use a condition on the right-hand side to compare names from the ``div`` and the paragraph:

```wl
In[1]:= body = XMLElement["body", {}, {XMLElement["div", {"id" -> "a"}, {XMLElement["p", {"id" -> "a-1"}, {"keep"}], XMLElement["p", {"id" -> "b-1"}, {"drop"}]}]}];
XMLDeleteCases[body, XMLPattern["div", "id" -> d_][Descendant[x : XMLPattern["p", "id" -> p_]]] :> x /; ! StringStartsQ[p, d]]

Out[1]= XMLElement["body", {}, {XMLElement["div", {"id" -> "a"}, {XMLElement["p", {"id" -> "a-1"}, {"keep"}]}]}]
```

---

Remove the items of each list of two or more items; both go, as matches are found first:

```wl
In[1]:= body = XMLElement["body", {}, {XMLElement["ul", {}, {XMLElement["li", {}, {"a"}], XMLElement["li", {}, {"b"}]}], XMLElement["ul", {}, {XMLElement["li", {}, {"c"}]}]}];
XMLDeleteCases[body, (list : XMLPattern["ul"][Child[x : XMLPattern["li"]]]) /; Length[list[[3]]] >= 2 :> x]

Out[1]= XMLElement["body", {}, {XMLElement["ul", {}, {}], XMLElement["ul", {}, {XMLElement["li", {}, {"c"}]}]}]
```

---

Remove the ``div`` children of the ``XMLElement`` given as the tree:

```wl
In[1]:= body = XMLElement["body", {}, {XMLElement["div", {}, {"one"}], XMLElement["p", {}, {XMLElement["div", {}, {"two"}]}]}];
XMLDeleteCases[body, XMLPattern["body"][Child[x : XMLPattern["div"]]] :> x]

Out[1]= XMLElement["body", {}, {XMLElement["p", {}, {XMLElement["div", {}, {"two"}]}]}]
```

---

Remove the paragraphs of a ``div``, and check that the whitespace between them is kept:

```wl
In[1]:= spaced = ImportString["<div><p>a</p>\n<p>b</p></div>", {"HTML", "XMLObject"}];
First[XMLCases[XMLDeleteCases[spaced, XMLPattern["p"]], XMLPattern["div"]]][[3]]

Out[1]= {"\n"}
```

---

Give a CSS selector string as the pattern:

```wl
In[1]:= page = ImportString["<main><p>News.</p><div class=\"ad\">Buy now!</div><p>More news.</p></main>", {"HTML", "XMLObject"}];
XMLDeleteCases[page, "main > div.ad"]

Out[1]= XMLObject["Document"][{XMLObject["Declaration"]["Version" -> "1.0", "Standalone" -> "yes"]}, XMLElement["main", {{"http://www.w3.org/2000/xmlns/", "xmlns"} -> "http://www.w3.org/1999/xhtml"}, {XMLElement["p", {}, {"News."}], XMLElement["p", {}, {"More news."}]}], {}]
```

---

Give a CSS selector list to remove the elements that match any of its selectors:

```wl
In[1]:= page = ImportString["<body><nav><a href=\"/\">Home</a></nav><ul><li>Miso</li></ul><p>Text</p></body>", {"HTML", "XMLObject"}];
HTMLTextContent[XMLDeleteCases[page, "nav a, ul > li"]]

Out[1]= "Text"
```

---

Remove the paragraph right after each heading:

```wl
In[1]:= doc = ImportString["<section><p>intro</p><h2>A</h2><p>a1</p><p>a2</p></section>", {"HTML", "XMLObject"}];
HTMLTextContent /@ XMLCases[XMLDeleteCases[doc, XMLPattern[_][{___, XMLPattern["h2"], x : XMLPattern["p"], ___}] :> x], XMLPattern["p"]]

Out[1]= {"intro", "a2"}
```

Remove every later paragraph:

```wl
In[2]:= HTMLTextContent /@ XMLCases[XMLDeleteCases[doc, XMLPattern[_][{___, XMLPattern["h2"], ___, x : XMLPattern["p"], ___}] :> x], XMLPattern["p"]]

Out[2]= {"intro"}
```

---

Remove only the top-level paragraphs of a list with ``XMLDocument``:

```wl
In[1]:= fragment = {XMLElement["p", {}, {"Top"}], XMLElement["div", {}, {XMLElement["p", {}, {"Nested"}]}]};
XMLDeleteCases[fragment, XMLDocument[Child[x : XMLPattern["p"]]] :> x]

Out[1]= {XMLElement["div", {}, {XMLElement["p", {}, {"Nested"}]}]}
```

### Options

#### AttributeReadings

---

Split ``rel`` into tokens, and remove the links that have the token sponsored:

```wl
In[1]:= body = XMLElement["body", {}, {XMLElement["a", {"rel" -> "nofollow sponsored", "href" -> "/ad"}, {"Ad"}], XMLElement["a", {"href" -> "/story"}, {"Story"}]}];
XMLDeleteCases[body, XMLPattern["a", "relList" -> "sponsored"], "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= XMLElement["body", {}, {XMLElement["a", {"href" -> "/story"}, {"Story"}]}]
```

Remove only that token of ``rel``, keeping the link:

```wl
In[2]:= XMLDeleteCases[body, XMLPattern["a", "relList" -> {___, r : "sponsored", ___}] :> r, "AttributeReadings" -> <|"rel" -> <||>|>]

Out[2]= XMLElement["body", {}, {XMLElement["a", {"rel" -> "nofollow", "href" -> "/ad"}, {"Ad"}], XMLElement["a", {"href" -> "/story"}, {"Story"}]}]
```

### Applications

---

Remove page chrome, then get the text of the page with ``HTMLInnerText``:

```wl
In[1]:= page = ImportString["<html><body><nav>Menu</nav><main><p>Keep <script>x()</script>me</p></main><footer>End</footer><style>.a{}</style></body></html>", {"HTML", "XMLObject"}];
HTMLInnerText[XMLDeleteCases[page, XMLPattern["script" | "style" | "nav" | "footer"]]]

Out[1]= "Keep me"
```

---

Remove advertisement blocks by class before extracting the text:

```wl
In[1]:= page = ImportString["<main><p>First paragraph.</p><div class=\"ad banner\"><p>Buy now!</p></div><p>Second paragraph.</p></main>", {"HTML", "XMLObject"}];
HTMLInnerText[XMLDeleteCases[page, XMLPattern[_, "classList" -> "ad"]]]

Out[1]= "First paragraph.\nSecond paragraph."
```

---

Strip tracking attributes from every link:

```wl
In[1]:= links = ImportString["<p><a href=\"/a\" data-track=\"1\" onclick=\"t()\">A</a><a href=\"/b\">B</a></p>", {"HTML", "XMLObject"}];
XMLCases[XMLDeleteCases[links, XMLPattern["a", {"data-track" -> t_, "onclick" -> o_}] :> {t, o}], XMLPattern["a"]]

Out[1]= {XMLElement["a", {"shape" -> "rect", "href" -> "/a"}, {"A"}], XMLElement["a", {"shape" -> "rect", "href" -> "/b"}, {"B"}]}
```

### Properties & Relations

---

Compare with ``DeleteCases`` at all depths, which gives the same result for an element pattern:

```wl
In[1]:= tree = ImportString["<div><p>a</p><p>b</p></div>", {"HTML", "XMLObject"}];
XMLDeleteCases[tree, XMLPattern["p"]] === DeleteCases[tree, XMLElement["p", _, _], Infinity]

Out[1]= True
```

Check with ``XMLCases`` that no match is left:

```wl
In[2]:= XMLCases[XMLDeleteCases[tree, XMLPattern["p"]], XMLPattern["p"]]

Out[2]= {}
```

---

Remove the parts at the positions that ``XMLPosition`` gives:

```wl
In[1]:= page = ImportString["<div><p>a</p><section><p>b</p></section></div>", {"HTML", "XMLObject"}];
query = XMLPattern["div"][Child[x : XMLPattern["p"]]] :> x;
{XMLPosition[page, query], XMLCases[XMLDeleteCases[page, query], XMLPattern["p"]]}

Out[1]= {{{1, 1, 1, 1}}, {XMLElement["p", {}, {"b"}]}}
```

---

Remove an element with ``XMLReplace`` and ``Nothing`` instead:

```wl
In[1]:= page = ImportString["<div><p>a</p><b>b</b></div>", {"HTML", "XMLObject"}];
XMLDeleteCases[page, XMLPattern["p"]] === XMLReplace[page, XMLPattern["p"] :> Nothing]

Out[1]= True
```

### Possible Issues

---

The right-hand side must be a name or a list of names, so any other expression gives a message:

```wl
In[1]:= tree = ImportString["<p>a</p>", {"HTML", "XMLObject"}];
XMLDeleteCases[tree, XMLPattern["p"] :> "x"]

During evaluation of In[1]:= XMLDeleteCases::delrhs: The right-hand side of XMLPattern["p"] :> "x" should be a name of the pattern, or a list of names, optionally with a condition (/;): XMLDeleteCases deletes what those names match, as in x : XMLPattern["a"] :> x. Use :> so that the names are not evaluated.

Out[1]= $Failed
```

Use ``XMLReplace`` to replace the matches:

```wl
In[2]:= XMLReplace[tree, XMLPattern["p"] :> "x"]

Out[2]= XMLObject["Document"][{XMLObject["Declaration"]["Version" -> "1.0", "Standalone" -> "yes"]}, XMLElement["html", {{"http://www.w3.org/2000/xmlns/", "xmlns"} -> "http://www.w3.org/1999/xhtml"}, {XMLElement["body", {}, {"x"}]}], {}]
```

---

A tag cannot be deleted, so a name for one gives a message:

```wl
In[1]:= XMLDeleteCases[{XMLElement["p", {}, {}]}, XMLPattern[t_] :> t]

During evaluation of In[1]:= XMLDeleteCases::target: {1, 0} is the position of the document or of a tag, which cannot be deleted. Name an element, an attribute, a token, a run of children or the contents instead.

Out[1]= $Failed
```

---

A name on a ``Descendant`` constraint cannot be deleted:

```wl
In[1]:= navs = ImportString["<nav><p><a>Home</a></p></nav>", {"HTML", "XMLObject"}];
XMLDeleteCases[navs, XMLPattern["nav"][path : Descendant[XMLPattern["a"]]] :> path]

During evaluation of In[1]:= XMLDeleteCases::pathtarget: {1} ;; {1, 1, 1} gives the elements between two others, as for a name on a Descendant constraint, which cannot be deleted. Name the elements to delete instead.

Out[1]= $Failed
```

Name the elements to delete instead:

```wl
In[2]:= XMLDeleteCases[navs, XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> x]

Out[2]= XMLObject["Document"][{XMLObject["Declaration"]["Version" -> "1.0", "Standalone" -> "yes"]}, XMLElement["nav", {{"http://www.w3.org/2000/xmlns/", "xmlns"} -> "http://www.w3.org/1999/xhtml"}, {XMLElement["p", {}, {}]}], {}]
```

---

A name that the right-hand side does not use must match, but its part is not deleted:

```wl
In[1]:= page = ImportString["<div><h2>A</h2><p>a</p></div>", {"HTML", "XMLObject"}];
XMLDeleteCases[page, XMLPattern["div"][{h : XMLPattern["h2"], p : XMLPattern["p"]}] :> p]

Out[1]= XMLObject["Document"][{XMLObject["Declaration"]["Version" -> "1.0", "Standalone" -> "yes"]}, XMLElement["html", {{"http://www.w3.org/2000/xmlns/", "xmlns"} -> "http://www.w3.org/1999/xhtml"}, {XMLElement["body", {}, {XMLElement["div", {}, {XMLElement["h2", {}, {"A"}]}]}]}], {}]
```

---

With ``DeleteCases``, an ``XMLPattern`` is a literal expression, so nothing is removed:

```wl
In[1]:= tree = ImportString["<div><p>a</p></div>", {"HTML", "XMLObject"}];
DeleteCases[tree, XMLPattern["p"], Infinity] === tree

Out[1]= True
```

---

An invalid tree gives a message and ``$Failed``:

```wl
In[1]:= XMLDeleteCases[42, XMLPattern["p"]]

During evaluation of In[1]:= XMLDeleteCases::badtree: The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head Integer.

Out[1]= $Failed
```

---

The root element of a document is kept, and the other matches are removed:

```wl
In[1]:= doc = ImportString["<html><body><p>Text</p></body></html>", {"HTML", "XMLObject"}];
XMLDeleteCases[doc, XMLPattern["html" | "p"]]

During evaluation of In[1]:= XMLDeleteCases::root: The root element of an XMLObject cannot be deleted; it was kept.

Out[1]= XMLObject["Document"][{XMLObject["Declaration"]["Version" -> "1.0", "Standalone" -> "yes"]}, XMLElement["html", {{"http://www.w3.org/2000/xmlns/", "xmlns"} -> "http://www.w3.org/1999/xhtml"}, {XMLElement["body", {}, {}]}], {}]
```

## See Also

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [XMLReplace](paclet:MaximilienTirard/HTMLPatterns/ref/XMLReplace)

* [XMLPosition](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPosition)

* [XMLFirstCase](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFirstCase)

* [XMLMatchQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLMatchQ)

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [Child](paclet:MaximilienTirard/HTMLPatterns/ref/Child)

* [Descendant](paclet:MaximilienTirard/HTMLPatterns/ref/Descendant)

* [XMLDocument](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDocument)

* [FromCSSSelector](paclet:MaximilienTirard/HTMLPatterns/ref/FromCSSSelector)

* [HTMLInnerText](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLInnerText)

* [DeleteCases](paclet:ref/DeleteCases)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
