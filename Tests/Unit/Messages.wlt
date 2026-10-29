(* Message text as a reader sees it when a message is captured as text (a doc
   page's Message cell, a log): each argument is written in InputForm, the way
   wltext and other capture tools write it. An argument must read as the
   expression itself, not as a formatting wrapper around it. A message with no
   text of its own, such as f::argx, has General's text, as Message gives it. *)

SetAttributes[capturedMessages, HoldFirst];
capturedMessages[expr_] := Module[{texts = {}},
  Internal`HandlerBlock[
    {"Message", Function[m,
      Replace[m, Hold[Message[mn : MessageName[_, _], args___], _] :>
        AppendTo[texts, ToString[
          StringForm[messageText[mn], Sequence @@ (List @@ Map[
            Function[a, ToString[Unevaluated[a], InputForm], HoldAllComplete],
            Hold[args]])],
          OutputForm, PageWidth -> Infinity]]]]},
    Quiet[expr]];
  texts];

SetAttributes[messageText, HoldFirst];
messageText[MessageName[s_, tag_]] :=
  Replace[MessageName[s, tag], _MessageName :> MessageName[General, tag]];

$msgTree = ImportString[
  "<article><p>Top.</p><section><p>Nested.</p></section></article>",
  {"HTML", "XMLObject"}];

(* Descendant with one argument is a constraint, which says where it goes. *)
TestCreate[
  capturedMessages[XMLCases[$msgTree, Descendant[XMLPattern["p"]]]],
  {"Descendant[XMLPattern[\"p\"]] is a constraint, which can only be an argument of the bracket after XMLPattern[tag, attrs] or of XMLDocument, as in XMLPattern[\"nav\"][Descendant[XMLPattern[\"a\"]]]. To find matching elements at any depth, give the pattern alone."},
  TestID -> "message-descendant-constraint-as-query"
];

(* A misplaced XMLDocument[] says where it can stand. *)
TestCreate[
  capturedMessages[XMLCases[$msgTree, XMLPattern["article"][Descendant[XMLDocument[]]]]],
  {"XMLDocument[...] matches only the document above the top elements, so it can only be a pattern root: the whole query, named, conditioned or tested, or a branch of alternatives at the top, as in XMLPattern[_][L] | XMLDocument[L]. It cannot be inside Descendant, an attribute pattern or an XMLElement pattern. Got XMLDocument[]."},
  TestID -> "message-document-placement"
];

(* Descendant alone is a constraint, not a pattern to test. *)
TestCreate[
  capturedMessages[XMLMatchQ[XMLElement["p", {}, {"x"}], Descendant[XMLPattern["p"]]]],
  {"Descendant[XMLPattern[\"p\"]] is a constraint, which can only be an argument of the bracket after XMLPattern[tag, attrs] or of XMLDocument, as in XMLPattern[\"nav\"][Descendant[XMLPattern[\"a\"]]]. To find matching elements at any depth, give the pattern alone."},
  TestID -> "message-descendant-in-xmlmatchq"
];

(* ---- The tree argument ----
   A list holds XMLElement expressions and strings only (issue #36, ADR 0018).
   A refused list is described by its first refused member, not by List. *)

TestCreate[
  {XMLCases[{$msgTree}, XMLPattern["p"]], HTMLTextContent[{$msgTree, "x"}]},
  {$Failed, $Failed},
  {XMLCases::badmember, HTMLTextContent::badmember},
  TestID -> "tree-list-with-document-refused"
];

TestCreate[
  capturedMessages[XMLCases[{XMLElement["p", {}, {}], $msgTree}, XMLPattern["p"]]],
  {"A list given as the first argument should hold only XMLElement expressions and strings. The member at position 2 has head XMLObject[\"Document\"]."},
  TestID -> "tree-list-message-names-member"
];

TestCreate[
  Flatten[capturedMessages /@ Unevaluated[{
    XMLFirstCase[{$msgTree}, XMLPattern["p"]],
    XMLDeleteCases[{$msgTree}, XMLPattern["p"]],
    HTMLInnerText[{$msgTree}],
    HTMLToNotebook[{$msgTree}]}]],
  ConstantArray[
    "A list given as the first argument should hold only XMLElement expressions and strings. The member at position 1 has head XMLObject[\"Document\"].",
    4],
  TestID -> "tree-list-message-on-each-function"
];

TestCreate[
  {XMLFirstCase[{$msgTree}, XMLPattern["p"]], XMLDeleteCases[{$msgTree}, XMLPattern["p"]],
    HTMLInnerText[{$msgTree}], HTMLToNotebook[{$msgTree}]},
  ConstantArray[$Failed, 4],
  {XMLFirstCase::badmember, XMLDeleteCases::badmember, HTMLInnerText::badmember, HTMLToNotebook::badmember},
  TestID -> "tree-list-message-names-function-called"
];

(* No text says a list may hold a document. *)
TestCreate[
  Flatten[capturedMessages /@ Unevaluated[{
    XMLCases[42, XMLPattern["p"]], XMLFirstCase[42, XMLPattern["p"]], XMLDeleteCases[42, XMLPattern["p"]],
    HTMLTextContent[37], HTMLInnerText[37], HTMLToNotebook[37]}]],
  Join[
    ConstantArray["The first argument should be an XMLObject, an XMLElement, or a list of XMLElement expressions and strings. Got head Integer.", 3],
    ConstantArray["The first argument should be an XMLObject, an XMLElement, a string, or a list of XMLElement expressions and strings. Got head Integer.", 3]],
  TestID -> "tree-message-describes-accepted-input"
];

(* ---- Argument counts ----
   A call with a number of positional arguments outside a function's range gives
   the standard argument-count message and stays unevaluated, as a built-in
   does. Options are not counted. *)

(* An unevaluated call is compared as its head and its arguments: the expected
   value cannot be written as the call itself, which would evaluate. *)
callParts[call_] := {Head[call], List @@ call};

TestCreate[
  callParts /@ {XMLCases[$msgTree, XMLPattern["p"], 2, 3], XMLCases[$msgTree, XMLPattern["p"], Infinity, 2, 3]},
  {{XMLCases, {$msgTree, XMLPattern["p"], 2, 3}}, {XMLCases, {$msgTree, XMLPattern["p"], Infinity, 2, 3}}},
  {XMLCases::argt, XMLCases::argt},
  TestID -> "count-xmlcases-extra-arguments-unevaluated"
];

TestCreate[
  capturedMessages[XMLDeleteCases[$msgTree, XMLPattern["p"], 2]],
  {"XMLDeleteCases called with 3 arguments; 2 arguments are expected."},
  TestID -> "count-message-is-the-standard-text"
];

TestCreate[
  {callParts[XMLFirstCase[$msgTree, XMLPattern["p"], "none", 4]],
    callParts[XMLDeleteCases[$msgTree, XMLPattern["p"], 3]]},
  {{XMLFirstCase, {$msgTree, XMLPattern["p"], "none", 4}},
    {XMLDeleteCases, {$msgTree, XMLPattern["p"], 3}}},
  {XMLFirstCase::argt, XMLDeleteCases::argrx},
  TestID -> "count-xmlfirstcase-xmldeletecases-extra-arguments"
];

TestCreate[
  capturedMessages[{XMLFirstCase[$msgTree, XMLPattern["p"], "none", 4], XMLMatchQ[]}],
  {"XMLFirstCase called with 4 arguments; 2 or 3 arguments are expected.",
    "XMLMatchQ called with 0 arguments; 1 or 2 arguments are expected."},
  TestID -> "count-message-gives-the-range"
];

TestCreate[
  {callParts[XMLMatchQ[]],
    callParts[XMLMatchQ[XMLElement["p", {}, {}], XMLPattern["p"], 3]]},
  {{XMLMatchQ, {}}, {XMLMatchQ, {XMLElement["p", {}, {}], XMLPattern["p"], 3}}},
  {XMLMatchQ::argt, XMLMatchQ::argt},
  TestID -> "count-xmlmatchq-none-or-three"
];

(* An option is not counted: a fourth argument that is not one is. *)
TestCreate[
  callParts[XMLCases[$msgTree, XMLPattern["p"], 2, 3, "AttributeReadings" -> <||>]],
  {XMLCases, {$msgTree, XMLPattern["p"], 2, 3, "AttributeReadings" -> <||>}},
  {XMLCases::argt},
  TestID -> "count-options-are-not-counted"
];

TestCreate[
  capturedMessages[XMLCases[$msgTree, XMLPattern["p"], 2, 3, "AttributeReadings" -> <||>]],
  {"XMLCases called with 4 arguments; 2 or 3 arguments are expected."},
  TestID -> "count-message-leaves-options-out"
];

TestCreate[
  Map[callParts, {HTMLInnerText[], HTMLInnerText[$msgTree, 2], HTMLTextContent[],
    HTMLTextContent[$msgTree, 2], HTMLToNotebook[], HTMLToNotebook[$msgTree, 2],
    HTMLClassList[], HTMLClassList[XMLElement["p", {}, {}], 2]}],
  {{HTMLInnerText, {}}, {HTMLInnerText, {$msgTree, 2}}, {HTMLTextContent, {}},
    {HTMLTextContent, {$msgTree, 2}}, {HTMLToNotebook, {}}, {HTMLToNotebook, {$msgTree, 2}},
    {HTMLClassList, {}}, {HTMLClassList, {XMLElement["p", {}, {}], 2}}},
  {HTMLInnerText::argx, HTMLInnerText::argx, HTMLTextContent::argx, HTMLTextContent::argx,
    HTMLToNotebook::argx, HTMLToNotebook::argx, HTMLClassList::argx, HTMLClassList::argx},
  TestID -> "count-text-functions-none-or-two"
];

TestCreate[
  capturedMessages[HTMLInnerText[$msgTree, 2]],
  {"HTMLInnerText called with 2 arguments; 1 argument is expected."},
  TestID -> "count-message-for-one-argument-function"
];

(* One argument is the shape of an operator form, as Cases[pattern] is: it stays
   unevaluated with no message. *)
TestCreate[
  callParts /@ {XMLCases[XMLPattern["p"]], XMLFirstCase[XMLPattern["p"]], XMLDeleteCases[XMLPattern["p"]]},
  {{XMLCases, {XMLPattern["p"]}}, {XMLFirstCase, {XMLPattern["p"]}}, {XMLDeleteCases, {XMLPattern["p"]}}},
  TestID -> "count-one-argument-stays-unevaluated-without-message"
];

(* The operator form, with or without an option, is not a count error. *)
TestCreate[
  {callParts[XMLMatchQ[XMLPattern["p"]]],
    callParts[XMLMatchQ[XMLPattern["p"], "AttributeReadings" -> <||>]],
    XMLMatchQ[XMLPattern["p"], "AttributeReadings" -> <||>][XMLElement["p", {}, {}]]},
  {{XMLMatchQ, {XMLPattern["p"]}}, {XMLMatchQ, {XMLPattern["p"], "AttributeReadings" -> <||>}}, True},
  TestID -> "count-xmlmatchq-operator-form-unchanged"
];

(* A second-argument rule is the query, and a third that names no option is the
   default, so neither is read as an option or counted wrongly. *)
TestCreate[
  {XMLCases[$msgTree, XMLPattern["p"] -> 1],
    XMLFirstCase[$msgTree, XMLPattern["p"] -> 1, "none"],
    XMLFirstCase[$msgTree, XMLPattern["div"], "none"],
    XMLFirstCase[$msgTree, XMLPattern["div"], "a" -> "b"],
    XMLFirstCase[$msgTree, XMLPattern["div"], "none", "AttributeReadings" -> <||>]},
  {{1}, 1, "none", "a" -> "b", "none"},
  TestID -> "count-rules-as-query-and-default-unchanged"
];

TestCreate[
  {HTMLInnerText[$msgTree, "Roles" -> {"section" -> "Skip"}, "BlockSeparator" -> " "],
    Length[First[HTMLToNotebook[$msgTree, "Constructs" -> {"p" -> "Section"}]]]},
  {"Top.", 2},
  TestID -> "count-text-function-options-unchanged"
];

(* The front end colours a wrong argument count from SyntaxInformation. The
   second argument of XMLCases, XMLFirstCase and XMLDeleteCases is required:
   were it optional, the front end would read a query pattern :> rhs as an
   option and colour its pattern red. *)
TestCreate[
  Lookup[SyntaxInformation /@ {XMLCases, XMLFirstCase, XMLDeleteCases, XMLMatchQ,
    HTMLInnerText, HTMLTextContent, HTMLToNotebook, HTMLClassList,
    XMLPattern, Descendant}, "ArgumentsPattern"],
  {{_, _, _., OptionsPattern[]}, {_, _, _., OptionsPattern[]}, {_, _, OptionsPattern[]},
    {_, _., OptionsPattern[]}, {_, OptionsPattern[]}, {_}, {_, OptionsPattern[]}, {_},
    {_, _.}, {_, _.}},
  TestID -> "syntax-information-arguments-pattern"
];

TestCreate[
  Lookup[SyntaxInformation /@ {XMLCases, XMLFirstCase, XMLDeleteCases, XMLMatchQ,
    HTMLInnerText, HTMLToNotebook}, "OptionNames"],
  {{"AttributeReadings"}, {"AttributeReadings"}, {"AttributeReadings"}, {"AttributeReadings"},
    {"Roles", "BlockSeparator", "AttributeReadings"}, {"Roles", "Constructs", "AttributeReadings"}},
  TestID -> "syntax-information-option-names"
];

(* A count that is not a non-negative integer or Infinity gives the built-in
   innf text, naming the call and position 3, as Cases names position 4. *)
TestCreate[
  capturedMessages[XMLCases[XMLElement["p", {}, {}], XMLPattern["p"], UpTo[2]]],
  {"Non-negative integer or Infinity expected at position 3 in XMLCases[XMLElement[\"p\", {}, {}], XMLPattern[\"p\"], UpTo[2]]."},
  TestID -> "count-innf-message-text"
];

(* No arguments is a count error too; an option before the extra argument is
   not at the end, so it is counted. *)
TestCreate[
  {callParts[XMLCases[]], callParts[XMLDeleteCases[]],
    callParts[XMLFirstCase[$msgTree, XMLPattern["p"], "AttributeReadings" -> <||>, 4]]},
  {{XMLCases, {}}, {XMLDeleteCases, {}},
    {XMLFirstCase, {$msgTree, XMLPattern["p"], "AttributeReadings" -> <||>, 4}}},
  {XMLCases::argt, XMLDeleteCases::argrx, XMLFirstCase::argt},
  TestID -> "count-no-arguments-and-option-before-extra"
];

(* FromCSSSelector: one message per kind, naming the selector, the part that
   caused it and, where there is one, the workaround. *)
TestCreate[
  Join @@ (capturedMessages[FromCSSSelector[#]] & /@ {"a > > b", ":foo", ":matches(a)"}),
  {"\"a > > b\" is not a valid CSS selector: \"two combinators in a row at character 5\".",
   "\":foo\" is not a valid CSS selector: \"unknown pseudo-class :foo at character 1\".",
   "\":matches(a)\" is not a valid CSS selector: \"unknown pseudo-class :matches() at character 1; write :is() instead\"."},
  TestID -> "message-css-invalid"
];

TestCreate[
  Join @@ (capturedMessages[FromCSSSelector[#]] & /@ {"body :root", "x :is(a + b)"}),
  {"\"body :root\" is valid CSS, but \":root\" cannot be translated to an XML pattern. \"It matches the only top element, which has no parent or sibling in the tree, so it can only be in the first compound of a selector, followed by > or a descendant combinator, as in :root > body.\"",
   "\"x :is(a + b)\" is valid CSS, but \":is(a + b)\" cannot be translated to an XML pattern. \"Its arguments can hold only descendant and > combinators, which look at the element's ancestors; + and ~ look at its siblings.\""},
  TestID -> "message-css-unsupported"
];

TestCreate[
  Join @@ (capturedMessages[FromCSSSelector[#]] & /@ {"a:target", "p::first-letter"}),
  {"\":target\" in \"a:target\" depends on a browser, such as user input, layout or the page's URL, and cannot be matched in a static document. \"To match the element that a fragment names, use XMLPattern[_, \\\"id\\\" -> fragment].\"",
   "\"::first-letter\" in \"p::first-letter\" depends on a browser, such as user input, layout or the page's URL, and cannot be matched in a static document. \"To get the first letter of each match, use StringTake[HTMLInnerText[e], UpTo[1]].\""},
  TestID -> "message-css-impossible"
];

(* A context selector, given to XMLMatchQ, is named as written, and the text
   says it looks above the element. *)
TestCreate[
  capturedMessages[XMLMatchQ[XMLElement["p", {}, {}], "div > p"]],
  {"The pattern should be an XMLPattern, an XMLElement pattern, an XMLDocument pattern, a list pattern for a list of elements, or a CSS selector string that describes one element, or alternatives of these, any of them named, with a condition pat /; test or a test pat?f. A rule gives a value, not a test. A CSS selector such as \"nav a\" or \"ul > li\" looks above the element, which a lone element does not have; use XMLCases or XMLPosition to search a tree with it. Child, Adjacent and Sibling were removed in version 4; a test of an element's children constrains them, as in XMLPattern[\"ul\"][{___, XMLPattern[\"li\"], ___}], and XMLCases searches a tree with a rule, as in XMLPattern[\"ul\"][{___, x : XMLPattern[\"li\"], ___}] :> x. Got \"div > p\"."},
  TestID -> "message-css-string-combinator-names-the-string"
];


(* ---- The bracket form ----
   Constraints are written in a second bracket, XMLPattern[tag, attrs][c...],
   so no usage or message text shows an XMLPattern with a third argument. An
   argument count ignores what is nested in brackets, braces and strings, and
   the XMLPattern expressions nested in an argument are checked too. *)

threeArgumentForms[text_String] := Join @@ Map[
  Function[inner, If[StringCount[
      FixedPoint[StringReplace[RegularExpression["\\[[^\\[\\]]*\\]|\\{[^{}]*\\}|\"[^\"]*\""] -> ""], inner],
      ","] >= 2,
    {inner}, threeArgumentForms[inner]]],
  StringCases[text, RegularExpression["XMLPattern\\[((?:[^\\[\\]]++|\\[(?1)\\])*)\\]"] :> "$1"]];

TestCreate[
  Union @@ threeArgumentForms /@ Cases[
    Flatten[Messages /@ Names["MaximilienTirard`HTMLPatterns`*"]], (_ :> s_String) :> s],
  {},
  TestID -> "message-texts-use-the-bracket-form"
];

(* The hints that messages take as arguments use the bracket form too. *)
TestCreate[
  With[{texts = Join[
      Join @@ (capturedMessages[FromCSSSelector[#]] & /@ {"p:lang(en)", "li:not(:first-child)"}),
      capturedMessages[XMLCases[$msgTree, XMLPattern["article"][{___, Descendant[XMLPattern["p"]], ___}]]],
      capturedMessages[XMLCases[$msgTree, XMLPattern["article"][{___, {}, ___}]]]]},
    {Length[texts], Union @@ threeArgumentForms /@ texts}],
  {4, {}},
  TestID -> "message-hints-use-the-bracket-form"
];
