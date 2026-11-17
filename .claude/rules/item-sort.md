---
paths:
  - "util/sort.lua"
  - "data/items.lua"
  - "data/categories.lua"
  - "config/catalog.lua"
  - "core/constants.lua"
  - "core/database.lua"
  - "next/settings/categories.lua"
  - "next/settings/content.lua"
  - "spec/sort_spec.lua"
  - "spec/items_spec.lua"
  - "spec/categories_spec.lua"
  - "spec/database_spec.lua"
  - "spec/database_migration_spec.lua"
  - "spec/config/catalog_spec.lua"
  - "spec/config/settings_effects_spec.lua"
  - "spec/next/settings/categories_spec.lua"
  - "spec/next/settings/content_spec.lua"
  - "spec/gap_reconciliation_spec.lua"
  - "spec/refresh_pipeline_spec.lua"
  - "spec/integration/next_settings_spec.lua"
---
# Item Orders (`util/sort.lua`, Item Order, Then By, And Then By)

The order of items within each section of a bag. An order is a list of keys (`const.ITEM_ORDER_KEY`): the first decides,
each next one breaks the ties of those before it. Each bag kind and view keeps its own (`DB:GetItemOrder(kind, view)`,
`DB.data.profile.itemOrder[kind][view]`, `const.DEFAULT_ITEM_ORDER`, Quality, until one is chosen), chosen with three
dropdowns in the bag's Layout tab, Order (`config/catalog.lua`: `itemOrder`, `itemOrderThen`, `itemOrderLast`). A
category can have its own, which its items take in every bag that uses it (§5). There is one settings window (the
classic one was removed; config/README.md).

## 1. Keys, not orders (issue #108)

Asked (#108, and #203, its duplicate): "multiple sort tiers within categories", "by ilvl, by slot, by rarity, by count, or
alphabetical ... allowing all of those filters to apply in a specific ordering", and in a comment, three Stormwind
teleport cloaks of three names (Wrap of Unity, Shroud of Cooperation, Cloak of Coordination: one slot, Back) that no order
put together. The user decided: an order is made of keys, moving away from the hand-written orders ("in general this
sounds like something we should probably do and move away from hand written ones"); three dropdowns choose it ("dropdowns
may work, i would need to see it in game"); "global order goes in the bag's layout/order section, but then each category
can have it's own sort order"; and Upgrade Track (#1325, made the same day as a seventh order) rolled into the keys.

| Key (`ITEM_ORDER_KEY`) | Dropdown | Order |
|---|---|---|
| `name` | Name | A to Z (the string's byte order, as before) |
| `quality` | Quality | highest first |
| `itemLevel` | Item Level | current item level, highest first |
| `upgradeTrack` | Upgrade Track | the item level the track upgrades to, highest first; no track (or read cold) last (§4) |
| `equipmentSlot` | Equipment Slot | the character sheet's order, top to bottom, then the weapons, then what is equipped elsewhere (`SLOTS`); a robe where a chest piece is; not equipment last |
| `itemType` | Item Type | Blizzard's class ID, then subclass ID (`Enum.ItemClass`): the same in every language, and under Armor Cloth, Leather, Mail, Plate |
| `expansion` | Expansion | oldest first; none read as Classic's (0) |
| `count` | Count | the count the button shows (a merged virtual stack's total, else the pile's), highest first |
| `sellPriceStack` | Sell Price (Stack) | what the stack the button shows sells for, highest first (§2) |
| `sellPriceEach` | Sell Price (Each) | what one sells for, highest first (§2) |

The dropdowns list them in the order Name, Quality, Item Level, Upgrade Track, Equipment Slot, Item Type, Expansion,
Count, Sell Price (Stack), Sell Price (Each) (`sort:ItemOrderKeys`, `ItemOrderKeyName`). The names are not translated,
as the catalog's choices are not.

- **One comparison** (`sort:ItemDataComparator(order)`, `inOrder`): free slots and gaps last; two items either of which
  lacks its data (`invalidData`: no quality, count, GUID or name) left unordered; then each key in turn; then the name
  when the order has not got it; then the bigger pile (`currentItemCount`, the item's own, never a virtual stack's
  total); last the GUID, which makes the order total. Each key's comparison (`compare[key]`) compares its two values
  itself, with no helper call: a sort of 600 items calls them about 6,000 times (§6).
- **A key it does not have asserts** (`"Unknown item order key: "`), when the comparison is made. Saved orders are
  BetterBags' own; a pasted one is read by `itemOrderOf` first (§5d), so none reaches it.
- **The equipment slots** are `Enum.InventoryType`'s `ItemEquipLoc` strings, as warcraft.wiki.gg lists them and the UI
  source uses them (`INVTYPE_HEAD` ... `INVTYPE_EQUIPABLESPELL_WEAPON`, `INVTYPE_BAG` last); the captures hold
  `INVTYPE_CLOAK`, `INVTYPE_BAG` and `INVTYPE_NON_EQUIP_IGNORE` (`spec/fixtures/dump_retail_12_1_5*.lua`). The harvest
  sets `""` for an item with none: it goes with what is not equipment.
- **Only the data form.** The data pipeline sorts with `sort:GetItemDataSortFunction(kind, view)` (`items:Phase9_Sort`,
  and the new items `items:BuildOrderedItems` appends, data-loader.md §13). The item button forms (`SortItemsBy*`,
  `GetItemSortFunction`, `GetItemSortBySlot`) had no caller and went with the hand-written orders.
- **Upgrade Track only where the client reads tracks** (`C_Item.GetItemUpgradeInfo`, as `items:ReadItemTraits` asks):
  the Sort module decides when it loads (`OFFERED`, `sort:OffersItemOrderKey`), and the catalog names it in Item Order's
  description and keywords only there. Elsewhere no item has a track, and the key would order nothing.
- Show Bags (`SECTION_ALL_BAGS`) ignores the item order: it is always slot order (`SortItemDataBySlot`, keyring.md).

### 1a. Choosing an order: three dropdowns

Item Order, Then By and And Then By are each a tier of the order (`const.ITEM_ORDER_DEPTH`, 3), defined once
(`itemOrderTier` in `config/catalog.lua`) on the Sort module's helpers, which a category's Item Order tab uses too (§5c):

- **What a tier lists** (`sort:ItemOrderChoices(order, tier)`, read each time its menu opens: the catalog binds a
  setting's `itemsFunction` to its bag): Item Order every key offered; a later tier None, then the keys the tiers above
  it have not taken.
- **What it shows** (`ItemOrderChoice`): its key's name, or None.
- **What choosing saves** (`WithItemOrderChoice`, a new list): the key at that tier. A key is in an order once, so a key
  chosen leaves the tier below that had it (`{Quality, Item Level, Count}`, Item Order set to Count: `{Count, Item
  Level}`); None takes a later tier out and the tiers below move up. Choosing re-sorts the bags at once
  (`bags/Rederive { resetLayout = true, buttons = true }`).
- **And Then By is off while Then By is None** (`disabled`).
- Choosing Upgrade Track adds no Item Level: what the player chose is the order (Then By Item Level gives the old Upgrade
  Track order).

### 1b. Saved, and what profiles had before (`core/database.lua`)

- `DB:GetItemOrder(kind, view)` returns a new list, the saved one's copy or `DEFAULT_ITEM_ORDER`'s; `DB:SetItemOrder`
  saves a copy. `itemOrder` has no defaults in `DATABASE_DEFAULTS` but an empty table: AceDB strips a default's entries
  one by one at logout and copies them back at load, which for a list could put the old default into a hole.
- **`DB:MigrateItemOrders`** gives each kind and view, once, the keys the order it saved (`profile.itemSort`,
  `const.ITEM_SORT_TYPE`) sorted by, then drops `itemSort`: Alphabetically `{name, quality}`, Quality `{quality}`, Item
  Level `{itemLevel}`, Expansion `{expansion}`, the Sell Prices `{sellPriceStack}` and `{sellPriceEach}`, Upgrade Track
  `{upgradeTrack, itemLevel}`. Each gives the order it gave (`spec/sort_spec.lua`, "gives each order a profile saved
  before the order it gave"). An order at the old default was never saved and stays the default; an order already of
  keys is kept. It runs last in `DB:Migrate` (after the profile system's, which can switch profiles) and in
  `CopyFromProfile`; switching profiles reloads the UI.

## 2. Sell Price (Stack) and Sell Price (Each) (issue #1303)

Asked: sort items within each section by what a vendor pays, highest first, "by the value of the whole stack,
and by the price of one item", so the player sees what to sell or destroy when the bags are full.

- **The price is Auto Sell's:** `items:SellPriceOf(data)` (`data/items.lua`), shared with Auto Sell's total
  (`automation:FinishSale`). Asked which price: "yes, autosell is fine". It is the item in the slot's price,
  read from its link once its data has loaded (`itemInfo.traits.sellPrice`, search-indexing.md §10), else its
  base item's, by item ID (`itemInfo.sellPrice`), else 0.
- **0 for an item no merchant buys:** the slot's `containerInfo.hasNoValue`, the flag Auto Sell sells by
  (automation.md §2). It disagrees with the price for 1 of 88 items in the retail 12.1.5 capture
  (`spec/fixtures/dump_retail_12_1_5.lua`): Mark of Honor (137642) sells for 1 copper and is flagged. So what
  no vendor buys goes last, as the issue asked, never beside 1-copper junk. Auto Sell's total is unchanged by
  it: a sale never holds an item with the flag (`SellList`, `Seller`).
  - **Left as is: the guild bank has no such flag.** Its harvest sets `hasNoValue = props.sellPrice == 0`
    (`items:HarvestGuildBank`), from the item ID's price, so an item like Mark of Honor would sort beside
    1-copper junk there. Not seen: the bug review found it needs a bound item, which a guild bank does not take.
- **Stack: the count the button shows.** Asked: "yes, the one the button shows". The price times
  `data.stackedCount or itemInfo.currentItemCount` (`shownCount`, which Count sorts by too): a merged virtual stack's
  total (set by `Phase7_ApplyVirtualStacks`, which runs before the sort), else the pile's own count, as the button
  draws it (`frames/item.lua`, `SetItemButtonCount`).
- **Each:** the price of one, whatever the count.
- **An item read cold** has no traits, so it sorts by its base item's price (0 when that has not loaded
  either) until its data loads. Once it has, closing the bag puts it in order: its rehash marks the bag
  (data-loader.md §13), and so does a price that put it out of order without one (§3).

## 3. An open bag out of order

While a bag is open, Preserve Empty Slots as Gaps (default on) keeps every item where it was and appends new
items at the end (`items:BuildOrderedItems`, data-loader.md §13). An item's place only changed on close when a
sweep left a gap or kept a rehashed item. A stack's count is not in its hash (`GenerateItemHash`), so a stack
that grew kept its place and nothing re-sorted it on close: under Sell Price (Stack) a stack that grew past
another's worth stayed below it across a close and a reopen. A new item likewise stayed at the end of its
section until a refresh while the bag was closed: a valuable item looted with the bag open stayed below the
junk under Sell Price.

- **The check:** once the kept items, the gaps and the new items are placed, `BuildOrderedItems` asks
  `items:OutOfOrder(result, sortFunc)` whether two items of one category (`itemInfo.category`), gaps aside, are
  the other way round in the bag's item order, each compared with the item of its category before it. When so
  it marks the bag (`items:MarkDrawOnClose`), and closing it refreshes into a fresh sort (`bagProto:OnClosed`,
  `panelProto:OnClosed`, with the frame hidden). The sort function is the one §5 makes, so a category with its own
  order is checked by it.
  - **One category, because a section is one:** `Phase10_PartitionIntoTabs` gives each tab's sections their
    category's items in the list's order. Comparing across categories marked a bag whose every section was in order:
    in the second review's 1,800 random sweeps, 375 of the 1,426 marked (26%), above all a looted item in Recent Items
    against the last item of another section. A category can span tabs (the bank's), which only compares more items
    than a section holds, never fewer, so it misses nothing: a list holding a section's items in order holds them in
    order too.
  - **Neighbours suffice:** a list is in a strict weak order exactly when no neighbouring pair is out of it.
    Items the order holds equal (two guild bank piles of one item, whose GUIDs are empty) are not out of order.
  - The third review checked every view that draws sections (`views/views.lua`, `next/content.lua`, Recent
    Items in `frames/bag.lua` and `next/content.lua`, group by's subcategories, which are their items' own
    category): each takes a section's items by `itemInfo.category`, in the list's order. 20,000 random lists
    with tabs and gaps: no section out of order went unmarked.
  - **Left as is:** an item with no category is grouped under `""`, where the sections say "Everything".
    Not reachable: `GetCategory` always returns a string.
- **It returns the two slot keys** (earlier, later), or nil, so a profiler capture's call trace shows which pair
  marked the bag (`Items.OutOfOrder`, perf-profiler.md §4).
- **Every order, not only Sell Price:** any sort key that changes without the hash counts (a count under any
  order's tie-break or Count, a cold item's name or price once read), and so does a new item the order puts before the
  items of its section above it. Two piles of one item can then swap places on the next open, and a close after
  looting can refresh once.
- **It does not loop.** The refresh on close is queued without `resetLayout`. When it runs with the bag closed
  it is a fresh sort, which never marks; when the player reopens the bag first, it keeps every item in place and
  marks the bag again, and the next close re-sorts it. Nothing moves while the bag is shown.
- **Bug reviews:** the first version ran the check before the new items were appended, so an item looted out
  of order was put in place on close only if another sweep ran while the bag was open; it runs after them since.
  The second found the cross-category marks above.
- **Left as is: an item without its data hides an inversion across it.** The comparison leaves such an item
  unordered with every other (`invalidData`), so `OutOfOrder` does not see past it (`{cheap, bad, dear}` gives
  nil). Not seen: the harvest fills in an empty name and GUID and a quality, so a real item does not get there.
- **Cost:** one comparison per item in each sweep while the bag is open, and the refresh on close it adds.
- Asked: "go ahead and do as you will here, we'll test in game".

## 4. Upgrade Track (issue #769)

Asked: arrange gear "according to their upgrade level (i.e mythic, hero, champion) instead of current item level".
Item Level mixes the tracks, because they overlap: each track's lowest ranks sit below the highest ranks of the track
under it (a Veteran 6/6 sorts above a Champion 1/6). Upgrade Track keeps each track together, the highest first. Made as
a seventh order (#1325: the track, then the current item level), then a key (#108): the order it was is Upgrade Track,
Then By Item Level, which a saved order 7 becomes (§1b). The user decided against a Group By Track for search categories;
a category of one track is a search category (`track = hero`, README).

- **A track's rank is the item level it upgrades to** (`trackTop` in `util/sort.lua`): the item's
  `itemInfo.traits.upgradeMaxItemLevel` (`items:ReadItemTraits`, search-indexing.md §10), the client's
  `C_Item.GetItemUpgradeInfo(link).maxItemLevel`, or the level the item's own level and rank reach when the client
  answers 0, as Midnight's does (§4a). Within a season every track tops out at its own item level,
  higher for a higher track. The track's name (`trackString`) cannot rank it: it is in the game's language.
  `trackStringID` was not used either: one value has been seen (Adventurer, 971, `spec/fixtures/dump_retail_12_1_5.lua`),
  so nothing says its IDs follow the tracks' order.
- **No track is rank 0, after every track:** gear `ReadItemTraits` does not put on a track (a track string with no
  levels, as last season's gear reads: 0/0 and maximum item level 0 in the 12.1.5 dump), everything that is not gear,
  and an item read cold (no traits yet).
- **Once a cold item's data loads**, it gets its traits and its rank in place; with the bag open it is kept where it
  was and the bag is marked, and closing it puts it in order (§3). So does an item upgraded at the upgrade vendor
  while the bag is open (a new link and item level).
- **Not verified in game, by the user's decision** ("no need for a capture", and for #1332 "skip the capture step"):
  no capture has held gear with upgrade levels (docs/vendor-compat.md, "Needs an in-game check"). #1325 trusted the
  client's `maxItemLevel`, which the game answers 0 (§4a).
- **#1325's bug review** found no bug in the order or the re-sort on close. It found the description and keywords
  naming Upgrade Track where the dropdown did not offer it, and a gap test that passed with the gap check removed;
  both fixed then.

### 4a. When the client answers 0 (issue #1332)

Reported: with Upgrade Track chosen, the bags stayed in item level order. Midnight's client answers 0 for the
`maxItemLevel` of gear on a track: Vendor (typicalzergling/vendor, `systems/itemproperties/itemproperties.lua`) works the
level out itself since 2026-09-21 ("it seems blizzard realized the error and instead made everything 0"). Every track
then ranked 0, Upgrade Track ordered nothing, and its Then By decided alone (Item Level, the order #1325 made): a
Champion 6/6 at 308 above a Hero 1/6 at 305. #1325's specs mocked a `maxItemLevel` for each track, so they passed.

- **`topOfTrack(level, rank, ranks)`** (`data/items.lua`, called by `ReadItemTraits` when the client answers 0): from
  the link's item level (`C_Item.GetDetailedItemLevelInfo(link)`, the tooltip's, upgrades included; the retail 12.1.5
  capture had it equal `GetCurrentItemLevel` at the slot for every item), each rank to the last adds 3 item levels, 4
  from a level of 12 modulo 13. It agrees with Vendor's `getMaxItemLevelForUpgradeInfo` for every item level on that
  ladder (3, 6, 9 or 12 modulo 13) at rank 1 and up (the bug review compared both from 200 to 400, tracks of 1 to 8
  ranks), and it gives each published track range from every rank: Season 2's Adventurer 266-282, Veteran 279-295,
  Champion 292-308, Hero 305-321 and Myth 318-334, Season 1's Hero 259-276 and Myth 272-289 (`spec/items_spec.lua`).
  Every item on one track reaches the same level, so Then By orders a track's items.
- **The client's own when it gives one** (above 0); the link's item level is not asked for then. When the link has no
  item level (`GetDetailedItemLevelInfo` may return nothing), the client's 0 stays: that item ranks with no track.
- **The search's `maxlevel`** reads the same trait, so it is the fully upgraded item level again too (search-indexing.md
  §10).
- **Left as is: a season whose ranks step otherwise.** Its levels would come out a little off: the tracks still rank
  right while each lands nearer its own top than the next track's (13 apart in both Midnight seasons), but two items of
  one track could rank apart, before Then By. Not seen: both Midnight seasons follow the ladder. Off the ladder Vendor
  reads any other remainder as 6 (286 at 3/6: 296 there, 295 here); neither is a level the tracks have.
- **Left as is: an item at rank 0 of a track** (`currentLevel` 0, `maxLevel` above 0). `topOfTrack` adds every rank, so
  a Hero 0/6 at 305 would reach 324, past the track's top, where Vendor keeps the item's own level. Found by the bug
  review; not built for, as no client has shown a track item at rank 0 (`currentLevel` is documented only as never nil,
  `ItemDocumentation.lua`).
- Coverage: `spec/items_spec.lua` ("the item level a track reaches, when the client answers 0": every rank of the seven
  ranges, the issue's two items, the client's own value kept without the extra call, a link with no item level),
  `spec/refresh_pipeline_spec.lua` ("sorting by upgrade track": the bag in track order with the client answering 0).

## 5. A category's own order (issue #108)

Asked: "global order goes in the bag's layout/order section, but then each category can have it's own sort order".

### 5a. The sort (`sort:GetItemDataSortFunction`)

- **A category's items take its order** (`Categories:ItemOrderOf(name, kind)`, through `CategoryIn`: a group by's
  sections their category's; nothing for a Blizzard category, a category the bag does not use, or Recent Items, whose
  items take the bag's order). The others take the bag's.
- **One order over the whole list.** Comparing two items by the order of the first one's category would not be one order
  table.sort can use (an item of a category with its own order and two of others can each come before the next).
  So the items of a category with its own order are kept apart in the list: the bag's order's items first, then each
  such category's, by its name; within a group, its order. Whether an item's category has its own order is what tells
  the groups apart, never a name (a category may be named anything, `""` too). Sections take their category's items in
  the list's order (§3, Phase10), so where the groups fall in the list shows nowhere. `spec/sort_spec.lua` checks the
  comparison is a strict weak order over a mixed list and that 200 shuffles of it sort each category's items alike.
- **Each category's order is read once per sort**, the first time the comparison meets it (`own`, per sort function).
- **No category with its own order, no grouping** (`Categories:HasItemOrders(kind)`: any category used in the bag with
  `itemOrder`): the bag's order is the whole sort, `ItemDataComparator`'s, which reads no category per item. A spurious
  yes (a group by's section with an order of its own, which nothing sets) only takes the grouping path, which is as
  correct.
- **An open bag** is checked by the same comparison (§3): a pile that grew in a category ordered by Count is kept in
  place and the bag re-sorts on close (`spec/refresh_pipeline_spec.lua`, "a category's own item order").

### 5b. Saved

- `CustomCategoryFilter.itemOrder` (a list of keys; none: the bag's). `categories:UpdateCategory(ctx, name, { itemOrder
  = order })` keeps a copy; `false` takes it away. Either recalculates the bags with a fresh layout.
- **A plugin's category** keeps it in its saved state (`DB:UpdateEphemeralItemCategory`, `CreateOrUpdateCategory`,
  `saveState`), and it wins when the plugin makes the category again, as its color and automation do.
- **Shared** with the category (`sharedCategory`, import-export.md §7a), as its group by and color are: it is how the
  category shows. `ImportCategory` takes it (replacing, a string without one clears it).
- **`NormalizeCategories`** reads every category's (a plugin's saved state's too) with `itemOrderOf`, on every load and
  after a whole set is imported (§5d).

### 5c. The Item Order tab (`next/settings/categories.lua`, `next/settings/content.lua`)

On the Categories page, after Automation (next-settings-categories.md §5): one section, Order, of settings rows, as the
Automation tab's are: **Own Item Order** (on gives it the default order, Quality; off takes it away), then **Item
Order, Then By, And Then By**, the bag's three dropdowns' choices and saving (§1a) on the category's order
(`NextSettingsCategories:ItemOrderOptions`). The dropdowns are off while Own Item Order is, showing Quality, None, None,
the order it would start from. One interface for one action: the same three dropdowns choose a bag's order and a
category's (CLAUDE.md, UI Consistency).

### 5d. Reading an order from anywhere (`itemOrderOf`)

A pasted string's (one category's, or a whole set's) may hold anything: `itemOrderOf` keeps the keys BetterBags has
(`const.ITEM_ORDER_KEY`), each once, at most `ITEM_ORDER_DEPTH`, and nothing for a value that is not a list or has none
of them.

- **Left as is: a key this client does not offer.** Upgrade Track from a retail player's string, on a Classic client,
  is a key BetterBags has: kept, it orders nothing (no item there has a track), and its dropdown shows "Upgrade Track"
  with no choice checked until the player picks another. Not worth a check per client: the order still sorts.

## 6. Cost

Measured in desktop Lua 5.1.5 (`/tmp` benchmark, not committed): `table.sort` over 600 items with mixed qualities,
names, counts and six categories, 300 runs each, against the hand-written orders of b3d9e8c2:

| Order | Hand-written | Keys |
|---|---|---|
| Quality | 1.04-1.07 ms | 1.36-1.39 ms |
| Upgrade Track (with Item Level) | 1.18-1.22 ms | 1.42-1.47 ms |
| Sell Price (Stack) | 1.36-1.38 ms | 1.69-1.74 ms |
| three keys (Equipment Slot, Item Level, Quality) | - | 1.45-1.48 ms |
| Quality, two categories with their own Item Level | - | 1.41-1.48 ms |

About 0.3 ms more per fresh sort of 600 items, from the loop over the keys. The first version, with a helper call per
key and the category read per comparison for every bag, was 1.6-2.1 ms; inlining the comparisons and the fast path of §5a
took it to the above. Not measured in a capture from the game.

## 7. Bug review (#108)

No bug a player can hit. It fuzzed the grouped comparison over 5,000 random lists (free slots, gaps, items without
their data, Recent Items, ties, none to two categories with their own orders: `table.sort` never raised, each category in
its order), tried `WithItemOrderChoice` on every order of one to three keys at every tier with every choice listed
(23,790: never a duplicate, a hole, four keys or none), and caught 45 of 49 mutations. Fixed from it, each test seen
failing first:

- **The groups were told apart by name:** the bag's order's items were the group `""`, so a category named `""` with
  its own order shared it, and the comparison called the bag's `false` (`attempt to call local 'aOwn'`). Not seen (the
  dialogs refuse an empty name; a plugin would have to make one), but the fix is the plain form, not a guard: whether a
  category has its own order first, then the name (§5a).
- **Tests that asserted less than they could:** an item without its data through the grouped comparison (removing its
  `invalidData` check passed every spec), None at the first tier, and a tier below one the order has not got.

Seen in passing, as before this change: in Show Bags the Layout tab's dropdowns choose that view's order, which nothing
reads (Show Bags is slot order).

**Not verified in game:** the three dropdowns and the Item Order tab as drawn (the user: "i would need to see it in
game"), the orders at a real merchant, a merged stack's order, the equipment slots of real gear, and the re-sort on close.

Coverage: `spec/sort_spec.lua` (every key, an order of several keys, each old order's keys giving the order it gave,
free slots and gaps, an item without its data, an unknown key; a category's own order through `GetItemDataSortFunction`,
asked once per category, 200 shuffles, a strict weak order, an item without its data, a category named `""`; the fast
path; the keys a client offers, with and without
upgrade tracks; the tiers' choices and what each saves), `spec/database_spec.lua` (`GetItemOrder`/`SetItemOrder`, copies,
a plugin's saved order, export, `ReadImport` and `ApplyImport` reading orders), `spec/database_migration_spec.lua`
(`MigrateItemOrders`: every old order, the default, an order of keys kept, a copied profile; `NormalizeCategories`),
`spec/categories_spec.lua` (`UpdateCategory { itemOrder }`, a plugin's across its next creation and a move, `ItemOrderOf`,
`HasItemOrders`, a bag that does not use the category, `ImportCategory`), `spec/config/catalog_spec.lua` ("the item
order": three dropdowns per bag, their choices, what each saves, And Then By off, words, Upgrade Track where offered and
not), `spec/config/settings_effects_spec.lua` (each re-sorts the bags), `spec/next/settings/categories_spec.lua` ("the
Item Order settings"), `spec/next/settings/content_spec.lua` (the Layout tab's rows, the Item Order tab and its rows),
`spec/integration/next_settings_spec.lua` (every tab built on the whole addon), `spec/refresh_pipeline_spec.lua`
("sorting by sell price", "sorting by upgrade track", "a category's own item order": the real Items and Sort modules),
`spec/items_spec.lua` ("sell price (items:SellPriceOf)"), `spec/gap_reconciliation_spec.lua` ("items the item order now
puts the other way round"), `spec/automation_spec.lua` (Auto Sell's total through `SellPriceOf`).
