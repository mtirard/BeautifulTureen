# XMLCases

   ``XMLCases[tree$, pattern$]`` gives a list of the elements of ``tree$`` that match ``pattern$``, in document order.
   ``XMLCases[tree$, pattern$ :> rhs$]`` gives the value of ``rhs$`` once for each distinct combination of the positions in ``tree$`` of the names that ``rhs$`` uses.
   ``XMLCases[tree$, pattern$, n$]`` gives the first ``n$`` results.

## Details and Options

``XMLCases[tree$, pattern$ :> rhs$]`` gives one result for each distinct combination of the positions of the names that ``rhs$`` uses:

| ``rhs$`` uses | results |
| :--- | :--- |
| one name ``x`` | one for each position of ``x`` |
| names ``x`` and ``y`` | one for each pair of positions of ``x`` and ``y`` matched together |
| no name | at most one |

A name that ``rhs$`` does not use must match, but adds no results. A name that ``rhs$`` uses only in its condition, after ``/;``, adds no results either.

The results are in **document order**: an element comes before the elements nested in it, and an earlier sibling and its contents come before a later sibling. With several names, the results are ordered by the first name in ``pattern$``, then by the next, whatever their order in ``rhs$``.

``tree$`` can be an ``XMLObject``, an ``XMLElement``, or a list of elements and strings.

``pattern$`` can be an ``XMLPattern``, an ``XMLElement`` pattern, which matches exactly as written, an ``XMLDocument`` pattern, a CSS selector string such as ``"div.note > p"``, or alternatives of these. Each can be named, as in ``x : XMLPattern["p"]``, have a condition, as in ``x : XMLPattern["p"] /; test``, or have a test, as in ``XMLPattern["p"]?f``.

``XMLPattern[tag$, attrs$][c$1, c$2, $$]`` takes constraints on the elements below it: a list pattern over its element children, such as ``{XMLPattern["li"], ___}``, ``Child[p$]`` for an element child, or ``Descendant[p$]`` for an element anywhere below. The outermost pattern in ``pattern$`` matches an element of ``tree$``, and the patterns in its constraints match elements below that element.

A CSS selector for one element, one that depends only on its element and what is below it, such as ``"a.note"`` or ``"ul:has(> li)"``, can be used anywhere a pattern can. Other selectors depend on what is above or beside their element, such as ``"nav a"``: give one as the whole pattern, or name it on the left of a rule, as in ``n : "nav a" :> n``.

A name used twice, in one list or once above and once below, must have equal values at both positions. A name for an element used in two constraints of one ``XMLPattern`` must match the same element in both.

A condition can use only the names bound inside the pattern it is on. It is evaluated in no promised order, and can be evaluated once for several matches that bind its names to the same parts of ``tree$``.

In ``XMLCases[tree$, pattern$, n$]``, ``n$`` is a non-negative integer or ``Infinity``. With ``pattern$ :> rhs$``, ``rhs$`` is evaluated in the order of the results, only for the results given. A condition or test in ``pattern$`` can also be evaluated for elements past the ``n$``-th result.

When ``tree$`` is an ``XMLElement``, the outermost pattern can match it, but it is never itself a result. The root element of an ``XMLObject`` and the elements of a list can be results.

``XMLCases`` issues a message and returns ``$Failed`` when ``tree$`` or ``pattern$`` has none of the forms above, when an ``XMLPattern`` in ``pattern$`` is malformed, or when a name that ``rhs$`` uses has no position, such as a name in an ``XMLElement`` pattern's contents that can match text, whether or not the tree has text there.

The following option can be given:

| option | default | description |
| :--- | :--- | :--- |
| ``"AttributeReadings"`` | ``<\|\|>`` | attributes to split into lists of tokens for this call, in addition to ``$AttributeReadings`` |

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Find every paragraph in an HTML fragment:

```wl
In[1]:= tree = ImportString["<p class=\"lead\">First.</p><p>Second.</p>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern["p"]]

Out[1]= {XMLElement["p", {"class" -> "lead"}, {"First."}], XMLElement["p", {}, {"Second."}]}
```

Find only the paragraphs that have the class lead:

```wl
In[2]:= XMLCases[tree, XMLPattern["p", "classList" -> "lead"]]

Out[2]= {XMLElement["p", {"class" -> "lead"}, {"First."}]}
```

---

Name the href value and use it on the right-hand side:

```wl
In[1]:= tree = ImportString["<ul><li><a href=\"/miso\">Miso</a></li><li><a href=\"/pho\">Pho</a></li></ul>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern["a", "href" -> href_] :> href]

Out[1]= {"/miso", "/pho"}
```

---

Get the date and the name of each bank holiday from one pattern for a table row:

```wl
In[1]:= holidays = ImportString["<table><tr><th><time datetime=\"2026-12-25\">25 December</time></th><td>Friday</td><td>Christmas Day</td></tr><tr><th><time datetime=\"2026-12-28\">28 December</time></th><td>Monday</td><td>Boxing Day</td></tr></table>", {"HTML", "XMLObject"}];
XMLCases[holidays, XMLPattern["tr"][{XMLPattern["th"][{XMLPattern["time", "datetime" -> date_]}], ___, name : XMLPattern["td"]}] :> {date, HTMLTextContent[name]}]

Out[1]= {{"2026-12-25", "Christmas Day"}, {"2026-12-28", "Boxing Day"}}
```

### Scope

---

Search an ``XMLObject`` document:

```wl
In[1]:= tree = ImportString["<article><h1>Menu</h1><ul><li><a href=\"/miso\">Miso</a></li><li><a href=\"/pho\">Pho</a></li></ul></article>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern["a"]]

Out[1]= {XMLElement["a", {"shape" -> "rect", "href" -> "/miso"}, {"Miso"}], XMLElement["a", {"shape" -> "rect", "href" -> "/pho"}, {"Pho"}]}
```

Search an ``XMLElement``:

```wl
In[2]:= listElement = First@XMLCases[tree, XMLPattern["ul"]];
XMLCases[listElement, XMLPattern["a"]]

Out[2]= {XMLElement["a", {"shape" -> "rect", "href" -> "/miso"}, {"Miso"}], XMLElement["a", {"shape" -> "rect", "href" -> "/pho"}, {"Pho"}]}
```

Search a list of elements:

```wl
In[3]:= items = XMLCases[tree, XMLPattern["li"]];
XMLCases[items, XMLPattern["a"]]

Out[3]= {XMLElement["a", {"shape" -> "rect", "href" -> "/miso"}, {"Miso"}], XMLElement["a", {"shape" -> "rect", "href" -> "/pho"}, {"Pho"}]}
```

---

Give several attribute constraints in a list, where a bare key matches any value:

```wl
In[1]:= form = ImportString["<form><input type=\"text\" name=\"q\" required><input type=\"text\" name=\"n\"><input type=\"submit\"></form>", {"HTML", "XMLObject"}];
XMLCases[form, XMLPattern["input", {"type" -> "text", "required"}]]

Out[1]= {XMLElement["input", {"type" -> "text", "name" -> "q", "required" -> "required"}, {}]}
```

---

Match any of several element patterns with ``Alternatives``:

```wl
In[1]:= tree = ImportString["<article><h1>Menu</h1><p>See the <a href=\"/about\">about page</a>.</p></article>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern["h1"] | XMLPattern["a"]]

Out[1]= {XMLElement["h1", {}, {"Menu"}], XMLElement["a", {"shape" -> "rect", "href" -> "/about"}, {"about page"}]}
```

---

Match elements that have either of two classes:

```wl
In[1]:= cards = ImportString["<p class=\"lead promo\">A</p><p class=\"promo ad\">B</p><p>C</p>", {"HTML", "XMLObject"}];
XMLCases[cards, XMLPattern["p", "classList" -> "lead" | "ad"]]

Out[1]= {XMLElement["p", {"class" -> "lead promo"}, {"A"}], XMLElement["p", {"class" -> "promo ad"}, {"B"}]}
```

Match elements that have both of two classes, in any order:

```wl
In[2]:= XMLCases[cards, XMLPattern["p", "classList" -> _?(ContainsAll[{"promo", "ad"}])]]

Out[2]= {XMLElement["p", {"class" -> "promo ad"}, {"B"}]}
```

Match elements that do not have the class ad, including elements with no classes:

```wl
In[3]:= XMLCases[cards, XMLPattern["p", "classList" -> _?(FreeQ["ad"])]]

Out[3]= {XMLElement["p", {"class" -> "lead promo"}, {"A"}], XMLElement["p", {}, {"C"}]}
```

---

Name both the element and its classes:

```wl
In[1]:= cards = ImportString["<p class=\"lead promo\">A</p><p>B</p>", {"HTML", "XMLObject"}];
XMLCases[cards, element : XMLPattern["p", "classList" -> classes_] :> {element, classes}]

Out[1]= {{XMLElement["p", {"class" -> "lead promo"}, {"A"}], {"lead", "promo"}}, {XMLElement["p", {}, {"B"}], {}}}
```

---

Get nested matches in document order, the outer element first:

```wl
In[1]:= nested = ImportString["<div id=\"outer\"><div id=\"inner\">x</div></div>", {"HTML", "XMLObject"}];
XMLCases[nested, XMLPattern["div", "id" -> id_] :> id]

Out[1]= {"outer", "inner"}
```

---

Give a list pattern over the children of an element to get its first child:

```wl
In[1]:= links = ImportString["<p><a href=\"/a\">A</a><a href=\"/b\">B</a><a href=\"/c\">C</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["p"][{x : XMLPattern["a"], ___}] :> HTMLTextContent[x]]

Out[1]= {"A"}
```

Get its last child:

```wl
In[2]:= XMLCases[links, XMLPattern["p"][{___, x : XMLPattern["a"]}] :> HTMLTextContent[x]]

Out[2]= {"C"}
```

Get each child, as the CSS selector ``"p > a"`` does:

```wl
In[3]:= XMLCases[links, XMLPattern["p"][Child[x : XMLPattern["a"]]] :> HTMLTextContent[x]]

Out[3]= {"A", "B", "C"}
```

---

Get two results for two equal values at different positions:

```wl
In[1]:= hrefs = ImportString["<p><a href=\"/x\">one</a><a href=\"/x\">two</a></p>", {"HTML", "XMLObject"}];
XMLCases[hrefs, XMLPattern["a", "href" -> h_] :> h]

Out[1]= {"/x", "/x"}
```

---

Use only ``x`` on the right-hand side to get each link that has a later link, once:

```wl
In[1]:= links = ImportString["<p><a href=\"/a\">A</a><a href=\"/b\">B</a><a href=\"/c\">C</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["p"][{___, x : XMLPattern["a"], ___, y : XMLPattern["a"], ___}] :> HTMLTextContent[x]]

Out[1]= {"A", "B"}
```

Use both names to get each pair:

```wl
In[2]:= XMLCases[links, XMLPattern["p"][{___, x : XMLPattern["a"], ___, y : XMLPattern["a"], ___}] :> {HTMLTextContent[x], HTMLTextContent[y]}]

Out[2]= {{"A", "B"}, {"A", "C"}, {"B", "C"}}
```

Use no name on the right-hand side to get at most one result, which shows whether there is a match:

```wl
In[3]:= XMLCases[links, XMLPattern["a"] :> "found"]

Out[3]= {"found"}
```

---

Give each link inside a nav once, including a link inside two nav elements:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav><a>About</a></nav>", {"HTML", "XMLObject"}];
XMLCases[navs, XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> HTMLTextContent[x]]

Out[1]= {"Home", "News", "About"}
```

Use the name of the nav as well to get one result for each pair of a nav and a link inside it:

```wl
In[2]:= XMLCases[navs, XMLPattern["nav", "id" -> id_][Descendant[x : XMLPattern["a"]]] :> {id, HTMLTextContent[x]}]

Out[2]= {{"outer", "Home"}, {"outer", "News"}, {"outer", "About"}, {"inner", "News"}}
```

Swap the names on the right-hand side; the results stay ordered by the first name in the pattern:

```wl
In[3]:= XMLCases[navs, XMLPattern["nav", "id" -> id_][Descendant[x : XMLPattern["a"]]] :> {HTMLTextContent[x], id}]

Out[3]= {{"Home", "outer"}, {"News", "outer"}, {"About", "outer"}, {"News", "inner"}}
```

---

Use a name twice in one list to require equal values, here the same class as an earlier sibling:

```wl
In[1]:= list = ImportString["<ul><li class=\"x\">1</li><li class=\"y\">2</li><li class=\"x\">3</li></ul>", {"HTML", "XMLObject"}];
XMLCases[list, XMLPattern["ul"][{___, XMLPattern["li", "class" -> c_], ___, item : XMLPattern["li", "class" -> c_], ___}] :> HTMLTextContent[item]]

Out[1]= {"3"}
```

---

Put a condition on an element pattern to select lists with at least two items:

```wl
In[1]:= menu = ImportString["<ul><li>Miso</li><li>Pho</li></ul><ol><li>Ramen</li></ol>", {"HTML", "XMLObject"}];
XMLCases[menu, (list : XMLPattern["ul" | "ol"]) /; Count[list[[3]], _XMLElement] >= 2]

Out[1]= {XMLElement["ul", {}, {XMLElement["li", {}, {"Miso"}], XMLElement["li", {}, {"Pho"}]}]}
```

---

Put a condition on the right-hand side to keep each item that some later item exceeds:

```wl
In[1]:= ranks = ImportString["<ol><li>3</li><li>1</li><li>2</li></ol>", {"HTML", "XMLObject"}];
rank[item_] := ToExpression[HTMLTextContent[item]];
XMLCases[ranks, XMLPattern["ol"][{___, x : XMLPattern["li"], ___, y : XMLPattern["li"], ___}] :> HTMLTextContent[x] /; rank[x] < rank[y]]

Out[1]= {"1"}
```

---

Match the ``XMLElement`` given as the tree, and give the elements below it:

```wl
In[1]:= section = XMLElement["section", {}, {XMLElement["p", {}, {"Direct"}], XMLElement["div", {}, {XMLElement["p", {}, {"Nested"}]}]}];
XMLCases[section, XMLPattern["section"][Child[x : XMLPattern["p"]]] :> x]

Out[1]= {XMLElement["p", {}, {"Direct"}]}
```

Check that the tree itself is never a result:

```wl
In[2]:= XMLCases[section, XMLPattern["section"]]

Out[2]= {}
```

---

Give the links not inside a nav, with a test on the elements above each link:

```wl
In[1]:= page = ImportString["<body><nav><a href=\"/\">Home</a></nav><p>See <a href=\"/about\">About</a>.</p></body>", {"HTML", "XMLObject"}];
XMLCases[page, XMLDocument[Descendant[x : XMLPattern["a"]]?(NoneTrue[XMLMatchQ["nav"]])] :> HTMLTextContent[x]]

Out[1]= {"About"}
```

---

Name a ``Descendant`` constraint to get the elements between the outer element and the match:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav><a>About</a></nav>", {"HTML", "XMLObject"}];
XMLCases[navs, XMLPattern["nav", "id" -> "outer"][path : Descendant[x : XMLPattern["a"]]] :> {HTMLTextContent[x], Length[path] + 1}]

Out[1]= {{"Home", 1}, {"News", 2}, {"About", 1}}
```

---

Pair each link with only its nearest enclosing nav by wrapping ``Descendant`` in ``Shortest``:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav><a>About</a></nav>", {"HTML", "XMLObject"}];
XMLCases[navs, XMLPattern["nav", "id" -> id_][Shortest@Descendant[x : XMLPattern["a"]]] :> {id, HTMLTextContent[x]}]

Out[1]= {{"outer", "Home"}, {"outer", "About"}, {"inner", "News"}}
```

---

Get ``Sequence[]`` for a name bound only in an alternative that did not match:

```wl
In[1]:= items = ImportString["<ul><li><span>s</span></li><li><a>a</a></li></ul>", {"HTML", "XMLObject"}];
XMLCases[items, XMLPattern["li"][{(x : XMLPattern["a"]) | (y : XMLPattern["span"])}] :> {x, y}]

Out[1]= {{XMLElement["span", {}, {"s"}]}, {XMLElement["a", {"shape" -> "rect"}, {"a"}]}}
```

---

Give only the first two results, in order:

```wl
In[1]:= tree = ImportString["<ol><li>Miso</li><li>Pho</li><li>Ramen</li><li>Udon</li></ol>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern["li"], 2]

Out[1]= {XMLElement["li", {}, {"Miso"}], XMLElement["li", {}, {"Pho"}]}
```

Get all the results when there are fewer than the count:

```wl
In[2]:= XMLCases[tree, XMLPattern["li"], 10]

Out[2]= {XMLElement["li", {}, {"Miso"}], XMLElement["li", {}, {"Pho"}], XMLElement["li", {}, {"Ramen"}], XMLElement["li", {}, {"Udon"}]}
```

Use ``Sow`` to see that the right-hand side is evaluated only for the results given:

```wl
In[3]:= Reap[XMLCases[tree, item : XMLPattern["li"] :> Sow[HTMLTextContent[item]], 2]]

Out[3]= {{"Miso", "Pho"}, {{"Miso", "Pho"}}}
```

---

Give a CSS selector string as the pattern to get the elements it selects:

```wl
In[1]:= notes = ImportString["<div class=\"note\"><p>Read me.</p></div><div><p>Skip me.</p></div>", {"HTML", "XMLObject"}];
XMLCases[notes, "div.note > p"]

Out[1]= {XMLElement["p", {}, {"Read me."}]}
```

Name the selected element on the left of a rule:

```wl
In[2]:= XMLCases[notes, n : "div.note > p" :> HTMLTextContent[n]]

Out[2]= {"Read me."}
```

---

Give a CSS selector list to get each element that it selects once, in document order:

```wl
In[1]:= page = ImportString["<body><nav><a href=\"/\">Home</a></nav><ul><li>Miso</li><li>Pho</li></ul></body>", {"HTML", "XMLObject"}];
XMLCases[page, "nav a, ul > li"]

Out[1]= {XMLElement["a", {"shape" -> "rect", "href" -> "/"}, {"Home"}], XMLElement["li", {}, {"Miso"}], XMLElement["li", {}, {"Pho"}]}
```

### Options

#### AttributeReadings

---

Split rel into tokens, and match one with the list key "relList", whose value is the list of tokens:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow noopener\" href=\"/x\">x</a><a rel=\"noopener\" href=\"/y\">y</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["a", "relList" -> "nofollow"], "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= {XMLElement["a", {"shape" -> "rect", "rel" -> "nofollow noopener", "href" -> "/x"}, {"x"}]}
```

Without the option, "relList" is an ordinary attribute name, which no element has:

```wl
In[2]:= XMLCases[links, XMLPattern["a", "relList" -> "nofollow"]]

During evaluation of In[2]:= XMLPattern::nolistreading: "rel" has no entry in $AttributeReadings, so the key "relList" is matched as an attribute of that name. To split "rel" into tokens, add an entry: $AttributeReadings["rel"] = <||> for the session, or "AttributeReadings" -> <|"rel" -> <||>|> in the call.

Out[2]= {}
```

### Applications

---

Scrape every link target from the 1989 proposal that founded the web:

```wl
In[1]:= tree = Import["https://www.w3.org/History/1989/proposal.html", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern["a", "href" -> href_] :> href]

Out[1]= {"../../DesignIssues/OldDocs.html", "proposal", "proposal.rtf", "proposal-msw.html"}
```

Tally the tags used in the document:

```wl
In[2]:= ReverseSortBy[Tally@XMLCases[tree, element : XMLPattern[_] :> element[[1]]], Last]

Out[2]= {{"p", 81}, {"li", 25}, {"h3", 19}, {"small", 18}, {"td", 17}, {"dt", 16}, {"dd", 16}, {"h2", 12}, {"tr", 8}, {"center", 8}, {"i", 6}, {"ul", 5}, {"pre", 4}, {"img", 4}, {"a", 4}, {"th", 3}, {"tbody", 3}, {"table", 3}, {"kbd", 2}, {"dl", 2}, {"b", 2}, {"title", 1}, {"html", 1}, {"hr", 1}, {"head", 1}, {"h1", 1}, {"br", 1}, {"body", 1}, {"address", 1}}
```

---

List the distinct classes used on a page:

```wl
In[1]:= page = ImportString["<div class=\"card featured\"><p class=\"lead\">A</p><p class=\"lead promo\">B</p></div>", {"HTML", "XMLObject"}];
Union@Flatten@XMLCases[page, XMLPattern[_, "classList" -> classes_] :> classes]

Out[1]= {"card", "featured", "lead", "promo"}
```

---

Count the matches with ``Length`` and a bare pattern:

```wl
In[1]:= links = ImportString["<p><a href=\"/a\">A</a><a href=\"/b\">B</a><a href=\"/c\">C</a></p>", {"HTML", "XMLObject"}];
Length[XMLCases[links, XMLPattern["a"]]]

Out[1]= 3
```

### Properties & Relations

---

``XMLCases`` gives an element before the elements nested in it, and ``Cases`` gives it after them:

```wl
In[1]:= nested = ImportString["<div id=\"outer\"><div id=\"inner\">x</div></div>", {"HTML", "XMLObject"}];
{XMLCases[nested, XMLPattern["div", "id" -> id_] :> id], Cases[nested, XMLElement["div", {"id" -> id_}, _] :> id, Infinity]}

Out[1]= {{"outer", "inner"}, {"inner", "outer"}}
```

---

A bare pattern gives the same results as the pattern named and used on the right-hand side:

```wl
In[1]:= tree = ImportString["<p class=\"lead\">a</p><div><p>b</p></div>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern["p"]] === XMLCases[tree, x : XMLPattern["p"] :> x]

Out[1]= True
```

---

``XMLCases`` gives the elements for which ``XMLMatchQ`` gives ``True``:

```wl
In[1]:= tree = ImportString["<p class=\"lead\">a</p><div><p>b</p></div>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern["p"]] === Select[XMLCases[tree, XMLPattern[_]], XMLMatchQ[XMLPattern["p"]]]

Out[1]= True
```

``XMLFirstCase`` gives the first element of the ``XMLCases`` result:

```wl
In[2]:= XMLFirstCase[tree, XMLPattern["p"]] === First@XMLCases[tree, XMLPattern["p"]]

Out[2]= True
```

A name at "classList" gives the same list as ``HTMLClassList``:

```wl
In[3]:= XMLCases[tree, XMLPattern["p", "classList" -> classes_] :> classes] === (HTMLClassList /@ XMLCases[tree, XMLPattern["p"]])

Out[3]= True
```

After ``XMLDeleteCases`` removes the matches, ``XMLCases`` finds none:

```wl
In[4]:= XMLCases[XMLDeleteCases[tree, XMLPattern["p"]], XMLPattern["p"]]

Out[4]= {}
```

---

``XMLPosition`` gives the positions of the results, and ``XMLExtract`` the parts there:

```wl
In[1]:= tree = ImportString["<p class=\"lead\">a</p><div><p>b</p></div>", {"HTML", "XMLObject"}];
XMLExtract[tree, XMLPosition[tree, XMLPattern["p"]]] === XMLCases[tree, XMLPattern["p"]]

Out[1]= True
```

---

``XMLCases[tree$, pattern$, 1]`` gives in a list what ``XMLFirstCase`` gives:

```wl
In[1]:= tree = ImportString["<section><div id=\"outer\"><div id=\"inner\"></div></div><div id=\"last\"></div></section>", {"HTML", "XMLObject"}];
{XMLCases[tree, XMLPattern["div", "id" -> id_] :> id, 1], XMLFirstCase[tree, XMLPattern["div", "id" -> id_] :> id]}

Out[1]= {{"outer"}, "outer"}
```

### Possible Issues

---

``Cases`` gives one result for each match:

```wl
In[1]:= Cases[{a, a}, _ -> 1]

Out[1]= {1, 1}
```

``XMLCases`` gives at most one result when the right-hand side uses no name:

```wl
In[2]:= links = ImportString["<p><a href=\"/a\">A</a><a href=\"/b\">B</a><a href=\"/c\">C</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["a"] -> 1]

Out[2]= {1}
```

With no match, there is no result:

```wl
In[3]:= XMLCases[ImportString["<p>No links.</p>", {"HTML", "XMLObject"}], XMLPattern["a"] -> 1]

Out[3]= {}
```

Naming the element does not change this when the right-hand side does not use the name:

```wl
In[4]:= XMLCases[links, x : XMLPattern["a"] :> 1]

Out[4]= {1}
```

Use the name to get one result for each link:

```wl
In[5]:= XMLCases[links, x : XMLPattern["a"] :> x]

Out[5]= {XMLElement["a", {"shape" -> "rect", "href" -> "/a"}, {"A"}], XMLElement["a", {"shape" -> "rect", "href" -> "/b"}, {"B"}], XMLElement["a", {"shape" -> "rect", "href" -> "/c"}, {"C"}]}
```

A bare pattern also gives each link:

```wl
In[6]:= XMLCases[links, XMLPattern["a"]]

Out[6]= {XMLElement["a", {"shape" -> "rect", "href" -> "/a"}, {"A"}], XMLElement["a", {"shape" -> "rect", "href" -> "/b"}, {"B"}], XMLElement["a", {"shape" -> "rect", "href" -> "/c"}, {"C"}]}
```

---

A CSS selector in a rule that uses no name also gives at most one result:

```wl
In[1]:= hrefs = ImportString["<p><a href=\"/x\">one</a><a href=\"/x\">two</a><a>three</a></p>", {"HTML", "XMLObject"}];
XMLCases[hrefs, "a[href]" :> 1]

Out[1]= {1}
```

Naming the selected element does not change this when the name is not used:

```wl
In[2]:= XMLCases[hrefs, n : "a[href]" :> 1]

Out[2]= {1}
```

Use the name to get each link that has an href:

```wl
In[3]:= XMLCases[hrefs, n : "a[href]" :> n]

Out[3]= {XMLElement["a", {"shape" -> "rect", "href" -> "/x"}, {"one"}], XMLElement["a", {"shape" -> "rect", "href" -> "/x"}, {"two"}]}
```

The selector alone also gives each link:

```wl
In[4]:= XMLCases[hrefs, "a[href]"]

Out[4]= {XMLElement["a", {"shape" -> "rect", "href" -> "/x"}, {"one"}], XMLElement["a", {"shape" -> "rect", "href" -> "/x"}, {"two"}]}
```

---

``Cases`` and ``MatchQ`` treat an ``XMLPattern`` as a literal expression:

```wl
In[1]:= tree = ImportString["<p>hello</p>", {"HTML", "XMLObject"}];
{Cases[tree, XMLPattern["p"], Infinity], MatchQ[First@XMLCases[tree, XMLPattern["p"]], XMLPattern["p"]]}

Out[1]= {{}, False}
```

Use ``XMLCases`` and ``XMLMatchQ``:

```wl
In[2]:= {XMLCases[tree, XMLPattern["p"]], XMLMatchQ[First@XMLCases[tree, XMLPattern["p"]], XMLPattern["p"]]}

Out[2]= {{XMLElement["p", {}, {"hello"}]}, True}
```

---

``XMLPattern["hello"]`` matches elements with the tag hello, which this tree does not have:

```wl
In[1]:= tree = ImportString["<p>hello</p>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern["hello"]]

Out[1]= {}
```

---

A match nested in another match is also returned, after the outer one:

```wl
In[1]:= nested = ImportString["<div id=\"outer\"><div id=\"inner\">x</div></div>", {"HTML", "XMLObject"}];
XMLCases[nested, XMLPattern["div"]]

Out[1]= {XMLElement["div", {"id" -> "outer"}, {XMLElement["div", {"id" -> "inner"}, {"x"}]}], XMLElement["div", {"id" -> "inner"}, {"x"}]}
```

---

Whitespace is kept in the contents, but a list pattern over the children skips text:

```wl
In[1]:= tree = ImportString["<div><p>a</p>\n<p>b</p></div>", {"HTML", "XMLObject"}];
{First[XMLCases[tree, XMLPattern["div"]]][[3]], XMLCases[tree, XMLPattern["div"][{XMLPattern["p"], x : XMLPattern["p"]}] :> x]}

Out[1]= {{XMLElement["p", {}, {"a"}], "\n", XMLElement["p", {}, {"b"}]}, {XMLElement["p", {}, {"b"}]}}
```

---

A condition on a pattern cannot use a name bound later in the pattern, so this matches nothing:

```wl
In[1]:= ranks = ImportString["<ol><li>3</li><li>1</li><li>2</li></ol>", {"HTML", "XMLObject"}];
rank[XMLElement[_, _, {s_String}]] := ToExpression[s];
XMLCases[ranks, XMLPattern["ol"][{___, (x : XMLPattern["li"]) /; rank[x] < rank[y], ___, y : XMLPattern["li"], ___}] :> HTMLTextContent[x]]

Out[1]= {}
```

Put the condition on a pattern that contains both names:

```wl
In[2]:= XMLCases[ranks, XMLPattern["ol"][{___, x : XMLPattern["li"], ___, y : XMLPattern["li"], ___} /; rank[x] < rank[y]] :> HTMLTextContent[x]]

Out[2]= {"1"}
```

---

The function of a ``PatternTest`` cannot use pattern names:

```wl
In[1]:= doc = ImportString["<div id=\"a\"><p id=\"a\">one</p><p id=\"x\">two</p></div>", {"HTML", "XMLObject"}];
XMLCases[doc, XMLPattern["div", "id" -> d_][Descendant[x : XMLPattern["p", "id" -> _?(# === d &)]]] :> x]

Out[1]= {}
```

Use the name again to require an equal value:

```wl
In[2]:= XMLCases[doc, XMLPattern["div", "id" -> d_][Descendant[x : XMLPattern["p", "id" -> d_]]] :> x]

Out[2]= {XMLElement["p", {"id" -> "a"}, {"one"}]}
```

---

A name for text cannot be a result, since text has no position of its own:

```wl
In[1]:= row = ImportString["<table><tr><th>Mon</th><td>Mon</td></tr></table>", {"HTML", "XMLObject"}];
XMLCases[row, XMLPattern["tr"][{XMLElement["th", _, {t_String}], ___}] :> t]

During evaluation of In[1]:= XMLCases::text: The name t can match text inside an XMLElement pattern, and text has no position, so the name cannot be a result. Give it a pattern that matches only elements, such as t_XMLElement, name the element that holds the text instead, or use the name only in a test.

Out[1]= $Failed
```

Name the element that holds the text:

```wl
In[2]:= XMLCases[row, XMLPattern["tr"][{h : XMLElement["th", _, {_String}], ___}] :> HTMLTextContent[h]]

Out[2]= {"Mon"}
```

---

A name bound inside ``Except`` has no value on the right-hand side:

```wl
In[1]:= links = ImportString["<p><b>x</b><a href=\"/a\">A</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["p"][{Except[x : XMLPattern["a"]] ..., ___}] :> x]

During evaluation of In[1]:= XMLCases::exceptname: The name x is bound inside Except, which matches only where its pattern does not, so it has no value in the right-hand side. A name inside Except can be used only by tests inside that Except.

Out[1]= $Failed
```

---

``XMLCases`` issues a message for a malformed ``XMLPattern``, such as one with a string pattern:

```wl
In[1]:= tree = ImportString["<p class=\"col-6\">x</p>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern["p", "classList" -> "col-" ~~ __]]

During evaluation of In[1]:= XMLPattern::strpat: "col-"~~__ is a string pattern, and in an XMLPattern it does not match any string. Write _?(StringMatchQ["col-"~~__]) instead.

Out[1]= $Failed
```

Write a string test as a ``PatternTest``:

```wl
In[2]:= XMLCases[tree, XMLPattern["p", "classList" -> _?(AnyTrue[StringStartsQ["col-"]])]]

Out[2]= {XMLElement["p", {"class" -> "col-6"}, {"x"}]}
```

---

``UpTo`` is not accepted as the count, as in ``StringCases``:

```wl
In[1]:= tree = XMLElement["ol", {}, {XMLElement["li", {}, {"Miso"}], XMLElement["li", {}, {"Pho"}]}];
XMLCases[tree, XMLPattern["li"], UpTo[2]]

During evaluation of In[1]:= XMLCases::innf: Non-negative integer or Infinity expected at position 3 in XMLCases[XMLElement["ol", {}, {XMLElement["li", {}, {"Miso"}], XMLElement["li", {}, {"Pho"}]}], XMLPattern["li"], UpTo[2]].

Out[1]= XMLCases[XMLElement["ol", {}, {XMLElement["li", {}, {"Miso"}], XMLElement["li", {}, {"Pho"}]}], XMLPattern["li"], UpTo[2]]
```

Give the count as an integer:

```wl
In[2]:= XMLCases[tree, XMLPattern["li"], 2]

Out[2]= {XMLElement["li", {}, {"Miso"}], XMLElement["li", {}, {"Pho"}]}
```

---

``Child[a, b]`` is not a pattern, and gives a message:

```wl
In[1]:= tree = ImportString["<p><a href=\"/about\">About</a></p><ul><li><a href=\"/miso\">Miso</a></li></ul>", {"HTML", "XMLObject"}];
XMLCases[tree, Child[XMLPattern["li"], XMLPattern["a"]]]

During evaluation of In[1]:= Child::place: Child[XMLPattern["li"], XMLPattern["a"]] is not a pattern. Child is a constraint, which can only be an argument of the bracket after XMLPattern[tag, attrs] or of XMLDocument: XMLPattern["ul"][Child[x : XMLPattern["li"]]] :> x gives the li children of each ul. Child takes one pattern: for children that match several patterns, give several constraints, Child[a], Child[b], or a list, {___, a, ___, b, ___}.

Out[1]= $Failed
```

Give ``Child`` as a constraint inside the bracket, and name what to give:

```wl
In[2]:= XMLCases[tree, XMLPattern["li"][Child[x : XMLPattern["a"]]] :> x]

Out[2]= {XMLElement["a", {"shape" -> "rect", "href" -> "/miso"}, {"Miso"}]}
```

---

An unnamed selector such as ``"nav a"`` gives a message on the left of a rule:

```wl
In[1]:= page = ImportString["<body><nav><a href=\"/\">Home</a></nav><p>See <a href=\"/about\">About</a>.</p></body>", {"HTML", "XMLObject"}];
XMLCases[page, "nav a" :> 1]

During evaluation of In[1]:= XMLCases::badpat: The second argument should be a pattern, or a rule pattern -> rhs or pattern :> rhs. A pattern is an XMLPattern, which can take constraints on the elements below it, an XMLDocument pattern, an XMLElement pattern, or a CSS selector string, or alternatives of these, any of them named, with a condition pat /; test or a test pat?f. A CSS selector that depends on what is above or beside the element it selects, such as "nav a", gives that element when given alone; on the left of a rule, name the element, as in n : "nav a" :> n. Got "nav a".

Out[1]= $Failed
```

Name the selected element:

```wl
In[2]:= XMLCases[page, n : "nav a" :> HTMLTextContent[n]]

Out[2]= {"Home"}
```

---

A test in the pattern can be evaluated for elements past the count:

```wl
In[1]:= list = ImportString["<ul><li>Miso</li><li>Pho</li><li>Ramen</li></ul>", {"HTML", "XMLObject"}];
Reap[XMLCases[list, XMLPattern["li"]?((Sow[HTMLTextContent[#]]; True) &), 2]]

Out[1]= {{XMLElement["li", {}, {"Miso"}], XMLElement["li", {}, {"Pho"}]}, {{"Miso", "Pho", "Ramen"}}}
```

## See Also

* [XMLFirstCase](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFirstCase)

* [XMLPosition](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPosition)

* [XMLExtract](paclet:MaximilienTirard/HTMLPatterns/ref/XMLExtract)

* [XMLDeleteCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDeleteCases)

* [XMLReplace](paclet:MaximilienTirard/HTMLPatterns/ref/XMLReplace)

* [XMLMatchQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLMatchQ)

* [XMLFreeQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFreeQ)

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [Descendant](paclet:MaximilienTirard/HTMLPatterns/ref/Descendant)

* [Child](paclet:MaximilienTirard/HTMLPatterns/ref/Child)

* [XMLDocument](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDocument)

* [FromCSSSelector](paclet:MaximilienTirard/HTMLPatterns/ref/FromCSSSelector)

* [HTMLClassList](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLClassList)

* [$AttributeReadings](paclet:MaximilienTirard/HTMLPatterns/ref/$AttributeReadings)

* [HTMLTextContent](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLTextContent)

* [HTMLToTree](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLToTree)

* [Cases](paclet:ref/Cases)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
