# HTMLInnerText

   ``HTMLInnerText[tree$]`` gives the readable text of ``tree$``, with whitespace collapsed and each block-level element on its own line.

## Details and Options

Each element has a role, which sets how its text is placed:

| role | text | built-in tags |
| :--- | :--- | :--- |
| "Block" | on its own line | ``div``, ``p``, ``h1``, ``li``, etc. |
| "Inline" | in the surrounding line | all other tags, such as ``span``, ``b`` and ``a`` |
| "Preformatted" | on its own lines, with whitespace kept as written | ``pre``, ``xmp``, etc. |
| "LineBreak" | a newline | ``br`` |
| "Skip" | dropped with its content | ``script``, ``style``, ``head``, etc. |

Without a "Roles" rule, the role of an element depends only on its tag, as given by the built-in user-agent stylesheet, a copy of the default styles of the HTML standard. CSS is not read, including the ``style`` attribute.

Outside preformatted elements, each run of spaces, tabs and newlines becomes one space. A no-break space, such as one written ``&nbsp;``, is kept. The result is trimmed at both ends.

Each ``br`` element gives one newline, whatever the setting of "BlockSeparator", so two in a row leave a blank line.

``tree$`` can be an ``XMLObject``, an ``XMLElement``, a string, or a list of elements and strings.

If ``tree$``, the root element of a document, or a top-level element of a list has the role "Skip", as a ``title`` or ``script`` element does, its whole text is given as ``HTMLTextContent`` gives it, trimmed at both ends.

The following options can be given:

| option | default | description |
| :--- | :--- | :--- |
| "Roles" | ``{}`` | rules that set the role of elements |
| "BlockSeparator" | ``"\n"`` | string inserted between blocks |
| "AttributeReadings" | ``<\|\|>`` | attributes to split into lists of tokens for this call, in addition to ``$AttributeReadings`` |

Each rule of "Roles" has the form ``key$ -> val$`` or ``key$ :> val$``, and the rules can also be given as an ``Association``.

``key$`` is an element test or a query. An **element test**, such as an ``XMLPattern`` or the CSS selector ``"div.ad"``, is tested on each element, and depends only on the element and what is below it.

A **query** is a rule such as ``pattern$ :> x$``, or a CSS selector that depends on what is above or beside its element, such as ``"nav a"``. It applies to the elements that ``XMLCases`` gives for it in ``tree$``. For more on both kinds, see [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns).

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Get the text of a paragraph, with whitespace collapsed:

```wl
In[1]:= HTMLInnerText[ImportString["<p>Hi   <em>there</em>, \n  world</p>", {"HTML", "XMLObject"}]]

Out[1]= "Hi there, world"
```

---

Get the text of a ``div``, with each block-level element on its own line:

```wl
In[1]:= HTMLInnerText[XMLElement["div", {}, {
   XMLElement["h2", {}, {"Title"}],
   XMLElement["p", {}, {"First para."}],
   XMLElement["p", {}, {"Second ", XMLElement["b", {}, {"bold"}], " para."}]}]]

Out[1]= "Title\nFirst para.\nSecond bold para."
```

### Scope

---

Get the text of an imported document:

```wl
In[1]:= HTMLInnerText[ImportString["<p>Hi <b>bold</b></p>", {"HTML", "XMLObject"}]]

Out[1]= "Hi bold"
```

---

Get the text of a list of elements, read as one tree:

```wl
In[1]:= HTMLInnerText[{XMLElement["p", {}, {"a"}], XMLElement["p", {}, {"b"}]}]

Out[1]= "a\nb"
```

---

Collapse and trim the whitespace of a string:

```wl
In[1]:= HTMLInnerText["  raw   text  "]

Out[1]= "raw text"
```

---

Break a line with a ``br`` element:

```wl
In[1]:= HTMLInnerText[XMLElement["p", {}, {"line1", XMLElement["br", {}, {}], "line2"}]]

Out[1]= "line1\nline2"
```

---

Get the text of a ``pre`` element with its whitespace as written:

```wl
In[1]:= HTMLInnerText[XMLElement["div", {}, {"code:", XMLElement["pre", {}, {"  for x:\n    print x"}], "done"}]]

Out[1]= "code:\n  for x:\n    print x\ndone"
```

---

Get the text without the ``script`` elements, which are dropped with their content:

```wl
In[1]:= HTMLInnerText[ImportString["<section><script>var x=1;</script><p>Visible.</p></section>", {"HTML", "XMLObject"}]]

Out[1]= "Visible."
```

---

Get the text of a ``title`` element, which is dropped inside a tree but not on its own:

```wl
In[1]:= tree = ImportString["<html><head><title>My page</title></head><body><p>Body.</p></body></html>", {"HTML", "XMLObject"}];
{HTMLInnerText[tree], HTMLInnerText[XMLFirstCase[tree, "title"]]}

Out[1]= {"Body.", "My page"}
```

---

Keep no-break spaces, while other whitespace is collapsed:

```wl
In[1]:= HTMLInnerText[ImportString["<p>10&nbsp;km   away</p>", {"HTML", "XMLObject"}]] // InputForm

Out[1]= «InputForm["10\[NonBreakingSpace]km away"]»
```

### Options

#### Roles

---

Drop the spans that have the class ``sr-only``:

```wl
In[1]:= HTMLInnerText[
 XMLElement["div", {}, {"keep ", XMLElement["span", {"class" -> "sr-only visually-hidden"}, {"screenreader"}], " this"}],
 "Roles" -> {XMLPattern["span", "classList" -> "sr-only"] -> "Skip"}]

Out[1]= "keep this"
```

---

Drop the list items whose text contains "sold out", using a condition:

```wl
In[1]:= HTMLInnerText[
 XMLElement["ul", {}, {XMLElement["li", {}, {"Miso"}], XMLElement["li", {}, {"Ramen (sold out)"}]}],
 "Roles" -> {(e : XMLPattern["li"] /; StringContainsQ[HTMLTextContent[e], "sold out"]) -> "Skip"}]

Out[1]= "Miso"
```

---

Use a CSS selector string to drop the ``div`` elements that have the class ``ad``:

```wl
In[1]:= HTMLInnerText[ImportString["<div class=\"ad\">Buy now!</div><p>News.</p>", {"HTML", "XMLObject"}], "Roles" -> {"div.ad" -> "Skip"}]

Out[1]= "News."
```

---

Put the links inside a ``nav`` on their own lines with the CSS selector "nav a":

```wl
In[1]:= page = XMLElement["body", {}, {XMLElement["nav", {}, {XMLElement["a", {}, {"Home"}], XMLElement["a", {}, {"News"}]}], XMLElement["p", {}, {"Text with ", XMLElement["a", {}, {"a link"}], "."}]}];
HTMLInnerText[page, "Roles" -> {"nav a" -> "Block"}]

Out[1]= "Home\nNews\nText with a link."
```

---

Give a query as the key, and name the elements that get the role:

```wl
In[1]:= page = XMLElement["body", {}, {XMLElement["nav", {}, {XMLElement["a", {}, {"Home"}], XMLElement["a", {}, {"News"}]}], XMLElement["p", {}, {"Text with ", XMLElement["a", {}, {"a link"}], "."}]}];
HTMLInnerText[page, "Roles" -> {(XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> x) -> "Block"}]

Out[1]= "Home\nNews\nText with a link."
```

#### BlockSeparator

---

Widen the gap between blocks to a blank line:

```wl
In[1]:= HTMLInnerText[XMLElement["div", {}, {
   XMLElement["p", {}, {"First."}], XMLElement["p", {}, {"Second."}]}],
 "BlockSeparator" -> "\n\n"]

Out[1]= "First.\n\nSecond."
```

#### AttributeReadings

---

Split ``rel`` into tokens, and drop the links that have the token sponsored:

```wl
In[1]:= HTMLInnerText[
 XMLElement["p", {}, {"Read ", XMLElement["a", {"rel" -> "nofollow sponsored"}, {"this ad"}], " the docs."}],
 "Roles" -> {XMLPattern["a", "relList" -> "sponsored"] -> "Skip"},
 "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= "Read the docs."
```

### Applications

---

Get the byline of the 1989 proposal that founded the web as readable text:

```wl
In[1]:= tree = Import["https://www.w3.org/History/1989/proposal.html", {"HTML", "XMLObject"}];
HTMLInnerText[XMLFirstCase[tree, XMLPattern["address"]]]

Out[1]= "Tim Berners-Lee, CERN\nMarch 1989, May 1990"
```

### Properties & Relations

---

Compare with ``HTMLTextContent``, which keeps the whitespace as written:

```wl
In[1]:= doc = ImportString["<p>Hi   <em>there</em>, \n  world</p>", {"HTML", "XMLObject"}];
{HTMLInnerText[doc], HTMLTextContent[doc]}

Out[1]= {"Hi there, world", "Hi   there, \n  world"}
```

---

Compare with a web browser, which also puts block-level elements on separate lines:

```wl
In[1]:= HTMLInnerText[XMLElement["div", {}, {
   XMLElement["p", {}, {"one ", XMLElement["b", {}, {"two"}]}],
   XMLElement["p", {}, {"three"}]}]]

Out[1]= "one two\nthree"
```

### Possible Issues

---

The ``style`` attribute is not read, so an element styled with ``display:none`` still gives text:

```wl
In[1]:= HTMLInnerText[XMLElement["p", {}, {"keep ", XMLElement["span", {"style" -> "display:none"}, {"hidden"}], " this"}]]

Out[1]= "keep hidden this"
```

---

An unknown tag has the role "Inline", so it adds no line break:

```wl
In[1]:= HTMLInnerText[XMLElement["p", {}, {"a", XMLElement["widget", {}, {"b"}], "c"}]]

Out[1]= "abc"
```

---

A "Roles" rule that gives an invalid role issues a message and is ignored:

```wl
In[1]:= HTMLInnerText[XMLElement["p", {}, {"hi"}], "Roles" -> {"p" -> "Purple"}]

During evaluation of In[1]:= HTMLInnerText::badrole: A "Roles" rule gave "Purple", which is not "Block", "Inline", "Preformatted", "LineBreak" or "Skip". The element gets its role from the built-in user-agent stylesheet instead.

Out[1]= "hi"
```

---

A rule on "class" does not match a span with two classes, while a rule on "classList" does:

```wl
In[1]:= fragment = XMLElement["div", {}, {"keep ", XMLElement["span", {"class" -> "sr-only visually-hidden"}, {"screenreader"}], " this"}];
{HTMLInnerText[fragment, "Roles" -> {XMLPattern["span", "class" -> "sr-only"] -> "Skip"}],
 HTMLInnerText[fragment, "Roles" -> {XMLPattern["span", "classList" -> "sr-only"] -> "Skip"}]}

Out[1]= {"keep screenreader this", "keep this"}
```

---

A query that gives an attribute, not an element, gives a message:

```wl
In[1]:= HTMLInnerText[XMLElement["p", {}, {XMLElement["a", {"href" -> "/"}, {"Home"}]}], "Roles" -> {(XMLPattern["a", "href" -> h_] :> h) -> "Skip"}]

During evaluation of In[1]:= HTMLInnerText::keytarget: A query key selects the position {1, 1, Key["href"]}, which is not an element. A "Roles" or "Constructs" query should select elements only.

Out[1]= $Failed
```

Name the element instead:

```wl
In[2]:= HTMLInnerText[XMLElement["p", {}, {XMLElement["a", {"href" -> "/"}, {"Home"}], " text"}], "Roles" -> {(x : XMLPattern["a", "href" -> _] :> x) -> "Skip"}]

Out[2]= "text"
```

## See Also

* [HTMLTextContent](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLTextContent)

* [HTMLToNotebook](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLToNotebook)

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [XMLMatchQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLMatchQ)

* [$AttributeReadings](paclet:MaximilienTirard/HTMLPatterns/ref/$AttributeReadings)

* [XMLDeleteCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDeleteCases)

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [FromCSSSelector](paclet:MaximilienTirard/HTMLPatterns/ref/FromCSSSelector)

* [HTMLToTree](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLToTree)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
