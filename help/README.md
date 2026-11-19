# help

The `help/` package contains BetterBags' in-game help data and Lua 5.1 search engine. The settings window displays articles on the `Help` page (`next/settings/help.lua` and `next/settings/article.lua`), lists matching articles under `Help Articles` in the settings window search (`next/settings/window.lua`), and opens to the `Help` page on `/bb help` (`config/config.lua`). (In the settings window, `Settings Window` is a section on the `Appearance` page in classic mode containing `Settings Window Theme`.) The full design specification is in `.claude/rules/help.md`.

## Package Contents

### `help/search.lua` (`HelpSearch`)

`HelpSearch` indexes and ranks documents in plain Lua 5.1 tables with no external dependencies.

- `search.FIELDS`: field weights and BM25F length normalization (`b`): `title` (`weight = 6`, `b = 0.5`), `keywords` (`weight = 4`, `b = 0.75`), `questions` (`weight = 3`, `b = 0.9`), `headings` (`weight = 0.75`, `b = 0.5`), and `body` (`weight = 0.4`, `b = 0.9`).
- `search.SYNONYMS`: maps player terms (such as `storage`, `bucket`, or `skin`) to indexed terms at weight `0.8`.
- `search.STOP`: English stop words excluded from indexing and from finished-word queries.
- `StripCodes(text)`: removes Blizzard color (`|c...`, `|cn...:`, `|r`), texture (`|T...|t`), and atlas (`|A...|a`) escape sequences, unwraps hyperlinks (`|H...|h...|h`) to their display text, turns `|n` into a space, and unescapes `||` to `|`.
- `Normalize(text)`: runs `StripCodes`, lowercases ASCII, Latin-1, and Cyrillic characters, and folds Latin-1 accents to ASCII.
- `Stem(word)`: changes only words made entirely of 3 or more lowercase `a-z` letters, applying Porter's first step and dropping a trailing `e`; shorter words and words with non-`a-z` characters return unchanged. A local `STEMS` table (`{ setting = "setting", settings = "setting" }`, not a module field) gives `setting` and `settings` the stem `setting` so they match each other without colliding with `set` (an equipment set).
- `Terms(text)`: runs `StripCodes`, scans words, drops stop words in `search.STOP`, stems non-wide words, and converts Korean, Chinese, and Japanese runs into overlapping two-character pairs (or a single character when length is 1).
- `Build(docs)`: builds a `HelpIndex` from `HelpSearchDoc` entries (`{ id, fields = { title, keywords, questions, headings, body } }`), where every field is an array of strings. Document order is preserved for tie-breaking.
- `index:Query(text, opts)`: ranks documents matching `text` by BM25F (`K1 = 1.2`) multiplied by the coverage factor `0.3 + 0.7 * matched_items / total_items`, truncates to `opts.limit`, and returns `(results, matched)`. Each entry in `results` is `{ id, score }`, and `matched` maps matched stems to `true`.
  - Query items: a stop word adds no query item unless it is the last word, is still being typed (no trailing whitespace), and has 2 or more characters (matching longer indexed words that start with it, such as `the` matching `theme`); a Korean, Chinese, or Japanese run adds one item per character pair; a split compound word adds two items (one when one half is a stop word).
  - Matching order per word: exact stem (weight `1`), active prefix matches when the last word is still being typed and has 2 or more characters (up to 40 words, weight `0.6` to `0.9`), and `search.SYNONYMS` (weight `0.8`). If none match, compound splitting runs for words of 5 or more lowercase `a-z` letters (two halves at `0.9` each, allowing one half to be a stop word or synonym); if still unmatched, optimal string alignment edit-distance matching runs for words of 4 or more lowercase `a-z` letters (1 edit at weight `0.7`, or up to 2 edits for 8 or more letters at weight `0.5`).
- `Snippet(text, terms, width)`: selects the sentence in `text` containing the most distinct terms from `terms` (falling back to the first sentence) and returns two values: `(snippet, spans)`. Sentences of at most `width` characters return whole; longer sentences crop to `width` characters around the first matched word (in a Korean, Chinese, or Japanese run, the first matched character pair), starting up to `width / 3` characters before it unless that would pass the sentence's end (then ending at the sentence's end), with `…` added outside `width` on each cut side. A cut falls at a space or beside a kana, CJK ideograph, ideographic space, or CJK or full-width punctuation character, because Chinese and Japanese place no spaces between words; Korean, which places spaces between words, is cut only at spaces, and full-width letters and digits are cut only at a word's edge. A cut never leaves a closing mark (such as `，`, `。`, `）`, `」`, or `”`) at the snippet's start or an opening mark (such as `（`, `「`, or `“`) at its end, and spaces and ideographic spaces at either edge are dropped. The start never moves past the first match, and when no cut point lies between the first match's end and the window's end, the end is cut at the window's edge. `spans` is an array of `{ start_byte, end_byte }` byte offsets in the cropped string.

### `help/articles.lua` (`HelpArticles`)

`HelpArticles` registers article groups and articles, filters visibility, and caches the search index.

- `Group(def)` and `GroupOf(id)`: register `{ id, title }` in `groups` (replacing an existing `id` in place) and look up a group by `id`.
- `Define(def)`: registers a `HelpArticleDef` in `list` (replacing an existing `id` in place) and increments `version`. Errors if `def.group` is not registered via `Group`.
- `Clear()`: clears `groups`, `list`, and the cached search index, and increments `version`.
- `Get(id)`: returns the article matching `id`, or `nil`.
- `IsShown(article)`: returns `true` when `NextSettingsPages:InDesign(article)` is `true` and `article.shown` is `nil` or returns `true`.
- `Tree()`, `Shown()`, `Featured()`, `Related(article)`, `Adjacent(article)`: return visible groups and articles in definition order for the active design and client. `Featured()` returns shown articles with `featured = true`; `Adjacent(article)` returns `(before, after)` across groups in `Shown()` order.
- `TextOf(article)`: joins `summary` and body `text`, `tip`, `warning`, `list`, and `steps` strings with `\n` for snippet extraction.
- `Docs()`: builds `HelpSearchDoc` entries for all `Shown()` articles, indexing `title`, `keywords`, `questions`, `headings` (`heading` blocks), and `body` (`summary`, `example` strings, `open.text`, and `TextOf` lines).
- `Search(text, limit)`: rebuilds the `HelpSearch` index whenever `version` or the `Shown()` IDs change, queries up to `limit` results, and returns `{ article, score, snippet, spans }[]` with `Snippet` width `140`.

### `help/articles/*.lua`

Eleven files define the 11 groups and 80 articles in TOC load order: `start.lua`, `bags.lua`, `next.lua`, `search.lua`, `categories.lua`, `automation.lua`, `bank.lua`, `appearance.lua`, `profiles.lua`, `integrations.lua`, and `troubleshooting.lua`. A group file may define an article in another group; for example, `help/articles/bank.lua` defines `classic-currency` in the `bags` group.

## Settings Window Integration and Article View

- Opening and navigation (`next/settings/help.lua`, `next/settings/window.lua`, `config/config.lua`): `/bb help` sends `help/Open` to open the `Help` page on `Help Home` or on `Search Results` when followed by query words. Typing in the settings window's own search lists up to 4 matching articles under `Help Articles` and sends `help/OpenArticle` on click.
- Home, search results, and cards (`next/settings/help.lua`, `next/settings/article.lua`): the home view displays at most 6 featured cards (the first 6 shown featured articles in tree order). `article.summary` displays under the title in the page header, on the home page's featured cards, and on the `Previous` and `Next` cards at the bottom of an article; search result cards display the cropped 140-character snippet from `HelpArticles:Search`.
- Dynamic visibility and refresh (`next/settings/article.lua`, `next/settings/pages.lua`, `next/settings/help.lua`): `NextHelpView:Refresh` re-reads the displayed article whenever the `Help` page comes back into view, preserving scroll position. `NextHelpArticle:Show` evaluates every dynamic element for the active design, client, and page state:
  - A `see` block renders only while `HelpArticles:IsShown` returns `true` for the target article.
  - An `open` block renders only while `NextSettingsPages:IsShown` returns `true` for the target page and, when `tab` is specified, while that tab appears in `NextSettingsPages:ShownTabs(page)` (calling `page.choose()` first when defined, such as on the `Categories` page), because the settings window falls back to its first shown page or tab when asked to open an unshown one.
  - A `setting` block renders only while `NextSettingsPages:ShowsSetting(id, bag)` returns `true` (a shown page and shown tab bound to that `bag.kind` containing a matching, non-hidden section and row for the active design and bag).
  - `Related Articles` lists only shown related articles not already linked by a `see` block in `body`.

## Article Format

### `HelpArticleDef` Fields

- Required: `id` (unique string), `group` (registered `HelpGroupDef.id`), `title` (unique string, 1 to 3 words), `summary` (string displayed under the page title, on home page featured cards, and on `Previous` and `Next` cards), and `body` (non-empty array of `HelpBlock` tables).
- Optional metadata: `keywords` (`string[]`), `questions` (`string[]`), `related` (array of article IDs), `featured` (`boolean`), `design` (`"next"` or `"classic"`), `shown` (`fun(): boolean`), `settings` (array of `SettingsCatalog` IDs), and `pages` (array of `"page"` or `"page:tab"` strings).

### `HelpBlock` Kinds

Each entry in `body` holds one block kind:

- `heading`: 1 to 3 words starting with an uppercase letter, not beginning with any clause word rejected by `spec/help/content_spec.lua`, with no trailing punctuation, unique within the article.
- `text`: paragraph string.
- `list`: array of bulleted item strings.
- `steps`: array of numbered step strings.
- `example`: raw search query string (never wrapped in `L:G`), rendered as a static field in the input's look with the search icon rather than an editable box; may include `text` describing what the query matches.
- `tip` or `warning`: callout string.
- `open`: `{ page, tab?, text }` link button opening a settings page or tab.
- `see`: article ID rendered as a link button when that article is currently shown.
- `setting`: `SettingsCatalog` ID rendered as a live settings row; accepts optional `bag` naming a bag from `SettingsCatalog:Bags()`.

### Localization Strings

Every localizable string must use `L:G("...")` on a single line in double quotes with no `\` escapes, no `")` or `')` substrings, and no `|` characters (`tools/translate/translate.go` and `spec/help/content_spec.lua`).

## New Articles

1. Read the implementation of every setting, page, and behavior the article covers; state only behavior verified in code.
2. Add the article to its group file under `help/articles/`, including `settings`, `pages`, `keywords`, and `questions` (`#(keywords) + #(questions) >= 6`). If adding a new group file, list it after `help\articles.lua` in the exact same order across all five `.toc` files: `BetterBags.toc`, `BetterBags_Camelot.toc`, `BetterBags_Mists.toc`, `BetterBags_TBC.toc`, and `BetterBags_Vanilla.toc`.
3. Run the help specs with `~/.local/lua51/bin/busted`:
   - `spec/help/content_spec.lua`: checks `.toc` file lists and order, unique IDs and titles, 1-to-3-word titles, heading rules (uppercase first letter, 1 to 3 words, no trailing punctuation, no listed leading clause words, unique within the article), single-kind blocks, `related` and `see` targets, design visibility, and `L:G("...")` string rules.
   - `spec/integration/help_coverage_spec.lua`: under BetterBags Next only, checks that every `SettingsCatalog` ID appears in at least one article's `settings` and every `example` parses via `QueryParser:Query` with valid `Search` fields; under both `"next"` and `"classic"` designs, checks that every `NextSettingsPages` page and tab (excluding `help` and `plugin:*`) appears in `pages`, every `open` and `setting`/`bag` target exists, and every shown article renders in `NextSettingsHelp:OpenArticle` without errors.
   - `spec/help/search_spec.lua`, `spec/help/articles_spec.lua`, `spec/next/settings/help_spec.lua`, `spec/next/settings/pages_spec.lua`, and `spec/help/quality_spec.lua`.

## Search Quality

`spec/help/queries.tsv` holds three rounds of 400 queries (5 per article), authored by the `writer` agent from each article's title, summary, and headings in an earlier version of the text as players would type them. `spec/help/quality_spec.lua` runs each query against `HelpArticles:Search(query, 3)` under a design and client configuration (`retail`, `Classic Era`, `Mists of Pandaria Classic`, `WoW: Forever`) where the target article is shown, and enforces minimum top-1 and top-3 hit rates:

- Round 1: floors `0.71` first / `0.90` top 3 (measured `72.2%` / `90.8%`).
- Round 2: floors `0.71` first / `0.90` top 3 (measured `72.2%` / `90.8%`).
- Round 3 (held out): floors `0.72` first / `0.855` top 3 (measured `73.0%` / `86.5%`).

Rounds 1 and 2 were used to tune field weights, synonyms, `STEMS`, and compound splitting; round 3 is held out and must not be tuned against. `body` weight remains `0.4` because lowering it to `0.2` (the break occurs between `0.24` and `0.23`) breaks the `spec/help/search_spec.lua` invariant that a document matching every typed word outranks one repeating a single word.
