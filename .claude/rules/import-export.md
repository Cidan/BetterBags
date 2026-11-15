---
paths:
  - "util/serialization.lua"
  - "core/database.lua"
  - "next/settings/content.lua"
  - "spec/serialization_spec.lua"
  - "spec/database_spec.lua"
  - "spec/helpers/encoding_util.lua"
  - "spec/helpers/legacy_export.lua"
  - "spec/helpers_encoding_util_spec.lua"
  - "spec/fixtures/legacy_export_v3.lua"
  - "data/categories.lua"
  - "next/settings/categories.lua"
  - "spec/categories_spec.lua"
  - "spec/next/settings/categories_spec.lua"
  - "spec/next/settings/content_spec.lua"
---
# Importing and Exporting Categories

Players share their categories as text: Settings → Profiles → Import / Export (`next/settings/content.lua`, `transfer` tab)
fills a box with `DB:ExportSettings()` and reads one back with `DB:ReadImport(text)` (`core/database.lua`), then
`DB:ApplyImport(data)`; one category is shared from its own page (§7). The text is pasted from Discord, forums and other
players, so **an import string is untrusted input, and it is read as data, never run**.

## 1. Why: the import ran the pasted string (issue #1317)

Until #1317 the text after `!BB` was Base64 of a Lua table constructor, and `Serialization:Deserialize` handed it to
`loadstring("return " .. str)` and called the result, with the global environment and no sandbox. A string could carry
a function call instead of a table, and it ran with every API an addon has, while the import still reported success
(reproduced against the real `DB:ImportSettings`, since split into `ReadImport` and `ApplyImport` (§7), in a spec, and
kept as one: `spec/database_spec.lua`, "never runs code a pasted '!BB' string holds"). Category strings are shared in public, and #1250 (one category at a time) makes sharing
them the point, so the importer was fixed first.

## 2. The formats

| Prefix | After it | Written | Read by |
|--------|----------|---------|---------|
| `!BB2!` | `Serialization:Encode`: CBOR, Deflate, Base64 | `DB:ExportSettings` since #1317 | `Serialization:Decode` |
| `!BB` | Base64 of a Lua table constructor (`serializeTable`) | before #1317 | `Serialization:DecodeLegacy` |

- `ReadImport` strips all whitespace first (a chat box breaks long text over lines), then checks `!BB2!` before
  `!BB`: `!BB` is a prefix of it, and an old string never has `!` after `!BB` (Base64 has none). Anything else is
  refused with the "Missing !BB prefix" message.
- **After the prefix, every character outside Base64 is skipped** (`base64Only`, in both `Decode` and `DecodeLegacy`).
  The old reader did that (its decoder dropped them), so an old string saved with a period after it, or pasted with a
  no-break or zero-width space, imported; the bug review found the new reader refused those, and both formats skip them
  now.
- **The payload is the same in both**: `{ version = 3, customCategoryFilters, customCategoryIndex,
  ephemeralCategoryFilters, categoryFilters, customSectionSort }` for your categories (one category's is
  `{ version = 3, category }`, §7, written as `!BB2!` only). `version` is the shape of the data (2: unified categories;
  3: search rule version 2), not the encoding; the prefix says the encoding. `ApplyImport` normalizes what it put in
  place (`DB:NormalizeCategories`) and brings its rules to the current version (`DB:MigrateSearchRules`), as before.
- What a failed read returns: `nil, "Failed to read import data: " .. reason` (or the empty, prefix and format
  messages), and nothing in the profile changes: reading writes nothing.

## 3. `Serialization` (`util/serialization.lua`)

- `Encode(value) -> string`: `C_EncodingUtil.SerializeCBOR`, `CompressString(_, Deflate, OptimizeForSize)`,
  `EncodeBase64` (Standard). Not protected: what it encodes is the profile's own data.
- `Decode(text) -> table | nil, reason`: the reverse, each step in `pcall`, and a result that is not a table refused.
  `C_EncodingUtil` raises an error on some bad data and returns nothing on other (the documentation's
  `MayReturnNothing` on DecodeBase64 and DecompressString; warcraft.wiki.gg: DecompressString "will raise an error if the
  data appears to be invalid"; it says nothing for DeserializeCBOR), so every step handles both. CBOR can hold only
  nil, booleans, numbers, strings and tables: nothing in it can run.
- `DecodeLegacy(text) -> table | nil, reason`: `C_EncodingUtil.DecodeBase64`, then `parseLegacy`, in `pcall`.
- `DeepCopy(value)`, unchanged.
- **`C_EncodingUtil` is on every client BetterBags ships for**: `EncodingUtilDocumentation.lua` documents the same
  functions, arguments and enums on the live, classic (Mists), classic_era (Vanilla), classic_anniversary (TBC),
  classic_titan and forever branches of `.libraries/wow-ui-source` (`SerializeCBOR`, `DeserializeCBOR`,
  `CompressString`, `DecompressString`, `EncodeBase64`, `DecodeBase64`; only live's carries the `SecretArguments`
  lines), and every TOC's interface version is at or past the patch warcraft.wiki.gg gives for it on that client.
  Blizzard's own Cooldown Viewer export uses the same chain (`CooldownViewerSettingsDataStoreSerialization.lua`).
- `loadstring` and the hand-written Base64 are gone from the module.

### 3a. The legacy parser

`parseLegacy` reads exactly what `serializeTable` wrote, and refuses the rest:

- a table: `{`, then fields `[key] = value` each followed by `,` (the last one's may be left out), then `}`; whitespace
  between anything;
- a key: a string, a number, `true` or `false` (a `nil` key raises Lua's own "table index is nil");
- a value: a table, or a literal: a string, a number, `true`, `false`, `nil` (the old writer's value for a function);
- a string as Lua 5.1's `string.format("%q")` writes it (`lstrlib.c`, `addquoted`): `\"`, `\\`, a backslash before a
  real newline, `\r`, `\ddd` (it wrote `\000`); any other byte as it is;
- a number as `tostring` writes it (`%.14g`): `-?digits[.digits][e±digits]`;
- one table, and nothing after it.

Identifiers, calls, operators, `..`, positional values, `name = value` fields, long strings, comments, hex numbers and
table keys are all refused. A table nested too deep for Lua's stack makes the parse raise, and `DecodeLegacy` returns
that as the reason.

## 4. The mock (`spec/helpers/encoding_util.lua`)

`spec/helpers/world.lua` loads it after `wow_mocks.lua`, with `Enum.CompressionMethod`, `Enum.CompressionLevel` and
`Enum.Base64Variant`. Real CBOR (RFC 8949: arrays only for tables wholly 1..n, maps otherwise, strings as byte strings,
errors for functions, tables holding themselves and nesting past 100, `ignoreSerializationErrors` writing undefined),
real Base64 (RFC 4648, both alphabets; nothing returned for text that is not), and Deflate's stored blocks: the mock
writes uncompressed blocks, which any inflater reads, and reads only those, so it reads what it wrote and raises an error
on anything else. Zlib and Gzip raise an error in the mock: nothing uses them. `spec/helpers_encoding_util_spec.lua`
checks it against RFC 8949 Appendix A, RFC 4648 §10 and RFC 1951's stored block layout.

`spec/helpers/legacy_export.lua` is the old writer, unchanged, so specs can make the strings players still hold;
`spec/fixtures/legacy_export_v3.lua` is a string the old `ExportSettings` wrote, captured from it before #1317, with the
data it was written from.

## 5. Coverage

`spec/serialization_spec.lua` (round trips of an export's shapes, every byte, Base64 only, each kind of bad text;
the fixture; every value form the old writer wrote; payloads that would run code, and texts the old writer never wrote,
each refused; a last field with no comma; nesting too deep; each `C_EncodingUtil` step raising or returning nothing,
with the reason naming it), `spec/database_spec.lua` ("import/export": the `!BB2!` format, the fixture imported into
the profile, the code payload refused with the categories left alone, a bad `!BB2!` string, stray characters in either
format, a string broken over lines, the version 1 and 2 imports built with the old writer).

22 mutations of the parser, `Decode`, `DecodeLegacy` and the prefixes: 21 caught. The survivor is equivalent: with the
unknown-escape check off, `tonumber(nil)` raises and the string is refused anyway; the check stays to name the problem.
Two guards whose mutations survived the same way were removed, as Lua raises for them itself (an escape above 255, a nil
key). The bug review also read 3000 random tables written by the old writer through both `DecodeLegacy` and the old
`loadstring` reader (identical), and fuzzed 20000 old and 15000 new texts (never raised).

## 6. Left as they are, and why

- **The shape of a whole set's import is not checked.** `ApplyImport` copies the five tables whole, as the import did
  before #1317. A string written by hand can hold a table of the wrong shape (a category that is a number), which the
  bags then fail to read until the profile is fixed or reset. That is not code running, the old format allowed the
  same, and nothing BetterBags exports has that shape. One category's import is checked field by field (§7a): it is
  added live, without a reload, and is the string players pass around.
- **A function in a category makes the export raise** (bug review of #1317). `DB:CreateOrUpdateCategory` saves a
  plugin's `save = true` category table as given, so a plugin that put a function in one would have
  `SerializeCBOR` raise in `Encode`, where the old writer wrote `nil` for it. No plugin has been seen doing that; the
  documented `{ ignoreSerializationErrors = true }` is the fix if one does.
- **`CompressString` and `EncodeBase64` returning nothing is not handled in `Encode`.** The documentation marks them
  `MayReturnNothing`, but nothing shows them doing so for a string BetterBags hands them; Blizzard's own export only
  asserts it. `ExportSettings` would raise.
- **`inf` or `nan` in an old string is refused** where `loadstring` read them as nil globals. No profile field holds one.
- **A hand-made old string the parser cannot read may name a line of `util/serialization.lua`** in its reason ("table
  index is nil", "bad argument #1 to 'char'", "stack overflow"), shown in the import's message. Only text the old
  writer never wrote gets there.
- **Decompressing is bounded only by the client** (`Constants.EncodingLimits.EncodingDecompressSizeLimit`, about
  100 MB). A small string that inflates to a lot is data, not code, and the same as pasting that much.

## 7. One category, shared (issue #1250)

Asked (Discord, filed as #1250): import and export a single category, with its items and rule, without exporting or
overwriting all of them. Decided with the user (2026-11-14): **what a category does on its own is left out** (Auto
Sell, Destroy, Auto Deposit: whoever imports it chooses their own), **a name taken asks** whether to replace yours or
keep both under another name, and **the last question says how many of its items move** from the player's other
categories (an item has one home). Export is a button on the category's own page; import is the one Import box,
which tells the two kinds of string apart.

### 7a. What a category shares (`sharedCategory`, `core/database.lua`)

One function builds it, for a category of yours to export and for one read from a pasted string alike, so a crafted
string gives a category nothing an export could not:

| Field | Kept when |
|-------|-----------|
| `name` | a string, trimmed, not empty (else the whole string is refused: "Invalid import data format") |
| `itemList`, `ignoredItems` | keys that are whole numbers above 0 and below 2^31 (an int32), each `true` (`itemList` is `{}` when none): a key like `inf` would be saved as one the next load cannot read |
| `searchCategory` | `{ query }`, a string not empty once trimmed |
| `groupBy` | one of `const.SEARCH_CATEGORY_GROUP_BY`'s values |
| `color` | three or four numbers, each from 0 to 1 |
| `enabled` | a boolean for a bag kind BetterBags has; every other kind used (`normalizeEnabled`) |
| `hidden` | `true` for a bag kind BetterBags has |
| `note` | a string not empty |
| `skipRecent` | `true` |
| `itemOrder` | its own item order (item-sort.md §5): the keys BetterBags has (`const.ITEM_ORDER_KEY`), each once, at most `ITEM_ORDER_DEPTH` (`itemOrderOf`); none when no key is left |

A whole set of categories pasted in (`ApplyImport`) is brought to shape by `NormalizeCategories`, which reads each
category's `itemOrder` the same way (`itemOrderOf`), a plugin's saved state's too: an order with a key BetterBags does
not have would stop the sort (`sort:ItemDataComparator` refuses one). A key this client does not offer (Upgrade Track,
from a retail string, on a Classic client) is one BetterBags has: kept, it orders nothing there (every item is on no
track), and its dropdown shows its name with no choice checked.

Never shared: `automation`, `confirmSale`, `deposit` (the user's decision), `priority` (the importer's order),
`blizzard` (worked out again from the name, category-lifecycle.md §11), `save`, `dynamic`, `isGroupBySubcategory`,
`groupByParent`, `readOnly`, and every bag's pins and tabs (`customSectionSort`, `categoryToGroup`: the player's layout).

### 7b. The database (`core/database.lua`)

- `DB:ExportCategory(name)`: `!BB2!` and `Serialization:Encode({ version = 3, category = sharedCategory(filter) })` for
  a category of yours (`customCategoryFilters[name]`); nil for a plugin's or a name no category has.
- `DB:ReadImport(text)`: §2's reading, for either kind. A payload with `category` comes back as
  `{ version, category = sharedCategory(...) }` and nothing else of it; any other is your categories, as read.
- `DB:ApplyImport(data)`: what `ImportSettings` did after reading, for your categories. `ImportSettings` is gone: the
  Import box reads first so it can tell the kinds apart, and say what is wrong before asking anything.

### 7c. Adding it (`data/categories.lua`)

- `categories:ImportCategory(ctx, shared, name, replace)` → boolean. **New** (`replace` false): `CreateCategory` with the
  shared fields and `save = true`, so it goes on top of the order and a Blizzard category's name makes it a converted
  one, as for any new category. **Replace**: the category of yours named `name` takes every shared field (one the
  string lacks is cleared), its group by never for a converted one; it keeps `priority`, `automation`, `confirmSale`,
  `deposit`, `blizzard` and every name-keyed side table (category-lifecycle.md §1); items it held that the string does
  not are unfiled (`DB:DeleteItemFromCategory`). Either way each shared item is filed with `DB:SaveItemToCategory`, which
  takes it from the category it was in; never `AddPermanentItemToCategory`, which asserts the client knows the item ID
  (a string from another client holds that client's). Then `categories/Changed` (from `CreateCategory` when new) and one
  `bags/Rederive { resetLayout, buttons }`. **False, changing nothing**, for a name a category has (yours or a
  plugin's) when adding, or a name with no category of yours when replacing: the question was asked before a plugin
  could have made one, so the answer is checked again.
- `categories:MovesOnImport(shared, name)`: how many shared items are filed now in a category of yours other than
  `name` (nil for a new one: every one filed). Plugins' item lists are not counted: an item added by hand to a category
  of yours wins over them anyway (category-lifecycle.md §6).

### 7d. The questions (`next/settings/categories.lua`, `content.lua`)

- **Export** (`NextCategoryActions:ShowExport`): the header's third button, left of Rename, shown with them for your
  categories. A `NextDialog` with the string in its field, focused and selected to copy (the dialog does both for a
  field), its text saying what it does on its own stays; one button, Close.
- **Import** (`importCategories`, content.lua): `DB:ReadImport` first; a string it cannot read says why at once. Your
  categories: asks, `ApplyImport`, offers a reload, as before. One category: `NextSettingsCategories:AskImport(owner,
  category, done)`, `done` emptying the box once it is added.
- **`AskImport`**, every question a `NextDialog` over the settings window:
  - no category of the name: "Import the category 'X'?" and the moves (§7c), Cancel or Import;
  - one of yours: "You already have a category named 'X'…", Cancel, Keep Both or Replace. Replace asks again, saying
    what changes and what stays, with the moves, then replaces;
  - a plugin's: Cancel or Keep Both only (a plugin makes its category again every session, so it cannot be replaced);
    a group by's section (`isGroupBySubcategory`, not saved either) the same, named as a section of its category;
  - one that groups, when it would become a converted category (category-lifecycle.md §11: a new one under a name
    `items:KnowsBlizzardCategory` knows, or replacing one made from a Blizzard category), says its Group By is turned
    off, in Rename's words: in the question for a free name and in Replace's second question; for Keep Both, a name
    like that asks once more before importing;
  - Keep Both: the category name dialog (New Category's and Rename's `askName`), filled in with the first free
    "X (n)" from 2, saying the moves; a taken name asks again;
  - imported: `done`, then "Category Imported" with OK or Show Category (`editor:Show(name)`, then
    `settings:Open("categories")`, as a bag's Order tab opens a category);
  - `ImportCategory` returning false: says the name was taken (or the category deleted) meanwhile.

### 7e. Coverage

`spec/database_spec.lua` ("one category": the export's fields and none of what it does on its own, nothing for a
plugin's or a missing name, `ReadImport` telling the kinds apart, a crafted category keeping only what it may, colors
and group bys, a category with no name refused), `spec/categories_spec.lua` ("a category shared as text": new, on top,
items moved, the bags recalculated; another name; item IDs the client does not know; replacing; a converted one;
refusals changing nothing; the count), `spec/next/settings/categories_spec.lua` (Export in the header and its dialog;
`AskImport`: asked first with the moves, shown on request, none or one moving, cancelled, replaced after asking again,
kept both under a free name, only kept beside a plugin's or a group by's section, its Group By going under a Blizzard
name or over a converted category, the name taken or the category deleted meanwhile), `spec/next/settings/content_spec.lua`
(the Import box reading first, a whole set applied after asking, an unreadable string said at once, one category
handed to the Categories page and the box emptied once it is added).

41 mutations of the shared fields' checks, `ReadImport`, `ExportCategory`, `ImportCategory`, `MovesOnImport`, the
header, the questions and the Import box: all caught (one first survived, the free name's search, and led to a test of
two names taken).

### 7f. The bug review, and what was left

Found and fixed: a group by's section was called a plugin's category; a category that groups, imported under a
Blizzard category's name, lost its Group By with no word (Rename warns); a pasted item ID could be any number (`inf`,
`1e300`). Left, as only a string written by hand gets there and nothing has been seen to:

- a name with a line break or control bytes inside it is kept (only its ends are trimmed);
- a category string of `version` 1 or 2 is read with its rule as it is, never grouped left to right as a whole set's is
  (`MigrateSearchRules`): `ExportCategory` writes version 3 only;
- a saved category whose name is only spaces (no dialog makes one; a plugin could) exports as a string with no
  `category`, which reads as a whole set that replaces nothing.
