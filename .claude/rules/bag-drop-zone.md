# The Bag Window as a Drop Target (issue #408)

An item dropped anywhere on a bag window, or the window left-clicked while holding one, goes
into a free slot of that window's bags. Before this only a Free Space slot accepted a drop, so
unequipping gear by dragging it from the character panel onto the bag only worked when it
landed exactly on that slot.

## 1. Where drops are caught

`bagProto:WatchMouse()` (`frames/bag.lua`, called from `bagFrame:Create` for both bag kinds) sets
the window frame's mouse scripts:

- `OnReceiveDrag` and `OnMouseUp` with the left button call `bag:PlaceCursorItem()`, which hands
  the window's kind and active bank tab (`bag.bankTab`) to `CursorPlacement:PlaceCursorItem`.
- `OnDragStart` moves the window only when nothing is on the cursor. With an item held, pressing
  on the window is a drop. `OnDragStop` saves the position only after a move started
  (`bag.movingWindow`).

The window frame is the only mouse-enabled frame under the bag's backgrounds: section frames,
grids and scroll boxes do not take the mouse (`ScrollBoxBaseTemplate` sets no mouse), so a drop
on a background, a gap or the empty part of a section reaches it. Frames above it keep their
own drops: item buttons (place or swap with that slot), the bag button (create a category), the
bag slots. A section title with Shift adds the item to that category; without Shift the title
passes the drop to its window (`sectionFrame:OnTitleClickOrDrop`, through
`addon:GetBagFromKind(section:GetKind())`).

BetterBags Next's sections have a header button over their title row (next.md §7). It takes the
item drops the classic section title takes: an item dropped or left-clicked onto it goes to its
panel (`PlaceCursorItem`), or with Shift into its category, through the same
`sectionFrame:OnTitleClickOrDrop`.

## 2. What happens to the item (`util/cursorplacement.lua`)

`CursorPlacement:PlaceCursorItem(kind, bankTab)` returns what it did, so a profiler trace shows
it: `"placed"`, `"returned"`, `"full"` or `"ignored"`.

- Only an item (`GetCursorInfo()` type `"item"`). Merchant items (buying by drag), money and
  anything else are ignored: buying needs Blizzard's purchase confirmations.
- An item picked up from this window (`C_Cursor.GetCursorItem()` is a slot of one of its bags;
  the bank window counts both bank types) goes back to its slot (`ClearCursor`).
- A refundable item (`C_Item.CanBeRefunded`) is ignored when the bank shows the Warbank:
  Blizzard's bank asks before that deposit, which loses the refund
  (`BankPanelItemButtonMixin:HandleItemPickup`). Taking items out of the Warbank needs no
  confirmation for an empty target slot (`ContainerFrameItemButton_OnClick` only asks when the
  target holds a refundable item; `ItemLocationMixin:IsValid` is `C_Item.DoesItemExist`).
- Target bags (`TargetBags`): the backpack window's `const.BACKPACK_BAGS`; the bank window's
  `const.ACCOUNT_BANK_BAGS` while its active tab is a Warbank tab (`ShowsWarbank`), else
  `const.BANK_BAGS`. Ascending bag ID, with the bank's active tab first (the tab selected under
  Show Bags).
- Slot (`FindFreeSlot`), read from the client at the drop (`C_Container.GetContainerFreeSlots`),
  never from committed data: picking up onto an occupied slot would swap and put the other item
  on the cursor.
  1. The first bag made for the item: a profession bag of one of its families
     (`bit.band(C_Item.GetItemFamily(item), bagFamily) ~= 0`, family from
     `C_Container.GetContainerNumFreeSlots`), the retail reagent bag for a crafting reagent (it
     reports family 0; `const.BACKPACK_ONLY_REAGENT_BAGS` and `GetItemInfo`'s
     `isCraftingReagent`), the keyring for a key on Classic Era and WoW: Forever (family 256 when the
     client reports 0; the Forever keyring is a backpack bag, camelot-forever.md §7).
  2. Else the first bag that holds anything (family 0), in order: backpack first, the order
     Blizzard's `EquipmentManager_PutItemInInventory` uses for unequipped gear.
  - A specialized bag the item does not fit is never used. A bag or quiver item reports the
    family it holds (warcraft.wiki.gg `C_Item.GetItemFamily`), so it only goes in a bag that
    holds anything.
- No room: `UIErrorsFrame:AddMessage(ERR_INV_FULL)` (`ERR_BANK_FULL` for the bank) and the item
  stays on the cursor.
- Placement is `C_Container.PickupContainerItem(bag, slot)`, the call a drop on that slot makes.
  Not `PutItemInBag(invSlot)`: with a bag on the cursor it equips the bag into that bag slot.

## 3. Taint

The drop never taints anything:

- `C_Container.PickupContainerItem` is not protected. warcraft.wiki.gg lists it in the Cursor
  API with no restriction tag (it tags `C_Container.UseContainerItem` "#protected"), and
  `ContainerDocumentation.lua` marks neither; BetterBags has called it from its own code since
  v0.5.13 (`frames/bankslots.lua`, WoW: Forever bank sockets). Every other call is a plain read.
- The scripts are on BetterBags' own frame, and the drop writes nothing Blizzard's code reads.
- It never forwards to the slot button's `OnClick` (AdiBags' approach): Blizzard's
  `ContainerFrameItemButton_OnClick` would run from our call and reach the protected
  `UseContainerItem` while a spell waits for an item target, and write `MerchantFrame` state.
  It never shows a Blizzard `StaticPopup` either (see the Warbank rule above).

Not verified in game. To check: `/console taintLog 1`, drag gear onto the backpack, drop items at
the bank, then use a consumable from the bag in and out of combat; `Logs/taint.log` should have no
BetterBags entries.

## 4. Coverage

`spec/cursorplacement_spec.lua`: free slot, next bag, live reads, family bags (multi-family
items), specialized bags never misused, reagent bag both ways, bag items, keyring, same-window
return (backpack and both bank types), Warbank withdrawal, no location, non-items, Warbank /
character bank / active tab targets, refundable items, full messages, Classic bank order.
`spec/frames/bag_draw_ownership_spec.lua` ("the window as a drop target (WatchMouse)"): drop and
left-click wiring with the bank tab, no move with an item held, moves and saves without one,
`Create` calls `WatchMouse`, section titles with and without Shift. Every guard was
mutation-tested (13 mutations, each failing at least one test).
