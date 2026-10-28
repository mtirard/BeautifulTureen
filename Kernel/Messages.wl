(* ::Package:: *)
(* HTMLPatterns: messages that several functions share, and the message
   families generated over several symbols *)

XMLCases::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head `1`.";
XMLCases::badpat = "The second argument should be an XMLPattern, a Child, Descendant, Adjacent or Sibling combinator, a CSS selector string, alternatives of any of these, or a rule pattern -> rhs or pattern :> body with one of these. Each can have a condition (/;). An XMLPattern or alternatives of them can also be named or have a test (?), but a combinator, or alternatives that hold one, cannot. Got `1`.";
XMLCases::testcombinator = "A test (?) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Put it on the stage it tests, as in Child[a, b?f]. Got `1`.";
XMLCases::exceptname = "The name `1` is bound inside Except, which matches only where its pattern does not, so it has no value in the right-hand side. A name inside Except can be used only by tests inside that Except.";
XMLFirstCase::exceptname = "The name `1` is bound inside Except, which matches only where its pattern does not, so it has no value in the right-hand side. A name inside Except can be used only by tests inside that Except.";
XMLFirstCase::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head `1`.";
XMLFirstCase::badpat = "The second argument should be an XMLPattern, a Child, Descendant, Adjacent or Sibling combinator, a CSS selector string, alternatives of any of these, or a rule pattern -> rhs or pattern :> body with one of these. Each can have a condition (/;). An XMLPattern or alternatives of them can also be named or have a test (?), but a combinator, or alternatives that hold one, cannot. Got `1`.";
XMLFirstCase::testcombinator = "A test (?) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Put it on the stage it tests, as in Child[a, b?f]. Got `1`.";
XMLDeleteCases::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head `1`.";
XMLDeleteCases::badpat = "The second argument should be an XMLPattern, a Child, Descendant, Adjacent or Sibling combinator, a CSS selector string, or alternatives of any of these. Each can have a condition (/;). An XMLPattern or alternatives of them can also be named or have a test (?), but a combinator, or alternatives that hold one, cannot. A rule, whether pattern -> rhs or pattern :> body, cannot be used. Got `1`.";
XMLDeleteCases::testcombinator = "A test (?) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Put it on the stage it tests, as in Child[a, b?f]. Got `1`.";
XMLMatchQ::badpat = "The pattern should be an XMLPattern, an XMLElement pattern, an XMLDocument pattern, a list pattern for a list of elements, or a CSS selector string that describes one element, or alternatives of these, any of them named, with a condition pat /; test or a test pat?f. A rule gives a value, not a test. A CSS selector such as \"nav a\" or \"ul > li\" looks above the element, which a lone element does not have; use XMLCases or XMLPosition to search a tree with it. Got `1`.";
XMLMatchQ::stages = "`1` is a combinator with fewer than two stages. A combinator needs at least two, but XMLMatchQ tests a lone element and cannot use one; use XMLCases or XMLFirstCase to search a tree with it.";
XMLMatchQ::condcombinator = "A condition (/;) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Got `1`.";
XMLMatchQ::testcombinator = "A test (?) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Put it on the stage it tests, as in Child[a, b?f]. Got `1`.";
XMLFreeQ::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head `1`.";
HTMLTextContent::badtree = "The first argument should be an XMLObject, an XMLElement, a string, or a list of XMLElement expressions and strings. Got head `1`.";
HTMLInnerText::badtree = "The first argument should be an XMLObject, an XMLElement, a string, or a list of XMLElement expressions and strings. Got head `1`.";
HTMLInnerText::badrole = "A \"Roles\" rule gave `1`, which is not \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\" or \"Skip\". The element gets its role from the built-in user-agent stylesheet instead.";
HTMLInnerText::badpat = "The left-hand side of a rule should be an XMLPattern, alternatives of them, or either with a condition pat /; test or a test pat?f, or a CSS selector string that describes one element. Got `1`.";
HTMLInnerText::stages = "`1` is a combinator with fewer than two stages. A combinator needs at least two, but a rule is tried on one element at a time and cannot use one; use an XMLPattern or alternatives of them.";
HTMLInnerText::notrule = "Each \"Roles\" entry should be a rule pattern -> value or pattern :> value. Got `1`.";
HTMLInnerText::condcombinator = "A condition (/;) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Got `1`.";
HTMLInnerText::testcombinator = "A test (?) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Put it on the stage it tests, as in Child[a, b?f]. Got `1`.";
HTMLToNotebook::badtree = "The first argument should be an XMLObject, an XMLElement, a string, or a list of XMLElement expressions and strings. Got head `1`.";
HTMLToNotebook::badrole = "A \"Roles\" rule gave `1`, which is not \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\" or \"Skip\". The element gets its role from the built-in user-agent stylesheet instead.";
HTMLToNotebook::badpat = "The left-hand side of a rule should be an XMLPattern, alternatives of them, or either with a condition pat /; test or a test pat?f, or a CSS selector string that describes one element. Got `1`.";
HTMLToNotebook::stages = "`1` is a combinator with fewer than two stages. A combinator needs at least two, but a rule is tried on one element at a time and cannot use one; use an XMLPattern or alternatives of them.";
HTMLToNotebook::notrule = "Each \"Roles\" or \"Constructs\" entry should be a rule pattern -> value or pattern :> value. Got `1`.";
HTMLToNotebook::condcombinator = "A condition (/;) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Got `1`.";
HTMLToNotebook::testcombinator = "A test (?) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Put it on the stage it tests, as in Child[a, b?f]. Got `1`.";
HTMLToTree::badtree = "The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head `1`.";
HTMLToTree::badrole = "A \"Roles\" rule gave `1`, which is not \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\" or \"Skip\". The element gets its role from the built-in user-agent stylesheet instead.";
HTMLToTree::badpat = "The left-hand side of a rule should be an XMLPattern, alternatives of them, or either with a condition pat /; test or a test pat?f, or a CSS selector string that describes one element. Got `1`.";
HTMLToTree::stages = "`1` is a combinator with fewer than two stages. A combinator needs at least two, but a rule is tried on one element at a time and cannot use one; use an XMLPattern or alternatives of them.";
HTMLToTree::notrule = "Each \"Roles\" entry should be a rule pattern -> value or pattern :> value. Got `1`.";
HTMLToTree::condcombinator = "A condition (/;) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Got `1`.";
HTMLToTree::testcombinator = "A test (?) can apply to an XMLPattern or alternatives of them, but not to a combinator such as Child or Descendant. Put it on the stage it tests, as in Child[a, b?f]. Got `1`.";

(* A list of patterns for an element's children (ADR 0016), refused where it
   cannot stand, with the reason. Set by one Scan, since every head listed
   takes the same three messages. *)
Scan[Function[h,
    MessageName[h, "liststage"] = "`1` is a list of patterns for an element's children. `2`";
    MessageName[h, "listentry"] = "`1` cannot be an entry in a list of patterns for an element's children. `2`";
    MessageName[h, "blank"] = "`1` is a blank, which is not an XML pattern. Any element is XMLPattern[_]. An XML pattern matches elements only; for the text inside an element, use HTMLTextContent or HTMLInnerText."],
  {XMLCases, XMLFirstCase, XMLDeleteCases, XMLMatchQ, XMLFreeQ, HTMLInnerText, HTMLToNotebook, Child, Descendant, Adjacent, Sibling}];

(* A list given as a tree holding something other than elements and strings. *)
Scan[Function[h,
    MessageName[h, "badmember"] = "A list given as the first argument should hold only XMLElement expressions and strings. The member at position `1` has head `2`."],
  {XMLCases, XMLFirstCase, XMLDeleteCases, XMLFreeQ, HTMLTextContent, HTMLInnerText, HTMLToNotebook, HTMLToTree}];

(* A mistake in a combinator is its message, named for it (ADR 0022). HEAD
   stands for the combinator's name; the message's own slot `1` is kept.
   StringReplace rather than TemplateApply: TextString of a symbol loads the
   entity framework, ~0.4 s the first time in a session. *)
Scan[Function[h,
    With[{fill = StringReplace[#, "HEAD" -> SymbolName[h]] &},
      MessageName[h, "stages"] = fill["HEAD needs at least two stages, as in HEAD[a, b] or HEAD[a, b, c]. Got `1`."];
      MessageName[h, "testcombinator"] = fill["A test (?) can apply to an XMLPattern or alternatives of them, but not to a HEAD combinator. Put it on the stage it tests, as in HEAD[a, b?f]. Got `1`."]]],
  {Child, Descendant, Adjacent, Sibling}];
