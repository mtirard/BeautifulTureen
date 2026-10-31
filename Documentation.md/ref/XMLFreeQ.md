# XMLFreeQ

   ``XMLFreeQ[tree$, pattern$]`` gives ``True`` if no element of ``tree$``, ``tree$`` itself included, matches ``pattern$``, and ``False`` otherwise.
   ``XMLFreeQ[tree$, pattern$, levelspec$]`` tests only the elements at the depths in ``levelspec$``.
   ``XMLFreeQ[pattern$]`` represents an operator form of ``XMLFreeQ`` that can be applied to a tree.

## Details and Options

``XMLFreeQ`` tests each element of ``tree$`` as ``XMLMatchQ`` does, and gives ``True`` when none of them matches.

In ``levelspec$``, ``tree$`` is at depth 0 and its children at depth 1. ``levelspec$`` has the following forms:

| form | description |
| :--- | :--- |
| ``n$`` | depths 1 to ``n$`` |
| ``{n$}`` | depth ``n$`` only |
| ``{m$, n$}`` | depths ``m$`` to ``n$`` |
| ``Infinity`` | depths 1 and below |
| ``{0, Infinity}`` | ``tree$`` itself and all depths below it, the default |

For a list, the elements of the list are at depth 1. For an ``XMLObject``, the document is at depth 0 and its root element at depth 1.

``tree$`` can be an ``XMLObject``, an ``XMLElement``, or a list of elements and strings.

``pattern$`` can be an ``XMLPattern``, an ``XMLElement`` pattern, an ``XMLDocument`` pattern, which matches only a document at depth 0, a CSS selector for one element, such as ``"a.ext"``, or alternatives of these. Each can be named, have a condition or have a test.

``XMLFreeQ`` issues a message and returns ``$Failed`` when ``tree$`` has none of the forms above, or when ``pattern$`` is a malformed ``XMLPattern``, a rule, or a CSS selector that depends on what is above or beside its element, such as ``"nav a"``.

The operator form ``XMLFreeQ[pattern$]`` takes no level spec. Give options with the pattern: ``XMLFreeQ[pattern$, opts$$][tree$]``.

The following option can be given:

| option | default | description |
| :--- | :--- | :--- |
| ``"AttributeReadings"`` | ``<\|\|>`` | attributes to split into lists of tokens for this call, in addition to ``$AttributeReadings`` |

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Test whether a tree has no table:

```wl
In[1]:= page = ImportString["<div><p>Text</p></div>", {"HTML", "XMLObject"}];
XMLFreeQ[page, XMLPattern["table"]]

Out[1]= True
```

---

Test only the elements below an element, and not the element itself:

```wl
In[1]:= navs = XMLElement["nav", {}, {XMLElement["a", {}, {"Home"}]}];
{XMLFreeQ[navs, XMLPattern["nav"]], XMLFreeQ[navs, XMLPattern["nav"], {1, Infinity}]}

Out[1]= {False, True}
```

### Scope

---

Test only the children:

```wl
In[1]:= element = XMLElement["p", {}, {XMLElement["i", {}, {XMLElement["b", {}, {"bold"}]}]}];
{XMLFreeQ[element, XMLPattern["b"], {1}], XMLFreeQ[element, XMLPattern["b"], {2}]}

Out[1]= {True, False}
```

---

Use the operator form to select the paragraphs with no link:

```wl
In[1]:= paras = {XMLElement["p", {}, {"Plain"}], XMLElement["p", {}, {XMLElement["a", {"href" -> "/"}, {"Link"}]}]};
Select[paras, XMLFreeQ[XMLPattern["a"]]]

Out[1]= {XMLElement["p", {}, {"Plain"}]}
```

---

Give a CSS selector for one element:

```wl
In[1]:= page = ImportString["<p><a class=\"ext\" href=\"https://w3.org\">W3C</a></p>", {"HTML", "XMLObject"}];
XMLFreeQ[page, "a.ext"]

Out[1]= False
```

---

Test for an empty list with a constraint on the children:

```wl
In[1]:= page = ImportString["<ul><li>Miso</li></ul><ol></ol>", {"HTML", "XMLObject"}];
XMLFreeQ[page, XMLPattern["ol" | "ul"][{}]]

Out[1]= False
```

---

Give an ``XMLDocument`` pattern to test the document at depth 0:

```wl
In[1]:= page = ImportString["<html><body></body></html>", {"HTML", "XMLObject"}];
XMLFreeQ[page, XMLDocument[{XMLPattern["html"]}]]

Out[1]= False
```

### Options

#### AttributeReadings

---

Split rel into tokens, and test for a link with one of them:

```wl
In[1]:= links = {XMLElement["a", {"rel" -> "nofollow noopener"}, {}]};
XMLFreeQ[links, XMLPattern["a", "relList" -> "nofollow"], "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= False
```

### Applications

---

Select the paragraphs that hold no bold text, as the CSS selector ``p:not(:has(b))`` does:

```wl
In[1]:= page = ImportString["<p>Plain</p><p>Some <b>bold</b></p>", {"HTML", "XMLObject"}];
XMLCases[page, x : XMLPattern["p"]?(XMLFreeQ[#, XMLPattern["b"], {1, Infinity}] &) :> HTMLTextContent[x]]

Out[1]= {"Plain"}
```

### Properties & Relations

---

``FromCSSSelector`` translates ``:not(:has(...))`` to ``XMLFreeQ``:

```wl
In[1]:= FromCSSSelector["p:not(:has(b))"]

Out[1]= (XMLPattern["p"])?(XMLFreeQ[#1, XMLPattern["b"], {1, ∞}] &)
```

---

``XMLFreeQ`` at depths 1 and below gives the opposite of a ``Descendant`` constraint:

```wl
In[1]:= element = XMLElement["p", {}, {XMLElement["i", {}, {XMLElement["b", {}, {"x"}]}]}];
{XMLFreeQ[element, XMLPattern["b"], {1, Infinity}], XMLMatchQ[element, XMLPattern["p"][Descendant[XMLPattern["b"]]]]}

Out[1]= {False, True}
```

---

For an ``XMLObject``, ``XMLFreeQ`` gives ``True`` exactly when ``XMLCases`` gives ``{}``:

```wl
In[1]:= page = ImportString["<div><p>a</p></div>", {"HTML", "XMLObject"}];
Table[XMLFreeQ[page, pattern] === (XMLCases[page, pattern] === {}), {pattern, {XMLPattern["p"], XMLPattern["table"]}}]

Out[1]= {True, True}
```

For an ``XMLElement``, ``XMLCases`` never gives the tree itself, so compare at depths 1 and below:

```wl
In[2]:= element = XMLElement["p", {}, {"a"}];
{XMLFreeQ[element, XMLPattern["p"]], XMLFreeQ[element, XMLPattern["p"], {1, Infinity}], XMLCases[element, XMLPattern["p"]]}

Out[2]= {False, True, {}}
```

### Possible Issues

---

``FreeQ`` treats an ``XMLPattern`` as a literal expression:

```wl
In[1]:= page = ImportString["<div><p>a</p></div>", {"HTML", "XMLObject"}];
{FreeQ[page, XMLPattern["p"]], XMLFreeQ[page, XMLPattern["p"]]}

Out[1]= {True, False}
```

---

The default level spec includes the tree itself:

```wl
In[1]:= element = XMLElement["nav", {}, {XMLElement["a", {}, {}]}];
XMLFreeQ[element, XMLPattern["nav"]]

Out[1]= False
```

---

A level spec gives depths in the tree, not levels of the expression:

```wl
In[1]:= element = XMLElement["div", {}, {XMLElement["p", {}, {}]}];
{XMLFreeQ[element, XMLPattern["p"], {1}], FreeQ[element, XMLElement["p", __], {1}]}

Out[1]= {False, True}
```

---

A rule gives ``$Failed``:

```wl
In[1]:= XMLFreeQ[XMLElement["p", {}, {}], x : XMLPattern["p"] :> x]

During evaluation of In[1]:= XMLFreeQ::badpat: The pattern should be an XMLPattern, an XMLElement pattern, an XMLDocument pattern, which matches only a document at depth 0, or a CSS selector string for one element, or alternatives of these, any of them named, with a condition pat /; test or a test pat?f. A rule gives a value, not a test. A CSS selector such as "nav a" or "ul > li" depends on what is above the element it selects; use XMLCases or XMLPosition to search a tree with it. Got x:XMLPattern["p"] :> x.

Out[1]= $Failed
```

---

A CSS selector that depends on what is above its element gives ``$Failed``:

```wl
In[1]:= XMLFreeQ[XMLElement["nav", {}, {XMLElement["a", {}, {}]}], "nav a"]

During evaluation of In[1]:= XMLFreeQ::badpat: The pattern should be an XMLPattern, an XMLElement pattern, an XMLDocument pattern, which matches only a document at depth 0, or a CSS selector string for one element, or alternatives of these, any of them named, with a condition pat /; test or a test pat?f. A rule gives a value, not a test. A CSS selector such as "nav a" or "ul > li" depends on what is above the element it selects; use XMLCases or XMLPosition to search a tree with it. Got "nav a".

Out[1]= $Failed
```

Test for a nav with a link below it instead:

```wl
In[2]:= XMLFreeQ[XMLElement["nav", {}, {XMLElement["a", {}, {}]}], XMLPattern["nav"][Descendant[XMLPattern["a"]]]]

Out[2]= False
```

## See Also

* [XMLMatchQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLMatchQ)

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [Descendant](paclet:MaximilienTirard/HTMLPatterns/ref/Descendant)

* [Child](paclet:MaximilienTirard/HTMLPatterns/ref/Child)

* [XMLDocument](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDocument)

* [FromCSSSelector](paclet:MaximilienTirard/HTMLPatterns/ref/FromCSSSelector)

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [FreeQ](paclet:ref/FreeQ)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
