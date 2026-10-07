---
status: accepted
---

# The paclet is named `HTMLPatterns`

Through 2.1.0 the paclet was called `BeautifulTureen` (`MaximilienTirard/BeautifulTureen`), a pun on Python's Beautiful Soup (bs4). From 3.0.0 it is `HTMLPatterns`: paclet `MaximilienTirard/HTMLPatterns`, context `` MaximilienTirard`HTMLPatterns` ``. The old name did not tell a Wolfram Language user what the paclet does, and the new one does. This is the only tracked file that names the old paclet. The work is recorded in `.scratch/paclet-naming/map.md` and its tickets.

## Context

At the internal code review of 2026-10-05, colleagues disliked the name `BeautifulTureen`:

- It is a nod to bs4 and tries to be clever.
- It is not memorable unless you get the pun, that is, unless you already know bs4.
- It is hard to type.
- It does not tell a WL user what the paclet does.

Descriptive names were suggested there, but they felt lacklustre, and nobody proposed an alternative. The paclet was about to be presented publicly for the first time at the Wolfram Technology Conference, where the talk notebook and recording stay online. Renaming it after publication would need an alias.

## Decision

### Criteria

A candidate had to pass these gates before it was ranked:

- It follows the naming conventions of the Paclet Repository: CamelCase ASCII, not a single generic word, no confusing near-match with an existing paclet, no System symbol or Function Repository resource of the same name, and nothing that reads as an extension of the `Web…`, `XML…` or `Select…` families.
- It is not the name of an existing HTML or XML tool from another ecosystem, unless the nod is deliberate and the name means something without it.
- It contains no word for something the paclet does not do. It does not fetch pages, drive a browser or parse (`Import` parses), so no "Parse", "Crawl", "Browser" or "Web".
- It has at most about 16 characters (12 or fewer preferred) and at most three words.
- It is not shaped like a symbol the user would look for, such as `HTML‹Noun›` in the singular, `‹X›To‹Y›`, `XML‹Verb›` or a verb-object name such as `MatchHTML`. A plural noun that names the field reads as a topic and passes.
- It has no `…Link` suffix, because the paclet is not a binding to an external library.

Candidates that passed were ranked by these criteria, in order:

1. A WL user can guess what it does: the name points at HTML. XML support stays implicit, as it does in bs4.
2. It is easy to type in `Needs` and easy to say in a talk.
3. It is memorable without backstory.
4. It has some character.

The preferred shape was a compound coined word that still states the domain, as `Chatbook` does. A nod to bs4 was allowed but not required: "Soup" passes, because "tag soup" is a web term in its own right, while "Tureen" was ruled out because it caused two of the objections. A word with a negative or effortful dictionary sense, "Scrape", the `…Tools` and `…Kit` suffixes, and an existing project with the same name counted against a candidate without excluding it. The paclet name saying "HTML" while its functions say `XML…` did not count against a candidate: `XML…` names the WL expression type the functions work on.

### Shortlist

A first draft of 20 scored names was cut to four, which went to the colleagues:

- `HTMLPatterns`: says HTML and says patterns, in WL's own terms.
- `DOMPatterns`: "DOM" is the exact web term for the tree, but said aloud it sounds like a person's name, and not every WL user knows the term.
- `PatternSoup`: the most character, but it says HTML only to someone who knows "tag soup".
- `SoupLadle`: no domain word. It served as the control in the colleagues' test of what each name suggests.

Among the names cut: `PluckHTML` and `GleanHTML` for their negative or effortful dictionary senses, `MatchHTML` because it reads as a function, `MarkupPatterns` because "Markup" is not a WL term and invites a Markup/Markdown mix-up, and `SoupSieve` because it is bs4's own CSS-selector library.

### Choice

The colleagues agreed on `HTMLPatterns`, and the author chose it on 2026-10-07. The weak point accepted with it: a user may look for an `HTMLPattern[…]` function by analogy with `XMLPattern`, `DatePattern` and `KeyValuePattern`. A lesser point was known too: in web design "HTML patterns" also means UI component libraries. No single well-known project has the name.

## Consequences

- The rename is version 3.0.0, because the context changes and code that loads the old context breaks. The release contains the rename and nothing else.
- There is no alias or compatibility shim. The paclet was never published: it was not on the Paclet Repository, and had no GitHub release or version tag.
- The documentation does not mention the old name. The tutorial is now *Scraping HTML with Patterns*, and the description no longer refers to Beautiful Soup. The bs4 comparisons in the tutorial and reference pages stay.
- The GitHub repository is renamed to `mtirard/HTMLPatterns`. Links to issues under the old repository name redirect.
- Public symbol names (`XMLPattern`, `Child`, `Descendant`, `Adjacent`, `Sibling`) are unchanged. They are API design, separate from the paclet's name.
