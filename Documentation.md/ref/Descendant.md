# Descendant

   ``Descendant[p$]`` is a constraint on an element in an ``XMLPattern``, met when some element anywhere below it matches ``p$``.
   ``Descendant[p$, levelspec$]`` is met when some element at the depths in ``levelspec$`` below the element matches ``p$``.

## Details and Options

``Descendant`` is a **constraint**: a condition on what is below an element, given as an argument of the second bracket of ``XMLPattern`` or of ``XMLDocument``. Elsewhere, such as the whole pattern or an entry of a list pattern, it gives a message.

``p$`` can be an ``XMLPattern``, an ``XMLElement`` pattern, a CSS selector for one element, or alternatives of these. Each can be named, have a condition or have a test. An ``XMLPattern`` or CSS selector in ``p$`` can have constraints of its own.

``levelspec$`` counts depth below the element that the constraint is on, with its children at depth 1, its grandchildren at depth 2, and so on. It has the following forms:

| form | description |
| :--- | :--- |
| ``n$`` | depths 1 to ``n$`` |
| ``{n$}`` | depth ``n$`` only |
| ``{m$, n$}`` | depths ``m$`` to ``n$`` |
| ``Infinity`` | all depths, the default |

``Descendant`` matches elements only, not text.

Several ``Descendant`` constraints on one element are independent, and one element below may meet several of them.

A name on the constraint, as in ``path : Descendant[XMLPattern["a"]]``, is bound to the list of the elements strictly between the element and the match, outermost first, or ``{}`` for a child. Under ``XMLDocument``, the list holds every ancestor of the match.

A test on the constraint, as in ``Descendant[XMLPattern["a"]]?f``, tests that list.

``Shortest`` and ``Longest`` on the constraint pair each match with only one element that meets the whole pattern: the nearest or the outermost.

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Give each link inside a nav once, including a link inside two nav elements:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav><a>About</a></nav>", {"HTML", "XMLObject"}];
XMLCases[navs, XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> HTMLTextContent[x]]

Out[1]= {"Home", "News", "About"}
```

---

Test whether an element has a bold element anywhere below it:

```wl
In[1]:= XMLMatchQ[XMLElement["p", {}, {"Some ", XMLElement["i", {}, {XMLElement["b", {}, {"bold"}]}], " text"}], XMLPattern["p"][Descendant[XMLPattern["b"]]]]

Out[1]= True
```

### Scope

---

Give a level spec to match only the children:

```wl
In[1]:= tree = ImportString["<ul id=\"top\"><li id=\"a\">A<ul><li id=\"b\">B</li></ul></li></ul>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern["ul", "id" -> "top"][Descendant[XMLPattern["li", "id" -> id_], {1}]] :> id]

Out[1]= {"a"}
```

Match only the elements three levels down, below a li and a ul:

```wl
In[2]:= XMLCases[tree, XMLPattern["ul", "id" -> "top"][Descendant[XMLPattern["li", "id" -> id_], {3}]] :> id]

Out[2]= {"b"}
```

Match the elements one to three levels down:

```wl
In[3]:= XMLCases[tree, XMLPattern["ul", "id" -> "top"][Descendant[XMLPattern["li", "id" -> id_], 3]] :> id]

Out[3]= {"a", "b"}
```

---

Nest a pattern with constraints of its own, as the selector ``table tr > td`` does:

```wl
In[1]:= table = ImportString["<table><tr><th>Day</th><td>Friday</td></tr></table>", {"HTML", "XMLObject"}];
XMLCases[table, XMLPattern["table"][Descendant[XMLPattern["tr"][Child[x : XMLPattern["td"]]]]] :> HTMLTextContent[x]]

Out[1]= {"Friday"}
```

---

Give several ``Descendant`` constraints, all of which must hold:

```wl
In[1]:= forecast = ImportString["<div class=\"day\" id=\"mon\"><span class=\"high\">14</span><span class=\"low\">6</span></div><div class=\"day\" id=\"tue\"><span class=\"high\">12</span></div>", {"HTML", "XMLObject"}];
XMLCases[forecast, XMLPattern["div", "id" -> day_][Descendant[XMLPattern["span", "classList" -> "high"]], Descendant[XMLPattern["span", "classList" -> "low"]]] :> day]

Out[1]= {"mon"}
```

Name the element that meets each constraint, and give both:

```wl
In[2]:= XMLCases[forecast, XMLPattern["div"][Descendant[high : XMLPattern["span", "classList" -> "high"]], Descendant[low : XMLPattern["span", "classList" -> "low"]]] :> {HTMLTextContent[high], HTMLTextContent[low]}]

Out[2]= {{"14", "6"}}
```

---

Use the names of both the nav and the link to get one result for each pair:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav><a>About</a></nav>", {"HTML", "XMLObject"}];
XMLCases[navs, XMLPattern["nav", "id" -> id_][Descendant[x : XMLPattern["a"]]] :> {id, HTMLTextContent[x]}]

Out[1]= {{"outer", "Home"}, {"outer", "News"}, {"outer", "About"}, {"inner", "News"}}
```

Wrap the constraint in ``Shortest`` to pair each link with its nearest nav only:

```wl
In[2]:= XMLCases[navs, XMLPattern["nav", "id" -> id_][Shortest[Descendant[x : XMLPattern["a"]]]] :> {id, HTMLTextContent[x]}]

Out[2]= {{"outer", "Home"}, {"outer", "About"}, {"inner", "News"}}
```

Wrap it in ``Longest`` to pair each link with its outermost nav only:

```wl
In[3]:= XMLCases[navs, XMLPattern["nav", "id" -> id_][Longest[Descendant[x : XMLPattern["a"]]]] :> {id, HTMLTextContent[x]}]

Out[3]= {{"outer", "Home"}, {"outer", "News"}, {"outer", "About"}}
```

---

Name the constraint to get the elements between the nav and each link:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav><a>About</a></nav>", {"HTML", "XMLObject"}];
XMLCases[navs, XMLPattern["nav", "id" -> "outer"][path : Descendant[x : XMLPattern["a"]]] :> {HTMLTextContent[x], Map[First, path]}]

Out[1]= {{"Home", {}}, {"News", {"nav"}}, {"About", {}}}
```

Give the depth of each link below the outer nav:

```wl
In[2]:= XMLCases[navs, XMLPattern["nav", "id" -> "outer"][path : Descendant[x : XMLPattern["a"]]] :> {HTMLTextContent[x], Length[path] + 1}]

Out[2]= {{"Home", 1}, {"News", 2}, {"About", 1}}
```

---

Test the elements in between, so that no table lies between a table and its cell:

```wl
In[1]:= tables = XMLElement["table", {"id" -> "A"}, {XMLElement["tr", {}, {XMLElement["td", {"id" -> "o"}, {XMLElement["table", {"id" -> "B"}, {XMLElement["tr", {}, {XMLElement["td", {"id" -> "t"}, {}]}]}]}]}]}];
XMLCases[{tables}, XMLPattern["table", "id" -> t_][Descendant[x : XMLPattern["td", "id" -> c_]]?(NoneTrue[XMLMatchQ["table"]])] :> {t, c}]

Out[1]= {{"A", "o"}, {"B", "t"}}
```

---

Give the constraint to ``XMLDocument`` to test every ancestor, here for links outside a nav:

```wl
In[1]:= page = ImportString["<body><nav><a href=\"/\">Home</a></nav><p>See <a href=\"/about\">About</a>.</p></body>", {"HTML", "XMLObject"}];
XMLCases[page, XMLDocument[Descendant[x : XMLPattern["a"]]?(NoneTrue[XMLMatchQ["nav"]])] :> HTMLTextContent[x]]

Out[1]= {"About"}
```

---

Give a CSS selector string for one element as the pattern:

```wl
In[1]:= page = ImportString["<div><p><a class=\"ext\" href=\"https://w3.org\">W3C</a></p></div><div><a href=\"/\">Home</a></div>", {"HTML", "XMLObject"}];
XMLCases[page, XMLPattern["div"][Descendant["a.ext"]]]

Out[1]= {XMLElement["div", {}, {XMLElement["p", {}, {XMLElement["a", {"shape" -> "rect", "class" -> "ext", "href" -> "https://w3.org"}, {"W3C"}]}]}]}
```

### Properties & Relations

---

``FromCSSSelector`` gives a ``Descendant`` constraint for the selector ``"nav a"``:

```wl
In[1]:= FromCSSSelector[n : "nav a"]

Out[1]= XMLPattern["nav"][Descendant[n : XMLPattern["a"]]]
```

The selector and the pattern give the same results:

```wl
In[2]:= page = ImportString["<body><nav><a href=\"/\">Home</a></nav><p><a href=\"/about\">About</a></p></body>", {"HTML", "XMLObject"}];
XMLCases[page, "nav a"] === XMLCases[page, XMLPattern["nav"][Descendant[n : XMLPattern["a"]]] :> n]

Out[2]= True
```

---

``Descendant[p$, {1}]`` is met by the same elements as ``Child[p$]``:

```wl
In[1]:= tree = ImportString["<ul><li>A<ul><li>B</li></ul></li></ul><ol><li>C</li></ol>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern[_][Descendant[XMLPattern["li"], {1}]]] === XMLCases[tree, XMLPattern[_][Child[XMLPattern["li"]]]]

Out[1]= True
```

---

An element meets ``Descendant[p$]`` when ``XMLFreeQ`` below it gives ``False``:

```wl
In[1]:= element = XMLElement["p", {}, {XMLElement["i", {}, {XMLElement["b", {}, {"x"}]}]}];
{XMLMatchQ[element, XMLPattern["p"][Descendant[XMLPattern["b"]]]], XMLFreeQ[element, XMLPattern["b"], {1, Infinity}]}

Out[1]= {True, False}
```

### Possible Issues

---

``Descendant`` is a constraint, so it cannot be the whole pattern:

```wl
In[1]:= navs = ImportString["<nav><a>Home</a></nav>", {"HTML", "XMLObject"}];
XMLCases[navs, Descendant[XMLPattern["a"]]]

During evaluation of In[1]:= Descendant::place: Descendant[XMLPattern["a"]] is a constraint, which can only be an argument of the bracket after XMLPattern[tag, attrs] or of XMLDocument, as in XMLPattern["nav"][Descendant[XMLPattern["a"]]]. To find matching elements at any depth, give the pattern alone.

Out[1]= $Failed
```

Give the pattern alone to find matches at any depth:

```wl
In[2]:= XMLCases[navs, XMLPattern["a"]]

Out[2]= {XMLElement["a", {"shape" -> "rect"}, {"Home"}]}
```

---

``Descendant`` cannot be an entry of a list pattern, which matches one child or a run of children:

```wl
In[1]:= navs = ImportString["<nav><p><a>Home</a></p></nav>", {"HTML", "XMLObject"}];
XMLCases[navs, XMLPattern["nav"][{Descendant[x : XMLPattern["a"]]}] :> x]

During evaluation of In[1]:= XMLPattern::listentry: Descendant[x:XMLPattern["a"]] cannot be an entry in a list of patterns for an element's children. "An entry is one element child or a sequence of them, and Descendant[...] is a constraint on what is somewhere below an element. A child containing x is XMLPattern[_][Descendant[x]]."

Out[1]= $Failed
```

Give a child that holds the match:

```wl
In[2]:= XMLCases[navs, XMLPattern["nav"][{XMLPattern[_][Descendant[x : XMLPattern["a"]]]}] :> x]

Out[2]= {XMLElement["a", {"shape" -> "rect"}, {"Home"}]}
```

---

A pattern in place of the level spec issues a message:

```wl
In[1]:= navs = ImportString["<nav><a>Home</a></nav>", {"HTML", "XMLObject"}];
XMLCases[navs, Descendant[XMLPattern["nav"], XMLPattern["a"]]]

During evaluation of In[1]:= Descendant::level: XMLPattern["a"] is not a level specification. Use n, {n}, {m, n} or Infinity, with every level at least 1. For an element inside an element inside another, nest the patterns: XMLPattern[a][Descendant[XMLPattern[b][Descendant[c]]]].

Out[1]= $Failed
```

Nest the patterns as the document is, and name what to give:

```wl
In[2]:= XMLCases[navs, XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> x]

Out[2]= {XMLElement["a", {"shape" -> "rect"}, {"Home"}]}
```

---

``Shortest`` changes nothing when the right-hand side uses no name from the nav:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav></nav>", {"HTML", "XMLObject"}];
{XMLCases[navs, XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> HTMLTextContent[x]], XMLCases[navs, XMLPattern["nav"][Shortest[Descendant[x : XMLPattern["a"]]]] :> HTMLTextContent[x]]}

Out[1]= {{"Home", "News"}, {"Home", "News"}}
```

---

``Shortest`` gives the nearest element that meets the whole pattern, here a table with a caption:

```wl
In[1]:= tables = XMLElement["table", {"id" -> "A"}, {XMLElement["caption", {}, {}], XMLElement["tr", {}, {XMLElement["td", {"id" -> "o"}, {XMLElement["table", {"id" -> "B"}, {XMLElement["tr", {}, {XMLElement["td", {"id" -> "t"}, {}]}]}]}]}]}];
XMLCases[{tables}, XMLPattern["table", "id" -> t_][{XMLPattern["caption"], ___}, Shortest[Descendant[XMLPattern["td", "id" -> c_]]]] :> {t, c}]

Out[1]= {{"A", "o"}, {"A", "t"}}
```

Test the elements in between to exclude a cell inside any inner table:

```wl
In[2]:= XMLCases[{tables}, XMLPattern["table", "id" -> t_][{XMLPattern["caption"], ___}, Descendant[XMLPattern["td", "id" -> c_]]?(NoneTrue[XMLMatchQ["table"]])] :> {t, c}]

Out[2]= {{"A", "o"}}
```

## See Also

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [XMLDocument](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDocument)

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [XMLPosition](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPosition)

* [XMLMatchQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLMatchQ)

* [XMLFreeQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFreeQ)

* [FromCSSSelector](paclet:MaximilienTirard/HTMLPatterns/ref/FromCSSSelector)

* [Shortest](paclet:ref/Shortest)

* [Longest](paclet:ref/Longest)

* [Child](paclet:MaximilienTirard/HTMLPatterns/ref/Child)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
