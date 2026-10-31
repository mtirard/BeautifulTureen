# Child

   ``Child[p$]`` is a constraint on an element in an ``XMLPattern``, met when some element child of it matches ``p$``.

## Details and Options

``Child`` is a **constraint**: a condition on what is below an element, given as an argument of the second bracket of ``XMLPattern`` or of ``XMLDocument``. Elsewhere, such as the whole pattern or an entry of a list pattern, it gives a message.

``Child[p$]`` is the list pattern ``{___, p$, ___}``, and gives the same results in the same order. Text among the children is left out.

``p$`` can be an ``XMLPattern``, an ``XMLElement`` pattern, a CSS selector for one element, or alternatives of these. Each can be named, have a condition or have a test. An ``XMLPattern`` or CSS selector in ``p$`` can have constraints of its own.

Under ``XMLDocument``, the children are the top-level elements of the tree.

Several ``Child`` constraints on one element are independent, and one child may meet several of them. For children in an order, or next to each other, give a list pattern, such as ``{___, a$, ___, b$, ___}`` or ``{___, a$, b$, ___}``.

Unlike ``Descendant``, ``Child`` takes no name or test on itself. Give them to the child, as in ``Child[x : XMLPattern["li"]]``.

## Examples

```wl
Needs["MaximilienTirard`HTMLPatterns`"]
```

---

Give each li child of a ul, but not those of an ol:

```wl
In[1]:= lists = ImportString["<ul><li>Home</li><li>Docs</li></ul><ol><li>Step one</li></ol>", {"HTML", "XMLObject"}];
XMLCases[lists, XMLPattern["ul"][Child[x : XMLPattern["li"]]] :> HTMLTextContent[x]]

Out[1]= {"Home", "Docs"}
```

---

Test whether a figure has an img child:

```wl
In[1]:= XMLMatchQ[XMLElement["figure", {}, {XMLElement["img", {"src" -> "a.png"}, {}], XMLElement["figcaption", {}, {"A"}]}], XMLPattern["figure"][Child[XMLPattern["img"]]]]

Out[1]= True
```

### Scope

---

Give several ``Child`` constraints, all of which must hold:

```wl
In[1]:= page = ImportString["<section id=\"a\"><h2>Rates</h2><table></table></section><section id=\"b\"><h2>Notes</h2><p>None.</p></section>", {"HTML", "XMLObject"}];
XMLCases[page, XMLPattern["section", "id" -> id_][Child[XMLPattern["h2"]], Child[XMLPattern["table"]]] :> id]

Out[1]= {"a"}
```

---

Name the child that meets each constraint, and give both:

```wl
In[1]:= page = ImportString["<dl><dt>Term</dt><dd>Definition</dd></dl>", {"HTML", "XMLObject"}];
XMLCases[page, XMLPattern["dl"][Child[t : XMLPattern["dt"]], Child[d : XMLPattern["dd"]]] :> HTMLTextContent[t] -> HTMLTextContent[d]]

Out[1]= {"Term" -> "Definition"}
```

---

Nest a pattern with a ``Child`` constraint of its own, as the selector ``table > tr > td`` does:

```wl
In[1]:= table = ImportString["<table><tr><th>Day</th><td>Friday</td></tr></table>", {"HTML", "XMLObject"}];
XMLCases[table, XMLPattern["table"][Child[XMLPattern["tr"][Child[x : XMLPattern["td"]]]]] :> HTMLTextContent[x]]

Out[1]= {"Friday"}
```

---

Combine ``Child`` with ``Descendant``, here for a nav with a ul child and a link anywhere below:

```wl
In[1]:= navs = ImportString["<nav id=\"main\"><ul><li><a href=\"/\">Home</a></li></ul></nav><nav id=\"crumbs\"><a href=\"/\">Home</a></nav>", {"HTML", "XMLObject"}];
XMLCases[navs, XMLPattern["nav", "id" -> id_][Child[XMLPattern["ul"]], Descendant[XMLPattern["a"]]] :> id]

Out[1]= {"main"}
```

---

Give a CSS selector string for one element as the pattern:

```wl
In[1]:= lists = ImportString["<ul><li class=\"done\">Draft</li><li>Review</li></ul>", {"HTML", "XMLObject"}];
XMLCases[lists, XMLPattern["ul"][Child[x : "li:not(.done)"]] :> HTMLTextContent[x]]

Out[1]= {"Review"}
```

---

Give alternatives of constraints, here for a div that has an img child or no element children:

```wl
In[1]:= divs = XMLElement["body", {}, {XMLElement["div", {"id" -> "a"}, {XMLElement["img", {}, {}]}], XMLElement["div", {"id" -> "b"}, {"text"}], XMLElement["div", {"id" -> "c"}, {XMLElement["p", {}, {}]}]}];
XMLCases[divs, XMLPattern["div", "id" -> id_][Child[XMLPattern["img"]] | {}] :> id]

Out[1]= {"a", "b"}
```

---

Under ``XMLDocument``, give ``Child`` to constrain the top-level elements of the tree:

```wl
In[1]:= fragments = {XMLElement["p", {}, {"Intro"}], XMLElement["table", {"id" -> "rates"}, {}]};
XMLCases[fragments, XMLDocument[Child[x : XMLPattern["table"]]] :> x]

Out[1]= {XMLElement["table", {"id" -> "rates"}, {}]}
```

### Properties & Relations

---

``Child[p$]`` gives what the list pattern ``{___, p$, ___}`` gives:

```wl
In[1]:= tree = ImportString["<ul><li>A<ul><li>B</li></ul></li></ul><ol><li>C</li></ol>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern[_][Child[x : XMLPattern["li"]]] :> x] === XMLCases[tree, XMLPattern[_][{___, x : XMLPattern["li"], ___}] :> x]

Out[1]= True
```

---

It is met by the same elements as ``Descendant[p$, {1}]``:

```wl
In[1]:= tree = ImportString["<ul><li>A<ul><li>B</li></ul></li></ul><ol><li>C</li></ol>", {"HTML", "XMLObject"}];
XMLCases[tree, XMLPattern[_][Child[XMLPattern["li"]]]] === XMLCases[tree, XMLPattern[_][Descendant[XMLPattern["li"], {1}]]]

Out[1]= True
```

---

The CSS selector ``"ul > li"`` gives the li children of each ul:

```wl
In[1]:= lists = ImportString["<ul><li>Home</li><li>Docs</li></ul><ol><li>Step one</li></ol>", {"HTML", "XMLObject"}];
XMLCases[lists, "ul > li"] === XMLCases[lists, XMLPattern["ul"][Child[x : XMLPattern["li"]]] :> x]

Out[1]= True
```

### Possible Issues

---

A name on the constraint itself issues a message:

```wl
In[1]:= lists = ImportString["<ul><li>Home</li></ul>", {"HTML", "XMLObject"}];
XMLCases[lists, XMLPattern["ul"][x : Child[XMLPattern["li"]]] :> x]

During evaluation of In[1]:= Child::name: x:Child[XMLPattern["li"]] names a Child constraint, which has nothing to bind: between an element and its child there is no element. Name the child instead, as in Child[n : p].

Out[1]= $Failed
```

Name the child instead:

```wl
In[2]:= XMLCases[lists, XMLPattern["ul"][Child[x : XMLPattern["li"]]] :> x]

Out[2]= {XMLElement["li", {}, {"Home"}]}
```

---

``Child`` takes one pattern:

```wl
In[1]:= page = ImportString["<dl><dt>Term</dt><dd>Definition</dd></dl>", {"HTML", "XMLObject"}];
XMLCases[page, XMLPattern["dl"][Child[XMLPattern["dt"], XMLPattern["dd"]]]]

During evaluation of In[1]:= Child::args: Child[XMLPattern["dt"], XMLPattern["dd"]] is not a constraint: Child takes one pattern. For children that match several patterns, give several constraints, as in XMLPattern[tag][Child[a], Child[b]], or, for children in an order, a list, as in XMLPattern[tag][{___, a, ___, b, ___}].

Out[1]= $Failed
```

Give two constraints for children in any order:

```wl
In[2]:= XMLCases[page, XMLPattern["dl"][Child[XMLPattern["dd"]], Child[XMLPattern["dt"]]]]

Out[2]= {XMLElement["dl", {}, {XMLElement["dt", {}, {"Term"}], XMLElement["dd", {}, {"Definition"}]}]}
```

Give a list for children in an order, here next to each other:

```wl
In[3]:= XMLCases[page, XMLPattern["dl"][{___, XMLPattern["dt"], XMLPattern["dd"], ___}]]

Out[3]= {XMLElement["dl", {}, {XMLElement["dt", {}, {"Term"}], XMLElement["dd", {}, {"Definition"}]}]}
```

---

``Child`` is a constraint, so it cannot be the whole pattern:

```wl
In[1]:= lists = ImportString["<ul><li>Home</li><li>Docs</li></ul>", {"HTML", "XMLObject"}];
XMLCases[lists, Child[XMLPattern["ul"], XMLPattern["li"]]]

During evaluation of In[1]:= Child::place: Child[XMLPattern["ul"], XMLPattern["li"]] is not a pattern. Child is a constraint, which can only be an argument of the bracket after XMLPattern[tag, attrs] or of XMLDocument: XMLPattern["ul"][Child[x : XMLPattern["li"]]] :> x gives the li children of each ul. Child takes one pattern: for children that match several patterns, give several constraints, Child[a], Child[b], or a list, {___, a, ___, b, ___}.

Out[1]= $Failed
```

Nest the patterns as the document is, and name what to give:

```wl
In[2]:= XMLCases[lists, XMLPattern["ul"][Child[x : XMLPattern["li"]]] :> x]

Out[2]= {XMLElement["li", {}, {"Home"}], XMLElement["li", {}, {"Docs"}]}
```

---

An element pattern alone is not a constraint:

```wl
In[1]:= lists = ImportString["<ul><li>Home</li></ul>", {"HTML", "XMLObject"}];
XMLCases[lists, XMLPattern["ul"][XMLPattern["li"]]]

During evaluation of In[1]:= XMLPattern::constraint: XMLPattern["li"] is not a constraint. The constraints on what is below an element are the arguments of the bracket after XMLPattern[tag, attrs], as in XMLPattern[tag, attrs][c1, c2, ...]: Child[p] for some element child that matches p, a list pattern over its element children, as in {p} for an only child, or Descendant[p] for an element anywhere below. Attribute constraints go in the first bracket, several in one list: XMLPattern[tag, {a1, a2, ...}].

Out[1]= $Failed
```

Give ``Child[p$]`` for some child that matches ``p$``, or ``{p$}`` for an only child:

```wl
In[2]:= {XMLCases[lists, XMLPattern["ul"][Child[XMLPattern["li"]]]], XMLCases[lists, XMLPattern["ul"][{XMLPattern["li"]}]]}

Out[2]= {{XMLElement["ul", {}, {XMLElement["li", {}, {"Home"}]}]}, {XMLElement["ul", {}, {XMLElement["li", {}, {"Home"}]}]}}
```

## See Also

* [XMLPattern](paclet:MaximilienTirard/HTMLPatterns/ref/XMLPattern)

* [Descendant](paclet:MaximilienTirard/HTMLPatterns/ref/Descendant)

* [XMLDocument](paclet:MaximilienTirard/HTMLPatterns/ref/XMLDocument)

* [XMLCases](paclet:MaximilienTirard/HTMLPatterns/ref/XMLCases)

* [XMLMatchQ](paclet:MaximilienTirard/HTMLPatterns/ref/XMLMatchQ)

* [FromCSSSelector](paclet:MaximilienTirard/HTMLPatterns/ref/FromCSSSelector)

## Tech Notes

* [Scraping HTML with Patterns](paclet:MaximilienTirard/HTMLPatterns/tutorial/ScrapingHTMLWithPatterns)

## Related Guides

* [HTMLPatterns](paclet:MaximilienTirard/HTMLPatterns/guide/HTMLPatterns)
