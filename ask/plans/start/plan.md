# Implementation Plan: Decoupling Data Sweep from Bag View State

## Overview
The goal is to modify the data sweep pipeline (`data/items.lua`) so it no longer mutates `itemInfo.category` based on the UI state (`database.GetBagView()`). Instead, it should collect all data and generate two distinct pre-computed layouts inside `slotInfo.layouts`: one for the category view and one for the bag view.

## 1. Modify `data/items.lua`
- Remove all instances of `database.GetBagView` polling during `items:ProcessRefresh(ctx, kind)`. The data layer should not care what view the UI is currently displaying.
- During item data population (or in `AttachBasicItemInfo`), populate `currentItem.itemInfo.physicalBagName = self:GetBagName(currentItem.bagid)` for all items.
- Structure `slotInfo` to contain two pre-computed layout models:
  ```lua
  slotInfo.layouts = {
    categoryView = {},
    bagView = {}
  }
  ```
- **Category View (`layouts.categoryView`)**:
  - Group items by `itemInfo.category`.
  - Sort items using standard user preferences (quality, ilvl, name, etc.).
  - Partition items into tabs (Bank Tab 1, Bank Tab 2, etc.) as normal.
- **Bag View (`layouts.bagView`)**:
  - Group items strictly by `itemInfo.physicalBagName`.
  - Sort items strictly by physical location (`bagid` then `slotid`), bypassing standard sorting rules.
  - Apply `{ hideHeader = true, sortMode = "physical" }` metadata to `sectionLayouts` so the view knows to hide headers.
  - Include empty slot dummy items correctly attributed to their physical bags.

## 2. Update Bag UI Layer (`frames/bag.lua` and related context menus)
- **`bagProto:Draw(ctx, slotInfo, callback)`**:
  - Determine the active layout using `database:GetBagView`:
    ```lua
    local layoutKey = database:GetBagView(self.kind) == const.BAG_VIEW.SECTION_ALL_BAGS and "bagView" or "categoryView"
    local activeSlotInfo = slotInfo.layouts and slotInfo.layouts[layoutKey] or slotInfo
    ```
  - Pass `activeSlotInfo` to `DrawGlobalSections` and `view:Render`.
- **Context Menus (`frames/contextmenu.lua` and `themes/*.lua`)**:
  - Currently, clicking "Show Bags" or "Show Categories" might trigger a full database refresh.
  - Refactor this to perform an instant visual swap. Set `ctx:Set("tab_switch", true)`, invoke `database:SetBagView`, and call `bag:Draw(ctx, bag.lastSlotInfo)` without sending `bags/FullRefreshAll`.

## 3. Testing
- **`spec/items_spec.lua`**:
  - Remove tests that assert `itemInfo.category` is mutated when `database:GetBagView` returns `SECTION_ALL_BAGS`.
  - Add tests validating that both `slotInfo.layouts.categoryView` and `slotInfo.layouts.bagView` are generated and structured correctly, independent of UI state.
- **`spec/debug_dump_harness_spec.lua`**:
  - Use the integration testing harness (with item dumps) to test full pipeline execution.
  - Validate that `items:ProcessRefresh` produces correctly partitioned `bagView` and `categoryView` layouts for real-world user dataset dumps in both the Backpack and Bank.

## Risks & Edge Cases
- **Compatibility**: The dual-layout structure could affect other views or listeners expecting `slotInfo.tabs` at the root. We must ensure `activeSlotInfo` seamlessly provides all the necessary fields (`tabs`, `sortedItems`, `sectionLayouts`, etc.).
- **Global Context Variables**: `DrawGlobalSections` uses `emptySlotsSorted` and `freeSlotKeysByBag`. Make sure these global-scope data structures are correctly mapped into the chosen layout or properly accessed from the root `slotInfo`.