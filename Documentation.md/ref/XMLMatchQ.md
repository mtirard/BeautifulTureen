# XMLMatchQ

   ``XMLMatchQ[element$, pattern$]`` gives ``True`` if ``element$`` itself, not an element inside it, matches ``pattern$``, and ``False`` otherwise.
   ``XMLMatchQ[document$, XMLDocument[$$]]`` tests an ``XMLObject`` document.
   ``XMLMatchQ[{e$1, e$2, $$}, listpattern$]`` tests a list of elements against a list pattern, leaving strings out.
   ``XMLMatchQ[pattern$]`` represents an operator form of ``XMLMatchQ`` that can be applied to an element.

## Details and Options

``XMLMatchQ`` tests ``element$`` itself, as ``StringMatchQ`` tests a whole string. Constraints in ``pattern$`` test the elements below it.

``pattern$`` can have the following forms, each of which can be named, have a condition, as in ``x : XMLPattern["p"] /; test``, or have a test, as in ``XMLPattern["p"]?f``:

| form | description |
| :--- | :--- |
| ``XMLPattern[$$]`` | an element pattern, which can have constraints on the elements below it |
| ``XMLElement[$$]`` | an element pattern matched exactly as written, text included |
| ``"selector$"`` | a CSS selector for one element, one that depends only on its element and what is below it, such as ``"a.external"`` |
| ``XMLDocument[$$]`` | a pattern for a document, which tests an ``XMLObject`` |
| ``{p$1, p$2, $$}`` | a list pattern, which tests a list of elements, with strings left out |
| ``Alternatives[p$1, p$2]`` | any of the patterns |

Any expression can be tested: one that is not of the kind that ``pattern$`` matches gives ``False``.

Names in ``pattern$`` do not change the result except through a condition.

``XMLMatchQ`` issues a message and returns ``$Failed`` if ``pattern$`` is a malformed ``XMLPattern``, a rule ``pattern$ :> rhs$``, or a CSS selector that depends on what is above or beside its element, such as ``"nav a"`` or ``"li:first-child"``.

The following option can be given:

| option | default | description |
| :--- | :--- | :--- |
| ``"AttributeReadings"`` | ``<\|\|>`` | attributes to split into lists of tokens for this call, in addition to ``$AttributeReadings`` |

In the operator form, give options with the pattern: ``XMLMatchQ[pattern$, opts$$][element$]``.

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Test whether an element has a given tag:

```wl
In[1]:= XMLMatchQ[XMLElement["p", {"class" -> "lead"}, {"Intro."}], XMLPattern["p"]]

Out[1]= True
```

---

Test whether an element has the class ``lead``:

```wl
In[1]:= XMLMatchQ[XMLElement["p", {"class" -> "lead disclaimer"}, {"Intro."}], XMLPattern["p", "classList" -> "lead"]]

Out[1]= True
```

---

Test whether a list has an item, with a constraint on its children:

```wl
In[1]:= XMLMatchQ[XMLElement["ul", {}, {XMLElement["li", {}, {"Miso"}]}], XMLPattern["ul"][Child[XMLPattern["li"]]]]

Out[1]= True
```

---

Use the operator form to select the links that have a target:

```wl
In[1]:= links = {XMLElement["a", {"href" -> "/home"}, {"Home"}], XMLElement["a", {"name" -> "top"}, {"Top"}]};
Select[links, XMLMatchQ[XMLPattern["a", "href"]]]

Out[1]= {XMLElement["a", {"href" -> "/home"}, {"Home"}]}
```

### Scope

---

Match any of several element patterns with ``Alternatives``:

```wl
In[1]:= XMLMatchQ[XMLElement["h2", {}, {"Sub"}], XMLPattern["h1"] | XMLPattern["h2"]]

Out[1]= True
```

---

Test a value bound in the pattern with a ``Condition``:

```wl
In[1]:= XMLMatchQ[XMLElement["a", {"href" -> "https://example.com"}, {"Example"}], XMLPattern["a", "href" -> href_] /; StringStartsQ[href, "https:"]]

Out[1]= True
```

---

Name the whole element and test it with a ``Condition``:

```wl
In[1]:= XMLMatchQ[XMLElement["p", {}, {"Hello"}], element : XMLPattern["p"] /; HTMLTextContent[element] =!= ""]

Out[1]= True
```

---

Check for several classes in any order with ``ContainsAll``:

```wl
In[1]:= XMLMatchQ[XMLElement["li", {"class" -> "item active"}, {"A"}], XMLPattern["li", "classList" -> _?(ContainsAll[{"active", "item"}])]]

Out[1]= True
```

---

Test for an element anywhere below, or at a given depth:

```wl
In[1]:= element = XMLElement["p", {}, {XMLElement["i", {}, {XMLElement["b", {}, {"bold"}]}]}];
{XMLMatchQ[element, XMLPattern["p"][Descendant[XMLPattern["b"]]]], XMLMatchQ[element, XMLPattern["p"][Descendant[XMLPattern["b"], {1}]]]}

Out[1]= {True, False}
```

---

Give an ``XMLElement`` pattern to match the contents exactly, text included:

```wl
In[1]:= element = XMLElement["p", {}, {"Hello"}];
{XMLMatchQ[element, XMLElement["p", _, {"Hello"}]], XMLMatchQ[element, XMLElement["p", _, {}]]}

Out[1]= {True, False}
```

---

Test a document with an ``XMLDocument`` pattern:

```wl
In[1]:= page = ImportString["<html><body><p>Text</p></body></html>", {"HTML", "XMLObject"}];
XMLMatchQ[page, XMLDocument[{XMLPattern["html"]}]]

Out[1]= True
```

---

Test a list of elements with a list pattern, which leaves out strings:

```wl
In[1]:= XMLMatchQ[{XMLElement["th", {}, {"Day"}], "\n", XMLElement["td", {}, {"Friday"}]}, {XMLPattern["th"], ___}]

Out[1]= True
```

---

Give a CSS selector for one element:

```wl
In[1]:= XMLMatchQ[XMLElement["a", {"class" -> "external", "href" -> "https://example.org"}, {"Example"}], "a.external[href]"]

Out[1]= True
```

Give a selector that depends on what is below the element:

```wl
In[2]:= XMLMatchQ[XMLElement["div", {}, {XMLElement["table", {}, {}]}], "div:has(> table)"]

Out[2]= True
```

---

Test only the element itself, not the elements inside it:

```wl
In[1]:= XMLMatchQ[XMLElement["div", {}, {XMLElement["p", {}, {"text"}]}], XMLPattern["p"]]

Out[1]= False
```

---

Test an expression that is not an element:

```wl
In[1]:= XMLMatchQ["text", XMLPattern["p"]]

Out[1]= False
```

### Options

#### AttributeReadings

---

Split ``rel`` into tokens, held at the list key ``"relList"``, and match one:

```wl
In[1]:= XMLMatchQ[XMLElement["a", {"rel" -> "nofollow noopener", "href" -> "/ad"}, {"Ad"}], XMLPattern["a", "relList" -> "nofollow"], "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= True
```

Without the option, ``"relList"`` is an ordinary key, and the element has no such attribute:

```wl
In[2]:= XMLMatchQ[XMLElement["a", {"rel" -> "nofollow noopener", "href" -> "/ad"}, {"Ad"}], XMLPattern["a", "relList" -> "nofollow"]]

During evaluation of In[2]:= XMLPattern::nolistreading: "rel" has no entry in $AttributeReadings, so the key "relList" is matched as an attribute of that name. To split "rel" into tokens, add an entry: $AttributeReadings["rel"] = <||> for the session, or "AttributeReadings" -> <|"rel" -> <||>|> in the call.

Out[2]= False
```

---

In the operator form, give the option with the pattern:

```wl
In[1]:= links = {XMLElement["a", {"rel" -> "nofollow"}, {"Ad"}], XMLElement["a", {"href" -> "/home"}, {"Home"}]};
Select[links, XMLMatchQ[XMLPattern["a", "relList" -> _?(FreeQ["nofollow"])], "AttributeReadings" -> <|"rel" -> <||>|>]]

Out[1]= {XMLElement["a", {"href" -> "/home"}, {"Home"}]}
```

### Applications

---

Split the links of a page into absolute and relative ones:

```wl
In[1]:= page = ImportString["<p><a href=\"https://w3.org\">W3C</a> <a href=\"/about\">About</a> <a href=\"http://example.com\">Example</a> <a name=\"top\">Top</a></p>", {"HTML", "XMLObject"}];
GroupBy[XMLCases[page, XMLPattern["a", "href"]], XMLMatchQ[XMLPattern["a", "href" -> _?(StringStartsQ["http"])]] -> HTMLTextContent]

Out[1]= <|True -> {"W3C", "Example"}, False -> {"About"}|>
```

---

Count the list items that have the class ``active``:

```wl
In[1]:= menu = ImportString["<ul><li class=\"item active\">A</li><li class=\"item\">B</li><li class=\"active\">C</li></ul>", {"HTML", "XMLObject"}];
Count[XMLCases[menu, XMLPattern["li"]], _?(XMLMatchQ[XMLPattern["li", "classList" -> "active"]])]

Out[1]= 2
```

---

Test the elements on the path to a link, here for a link outside any nav:

```wl
In[1]:= page = ImportString["<body><nav><a href=\"/\">Home</a></nav><p>See <a href=\"/about\">About</a>.</p></body>", {"HTML", "XMLObject"}];
XMLCases[page, XMLDocument[Descendant[x : XMLPattern["a"]]?(NoneTrue[XMLMatchQ["nav"]])] :> HTMLTextContent[x]]

Out[1]= {"About"}
```

### Properties & Relations

---

``XMLCases`` searches inside an element, and ``XMLMatchQ`` tests only the element itself:

```wl
In[1]:= div = XMLElement["div", {}, {XMLElement["p", {}, {"text"}]}];
{XMLMatchQ[div, XMLPattern["p"]], XMLCases[div, XMLPattern["p"]]}

Out[1]= {False, {XMLElement["p", {}, {"text"}]}}
```

---

``XMLFreeQ`` tests every element of a tree, and ``XMLMatchQ`` only the element given:

```wl
In[1]:= div = XMLElement["div", {}, {XMLElement["p", {}, {"text"}]}];
{XMLMatchQ[div, XMLPattern["p"]], XMLFreeQ[div, XMLPattern["p"]]}

Out[1]= {False, False}
```

---

The list key ``"classList"`` gives the same classes as ``HTMLClassList``:

```wl
In[1]:= element = XMLElement["p", {"class" -> "lead disclaimer"}, {"Intro."}];
{XMLMatchQ[element, XMLPattern["p", "classList" -> "lead"]], MemberQ[HTMLClassList[element], "lead"]}

Out[1]= {True, True}
```

### Possible Issues

---

A CSS selector that depends on what is above its element gives ``$Failed``:

```wl
In[1]:= XMLMatchQ[XMLElement["a", {}, {}], "nav a"]

During evaluation of In[1]:= XMLMatchQ::badpat: The pattern should be an XMLPattern, an XMLElement pattern, an XMLDocument pattern, a list pattern for a list of elements, or a CSS selector string for one element, or alternatives of these, any of them named, with a condition pat /; test or a test pat?f. A rule gives a value, not a test. A CSS selector such as "nav a" or "ul > li" depends on what is above the element, which a lone element does not have; use XMLCases or XMLPosition to search a tree with it. Got "nav a".

Out[1]= $Failed
```

Search a tree with the selector instead:

```wl
In[2]:= XMLCases[XMLElement["nav", {}, {XMLElement["a", {}, {}]}], "nav a"]

Out[2]= {XMLElement["a", {}, {}]}
```

---

A rule gives ``$Failed``, since it gives a value rather than a test:

```wl
In[1]:= XMLMatchQ[XMLElement["a", {}, {}], x : XMLPattern["a"] :> x]

During evaluation of In[1]:= XMLMatchQ::badpat: The pattern should be an XMLPattern, an XMLElement pattern, an XMLDocument pattern, a list pattern for a list of elements, or a CSS selector string for one element, or alternatives of these, any of them named, with a condition pat /; test or a test pat?f. A rule gives a value, not a test. A CSS selector such as "nav a" or "ul > li" depends on what is above the element, which a lone element does not have; use XMLCases or XMLPosition to search a tree with it. Got x:XMLPattern["a"] :> x.

Out[1]= $Failed
```

---

An element tested against an ``XMLDocument`` pattern gives ``False``:

```wl
In[1]:= XMLMatchQ[XMLElement["html", {}, {}], XMLDocument[{XMLPattern["html"]}]]

Out[1]= False
```

---

A list of elements tested against an element pattern gives ``False``:

```wl
In[1]:= XMLMatchQ[{XMLElement["a", {}, {}]}, XMLPattern["a"]]

Out[1]= False
```

---

``Child[a, b]`` is not a pattern, and gives ``$Failed``:

```wl
In[1]:= XMLMatchQ[XMLElement["div", {}, {XMLElement["p", {}, {}]}], Child[XMLPattern["div"], XMLPattern["p"]]]

During evaluation of In[1]:= Child::place: Child[XMLPattern["div"], XMLPattern["p"]] is not a pattern. Child is a constraint, which can only be an argument of the bracket after XMLPattern[tag, attrs] or of XMLDocument: XMLPattern["ul"][Child[x : XMLPattern["li"]]] :> x gives the li children of each ul. Child takes one pattern: for children that match several patterns, give several constraints, Child[a], Child[b], or a list, {___, a, ___, b, ___}.

Out[1]= $Failed
```

Test the children with a constraint instead:

```wl
In[2]:= XMLMatchQ[XMLElement["div", {}, {XMLElement["p", {}, {}]}], XMLPattern["div"][Child[XMLPattern["p"]]]]

Out[2]= True
```

---

A malformed pattern gives ``$Failed`` rather than ``False``:

```wl
In[1]:= XMLMatchQ[XMLElement["div", {"class" -> "col-6"}, {}], XMLPattern["div", "classList" -> "col-" ~~ __]]

During evaluation of In[1]:= XMLPattern::strpat: "col-"~~__ is a string pattern, and in an XMLPattern it does not match any string. Write _?(StringMatchQ["col-"~~__]) instead.

Out[1]= $Failed
```

Test the classes with ``StringMatchQ`` instead:

```wl
In[2]:= XMLMatchQ[XMLElement["div", {"class" -> "col-6"}, {}], XMLPattern["div", "classList" -> _?(AnyTrue[StringMatchQ["col-" ~~ __]])]]

Out[2]= True
```

---

``MatchQ`` treats an ``XMLPattern`` as a literal expression, as it treats a string pattern:

```wl
In[1]:= {MatchQ[XMLElement["p", {}, {}], XMLPattern["p"]], XMLMatchQ[XMLElement["p", {}, {}], XMLPattern["p"]]}

Out[1]= {False, True}
```

Compare with string patterns:

```wl
In[2]:= {MatchQ["abc", "a" ~~ __], StringMatchQ["abc", "a" ~~ __]}

Out[2]= {False, True}
```

## See Also

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [XMLFreeQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFreeQ)

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [XMLDocument](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDocument)

* [Descendant](paclet:MaximilienTirard/HTMLPatterns/ref/Descendant)

* [Child](paclet:MaximilienTirard/HTMLPatterns/ref/Child)

* [FromCSSSelector](paclet:MaximilienTirard/HTMLPatterns/ref/FromCSSSelector)

* [HTMLClassList](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLClassList)

* [$AttributeReadings](paclet:MaximilienTirard/HTMLPatterns/ref/$AttributeReadings)

* [MatchQ](paclet:ref/MatchQ)

* [StringMatchQ](paclet:ref/StringMatchQ)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
