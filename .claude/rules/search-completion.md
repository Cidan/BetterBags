---
paths:
  - "data/searchcompletion.lua"
  - "util/query.lua"
  - "next/controls/input.lua"
  - "next/controls/menu.lua"
  - "spec/searchcompletion_spec.lua"
  - "spec/query_spec.lua"
  - "spec/next/controls/input_spec.lua"
  - "spec/next/controls/dropdown_spec.lua"
---
# Search Rule Suggestions

Asked (2026-11-22): "search auto-complete in our query builder in the category query screens ... like an IDE where a
little intellisense appears at the cursor with possible next keywords if any ... a look ahead and have text aligned
right ... that says how many items match". The category query screen is the Search Rule tab of the Categories page
(next-settings-categories.md §5; the classic config forms are gone). Studied before building: VS Code IntelliSense (Tab
and Enter accept, the first row preselected), CodeMirror 6 (arrows select, Enter picks, Escape closes; a completion
replaces a `from`..`to` range and shows a `detail`), Kibana's KQL bar (field, operator, value and conjunction
suggestions; values quoted and followed by a space; the cursor's place found by parsing the query with a cursor marker
in it), Splunk's search assistant (terms with how often each appears in the data), and Blizzard's own: AutoComplete.lua
(arrow keys kept for the list), the group finder's search box (Tab and arrows), the developer console
(`Blizzard_Console.xml`: Tab completion in a multi-line edit box, its own `Insert("\n")` on Shift-Enter, Up and Down read
from `OnKeyDown`; `Blizzard_Console_AutoComplete.lua`: work spread over frames at 15 ms each), and Blizzard's menus,
closed on `GLOBAL_MOUSE_DOWN` outside them (`Blizzard_Menu/Menu.lua`).

**Decisions (approved by the user, not to reopen):** the count on the right is the Search Results count in its words
("12 results"); a row that makes no whole rule says "0 results" (no descriptions); Tab and Enter both take the lit row,
and Enter starts a new line while none shows; the list opens on its own right after a field (operators) and an operator
(values); only the Search Rule box for now, not the bags' search box.

## 1. What the query expects at the cursor (`QueryParser:Context`, `util/query.lua`)

From the lexer's tokens and spans alone (no parse), so a query typed part way says it too. The cursor is a byte offset
(`EditBox:GetCursorPosition`; the lexer works in bytes). Returns `{ expects, prefix, from, to, quote?, field?,
operator?, start?, after? }`, or nil when the lexer raises (a control character).
- **The word at the cursor** is a term, an operator or a logical word the cursor is in or at the end of (a parenthesis,
  a comma or a lone sign is whole once typed). It is what a suggestion replaces, all of it (`from`..`to`, so `ra|rity`
  never becomes `rarityrity`); `prefix` is what of it is before the cursor. A quoted word is read from after its quote
  (`quote` says which) and replaced from its opening quote to its closing one; one with no closing quote runs to the end
  of the query in the lexer, so only up to the cursor is replaced. A closed quote with the cursor past it is finished.
  With no word at the cursor, `from = cursor + 1`, `to = cursor`.
- **`expects`**, from a walk of the tokens before that word (the condition's side, how many parts it has, its one word,
  each open parenthesis and whether it is a function call): `condition` (at the start, after AND, OR, NOT or `(`),
  `operator` (after a word on the left; `field` is that word when it is the side's only part: a quoted word never is),
  `value` (after an operator: `field` and `operator`, and `start`, the field's first byte, when the left side is one word
  and nothing of the right is typed yet; inside a function's arguments too, with no field), `join` (after a whole
  comparison or a group holding one), `none` (after an argument: only a comma, a sign or `)` comes). `after` is the
  type of the token after the replaced word.
- Coverage: `spec/query_spec.lua` ("Context").

## 2. What the suggestions read from the index (`data/search.lua`)

- **`search:Fields()`**: every field and alias a query reads, by name, once each (`{ name, key, kind, list?, alias? }`,
  shared, read-only), built from the tables the evaluator uses (`TEXT_FIELDS`, `NUMBER_FIELDS`, `BOOL_FIELDS`,
  `LIST_KEYS`, `ALIASES`), so the suggestions cannot drift from what a query accepts. `expansionid` is left out (the
  release order, never typed). **`search:FieldOf(word)`** in any case.
- **`search:ValuesOf(word, within)`**: the values a field has among the items given (slot keys), as their snapshots hold
  them (text as written), each with how many items have it, the most common first (sort keys made once: lower-casing in
  the comparator cost 1.6 ms of a 6.3 ms suggestion over 900 values). **`search:ValuesBySlot(word, within)`**: each
  item's value. **`search:HasValue(word, within)`**: the items with a value (a list field, one at least).
- **`search.PLAYER_VALUES`**: the names `PlayerValue` reads after `player.`, each a number or text.
- **A `set` node** (`{ type = "set", set = slotkeys }`, never parsed) evaluates to its items (within what an AND
  narrows to): how a suggestion stands a set of items in for a condition (§3).
- Coverage: `spec/search_spec.lua` ("fields and values for suggestions").

## 3. The suggestions (`data/searchcompletion.lua`, `SearchCompletion:Suggest(text, cursor, within)`)

Returns `SearchSuggestion[]` (`label`, `kind`, `text` the query with it taken, `cursor`, `count`, `chain`) and the
context (§1). `within` is the slot keys counted: the Search Rule tab passes the items of the bags the settings show.
- **What**: at a `condition`, once a letter is typed: fields (and aliases), NOT, `player.` values, functions (`min(`); at
  an `operator`: the operators the field's kind takes (`OPERATORS`: text `= == != ~= %=`, number `= != < <= > >=`,
  true-or-false `= !=`, an expansion text and order), or a `player.` value's; AND and OR once a letter is typed (there
  and at a `join`). At a `value`: every name of rarity (`const.ITEM_QUALITY_TO_ENUM`'s lower-case keys, by quality),
  expansion (`BRIEF_EXPANSION_MAP`, by release), binding (`BINDING_MAP`), true-or-false fields, appearance and source;
  else the values the items given have (`ValuesOf`), numbers from the lowest after `< <= > >=`; none for tooltip and
  guid; after a number field's operator, a letter typed offers number fields, player numbers and functions instead.
  Nothing for an empty condition or join, a quoted word that is not a value, `none`, or when the only suggestion is what
  is typed (Blizzard's AutoComplete hides a lone exact match).
- **Ranking**: the same as typed (4), starting with it (3), a value with a word starting with it after a space or a
  sign (2), anything when nothing is typed (1); then the order made (fields by name, NOT, player values in their order,
  functions; values most common first or by number). At most 50. Text for each is built only for the 50 kept.
- **Taking one** puts its insert where the word was, then a space unless one, `)` or `,` follows (none after a
  function's `(`); a value that is not one word goes in quotes, the player's quote if they opened one. A field chains
  to its operators (unless an operator follows already), an operator to values, a player value at a condition to its
  operators: the cursor goes past a space that follows.
- **Counts** (the user's "look ahead"): after an operator, every suggestion makes a whole comparison and is counted as
  the whole rule with it would match. A field at a condition: the items the rest of the rule leaves that have the field
  (`CountWithField`: the field's word replaced by a word that names no field, then by a `set` of `HasValue`; Kibana's
  cursor marker); a true-or-false field: its word alone (the items where it is true, plus its text matches), or the
  whole rule when an operator follows. Everything else (operators, AND, OR, NOT, functions, player values at a
  condition) makes no whole rule: 0, as Search Results says for a rule that does not parse.
- **How values are counted** (`ValueCounter`): whether an item matches follows only whether it matches the comparison
  being completed (AND, OR and NOT work item by item: Shannon expansion), so the rest of the rule is evaluated once
  with the comparison standing for every item (`all`) and for none (`none`), and each value costs its comparison alone:
  `count = |none ∩ within| + Σ over the items it matches (all - none)`. For a number field's plain number with `= == !=
  ~= < <= > >=`, `numberCounter` sorts the items' values once and counts by binary search (`!=` and `~=` count the
  items without a value, as `isNotInIndex` does); built only when a number needs it. Anything the rest cannot be read
  without falls back to the whole rule (`CountOf`). The spec checks every count against `CountOf(s.text)` for a dozen
  rules, and how many evaluations run.
- **Measured** (offline, PUC Lua 5.1, 1,500 indexed items, 20 runs each; `/tmp` script, not kept): first build, every
  value evaluated as a whole rule: `ilvl > ` 20.65 ms (50 range lookups of ~750 items), `id = ` 5.73, `name = ` 3.98,
  `s` 2.50, others under 0.5. With the rest evaluated once: `ilvl > ` 17.59 (the range lookups were the cost). With
  the sorted numbers: 3.71; with sort keys made once and the numbers built only when needed: `id = ` 4.60, `name = `
  3.55, `ilvl > ` 3.31, `rarity = ` 0.48, `type = armor AND tr` 0.24. Suggestions are read at most once a frame (§4).
- Coverage: `spec/searchcompletion_spec.lua` (on the real QueryParser and Search over indexed items).

## 4. Showing them (`NextMenu` at a text cursor, `NextInput:CreateArea{ complete }`)

**UI consistency**: the list is a `NextMenu` (rows with a label and a note at the right in `Picker.NoteFont`, the lit
row in `HoverFill`, `Menu.MaxRows` before it scrolls), not a popup of its own, so every theme draws it.
- **`NextMenu` with `attached`**: no screen catcher (it ate the click that should move the cursor); a left or right
  button down anywhere but over the menu closes it (`GLOBAL_MOUSE_DOWN`, registered only while open, as
  `MenuManagerMixin:HandleGlobalMouseEvent`), the click going on to what is under it; the first takeable row lit (or
  `opts.lit`); the light kept where the pointer leaves it (`keyed`, as with a field); `SetItems(items, lit)` shows new
  rows in place, open; the owner gives it keys through `Arrow` and `Take`.
- **A text area with `complete(text, cursor) -> { items, from }?`** (each item's `value` `{ text, cursor, chain? }`):
  - Read once a frame (`schedule`, `C_Timer.After(0)`): after the player types (`OnTextChanged` with `userInput`), or
    when the cursor moves while they show; never on a cursor move, a click or focus alone. `Suggest` returns what it
    did ("closed", "kept", "idle", "unchanged", "none", "shown") for the trace.
  - Shown below `caret`, a frame on the edit box at the start of the word they replace (`OnCursorChanged`'s x less the
    width of the word's typed part, measured in the edit box's font; its y and line height), in whole pixels.
  - Keys while they show: Tab and Enter take the lit row (`TakeSuggestion`); Up and Down (`OnKeyDown`, as the
    console reads them in its multi-line box) move the light, and the cursor is put back where they were read when
    the frame ends, whichever order the edit box moved it in; Escape closes them and keeps focus, none again until the
    next key typed (`dismissed`); with none shown Escape lets go of focus as before, and Enter inserts a new line
    itself (`NewLine`: a multi-line edit box with an `OnEnterPressed` puts in none, as the console's shows). A text area
    without `complete` sets none of these scripts and keeps the game's keys.
  - Taking one (`Accept`): its text and cursor, reported through `onChange` as typed; one that chains reads again.
  - Closed when focus goes, the text is set from code, the area is disabled or made read-only, or nothing is suggested.
- **Mocks added from Blizzard's source** (`spec/helpers/wow_mocks.lua`): EditBox `GetCursorPosition` /
  `SetCursorPosition` (bytes, the end until set; setting it runs `OnCursorChanged(x, y, w, h)`) and `Insert`
  (SimpleEditBoxAPIDocumentation; AutoComplete.lua; Blizzard_Console.xml). `GLOBAL_MOUSE_DOWN`'s payload is the button
  (SystemDocumentation), fired by specs through the frame's `OnEvent`.
- Coverage: `spec/next/controls/dropdown_spec.lua` ("NextMenu, at a text cursor"), `spec/next/controls/input_spec.lua`
  ("NextTextArea, with suggestions").

## 5. Not seen in game (no client here)

Each is built so either answer works, and is reported rather than built for:
- Whether a multi-line edit box moves its cursor on Up and Down before or after `OnKeyDown` runs: the cursor is put back
  when the frame ends.
- Whether it puts in a new line on Enter when it has an `OnEnterPressed`: the console's code says it does not, so
  `NewLine` puts one in; if the client also did, Enter would make two.
- Whether `OnKeyDown` fires for Up and Down in a focused multi-line edit box on every client (the console relies on it).
- `GLOBAL_MOUSE_DOWN` on WoW: Forever: documented on the retail, Classic Era, Anniversary and Mists sources here; no
  Forever source.

## 6. Bug review (2026-11-22)

One review of the whole change (Prime Directive #2). It found no count wrong: every value's count matched
`CountOf(s.text)` over about 600 cursor positions in 50 rules. Fixed, each test-first:
- **Tab or Enter took a suggestion read for the text before a key typed in the same frame** (suggestions are read once a
  frame): `TakeSuggestion` reads them again first when the text or cursor changed since.
- **Up or Down, then a key in the same frame, put the cursor back before that key**: it goes back only when the text is
  the same.
- **A value ending in a backslash was quoted, and the lexer read the backslash and the closing quote as a quote in the
  text**: a backslash no longer makes a value quoted (unquoted it is one word). Left: a value with a space and a
  backslash at its end cannot be written for the lexer at all.
- **The box scrolled with the wheel left the list by a line scrolled away** (no catcher): the wheel closes it.
- **An operator put in before a value already there opened the values**: it chains only when no value follows.
- **`ilvl > (le` read as a condition**: a parenthesis after an operator opens a value worked out.
- Tests it found asserting less than they named: the Left key never moved the cursor; `!=` on a number field had no
  item without a value (a mutation counting them wrong survived); closing on `SetReadOnly` was untested. All added.
Left, not seen in game: whether the client sends `OnEnter` to a row that appears under a resting pointer (the list
opening under it would light that row instead of the first); the mock `Insert` runs no `OnTextChanged` (if the client
runs it as typed, a new line is reported twice, which changes nothing). The fixes add no state and touch nothing another
feature shares, so no second review ran.
