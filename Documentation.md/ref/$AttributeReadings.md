# $AttributeReadings

   ``$AttributeReadings`` is an ``Association`` of the attributes whose values ``XMLPattern`` can match as lists of tokens, such as ``class`` under the key ``"classList"``.

## Details and Options

For an attribute with an entry in ``$AttributeReadings``, ``XMLPattern`` takes a *list key*: a key such as ``"classList"``, whose value is a list of tokens taken from the attribute.

By default, only ``class`` has an entry, with the list key ``"classList"``.

At a list key, a string, or alternatives of strings, matches one token among several, and any other value is matched against the whole list. With an entry for ``rel``, ``"relList" -> "nofollow"`` matches an element whose ``rel`` contains the token ``nofollow``, and ``"relList" -> r_`` binds ``r`` to the list of tokens.

The option ``"AttributeReadings" -> entries$``, which ``XMLCases``, ``HTMLInnerText`` and most other functions of this paclet take, adds ``entries$`` for one call. An entry given in the option replaces the entry for the same attribute.

Each key is an attribute name given as a string. A namespaced attribute ``{namespace$, name$}`` cannot have an entry. Each value is an ``Association`` with any of the following fields:

| field | default | description |
| :--- | :--- | :--- |
| ``Method`` | ``"SpaceSeparated"`` | how the value is split: ``"SpaceSeparated"`` or ``"CommaSeparated"`` |
| ``Delimiters`` | ``Automatic`` | a string pattern to split the value on |
| ``"TrimWhitespace"`` | ``Automatic`` | whether to trim HTML whitespace from each token: ``True`` or ``False`` |
| ``"ListKey"`` | ``Automatic`` | the list key, a string; ``Automatic`` gives the attribute name followed by ``"List"`` |

``Method`` sets the defaults of ``Delimiters`` and ``"TrimWhitespace"``:

| name | default value | description |
| :--- | :--- | :--- |
| ``"SpaceSeparated"`` | ``HTMLWhitespace`` | ``False`` |
| ``"CommaSeparated"`` | ``","`` | ``True`` |

An explicit ``Delimiters`` or ``"TrimWhitespace"`` setting overrides the one from ``Method``.

For an element without the attribute, or with an empty or whitespace-only value, the list is ``{}``.

The key for the attribute itself still matches the whole value: with an entry for ``rel``, ``"rel" -> "nofollow"`` matches only the value ``nofollow``.

Assigning to ``$AttributeReadings`` changes the entries for all later calls.

A malformed entry gives a message, such as ``$AttributeReadings::badmethod``, and the function returns ``$Failed``.

``HTMLClassList`` does not depend on ``$AttributeReadings``.

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Show the default value, with an entry only for ``class``:

```wl
In[1]:= $AttributeReadings

Out[1]= <|"class" -> <|Method -> "SpaceSeparated", Delimiters -> Automatic, "TrimWhitespace" -> Automatic, "ListKey" -> Automatic|>|>
```

---

Add an entry for ``rel`` for one call, and find the links marked ``nofollow``:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow noopener\" href=\"/ad\">Ad</a><a href=\"/home\">Home</a><a rel=\"noopener\" href=\"/x\">X</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["a", "relList" -> "nofollow"], "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= {XMLElement["a", {"shape" -> "rect", "rel" -> "nofollow noopener", "href" -> "/ad"}, {"Ad"}]}
```

### Scope

---

Bind the list of tokens, which is empty for a link without ``rel``:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow noopener\" href=\"/ad\">Ad</a><a href=\"/home\">Home</a><a rel=\"noopener\" href=\"/x\">X</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["a", {"relList" -> rels_, "href" -> href_}] :> href -> rels, "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= {"/ad" -> {"nofollow", "noopener"}, "/home" -> {}, "/x" -> {"noopener"}}
```

---

Split a comma-separated attribute with the ``"CommaSeparated"`` method:

```wl
In[1]:= upload = ImportString["<form><input type=\"file\" accept=\"image/png, image/jpeg\"><input type=\"file\" accept=\".pdf\"></form>", {"HTML", "XMLObject"}];
XMLCases[upload, XMLPattern["input", "acceptList" -> types_] :> types, "AttributeReadings" -> <|"accept" -> <|Method -> "CommaSeparated"|>|>]

Out[1]= {{"image/png", "image/jpeg"}, {".pdf"}}
```

Find the inputs that accept PNG images:

```wl
In[2]:= XMLCases[upload, XMLPattern["input", "acceptList" -> "image/png"], "AttributeReadings" -> <|"accept" -> <|Method -> "CommaSeparated"|>|>]

Out[2]= {XMLElement["input", {"type" -> "file", "accept" -> "image/png, image/jpeg"}, {}]}
```

---

Choose the list key with ``"ListKey"``:

```wl
In[1]:= upload = ImportString["<form><input type=\"file\" accept=\"image/png, image/jpeg\"><input type=\"file\" accept=\".pdf\"></form>", {"HTML", "XMLObject"}];
XMLCases[upload, XMLPattern["input", "types" -> types_] :> types, "AttributeReadings" -> <|"accept" -> <|Method -> "CommaSeparated", "ListKey" -> "types"|>|>]

Out[1]= {{"image/png", "image/jpeg"}, {".pdf"}}
```

---

Split on any string pattern with ``Delimiters``:

```wl
In[1]:= tagged = XMLElement["div", {"data-tags" -> "news; sport ;weather"}, {}];
XMLCases[{tagged}, XMLPattern["div", "data-tagsList" -> tags_] :> tags, "AttributeReadings" -> <|"data-tags" -> <|Delimiters -> ";", "TrimWhitespace" -> True|>|>]

Out[1]= {{"news", "sport", "weather"}}
```

---

Add an entry for every call inside a ``Block`` by appending to ``$AttributeReadings``:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow noopener\" href=\"/ad\">Ad</a><a href=\"/home\">Home</a><a rel=\"noopener\" href=\"/x\">X</a></p>", {"HTML", "XMLObject"}];
Block[{$AttributeReadings = Append[$AttributeReadings, "rel" -> <||>]}, XMLCases[links, e : XMLPattern["a", "relList" -> "noopener"] :> HTMLTextContent[e]]]

Out[1]= {"Ad", "X"}
```

---

Check that a namespaced attribute has no list key, even when its local name is ``class``:

```wl
In[1]:= element = XMLElement["g", {{"urn:example", "class"} -> "a b"}, {}];
{XMLMatchQ[element, XMLPattern["g", "classList" -> "a"]], XMLMatchQ[element, XMLPattern["g", {"urn:example", "class"} -> "a b"]]}

Out[1]= {False, True}
```

---

Use a list key in the ``"Roles"`` option of ``HTMLInnerText``:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow noopener\" href=\"/ad\">Ad</a><a href=\"/home\">Home</a><a rel=\"noopener\" href=\"/x\">X</a></p>", {"HTML", "XMLObject"}];
HTMLInnerText[links, "Roles" -> {XMLPattern["a", "relList" -> "nofollow"] -> "Skip"}, "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= "HomeX"
```

### Applications

---

List the links that search engines are allowed to follow:

```wl
In[1]:= page = ImportString["<ul><li><a href=\"/docs\">Docs</a></li><li><a rel=\"sponsored nofollow\" href=\"https://ads.example\">Ad</a></li><li><a rel=\"noopener\" href=\"https://w3.org\">W3C</a></li></ul>", {"HTML", "XMLObject"}];
XMLCases[page, XMLPattern["a", {"relList" -> _?(FreeQ["nofollow"]), "href" -> href_}] :> href, "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= {"/docs", "https://w3.org"}
```

---

Map each table cell to the header ids in its ``headers`` attribute:

```wl
In[1]:= table = ImportString["<table><tr><th id=\"name\">Name</th><th id=\"q1\">Q1</th><th id=\"q2\">Q2</th></tr><tr><td headers=\"name\">Ada</td><td headers=\"q1 total\">3</td><td headers=\"q2 total\">5</td></tr></table>", {"HTML", "XMLObject"}];
XMLCases[table, e : XMLPattern["td", "headersList" -> ids_] :> HTMLTextContent[e] -> ids, "AttributeReadings" -> <|"headers" -> <||>|>]

Out[1]= {"Ada" -> {"name"}, "3" -> {"q1", "total"}, "5" -> {"q2", "total"}}
```

Select the cells that count towards the total:

```wl
In[2]:= XMLCases[table, e : XMLPattern["td", "headersList" -> "total"] :> HTMLTextContent[e], "AttributeReadings" -> <|"headers" -> <||>|>]

Out[2]= {"3", "5"}
```

### Properties & Relations

---

Replace the entry for ``class`` in the option, to match its tokens under another key:

```wl
In[1]:= element = XMLElement["p", {"class" -> "lead promo"}, {}];
XMLCases[{element}, XMLPattern["p", "classes" -> c_] :> c, "AttributeReadings" -> <|"class" -> <|"ListKey" -> "classes"|>|>]

Out[1]= {{"lead", "promo"}}
```

Get a message and no match for the key ``"classList"``:

```wl
In[2]:= XMLCases[{element}, XMLPattern["p", "classList" -> c_] :> c, "AttributeReadings" -> <|"class" -> <|"ListKey" -> "classes"|>|>]

During evaluation of In[2]:= XMLPattern::otherlistkey: The key "classList" is matched as an attribute of that name, but the tokens of "class" are under the list key "classes". Use "classes", or set "ListKey" -> "classList" in the entry for "class".

Out[2]= {}
```

---

Match the key ``"rel"`` against the whole value, even with an entry for ``rel``:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow noopener\" href=\"/ad\">Ad</a><a href=\"/home\">Home</a><a rel=\"noopener\" href=\"/x\">X</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, e : XMLPattern["a", "rel" -> "nofollow"] :> HTMLTextContent[e], "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= {}
```

---

Get a token that keeps a no-break space, since only HTML whitespace is trimmed:

```wl
In[1]:= element = XMLElement["input", {"accept" -> "image/png, \[NonBreakingSpace]image/gif"}, {}];
XMLCases[{element}, XMLPattern["input", "acceptList" -> types_] :> types, "AttributeReadings" -> <|"accept" -> <|Method -> "CommaSeparated"|>|>]

Out[1]= {{"image/png", "\[NonBreakingSpace]image/gif"}}
```

---

Compare the ``"classList"`` key with ``HTMLClassList``:

```wl
In[1]:= element = XMLElement["p", {"class" -> " lead\tpromo "}, {}];
{XMLCases[{element}, XMLPattern["p", "classList" -> c_] :> c], {HTMLClassList[element]}}

Out[1]= {{{"lead", "promo"}}, {{"lead", "promo"}}}
```

---

Use ``XMLMatchQ`` in a condition, where the option applies too:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow noopener\" href=\"/ad\">Ad</a><a href=\"/home\">Home</a><a rel=\"noopener\" href=\"/x\">X</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, e : XMLPattern["a"] /; ! XMLMatchQ[e, XMLPattern["a", "relList" -> "nofollow"]] :> HTMLTextContent[e], "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= {"Home", "X"}
```

### Possible Issues

---

Set ``$AttributeReadings`` in a ``Block``, which also removes the entry for ``class``:

```wl
In[1]:= element = XMLElement["p", {"class" -> "lead promo"}, {}];
Block[{$AttributeReadings = <|"rel" -> <||>|>}, XMLMatchQ[element, XMLPattern["p", "classList" -> "lead"]]]

During evaluation of In[1]:= XMLPattern::nolistreading: "class" has no entry in $AttributeReadings, so the key "classList" is matched as an attribute of that name. To split "class" into tokens, add an entry: $AttributeReadings["class"] = <||> for the session, or "AttributeReadings" -> <|"class" -> <||>|> in the call.

Out[1]= False
```

Append to ``$AttributeReadings`` instead, or use the ``"AttributeReadings"`` option:

```wl
In[2]:= Block[{$AttributeReadings = Append[$AttributeReadings, "rel" -> <||>]}, XMLMatchQ[element, XMLPattern["p", "classList" -> "lead"]]]

Out[2]= True
```

---

Match every element with a list key alone, even one without the attribute:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow noopener\" href=\"/ad\">Ad</a><a href=\"/home\">Home</a><a rel=\"noopener\" href=\"/x\">X</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, e : XMLPattern["a", "relList"] :> HTMLTextContent[e], "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= {"Ad", "Home", "X"}
```

Match a nonempty list, or the attribute itself:

```wl
In[2]:= {XMLCases[links, e : XMLPattern["a", "relList" -> {__}] :> HTMLTextContent[e], "AttributeReadings" -> <|"rel" -> <||>|>], XMLCases[links, e : XMLPattern["a", "rel"] :> HTMLTextContent[e]]}

Out[2]= {{"Ad", "X"}, {"Ad", "X"}}
```

---

Split a value that starts with a comma, and get no empty first token, where HTML gives one:

```wl
In[1]:= element = XMLElement["input", {"accept" -> ",image/png,,image/gif"}, {}];
XMLCases[{element}, XMLPattern["input", "acceptList" -> types_] :> types, "AttributeReadings" -> <|"accept" -> <|Method -> "CommaSeparated"|>|>]

Out[1]= {{"image/png", "", "image/gif"}}
```

---

Give the ``"AttributeReadings"`` option to the function, not to ``XMLPattern``:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow noopener\" href=\"/ad\">Ad</a><a href=\"/home\">Home</a><a rel=\"noopener\" href=\"/x\">X</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["a", "relList" -> "nofollow"]["AttributeReadings" -> <|"rel" -> <||>|>]]

During evaluation of In[1]:= XMLPattern::nolistreading: "rel" has no entry in $AttributeReadings, so the key "relList" is matched as an attribute of that name. To split "rel" into tokens, add an entry: $AttributeReadings["rel"] = <||> for the session, or "AttributeReadings" -> <|"rel" -> <||>|> in the call.

During evaluation of In[1]:= XMLPattern::constraint: "AttributeReadings" -> <|"rel" -> <||>|> is not a constraint. The constraints on what is below an element are the arguments of the bracket after XMLPattern[tag, attrs], as in XMLPattern[tag, attrs][c1, c2, ...]: Child[p] for some element child that matches p, a list pattern over its element children, as in {p} for an only child, or Descendant[p] for an element anywhere below. Attribute constraints go in the first bracket, several in one list: XMLPattern[tag, {a1, a2, ...}].

Out[1]= $Failed
```

Give it to ``XMLCases`` instead:

```wl
In[2]:= XMLCases[links, XMLPattern["a", "relList" -> "nofollow"], "AttributeReadings" -> <|"rel" -> <||>|>]

Out[2]= {XMLElement["a", {"shape" -> "rect", "rel" -> "nofollow noopener", "href" -> "/ad"}, {"Ad"}]}
```

---

Give a malformed entry to get a message and ``$Failed``:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow noopener\" href=\"/ad\">Ad</a><a href=\"/home\">Home</a><a rel=\"noopener\" href=\"/x\">X</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["a"], "AttributeReadings" -> <|"rel" -> <|Method -> "TabSeparated"|>|>]

During evaluation of In[1]:= $AttributeReadings::badmethod

Out[1]= $Failed
```

Give an attribute name that is not a string:

```wl
In[2]:= XMLCases[links, XMLPattern["a"], "AttributeReadings" -> <|{"urn:example", "rel"} -> <||>|>]

During evaluation of In[2]:= $AttributeReadings::badkey

Out[2]= $Failed
```

Give two entries the same list key:

```wl
In[3]:= XMLCases[links, XMLPattern["a"], "AttributeReadings" -> <|"rel" -> <|"ListKey" -> "classList"|>|>]

During evaluation of In[3]:= $AttributeReadings::duplistkey

Out[3]= $Failed
```

Give a list key that is the name of an attribute with an entry:

```wl
In[4]:= XMLCases[links, XMLPattern["a"], "AttributeReadings" -> <|"rel" -> <|"ListKey" -> "class"|>|>]

During evaluation of In[4]:= $AttributeReadings::listkeyisreading

Out[4]= $Failed
```

---

Use ``:>``, not ``->``, when ``rhs$`` depends on the option:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow noopener\" href=\"/ad\">Ad</a><a href=\"/home\">Home</a><a rel=\"noopener\" href=\"/x\">X</a></p>", {"HTML", "XMLObject"}];
{XMLCases[links, e : XMLPattern["a"] -> XMLMatchQ[e, XMLPattern["a", "relList" -> "nofollow"]], "AttributeReadings" -> <|"rel" -> <||>|>], XMLCases[links, e : XMLPattern["a"] :> XMLMatchQ[e, XMLPattern["a", "relList" -> "nofollow"]], "AttributeReadings" -> <|"rel" -> <||>|>]}

During evaluation of In[1]:= XMLPattern::nolistreading: "rel" has no entry in $AttributeReadings, so the key "relList" is matched as an attribute of that name. To split "rel" into tokens, add an entry: $AttributeReadings["rel"] = <||> for the session, or "AttributeReadings" -> <|"rel" -> <||>|> in the call.

Out[1]= {{False}, {True, False, False}}
```

---

Use ``"relList"`` with no entry for ``rel`` to get a message and no match:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow\" href=\"/ad\">Ad</a><a href=\"/home\">Home</a></p>", {"HTML", "XMLObject"}];
XMLCases[links, XMLPattern["a", "relList" -> "nofollow"]]

During evaluation of In[1]:= XMLPattern::nolistreading: "rel" has no entry in $AttributeReadings, so the key "relList" is matched as an attribute of that name. To split "rel" into tokens, add an entry: $AttributeReadings["rel"] = <||> for the session, or "AttributeReadings" -> <|"rel" -> <||>|> in the call.

Out[1]= {}
```

Add an entry for ``rel``, here for one call:

```wl
In[2]:= XMLCases[links, XMLPattern["a", "relList" -> "nofollow"], "AttributeReadings" -> <|"rel" -> <||>|>]

Out[2]= {XMLElement["a", {"shape" -> "rect", "rel" -> "nofollow", "href" -> "/ad"}, {"Ad"}]}
```

---

Use ``"relList"`` when the entry for ``rel`` gives another list key:

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

## See Also

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [HTMLWhitespace](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLWhitespace)

* [HTMLClassList](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLClassList)

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [XMLFirstCase](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFirstCase)

* [XMLDeleteCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDeleteCases)

* [XMLMatchQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLMatchQ)

* [HTMLInnerText](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLInnerText)

* [HTMLToNotebook](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLToNotebook)

* [StringSplit](paclet:ref/StringSplit)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
