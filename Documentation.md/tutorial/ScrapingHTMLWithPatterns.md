# Scraping HTML with Patterns

[HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns) is a set of functions for querying HTML and XML in the Wolfram Language, in the style of the Python library BeautifulSoup. ``Import`` gives an HTML page as an ``XMLObject`` expression: a tree of elements, each with a tag, attributes and contents. HTMLPatterns finds elements in this tree by *pattern*. An ``XMLPattern`` matches an element by its tag, its attributes and its classes, and by the elements below it, so a pattern is nested as the document is. Other functions extract the text of the elements you find, or convert them to a notebook.

In this tutorial you import one small HTML document, find elements in it by tag, attribute and class, and test single elements. You then match what is below an element, with *constraints* such as ``Child`` and ``Descendant`` that you give to an ``XMLPattern``, and use CSS selectors in place of patterns. Finally you remove and replace elements, and turn the rest into text or a notebook.

## Importing a Document

Load the paclet:

```wl
In[1]:= Needs["MaximilienTirard`HTMLPatterns`"]
```

Import a small HTML document in the ``{"HTML", "XMLObject"}`` format. The rest of this tutorial uses this tree:

```wl
In[2]:= tree = ImportString["
<article>
  <h1>Copper Soup Bar</h1>
  <p class=\"lead\">Seasonal <b>bowls</b>, made to order.</p>
  <nav class=\"menu compact\">
    <a href=\"/menu\">Menu</a>
    <a href=\"/hours\">Hours</a>
  </nav>
  <ul class=\"menu specials\">
    <li class=\"specials\"><a href=\"/miso\">Miso</a></li>
    <li><a href=\"/pho\">Pho</a></li>
    <li><a href=\"/ramen\">Ramen (sold out)</a></li>
  </ul>
  <script>track();</script>
</article>", {"HTML", "XMLObject"}];
tree

Out[2]= XMLObject["Document"][{XMLObject["Declaration"]["Version" -> "1.0", "Standalone" -> "yes"]}, XMLElement["article", {{"http://www.w3.org/2000/xmlns/", "xmlns"} -> "http://www.w3.org/1999/xhtml"}, {"\n  ", XMLElement["h1", {}, {"Copper Soup Bar"}], "\n  ", XMLElement["p", {"class" -> "lead"}, {"Seasonal ", XMLElement["b", {}, {"bowls"}], ", made to order."}], "\n  ", XMLElement["nav", {"class" -> "menu compact"}, {"\n    ", XMLElement["a", {"shape" -> "rect", "href" -> "/menu"}, {"Menu"}], "\n    ", XMLElement["a", {"shape" -> "rect", "href" -> "/hours"}, {"Hours"}], "\n  "}], "\n  ", XMLElement["ul", {"class" -> "menu specials"}, {XMLElement["li", {"class" -> "specials"}, {XMLElement["a", {"shape" -> "rect", "href" -> "/miso"}, {"Miso"}]}], XMLElement["li", {}, {XMLElement["a", {"shape" -> "rect", "href" -> "/pho"}, {"Pho"}]}], XMLElement["li", {}, {XMLElement["a", {"shape" -> "rect", "href" -> "/ramen"}, {"Ramen (sold out)"}]}]}], "\n  ", XMLElement["script", {}, {"track();"}], "\n"}], {}]
```

Draw its structure with ``HTMLToTree``. Each element is a node labelled with its tag, and each string of text is a leaf:

```wl
In[3]:= HTMLToTree[tree]

Out[3]= (* graphics *)
```

The tree is an ordinary Wolfram Language expression. Each element is an ``XMLElement[tag$, attributes$, children$]``: its tag name, its attributes as a list of rules, and its contents as a list. The contents hold the text of the element as strings and the elements nested in it as further ``XMLElement`` expressions, in source order. The whole tree is wrapped in ``XMLObject["Document"][$$]``, which also holds the XML declaration.

The import made a few changes to the source. The ``article`` element has an ``xmlns`` attribute, which identifies the markup as XHTML. Each ``a`` element has an extra ``"shape$" -> "rect$"`` attribute. The indentation of the source is kept, as strings between the elements, but ``HTMLToTree`` leaves those strings out.

Because the tree is an ordinary expression, the standard [pattern language](tutorial/Patterns) applies to it. List the tags in the document with ``Cases`` and the three-argument ``XMLElement`` form:

```wl
In[4]:= Union[Cases[tree, XMLElement[tag_, _, _] :> tag, Infinity]]

Out[4]= {"a", "article", "b", "h1", "li", "nav", "p", "script", "ul"}
```

Elements can be nested at any depth, so this needs the level specification ``Infinity``. Without it, ``Cases`` matches only at level 1 of the document, which holds the ``article`` element:

```wl
In[5]:= Cases[tree, XMLElement[tag_, _, _] :> tag]

Out[5]= {"article"}
```

``XMLCases`` and ``XMLPattern`` give a shorter form. ``XMLCases`` searches the whole tree, so it needs no level specification, and ``XMLPattern[tag_]`` matches any element, as ``XMLElement[tag_, _, _]`` does:

```wl
In[6]:= Union[XMLCases[tree, XMLPattern[tag_] :> tag]]

Out[6]= {"a", "article", "b", "h1", "li", "nav", "p", "script", "ul"}
```

## Selecting Elements

``XMLPattern[tag$]`` matches any element with the tag ``tag$``. ``tag$`` can be a string, alternatives such as ``"ul" | "li"``, or a pattern such as ``_``. ``XMLPattern[tag$, attrs$]`` also matches the attributes of the element. ``attrs$`` has one of these forms:

| calling form | description |
| :--- | :--- |
| ``key$`` | has the attribute ``key$`` |
| ``key$ -> val$`` | has the attribute ``key$``, with a value that matches ``val$`` |
| ``{a$1, a$2, $$}`` | matches every ``a$i`` |

The element can have other attributes as well. As with ``Cases``, a rule ``patt$ :> rhs$`` gives a result computed from each match. Get the targets of the links:

```wl
In[7]:= XMLCases[tree, XMLPattern["a", "href" -> target_] :> target]

Out[7]= {"/menu", "/hours", "/miso", "/pho", "/ramen"}
```

The rule ``"href" -> target_`` matches only elements that have an ``"href$"`` attribute, and binds ``target`` to its value. A key on its own matches by the attribute alone. Get the tags of the elements that have a ``"class$"`` attribute:

```wl
In[8]:= XMLCases[tree, XMLPattern[tag_, "class"] :> tag]

Out[8]= {"p", "nav", "ul", "li"}
```

``XMLCases`` gives its matches in document order, the order in which their start tags appear in the source, as ``querySelectorAll`` does in a browser. So an element comes before the elements nested in it. ``Cases`` gives the elements nested in an element before the element itself. Compare the two on the ``ul`` and ``li`` elements, matched with the alternatives ``"ul" | "li"``:

```wl
In[9]:= {Cases[tree, XMLElement[tag : "ul" | "li", _, _] :> tag, Infinity], XMLCases[tree, XMLPattern[tag : "ul" | "li"] :> tag]}

Out[9]= {{"li", "li", "li", "ul"}, {"ul", "li", "li", "li"}}
```

``XMLFirstCase`` gives the first match in document order, or ``Missing["NotFound"]`` if there is none. A third argument sets a different default. Get the lead paragraph by its ``"class$"`` attribute:

```wl
In[10]:= XMLFirstCase[tree, XMLPattern["p", "class" -> "lead"]]

Out[10]= XMLElement["p", {"class" -> "lead"}, {"Seasonal ", XMLElement["b", {}, {"bowls"}], ", made to order."}]
```

## Matching Classes

That worked because the paragraph has only one class. HTML puts all the classes of an element into one ``"class$"`` attribute, separated by spaces, and an attribute rule matches the whole value. So ``"class" -> "menu"`` does not match the ``nav``, whose ``"class$"`` attribute is ``"menu compact"``. To match one class among several, use the key ``"classList$"`` instead:

```wl
In[11]:= {XMLFirstCase[tree, XMLPattern[tag_, "class" -> "menu"] :> tag], XMLFirstCase[tree, XMLPattern[tag_, "classList" -> "menu"] :> tag]}

Out[11]= {Missing["NotFound"], "nav"}
```

The value at ``"classList$"`` is the list of the classes of the element, which is ``{}`` for an element without a ``"class$"`` attribute. ``HTMLClassList`` gives the same list:

```wl
In[12]:= HTMLClassList /@ XMLCases[tree, XMLPattern["nav" | "ul" | "li"]]

Out[12]= {{"menu", "compact"}, {"menu", "specials"}, {"specials"}, {}, {}}
```

The value at ``"classList$"`` is a pattern matched against the whole list, except that a string, or alternatives of strings, matches one class among the others. So ``"classList" -> "menu"`` selects the same elements as ``"classList" -> {___, "menu", ___}``:

```wl
In[13]:= {XMLCases[tree, XMLPattern[tag_, "classList" -> "menu"] :> tag], XMLCases[tree, XMLPattern[tag_, "classList" -> {___, "menu", ___}] :> tag]}

Out[13]= {{"nav", "ul"}, {"nav", "ul"}}
```

A list pattern depends on the order of the classes. ``{"specials", ___}`` matches the ``li``, whose first class is ``"specials$"``, but not the ``ul``:

```wl
In[14]:= XMLCases[tree, XMLPattern[tag_, "classList" -> {"specials", ___}] :> tag]

Out[14]= {"li"}
```

To check membership in any order, use ``MemberQ``, ``ContainsAll``, ``ContainsAny``, etc. in a ``PatternTest``. Find the elements that have both the class ``"menu$"`` and the class ``"specials$"``:

```wl
In[15]:= XMLCases[tree, XMLPattern[tag_, "classList" -> _?(ContainsAll[{"menu", "specials"}])] :> tag]

Out[15]= {"ul"}
```

To combine several tests on the classes, name the list and test it in a ``Condition``. Find the elements that have the class ``"menu$"`` or ``"specials$"`` but not ``"compact$"``, which the CSS selector ``":is(.menu, .specials):not(.compact)"`` also selects:

```wl
In[16]:= XMLCases[tree, XMLPattern[tag_, "classList" -> c_ /; ContainsAny[c, {"menu", "specials"}] && FreeQ[c, "compact"]] :> tag]

Out[16]= {"ul", "li"}
```

``Except["compact"]`` excludes nothing, because a list of classes is never the string ``"compact$"``. Use ``FreeQ`` to exclude a class:

```wl
In[17]:= XMLCases[tree, XMLPattern[tag : "nav" | "ul", "classList" -> Except["compact"]] :> tag]

Out[17]= {"nav", "ul"}
```

Other attributes that hold a list of tokens, such as ``rel``, can be split in the same way with ``$AttributeReadings``.

## Testing One Element

``MatchQ[elem$, XMLPattern[$$]]`` is ``False`` for every element, as ``MatchQ[string$, "col-" ~~ __]`` is for every string. To test a single element, use ``XMLMatchQ``, as you use ``StringMatchQ`` for a string:

```wl
In[18]:= lead = XMLFirstCase[tree, XMLPattern["p"]];
{MatchQ[lead, XMLPattern["p"]], XMLMatchQ[lead, XMLPattern["p", "classList" -> "lead"]]}

Out[18]= {False, True}
```

``XMLMatchQ`` has an operator form, for use with ``Select``. Select the list items that have no class:

```wl
In[19]:= Select[XMLCases[tree, XMLPattern["li"]], XMLMatchQ[XMLPattern["li", "classList" -> {}]]]

Out[19]= {XMLElement["li", {}, {XMLElement["a", {"shape" -> "rect", "href" -> "/pho"}, {"Pho"}]}], XMLElement["li", {}, {XMLElement["a", {"shape" -> "rect", "href" -> "/ramen"}, {"Ramen (sold out)"}]}]}
```

## Nested Patterns

An ``XMLPattern`` matches an element wherever it is in the tree. To also match what is below an element, give *constraints* in a second bracket: ``XMLPattern[tag$, attrs$][c$1, c$2, $$]`` matches an element for which every constraint ``c$i`` holds.

### Child and Descendant

``Child[p$]`` holds if a child element of the element matches ``p$``, as the CSS pseudo-class ``":has(> p)"`` does. ``Descendant[p$]`` holds if an element at any depth below matches ``p$``, as ``":has(p)"`` does. To get an element below, name it, and use the name on the right-hand side of the rule. Get the targets of the links inside the ``ul`` list, which leaves out the links in the ``nav``:

```wl
In[20]:= XMLCases[tree, XMLPattern["ul", "classList" -> "menu"][Descendant[XMLPattern["a", "href" -> target_]]] :> target]

Out[20]= {"/miso", "/pho", "/ramen"}
```

The CSS selector ``"ul.menu a"`` selects the same ``a`` elements. A selector gives the last element in it, and a pattern gives what the names on the right-hand side are bound to.

### Choosing What Is Returned

``XMLCases`` gives one result for each element or value that the names on the right-hand side are bound to, or for each combination when there are several names, in document order. Name the ``ul`` instead, and the same pattern gives one result, not one for each link in the list:

```wl
In[21]:= XMLCases[tree, ul : XMLPattern["ul", "classList" -> "menu"][Descendant[XMLPattern["a", "href" -> _]]] :> HTMLClassList[ul]]

Out[21]= {{"menu", "specials"}}
```

Here the name ``ul`` is bound to one element, so there is one result.

### Order Among Siblings

A *list pattern*, such as ``{XMLPattern["li"], ___}``, is a constraint matched against the list of child elements, without the text between them. It matches the order of the children, as the CSS combinators ``+`` and ``~`` do. To find an element by the element before it, match their parent. Get the paragraph that immediately follows the ``h1`` heading:

```wl
In[22]:= XMLCases[tree, XMLPattern[_][{___, XMLPattern["h1"], p : XMLPattern["p"], ___}] :> p]

Out[22]= {XMLElement["p", {"class" -> "lead"}, {"Seasonal ", XMLElement["b", {}, {"bowls"}], ", made to order."}]}
```

With ``___`` between ``XMLPattern["h1"]`` and ``p``, the pattern would match a paragraph anywhere after the heading, as ``"h1 ~ p"`` does.

### Conditions across Levels

Constraints nest as the elements do: a pattern in a constraint can have constraints of its own. A ``Condition`` on an ``XMLPattern`` can use the names in that pattern and in the patterns below it, but not the names in the patterns above it. Find the links in list items that share a class with their list:

```wl
In[23]:= XMLCases[tree, XMLPattern["ul", "classList" -> outer_][Child[XMLPattern["li", "classList" -> inner_][Child[XMLPattern["a", "href" -> target_]]]]] /; IntersectingQ[outer, inner] :> target]

Out[23]= {"/miso"}
```

Only the ``"specials$"`` item shares a class with its list. The condition is on the ``ul`` pattern, the one that contains both ``outer`` and ``inner``.

## Using CSS Selectors

A CSS selector string can be given wherever a pattern goes. Get the links in the list with the class ``"menu$"``:

```wl
In[24]:= XMLCases[tree, "ul.menu a"]

Out[24]= {XMLElement["a", {"shape" -> "rect", "href" -> "/miso"}, {"Miso"}], XMLElement["a", {"shape" -> "rect", "href" -> "/pho"}, {"Pho"}], XMLElement["a", {"shape" -> "rect", "href" -> "/ramen"}, {"Ramen (sold out)"}]}
```

A CSS selector for one element depends only on its element and what is below it, such as ``"nav.menu"`` or ``"ul:has(> li)"``. ``FromCSSSelector`` gives its pattern. Other selectors depend on what is above or beside their element, such as ``"ul.menu a"``. Their pattern also matches the elements above, so give ``FromCSSSelector`` a name for the element they select:

```wl
In[25]:= {FromCSSSelector["nav.menu"], FromCSSSelector[x : "ul.menu a"]}

Out[25]= {XMLPattern["nav", "classList" -> "menu"], XMLPattern["ul", "classList" -> "menu"][Descendant[x : XMLPattern["a"]]]}
```

On the left of a rule, name the selected element in the same way. Get the text of the links in the list:

```wl
In[26]:= XMLCases[tree, link : "ul.menu a" :> HTMLTextContent[link]]

Out[26]= {"Miso", "Pho", "Ramen (sold out)"}
```

## Changing the Tree

``XMLDeleteCases`` gives the tree with every matching element removed, together with its contents. Use it before extracting text, to remove navigation, scripts and other elements that are not part of the content. Remove the script and the navigation, and list the links that remain:

```wl
In[27]:= readable = XMLDeleteCases[tree, XMLPattern["script" | "nav"]]; XMLCases[readable, XMLPattern["a", "href" -> target_] :> target]

Out[27]= {"/miso", "/pho", "/ramen"}
```

Only the links in the ``ul`` list remain. With a ``Condition``, only the elements for which the test gives ``True`` are removed. To test the text of an element, name the whole element. Remove the list item that is sold out:

```wl
In[28]:= readable = XMLDeleteCases[readable, item : XMLPattern["li"] /; StringContainsQ[HTMLTextContent[item], "sold out"]];
XMLCases[readable, XMLPattern["a", "href" -> target_] :> target]

Out[28]= {"/miso", "/pho"}
```

Given a rule ``patt$ :> x``, ``XMLDeleteCases`` removes what ``x`` is bound to, so a nested pattern can remove an element by what is above it.

``XMLReplace`` replaces parts of the tree. Name each part to replace, and give its replacement in a rule on the right-hand side. Make the links absolute:

```wl
In[29]:= absolute = XMLReplace[readable, XMLPattern["a", "href" -> href_] :> {href -> "https://example.com" <> href}];
XMLCases[absolute, XMLPattern["a", "href" -> target_] :> target]

Out[29]= {"https://example.com/miso", "https://example.com/pho"}
```

With any other right-hand side, ``XMLReplace`` replaces each matching element.

## Extracting Text

Two functions turn a tree into a string. They correspond to the ``textContent`` and ``innerText`` properties of an element in a browser. ``HTMLTextContent`` joins all the strings in the tree in document order, and keeps the whitespace of the source. ``HTMLInnerText`` gives the text as a browser displays it:

| calling form | description |
| :--- | :--- |
| block-level elements, such as ``p``, ``li`` and ``h1`` | on their own lines |
| inline elements, such as ``b``, ``a`` and ``span`` | in the surrounding line |
| ``pre`` | on its own lines, with whitespace kept as written |
| ``br`` | a newline |
| elements that are not displayed, such as ``script`` and ``style`` | left out, with their contents |
| ``a run of whitespace`` | one space, or nothing between blocks |

Compare the two on the pruned tree:

```wl
In[30]:= {HTMLTextContent[readable], HTMLInnerText[readable]}

Out[30]= {"\n  Copper Soup Bar\n  Seasonal bowls, made to order.\n  \n  MisoPho\n  \n", "Copper Soup Bar\nSeasonal bowls, made to order.\nMiso\nPho"}
```

In ``HTMLInnerText``, the layout of the text of an element depends only on its tag, as in a browser with its default styles. The CSS of the page, including ``style`` attributes, has no effect. Each element has a *role*, ``"Block"``, ``"Inline"``, ``"Preformatted"``, ``"LineBreak"`` or ``"Skip"``, which sets how its text is laid out. The ``"Roles"`` option sets the role of the elements you choose, and the ``"BlockSeparator"`` option sets the string inserted between blocks. Skip the list items with the class ``"specials$"``:

```wl
In[31]:= HTMLInnerText[readable, "Roles" -> {XMLPattern["li", "classList" -> "specials"] -> "Skip"}]

Out[31]= "Copper Soup Bar\nSeasonal bowls, made to order.\nPho"
```

The next section shows how to choose elements in ``"Roles"``.

## Choosing Elements for Roles and Constructs

The ``"Roles"`` option of ``HTMLInnerText``, ``HTMLToNotebook`` and ``HTMLToTree``, and the ``"Constructs"`` option of ``HTMLToNotebook``, take a list of rules ``key$ -> val$`` or ``key$ :> val$``, or an ``Association`` of them. The key of each rule is one of two kinds:

| calling form | description |
| :--- | :--- |
| an element test: an ``XMLPattern``, an ``XMLElement`` pattern, a CSS selector for one element, or alternatives of these, each of which can be named, have a condition or have a test | each element that the outermost pattern matches |
| a query: a rule ``patt$ :> rhs$``, or any other CSS selector | the elements that the names in ``rhs$`` are bound to, or that the selector selects, matched once against the whole tree |

An element test is matched against each element by itself, so it matches an element by what is below it. A query also depends on what is above the element. Skip the links in the navigation with the query ``"nav a"``, and all the links with the element test ``"a"``:

```wl
In[32]:= {HTMLInnerText[tree, "Roles" -> {"nav a" -> "Skip"}], HTMLInnerText[tree, "Roles" -> {"a" -> "Skip"}]}

Out[32]= {"Copper Soup Bar\nSeasonal bowls, made to order.\nMiso\nPho\nRamen (sold out)", "Copper Soup Bar\nSeasonal bowls, made to order."}
```

To give a rule as a query, put it in parentheses, as in ``(XMLPattern["nav"][Descendant[x : XMLPattern["a"]]] :> x) -> "Skip"``, which skips the same links as ``"nav a" -> "Skip"``. The names in ``rhs$`` must be bound to elements, not to attributes or text. An ``XMLDocument`` pattern can be used only in a query.

The first rule that selects an element applies, whichever kind its key is. An element that no rule selects keeps its default role, or its default construct. Compare the same two rules in both orders:

```wl
In[33]:= {HTMLInnerText[readable, "Roles" -> {"li.specials" -> "Skip", "ul > li" -> "Inline"}], HTMLInnerText[readable, "Roles" -> {"ul > li" -> "Inline", "li.specials" -> "Skip"}]}

Out[33]= {"Copper Soup Bar\nSeasonal bowls, made to order.\nPho", "Copper Soup Bar\nSeasonal bowls, made to order.\nMisoPho"}
```

The names in an element test can be used in the value of a ``:>`` rule. The names in a query cannot. Keys can also use list keys: keys such as ``"classList$"``, whose value is a list of tokens taken from an attribute. The ``"AttributeReadings"`` option adds list keys for other attributes, such as ``"relList$"`` for ``rel``. Skip the list items that have a class:

```wl
In[34]:= HTMLInnerText[readable, "Roles" -> {XMLPattern["li", "classList" -> classes_] :> If[classes === {}, "Block", "Skip"]}]

Out[34]= "Copper Soup Bar\nSeasonal bowls, made to order.\nPho"
```

A name for a whole element, such as ``item`` in ``item : XMLPattern["li"]``, is bound to the element as it is in the tree, with its attributes as raw strings, such as ``"class" -> "menu specials"``, and without a ``"classList$"`` key.

## Converting to a Notebook

To keep the headings, lists, links and emphasis, convert the tree to a ``Notebook`` expression with ``HTMLToNotebook``. Block-level elements become cells, and inline elements become formatted text in those cells. ``Export`` and ``ExportString`` can then write the notebook as Markdown, PDF, RTF, etc. Convert the pruned tree to Markdown:

```wl
In[35]:= ExportString[HTMLToNotebook[readable], "Markdown"]

Out[35]= "# Copper Soup Bar\n\nSeasonal **bowls**, made to order.\n\n- [Miso](/miso)\n\n- [Pho](/pho)"
```

The ``"Constructs"`` option sets what elements become: a cell style such as ``"Section"``, a text style such as ``"Bold"``, ``"Plain"`` for plain text, or a function that gives a ``Cell`` or boxes. Its keys are chosen as in ``"Roles"``. Make the heading a section, and the links in the list plain text:

```wl
In[36]:= ExportString[HTMLToNotebook[readable, "Constructs" -> {"h1" -> "Section", "ul a" -> "Plain"}], "Markdown"]

Out[36]= "### Copper Soup Bar\n\nSeasonal **bowls**, made to order.\n\n- Miso\n\n- Pho"
```

## Other Functions

``XMLPosition`` gives the positions of the matches of a pattern, and ``XMLExtract`` gives the parts at such positions. ``XMLFreeQ`` tests whether no element of a tree matches a pattern. ``XMLReplace`` can also replace tags, classes, attribute lists and the contents of elements. ``HTMLToTree`` can draw only the elements that match a query, and ``FromCSSSelector`` lists the CSS selectors that it translates. The reference page of each function gives the details.

## More About

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)

## Related Tech Notes

* [Patterns](paclet:tutorial/Patterns)

* [Working with String Patterns](paclet:tutorial/WorkingWithStringPatterns)
