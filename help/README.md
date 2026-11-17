# help

BetterBags' in-game help: the articles, and the search that finds them. The Help page that shows them is in
`next/settings/help.lua` and `next/settings/article.lua`. The full design is in `.claude/rules/help.md`.

## Files

### search.lua (`HelpSearch`)

Ranks documents for what a player types, in plain Lua 5.1 tables built when the help first searches.

- `Normalize(text)`: the client's escape codes dropped, lowercased (ASCII, Latin-1, Cyrillic), accents folded.
- `Stem(word)`: a light Porter stemmer (plurals, past and -ing forms, a final e), English only; `STEMS` keeps words
  apart that the rules would merge ("setting" is not "set").
- `Terms(text)`: the stems of a text's words, stop words left out; Korean, Chinese and Japanese text as pairs of
  characters.
- `Build(docs)`: an index over documents, each `{ id, fields = { title, keywords, questions, headings, body } }`,
  every field a list of strings. `index:Query(text, { limit })` ranks them by BM25F over those fields
  (`search.FIELDS`: each field's weight and length normalization), a document matching every word typed before one
  matching some, and returns the terms matched. The word still being typed matches the start of longer words; a word
  a letter or two off matches the word meant; two words typed as one match both; a player's word for what the help
  names otherwise matches it too (`search.SYNONYMS`).
- `Snippet(text, terms, width)`: the part of a text around the words matched, and where they are in it.

### articles.lua (`HelpArticles`)

The articles, in groups, in the order they are defined.

- `Group(def)`, `Define(def)`: add a group, or an article to a group (defining an id again replaces it in place).
- `Get(id)`, `GroupOf(id)`, `IsShown(article)`: an article is shown with the bags it is about (`design`) and while its
  `shown()` says so.
- `Tree()`, `Shown()`, `Featured()`, `Related(article)`, `Adjacent(article)`: what the Help page lists, for the bags
  in use.
- `Docs()`, `TextOf(article)`: the articles as the search's documents, and an article's text for its snippet.
- `Search(text, limit)`: the articles shown, ranked, each `{ article, score, snippet, spans }`. The index is built
  again when the articles shown change.

### articles/*.lua

One file per group: its title and its articles. Each article has a title, a one-sentence summary, a body of blocks
(heading, text, list, steps, search example, tip, warning, a link to a settings page or to another article, a setting
shown as its own row), the keywords and questions a player may search for it by, related articles, and the settings
and settings pages it explains. Every string is `L:G("...")` on one line, in double quotes, with no escapes (what
`tools/translate` reads); a search example is never translated.

## Adding an article

1. Read the code of what it explains; write only what the code does.
2. Add it to the group's file, with `settings` and `pages` naming what it explains, and keywords and questions in a
   player's words.
3. A new group is a new file, listed after `help\articles.lua` in all five TOCs, in the same order.
4. Run `spec/help/` and `spec/integration/help_coverage_spec.lua`: they check every file, link, string, example,
   setting and settings page.

## Measuring the search

`spec/help/queries.tsv` holds three rounds of searches written by someone who never saw the articles' words, and
`spec/help/quality_spec.lua` keeps each round's results from getting worse. Round 3 was never tuned against: it is the
measure. See `.claude/rules/help.md` §2 before changing weights, synonyms or keywords.
