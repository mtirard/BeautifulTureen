# XMLPattern

   ``XMLPattern[tag$]`` is an XML pattern that represents any ``XMLElement`` whose tag matches ``tag$``.
   ``XMLPattern[tag$, attrs$]`` represents any ``XMLElement`` whose tag matches ``tag$`` and whose attributes match ``attrs$``.
   ``XMLPattern[tag$][c$1, c$2, $$]`` represents any ``XMLElement`` whose tag matches ``tag$`` and below which each constraint ``c$i`` is met, such as a list pattern over its element children, ``Child[p$]`` or ``Descendant[p$]``.
   ``XMLPattern[tag$, attrs$][c$1, c$2, $$]`` also requires the attributes to match ``attrs$``.

## Details and Options

``XMLPattern`` is not an ordinary pattern: ``MatchQ``, ``Cases``, ``ReplaceAll``, etc. treat it as a literal expression. Only the functions of this paclet interpret it, such as ``XMLCases`` and ``XMLMatchQ``.

``tag$`` may have the following forms:

| form | description |
| :--- | :--- |
| ``"name"`` | an element with the tag ``"name"`` |
| ``{namespace$, name$}`` | an element with a namespaced tag |
| ``"h1" \| "h2"`` | an element with any of the given tags |
| ``patt$`` | an element whose tag matches the pattern ``patt$``, such as ``_``, ``t_`` or ``_?(StringMatchQ["h" ~~ DigitCharacter])`` |

``attrs$`` may have the following forms:

| form | description |
| :--- | :--- |
| ``_`` | any attributes, the same as leaving out ``attrs$`` |
| ``key$ -> val$`` | an attribute ``key$`` whose value matches ``val$`` |
| ``key$`` | an attribute ``key$`` with any value, equivalent to ``key$ -> _`` |
| ``{{ns$, name$}}`` | a namespaced attribute with any value |
| ``{a$1, a$2, $$}`` | attributes that match each of ``a$1``, ``a$2``, etc. |

The order of the attribute constraints ``a$i`` does not matter, and the element may have other attributes as well.

A value may be any pattern. It is matched against the whole attribute value, so ``"class" -> "lead"`` matches ``class="lead"`` but not ``class="lead intro"``.

A key must be a string, a ``{namespace$, name$}`` pair, or alternatives of these, such as ``("href" | "src") -> url_``. A pattern such as ``_`` or ``_?StringQ`` cannot be a key.

``attrs$`` may also be named or tested as a whole, as in ``attrs : {"id" -> _}`` or ``_?(Keys /* AnyTrue[StringStartsQ["data-"]])``.

A **list key** is a key, such as ``"classList"``, whose value is a list of tokens taken from an attribute. For ``"classList"``, the list is the value of ``class`` split on ``HTMLWhitespace``, or ``{}`` for an element without classes. Entries in ``$AttributeReadings`` add list keys for other attributes.

At a list key, a string, or alternatives of strings, matches one token among several: ``"classList" -> "lead"`` matches any element that has the class ``lead``. Any other value is matched against the whole list, as in ``"classList" -> {"lead", ___}`` for a first class ``lead``, or ``"classList" -> c_``, which binds ``c`` to the list.

To check for classes in any order, use functions such as ``MemberQ``, ``FreeQ``, ``ContainsAll`` and ``ContainsNone``. The following table gives some CSS class selectors and their equivalents:

| CSS | ``attrs$`` |
| :--- | :--- |
| ``.a`` | ``"classList" -> "a"`` |
| ``.a.b`` | ``"classList" -> _?(ContainsAll[{"a", "b"}])`` |
| ``.a, .b`` | ``"classList" -> "a" \| "b"`` |
| ``:not(.a)`` | ``"classList" -> _?(FreeQ["a"])`` |
| ``[class]`` | ``"class"`` |
| ``:not([class])`` | ``_?(FreeQ["class" -> _])`` |

A **constraint** is a condition on what is below an element. ``XMLPattern[tag$, attrs$][c$1, c$2, $$]`` matches an element when each constraint ``c$i`` holds below it, so patterns are nested as the document is.

A constraint ``c$i`` may have the following forms:

| form | description |
| :--- | :--- |
| ``{p$1, p$2, $$}`` | the element children, text left out, match the list pattern |
| ``Child[p$]`` | some element child matches ``p$``, the same as ``{___, p$, ___}`` |
| ``Descendant[p$]`` | some element anywhere below matches ``p$`` |
| ``Descendant[p$, levelspec$]`` | some element at the depths in ``levelspec$`` matches ``p$``, with the children at depth 1 |
| ``Alternatives[c$1, c$2]`` | either constraint holds |

All the constraints must hold, in any order. They are independent, so one element below may meet several of them. A name used in two constraints must match the same part in both.

An entry of a list pattern can be an ``XMLPattern``, an ``XMLElement`` pattern, a CSS selector for one element, ``_`` for any one element child, or a sequence pattern such as ``___``, ``Repeated`` or ``PatternSequence``. So ``{x : XMLPattern["li"], ___}`` matches an element whose first element child is an ``li``.

A list pattern can be named, as in ``s : {___}``, have a condition, or have a test.

A name inside a constraint can be bound to an element below, to its attributes, to a run of children, etc. Use it on the right-hand side of a rule in functions such as ``XMLCases``.

A CSS selector for one element, one that depends only on its element and what is below it, such as ``"ul.menu"``, can be given in place of an ``XMLPattern``. It takes constraints in the same way, as in ``"ul.menu"[{x : "li", ___}]``. ``FromCSSSelector`` gives the ``XMLPattern`` for a selector.

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Test whether an element has a given tag:

```wl
In[1]:= XMLMatchQ[XMLElement["p", {}, {"text"}], XMLPattern["p"]]

Out[1]= True
```

---

Collect the target of every link that has one:

```wl
In[1]:= nav = ImportString["<nav><a class=\"btn primary\" href=\"/buy\">Buy</a><a class=\"btn\">Disabled</a><a href=\"/about\">About</a></nav>", {"HTML", "XMLObject"}];
XMLCases[nav, XMLPattern["a", "href" -> href_] :> href]

Out[1]= {"/buy", "/about"}
```

---

Find the links that have the class ``btn``:

```wl
In[1]:= nav = ImportString["<nav><a class=\"btn primary\" href=\"/buy\">Buy</a><a class=\"btn\">Disabled</a><a href=\"/about\">About</a></nav>", {"HTML", "XMLObject"}];
XMLCases[nav, XMLPattern["a", "classList" -> "btn"]]

Out[1]= {XMLElement["a", {"shape" -> "rect", "class" -> "btn primary", "href" -> "/buy"}, {"Buy"}], XMLElement["a", {"shape" -> "rect", "class" -> "btn"}, {"Disabled"}]}
```

---

Give constraints on the children of the element in a second bracket, and name the child to give:

```wl
In[1]:= menu = ImportString["<ul><li>Miso</li><li>Pho</li></ul><ol><li>Ramen</li></ol>", {"HTML", "XMLObject"}];
XMLCases[menu, XMLPattern["ul"][Child[x : XMLPattern["li"]]] :> HTMLTextContent[x]]

Out[1]= {"Miso", "Pho"}
```

### Scope

#### Tags

---

Match several tags with an ``Alternatives``:

```wl
In[1]:= tree = ImportString["<article><h1>Title</h1><h2>Sub</h2><p>Body</p></article>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern["h1" | "h2"]]

Out[1]= {XMLElement["h1", {}, {"Title"}], XMLElement["h2", {}, {"Sub"}]}
```

Bind the tag of every element with a named pattern:

```wl
In[2]:= XMLCases[tree, XMLPattern[t_] :> t]

Out[2]= {"article", "h1", "h2", "p"}
```

Test the tag with ``StringMatchQ``:

```wl
In[3]:= XMLCases[tree, XMLPattern[_?(StringMatchQ["h" ~~ DigitCharacter])]]

Out[3]= {XMLElement["h1", {}, {"Title"}], XMLElement["h2", {}, {"Sub"}]}
```

#### Attribute Constraints

---

Match one attribute with a rule:

```wl
In[1]:= form = ImportString["<form><input type=\"text\" name=\"q\" required><input type=\"checkbox\" name=\"ok\"><input type=\"search\" name=\"s\"></form>", {"HTML", "XMLObject"}];
XMLCases[form, XMLPattern["input", "type" -> "search"]]

Out[1]= {XMLElement["input", {"type" -> "search", "name" -> "s"}, {}]}
```

Give several constraints as a list to match all of them:

```wl
In[2]:= XMLCases[form, XMLPattern["input", {"type" -> "text", "required"}]]

Out[2]= {XMLElement["input", {"type" -> "text", "name" -> "q", "required" -> "required"}, {}]}
```

Give a key alone to match an attribute with any value:

```wl
In[3]:= XMLCases[form, XMLPattern["input", "required"]]

Out[3]= {XMLElement["input", {"type" -> "text", "name" -> "q", "required" -> "required"}, {}]}
```

---

Match either of two keys with an ``Alternatives``:

```wl
In[1]:= media = ImportString["<p><img src=\"/a.png\"><a href=\"/b\">b</a></p>", {"HTML", "XMLObject"}];
XMLCases[media, XMLPattern[_, ("href" | "src") -> url_] :> url]

Out[1]= {"/a.png", "/b"}
```

---

Give a namespaced key as a ``{namespace, name}`` pair:

```wl
In[1]:= svg = XMLElement["svg", {}, {XMLElement["use", {{"http://www.w3.org/1999/xlink", "href"} -> "#icon"}, {}]}];
XMLCases[svg, XMLPattern["use", {"http://www.w3.org/1999/xlink", "href"} -> target_] :> target]

Out[1]= {"#icon"}
```

To match any value, give a namespaced key alone inside a list:

```wl
In[2]:= XMLCases[svg, XMLPattern["use", {{"http://www.w3.org/1999/xlink", "href"}}]]

Out[2]= {XMLElement["use", {{"http://www.w3.org/1999/xlink", "href"} -> "#icon"}, {}]}
```

---

Name the attributes as a whole:

```wl
In[1]:= divs = ImportString["<div id=\"a\" data-x=\"1\">A</div><div id=\"b\">B</div>", {"HTML", "XMLObject"}];
XMLCases[divs, XMLPattern["div", attrs : {"id" -> _}] :> attrs]

Out[1]= {{"id" -> "a", "data-x" -> "1"}, {"id" -> "b"}}
```

Test the attributes as a whole, here for some ``data-*`` attribute:

```wl
In[2]:= XMLCases[divs, XMLPattern["div", _?(Keys/*AnyTrue[StringStartsQ["data-"]])]]

Out[2]= {XMLElement["div", {"id" -> "a", "data-x" -> "1"}, {"A"}]}
```

---

Compare two attribute values in a condition on the whole pattern:

```wl
In[1]:= links = ImportString["<p><a href=\"/buy\" data-id=\"buy\">Buy</a><a href=\"/help\" data-id=\"faq\">Help</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["a", {"href" -> h_, "data-id" -> i_}] /; StringContainsQ[h, i] :> h]

Out[1]= {"/buy"}
```

#### Values

---

Match any of several values with an ``Alternatives``:

```wl
In[1]:= form = ImportString["<form><input type=\"text\" name=\"q\" required><input type=\"checkbox\" name=\"ok\"><input type=\"search\" name=\"s\"></form>", {"HTML", "XMLObject"}];
XMLCases[form, XMLPattern["input", {"type" -> "text" | "search", "name" -> name_}] :> name]

Out[1]= {"q", "s"}
```

---

Test a value with a predicate:

```wl
In[1]:= links = ImportString["<p><a href=\"https://w3.org\">W3C</a><a href=\"/about\">About</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["a", "href" -> _?(StringStartsQ["https:"])]]

Out[1]= {XMLElement["a", {"shape" -> "rect", "href" -> "https://w3.org"}, {"W3C"}]}
```

---

At a key such as ``"class"``, a string matches only the whole value:

```wl
In[1]:= nav = ImportString["<nav><a class=\"btn primary\" href=\"/buy\">Buy</a><a class=\"btn\">Disabled</a><a href=\"/about\">About</a></nav>", {"HTML", "XMLObject"}];
XMLCases[nav, XMLPattern["a", "class" -> "btn"]]

Out[1]= {XMLElement["a", {"shape" -> "rect", "class" -> "btn"}, {"Disabled"}]}
```

#### List Keys

---

At the list key ``"classList"``, a string matches one class among several:

```wl
In[1]:= items = ImportString["<ul><li class=\"item active\">A</li><li class=\"item\">B</li><li class=\"item disabled\">C</li><li>D</li></ul>", {"HTML", "XMLObject"}];
XMLCases[items, e : XMLPattern["li", "classList" -> "active"] :> HTMLTextContent[e]]

Out[1]= {"A"}
```

Match either of two classes with an ``Alternatives``:

```wl
In[2]:= XMLCases[items, e : XMLPattern["li", "classList" -> "active" | "disabled"] :> HTMLTextContent[e]]

Out[2]= {"A", "C"}
```

Bind the class list of each element:

```wl
In[3]:= XMLCases[items, XMLPattern["li", "classList" -> classes_] :> classes]

Out[3]= {{"item", "active"}, {"item"}, {"item", "disabled"}, {}}
```

Match elements that have no class:

```wl
In[4]:= XMLCases[items, e : XMLPattern["li", "classList" -> {}] :> HTMLTextContent[e]]

Out[4]= {"D"}
```

---

Bind the first class with a list pattern:

```wl
In[1]:= grid = ImportString["<div class=\"row\"><div class=\"col-6 lead\">A</div><div class=\"col-md-4\">B</div><div class=\"lead\">C</div><div>D</div></div>", {"HTML", "XMLObject"}];
XMLCases[grid, XMLPattern["div", "classList" -> {first_, ___}] :> first]

Out[1]= {"row", "col-6", "col-md-4", "lead"}
```

Match elements with exactly two classes:

```wl
In[2]:= XMLCases[grid, e : XMLPattern["div", "classList" -> {_, _}] :> HTMLTextContent[e]]

Out[2]= {"A"}
```

Combine tests on the list with a ``Condition`` in the value:

```wl
In[3]:= XMLCases[grid, e : XMLPattern["div", "classList" -> c_ /; MemberQ[c, "lead"] && FreeQ[c, "col-6"]] :> HTMLTextContent[e]]

Out[3]= {"C"}
```

#### List Predicates

---

Require several classes in any order with ``ContainsAll``:

```wl
In[1]:= items = ImportString["<ul><li class=\"item active\">A</li><li class=\"item\">B</li><li class=\"active item\">C</li></ul>", {"HTML", "XMLObject"}];
XMLCases[items, e : XMLPattern["li", "classList" -> _?(ContainsAll[{"item", "active"}])] :> HTMLTextContent[e]]

Out[1]= {"A", "C"}
```

---

Rule out a class with ``FreeQ``, which also matches elements with no class:

```wl
In[1]:= page = ImportString["<article><p>Body one.</p><p class=\"ad promo\">Sponsored.</p><p class=\"note\">Body two.</p></article>", {"HTML", "XMLObject"}];
XMLCases[page, e : XMLPattern["p", "classList" -> _?(FreeQ["ad"])] :> HTMLTextContent[e]]

Out[1]= {"Body one.", "Body two."}
```

---

Match a class by prefix with ``AnyTrue`` and ``StringStartsQ``:

```wl
In[1]:= grid = ImportString["<div class=\"row\"><div class=\"col-6 lead\">A</div><div class=\"col-md-4\">B</div><div class=\"lead\">C</div><div>D</div></div>", {"HTML", "XMLObject"}];
XMLCases[grid, e : XMLPattern["div", "classList" -> _?(AnyTrue[StringStartsQ["col-"]])] :> HTMLTextContent[e]]

Out[1]= {"A", "B"}
```

Use string patterns in ``ContainsAll`` with ``SameTest -> StringMatchQ``:

```wl
In[2]:= XMLCases[grid, e : XMLPattern["div", "classList" -> _?(ContainsAll[{"col-" ~~ __, "lead"}, SameTest -> StringMatchQ])] :> HTMLTextContent[e]]

Out[2]= {"A"}
```

#### Constraints

---

Give a list pattern over the element children to match the first child:

```wl
In[1]:= links = ImportString["<p>See <a href=\"/a\">A</a>, <a href=\"/b\">B</a> and <a href=\"/c\">C</a>.</p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["p"][{x : XMLPattern["a"], ___}] :> HTMLTextContent[x]]

Out[1]= {"A"}
```

Match every second child with ``Repeated``:

```wl
In[2]:= XMLCases[links, XMLPattern["p"][{PatternSequence[_, _] ..., x : XMLPattern["a"], ___}] :> HTMLTextContent[x]]

Out[2]= {"A", "C"}
```

Match an element with exactly three element children:

```wl
In[3]:= XMLMatchQ[First[XMLCases[links, XMLPattern["p"]]], XMLPattern["p"][{_, _, _}]]

Out[3]= True
```

---

Give ``Descendant`` to match an element that has a match anywhere below it:

```wl
In[1]:= tree = ImportString["<div id=\"a\"><p><b>bold</b></p></div><div id=\"b\"><p>plain</p></div>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern["div", "id" -> id_][Descendant[XMLPattern["b"]]] :> id]

Out[1]= {"a"}
```

Give a level spec, with the children at depth 1:

```wl
In[2]:= {XMLCases[tree, XMLPattern["div", "id" -> id_][Descendant[XMLPattern["b"], {1}]] :> id], XMLCases[tree, XMLPattern["div", "id" -> id_][Descendant[XMLPattern["b"], {2}]] :> id]}

Out[2]= {{}, {"a"}}
```

---

Give several constraints, all of which must hold:

```wl
In[1]:= forecast = ImportString["<div class=\"day\"><span class=\"high\">14</span><span class=\"low\">6</span></div><div class=\"day\"><span class=\"high\">12</span></div>", {"HTML", "XMLObject"}];
XMLCases[forecast, XMLPattern["div"][Descendant[XMLPattern["span", "classList" -> "high"]], Descendant[XMLPattern["span", "classList" -> "low"]]]]

Out[1]= {XMLElement["div", {"class" -> "day"}, {XMLElement["span", {"class" -> "high"}, {"14"}], XMLElement["span", {"class" -> "low"}, {"6"}]}]}
```

---

Match an element with no element children, which may still hold text:

```wl
In[1]:= tree = ImportString["<ul><li>text</li><li><b>bold</b></li><li></li></ul>", {"HTML", "XMLObject"}];
XMLCases[tree, x : XMLPattern["li"][{}] :> x]

Out[1]= {XMLElement["li", {}, {"text"}], XMLElement["li", {}, {}]}
```

Use an ``XMLElement`` pattern to match an element with no contents at all:

```wl
In[2]:= XMLCases[tree, x : XMLElement["li", _, {}] :> x]

Out[2]= {XMLElement["li", {}, {}]}
```

---

Nest the patterns as the document is:

```wl
In[1]:= holidays = ImportString["<table><tr><th><time datetime=\"2026-12-25\">25 December</time></th><td>Friday</td><td>Christmas Day</td></tr></table>", {"HTML", "XMLObject"}];
XMLCases[holidays, XMLPattern["tr"][{XMLPattern["th"][{XMLPattern["time", "datetime" -> date_]}], ___, name : XMLPattern["td"]}] :> {date, HTMLTextContent[name]}]

Out[1]= {{"2026-12-25", "Christmas Day"}}
```

---

Give a CSS selector string for one element as an entry of a list pattern:

```wl
In[1]:= cards = ImportString["<div><p class=\"lead\">A</p><p>B</p></div>", {"HTML", "XMLObject"}];
XMLCases[cards, XMLPattern["div"][{x : "p.lead", ___}] :> HTMLTextContent[x]]

Out[1]= {"A"}
```

---

Give constraints to a CSS selector string, and name several elements below its element:

```wl
In[1]:= menus = ImportString["<ul class=\"menu\"><li>Home</li><li>Shop</li><li>Contact</li></ul><ul><li>Other</li></ul>", {"HTML", "XMLObject"}];
XMLCases[menus, "ul.menu"[{first : "li", ___, last : "li"}] :> HTMLTextContent /@ {first, last}]

Out[1]= {{"Home", "Contact"}}
```

### Applications

---

Keep every paragraph that is not an ad:

```wl
In[1]:= page = ImportString["<article><p>Body one.</p><p class=\"ad promo\">Sponsored.</p><p class=\"note\">Body two.</p><p class=\"ad\">Sponsored.</p></article>", {"HTML", "XMLObject"}];
XMLCases[page, e : XMLPattern["p", "classList" -> _?(FreeQ["ad"])] :> HTMLTextContent[e]]

Out[1]= {"Body one.", "Body two."}
```

Delete the ads from the tree instead, leaving the rest in place:

```wl
In[2]:= HTMLTextContent[XMLDeleteCases[page, XMLPattern["p", "classList" -> "ad"]]]

Out[2]= "Body one.Body two."
```

---

Read the name and price off each product card:

```wl
In[1]:= shop = ImportString["<div class=\"card sale\" data-price=\"9.99\"><h3>Mug</h3></div><div class=\"card\" data-price=\"24.50\"><h3>Lamp</h3></div><div class=\"banner\" data-price=\"0\">Ad</div>", {"HTML", "XMLObject"}];
XMLCases[shop, e : XMLPattern["div", {"classList" -> "card", "data-price" -> price_}] :> HTMLTextContent[e] -> ToExpression[price]]

Out[1]= {"Mug" -> 9.99`, "Lamp" -> 24.5`}
```

---

Map each heading level to the headings at that level:

```wl
In[1]:= doc = ImportString["<body><h1>Intro</h1><h2>Setup</h2><h2>Usage</h2><h3>Options</h3></body>", {"HTML", "XMLObject"}];
GroupBy[XMLCases[doc, e : XMLPattern[tag : ("h1" | "h2" | "h3")] :> tag -> HTMLTextContent[e]], First -> Last]

Out[1]= <|"h1" -> {"Intro"}, "h2" -> {"Setup", "Usage"}, "h3" -> {"Options"}|>
```

### Properties & Relations

---

The order of the constraints does not matter, and other attributes are allowed:

```wl
In[1]:= XMLMatchQ[XMLElement["a", {"id" -> "buy", "class" -> "cta", "href" -> "/x"}, {}], XMLPattern["a", {"href" -> "/x", "id" -> _}]]

Out[1]= True
```

---

The list key ``"classList"`` gives the same classes as ``HTMLClassList``:

```wl
In[1]:= items = ImportString["<ul><li class=\"item  active\">A</li><li>B</li></ul>", {"HTML", "XMLObject"}];
{XMLCases[items, XMLPattern["li", "classList" -> c_] :> c], HTMLClassList /@ XMLCases[items, XMLPattern["li"]]}

Out[1]= {{{"item", "active"}, {}}, {{"item", "active"}, {}}}
```

---

A name for the whole element gives it without the ``"classList"`` key:

```wl
In[1]:= XMLCases[XMLElement["div", {}, {XMLElement["p", {"class" -> "lead"}, {"Intro."}]}], e : XMLPattern["p", "classList" -> "lead"] :> e]

Out[1]= {XMLElement["p", {"class" -> "lead"}, {"Intro."}]}
```

---

Combine ``XMLPattern`` expressions with ``Alternatives``:

```wl
In[1]:= tree = ImportString["<article><h1>Title</h1><p class=\"lead\">Intro.</p><p>Body.</p></article>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern["h1"] | XMLPattern["p", "classList" -> "lead"]]

Out[1]= {XMLElement["h1", {}, {"Title"}], XMLElement["p", {"class" -> "lead"}, {"Intro."}]}
```

---

Split ``rel`` into tokens for one search, and match them at the list key ``"relList"``:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow noopener\" href=\"/ad\">Ad</a><a href=\"/home\">Home</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["a", {"relList" -> _?(FreeQ["nofollow"]), "href" -> h_}] :> h, "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= {"/home"}
```

---

``XMLMatchQ`` tests the constraints against what is below the element:

```wl
In[1]:= XMLMatchQ[XMLElement["ul", {}, {XMLElement["li", {}, {"a"}]}], XMLPattern["ul"][{XMLPattern["li"]}]]

Out[1]= True
```

---

An empty second bracket adds no constraints:

```wl
In[1]:= tree = ImportString["<ul><li>a</li></ul><ul></ul>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern["ul"][]] === XMLCases[tree, XMLPattern["ul"]]

Out[1]= True
```

### Possible Issues

---

``?`` binds tighter than function application, so ``_?MemberQ["lead"]`` matches nothing:

```wl
In[1]:= element = XMLElement["p", {"class" -> "lead"}, {}];
{XMLMatchQ[element, XMLPattern["p", "classList" -> _?MemberQ["lead"]]], XMLMatchQ[element, XMLPattern["p", "classList" -> _?(MemberQ["lead"])]]}

Out[1]= {False, True}
```

---

At a list key, ``Except["ad"]`` matches every list, including one that contains ``"ad"``:

```wl
In[1]:= elements = {XMLElement["p", {"class" -> "ad"}, {}], XMLElement["p", {}, {}]};
Map[XMLMatchQ[XMLPattern["p", "classList" -> Except["ad"]]], elements]

Out[1]= {True, True}
```

Use ``FreeQ`` to rule out a class:

```wl
In[2]:= Map[XMLMatchQ[XMLPattern["p", "classList" -> _?(FreeQ["ad"])]], elements]

Out[2]= {False, True}
```

---

A list pattern depends on the order of the classes:

```wl
In[1]:= XMLMatchQ[XMLElement["li", {"class" -> "active item"}, {}], XMLPattern["li", "classList" -> {"item", "active", ___}]]

Out[1]= False
```

Check for the classes in any order with ``ContainsAll``:

```wl
In[2]:= XMLMatchQ[XMLElement["li", {"class" -> "active item"}, {}], XMLPattern["li", "classList" -> _?(ContainsAll[{"item", "active"}])]]

Out[2]= True
```

---

``"class" -> "menu"`` matches only ``class="menu"``, so it misses ``class="menu compact"``:

```wl
In[1]:= menu = XMLElement["ul", {"class" -> "menu compact"}, {}];
{XMLMatchQ[menu, XMLPattern["ul", "class" -> "menu"]], XMLMatchQ[menu, XMLPattern["ul", "classList" -> "menu"]]}

Out[1]= {False, True}
```

---

Put the ``___`` inside an ``OrderlessPatternSequence`` to match the classes anywhere in the list:

```wl
In[1]:= element = XMLElement["div", {"class" -> "x1 lead col-6"}, {}];
{XMLMatchQ[element, XMLPattern["div", "classList" -> {OrderlessPatternSequence["lead", "col-6"], ___}]], XMLMatchQ[element, XMLPattern["div", "classList" -> {OrderlessPatternSequence["lead", "col-6", ___]}]]}

Out[1]= {False, True}
```

---

``Cases`` and ``MatchQ`` treat an ``XMLPattern`` as a literal, like a string pattern:

```wl
In[1]:= elements = {XMLElement["p", {}, {"one"}], XMLElement["p", {}, {"two"}]};
{Cases[elements, XMLPattern["p"]], MatchQ["abc", "a" ~~ __]}

Out[1]= {{}, False}
```

Use ``XMLCases`` and ``XMLMatchQ`` instead:

```wl
In[2]:= {XMLCases[elements, XMLPattern["p"]], XMLMatchQ[First[elements], XMLPattern["p"]]}

Out[2]= {{XMLElement["p", {}, {"one"}], XMLElement["p", {}, {"two"}]}, True}
```

---

A list ``{ns$, name$}`` gives two keys, not one namespaced key:

```wl
In[1]:= use = XMLElement["use", {{"http://www.w3.org/1999/xlink", "href"} -> "#icon"}, {}];
{XMLMatchQ[use, XMLPattern["use", {"http://www.w3.org/1999/xlink", "href"}]], XMLMatchQ[use, XMLPattern["use", {{"http://www.w3.org/1999/xlink", "href"}}]]}

Out[1]= {False, True}
```

---

A string matches one class only at a key whose alternatives are all list keys:

```wl
In[1]:= element = XMLElement["div", {"class" -> "lead"}, {}];
{XMLMatchQ[element, XMLPattern["div", ("classList" | "id") -> "lead"]], XMLMatchQ[element, XMLPattern["div", "classList" -> "lead"]]}

Out[1]= {False, True}
```

---

In a hand-built tree, ``"classList"`` matches the classes, not an attribute of that name:

```wl
In[1]:= element = XMLElement["p", {"classList" -> "x", "class" -> "lead"}, {}];
{XMLMatchQ[element, XMLPattern["p", "classList" -> "x"]], XMLMatchQ[element, XMLPattern["p", "classList" -> "lead"]]}

Out[1]= {False, True}
```

Test the attributes as a whole to match that attribute:

```wl
In[2]:= XMLMatchQ[element, XMLPattern["p", _?(MemberQ["classList" -> "x"])]]

Out[2]= True
```

---

Of two attributes with the same name, HTML import keeps the last, where a browser keeps the first:

```wl
In[1]:= XMLCases[ImportString["<p class=\"first\" class=\"second\">x</p>", {"HTML", "XMLObject"}], XMLPattern["p", "classList" -> c_] :> c]

Out[1]= {{"second"}}
```

---

A string pattern cannot appear anywhere in an ``XMLPattern``:

```wl
In[1]:= XMLMatchQ[XMLElement["div", {"class" -> "col-6"}, {}], XMLPattern["div", "classList" -> {"col-" ~~ __}]]

During evaluation of In[1]:= XMLPattern::strpat: "col-"~~__ is a string pattern, and in an XMLPattern it does not match any string. Write _?(StringMatchQ["col-"~~__]) instead.

Out[1]= $Failed
```

Test the classes with ``StringMatchQ`` instead:

```wl
In[2]:= XMLMatchQ[XMLElement["div", {"class" -> "col-6"}, {}], XMLPattern["div", "classList" -> {_?(StringMatchQ["col-" ~~ __])}]]

Out[2]= True
```

---

A key cannot be a pattern:

```wl
In[1]:= XMLMatchQ[XMLElement["div", {"data-id" -> "7"}, {}], XMLPattern["div", _?(StringStartsQ["data-"]) -> _]]

During evaluation of In[1]:= XMLPattern::badkey: An attribute key should be a string, a {namespace, name} pair of strings, or alternatives of these. Got _?(StringStartsQ["data-"]). To test the keys, test the attributes as a whole: XMLPattern[tag, attrs_?test].

Out[1]= $Failed
```

Test the keys of all the attributes instead:

```wl
In[2]:= XMLMatchQ[XMLElement["div", {"data-id" -> "7"}, {}], XMLPattern["div", _?(Keys/*AnyTrue[StringStartsQ["data-"]])]]

Out[2]= True
```

---

A key can have only one constraint:

```wl
In[1]:= XMLMatchQ[XMLElement["li", {"class" -> "item active"}, {}], XMLPattern["li", {"classList" -> "item", "classList" -> "active"}]]

During evaluation of In[1]:= XMLPattern::dupkey: The attribute key "classList" appears in more than one constraint, so the pattern can never match. Combine the constraints into one value pattern.

Out[1]= $Failed
```

Combine them into one value pattern:

```wl
In[2]:= XMLMatchQ[XMLElement["li", {"class" -> "item active"}, {}], XMLPattern["li", "classList" -> _?(ContainsAll[{"item", "active"}])]]

Out[2]= True
```

---

An argument of the second bracket is a constraint, so an attribute key there issues a message:

```wl
In[1]:= XMLMatchQ[XMLElement["input", {"type" -> "text", "required" -> ""}, {}], XMLPattern["input", "type" -> "text"]["required"]]

During evaluation of In[1]:= XMLPattern::constraint: "required" is not a constraint. The constraints on what is below an element are the arguments of the bracket after XMLPattern[tag, attrs], as in XMLPattern[tag, attrs][c1, c2, ...]: Child[p] for some element child that matches p, a list pattern over its element children, as in {p} for an only child, or Descendant[p] for an element anywhere below. Attribute constraints go in the first bracket, several in one list: XMLPattern[tag, {a1, a2, ...}].

Out[1]= $Failed
```

Give the attribute constraints as a list in the first bracket:

```wl
In[2]:= XMLMatchQ[XMLElement["input", {"type" -> "text", "required" -> ""}, {}], XMLPattern["input", {"type" -> "text", "required"}]]

Out[2]= True
```

---

A malformed ``XMLPattern`` evaluates without a message:

```wl
In[1]:= pattern = XMLPattern["p", _ -> "x"]

Out[1]= XMLPattern["p", _ -> "x"]
```

A function that uses it issues a message and returns ``$Failed``:

```wl
In[2]:= XMLCases[XMLElement["div", {}, {XMLElement["p", {"id" -> "x"}, {}]}], pattern]

During evaluation of In[2]:= XMLPattern::badkey: An attribute key should be a string, a {namespace, name} pair of strings, or alternatives of these. Got _. To test the keys, test the attributes as a whole: XMLPattern[tag, attrs_?test].

Out[2]= $Failed
```

---

Without an entry for ``rel`` in ``$AttributeReadings``, ``"relList"`` is an attribute:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow\" href=\"/ad\">Ad</a><a href=\"/home\">Home</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["a", "relList" -> "nofollow"]]

During evaluation of In[1]:= XMLPattern::nolistreading: "rel" has no entry in $AttributeReadings, so the key "relList" is matched as an attribute of that name. To split "rel" into tokens, add an entry: $AttributeReadings["rel"] = <||> for the session, or "AttributeReadings" -> <|"rel" -> <||>|> in the call.

Out[1]= {}
```

Give an entry for ``rel`` with the ``"AttributeReadings"`` option, here for one call:

```wl
In[2]:= XMLCases[links, XMLPattern["a", "relList" -> "nofollow"], "AttributeReadings" -> <|"rel" -> <||>|>]

Out[2]= {XMLElement["a", {"shape" -> "rect", "rel" -> "nofollow", "href" -> "/ad"}, {"Ad"}]}
```

---

If the entry for ``rel`` gives another list key, ``"relList"`` is an attribute:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow\" href=\"/ad\">Ad</a><a href=\"/home\">Home</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["a", "relList" -> "nofollow"], "AttributeReadings" -> <|"rel" -> <|"ListKey" -> "rels"|>|>]

During evaluation of In[1]:= XMLPattern::otherlistkey: The key "relList" is matched as an attribute of that name, but the tokens of "rel" are under the list key "rels". Use "rels", or set "ListKey" -> "relList" in the entry for "rel".

Out[1]= {}
```

Use the list key that the entry gives:

```wl
In[2]:= XMLCases[links, XMLPattern["a", "rels" -> "nofollow"], "AttributeReadings" -> <|"rel" -> <|"ListKey" -> "rels"|>|>]

Out[2]= {XMLElement["a", {"shape" -> "rect", "rel" -> "nofollow", "href" -> "/ad"}, {"Ad"}]}
```

---

Several constraints go in one bracket, and a second constraint bracket issues a message:

```wl
In[1]:= forecast = XMLElement["div", {}, {XMLElement["span", {"class" -> "high"}, {"14"}], XMLElement["span", {"class" -> "low"}, {"6"}]}];
XMLMatchQ[forecast, XMLPattern["div"][Descendant["span.high"]][Descendant["span.low"]]]

During evaluation of In[1]:= XMLPattern::chain: XMLPattern["div"][Descendant["span.high"]][Descendant["span.low"]] gives constraints in more than one bracket. Several constraints are the arguments of one bracket: XMLPattern["div"][Descendant["span.high"], Descendant["span.low"]].

Out[1]= $Failed
```

Give the constraints as arguments of one bracket:

```wl
In[2]:= XMLMatchQ[forecast, XMLPattern["div"][Descendant["span.high"], Descendant["span.low"]]]

Out[2]= True
```

---

A CSS selector that depends on what is above its element takes no constraints:

```wl
In[1]:= menus = ImportString["<nav><ul><li>Home</li><li>Shop</li></ul></nav>", {"HTML", "XMLObject"}];
XMLCases[menus, "nav ul"[{x : "li", ___}] :> x]

During evaluation of In[1]:= FromCSSSelector::constraints: "nav ul"[{x:"li", ___}] gives constraints to "nav ul", which depends on what is above or beside its element. Only a selector for one element takes constraints. Nest the selectors as the tree is, as in "nav"[Descendant[x : "a"[c]]] :> x.

Out[1]= $Failed
```

Nest the selectors as the document is:

```wl
In[2]:= XMLCases[menus, "nav"[Descendant["ul"[{x : "li", ___}]]] :> HTMLTextContent[x]]

Out[2]= {"Home"}
```

## See Also

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [XMLMatchQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLMatchQ)

* [XMLFreeQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFreeQ)

* [XMLFirstCase](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFirstCase)

* [XMLPosition](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPosition)

* [XMLDeleteCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDeleteCases)

* [XMLReplace](paclet:MaximilienTirard/HTMLPatterns/ref/XMLReplace)

* [Descendant](paclet:MaximilienTirard/HTMLPatterns/ref/Descendant)

* [XMLDocument](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDocument)

* [FromCSSSelector](paclet:MaximilienTirard/HTMLPatterns/ref/FromCSSSelector)

* [HTMLClassList](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLClassList)

* [$AttributeReadings](paclet:MaximilienTirard/HTMLPatterns/ref/$AttributeReadings)

* [HTMLWhitespace](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLWhitespace)

* [XMLElement](paclet:ref/XMLElement)

* [KeyValuePattern](paclet:ref/KeyValuePattern)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
