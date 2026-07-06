# Implementation Plan

This plan details the exact steps to fix the three post-architecture-refactor bugs relating to scrolling, Warbank free space counts, and Blizzard Bank tabs rendering. 

## 1. Bug 1: Scroll clipping off-screen

**Root Cause:**
Blizzard's `WowScrollBox` with a `LinearView` checks for children with `scrollable = true` during its initialization phase to calculate the pan extent. Currently, `scrollChild.scrollable = true` is set *after* `ScrollUtil.InitScrollBoxWithScrollBar` is invoked, meaning the box initializes with an assumed scroll range of 0.

**Implementation Steps:**
- **File:** `frames/bag.lua`
- **Location:** `bagFrame.bagProto:Create` (around lines 777-780).
- **Action:** Move the `scrollChild.scrollable = true` and `scrollChild:SetParent(scrollBox)` assignments to be physically located *before* the `ScrollUtil.InitScrollBoxWithScrollBar(scrollBox, scrollBar, scrollView)` call.

## 2. Bug 2: Warbank free space shows total Bank free space

**Root Cause:**
Currently, `items:UpdateFreeSlots` aggregates the `emptySlots` counts strictly by the Blizzard subclass string (e.g., `"Bag"`). Since both Character Bank bags and Warbank bags share the `"Bag"` subclass string, their counts are unconditionally merged. When the UI renders the global footer, it displays the combined integer across all tabs.

**Implementation Steps:**
- **File:** `data/slots.lua`
  - In `SlotInfo:Wipe` and `SlotInfo:Update`, reset `self.freeSlotKeysByBag = {}`.
  - In `SlotInfo:StoreIfEmptySlot`, safely populate `self.freeSlotKeysByBag = self.freeSlotKeysByBag or {}` and `self.freeSlotKeysByBag[item.bagid] = item.slotkey`.
- **File:** `data/items_new.lua` and `data/items.lua`
  - In `UpdateFreeSlots`, preserve the existing `emptySlots` behavior but also populate a new mapping: `self.slotInfo[kind].emptySlotsByBag = self.slotInfo[kind].emptySlotsByBag or {}` and `self.slotInfo[kind].emptySlotsByBag[bagid] = { name = name, count = freeSlots }`.
- **File:** `frames/bag.lua`
  - Import the Groups module at the top: `local groups = addon:GetModule("Groups")`.
  - In `bagProto:DrawGlobalSections`, introduce a helper function `IncludeBagInFreeSpace(bagid)` that checks if a `bagid` belongs to `self:GetCurrentTabID()` (using similar retail/account bank boolean logic as `ItemBelongsToTab`).
  - Update the `database:GetShowAllFreeSpace` `true` path to skip items in `slotInfo.emptySlotsSorted` where `IncludeBagInFreeSpace(item.bagid)` is false.
  - Update the `false` path to iterate over `slotInfo.emptySlotsByBag`, filtering via `IncludeBagInFreeSpace`, and dynamically aggregating the `freeSlotCount` sum per `name` to render the correct contextual counts on-the-fly.

## 3. Bug 3: Blizzard Bank Tabs are totally busted (Rendering multiple tabs at once)

**Root Cause:**
In PR 1024, the cache was updated to always contain ALL bank items (Character + Warbank) simultaneously to allow instant tab-swapping. However, `ItemBelongsToTab` still features a legacy catch-all `if view.bagview == const.BAG_VIEW.SECTION_ALL_BAGS then return true end` block. When switching to a specific Warbank tab in Blizzard Bag View, this causes the grid to render the Character bank, Warbank tab 1, Warbank tab 2, etc., all on top of each other.

**Implementation Steps:**
- **Files:** `views/gridview_new.lua` and `views/bagview_new.lua`
- **Location:** `ItemBelongsToTab` function.
- **Action:** Update the `SECTION_ALL_BAGS` escape block to restrict retail bank items mathematically to the viewed bank type.
  ```lua
  if view.bagview == const.BAG_VIEW.SECTION_ALL_BAGS then
    if bagKind == const.BAG_KIND.BANK and addon.isRetail then
      if view.tabID == const.BANK_TAB.BANK then
         -- Character Bank: Show everything that isn't Account Bank
         return const.ACCOUNT_BANK_BAGS == nil or const.ACCOUNT_BANK_BAGS[item.bagid] == nil
      else
         -- Warbank Tabs: Only show the exact bag representing that specific tab
         return item.bagid == view.tabID
      end
    end
    return true
  end
  ```

This exact sequence will be implemented and validated across all views natively.