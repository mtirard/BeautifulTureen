# XMLExtract

   ``XMLExtract[tree$, pos$]`` gives the part of ``tree$`` at ``pos$``, a position in the form that ``XMLPosition`` gives.
   ``XMLExtract[tree$, {pos$1, pos$2, $$}]`` gives a list of the parts at each ``pos$i``.

## Details and Options

When ``pattern$`` matches, ``XMLExtract[tree$, XMLPosition[tree$, pattern$]]`` gives what ``XMLCases[tree$, pattern$]`` gives. When nothing matches, ``XMLPosition`` gives ``{}``, which ``XMLExtract`` reads as the position of the document.

A position is a list of indices among element children, starting at the document at ``{}``. The root element of an ``XMLObject``, and an ``XMLElement`` given as the tree, are at ``{1}``; the ``i$``-th element of a list is at ``{i$}``.

A position for an element is a list of indices ``{i$1, i$2, $$}``. Other positions end in one of the following:

| end | part |
| :--- | :--- |
| ``0`` | the tag |
| ``Key[All]`` | the attribute list |
| ``Key["key$"]`` | the value of an attribute, or of a list key such as ``"classList"``, whose value is a list of tokens taken from an attribute |
| ``Key["key$"], i$`` | the ``i$``-th token of a list key |
| ``All`` | the contents, text included |
| ``m$;;n$`` | the run of element children ``m$`` to ``n$``, as a sequence |
| ``n$;;n$-1`` | the gap before element child ``n$``, as ``Sequence[]`` |

``XMLExtract[tree$, upper$;;lower$]`` gives the list of the elements strictly between the element at ``upper$`` and the element at ``lower$``, outermost first. This is the value of a name on a ``Descendant`` constraint. ``upper$`` is ``{}`` or a position above ``lower$``.

A list is read as several positions when every entry is a list or a path.

``XMLExtract`` issues a message and returns ``$Failed`` when ``tree$`` has none of the forms that ``XMLCases`` accepts, when a position has none of the forms above, or when ``tree$`` has no part at a position.

The following option can be given:

| option | default | description |
| :--- | :--- | :--- |
| ``"AttributeReadings"`` | ``<\|\|>`` | attributes to split into lists of tokens for this call, in addition to ``$AttributeReadings`` |

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Give the element at a position:

```wl
In[1]:= listing = XMLElement["ul", {"class" -> "a b"}, {XMLElement["li", {}, {"one"}], " ", XMLElement["li", {}, {XMLElement["a", {"href" -> "/x"}, {"two"}]}]}];
XMLExtract[{listing}, {1, 2}]

Out[1]= XMLElement["li", {}, {XMLElement["a", {"href" -> "/x"}, {"two"}]}]
```

Give the parts at several positions:

```wl
In[2]:= XMLExtract[{listing}, {{1, 0}, {1, Key["class"]}, {1, 2, 1, Key["href"]}}]

Out[2]= {"ul", "a b", "/x"}
```

---

Give the parts at the positions that ``XMLPosition`` gives:

```wl
In[1]:= links = ImportString["<p><a href=\"/a\">A</a> and <a href=\"/b\">B</a></p>", {"HTML", "XMLObject"}];
XMLExtract[links, XMLPosition[links, XMLPattern["a", "href" -> h_] :> h]]

Out[1]= {"/a", "/b"}
```

### Scope

---

Give the document, the root element and its tag:

```wl
In[1]:= listing = XMLElement["ul", {"class" -> "a b"}, {XMLElement["li", {}, {"one"}], " ", XMLElement["li", {}, {XMLElement["a", {"href" -> "/x"}, {"two"}]}]}];
{XMLExtract[{listing}, {}], XMLExtract[{listing}, {1, 0}]}

Out[1]= {{XMLElement["ul", {"class" -> "a b"}, {XMLElement["li", {}, {"one"}], " ", XMLElement["li", {}, {XMLElement["a", {"href" -> "/x"}, {"two"}]}]}]}, "ul"}
```

---

Give the attribute list, an attribute value, the class list and one class:

```wl
In[1]:= listing = XMLElement["ul", {"class" -> "a b"}, {XMLElement["li", {}, {"one"}], " ", XMLElement["li", {}, {XMLElement["a", {"href" -> "/x"}, {"two"}]}]}];
XMLExtract[{listing}, {{1, Key[All]}, {1, Key["class"]}, {1, Key["classList"]}, {1, Key["classList"], 2}}]

Out[1]= {{"class" -> "a b"}, "a b", {"a", "b"}, "b"}
```

---

Give the contents of an element, text included:

```wl
In[1]:= listing = XMLElement["ul", {"class" -> "a b"}, {XMLElement["li", {}, {"one"}], " ", XMLElement["li", {}, {XMLElement["a", {"href" -> "/x"}, {"two"}]}]}];
XMLExtract[{listing}, {1, All}]

Out[1]= {XMLElement["li", {}, {"one"}], " ", XMLElement["li", {}, {XMLElement["a", {"href" -> "/x"}, {"two"}]}]}
```

Give the run of element children 1 to 2, a sequence that leaves out the text between them:

```wl
In[2]:= {XMLExtract[{listing}, {1, 1 ;; 2}]}

Out[2]= {XMLElement["li", {}, {"one"}], XMLElement["li", {}, {XMLElement["a", {"href" -> "/x"}, {"two"}]}]}
```

Give the gap between them, which is ``Sequence[]``:

```wl
In[3]:= {XMLExtract[{listing}, {1, 2 ;; 1}]}

Out[3]= {}
```

---

Give the elements strictly between two elements:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav></nav>", {"HTML", "XMLObject"}];
XMLExtract[navs, {1} ;; {1, 2, 1}]

Out[1]= {XMLElement["nav", {"id" -> "inner"}, {XMLElement["a", {"shape" -> "rect"}, {"News"}]}]}
```

Start at the document to get every element above an element:

```wl
In[2]:= Map[First, XMLExtract[navs, {} ;; {1, 2, 1}]]

Out[2]= {"nav", "nav"}
```

Get an empty list for a child and its parent:

```wl
In[3]:= XMLExtract[navs, {1} ;; {1, 1}]

Out[3]= {}
```

---

Give a part of an ``XMLElement`` given as the tree, which is at ``{1}``:

```wl
In[1]:= XMLExtract[XMLElement["ul", {}, {XMLElement["li", {}, {"a"}]}], {1, 1}]

Out[1]= XMLElement["li", {}, {"a"}]
```

### Options

#### AttributeReadings

---

Split rel into tokens, and give one with the list key "relList", whose value is the list of tokens:

```wl
In[1]:= link = XMLElement["a", {"rel" -> "nofollow noopener"}, {}];
XMLExtract[{link}, {1, Key["relList"], 2}, "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= "noopener"
```

### Properties & Relations

---

For a bare pattern, ``XMLExtract`` of ``XMLPosition`` gives what ``XMLCases`` gives:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav></nav>", {"HTML", "XMLObject"}];
XMLExtract[navs, XMLPosition[navs, XMLPattern["a"]]] === XMLCases[navs, XMLPattern["a"]]

Out[1]= True
```

---

``Extract`` counts text and the parts of an ``XMLObject``, and ``XMLExtract`` only element children:

```wl
In[1]:= tree = ImportString["<div><p>a</p>\n<p>b</p></div>", {"HTML", "XMLObject"}];
{Extract[tree, {2, 3, 1, 3, 1, 3, 3}], XMLExtract[tree, {1, 1, 1, 2}]}

Out[1]= {XMLElement["p", {}, {"b"}], XMLElement["p", {}, {"b"}]}
```

### Possible Issues

---

``XMLExtract`` issues a message for a position that is not of the forms that ``XMLPosition`` gives:

```wl
In[1]:= XMLExtract[{XMLElement["p", {}, {}]}, {0}]

During evaluation of In[1]:= XMLExtract::pos: {0} is not a position in an XML tree. A position is {} for the document or a list of element-child indices, optionally followed by 0, Key[All], Key[key] (then, for a list key, a token index, run or gap), All, or a run m ;; n or gap n ;; n-1 of element children; or upper ;; lower for the elements strictly between, where upper is {} or an element above the element lower.

Out[1]= $Failed
```

---

``XMLExtract`` issues a message for a position that the tree does not have:

```wl
In[1]:= XMLExtract[{XMLElement["ul", {}, {XMLElement["li", {}, {}]}]}, {1, 2}]

During evaluation of In[1]:= XMLExtract::nopos: There is no position {1, 2} in the tree.

Out[1]= $Failed
```

---

``XMLExtract`` issues a message for a path whose upper end is not above its lower end:

```wl
In[1]:= navs = ImportString["<nav id=\"outer\"><a>Home</a><nav id=\"inner\"><a>News</a></nav></nav>", {"HTML", "XMLObject"}];
XMLExtract[navs, {1, 1} ;; {1, 2, 1}]

During evaluation of In[1]:= XMLExtract::pos: {1, 1} ;; {1, 2, 1} is not a position in an XML tree. A position is {} for the document or a list of element-child indices, optionally followed by 0, Key[All], Key[key] (then, for a list key, a token index, run or gap), All, or a run m ;; n or gap n ;; n-1 of element children; or upper ;; lower for the elements strictly between, where upper is {} or an element above the element lower.

Out[1]= $Failed
```

---

A run of children is a sequence, so in a list of parts its elements are spliced in:

```wl
In[1]:= paras = XMLElement["div", {}, {XMLElement["p", {}, {"1"}], XMLElement["p", {}, {"2"}]}];
XMLExtract[{paras}, {{1, 1 ;; 2}, {1, 1}}]

Out[1]= {XMLElement["p", {}, {"1"}], XMLElement["p", {}, {"2"}], XMLElement["p", {}, {"1"}]}
```

---

With no match, XMLPosition gives ``{}``, the position of the document:

```wl
In[1]:= links = ImportString["<p><a href=\"/a\">A</a></p>", {"HTML", "XMLObject"}];
XMLPosition[links, XMLPattern["table"]]

Out[1]= {}
```

``XMLExtract`` reads it as the document:

```wl
In[2]:= XMLExtract[links, {}] === links

Out[2]= True
```

## See Also

* [XMLPosition](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPosition)

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [XMLReplace](paclet:MaximilienTirard/HTMLPatterns/ref/XMLReplace)

* [Descendant](paclet:MaximilienTirard/HTMLPatterns/ref/Descendant)

* [Child](paclet:MaximilienTirard/HTMLPatterns/ref/Child)

* [Extract](paclet:ref/Extract)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
