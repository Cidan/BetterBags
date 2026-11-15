---
paths:
  - "util/sort.lua"
  - "data/items.lua"
  - "config/catalog.lua"
  - "spec/sort_spec.lua"
  - "spec/items_spec.lua"
  - "spec/config/catalog_spec.lua"
  - "spec/gap_reconciliation_spec.lua"
  - "spec/refresh_pipeline_spec.lua"
---
# Item Orders (`util/sort.lua`, the Item Order setting)

The order of items within each section of a bag. Each bag kind and view keeps its own
(`DB:GetItemSortType(kind, view)`, `DB.data.profile.itemSort[kind][view]`, default Quality), chosen in the
settings catalog's `itemOrder` dropdown (`config/catalog.lua`), which both settings windows show (BetterBags
Next: a bag's Layout tab, Order).

## 1. The orders

| Item Order | `const.ITEM_SORT_TYPE` | Order |
|---|---|---|
| Alphabetically | `ALPHABETICALLY_THEN_QUALITY` (1) | name, quality, count, GUID |
| Quality | `QUALITY_THEN_ALPHABETICALLY` (2) | quality, name, count, GUID |
| Item Level | `ITEM_LEVEL` (3) | current item level, name, count, GUID |
| Expansion | `EXPANSION` (4) | expansion (oldest first), name, count, GUID |
| Sell Price (Stack) | `SELL_PRICE_STACK` (5) | what the stack the button shows sells for, name, count, GUID |
| Sell Price (Each) | `SELL_PRICE_EACH` (6) | what one sells for, name, count, GUID |
| Upgrade Track | `UPGRADE_TRACK` (7) | upgrade track (highest first), current item level, name, count, GUID (§4) |

The dropdown lists them in the order Alphabetically, Quality, Item Level, Upgrade Track, Expansion, Sell Price
(Stack), Sell Price (Each); the constants keep the numbers saved profiles hold.

- **Two forms of each order.** `SortItemDataBy*` compares two `ItemData` and is what the bags use: the data
  pipeline sorts with `sort:GetItemDataSortFunction(kind, view)` (`items:Phase9_Sort`, and the new items
  `items:BuildOrderedItems` appends, data-loader.md §13). `SortItemsBy*` compares two item buttons
  (`item:GetItemData()`), returned by `sort:GetItemSortFunction`, which nothing in the addon calls today; it is
  kept in step so it never asserts on an order it does not know.
- **Common to all:** free slots and gaps go last; two items either of which lacks its data (`invalidData`:
  no quality, count, GUID or name) are left unordered; "count" in a tie is the item's own pile
  (`currentItemCount`), never a virtual stack's total; the GUID makes the order total.
- **An unknown order asserts** (`"Unknown sort type: "`), in both `Get*SortFunction`s. A new order needs its
  constant, both forms, both dispatches and its dropdown entry, together.
- Show Bags (`SECTION_ALL_BAGS`) ignores the item order: it is always slot order (`SortItemDataBySlot`,
  keyring.md).

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
  `data.stackedCount or itemInfo.currentItemCount`: a merged virtual stack's total (set by
  `Phase7_ApplyVirtualStacks`, which runs before the sort), else the pile's own count, as the button draws it
  (`frames/item.lua`, `SetItemButtonCount`).
- **Each:** the price of one, whatever the count.
- **An item read cold** has no traits, so it sorts by its base item's price (0 when that has not loaded
  either) until its data loads. Once it has, closing the bag puts it in order: its rehash marks the bag
  (data-loader.md §13), and so does a price that put it out of order without one (§3).
- **Labels are not translated**, as Quality's is not: the catalog's items are English strings.

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
  `panelProto:OnClosed`, with the frame hidden).
  - **One category, because a section is one:** `Phase10_PartitionIntoTabs` gives each tab's sections their
    category's items in the list's order, and the item orders ignore the category. Comparing across categories
    marked a bag whose every section was in order: in the second review's 1,800 random sweeps, 375 of the 1,426
    marked (26%), above all a looted item in Recent Items against the last item of another section. A category
    can span tabs (the bank's), which only compares more items than a section holds, never fewer, so it misses
    nothing: a list holding a section's items in order holds them in order too.
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
  order's tie-break, a cold item's name or price once read), and so does a new item the order puts before the
  items of its section above it. Two piles of one item can then swap places on the next open, and a close after
  looting can refresh once.
- **It does not loop.** The refresh on close is queued without `resetLayout`. When it runs with the bag closed
  it is a fresh sort, which never marks; when the player reopens the bag first, it keeps every item in place and
  marks the bag again, and the next close re-sorts it. Nothing moves while the bag is shown.
- **Bug reviews:** the first version ran the check before the new items were appended, so an item looted out
  of order was put in place on close only if another sweep ran while the bag was open; it runs after them since.
  The second found the cross-category marks above.
- **Left as is: an item without its data hides an inversion across it.** The comparators leave such an item
  unordered with every other (`invalidData`), so `OutOfOrder` does not see past it (`{cheap, bad, dear}` gives
  nil). Not seen: the harvest fills in an empty name and GUID and a quality, so a real item does not get there.
- **Cost:** one comparator call per item in each sweep while the bag is open (the second review: 0.13-0.22 ms for
  600 items in desktop Lua 5.1, against 1.1-1.8 ms for the fresh sort), and the refresh on close it adds. Not
  measured in a capture from the game.
- Asked: "go ahead and do as you will here, we'll test in game".

**Not verified in game:** the orders at a real merchant, a merged stack's order, and the re-sort on close.

Coverage: `spec/sort_spec.lua` ("by sell price": both orders, both forms, the dispatch, ties, unsellable items,
free slots and gaps, a merged stack's total, `table.sort` over a list), `spec/items_spec.lua` ("sell price
(items:SellPriceOf)"), `spec/config/catalog_spec.lua` ("offers the item orders"), `spec/gap_reconciliation_spec.lua`
("items the item order now puts the other way round"), `spec/refresh_pipeline_spec.lua` ("sorting by sell
price": the real Items and Sort modules, a merged stack, an item no merchant buys, an unchanged open sweep, a
grown stack, an item looted while the bag is open, and Quality's count tie-break, each kept in place while open
and in order once closed), and `spec/automation_spec.lua` (Auto Sell's total through `SellPriceOf`).
Mutation-tested (15 mutations, each caught: the button's count, the order's direction, the name tie-break, the
dispatch, the re-sort mark, gaps in the check, the check before the new items, the neighbour comparison reversed,
equal neighbours as out of order, the category ignored, each item against its category's first, `hasNoValue`,
the link's price, Auto Sell's total, the dropdown's order).

## 4. Upgrade Track (issue #769)

Asked: arrange gear "according to their upgrade level (i.e mythic, hero, champion) instead of current item level".
Item Level mixes the tracks, because they overlap: each track's lowest ranks sit below the highest ranks of the track
under it (a Veteran 6/6 sorts above a Champion 1/6). Upgrade Track keeps each track together, the highest first, and within a
track puts the most upgraded (the highest current item level) first. The user decided against a Group By Track for
search categories in the same change; a category of one track is a search category (`track = hero`, README).

- **A track's rank is the item level it upgrades to** (`trackTop` in `util/sort.lua`): the item's
  `itemInfo.traits.upgradeMaxItemLevel`, from `C_Item.GetItemUpgradeInfo(link).maxItemLevel`
  (`items:ReadItemTraits`, search-indexing.md §10). Within a season every track tops out at its own item level,
  higher for a higher track. The track's name (`trackString`) cannot rank it: it is in the game's language.
  `trackStringID` was not used either: one value has been seen (Adventurer, 971, `spec/fixtures/dump_retail_12_1_5.lua`),
  so nothing says its IDs follow the tracks' order.
- **No track is rank 0, after every track:** gear `ReadItemTraits` does not put on a track (a track string with no
  levels, as last season's gear reads: 0/0 and maximum item level 0 in the 12.1.5 dump), everything that is not gear,
  and an item read cold (no traits yet). Among those the order is Item Level's: current item level, name, count,
  GUID. So a section with no gear in it sorts as under Item Level.
- **Once a cold item's data loads**, it gets its traits and its rank in place; with the bag open it is kept where it
  was and the bag is marked, and closing it puts it in order (§3). So does an item upgraded at the upgrade vendor
  while the bag is open (a new link and item level). Choosing the order re-sorts the bags at once. The bug review
  checked each through the real Items and Sort modules.
- **Offered where the client reads tracks:** the catalog decides when it loads, by the check `ReadItemTraits` makes
  (`C_Item.GetItemUpgradeInfo` exists: retail and WoW: Forever; not Classic Era, Anniversary, Mists or Titan, by the
  UI source's branches). There the dropdown lists Upgrade Track after Item Level, its description says what it does,
  and its keywords (`upgrade track`, `track`, `myth`, `hero`, `champion`) find it; elsewhere none of the three
  mention it (no item has a track there, so the order would be Item Level's under another name). A client's APIs do
  not change while it runs, so the setting keeps a plain `items` list.
  - **Left as is:** a saved order 7 on a client without the API would show "Upgrade Track" with no choice checked in
    the menu (and still sort, as Item Level). Not reachable: saved variables are per client, and nothing there can
    choose it.
- **Not verified in game, by the user's decision** ("no need for a capture"): no capture has held gear with upgrade
  levels (docs/vendor-compat.md, "Needs an in-game check"), so neither the `maxItemLevel` the client reports for each
  track nor the gap Vendor patches after the Midnight item level squish (a `maxItemLevel` more than 26 above the item
  level, docs/vendor-compat.md) has been seen. The order holds as long as a higher track reports a higher
  `maxItemLevel` than a lower one in the same bag.
- **Bug review:** it found no bug in the order, the dispatch or the re-sort on close. It found the description and
  keywords naming Upgrade Track where the dropdown did not offer it (the choice was then read each time the menu
  opened), and a gap test that passed with the gap check removed (its gap had no item data, so `invalidData` left it
  unordered either way); both fixed. The catalog now decides once, and the test's gap is a copy of an item, as
  `CloneAsGap` makes one.

Coverage: `spec/sort_spec.lua` ("by upgrade track": a higher track above a lower one at a higher item level, item
level within a track, the tracks ranked by their top over a whole list, no track and cold items last, ties, free slots
and gaps, an item without its data, the button form, the dispatch), `spec/config/catalog_spec.lua` ("offers Upgrade
Track where the client has upgrade tracks, and saves it"; "neither lists nor names Upgrade Track where the client has
no upgrade tracks", a fresh catalog loaded without the API), `spec/refresh_pipeline_spec.lua` ("sorting by upgrade
track": the traits read from the link through the real Items and Sort modules, against the same bag under Item
Level). Mutation-tested by the review: 22 of 25 caught; the gap check (since fixed), one equivalent mutation, and
dropping a track string with no levels (caught by `spec/items_spec.lua`, "item traits").
