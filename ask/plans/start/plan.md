# Implementation Plan: Pure Presentation Refactor (Items 1, 2, and 4)

## Overview
This plan outlines the refactoring of the item drawing phase to strictly enforce the "Zero On-the-Fly Database Queries" rule. All required data will be pre-computed during Phase 2 (Data Farming), and pure presentation functions will have their legacy `GetItemData` fallbacks removed.

## 1. `UpdateNewItem` & `IsBattlePayItem` (Retail)
**Files to change:** `data/items.lua`, `data/items_new.lua`, `frames/item.lua`

**Approach:**
- **Phase 2 Pre-computation:** Inside `Harvest` or `GetItemDataFromInventorySlot`, safely calculate `isBattlePayItem` using `_G.C_Container.IsBattlePayItem(bagid, slotid)` (with a `nil` check for Era compatibility) and assign it to `ItemData.itemInfo.isBattlePayItem`.
- **New Item Pre-computation:** Ensure `ItemData.itemInfo.isNewItem` accurately captures the new item status using the existing `items:IsNewItem(data)` logic during data harvesting, instead of during the draw phase.
- **Draw Phase Simplification:** In `frames/item.lua`, update `UpdateNewItem(ctx, data)` to strictly use `data.itemInfo.isNewItem` and `data.itemInfo.isBattlePayItem`. Remove all native API queries.

## 2. Free Space / Empty Slot Bag Types
**Files to change:** `data/items.lua`, `data/items_new.lua`, `frames/item.lua`, `frames/era/item.lua`

**Approach:**
- **Phase 2 Pre-computation:** When creating an `ItemData` node for an empty slot (`isItemEmpty == true`), use the existing `items:GetBagTypeFromBagID(bagid)` logic to compute the bag's type name and quality. Store these as `data.itemInfo.emptySlotName` and `data.itemInfo.itemQuality`.
- **Draw Phase Simplification:** Update `itemProto:SetFreeSlots(ctx, data)` in both Retail and Era item frames to read these pre-computed values directly from `data`.
- **Cleanup:** Remove `GetBagType` and `GetBagTypeQuality` helper methods from the `itemProto`.

## 4. Legacy `GetItemData` Fallbacks and Helpers
**Files to change:** `frames/item.lua`, `frames/era/item.lua`, `frames/itemrow.lua`

**Approach:**
- **Remove Fallbacks:** In all drawing functions within `frames/item.lua` and `frames/era/item.lua` (e.g., `UpdateCount`, `DrawItemLevel`, `UpdateUpgrade`, `UpdateCooldown`, `SetFreeSlots`, `UpdateNewItem`), remove the fallback line `data = data or self:GetItemData()`. Enforce that `data` is explicitly passed in from the upstream refresh pipeline.
- **Refactor `itemRowProto:SetItem`:** Update `itemRowProto:SetItem(slotkey)` in `frames/itemrow.lua` to accept the `data` parameter instead of performing a live database query (`items:GetItemDataFromSlotKey(slotkey)`). Ensure the caller passes `data`.
- **Refactor `itemFrame:RefreshItemLevelColors()`:** Modify the function so that instead of querying `items:GetItemDataFromSlotKey` for every visible frame, it relies on cached frame data or triggers a standard pipeline redraw.
- **Refactor `IsNewItem(ctx)` Helper:** Remove the `itemFrame.itemProto:IsNewItem(ctx)` function that queries `GetItemDataFromSlotKey`, replacing its usage with direct checks against the passed `data` object.

## Risks & Edge Cases
- **Missing Data Passed to Drawings:** Removing `data = data or self:GetItemData()` will cause Lua errors if any upstream caller or external plugin invokes drawing functions without passing `data`. A thorough search for callers of these functions is required.
- **Test Invalidation:** Existing `item_spec.lua` tests may currently rely on `itemProto` fetching its own data. Tests will need to be updated to explicitly pass the mocked `ItemData`.
- **Classic/Era Parity:** `C_NewItems` and `C_Container.IsBattlePayItem` do not exist in Classic/Era. Conditional checks must be strictly applied in Phase 2 during data harvesting to avoid script errors.