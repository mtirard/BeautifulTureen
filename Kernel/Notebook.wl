(* ::Package:: *)
(* HTMLPatterns: HTMLToNotebook *)

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
   is in the tree, without the marks of the rules that select it. *)
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

(* A constructor function is applied to the element alone, unmarked; a
   built-in one wrapped in contextConstruct also takes the context. *)
applyConstruct[contextConstruct[f_], el_, ctx_] := f[el, ctx];
applyConstruct[f_, el_, _] := f[unmarked[el]];

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

(* <table> -> Dataset when a header row gives unique column labels (an
   idiomatic GFM header), at least one body row follows it and none is wider
   than it, else Grid (positional, blank header, every row kept). The header
   row is the one row of a <thead>, or with no <thead> a leading all-<th> row.
   Dataset/Grid over Tabular was chosen when Tabular (14.1) was above the
   paclet floor; the floor is now 15.0 and the choice has not been revisited.
   Cells degrade to plain text, which is what HTMLInnerText
   gives for the cell under the call's "Roles"; in the Grid form a <th> cell
   is bold. See ADR 0003. *)
cellText[cell_XMLElement, ctx_] := innerText[cell, nodeRole[#, ctx] &, "\n"];

gridItem[e : XMLElement["th", _, _], ctx_] := With[{t = cellText[e, ctx]}, If[t === "", t, Style[t, Bold]]];
gridItem[e_, ctx_] := cellText[e, ctx];

tableCellsOf[tr_] := Cases[tr[[3]], XMLElement["th" | "td", _, _]];

(* A table's own rows, in document order: the <tr> children of the <table> and
   of its <thead>, <tbody> and <tfoot>, not the rows of a nested table. Each is
   {inHead, tr}, inHead being whether the row is in a <thead>. *)
tableRowsOf[XMLElement[_, _, ch_]] :=
  Catenate @ Replace[ch, {
    tr : XMLElement["tr", _, _] :> {{False, tr}},
    XMLElement[s : "thead" | "tbody" | "tfoot", _, sec_] :>
      Cases[sec, tr : XMLElement["tr", _, _] :> {s === "thead", tr}],
    _ -> {}}, {1}];

headerRowQ[cells_] := cells =!= {} && AllTrue[cells, MatchQ[XMLElement["th", _, _]]];

(* The position of the header row in rows, the cells of each row, or None: the
   one row of a <thead>, whatever its cells are, given inHead, whether each row
   is in a <thead>; with no <thead> row, a leading row of <th> cells. A <thead>
   of several rows gives none (ADR 0003). *)
headerRowPosition[rows_, inHead_] :=
  Replace[Flatten @ Position[inHead, True], {
    {i_} :> i,
    {} :> If[headerRowQ[First[rows]], 1, None],
    _ -> None}];

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
tableConstruct[el_XMLElement, ctx_] := Join[captionCells[el, ctx], {tableCell[el, ctx]}];

captionCells[XMLElement[_, _, ch_], ctx_] :=
  blockEmit[Cases[ch, XMLElement["caption", _, _]], <|ctx, "blk" -> "Text"|>];

tableCell[el_XMLElement, ctx_] :=
  Module[{tagged, inHead, rows, headerPos, headers, body},
    (* A row with no cells is ignored, also when choosing the header row *)
    tagged = DeleteCases[MapAt[tableCellsOf, tableRowsOf[el], {All, 2}], {_, {}}];
    If[tagged === {}, Return[gridCell[{{""}}]]];
    {inHead, rows} = Transpose[tagged];
    headerPos = headerRowPosition[rows, inHead];
    {headers, body} = If[headerPos === None, {None, {}},
      {cellText[#, ctx] & /@ rows[[headerPos]], Delete[rows, headerPos]}];
    (* A Dataset with no body rows shows no header and fails to export. A
       Dataset has no column for a cell beyond the last label. *)
    If[headerPos =!= None && body =!= {} && DuplicateFreeQ[headers] &&
        Max[Length /@ body] <= Length[headers],
      datasetCell[headers, Map[cellText[#, ctx] &, body, {2}]],
      gridCell[Map[gridItem[#, ctx] &, rows, {2}]]]];

(* ---- Public interface ---- *)

initCtx[roleRules_, conRules_] :=
  <|"blk" -> "Text", "depth" -> 0, "ord" -> False, "qd" -> 0, "inLink" -> False,
    "roles" -> roleRules, "constructs" -> conRules|>;

toChildList[s_String] := {s};
toChildList[l_List] := l;
toChildList[e_XMLElement] := {e};

PackageExported[HTMLToNotebook]
HTMLToNotebook::usage = "HTMLToNotebook[tree] converts an HTML or XML tree to a Notebook expression, which can be displayed or exported with Export to Markdown, PDF, RTF, etc. Block-level tags become cells, such as headings -> Title, Chapter, Section, etc., p -> Text, li -> Item, Subitem, etc., blockquote -> a framed quote, pre -> a Program cell, and table -> a Dataset or Grid, with its caption as a Text cell before it. Inline tags become boxes in the surrounding cell, such as b -> bold, i -> italic, code -> inline code, a -> a hyperlink and img -> its alt text, linked to its src. How each element is treated depends only on its tag, as given by the built-in user-agent stylesheet. HTMLToNotebook[tree, \"Roles\" -> rules] changes the role of elements, such as block or inline. \"Constructs\" -> rules changes what an element becomes: an inline style such as \"Bold\", a cell style, or a function that is applied to the element and gives a Cell or boxes. The left-hand side of each rule is an XMLPattern or a CSS selector string. \"AttributeReadings\" -> readings adds readings to $AttributeReadings for this call. tree can be an XMLElement, an XMLObject document, a list, or a string.";

Options[HTMLToNotebook] = {"Roles" -> {}, "Constructs" -> {}, "AttributeReadings" -> <||>};

(* The "Roles" and "Constructs" queries run on the input as given, a document
   included; the walk starts from its root. *)
HTMLToNotebook[tree_, opts : OptionsPattern[]] :=
  withReadings[OptionValue["AttributeReadings"],
    Replace[ruleLookups[{OptionValue["Roles"], OptionValue["Constructs"]}, HTMLToNotebook, tree], {
      $Failed -> $Failed,
      {marked_, {roles_, cons_}} :> Notebook[blockEmit[toChildList[documentRoot[marked]], initCtx[roles, cons]]]}]
  ] /; validTextInputQ[tree];

HTMLToNotebook[tree_, OptionsPattern[]] :=
  (messageTreeRefusal[HTMLToNotebook, tree]; $Failed) /; !validTextInputQ[tree];

HTMLToNotebook[args___] /; (countMessage[HTMLToNotebook, {args}, {1, 1}]; False) := Null;
