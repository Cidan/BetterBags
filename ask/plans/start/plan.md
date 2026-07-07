# Implementation Plan: Pre-Sorted Data Architecture & Physical Slot Ordering

## Overview
The goal is to shift all item sorting logic entirely out of the UI rendering layers (`views/bagview_new.lua` and `views/gridview_new.lua`) and into the data enrichment phase (`data/items_new.lua`). A single, perfectly sorted array of real items and "dummy" empty slots will be synthesized, allowing the view layer to iterate over it sequentially and build sections without calling any sorting algorithms. Additionally, this fixes the issue where the Backpack did not properly sort by physical slot in Blizzard Bag mode (`SECTION_ALL_BAGS`).

This implementation will be applied directly to the current branch (`refactor/data-driven-show-bags-layout`).

## 1. Refactor Sorting Logic for Data (`util/sort.lua`)
The existing sort functions expect `Item` UI frame instances. We need pure data equivalents.
- **Action**: Create an `invalidItemData(aData, bData)` helper parallel to the existing `invalidData` function.
- **Action**: Implement new sort functions that accept `ItemData` tables:
  - `SortItemDataByQualityThenAlpha(aData, bData)`
  - `SortItemDataByAlphaThenQuality(aData, bData)`
  - `SortItemDataByItemLevel(aData, bData)`
  - `SortItemDataByExpansion(aData, bData)`
- **Action**: Implement `SortItemDataBySlot(aData, bData)` for physical sorting.
  - **Logic**: Compare `aData.bagid` and `bData.bagid`. If they differ, return `aData.bagid < bData.bagid`. Otherwise, return `aData.slotid < bData.slotid`.
- **Action**: Expose `sort:GetItemDataSortFunction(kind, view)` which reads `database:GetItemSortType(kind, view)` and returns the appropriate data-layer sort function.

## 2. Synthesize and Pre-Sort in the Data Phase (`data/items_new.lua`)
Synthesize a single `sortedItems` array containing everything the view needs to render, fully ordered.
- **Action**: In `items:ProcessRefresh(ctx, kind)` (Phase 4.5), right before `events:SendMessage(ctx, ev, slotInfo)`:
  - Initialize `slotInfo.sortedItems = {}`.
  - Iterate `slotInfo.visibleItemsBySlotKey` and insert all real `ItemData` objects into `sortedItems`.
  - Iterate `slotInfo.emptySlotByBagAndSlot` and create dummy `ItemData` objects for every empty slot.
    - **Dummy Object Shape**: `{ isFreeSlot = true, bagid = bagid, slotid = slotid, itemInfo = { category = category, itemName = "", itemQuality = 0, currentItemCount = 1, itemGUID = "" } }`. This ensures they do not cause nil errors in sorting functions.
    - Insert these dummy objects into `sortedItems`.
  - **Sort Resolution**:
    - If `database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS`, force the sort function to `sort.SortItemDataBySlot`.
    - Otherwise, fetch the user's preferred sort function via `sort:GetItemDataSortFunction(kind, view)`.
  - Execute `table.sort(slotInfo.sortedItems, selectedSortFunction)`.

## 3. Make the View Layer 100% "Dumb" (`views/bagview_new.lua` & `views/gridview_new.lua`)
Refactor the view layer to consume `sortedItems` iteratively, dropping all internal UI sorting logic.
- **Action**: Remove the separate iteration loops for `itemsGetter(slotInfo)` and `slotInfo.emptySlotByBagAndSlot`.
- **Action**: Implement a single master loop: `for _, itemData in ipairs(slotInfo.sortedItems) do`.
- **Action**: Inside the loop:
  - Check `itemData.isFreeSlot`.
    - If true: generate an empty slot button via `itemButton:SetFreeSlots(ctx, itemData.bagid, itemData.slotid, -1)`.
    - If false: generate a standard item button via `itemButton:SetItemFromData(ctx, itemData)`.
  - Append the `itemButton` to the section matching `itemData.itemInfo.category`.
- **Action**: **Delete all sorting calls**. Remove any `view.content:Sort()` and `section:Draw(..., nosort)` logic, as well as `section.content:Sort()` parameters from within the rendering passes. The items will naturally stack in the exact order they are encountered in `sortedItems`.

## 4. Risks and Edge Cases
- **Nil Reference in Dummy Objects**: Ensure all data-sort functions safely handle `isFreeSlot` exactly as the UI versions did (e.g., placing free slots at the end of the list where applicable).
- **Section Layout Preservation**: The logic mapping `hideHeader` in `slotInfo.sectionLayouts` to specific bags (e.g., hiding for Bank but not Backpack) must remain intact and must apply equally to sections containing dummy empty slots.

## 5. Finalizing
- Update and run `luacheck` to catch any undefined variables or syntactical issues before committing.
- Commit the changes to the active branch (`refactor/data-driven-show-bags-layout`) to update PR 1028.