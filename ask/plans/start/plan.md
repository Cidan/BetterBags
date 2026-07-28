# Functional Pipeline Refactor Plan

## Objective
Convert `items:ProcessRefresh` into a truly pure functional pipeline by removing the `_tempSlotInfo` hack and passing explicit data structures between phases. This eliminates side effects and makes the data refresh process entirely stateless until the final commit phase.

## Approach
1. **Remove `tempSlotInfo` from the Pipeline**
   - Delete `local tempSlotInfo = self:NewSlotInfo()` and the registration `self._tempSlotInfo[kind] = tempSlotInfo`.
   - Update `items:GetItemDataFromSlotKey` to only read from `self.slotInfo[kind]` (removing the fallback to `_tempSlotInfo`).

2. **Pass Explicit Data Instead of Using Getters**
   - Identify helper functions called during the refresh pipeline that currently rely on `self:GetItemDataFromSlotKey` to fetch newly harvested items (e.g., `RefreshSearchCache`).
   - Update these helpers to accept the explicit `itemData` map being passed down the pipeline:
     - `items:RefreshSearchCache(kind, itemData)`
     - Phase 5 `EnrichCategories` will pass `itemData` to `RefreshSearchCache`.

3. **Refactor Phase Signatures**
   - `Phase2b_EnrichData(ctx, kind, itemData)`: Instead of mutating `tempSlotInfo`, instantiate a local temporary struct (or separate tables) for empty slots and item counts, and return them.
     - Returns: `emptySlotData` (a struct containing emptySlotsSorted, emptySlotsByBag, emptySlots, emptySlotByBagAndSlot, totalItems)
   - `Phase4_ApplyVirtualStacks(kind, itemData)`: Takes `itemData`, returns `visibleItemsBySlotKey` and `stackData`.
   - `Phase5_EnrichCategories(kind, itemData, emptySlotData)`: Takes `itemData` and `emptySlotData`, returns `sectionLayouts`.
   - `Phase6_Sort(kind, visibleItemsBySlotKey, emptySlotData)`: Returns `sortedItems`.
   - `Phase7_PartitionIntoTabs(ctx, kind, sortedItems, emptySlotData)`: Returns `tabData`.

4. **Phase8_CommitAndDispatch (The Pure State Update)**
   - `Phase8_CommitAndDispatch(ctx, kind, itemData, visibleItemsBySlotKey, sectionLayouts, sortedItems, tabData, emptySlotData, stackData, ...)`
   - Takes all these isolated return values and atomically populates the real `self.slotInfo[kind]`, creating it fresh or wiping the old data, then dispatches the done event.

5. **Update Tests**
   - Update `spec/items_spec.lua` and any other tests mocking or expecting `tempSlotInfo` or the old phase signatures. The tests will need to reflect the new purely functional phase inputs and outputs.

## Risks & Edge Cases
- **Stale State Reads**: Since `GetItemDataFromSlotKey` will no longer read `_tempSlotInfo`, any internal function inadvertently calling it during the refresh pipeline might read the stale state from the previous frame. We must exhaustively ensure that all phase helpers use the passed `itemData` map.
- **Test Harness Breakage**: Our test suite heavily relies on the exact mutations of `ProcessRefresh`. We will need to update the mocks to handle the new return types for each phase.

## Summary of Changes
- **Files to Modify**: 
  - `data/items.lua`
  - `spec/items_spec.lua`
  - `spec/search_spec.lua` (if it tests `RefreshSearchCache`)
- **Action**: Cleanly restructure `ProcessRefresh` and its sub-phases to use pure input/output maps, culminating in a single atomic update in Phase 8.