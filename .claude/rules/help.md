---
paths:
  - "help/**/*.lua"
  - "next/settings/help.lua"
  - "next/settings/article.lua"
  - "spec/help/*"
  - "spec/next/settings/help_spec.lua"
  - "spec/integration/help_coverage_spec.lua"
---
# The Help

BetterBags' help: articles about everything it does, searched in game, read on a Help page of the settings window.
Asked: "an interactive help system ... some sort of KNN search for help, and various help topics". Decided with the
user:

- **Search is option 2**: word search in game (BM25F over each article's fields), with keywords and questions written
  for each article so it is found by a player's words, not only its own. No embeddings: nothing outside Lua 5.1, and
  nothing to precompute or ship.
- **A page of the settings window**, its own list in the sidebar as the Categories page has, a home asking "What do
  you need help with?", search results, an article view, and motion like the rest of BetterBags Next.
- **No bag menu entry.** `/bb help`, and help articles listed by the settings window's own search, open it.
- **Articles hide by design and client**: an article about BetterBags Next's vendor does not show with the classic
  bags, one about the Warbank not on a client without one.
- **The text is iterated with the `writer` agent** (`~/.config/ask/agents/writer.md`), in a loop (§3).
- **`tools/translate` is not run** for the new strings.
- **The tree keeps every group open** (asked: "expand and keep expanded, all the help headers on the left"); its
  headings fold nothing.
- **A title is one to three words** (asked: "titles should be 1, 2, MAYBE 3 words max. they are titles, not
  descriptions"): it names the article; its summary describes it. Each title is its own. The longer titles they had
  are kept among their keywords and questions, so a search for those words still finds them.
- **A heading is a title too** (asked, of "Where sections come from" and "Which section wins": "these are a hard no.
  do not make statements in subtitle or sections. this should be 'Section Sources' and 'Section Ordering'"): one to
  three words in Title Case naming what the part covers, never a clause, a question or a statement, each its own in
  its article. The first drafts' headings were phrases, and the writer was asked only for "short, Sentence case"
  headings, so it kept them: the writer's brief for any heading states this rule.

## 1. Articles (`help/articles.lua`, `HelpArticles`; `help/articles/*.lua`)

Articles are data, in groups, in the order they are defined. Each file in `help/articles/` defines one group
(`articles:Group({ id, title })`) and its articles (`articles:Define(def)`); the TOCs load them after
`help\articles.lua`, the same files in the same order in all five (`spec/help/content_spec.lua`). Defining an id again
replaces it in its place; an article in a group never defined is an error.

An article (`HelpArticleDef`): `id`, `group`, `title` (one to three words, its own), `summary` (one sentence: under the title and in results),
`body` (blocks), `keywords` and `questions` (what a player may search for it by), `related` (ids, listed under it),
`featured` (on the home), `design` ("next" or "classic": shown only with those bags), `shown()` (shown only while it
says so: a client's flags), `settings` (catalog ids it explains) and `pages` ("page" or "page:tab" it explains).

A block (`HelpBlock`) is one of: `heading` (a title of one to three words, never a clause), `text`, `list`, `steps`, `example` (a search, typed as is and never
translated, with `text` saying what it finds), `tip`, `warning`, `open = { page, tab?, text }` (a link that opens a
settings page), `see` (a link to another article), `setting` (the setting itself, as its own row, which changes it;
with `bag`, the name of the bag a bag's own setting is bound to, as `SettingsCatalog:Bags()` names it).

Shown: `IsShown` (its design matches `BagSystem:ActiveDesign()`, and its `shown()` is true); `Tree` (groups with
articles shown, in order), `Shown`, `Featured`, `Related`, `Adjacent` (before and after it in the tree, across
groups) and `Search` leave out the rest. The index is built when the help first searches, and again when the articles
shown change (the bags switched) or an article is defined.

**Strings.** Every string is `L:G("...")` on one line, in double quotes, with no escapes and no `")` inside it: what
`tools/translate` reads (its pattern ends a string at the first quote followed by a parenthesis and never crosses a
line). `spec/help/content_spec.lua` checks every file. A search example is a raw string, never `L:G`: it is typed as is.

**80 articles in 11 groups**: Getting Started (`start.lua`), Your Bags (`bags.lua`), BetterBags Next (`next.lua`),
Search (`search.lua`), Categories (`categories.lua`), Selling and Depositing (`automation.lua`), Bank and Warbank
(`bank.lua`), Appearance (`appearance.lua`), Profiles and Settings (`profiles.lua`), Other Addons
(`integrations.lua`), Troubleshooting (`troubleshooting.lua`). Coverage (`spec/integration/help_coverage_spec.lua`, on
the whole addon): every setting of the catalog is in some article's `settings`; every page and tab of the settings
window, with either design, in some article's `pages`; every `open` names a page and tab that exist and every
`setting` block one the Help page can draw (a bag's setting with its bag); every search example parses
(`QueryParser:Query`) and names only fields the search indexes; every article shown opens on the Help page without an
error, with either design.

## 2. Search (`help/search.lua`, `HelpSearch`)

Text is made comparable (`Normalize`: the client's escape codes dropped, lowercased in ASCII, Latin-1 and Cyrillic,
accents folded), cut into words (`Terms`), each stemmed (`Stem`: Porter's first step and a final e dropped, English;
`STEMS` names words the rules would give another word's stem: a setting is no equipment set) with stop words left out;
Korean, Chinese and Japanese runs become pairs of characters. A document is ranked by BM25F over its fields
(`search.FIELDS`), times `0.3 + 0.7 * matched / typed`, so a document matching every word typed comes before one
matching some.

| Field | Weight | b | What it holds |
|---|---|---|---|
| title | 4 | 0.5 | The title |
| keywords | 6 | 0.75 | Its keywords |
| questions | 0.75 | 0.9 | Its questions |
| headings | 1.5 | 0.5 | Its headings |
| body | 0.4 | 0.9 | Its summary, paragraphs, lists, steps, tips, warnings, examples |

What each word typed searches for (`indexProto:items`), each with how much a match counts: its stem (1); while it is
still being typed (no space after it), longer words it starts (0.6 to 0.9, more for less left); its synonyms
(`search.SYNONYMS`, 0.8); when the documents have none of these, two words run together (`split`, 0.9 each: two words
the documents have, else one and a stop word, "myvault", "filterby"; a half may be a synonym), tried before a near
word; else a word one letter off (0.7) or, for a word of 8 letters or more, two (0.5): a letter wrong, missing, added
or two swapped. A stop word searches for nothing unless it is still being typed ("the" may become "theme").

**Synonyms** are a player's words for what the articles name otherwise: storage and vault for the bank, a bucket for a
category, a pouch for a bag, a skin for a theme, a toon for a character, other bag addons' words. They apply to every
article, so only words that mean one thing everywhere: "filter" and "rule" (AdiBags' and ArkInventory's categories)
mean search in BetterBags, "bar" is the Food & Drink bar and the currency bar, and none of them is a synonym.

**Measured** (the data-driven rule: a change to the search is shown by these numbers). Three rounds of 400 searches,
5 per article (`spec/help/queries.tsv`: round, article, search), written by the `writer` agent from each article's
title, summary and headings alone, as players would type them (other addons' words, a frustrated player, one or two
words, typos and words run together, WoW slang). Rounds 1 and 2 were what the weights, synonyms, stems, split and
words were tuned against; round 3 was not, and measures the search:

| Round | Found first | Among the first three | Mean reciprocal rank |
|---|---|---|---|
| 1, before tuning | 70.2% | 87.2% | 0.793 |
| 1, after (tuned on) | 80.8% | 96.2% | 0.884 |
| 2, before its own tuning | 68.0% | 85.8% | 0.777 |
| 2, after (tuned on) | 75.5% | 93.5% | 0.846 |
| 3 (held out) | 76.8% | 89.0% | 0.837 |
| 3, after the titles were shortened | 77.0% | 88.8% | 0.838 |
| 3, after the headings were made titles | 77.5% | 89.5% | 0.841 |

On round 3, a question, a short search and a search with a typo find their article first about 89% of the time; a
symptom ("my bags keep...") 56%, WoW slang 60%, and those are most of what misses: a word search cannot tell what a
symptom means. `spec/help/quality_spec.lua` keeps every round at least what it found when the help shipped,
less a little. To tune again: tune against rounds 1 and 2, have the writer write a new held-out round (never shown its
misses), measure on it, and add it to `queries.tsv` and the floors. Never tune against round 3.

`Snippet` returns the part of an article's text around the words matched, with where they are, for a result card.

## 3. Writing the articles

Facts come from the code, never from memory: the settings window's every page, tab, section and setting dumped from
the whole addon (`spec/helpers/whole_addon.lua`), the catalog's names and descriptions, the README, the rules files,
and the code where those disagree or say nothing (the menus, header buttons, tooltips, what a click does). The text
went through the `writer` agent in a loop: each group's prose extracted as labelled pieces, rewritten by the writer
(keeping every name of a setting, page, tab, button and command as written, and every fact), applied, and every
changed piece checked against its draft for a changed fact, which was read and fixed when flagged. Keywords and
questions came from the writer too: ten phrases a player would type per article, short ones as keywords, questions and
longer ones as questions; then the concepts the tuning rounds showed missing (§2).

A new feature needs its article, or its settings in an existing one's `settings`: the coverage spec fails on a setting
or a settings page no article explains.

## 4. The Help page (`next/settings/help.lua`, `NextSettingsHelp`)

The last page of the settings window (`NextSettingsContent` defines `helpPage:Page()` after QuickFind), under its own
heading, Help. Its own list in the sidebar (`sidebar`: the window slides the pages out and the tree in, next-settings.md
§3), its header read from what it shows (`heading`), and one tab of one block filling the page, the view.

- **The tree** (`CreateTree`): Help Home, then each group's heading and every article under it, the rows of
  `NextSettingsNav` (next-settings.md §3) as the window's list of pages draws them. Headings take no click and fold
  nothing. The chosen row's fill and bar are a marker that glides from one row to the next, the tree scrolled just
  enough to show the row (`reveal`: an article opened from a search or a card may be far down it); the rows fade in
  one after another as the tree slides in. The bags switched while it shows: it lists the articles of the new bags.
- **State**: what the page shows, `{ view = "home" | "results" | "article", query, articleId }`, kept for the session
  (`Init` from `core/init.lua`), and the direction an article came from (later in the tree: forward). An article the
  bags in use do not show (they were switched while it showed) gives way to the search it was opened from, else the
  home (`Settle`, read before the header, the tree's choice and the view).
- **Opening it**: `Open(ctx, query)` (`help/Open`: `/bb help` and the words after it, `config/config.lua`) shows the
  home, or the results for the words; `OpenArticle(ctx, id)` (`help/OpenArticle`: the settings window's search) an
  article; both open the window on the page, or show the page when the window is open. The messages are registered in
  `OnEnable` (`Enable` from `core/init.lua`).
- **The home**: "What do you need help with?" and a line under it, over a search box with a soft halo (stronger while
  focused), and the featured articles as cards (at most 6). It rises and fades in.
- **Search**, as typed: the box glides to the page's top and the articles found (at most 30) show as cards, each its
  title, group and snippet with the words matched in `MatchColor`; coming into view every card staggers in, one an
  earlier search showed too, and while they show a card still found slides to its new place as the ranking changes
  (Motion). A new search shows from its top, as the window's own search does. Nothing found says so. Enter opens the first, the arrow keys choose another; clearing the
  box or Escape goes back to the home. The header says what was searched for.
- **An article** slides in from the right going forward and from the left going back, scrolled to its top.
- **The header** follows: `settings:ShowHeading()` reads `Heading()` again (the article's title and summary, the
  search, or the home's), unless the window's own search shows.
- **The window's own search** lists the help's articles too, in a Help section under the settings found
  (next-settings.md §3).

## 5. An article's view (`next/settings/article.lua`, `NextHelpArticle`)

Blocks one under another, no wider than `MaxWidth`, each made once per kind and reused: a heading in capitals (as a
settings page's section titles), a paragraph, a list after its bullets, steps after their numbers, an example as typed
in a field (the input's fill and edge) with what it finds, a tip and a warning over their fill with their accent, a
link to another article or to a settings page (`settings:Open(page, tab)`), and a setting as `NextSettingsRows`' own
row bound to its bag, which changes it (made once per setting and bag); a change shows every setting the article shows
again (`RefreshSettings`), as a settings page does, since one may follow another (Compact Sections is used only with
Section Columns over 1). A theme applied lays the article and the results out again in its fonts. Under them, its related articles shown, as
links, and the articles before and after it in the tree as `NextSettingsCards` cards (next-settings.md §3).

## 6. Theme keys

`Settings.Help` in `sonata/themes/next/default.lua` (every theme inherits it): the home's `PromptFont`, `LeadFont`,
`SectionFont`, `PromptGap`, `Gap`, `SearchWidth`, `Halo` and `FocusAlpha`; `MatchColor` for the words matched; an
article's `MaxWidth`, `BlockGap`, `HeadingGap`, `HeadingFont`, `TextFont`, `ExampleFont`, `ListIndent`, `Bullet`,
`Tip`, `Warning`, `AccentWidth`, `NotePad`. The fonts and `MatchColor` are in `sonata/next.lua`'s `FONT_KEYS` and
`COLOR_KEYS`, so a theme's fonts and colors reach them. Cards are `Settings.Cards`', the tree's rows `Settings.Nav`'s.

## 7. What the bug reviews found

Two reviews of the code (CLAUDE.md, Prime Directive #2), and one of the articles against the code.

- **Fixed, test-first** (`spec/next/settings/help_spec.lua`, "bug review"): an article's settings did not follow one
  another (§5); an article the switched bags hide stayed on screen (§4, `Settle`); a new search, the same one again, or
  one typed while the results faded out kept the last scroll or showed its cards at once (§4); the window's own search
  listed two sections titled Help (now Help Articles); `guide` and `tutorial` were synonyms of a stop word; a theme
  left the article and results laid out in the old fonts, or, restyled before the buttons, its links at the old
  buttons' height (a link's button is restyled before it is measured, patterns-ui-themes.md); the tree did not scroll
  to the article chosen, and then scrolled back to it on every restyle (it reveals a row newly chosen, once).
- **The articles**: 18 said something the code does not do (Auto Sell with Confirm Auto Sell on by default, the
  classic bags' right-click needing Enable Category Sell and Deposit and selling 10 at a time, a dropped section of 12
  or fewer selling at once, the Warbank's gold clicks, the classic bank's tabs and bags, profile switches, and more);
  each was read in the code and corrected.
- **Left as they are, reported to the user**: an article opened from the window's search or the tree keeps the Help
  search box's last words (a choice, not a fault); reversing a slide part way may jump (not reproduced); a snippet is
  cut at spaces, so a translation with no spaces between words (Korean, Chinese) would be cut short (no such text
  yet); the word being typed matches at most 40 longer words, in the index's order; a setting row's label is not
  restyled before it is measured, so a theme's font wrapping a setting's name onto more lines would leave its block
  short until the next article (the mock's text has one size, so not reproduced).

## 8. Specs

`spec/help/search_spec.lua` (the search), `spec/help/articles_spec.lua` (the registry), `spec/help/content_spec.lua`
(the articles' files, ids, titles, headings, fields, blocks, links and strings), `spec/help/quality_spec.lua` (§2),
`spec/next/settings/help_spec.lua` (the page), `spec/integration/help_coverage_spec.lua` (§1, on the whole addon);
`spec/config/config_spec.lua` (`/bb help`), `spec/core/init_spec.lua`, `spec/next/settings/content_spec.lua` (the page
listed last), `spec/integration/next_settings_spec.lua` (built with every page), `spec/integration/papercraft_spec.lua`
(its art sized on the Help page too).

**The tree's scroll bar on the whole addon.** The help's tree is the first list in the settings window long enough to
show its scroll bar in the whole-addon specs, and it showed a harness gap: the harness pins every frame it makes to a
rect with no size, so a bar laid out while pinned has a thumb with no height, and unpinning never fired
`OnSizeChanged`, which the client does when a frame's size changes and which re-lays the bar out
(`next/controls/scrollbar.lua`). The Papercraft spec's art check fires it for every frame whose size its unpinning
changed. In game the thumb was right: the bar lays itself out again whenever its size changes.
