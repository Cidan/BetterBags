# Recent Items: Timer-Only Membership, Expiry When the Bag Closes

This defines when an item is in the Recent Items section, when it leaves, and why nothing
leaves the section while the bag is open.

## 1. Membership is the timer alone

`items:IsNewItem(data)` (`data/items.lua`, read by `GetCategory`) is true while the item's GUID
has an entry in `items._newItemTimers[kind]`. Nothing else decides it.

- **What starts a timer** (the current `time()`, only if the GUID has none):
  - the harvest, for an item the client flags new (`items:SeedNewItemTimer`, from `AttachItemInfo` and
    `ReuseHarvestedSlot`);
  - "All Items Recent" (`MarkAddedItemsRecent` → `MarkItemAsNew`), for an item whose GUID was not
    in the previous sweep (data-loader.md §12).
  - "All Items Recent", for a stack that kept its GUID but grew, when its item's total count in
    the kind grew too (a vendor purchase onto a partial stack). The client did not flag the stack
    a captured purchase grew (`C_NewItems.IsNewItem` false for its slot), while it flagged the item
    bought into an empty slot. Merging stacks by hand leaves the total unchanged, so it does not
    count.
- **The client's new-item flag only starts the timer and drives the glow**
  (`itemInfo.isNewItem` = `items:ClientNewItemFlag`, read by `frames/item.lua`). It must not decide the
  category: the client clears it on hover (`ContainerFrameItemButtonMixin:OnUpdate` calls
  `C_NewItems.RemoveNewItem`, `Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua`) and when
  Blizzard's own bag frames close (`CloseBag_Individual` → `UpdateNewItemList`). Those frames
  still open and close under BetterBags' hidden parent, because `ToggleAllBags` is only
  post-hooked.
- **No timer for an empty GUID.** `items:SeedNewItemTimer` and `MarkItemAsNew` skip `""`. A shared `""`
  key would make every GUID-less item recent, and expiring it would clear all their flags.
- **A virtual stack is recent while any pile it merges is** (`stackRecent`, set by Phase 7 on the
  stack's root, read by `GetCategory`; virtual-stacks.md §9). Its icon shows the largest pile, which
  looting changes, so going by that pile alone moved a stack between Recent Items and its category.
- **Starting or ending a timer changes no category by itself.** `MarkItemAsNew` and
  `ClearNewItemFromData` change the timer and the glow flag; the refresh that follows sees the item's
  recency change and works its category out again (data-loader.md §18). Both are only called by the
  pipeline, before Phases 6 and 8.

**Failure mode (fixed):** `IsNewItem` used to return true whenever the client flag was set, with
no time limit, and fell back to `time() - started < newItemTime` only once the flag was gone. An
item stayed in Recent Items indefinitely until the player hovered it. After that, it left on the
next refresh if it was older than the duration. At a vendor, every item the cursor passed over
jumped out of Recent Items at the next sale, while unhovered ones stayed. Which bag the item sat
in and the Combined Bags setting also changed when the flag was cleared.

## 2. Timers end only when the bag closes

`items:ExpireRecentItems(kind)` removes every timer of that kind at least
`database:GetNewItemTime()` seconds old (default 300, shown in minutes in the config) and returns
true when any expired. It also calls `C_NewItems.RemoveNewItem` for each expired item found in
the kind's committed `itemsBySlotKey`. Otherwise an item the client still flags would get a fresh
timer on the next harvest and come straight back.

There is no timer callback: expiry is a timestamp comparison made when the bag closes. An item
past its duration stays in Recent Items for as long as the bag stays open. An item looted while
the bag was closed is in Recent Items the next time the bag opens, however long ago that was, and
leaves on the following close once it is old enough.

## 3. The close hook (`frames/bag.lua`)

- `bagFrame:Create` calls `b:WatchForClose()`, which hooks the bag frame's own `OnHide`
  (`addon.HookScript`) to `bagProto:OnClosed`. The frame's `OnHide` fires on every way of closing
  the bag: the toggle and the close button (through `behavior:OnHide` → `Window:Hide`), ESC
  (`UISpecialFrames` hides the frame directly and never calls `behavior:OnHide`), and the end of
  the window's hide animation (window.md §4). Both bag kinds, every client.
- `bagProto:OnClosed` returns at once while `self.frame:IsShown()` is true. That case is `OnHide`
  firing because a parent hid (Alt+Z hides `UIParent`) while the bag is still open. Otherwise it
  calls `items:ExpireRecentItems(self.kind)`. If anything expired, or held gaps are waiting
  (`drawOnClose`, data-loader.md §13), it clears `drawOnClose` and calls `self:Refresh(ctx)` once.
- **One refresh, while hidden.** The refresh runs with the frame hidden, so `IsBagOpen` is false
  and `BuildOrderedItems` commits a fresh, gapless sort with the expired items in their normal
  categories. The next open shows the result; nothing moved on screen.
- **The on-close refresh moved here from `backpack.proto:OnHide`.** Leaving it there as well would
  sweep twice on a normal close. ESC used to skip it entirely, so held gaps also failed to
  collapse on an ESC close.
- **Bank:** the backpack's `OnRefresh` recalculates the backpack (`bags/Rederive { backpack }`, refresh-scheduler.md §10). The retail bank's `OnRefresh`
  does nothing, and the Classic/Era bank's request does not sweep once `addon.atBank` is false.
  The bank does not need it: every bank open sweeps with `resetLayout` (`BANKFRAME_OPENED`), which
  re-resolves categories after the expiry that ran when the bank closed.

## 4. Other ways an item leaves Recent Items (unchanged)

- **Sort:** `items:ClearNewItems(kind)` wipes the kind's timers and client flags, and the sort's
  sweep rebuilds the layout (refresh-scheduler.md §6).
- **Move:** an item whose GUID leaves one slot and appears in another in the same sweep is a
  move, not loot. `Phase4_ClearMovedItemGlows` clears its recency through `ClearNewItemFromData`
  (data-loader.md §11). This happens in the sweep that sees the move, including while the bag is
  open.

## 5. Coverage

- `spec/items_spec.lua` ("Recent Items timer rule"): recent past the duration until close; the
  client flag alone is not recent; no timer for an empty GUID; expiry boundary (exactly the
  duration expires); expiry clears the expired item's client flag only; per-kind scoping.
- `spec/refresh_pipeline_spec.lua` ("Recent Items (timer only, expires when the bag closes)"):
  hovered and past its duration, the item stays while open across a sale's sweep; an expired
  item leaves on the sweep after close, stops glowing, and does not come back while still flagged;
  a flagged item without a GUID gets no timer; an unexpired item survives a close.
- `spec/frames/bag_draw_ownership_spec.lua` ("closing the bag (OnClosed)"): one refresh when
  something expired, when gaps are held, or both; none when neither; nothing while the frame is
  still shown; the bank kind; `WatchForClose` wiring through `OnHide`; `Create` calls it.
- `spec/bags/backpack_spec.lua` ("does not refresh from its own OnHide, with or without fading").
- `spec/refresh_pipeline_spec.lua` ("virtual stacks and Recent Items": a stack looted into stays in
  Recent Items whichever pile is largest, including a recent partial pile filling and merging, in a
  slot before or after the old one; it goes back once no pile is recent; the same however the piles
  are read. "deriving only what changed": an own category that follows recency; a pile's own
  category once stacking stops merging it).

Every guard in this file was mutation-tested: removing any one fails at least one of these tests.
