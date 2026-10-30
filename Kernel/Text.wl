(* ::Package:: *)
(* HTMLPatterns: HTMLTextContent and HTMLInnerText *)

(* Used by DisplayRoles.wl, Notebook.wl and Tree.wl *)
PackageScoped[textContentWalk]

(* =========================================================== *)
(* HTMLTextContent                                             *)
(* Lossless tree-fold: concatenate every descendant string in  *)
(* document order, inserting/removing no whitespace.           *)
(*                                                              *)
(* Public arm validates with validTextInputQ (same input       *)
(* surface as XMLCases) and delegates to the internal total     *)
(* walk; the walk never messages, so stray non-element/         *)
(* non-string nodes (comments, declarations) silently           *)
(* contribute "" mid-tree.                                      *)
(* =========================================================== *)

PackageExported[HTMLTextContent]
HTMLTextContent::usage ="HTMLTextContent[tree] gives the text of an XML tree: all the strings it contains, joined in document order. No whitespace is added or removed, so source indentation and the whitespace in <pre> are kept. tree can be an XMLElement, an XMLObject document, a list, or a string.";

HTMLTextContent[tree_] := textContentWalk[tree] /; validTextInputQ[tree];

HTMLTextContent[tree_] :=
  (messageTreeRefusal[HTMLTextContent, tree]; $Failed) /; !validTextInputQ[tree];

HTMLTextContent[args___] /; (countMessage[HTMLTextContent, {args}, {1, 1}]; False) := Null;

(* Internal total recursion \[LongDash] every node contributes a string *)
textContentWalk[XMLObject["Document"][_, root_, _]] := textContentWalk[root];
textContentWalk[XMLElement[_, _, children_List]] :=
  StringJoin[textContentWalk /@ children];
textContentWalk[s_String] := s;
textContentWalk[l_List] := StringJoin[textContentWalk /@ l];
textContentWalk[_] := "";

(* =========================================================== *)
(* HTMLInnerText                                               *)
(* Readable text over the display-role substrate. A two-pass    *)
(* fold turns the classified tree into text:                    *)
(*   Pass A (itTopToks, itToks): tree -> flat token stream; a   *)
(*     skipped top element gives its text content, the preserve *)
(*     whitespace flag is threaded down, box/skip/break are     *)
(*     decided locally.                                         *)
(*   Pass B (itSerialize): tokens -> string; collapse runs,     *)
(*     strongest-glue-wins between content, one newline per     *)
(*     <br>, trim both ends (glue is gated on a non-empty       *)
(*     accumulator).                                            *)
(* Public arms validate (validTextInputQ) and message on bad    *)
(* input; the internal walk is total so stray nodes contribute  *)
(* nothing mid-tree.                                            *)
(* =========================================================== *)

(* ---- Public interface ---- *)
PackageExported[HTMLInnerText]
HTMLInnerText::usage = "HTMLInnerText[tree] gives the readable text of an XML tree. Runs of whitespace are collapsed, block-level elements go on their own lines, <br> becomes a newline, <pre> content is kept as written, tags such as script and style are dropped, and the result is trimmed. How each element is treated depends only on its tag, as given by the built-in user-agent stylesheet. The \"Roles\" option changes this, with rules of the form pattern -> role, where pattern is an XMLPattern or a CSS selector string and role is \"Block\", \"Inline\", \"Preformatted\", \"LineBreak\" or \"Skip\". The \"BlockSeparator\" option sets the string inserted between blocks (default \"\\n\"). The \"AttributeReadings\" option adds entries to $AttributeReadings for one call. tree can be an XMLElement, an XMLObject document, a list, or a string.";

Options[HTMLInnerText] = {"Roles" -> {}, "BlockSeparator" -> "\n", "AttributeReadings" -> <||>};

(* The "Roles" queries run on the input as given, a document included; the
   walk starts from its root. *)
HTMLInnerText[tree_, opts : OptionsPattern[]] :=
  withReadings[OptionValue["AttributeReadings"],
    Replace[ruleLookups[{OptionValue["Roles"]}, HTMLInnerText, tree], {
      $Failed -> $Failed,
      {marked_, {roles_}} :> innerText[documentRoot[marked], roleOf[#, roles, HTMLInnerText] &, OptionValue["BlockSeparator"]]}]
  ] /; validTextInputQ[tree];

HTMLInnerText[tree_, OptionsPattern[]] :=
  (messageTreeRefusal[HTMLInnerText, tree]; $Failed) /; !validTextInputQ[tree];

HTMLInnerText[args___] /; (countMessage[HTMLInnerText, {args}, {1, 1}]; False) := Null;
