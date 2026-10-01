(* Message text as a reader sees it when a message is captured as text (a doc
   page's Message cell, a log): each argument is written in InputForm, the way
   wltext and other capture tools write it. An argument must read as the
   expression itself, not as a formatting wrapper around it. *)

SetAttributes[capturedMessages, HoldFirst];
capturedMessages[expr_] := Module[{texts = {}},
  Internal`HandlerBlock[
    {"Message", Function[m,
      Replace[m, Hold[Message[mn : MessageName[_, _], args___], _] :>
        AppendTo[texts, ToString[
          StringForm[mn, Sequence @@ (List @@ Map[
            Function[a, ToString[Unevaluated[a], InputForm], HoldAllComplete],
            Hold[args]])],
          OutputForm, PageWidth -> Infinity]]]]},
    Quiet[expr]];
  texts];

$msgTree = ImportString[
  "<article><p>Top.</p><section><p>Nested.</p></section></article>",
  {"HTML", "XMLObject"}];

TestCreate[
  capturedMessages[
    XMLMatchQ[XMLElement["p", {}, {"x"}], Child[XMLPattern["div"], XMLPattern["p"]]]],
  {"Child[XMLPattern[\"div\"], XMLPattern[\"p\"]] relates an element to its parent or siblings, which a lone element does not have. Use XMLCases or XMLFirstCase to search a tree with it."},
  TestID -> "message-names-the-pattern-as-written"
];

(* An Alternatives holding a combinator is refused as a whole: the message names
   the pattern the caller wrote, not the alternative that tripped it. *)
TestCreate[
  StringReplace[capturedMessages[
    XMLCases[$msgTree,
      Child[XMLPattern["article"], XMLPattern["p"]] | Child[XMLPattern["section"], XMLPattern["p"]]]],
    StartOfString ~~ __ ~~ "Got " -> "Got "],
  {"Got Child[XMLPattern[\"article\"], XMLPattern[\"p\"]] | Child[XMLPattern[\"section\"], XMLPattern[\"p\"]]."},
  TestID -> "message-names-whole-alternatives-with-combinator"
];

(* A combinator with one stage is refused with a message that says it needs two. *)
TestCreate[
  capturedMessages[XMLCases[$msgTree, Descendant[XMLPattern["p"]]]],
  {"A combinator such as Child or Descendant needs at least two stages, as in Descendant[a, b] or Descendant[a, b, c]. Got Descendant[XMLPattern[\"p\"]]."},
  TestID -> "message-one-stage-combinator-names-two-stage-minimum"
];

(* Where no combinator can be used, the message does not suggest one. *)
TestCreate[
  capturedMessages[XMLMatchQ[XMLElement["p", {}, {"x"}], Descendant[XMLPattern["p"]]]],
  {"Descendant[XMLPattern[\"p\"]] is a combinator with fewer than two stages. A combinator needs at least two, but XMLMatchQ tests a lone element and cannot use one; use XMLCases or XMLFirstCase to search a tree with it."},
  TestID -> "message-one-stage-combinator-in-xmlmatchq"
];
