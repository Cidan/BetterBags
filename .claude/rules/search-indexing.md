# Search Indexing Rules

This document defines the architecture, design guidelines, and API contracts for search indexing within BetterBags.

## Architectural Guidelines

### 1. Incremental Indexing That Always Equals a Clean Rebuild
v0.4.x updated the index with imperative `search:Add(currentItem)` / `search:Remove(previousItem)` calls per changed slot and suffered ghost and out-of-sync entries: removal used the item's *current* values, which no longer matched what had been indexed. v0.5.0 replaced that with a clean rebuild of the whole index (both bags) on every sweep, which cost time proportional to every indexed item for a one-slot change (~7.7 ms of a profiled refresh on WoW: Forever). The index is now incremental again, built so that it cannot drift:
- **Snapshots are the source of truth for removal.** `fillSnapshot(item)` (`data/search.lua`) is the single definition of what an item contributes to the index (strings, equipment sets, numbers, bonus IDs, booleans). `search:Add` indexes a snapshot and stores it in `search.indexed[slotkey]`; `search:Remove` and every re-index remove the slot's **stored** snapshot, never the item's current values. ItemData objects are reused and mutated in place across sweeps (targeted merges, the per-slot harvest cache, Phase 6/8 category writes), so the current values are not what was indexed.
- **`search:SyncKind(kind, items, rebuild)`** brings one kind's entries in line with that kind's items: slots that are gone or now empty are removed; new items are added; an item whose fresh snapshot (built into a reused scratch table, so an unchanged item allocates nothing) differs from its stored snapshot is removed and re-added. The other kind's entries are untouched. With `rebuild`, every entry of the kind is removed and re-added.
- **`search:Add` replaces** whatever the slot was indexed with, so a slot can never hold two items' values.
- **Unchanged items are not compared** (data-loader.md §18). `SyncKind(kind, items, rebuild, changed)` with a `changed` set compares only the items in it and the items that are other objects than their slot was indexed from (`search.indexedItems`, kept with the snapshots: `Add` records it, removal and `Wipe` forget it, and an equal new object is recorded in its place). The pipeline passes the items it worked out again (`derived.indexPending`, gathered and cleared by `items:syncIndex`), so a one-slot refresh compares one item, not the bag. This is sound because every in-place change of an indexed value of a committed item either drops the item's kept work, which marks it (`RefreshKeptItem`: quest state, tooltip text, gear sets), or goes through `UpdateCategoryIndex` (the category, which Phase 8 now also reports for Show Bags names); every other indexed value comes from the slot read. The object check brings the index back after a sweep that failed after indexing and before committing. Without `changed`, every item is compared, as before. The randomized equivalence test (data-loader.md §18) checks the index against a clean rebuild after every step.
- **Removal deletes empty value sets** (`removeStringFromIndex`, `removeBoolFromIndex`; the interval tree already deleted empty nodes). Queries treat a missing value and an empty set alike, so this changes no result, but it keeps the structure identical to a clean rebuild, and stops full-text searches (`isFullTextMatch` walks every value) from slowing down as items come and go over a session.
- **`search:UpdateCategoryIndex`** moves an indexed item out of the category it was indexed with (its snapshot's) and updates the snapshot; it does nothing when the snapshot already holds the item's category. The index holds the category each item is shown in. Search categories are matched against each item's own category (data-loader.md §8), so while one is enabled for the kind, Phase 8 moves each item whose shown category differs from its own to its own before matching and back after: two category moves per such item per sweep, no full re-index. With none enabled, nothing moves. Phase 8 also moves an item whenever its shown category changes, Show Bags names included.
- **Acceptance gate:** `spec/search_spec.lua` ("Search incremental indexing (SyncKind)" → "matches a clean rebuild") runs randomized adds, removes, moves, in-place changes, post-index category updates and rebuilds across both bags, and after every step compares the incremental index with `search:IndexItems` over the same items, value by value, including interval-tree min/max. "re-indexes an item when one indexed value changes in place" changes each indexed field on the same ItemData object and checks the same equality, so dropping a field from the snapshot comparison fails a test. `spec/refresh_pipeline_spec.lua` ("incremental search index") checks the equality end to end after targeted, plain and wipe sweeps of both bags. Any change to what `Add` indexes must go through `fillSnapshot`, or these fail.

### 2. Zero-Tooltip-Scanning Overhead on Unchanged Items
- **Rule:** Indexing must never scan tooltips or call client APIs.
- **Optimization:** We decouple heavy text extraction from the indexing loop. Tooltips are scanned during the data-farming phase (Phase 2), caching the results inside `itemInfo.tooltipText`. The search engine simply indexes the cached strings without invoking the WoW client API, keeping the entire indexing loop synchronous and instant.

### 2a. The Tooltip Index Is Full-Text Only (No Prefix N-grams)
`search:addStringToIndex` stores two structures per string: `fullText[value]` (the whole lowercased string, used by substring matching) and `ngrams[prefix]` for **every prefix** of the string (used by `=` / `!=` "starts with" matching). Building the prefixes is quadratic in string length (`prefix = prefix .. c`, one new string and one table per character).
- **Failure mode (fixed):** tooltip text is the whole tooltip joined together, commonly 300-600+ characters, and the v0.5.0 clean sweep re-indexes every item of both bags on every sweep (including a one-slot change). The tooltip prefixes were 85-95% of each sweep: in the `test.lua` harness (176-slot backpack, local Lua 5.1) a targeted sweep cost ~24-39 ms at 300-character tooltips and ~54-111 ms at 600, plus tens of MB of garbage per sweep once bank items were also indexed. Users saw 100+ ms hitches from the timer-resumed half of each refresh, and a large spike at login where several full sweeps run back to back.
- **Rule:** an index created with `search:CreateIndex(name, true)` sets `fullTextOnly` and stores **no** prefix n-grams (`addStringToIndex` / `removeStringFromIndex` skip the prefix loop). The `tooltip` index is the only such index. With it, the same sweeps take ~6-14 ms regardless of tooltip length. Short fields (`name`, `type`, `category`, ...) keep their prefix n-grams.
- **Query semantics:** on a `fullTextOnly` index, `isInIndex` (`=`) returns the substring matches from `isFullTextMatch`, and `isNotInIndex` (`!=`) returns every other indexed item (§5). This is checked **before** the number/boolean branches, so `tooltip = 70` is a text match, not a numeric lookup. Plain searches (`DefaultSearch`) and `%=` were already substring matches over `fullText` and are unchanged. The old `tooltip = x` meant "the tooltip starts with x", which is effectively a name search, so nothing useful was lost. User docs: `README.md` "Search".
- **Coverage:** `spec/search_spec.lua` ("Tooltip index (full text only)").

### 3. API Contract and Lookup Support
- **Wipe:** Wipes all indexed data fields (ngrams, numbers, bools, and fullText indices) and the stored snapshots.
- **SyncKind:** The pipeline's entry point (§1, §4).
  ```lua
  local search = addon:GetModule('Search')
  search:SyncKind(kind, itemsBySlotKey, rebuild)
  ```
- **IndexItems:** A clean rebuild (`Wipe` then `Add` every item). The reference the incremental index is tested against; the pipeline no longer calls it.
- **Downward Compatibility:** The search engine fully supports legacy matching and query execution APIs (`search:Search()`, `search:EvaluateQuery()`, `search:isInIndex()`, and `search:DefaultSearch()`), ensuring no downstream views, filters, or dynamic category rules are broken.

### 4. Single Global Index Shared by Every Kind of Bag
There is exactly **one** search index (`search.indicies`), and it is shared by the backpack, the bank and the guild bank (guild-bank.md §3). It must hold every kind's items after every sweep.
- **Failure Mode (bank-only search filtering everything, under the old clean rebuild):** `items:ProcessRefresh` runs per kind, and a full refresh (`data/refresh.lua:RequestUpdate`) processes the **bank first and the backpack second**. When `Phase8_EnrichCategories` rebuilt the index from only the current kind's `itemData`, the backpack's rebuild wiped the bank's freshly-indexed entries. The live search box (`frames/search.lua:UpdateSearch` -> `search:Search(text)` -> `bag:Search`) then evaluates against a global index that contains only backpack slotkeys, so every bank item resolves to `found = false` and the bank appears to filter out all items for any query. Only the bank breaks, because it is never the last kind indexed. See `spec/refresh_pipeline_spec.lua` ("keeps both bags searchable in the shared global index after a full refresh").
- **Rule:** In `Phase8_EnrichCategories`, call `search:SyncKind(kind, itemData, wipe)` for this kind's fresh, not-yet-committed items (a wipe sweep re-adds them all), then `search:SyncKind(otherKind, slotInfo[otherKind].itemsBySlotKey)` for every other kind's last-committed items (every kind of `const.BAG_KIND`). The second call is what a union with the other kind's committed items did in the clean rebuild: it drops the other kind's entries when its committed items were wiped (`ClearItemCache` before a wipe pair, `ClearBankCache`), and re-indexes any of them mutated in place since its own sweep (e.g. the Show Bags view writes bag names into `itemInfo.category` after indexing), so the index stays equal to a clean rebuild over both bags.
- **Why per-kind computations are unaffected:** The `isSearchResult` loop only reads `searchResults[currentItem.slotkey]` for this kind's `itemData`, and `RefreshSearchCache` writes/reads `searchCache[kind][slotkey]` only, while `GetCategory` reads `searchCache[data.kind][data.slotkey]` for the item's own kind. A cross-kind slotkey therefore can never be read back through the wrong kind, so widening the index to both bags does not change category resolution — it only restores live search.

### 5. Evaluating a Query: Sets, and Negation Over What Is Indexed
A query (`util/query.lua`) is evaluated by `search:EvaluateAST` (`data/search.lua`), and every part of it is the **set of slot keys it matches**: a comparison is an index lookup, a bare word a full-text search over the default fields, AND keeps the items in both sides, OR the items in either, and **NOT** (and `!=`, `search:isNotInIndex`) every item a query can match outside its part's set (`search:Complement`). `search:Search` returns that set; `search:Find` asks it about one item.
- **What a query can match** is `search:Universe()`: the items indexed now (`search.indexed`). In a sweep, Phase 8 syncs every kind's items into the index before it searches (§4), so that is this sweep's items of the kind being read and the committed items of the others. A search instance of other items (BetterBags Next's vendor, `next/merchant.lua`) has its own `indexed`, so a negation there covers only its items.
- **An AND with a NOT side** removes the NOT's expression's items from the other side, without building the complement (measured offline over 1,500 items: 0.18 ms through the complement, 0.06 ms as one side minus the other). `spec/search_spec.lua` checks that such an AND never calls `Complement`.
- **An unknown field** matches nothing, for `=` and `!=` alike (`isNotInIndex` checks the index exists).
- **A bare word naming a true or false field** (`BOOL_FIELDS`, aliases and any case; not quoted) also matches the items where it is true, added to its text search. Reported (issue #1219): `NOT collectable` kept a pet at 1 of 3, since `collectable` alone was only a text search and matched nothing, so its NOT matched everything. So typing `pet` in the search box also finds pets whose text does not say "pet".
- **Grammar** (`QueryParser:Parser`): NOT binds tightest, then AND, then OR, as in Lua (`binary`, `parse_and`, `parse_expression`); AND and OR each group left to right. A NOT only comes before what it negates: one right after a term (`alpha NOT beta`) makes the query invalid (`Query` returns nil, matching nothing), as its old two-sided NOT node evaluated to nothing. Words after the first expression are still ignored (`sword shield` searches `sword`).
- **Failure mode (fixed):** a negation used to return the items it excluded, marked false, plus a `___NEGATED___` marker that only AND read; only a bare `field != value` was completed, against `items:GetAllSlotInfo()` (the bags' committed items). So `NOT rarity = poor` on its own matched nothing, a NOT inside an OR matched too little, the marker leaked into `!=` results as a slot key (the vendor filtered it out by hand), and during a sweep the bare `!=` covered the previous sweep's items: an item that arrived in the sweep did not match a `!=` search category until the next one. Measured with the real modules (docs/vendor-compat.md, "The query engine today").
- **Coverage:** `spec/search_spec.lua` ("Negation": NOT alone, `!=`, inside OR, groups, double NOT, with AND either side, a word, items indexed but not committed, `Find`, unknown fields), `spec/refresh_pipeline_spec.lua` ("puts every item a NOT rule does not exclude in its category", "matches an item arriving in a sweep against a != rule in that sweep"), `spec/next/merchant_spec.lua` (a NOT over the vendor's items). Every guard was mutation-tested (13 mutations; the one that first survived, the AND shortcut, led to the `Complement` test).

### 6. Saved Rules and the Query Language's Version
`QueryParser.VERSION` (`util/query.lua`) is the version of the query language saved rules are written in. 1: AND and OR at one precedence, grouped left to right. 2: AND binds tighter than OR (asked, docs/vendor-compat.md "Decisions").
- **Each profile records it** (`profile.searchRuleVersion`; absent means 1). `DB:MigrateSearchRules(from)` (`core/database.lua`) rewrites every saved rule (`customCategoryFilters[*].searchCategory.query`) of a version-1 profile with `QueryParser:GroupLeftToRight`, then records the current version. It must run once per profile: the rewrite assumes the old grouping, so a rule written for the current precedence would change meaning. AceDB cannot tell an old profile from a new one by its defaults, so every way a profile comes to exist records it:
  - **every load** (`DB:Migrate`): the active profile (profile switches, renames and deletes reload the UI);
  - **a new profile** (`DB:CreateProfile`) and **a reset one** (`DB:ResetCurrentProfile`): marked current, since they hold no old rules and the player may write some before the next load;
  - **a copy** (`DB:CopyFromProfile`): the copy has the source's rules and version, and is migrated at once;
  - **an import** (`DB:ImportSettings`): exports are version 3 since this change (`DB:ExportSettings`); an older export's rules are version 1.
- **`GroupLeftToRight`** adds parentheses only where an AND follows an OR at the same level, putting everything before that AND at that level in parentheses, so `a OR b AND c` becomes `(a OR b) AND c` and `a AND b OR c` is left alone. It works on the input text (the lexer's second result gives each token's span), so quotes and spacing are kept. It leaves a query that does not parse unchanged, a lexer error included (a control character), so a bad saved rule cannot stop the load, and stops at a stray `)`, after which the old parser read nothing.
- **Not rewritten:** plugins' categories (not saved; plugins make them on every load), and queries typed in the search box. Both read with the current precedence.
- **Coverage:** `spec/query_spec.lua` ("binds AND tighter than OR", "GroupLeftToRight": examples, the real profile's rules left alone, a lexer error, unclosed and stray parentheses, and 1,000 random rules, each read by a copy of the old parser and compared with the current parser's reading of its rewrite), `spec/database_migration_spec.lua` ("search rules written before AND bound tighter than OR": rewrite, once, current profiles left alone, new and reset profiles, copies), `spec/database_spec.lua` (export version 3; version 2 imports rewritten, version 3 not). Every guard was mutation-tested (17 mutations; the guard that first survived led to the lexer-error test; one is equivalent: a group's "(" inserted before or after its own "(" is the same text).

### 7. The Bag Name Field
`bagname` (alias `bag`) is the plain name of the bag holding an item: `items:GetPlainBagName(bagid)` (`data/items.lua`), the name Show Bags labels with a number (`items:GetBagName`: "#1: Backpack"). A guild tab's name, Keyring, Bank, Reagent Bank, else `C_Container.GetBagName` ("Unknown" in the backpack, "Bank Bag" in the bank when the client has none). Phase 6 stamps it on every item (`item.bagName`) once per bag per sweep, and `fillSnapshot` indexes it (indexing reads no client API, §2). It is not a default field, so a bare word does not search it.
- **Failure mode (fixed):** the index was created as `bagName` with Search Redone (#494) and the lines filling it were commented out from the start. It was also unreachable: the evaluator lower-cases a field name before looking it up, and every other index is created lower-case. Typing `bagName` still works.
- **Coverage:** `spec/search_spec.lua` ("bag name"; the per-field and randomized re-index tests change it), `spec/items_spec.lua` ("plain bag names", and the Show Bags labels built from them), `spec/refresh_pipeline_spec.lua` ("gives every item the plain name of its bag"), `spec/guildbank_pipeline_spec.lua` ("finds a guild bank item by its tab's name"). Mutation-tested (15 mutations; the stamp's guard for empty slots, which protected nothing, was removed, and the bank's Show Bags label got a test).

### 8. Expansions in Release Order
The `expansion` field (alias `exp`) holds a short name (`const.BRIEF_EXPANSION_MAP`, `core/constants.lua`), so it is a text index, and `<`/`>` on it matched nothing (measured, docs/vendor-compat.md). Asked: they compare expansions in release order.
- **`expansionid`**, a number index, holds the number an item's expansion orders by: the lowest expansion ID the map gives its name (`expansionNumbers`, built by `search:Init` from the map). So TBC Anniversary's 254, which the map names `bc` (`addon.isAnniversary`), orders as 1, between Classic and Wrath. `fillSnapshot` fills it from the snapshot's `expansion`, so it is not a compared field of its own (it changes only with `expansion`, which is).
- **Evaluation** (`evaluate_condition`): an `expansion`/`exp` comparison with `<`, `<=`, `>`, `>=`, or `=`/`!=` with a number, is answered from `expansionid`: a number as it is, else `search:ExpansionNumberOf(name)`, the exact name or the start of exactly one name (`exp >= mid`); none or several (`exp < c`: Classic or Cata) matches nothing. `=`/`!=` with a name stay text matches, as before (`exp = c` finds Classic and Cata).
- `search:Init` must run after `core/constants.lua` built the map; it does (initialization.md, phase 3). A spec that stubs `Constants` and initializes the search module gives the stub a `BRIEF_EXPANSION_MAP`.
- **Cost** (offline, PUC Lua 5.1, a clean re-index of 1,500 items): 25.0-25.7 ms on `main`, 29.0-29.2 ms with this and `bagname` (§7), about 2 ms each; a per-item search of the map at first cost more, so the map is built once.
- **Coverage:** `spec/search_spec.lua` ("expansion order": comparisons by name, case, numbers, `!=` with a number, unique and ambiguous starts, unknown names, text matches kept, Anniversary's 254). Mutation-tested (11 mutations; the one that survived, `expansionid` as a compared field, was equivalent and the field was dropped from the comparison).

### 9. Crafting Quality (`quality`)
`quality` is the crafting quality tier of a profession reagent or a crafted item; an item's quality in the Poor-to-Legendary sense is `rarity`. That split was the intent behind the two fields (the player, 2026-10-21); nothing in the repository recorded it, and `quality` was created with Search Redone (#494) and never filled.
- **Read** in the harvest, never by the index (§2): `items:CraftingQualityOf(link)` (`data/items.lua`) asks `C_TradeSkillUI.GetItemReagentQualityByItemInfo`, and only when that has none, `GetItemCraftedQualityByItemInfo`: the order Blizzard's item buttons use (`SetItemCraftingQualityOverlay`, `Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua:323-339`, which uses the `...QualityInfo` pair; the `...ByItemInfo` pair, used by the auction house, returns the number without a table). Both are documented in `TradeSkillUIDocumentation.lua` (nilable numbers) with the same `SecretArguments` tag as `GetItemInfoInstant` and `GetItemStats`. Each is checked for existence; on a client without them every item has none.
- From the slot's link: a crafted item's tier is its own. `items:ReadItemProperties` (bag and guild bank slots) puts it in `itemInfo.craftingQuality` (`ItemInfoOf`); the vendor's records read it the same way (`next/merchant.lua`). A kept slot keeps it with its link (caches.md §1).
- Indexed as a number (`fillSnapshot`, `NUMBER_FIELDS`), so `=`, `!=`, `<`, `>` take tier numbers. Blizzard's source names no tiers (no "bronze" anywhere but a text color and a Mythic+ medal), so there are no tier names. Rarity names (`quality = epic`) match nothing.
- **Read only once the item's data has loaded** (rule #1, data-loader.md §19): an item read cold (`props.incomplete`) has no tier until it is read again.
- **Coverage:** `spec/items_spec.lua` ("crafting quality": the order, a reagent's crafted tier never asked for, clients without the API, read from the link, not read cold), `spec/search_spec.lua` ("crafting quality"; the per-field and randomized re-index tests change it), `spec/refresh_pipeline_spec.lua` ("reads each item's crafting tier from its link"), `spec/next/merchant_spec.lua` ("searches a vendor item's crafting tier"). 12 mutations, all caught (the read order needed a test).

### 10. Item Traits (`items:ReadItemTraits`)
The fields Vendor's rules use that BetterBags did not have (docs/vendor-compat.md, "Proposed: new fields"), first batch: what an item is, read from the slot's link once its data has loaded.
- **Read in the harvest** (`items:ReadItemProperties`, so bag and guild bank slots alike, and the vendor's records in their loaded branch) into one table, `itemInfo.traits`, built only when the read is complete (rule #1, data-loader.md §19). An item read cold has no traits at all, so every field below is absent for it; the snapshot needs no gate per field.
- **The link, not the item ID.** `items:ReadLinkInfo(link)` reads `C_Item.GetItemInfo(link)` once (the call the bind type already made, `GetBindTypeFromLink`, which it replaces): the required level, max stack, sell price and bind type of the item in the slot, where the item ID gives its base item (the wiki: the item ID's 4th return is "the base item level, not including upgrades"). The ID-based fields the harvest already had (`itemInfo.itemMinLevel`, `itemStackCount`, `sellPrice`) are unchanged, so nothing reading them changes. Only an item link (`item:`) is read: a caged pet's `battlepet:` link is read by item ID, as its bind type was. When the link's data has not loaded while the item ID's has, the read is incomplete too, so the item is read again.
- **Fields** (`fillSnapshot`): `minlevel`, `stacksize`, `price` (numbers, from the link); `equipment` (`C_Item.IsEquippableItem`), `hasuse` (`C_Item.GetItemSpell` returns something: documented as non-nilable, but Blizzard's `/use` code treats it as a truth value, `ChatFrameUtilOverrides.lua:27`), `cosmetic` (`C_Item.IsCosmeticItem`, the item button's cosmetic overlay check), `pet` (`C_PetJournal.GetPetInfoByItemID`, by item ID only: the wiki says a link raises an error; Blizzard's PlayerChoice treats it as a truth value), `scrappable` (`C_Item.CanScrapItem`, bag slots only: it takes a location) (booleans); `upgradeable`, `track`, `upgradelevel`, `upgrademax` and `maxlevel` from `C_Item.GetItemUpgradeInfo`, asked only for equipment and taken only with a `trackString` (as Vendor does) and a `maxLevel` above 0 (a retail capture's Adventurer cloak named a track with 0/0 levels, max item level 0 and no upgrade line in its tooltip; docs/vendor-compat.md, "What a capture settled"); `maxlevel` is the fully upgraded item level, never below the current one, and the current one for an item without a track (Vendor's `MaxLevel`, without its squish curve, which nothing here can verify); `stat`, the item's stat names (`GetItemStats` keys are global strings), sorted, as a list like equipment sets; `quality` (§9) moved into the traits.
- **Each API is checked for existence**; a client without one gives no answer for its field (a boolean field is then absent, not false).
- **Kept with the slot:** every trait is a property of the item in the slot, so a kept slot keeps them with its link (caches.md §1).
- **Left out, and why:** binding booleans (`binding = soulbound OR binding = quest` says it), profession gear (`equipment = true AND class = 19`), sellable (`price > 0`), total price (`price * count`, once arithmetic exists); appearance fields, usability and pet counts (they follow the character's collections and skills: the next batch); the slot-relative values (with the player values).
- **Cost** (offline, PUC Lua 5.1, the real profile's backpack, 57 items, 40 full re-reads, Blizzard's APIs mocked): 4.62-4.79 ms per re-read before, 5.20-5.31 ms after, about 9 µs per item read; only re-read slots pay it. The game's own API calls are not in that figure.
- **Coverage:** `spec/items_spec.lua` ("item traits": the link's values, the item ID's left alone, each trait, upgrade info only for equipment and only with a track, a pet by item ID, missing APIs, cold reads of the item ID and of the link alone, a battle pet link never read as an item link), `spec/search_spec.lua` ("item traits": every field, `maxlevel` with and without a track and above the track's max, stat names by their start, a cold item matching no trait; the per-field and randomized re-index tests change every trait), `spec/refresh_pipeline_spec.lua` ("reads each item's traits from its link, and searches them", a kept slot keeping them), `spec/next/merchant_spec.lua` (the vendor's traits, none read cold), `spec/debug_dump_harness_spec.lua` (every item of the real profile read complete with its traits; its `GetItemInfo` mock now takes links, as the API does). 31 mutations, all caught (the two that first survived led to a test that a battle pet link is never read as an item link and a per-field test changing a track).

### 11. Fields the Pipeline Works Out: `inset`, `upgrade`, `total`
These change on an item a sweep kept, without its slot being read: the gear-set map, the worn gear
or the upgrade provider, another slot of the same item. The index compares only the items marked
`indexPending` and the ones that are new objects (data-loader.md §18), so each marks the item when
it changes.
- **`inset`** (boolean): the item is in any equipment set (`itemInfo.equipmentSets` has a name).
  It follows the sets, which `fillSnapshot` compares, and which `RefreshKeptItem` refreshes,
  dropping the item's `derived` (so Phase 6 marks it) when they change.
- **`upgrade`** (boolean): the arrow BetterBags draws (`item.isUpgrade`, Phase 6, from the active
  provider, data-loader.md §15). Phase 6 marks the item when its arrow changed, or when it became known
  or not known. Absent for an item read before its data loaded (rule #1, data-loader.md §19), whose arrow
  is a guess, and for one its provider cannot tell about yet (`upgradeUnknown`, caches.md §2a): no arrow
  there is no answer, so `upgrade = false` must not take it.
- **`total`** (number): how many of the item the kind's bags hold, by item ID, every stack counted
  (Vendor's `TotalItemCount`). `items:CountItemTotals`, between Phase 7 and Phase 8, every sweep,
  marks an item whose total changed. Per kind: the backpack's bags for the backpack, the bank's for
  the bank, a guild bank's tabs for it.
- **Coverage:** `spec/search_spec.lua` ("gear sets, upgrade arrows and totals"; the per-field and
  randomized re-index tests change the arrow, the total and the cold mark),
  `spec/refresh_pipeline_spec.lua` ("keeps the upgrade field current when a kept item's arrow
  changes", "keeps inset current when a kept item leaves its set", "counts each item across the
  bags, and keeps a kept item's total current"). The randomized "equals a full recalculation" test
  compares the index with a clean rebuild after gear changes. 10 mutations, all caught.

### 12. Toys and "Already Known": Whole Tooltip Lines
`toy` and `known` (booleans) are what two whole tooltip lines say: `Toy` (`TOY`) and `Already
known` (`ITEM_SPELL_KNOWN`, a UsageRequirement line). From a retail capture (docs/vendor-compat.md,
"What a capture settled"): both toys of 88 items had both lines; `C_ToyBox.GetToyInfo` also
answered for them and no other item, but Vendor found the toy box unreliable (`itemproperties.lua`:
"sometimes not available"), and the tooltip comes with the item's data, so the lines are used.
Global string values from Blizzard's enUS strings (Ketho/BlizzardInterfaceResources, live, at
`36dd01db`): `TOY = "Toy"`, `ITEM_SPELL_KNOWN = "Already known"`.
- **The scan marks them** (`markLine`, `data/tooltip.lua`): the joined tooltip text cannot tell a
  whole line from words inside one ("Use: Adds this toy to your Toy Box." is not the toy line), so
  each extraction (bag items on retail and Classic, guild bank and vendor items) notes the left
  texts equal to either string. A recipe's tooltip holds the item it makes after a `NestedBlock`
  line (`TooltipDataLineType` 19), in the same flat list with no end marker: a retail dump's
  Schematic: Stonebound Lantern has the toy's own "Toy" line after it. A toy line counts only
  before a `NestedBlock` line (retail; Classic scans have no line types). `known` still counts
  anywhere: a recipe's own "Already known" (a UsageRequirement line, as its "Requires ..." line in
  the same tooltip) comes after the nested item, and no capture had a known recipe to place it.
  Vendor's own check (`IsItemToyInTooltip`) matches "Toy" anywhere in any line, so it takes the
  recipe for a toy too. Marks are cached with the text, under the same key, kept 1:1 with
  it (`tooltipScanner.marks`; `RemoveFromCache` and `ClearCache` drop them), returned as the second
  value of `GetTooltipText`, `GetGuildBankItemText` and `GetMerchantItemText`; the tooltip's search
  text is unchanged.
- **Carried on the item** (`itemInfo.tooltipMarks`): the harvest, a kept item's refresh
  (`RefreshKeptItem`), a guild bank recalculation and the vendor's records set them with the text.
  The index compares them (they are a field of their own).
- **Read with the item's data** (rule #1): absent for an item without traits.
- **Known staleness:** a toy learned from another copy leaves this copy's cached tooltip as it was
  until it is scanned again (the slot changes, a wipe, or a tooltip resolution).
- **Coverage:** `spec/tooltip_spec.lua` ("line marks": whole lines only, cached and forgotten with
  the text, Classic, guild bank and vendor), `spec/refresh_pipeline_spec.lua` ("finds toys and items
  already known, and follows a kept item's tooltip"), `spec/search_spec.lua` (cold items; the
  per-field and randomized tests change the marks), `spec/debug_dump_harness_spec.lua` (the capture's
  two toys). 19 mutations, all caught (the one that first survived led to a cold item carrying
  marks in the tests).

### 13. Usability and Appearances
- **`usable`** (boolean): whether the character can use the item, `items:CanUseItem`
  (`C_PlayerInfo.CanUseItem`, retail; nil without it). A retail capture: false for the 9 recipes of
  professions the character lacks, true for the other 79 items. It follows the character, so it is
  not a trait: the harvest asks it for an item read with its data (bag and guild bank slots,
  `items:ReadCharacterState`), and `items:RefreshCharacterState` asks again on every kept item (`RefreshKeptItem`, a guild bank
  recalculation), marking the item `indexPending` when the answer changed (data-loader.md §18).
  What changes it (level, skills, spec, gear) already requests a recalculation for the upgrade
  arrows (caches.md §2). Spells and reputations (`SPELLS_CHANGED`, `UPDATE_FACTION`, bucketed:
  they fire often) run `items:OnCharacterStateChanged(false)`, which asks every committed item of
  the open kinds again (`CharacterStateChanged`) and recalculates only the kinds where an answer
  changed. **Why:** a diagnostics login capture (retail 12.1.5, 2026-10-21) had `CanUseItem` answer
  false for all 30 backpack items, food included, at the end of the loading screen, false for 6
  after the first `SPELLS_CHANGED`, and true for all after the second, about 2.2 s later; the first
  bag read came only 0.23 to 0.3 s after it in every login captured, so a slower login would have
  kept "unusable" until some other refresh. On a `/reload` the answers were right from the start. The vendor's records take the merchant's own flag
  (`GetMerchantItemInfo`'s isUsable).
- **`equippable`**: usable and equipment.
- **`transmoggable`** (a trait): the item has an appearance (`C_TransmogCollection.GetItemInfo`
  returns one: the capture's cloak; nothing for the other 87 items).
- Whether an appearance is collected waits for a login capture: when the appearance collection
  loads is not known yet (docs/vendor-compat.md, "Needs an in-game check"). Pets: §14.
- **Coverage:** `spec/search_spec.lua` ("usability and appearances"; the per-field and randomized
  re-index tests change both), `spec/items_spec.lua` (traits: appearances, missing API, not read
  cold), `spec/refresh_pipeline_spec.lua` ("asks whether the character can use each item, again on a
  kept item, never cold"), `spec/guildbank_pipeline_spec.lua` ("finds the guild bank items the
  character can use"), `spec/next/merchant_spec.lua` (the merchant's flag),
  `spec/debug_dump_harness_spec.lua` (the capture's 9 recipes, the cloak). 14 mutations: the three
  that first survived led to a recalculation test that changes no category and to removing two
  guards that could not change anything (a kept item always has traits; `nil and x` is nil).

### 14. Pet Counts
**A caged pet is its species** (`items:ReadItemTraits`, issue #1219): every cage's item is the same Pet Cage (82800), so its species is read from the first value of its `battlepet:` link (Blizzard's `BattlePetToolTip_UnpackBattlePetLink`), and `pet`, `petcount`, `petlimit` and `collectable` answer for it. Not seen in game yet: a cage in a real bag.
Vendor's `PetCount`, `PetLimit` and `IsPetCollectable` (`itemproperties.lua`): **`petcount`** and
**`petlimit`** (numbers), how many of the item's battle pet species the account has and may have,
and **`collectable`** (boolean), whether one more can be learned (count below limit); false for an
item that teaches no pet, absent for an item with no answer about pets.
- **Read:** `items:PetCountsOf(speciesID)`, `C_PetJournal.GetNumCollectedInfo` (not in the generated
  API documentation; Blizzard_PetBattleUI.lua reads it as `numOwned, maxAllowed`, and a retail
  capture answered 1 of 1 for both of its pets). The species comes from the item's traits
  (`GetPetInfoByItemID`, §10). Like `usable`, the counts follow the account, not the item: read with
  the item's data (`items:ReadCharacterState`) and again on every kept item
  (`RefreshCharacterState`), which marks it `indexPending` when they changed.
- **Not before the journal has loaded, and known on a reload.** A fresh-login capture (retail 12.1.5, 2026-10-21):
  `C_PetJournal.GetNumPets` answered 2014 pets, 0 owned, at 6.9 s (during the loading screen), and
  2045, 234 owned at the first `PET_JOURNAL_LIST_UPDATE`, at 13.36 s, just after the loading screen
  ended (13.34 s) and 1.4 s before the startup read (14.80 s). A diagnostics run's `/reload` capture:
  the journal answered 234 owned from its first sample (at `ADDON_LOADED`), and its first
  `PET_JOURNAL_LIST_UPDATE` came 59 ms after the first bag read had started. So `PetCountsOf` takes the
  journal as loaded (`items._petJournalLoaded`) once the event has fired or `GetNumPets` reports a
  pet owned (no capture showed a partial count: 0, then the full count, in three logins), and
  answers nil until then, so a count read too early is absent, never 0. An account without a pet
  waits for the event.
- **Events** (registered in `RegisterCacheEvents` where the client has them): `PET_JOURNAL_LIST_UPDATE`,
  `NEW_PET_ADDED`, `PET_JOURNAL_PET_DELETED`, `PET_JOURNAL_PET_RESTORED` (PetJournalInfoDocumentation)
  run `items:OnCharacterStateChanged(true)` (shared with usability, §13): it marks the journal
  loaded, asks every committed item of the backpack (and of the bank and guild bank while open:
  opening them reads them) again, and sends `bags/Rederive` naming only the kinds where an answer
  changed; nothing when none did. When the journal first loads it recalculates every open kind
  regardless: on a `/reload` the event came while the first read was under way, with nothing
  committed to compare, and the request waits for that read in the queue.
- **Vendor items** take the counts when the vendor's items are read (`next/merchant.lua`); a pet
  learned while the vendor stays open is shown at the next read of the vendor.
- **Coverage:** `spec/items_spec.lua` ("knows a pet's counts only once the pet journal has loaded"),
  `spec/refresh_pipeline_spec.lua` ("pet counts": the events, nothing before the journal loads, a
  recalculation on a change and only then, the limit alone, the bank only while open, a pet read
  after the load), `spec/search_spec.lua` (the fields; per-field re-index tests on a pet; the
  randomized test), `spec/next/merchant_spec.lua` (a vendor pet), `spec/debug_dump_harness_spec.lua`
  (the capture's pets, 1 of 1), and for the reload case and the shared check: "knows the counts at
  once when the account already owns pets", "recalculates the bags when the journal first loads, even
  with nothing committed yet", "usability that changes with spells and reputations" (8 more
  mutations, all caught). 22 mutations: five first survived; three led to tests (the limit
  alone, a closed bank, a pet's count changed alone) and two to removing code that guarded nothing
  (comparing `collectable`, which follows compared fields; a pet check on items that cannot have
  counts otherwise).

### 15. Expressions: Arithmetic, Money, Functions and Player Values
Step 4 of docs/vendor-compat.md ("Proposed: the math"), with the player values of step 3.
- **Lexer** (`util/query.lua`): `==` and `~=` are operators (also unspaced, `a~=b`); a comma is a
  token; a word that is only `+ - * / %` is an arithmetic token (a lone `%` too, `%=` stays an
  operator). Signs inside a word stay part of it (`100-10`, `-5`), so every word reads as before.
  A quoted string's token says `quoted`.
- **Parser**: `or := and (OR and)*`, `and := not (AND not)*`, `not := NOT not | comparison`,
  `comparison := sum [op sum]`, `sum := product ((+|-) product)*`, `product := unary ((*|/|%)
  unary)*`, `unary := - unary | primary`, `primary := ( or ) | word | word ( args )`. A word compared
  with a word is the `comparison` node it always was (with `quoted` when the value was quoted); any
  other comparison is a `compare` node of expressions (`word`, `arith`, `neg`, `call`). A condition
  used as a number, a number used as a condition, an unknown function (`QueryParser.FUNCTIONS`: min,
  max, floor, ceil, abs; `math.` accepted), and arithmetic that is not compared are parse errors:
  the query matches nothing.
- **Reading a word** (`search:ValueOf`): quoted, text; `player.<name>`, a player value; a number or
  money (`5g`, `50s`, `1g50s`, `20c`, `moneyOf`), a number; a field (`fieldKey`, aliases included),
  the item's snapshot value; anything else, text. A `comparison` reads its word by the field's type,
  so every query keeps its meaning: a `player.` word is the player value with any field (`tooltip %=
  player.class`, what Vendor writes as `TooltipContains(PlayerClass())`); only for a numeric field do
  money and another numeric field's name take their new meaning; with a text field any other word is
  text (`name = level`); an equipment slot token (`INVTYPE_HEAD`) on `slot` is the slot's name; a word
  naming no field on the left matches nothing, as an unknown field always has, unless it is a player
  value or a number. A constant that is a list (a class's token and name, every profession) is
  checked item by item, any of its values matching.
- **Answering a comparison** (`EvaluateAST`): with no field on either side, the same for every item
  (`everything`) or none; a bare field against a constant (folded: player values and arithmetic on
  them), from the index as before, sides swapped (`FLIPPED`; `%=` cannot be) when the field is on the
  right; anything else item by item (`search:MatchEach` over the snapshots, its constant parts folded
  once, `search:Fold`). `compareValues` follows the index's semantics (text without case, `=` by its
  start, `==` whole, `%=` anywhere; a missing value matches only `!=` and `~=`, as `isNotInIndex`
  answers them), which a randomized test checks against the index (`field op N` against `field + 0
  op N`, alone and inside AND, OR and AND NOT).
- **Narrowing**: within an AND, a side the index answers is evaluated first and the other gets its
  matches as `within`; item-by-item checks and NOTs (`Complement(set, within)`) go only over those.
- **`==` / `~=`** (`search:isExactly`): a text index's whole lowercased value (`fullText`), a number
  or boolean as `=`; rarity and expansions map them to `=` and `!=`.
- **Player values** (`search:PlayerValue`), read when the query is evaluated, as Vendor's player
  functions are: `level` (`UnitLevel`), `ilvl` and `equippedilvl` (`GetAverageItemLevel`'s first and
  second returns, floored, as Vendor's `PlayerItemLevel`), `class` (the English token and the
  localized name, either matches), `classid`, `spec` and `specid` (`GetSpecializationInfo` of
  `C_SpecializationInfo.GetSpecialization`, else the globals; none for index 0), `profession` (every
  profession's name and skill line, from `GetProfessions` and `GetProfessionInfo`'s 1st and 7th
  returns, as a retail capture recorded them), `name`, `realm` (`UnitFullName`). A diagnostics capture
  showed the specialization reading 1 and the average item level 0 early in the load, both right
  about 11 s in, before any bag read (docs/vendor-compat.md, "What a capture settled").
- **Kept current**: every event that changes a player value (`PLAYER_LEVEL_UP`, `PLAYER_LEVEL_CHANGED`,
  `PLAYER_AVG_ITEM_LEVEL_UPDATE`, `SKILL_LINES_CHANGED`, `LEARNED_SPELL_IN_SKILL_LINE`,
  `PLAYER_SPECIALIZATION_CHANGED`) already recalculates the backpack and the open bank for the upgrade
  arrows (caches.md §2), and a recalculation runs every search category again. Class, name and realm
  do not change. Not refreshed by them: the guild bank and the vendor's items (read again when opened).
- **Changed meaning**: a lone `+ - * / %` or a comma used to be a word; after a comparison such a
  word was ignored (`category = Gear - Tank` was `category = Gear`). It is now arithmetic or an
  argument separator, so such a rule matches nothing; quote the text. The real profile's saved rules
  have none.
- **Coverage:** `spec/query_spec.lua` (tokens, precedence, calls, unary minus, quoted words, the old
  forms unchanged, parse errors), `spec/search_spec.lua` ("expressions": `==`/`~=`, money, folding,
  flipping, every player value, no specialization, field against field, arithmetic, functions (Vendor's
  Potential Upgrades rule), NOT, missing values, narrowing (`MatchEach` given one candidate either way
  round), folding once (`PlayerValue` asked once), the NOT within an AND (`Universe` never asked),
  slot tokens, text fields; the randomized index-against-item test). 39 mutations: eight first
  survived and led to tests.

### 16. Slot Values: `slotequipped` and `slotbest`
Vendor's `CurrentEquippedLevel()` and `WatermarkLevel()` (`systems/rules/builtins.lua`), per item, so
a rule compares an item with what the character wears (`ilvl > slotequipped`, Vendor's Side-grade or
Better: `maxlevel >= slotbest`).
- **`items:SlotLevelsOf`** (Phase 6, next to the upgrade arrow, every sweep): for equipment read with
  its data (`traits.isEquipment`), `slotequipped` is the lowest current item level worn in the item's
  slots (`inventorySlots`; `equipmentCache`, keyed by the worn item's own slot), 0 when nothing is
  worn there, as Vendor's; a one-hander (`INVTYPE_WEAPON`) counts only the main hand without
  `CanDualWield()`, and a Warrior's two-hander both hands, as Vendor's. Nil before the worn gear has
  been read. `slotbest` is `C_ItemUpgrade.GetHighWatermarkForItem(link)`'s first return, the
  character's (retail; the dump recorded 246 for the worn 246 items). Nil for anything else.
- **Kept current**: they change with the worn gear, not the item: `PLAYER_EQUIPMENT_CHANGED` already
  recalculates the bags (caches.md §2), and Phase 6 marks an item `indexPending` when either changed,
  as for the arrow (§11).
- **Not verified at login**: whether the watermark answers before the first bag read; a later
  recalculation corrects it.
- The spec mocks gained Blizzard's `INVSLOT_*` values (`Blizzard_FrameXMLBase/Constants.lua`).
- **Coverage:** `spec/refresh_pipeline_spec.lua` ("slot values": lowest worn level and the watermark,
  dual wield, a Warrior's two-hander, nothing worn, kept current over a gear change with a field
  compared against it, read cold), `spec/search_spec.lua` (per-field re-index tests). 8 mutations, all
  caught.

### 17. Collected Appearances: `appearance` and `source`
Vendor's `IsAppearanceCollected` / `IsUnknownAppearance` (`appearance = known` / `unknown`) and this
item's own source (`source = known` / `unknown`), text fields.
- **Read** (`items:AppearanceStateOf(traits, link)`): the traits keep the appearance and source IDs
  (`C_TransmogCollection.GetItemInfo(link)`, the call `transmoggable` already makes). The appearance
  is known through its own source (`PlayerHasTransmogItemModifiedAppearance`), any source of the
  appearance (`GetAppearanceSources`, `isCollected`), or the item (`PlayerHasTransmogByItemInfo`), in
  that order, as Vendor asks (its soulbound shortcut left out: not checked against data). A retail
  dump: all three agreed on 141 items, except `PlayerHasTransmogByItemInfo` saying no for 3 artifacts
  where the others said yes. No uncollected appearance was in a dump.
- **Not before the collection has loaded** (`items:AppearanceCollectionLoaded`): loaded once
  `GetCategoryCollectedCount` is above 0 for a category other than None. Captures: 0 until the player
  entered the world, then 3,083, on a login and a reload, both before the first bag read;
  `TRANSMOG_COLLECTION_UPDATED` fired at login with 0 collected, so it is no sign. Asked at most once a
  frame until loaded, then never. An account with nothing collected never loads: the fields stay absent.
- **Follows the account**, like usability and pet counts (`ReadCharacterState`, `RefreshCharacterState`,
  `CharacterStateChanged`): `TRANSMOG_COLLECTION_UPDATED`, `TRANSMOG_COLLECTION_SOURCE_ADDED` and
  `_REMOVED` (bucketed, with spells and reputations) recalculate the kinds where an answer changed, so
  a read made before the collection loaded is corrected too. Vendor items take it when read.
- **Coverage:** `spec/items_spec.lua` ("appearances": nothing before the load, once a frame until
  loaded and then never, None not counted, each way of knowing, no appearance),
  `spec/refresh_pipeline_spec.lua` (the events, a collected appearance recalculating and the search
  following), `spec/search_spec.lua` (the fields; per-field re-index tests),
  `spec/next/merchant_spec.lua`, `spec/debug_dump_harness_spec.lua` (the capture's cloak). 14
  mutations: three first survived and led to tests.
