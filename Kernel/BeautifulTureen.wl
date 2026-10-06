(* ::Package:: *)
(* BeautifulTureen: XML patterns + the XML* consumers *)

BeginPackage["MaximilienTirard`BeautifulTureen`"];

(* === Public symbols === *)

XMLPattern::usage = "XMLPattern[tag] is an XML pattern that matches any XMLElement whose tag matches tag. XMLPattern[tag, attrs] also requires the element's attributes to match attrs. MatchQ and Cases treat XMLPattern as a literal expression; use it with XMLCases, XMLFirstCase, XMLDeleteCases, XMLMatchQ and the \"Roles\" and \"Constructs\" options. attrs is a \"key\" -> value rule, a bare \"key\" (any value), or a list of these, and can be named or tested as a whole. The element may have other attributes as well. A key is a string, a {namespace, name} pair, or alternatives of these. A value is any pattern, matched against the whole attribute value. The list key \"classList\" gives the element's classes as a list of strings, and \"classList\" -> \"cls\" matches an element that has the class cls. $AttributeReadings can add list keys for other attributes.";
CSSClass::usage = "CSSClass is obsolete. Match an element's class list with the \"classList\" key of XMLPattern instead: XMLPattern[tag, \"classList\" -> \"cls\"].";
$AttributeReadings::usage = "$AttributeReadings is an Association that gives, for each attribute it names, how the attribute value is split into a list of tokens and the list key that gives that list in an XMLPattern. Each entry is an Association with the fields Method, Delimiters, \"TrimWhitespace\" and \"ListKey\", any of which can be omitted. Method \"SpaceSeparated\" (the default) splits on HTMLWhitespace and does not trim tokens. Method \"CommaSeparated\" splits on \",\" and trims HTML whitespace from each token. Delimiters (a string pattern) and \"TrimWhitespace\" (True or False) override the setting that Method gives. \"ListKey\" -> Automatic gives the attribute name followed by \"List\". Keys are attribute names given as strings; a {namespace, name} attribute cannot have an entry. By default, $AttributeReadings has one entry, for \"class\", with the list key \"classList\". The \"AttributeReadings\" option of functions such as XMLCases adds entries for one call, and an entry for an attribute already present replaces it. Block[{$AttributeReadings = ...}, ...] replaces the whole Association, including the \"class\" entry.";
HTMLWhitespace::usage = "HTMLWhitespace is a string pattern that matches a run of one or more HTML whitespace characters: space, tab, line feed, form feed and carriage return. Use StringSplit[value, HTMLWhitespace] to split a class attribute as a browser does. HTMLWhitespace does not match no-break space or other Unicode whitespace, which StringSplit splits on by default.";
HTMLClassList::usage = "HTMLClassList[element] gives the classes of an XMLElement as a list of strings: its class attribute split on HTMLWhitespace, in the order written and with duplicates kept. An element with no class attribute, or with a class attribute that is empty or only whitespace, gives {}. HTMLClassList takes a single element; for many elements, use HTMLClassList /@ XMLCases[tree, pattern].";
XMLCases::usage = "XMLCases[tree, pattern] gives a list of the elements of tree, at any depth, that match pattern. The elements are in document order: an element comes before the elements nested in it, and an earlier sibling before a later one. tree itself is never included. pattern can be an XMLPattern, a Child, Descendant, Adjacent or Sibling combinator, alternatives of any of these, or any of these with a condition pat /; test. An XMLPattern or alternatives of them can also have a test pat?f, which applies f to the element. A CSS selector string, such as \"div.note > p\", can be given wherever a pattern goes, and means FromCSSSelector[string]. XMLCases[tree, pattern :> body] gives the value of body for each match, evaluated in document order. XMLCases[tree, pattern -> rhs] evaluates rhs once, before any matching, as Cases does, and gives its value for each match, with the names in pattern replaced by what they matched. XMLCases[tree, pattern, n] gives the first n of these, in document order, or all of them if there are fewer; n is a non-negative integer or Infinity. With pattern :> body, body is evaluated only for the matches it gives. A combinator gives each element that its last stage matches once. Alternatives that hold a combinator give each element that any of them matches once, and a name bound only in an alternative that did not match is Sequence[], as in Cases. If several alternatives match an element, the first of them that matches binds the names. If tree is an XMLElement, tree can match any stage of a combinator except the last. A name for a whole element, as in e : XMLPattern[...], gives the element as it appears in tree, without list keys such as \"classList\". XMLCases[tree, pattern, \"AttributeReadings\" -> readings] adds readings to $AttributeReadings for this call.";
XMLFirstCase::usage = "XMLFirstCase[tree, pattern] gives the first element of tree that matches pattern, in document order, or Missing[\"NotFound\"] if there is none. Of nested matches, it gives the outermost. XMLFirstCase[tree, pattern, default] gives default if there is no match. XMLFirstCase accepts the same patterns as XMLCases, including a CSS selector string, and gives the first element of the list that XMLCases gives. With pattern :> body, body is evaluated only for the match that XMLFirstCase returns. With pattern -> rhs, rhs is evaluated once, before any matching, as in FirstCase, and the names in pattern are replaced in its value by what they matched. The \"AttributeReadings\" option adds readings to $AttributeReadings, as in XMLCases.";
XMLDeleteCases::usage = "XMLDeleteCases[tree, pattern] gives tree with every element that matches pattern removed, at any depth. pattern can be an XMLPattern, a Child, Descendant, Adjacent or Sibling combinator, alternatives of any of these, or any of these with a condition pat /; test. An XMLPattern or alternatives of them can also have a test pat?f, which applies f to the element. A CSS selector string can be given wherever a pattern goes, and means FromCSSSelector[string]. Combinators can be nested, and each stage can have a condition. A combinator removes the elements that its last stage matches, by their position in tree, so Child[XMLPattern[_], {XMLPattern[\"li\"], ___}] removes the first li of each list and no other. As in XMLCases, if tree is an XMLElement, tree can match any stage of a combinator except the last. The root element of an XMLObject is never removed: XMLDeleteCases issues a message and removes the other elements that match. The \"AttributeReadings\" option adds readings to $AttributeReadings, as in XMLCases.";
XMLMatchQ::usage = "XMLMatchQ[element, pattern] gives True if element matches pattern, and False otherwise. XMLMatchQ[pattern] is an operator form. pattern can be an XMLPattern, alternatives of them, or either with a condition pat /; test or a test pat?f, or a CSS selector string that describes one element, such as \"a.external\". XMLMatchQ tests the element itself, not the elements nested in it; use XMLCases to search a tree. The \"AttributeReadings\" option adds readings to $AttributeReadings, in both XMLMatchQ[element, pattern, opts] and XMLMatchQ[pattern, opts].";
Child::usage = "Child[parentPat, childPat] is a combinator for XMLCases, XMLFirstCase and XMLDeleteCases that matches elements that match childPat and are direct children of an element that matches parentPat. Child[parentPat, {e1, e2, ...}] matches the list of patterns {e1, e2, ...} against the element children of each element that matches parentPat, leaving out text, and selects the child in the place of the last entry that is an XML pattern: Child[XMLPattern[_], {XMLPattern[\"li\"], ___}] matches each li that is the first element child of its parent, and Child[XMLPattern[_], {PatternSequence[_, _] ..., XMLPattern[\"tr\"], ___}] the odd rows. The other entries are patterns such as _, ___, Repeated, Except and PatternSequence over the children. Names in the list are bound as in a WL list pattern, where the first way the list matches binds them, and a name on the list, s : {...}, binds the List of element children. Child[pat1, pat2, pat3, ...] is Child[pat1, Child[pat2, pat3, ...]], so Child[a, b, c] matches each c that is a child of a b that is a child of an a. Each argument is a stage: an XMLPattern, another combinator, a CSS selector string, or alternatives of these. The first argument can also be XMLDocument[], the parent of the top-level elements of the tree, or alternatives that hold it. After Child or Descendant, a stage can also be a list of patterns for the parent's element children. A stage that is alternatives holding a combinator is each of them in turn, so Child[a, Descendant[b, c] | d] matches each c inside a b that is a child of an a, and each d that is a child of an a. Stages chain left to right, as in a CSS selector, so Descendant[a, Child[b, c]] and Child[Descendant[a, b], c] select the same elements. A condition on a stage can use the names bound in that stage. A condition on the whole combinator can use the names bound in all its stages.";
Adjacent::usage = "Adjacent[beforePat, afterPat] is a combinator for XMLCases, XMLFirstCase and XMLDeleteCases that matches elements that match afterPat and immediately follow a sibling that matches beforePat. Only elements count as siblings, not text. Adjacent[beforePat, afterPat] gives the same as Child[XMLDocument[] | XMLPattern[_], {___, beforePat, afterPat, ___}], so the top-level elements of a list are siblings. Adjacent[pat1, pat2, pat3, ...] is Adjacent[pat1, Adjacent[pat2, pat3, ...]], so Adjacent[a, b, c] matches each c that immediately follows a b that immediately follows an a. Each argument is a stage: an XMLPattern, another combinator, a CSS selector string, or alternatives of these. The first argument can also be XMLDocument[], the parent of the top-level elements of the tree, or alternatives that hold it. After Child or Descendant, a stage can also be a list of patterns for the parent's element children. A stage that is alternatives holding a combinator is each of them in turn, so Child[a, Descendant[b, c] | d] matches each c inside a b that is a child of an a, and each d that is a child of an a. Stages chain left to right, as in a CSS selector, so Descendant[a, Child[b, c]] and Child[Descendant[a, b], c] select the same elements. A condition on a stage can use the names bound in that stage. A condition on the whole combinator can use the names bound in all its stages.";
Sibling::usage = "Sibling[beforePat, afterPat] is a combinator for XMLCases, XMLFirstCase and XMLDeleteCases that matches elements that match afterPat and follow a sibling that matches beforePat, at any distance. Only elements count as siblings, not text. Each such element is given once. Sibling[beforePat, afterPat] gives the same as Child[XMLDocument[] | XMLPattern[_], {___, beforePat, ___, afterPat, ___}], so the top-level elements of a list are siblings. A name bound in beforePat, as used in a rule body, gives the first matching earlier sibling in document order. Sibling[pat1, pat2, pat3, ...] is Sibling[pat1, Sibling[pat2, pat3, ...]], so Sibling[a, b, c] matches each c that follows a b that follows an a. Each argument is a stage: an XMLPattern, another combinator, a CSS selector string, or alternatives of these. The first argument can also be XMLDocument[], the parent of the top-level elements of the tree, or alternatives that hold it. After Child or Descendant, a stage can also be a list of patterns for the parent's element children. A stage that is alternatives holding a combinator is each of them in turn, so Child[a, Descendant[b, c] | d] matches each c inside a b that is a child of an a, and each d that is a child of an a. Stages chain left to right, as in a CSS selector, so Descendant[a, Child[b, c]] and Child[Descendant[a, b], c] select the same elements. A condition on a stage can use the names bound in that stage. A condition on the whole combinator can use the names bound in all its stages.";
Descendant::usage = "Descendant[ancestorPat, descPat] is a combinator for XMLCases, XMLFirstCase and XMLDeleteCases that matches elements that match descPat and are nested at any depth inside an element that matches ancestorPat. Descendant[ancestorPat, {e1, e2, ...}] matches the list of patterns {e1, e2, ...} against the element children of each element that matches ancestorPat or lies inside one, one parent at a time, as Child does, so Descendant[XMLPattern[\"div\"], {XMLPattern[\"p\"], ___}] matches each p inside a div that is the first element child of its parent. Each such element is given once, however many of its ancestors match. A name bound in ancestorPat, as used in a rule body, gives the outermost matching ancestor. Descendant[pat1, pat2, pat3, ...] is Descendant[pat1, Descendant[pat2, pat3, ...]], so Descendant[a, b, c] matches each c inside a b inside an a. Each argument is a stage: an XMLPattern, another combinator, a CSS selector string, or alternatives of these. The first argument can also be XMLDocument[], the parent of the top-level elements of the tree, or alternatives that hold it. After Child or Descendant, a stage can also be a list of patterns for the parent's element children. A stage that is alternatives holding a combinator is each of them in turn, so Child[a, Descendant[b, c] | d] matches each c inside a b that is a child of an a, and each d that is a child of an a. Stages chain left to right, as in a CSS selector, so Descendant[a, Child[b, c]] and Child[Descendant[a, b], c] select the same elements. A condition on a stage can use the names bound in that stage. A condition on the whole combinator can use the names bound in all its stages.";
XMLDocument::usage = "XMLDocument[] is a pattern for the parent of the top-level elements of a tree, used as the first stage of a Child or Descendant combinator in XMLCases, XMLFirstCase and XMLDeleteCases. Child[XMLDocument[], pattern] gives the top-level elements that match pattern: the root element of an XMLObject, or the elements of a list. On a bare XMLElement, XMLDocument[] is a parent above it, so Child[XMLDocument[], XMLPattern[_], pattern] gives the children of the element that match pattern. Descendant[XMLDocument[], pattern] gives every element that matches pattern, as pattern alone does. In a list stage, Child[XMLDocument[] | XMLPattern[_], {...}] counts the top-level elements as the children of the document, so Child[XMLDocument[] | XMLPattern[_], {XMLPattern[\"html\"], ___}] matches the root element of a document. XMLDocument[] takes no arguments, and cannot be named, have a condition or test of its own, or be a later stage. The tree given is never a result.";
FromCSSSelector::usage = "FromCSSSelector[\"selector\"] gives the XML pattern that a CSS selector describes, for use in XMLCases, XMLFirstCase, XMLDeleteCases and XMLMatchQ, or as a stage of Child, Descendant, Adjacent or Sibling. A CSS selector string can also be given directly wherever these take a pattern, and means its translation. The selector is matched as written: letter case matters in tag names, attribute names and values, and attributes that the HTML importer adds, such as rowspan=\"1\", count as present. [foo~=\"x\"] becomes \"fooList\" -> \"x\", which needs a reading for foo in $AttributeReadings or in the \"AttributeReadings\" option of the function that runs the query.";
HTMLTextContent::usage ="HTMLTextContent[tree] gives the text of an XML tree: all the strings it contains, joined in document order. No whitespace is added or removed, so source indentation and the whitespace in <pre> are kept. tree can be an XMLElement, an XMLObject document, a list, or a string.";
HTMLInnerText::usage = "HTMLInnerText[tree] gives the readable text of an XML tree. Runs of whitespace are collapsed, block-level elements go on their own lines, <br> becomes a newline, <pre> content is kept as written, tags such as script and style are dropped, and the result is trimmed. How each element is treated depends only on its tag, as given by the built-in user-agent stylesheet. HTMLInnerText[tree, \"Roles\" -> rules] changes this, with rules of the form pattern -> role, where pattern is an XMLPattern or a CSS selector string and role is \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\" or \"Skip\". \"BlockSeparator\" -> sep sets the string inserted between blocks (default \"\\n\"). \"AttributeReadings\" -> readings adds readings to $AttributeReadings for this call. tree can be an XMLElement, an XMLObject document, a list, or a string.";
HTMLToNotebook::usage = "HTMLToNotebook[tree] converts an HTML or XML tree to a Notebook expression, which can be displayed or exported with Export to Markdown, PDF, RTF, etc. Block-level tags become cells, such as headings -> Title, Chapter, Section, etc., p -> Text, li -> Item, Subitem, etc., blockquote -> a framed quote, pre -> a Program cell, and table -> a Dataset or Grid, with its caption as a Text cell before it. Inline tags become boxes in the surrounding cell, such as b -> bold, i -> italic, code -> inline code, a -> a hyperlink and img -> its alt text, linked to its src. How each element is treated depends only on its tag, as given by the built-in user-agent stylesheet. HTMLToNotebook[tree, \"Roles\" -> rules] changes the role of elements, such as block or inline. \"Constructs\" -> rules changes what an element becomes: an inline style such as \"Bold\", a cell style, or a function that is applied to the element and gives a Cell or boxes. The left-hand side of each rule is an XMLPattern or a CSS selector string. \"AttributeReadings\" -> readings adds readings to $AttributeReadings for this call. tree can be an XMLElement, an XMLObject document, a list, or a string.";

(* === Messages === *)

CSSClass::obs = "CSSClass is obsolete. Match the class list with the \"classList\" key instead: XMLPattern[tag, \"classList\" -> \"cls\"] for .cls, or \"classList\" -> _?(FreeQ[\"cls\"]) for :not(.cls).";
XMLPattern::badtag = "The tag should be a string, a {namespace, name} pair, alternatives of these, or a pattern such as _. Got `1`.";
XMLPattern::nargs = "XMLPattern was given `1` arguments, but takes a tag and at most one attribute argument. Put several attribute constraints in one list: XMLPattern[tag, {c1, c2, ...}].";
XMLPattern::badattrs = "The attribute argument should be a key -> value rule, a key, or a list of these, optionally named (attrs : ...) or tested (...?test) as a whole. Got `1`.";
XMLPattern::badkey = "An attribute key should be a string, a {namespace, name} pair of strings, or alternatives of these. Got `1`. To test the keys, test the attributes as a whole: XMLPattern[tag, attrs_?test].";
XMLPattern::dupkey = "The attribute key `1` appears in more than one constraint, so the pattern can never match. Combine the constraints into one value pattern.";
XMLPattern::strpat = "`1` is a string pattern, and in an XMLPattern it does not match any string. Write _?(StringMatchQ[`1`]) instead.";
XMLCases::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of these. Got head `1`.";
XMLCases::badpat = "The second argument should be an XMLPattern, a Child, Descendant, Adjacent or Sibling combinator, a CSS selector string, alternatives of any of these, or a rule pattern -> rhs or pattern :> body with one of these. Each can have a condition (/;). An XMLPattern or alternatives of them can also be named or have a test (?), but a combinator, or alternatives that hold one, cannot. XMLDocument[] can only be the first stage of a combinator, alone or in alternatives, and cannot be named or have a condition or test of its own. Got `1`.";
XMLCases::stages = "A combinator such as Child or Descendant needs at least two stages, as in Descendant[a, b] or Descendant[a, b, c]. Got `1`.";
XMLCases::testcombinator = "A test (?) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Put it on the stage it tests, as in Child[a, b?f]. Got `1`.";
XMLFirstCase::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of these. Got head `1`.";
XMLFirstCase::badpat = "The second argument should be an XMLPattern, a Child, Descendant, Adjacent or Sibling combinator, a CSS selector string, alternatives of any of these, or a rule pattern -> rhs or pattern :> body with one of these. Each can have a condition (/;). An XMLPattern or alternatives of them can also be named or have a test (?), but a combinator, or alternatives that hold one, cannot. XMLDocument[] can only be the first stage of a combinator, alone or in alternatives, and cannot be named or have a condition or test of its own. Got `1`.";
XMLFirstCase::stages = "A combinator such as Child or Descendant needs at least two stages, as in Descendant[a, b] or Descendant[a, b, c]. Got `1`.";
XMLFirstCase::testcombinator = "A test (?) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Put it on the stage it tests, as in Child[a, b?f]. Got `1`.";
XMLDeleteCases::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of these. Got head `1`.";
XMLDeleteCases::badpat = "The second argument should be an XMLPattern, a Child, Descendant, Adjacent or Sibling combinator, a CSS selector string, or alternatives of any of these. Each can have a condition (/;). An XMLPattern or alternatives of them can also be named or have a test (?), but a combinator, or alternatives that hold one, cannot. XMLDocument[] can only be the first stage of a combinator, alone or in alternatives, and cannot be named or have a condition or test of its own. A rule, whether pattern -> rhs or pattern :> body, cannot be used. Got `1`.";
XMLDeleteCases::stages = "A combinator such as Child or Descendant needs at least two stages, as in Descendant[a, b] or Descendant[a, b, c]. Got `1`.";
XMLDeleteCases::testcombinator = "A test (?) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Put it on the stage it tests, as in Child[a, b?f]. Got `1`.";
XMLMatchQ::badpat = "The pattern should be an XMLPattern, alternatives of them, or either with a condition pat /; test or a test pat?f, or a CSS selector string that describes one element. Got `1`.";
XMLMatchQ::stages = "`1` is a combinator with fewer than two stages. A combinator needs at least two, but XMLMatchQ tests a lone element and cannot use one; use XMLCases or XMLFirstCase to search a tree with it.";
XMLMatchQ::condcombinator = "A condition (/;) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Got `1`.";
XMLMatchQ::testcombinator = "A test (?) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Put it on the stage it tests, as in Child[a, b?f]. Got `1`.";
$AttributeReadings::badkey = "Each key in the readings should be an attribute name given as a string. Got `1`.";
$AttributeReadings::notassoc = "$AttributeReadings and the \"AttributeReadings\" option should be an Association from attribute names to readings. Got `1`.";
$AttributeReadings::badentry = "The reading for `1` should be an Association with any of the fields Method, Delimiters, \"TrimWhitespace\" and \"ListKey\". Got `2`.";
$AttributeReadings::badfield = "The reading for `1` has the unknown field `2`. The fields of a reading are Method, Delimiters, \"TrimWhitespace\" and \"ListKey\".";
$AttributeReadings::badmethod = "The reading for `1` has Method `2`. Method should be \"SpaceSeparated\" or \"CommaSeparated\".";
$AttributeReadings::badvalue = "The reading for `1` has `2` -> `3`. Delimiters should be a string pattern, \"TrimWhitespace\" should be True or False, and \"ListKey\" should be a string. Any of them can also be Automatic.";
$AttributeReadings::duplistkey = "More than one reading has the list key `1`. Give each reading a different \"ListKey\".";
$AttributeReadings::listkeyisreading = "The list key `1` is also an attribute with a reading, so `1` in an XMLPattern would be ambiguous. Choose a different \"ListKey\".";
XMLMatchQ::combinator = "`1` relates an element to its parent or siblings, which a lone element does not have. Use XMLCases or XMLFirstCase to search a tree with it.";
(* A list of patterns for an element's children (ADR 0016), refused where it
   cannot stand, with the reason. *)
Scan[Function[h,
    MessageName[h, "liststage"] = "`1` is a list of patterns for an element's children. `2`";
    MessageName[h, "listentry"] = "`1` cannot be an entry in a list of patterns for an element's children. `2`"],
  {XMLCases, XMLFirstCase, XMLDeleteCases, XMLMatchQ, HTMLInnerText, HTMLToNotebook}];
FromCSSSelector::invalid = "`1` is not a valid CSS selector: `2`.";
FromCSSSelector::unsupported = "`1` is valid CSS, but `2` cannot be translated to an XML pattern. `3`";
FromCSSSelector::impossible = "`2` in `1` depends on a browser, such as user input, layout or the page's URL, and cannot be matched in a static document. `3`";
XMLDeleteCases::root = "The root element of an XMLObject cannot be deleted; it was kept.";
HTMLTextContent::badtree ="The first argument should be an XMLObject, an XMLElement, a string, or a list of these. Got head `1`.";
HTMLClassList::notelement = "The argument should be a single XMLElement. Got head `1`. For a list of elements, use HTMLClassList /@ elements.";
HTMLInnerText::badtree = "The first argument should be an XMLObject, an XMLElement, a string, or a list of these. Got head `1`.";
HTMLInnerText::badrole = "A \"Roles\" rule gave `1`, which is not \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\" or \"Skip\". The element gets its role from the built-in user-agent stylesheet instead.";
HTMLInnerText::badpat = "The left-hand side of a rule should be an XMLPattern, alternatives of them, or either with a condition pat /; test or a test pat?f, or a CSS selector string that describes one element. Got `1`.";
HTMLInnerText::stages = "`1` is a combinator with fewer than two stages. A combinator needs at least two, but a rule is tried on one element at a time and cannot use one; use an XMLPattern or alternatives of them.";
HTMLInnerText::notrule = "Each \"Roles\" entry should be a rule pattern -> value or pattern :> value. Got `1`.";
HTMLInnerText::condcombinator = "A condition (/;) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Got `1`.";
HTMLInnerText::testcombinator = "A test (?) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Put it on the stage it tests, as in Child[a, b?f]. Got `1`.";
HTMLToNotebook::badtree = "The first argument should be an XMLObject, an XMLElement, a string, or a list of these. Got head `1`.";
HTMLToNotebook::badrole = "A \"Roles\" rule gave `1`, which is not \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\" or \"Skip\". The element gets its role from the built-in user-agent stylesheet instead.";
HTMLToNotebook::badpat = "The left-hand side of a rule should be an XMLPattern, alternatives of them, or either with a condition pat /; test or a test pat?f, or a CSS selector string that describes one element. Got `1`.";
HTMLToNotebook::stages = "`1` is a combinator with fewer than two stages. A combinator needs at least two, but a rule is tried on one element at a time and cannot use one; use an XMLPattern or alternatives of them.";
HTMLToNotebook::notrule = "Each \"Roles\" or \"Constructs\" entry should be a rule pattern -> value or pattern :> value. Got `1`.";
HTMLToNotebook::condcombinator = "A condition (/;) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Got `1`.";
HTMLToNotebook::testcombinator = "A test (?) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Put it on the stage it tests, as in Child[a, b?f]. Got `1`.";

Begin["`Private`"];

(* =========================================================== *)
(* Validation helpers                                           *)
(* =========================================================== *)

(* Valid tag: a string, a {namespace, name} pair, or any ordinary pattern matched
   against the element's tag \[LongDash] Alternatives, Blank(Sequence), a named Pattern,
   or a predicate-bearing PatternTest (_?f) / Condition (t_ /; test). *)
validTagQ[_String] := True;
validTagQ[{_, _}] := True;
validTagQ[_Alternatives] := True;
validTagQ[_Blank] := True;
validTagQ[_BlankSequence] := True;
validTagQ[_Pattern] := True;
validTagQ[_PatternTest] := True;
validTagQ[_Condition] := True;
validTagQ[_] := False;

(* A literal attribute key: a plain name, an imported {namespace, name} pair (WL
   imports a namespaced attribute such as xlink:href with a two-element list key
   {namespaceURI, localName}), or Alternatives of those. *)
literalKeyQ[_String] := True;
literalKeyQ[{_String, _String}] := True;
literalKeyQ[Verbatim[Alternatives][ks__]] := AllTrue[{ks}, literalKeyQ];
literalKeyQ[_] := False;

keyLiterals[Verbatim[Alternatives][ks__]] := Join @@ (keyLiterals /@ {ks});
keyLiterals[k_] := {k};

(* The four combinator heads, each a link of a chain. *)
$links = Child | Descendant | Adjacent | Sibling;

combinatorQ[$links[___]] := True;
combinatorQ[_] := False;

(* A name, a Condition or a test around a pattern never changes what it is. *)
patternBase[Verbatim[Pattern][_, x_]] := patternBase[x];
patternBase[Verbatim[Condition][x_, _]] := patternBase[x];
patternBase[Verbatim[PatternTest][x_, _]] := patternBase[x];
patternBase[x_] := x;

(* Valid tree for XMLCases *)
validTreeQ[XMLObject["Document"][_, _XMLElement, _]] := True;
validTreeQ[_XMLElement] := True;
validTreeQ[expr_List] := AllTrue[expr, MatchQ[#, _XMLElement | _String] &];
validTreeQ[_] := False;

(* Input surface for the text extractors: the selector surface, plus a bare
   string (text-of-a-string is meaningful, unlike for the selectors). *)
validTextInputQ[_String] := True;
validTextInputQ[t_] := validTreeQ[t];

(* The bare string patterns written where a pattern is matched. A StringExpression
   inside a PatternTest's test or a Condition's test is an argument to a string
   function, not a pattern, and neither is anything under Verbatim. *)
SetAttributes[barePatterns, HoldAllComplete];
barePatterns[s_StringExpression] := {s};
barePatterns[Verbatim[PatternTest][p_, _]] := barePatterns[p];
barePatterns[Verbatim[Condition][p_, _]] := barePatterns[p];
barePatterns[Verbatim[Verbatim][___]] := {};
barePatterns[_[args___]] := Join @@ (barePatterns /@ Unevaluated[{args}]);
barePatterns[_] := {};

(* =========================================================== *)
(* HTMLWhitespace                                               *)
(* The delimiter of the space-separated microsyntax.            *)
(* =========================================================== *)

(* A run, not one character, mirroring Whitespace rather than
   WhitespaceCharacter: splitting "a  b" on it gives no phantom empty token. *)
HTMLWhitespace = (" " | "\t" | "\n" | "\f" | "\r") ..;

(* =========================================================== *)
(* HTMLClassList                                                *)
(* The extraction form of the class reading. Shares classList   *)
(* with the class reading's split, so extracting and matching   *)
(* agree on the same element.                                   *)
(* =========================================================== *)

(* The class list: the tokens of the class attribute, split on HTMLWhitespace
   as a browser splits them. Splitting gives the empty list for "", for
   whitespace-only values, and (via the "" default in classValue) for a missing
   attribute \[LongDash] the three ways an element ends up carrying no classes, which
   must be indistinguishable here. *)
classList[val_String] := StringSplit[val, HTMLWhitespace];

(* Absent class reads as "", the same value a present-but-empty class="" carries. *)
classValue[attrs_] := Lookup[attrs, "class", ""];

HTMLClassList[XMLElement[_, attrs_List, _]] := classList[classValue[attrs]];

(* A list, a document or a bare string is refused, not interpreted: a list is a
   forest elsewhere in the paclet (one answer), where concatenated class lists
   mean nothing, and a bare string is a text node, not an attribute value. *)
HTMLClassList[other_] :=
  (Message[HTMLClassList::notelement, Head[other]]; $Failed);

HTMLClassList[args___] /; (countMessage[HTMLClassList, {args}, {1, 1}]; False) := Null;

(* =========================================================== *)
(* CSSClass                                                     *)
(* Obsolete (ADR 0011): the class list is the "classList" key.  *)
(* =========================================================== *)

CSSClass[___] := (Message[CSSClass::obs]; $Failed);

(* =========================================================== *)
(* Readings (ADR 0012)                                          *)
(* A reading fixes a microsyntax to a literal attribute key and *)
(* names the list key an XML pattern reaches its token list by. *)
(* =========================================================== *)

$AttributeReadings = <|
  "class" -> <|Method -> "SpaceSeparated", Delimiters -> Automatic,
    "TrimWhitespace" -> Automatic, "ListKey" -> Automatic|>|>;

(* Method is shorthand defining the other two fields. *)
$methodDefaults = <|
  "SpaceSeparated" -> <|Delimiters -> HTMLWhitespace, "TrimWhitespace" -> False|>,
  "CommaSeparated" -> <|Delimiters -> ",", "TrimWhitespace" -> True|>|>;

splitter[delim_, False] := Function[v, StringSplit[v, delim]];
(* Trimming strips HTML whitespace, as the comma microsyntax does: a no-break
   space is part of a token. *)
splitter[delim_, True] := Function[v, StringTrim[#, HTMLWhitespace] & /@ StringSplit[v, delim]];

(* A readings table resolved for the compiler: list key -> {raw key, split}. *)
resolveReading[key_String -> spec_Association] :=
  With[{defaults = $methodDefaults[Lookup[spec, Method, "SpaceSeparated"]]},
    listKeyOf[key, spec] ->
      {key, splitter[
        Replace[Lookup[spec, Delimiters, Automatic], Automatic -> defaults[Delimiters]],
        Replace[Lookup[spec, "TrimWhitespace", Automatic], Automatic -> defaults["TrimWhitespace"]]]}];

resolveReadings[readings_Association] := Association[resolveReading /@ Normal[readings]];

(* The readings table in force, $AttributeReadings, resolved. A table that
   fails validation has said why, and gives $Failed. *)
readingsInForce[] :=
  Catch[resolveReadings[validReadings[validTable[$AttributeReadings]]], $refusal];

(* A consumer's AttributeReadings option is shorthand for a Block of the global
   over the whole call (#34), so a nested XML* call in a condition or a rule
   body, and any function it calls, sees it. It adds to the global; an entry
   for a key the global already has replaces that key's entry whole. Only the
   two tables' shapes are checked here, as Join needs them; each query compiled
   in the call validates the joined table. *)
SetAttributes[withReadings, HoldRest];
withReadings[opt_, call_] :=
  Replace[Catch[Join @@ (validTable /@ {$AttributeReadings, opt}), $refusal], {
    $Failed -> $Failed,
    t_ :> Block[{$AttributeReadings = t}, call]}];

(* A Block of $AttributeReadings, the option's or a caller's, hides the
   symbol's message texts too, so a refusal gives its text back for the
   Block's duration. *)
$readingMessages = AssociationMap[MessageName[$AttributeReadings, #] &,
  {"notassoc", "badkey", "badentry", "badfield", "badmethod", "badvalue", "duplistkey", "listkeyisreading"}];

refuseReading[tag_String, args___] := (
  If[!StringQ[MessageName[$AttributeReadings, tag]],
    MessageName[$AttributeReadings, tag] = $readingMessages[tag]];
  refuse[MessageName[$AttributeReadings, tag], args]);

validTable[t_Association] := t;
validTable[t_] := refuseReading["notassoc", t];

validReadings[readings_] :=
  (KeyValueMap[validReading, readings]; validListKeys[readings]; readings);

listKeyOf[key_, spec_] := Replace[Lookup[spec, "ListKey", Automatic], Automatic -> key <> "List"];

validListKeys[readings_] :=
  With[{listKeys = KeyValueMap[listKeyOf, readings]},
    Replace[Select[Tally[listKeys], Last[#] > 1 &],
      {{k_, _}, ___} :> refuseReading["duplistkey", k]];
    Replace[Intersection[listKeys, Keys[readings]],
      {k_, ___} :> refuseReading["listkeyisreading", k]]];

$readingFields = {Method, Delimiters, "TrimWhitespace", "ListKey"};

validReading[key_, _] /; !StringQ[key] := refuseReading["badkey", key];
validReading[key_, spec_] /; !AssociationQ[spec] := refuseReading["badentry", key, spec];
validReading[key_, spec_] := (
  Replace[Complement[Keys[spec], $readingFields],
    {f_, ___} :> refuseReading["badfield", key, f]];
  If[!KeyExistsQ[$methodDefaults, Lookup[spec, Method, "SpaceSeparated"]],
    refuseReading["badmethod", key, spec[Method]]];
  KeyValueMap[
    If[!validFieldQ[#1, #2], refuseReading["badvalue", key, #1, #2]] &,
    KeyDrop[spec, Method]]);

(* Whether a value is a string pattern is the string functions' own judgement. *)
validFieldQ[Delimiters, d_] := d === Automatic || Quiet[Check[StringFreeQ["", d]; True, False]];
validFieldQ["TrimWhitespace", t_] := MatchQ[t, Automatic | True | False];
validFieldQ["ListKey", k_] := MatchQ[k, Automatic | _String];

(* =========================================================== *)
(* Materialisation (ADR 0012)                                   *)
(* A query naming a list key runs on a tree whose elements each *)
(* carry the token list beside the raw value, under the private *)
(* key head tok (inert: no definitions). strip is the exact     *)
(* inverse: strip[materialise[e, ...]] === e.                   *)
(* =========================================================== *)

(* Only the distinct raw values on the tree are split: a page has a handful of
   distinct class strings across thousands of elements. An absent attribute
   reads as {}, as a browser's classList does. *)
tokenMap[tree_, {key_, split_}, level_] :=
  With[{vals = DeleteDuplicates @
      Cases[tree, XMLElement[_, a_List, _] :> Lookup[a, key, Nothing], level]},
    AssociationThread[vals, split /@ vals]];

(* One pass per list key: nearly every query names one. *)
materialise[tree_, readings_List, level_ : {0, Infinity}] :=
  Fold[materialiseKey[#1, #2, level] &, tree, readings];

materialiseKey[tree_, reading : {key_, _}, level_] :=
  With[{map = tokenMap[tree, reading, level]},
    Replace[tree,
      XMLElement[t_, a_List, c_] :>
        XMLElement[t, Append[a, tok[key] -> Lookup[map, Lookup[a, key, None], {}]], c],
      level]];

(* An element materialised when it is asked for, the distinct raw values on
   tree split once, up front: for rules tried on one element at a time. *)
materialiser[_, {}] := Identity;
materialiser[tree_, readings_] :=
  With[{maps = {First[#], tokenMap[tree, #, {0, Infinity}]} & /@ readings},
    attachTokens[maps, #] &];

attachTokens[maps_, XMLElement[t_, a_List, c_]] :=
  XMLElement[t, Join[a, Function[{key, map}, tok[key] -> Lookup[map, Lookup[a, key, None], {}]] @@@ maps], c];

stripAttrs[a_] := DeleteCases[a, _tok -> _];

strip[x_] :=
  Replace[x, XMLElement[t_, a_List, c_] :> XMLElement[t, stripAttrs[a], c], {0, Infinity}];

(* A name on a sequence of children binds a Sequence. *)
stripAll[xs___] := Sequence @@ (strip /@ {xs});

(* =========================================================== *)
(* The query compiler                                           *)
(*                                                              *)
(* compileQuery[query, head] -> the query's normal form under  *)
(* the readings in force: an Association every decision about  *)
(* the query reads:                                             *)
(*   "Stages"     the compiled element patterns, in chain order, *)
(*                and list stages, listStage[...] (see List      *)
(*                stages), which only follow a Child or          *)
(*                Descendant link                                *)
(*   "Links"      the combinator heads between them ({} for a   *)
(*                plain query, which has one stage)             *)
(*   "Conditions" {{i, j}, Hold[test]} for each Condition on a  *)
(*                combinator, over its stages i to j, innermost *)
(*                first                                         *)
(*   "Body"       the rule's held body, or None                 *)
(*   "Readings"   the readings of the list keys it names ({}    *)
(*                when it names none, in which case it runs on  *)
(*                the tree as it is)                            *)
(*   "Head"       the consumer, whose messages refusals use     *)
(*   "Query"      the query as written, for messages            *)
(*   "ContextEntries" the normal forms of the context combinator *)
(*                entries of its list stages, by key            *)
(*   "Recognition" whether shapes were recognised when it was    *)
(*                compiled ($recogniseShapes)                    *)
(* Each list stage in "Stages" also carries how it runs, its     *)
(* "Method" (see List stage methods): a recognised shape with    *)
(* its parameters, or the general matcher with its rule. The     *)
(* runners read it and do not inspect the list's pattern.        *)
(* How the rest runs is decided once too, and the runners read  *)
(* it (see withPlan); the two-step match (solvable) is applied  *)
(* here and never by a runner. A plain query, one stage and no  *)
(* link, has                                                    *)
(*   "Plain"      the pattern or rule it runs                    *)
(* and a chain, each alternative of a query of "Alternatives"   *)
(* and each normal form in "ContextEntries" has                  *)
(*   "Chain"      the stages and links, alternating, as the      *)
(*                chain runner reads them                        *)
(*   "StagesDecide" whether the stages' own matches decide a     *)
(*                tuple (see Chains)                             *)
(*   "TupleTest"  the test a tuple of sites passes, or None when *)
(*                the stages decide                              *)
(*   "TupleRule"  the rule a tuple of elements is given to, or   *)
(*                None when there is no body                     *)
(* Refusals message under XMLPattern (an XML pattern's own      *)
(* shape) or under head and give $Failed. Which query shapes an *)
(* operation can run is the operation's to check, on the normal *)
(* form (see Running a compiled query).                         *)
(*                                                              *)
(* When a list key is named, every binding that can see an      *)
(* element's attributes \[LongDash] an element binding e : XMLPattern[...],  *)
(* or a name or test on the attribute argument \[LongDash] is renamed to a   *)
(* fresh symbol, and each place that can see the name (a rule   *)
(* body, a Condition's test) is wrapped in                      *)
(* With[{e = strip[e$]}, ...], so it sees the original element. *)
(* A query is compiled once to learn its list keys and, only if *)
(* it names one, again with the renaming on.                    *)
(* =========================================================== *)

compileQuery[q_, head_] := compileWith[q, head, readingsInForce[]];

(* Whether the compiler recognises shapes (ADR 0020). Block it to False to run
   every list stage on the general matcher, as WL's matcher runs the pattern as
   written, to check a recognised method against it. *)
$recogniseShapes = True;

(* With the readings table resolved, for a caller that compiles several queries
   against one table. *)
compileWith[_, _, $Failed] := $Failed;
compileWith[q_, head_, readings_Association] :=
  Catch[
    Module[{query, keys, contexts},
      {query, keys, contexts} = compilePass[q, head, readings, False];
      If[keys =!= {}, {query, contexts} = Delete[compilePass[q, head, readings, True], 2]];
      Join[withPlan[withMethods[query]], <|"Readings" -> Lookup[readings, keys], "Head" -> head, "Query" -> q,
        "ContextEntries" -> chainPlan @* withMethods /@ contexts, "Recognition" -> $recogniseShapes|>]],
    $refusal];

compilePass[q_, head_, readings_, mat_] :=
  Block[{$head = head, $readings = readings, $mat = mat, $fresh = <||>, $listSources = <||>,
      $atStart = True, $firstOfLink = False},
    With[{r = Reap[First @ Reap[cQuery[q], $bindTag], {$listKeyTag, $contextTag}]},
      {First[r], Union @@ r[[2, 1]], contextEntries[First[r], Join @@ r[[2, 2]]]}]];

(* How a normal form runs, decided once (see the header): a plain query's
   pattern or rule, or for a chain, each alternative of one and each context
   entry, its chain, tuple test and tuple rule, with the two-step match
   (solvable) applied wherever it is needed. *)
withPlan[q_] /; unionQ[q] := MapAt[chainPlan, q, {Key["Alternatives"], All}];
withPlan[q_] /; chainQ[q] := chainPlan[q];
withPlan[q_] := Append[q, "Plain" -> plainQuery[q]];

chainPlan[q_] :=
  Join[q, <|"Chain" -> chainOf[q], "StagesDecide" -> stagesDecideQ[q], "TupleTest" -> tupleTest[q],
    "TupleRule" -> If[q["Body"] === None, None, tupleRule[q]]|>];

(* Held, since a MessageName evaluates to its text. *)
SetAttributes[refuse, HoldFirst];
refuse[msg_, args___] := (Message[msg, args]; Throw[$Failed, $refusal]);
(* An upstream failure (CSSClass::obs) has already said what went wrong. *)
refuseQuietly[] := Throw[$Failed, $refusal];

(* MessageName holds its first argument, so the consumer head is injected. *)
refuseAtHead[tag_, args___] := With[{h = $head}, refuse[MessageName[h, tag], args]];
badpat[q_] := refuseAtHead["badpat", q];

(* ---- Queries: a rule over a pattern, or a pattern ---- *)

cQuery[r_RuleDelayed] := ruleQuery[r[[1]], Extract[r, {2}, Hold]];
(* A Rule's right-hand side was evaluated when the query was given, as in
   Cases, and its value is the body. A Condition in the value is part of it,
   not a test on the match, as in Cases. *)
cQuery[r : Verbatim[Rule][_, _]] := ruleQuery[r[[1]], literalBody[Extract[r, {2}, Hold]]];
cQuery[q_] := normalForm[cStage[q], None];

ruleQuery[lhs_, body_Hold] :=
  Module[{stages, binds},
    {stages, binds} = reapBinds[cStage[lhs]];
    normalForm[stages, wrapBinds[binds, body]]];

(* Identity keeps a Condition from being the top of the body, where it would
   be a test. *)
literalBody[Hold[c_Condition]] := Hold[Identity[c]];
literalBody[body_Hold] := body;

(* A list stage needs a parent: as the whole query or as a first stage it has
   none. *)
normalForm[chain[{ls_listStage, rest___}, _, _], _] :=
  refuseList[If[{rest} === {}, "query", "first"], ls];
normalForm[chain[stages_, links_, conditions_], body_] :=
  <|"Stages" -> stages, "Links" -> links, "Conditions" -> conditions, "Body" -> body|>;
(* Alternatives holding a combinator are the list of their chains, each with
   the body in which the names the query binds and it does not are Sequence[]
   (ADR 0015). *)
normalForm[union[cs_], body_] :=
  <|"Alternatives" -> perAlternative[cs, body, normalForm], "Body" -> body|>;

(* A combinator's stages are element patterns or combinators, compiled to
   chain[stages, links, conditions]. A Condition on a combinator sees the names
   of all its stages, and covers them. L[s1, s2, ..., sn] is the right-nested
   chain L[s1, L[s2, ..., sn]]; one stage or none is refused. *)
(* A string is a CSS selector, and means its translation (ADR 0017): one that
   gives a combinator is spliced into the chain, as any combinator stage is. *)
cStage[s_String] := cStage[stageTranslation[s]];
cStage[c : Verbatim[Condition][_String, _]] := cStage[conditionWith[stageTranslation[c[[1]]], Extract[c, {2}, Hold]]];

(* After the start of a chain no stage is the document, so a translation that
   starts with any parent, the document or an element, starts with an element;
   one that needs the document, as :root does, cannot stand there. *)
stageTranslation[s_] :=
  With[{t = cssPattern[s]},
    If[$atStart, t,
      Replace[t /. Verbatim[XMLDocument[] | XMLPattern[_]] -> XMLPattern[_], u_ /; documentQ[u] :> badpat[s]]]];
(* A list, named, conditioned or tested, is a list stage (ADR 0016), one chain
   for each alternative of its selected entry. A name on alternatives of lists
   is the name on each. *)
cStage[l_] /; listFormQ[l] := Block[{$atStart = False}, toUnion[listChains[l]]];
cStage[Verbatim[Pattern][s_Symbol, alts_Alternatives]] /; AllTrue[List @@ alts, listFormQ] :=
  cStage[Alternatives @@ (namedPattern[s, #] & /@ List @@ alts)];
(* The document can be only the first stage of a chain (ADR 0018): $atStart
   while a stage at the start of the query is compiled, $firstOfLink while it is the
   first argument of a combinator. *)
cStage[(h : $links)[a_, b_]] := joinChains[Block[{$firstOfLink = True}, cStage[a]], h, Block[{$atStart = False}, cStage[b]]];
cStage[(h : $links)[a_, b_, rest__]] := cStage[h[a, h[b, rest]]];
cStage[q : $links[RepeatedNull[_, 1]]] := refuseAtHead["stages", q];
cStage[c_Condition] /; multiStageQ[patternBase[c]] := conditioned[cStage, c, coverChain];
(* A test on a combinator would only restate a test on its last stage, so it is
   refused until a CSS selector string can be a combinator (ADR 0014). *)
cStage[t : Verbatim[PatternTest][x_, _]] /; multiStageQ[patternBase[x]] := refuseAtHead["testcombinator", t];
(* Alternatives holding a combinator are union[{chain, ...}], one chain per
   alternative, in written order (ADR 0015). Alternatives of element patterns
   stay one stage. *)
cStage[alts_Alternatives] /; AnyTrue[List @@ alts, multiStageQ] := toUnion[Join @@ (chainsOf[cStage[#]] & /@ List @@ alts)];
cStage[q_] := chain[{cElem[q]}, {}, {}];

chainsOf[union[cs_]] := cs;
chainsOf[c_chain] := {c};

toUnion[{c_}] := c;
toUnion[cs_] := union[cs];

(* A list stage lists the children of the element before it, so a sibling link
   cannot lead to one. *)
joinChains[_chain, Adjacent | Sibling, chain[{ls_listStage, ___}, _, _]] := refuseList["sibling", ls];
joinChains[chain[s1_, l1_, c1_], link_, chain[s2_, l2_, c2_]] :=
  chain[Join[s1, s2], Join[l1, {link}, l2],
    Join[c1, Replace[c2, {span_, test_} :> {span + Length[s1], test}, {1}]]];
(* A stage that is alternatives distributes: the chains of the product, the
   leftmost alternative most significant. *)
joinChains[a_, link_, b_] :=
  toUnion[Flatten[Outer[joinChains[#1, link, #2] &, chainsOf[a], chainsOf[b], 1]]];

coverChain[chain[s_, l_, c_], test_] := chain[s, l, Append[c, {{1, Length[s]}, test}]];
(* A Condition on alternatives covers each of their chains, and a name bound
   only in another alternative is Sequence[] in it, as in WL. *)
coverChain[union[cs_], test_] := union[perAlternative[cs, test, coverChain]];

(* f[chain, held] for each chain, with the names the other chains bind and it
   does not replaced by Sequence[] in held. *)
perAlternative[cs_, held_, f_] :=
  With[{names = unionNames[cs]}, f[#, unboundEmpty[held, Complement[names, chainNames[#]]]] & /@ cs];

(* The names a chain's stages bind, after any renaming, each Hold[name]. *)
chainNames[chain[s_, _, _]] := Union @@ (stageNames /@ s);
unionNames[cs_] := Union @@ (chainNames /@ cs);

(* Held code with each of names replaced by Sequence[]. A body or test that is
   only such a name would become Hold[], so it is kept as one expression,
   Sequence @@ {}, which evaluates to Sequence[]. *)
unboundEmpty[held_, {}] := held;
unboundEmpty[None, _] := None;
unboundEmpty[held_, names_] :=
  Replace[held /. Replace[names, Hold[n_] :> (HoldPattern[n] :> Sequence[]), {1}], Hold[] -> Hold[Sequence @@ {}]];

(* ---- Element patterns ---- *)

cElem[XMLPattern[args___]] := cXMLPattern[{args}];
(* The document above the top elements (ADR 0018), featureless. A chain site
   {0} stands for it, where the tree has its head, which this matches. *)
cElem[XMLDocument[]] /; documentAllowedQ[] := $documentStage;
documentAllowedQ[] := $atStart && $firstOfLink;
$documentStage = List | XMLElement | XMLObject["Document"];
documentQ[p_] := !FreeQ[p, XMLDocument];
(* A string that gives a combinator is not an element pattern, and is named as
   written. *)
cElem[s_String] := With[{t = cssPattern[s]}, If[multiStageQ[t], badpat[s], cElem[t]]];
(* An XML pattern of several stages: a combinator or alternatives holding one,
   with any name, Condition or test, or a CSS selector string that gives one. *)
multiStageQ[s_String] := multiStageQ[cssPattern[s]];
multiStageQ[p_] :=
  With[{b = patternBase[p]}, combinatorQ[b] || ListQ[b] || MatchQ[b, _Alternatives] && AnyTrue[List @@ b, multiStageQ]];
(* A combinator is not an element pattern; the whole Alternatives is named. *)
cElem[alts_Alternatives] /; AnyTrue[List @@ alts, multiStageQ] := badpat[alts];
cElem[alts_Alternatives] /; !documentAllowedQ[] && documentQ[alts] := badpat[alts];
cElem[alts_Alternatives] := Alternatives @@ (cElem /@ List @@ alts);
(* A named combinator, or named alternatives holding one, would bind a Sequence
   of elements, which says nothing of how they relate (ADR 0015). *)
cElem[Verbatim[Pattern][s_Symbol, p_]] :=
  If[multiStageQ[p] || documentQ[p], badpat[namedPattern[s, p]], bindAs[s, cElem[p], strip]];
(* The document has no element for a name, a Condition or a test to see. *)
cElem[c_Condition] := If[documentQ[patternBase[c]], badpat[c], conditioned[cElem, c, conditionWith]];
(* The same refusal, for a tested combinator inside Alternatives or a name. *)
cElem[t : Verbatim[PatternTest][x_, _]] /; multiStageQ[patternBase[x]] := refuseAtHead["testcombinator", t];
(* pat?f is n : pat /; f[n]: f sees the original element, as a name does. *)
cElem[t : Verbatim[PatternTest][p_, test_]] /; documentQ[p] := badpat[t];
cElem[Verbatim[PatternTest][p_, test_]] :=
  With[{c = cElem[p]}, If[$mat, PatternTest[c, Function[e, test[strip[e]]]], PatternTest[c, test]]];
(* A plain XMLElement pattern is already what the consumers run. *)
cElem[x_XMLElement] := x;
cElem[l_List] := refuseEntry["list", l];
cElem[q_] := badpat[q];

(* ---- List stages (ADR 0016) ---- *)

(* A list stage is listStage[a], a holding:
     "Id"      the key of the list as written, for messages
     "Pattern" the compiled list, with the user's names, Conditions and tests
     "Index"   the name of the entries before the selected one, matched as one
               PatternSequence: the selected child's index is its length + 1
     "Checks"  {id, mark} for each context combinator entry: the rest of its
               chain is run from the child whose index is Length[{mark}] + 1
     "Parent", "At"  the names of the parent's position and the index in the
               tuple pattern
   In a tuple the stage is listSlot[parent, index, children], the parent's
   element children; its site is the selected child's. *)
listFormQ[p_] := ListQ[patternBase[p]];

(* A refusal names the list or the entry as written. *)
refuseList[reason_, ls_listStage] := refuseList[reason, $listSources[ls[[1, "Id"]]]];
refuseList[reason_, l_] := refuseAtHead["liststage", l, $listReasons[reason]];
refuseEntry[reason_, e_] := refuseAtHead["listentry", e, $listReasons[reason]];

stageNames[listStage[a_]] := namesIn[a["Pattern"]];
stageNames[s_] := namesIn[s];

$listReasons = <|
  "query" -> "It can only follow Child or Descendant, as in Child[XMLPattern[_], {XMLPattern[\"li\"], ___}], and is not a pattern on its own. For alternatives, use p1 | p2.",
  "first" -> "It can only follow Child or Descendant, as in Child[XMLPattern[_], {XMLPattern[\"li\"], ___}], and cannot be the first stage, which has no parent whose children it would list.",
  "sibling" -> "It can only follow Child or Descendant, not Adjacent or Sibling.",
  "noentry" -> "It needs an entry that is an XML pattern, which selects the child in its place, as XMLPattern[_] does in {___, XMLPattern[_]}. Entries such as _, ___, Repeated and Except only describe the other children.",
  "list" -> "An entry is an XML pattern, a combinator, or a pattern such as _, ___, Repeated, Except or PatternSequence over these, but not a list.",
  "element" -> "An entry is an XML pattern, a combinator, or a pattern such as _, ___, Repeated, Except or PatternSequence over these. Write an element pattern as XMLPattern[tag, attrs].",
  "entry" -> "An entry is an XML pattern, a combinator, or a pattern such as _, ___, Repeated, Except or PatternSequence over these.",
  "firstlist" -> "A combinator in a list stands for its first stage, which is a child of the parent, so its first stage cannot be a list.",
  "contextalternatives" -> "Alternatives that hold a combinator can be the last XML pattern in the list, but not an entry before it.",
  "contextname" -> "A combinator before the last XML pattern in the list is a test below or beside that child, and a name bound in its later stages cannot be used elsewhere in the pattern."|>;

(* The selected entry is the last top-level entry that is an XML pattern. *)
xmlEntryQ[e_] :=
  With[{b = patternBase[e]},
    MatchQ[b, _XMLPattern | _String] || combinatorQ[b] || MatchQ[b, _Alternatives] && AllTrue[List @@ b, xmlEntryQ]];

(* The chains of a list as written: one for each alternative of its selected
   entry, each starting with the list stage. *)
listChains[l_] :=
  With[{id = Length[$listSources] + 1},
    $listSources[id] = l;
    Function[form, chain[Prepend[form[[2, 1]], listStage[Append[form[[1]], "Id" -> id]]], form[[2, 2]], form[[2, 3]]]] /@
      listForms[l]];

(* Each form is {stage, chain}: the list stage's Association so far, and the
   rest of the chain its selected entry continues with, as chain[stages after
   the first, links, conditions]. A name, a Condition or a test on the list
   applies to its pattern. *)
listForms[Verbatim[Pattern][s_Symbol, p_]] := mapListPattern[bindAs[s, #, strip] &, listForms[p]];
listForms[c_Condition] :=
  conditioned[listForms, c, Function[{forms, test}, mapListPattern[conditionWith[#, test] &, forms]]];
listForms[Verbatim[PatternTest][p_, f_]] :=
  mapListPattern[PatternTest[#, If[$mat, Function[x, f[strip[x]]], f]] &, listForms[p]];
listForms[entries_List] :=
  With[{s = Replace[Flatten @ Position[xmlEntryQ /@ entries, True],
      {{} :> (Scan[cEntry, entries]; refuseList["noentry", entries]), is_ :> Last[is]}]},
    With[{context = MapIndexed[If[First[#2] === s, Null, contextEntry[#1]] &, entries],
        chains = chainsOf[cStage[entries[[s]]]]},
      If[MemberQ[chains, chain[{_listStage, ___}, _, _]], refuseEntry["firstlist", entries[[s]]]];
      selectedForm[context, s, #] & /@ chains]];

mapListPattern[f_, forms_] := MapAt[f, forms, {All, 1, Key["Pattern"]}];

(* The selected entry's first stage takes its place in the list; the rest of
   its chain follows the list stage. *)
selectedForm[context_, s_, chain[{first_, rest___}, links_, conditions_]] :=
  Module[{pre = freshSymbol[], checks},
    checks = Cases[MapIndexed[{First[#2], #1} &, context], {k_, entry[_, id_Integer]} :> {k, id, freshSymbol[]}];
    {<|"Pattern" -> prefixed[ReplacePart[Replace[context, entry[p_, _] :> p, {1}], s -> first],
          Association[s -> pre, Rule @@@ checks[[All, {1, 3}]]]],
        "Index" -> pre, "Checks" -> checks[[All, {2, 3}]], "Parent" -> freshSymbol[], "At" -> freshSymbol[]|>,
      chain[{rest}, links, conditions]}];

(* A context entry is entry[pattern, check]: check is None, or for a combinator
   the key of the rest of its chain, run from the child in its place. *)
contextEntry[e_] /; xmlEntryQ[e] && multiStageQ[e] := contextCombinator[e];
contextEntry[e_] := entry[cEntry[e], None];

(* Only the names of the first stage reach the list; those of the later stages
   are the test's own. *)
contextCombinator[e_] :=
  Module[{ch, binds},
    {ch, binds} = reapBinds[cStage[e]];
    Which[
      !MatchQ[ch, _chain], refuseEntry["contextalternatives", e],
      MatchQ[First[ch[[1]]], _listStage], refuseEntry["firstlist", e]];
    With[{first = First[ch[[1]]], id = ++$contextCount},
      Scan[Sow[#, $bindTag] &, Select[binds, !FreeQ[first, #[[2]]] &]];
      Sow[{id, normalForm[ch, None], Complement[Union @@ (stageNames /@ Rest[ch[[1]]]), stageNames[first]], e}, $contextTag];
      entry[first, id]]];

$contextCount = 0;

(* The rests of the context combinator entries, by key. A name bound in one
   and used elsewhere would need the test to bind it, which it does not. *)
contextEntries[$Failed, _] := <||>;
contextEntries[query_, sown_] :=
  With[{outer = Union @@ (Union @@ (stageNames /@ #["Stages"]) & /@ alternativesOf[query])},
    Scan[If[IntersectingQ[#[[3]], outer], refuseEntry["contextname", #[[4]]]] &, sown];
    Association[#[[1]] -> #[[2]] & /@ sown]];

(* ---- List stage methods (ADR 0020) ---- *)

(* How each list stage of a normal form runs, decided once, from the list stage
   alone: its "Method" is
     anywhere[s, n]        {___, s, ___} with no other entry: each child s
                           matches
     generalMatcher[r, n]  any other list: the children r's matches select
   where n is the number of copies of each child's attributes the two-step
   match needs (solvable), or None. *)
withMethods[q_] /; KeyExistsQ[q, "Alternatives"] := MapAt[withMethods, q, {Key["Alternatives"], All}];
withMethods[q_] /; KeyExistsQ[q, "Stages"] :=
  MapAt[Replace[#, listStage[a_] :> listStage[Append[a, "Method" -> listMethod[listStage[a]]]], {1}] &, q, Key["Stages"]];
withMethods[q_] := q;

(* Shape 1, anywhere: the selected entry between two ___, with no context
   entry, name, Condition or test on the list. *)
listMethod[listStage[a_]] /; $recogniseShapes && a["Checks"] === {} &&
    MatchQ[a["Pattern"], {Verbatim[Pattern][a["Index"], Verbatim[PatternSequence][Verbatim[___]]], _, Verbatim[___]}] :=
  anywhere @@ twoStep[a["Pattern"][[2]]];
listMethod[ls_] := generalMatcher @@ listMatcher[ls];

(* The select rule, or, when a Condition would see a KeyValuePattern's later
   names unbound, its two-step form (solvable) over copied children, with the
   number of copies. *)
listMatcher[ls_] :=
  With[{r = selectRule[ls]},
    If[twoStepQ[First[r]],
      {First @ copiedRule[First[r], Extract[r, {2}, Hold]], copyCount[First[r]]},
      {r, None}]];

twoStep[p_] := If[twoStepQ[p], {copiedPattern[p], copyCount[p]}, {p, None}];

twoStepQ[p_] := brokenConditionsQ[p] || overlappingKeysQ[p];

(* An entry that is not an XML pattern is a WL pattern over the children:
   blanks, and the pattern heads over entries. A name on it binds a sequence of
   children, each the original element. *)
cEntry[e_] /; xmlEntryQ[e] := cElem[e];
cEntry[b : (_Blank | _BlankSequence | _BlankNullSequence)] := b;
cEntry[Verbatim[Pattern][s_Symbol, p_]] := bindAs[s, cEntry[p], stripAll];
cEntry[c_Condition] := conditioned[cEntry, c, conditionWith];
cEntry[Verbatim[PatternTest][p_, f_]] :=
  With[{c = cEntry[p]}, If[$mat, PatternTest[c, Function[x, f[strip[x]]]], PatternTest[c, f]]];
cEntry[(h : Repeated | RepeatedNull)[p_, spec___]] := h[cEntry[p], spec];
cEntry[Verbatim[Except][p_, q___]] := Except @@ (cEntry /@ {p, q});
cEntry[Verbatim[PatternSequence][ps___]] := PatternSequence @@ (cEntry /@ {ps});
cEntry[Verbatim[Alternatives][ps__]] := Alternatives @@ (cEntry /@ {ps});
cEntry[Verbatim[Optional][p_, d___]] := Optional[cEntry[p], d];
cEntry[l_List] := refuseEntry["list", l];
cEntry[x_XMLElement] := refuseEntry["element", x];
cEntry[e_] := refuseEntry["entry", e];

(* The entries in order, with the entries before each marked one matched as one
   named PatternSequence. *)
prefixed[es_, marks_] :=
  Fold[Function[{acc, k},
      Append[If[KeyExistsQ[marks, k], With[{m = marks[k]}, {namedPattern[m, PatternSequence @@ acc]}], acc], es[[k]]]],
    {}, Range[Length[es]]];

(* A Condition's test sees the names bound in its left-hand side, compiled by
   comp; attach puts the held test on the compiled left-hand side. *)
(* A selector that is not translated has given FromCSSSelector's message. *)
cssPattern[s_] := Replace[FromCSSSelector[s], $Failed :> refuseQuietly[]];

conditioned[comp_, c_, attach_] :=
  Module[{lhs, binds},
    {lhs, binds} = reapBinds[comp[c[[1]]]];
    Scan[Sow[#, $bindTag] &, binds];
    attach[lhs, wrapBinds[binds, Extract[c, {2}, Hold]]]];

(* p /; test, from a held test. *)
conditionWith[p_, test_Hold] := Condition @@ Join[Hold[p], test];

cXMLPattern[{tag_}] := XMLElement[cTag[tag], _, _];
cXMLPattern[{tag_, attrs_}] := With[{t = cTag[tag]}, XMLElement[t, cAttrs[attrs], _]];
cXMLPattern[args_] := refuse[XMLPattern::nargs, Length[args]];

cTag[tag_] := (
  noStringPatterns[tag];
  If[!validTagQ[tag], refuse[XMLPattern::badtag, tag]];
  tag);

noStringPatterns[p_] :=
  Replace[barePatterns[p], {s_, ___} :> refuse[XMLPattern::strpat, s]];

(* ---- The attribute argument ---- *)

cAttrs[$Failed] := refuseQuietly[];
cAttrs[Verbatim[Pattern][s_Symbol, inner_]] := bindAs[s, cAttrs[inner], stripAttrs];
(* A test on the whole attribute map sees the original map. *)
cAttrs[Verbatim[PatternTest][inner_, test_]] :=
  With[{p = cAttrs[inner]},
    If[$mat, PatternTest[p, Function[a, test[stripAttrs[a]]]], PatternTest[p, test]]];
cAttrs[Verbatim[_]] := _;
cAttrs[rules_List] :=
  With[{kvp = KeyValuePattern[cRule /@ rules]}, noDuplicateKeys[rules]; kvp];
cAttrs[r_Rule] := cAttrs[{r}];
(* A list is always the rule list, so a bare namespaced key is written {{ns, name}}. *)
cAttrs[k : (_String | _Alternatives)] /; literalKeyQ[k] := cAttrs[{k}];
cAttrs[a_] := refuse[XMLPattern::badattrs, a];

cRule[$Failed] := refuseQuietly[];
cRule[Verbatim[Rule][k_, v_]] :=
  Module[{listKeys},
    If[!literalKeyQ[k], refuse[XMLPattern::badkey, k]];
    noStringPatterns[v];
    listKeys = Select[keyLiterals[k], StringQ[#] && KeyExistsQ[$readings, #] &];
    Scan[Sow[#, $listKeyTag] &, listKeys];
    slotKey[k] -> If[Length[listKeys] === Length[keyLiterals[k]], desugar[v], v]];
cRule[k_?literalKeyQ] := cRule[k -> _];
cRule[k_] := refuse[XMLPattern::badkey, k];

(* A list key compiles to its private slot; every other key is itself. *)
slotKey[Verbatim[Alternatives][ks__]] := Alternatives @@ (slotKey /@ {ks});
slotKey[k_String] /; KeyExistsQ[$readings, k] := tok[First[$readings[k]]];
slotKey[k_] := k;

(* The one desugaring (ADR 0011): at a list key, a literal string or an
   Alternatives of literal strings can never match a list as written, so it
   means "contains this token". Nothing else is rewritten. *)
desugar[s : (_String | Verbatim[Alternatives][__String])] := {___, s, ___};
desugar[v_] := v;

(* KeyValuePattern demands distinct elements, so two rules on one key are a
   silent False however each would match alone. An Alternatives key may share
   a key with another rule, as each can take a different attribute. *)
noDuplicateKeys[rules_] :=
  Replace[
    Select[Tally[DeleteCases[Replace[#, Verbatim[Rule][k_, _] :> k] & /@ rules, _Alternatives]],
      Last[#] > 1 &],
    {{k_, _}, ___} :> refuse[XMLPattern::dupkey, k]];

(* ---- Bindings ---- *)

(* The same name gets the same fresh symbol throughout a query, so that
   (e : XMLPattern["a"]) | (e : XMLPattern["b"]) still binds one name, and a name
   at two stages of a combinator is still one value: materialisation is the same
   on equal elements. *)
SetAttributes[bindAs, HoldFirst];
bindAs[s_, p_, inverse_] :=
  If[!$mat,
    namedPattern[s, p],
    With[{fresh = If[KeyExistsQ[$fresh, Hold[s]], $fresh[Hold[s]],
        $fresh[Hold[s]] = freshSymbol[]]},
      Sow[{Hold[s], fresh, inverse}, $bindTag];
      namedPattern[fresh, p]]];

(* A temporary private symbol, so nothing is left in the caller's context. *)
freshSymbol[] := Module[{bound}, bound];

(* s : p, built without a literal Pattern on a right-hand side. *)
SetAttributes[namedPattern, HoldFirst];
namedPattern[s_, p_] := Pattern @@ Hold[s, p];

(* Held, so that the bindings its argument sows are reaped here. *)
SetAttributes[reapBinds, HoldFirst];
reapBinds[expr_] :=
  MapAt[DeleteDuplicates[Join @@ #] &, Reap[expr, $bindTag], 2];

(* Hold[body] -> Hold[With[{e = strip[e$], ...}, body]]

   The two-step match (restored, below) renames an element name a second time
   and wraps what this gives, so the two compose as
   With[{e$ = uncopied[e$$]}, With[{e = strip[e$]}, body]]. The order is
   required: strip removes token lists from an attribute list, not from a list
   of copies of one, so an element is uncopied before it is stripped. Issue #3
   proposes one module for both renamings.

   Only the names written in held are restored, also those inside held code
   within it: strip is linear in an element's subtree, and a list stage's test
   runs once per split of the list, often seeing none of the siblings after the
   selected one. With replaces a name only where it is written, so a name
   reached otherwise, as Symbol["e"], never saw the restored value, and leaving
   it out changes nothing. *)
wrapBinds[binds_, held_Hold] :=
  withBinds[Select[binds, !FreeQ[held, Replace[First[#], Hold[s_] :> HoldPattern[s]]] &], held];

withBinds[{}, held_Hold] := held;
withBinds[binds_, held_Hold] :=
  With[{spec = Replace[
      Join @@ (Replace[#, {Hold[s_], fresh_, inverse_} :> Hold[s = restore[inverse, fresh]]] & /@ binds),
      Hold[sets___] :> Hold[{sets}]]},
    Replace[Join[spec, held], Hold[vars_, body_] :> Hold[With[vars, body]]]];

(* A name bound only in an Alternatives branch that did not match is Sequence[],
   as in WL, and stays so when restored: inverse[] would leak a private head
   (issue #18). *)
restore[_] := Sequence[];
restore[inverse_, xs__] := inverse[xs];

(* ---- Conditions over a KeyValuePattern ---- *)

(* WL tests a Condition around a nested KeyValuePattern as soon as the first of
   its rules is matched, with the names of the later rules bound to nothing, and
   a False then is final: XMLPattern["a", {"href" -> h_, "data-id" -> i_}] /;
   StringContainsQ[h, i] never matches. A body condition, lhs :> body /; test,
   is tested the same way, and ReplaceList binds only the first rule's names.
   {OrderlessPatternSequence[rules..., ___]} binds them all but costs the
   factorial of the attribute count (ADR 0007: seconds at six rules).

   So a pattern or rule with such a Condition is matched in two steps. Its
   skeleton, with no names and no Conditions, finds the candidates as fast as a
   plain query. Each candidate is then matched with plain list patterns only:
   each element's attribute list is repeated, and each rule of a
   KeyValuePattern is matched, as {___, rule, ___}, in a copy of its own, the
   first copy keeping the KeyValuePattern as a test with no names. Each rule
   matches a different attribute, as KeyValuePattern requires. An element name
   sees the element with one attribute list, restored around each test and
   body that can see it. A rule's body is evaluated once, for that match. Any
   other pattern is left as it is. *)
solvable[r : Verbatim[RuleDelayed][lhs_, _]] /;
    twoStepQ[lhs] || (laterNamesQ[lhs] && bodyConditionQ[Extract[r, {2}, Hold]]) :=
  Module[{v = freshSymbol[], n = copyCount[lhs]},
    Replace[copiedRule[lhs, Extract[r, {2}, Hold]],
      Hold[rule_] :> RuleDelayed @@ Join[Hold @@ {namedPattern[v, skeleton[lhs]]},
        Hold[With[{s = {Replace[copied[v, n], {rule, _ :> $unmatched}]}}, Sequence @@ s /; s =!= {$unmatched}]]]]];
solvable[p_] /; twoStepQ[p] :=
  With[{v = freshSymbol[], n = copyCount[p], c = copiedPattern[p]},
    Condition @@ Join[Hold @@ {namedPattern[v, skeleton[p]]}, Hold[MatchQ[copied[v, n], c]]]];
solvable[x_] := x;

(* A KeyValuePattern with a name after its first rule. Held, since a Condition
   in a rule's body holds the caller's code. *)
SetAttributes[laterNamesQ, HoldFirst];
laterNamesQ[p_] :=
  !FreeQ[Unevaluated[p], Verbatim[KeyValuePattern][{_, rest__}] /; !FreeQ[Unevaluated[{rest}], Verbatim[Pattern][_Symbol, _]]];

brokenConditionsQ[p_] := !FreeQ[p, Verbatim[Condition][l_, _] /; laterNamesQ[l]];

(* A KeyValuePattern with an Alternatives key that shares a key with another of
   its rules. WL does not backtrack over which attribute the Alternatives key
   takes: MatchQ[{"x" -> 1, "y" -> 2}, KeyValuePattern[{("x" | "y") -> _,
   "x" -> _}]] is False. So such a pattern is matched in two steps too, with or
   without a Condition, and its skeleton leaves out those Alternatives rules. *)
overlappingKeysQ[p_] := !FreeQ[p, Verbatim[KeyValuePattern][r_List] /; MemberQ[overlapping[r], True]];

(* For each rule, whether it is an Alternatives rule whose key shares a key with
   another rule. *)
overlapping[rules_List] :=
  With[{keys = Replace[rules, {Verbatim[Rule][k_, _] :> DeleteDuplicates[keyLiterals[k]], _ -> {}}, {1}]},
    MapIndexed[
      MatchQ[rules[[First[#2]]], Verbatim[Rule][_Alternatives, _]] &&
        IntersectingQ[#1, Join @@ Delete[keys, #2]] &, keys]];

bodyConditionQ[Hold[_Condition]] := True;
bodyConditionQ[Hold[(With | Module | Block)[_, body_]]] := bodyConditionQ[Hold[body]];
bodyConditionQ[_] := False;

(* The pattern with no names and no Conditions, which every match matches. *)
skeleton[Verbatim[KeyValuePattern][r_List]] /; MemberQ[overlapping[r], True] :=
  KeyValuePattern[skeleton /@ Pick[r, overlapping[r], False]];
skeleton[Verbatim[Pattern][_, p_]] := skeleton[p];
skeleton[Verbatim[Condition][l_, _]] := skeleton[l];
skeleton[Verbatim[PatternTest][p_, f_]] := PatternTest[skeleton[p], f];
skeleton[v_Verbatim] := v;
skeleton[h_[args___]] := skeleton[h] @@ (skeleton /@ {args});
skeleton[x_] := x;

(* The candidate, the element or each element of a tuple, with its attribute
   list repeated n times. *)
copied[x_, n_] :=
  Replace[x, {XMLElement[t_, a_List, c_] :> XMLElement[t, ConstantArray[a, n], c],
    listSlot[p_, i_, els_] :> listSlot[p, i, copied[els, n]]}, {0, 1}];

(* An element, or each of a sequence of them, or of a list of them. *)
uncopied[xs___] := Sequence @@ Replace[{xs}, XMLElement[t_, {a_, ___}, c_] :> XMLElement[t, a, c], {1, 2}];

copyCount[p_] := 1 + Max[0, Cases[p, Verbatim[KeyValuePattern][r_List] :> Length[r], {0, Infinity}]];

copiedPattern[p_] := Block[{$renamed = renaming[p]}, copiedIn[p]];

copiedRule[lhs_, body_Hold] :=
  Block[{$renamed = renaming[lhs]},
    Hold @@ {RuleDelayed @@ Join[Hold @@ {copiedIn[lhs]}, restored[lhs, body]]}];

(* Each name that binds an element is renamed, and is the uncopied element in
   each test and body that can see it. When the query names a list key, the
   name was already renamed for materialisation; see wrapBinds for how the two
   compose. *)
renaming[p_] := Association[# -> freshSymbol[] & /@ elementNames[p]];

restored[l_, held_Hold] :=
  wrapBinds[{#, $renamed[#], uncopied} & /@ Select[elementNames[l], KeyExistsQ[$renamed, #] &], held];

copiedIn[Verbatim[Pattern][s_, p_]] /; KeyExistsQ[$renamed, Hold[s]] :=
  With[{f = $renamed[Hold[s]]}, namedPattern[f, copiedIn[p]]];
copiedIn[Verbatim[Pattern][s_, p_]] := namedPattern[s, copiedIn[p]];
copiedIn[c : Verbatim[Condition][l_, _]] :=
  Condition @@ Join[Hold @@ {copiedIn[l]}, restored[l, Extract[c, {2}, Hold]]];
copiedIn[XMLElement[t_, a_, c_]] := XMLElement[t, copiedAttributes[a], c];
(* copiedIn reaches only tests on an element (copiedAttributes keeps the tests
   on attributes). The first step ran them on the skeleton, but a branch of an
   Alternatives must fail its test here too, on the uncopied element. *)
copiedIn[Verbatim[PatternTest][p_, f_]] := PatternTest[copiedIn[p], Function[e, f[uncopied[e]]]];
copiedIn[h_[args___]] := copiedIn[h] @@ (copiedIn /@ {args});
copiedIn[x_] := x;

(* {first, {___, rule1, ___}, ..., ___}: first is the attribute argument, which
   sees the original list, with its KeyValuePattern made a test. *)
copiedAttributes[a_] :=
  With[{rules = attributeRules[a]},
    With[{marks = Table[freshSymbol[], Length[rules]]},
      With[{list = Join[{firstCopy[a]}, MapThread[{___, namedPattern[#1, #2], ___} &, {marks, rules}], {___}]},
        If[Length[rules] < 2, list, Condition @@ Join[Hold[list], Hold[DuplicateFreeQ[marks]]]]]]];

attributeRules[Verbatim[KeyValuePattern][r_List]] := r;
attributeRules[Verbatim[Pattern][_, p_]] := attributeRules[p];
attributeRules[Verbatim[PatternTest][p_, _]] := attributeRules[p];
attributeRules[_] := {};

firstCopy[k : Verbatim[KeyValuePattern][_List]] := With[{sk = skeleton[k]}, _?(MatchQ[sk])];
firstCopy[Verbatim[Pattern][s_, p_]] := namedPattern[s, firstCopy[p]];
firstCopy[Verbatim[PatternTest][p_, f_]] := PatternTest[firstCopy[p], f];
firstCopy[x_] := x;

(* The names that bind an element, not those in its children or tests. *)
elementNames[p_] := DeleteDuplicates @ Flatten[Last @ Reap[sowElementNames[p]]];
sowElementNames[Verbatim[Pattern][s_Symbol, p_]] :=
  (If[!FreeQ[p, XMLElement], Sow[Hold[s]]]; sowElementNames[p]);
sowElementNames[Verbatim[Condition][l_, _]] := sowElementNames[l];
sowElementNames[Verbatim[PatternTest][p_, _]] := sowElementNames[p];
sowElementNames[_XMLElement] := Null;
(* In a list stage every name on an entry binds elements, or a sequence or list
   of them; the parent and index names do not. *)
sowElementNames[listSlot[_, _, l_]] := sowEntryNames[l];
sowElementNames[_[args___]] := Scan[sowElementNames, {args}];
sowElementNames[_] := Null;

sowEntryNames[Verbatim[Pattern][s_Symbol, p_]] := (Sow[Hold[s]]; sowEntryNames[p]);
sowEntryNames[Verbatim[Condition][l_, _]] := sowEntryNames[l];
sowEntryNames[Verbatim[PatternTest][p_, _]] := sowEntryNames[p];
sowEntryNames[x_XMLElement] := sowElementNames[x];
sowEntryNames[_[args___]] := Scan[sowEntryNames, {args}];
sowEntryNames[_] := Null;

(* =========================================================== *)
(* Running a compiled query                                     *)
(*                                                              *)
(* The operations the XML* functions are: each takes a compiled *)
(* query (or $Failed, having messaged) and a tree, refuses what *)
(* it cannot run under the query's head, and gives the elements *)
(* as they are in the tree. elementMatcher instead gives a      *)
(* function that tests one element.                            *)
(* =========================================================== *)

(* At most the first n of the elements, in document order. *)
queryCases[$Failed, _, _] := $Failed;
queryCases[c_, tree_, n_] :=
  If[treeRefusedQ[c, tree], $Failed, runCompiled[runnerOf[c, unionCases, chainCases, casesC], tree, c, n]];

queryFirst[$Failed, _, _] := $Failed;
queryFirst[c_, tree_, default_] :=
  If[treeRefusedQ[c, tree], $Failed, runCompiled[runnerOf[c, unionFirst, chainFirst, firstC], tree, c, default]];

(* A rule has nothing to delete with. *)
queryDelete[$Failed, _] := $Failed;
queryDelete[c_, tree_] :=
  With[{h = c["Head"]},
    Which[
      c["Body"] =!= None, Message[MessageName[h, "badpat"], c["Query"]]; $Failed,
      treeRefusedQ[c, tree], $Failed,
      True, runCompiled[runnerOf[c, unionDelete, chainDelete, deleteC], tree, c]]];

(* A query of alternatives holding a combinator runs as their chains, any
   other combinator as one chain. *)
runnerOf[c_, onUnion_, onChain_, onPlain_] := Which[unionQ[c], onUnion, chainQ[c], onChain, True, onPlain];

(* A function that tests one element, or $Failed if the query is refused. Only
   the element itself is materialised: its children cannot be reached. *)
elementMatcher[$Failed] := $Failed;
elementMatcher[c_] :=
  With[{h = c["Head"]},
    Which[
      elementQuery[c, c["Query"], h, "combinator"] === $Failed, $Failed,
      c["Body"] =!= None, Message[MessageName[h, "badpat"], c["Query"]]; $Failed,
      True, With[{p = c["Plain"], r = c["Readings"]},
        If[r === {}, MatchQ[p], Function[el, MatchQ[materialise[el, r, {0}], p]]]]]];

treeRefusedQ[c_, tree_] :=
  !validTreeQ[tree] && With[{h = c["Head"]}, Message[MessageName[h, "badtree"], Head[tree]]; True];

(* A query tested on one element at a time takes no links: a combinator is
   refused under tag, and a combinator with a Condition under condcombinator.
   q is the query as written; a CSS selector string has no Condition of the
   caller's, whatever its translation holds. *)
elementQuery[$Failed, _, _, _] := $Failed;
elementQuery[c_, q_, head_, tag_] :=
  With[{h = head},
    Which[
      !unionQ[c] && c["Links"] === {}, c,
      AllTrue[alternativesOf[c], #["Conditions"] === {} &] || StringQ[q], Message[MessageName[h, tag], q]; $Failed,
      True, Message[MessageName[h, "condcombinator"], patternBase[q]]; $Failed]];

(* Materialise once per query, over the union of the list keys all its stages
   name; strip once, at the output. A chain runner is given the normal form, a
   plain runner the pattern or rule it runs. *)
runCompiled[run_, tree_, q_, rest___] :=
  With[{p = If[unionQ[q] || chainQ[q], q, q["Plain"]]},
    Block[{$kids = <||>, $contextMemo = <||>, $contexts = q["ContextEntries"]},
      If[q["Readings"] === {}, run[tree, p, rest],
        strip @ run[materialise[tree, q["Readings"]], p, rest]]]];

(* The pattern a plain query runs, or its rule, in its two-step form. *)
plainQuery[q_] :=
  solvable @ Replace[q["Body"], {None -> First[q["Stages"]],
    body_Hold :> RuleDelayed @@ Join[Hold @@ {First[q["Stages"]]}, body]}];

(* =========================================================== *)
(* Chains: every combinator query                               *)
(*                                                              *)
(* A combinator reads as a chain, left to right, as a CSS       *)
(* selector does: Descendant[a, Child[b, c]] and                *)
(* Child[Descendant[a, b], c] are both the chain a, Descendant, *)
(* b, Child, c. A chain runs on positions in the one            *)
(* (materialised) tree, so every relation, siblings included,   *)
(* is between sites of that tree. Each stage alone selects the  *)
(* sites related to the last site of a tuple; each tuple of     *)
(* elements is then matched against the stages as one plain WL  *)
(* pattern {s1, ..., sn}, so names scope as they do in WL: a    *)
(* stage's test sees only its own names, a name at two stages   *)
(* is one value, and a rule body sees every name. A list stage   *)
(* is matched against one parent's element children at a time,  *)
(* by the one list matcher, which Adjacent and Sibling links     *)
(* also run on (ADR 0016); in a tuple it is the list of those    *)
(* children, and its site is the selected child's.               *)
(* =========================================================== *)

(* Every combinator query runs as a chain, nested or not, tested or not. *)
chainQ[q_] := q["Links"] =!= {};

(* A query of alternatives holding a combinator runs as several (ADR 0015). *)
unionQ[q_] := KeyExistsQ[q, "Alternatives"];
alternativesOf[q_] := If[unionQ[q], q["Alternatives"], {q}];

(* The stages and links, alternating, as the chain runner reads them, each
   element stage in its two-step form. *)
chainOf[q_] := Riffle[runStage /@ q["Stages"], q["Links"]];

runStage[ls_listStage] := ls;
runStage[s_] := solvable[s];

(* The pattern a tuple of elements matches: the list of the chain's stages. A
   Condition on the whole combinator wraps the list; one on a combinator that is
   a stage wraps the sequence of its stages, so it sees only theirs. Each
   Condition covers the stages i to j, and an inner one is applied first. *)
tuplePattern[q_] :=
  With[{n = Length[q["Stages"]]},
    Fold[conditionWith[#1, Last[#2]] &,
      Last /@ Fold[coverStages, Transpose[{Transpose[{Range[n], Range[n]}], tupleStage /@ q["Stages"]}],
        Select[q["Conditions"], First[#] =!= {1, n} &]],
      Select[q["Conditions"], First[#] === {1, n} &]]];

(* The items {{i, j}, pattern} inside a Condition's span become one. *)
coverStages[items_, {{i_, j_}, test_}] :=
  With[{in = Flatten @ Position[items, {{a_, b_}, _} /; i <= a && b <= j, {1}, Heads -> False]},
    Join[Take[items, First[in] - 1],
      {{{i, j}, conditionWith[PatternSequence @@ items[[in, 2]], test]}},
      Drop[items, Last[in]]]];

tupleRule[q_] := solvable[RuleDelayed @@ Join[Hold @@ {tuplePattern[q]}, q["Body"]]];

(* A list stage in a tuple: the list, with the selected entry at the child's
   index, and each context combinator entry's chain completing from its child. *)
tupleStage[listStage[a_]] :=
  With[{par = a["Parent"], i = a["At"], pre = a["Index"]},
    Condition @@ Join[Hold @@ {listSlot[namedPattern[par, _], namedPattern[i, _], a["Pattern"]]},
      heldAnd[Hold[Length[{pre}] + 1 == i], contextChecks[a]]]];
tupleStage[s_] := s;

(* The children a list stage selects, from listSlot[parent, _, children]: each
   child's index. *)
selectRule[listStage[a_]] :=
  With[{par = a["Parent"], pre = a["Index"]}, With[{slot = listSlot[namedPattern[par, _], _, a["Pattern"]]},
    RuleDelayed @@ Join[
      If[a["Checks"] === {}, Hold[slot], Hold @@ {Condition @@ Join[Hold[slot], contextChecks[a]]}],
      Hold[Length[{pre}] + 1]]]];

(* Held: the marks are names the list binds. *)
contextChecks[a_] :=
  With[{par = a["Parent"]},
    Fold[heldAnd, Hold[True], Function[{id, m}, Hold[contextQ[id, par, Length[{m}] + 1]]] @@@ a["Checks"]]];

heldAnd[Hold[True], b_Hold] := b;
heldAnd[Hold[x_], Hold[True]] := Hold[x];
heldAnd[Hold[x_], Hold[y_]] := Hold[x && y];

(* Extract reads {} as no positions, not as the whole tree. *)
at[{}] := $chainTree;
at[p_] := Extract[$chainTree, p];

elementIndices[l_List] := Flatten @ Position[l, _XMLElement, {1}, Heads -> False];

(* The document above the top elements (ADR 0018) is the site {0}, which no
   position in the tree is: Extract gives the tree's head there. Its element
   children are the top elements: the root element of an XMLObject, the
   elements of a list, or a bare XMLElement itself, at {}. *)
$documentSite = {0};

(* The parent of an element's site: an element child is at {..., 3, k}, and
   every other element is a top element. *)
parentOf[p_] := If[Length[p] >= 2 && p[[-2]] === 3, Drop[p, -2], $documentSite];

topSites[XMLObject["Document"][__]] := {{2}};
topSites[_XMLElement] := {{}};
topSites[l_List] := List /@ elementIndices[l];

(* selected[r, p, s]: the sites related to p by r that stage s selects. From
   the document, every element is a descendant, the input included, which is
   never a result (siteTuples). *)
selected[Descendant, {0}, s_] := Position[$chainTree, s, {0, Infinity}, Heads -> False];
selected[Child, {0}, s_] := With[{k = kidsAt[$documentSite]}, Pick[k[[1]], MatchQ[s] /@ k[[2]]]];
selected[Descendant, p_, s_] := Join[p, #] & /@ Position[at[p], s, Infinity, Heads -> False];
selected[Child, p_, s_] := Join[p, {3}, #] & /@ Position[at[p][[3]], s, {1}, Heads -> False];

(* The element children of the element or document at par: their sites, the
   elements, and each site's place among them, found once per parent in a run,
   since a list of children may be long; none when par is not an element. *)
kidsAt[par_] := Replace[$kids[par], _Missing :> ($kids[par] = kidsOf[par])];

kidsOf[{0}] := With[{ss = topSites[$chainTree]}, kidsList[ss, If[ss === {}, {}, atAll[ss]]]];
kidsOf[par_] :=
  With[{e = at[par]},
    If[MatchQ[e, _XMLElement],
      With[{is = elementIndices[Last[e]]}, kidsList[Join[par, {3, #}] & /@ is, Last[e][[is]]]],
      {{}, {}, <||>}]];

kidsList[sites_, els_] := {sites, els, AssociationThread[sites, Range[Length[sites]]]};

(* The one list matcher (ADR 0016): the indices of the children els of par that
   a list stage selects, each once, by the stage's method. The general matcher
   takes them from its rule's matches. Anywhere selects each child s matches,
   which Position finds without building the sequence before each one: over
   5,000 siblings that is 1 ms against 300 ms. *)
listIndices[anywhere[s_, n_], _, els_] := anywhereIndices[copiedBy[els, n], s];
listIndices[generalMatcher[rule_, n_], par_, els_] := Union @ ReplaceList[copiedBy[listSlot[par, 0, els], n], rule];

anywhereIndices[els_, s_] := Flatten @ Position[els, s, {1}, Heads -> False];

copiedBy[x_, None] := x;
copiedBy[x_, n_] := copied[x, n];

(* The sites a list stage selects below site p, by its method: among the
   children of p, or for Descendant of p and of every element inside it, one
   parent at a time. Below the document, that is the document and every
   element. *)
listSelected[Child, p_, method_] := childrenSelected[p, method];
listSelected[Descendant, {0}, method_] :=
  Join @@ (childrenSelected[#, method] & /@
    Prepend[Position[$chainTree, XMLElement[_, _, {___, _XMLElement, ___}], {0, Infinity}, Heads -> False], $documentSite]);
listSelected[Descendant, p_, method_] :=
  Join @@ (childrenSelected[Join[p, #], method] & /@ Position[at[p], XMLElement[_, _, {___, _XMLElement, ___}], {0, Infinity}, Heads -> False]);

childrenSelected[par_, method_] :=
  With[{k = kidsAt[par]}, If[k[[2]] === {}, {}, k[[1, listIndices[method, par, k[[2]]]]]]];

(* The tuple's elements, a list stage's slot as listSlot[parent, index,
   children]. *)
tupleElements[q_] :=
  With[{slots = Flatten @ Position[q["Stages"], _listStage, {1}, Heads -> False]},
    If[slots === {}, atAll, withListSlots[slots]]];

withListSlots[slots_][t_] := ReplacePart[atAll[t], Thread[slots -> (listSlotAt /@ t[[slots]])]];

listSlotAt[site_] :=
  With[{par = parentOf[site]}, With[{k = kidsAt[par]}, listSlot[par, k[[3]][site], k[[2]]]]];

tuplesElements[q_, tuples_] := If[MemberQ[q["Stages"], _listStage], tupleElements[q] /@ tuples, elementsAt[tuples]];

(* Whether the child at index j of par completes context combinator entry id:
   the rest of its chain run from that child alone, once per child in a run. *)
contextQ[id_, par_, j_] :=
  With[{site = kidsAt[par][[1, j]]},
    Lookup[$contextMemo, Key[{id, site}], $contextMemo[{id, site}] = completesQ[$contexts[id], site]]];

completesQ[q_, site_] := siteTuples[q["Chain"], q["TupleTest"], {site}] =!= {};

(* The test a chain's tuples pass, None when its stages' own matches decide. *)
tupleTest[q_] := If[stagesDecideQ[q], None, MatchQ[solvable[tuplePattern[q]]] @* tupleElements[q]];

(* Adjacent[a, b] is Child[XMLDocument[] | XMLPattern[_], {___, a, b, ___}]
   and Sibling[a, b] is Child[XMLDocument[] | XMLPattern[_], {___, a, ___, b, ___}]
   (ADR 0016, ADR 0018): from an a at index i of its
   parent's children, the list {Repeated[_, {i - 1}], _, b, ___} or
   {Repeated[_, {i - 1}], _, ___, b, ___}, which is {b, ___} or {___, b, ___}
   over the children after it. The parent of a top element is the document,
   so the top elements of a list are siblings (ADR 0018); the document has
   none. *)
siblingSiteQ[p_] := p =!= $documentSite;

followingSelected[p_, s_] /; siblingSiteQ[p] :=
  With[{k = kidsAt[parentOf[p]]},
    With[{i = k[[3]][p]},
      k[[1, i + anywhereIndices[Drop[k[[2]], i], s]]]]];
followingSelected[_, _] := {};

(* Adjacent extends the tuples whose last sites are children of one parent
   together: {b, ___} over the children after a child matches when the next
   one matches b, as ___ matches the rest. *)
adjacentSelected[tuples_, s_] /; siblingSiteQ[Last[First[tuples]]] :=
  Module[{k, next, in, ts, ns, keep},
    k = kidsAt[parentOf[Last[First[tuples]]]];
    next = Lookup[k[[3]], Last /@ tuples] + 1;
    in = UnitStep[Length[k[[2]]] - next];
    ts = Pick[tuples, in, 1];
    ns = Pick[next, in, 1];
    keep = MatchQ[s] /@ k[[2, ns]];
    MapThread[Append, {Pick[ts, keep], k[[1, Pick[ns, keep]]]}]];
adjacentSelected[_, _] := {};

(* Sibling[before, after] matches an element with SOME earlier sibling matching
   before together with it, the whole chain's names and Condition included, and
   gives that element once. So a tuple ending at an after site defers its before
   stage: it holds before[g, k], the choices of group g earlier than the sibling
   at index k, and a runOf mark for each further stage a choice fixes. A choice
   fixes the stages back to the start of its run of Adjacent and Sibling links,
   as they are its siblings; the stages before the run relate to the list, not
   to the sibling, and group the choices. Adjacent needs no choice: an element
   has one previous sibling. A bare XMLElement input, at {}, is the document's
   only child, and the document has no siblings, so a sibling link drops
   both. *)
extend[tuples_, link : {Adjacent | Sibling, _, _}] /; MemberQ[tuples, {___, {} | {0}}] :=
  extend[DeleteCases[tuples, {___, {} | {0}}], link];
extend[tuples_, {Adjacent, s_, _}] := related[Adjacent, tuples, s];
extend[tuples_, {Sibling, s_, run_}] :=
  Join @@ (siblingChoices[#, s, run] & /@ GatherBy[tuples, {Take[#, run - 1], parentOf[Last[#]]} &]);
extend[tuples_, {Descendant, s_listStage, _}] /; $stagesDecide := listRelated[Descendant, outermost[tuples], s];
extend[tuples_, {r_, s_listStage, _}] := listRelated[r, tuples, s];
extend[tuples_, {Descendant, s_, _}] /; $stagesDecide := related[Descendant, outermost[tuples], s];
extend[tuples_, {r_, s_, _}] := related[r, tuples, s];

related[Adjacent, tuples_, s_] := Join @@ (adjacentSelected[#, s] & /@ GatherBy[tuples, parentOf @* Last]);
related[r_, tuples_, s_] := Join @@ (Function[t, Append[t, #] & /@ selected[r, Last[t], s]] /@ tuples);

listRelated[r_, tuples_, listStage[a_]] :=
  With[{m = a["Method"]}, Join @@ (Function[t, Append[t, #] & /@ listSelected[r, Last[t], m]] /@ tuples)];

(* Descendant[ancestor, desc] gives each element once, as querySelectorAll and
   soupsieve's select do. When the stages' own matches decide, any ancestor
   will do, and the first in document order, the outermost, is taken: a name
   bound at the ancestor stage, as in a rule body, sees the outermost ancestor.
   So a site below another tuple's last site is dropped, its descendants being
   the other's too; the subtrees searched are then disjoint. When the stages
   decide, a site is the last of at most one tuple after every link, so the
   dropped tuples are the only duplicates. Every element is below the
   document. *)
outermost[tuples_] /; MemberQ[tuples, {$documentSite}] := {{$documentSite}};
outermost[tuples_] :=
  Module[{cover = None},
    Select[tuples[[documentOrdering[Last /@ tuples]]],
      Function[t, If[cover =!= None && Take[Last[t], UpTo[Length[cover]]] === cover,
        False, cover = Last[t]; True]]]];

(* Document order, as querySelectorAll gives elements: lexicographic, with a
   position before every position below it, so an element comes before the
   elements nested in it and after an earlier sibling's. Ties keep their
   order. The document comes first. *)
documentOrdering[{}] := {};
documentOrdering[ps_] :=
  Ordering @ Join[PadRight[Replace[ps, {0} -> {-1}, {1}], {Length[ps], Max[Length /@ ps]}, 0], List /@ Range[Length[ps]], 2];

(* The choices are a group's tuples from the run on, in document order of their
   last site; the sites the list selects after the first choice are the
   candidates. When the stages' own matches decide the match, the first choice
   is the one taken, and taken at once, as Descendant takes the outermost
   ancestor: Sibling then lists the children once per parent. *)
siblingChoices[tuples_, s_, run_] :=
  With[{sorted = tuples[[Ordering[Last /@ Last /@ tuples]]]},
    With[{sites = followingSelected[Last[First[sorted]], s]},
      If[$stagesDecide,
        Append[First[sorted], #] & /@ sites,
        With[{g = Length[$choices] + 1},
          $choices[g] = sorted[[All, run ;;]];
          Join[Take[First[sorted], run - 1], {before[g, Last[#]]},
              ConstantArray[runOf, Length[First[sorted]] - run], {#}] & /@ sites]]]];

(* For each link, the stage its run of Adjacent and Sibling links starts at. *)
runStarts[links_] :=
  FoldList[If[MatchQ[First[#2], Adjacent | Sibling], #1, Last[#2]] &, 1,
    Transpose[{Most[links], Range[2, Length[links]]}]];

(* The first site tuple t stands for that test accepts, or Nothing. The latest
   deferred stage is chosen first, earliest sibling first: a name bound at the
   before stage, as in a rule body, sees the first earlier sibling, in document
   order, with which the element matches the whole pattern. *)
resolved[t_, test_] := Catch[choose[t, test]; Nothing, $chosen];

choose[t_, test_] :=
  Replace[FirstPosition[Reverse[t], _before, None, {1}, Heads -> False], {
    None :> If[test[t], Throw[t, $chosen]],
    {r_} :> chooseAt[t, Length[t] + 1 - r, test]}];

(* A loop by index: Do over a long list of choices costs its length at once. *)
chooseAt[t_, p_, test_] :=
  With[{cs = $choices[t[[p, 1]]], k = t[[p, 2]]},
    Module[{i = 1},
      While[i <= Length[cs] && Last[Last[cs[[i]]]] < k,
        choose[Join[Take[t, p - 1], cs[[i]], Drop[t, p - 1 + Length[cs[[i]]]]], test];
        i++]]];

(* The site tuples of a chain that test accepts, test None when the stages'
   own matches decide, in document order of their last sites, as a base
   XMLCases gives its elements. The first stage's sites include the document
   and the root, which a bare XMLElement tree makes an element. The root can
   be a later stage below the document, but is never a result, as it is never
   one of a base XMLCases (ADR 0018). *)
siteTuples[chain_, test_, starts_ : All] :=
  With[{links = chain[[2 ;; ;; 2]]},
    Block[{$choices = <||>, $stagesDecide = test === None},
      If[$stagesDecide, Identity, firstPerSite[#, test] &] @ byLastSite @ DeleteCases[Fold[extend,
        List /@ firstSites[First[chain], starts],
        Transpose[{links, chain[[3 ;; ;; 2]], runStarts[links]}]], {__, {}}]]];

(* The sites of the first stage, or those of starts that it matches. *)
firstSites[s_, All] :=
  Join[If[MatchQ[Head[$chainTree], s], {$documentSite}, {}], Position[$chainTree, s, {0, Infinity}, Heads -> False]];
firstSites[s_, starts_] := Select[starts, MatchQ[at[#], s] &];

(* Each element once: of the tuples ending at one site, which are adjacent
   once ordered by their last sites, the first that test accepts, by their
   stages in document order, the latest stage first, as a Sibling choice is
   made. So a name bound at a Descendant's ancestor stage sees the outermost
   ancestor with which the element matches the whole pattern. A tuple with a
   deferred Sibling stage is ordered once its choices are made. *)
firstPerSite[tuples_, test_] := firstAccepted[#, test] & /@ SplitBy[tuples, Last];

firstAccepted[ts_, test_] /; FreeQ[ts, _before] := SelectFirst[inDocumentOrder[ts], test, Nothing];
firstAccepted[ts_, test_] := Replace[resolved[#, test] & /@ ts, {{} -> Nothing, rs_ :> First[inDocumentOrder[rs]]}];

inDocumentOrder[{t_}] := {t};
inDocumentOrder[ts_] :=
  With[{n = Max[Map[Length, ts, {2}]]},
    ts[[documentOrdering[Flatten[PadRight[Reverse[Most[#]], {Automatic, n}]] & /@ ts]]]];

(* Tuples in document order of their last sites; tuples ending at one site
   keep their order. *)
byLastSite[tuples_] := tuples[[documentOrdering[Last /@ tuples]]];

(* The elements at a list of positions, with one Extract. *)
atAll[ps_] := Extract[$chainTree, ps];

(* The element tuples of site tuples, which have one length. *)
elementsAt[{}] := {};
elementsAt[tuples_] := Partition[atAll[Join @@ tuples], Length[First[tuples]]];

(* The site tuples whose elements match the tuple pattern. The stages' own
   matches, which selected the sites, decide it unless a Condition wraps a
   combinator or a name is bound at two stages. *)
matchedSites[q_] := siteTuples[q["Chain"], q["TupleTest"]];

stagesDecideQ[q_] :=
  q["Conditions"] === {} && DuplicateFreeQ[Join @@ (stageNames /@ q["Stages"])];

(* A Condition in the body can reject a tuple. *)
bodyRejectsQ[q_] := bodyConditionQ[q["Body"]];

namesIn[s_] :=
  DeleteDuplicates @ Cases[s, Verbatim[Pattern][n_Symbol, _] :> Hold[n], {0, Infinity}, Heads -> True];

(* The plain form picks the last element of a matching tuple rather than binding
   the tuple: a rule's right-hand side re-evaluates what it is given, and a
   tuple may hold a large element. *)
chainCases[tree_, q_, n_] /; bodyRejectsQ[q] := Block[{$chainTree = tree}, Take[ruleValues[q], UpTo[n]]];
chainCases[tree_, q_, n_] /; q["Body"] =!= None :=
  Block[{$chainTree = tree}, Cases[tuplesElements[q, matchedSites[q]], q["TupleRule"], {1}, n]];
chainCases[tree_, q_, n_] :=
  Block[{$chainTree = tree}, atAll[Last /@ Take[matchedSites[q], UpTo[n]]]];

chainFirst[tree_, q_, default_] /; bodyRejectsQ[q] :=
  Block[{$chainTree = tree}, Replace[ruleValues[q], {{v_, ___} :> v, {} -> default}]];
chainFirst[tree_, q_, default_] /; q["Body"] =!= None :=
  Block[{$chainTree = tree},
    FirstCase[tuplesElements[q, matchedSites[q]], q["TupleRule"], default, {1}]];
chainFirst[tree_, q_, default_] :=
  Block[{$chainTree = tree},
    Replace[matchedSites[q], {{t_, ___} :> at[Last[t]], {} -> default}]];

(* A Condition in a rule's body can reject a tuple, so it takes part in
   choosing one, as a Condition on the combinator does: as Cases gives the
   places where a rule gives a value, a tuple is accepted when the rule gives
   it one. The value is kept, so the body is not evaluated again once the tuple
   is chosen. *)
ruleValues[q_] :=
  Module[{rule = q["TupleRule"], elements = tupleElements[q], values = <||>, tuples},
    tuples = siteTuples[q["Chain"],
      Function[t, With[{v = Replace[elements[t], {rule, _ :> $unmatched}]},
        v =!= $unmatched && (values[t] = v; True)]]];
    Lookup[values, Key /@ tuples]];

(* A chain deletes the elements its last stage selects. Delete removes
   positions nested in one another together. *)
chainDelete[tree_, q_] :=
  Block[{$chainTree = tree},
    deleteAt[tree, DeleteDuplicates[Last /@ matchedSites[q]]]];

(* =========================================================== *)
(* Alternatives of chains (ADR 0015)                            *)
(*                                                              *)
(* Alternatives holding a combinator run as the list of their   *)
(* chains, in disjunctive normal form, over one materialised    *)
(* tree, and are merged per element, as XPath's union merges    *)
(* node sets: each element once, in document order, from the    *)
(* first alternative, in written order, that accepts it. Each   *)
(* chain chooses its own tuple by ADR 0014's rule, so the       *)
(* choice of alternative ranks above every choice of stage. An  *)
(* alternative that is an element pattern is a chain of one     *)
(* stage, and selects what a plain query with it selects, never *)
(* the root.                                                    *)
(* =========================================================== *)

(* The site tuples of alternative a that test accepts, test None when its
   stages decide, in document order of their last sites. *)
alternativeSites[a_, test_] /; a["Links"] === {} :=
  With[{ts = List /@ elementSites[First[a["Chain"]]]}, If[test === None, ts, Select[ts, test]]];
alternativeSites[a_, test_] := siteTuples[a["Chain"], test];

(* The sites below the root that s matches, in document order. *)
elementSites[s_] :=
  Replace[Position[$chainTree, s, Infinity, Heads -> False], {{} -> {}, ps_ :> fromCasesOrder[ps]}];

(* The accepted tuples of alternative a whose last site keep accepts, each
   {tuple}, or {tuple, value} when the body can reject and so is evaluated in
   choosing one. keep is tested first, so a site an earlier alternative took is
   not tried again, and its body not evaluated. *)
acceptedTuples[a_, keep_] /; bodyRejectsQ[a] :=
  Module[{rule = a["TupleRule"], elements = tupleElements[a], values = <||>, tuples},
    tuples = alternativeSites[a,
      Function[t, keep[Last[t]] && With[{v = Replace[elements[t], {rule, _ :> $unmatched}]},
        v =!= $unmatched && (values[t] = v; True)]]];
    {#, values[#]} & /@ tuples];
acceptedTuples[a_, keep_] :=
  With[{test = a["TupleTest"]},
    List /@ Select[alternativeSites[a, If[test === None, None, keep[Last[#]] && test[#] &]], keep @* Last]];

(* For each alternative in order, its accepted entries {k, tuple} or {k, tuple,
   value}, k its index, of the sites no earlier alternative took. *)
unionEntries[q_] :=
  Module[{taken = <||>},
    Join @@ MapIndexed[
      Function[{a, k}, With[{es = acceptedTuples[a, !KeyExistsQ[taken, #] &]},
        Scan[(taken[Last[First[#]]] = True) &, es];
        Prepend[#, First[k]] & /@ es]],
      q["Alternatives"]]];

(* What an entry gives: its element, or its value, the body evaluated now when
   it was not in choosing the entry. *)
entryResult[q_, rules_][{k_, t_}] :=
  If[q["Body"] === None, at[Last[t]], Replace[tupleElements[q["Alternatives"][[k]]][t], rules[[k]]]];
entryResult[_, _][{_, _, v_}] := v;

inSiteOrder[es_] := es[[documentOrdering[es[[All, 2, -1]]]]];

entryRules[q_] := If[q["Body"] === None, None, #["TupleRule"] & /@ q["Alternatives"]];

unionCases[tree_, q_, n_] :=
  Block[{$chainTree = tree},
    With[{es = Take[inSiteOrder[unionEntries[q]], UpTo[n]]},
      If[q["Body"] === None, atAll[es[[All, 2, -1]]], entryResult[q, entryRules[q]] /@ es]]];

(* Each alternative stops at its first accepted entry before the best so far:
   the answer is the earliest, ties going to the earlier alternative, as one
   element can only tie with itself. *)
unionFirst[tree_, q_, default_] :=
  Block[{$chainTree = tree},
    Module[{best = None},
      MapIndexed[
        Function[{a, k}, With[{keep = If[best === None, True &, With[{b = best[[2, -1]]}, beforeQ[#, b] &]]},
          Replace[firstAcceptedTuple[a, keep], {e_} :> (best = Prepend[e, First[k]])]]],
        q["Alternatives"]];
      If[best === None, default, entryResult[q, entryRules[q]][best]]]];

(* An element pattern's first match in document order is found without the
   others; it is a candidate only if keep takes it, and no later match is. *)
firstAcceptedTuple[a_, keep_] /; a["Links"] === {} && a["StagesDecide"] && !bodyRejectsQ[a] :=
  Select[{{#}} & /@ firstMatchPositions[$chainTree, First[a["Chain"]], 1], keep[#[[1, -1]]] &];
firstAcceptedTuple[a_, keep_] := Take[acceptedTuples[a, keep], UpTo[1]];

(* Whether site p comes before site s in document order. *)
beforeQ[p_, s_] := p =!= s && documentOrdering[{p, s}] === {1, 2};

unionDelete[tree_, q_] :=
  Block[{$chainTree = tree},
    deleteAt[tree, DeleteDuplicates[Join @@ (Last @* First /@ acceptedTuples[#, True &] & /@ q["Alternatives"])]]];

(* A document keeps its root element, which an XMLObject needs (ADR 0018). *)
deleteAt[tree : XMLObject["Document"][_, _, _], ps_] /; MemberQ[ps, {2}] :=
  (Message[XMLDeleteCases::root]; deleteAt[tree, DeleteCases[ps, {2}]]);
deleteAt[tree_, {}] := tree;
deleteAt[tree_, ps_] := Delete[tree, ps];

(* =========================================================== *)
(* Argument counts and options                                  *)
(* =========================================================== *)

(* Only a rule naming an option of f is read as one: any other rule, such as
   XMLFirstCase's default, is an argument. *)
optionRuleQ[f_][(Rule | RuleDelayed)[name_, _]] :=
  MemberQ[Keys[Options[f]], ToString[name]];
optionRuleQ[_][_] := False;

optionQ[f_][a_] := MatchQ[a, _?(optionRuleQ[f]) | {__?(optionRuleQ[f])}];

(* Each public function ends with
   f[args___] /; (countMessage[f, {args}, {min, max}]; False) := Null,
   for a call that no other definition takes. countMessage gives the message a
   built-in gives when the number of positional arguments is outside
   {min, max} (argx, argrx or argt), and the condition fails either way, so the
   call stays unevaluated, as a built-in's does. The options of f at the end of
   args are not counted, but the first min arguments are always positional, so
   a query pattern -> rhs is never read as an option.
   A one-argument call gives no message: for XMLMatchQ it is the operator form,
   and for XMLCases, XMLFirstCase and XMLDeleteCases it has the shape of an
   operator form, as Cases[pattern] has, which they may get. *)
countMessage[_, {_}, _] := Null;
countMessage[f_, args_List, spec : {min_, max_}] :=
  With[{
      optionCount = LengthWhile[Reverse[args], optionQ[f]],
      alwaysPositional = Min[min, Length[args]]},
    With[{n = Max[alwaysPositional, Length[args] - optionCount]},
      If[n < min || n > max, argumentCountMessage[f, n, spec]]]];

argumentCountMessage[f_, n_, {1, 1}] := Message[MessageName[f, "argx"], f, n];
argumentCountMessage[f_, n_, {m_, m_}] := Message[MessageName[f, "argrx"], f, n, m];
argumentCountMessage[f_, n_, {min_, max_}] := Message[MessageName[f, "argt"], f, n, min, max];

(* =========================================================== *)
(* XMLCases                                                     *)
(* =========================================================== *)

Options[XMLCases] = {"AttributeReadings" -> <||>};

(* The count n is a ceiling, as in StringCases (ADR 0019). A third argument
   that is not an option is a count, and one that is not valid gives innf. *)
XMLCases[tree_, q_, n : Except[_?(optionQ[XMLCases])] : Infinity, opts : OptionsPattern[]] /; countQ[n] :=
  withReadings[OptionValue["AttributeReadings"], queryCases[compileQuery[q, XMLCases], tree, n]];

XMLCases[tree_, q_, n : Except[_?(optionQ[XMLCases])], opts : OptionsPattern[]] /;
    (Message[XMLCases::innf, Unevaluated[XMLCases[tree, q, n, opts]], 3]; False) := Null;

XMLCases[args___] /; (countMessage[XMLCases, {args}, {2, 3}]; False) := Null;

countQ[n_] := MatchQ[n, Infinity | _Integer?NonNegative];

(* Base: a pattern, a Condition, or a rule over either, in document order. Cases
   and Position visit an element after the elements nested in it, so the
   positions of the matches are put in document order; a rule is then applied
   to the matched elements in that order, its body evaluated once for each it
   gives a value for, up to n. A Condition in the body can reject a match, so
   then every match is a candidate. *)
casesC[tree_, r : Verbatim[RuleDelayed][lhs_, _], n_] :=
  Cases[If[bodyConditionQ[Extract[r, {2}, Hold]], matchesInOrder[tree, lhs], firstMatches[tree, lhs, n]],
    r, {1}, n];
casesC[tree_, pat_, n_] := firstMatches[tree, pat, n];

(* The first n elements of tree, below its root, that match pat, in document
   order, the search stopping early. *)
firstMatches[tree_, pat_, Infinity] := matchesInOrder[tree, pat];
firstMatches[tree_, pat_, n_] := Extract[tree, firstMatchPositions[tree, pat, n]];

(* Position stops at the nth match in Cases order, which visits an element
   after the elements nested in it. A match earlier in document order that it
   has not visited is visited after one it has, so it is an element that one is
   nested in: the first n in document order are among the matches found and the
   matches on the way down to them. Each of these is tested once. *)
firstMatchPositions[tree_, pat_, n_] :=
  With[{ps = Position[tree, pat, Infinity, n, Heads -> False]},
    Take[#[[documentOrdering[#]]], UpTo[n]] & @ Join[ps, Select[
      Complement[Join @@ (Table[Take[#, k], {k, Length[#] - 1}] &) /@ ps, ps],
      MatchQ[Extract[tree, #], pat] &]]];

(* The elements of tree, below its root, that match pat, in document order.
   Extract reads {} as the whole tree, not as no positions. *)
matchesInOrder[tree_, pat_] :=
  Replace[Position[tree, pat, Infinity, Heads -> False], {
    {} -> {},
    ps_ :> Extract[tree, fromCasesOrder[ps]]}];

(* Positions in Cases order, as Position gives them, put in document order.
   Cases visits an element right after the elements nested in it, so the
   matches nested in a match m come as one block right before it; moving m to
   the start of its block gives document order. So the positions are ordered
   by the start of their block, and at one start the outer, the later in Cases
   order, first. A match with others nested in it is one right after a position
   below it; without such a match the order is already document order. A sort
   of the padded positions would cost their depth for every match. *)
fromCasesOrder[ps_] :=
  With[{outer = 1 + Select[Pick[Range[Length[ps] - 1], UnitStep[Differences[Length /@ ps]], 0],
      belowQ[ps[[#]], ps[[# + 1]]] &]},
    If[outer === {}, ps,
      Module[{starts = Range[Length[ps]]},
        starts[[outer]] = blockStart[ps, #] & /@ outer;
        ps[[Ordering @ Transpose[{starts, -Range[Length[ps]]}]]]]]];

belowQ[p_, q_] := Length[p] > Length[q] && Take[p, Length[q]] === q;

(* The first position of the block of matches nested in the match at i: the
   positions before it that are below it end right before it. A binary search,
   as whether a position is below it changes once, from False to True. *)
blockStart[ps_, i_] :=
  Module[{lo = 1, hi = i - 1, mid},
    While[lo < hi,
      mid = Quotient[lo + hi, 2];
      If[belowQ[ps[[mid]], ps[[i]]], hi = mid, lo = mid + 1]];
    lo];

(* =========================================================== *)
(* XMLFirstCase                                                 *)
(* The first of what XMLCases gives; the base form short-      *)
(* circuits. Default (3rd arg) returned when nothing found.     *)
(* =========================================================== *)

Options[XMLFirstCase] = {"AttributeReadings" -> <||>};

XMLFirstCase[tree_, q_, default : Except[_?(optionRuleQ[XMLFirstCase])] : Missing["NotFound"],
    opts : OptionsPattern[]] :=
  withReadings[OptionValue["AttributeReadings"], queryFirst[compileQuery[q, XMLFirstCase], tree, default]];

XMLFirstCase[args___] /; (countMessage[XMLFirstCase, {args}, {2, 3}]; False) := Null;

(* Base: the first match in document order, the search stopping early. A rule's
   body is evaluated for that match only, unless a Condition on the body
   rejects it and the search goes on. *)
firstC[tree_, r : Verbatim[RuleDelayed][lhs_, _], default_] :=
  Replace[firstMatchPosition[tree, lhs], {
    None -> default,
    p_ :> Replace[Extract[tree, p], {r,
      _ :> FirstCase[Drop[matchesInOrder[tree, lhs], UpTo[1]], r, default, {1}]}]}];
firstC[tree_, pat_, default_] :=
  Replace[firstMatchPosition[tree, pat], {None -> default, p_ :> Extract[tree, p]}];

(* The first match in document order, or None. *)
firstMatchPosition[tree_, pat_] :=
  Replace[firstMatchPositions[tree, pat, 1], {{p_} :> p, {} -> None}];

(* =========================================================== *)
(* XMLDeleteCases                                               *)
(* Base: native DeleteCases with Infinity levelspec.            *)
(* Combinators: the chain's last-stage elements are deleted.    *)
(* =========================================================== *)

Options[XMLDeleteCases] = {"AttributeReadings" -> <||>};

XMLDeleteCases[tree_, q_, opts : OptionsPattern[]] :=
  withReadings[OptionValue["AttributeReadings"], queryDelete[compileQuery[q, XMLDeleteCases], tree]];

XMLDeleteCases[args___] /; (countMessage[XMLDeleteCases, {args}, {2, 2}]; False) := Null;

(* Base: a pattern or a Condition *)
deleteC[tree : XMLObject["Document"][_, root_, _], pat_] /; MatchQ[root, pat] :=
  (Message[XMLDeleteCases::root]; ReplacePart[tree, 2 -> DeleteCases[root, pat, Infinity]]);
deleteC[tree_, pat_] := DeleteCases[tree, pat, Infinity];

(* =========================================================== *)
(* XMLMatchQ (ADR 0013)                                         *)
(* A whole-element test, as StringMatchQ is a whole-string one. *)
(* =========================================================== *)

Options[XMLMatchQ] = {"AttributeReadings" -> <||>};

(* An option rule is never a pattern, so XMLMatchQ[pattern, opts] is the
   operator form. Its option is a Block for each call of the operator. *)
XMLMatchQ[q_, opts : Longest[__?(optionRuleQ[XMLMatchQ])]][el_] :=
  withReadings[OptionValue[XMLMatchQ, {opts}, "AttributeReadings"], matchWith[cachedMatcher[q], el]];
XMLMatchQ[q_][el_] := matchWith[cachedMatcher[q], el];

XMLMatchQ[el_, q : Except[_?(optionRuleQ[XMLMatchQ])], opts : OptionsPattern[]] :=
  withReadings[OptionValue["AttributeReadings"], matchWith[matcherOf[q], el]];

XMLMatchQ[args___] /; (countMessage[XMLMatchQ, {args}, {1, 2}]; False) := Null;

matchWith[$Failed, _] := $Failed;
matchWith[m_, el_] := m[el];

matcherOf[q_] := elementMatcher[compileQuery[q, XMLMatchQ]];

(* The operator form stays unevaluated, as MatchQ[pattern] does, and is applied
   to each element in turn, so its matcher is kept, keyed on everything the
   compiled query depends on: the pattern, $AttributeReadings, which the
   "AttributeReadings" option joins to (issue #2), and whether shapes are
   recognised, so that a test turning recognition off gets a matcher compiled
   with it off (ADR 0020). A refused pattern is not
   kept: it gives its message on each call, as the two-argument form does. The
   cache is emptied when it is full. *)
$matcherCache = <||>;
$matcherCacheSize = 256;

cachedMatcher[q_] :=
  With[{key = {q, $AttributeReadings, $recogniseShapes}},
    Lookup[$matcherCache, Key[key],
      With[{m = matcherOf[q]},
        If[m =!= $Failed,
          If[Length[$matcherCache] >= $matcherCacheSize, $matcherCache = <||>];
          $matcherCache[key] = m];
        m]]];

(* =========================================================== *)
(* FromCSSSelector (ADR 0017)                                   *)
(*                                                              *)
(* A CSS selector, tokenised by CSS Syntax 3 and read as static *)
(* Selectors Level 4, to the XML pattern it says. The string is *)
(* parsed whole first, so a selector that is not valid CSS is   *)
(* ::invalid wherever the fault is, into a tree:                *)
(*   a selector list   {cx, ...}                                *)
(*   a selector        cx[{compound, ...}, {link, ...}]         *)
(*   a compound        cp[{simple, ...}, its text]              *)
(*   a relative one    rel[link, cx[...]], in :has()            *)
(* The tree is then translated, and what cannot be translated   *)
(* is ::unsupported or ::impossible, naming the workaround.     *)
(* The output holds only public symbols and the names made by   *)
(* cssFreshName, so it can be spliced into a larger pattern.    *)
(* =========================================================== *)

FromCSSSelector[s_String] := cssTranslate[s];
FromCSSSelector[x_] := (Message[FromCSSSelector::string, 1, HoldForm[FromCSSSelector[x]]]; $Failed);
FromCSSSelector[args___] := (argumentCountMessage[FromCSSSelector, Length[{args}], {1, 1}]; $Failed);

(* An invalid selector is caught before any translation, as the whole string
   is parsed first. *)
cssTranslate[s_] :=
  Block[{$cssInput = cssPreprocess[s], $cssArgOf = None, $cssInHas = False},
    Catch[
      Catch[cssListPattern[cssParse[cssTokens[$cssInput]]], $cssRefused,
        Function[{why, tag}, cssRefusal[s, why]]],
      $cssInvalid,
      Function[{why, tag}, Message[FromCSSSelector::invalid, s, why]; $Failed]]];

cssRefusal[s_, {kind_, part_, how_}] := (Message[MessageName[FromCSSSelector, kind], s, part, how]; $Failed);

cssInvalid[why_String, pos_Integer] := Throw[why <> " at character " <> ToString[pos], $cssInvalid];
cssInvalid[why_String, pos_Integer, hint_String] :=
  Throw[why <> " at character " <> ToString[pos] <> "; " <> hint, $cssInvalid];
cssInvalid[why_String] := Throw[why, $cssInvalid];
cssRefuse[kind_, part_, how_] := Throw[{kind, part, how}, $cssRefused];

(* ASCII case-insensitivity, as Selectors requires for keywords: ToLowerCase
   would also fold letters such as \[CapitalEAcute]. *)
$cssFold = StringReplace[RegularExpression["[A-Z]"] :> ToLowerCase["$0"]];
cssLower[s_] := $cssFold[s];

(* ---- Tokens (CSS Syntax 3, sections 3 and 4) ---- *)

cssPreprocess[s_] :=
  StringReplace[s, {"\r\n" -> "\n", "\r" -> "\n", "\f" -> "\n", FromCharacterCode[0] -> "\:fffd"}];

(* The non-ASCII code points an identifier may hold unescaped (the current
   draft's list, after HTML's valid custom element names): U+00A0, for one,
   must be escaped. *)
$cssNonASCII = "\\x{B7}\\x{C0}-\\x{D6}\\x{D8}-\\x{F6}\\x{F8}-\\x{37D}\\x{37F}-\\x{1FFF}\\x{200C}\\x{200D}\\x{203F}\\x{2040}\\x{2070}-\\x{218F}\\x{2C00}-\\x{2FEF}\\x{3001}-\\x{D7FF}\\x{F900}-\\x{FDCF}\\x{FDF0}-\\x{FFFD}\\x{10000}-\\x{10FFFF}";
(* An escape: hex digits and one optional whitespace, or any other code point
   but a newline, or the end of the input. *)
$cssEscape = "\\\\(?:[0-9a-fA-F]{1,6}[ \\t\\n]?|[^\\n0-9a-fA-F]|\\z)";
$cssNameChar = "(?:[a-zA-Z0-9_\\-" <> $cssNonASCII <> "]|" <> $cssEscape <> ")";
$cssIdent = "(?:--|-?(?:[a-zA-Z_" <> $cssNonASCII <> "]|" <> $cssEscape <> "))" <> $cssNameChar <> "*";
cssStringRegex[q_] := q <> "(?:[^" <> q <> "\\\\\\n]|\\\\[\\s\\S]?)*" <> q <> "?";
cssClosedStringRegex[q_] := q <> "(?:[^" <> q <> "\\\\\\n]|\\\\[\\s\\S])*" <> q;

(* In the order consume-token tries them, the first that matches winning: so a
   "-" starts a number, then -->, then an identifier, before it is a delim. *)
$cssTokenKinds = {
  "comment" -> "/\\*[\\s\\S]*?(?:\\*/|\\z)",
  "ws" -> "[ \\t\\n]+",
  "string" -> cssStringRegex["\""] <> "|" <> cssStringRegex["'"],
  "hash" -> "#" <> $cssNameChar <> "+",
  "number" -> "[+-]?(?:[0-9]+(?:\\.[0-9]+)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?(?:%|" <> $cssIdent <> ")?",
  "cdc" -> "-->",
  "function" -> $cssIdent <> "\\(",
  "ident" -> $cssIdent,
  "cdo" -> "<!--",
  "delim" -> "[\\s\\S]"};

$cssTokenRegex = RegularExpression[StringRiffle[("(?:" <> # <> ")") & /@ Values[$cssTokenKinds], "|"]];
$cssTokenTests = MapAt[RegularExpression, $cssTokenKinds, {All, 2}];

(* tk[kind, value, start, end], with escapes resolved; comments are dropped,
   and are not whitespace. *)
cssTokens[s_] := cssToken[s, #] & /@ StringPosition[s, $cssTokenRegex, Overlaps -> False];

cssToken[s_, {i_, j_}] :=
  With[{text = StringTake[s, {i, j}]},
    cssTokenOf[SelectFirst[$cssTokenTests, StringMatchQ[text, Last[#]] &][[1]], text, s, i, j]];

cssTokenOf["comment", __] := Nothing;
cssTokenOf["ws", _, _, i_, j_] := tk["ws", " ", i, j];
cssTokenOf["string", text_, s_, i_, j_] :=
  With[{closed = StringMatchQ[text, RegularExpression[cssClosedStringRegex[StringTake[text, 1]]]]},
    Which[
      closed, tk["string", cssUnescape[StringTake[text, {2, -2}], ""], i, j],
      (* Open at the end of the input, it is closed; open at a newline, bad. *)
      j == StringLength[s], tk["string", cssUnescape[StringDrop[text, 1], ""], i, j],
      True, tk["badstring", text, i, j]]];
cssTokenOf["hash", text_, _, i_, j_] :=
  tk[If[StringMatchQ[StringDrop[text, 1], RegularExpression[$cssIdent]], "hash-id", "hash"],
    cssUnescape[StringDrop[text, 1], "\:fffd"], i, j];
cssTokenOf["number", text_, _, i_, j_] := tk["number", text, i, j];
cssTokenOf["function", text_, _, i_, j_] := tk["function", cssUnescape[StringDrop[text, -1], "\:fffd"], i, j];
cssTokenOf["ident", text_, _, i_, j_] := tk["ident", cssUnescape[text, "\:fffd"], i, j];
cssTokenOf[_, text_, _, i_, j_] := tk["delim", text, i, j];

(* A backslash at the end of the input is U+FFFD in a name, and nothing in a
   string; before a newline, in a string, it continues the line. *)
cssUnescape[s_, atEnd_] :=
  StringReplace[s, {
    RegularExpression["\\\\([0-9a-fA-F]{1,6})[ \\t\\n]?"] :> cssCodePoint[FromDigits["$1", 16]],
    RegularExpression["\\\\\\n"] -> "",
    RegularExpression["\\\\([\\s\\S])"] :> "$1",
    RegularExpression["\\\\\\z"] -> atEnd}];

cssCodePoint[n_] :=
  If[n == 0 || 16^^D800 <= n <= 16^^DFFF || n > 16^^10FFFF, "\:fffd", FromCharacterCode[n]];

(* ---- Blocks (CSS Syntax 3, section 5) ---- *)

(* [ ], ( ) and a function's ( ) become blk[opener, contents, end]. A block
   still open at the end of the input is closed there, without error. *)
cssBlocks[toks_] :=
  With[{stack = Fold[cssBlockStep, {{None, {}}}, toks]},
    Last @ First @ Nest[cssCloseBlock[#, StringLength[$cssInput]] &, stack, Length[stack] - 1]];

cssBlockStep[stack_, t : (tk["delim", "[" | "(", _, _] | tk["function", __])] := Append[stack, {t, {}}];
cssBlockStep[stack_, t : tk["delim", "]" | ")", _, _]] /; cssClosesQ[stack[[-1, 1]], t] :=
  cssCloseBlock[stack, t[[4]]];
cssBlockStep[stack_, t_] := MapAt[Append[t], stack, {-1, 2}];

cssCloseBlock[stack_, end_] :=
  MapAt[Append[blk[stack[[-1, 1]], stack[[-1, 2]], end]], Most[stack], {-1, 2}];

cssClosesQ[tk["delim", "[", __], tk["delim", "]", __]] := True;
cssClosesQ[tk["delim", "(", __] | tk["function", __], tk["delim", ")", __]] := True;
cssClosesQ[_, _] := False;

cssStart[tk[_, _, i_, _]] := i;
cssStart[blk[o_, _, _]] := cssStart[o];
cssEnd[tk[_, _, _, j_]] := j;
cssEnd[blk[_, _, j_]] := j;

(* The source text of a run of items, and of one item as a message shows it. *)
cssText[items_List] := StringTake[$cssInput, {cssStart[First[items]], cssEnd[Last[items]]}];
cssShown[blk[o_, _, _]] := cssShown[o];
cssShown[t_tk] := cssText[{t}];

cssWSQ[tk["ws", __]] := True;
cssWSQ[_] := False;

cssTrimWS[items_] :=
  With[{n = LengthWhile[items, cssWSQ]},
    If[n == Length[items], {}, Drop[Drop[items, n], -LengthWhile[Reverse[items], cssWSQ]]]];

(* ---- The grammar (Selectors Level 4, section 16) ---- *)

cssParse[toks_] := (
  Replace[FirstCase[toks, tk["badstring", __]],
    t_tk :> cssInvalid["a string cannot hold a newline that is not escaped", cssStart[t]]];
  Replace[FirstCase[toks, tk["delim", "\\", __]],
    t_tk :> cssInvalid["\\ before a newline is not an escape outside a string", cssStart[t]]];
  cssSelectorList[cssBlocks[toks]]);

cssSelectorList[items_] :=
  Replace[cssCommaSplit[items], {
    {{{}, _}} :> cssInvalid["the selector is empty"],
    parts_ :> (cssComplex[cssNonEmpty[#, items], False] & /@ parts)}];

(* The items between commas, each with whitespace trimmed, and the index of
   the comma before it (0 for the first). *)
cssCommaSplit[items_] :=
  With[{cs = Flatten[Position[items, tk["delim", ",", _, _], {1}, Heads -> False]]},
    MapThread[{cssTrimWS[items[[#1 + 1 ;; #2 - 1]]], #1} &, {Prepend[cs, 0], Append[cs, Length[items] + 1]}]];

cssNonEmpty[{{}, 0}, items_] :=
  cssInvalid["a selector is missing before ,", cssStart[First[Select[items, MatchQ[tk["delim", ",", _, _]]]]]];
cssNonEmpty[{{}, k_}, items_] := cssInvalid["a selector is missing after ,", cssStart[items[[k]]]];
cssNonEmpty[{seg_, _}, _] := seg;

(* Compounds and the links between them: a run of whitespace alone is a
   descendant combinator, and whitespace around >, +, ~ and || is ignored. A
   relative selector, in :has(), may start with a combinator. *)
cssComplex[items_, relative_] :=
  Module[{runs = SplitBy[cssColumns[items], cssSeparatorQ], lead = Descendant, compounds},
    If[cssSeparatorQ[runs[[1, 1]]],
      If[!relative,
        cssInvalid["a selector cannot start with " <> cssShown[runs[[1, 1]]], cssStart[runs[[1, 1]]]]];
      lead = cssLink[First[runs]];
      runs = Rest[runs];
      If[runs === {}, cssInvalid["a selector is missing after " <> cssShown[Last[items]], cssStart[Last[items]]]]];
    If[cssSeparatorQ[runs[[-1, 1]]],
      With[{c = Last[Select[runs[[-1]], cssCombinatorQ]]},
        cssInvalid["a selector cannot end with " <> cssShown[c], cssStart[c]]]];
    compounds = cssCompound /@ runs[[1 ;; ;; 2]];
    cssPseudoElementsLast[compounds];
    With[{c = cx[compounds, cssLink /@ runs[[2 ;; ;; 2]]]}, If[relative, rel[lead, c], c]]];

cssColumns[items_] :=
  SequenceReplace[items,
    {tk["delim", "|", i_, _], tk["delim", "|", k_, j_]} /; k == i + 1 :> tk["column", "||", i, j]];

cssCombinatorQ[tk["delim", ">" | "+" | "~", _, _] | tk["column", __]] := True;
cssCombinatorQ[_] := False;

cssSeparatorQ[t_] := cssWSQ[t] || cssCombinatorQ[t];

cssLink[run_] :=
  With[{cs = Select[run, cssCombinatorQ]},
    Switch[Length[cs],
      0, Descendant,
      1, cssLinkOf[First[cs]],
      _, cssInvalid["two combinators in a row", cssStart[cs[[2]]]]]];

cssLinkOf[tk["delim", ">", __]] := Child;
cssLinkOf[tk["delim", "+", __]] := Adjacent;
cssLinkOf[tk["delim", "~", __]] := Sibling;
cssLinkOf[tk["column", __]] := cssColumn;

(* A pseudo-element can only end the last compound of a selector, and is
   never valid in a pseudo-class's argument. *)
cssPseudoElementsLast[compounds_] := (
  Scan[Replace[FirstCase[First[#], _sPseudoElement],
      e_sPseudoElement :> cssInvalid[e[[1]] <> " can only end a selector", e[[2]]]] &,
    Most[compounds]];
  If[$cssArgOf =!= None,
    Replace[FirstCase[First[Last[compounds]], _sPseudoElement],
      e_sPseudoElement :> cssInvalid[e[[1]] <> " cannot be used inside " <> $cssArgOf, e[[2]]]]]);

(* A compound: at most one type selector, first, then subclass selectors, with
   only pseudo-classes after a pseudo-element. *)
cssCompound[parts_] :=
  With[{nodes = Replace[cssType[parts], {t_, rest_} :> Join[t, cssSubclasses[rest]]]},
    Replace[FirstPosition[nodes, _sPseudoElement, None, {1}], {k_} :>
      If[!FreeQ[Drop[nodes, k], _sId | _sClass | _sAttr, {1}],
        cssInvalid[nodes[[k, 1]] <> " must come last in its compound", nodes[[k, 2]]]]];
    cp[nodes, cssText[parts]]];

$cssTypeName = tk["ident", __] | tk["delim", "*", __];

cssType[{a : $cssTypeName, tk["delim", "|", __], b : $cssTypeName, r___}] := {{cssNamespaced[{a, b}]}, {r}};
cssType[{a : tk["delim", "|", __], b : $cssTypeName, r___}] := {{cssNamespaced[{a, b}]}, {r}};
cssType[{tk["ident", n_, __], r___}] := {{sType[n]}, {r}};
cssType[{tk["delim", "*", __], r___}] := {{sUniversal[]}, {r}};
cssType[parts_] := {{}, parts};

cssNamespaced[items_] := sRefuse["unsupported", cssText[items], $cssNamespaceHow];

cssSubclasses[{}] := {};
cssSubclasses[parts_] := Replace[cssSubclass[parts], {node_, rest_} :> Prepend[cssSubclasses[rest], node]];

cssSubclass[{tk["hash-id", v_, __], r___}] := {sId[v], {r}};
cssSubclass[{t : tk["hash", __], ___}] := cssInvalid[cssShown[t] <> " is not a valid id selector", cssStart[t]];
cssSubclass[{tk["delim", ".", __], tk["ident", v_, __], r___}] := {sClass[v], {r}};
cssSubclass[{t : tk["delim", ".", __], ___}] := cssInvalid["a class name is missing after .", cssStart[t]];
cssSubclass[{b : blk[tk["delim", "[", __], _, _], r___}] := {cssAttribute[b], {r}};
cssSubclass[{c : tk["delim", ":", __], tk["delim", ":", __], x : (tk["ident", __] | blk[tk["function", __], _, _]), r___}] :=
  {cssPseudoElement[c, x], {r}};
cssSubclass[{c : tk["delim", ":", __], x : tk["ident", __], r___}] := {cssPseudoClass[c, x], {r}};
cssSubclass[{c : tk["delim", ":", __], x : blk[tk["function", __], _, _], r___}] := {cssPseudoFunction[c, x], {r}};
cssSubclass[{c : tk["delim", ":", __], ___}] := cssInvalid["a pseudo-class name is missing after :", cssStart[c]];
cssSubclass[{t_, ___}] := cssInvalid["unexpected " <> cssShown[t], cssStart[t]];

(* ---- Attribute selectors ---- *)

(* The value must be one identifier or one string. No whitespace is allowed
   inside a matcher such as ^=, so its two delims must be adjacent. *)
cssAttribute[b : blk[_, items_, _]] :=
  With[{its = DeleteCases[cssMatchers[items], tk["ws", __]]},
    If[MatchQ[its, {$cssTypeName, tk["delim", "|", __], tk["ident", __], ___} | {tk["delim", "|", __], tk["ident", __], ___}],
      sRefuse["unsupported", cssText[{b}], $cssNamespaceHow],
      cssAttributeOf[its, b]]];

cssMatchers[items_] :=
  SequenceReplace[items, {
    {tk["delim", m : "~" | "|" | "^" | "$" | "*", i_, _], tk["delim", "=", k_, j_]} /; k == i + 1 :>
      tk["matcher", m <> "=", i, j],
    {tk["delim", "=", i_, j_]} :> tk["matcher", "=", i, j]}];

cssAttributeOf[{tk["ident", n_, __]}, _] := sAttr[n];
cssAttributeOf[{tk["ident", n_, __], tk["matcher", m_, __], tk["ident" | "string", v_, __]}, _] := sAttr[n, m, v, None];
cssAttributeOf[{tk["ident", n_, __], tk["matcher", m_, __], tk["ident" | "string", v_, __], f : tk["ident", flag_, __]}, _] :=
  If[MemberQ[{"i", "s"}, cssLower[flag]], sAttr[n, m, v, cssLower[flag]],
    cssInvalid["unknown attribute flag " <> cssShown[f], cssStart[f]]];
cssAttributeOf[{tk["ident", __], tk["matcher", __], tk["ident" | "string", __], t_, ___}, _] :=
  cssInvalid["unexpected " <> cssShown[t] <> " in an attribute selector", cssStart[t]];
cssAttributeOf[{tk["ident", __], tk["matcher", __], v_, ___}, _] :=
  cssInvalid["an attribute value must be an identifier or a string, not " <> cssShown[v], cssStart[v]];
cssAttributeOf[{tk["ident", __], m : tk["matcher", __]}, _] :=
  cssInvalid["an attribute value is missing after " <> cssShown[m], cssStart[m]];
cssAttributeOf[{}, b_] := cssInvalid["an attribute selector is empty", cssStart[b]];
cssAttributeOf[{t : Except[tk["ident", __]], ___}, _] :=
  cssInvalid["an attribute name is missing before " <> cssShown[t], cssStart[t]];
cssAttributeOf[{_, t_, ___}, _] := cssInvalid["unexpected " <> cssShown[t] <> " in an attribute selector", cssStart[t]];

(* ---- Pseudo-classes and pseudo-elements ---- *)

(* Translated. The child-indexed ones are positions among the parent's
   element children (ADR 0016): each is cssPos[fromEnd, a, b, of, text], the
   index a k + b, k >= 0, counted from the start or the end, among all the
   children (of None), those of the compound's type ("type"), or those that
   match a selector ("of", then the pattern). *)
$cssPseudoClasses = {"empty", "checked", "link", "any-link", "only-child", "only-of-type",
  "first-child", "last-child", "first-of-type", "last-of-type", "root", "scope"};

(* The pseudo-classes of the only top element (ADR 0018). *)
$cssRootPseudoClasses = "root" | "scope";

$cssPositions = <|
  "first-child" -> {{False, 0, 1, None}}, "last-child" -> {{True, 0, 1, None}},
  "only-child" -> {{False, 0, 1, None}, {True, 0, 1, None}},
  "first-of-type" -> {{False, 0, 1, "type"}}, "last-of-type" -> {{True, 0, 1, "type"}},
  "only-of-type" -> {{False, 0, 1, "type"}, {True, 0, 1, "type"}}|>;

$cssNth = <|"nth-child" -> {False, None}, "nth-last-child" -> {True, None},
  "nth-of-type" -> {False, "type"}, "nth-last-of-type" -> {True, "type"}|>;

(* Valid Selectors 4 that is not translated, with the workaround. *)
$cssChildIndexedHow = "It needs the element's parent, so it can be in a compound of the selector or of a relative selector in :has(), but not in an argument of :not(), :is() or :where(). Write a list of patterns for the parent's children instead, as in Child[XMLDocument[] | XMLPattern[_], {XMLPattern[\"li\"], ___}].";
$cssFormHow = "Write the test as a condition on an XMLPattern.";
(* :root and :scope are the only top element (ADR 0018), at the start of a
   selector. *)
$cssRootHow = "It matches the only top element, which has no parent or sibling in the tree, so it can only be in the first compound of a selector, followed by > or a descendant combinator, as in :root > body.";
$cssRootInsideHow = "It cannot be in an argument of :not(), :is(), :where(), :has() or :nth-child(). Put it in the first compound of the selector, as in :root > body.";
$cssUnsupported = Join[
  AssociationMap[$cssFormHow &, {"enabled", "disabled", "read-only", "read-write", "placeholder-shown",
    "default", "unchecked", "indeterminate", "valid", "invalid", "in-range", "out-of-range",
    "required", "optional", "defined"}]];
$cssUnsupportedFunctions =
  <|"lang" -> "Use Descendant[XMLPattern[_, \"lang\" -> ...], ...], which takes the lang of any ancestor, not only the nearest.",
    "dir" -> $cssFormHow|>;

(* Valid, but true only in a browser. *)
$cssShadowHow = "A document has no shadow trees.";
$cssStateHow = "Leave it out of the selector to match the elements in any state.";
$cssImpossible = Join[
  AssociationMap[$cssStateHow &, {"visited", "hover", "active", "focus", "focus-visible", "focus-within",
    "playing", "paused", "seeking", "buffering", "stalled", "muted", "volume-locked", "open",
    "popover-open", "modal", "fullscreen", "picture-in-picture", "autofill", "-webkit-autofill",
    "user-valid", "user-invalid"}],
  <|"target" -> "To match the element that a fragment names, use XMLPattern[_, \"id\" -> fragment].",
    "host" -> $cssShadowHow|>];
$cssImpossibleFunctions = <|"host" -> $cssShadowHow, "host-context" -> $cssShadowHow|>;

(* The functional pseudo-classes, for the message on one written without
   parentheses. *)
$cssPseudoFunctions = {"not", "is", "where", "has", "nth-child", "nth-last-child", "nth-of-type",
  "nth-last-of-type", "lang", "dir", "host-context"};

$cssLegacyPseudoElements = {"before", "after", "first-line", "first-letter"};
$cssPseudoElements = {"before", "after", "first-line", "first-letter", "prefix", "suffix", "marker",
  "placeholder", "file-selector-button", "details-content", "selection", "target-text", "search-text",
  "spelling-error", "grammar-error", "backdrop", "cue", "column", "scroll-marker", "scroll-marker-group",
  "view-transition"};
$cssPseudoElementFunctions = {"highlight", "cue", "part", "slotted", "view-transition-group",
  "view-transition-image-pair", "view-transition-old", "view-transition-new", "scroll-button", "picker"};

cssPseudoElementHow["first-letter"] := "To get the first letter of each match, use StringTake[HTMLInnerText[e], UpTo[1]].";
cssPseudoElementHow[_] := "Pseudo-elements are generated or laid out by a browser, and are not elements of the document.";

cssPseudoClass[c_, x : tk["ident", n_, __]] :=
  With[{name = cssLower[n], text = cssText[{c, x}]},
    Which[
      MemberQ[$cssPseudoClasses, name], sPseudo[name, text],
      KeyExistsQ[$cssUnsupported, name], sRefuse["unsupported", text, $cssUnsupported[name]],
      KeyExistsQ[$cssImpossible, name], sRefuse["impossible", text, $cssImpossible[name]],
      MemberQ[$cssLegacyPseudoElements, name], sPseudoElement[text, cssStart[c], name],
      MemberQ[$cssPseudoFunctions, name], cssInvalid[text <> " needs an argument in parentheses", cssStart[c]],
      True, cssInvalid["unknown pseudo-class " <> text, cssStart[c]]]];

cssPseudoFunction[c_, b : blk[tk["function", n_, __], items_, _]] :=
  With[{name = cssLower[n], text = cssText[{c, b}], where = ":" <> n <> "()"},
    Switch[name,
      "not", sNot[cssArguments[items, where, cssStart[c], False, False], text],
      "is" | "where", sIs[cssArguments[items, where, cssStart[c], False, True], text],
      "has",
        If[$cssInHas, cssInvalid[":has() cannot be used inside :has()", cssStart[c]]];
        sHas[Block[{$cssInHas = True}, cssArguments[items, where, cssStart[c], True, False]], text],
      "nth-child" | "nth-last-child" | "nth-of-type" | "nth-last-of-type",
        cssNthOf[$cssNth[name], items, where, cssStart[c], text],
      "matches", cssInvalid["unknown pseudo-class " <> where, cssStart[c], "write :is() instead"],
      "contains" | "-soup-contains" | "-soup-contains-own",
        cssInvalid["unknown pseudo-class " <> where, cssStart[c],
          "soupsieve adds it; test the text in a condition instead, as in e : XMLPattern[...] /; StringContainsQ[HTMLTextContent[e], ...]"],
      _, Which[
        KeyExistsQ[$cssUnsupportedFunctions, name], sRefuse["unsupported", text, $cssUnsupportedFunctions[name]],
        KeyExistsQ[$cssImpossibleFunctions, name], sRefuse["impossible", text, $cssImpossibleFunctions[name]],
        MemberQ[$cssPseudoClasses, name], cssInvalid[":" <> n <> " takes no argument", cssStart[c]],
        True, cssInvalid["unknown pseudo-class " <> where, cssStart[c]]]]];

(* The arguments of :not(), :is(), :where() and :has(). :is() and :where() are
   forgiving: an argument that is not valid is dropped, and none at all is
   valid. *)
cssArguments[items_, where_, pos_, relative_, forgiving_] :=
  Block[{$cssArgOf = where},
    If[forgiving,
      Cases[cssCommaSplit[items], {seg : Except[{}], _} :>
        Catch[cssComplex[seg, relative], $cssInvalid, Nothing &]],
      Replace[cssCommaSplit[items], {
        {{{}, _}} :> cssInvalid[where <> " needs an argument", pos],
        parts_ :> (cssComplex[cssNonEmpty[#, items], relative] & /@ parts)}]]];

(* :nth-child(An+B of S): the An+B, then for the -child forms an optional
   "of" and a selector list. *)
cssNthOf[{fromEnd_, of_}, items_, where_, pos_, text_] :=
  With[{k = FirstPosition[items, tk["ident", o_, __] /; cssLower[o] === "of", None, {1}, Heads -> False]},
    If[k === None,
      sNth[cssPos[fromEnd, Sequence @@ cssAnB[cssTrimWS[items], where, pos], of, text], None],
      If[of =!= None || k === {1} || !cssWSQ[items[[First[k] - 1]]],
        cssInvalid["unexpected \"of\" in " <> where, cssStart[items[[First[k]]]]]];
      sNth[cssPos[fromEnd, Sequence @@ cssAnB[cssTrimWS[Take[items, First[k] - 1]], where, pos], "of", text],
        cssArguments[Drop[items, First[k]], where, pos, False, False]]]];

(* An+B (CSS Syntax 3, section 6), read from its source text: odd, even, an
   integer, or An+B with whitespace only around the sign of B. *)
$cssAnB = RegularExpression["(?i)([+-]?)([0-9]*)n(?:[ \\t\\n]*([+-])[ \\t\\n]*([0-9]+))?"];

cssAnB[{}, where_, pos_] := cssInvalid[where <> " needs an argument", pos];
cssAnB[items_, where_, _] :=
  With[{t = cssText[items]},
    Which[
      StringMatchQ[t, "odd", IgnoreCase -> True], {2, 1},
      StringMatchQ[t, "even", IgnoreCase -> True], {2, 0},
      StringMatchQ[t, RegularExpression["[+-]?[0-9]+"]], {0, ToExpression[StringDelete[t, "+"]]},
      StringMatchQ[t, $cssAnB],
        First @ StringCases[t, $cssAnB :> {
          If["$1" === "-", -1, 1] If["$2" === "", 1, FromDigits["$2"]],
          If["$4" === "", 0, If["$3" === "-", -1, 1] FromDigits["$4"]]}],
      True, cssInvalid[t <> " is not a valid An+B in " <> where, cssStart[First[items]]]]];

cssPseudoElement[c_, x_] :=
  With[{name = cssLower[If[MatchQ[x, _blk], x[[1, 2]], x[[2]]]], text = cssText[{c, x}]},
    If[If[MatchQ[x, _blk], MemberQ[$cssPseudoElementFunctions, name],
        MemberQ[$cssPseudoElements, name] || StringStartsQ[name, "-webkit-"]],
      sPseudoElement[text, cssStart[c], name],
      cssInvalid["unknown pseudo-element " <> text, cssStart[c]]]];

$cssNamespaceHow = "Namespaces are not supported in a CSS selector; give the tag or key as {namespace, name} in an XMLPattern.";
$cssComplexHow = "Its arguments can only be compound selectors, with no combinator.";
$cssComplexIsHow = "Its arguments can hold a combinator only when its compound is the whole selector, as in p:is(div p, section > p), and not inside :not() or :has().";

(* ---- Translation: selector lists ---- *)

(* A selector list whose selectors have the same links and differ, as parsed,
   in at most one compound, which has no position, is the shared chain, with
   the alternatives at that compound. Any other is the alternatives of its
   selectors' chains, in written order (ADR 0015). *)
cssListPattern[cs_] :=
  Replace[DeleteDuplicatesBy[Join @@ (cssSpreadIs /@ cs), cssShape], {
    {c_} :> cssChainPattern[c],
    u_ :> Replace[cssSharedChain[u], None :> cssAlternatives[cssChainPattern /@ u]]}];

cssSharedChain[u_] :=
  With[{comps = First /@ u},
    If[!(SameQ @@ (Last /@ u)), None,
      With[{diff = Select[Range[Length[First[comps]]], !(SameQ @@ cssShape /@ comps[[All, #]]) &]},
        If[Length[diff] > 1 || AnyTrue[comps[[All, First[diff]]], cssPositionedQ], None,
          cssChainPattern[cx[
            ReplacePart[First[comps], First[diff] -> cpAlt[DeleteDuplicatesBy[comps[[All, First[diff]]], cssShape]]],
            Last[First[u]]]]]]]];

cssPositionedQ[cp[nodes_, _]] :=
  MemberQ[nodes, _sNth] || AnyTrue[Cases[nodes, sPseudo[c_, _] :> c], KeyExistsQ[$cssPositions, #] || MatchQ[#, $cssRootPseudoClasses] &];

(* A selector of one compound whose :is() or :where() has an argument with a
   combinator is a selector list: each argument with the rest of the compound
   merged into its last compound, as p:is(div p) is div p.p. With a compound
   before it, x :is(a b) is an element with ancestors x and a in either order,
   whose expansion grows with the chains, so it is not translated (cssApply). *)
cssSpreadIs[cx[{cp[nodes_, text_]}, {}]] /; Count[nodes, _?cssComplexIsQ] == 1 :=
  With[{k = First[FirstPosition[nodes, _?cssComplexIsQ, None, {1}, Heads -> False]]},
    cssMergeInto[#, Delete[nodes, k], text] & /@ First[nodes[[k]]]];
cssSpreadIs[c_] := {c};

cssComplexIsQ[sIs[args_, _]] := !MatchQ[args, {cx[{_}, {}] ...}];
cssComplexIsQ[_] := False;

cssMergeInto[cx[comps_, links_], rest_, text_] :=
  cx[Append[Most[comps], cp[Join[First[Last[comps]], rest], text]], links];

(* A part of the tree without its source text and positions, which only
   messages use: compounds written differently, as with other quotes or
   keyword case, are equal when they parse alike. *)
cssShape[x_] := x //. {cp[n_, _String] :> cp[n], sPseudo[n_, _String] :> sPseudo[n], sNot[a_, _String] :> sNot[a],
  sIs[a_, _String] :> sIs[a], sHas[r_, _String] :> sHas[r], sPseudoElement[_String, _Integer, n_] :> sPseudoElement[n]};

(* ---- Translation: chains ---- *)

(* The stages and the links between them. A run of compounds joined by + or ~
   in which one has a child-indexed pseudo-class is one list stage over their
   parent's children (ADR 0016), as Adjacent and Sibling are shorthands for
   lists: after > or a descendant combinator it follows that link, and at the
   start of a chain it lists the children of any element or of the document
   (ADR 0018), so that it reaches the top elements. *)
cssChainPattern[cx[comps_, links_]] :=
  Module[{ts = cssCompoundT /@ comps, runs},
    If[MemberQ[links, cssColumn], cssRefuse["unsupported", "the column combinator ||", "Columns are not supported."]];
    runs = Split[Transpose[{ts, Prepend[links, None]}], MatchQ[Last[#2], Adjacent | Sibling] &];
    Apply[cssChain, Fold[cssAddRun, {{}, {}}, runs]]];

(* :root and :scope: the first compound, alone in its run, is the only child
   of the document, and its positions among its siblings are each 1 or never
   hold. *)
cssAddRun[{stages_, links_}, run_] /; AnyTrue[run[[All, 1]], MemberQ[Last[#], _cssRoot] &] :=
  If[stages === {} && Length[run] == 1,
    With[{part = run[[1, 1]]},
      {{XMLDocument[], If[AllTrue[Last[part], cssFirstQ], {}, {Except[_]}] ~Append~ First[part]}, {Child}}],
    cssRefuse["unsupported", First[FirstCase[Join @@ run[[All, 1, 3]], _cssRoot]], $cssRootHow]];

cssFirstQ[_cssRoot] := True;
cssFirstQ[cssPos[_, a_, b_, _, _]] :=
  Which[a == 0, b == 1, a > 0, b <= 1 && Mod[1 - b, a] == 0, True, b >= 1 && Mod[b - 1, -a] == 0];

cssAddRun[{stages_, links_}, run_] :=
  With[{lead = run[[1, 2]], parts = run[[All, 1]], within = Rest[run[[All, 2]]]},
    Which[
      AllTrue[parts, Last[#] === {} &],
        {Join[stages, First /@ parts], Join[links, DeleteCases[{lead}, None], within]},
      lead === None,
        {Join[stages, {XMLDocument[] | XMLPattern[_], cssRunList[parts, within]}], Append[links, Child]},
      True,
        {Append[stages, cssRunList[parts, within]], Append[links, lead]}]];

(* A run as a list: its compounds in order, + adding nothing between two and ~
   a ___, with a position of the first compound written as the entries before
   it and one of the last as the entries after it. A position among all the
   siblings of a compound joined to the first by + alone is one of the first,
   less the compounds between (.b + .a:nth-child(5) is .b at 4), and the same
   from the end. Where positions need more than that, the general form names
   every gap and compound, and tests the positions in a condition on the list.
   So does a position among the siblings of a type or that match a selector,
   other than the first or the last: repeats of Except[s] ..., s backtrack
   without bound (over 20 s for tr:nth-of-type(50) among 1,000 rows, against
   0.06 s as a condition). *)
cssRunList[parts_, within_] :=
  With[{k = Length[parts]},
    With[{
        forward = Join @@ MapIndexed[cssShifted[#1, First[#2] - 1, Take[within, First[#2] - 1]] &, Select[#[[3]], !First[#] &] & /@ parts],
        backward = Join @@ MapIndexed[cssShifted[#1, k - First[#2], Drop[within, First[#2] - 1]] &, Select[#[[3]], First] & /@ parts]},
      If[Length[forward] <= 1 && Length[backward] <= 1 && FreeQ[{forward, backward}, None, {2}] &&
          FreeQ[{forward, backward}, cssOwnType | (cssPos[_, a_, b_, Except[None], _] /; !(a == 0 && b == 1))],
        Join[cssPositionEntries[forward, False], cssRunEntries[First /@ parts, within], cssPositionEntries[backward, True]],
        cssGeneralList[parts, within]]]];

(* The positions of a compound s compounds from an end of its run, moved to
   that end over the links between, or None when they cannot move. *)
cssShifted[ps_, 0, _] := ps;
cssShifted[{}, _, _] := {};
cssShifted[ps_, s_, links_] /; MatchQ[links, {Adjacent ..}] && MatchQ[ps, {cssPos[_, _, _, None, _] ..}] :=
  Replace[ps, cssPos[e_, a_, b_, None, t_] :> cssPos[e, a, b - s, None, t], {1}];
cssShifted[_, _, _] := {None};

(* Each compound but the last, with the gap after it. *)
cssRunEntries[ps_, within_] := Append[Join @@ MapThread[Prepend[cssGap[#2], #1] &, {Most[ps], within}], Last[ps]];

cssGap[Adjacent] := {};
cssGap[Sibling] := {___};

(* The entries before a compound at index a k + b, k >= 0 among all its
   siblings, or after it when counted from the end. An index that no k gives
   never matches. The first or last among the siblings of a type or that match
   a selector has only those that do not before or after it. *)
cssPositionEntries[{}, _] := {___};
cssPositionEntries[{cssPos[_, 0, 1, of_, _]}, _] /; of =!= None := {Except[cssUnnamed[of]] ...};
cssPositionEntries[{cssPos[_, a_, b_, None, _]}, fromEnd_] :=
  If[fromEnd, Reverse, Identity] @ Which[
    a == 0, If[b < 1, {Except[_]}, cssRepeat[_, b - 1]],
    a > 0, Append[cssRepeat[_, If[b >= 1, b - 1, Mod[b - 1, a]]], RepeatedNull[cssUnits[a]]],
    b < 1, {Except[_]},
    True, Append[cssRepeat[_, Mod[b - 1, -a]], Repeated[cssUnits[-a], {0, Floor[(b - 1)/-a]}]]];

cssUnits[1] := _;
cssUnits[n_] := PatternSequence @@ ConstantArray[_, n];

(* A name inside Except is never bound, so a selector with names is tested whole. *)
cssUnnamed[of_] := If[FreeQ[of, Verbatim[Pattern]], of, With[{m = XMLMatchQ[of]}, _?m]];

cssRepeat[_, 0] := {};
cssRepeat[u_, 1] := {u};
cssRepeat[u_, r_] := {Repeated[u, {r}]};

(* When only the last compound has positions: {g___, c : C, g___} /; tests,
   with the compounds before it tested on the siblings before it as one
   pattern. Naming each compound and gap instead makes WL try every split
   before the test: 640 s for .b ~ .a:nth-child(500) among 1,000 rows. *)
cssGeneralList[parts_, within_] /; AllTrue[Most[parts], Last[#] === {} &] :=
  Module[{pre = cssFreshName["g"], post = cssFreshName["g"], n = Replace[Last[parts][[2]], None :> cssFreshName["c"]]},
    conditionWith[
      {Pattern @@ {pre, BlankNullSequence[]},
        If[Last[parts][[2]] === None, Pattern @@ {n, First[Last[parts]]}, First[Last[parts]]],
        Pattern @@ {post, BlankNullSequence[]}},
      cssAnd[Join[
        cssPositionTest[#, n, If[First[#], {post}, {pre}]] & /@ Last[Last[parts]],
        cssRunTest[Most[parts], within, pre]]]]];

(* The siblings before the last compound end with the others of the run, each
   tested whole, as a name in it could not be bound. *)
cssRunTest[{}, _, _] := {};
cssRunTest[ps_, within_, pre_] :=
  With[{l = pre, run = Join[{___}, Join @@ MapThread[Prepend[cssGap[#2], With[{m = XMLMatchQ[First[#1]]}, _?m]] &, {ps, within}]]},
    {Hold[MatchQ[{l}, run]]}];

(* {g___, c1 : C1, ..., ck : Ck, g___} /; tests, with a named gap before the
   first compound, after the last, and for each ~ between two. A compound
   that already names its element keeps that name. *)
cssGeneralList[parts_, within_] :=
  Module[{names = Replace[parts[[All, 2]], None :> cssFreshName["c"], {1}], entries, seq, places},
    entries = MapThread[If[#2 === None, Pattern @@ {#3, First[#1]}, First[#1]] &, {parts, parts[[All, 2]], names}];
    seq = Join[{cssFreshName["g"]},
      Join @@ MapThread[Prepend[If[#2 === Sibling, {cssFreshName["g"]}, {}], #1] &, {Most[names], within}],
      {Last[names], cssFreshName["g"]}];
    places = Flatten[Position[seq, #, {1}, Heads -> False] & /@ names];
    conditionWith[
      Replace[seq, Join[Thread[names -> entries], {n_Symbol :> Pattern @@ {n, BlankNullSequence[]}}], {1}],
      cssAnd[Join @@ MapThread[
        Function[{part, n, k}, cssPositionTest[#, n, If[First[#], Drop[seq, k], Take[seq, k - 1]]] & /@ Last[part]],
        {parts, names, places}]]]];

(* Whether the element named n is at its position, the siblings on that side
   being the names in side. Held, with no private symbol. *)
cssPositionTest[cssPos[_, a_, b_, of_, _], n_, side_] :=
  Replace[cssIndexHeld[of, n, side], Hold[i_] :> Which[
    a == 0, Hold[i == b],
    a > 0, Hold[i >= b && Mod[i - b, a] == 0],
    True, Hold[i <= b && Mod[b - i, -a] == 0]]];

cssIndexHeld[None, _, side_] := With[{l = side}, Hold[Length[l] + 1]];
cssIndexHeld[cssOwnType, n_, side_] := With[{l = side, e = n}, Hold[Count[l, XMLElement[First[e], _, _]] + 1]];
(* A tag is tested on the elements directly: XMLMatchQ per sibling costs 1.5 s
   for tr:nth-of-type(500) among 1,000 rows, against 0.06 s. *)
cssIndexHeld[XMLPattern[t_String], _, side_] := With[{l = side}, Hold[Count[l, XMLElement[t, _, _]] + 1]];
cssIndexHeld[of_, _, side_] := With[{l = side, m = XMLMatchQ[of]}, Hold[Count[l, _?m] + 1]];

(* Runs of one link use the n-ary form; mixed links are right-nested. *)
cssChain[{s_}, {}] := s;
cssChain[ss_, links_] :=
  With[{k = LengthWhile[links, # === First[links] &]},
    If[k == Length[links], First[links] @@ ss,
      First[links] @@ Append[Take[ss, k], cssChain[Drop[ss, k], Drop[links, k]]]]];

(* ---- Translation: compounds ---- *)

(* A compound is a list of branches, br[tag, attributes, tests], its
   alternatives: :is() and :checked give several. The tag is tg[allowed, or
   All, excluded]; the attributes map each key to its constraints; a test is
   held, with cssSelf for the compound's element. cssCompoundT gives {pattern,
   name or None, its positions among its siblings, each a cssPos, and
   cssRoot[text] for :root or :scope}. *)
cssCompoundT[cpAnchor] := {XMLPattern[$cssAnchor], None, {}};
(* The compounds that differ between the selectors of a list have no position
   (cssSharedChain checks their own nodes; a position inside :is() or :not()
   is refused when its branches are made). *)
cssCompoundT[cpAlt[cps_]] := {cssAlternatives[First @* cssCompoundT /@ cps], None, {}};
cssCompoundT[c : cp[nodes_, _]] :=
  With[{type = FirstCase[nodes, sType[n_] :> n, _]},
    Replace[cssBranches[c], {bs_, counts_} :>
      Append[cssFinish[bs, type], Replace[counts, cssPos[e_, a_, b_, "type", t_] :> cssPos[e, a, b, cssOfType[type], t], {1}]]]];

(* The siblings an -of-type position counts: those of the compound's type, or
   when it has none, those of the element's own tag. *)
cssOfType[type_String] := XMLPattern[type];
cssOfType[_] := cssOwnType;

(* The anchor wraps an element's children in :has(), so that they have a
   parent; its namespaced tag is in no document. *)
$cssAnchor = {"urn:x-beautifultureen:anchor", "anchor"};

$cssAny = br[tg[All, {}], <||>, {}];

cssBranches[cp[nodes_, _]] :=
  MapAt[DeleteDuplicates[Flatten[#]] &, Reap[Fold[cssApply, {$cssAny}, nodes], cssPosTag], 2];

cssWith[bs_, b_] := cssMerge[#, b] & /@ bs;
cssAttr[k_, c_] := br[tg[All, {}], <|k -> {c}|>, {}];
cssTest[t_Hold] := br[tg[All, {}], <||>, {t}];

cssMerge[br[t1_, a1_, s1_], br[t2_, a2_, s2_]] :=
  br[cssTagMerge[t1, t2], Merge[{a1, a2}, Apply[Join]], Join[s1, s2]];

cssTagMerge[tg[a1_, x1_], tg[a2_, x2_]] :=
  tg[Which[a1 === All, a2, a2 === All, a1, True, Select[a1, MemberQ[a2, #] &]], DeleteDuplicates[Join[x1, x2]]];

cssApply[bs_, sType[n_]] := cssWith[bs, br[tg[{n}, {}], <||>, {}]];
cssApply[bs_, sUniversal[]] := bs;
cssApply[bs_, sId[v_]] := cssWith[bs, cssAttr["id", eq[v]]];
cssApply[bs_, sClass[v_]] := cssWith[bs, cssAttr["classList", has[v]]];
cssApply[bs_, sAttr[n_]] := cssWith[bs, cssAttr[n, present]];
cssApply[bs_, sAttr[n_, m_, v_, f_]] := cssWith[bs, cssAttr[If[m === "~=", n <> "List", n], cssConstraint[m, v, f === "i"]]];
cssApply[bs_, sPseudo["link" | "any-link", _]] := cssWith[bs, br[tg[{"a", "area"}, {}], <|"href" -> {present}|>, {}]];
cssApply[bs_, sPseudo["empty", _]] := cssWith[bs, cssTest[$cssEmptyTest]];
cssApply[bs_, sPseudo["checked", _]] := Flatten[Outer[cssMerge, bs, $cssChecked], 1];
cssApply[bs_, sPseudo[c_, text_]] /; KeyExistsQ[$cssPositions, c] :=
  (Scan[Sow[cssPos[Sequence @@ #, text], cssPosTag] &, $cssPositions[c]]; bs);
(* A place in the tree, as a position is: the compound is a list stage. *)
cssApply[bs_, sPseudo[$cssRootPseudoClasses, text_]] := (Sow[cssRoot[text], cssPosTag]; bs);
(* of S: the element matches S, and is counted among the siblings that do. *)
cssApply[bs_, sNth[p_, None]] := (Sow[p, cssPosTag]; bs);
cssApply[bs_, sNth[cssPos[e_, a_, b_, "of", text_], args_]] := (
  Sow[cssPos[e, a, b, cssAlternatives[cssArgPattern[#, text] & /@ args], text], cssPosTag];
  Flatten[Outer[cssMerge, bs, Join @@ (cssArgBranches[#, text] & /@ args)], 1]);
cssApply[bs_, sNot[args_, text_]] := cssNot[bs, args, text];
cssApply[bs_, sIs[args_, text_]] := Flatten[Outer[cssMerge, bs, Join @@ (cssArgBranches[#, text] & /@ args)], 1];
cssApply[bs_, sHas[rels_, text_]] := cssWith[bs, cssTest[cssOr[cssHasTest[#, text] & /@ rels]]];
cssApply[_, sRefuse[kind_, part_, how_]] := cssRefuse[kind, part, how];
cssApply[_, sPseudoElement[text_, _, name_]] := cssRefuse["impossible", text, cssPseudoElementHow[name]];

(* Whitespace-only text counts as empty, and comments and processing
   instructions are ignored, as in Selectors 4. *)
$cssEmptyTest = Hold[MatchQ[Last[cssSelf],
  {(_String?(StringMatchQ["" | HTMLWhitespace]) | XMLObject["Comment" | "ProcessingInstruction"][___]) ...}]];

(* type is an enumerated attribute, which HTML matches ASCII case-insensitively. *)
$cssChecked = {
  br[tg[{"input"}, {}], <|"type" -> {checkedType}, "checked" -> {present}|>, {}],
  br[tg[{"option"}, {}], <|"selected" -> {present}|>, {}]};

(* An argument of :is() or :where() is merged into the compound. *)
cssArgBranches[cx[{c_}, {}], text_] := cssUnpositioned[cssBranches[c], " inside " <> text, $cssChildIndexedHow];
cssArgBranches[_, text_] := cssRefuse["unsupported", text, $cssComplexIsHow];

(* An argument of :not() or :has() is a pattern of its own, with its own names. *)
cssArgPattern[cx[{c_}, {}], text_] := cssUnpositioned[cssCompoundT[c], " inside " <> text, $cssChildIndexedHow];
cssArgPattern[_, text_] := cssRefuse["unsupported", text, $cssComplexHow];

(* A compound's pattern or branches, which must have no position: a compound
   with one is a list stage, not an element pattern. *)
cssUnpositioned[{x_, {}}, _, _] := x;
cssUnpositioned[{x_, _, {}}, _, _] := x;
cssUnpositioned[{__, counts_List}, where_, how_] :=
  Replace[FirstCase[counts, _cssRoot, None], {
    None :> cssRefuse["unsupported", Last[First[counts]] <> where, how],
    cssRoot[text_] :> cssRefuse["unsupported", text <> where, $cssRootInsideHow]}];

(* :not() of one class or one type merges into the class list or the tag, so a
   classless element matches, as in CSS; otherwise it is a condition, never an
   Except at a raw key, which would require the attribute. The operator form
   keeps its compiled matcher, for the readings in force, so the argument is
   compiled once per query rather than once per candidate. *)
cssNot[bs_, {cx[{cp[{sClass[c_]}, _]}, {}]}, _] := cssWith[bs, cssAttr["classList", lacks[c]]];
cssNot[bs_, {cx[{cp[{sType[n_]}, _]}, {}]}, _] := cssWith[bs, br[tg[All, {n}], <||>, {}]];
cssNot[bs_, args_, text_] :=
  With[{p = cssAlternatives[cssArgPattern[#, text] & /@ args]},
    cssWith[bs, cssTest[Hold[! XMLMatchQ[p][cssSelf]]]]];

(* :has(s) and :has(> s) for one compound test the children; any other
   relative selector runs as a chain from an anchor around the children, so
   that siblings among them are siblings. *)
cssHasTest[rel[Adjacent | Sibling | cssColumn, _], text_] :=
  cssRefuse["unsupported", text, "A relative selector in :has() can only start with a descendant combinator or >."];
cssHasTest[rel[link_, cx[comps_, links_]], _] :=
  Replace[If[links === {}, cssCompoundT[First[comps]], None], {
    {p_, _, {}} :> cssHasChild[link, p],
    _ :> With[{chain = cssChainPattern[cx[Prepend[comps, cpAnchor], Prepend[links, link]]], a = $cssAnchor},
      Hold[! MissingQ[XMLFirstCase[XMLElement[a, {}, Last[cssSelf]], chain]]]]}];

(* The children are filtered to elements, as a list given to XMLFirstCase can
   hold only elements and strings, and an XML document's can hold comments. *)
cssHasChild[Child, p_] := Hold[AnyTrue[Last[cssSelf], XMLMatchQ[p]]];
cssHasChild[Descendant, p_] := Hold[! MissingQ[XMLFirstCase[Cases[Last[cssSelf], _XMLElement], p]]];

cssAnd[{t_}] := t;
cssAnd[ts_] := Replace[Join @@ ts, Hold[xs___] :> Hold[And[xs]]];
cssOr[{t_}] := t;
cssOr[ts_] := Replace[Join @@ ts, Hold[xs___] :> Hold[Or[xs]]];

cssAlternatives[{p_}] := p;
cssAlternatives[ps_] := Alternatives @@ ps;

(* The pattern of a compound, from its branches: a branch whose tag can never
   match is dropped, and with none left the compound is XMLPattern[tag] /;
   False. The tests of a compound are on one name. *)
cssFinish[bs_, type_] :=
  Module[{live = Select[bs, cssTagPattern[First[#]] =!= cssNever &], name},
    name = If[AnyTrue[live, Last[#] =!= {} &], cssFreshName["e"], None];
    {Which[
      live === {}, cssConditioned[XMLPattern[type], name, {Hold[False]}],
      SameQ @@ (Last /@ live), cssConditioned[cssAlternatives[cssElement /@ live], name, Last[First[live]]],
      True, Alternatives @@ (cssConditioned[cssElement[#], name, Last[#]] & /@ live)],
     name}];

cssConditioned[p_, None, {}] := p;
cssConditioned[p_, None, ts_] := conditionWith[p, cssAnd[ts]];
cssConditioned[p_, n_, {}] := Pattern @@ {n, p};
cssConditioned[p_, n_, ts_] := conditionWith[Pattern @@ {n, p}, cssAnd[ts] /. cssSelf -> n];

cssElement[br[t_, a_, _]] :=
  With[{tag = cssTagPattern[t], rules = KeyValueMap[cssRule, a]},
    Switch[Length[rules], 0, XMLPattern[tag], 1, XMLPattern[tag, First[rules]], _, XMLPattern[tag, rules]]];

cssTagPattern[tg[All, {}]] := _;
cssTagPattern[tg[All, {x_}]] := _?(# =!= x &);
cssTagPattern[tg[All, xs_]] := cssPatternTest[_, Function @@ cssAnd[cssNotTag /@ xs]];
cssTagPattern[tg[allowed_, xs_]] :=
  Replace[Select[allowed, !MemberQ[xs, #] &], {{} -> cssNever, {t_} :> t, ts_ :> Alternatives @@ ts}];

cssNotTag[x_] := Hold[# =!= x];

(* PatternTest holds its test, which is built here. *)
cssPatternTest[p_, f_] := PatternTest[p, f];

(* A temporary symbol in the caller's context, as Module makes one: no name
   the caller writes can be it. *)
cssFreshName[base_] :=
  Module[{name},
    While[NameQ[name = $Context <> base <> "$" <> ToString[$ModuleNumber++]]];
    With[{s = Symbol[name]}, SetAttributes[s, Temporary]; s]];

(* ---- Translation: attribute values ---- *)

(* XMLPattern refuses a key given twice, so every constraint on one key is
   merged into one value pattern. A raw key holds present, never, eq, eqI,
   dash, dashI, pre, preI, suf, sufI, sub, subI or checkedType; a list key
   holds has, hasI or lacks. The I forms hold their value folded. *)
cssConstraint["~=", v_, False] := has[v];
cssConstraint["~=", v_, True] := hasI[cssLower[v]];
cssConstraint["=", v_, False] := eq[v];
cssConstraint["=", v_, True] := eqI[cssLower[v]];
cssConstraint["|=", v_, False] := dash[v];
cssConstraint["|=", v_, True] := dashI[cssLower[v]];
(* An empty value of ^=, $= or *= represents nothing (Selectors 4, 6.2). *)
cssConstraint["^=" | "$=" | "*=", "", _] := never;
cssConstraint["^=", v_, i_] := If[i, preI[cssLower[v]], pre[v]];
cssConstraint["$=", v_, i_] := If[i, sufI[cssLower[v]], suf[v]];
cssConstraint["*=", v_, i_] := If[i, subI[cssLower[v]], sub[v]];

cssRule[k_, cs_] := Replace[If[MemberQ[cs, _has | _hasI | _lacks], cssListValue[cs], cssRawValue[cs]], {None -> k, v_ :> k -> v}];

(* A value implies presence, and an exact value decides every other
   constraint at once. *)
cssRawValue[cs_] :=
  With[{c = DeleteDuplicates[DeleteCases[cs, present]]},
    Which[
      MemberQ[c, never], Except[_],
      c === {}, None,
      MemberQ[c, _eq], With[{v = FirstCase[c, eq[v_] :> v]}, If[AllTrue[c, TrueQ[(Function @@ cssSlot[#])[v]] &], v, Except[_]]],
      Length[c] == 1, cssSingle[First[c]],
      True, cssPatternTest[_, Function @@ cssAnd[cssSlot /@ c]]]];

cssListValue[cs_] :=
  With[{h = DeleteDuplicates[Cases[cs, has[v_] :> v]], l = DeleteDuplicates[Cases[cs, lacks[v_] :> v]],
      hi = DeleteDuplicates[Cases[cs, hasI[v_] :> v]]},
    Which[
      IntersectingQ[h, l], Except[_],
      hi === {} && l === {}, If[Length[h] == 1, First[h], _?(ContainsAll[h])],
      hi === {} && h === {}, If[Length[l] == 1, With[{c = First[l]}, _?(FreeQ[c])], _?(ContainsNone[l])],
      True, cssPatternTest[_, Function @@ cssAnd[Join[
        If[h === {}, {}, {Hold[ContainsAll[#, h]]}],
        If[l === {}, {}, {Hold[ContainsNone[#, l]]}],
        cssSlot[hasI[#]] & /@ hi]]]]];

(* A constraint alone, as the value pattern. *)
cssSingle[eq[v_]] := v;
cssSingle[dash[v_]] := With[{w = v <> "-"}, v | _?(StringStartsQ[w])];
cssSingle[pre[v_]] := _?(StringStartsQ[v]);
cssSingle[suf[v_]] := _?(StringEndsQ[v]);
cssSingle[sub[v_]] := _?(StringContainsQ[v]);
cssSingle[checkedType] := _?(StringMatchQ["checkbox" | "radio", IgnoreCase -> True]);
cssSingle[c_] := cssPatternTest[_, Function @@ cssSlot[c]];

(* A constraint as a held test on #, to be joined with others. The i flag
   folds A-Z only, on both sides, as Selectors requires: IgnoreCase would
   also fold letters such as \[CapitalEAcute]. *)
cssSlot[eq[v_]] := Hold[# === v];
cssSlot[eqI[v_]] := With[{f = $cssFold}, Hold[f[#] === v]];
cssSlot[dash[v_]] := With[{w = v <> "-"}, Hold[# === v || StringStartsQ[#, w]]];
cssSlot[dashI[v_]] := With[{f = $cssFold, w = v <> "-"}, Hold[f[#] === v || StringStartsQ[f[#], w]]];
cssSlot[pre[v_]] := Hold[StringStartsQ[#, v]];
cssSlot[preI[v_]] := With[{f = $cssFold}, Hold[StringStartsQ[f[#], v]]];
cssSlot[suf[v_]] := Hold[StringEndsQ[#, v]];
cssSlot[sufI[v_]] := With[{f = $cssFold}, Hold[StringEndsQ[f[#], v]]];
cssSlot[sub[v_]] := Hold[StringContainsQ[#, v]];
cssSlot[subI[v_]] := With[{f = $cssFold}, Hold[StringContainsQ[f[#], v]]];
cssSlot[checkedType] := Hold[StringMatchQ[#, "checkbox" | "radio", IgnoreCase -> True]];
cssSlot[hasI[v_]] := With[{f = $cssFold}, Hold[MemberQ[f[#], v]]];

(* =========================================================== *)
(* HTMLTextContent                                             *)
(* Lossless tree-fold: concatenate every descendant string in  *)
(* document order, inserting/removing no whitespace.           *)
(*                                                              *)
(* Public arm validates with validTreeQ (same input surface as *)
(* XMLCases) and delegates to the internal total walk; the      *)
(* walk never messages, so stray non-element/non-string nodes   *)
(* (comments, declarations) silently contribute "" mid-tree.    *)
(* =========================================================== *)

HTMLTextContent[tree_] := textContentWalk[tree] /; validTextInputQ[tree];

HTMLTextContent[tree_] :=
  (Message[HTMLTextContent::badtree, Head[tree]]; $Failed) /; !validTextInputQ[tree];

HTMLTextContent[args___] /; (countMessage[HTMLTextContent, {args}, {1, 1}]; False) := Null;

(* Internal total recursion \[LongDash] every node contributes a string *)
textContentWalk[XMLObject["Document"][_, root_, _]] := textContentWalk[root];
textContentWalk[XMLElement[_, _, children_List]] :=
  StringJoin[textContentWalk /@ children];
textContentWalk[s_String] := s;
textContentWalk[l_List] := StringJoin[textContentWalk /@ l];
textContentWalk[_] := "";

(* =========================================================== *)
(* Display-role substrate (shared Layer 1)                     *)
(*                                                              *)
(* The classification that both readable-text extraction        *)
(* (HTMLInnerText) and notebook conversion (HTMLToNotebook)     *)
(* build on. Each element is classified by tag alone (the       *)
(* frozen user-agent stylesheet) into one of five display       *)
(* roles \[LongDash] Block, Inline, Preformatted, LineBreak, Skip \[LongDash] with   *)
(* a user "Roles" override layer (ruleLookups + roleOf). The   *)
(* emitters that sit on top of this substrate then decide *what *)
(* form* each placed element takes (HTMLInnerText: text; *)
(* HTMLToNotebook: a Cell or box \[LongDash] its own Layer 2). roleOf is   *)
(* message-head-parameterized so each public function reports   *)
(* a bad role rule under its own ::badrole.                     *)
(* =========================================================== *)

(* ---- Frozen UA tables: WHATWG HTML 15 "Rendering" defaults ---- *)
$htmlBlockTags = {"html", "body", "address", "article", "aside", "blockquote",
  "center", "dd", "details", "summary", "dialog", "dir", "div", "dl", "dt",
  "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3", "h4",
  "h5", "h6", "header", "hgroup", "hr", "legend", "li", "main", "menu", "nav",
  "ol", "p", "section", "search", "table", "caption", "colgroup", "thead",
  "tbody", "tfoot", "tr", "td", "th", "ul"};
$htmlPreTags = {"pre", "listing", "plaintext", "xmp", "textarea"};
$htmlSkipTags = {"script", "style", "head", "title", "template", "datalist",
  "link", "meta", "base", "noscript"};

(* Collapse every run of whitespace to a single space \[LongDash] the Normal-whitespace
   primitive shared by both emitters. *)
normWS[s_String] := StringReplace[s, Whitespace .. -> " "];

defaultRole[tag_String] := Which[
  MemberQ[$htmlSkipTags, tag], "Skip",
  tag === "br",               "LineBreak",
  MemberQ[$htmlPreTags, tag],  "Preformatted",
  MemberQ[$htmlBlockTags, tag], "Block",
  True,                        "Inline"];
defaultRole[_] := "Inline";

(* ---- Role rules: an Association sugars to an ordered rule list; first
   match wins. A string left-hand side is a CSS selector, as anywhere an XML
   pattern goes. ---- *)
$displayRoles = {"Block", "Inline", "Preformatted", "LineBreak", "Skip"};
validRoleQ[r_] := MemberQ[$displayRoles, r];

(* Each rule's left-hand side is compiled like a query, and must be an element
   pattern: a rule is tried against one element at a time. compileRule gives
   {rule, readings}, the readings being those of the list keys it names, or
   $Failed for an entry that is refused, a non-rule among them. *)
compileRule[Verbatim[Rule][lhs_, r_], head_, readings_] :=
  Replace[elementQuery[compileWith[lhs, head, readings], lhs, head, "badpat"],
    c_Association :> {c["Plain"] -> r, c["Readings"]}];
compileRule[rule_RuleDelayed, head_, readings_] :=
  Replace[
    elementQuery[
      compileWith[RuleDelayed @@ Join[Hold @@ {rule[[1]]}, Extract[rule, {2}, Hold]], head, readings],
      rule[[1]], head, "badpat"],
    c_Association :> {c["Plain"], c["Readings"]}];
compileRule[x_, head_, _] := With[{h = head}, Message[MessageName[h, "notrule"], x]; $Failed];

(* ruleLookups[{rules1, rules2, ...}, head, tree]: for each rule set, a
   function from an element of tree to the value of the first rule that matches
   it, or noRule; $Failed if any set is refused. The readings table is resolved
   once for them all. A rule naming a list key is matched on the element with
   its token lists attached, each distinct raw value on the tree split once;
   the element itself is never changed, so a caller walks the tree as it is. *)
ruleLookups[sets_List, head_, tree_] :=
  With[{readings = readingsInForce[]},
    If[readings === $Failed, $Failed,
      With[{lookups = ruleLookup[#, head, readings, tree] & /@ sets},
        If[MemberQ[lookups, $Failed], $Failed, lookups]]]];

ruleLookup[rules_, head_, readings_, tree_] :=
  With[{cs = compileRule[#, head, readings] & /@ If[AssociationQ[rules], Normal[rules], Flatten[{rules}]]},
    If[MemberQ[cs, $Failed], $Failed,
      With[{rs = Append[cs[[All, 1]], _ -> noRule], attach = materialiser[tree, Union @@ cs[[All, 2]]]},
        Replace[attach[#], rs] &]]];

(* roleOf: first matching rule wins; a non-role RHS messages (under the caller's
   own ::badrole) and defers to the frozen table; no match defers to the table;
   unknown tag -> Inline. *)
roleOf[el : XMLElement[tag_, _, _], lookup_, msgHead_] :=
  With[{r = lookup[el]},
    Which[
      MatchQ[r, noRule | _XMLElement], defaultRole[tag],
      validRoleQ[r],          r,
      True, (Message[MessageName[msgHead, "badrole"], r]; defaultRole[tag])
    ]];

(* =========================================================== *)
(* HTMLInnerText                                               *)
(* Readable text over the display-role substrate. A two-pass    *)
(* fold turns the classified tree into text:                    *)
(*   Pass A (itToks): tree -> flat token stream; the preserve   *)
(*     whitespace flag is threaded down, box/skip/break are     *)
(*     decided locally.                                         *)
(*   Pass B (itSerialize): tokens -> string; collapse runs,     *)
(*     strongest-glue-wins between content, coalesce breaks,    *)
(*     trim both ends (glue is gated on a non-empty accumulator).*)
(* Public arms validate (validTextInputQ) and message on bad    *)
(* input; the internal walk is total so stray nodes contribute  *)
(* nothing mid-tree.                                            *)
(* =========================================================== *)

(* ---- Pass A: tree -> token stream (itV = verbatim text; itNl = <br>;
   itBr = block boundary). The preserve flag rides down the recursion. ---- *)
itToks[s_String, False, _] := {s};
itToks[s_String, True, _] := {itV[s]};
itToks[l_List, pre_, rules_] := Flatten[itToks[#, pre, rules] & /@ l];
itToks[el : XMLElement[_, _, ch_], pre_, rules_] :=
  Switch[roleOf[el, rules, HTMLInnerText],
    "Skip",         {},
    "LineBreak",    {itNl},
    "Preformatted", Join[{itBr}, Flatten[itToks[#, True, rules] & /@ ch], {itBr}],
    "Block",        Join[{itBr}, Flatten[itToks[#, pre, rules] & /@ ch], {itBr}],
    _,              Flatten[itToks[#, pre, rules] & /@ ch]];
itToks[_, _, _] := {};

(* ---- Pass B: tokens -> atoms -> string. Words and soft spaces from normal
   text; verbatim text is one opaque atom; break markers pass through. ---- *)
atomize[s_String] := StringCases[normWS[s],
  {" " -> itSp, ww : (Except[" "] ..) :> itWd[ww]}];
atomize[itV[s_]] := {itVd[s]};
atomize[x_] := {x};

contentQ[itWd[_] | itVd[_]] := True;
contentQ[_] := False;
contentText[itWd[s_]] := s;
contentText[itVd[s_]] := s;

atomRank[itSp] := 1;
atomRank[itNl] := 2;
atomRank[itBr] := 3;
atomRank[_] := 0;

glueStr[1, _] := " ";
glueStr[2, _] := "\n";
glueStr[3, bsep_] := bsep;
glueStr[_, _] := "";

itSerialize[toks_, bsep_] :=
  First @ Fold[
    Function[{state, a},
      With[{out = First[state], glue = Last[state]},
        If[contentQ[a],
          {out <> If[out =!= "", glueStr[glue, bsep], ""] <> contentText[a], 0},
          {out, Max[glue, atomRank[a]]}
        ]]],
    {"", 0},
    Flatten[atomize /@ toks]];

(* ---- Public interface ---- *)
Options[HTMLInnerText] = {"Roles" -> {}, "BlockSeparator" -> "\n", "AttributeReadings" -> <||>};

HTMLInnerText[XMLObject["Document"][_, root_, _], opts : OptionsPattern[]] :=
  HTMLInnerText[root, opts];

HTMLInnerText[tree_, opts : OptionsPattern[]] :=
  withReadings[OptionValue["AttributeReadings"],
    Replace[ruleLookups[{OptionValue["Roles"]}, HTMLInnerText, tree], {
      $Failed -> $Failed,
      {roles_} :> itSerialize[Flatten[itToks[tree, False, roles]], OptionValue["BlockSeparator"]]}]
  ] /; validTextInputQ[tree];

HTMLInnerText[tree_, OptionsPattern[]] :=
  (Message[HTMLInnerText::badtree, Head[tree]]; $Failed) /; !validTextInputQ[tree];

HTMLInnerText[args___] /; (countMessage[HTMLInnerText, {args}, {1, 1}]; False) := Null;

(* =========================================================== *)
(* HTMLToNotebook                                              *)
(* The notebook emitter \[LongDash] the second function over the display- *)
(* role substrate. Layer 1 (roleOf) decides block-vs-inline    *)
(* placement; Layer 2 (the construct map) decides the form each *)
(* placed element takes: an inline box for an inline element, a *)
(* cell-style for a block. The walk recurses-and-flattens \[LongDash]      *)
(* block children become their own cells, nesting surviving     *)
(* only through style-name depth (Item/Subitem/...). The leaf-  *)
(* collapsing exceptions (pre, blockquote, table) collapse a    *)
(* whole subtree into one cell instead of recursing.            *)
(*                                                              *)
(* Threaded context (ctx) carries: the ambient block cell-style *)
(* ("blk", default "Text") that buffered inline runs land in;   *)
(* the list "depth"/"ord"ered flags; the blockquote "qd" depth; *)
(* "inLink", set inside a link; and the normalized              *)
(* "roles"/"constructs" override rules.                         *)
(* =========================================================== *)

(* ---- Construct map (Layer 2) ---- *)

(* The closed set of inline construct tokens. A construct RHS that is a string
   is an inline token when it is in this set, otherwise a block cell-style. *)
$inlineConstructs = {"Bold", "Italic", "Underline", "StrikeThrough", "Code",
  "Hyperlink", "Plain"};
(* Tokens that wrap their inner boxes in a StyleBox (Hyperlink/Plain differ). *)
$styleTokens = {"Bold", "Italic", "Underline", "StrikeThrough", "Code"};

(* A construct value that is neither a string nor None is a constructor
   function, applied to the matched element (the universal escape hatch) as it
   is in the tree: the element is stripped of any materialised token lists. *)
functionConstructQ[c_] := c =!= None && !StringQ[c];
(* A string construct destined for a block cell-style (not an inline token). *)
blockStyleQ[c_String] := !MemberQ[$inlineConstructs, c];
blockStyleQ[_] := False;

(* Default construct map: the frozen UA stylesheet read for font rendering
   (inline) plus the structural block styles. Tried after the user rules,
   first match wins; an unmatched element gets no construct (None). img/table/hr
   are themselves built-in constructor-function rules; img's and table's also
   take the context. *)
(* Plain XMLElement patterns: an XMLPattern is inert, and these name no list
   key, so they are what compiling XMLPattern[tag] would give. *)
$defaultConstructRules = {
  XMLElement["h1", _, _] -> "Title",
  XMLElement["h2", _, _] -> "Chapter",
  XMLElement["h3", _, _] -> "Section",
  XMLElement["h4", _, _] -> "Subsection",
  XMLElement["h5", _, _] -> "Subsubsection",
  XMLElement["h6", _, _] -> "Subsubsubsection",
  XMLElement["p", _, _] -> "Text",
  XMLElement["li", _, _] -> "Item",
  XMLElement["b" | "strong", _, _] -> "Bold",
  XMLElement["i" | "em" | "cite" | "var" | "dfn", _, _] -> "Italic",
  XMLElement["u" | "ins", _, _] -> "Underline",
  XMLElement["s" | "del" | "strike", _, _] -> "StrikeThrough",
  XMLElement["code" | "kbd" | "samp" | "tt", _, _] -> "Code",
  XMLElement["a", _, _] -> "Hyperlink",
  XMLElement["img", _, _] :> contextConstruct[imageConstruct],
  XMLElement["span" | "mark" | "small" | "q" | "abbr" | "sub" | "sup" |
    "time" | "label" | "bdi" | "bdo" | "data" | "ruby" | "rt" | "rp" |
    "wbr", _, _] -> "Plain",
  XMLElement["table", _, _] :> contextConstruct[tableConstruct],
  XMLElement["hr", _, _] :> hrConstruct
};

(* First user rule wins, else the default map, else None. *)
constructOf[el_XMLElement, ctx_] :=
  With[{r = Replace[ctx["constructs"][el], noRule :> Replace[el, $defaultConstructRules]]},
    If[MatchQ[r, _XMLElement], None, r]];

(* ---- Inline emission: node -> list of box atoms (strings + boxes) ---- *)

boxRow[{}] := "";
boxRow[{x_}] := x;
boxRow[xs_List] := RowBox[xs];

(* The spaces at the start and at the end of a string *)
$leadingSpaces = StartOfString ~~ " " ..;
$trailingSpaces = " " .. ~~ EndOfString;

(* Collapse whitespace across atom boundaries, as HTMLInnerText does: a string's
   leading spaces go when the atom before it ends in a space or is a line break
   ("\n"), and the spaces before a line break go. Empty strings are dropped.
   This does not reuse HTMLInnerText's atomize/itSerialize (ADR 0002): those
   reduce a token stream to one string, while these atoms include boxes that
   must stay in place, with each element's edge spaces kept outside its form. *)
joinSpaces[a_List] := Fold[joinAtom, {}, a];
joinAtom[acc_, ""] := acc;
joinAtom[{}, x_] := {x};
joinAtom[acc_, "\n"] :=
  Append[DeleteCases[MapAt[stripSpaces[#, $trailingSpaces] &, acc, -1], "", {1}], "\n"];
joinAtom[acc_, s_String] /; spaceEndQ[Last[acc]] :=
  DeleteCases[Append[acc, stripSpaces[s, $leadingSpaces]], "", {1}];
joinAtom[acc_, x_] := Append[acc, x];

spaceEndQ[s_String] := StringEndsQ[s, " " | "\n"];
spaceEndQ[_] := False;
stripSpaces[s_String, p_] := StringDelete[s, p];
stripSpaces[x_, _] := x;

(* Split a joined atom list into its leading edge, core and trailing edge. An
   edge is the whitespace-only strings (spaces, line breaks) at that end, plus
   the spaces at that end of the outermost string of the core. *)
blankQ[s_String] := StringMatchQ[s, Whitespace ...];
blankQ[_] := False;
splitEdges[a_List] :=
  With[{i = LengthWhile[a, blankQ]},
    If[i === Length[a], {a, {}, {}},
      With[{j = LengthWhile[Reverse[a], blankQ]},
        peelSpaces[Take[a, i], a[[i + 1 ;; -j - 1]], Take[a, -j]]]]];
peelSpaces[lead_, core_, trail_] :=
  With[{leadSpace = edgeSpace[First[core], $leadingSpaces],
        trailSpace = edgeSpace[Last[core], $trailingSpaces]},
    {Join[lead, leadSpace],
     MapAt[stripSpaces[#, $trailingSpaces] &,
       MapAt[stripSpaces[#, $leadingSpaces] &, core, 1], -1],
     Join[trailSpace, trail]}];
(* {" "} when a string has spaces where p looks for them, else {} *)
edgeSpace[s_String, p_] := If[StringContainsQ[s, p], {" "}, {}];
edgeSpace[_, _] := {};

(* The core of an inline run: boundary whitespace collapsed, edges trimmed. *)
trimAtoms[a_List] := splitEdges[joinSpaces[a]][[2]];

(* Does an atom list carry real content (a box, or non-blank text)? *)
realQ[a_List] := !AllTrue[a, blankQ];

(* Inside boxes the front end draws "-" as a minus sign; with operator
   substitution off it is drawn as typed. A blockquote's text cell, inline code
   and a table's Grid all need this. *)
$noOperatorSubstitution = PrivateFontOptions -> {"OperatorSubstitution" -> False};

(* Inline code and a table's Grid are typeset as input; these options show
   their text verbatim: no syntax coloring, no "->" drawn as an arrow, "-" drawn
   as a hyphen. *)
$verbatimTextOptions = {ShowAutoStyles -> False, AutoOperatorRenderings -> {},
  $noOperatorSubstitution};

styleBox["Bold", inner_] := StyleBox[boxRow[inner], FontWeight -> Bold];
styleBox["Italic", inner_] := StyleBox[boxRow[inner], FontSlant -> Italic];
styleBox["Underline", inner_] :=
  StyleBox[boxRow[inner], FontVariations -> {"Underline" -> True}];
styleBox["StrikeThrough", inner_] :=
  StyleBox[boxRow[inner], FontVariations -> {"StrikeThrough" -> True}];
styleBox["Code", inner_] :=
  FrameBox[StyleBox[boxRow[inner], "Code", Sequence @@ $verbatimTextOptions]];

(* An inline atom that is boxes, not text, goes into TextData as an inline
   Cell[BoxData[...]]; placed bare, the front end shows it as its box text. A
   string, a Cell, a ButtonBox or a StyleBox of text is text already. *)
textAtomQ[_String | _Cell | _ButtonBox] := True;
textAtomQ[StyleBox[x_, ___]] := textAtomQ[x];
textAtomQ[RowBox[xs_List]] := AllTrue[xs, textAtomQ];
textAtomQ[_] := False;
inlineCell[b_] := If[textAtomQ[b], b, Cell[BoxData[b]]];

(* Hyperlink reads href, falling back to src; the label is the inner boxes, or
   the alt text / URL when there are none. No usable href -> Plain. (img has its
   own built-in construct; src and alt matter here when a rule maps img to
   Hyperlink.) *)
linkHref[XMLElement[_, attrs_, _]] :=
  With[{a = Association[attrs]}, Lookup[a, "href", Lookup[a, "src", None]]];
(* The alt attribute as text: whitespace collapsed and trimmed; default when
   there is no alt. *)
altText[a_Association, default_] :=
  If[KeyExistsQ[a, "alt"], StringTrim[normWS[a["alt"]]], default];

usableURLQ[url_] := url =!= None && url =!= "";
linkBox[label_, url_] := ButtonBox[label, BaseStyle -> "Hyperlink", ButtonData -> {URL[url], None}];

hyperResult[el_, inner_] :=
  With[{href = linkHref[el]},
    If[!usableURLQ[href],
      inner,
      {linkBox[If[inner === {}, altText[Association[el[[2]]], href], boxRow[inner]], href]}]];

(* The img default gives its text, never its URL: the alt text, or "image" when
   there is no alt. alt="" marks a decorative image, which gives nothing. The
   text links to src, except inside a link, where it is part of that link's
   label. An img given a block role gives nothing, as it has no content. *)
imageConstruct[el : XMLElement[_, attrs_, _], ctx_] :=
  With[{a = Association[attrs]}, {label = altText[a, "image"], src = Lookup[a, "src", None]},
    Which[
      roleOf[el, ctx["roles"], HTMLToNotebook] =!= "Inline", {},
      label === "",                               {},
      TrueQ[ctx["inLink"]] || !usableURLQ[src],   {label},
      True,                                       {linkBox[label, src]}]];

(* Every atom of the form goes through inlineCell, so that a constructor
   function's boxes and inline code's frame (styleBox gives a FrameBox for
   "Code", as a StyleBox draws no frame) become inline cells. *)
inlineForm[c_, el_, inner_, ctx_] :=
  inlineCell /@ Which[
    functionConstructQ[c], Flatten[{applyConstruct[c, el, ctx]}],
    c === "Hyperlink",     hyperResult[el, inner],
    inner === {},          {},
    MemberQ[$styleTokens, c], {styleBox[c, inner]},
    True,                  inner   (* "Plain", None, or a block style placed inline *)
  ];

inlineBoxes[s_String, _] := {normWS[s]};
inlineBoxes[el : XMLElement[_, _, ch_], ctx_] :=
  Switch[roleOf[el, ctx["roles"], HTMLToNotebook],
    "Skip",      {},
    "LineBreak", {"\n"},
    _,           With[{c = constructOf[el, ctx]}, {innerCtx = childCtx[c, el, ctx]},
                   edgedForm[c, el, ctx,
                     splitEdges[joinSpaces@Flatten[inlineBoxes[#, innerCtx] & /@ ch]]]]];
inlineBoxes[_, _] := {};

(* An element's edge whitespace goes outside its form, so that formatting does
   not cover it and it can collapse with its neighbours'. *)
edgedForm[c_, el_, ctx_, {lead_, core_, trail_}] :=
  Join[lead, inlineForm[c, el, core, ctx], trail];

(* The children of an element that becomes a link are inside a link. *)
childCtx["Hyperlink", el_, ctx_] /; usableURLQ[linkHref[el]] := <|ctx, "inLink" -> True|>;
childCtx[_, _, ctx_] := ctx;

(* ---- Block emission: walk children, buffering inline runs into cells of the
   ambient block style and recursing on block children. ---- *)

nodeRole[_String, _] := "Inline";
nodeRole[el_XMLElement, ctx_] := roleOf[el, ctx["roles"], HTMLToNotebook];
nodeRole[_, _] := "Skip";

flushBuf[cells_, buf_, ctx_] :=
  With[{run = trimAtoms[buf]},
    If[realQ[run], Append[cells, Cell[TextData[run], ctx["blk"]]], cells]];

blockEmit[children_List, ctx_] :=
  Module[{res},
    res = Fold[
      Function[{acc, node},
        With[{cells = acc[[1]], buf = acc[[2]]},
          Switch[nodeRole[node, ctx],
            "Skip",                acc,
            "Inline" | "LineBreak", {cells, Join[buf, inlineBoxes[node, ctx]]},
            _,                     {Join[flushBuf[cells, buf, ctx],
                                       emitBlock[node, ctx]], {}}]]],
      {{}, {}}, children];
    flushBuf[res[[1]], res[[2]], ctx]];

(* List context: descending into a <ul>/<ol> deepens the list and records
   whether it is ordered; the style name is derived at each <li>. *)
listCtx[ctx_, tag_] :=
  <|ctx, "depth" -> ctx["depth"] + 1, "ord" -> (tag === "ol")|>;
listStyleName[ctx_] :=
  With[{base = Switch[ctx["depth"], 0 | 1, "Item", 2, "Subitem", _, "Subsubitem"]},
    If[TrueQ[ctx["ord"]], base <> "Numbered", base]];

(* Verbatim text for a <pre>: lossless descendant text, less the one leading
   newline browsers ignore right after the tag. *)
preText[el_] :=
  StringReplace[textContentWalk[el], StartOfString ~~ "\n" -> ""];

(* A constructor function is applied to the element alone; a built-in one
   wrapped in contextConstruct also takes the context. *)
applyConstruct[contextConstruct[f_], el_, ctx_] := f[el, ctx];
applyConstruct[f_, el_, _] := f[el];

(* Normalize a constructor-function result to a list of cells. *)
wrapCells[c_Cell] := {c};
wrapCells[l_List] := l;
wrapCells[b_] := {Cell[BoxData[b], "Output"]};

emitBlock[el : XMLElement[tag_, _, ch_], ctx_] :=
  With[{role = roleOf[el, ctx["roles"], HTMLToNotebook],
        c = constructOf[el, ctx]},
    Which[
      functionConstructQ[c],         wrapCells[applyConstruct[c, el, ctx]],
      blockStyleQ[c],                blockStyleEmit[el, c, ctx],
      role === "Preformatted",       {Cell[preText[el], "Program"]},
      tag === "blockquote",          quoteCells[el, ctx],
      MemberQ[{"ul", "ol"}, tag],    blockEmit[ch, listCtx[ctx, tag]],
      True,                          blockEmit[ch, ctx]]];
emitBlock[_, _] := {};

(* A block cell-style: recurse with it as the ambient style. An all-inline body
   (heading, paragraph, list item) collapses to one cell; a body with block
   children flattens them into their own cells. <li>'s "Item" is resolved to a
   depth-aware list style. *)
blockStyleEmit[XMLElement[_, _, ch_], style_, ctx_] :=
  blockEmit[ch,
    <|ctx, "blk" -> If[style === "Item", listStyleName[ctx], style]|>];

(* ---- Blockquote (leaf-collapsing, nesting-aware) ----
   A <blockquote> becomes one Cell[BoxData[FrameBox[Cell[TextData[...], "Text"]]],
   "Text"]; the Markdown exporter prefixes every line of the frame with "> ".
   The frame holds a Text cell so that the front end typesets the quote as text,
   not as input (operator spacing, monospace); operator substitution is off in
   it, as inside a box the front end otherwise draws "-" as a minus sign. Its
   TextData is the interior's inline atoms (formatting preserved), one paragraph
   per block descendant, paragraphs separated by "\n" atoms. A <br> is a "\n"
   atom too: inside a quote the exporter has no line break distinct from a
   paragraph break. A nested <blockquote> cannot carry its own frame (frames do
   not nest), so each of its lines starts with a "> " atom \[LongDash] which
   composes with the outer frame's "> " to "> > ", threading quote depth through
   the text itself. Lists inside a quote flatten to one paragraph (line) per
   item. *)

flushPara[paras_, buf_] :=
  With[{run = trimAtoms[buf]},
    If[realQ[run], Append[paras, run], paras]];

(* Walk a child list, buffering inline runs into paragraphs (atom lists) and
   recursing on block descendants \[LongDash] the cell-free analogue of blockEmit. *)
quoteCollect[children_List, ctx_] :=
  Module[{res},
    res = Fold[
      Function[{acc, node},
        With[{paras = acc[[1]], buf = acc[[2]]},
          Switch[nodeRole[node, ctx],
            "Skip",                acc,
            "Inline" | "LineBreak", {paras, Join[buf, inlineBoxes[node, ctx]]},
            _,                     {Join[flushPara[paras, buf],
                                       quoteBlockParas[node, ctx]], {}}]]],
      {{}, {}}, children];
    flushPara[res[[1]], res[[2]]]];

quoteBlockParas[XMLElement["blockquote", _, ch_], ctx_] :=
  nestedQuoteLines /@ quoteCollect[ch, ctx];
quoteBlockParas[XMLElement[_, _, ch_], ctx_] := quoteCollect[ch, ctx];
quoteBlockParas[_, _] := {};

(* A nested quote's paragraph: "> " at its start and after each line break *)
nestedQuoteLines[para_List] :=
  Prepend[Flatten[Replace[para, "\n" -> {"\n", "> "}, {1}], 1], "> "];

quoteCells[XMLElement[_, _, ch_], ctx_] :=
  {Cell[BoxData[FrameBox[Cell[TextData[Flatten[Riffle[quoteCollect[ch, ctx], "\n"], 1]],
    "Text", $noOperatorSubstitution]]], "Text"]};

(* ---- Built-in constructor-function constructs ---- *)

hrConstruct[_] := Cell["", "Text", CellFrame -> {{0, 0}, {0, 1}}];

(* <table> -> Dataset when a leading all-<th> row gives unique column labels (an
   idiomatic GFM header) and at least one body row follows it, else Grid
   (positional, blank header, every row kept).
   Dataset/Grid over Tabular because the paclet floor is WL 12.3. Cells degrade
   to plain text; in the Grid form a <th> cell is bold. See ADR 0003. *)
cellText[XMLElement[_, _, c_]] := StringTrim[normWS[StringJoin[textContentWalk /@ c]]];

gridItem[e : XMLElement["th", _, _]] := With[{t = cellText[e]}, If[t === "", t, Style[t, Bold]]];
gridItem[e_] := cellText[e];

tableCellsOf[tr_] := Cases[tr[[3]], XMLElement["th" | "td", _, _]];
tableHeaderRowQ[tr_] :=
  With[{cs = tableCellsOf[tr]},
    cs =!= {} && AllTrue[cs, MatchQ[#, XMLElement["th", _, _]] &]];

padRow[row_, n_] := PadRight[row, n, ""];
rectangular[rows_] := With[{n = Max[Length /@ rows]}, padRow[#, n] & /@ rows];

datasetCell[headers_, bodyRows_] :=
  Cell[BoxData[ToBoxes[
    Dataset[AssociationThread[headers, padRow[#, Length[headers]]] & /@ bodyRows]]],
    "Output"];
(* A framed, left-aligned table in the text font, its strings shown as written
   (no quotes, operator glyphs or coloring). *)
gridCell[rows_] := Cell[BoxData[ToBoxes[Grid[rectangular[rows],
    Frame -> All, Alignment -> Left,
    BaseStyle -> {"Text", ShowStringCharacters -> False, Sequence @@ $verbatimTextOptions}]]],
    "Output"];

(* A <caption> is a Text cell before the table's cell, converted as a paragraph
   is, so that it is not lost (ADR 0003). *)
tableConstruct[el_XMLElement, ctx_] := Join[captionCells[el, ctx], {tableCell[el]}];

captionCells[XMLElement[_, _, ch_], ctx_] :=
  blockEmit[Cases[ch, XMLElement["caption", _, _]], <|ctx, "blk" -> "Text"|>];

tableCell[el_XMLElement] :=
  Module[{trs = Cases[el, _XMLElement?(MatchQ[#, XMLElement["tr", _, _]] &), Infinity],
          rows, hasHeader, headers},
    rows = tableCellsOf /@ trs;
    rows = DeleteCases[rows, {}];
    If[rows === {}, Return[gridCell[{{""}}]]];
    hasHeader = trs =!= {} && tableHeaderRowQ[First[trs]];
    headers = cellText /@ First[rows];
    (* A Dataset with no body rows shows no header and fails to export *)
    If[hasHeader && Length[rows] > 1 && DuplicateFreeQ[headers],
      datasetCell[headers, Map[cellText, Rest[rows], {2}]],
      gridCell[Map[gridItem, rows, {2}]]]];

(* ---- Public interface ---- *)

initCtx[roleRules_, conRules_] :=
  <|"blk" -> "Text", "depth" -> 0, "ord" -> False, "qd" -> 0, "inLink" -> False,
    "roles" -> roleRules, "constructs" -> conRules|>;

toChildList[s_String] := {s};
toChildList[l_List] := l;
toChildList[e_XMLElement] := {e};

Options[HTMLToNotebook] = {"Roles" -> {}, "Constructs" -> {}, "AttributeReadings" -> <||>};

HTMLToNotebook[XMLObject["Document"][_, root_, _], opts : OptionsPattern[]] :=
  HTMLToNotebook[root, opts];

HTMLToNotebook[tree_, opts : OptionsPattern[]] :=
  withReadings[OptionValue["AttributeReadings"],
    Replace[ruleLookups[{OptionValue["Roles"], OptionValue["Constructs"]}, HTMLToNotebook, tree], {
      $Failed -> $Failed,
      {roles_, cons_} :> Notebook[blockEmit[toChildList[tree], initCtx[roles, cons]]]}]
  ] /; validTextInputQ[tree];

HTMLToNotebook[tree_, OptionsPattern[]] :=
  (Message[HTMLToNotebook::badtree, Head[tree]]; $Failed) /; !validTextInputQ[tree];

HTMLToNotebook[args___] /; (countMessage[HTMLToNotebook, {args}, {1, 1}]; False) := Null;

(* =========================================================== *)
(* Syntax information                                           *)
(* The front end colours a call with a wrong argument count.   *)
(* XMLPattern and the combinators are inert, but their counts   *)
(* are fixed too: a tag and at most one attribute argument, and *)
(* at least two stages. A one-argument XMLCases, XMLFirstCase  *)
(* or XMLDeleteCases is not coloured, as countMessage gives it  *)
(* no message (the shape of an operator form).                 *)
(* =========================================================== *)

Scan[
  Apply[Function[{f, args},
    SyntaxInformation[f] = Join[{"ArgumentsPattern" -> args},
      If[Options[f] === {}, {}, {"OptionNames" -> Keys[Options[f]]}]]]],
  {XMLCases -> {_, _., _., OptionsPattern[]}, XMLFirstCase -> {_, _., _., OptionsPattern[]},
    XMLDeleteCases -> {_, _., OptionsPattern[]}, XMLMatchQ -> {_, _., OptionsPattern[]},
    HTMLInnerText -> {_, OptionsPattern[]}, HTMLTextContent -> {_},
    HTMLToNotebook -> {_, OptionsPattern[]}, HTMLClassList -> {_}, FromCSSSelector -> {_},
    XMLPattern -> {_, _.},
    Child -> {_, _, ___}, Descendant -> {_, _, ___}, Adjacent -> {_, _, ___}, Sibling -> {_, _, ___}}];

End[];
EndPackage[];
