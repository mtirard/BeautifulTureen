(* ::Package:: *)
(* HTMLPatterns: messages that several functions share, and the message
   families generated over several symbols *)

XMLCases::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head `1`.";
XMLCases::badpat = "The second argument should be an XMLPattern, a Child, Descendant, Adjacent or Sibling combinator, a CSS selector string, alternatives of any of these, or a rule pattern -> rhs or pattern :> body with one of these. Each can have a condition (/;). An XMLPattern or alternatives of them can also be named or have a test (?), but a combinator, or alternatives that hold one, cannot. Got `1`.";
XMLCases::exceptname = "The name `1` is bound inside Except, which matches only where its pattern does not, so it has no value in the right-hand side. A name inside Except can be used only by tests inside that Except.";
XMLCases::text = "The name `1` binds text inside an XMLElement pattern, and text has no position, so the name cannot be a result. Name the element that holds the text instead, or use the name only in a test.";
XMLFirstCase::exceptname = "The name `1` is bound inside Except, which matches only where its pattern does not, so it has no value in the right-hand side. A name inside Except can be used only by tests inside that Except.";
XMLFirstCase::text = "The name `1` binds text inside an XMLElement pattern, and text has no position, so the name cannot be a result. Name the element that holds the text instead, or use the name only in a test.";
XMLFirstCase::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head `1`.";
XMLFirstCase::badpat = "The second argument should be an XMLPattern, a Child, Descendant, Adjacent or Sibling combinator, a CSS selector string, alternatives of any of these, or a rule pattern -> rhs or pattern :> body with one of these. Each can have a condition (/;). An XMLPattern or alternatives of them can also be named or have a test (?), but a combinator, or alternatives that hold one, cannot. Got `1`.";
XMLDeleteCases::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head `1`.";
XMLDeleteCases::badpat = "The second argument should be an XMLPattern, a Child, Descendant, Adjacent or Sibling combinator, a CSS selector string, or alternatives of any of these. Each can have a condition (/;). An XMLPattern or alternatives of them can also be named or have a test (?), but a combinator, or alternatives that hold one, cannot. A rule, whether pattern -> rhs or pattern :> body, cannot be used. Got `1`.";
XMLMatchQ::badpat = "The pattern should be an XMLPattern, an XMLElement pattern, an XMLDocument pattern, a list pattern for a list of elements, or a CSS selector string that describes one element, or alternatives of these, any of them named, with a condition pat /; test or a test pat?f. A rule gives a value, not a test. A CSS selector such as \"nav a\" or \"ul > li\" looks above the element, which a lone element does not have; use XMLCases or XMLPosition to search a tree with it. Got `1`.";
XMLFreeQ::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head `1`.";
HTMLTextContent::badtree = "The first argument should be an XMLObject, an XMLElement, a string, or a list of XMLElement expressions and strings. Got head `1`.";
HTMLInnerText::badtree = "The first argument should be an XMLObject, an XMLElement, a string, or a list of XMLElement expressions and strings. Got head `1`.";
HTMLInnerText::badrole = "A \"Roles\" rule gave `1`, which is not \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\" or \"Skip\". The element gets its role from the built-in user-agent stylesheet instead.";
HTMLInnerText::notrule = "Each \"Roles\" entry should be a rule pattern -> value or pattern :> value. Got `1`.";
HTMLToNotebook::badtree = "The first argument should be an XMLObject, an XMLElement, a string, or a list of XMLElement expressions and strings. Got head `1`.";
HTMLToNotebook::badrole = "A \"Roles\" rule gave `1`, which is not \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\" or \"Skip\". The element gets its role from the built-in user-agent stylesheet instead.";
HTMLToNotebook::notrule = "Each \"Roles\" or \"Constructs\" entry should be a rule pattern -> value or pattern :> value. Got `1`.";
HTMLToTree::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head `1`.";
HTMLToTree::badrole = "A \"Roles\" rule gave `1`, which is not \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\" or \"Skip\". The element gets its role from the built-in user-agent stylesheet instead.";
HTMLToTree::notrule = "Each \"Roles\" entry should be a rule pattern -> value or pattern :> value. Got `1`.";

(* The keys of "Roles" and "Constructs" rules (tree-pattern spec, section 6):
   an element test, or a query whose counted element positions get the value. *)
Scan[Function[h,
    MessageName[h, "badpat"] = "The key of a rule should be an element test or a query. An element test is an XMLPattern, an XMLElement pattern, or a CSS selector string that describes one element, or alternatives of these, any of them named, with a condition pat /; test or a test pat?f; each element is tested as the pattern root, and its names can be used in the value. A query is a rule such as XMLPattern[\"nav\", _, Descendant[x : XMLPattern[\"a\"]]] :> x, or a CSS selector string such as \"nav a\"; the elements it selects get the value. An XMLDocument pattern tests no element: name the elements it finds and give the rule, as in (XMLDocument[Descendant[x : XMLPattern[\"a\"]]] :> x) -> value. Got `1`.";
    MessageName[h, "keytarget"] = "A query key selects the position `1`, which is not an element. A \"Roles\" or \"Constructs\" query should select elements only."],
  {HTMLInnerText, HTMLToNotebook, HTMLToTree}];
(* HTMLToTree's are with its own messages, for its "Focus" and "Hide" queries. *)
Scan[Function[h,
    MessageName[h, "exceptname"] = "The name `1` is bound inside Except, which matches only where its pattern does not, so it has no value in the right-hand side. A name inside Except can be used only by tests inside that Except.";
    MessageName[h, "text"] = "The name `1` binds text inside an XMLElement pattern, and text has no position, so the name cannot be a result. Name the element that holds the text instead, or use the name only in a test."],
  {HTMLInnerText, HTMLToNotebook}];

(* A list of patterns for the elements of a list given to XMLMatchQ, whose
   entry cannot be one element (XMLPattern's and XMLDocument's are in
   Common.wl). *)
XMLMatchQ::listentry = "`1` cannot be an entry in a list of patterns for a list of elements. `2`";

(* A blank as the whole query, or as Descendant's pattern. *)
Scan[Function[h,
    MessageName[h, "blank"] = "`1` is a blank, which is not an XML pattern. Any element is XMLPattern[_]. An XML pattern matches elements only; for the text inside an element, use HTMLTextContent or HTMLInnerText."],
  {XMLCases, XMLFirstCase, XMLDeleteCases, XMLReplace, XMLMatchQ, XMLFreeQ, HTMLInnerText, HTMLToNotebook, Descendant}];

(* A list given as a tree holding something other than elements and strings. *)
Scan[Function[h,
    MessageName[h, "badmember"] = "A list given as the first argument should hold only XMLElement expressions and strings. The member at position `1` has head `2`."],
  {XMLCases, XMLFirstCase, XMLDeleteCases, XMLReplace, XMLFreeQ, HTMLTextContent, HTMLInnerText, HTMLToNotebook, HTMLToTree}];
