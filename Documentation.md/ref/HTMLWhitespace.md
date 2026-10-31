# HTMLWhitespace

   ``HTMLWhitespace`` is a string pattern that matches a run of one or more HTML whitespace characters.

## Details and Options

``HTMLWhitespace`` matches a run of one or more of the five characters that HTML counts as whitespace:

| character | character code |
| :--- | :--- |
| space ``" "`` | 32 |
| tab ``"\t"`` | 9 |
| line feed ``"\n"`` | 10 |
| form feed ``"\f"`` | 12 |
| carriage return ``"\r"`` | 13 |

Use ``StringSplit[value$, HTMLWhitespace]`` to split the value of an attribute such as ``class`` or ``rel`` as a browser does.

``Whitespace``, and ``StringSplit`` by default, also match no-break space, vertical tab and other Unicode whitespace.

``HTMLClassList`` and the ``"classList"`` key of ``XMLPattern`` split the ``class`` value on ``HTMLWhitespace``.

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Split a class attribute value as a browser does:

```wl
In[1]:= StringSplit["lead  promo\tcard", HTMLWhitespace]

Out[1]= {"lead", "promo", "card"}
```

---

Compare which characters ``HTMLWhitespace`` and ``Whitespace`` match:

```wl
In[1]:= characters = {" ", "\t", "\n", "\f", "\r", "", "\[NonBreakingSpace]", "\:2003"};
Grid[{{"code", Sequence @@ Map[First@*ToCharacterCode, characters]}, {"HTMLWhitespace", Sequence @@ StringMatchQ[characters, HTMLWhitespace]}, {"Whitespace", Sequence @@ StringMatchQ[characters, Whitespace]}}, Frame -> All]

Out[1]= \!\(\*TagBox[GridBox[{{"\"code\"", "32", "9", "10", "12", "13", "11", "160", "8195"}, {"\"HTMLWhitespace\"", "True", "True", "True", "True", "True", "False", "False", "False"}, {"\"Whitespace\"", "True", "True", "True", "True", "True", "True", "True", "True"}}, AutoDelete->False, GridBoxFrame->{"Columns"->{{True}}, "Rows"->{{True}}}, GridBoxItemSize->{"Columns"->{{Automatic}}, "Rows"->{{Automatic}}}], "Grid"]\)
```

### Scope

---

Trim HTML whitespace from both ends of a string:

```wl
In[1]:= StringTrim[" \n lead promo \t", HTMLWhitespace]

Out[1]= "lead promo"
```

---

Collapse each run of HTML whitespace to one space:

```wl
In[1]:= StringReplace["lead \t\n promo    card", HTMLWhitespace -> " "]

Out[1]= "lead promo card"
```

---

Count the runs of HTML whitespace in a string:

```wl
In[1]:= StringCount["lead  promo\tcard", HTMLWhitespace]

Out[1]= 2
```

---

Test whether a string consists of HTML whitespace only:

```wl
In[1]:= StringMatchQ[{" \t\n", "", "\[NonBreakingSpace]"}, HTMLWhitespace]

Out[1]= {True, False, False}
```

### Applications

---

Get the link types of each link from its ``rel`` attribute:

```wl
In[1]:= page = ImportString["<p><a rel=\"nofollow noopener\" href=\"/ad\">Ad</a><a rel=\"author\" href=\"/me\">Me</a></p>", {"HTML", "XMLObject"}];
XMLCases[page, XMLPattern["a", {"rel" -> rel_, "href" -> href_}] :> href -> StringSplit[rel, HTMLWhitespace]]

Out[1]= {"/ad" -> {"nofollow", "noopener"}, "/me" -> {"author"}}
```

---

Split a comma-separated value and trim HTML whitespace from each item:

```wl
In[1]:= StringTrim[#, HTMLWhitespace] & /@ StringSplit["image/png , image/jpeg,\t.pdf", ","]

Out[1]= {"image/png", "image/jpeg", ".pdf"}
```

### Properties & Relations

---

Show the full form of ``HTMLWhitespace``, a repeated alternative of five characters:

```wl
In[1]:= FullForm[HTMLWhitespace]

Out[1]= \!\(\*TagBox[StyleBox[RowBox[{"Repeated", "[", RowBox[{"Alternatives", "[", RowBox[{"\" \"", ",", "\"\\t\"", ",", "\"\\n\"", ",", "\"\\f\"", ",", "\"\\r\""}], "]"}], "]"}], ShowSpecialCharacters->False, ShowStringCharacters->True, NumberMarks->True], FullForm]\)
```

---

Split at a run of spaces with ``HTMLWhitespace`` or ``Whitespace`` to get no empty strings:

```wl
In[1]:= {StringSplit["a  b", HTMLWhitespace], StringSplit["a  b", Whitespace]}

Out[1]= {{"a", "b"}, {"a", "b"}}
```

Split with ``WhitespaceCharacter``, which matches one character, to get empty strings:

```wl
In[2]:= {StringSplit["a  b", " " | "\t" | "\n" | "\f" | "\r"], StringSplit["a  b", WhitespaceCharacter]}

Out[2]= {{"a", "", "b"}, {"a", "", "b"}}
```

---

Repeat ``HTMLWhitespace`` to get the same split:

```wl
In[1]:= StringSplit["a  \t b", HTMLWhitespace ..] === StringSplit["a  \t b", HTMLWhitespace]

Out[1]= True
```

---

Compare ``HTMLClassList`` with splitting the ``class`` value on ``HTMLWhitespace``:

```wl
In[1]:= element = XMLElement["p", {"class" -> " lead\n promo "}, {}];
{HTMLClassList[element], StringSplit[" lead\n promo ", HTMLWhitespace]}

Out[1]= {{"lead", "promo"}, {"lead", "promo"}}
```

### Possible Issues

---

Split a ``class`` value that contains a no-break space from ``&nbsp;``:

```wl
In[1]:= page = ImportString["<p class=\"btn&nbsp;btn-primary\">Buy</p>", {"HTML", "XMLObject"}];
value = Lookup[XMLFirstCase[page, XMLPattern["p"]][[2]], "class"];
{StringSplit[value, Whitespace], StringSplit[value, HTMLWhitespace]}

Out[1]= {{"btn", "btn-primary"}, {"btn\[NonBreakingSpace]btn-primary"}}
```

Check that the element does not have the class ``btn``, since the value is a single class:

```wl
In[2]:= XMLMatchQ[XMLFirstCase[page, XMLPattern["p"]], XMLPattern["p", "classList" -> "btn"]]

Out[2]= False
```

---

Split at a vertical tab, which is Unicode whitespace but not HTML whitespace:

```wl
In[1]:= {StringSplit["ab"], StringSplit["ab", HTMLWhitespace]}

Out[1]= {{"a", "b"}, {"ab"}}
```

## See Also

* [HTMLClassList](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLClassList)

* [$AttributeReadings](paclet:MaximilienTirard/HTMLPatterns/ref/$AttributeReadings)

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [Whitespace](paclet:ref/Whitespace)

* [WhitespaceCharacter](paclet:ref/WhitespaceCharacter)

* [StringSplit](paclet:ref/StringSplit)

* [StringTrim](paclet:ref/StringTrim)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
