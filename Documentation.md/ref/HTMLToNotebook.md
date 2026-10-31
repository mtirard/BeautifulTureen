# HTMLToNotebook

   ``HTMLToNotebook[tree$]`` converts ``tree$`` to a ``Notebook`` expression, which can be displayed or exported to Markdown, PDF, etc. with ``Export``.

## Details and Options

Each element has a role, which sets what it becomes:

| role | result | built-in tags |
| :--- | :--- | :--- |
| "Block" | one or more cells | ``div``, ``p``, ``h1``, ``li``, etc. |
| "Inline" | formatted text in the surrounding cell | all other tags, such as ``span``, ``b`` and ``a`` |
| "Preformatted" | a "Program" cell, with whitespace kept as written | ``pre``, ``xmp``, etc. |
| "LineBreak" | a newline in the surrounding cell | ``br`` |
| "Skip" | dropped with its content | ``script``, ``style``, ``head``, etc. |

Without a "Roles" rule, the role of an element depends only on its tag, as given by the built-in user-agent stylesheet, a copy of the default styles of the HTML standard. CSS is not read, including the ``style`` attribute.

Without a "Constructs" rule, elements become the following:

| element | becomes |
| :--- | :--- |
| ``h1`` to ``h6`` | "Title", "Chapter", "Section", "Subsection", "Subsubsection" and "Subsubsubsection" cells |
| ``p`` | a "Text" cell |
| ``li`` | an "Item", "Subitem" or "Subsubitem" cell, by depth, or "ItemNumbered", etc. inside ``ol`` |
| ``blockquote`` | a framed quote |
| ``pre`` | a "Program" cell |
| ``table`` | a ``Dataset`` or a ``Grid`` |
| ``hr`` | a horizontal line |
| ``b``, ``strong`` | bold |
| ``i``, ``em`` | italic |
| ``u`` | underlined |
| ``s``, ``del`` | struck through |
| ``code`` | inline code |
| ``a`` | a hyperlink |
| ``img`` | its alt text, linked to its ``src`` |
| ``span``, ``mark``, etc. | plain text |

A ``table`` becomes a ``Dataset`` if its header row has distinct labels and is followed by other rows, none wider than it, and a ``Grid`` otherwise. The header row is the one row of its ``thead``, or, with no ``thead``, a first row of only ``th`` cells.

The text of each table cell is what ``HTMLInnerText`` gives for it. A ``caption`` becomes a "Text" cell before the table.

``tree$`` can be an ``XMLObject``, an ``XMLElement``, a string, or a list of elements and strings. Text outside any block-level element goes in a "Text" cell.

The following options can be given:

| option | default | description |
| :--- | :--- | :--- |
| "Roles" | ``{}`` | rules that set the role of elements |
| "Constructs" | ``{}`` | rules that set what elements become |
| "AttributeReadings" | ``<\|\|>`` | attributes to split into lists of tokens for this call, in addition to ``$AttributeReadings`` |

Each rule of "Roles" or "Constructs" has the form ``key$ -> val$`` or ``key$ :> val$``, and the rules can also be given as an ``Association``.

``key$`` is an element test or a query. An **element test**, such as an ``XMLPattern`` or the CSS selector ``"div.ad"``, is tested on each element, and depends only on the element and what is below it.

A **query** is a rule such as ``pattern$ :> x$``, or a CSS selector that depends on what is above or beside its element, such as ``"nav a"``. It applies to the elements that ``XMLCases`` gives for it in ``tree$``. For more on both kinds, see [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns).

The value of a "Constructs" rule can have the following forms:

| value | gives |
| :--- | :--- |
| "Bold", "Italic", "Underline", "StrikeThrough", "Code" | formatted text |
| "Hyperlink" | a link to the ``href`` or ``src`` attribute, or plain text if there is none |
| "Plain" | plain text |
| any other string, such as "Section" | a cell with that style |
| ``f$`` | ``f$`` applied to the element as it is in ``tree$``, which should give a ``Cell`` or boxes |

The value must suit the role of the element. For a block-level element, give a cell style or a function that returns a ``Cell``. For an inline element, give a formatting string or a function that returns boxes.

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Convert a heading and a paragraph with inline formatting to Markdown:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<h1>Welcome</h1><p>A short <b>intro</b> with a <a href=\"https://wolfram.com\">link</a>.</p>", {"HTML", "XMLObject"}]], "Markdown"]

Out[1]= "# Welcome\n\nA short **intro** with a [link](https://wolfram.com)."
```

---

Get the ``Notebook`` expression:

```wl
In[1]:= HTMLToNotebook[ImportString["<p>Hi</p>", {"HTML", "XMLObject"}]]

Out[1]= Notebook[{Cell[TextData[{"Hi"}], "Text"]}]
```

### Scope

---

Convert headings to cells of decreasing level, starting with "Title":

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<h1>Title</h1><h2>Section</h2><h3>Sub</h3>", {"HTML", "XMLObject"}]], "Markdown"]

Out[1]= "# Title\n\n## Section\n\n### Sub"
```

---

Convert nested list items to "Item", "Subitem", etc. cells, numbered inside ``ol``:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<ol><li>one<ul><li>sub</li></ul></li><li>two</li></ol>", {"HTML", "XMLObject"}]], "Markdown"]

Out[1]= "1. one\n\n    - sub\n\n1. two"
```

---

Convert inline tags such as ``b``, ``i``, ``code`` and ``s`` to formatted text:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<p><b>bold</b>, <i>italic</i>, <code>code</code>, <s>gone</s></p>", {"HTML", "XMLObject"}]], "Markdown"]

Out[1]= "**bold**, *italic*, `code`, ~~gone~~"
```

---

Convert a ``blockquote`` to one framed quote:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<blockquote><p>Quoted.</p></blockquote>", {"HTML", "XMLObject"}]], "Markdown"]

Out[1]= "> Quoted.\n>\n>"
```

---

Convert a ``pre`` element to a "Program" cell, with its whitespace kept:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<pre>line 1\n  line 2</pre>", {"HTML", "XMLObject"}]], "Markdown"]

Out[1]= "```\nline 1\n  line 2\n```"
```

---

Convert a table whose first row has only ``th`` cells with distinct labels to a ``Dataset``:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<table><tr><th>Name</th><th>Role</th></tr><tr><td>Ann</td><td>Dev</td></tr></table>", {"HTML", "XMLObject"}]], "Markdown"]

Out[1]= "| Name | Role |\n| - | - |\n| Ann | Dev |"
```

---

Use the row of a ``thead`` as the column labels, whatever its cells are:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<table><thead><tr><td>Name</td><td>Role</td></tr></thead><tbody><tr><td>Ann</td><td>Dev</td></tr></tbody></table>", {"HTML", "XMLObject"}]], "Markdown"]

Out[1]= "| Name | Role |\n| - | - |\n| Ann | Dev |"
```

### Options

#### Roles

---

Drop the ``div`` that has the class ``ad``:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<div>keep</div><div class=\"ad banner\">drop</div>", {"HTML", "XMLObject"}], "Roles" -> {XMLPattern["div", "classList" -> "ad"] -> "Skip"}], "Markdown"]

Out[1]= "keep"
```

#### Constructs

---

Make each ``p`` a "Section" cell:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<p>Heading-like</p>", {"HTML", "XMLObject"}], "Constructs" -> {"p" -> "Section"}], "Markdown"]

Out[1]= "### Heading-like"
```

---

Give a function that returns a ``Cell`` for each element:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<p>Intro</p><p>Body</p>", {"HTML", "XMLObject"}], "Constructs" -> {"p" :> (Cell[TextData[{"Note: ", HTMLTextContent[#]}], "Text"] &)}], "Markdown"]

Out[1]= "Note: Intro\n\nNote: Body"
```

---

Select paragraphs by class, and apply ``HTMLClassList`` to each in the function:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<p class=\"note warn\">Mind the step.</p><p>Plain.</p>", {"HTML", "XMLObject"}], "Constructs" -> {XMLPattern["p", "classList" -> "note"] -> (Cell[TextData[{StyleBox[StringRiffle[HTMLClassList[#], ", "] <> ": ", FontWeight -> Bold], HTMLTextContent[#]}], "Text"] &)}], "Markdown"]

Out[1]= "**note, warn:** Mind the step.\n\nPlain."
```

---

Use a CSS selector string to make each ``p`` that has the class ``note`` a "Section" cell:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<p class=\"note\">Heading-like</p><p>Body.</p>", {"HTML", "XMLObject"}], "Constructs" -> {"p.note" -> "Section"}], "Markdown"]

Out[1]= "### Heading-like\n\nBody."
```

---

Make the links inside a ``nav`` plain text with the CSS selector "nav a":

```wl
In[1]:= page = ImportString["<body><nav><a href=\"/\">Home</a></nav><p>See <a href=\"/about\">About</a>.</p></body>", {"HTML", "XMLObject"}];
ExportString[HTMLToNotebook[page, "Constructs" -> {"nav a" -> "Plain"}], "Markdown"]

Out[1]= "Home\n\nSee [About](/about)."
```

#### AttributeReadings

---

Split ``rel`` into tokens, and make the links that have the token sponsored plain text:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<p>Read <a rel=\"nofollow sponsored\" href=\"/ad\">this ad</a> <a href=\"/docs\">the docs</a>.</p>", {"HTML", "XMLObject"}], "Constructs" -> {XMLPattern["a", "relList" -> "sponsored"] -> "Plain"}, "AttributeReadings" -> <|"rel" -> <||>|>], "Markdown"]

Out[1]= "Read this ad [the docs](/docs)."
```

### Applications

---

Fetch the 1989 web proposal and convert just its first list to Markdown:

```wl
In[1]:= tree = Import["https://www.w3.org/History/1989/proposal.html", {"HTML", "XMLObject"}];
firstList = XMLFirstCase[tree, XMLPattern["ul"] | XMLPattern["ol"]];
StringTake[ExportString[HTMLToNotebook[firstList], "Markdown"], UpTo[160]]

Out[1]= "- [The original document file (I think - I can't test it)](proposal)\n\n- [The RTF file generated from the above, with scalable drawings](proposal.rtf)\n\n- [A Micr"
```

---

Convert the whole page to a single Markdown document:

```wl
In[1]:= tree = Import["https://www.w3.org/History/1989/proposal.html", {"HTML", "XMLObject"}];
StringLength[ExportString[HTMLToNotebook[tree], "Markdown"]]

Out[1]= 30580
```

### Properties & Relations

---

Compare with ``HTMLInnerText``, which gives the same text without formatting:

```wl
In[1]:= fragment = ImportString["<p>A <b>bold</b> word.</p>", {"HTML", "XMLObject"}];
{HTMLInnerText[fragment], ExportString[HTMLToNotebook[fragment], "Markdown"]}

Out[1]= {"A bold word.", "A **bold** word."}
```

---

Convert a table without a header row to a ``Grid``, which Markdown shows with an empty header:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<table><tr><td>1</td><td>2</td></tr><tr><td>3</td><td>4</td></tr></table>", {"HTML", "XMLObject"}]], "Markdown"]

Out[1]= "|  |  |\n| - | - |\n| 1 | 2 |\n| 3 | 4 |"
```

### Possible Issues

---

Formatting with no Markdown equivalent, such as underline, is lost:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<p><u>underlined</u> text</p>", {"HTML", "XMLObject"}]], "Markdown"]

Out[1]= "underlined text"
```

---

The ``style`` attribute is not read, so an element styled with ``display:none`` is still shown:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<p style=\"display:none\">still shown</p>", {"HTML", "XMLObject"}]], "Markdown"]

Out[1]= "still shown"
```

---

Repeated header labels give a ``Grid`` with the labels in bold, not a ``Dataset``:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<table><thead><tr><th>X</th><th>X</th></tr></thead><tbody><tr><td>1</td><td>2</td></tr></tbody></table>", {"HTML", "XMLObject"}]], "Markdown"]

Out[1]= "|  |  |\n| - | - |\n| **X** | **X** |\n| 1 | 2 |"
```

---

An ``a`` element without an ``href`` gives plain text:

```wl
In[1]:= ExportString[HTMLToNotebook[ImportString["<p><a>bare</a> link</p>", {"HTML", "XMLObject"}]], "Markdown"]

Out[1]= "bare link"
```

---

A query that gives an attribute, not an element, gives a message:

```wl
In[1]:= HTMLToNotebook[XMLElement["p", {}, {XMLElement["a", {"href" -> "/"}, {"Home"}]}], "Constructs" -> {(XMLPattern["a", "href" -> h_] :> h) -> "Plain"}]

During evaluation of In[1]:= HTMLToNotebook::keytarget: A query key selects the position {1, 1, Key["href"]}, which is not an element. A "Roles" or "Constructs" query should select elements only.

Out[1]= $Failed
```

## See Also

* [HTMLInnerText](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLInnerText)

* [HTMLTextContent](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLTextContent)

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [HTMLClassList](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLClassList)

* [$AttributeReadings](paclet:MaximilienTirard/HTMLPatterns/ref/$AttributeReadings)

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [Export](paclet:ref/Export)

* [FromCSSSelector](paclet:MaximilienTirard/HTMLPatterns/ref/FromCSSSelector)

* [HTMLToTree](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLToTree)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
