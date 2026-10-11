# Front-end colouring of rule arguments: `Cases` versus a paclet function

Researched 2026-10-11 against Wolfram 15.0.0 for Mac OS X ARM (64-bit) (May 19, 2026), at `/Applications/Wolfram.app`.

## Question

In `Cases[list, pat :> rhs]` the front end (FE) does not colour `pat` red. In a user function with the same `SyntaxInformation`, `{_, _., _., OptionsPattern[]}`, it does: the FE reads the rule as an unknown option. Why is there a difference, and can a paclet get the `Cases` behaviour for `XMLCases`?

## Short answer

The FE has a hard-coded list of function names whose rule arguments are ordinary arguments, not options. The list is the `"virtualRulePositionExpr"` entry of the FE resource `SystemFiles/FrontEnd/TextResources/MiscExpressions.tr`. `Cases`, `Count`, `DeleteCases`, `Position`, `Replace`, `Map`, `Apply`, `StringCases` and others are on it, for argument position 2. The kernel's `SyntaxInformation` data plays no part in this. The FE matches on the short symbol name and ignores the context: `MyCtx`Count[x, Foo -> b]` is not coloured either.

No `SyntaxInformation` setting can put `XMLCases` on that list, so a paclet cannot get the `Cases` behaviour through supported means. Two settings avoid the red rule:

- `{_, _, _., OptionsPattern[]}`, the paclet's current setting. A rule in position 2 is read as the query. `XMLCases[pat]` is coloured "too few arguments". That is correct, because `XMLCases` has no operator form: its `countMessage` takes 2 to 3 arguments (`Kernel/HTMLPatterns.wl:2124`). Wolfram uses the same shape for `SequenceCases`, `SequencePosition`, `StringCount`, `SequenceCount` and `Level`.
- `{_, _., _., OptionsPattern[]}` with `"OptionNames" -> {}` (or `None`). The FE then checks no option names, so it colours no rule red. It also stops flagging a wrong option name, and `XMLCases[pat]` is not flagged.

The first is the better fit. Keep the current setting.

## Findings

### 1. The exemption list in `MiscExpressions.tr` (primary source)

File: `/Applications/Wolfram.app/Contents/SystemFiles/FrontEnd/TextResources/MiscExpressions.tr`, resource `FEExpressions`.

- Lines 6–16 hold a comment: "This expression is used to determine if rule arguments of certain functions are option rules or just normal rules." The value has three parts:
  - List 1 (line 19): functions that accept non-option rules in any argument position: `NetChain`, `NetFoldOperator`, `NetGraph`, `NetMapThreadOperator`, `Series`.
  - List 2: rules `position -> {{only-rules-with-LHS-from-List-3}, {any-rule-at-all}}`. For position 1 the "any rule" list holds `AnomalyDetection`, `AuthenticationDialog` and `CreateVectorDatabase`. For position 2 (lines 32–48) it holds: `Apply`, `Cases`, `ColorBalance`, `ConstructColumns`, `Count`, `DeleteCases`, `EdgeTaggedGraph`, `FirstCase`, `FileConvert`, `FirstPosition`, `FreeQ`, `FunctionLayer`, `GraphAssortativity`, `ImageCases`, `LayeredGraph`, `LayeredGraphPlot`, `LayeredGraphPlot3D`, `Map`, `MapIndexed`, `MemberQ`, `Once`, `PersistentSymbol`, `Position`, `ReplacePart`, `ReplaceRepeated`, `Replace`, `Scan`, `SelectFirst`, `StringCases`, `StringReplace`, `StringSplit`, `TextTranslation`, `Trace`, `TracePrint`, `TransformColumns`, `Transliterate`, `TreeLevel`, `TreePlot`, `VectorDatabaseSearch`, `VerificationTest`. Position 3 also has a list (`Classify`, `ServiceExecute`, …).
  - List 3 (line 63): `{"Left", "Right", "Top", "Bottom", "Front", "Back", "Center"}`, the rule LHSs accepted by the "only some rules" functions (`ImageRotate`, `LinearGradientImage`, `RadialGradientImage`).
- The FE binary contains the key: `strings /Applications/Wolfram.app/Contents/MacOS/WolframNB | grep virtualRulePositionExpr` finds it, next to `virtualOptionPositionExpr`. So the FE reads the resource by that name.
- The entries are plain name strings with no context.

### 2. How function information reaches the FE

- Built-in functions: `GetFEKernelInit.tr` line 352 sends `FrontEnd`SetFunctionInformation[Get[".../TextResources/English/FunctionInformation.m"], Contexts[]]` when the FE starts a user kernel (`SystemFiles/FrontEnd/TextResources/GetFEKernelInit.tr`, lines 340–353).
- User symbols: after each evaluation, `FrontEnd`Private`GetUpdatedSymbolContexts[]` calls `Internal`UpdateSyntaxInformation[]` (`GetFEKernelInit.tr` line 263). That function is built in: `Definition` shows only `Attributes = {Protected}`, and `Trace[..., TraceInternal -> True]` shows no top-level steps. The FE binary has these packet names next to each other: `SetFunctionInformation`, `AddFunctionTemplateInformationToFunctions` and `AddOptionInformationToFunctions` (`strings WolframNB`, around the `UpdateKernelSymbolContexts` entries). J/Link's `LinkSnooper.java` (`SystemFiles/Links/JLink/Source/Java/com/wolfram/jlink/util/LinkSnooper.java` lines 385–387) abbreviates `FrontEnd`AddFunctionTemplateInformationToFunctions` as a large packet, alongside `SetFunctionInformation`. It is likely, but not verified, that the kernel sends user `SyntaxInformation` with that packet.
- Elements of a `FunctionInformation.m` entry, worked out from the file contents (`Get` the file and count `Length` of each entry: 2→3545, 3→2327, 4→120, 5→82, 6→363):
  1. name, 2. `ArgumentsPattern`, 3. option names (`None` if none; string options are written `"\"Name\""`), 4. `LocalVariables` (e.g. `{"Table", {2, Infinity}}`), 5. `ColorEqualSigns` (e.g. `AddSides` → `{1, 2}`, `And` → `All`), 6. a list of attributes, in practice only `{"NumericFunction"}` (e.g. `Abs`). Elements 4 and 5 are `None` where a later element is present. The kernel shows elements 4 and 5 for built-ins: `SyntaxInformation[Abs]` gives `{ArgumentsPattern -> {_}, LocalVariables -> None, ColorEqualSigns -> None}`. Element 6 is not shown. None of these elements says how rule arguments are handled. That is decided only by the `MiscExpressions.tr` list.
- `"OptionNames"` is an undocumented `SyntaxInformation` key that first-party code uses (`SystemFiles/Components/PacletTools/DocumentationBuild/Kernel/SystemResourcesFromDocs.wl` around line 1073, `SyntaxInformationDataEntry` builds `{"ArgumentsPattern", "OptionNames", "LocalVariables", "ColorEqualSigns"}`. The coordinator also reported uses in ErrorHandling `Exceptions.wl:38`, FunctionResource `Function.m:668`, `Compile/InitializeCompiler.m:555`, RLink `RFunction.m:87`, `AddOns/Packages/Quaternions/Quaternions.m:351` and `AddOns/Packages/PlotLegends/PlotLegends.m:238`). It corresponds to element 3. The paclet already sets it (`Kernel/HTMLPatterns.wl:3807–3815`).
- FE error resources (`SystemFiles/FrontEnd/TextResources/ErrorMessages.tr` lines 2816–2826) contain `autoStyleReasonUnknownOption` "'%AUX%' is not an option for '%FUNCTION%'", `autoStyleReasonExcessArgument` "Too many arguments given for '%FUNCTION%'" and `autoStyleReasonMissingArgument` "Too few arguments given for '%FUNCTION%'". The matching `AutoStyleOptions` settings in the binary are `HighlightUnknownOptions`, `HighlightExcessArguments` and `HighlightMissingArguments`.

### 3. Experiments in a real front end (verified)

Method: a headless FE started with `UsingFrontEnd` does not apply function information by itself. Calling `SetFunctionInformation` from the controlling kernel had no effect either: `Table[i, {i, 3}]` was not coloured. Starting an FE-owned kernel with `FrontEndExecute[FrontEnd`EvaluatorStart["Local"]]` in a notebook with `Evaluator -> "Local"` makes the FE run `GetFEKernelInit.tr` for it, and autostyling then works (`Sin[x, y, z]` coloured red). The script below evaluates a definitions file in that kernel, writes the test inputs as Input cells, rasterizes the notebook, and counts red pixels per cell. Each result was also checked by eye in the PNG. "Red" below means coloured red; "clean" means not.

| Input | Result |
|---|---|
| `Cases[x, g[a] :> b]`, `Count[...]`, `Replace[...]` | clean |
| `Cases[x, Foo -> b]` | clean |
| `Cases[x, y, Foo -> b]`, `Cases[x, y, 1, 2, Foo -> b]`, `Count[x, y, 1, Foo -> b]` | red (`Foo`) |
| `DeleteCases`, `Position`, `ReplacePart`, `ReplaceRepeated`, `FreeQ`, `MemberQ`, `StringCases`, `StringReplace`, `StringSplit`, `FirstCase`, `Map`, `Apply`, `SequenceCases`, `StringCount` with `[x, Foo -> b]` | clean |
| `Activate`, `Binarize`, `AudioTrim`, `AlphabeticSort`, `ArraySimplify`, `StringPosition`, `StringDelete` with `[x, Foo -> b]` | red. These are System functions not on the list, e.g. `StringPosition` has the same `{_, _., _., OptionsPattern[]}` as `Count`. |
| `Plot[x, {x, 0, 1}, Foo -> b]` | red |
| `f1[x, g[a] :> b]` with `Options[f1] = {Heads -> False}`, `{_, _., _., OptionsPattern[]}` | red; the same for `"Heads"` string option names (`f2`) |
| user `{_, _., _., _., OptionsPattern[]}`, `{_, _., OptionsPattern[]}`, `{_, Optional[_], OptionsPattern[]}` | red; no form of the optional slot helps |
| user function with no `Options` (`f3`), or `Options` without `SyntaxInformation` (`f5`) | clean |
| `f6[x, g[a] :> b]` with `{_, _, _., OptionsPattern[]}` | clean; `f6[x]` gets the missing-argument marker |
| `"OptionNames" -> {}` or `None`, with `Options` defined | clean for `[x, g[a] :> b]`, `[x, Foo -> b]` and `[x, y, Foo -> b]`: no option check at all |
| `"OptionNames" -> {"\"Heads\""}` | `[x, g[a] :> b]` red; `[x, y, Foo -> b]` red; `[x, y, "Foo" -> b]` clean |
| `SetFunctionInformation` sent directly for `Global`g1` (Cases-format entry), or for a new `System`ZZCases` with `Cases`'s exact entry | red for `[x, Foo -> b]`. A System` context or the built-in transport is not enough. |
| `SetFunctionInformation` re-sent for `System`Count` | `Count[x, Foo -> b]` still clean |
| `MyCtx`Count` with `{_, _., _., OptionsPattern[]}` and Options | `[x, Foo -> b]` clean, `[x, y, Foo -> b]` red. The list is matched on the short name. |
| Installed paclet: `XMLCases[t, XMLPattern["a"] :> "hello"]` | clean |
| `XMLCases[XMLPattern["a"]]` | missing-argument marker |
| `XMLCases[t, p, 2, "AttributeReadings" -> r]`, `XMLCases[t, p, "Bogus" -> 1]` | clean |
| `XMLCases[t, p, Bogus -> 1]` | red (`Bogus`) |
| `xc1` = copy of `XMLCases` options with `{_, _., _., OptionsPattern[]}` | `xc1[t, XMLPattern["a"] :> "hello"]` red; `xc1[XMLPattern["a"]]` clean. This reproduces the original report. |

Other observations:

- An unknown option whose name is a string is never coloured red (`"Bogus" -> 1`, `h3[x, y, "Foo" -> b]`, `f2[x, "Foo" -> b]`). Only a symbol or compound LHS is.
- Extra non-rule arguments before `OptionsPattern[]` were not flagged (`h1[x, y, 1, 2]`, `XMLCases[t, p, 2, 3]`), but `Sin[x, y, z]` was. A 2010 MathGroup thread gives the reason: at read time the FE cannot tell that an argument is not a rule that will evaluate to an option ([MathGroup Archive 2010](https://forums.wolfram.com/mathgroup/archive/2010/Jul/msg00142.html), from a search result summary, not read in full).

### 4. Web sources

No Stack Exchange or Community post was found on `virtualRulePositionExpr` or this exemption. The `ArgumentsOptions` reference page ([reference.wolfram.com/language/ref/ArgumentsOptions.html](https://reference.wolfram.com/language/ref/ArgumentsOptions.html?view=all)) describes the kernel-side rule: a rule that does not match `OptionsPattern[]` counts as a positional argument. The FE does not apply this rule when colouring, except for the listed functions.

## Verified versus inferred

Verified:

- The list and its documented meaning (file contents).
- The FE colouring for every row in the table, rendered by a real FE with an FE-owned kernel.
- Name-only matching (`MyCtx`Count`).
- That `SyntaxInformation` patterns, a System` context and direct `SetFunctionInformation` all fail to give the exemption.
- The effect of `"OptionNames" -> {}`.

Inferred:

- That `MiscExpressions.tr` is the only source of the exemption. The binary could contain more logic, but the observed set (for example `Map` and `Apply` exempt, `StringPosition` not) matches the list exactly.
- That user `SyntaxInformation` reaches the FE via `AddFunctionTemplateInformationToFunctions`.
- The meaning of element 6 (`{"NumericFunction"}`), taken from its contents only.

## Options for the paclet

1. **Keep `{_, _, _., OptionsPattern[]}` (current, recommended).** A rule in position 2 fills the required query slot and is not coloured. `XMLCases[pat]` gets the missing-argument marker. That is correct, because `XMLCases` has no operator form and evaluating it gives the count message. Wolfram uses this shape for its own rule-taking functions that are not on the list (`SequenceCases`, `SequencePosition`, `StringCount`, `SequenceCount`). The same applies to `XMLFirstCase` (`{_, _, _., OptionsPattern[]}`) and `XMLDeleteCases` (`{_, _, OptionsPattern[]}`). If an operator form `XMLCases[pat]` is added later, this marker becomes a false positive.
2. **`{_, _., _., OptionsPattern[]}` with `"OptionNames" -> {}`.** No red rule, and `XMLCases[pat]` is clean. The cost is that `XMLCases[t, p, Bogus -> 1]` is no longer flagged. The only option, `"AttributeReadings"`, is a string, and unknown string option names are never flagged anyway, so the check catches little either way. The real loss is the missing-argument check. Use this only if an operator form is added.
3. **`{_, _., _., OptionsPattern[]}` with real option names (the old setting).** The query rule is coloured red. Not useful.
4. **Get onto the FE list.** This needs an edit to `MiscExpressions.tr` in the installation, or an FE resource override that replaces the whole `FEExpressions` resource. Neither is a paclet mechanism, both would break with FE updates, and neither was tested. Naming the function after a listed one (`Cases`) would work because matching is name-only, but that is not a realistic option.

So a paclet cannot get the `Cases` behaviour, which depends on a front-end name list. Option 1 gives the closest result, and for `XMLCases` it loses nothing.

## Appendix: test rig

Run as `wolframscript -file rig.wls /path/defs.wl 'input1;; input2;; ...' tag`. It writes `/tmp/sirig/<tag>.png` and prints red-pixel counts per test cell. An output cell from the definitions shifts the bands, so check the PNG then.

```wl
defs = $ScriptCommandLine[[2]];
tests = StringTrim /@ StringSplit[$ScriptCommandLine[[3]], ";;"];
tag = $ScriptCommandLine[[4]];
testBoxes = (ToExpression[#, InputForm, Function[e, MakeBoxes[e, StandardForm], HoldAllComplete]] /.
    s_String :> StringReplace[s, "Global`" -> ""]) & /@ tests;
res = UsingFrontEnd[
  nb = CreateDocument[{Cell["Get[\"" <> defs <> "\"]", "Input"]}, Visible -> False,
    WindowSize -> {900, 300}, Evaluator -> "Local"];
  FrontEndExecute[FrontEnd`EvaluatorStart["Local"]]; Pause[8];
  SelectionMove[First[Cells[nb]], All, Cell];
  FrontEndTokenExecute[nb, "EvaluateCells"]; Pause[6];
  SelectionMove[nb, After, Notebook];
  NotebookWrite[nb, Cell[BoxData[#], "Input"]] & /@ testBoxes; Pause[2];
  img = Rasterize[nb, ImageResolution -> 144];
  Export["/tmp/sirig/" <> tag <> ".png", img]; img];
d = ImageData[ColorConvert[res, "RGB"]];
ink = Map[Count[#, {r_, g_, b_} /; r + g + b < 2.4] &, d];
redrow = Map[Count[#, {r_, g_, b_} /; r > 0.7 && g < 0.45 && b < 0.45] &, d];
bands = {First[#], Last[#]} & /@ Split[Flatten[Position[ink, n_ /; n > 0]], #2 == #1 + 1 &];
Scan[Print[InputForm[#]] &, Transpose[{tests, Total[redrow[[#[[1]] ;; #[[2]]]]] & /@ Rest[bands]}]];
```
