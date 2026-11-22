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
- **The `writer` agent originates every piece of text** (asked, 2026-11-17: "have the writer originate the text, and
  you can double check it factually, BUT DO NOT CORRECT its copy/text. it's critical you do not write or suggest text,
  but instead if needed, update explainers or code pointers"). The coding agent writes briefs (what an article covers,
  where the facts are in the code, facts already checked) and checks the writer's facts against the code; it never
  writes, edits or suggests wording, not even a corrected sentence. A wrong fact goes back to the writer as a corrected
  brief (§3). The earlier text, drafted by the coding agent and rewritten by the writer, was rejected ("it's all wrong in
  multiple places, gets and get, confusing as hell structure to sentences").
- **`tools/translate` is not run** for the new strings.
- **The tree keeps every group open** (asked: "expand and keep expanded, all the help headers on the left"); its
  headings fold nothing.
- **A subtitle is a noun phrase** of at most eight words, never a sentence (the same request).
- **A title is one to three words** (asked: "titles should be 1, 2, MAYBE 3 words max. they are titles, not
  descriptions"): it names the article; its summary describes it. Each title is its own. The longer titles they had
  are kept among their keywords and questions, so a search for those words still finds them.
- **A heading is a title too** (asked, of "Where sections come from" and "Which section wins": "these are a hard no.
  do not make statements in subtitle or sections. this should be 'Section Sources' and 'Section Ordering'"): one to
  three words in Title Case naming what the part covers, never a clause, a question or a statement, each its own in
  its article. The first drafts' headings were phrases, and the writer was asked only for "short, Sentence case"
  headings, so it kept them: the writer's brief for any heading states this rule.
- **A search keyword titles its part as it is typed** (asked, 2026-11-22: "break down the search help a bit more so
  keywords are formal titles of sections"): a `heading` with `keyword = true` (`ilvl`, `%=`, `( )`, `player.level`),
  raw, never `L:G` (a query is never translated), shown as typed, not in capitals (`next/settings/article.lua`), exempt
  from Title Case, the clause words and the trailing punctuation check, still one to three words and its own in its
  article (`spec/help/content_spec.lua`); `spec/integration/help_coverage_spec.lua` checks a query reads each of its
  words (a field or alias, a player value, a function, or one token of its own as the lexer reads it). The search
  articles title every field, alias, operator, function and player value so, one each; what is not one keyword
  (arithmetic, money, quotes, precedence) keeps a Title Case heading.
- **Nothing "holds" anything, and nothing is a person** (asked, the same day: "nothing 'holds' anything, this is a
  claude-ism in speech, this should have been written by the writer agent", then "fix all the rest of the docs that has
  'holds' and other human like personifications ... all text should be highly technical"; CLAUDE.md, "Writing Register:
  Technical, Never Personified"): no field, page, tab, section, bag, setting, category or item holds, keeps, knows,
  waits, asks, decides or claims anything; the writer's brief states it. The search articles were written again without
  it; the sweep after it rewrote every other article's personified sentences.
- **How the sweep ran** (reusable for the next one; throwaway scripts in `/tmp/help_author/`): a loose verb filter
  picked candidate strings (the articles' shown text, never `keywords` or `questions`; the other in-game strings; the
  settings descriptions; README lines); the writer, given one shared brief (what personifies, what to leave: the
  player's own actions), returned only the entries it changed as `id TAB new text`, and decided the borderline ones
  again when told how; a script applied each by exact match (placeholders and escapes checked, specs asserting the old
  text updated) and kept every old/new pair; the decision tool read the pairs in chunks of ten for a changed fact or a
  person left, and every chunk it was unsure about was read in full. Strings written as several literals joined with
  `..` are found as one (the first filter missed them: "the Item Order holds equal"). Measured after it: rounds 1, 2
  and 3 at 72.0% / 90.7%, 71.5% / 90.2% and 72.5% / 86.0%, every floor kept.

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
Search (`search.lua`), Categories (`categories.lua`), Automation (`automation.lua`), Bank and Warbank
(`bank.lua`), Appearance (`appearance.lua`), Profiles and Settings (`profiles.lua`), Integrations
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
| title | 6 | 0.5 | The title |
| keywords | 4 | 0.75 | Its keywords |
| questions | 3 | 0.9 | Its questions |
| headings | 0.75 | 0.5 | Its headings |
| body | 0.4 | 0.9 | Its summary, paragraphs, lists, steps, tips, warnings, examples |

The weights were tuned again when the text was written from the code (§3): a grid over the five weights and the body's
b, scored on rounds 1 and 2 alone. The new text says what the code does in the game's own names, which are seldom a
player's words, so a player's questions now count for more. The body keeps 0.4: the grid preferred 0.2, which on the
final text finds as many first on round 3 and 0.3 points more among the first three, but a field weighted that low
barely saturates (the rule breaks between 0.24 and 0.23), so a body repeating one word typed outranked one matching every
word typed (`spec/help/search_spec.lua`, "ranks the document matching every word above one matching a word many
times"), against the rule above.

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
| 3, the text written from the code, old weights | 71.0% | 85.0% | 0.795 |
| 3, the text written from the code, weights tuned again | 73.0% | 86.5% | 0.806 |
| 3, the search articles' keywords made their parts' titles (2026-11-22) | 72.8% | 85.8% | not measured |

Rounds 1 and 2 with the keyword titles: 72.3% / 90.7% and 72.3% / 90.5% (from 71.8% / 91.0% and 72.0% / 90.2%), every
floor kept; nothing tuned.

On round 3, a question, a short search and a search with a typo find their article first about 89% of the time; a
symptom ("my bags keep...") 56%, WoW slang 60%, and those are most of what misses: a word search cannot tell what a
symptom means. `spec/help/quality_spec.lua` keeps every round at least what it finds now, less a little (the floors were
set again with the text written from the code: the queries were written from the earlier text's titles, summaries and
headings, so they favour its words, and the text players now read was worth that cost). To tune again: tune against rounds 1 and 2, have the writer write a new held-out round (never shown its
misses), measure on it, and add it to `queries.tsv` and the floors. Never tune against round 3.

`Snippet` returns the part of an article's text around the words matched, with where they are, for a result card.
A sentence longer than the width (`SNIPPET`, 140 characters, `help/articles.lua`) is cut to it, starting up to a third
of it before the first match: a word's start, or in a wide run (Korean, Chinese, Japanese) the first pair matched, not
the run's start, since a Chinese run between two punctuation marks can be longer than the width. A cut falls where
`breaks` allows one: beside a space, or beside a character of text written without spaces (`isUnspaced`: kana, CJK
ideographs, the ideographic space U+3000, CJK punctuation and the full-width punctuation sub-ranges FF01-FF0F, FF1A-FF20,
FF3B-FF40 and FF5B-FF65; not full-width letters and digits, which are words). Hangul is wide (searched by pairs) but not
unspaced: Korean puts spaces between words, so it is cut only at them. No cut leaves a mark that closes (`CLOSES`:
，。、）」』】”’ and the rest of Chinese and Japanese line breaking's no-line-start marks) at the snippet's start, nor one
that opens (`OPENS`: （「『【“‘ ...) at its end. Spaces and ideographic spaces (`isBlank`) are trimmed off both edges.
The start moves forward to a cut but never past the match; the end moves back to a cut but never before the match's
end, and is cut at the width when no cut lies between them (one long token).
Before #1357 the cuts looked for ASCII spaces alone: a Chinese sentence over the width came back as its first character,
or one character between two ellipses, and a translation keeping a Latin name ("BetterBags Next") was cut at that name's
space (`spec/help/search_spec.lua`, "in Chinese and Japanese, which have no spaces between words"). Its review compared
the old and new crops on every article sentence over the width with each of its terms (10,377 crops) and 1,810 snippets
of real searches: no English snippet changed. It found the marks and the ideographic space at the edges and full-width
letters cut inside a word, fixed test-first. Not changed: a match more than two thirds of the width long is cut inside
(no word is), and Korean text with no space in the third of the width before a match starts inside a word (no Korean
word is that long). Two mutants survive the specs, each the same on any real text: the match's last character taken as
its first, for a Latin word (no cut falls inside one) and for a wide pair (only closing marks all the way to the width
tell them apart).

## 3. Writing the articles

The `writer` agent originates the text in its authoring mode ("Authoring from sources" in
`~/.config/ask/agents/writer.md`, added for this): from a brief and the code, never from a draft. The coding agent does
not write, edit or suggest wording; it writes briefs and checks facts. The working files were under `/tmp/help_author/`
(throwaway); the process:

1. **A shared brief** for every batch: where the text appears, the game clients and how to name them, facts that hold
   across articles (each checked in the code, with its lines), the scope and level of detail (state what a player needs;
   leave out a detail whose exceptions cannot be stated briefly), the reference files (the exact in-game names, the
   settings window dumped from the whole addon, an index of every article's scope), the markup an article comes back in,
   and the limits (titles and headings of one to three words that begin with neither an article, a preposition nor a
   verb form; subtitles of at most eight words; strings `tools/translate` can read).
2. **An article's own brief**: its group, where it shows (design, client), its scope, the settings and pages it must
   explain (`settings`, `pages`), the code and rules files to read, and the facts earlier checks established.
3. **The writer authors** each article as markup (`title:`, `subtitle:`, `heading:`, `paragraph:`, `list:`, `steps:`,
   `tip:`, `warning:`, `example:` with `finds:`, `setting:`, `link:`, `see:`), with a model of its facts citing
   file and line for each. A converter turns the markup into the article's `title`, `summary` and `body`, keeping its
   data (`keywords`, `questions`, `related`, `settings`, `pages`, `design`, `shown`); it fills a setting's bag only when
   the setting has one bag (from the real `SettingsCatalog`), and refuses anything a spec would.
4. **A fact check** by a sub-agent reads every claim against the code and marks each problem MAJOR (a player following
   the article gets another result in normal play) or MINOR (an edge a player rarely meets, or a detail incomplete but
   not misleading), stating the true fact without wording for the article. Each fact becomes part of the article's
   brief, or of the shared brief when it recurs, and the writer authors the article again from the corrected brief.
   A checker's finding that contradicts an earlier one is settled in the code by the coding agent before it is used
   (one was wrong: Recent Items comes before pinned sections in the classic bags, `data/items.lua` 946-947).
5. **Stopping**: an article is done when a check finds nothing, or when, after one round given only minor findings, the
   next check again finds only minor ones; what those leave is listed below. 23 rounds of writing ran for the 80
   articles, the 11 group titles and the Help page's own strings.

**Minor findings left in the text** (accepted under the stopping rule; each is an edge the article does not mention):
the guild bank article puts Close among the Plain theme's menu entries (it stays in the header); move-category names
only the bank's body as a drop that assigns a group; confirm-sale says Confirm Auto Sell is on whenever Auto Sell is
turned on (it stays off for a category where it was turned off); category-rule and wrong-category leave out that Group
By is hidden for plugin and equipment set categories, and wrong-category that the Search Results preview runs on the
categories items show in now; recent-items' warning about the BetterBags Next bank's title sort without SortBags leaves
out the Plain bag button; shopping-list leaves out needed items the player cannot buy, and where a right-click sends the
card on another tab; next-dragging ties bank drops to Enable Groups (the backpack's setting); bag-menu, sorting and
section-order leave out conditions on classic clients without SortBags, and the bag-by-bag views; dropping says the
classic Shift-drop "always" adds the item though it states the equipment set refusal, and that a left-click with an item
on the classic bag button opens the Create Category prompt (a Shift-left-click toggles the search). `help/README.md`,
authored the same way, was accepted with minor imprecisions its fourth check found: it calls `Show` a method of
`NextHelpArticle` (it is the view's), says `Related` keeps definition order (it keeps the article's `related` order),
lists keywords and questions as optional (content_spec needs six together), and simplifies how a word's stem, prefix and
synonym matches combine and how compound halves count. The quickfind article's Item Selection, written again with
#1343 and #1344 (two rounds, both checks finding only minor problems with the text): the backpack's Show Bags and Show
Blizzard Bags views send an item to the Backpack group, its section being its bag's name (every tab there holds every
item); Hide In hides nothing in the bag-by-bag views, and never a new item in Recent Items; a new item shows in Recent
Items only with that category on, outside the bag-by-bag views, and when its category does not skip Recent Items.

**Bugs in the addon the checks found**, outside the help and not fixed (QuickFind's bank tab and its search by a
name's first word were fixed since, #1343 and #1344, and the quickfind article's Item Selection written again; its bank
items listed only while the bank is open are kept by design, quickfind.md §3; the reagent bank move on a section
right-click, which no bank view could reach, was removed, #1358, patterns-state.md): a double click on the vendor's red destroy card destroys two stacks; `rarity %= x` raises "Unknown
operator"; Flash Stacks (`newItemFlash`) is read by nothing; New Profile makes the new profile active before asking, so
Cancel leaves the character on it, and Copy Profile switches whichever button is chosen; Enable Enter to Make Category
is hidden in BetterBags Next but still acts there; a search rule with a syntax mistake shows 0 results and can still be
applied; Masque follows the classic Bag Theme even in BetterBags Next, where that setting is not shown; the gamepad
radial's Character entry does not reopen a BetterBags backpack B closed; `keyring.md` leaves out The Burning Crusade
Anniversary, which shows the keyring; in the classic bags a search typed in the box never reaches the Recent Items
section (`bagProto:Search` updates the tab view's buttons; Recent Items' are the bag's global section buttons), so those
keep the dimming of their last draw until the bag is recalculated (BetterBags Next's search covers them).

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

What an article draws is read when it shows, for the bags and client in use, as the settings window reads its own: a
link to an article only while that article is shown; a link to a settings page only while the page is shown, and to a
tab only while the tab is (`pages:IsShown`, `pages:ShownTabs`, after the page's `choose`: the Categories page's list
chooses a category, and so its tabs, before the window reads them), since the window opens its first page or tab in
place of one it does not show; a setting only while the settings window shows its row (`pages:ShowsSetting`: a tab shown now, a
section and a row for the bags in use and not hidden; Show Keystone Level is retail's); and under Related Articles only
the related articles its body does not link already. Found by the review of the text written from the code: Guild Bank
links opened the General page with the classic bags and on Classic Era, a Currencies tab link the Tracked tab on Classic
Era, category tab links the Settings tab with no category of the player's own, and 67 of 77 articles listed their links
twice (`spec/next/settings/help_spec.lua`, "leaves out a link to a settings page or tab not shown now", "leaves out a
setting the settings window does not show now", "lists its related articles shown"). Every article was opened on every
client and design after the fix: no heading is left with nothing under it. Because what it draws is read when it
shows, the view reads the article again whenever it comes back into view (`fillArticle` with `again`, keeping where it
was scrolled), not only when another article is chosen (a second review found a link drawn or left out by what the
Categories page chose stayed so on returning). A setting row is cached per setting and bag, and whether it shows is
checked before the cache. Not changed: Enable Enter to Make Category is left out of articles with BetterBags Next, as
the settings window leaves it out, though the setting still acts there (§3, bugs found).

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
  search box's last words (a choice, not a fault); reversing a slide part way may jump (not reproduced); the word being
  typed matches at most 40 longer words, in the index's order; a setting row's label is not
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
