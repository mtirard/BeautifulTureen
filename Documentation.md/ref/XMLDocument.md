# XMLDocument

   ``XMLDocument[c$1, c$2, $$]`` matches the document, the parent of the top-level elements of a tree, when each constraint ``c$i`` holds below it.
   ``XMLDocument[]`` matches any document.

## Details and Options

The top-level elements of a tree are the root element of an ``XMLObject``, each ``XMLElement`` in a list, or a bare ``XMLElement`` itself. ``XMLDocument`` matches the document above them.

Each ``c$i`` is a constraint, a condition on what is below the document, as in ``XMLPattern``: a list pattern over the top-level elements, text left out, ``Child[p$]`` for a top-level element, ``Descendant[p$]``, ``Descendant[p$, levelspec$]``, or alternatives of these.

``XMLDocument`` can only be the outermost pattern: the whole pattern, named, with a condition or a test, or one of the alternatives at the top, as in ``Alternatives[XMLPattern[_][l$], XMLDocument[l$]]``. Elsewhere it gives a message.

The position of the document is ``{}``. A name for the whole ``XMLDocument`` pattern gives the tree for an ``XMLObject`` or a list, and ``{e$}`` for a bare element ``e$``.

``XMLMatchQ[tree$, XMLDocument[$$]]`` can give ``True`` only for an ``XMLObject``.

``XMLDocument[]`` with no constraints matches any document.

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Give the p elements at the top of a list, and not those nested in other elements:

```wl
In[1]:= fragment = {XMLElement["p", {}, {"One"}], "text", XMLElement["div", {}, {XMLElement["p", {}, {"Nested"}]}], XMLElement["p", {}, {"Two"}]};
XMLCases[fragment, XMLDocument[Child[x : XMLPattern["p"]]] :> x]

Out[1]= {XMLElement["p", {}, {"One"}], XMLElement["p", {}, {"Two"}]}
```

---

Give the links that are not inside a nav, by testing every ancestor of each link:

```wl
In[1]:= page = ImportString["<body><nav><a href=\"/\">Home</a></nav><p>See <a href=\"/about\">About</a>.</p></body>", {"HTML", "XMLObject"}];
XMLCases[page, XMLDocument[Descendant[x : XMLPattern["a"]]?(NoneTrue[XMLMatchQ["nav"]])] :> HTMLTextContent[x]]

Out[1]= {"About"}
```

### Scope

---

Give the tag of the root element, the only top-level element of a document:

```wl
In[1]:= page = ImportString["<html><body><p>Text</p></body></html>", {"HTML", "XMLObject"}];
XMLCases[page, XMLDocument[{x_}] :> First[x]]

Out[1]= {"html"}
```

---

Test whether a document has an html root element:

```wl
In[1]:= page = ImportString["<html><body><p>Text</p></body></html>", {"HTML", "XMLObject"}];
XMLMatchQ[page, XMLDocument[{XMLPattern["html"]}]]

Out[1]= True
```

---

Give one list pattern for the children of any element and for the top-level elements:

```wl
In[1]:= fragment = {XMLElement["li", {}, {"Top"}], XMLElement["ul", {}, {XMLElement["li", {}, {"In a list"}], XMLElement["li", {}, {"Second"}]}]};
XMLCases[fragment, Alternatives[XMLPattern[_][{x : XMLPattern["li"], ___}], XMLDocument[{x : XMLPattern["li"], ___}]] :> HTMLTextContent[x]]

Out[1]= {"Top", "In a list"}
```

---

Name a ``Descendant`` constraint to get every ancestor of the match:

```wl
In[1]:= page = ImportString["<html><body><nav><a href=\"/\">Home</a></nav></body></html>", {"HTML", "XMLObject"}];
XMLCases[page, XMLDocument[path : Descendant[XMLPattern["a"]]] :> Map[First, path]]

Out[1]= {{"html", "body", "nav"}}
```

---

Find the direct children of an element, as BeautifulSoup's ``recursive=False`` does:

```wl
In[1]:= section = XMLElement["section", {}, {XMLElement["p", {}, {"Direct"}], XMLElement["div", {}, {XMLElement["p", {}, {"Nested"}]}]}];
XMLCases[section, XMLDocument[{XMLPattern[_][Child[x : XMLPattern["p"]]]}] :> x]

Out[1]= {XMLElement["p", {}, {"Direct"}]}
```

---

Delete the top-level p elements of a list:

```wl
In[1]:= fragment = {XMLElement["p", {}, {"One"}], XMLElement["div", {}, {XMLElement["p", {}, {"Nested"}]}]};
XMLDeleteCases[fragment, XMLDocument[Child[x : XMLPattern["p"]]] :> x]

Out[1]= {XMLElement["div", {}, {XMLElement["p", {}, {"Nested"}]}]}
```

---

Name the document to give it as a result, at position ``{}``:

```wl
In[1]:= fragment = {XMLElement["p", {}, {"One"}], XMLElement["p", {}, {"Two"}]};
{XMLCases[fragment, d : XMLDocument[{XMLPattern["p"], ___}] :> Length[d]], XMLPosition[fragment, d : XMLDocument[{XMLPattern["p"], ___}] :> d]}

Out[1]= {{2}, {{}}}
```

### Properties & Relations

---

``FromCSSSelector`` gives ``XMLDocument`` patterns for the CSS selectors ``:root`` and ``:scope``:

```wl
In[1]:= {FromCSSSelector[n : ":root"], FromCSSSelector[n : ":scope > p"]}

Out[1]= {XMLDocument[{n : XMLPattern[_]}], XMLDocument[{XMLPattern[_][Child[n : XMLPattern["p"]]]}]}
```

---

With one ``Descendant`` constraint, ``XMLDocument`` gives what the inner pattern gives:

```wl
In[1]:= page = ImportString["<html><body><p>One</p><div><p>Two</p></div></body></html>", {"HTML", "XMLObject"}];
XMLCases[page, XMLDocument[Descendant[x : XMLPattern["p"]]] :> x] === XMLCases[page, XMLPattern["p"]]

Out[1]= True
```

### Possible Issues

---

``XMLMatchQ`` gives ``False`` for an element tested against an ``XMLDocument`` pattern:

```wl
In[1]:= XMLMatchQ[XMLElement["p", {}, {"Text"}], XMLDocument[{XMLPattern["p"]}]]

Out[1]= False
```

Test a list of elements against a list pattern instead:

```wl
In[2]:= XMLMatchQ[{XMLElement["p", {}, {"Text"}]}, {XMLPattern["p"]}]

Out[2]= True
```

---

A bare element given as the tree is never a result, even as a top-level element:

```wl
In[1]:= XMLCases[XMLElement["p", {}, {"Text"}], XMLDocument[{x : XMLPattern["p"]}] :> x]

Out[1]= {}
```

---

``XMLDocument`` can only be the outermost pattern:

```wl
In[1]:= navs = ImportString["<nav><a>Home</a></nav>", {"HTML", "XMLObject"}];
XMLCases[navs, XMLPattern["nav"][Descendant[XMLDocument[]]]]

During evaluation of In[1]:= XMLDocument::place: XMLDocument[...] matches only the document above the top-level elements, so it can only be the outermost pattern: the whole query, named, conditioned or tested, or a branch of alternatives at the top, as in XMLPattern[_][L] | XMLDocument[L]. It cannot be inside Descendant, an attribute pattern or an XMLElement pattern. Got XMLDocument[].

Out[1]= $Failed
```

---

A list pattern leaves out text, so ``":root"`` matches even with text at the top:

```wl
In[1]:= XMLCases[{"Text", XMLElement["p", {}, {"Para"}]}, ":root"]

Out[1]= {XMLElement["p", {}, {"Para"}]}
```

---

On a list of several top-level elements, ``":root"`` and ``":scope > p"`` give nothing:

```wl
In[1]:= fragment = {XMLElement["p", {}, {"One"}], XMLElement["p", {}, {"Two"}]};
{XMLCases[fragment, ":root"], XMLCases[fragment, ":scope > p"]}

Out[1]= {{}, {}}
```

Give a ``Child`` constraint to ``XMLDocument`` instead:

```wl
In[2]:= XMLCases[fragment, XMLDocument[Child[x : XMLPattern["p"]]] :> x]

Out[2]= {XMLElement["p", {}, {"One"}], XMLElement["p", {}, {"Two"}]}
```

---

``XMLDeleteCases`` keeps the root element of a document, which an ``XMLObject`` needs:

```wl
In[1]:= page = ImportString["<html><body><p>Text</p></body></html>", {"HTML", "XMLObject"}];
XMLDeleteCases[page, XMLDocument[{x : XMLPattern["html"]}] :> x] === page

During evaluation of In[1]:= XMLDeleteCases::root: The root element of an XMLObject cannot be deleted; it was kept.

Out[1]= True
```

## See Also

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [Descendant](paclet:MaximilienTirard/HTMLPatterns/ref/Descendant)

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [XMLPosition](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPosition)

* [XMLMatchQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLMatchQ)

* [XMLDeleteCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDeleteCases)

* [FromCSSSelector](paclet:MaximilienTirard/HTMLPatterns/ref/FromCSSSelector)

* [Child](paclet:MaximilienTirard/HTMLPatterns/ref/Child)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
