# HTMLClassList

   ``HTMLClassList[element$]`` gives the classes of the ``XMLElement`` ``element$`` as a list of strings, in the order written.

## Details and Options

``HTMLClassList`` splits the ``class`` attribute on ``HTMLWhitespace``, as a browser does. A no-break space or other Unicode whitespace is part of a class name.

An element with no ``class`` attribute, or with an empty or whitespace-only one, gives ``{}``.

``HTMLClassList[element$]`` gives the list that the ``"classList"`` key of ``XMLPattern`` is matched against.

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Get the classes of an element:

```wl
In[1]:= HTMLClassList[XMLElement["p", {"class" -> "lead disclaimer"}, {"Intro."}]]

Out[1]= {"lead", "disclaimer"}
```

---

Get the classes of the first button in a page:

```wl
In[1]:= page = ImportString["<div><a class=\"btn btn-primary\" href=\"/buy\">Buy</a></div>", {"HTML", "XMLObject"}];
HTMLClassList[XMLFirstCase[page, XMLPattern["a"]]]

Out[1]= {"btn", "btn-primary"}
```

### Scope

---

Get the empty list for a missing, empty or whitespace-only ``class``:

```wl
In[1]:= HTMLClassList /@ {XMLElement["p", {}, {}], XMLElement["p", {"class" -> ""}, {}], XMLElement["p", {"class" -> " \t "}, {}]}

Out[1]= {{}, {}, {}}
```

---

Split classes separated by runs of spaces, tabs and newlines:

```wl
In[1]:= HTMLClassList[XMLElement["p", {"class" -> "  lead\n\tpromo  card "}, {}]]

Out[1]= {"lead", "promo", "card"}
```

---

Get the classes of each element that ``XMLCases`` finds:

```wl
In[1]:= menu = ImportString["<ul><li class=\"item active\">A</li><li>B</li><li class=\"item\">C</li></ul>", {"HTML", "XMLObject"}];
HTMLClassList /@ XMLCases[menu, XMLPattern["li"]]

Out[1]= {{"item", "active"}, {}, {"item"}}
```

### Applications

---

Count how often each class is used in a page:

```wl
In[1]:= page = ImportString["<div class=\"row\"><div class=\"col-6 card\">A</div><div class=\"col-6 card sale\">B</div><div class=\"col-12\">C</div></div>", {"HTML", "XMLObject"}];
Counts[Flatten[HTMLClassList /@ XMLCases[page, XMLPattern[_]]]]

Out[1]= <|"row" -> 1, "col-6" -> 2, "card" -> 2, "sale" -> 1, "col-12" -> 1|>
```

---

Collect the distinct grid classes of a page:

```wl
In[1]:= page = ImportString["<div class=\"row\"><div class=\"col-6 card\">A</div><div class=\"col-md-4\">B</div><div class=\"col-6\">C</div></div>", {"HTML", "XMLObject"}];
Select[Union @@ (HTMLClassList /@ XMLCases[page, XMLPattern["div"]]), StringStartsQ["col-"]]

Out[1]= {"col-6", "col-md-4"}
```

### Properties & Relations

---

Compare ``HTMLClassList`` with the list bound by the ``"classList"`` key of ``XMLPattern``:

```wl
In[1]:= menu = ImportString["<ul><li class=\"item  active\">A</li><li>B</li></ul>", {"HTML", "XMLObject"}];
XMLCases[menu, XMLPattern["li", "classList" -> classes_] :> classes] === (HTMLClassList /@ XMLCases[menu, XMLPattern["li"]])

Out[1]= True
```

---

Compare ``HTMLClassList`` with ``StringSplit`` on ``HTMLWhitespace``:

```wl
In[1]:= element = XMLElement["p", {"class" -> "lead\tpromo"}, {}];
HTMLClassList[element] === StringSplit[Lookup[element[[2]], "class"], HTMLWhitespace]

Out[1]= True
```

---

Get the classes when ``$AttributeReadings`` is empty:

```wl
In[1]:= Block[{$AttributeReadings = <||>}, HTMLClassList[XMLElement["p", {"class" -> "lead promo"}, {}]]]

Out[1]= {"lead", "promo"}
```

### Possible Issues

---

Split a value that contains a no-break space with ``StringSplit``:

```wl
In[1]:= page = ImportString["<p class=\"btn&nbsp;btn-primary\">Buy</p>", {"HTML", "XMLObject"}];
value = Lookup[XMLFirstCase[page, XMLPattern["p"]][[2]], "class"];
StringSplit[value]

Out[1]= {"btn", "btn-primary"}
```

Get a single class with ``HTMLClassList``, as a browser does:

```wl
In[2]:= HTMLClassList[XMLFirstCase[page, XMLPattern["p"]]]

Out[2]= {"btn\[NonBreakingSpace]btn-primary"}
```

Split on ``HTMLWhitespace`` to get the same result from the attribute value:

```wl
In[3]:= StringSplit[value, HTMLWhitespace]

Out[3]= {"btn\[NonBreakingSpace]btn-primary"}
```

---

Give ``HTMLClassList`` a list of elements to get a message:

```wl
In[1]:= HTMLClassList[{XMLElement["p", {"class" -> "a"}, {}], XMLElement["p", {"class" -> "b"}, {}]}]

During evaluation of In[1]:= HTMLClassList::notelement: The argument should be a single XMLElement. Got head List. For a list of elements, use HTMLClassList /@ elements.

Out[1]= $Failed
```

Map over the list instead:

```wl
In[2]:= HTMLClassList /@ {XMLElement["p", {"class" -> "a"}, {}], XMLElement["p", {"class" -> "b"}, {}]}

Out[2]= {{"a"}, {"b"}}
```

---

Give ``HTMLClassList`` a string to get a message:

```wl
In[1]:= HTMLClassList["lead promo"]

During evaluation of In[1]:= HTMLClassList::notelement: The argument should be a single XMLElement. Got head String. For a list of elements, use HTMLClassList /@ elements.

Out[1]= $Failed
```

To split an attribute value, use ``StringSplit`` with ``HTMLWhitespace``:

```wl
In[2]:= StringSplit["lead promo", HTMLWhitespace]

Out[2]= {"lead", "promo"}
```

---

Get duplicate classes, which ``HTMLClassList`` keeps:

```wl
In[1]:= HTMLClassList[XMLElement["p", {"class" -> "lead lead promo"}, {}]]

Out[1]= {"lead", "lead", "promo"}
```

Remove them with ``DeleteDuplicates`` to get the list that a browser's ``classList`` gives:

```wl
In[2]:= DeleteDuplicates[HTMLClassList[XMLElement["p", {"class" -> "lead lead promo"}, {}]]]

Out[2]= {"lead", "promo"}
```

---

Get the same empty list for an empty ``class`` and for a missing one:

```wl
In[1]:= elements = {XMLElement["p", {}, {}], XMLElement["p", {"class" -> ""}, {}]};
HTMLClassList /@ elements

Out[1]= {{}, {}}
```

Test for the attribute with ``XMLPattern`` to tell them apart:

```wl
In[2]:= XMLMatchQ[XMLPattern["p", "class"]] /@ elements

Out[2]= {False, True}
```

## See Also

* [HTMLWhitespace](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLWhitespace)

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [$AttributeReadings](paclet:MaximilienTirard/HTMLPatterns/ref/$AttributeReadings)

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [XMLFirstCase](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFirstCase)

* [XMLMatchQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLMatchQ)

* [StringSplit](paclet:ref/StringSplit)

* [DeleteDuplicates](paclet:ref/DeleteDuplicates)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
