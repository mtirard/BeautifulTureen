# HTMLToTree

   ``HTMLToTree[tree$]`` draws ``tree$`` as a ``Tree``, with one node per element and per text string.
   ``HTMLToTree[tree$, n$]`` draws the elements of ``tree$`` down to depth ``n$``.

## Details and Options

``tree$`` can be an ``XMLObject``, an ``XMLElement``, or a list of elements and strings. A document or a list is drawn under a root labelled ``"#document"``, and an ``XMLElement`` is drawn as the root.

Each element is drawn as a node labelled with its tag name. Its tooltip gives its compound selector, such as ``"div#main.note"``, and its attributes.

Each text string is drawn as a leaf labelled with its text, with runs of whitespace collapsed and the text cut to 40 characters. Its tooltip gives the whole string.

In ``HTMLToTree[tree$, n$]``, ``n$`` is a non-negative integer or ``Infinity``, the default. The root is at depth 0, its element children at depth 1, and so on. Text has the depth of its element.

An element at depth ``n$`` that has element children is drawn with a single ``...`` leaf in place of its contents.

In ``"Focus" -> query$`` and ``"Hide" -> query$``, ``query$`` can be anything that ``XMLCases`` takes, such as an ``XMLPattern``, an ``XMLDocument`` pattern, a CSS selector string or a rule.

With ``"Focus" -> query$``, only the elements that ``query$`` matches are drawn, with their contents, and the rest of ``tree$`` is collapsed. With a rule such as ``pattern$ :> x$``, the elements bound to ``x$`` are focused.

A focused element is drawn below its nearest drawn ancestor. When elements between them are not drawn, the edge is dashed, and its tooltip gives the elements left out.

Each run of consecutive siblings that are not drawn and contain no focused element is drawn as a single ``...`` leaf.

With ``"Focus"``, depth counts from each focused element, and a focused element below depth ``n$`` is still drawn.

With ``"Hide" -> query$``, the elements that ``query$`` matches are left out with their contents, and nothing is drawn in their place.

Hiding takes precedence over focus: a focused element that is hidden, or inside a hidden element, is not drawn.

Both queries are matched against the whole of ``tree$``, before anything is hidden.

In a rule, the name must be bound to an element or a run of element children. For ``"Hide"``, it can also be bound to the contents of an element, which hides the contents and keeps the element.

With ``"MergeText" -> HTMLInnerText``, an element whose children are all inline elements or text is drawn with a single text leaf in place of its contents. The text is what ``HTMLInnerText`` gives for the element, with the same ``"Roles"`` and ``"AttributeReadings"``.

With ``"MergeText" -> HTMLTextContent``, the text is what ``HTMLTextContent`` gives.

Strings made only of ``HTMLWhitespace`` characters are left out, unless ``"IncludeWhitespace" -> True`` is given. Comments and processing instructions are left out.

The following options can be given:

| option | default | description |
| :--- | :--- | :--- |
| "Focus" | ``Automatic`` | elements to draw with their contents; ``Automatic`` is ``All``, which draws all elements |
| "Hide" | ``Automatic`` | elements to leave out with their contents; ``Automatic`` is ``None`` |
| "CollapsePaths" | ``Automatic`` | whether to draw the elements on the path to a focused element as a dashed edge, ``True``, or as nodes, ``False``; ``Automatic`` is ``True`` |
| "MergeText" | ``Automatic`` | ``None``, ``HTMLInnerText`` or ``HTMLTextContent``, the function that gives merged text; ``Automatic`` is ``None`` |
| "IncludeWhitespace" | ``Automatic`` | whether to draw strings of only whitespace; ``Automatic`` is ``False`` |
| "Roles" | ``Automatic`` | rules that set the role of elements for merging, as in ``HTMLInnerText``; ``Automatic`` is ``{}`` |
| "AttributeReadings" | ``Automatic`` | attributes to split into lists of tokens for this call, in addition to ``$AttributeReadings``; ``Automatic`` is ``<\|\|>`` |

Any option of ``Tree`` can also be given, and is passed to ``Tree``. ``HTMLToTree`` uses ``TreeLayout -> Left``, and an ``ImageSize`` computed from the tree that is drawn, unless other values are given.

The result is a ``Tree``, with the following node data:

| node | data |
| :--- | :--- |
| element | ``XMLElement[tag$, attrs$, {}]``, the element with its contents removed |
| text | the string |
| root of a document or a list | ``"#document"`` |
| ``...`` leaf | ``Missing["Collapsed", k$]``, where ``k$`` is the number of elements it stands for |

``HTMLToTree`` issues a message and returns ``$Failed`` when ``tree$`` or an option value has none of the forms above.

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Draw an HTML fragment as a tree, with one node per element and per text string:

```wl
In[1]:= HTMLToTree[ImportString["<h1>Soups</h1><p>A <b>short</b> list.</p><ul><li>Miso</li><li>Pho</li></ul>", {"HTML", "XMLObject"}]]

Out[1]= (* graphics *)
```

---

Draw an element, such as one that ``XMLFirstCase`` gives, as the root:

```wl
In[1]:= menu = XMLFirstCase[ImportString["<h1>Soups</h1><ul><li>Miso</li><li class=\"new\">Pho</li></ul>", {"HTML", "XMLObject"}], "ul"];
HTMLToTree[menu]

Out[1]= (* graphics *)
```

---

Draw a list of elements under a ``"#document"`` root:

```wl
In[1]:= items = XMLCases[ImportString["<h1>Soups</h1><ul><li>Miso</li><li class=\"new\">Pho</li></ul>", {"HTML", "XMLObject"}], "li"];
HTMLToTree[items]

Out[1]= (* graphics *)
```

### Scope

---

Draw the elements down to depth 3, and collapse what is below:

```wl
In[1]:= doc = ImportString["<body><nav><a href=\"/\">Home</a> <a href=\"/soups\">Soups</a></nav><main><h1>Soups</h1><p class=\"lead\">A <b>short</b> list of <a href=\"/miso\">soups</a>.</p><ul class=\"menu\"><li>Miso</li><li class=\"new\">Pho</li><li>Laksa</li></ul></main><footer>Updated <time>2026</time></footer></body>", {"HTML", "XMLObject"}];
HTMLToTree[doc, 3]

Out[1]= (* graphics *)
```

Draw only the root, at depth 0:

```wl
In[2]:= HTMLToTree[doc, 0]

Out[2]= (* graphics *)
```

---

Focus on the elements that an ``XMLPattern`` matches:

```wl
In[1]:= doc = ImportString["<body><nav><a href=\"/\">Home</a> <a href=\"/soups\">Soups</a></nav><main><h1>Soups</h1><p class=\"lead\">A <b>short</b> list of <a href=\"/miso\">soups</a>.</p><ul class=\"menu\"><li>Miso</li><li class=\"new\">Pho</li><li>Laksa</li></ul></main><footer>Updated <time>2026</time></footer></body>", {"HTML", "XMLObject"}];
HTMLToTree[doc, "Focus" -> XMLPattern["li"]]

Out[1]= (* graphics *)
```

Focus on the elements bound to a name in a rule, here each paragraph right after a heading:

```wl
In[2]:= HTMLToTree[doc, "Focus" -> (XMLPattern[_][{___, XMLPattern["h1"], x : XMLPattern["p"], ___}] :> x)]

Out[2]= (* graphics *)
```

Focus on the elements that a CSS selector matches:

```wl
In[3]:= HTMLToTree[doc, "Focus" -> "li.new"]

Out[3]= (* graphics *)
```

---

Give a depth with a focus, to count depth from each focused element:

```wl
In[1]:= doc = ImportString["<body><nav><a href=\"/\">Home</a> <a href=\"/soups\">Soups</a></nav><main><h1>Soups</h1><p class=\"lead\">A <b>short</b> list of <a href=\"/miso\">soups</a>.</p><ul class=\"menu\"><li>Miso</li><li class=\"new\">Pho</li><li>Laksa</li></ul></main><footer>Updated <time>2026</time></footer></body>", {"HTML", "XMLObject"}];
HTMLToTree[doc, 1, "Focus" -> "main"]

Out[1]= (* graphics *)
```

---

Hide the elements that a query matches, with their contents:

```wl
In[1]:= doc = ImportString["<body><nav><a href=\"/\">Home</a> <a href=\"/soups\">Soups</a></nav><main><h1>Soups</h1><p class=\"lead\">A <b>short</b> list of <a href=\"/miso\">soups</a>.</p><ul class=\"menu\"><li>Miso</li><li class=\"new\">Pho</li><li>Laksa</li></ul></main><footer>Updated <time>2026</time></footer></body>", {"HTML", "XMLObject"}];
HTMLToTree[doc, "Hide" -> "nav, footer"]

Out[1]= (* graphics *)
```

---

Focus on links and hide ``nav``, so that the links inside ``nav`` are not drawn:

```wl
In[1]:= doc = ImportString["<body><nav><a href=\"/\">Home</a> <a href=\"/soups\">Soups</a></nav><main><h1>Soups</h1><p class=\"lead\">A <b>short</b> list of <a href=\"/miso\">soups</a>.</p><ul class=\"menu\"><li>Miso</li><li class=\"new\">Pho</li><li>Laksa</li></ul></main><footer>Updated <time>2026</time></footer></body>", {"HTML", "XMLObject"}];
HTMLToTree[doc, "Focus" -> "a", "Hide" -> "nav"]

Out[1]= (* graphics *)
```

---

Hide the contents of an element and keep the element, by binding a name to the contents:

```wl
In[1]:= HTMLToTree[XMLElement["div", {}, {XMLElement["pre", {}, {"code"}], XMLElement["p", {}, {"text"}]}], "Hide" -> (XMLElement["pre", _, c_] :> c)]

Out[1]= (* graphics *)
```

---

Focus on the links outside any ``nav``, with an ``XMLDocument`` pattern:

```wl
In[1]:= doc = ImportString["<body><nav><a href=\"/\">Home</a> <a href=\"/soups\">Soups</a></nav><main><h1>Soups</h1><p class=\"lead\">A <b>short</b> list of <a href=\"/miso\">soups</a>.</p><ul class=\"menu\"><li>Miso</li><li class=\"new\">Pho</li><li>Laksa</li></ul></main><footer>Updated <time>2026</time></footer></body>", {"HTML", "XMLObject"}];
HTMLToTree[doc, "Focus" -> (XMLDocument[Descendant[x : XMLPattern["a"]]?(NoneTrue[XMLMatchQ["nav"]])] :> x)]

Out[1]= (* graphics *)
```

### Options

#### CollapsePaths

---

Draw the elements on the path to a focused element as nodes:

```wl
In[1]:= doc = ImportString["<body><nav><a href=\"/\">Home</a> <a href=\"/soups\">Soups</a></nav><main><h1>Soups</h1><p class=\"lead\">A <b>short</b> list of <a href=\"/miso\">soups</a>.</p><ul class=\"menu\"><li>Miso</li><li class=\"new\">Pho</li><li>Laksa</li></ul></main><footer>Updated <time>2026</time></footer></body>", {"HTML", "XMLObject"}];
HTMLToTree[doc, "Focus" -> "li.new", "CollapsePaths" -> False]

Out[1]= (* graphics *)
```

#### MergeText

---

Draw each element whose contents are inline as a single text leaf:

```wl
In[1]:= doc = ImportString["<body><nav><a href=\"/\">Home</a> <a href=\"/soups\">Soups</a></nav><main><h1>Soups</h1><p class=\"lead\">A <b>short</b> list of <a href=\"/miso\">soups</a>.</p><ul class=\"menu\"><li>Miso</li><li class=\"new\">Pho</li><li>Laksa</li></ul></main><footer>Updated <time>2026</time></footer></body>", {"HTML", "XMLObject"}];
HTMLToTree[doc, "Focus" -> "main", "MergeText" -> HTMLInnerText]

Out[1]= (* graphics *)
```

---

Get the merged text, which is what ``HTMLInnerText`` gives, with whitespace collapsed:

```wl
In[1]:= para = ImportString["<p>Hot\n    <b>miso</b>\n    soup</p>", {"HTML", "XMLObject"}];
TreeData /@ TreeLeaves[HTMLToTree[para, "MergeText" -> HTMLInnerText]]

Out[1]= {"Hot miso soup"}
```

Use ``HTMLTextContent`` to get the text with its whitespace as written:

```wl
In[2]:= TreeData /@ TreeLeaves[HTMLToTree[para, "MergeText" -> HTMLTextContent]]

Out[2]= {"Hot\n    miso\n    soup"}
```

#### Roles

---

Make ``b`` a block-level element, so that the paragraph that holds it is not merged:

```wl
In[1]:= doc = ImportString["<body><nav><a href=\"/\">Home</a> <a href=\"/soups\">Soups</a></nav><main><h1>Soups</h1><p class=\"lead\">A <b>short</b> list of <a href=\"/miso\">soups</a>.</p><ul class=\"menu\"><li>Miso</li><li class=\"new\">Pho</li><li>Laksa</li></ul></main><footer>Updated <time>2026</time></footer></body>", {"HTML", "XMLObject"}];
HTMLToTree[doc, "Focus" -> "p", "MergeText" -> HTMLInnerText, "Roles" -> {"b" -> "Block"}]

Out[1]= (* graphics *)
```

#### IncludeWhitespace

---

Draw the whitespace-only string between two elements:

```wl
In[1]:= HTMLToTree[ImportString["<p><b>Hot</b> <i>miso</i></p>", {"HTML", "XMLObject"}], "IncludeWhitespace" -> True]

Out[1]= (* graphics *)
```

#### AttributeReadings

---

Split ``rel`` into tokens, to focus on the links whose ``rel`` contains ``sponsored``:

```wl
In[1]:= links = ImportString["<p><a rel=\"nofollow sponsored\" href=\"/ad\">Ad</a> and <a href=\"/docs\">docs</a></p>", {"HTML", "XMLObject"}];
HTMLToTree[links, "Focus" -> XMLPattern["a", "relList" -> "sponsored"], "AttributeReadings" -> <|"rel" -> <||>|>]

Out[1]= (* graphics *)
```

#### TreeLayout

---

Use the top-down layout of ``Tree``:

```wl
In[1]:= menu = XMLFirstCase[ImportString["<h1>Soups</h1><ul><li>Miso</li><li class=\"new\">Pho <b>new</b></li></ul>", {"HTML", "XMLObject"}], "ul"];
HTMLToTree[menu, TreeLayout -> Automatic]

Out[1]= (* graphics *)
```

#### MaxDisplayedChildren

---

Draw at most two children of each node, not only of the root:

```wl
In[1]:= doc = ImportString["<body><nav><a href=\"/\">Home</a> <a href=\"/soups\">Soups</a></nav><main><h1>Soups</h1><p class=\"lead\">A <b>short</b> list of <a href=\"/miso\">soups</a>.</p><ul class=\"menu\"><li>Miso</li><li class=\"new\">Pho</li><li>Laksa</li></ul></main><footer>Updated <time>2026</time></footer></body>", {"HTML", "XMLObject"}];
HTMLToTree[doc, "Focus" -> "main", MaxDisplayedChildren -> 2]

Out[1]= (* graphics *)
```

#### ImageSize

---

Give the width of the drawing:

```wl
In[1]:= doc = ImportString["<body><nav><a href=\"/\">Home</a> <a href=\"/soups\">Soups</a></nav><main><h1>Soups</h1><p class=\"lead\">A <b>short</b> list of <a href=\"/miso\">soups</a>.</p><ul class=\"menu\"><li>Miso</li><li class=\"new\">Pho</li><li>Laksa</li></ul></main><footer>Updated <time>2026</time></footer></body>", {"HTML", "XMLObject"}];
HTMLToTree[doc, 3, ImageSize -> 300]

Out[1]= (* graphics *)
```

#### TreeElementLabelFunction

---

Label the text leaves with a function, and keep the default labels of the elements:

```wl
In[1]:= menu = XMLFirstCase[ImportString["<h1>Soups</h1><ul><li>Miso</li><li class=\"new\">Pho <b>new</b></li></ul>", {"HTML", "XMLObject"}], "ul"];
HTMLToTree[menu, TreeElementLabelFunction -> {"Leaves" -> (Style[ToUpperCase[#], Bold] &)}]

Out[1]= (* graphics *)
```

### Applications

---

Draw a page roughly as a reader sees it, with hiding and merging:

```wl
In[1]:= page = ImportString["<html><head><title>Soups</title><style>b{color:red}</style></head><body><main><h1>Soups</h1><p>A <b>short</b> list of <a href=\"/miso\">soups</a>.</p><template><p>Not shown</p></template><ul><li>Miso <i>(new)</i></li><li>Pho</li></ul></main><script>track()</script></body></html>", {"HTML", "XMLObject"}];
HTMLToTree[page, "Hide" -> "head, script, style, template", "MergeText" -> HTMLInnerText]

Out[1]= (* graphics *)
```

---

Fetch the 1989 web proposal and draw its outline, focused on its section headings:

```wl
In[1]:= tree = Import["https://www.w3.org/History/1989/proposal.html", {"HTML", "XMLObject"}];
HTMLToTree[tree, "Focus" -> "h2"]

Out[1]= (* graphics *)
```

---

Find where the images inside ``center`` elements sit on the page:

```wl
In[1]:= tree = Import["https://www.w3.org/History/1989/proposal.html", {"HTML", "XMLObject"}];
HTMLToTree[tree, "Focus" -> "center img", "CollapsePaths" -> False]

Out[1]= (* graphics *)
```

---

Find the ``...`` leaves of a tree, and the number of elements each stands for:

```wl
In[1]:= doc = ImportString["<body><nav><a href=\"/\">Home</a> <a href=\"/soups\">Soups</a></nav><main><h1>Soups</h1><p class=\"lead\">A <b>short</b> list of <a href=\"/miso\">soups</a>.</p><ul class=\"menu\"><li>Miso</li><li class=\"new\">Pho</li><li>Laksa</li></ul></main><footer>Updated <time>2026</time></footer></body>", {"HTML", "XMLObject"}];
tree = HTMLToTree[doc, "Focus" -> "li"];
TreeData /@ TreeCases[tree, Missing["Collapsed", _]]

Out[1]= {Missing["Collapsed", 7], Missing["Collapsed", 2]}
```

Get the focused elements, with their contents removed:

```wl
In[2]:= TreeData /@ TreeCases[tree, XMLElement["li", __]]

Out[2]= {XMLElement["li", {}, {}], XMLElement["li", {"class" -> "new"}, {}], XMLElement["li", {}, {}]}
```

### Properties & Relations

---

Compare the focused elements with the elements that ``XMLCases`` gives for the same query:

```wl
In[1]:= doc = ImportString["<body><nav><a href=\"/\">Home</a> <a href=\"/soups\">Soups</a></nav><main><h1>Soups</h1><p class=\"lead\">A <b>short</b> list of <a href=\"/miso\">soups</a>.</p><ul class=\"menu\"><li>Miso</li><li class=\"new\">Pho</li><li>Laksa</li></ul></main><footer>Updated <time>2026</time></footer></body>", {"HTML", "XMLObject"}];
tree = HTMLToTree[doc, "Focus" -> "h1, li.new"];
TreeData /@ TreeCases[tree, _XMLElement] === (XMLCases[doc, "h1, li.new"] /. XMLElement[tag_, attrs_, _] :> XMLElement[tag, attrs, {}])

Out[1]= True
```

---

Get the data of the element nodes, each an element with its contents removed:

```wl
In[1]:= para = XMLElement["p", {"class" -> "lead"}, {"A ", XMLElement["b", {}, {"short"}], " list."}];
TreeData /@ TreeChildren[HTMLToTree[para]]

Out[1]= {"A ", XMLElement["b", {}, {}], " list."}
```

---

Draw one node per element and per string with ``HTMLToTree``:

```wl
In[1]:= para = XMLElement["p", {"class" -> "lead"}, {"A ", XMLElement["b", {}, {"short"}], " list."}];
HTMLToTree[para]

Out[1]= (* graphics *)
```

Compare with ``ExpressionTree``, which also draws the lists of attributes and contents:

```wl
In[2]:= ExpressionTree[para]

Out[2]= (* graphics *)
```

### Possible Issues

---

Focus on the element given as ``tree$``, which is not focused, as ``XMLCases`` does not give it:

```wl
In[1]:= menu = XMLFirstCase[ImportString["<h1>Soups</h1><ul><li>Miso</li><li class=\"new\">Pho <b>new</b></li></ul>", {"HTML", "XMLObject"}], "ul"];
HTMLToTree[menu, "Focus" -> "ul"]

Out[1]= (* graphics *)
```

Give the element in a list to focus it:

```wl
In[2]:= HTMLToTree[{menu}, "Focus" -> "ul"]

Out[2]= (* graphics *)
```

---

Hide the element given as ``tree$``, which is kept with a message:

```wl
In[1]:= menu = XMLFirstCase[ImportString["<h1>Soups</h1><ul><li>Miso</li><li class=\"new\">Pho <b>new</b></li></ul>", {"HTML", "XMLObject"}], "ul"];
HTMLToTree[menu, "Hide" -> "ul"]

During evaluation of In[1]:= HTMLToTree::root: The root element cannot be hidden; it was kept.

Out[1]= (* graphics *)
```

---

Draw a whole page, to get a tree too large to read:

```wl
In[1]:= tree = Import["https://www.w3.org/History/1989/proposal.html", {"HTML", "XMLObject"}];
TreeSize[HTMLToTree[tree]]

Out[1]= 466
```

Limit the depth and the number of children drawn, or use a focus or hide query:

```wl
In[2]:= HTMLToTree[tree, 3, MaxDisplayedChildren -> 5]

Out[2]= (* graphics *)
```

---

Give a string of HTML, which is not drawn:

```wl
In[1]:= HTMLToTree["<p>Hi</p>"]

During evaluation of In[1]:= HTMLToTree::badtree: The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head String.

Out[1]= $Failed
```

Import it first:

```wl
In[2]:= HTMLToTree[ImportString["<p>Hi</p>", {"HTML", "XMLObject"}]]

Out[2]= (* graphics *)
```

---

Focus with a name bound to an attribute value, to get a message:

```wl
In[1]:= doc = ImportString["<body><nav><a href=\"/\">Home</a> <a href=\"/soups\">Soups</a></nav><main><h1>Soups</h1><p class=\"lead\">A <b>short</b> list of <a href=\"/miso\">soups</a>.</p><ul class=\"menu\"><li>Miso</li><li class=\"new\">Pho</li><li>Laksa</li></ul></main><footer>Updated <time>2026</time></footer></body>", {"HTML", "XMLObject"}];
HTMLToTree[doc, "Focus" -> (XMLPattern["a", "href" -> h_] :> h)]

During evaluation of In[1]:= HTMLToTree::focustarget: The "Focus" query selects the position {1, 1, 1, 1, Key["href"]}. Focus draws only elements and runs of element children.

Out[1]= $Failed
```

Bind the name to the element instead:

```wl
In[2]:= HTMLToTree[doc, "Focus" -> (x : XMLPattern["a", "href" -> _] :> x)]

Out[2]= (* graphics *)
```

---

Give an option that neither ``HTMLToTree`` nor ``Tree`` has, to leave the call unevaluated:

```wl
In[1]:= menu = XMLFirstCase[ImportString["<h1>Soups</h1><ul><li>Miso</li><li class=\"new\">Pho <b>new</b></li></ul>", {"HTML", "XMLObject"}], "ul"];
HTMLToTree[menu, "Depth" -> 1]

During evaluation of In[1]:= HTMLToTree::optx: Unknown option "Depth" in HTMLToTree[XMLElement["ul", {}, {XMLElement["li", {}, {"Miso"}], XMLElement["li", {"class" -> "new"}, {"Pho ", XMLElement["b", {}, {"new"}]}]}], "Depth" -> 1].

Out[1]= HTMLToTree[XMLElement["ul", {}, {XMLElement["li", {}, {"Miso"}], XMLElement["li", {"class" -> "new"}, {"Pho ", XMLElement["b", {}, {"new"}]}]}], "Depth" -> 1]
```

Give the depth as the second argument:

```wl
In[2]:= HTMLToTree[menu, 1]

Out[2]= (* graphics *)
```

## See Also

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [HTMLToNotebook](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLToNotebook)

* [HTMLInnerText](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLInnerText)

* [HTMLTextContent](paclet:MaximilienTirard/HTMLPatterns/ref/HTMLTextContent)

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [FromCSSSelector](paclet:MaximilienTirard/HTMLPatterns/ref/FromCSSSelector)

* [XMLFirstCase](paclet:MaximilienTirard/HTMLPatterns/ref/XMLFirstCase)

* [Tree](paclet:ref/Tree)

* [ExpressionTree](paclet:ref/ExpressionTree)

* [TreeForm](paclet:ref/TreeForm)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
