(* XMLDocument (ADR 0018, 0023): the document above the top elements of
   every input. The document of an XMLObject is the XMLObject, of a list the
   list, and of a bare XMLElement a virtual parent whose only child is the
   input. XMLDocument[c...] as a pattern root is tested in TreeContext.wlt;
   these are the symbol, the element tests and XMLDeleteCases. Fixtures are
   local to this file. *)

$doc = ImportString["<html><body><p id=\"a\">a</p><div><p id=\"b\">b</p></div></body></html>", {"HTML", "XMLObject"}];
$bare = XMLElement["body", {}, {XMLElement["p", {"id" -> "x"}, {}],
  XMLElement["div", {}, {XMLElement["p", {"id" -> "y"}, {}]}]}];

(* === The symbol === *)

TestCreate[
  XMLDocument[],
  XMLDocument[],
  TestID -> "document-inert"
];

(* === Refusals === *)

(* XMLMatchQ tests an element as the pattern root, and an element is not the
   document. *)
TestCreate[
  {XMLMatchQ[XMLElement["p", {}, {}], XMLDocument[]],
   HTMLInnerText[$doc, "Roles" -> {XMLDocument[] -> "Skip"}]},
  {False, $Failed},
  {HTMLInnerText::badpat},
  TestID -> "document-refused-one-element"
];

(* === XMLDeleteCases === *)

(* A document keeps its root element (#35). *)
TestCreate[
  XMLDeleteCases[$doc, XMLPattern["html"]],
  $doc,
  {XMLDeleteCases::root},
  TestID -> "document-delete-keeps-root"
];

TestCreate[
  XMLDeleteCases[$bare, XMLPattern["body"]],
  $bare,
  TestID -> "document-delete-never-the-bare-input"
];
