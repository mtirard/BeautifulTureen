# HTMLTextContent

   ``HTMLTextContent[tree$]`` gives all the strings in ``tree$``, joined in document order.

## Details and Options

No whitespace is added or removed. Indentation, newlines and the content of ``pre`` are kept as written.

For readable text, with whitespace collapsed and each block-level element on its own line, use ``HTMLInnerText``.

``tree$`` can be an ``XMLObject``, an ``XMLElement``, a string, or a list of elements and strings.

``HTMLTextContent`` issues a message and returns ``$Failed`` when ``tree$`` has none of the forms above.

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Get the text of an element:

```wl
In[1]:= HTMLTextContent[XMLElement["p", {}, {"Hello, world"}]]

Out[1]= "Hello, world"
```

---

Join the text of nested elements in document order:

```wl
In[1]:= HTMLTextContent[XMLElement["p", {}, {"Hi ", XMLElement["em", {}, {"there"}]}]]

Out[1]= "Hi there"
```

### Scope

---

Get the text of an imported document:

```wl
In[1]:= HTMLTextContent[ImportString["<p>Hello</p>", {"HTML", "XMLObject"}]]

Out[1]= "Hello"
```

---

Join the text of a list of elements into one string:

```wl
In[1]:= HTMLTextContent[{XMLElement["p", {}, {"a"}], XMLElement["p", {}, {"b"}]}]

Out[1]= "ab"
```

---

Give a string, which is returned unchanged:

```wl
In[1]:= HTMLTextContent["  raw  text  "]

Out[1]= "  raw  text  "
```

---

Get the text of a ``pre`` element, with its indentation and newlines as written:

```wl
In[1]:= HTMLTextContent[XMLElement["pre", {}, {"  for x:\n    print x"}]]

Out[1]= "  for x:\n    print x"
```

---

Get the text of an element found with ``XMLFirstCase``:

```wl
In[1]:= tree = ImportString["<article><h1>Title</h1><p>Body</p></article>", {"HTML", "XMLObject"}];
HTMLTextContent[XMLFirstCase[tree, XMLPattern["h1"]]]

Out[1]= "Title"
```

### Applications

---

Collect the section headings of the 1989 proposal that founded the web:

```wl
In[1]:= tree = Import["https://www.w3.org/History/1989/proposal.html", {"HTML", "XMLObject"}];
HTMLTextContent /@ XMLCases[tree, XMLPattern["h2"]]

Out[1]= {"Overview", "Losing Information at CERN", "Linked information systems", "The problem with trees", "The problem with keywords", "A solution: Hypertext", "CERN Requirements", "Specific Applications", "The State of the Art in Hypermedia", "Accessing Existing Data", "Conclusion", "References"}
```

### Properties & Relations

---

Compare with ``HTMLInnerText``, which collapses whitespace:

```wl
In[1]:= doc = ImportString["<p>Hi   <em>there</em>, \n  world</p>", {"HTML", "XMLObject"}];
{HTMLTextContent[doc], HTMLInnerText[doc]}

Out[1]= {"Hi   there, \n  world", "Hi there, world"}
```

### Possible Issues

---

No whitespace is added between blocks, so their text runs together:

```wl
In[1]:= HTMLTextContent[XMLElement["div", {}, {XMLElement["p", {}, {"a"}], XMLElement["p", {}, {"b"}]}]]

Out[1]= "ab"
```

---

Comments and other nodes that are neither elements nor strings give no text:

```wl
In[1]:= HTMLTextContent[XMLElement["p", {}, {"a", XMLObject["Comment"]["note"], "b"}]]

Out[1]= "ab"
```

## See Also

* [HTMLInnerText](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLInnerText)

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [XMLFirstCase](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFirstCase)

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
