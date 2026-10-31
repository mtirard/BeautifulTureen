# FromCSSSelector

   ``FromCSSSelector["selector$"]`` gives the XML pattern for a CSS selector that depends only on its element and what is below it, such as ``"a.note"``.
   ``FromCSSSelector[n$:"selector$"]`` gives the pattern with the element that ``selector$`` selects named ``n$``, for any selector.

## Details and Options

``FromCSSSelector`` gives an XML pattern for functions such as ``XMLCases``, ``XMLMatchQ`` and ``XMLReplace``.

A CSS selector for one element depends only on its element and what is below it, such as ``"a.note"`` or ``"div:has(> table)"``. ``FromCSSSelector`` gives its pattern, named if the selector is named.

Other selectors depend on what is above or beside their element, such as ``"nav a"`` or ``"li:first-child"``. Their pattern describes an element higher up, so the element they select needs a name: ``FromCSSSelector[n : "nav a"]`` gives ``XMLPattern["nav"][Descendant[n : XMLPattern["a"]]]``.

A CSS selector string can be given directly wherever a pattern goes, and means its translation:

| where | selector for one element | other selector |
| :--- | :--- | :--- |
| the whole pattern of ``XMLCases``, etc. | the elements it selects | the elements it selects |
| left of a rule, named, as in ``n : "p a" :> n`` | ``n`` is the selected element | ``n`` is the selected element |
| left of a rule, unnamed, as in ``"a" :> 1`` | the pattern, unnamed; name it to use the element on the right-hand side | not accepted |
| a key in ``"Roles"`` or ``"Constructs"`` | a test of each element | each element it selects in the tree |
| ``XMLMatchQ``, ``XMLFreeQ``, a list entry, ``Child``, ``Descendant`` | a test of the element | not accepted |
| with constraints, as in ``"ul"[Child["li"]]`` | the pattern with the constraints added to each ``XMLPattern`` in it | not accepted |

The selector is matched as written against the imported tree, so letter case matters in tag names, attribute names and attribute values.

The following parts of a selector are translated:

| selector | elements described |
| :--- | :--- |
| ``E``, ``*`` | elements with the tag ``E``, or any element |
| ``.c``, ``#x`` | elements with the class ``c``, or with the id ``x`` |
| ``[a]``, ``[a=v]`` | elements with the attribute ``a``, or with ``a`` equal to ``v`` |
| ``[a~=v]`` | elements whose ``a``, split at whitespace, holds the token ``v`` |
| ``[a\|=v]`` | elements whose ``a`` is ``v`` or starts with ``v-`` |
| ``[a^=v]``, ``[a$=v]``, ``[a*=v]`` | elements whose ``a`` starts with, ends with or contains ``v`` |
| ``[a=v i]``, ``[a=v s]`` | the same, with the letters A to Z matched in either case, or as written |
| ``E F``, ``E > F`` | ``F`` elements inside an ``E`` element, or children of one |
| ``E + F``, ``E ~ F`` | ``F`` elements right after an ``E`` sibling, or after one |
| ``:not(s$1, s$2, $$)`` | elements that match none of the ``s$i`` |
| ``:is(s$1, s$2, $$)``, ``:where(s$1, s$2, $$)`` | elements that match any of the ``s$i`` |
| ``:has(r$1, r$2, $$)`` | elements with a descendant that an ``r$i`` describes, a child for ``>``, or a later sibling for ``+`` and ``~`` |
| ``:empty`` | elements with no element and no text other than whitespace |
| ``:link``, ``:any-link`` | ``a`` and ``area`` elements with an ``href`` attribute |
| ``:checked`` | checked checkboxes and radio buttons, and selected options |
| ``:first-child``, ``:last-child``, ``:only-child`` | elements that are the first, the last or the only element child of their parent |
| ``:nth-child(An+B)``, ``:nth-last-child(An+B)`` | elements at a position An+B among the element children of their parent, for some n ≥ 0, counted from the first or from the last; with ``of`` and selectors ``s$i``, among the children that match one of the ``s$i`` |
| ``:first-of-type``, ``:last-of-type``, ``:only-of-type``, ``:nth-of-type(An+B)``, ``:nth-last-of-type(An+B)`` | the same, among the children with the element's tag |
| ``:root``, ``:scope`` | the top-level element of the tree, when there is only one |
| ``s$1, s$2, $$`` | elements that any of the selectors describes |

The arguments of ``:not``, ``:is`` and ``:where`` can hold descendant and ``>`` combinators. ``+`` and ``~`` inside them are not translated, and nor are ``:not(:has(+ $$))`` and ``:not(:has(~ $$))``.

``[a~=v]`` works for ``class`` by default. For another attribute, add an entry to ``$AttributeReadings``, or give one with the ``"AttributeReadings"`` option.

``FromCSSSelector`` issues a message and returns ``$Failed`` for a string that is not a valid CSS selector, for a valid selector that it cannot translate, such as ``:lang(fr)``, and for one that only a browser can match, such as ``:hover``.

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Translate a CSS selector for one element:

```wl
In[1]:= FromCSSSelector["a.note"]

Out[1]= XMLPattern["a", "classList" -> "note"]
```

---

Name the selected element to translate a selector that depends on what is above it:

```wl
In[1]:= FromCSSSelector[n : "div.note > p"]

Out[1]= XMLPattern["div", "classList" -> "note"][Child[n : XMLPattern["p"]]]
```

---

Give a CSS selector directly to ``XMLCases``:

```wl
In[1]:= notes = ImportString["<div class=\"note\"><p>Read this.</p></div><div><p>Not this.</p></div>", {"HTML", "XMLObject"}];
XMLCases[notes, "div.note > p"]

Out[1]= {XMLElement["p", {}, {"Read this."}]}
```

Name the selected element on the left of a rule:

```wl
In[2]:= XMLCases[notes, n : "div.note > p" :> HTMLTextContent[n]]

Out[2]= {"Read this."}
```

### Scope

#### Simple Selectors

---

Translate a selector with classes, an id and an attribute into one ``XMLPattern``:

```wl
In[1]:= FromCSSSelector["a.external#home[href][title=\"Home\"]"]

Out[1]= XMLPattern["a", {"classList" -> "external", "id" -> "home", "href", "title" -> "Home"}]
```

---

Test the start, end or content of an attribute value:

```wl
In[1]:= FromCSSSelector["a[href^=\"https://\"][href$=\".pdf\"]"]

Out[1]= XMLPattern["a", "href" -> _?(StringStartsQ[#1, "https://"] && StringEndsQ[#1, ".pdf"] &)]
```

---

Give the ``i`` flag to match the letters A to Z in either case:

```wl
In[1]:= XMLCases[ImportString["<input type=\"CHECKBOX\"><input type=\"text\">", {"HTML", "XMLObject"}], "input[type=checkbox i]"]

Out[1]= {XMLElement["input", {"type" -> "CHECKBOX"}, {}]}
```

---

Match a token of a space-separated attribute, with an entry for it in ``"AttributeReadings"``:

```wl
In[1]:= XMLCases[ImportString["<a rel=\"nofollow noopener\" href=\"/ad\">Ad</a><a href=\"/\">Home</a>", {"HTML", "XMLObject"}], "a[rel~=nofollow]", "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= {XMLElement["a", {"shape" -> "rect", "rel" -> "nofollow noopener", "href" -> "/ad"}, {"Ad"}]}
```

#### Combinators

---

Translate a descendant combinator to ``Descendant``, and ``>`` to ``Child``:

```wl
In[1]:= {FromCSSSelector[n : "nav a"], FromCSSSelector[n : "nav > a"]}

Out[1]= {XMLPattern["nav"][Descendant[n : XMLPattern["a"]]], XMLPattern["nav"][Child[n : XMLPattern["a"]]]}
```

---

Translate ``+`` and ``~`` to a list pattern over the children of the parent:

```wl
In[1]:= FromCSSSelector[n : "h2 + p"]

Out[1]= XMLPattern[_][{___, XMLPattern["h2"], n : XMLPattern["p"], ___}] | XMLDocument[{___, XMLPattern["h2"], n : XMLPattern["p"], ___}]
```

---

Translate a chain of combinators to nested patterns:

```wl
In[1]:= FromCSSSelector[n : "main ul > li"]

Out[1]= XMLPattern["main"][Descendant[XMLPattern["ul"][Child[n : XMLPattern["li"]]]]]
```

---

Name the first part as well to use it in a rule:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav></nav>", {"HTML", "XMLObject"}];
XMLCases[navs, r : FromCSSSelector[n : "nav a"] :> {r[[2, 1, 2]], HTMLTextContent[n]}]

Out[1]= {{"outer", "Home"}, {"outer", "News"}, {"inner", "News"}}
```

---

Give a list of selectors to get alternatives that share the name:

```wl
In[1]:= FromCSSSelector[n : "h1, article > h2"]

Out[1]= (n : XMLPattern["h1"]) | XMLPattern["article"][Child[n : XMLPattern["h2"]]]
```

Get each element once, in document order:

```wl
In[2]:= page = ImportString["<body><h2>A</h2><p>x</p><ul><li><a href=\"/\">y</a></li></ul></body>", {"HTML", "XMLObject"}];
XMLCases[page, "li > a, h2 + p"]

Out[2]= {XMLElement["p", {}, {"x"}], XMLElement["a", {"shape" -> "rect", "href" -> "/"}, {"y"}]}
```

#### Pseudo-Classes

---

Use ``:not`` of a class, which also matches the elements that have no class:

```wl
In[1]:= XMLCases[ImportString["<p class=\"ad\">Ad.</p><p class=\"lead\">Lead.</p><p>Body.</p>", {"HTML", "XMLObject"}], "p:not(.ad)"]

Out[1]= {XMLElement["p", {"class" -> "lead"}, {"Lead."}], XMLElement["p", {}, {"Body."}]}
```

---

Use ``:not`` with a combinator to test the elements above, here for links outside any nav:

```wl
In[1]:= page = ImportString["<body><nav><a href=\"/\">Home</a></nav><p><a href=\"/about\">About</a></p></body>", {"HTML", "XMLObject"}];
XMLCases[page, "a:not(nav a)"]

Out[1]= {XMLElement["a", {"shape" -> "rect", "href" -> "/about"}, {"About"}]}
```

---

Use ``:is`` for alternatives:

```wl
In[1]:= FromCSSSelector["h2:is(.new, .updated)"]

Out[1]= XMLPattern["h2", "classList" -> "new"] | XMLPattern["h2", "classList" -> "updated"]
```

---

Use ``:has`` to test the descendants of the element, or with ``>`` its children:

```wl
In[1]:= {FromCSSSelector["section:has(h2)"], FromCSSSelector["section:has(> h2)"]}

Out[1]= {XMLPattern["section"][Descendant[XMLPattern["h2"]]], XMLPattern["section"][Child[XMLPattern["h2"]]]}
```

---

Use ``:has`` with ``+`` to test the next sibling:

```wl
In[1]:= XMLCases[{XMLElement["div", {}, {XMLElement["x", {"id" -> "1"}, {}], XMLElement["a", {"id" -> "2"}, {}], XMLElement["b", {"id" -> "3"}, {}]}]}, "a:has(+ b)"]

Out[1]= {XMLElement["a", {"id" -> "2"}, {}]}
```

---

Translate ``:not(:has(...))`` to a test with ``XMLFreeQ``:

```wl
In[1]:= FromCSSSelector["p:not(:has(b))"]

Out[1]= (XMLPattern["p"])?(XMLFreeQ[#1, XMLPattern["b"], {1, ∞}] &)
```

---

Use ``:empty`` to match elements that hold nothing but whitespace:

```wl
In[1]:= XMLCases[ImportString["<td> </td><td>0</td><td></td>", {"HTML", "XMLObject"}], "td:empty"]

Out[1]= {XMLElement["td", {"colspan" -> "1", "rowspan" -> "1"}, {" "}], XMLElement["td", {"colspan" -> "1", "rowspan" -> "1"}, {}]}
```

---

Use ``:checked`` to match checked checkboxes and radio buttons, and selected options:

```wl
In[1]:= FromCSSSelector[":checked"]

Out[1]= XMLPattern["input", {"type" -> _?(StringMatchQ["checkbox" | "radio", IgnoreCase -> True]), "checked"}] | XMLPattern["option", "selected"]
```

---

Translate a pseudo-class of position to a list pattern over the element children of the parent:

```wl
In[1]:= FromCSSSelector[n : "ul > li:nth-child(odd)"]

Out[1]= XMLPattern["ul"][{PatternSequence[_, _] ..., n : XMLPattern["li"], ___}]
```

---

Use ``:first-of-type`` to compare the tags of the siblings:

```wl
In[1]:= XMLCases[{XMLElement["a", {"id" -> "1"}, {}], XMLElement["b", {"id" -> "2"}, {}], XMLElement["a", {"id" -> "3"}, {}]}, ":first-of-type"]

Out[1]= {XMLElement["a", {"id" -> "1"}, {}], XMLElement["b", {"id" -> "2"}, {}]}
```

---

Give ``:only-child`` after any combinator:

```wl
In[1]:= XMLCases[ImportString["<div><ul><li>One</li></ul><ul><li>A</li><li>B</li></ul></div>", {"HTML", "XMLObject"}], "div li:only-child"]

Out[1]= {XMLElement["li", {}, {"One"}]}
```

---

Translate ``:root`` and ``:scope`` to ``XMLDocument`` patterns:

```wl
In[1]:= page = ImportString["<html><head></head><body><p>Text</p></body></html>", {"HTML", "XMLObject"}];
{FromCSSSelector[n : ":root > body"], XMLCases[page, ":scope > *"] // Map[First]}

Out[1]= {XMLDocument[{XMLPattern[_][Child[n : XMLPattern["body"]]]}], {"head", "body"}}
```

#### Workflow

---

Give a CSS selector in a ``"Roles"`` rule of ``HTMLInnerText``:

```wl
In[1]:= HTMLInnerText[ImportString["<div class=\"ad\">Buy now!</div><p>The article.</p>", {"HTML", "XMLObject"}], "Roles" -> {"div.ad" -> "Skip"}]

Out[1]= "The article."
```

---

Translate a selector to start from, and add a test that CSS cannot write:

```wl
In[1]:= links = ImportString["<a href=\"/a\">About us</a><a href=\"/b\">Go</a>", {"HTML", "XMLObject"}];
XMLCases[links, link : FromCSSSelector["a[href]"] /; StringLength[HTMLTextContent[link]] > 2]

Out[1]= {XMLElement["a", {"shape" -> "rect", "href" -> "/a"}, {"About us"}]}
```

---

Translate a selector and extend it with more names:

```wl
In[1]:= holidays = ImportString["<table><tr><th>25 December</th><td>Christmas Day</td></tr></table>", {"HTML", "XMLObject"}];
FromCSSSelector[n : "tr > td"]

Out[1]= XMLPattern["tr"][Child[n : XMLPattern["td"]]]
```

```wl
In[2]:= XMLCases[holidays, XMLPattern["tr"][{d : XMLPattern["th"], ___, n : XMLPattern["td"], ___}] :> HTMLTextContent /@ {d, n}]

Out[2]= {{"25 December", "Christmas Day"}}
```

---

Give constraints to a selector string to name several elements below its element:

```wl
In[1]:= menus = ImportString["<ul class=\"menu\"><li>Home</li><li>Shop</li><li>Contact</li></ul><ol><li>One</li></ol>", {"HTML", "XMLObject"}];
XMLCases[menus, "ul.menu"[{first : "li", ___, last : "li"}] :> HTMLTextContent /@ {first, last}]

Out[1]= {{"Home", "Contact"}}
```

On a selector list, each selector takes the constraints:

```wl
In[2]:= XMLCases[menus, "ul, ol"[{x : "li", ___}] :> HTMLTextContent[x]]

Out[2]= {"Home", "One"}
```

### Properties & Relations

---

A CSS selector string gives the same elements as its translation:

```wl
In[1]:= page = ImportString["<ul><li class=\"done\">a</li><li>b</li></ul>", {"HTML", "XMLObject"}];
XMLCases[page, "li:not(.done)"] === XMLCases[page, FromCSSSelector["li:not(.done)"]]

Out[1]= True
```

---

A selector that depends on what is above its element gives what its named translation gives:

```wl
In[1]:= page = ImportString["<body><nav><a href=\"/\">Home</a></nav></body>", {"HTML", "XMLObject"}];
XMLCases[page, "nav a"] === XMLCases[page, FromCSSSelector[n : "nav a"] :> n]

Out[1]= True
```

---

Naming the element does not change the translation of a selector for one element:

```wl
In[1]:= FromCSSSelector[n : "a.note"] === (n : FromCSSSelector["a.note"])

Out[1]= True
```

---

A selector for one element can be given to ``XMLMatchQ``:

```wl
In[1]:= XMLMatchQ[XMLElement["a", {"class" -> "external", "href" -> "https://example.com"}, {"Example"}], "a.external[href]"]

Out[1]= True
```

### Possible Issues

---

A selector that depends on what is above its element needs a name:

```wl
In[1]:= FromCSSSelector["nav a"]

During evaluation of In[1]:= FromCSSSelector::name: "nav a" depends on what is above or beside its element, so the element it selects needs a name. Use FromCSSSelector[n : "nav a"], which names it n.

Out[1]= $Failed
```

Name the element it selects:

```wl
In[2]:= FromCSSSelector[n : "nav a"]

Out[2]= XMLPattern["nav"][Descendant[n : XMLPattern["a"]]]
```

---

On the left of a rule, a selector that depends on what is above its element must be named:

```wl
In[1]:= page = ImportString["<body><nav><a href=\"/\">Home</a></nav></body>", {"HTML", "XMLObject"}];
XMLCases[page, "nav a" :> 1]

During evaluation of In[1]:= XMLCases::badpat: The second argument should be a pattern, or a rule pattern -> rhs or pattern :> rhs. A pattern is an XMLPattern, which can take constraints on the elements below it, an XMLDocument pattern, an XMLElement pattern, or a CSS selector string, or alternatives of these, any of them named, with a condition pat /; test or a test pat?f. A CSS selector that depends on what is above or beside the element it selects, such as "nav a", gives that element when given alone; on the left of a rule, name the element, as in n : "nav a" :> n. Got "nav a".

Out[1]= $Failed
```

Name it, and use the name:

```wl
In[2]:= XMLCases[page, n : "nav a" :> HTMLTextContent[n]]

Out[2]= {"Home"}
```

---

A rule whose right-hand side uses no name gives at most one result:

```wl
In[1]:= hrefs = ImportString["<p><a href=\"/x\">one</a><a href=\"/x\">two</a></p>", {"HTML", "XMLObject"}];
{XMLCases[hrefs, "a[href]" :> 1], XMLCases[hrefs, n : "a[href]" :> 1], XMLCases[hrefs, n : "a[href]" :> HTMLTextContent[n]]}

Out[1]= {{1}, {1}, {"one", "two"}}
```

---

The importer adds attributes such as ``rowspan="1"``, which count as present:

```wl
In[1]:= XMLCases[ImportString["<table><tr><td>a</td><td rowspan=\"2\">b</td></tr></table>", {"HTML", "XMLObject"}], "td[rowspan]"]

Out[1]= {XMLElement["td", {"colspan" -> "1", "rowspan" -> "1"}, {"a"}], XMLElement["td", {"colspan" -> "1", "rowspan" -> "2"}, {"b"}]}
```

---

Letter case matters, and the HTML importer gives names in lowercase:

```wl
In[1]:= XMLCases[ImportString["<DIV CLASS=\"Note\">x</DIV>", {"HTML", "XMLObject"}], #] & /@ {"DIV.Note", "div.Note", "div.note"}

Out[1]= {{}, {XMLElement["div", {"class" -> "Note"}, {"x"}]}, {}}
```

---

``[rel~=v]`` matches nothing without an entry for ``rel`` in ``$AttributeReadings``:

```wl
In[1]:= page = ImportString["<a rel=\"nofollow\" href=\"/ad\">Ad</a>", {"HTML", "XMLObject"}];
{XMLCases[page, "a[rel~=nofollow]"], Length[XMLCases[page, "a[rel~=nofollow]", "AttributeReadings" -> <|"rel" -> <||>|>]]}

During evaluation of In[1]:= XMLPattern::nolistreading: "rel" has no entry in $AttributeReadings, so the key "relList" is matched as an attribute of that name. To split "rel" into tokens, add an entry: $AttributeReadings["rel"] = <||> for the session, or "AttributeReadings" -> <|"rel" -> <||>|> in the call.

Out[1]= {{}, 1}
```

---

The ``i`` flag matches only the letters A to Z in either case, so ``é`` does not match ``É``:

```wl
In[1]:= XMLMatchQ[XMLElement["span", {"title" -> "\[CapitalEAcute]t\[EAcute]"}, {}], #] & /@ {"[title=\"\[EAcute]t\[EAcute]\" i]", "[title=\"\[CapitalEAcute]T\[EAcute]\" i]"}

Out[1]= {False, True}
```

---

``:checked`` tests the ``selected`` attribute only, not the default first option:

```wl
In[1]:= XMLCases[ImportString["<select><option>a</option><option>b</option></select>", {"HTML", "XMLObject"}], "option:checked"]

Out[1]= {}
```

---

On a list of several top-level elements, ``":scope > p"`` gives nothing:

```wl
In[1]:= XMLCases[{XMLElement["p", {}, {"One"}], XMLElement["p", {}, {"Two"}]}, ":scope > p"]

Out[1]= {}
```

Use ``XMLDocument`` to find the top-level ``p`` elements:

```wl
In[2]:= XMLCases[{XMLElement["p", {}, {"One"}], XMLElement["p", {}, {"Two"}]}, XMLDocument[{___, x : XMLPattern["p"], ___}] :> x]

Out[2]= {XMLElement["p", {}, {"One"}], XMLElement["p", {}, {"Two"}]}
```

---

``XMLMatchQ`` does not accept a selector that depends on what is above its element:

```wl
In[1]:= XMLMatchQ[XMLElement["li", {}, {}], "li:first-child"]

During evaluation of In[1]:= XMLMatchQ::badpat: The pattern should be an XMLPattern, an XMLElement pattern, an XMLDocument pattern, a list pattern for a list of elements, or a CSS selector string for one element, or alternatives of these, any of them named, with a condition pat /; test or a test pat?f. A rule gives a value, not a test. A CSS selector such as "nav a" or "ul > li" depends on what is above the element, which a lone element does not have; use XMLCases or XMLPosition to search a tree with it. Got "li:first-child".

Out[1]= $Failed
```

---

In a ``"Roles"`` rule a string is CSS, so a tag such as ``a.b`` needs ``XMLPattern``:

```wl
In[1]:= element = XMLElement["div", {}, {XMLElement["a.b", {}, {"hidden"}], XMLElement["p", {}, {"shown"}]}];
{HTMLInnerText[element, "Roles" -> {"a.b" -> "Skip"}], HTMLInnerText[element, "Roles" -> {XMLPattern["a.b"] -> "Skip"}]}

Out[1]= {"hidden\nshown", "shown"}
```

---

``:is`` and ``:where`` drop an argument that is not a valid selector, as CSS does:

```wl
In[1]:= FromCSSSelector["p:is(.lead, ::before)"]

Out[1]= XMLPattern["p", "classList" -> "lead"]
```

---

``+`` and ``~`` inside ``:not`` are not translated:

```wl
In[1]:= FromCSSSelector[n : "p:not(h2 + p)"]

During evaluation of In[1]:= FromCSSSelector::unsupported: "p:not(h2 + p)" is valid CSS, but ":not(h2 + p)" cannot be translated to an XML pattern. "Its arguments can hold only descendant and > combinators, not + or ~."

Out[1]= $Failed
```

---

A list pattern leaves out text, so ``:root`` matches even with text at the top:

```wl
In[1]:= XMLCases[{"Text", XMLElement["p", {}, {"Para"}]}, ":root"]

Out[1]= {XMLElement["p", {}, {"Para"}]}
```

---

A bracket on the translation of a selector list gives a message:

```wl
In[1]:= menus = ImportString["<ul class=\"menu\"><li>Home</li></ul><ol><li>One</li></ol>", {"HTML", "XMLObject"}];
XMLCases[menus, FromCSSSelector["ul.menu, ol"][{x : "li", ___}] :> x]

During evaluation of In[1]:= XMLPattern::bracket: (XMLPattern["ul", "classList" -> "menu"] | XMLPattern["ol"])[{x:"li", ___}] gives constraints to alternatives or a test, not to an XMLPattern. Constraints go in the bracket of each XMLPattern: XMLPattern["ul", "classList" -> "menu"][{x:"li", ___}] | XMLPattern["ol"][{x:"li", ___}]. For a pattern from FromCSSSelector["selector"], give them to the selector string instead, as in "selector"[c1, c2, ...].

Out[1]= $Failed
```

Give the constraints to the selector string:

```wl
In[2]:= XMLCases[menus, "ul.menu, ol"[{x : "li", ___}] :> HTMLTextContent[x]]

Out[2]= {"Home", "One"}
```

## See Also

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [XMLMatchQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLMatchQ)

* [XMLFreeQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFreeQ)

* [Descendant](paclet:MaximilienTirard/HTMLPatterns/ref/Descendant)

* [XMLDocument](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDocument)

* [$AttributeReadings](paclet:MaximilienTirard/HTMLPatterns/ref/$AttributeReadings)

* [HTMLInnerText](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLInnerText)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
