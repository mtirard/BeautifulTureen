# XMLFirstCase

   ``XMLFirstCase[tree$, pattern$]`` gives the first result of ``XMLCases[tree$, pattern$]``: the first element of ``tree$`` that matches ``pattern$``, in document order.
   ``XMLFirstCase[tree$, pattern$, default$]`` gives ``default$`` if no element matches ``pattern$``.
   ``XMLFirstCase[tree$, pattern$ :> rhs$]`` gives the value of ``rhs$`` for the first result of ``XMLCases[tree$, pattern$ :> rhs$]``.

## Details and Options

When there is no result, ``XMLFirstCase[tree$, pattern$]`` gives ``Missing["NotFound"]``, and ``XMLFirstCase[tree$, pattern$, default$]`` gives ``default$``.

Of nested matches, ``XMLFirstCase`` gives the outermost.

``tree$`` and ``pattern$`` can have the same forms as in ``XMLCases``, and names are bound in the same way.

With ``pattern$ :> rhs$``, ``XMLFirstCase`` gives the first result of ``XMLCases``, in the order given there, and evaluates ``rhs$`` only for it. A condition or test in ``pattern$`` can also be evaluated for elements past the first result.

``XMLFirstCase`` issues a message and returns ``$Failed`` when ``tree$`` or ``pattern$`` has none of the forms that ``XMLCases`` accepts, when an ``XMLPattern`` in ``pattern$`` is malformed, or when a name that ``rhs$`` uses has no position, such as a name for text.

The following option can be given:

| option | default | description |
| :--- | :--- | :--- |
| ``"AttributeReadings"`` | ``<\|\|>`` | attributes to split into lists of tokens for this call, in addition to ``$AttributeReadings`` |

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Find the first paragraph in a document:

```wl
In[1]:= XMLFirstCase[ImportString["<html><body><p>One</p><p>Two</p></body></html>", {"HTML", "XMLObject"}], XMLPattern["p"]]

Out[1]= XMLElement["p", {}, {"One"}]
```

---

Give a default when no element matches:

```wl
In[1]:= XMLFirstCase[ImportString["<html><body><p>Body</p></body></html>", {"HTML", "XMLObject"}], XMLPattern["h1"], "(no heading)"]

Out[1]= "(no heading)"
```

---

Name a part and use it on the right-hand side to give a value for the first result:

```wl
In[1]:= tree = ImportString["<ul><li><a href=\"/miso\">Miso</a></li><li><a href=\"/pho\">Pho</a></li></ul>", {"HTML", "XMLObject"}];
XMLFirstCase[tree, XMLPattern["a", "href" -> href_] :> href]

Out[1]= "/miso"
```

### Scope

---

Find the first element that matches any of several patterns:

```wl
In[1]:= tree = ImportString["<article><h1>Menu</h1><p class=\"lead\">See the <a href=\"/about\">about page</a>.</p><ul><li><a href=\"/miso\">Miso</a></li><li><a href=\"/pho\">Pho</a></li></ul></article>", {"HTML", "XMLObject"}];
XMLFirstCase[tree, XMLPattern["h1"] | XMLPattern["a"]]

Out[1]= XMLElement["h1", {}, {"Menu"}]
```

Find the first element that has the class lead:

```wl
In[2]:= XMLFirstCase[tree, XMLPattern[_, "classList" -> "lead"]]

Out[2]= XMLElement["p", {"class" -> "lead"}, {"See the ", XMLElement["a", {"shape" -> "rect", "href" -> "/about"}, {"about page"}], "."}]
```

Find the first link that is a child of a list item:

```wl
In[3]:= XMLFirstCase[tree, XMLPattern["li"][Child[x : XMLPattern["a"]]] :> x]

Out[3]= XMLElement["a", {"shape" -> "rect", "href" -> "/miso"}, {"Miso"}]
```

Find the first paragraph that immediately follows an h1:

```wl
In[4]:= XMLFirstCase[tree, XMLPattern[_][{___, XMLPattern["h1"], x : XMLPattern["p"], ___}] :> x]

Out[4]= XMLElement["p", {"class" -> "lead"}, {"See the ", XMLElement["a", {"shape" -> "rect", "href" -> "/about"}, {"about page"}], "."}]
```

---

Of nested matches, get the outermost:

```wl
In[1]:= nested = ImportString["<div id=\"outer\"><div id=\"inner\">x</div></div>", {"HTML", "XMLObject"}];
XMLFirstCase[nested, XMLPattern["div", "id" -> id_] :> id]

Out[1]= "outer"
```

---

Name the whole element to test its text in a condition:

```wl
In[1]:= tree = ImportString["<article><p>Short.</p><p>This paragraph mentions the Wolfram Language.</p></article>", {"HTML", "XMLObject"}];
XMLFirstCase[tree, (para : XMLPattern["p"]) /; StringContainsQ[HTMLTextContent[para], "Wolfram"]]

Out[1]= XMLElement["p", {}, {"This paragraph mentions the Wolfram Language."}]
```

---

Put a condition on a pattern to use names bound at two levels:

```wl
In[1]:= doc = ImportString["<div id=\"a\"><div id=\"b\"><p id=\"b-1\">one</p></div><p id=\"a-1\">two</p></div>", {"HTML", "XMLObject"}];
XMLFirstCase[doc, (XMLPattern["div", "id" -> d_][Descendant[XMLPattern["p", "id" -> p_]]] /; p === d <> "-1") :> {d, p}]

Out[1]= {"a", "a-1"}
```

---

With two names used, get the first pair, grouped by the first name:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav></nav>", {"HTML", "XMLObject"}];
XMLFirstCase[navs, XMLPattern["nav", "id" -> id_][Descendant[x : XMLPattern["a"]]] :> {id, HTMLTextContent[x]}]

Out[1]= {"outer", "Home"}
```

---

With two names on the right-hand side, get the first pair, ordered by the first name in the pattern:

```wl
In[1]:= article = ImportString["<article><h2>Intro</h2><p class=\"lead\">First.</p><p class=\"lead\">Second.</p></article>", {"HTML", "XMLObject"}];
XMLFirstCase[article, "article > p.lead"]

Out[1]= XMLElement["p", {"class" -> "lead"}, {"First."}]
```

---

With a CSS selector list, get the first element in document order that any of them selects:

```wl
In[1]:= page = ImportString["<body><nav><a href=\"/\">Home</a></nav><ul><li>Miso</li></ul></body>", {"HTML", "XMLObject"}];
XMLFirstCase[page, "ul > li, nav a"]

Out[1]= XMLElement["a", {"shape" -> "rect", "href" -> "/"}, {"Home"}]
```

---

Get ``Sequence[]`` for a name bound only in an alternative that did not match:

```wl
In[1]:= items = ImportString["<ul><li><span>s</span></li><li><a>a</a></li></ul>", {"HTML", "XMLObject"}];
XMLFirstCase[items, XMLPattern["li"][{(x : XMLPattern["a"]) | (y : XMLPattern["span"])}] :> {x, y}]

Out[1]= {XMLElement["span", {}, {"s"}]}
```

### Options

#### AttributeReadings

---

Split rel into tokens, and match one with the list key "relList", whose value is the list of tokens:

```wl
In[1]:= links = ImportString["<p><a rel=\"noopener\" href=\"/x\">x</a><a rel=\"nofollow noopener\" href=\"/y\">y</a></p>", {"HTML", "XMLObject"}];
XMLFirstCase[links, XMLPattern["a", {"href" -> href_, "relList" -> "nofollow"}] :> href, "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= "/y"
```

### Applications

---

Get the first link target from the 1989 proposal that founded the web:

```wl
In[1]:= tree = Import["https://www.w3.org/History/1989/proposal.html", {"HTML", "XMLObject"}];
XMLFirstCase[tree, XMLPattern["a", "href" -> href_] :> href]

Out[1]= "../../DesignIssues/OldDocs.html"
```

---

Read the title of a page, with a default:

```wl
In[1]:= page = ImportString["<html><head><title>Menu of the day</title></head><body></body></html>", {"HTML", "XMLObject"}];
XMLFirstCase[page, title : XMLPattern["title"] :> HTMLTextContent[title], "(untitled)"]

Out[1]= "Menu of the day"
```

### Properties & Relations

---

``XMLFirstCase`` gives the first element of the ``XMLCases`` result:

```wl
In[1]:= tree = ImportString["<div><p>a</p><p>b</p></div>", {"HTML", "XMLObject"}];
XMLFirstCase[tree, XMLPattern["p"]] === First@XMLCases[tree, XMLPattern["p"]]

Out[1]= True
```

The default is given only when nothing matches:

```wl
In[2]:= XMLFirstCase[tree, XMLPattern["table"], None]

Out[2]= None
```

---

Of nested matches, ``XMLFirstCase`` gives the outermost and ``FirstCase`` the innermost:

```wl
In[1]:= nested = ImportString["<div id=\"outer\"><div id=\"inner\">x</div></div>", {"HTML", "XMLObject"}];
{XMLFirstCase[nested, XMLPattern["div", "id" -> id_] :> id], FirstCase[nested, XMLElement["div", {"id" -> id_}, _] :> id, Missing["NotFound"], Infinity]}

Out[1]= {"outer", "inner"}
```

---

The right-hand side is evaluated only for the result given:

```wl
In[1]:= tree = ImportString["<p id=\"x\">one</p><p id=\"y\">two</p>", {"HTML", "XMLObject"}];
count = 0;
{XMLFirstCase[tree, XMLPattern["p", "id" -> id_] :> (count++; id)], count}

Out[1]= {"x", 1}
```

### Possible Issues

---

When nothing matches, the result is ``Missing["NotFound"]``, with no message:

```wl
In[1]:= tree = ImportString["<p>hello</p>", {"HTML", "XMLObject"}];
XMLFirstCase[tree, XMLPattern["h1"]]

Out[1]= Missing["NotFound"]
```

``XMLPattern["hello"]`` matches elements with the tag hello, which this tree does not have:

```wl
In[2]:= XMLFirstCase[tree, XMLPattern["hello"]]

Out[2]= Missing["NotFound"]
```

---

``FirstCase`` treats an ``XMLPattern`` as a literal expression:

```wl
In[1]:= tree = ImportString["<p>hello</p>", {"HTML", "XMLObject"}];
FirstCase[tree, XMLPattern["p"], None, Infinity]

Out[1]= None
```

---

An invalid tree gives a message and ``$Failed``:

```wl
In[1]:= XMLFirstCase[42, XMLPattern["p"]]

During evaluation of In[1]:= XMLFirstCase::badtree: The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head Integer.

Out[1]= $Failed
```

## See Also

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [XMLPosition](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPosition)

* [XMLExtract](paclet:MaximilienTirard/HTMLPatterns/ref/XMLExtract)

* [XMLDeleteCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDeleteCases)

* [XMLMatchQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLMatchQ)

* [XMLFreeQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFreeQ)

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [Descendant](paclet:MaximilienTirard/HTMLPatterns/ref/Descendant)

* [Child](paclet:MaximilienTirard/HTMLPatterns/ref/Child)

* [XMLDocument](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDocument)

* [FromCSSSelector](paclet:MaximilienTirard/HTMLPatterns/ref/FromCSSSelector)

* [HTMLTextContent](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLTextContent)

* [FirstCase](paclet:ref/FirstCase)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
