# Implementation Plan: Scoped Recent Items and Sort Integration

## 1. Files to Modify

### `data/items.lua`
- **Goal**: Refactor `_newItemTimers` from a single flat table to a table scoped by `BAG_KIND` (e.g., `BACKPACK` and `BANK`).
- **Changes**:
  - Initialize `self._newItemTimers` with keys for `const.BAG_KIND.BACKPACK` and `const.BAG_KIND.BANK`.
  - Update `items:IsNewItem(data)` to query `self._newItemTimers[data.kind][guid]`.
  - Update `items:MarkItemAsNew(ctx, data)` to insert into `self._newItemTimers[data.kind][guid]`.
  - Update `items:ClearNewItem(ctx, slotkey)` to handle scoped lookup.
  - Refactor `items:ClearNewItems(kind)` to clear state based on the passed `BAG_KIND`. Use Blizzard's `C_NewItems.RemoveNewItem` for specific bags if a kind is passed, or `C_NewItems.ClearAll()` if no kind is passed.

### `data/refresh.lua`
- **Goal**: Hook into sort requests to clear recent items and force an immediate layout redraw.
- **Changes**:
  - In `Refresh:RequestUpdate(request)`, handle `request.sort` (Backpack) and `request.sortBank` / `request.sortWarbank` (Bank):
    - If `request.sort` is true: call `items:ClearNewItems(const.BAG_KIND.BACKPACK)`, set `request.backpack = true`.
    - If bank sort is true: call `items:ClearNewItems(const.BAG_KIND.BANK)`, set `request.bank = true`.
    - Ensure the respective `C_Container.SortBags` or `SortBankBags` APIs are called appropriately, after the data state update is queued for redraw.

### `themes/themes.lua` & `frames/contextmenu.lua`
- **Goal**: Reroute direct Blizzard sort API calls to use the new `Refresh` sorting pipeline.
- **Changes**:
  - Replace direct calls to `C_Container.SortBankBags()` and `C_Container.SortAccountBankBags()` with appropriate calls to `refresh:RequestUpdate({sortBank = true})` or equivalent message dispatch.

### `spec/items_spec.lua` & `spec/refresh_spec.lua`
- **Goal**: Add comprehensive test coverage using item fakes to ensure data state correctness.
- **Changes**:
  - Write permutations testing that backpack sorting clears ONLY backpack recent items.
  - Write permutations testing that bank sorting clears ONLY bank recent items.
  - Test happy paths and edge cases (e.g., `C_NewItems` clearing behaviors, empty bag sorts).

## 2. Approach
1. **Tests First**: Begin by writing failing unit tests in `spec/items_spec.lua` and `spec/refresh_spec.lua` that simulate adding new items to both backpack and bank, requesting a sort on one, and verifying the state of the other.
2. **Data Layer Refactor**: Modify `data/items.lua` to implement the scoped `_newItemTimers`. Ensure all existing tests pass after the refactor.
3. **Refresh Pipeline Update**: Modify `data/refresh.lua` to handle the data clearing and redraw forcing prior to invoking the Blizzard sorting APIs.
4. **UI Integration**: Update the context menu and themes to use the centralized refresh pipeline for bank sorting.
5. **Final Validation**: Run the full test suite (`luacheck` and `busted`) to guarantee no regressions or taint issues.

## 3. Risks and Edge Cases
- **`BAG_KIND` Resolution**: Ensuring that `data.kind` is always correctly populated on the item data objects when interacting with `IsNewItem` and `MarkItemAsNew`.
- **Classic Compatibility**: Ensure that references to `C_NewItems` and Warbank/Account bank features are properly gated behind `addon.isRetail` where necessary, as Classic does not have these features.
- **Backward Compatibility**: If any other module calls `items:ClearNewItems()` without a `kind` argument, it should safely clear everything to avoid unexpected behavior.
- **Test Fidelity**: Mocking the `C_NewItems` behavior accurately in tests to ensure we don't accidentally leak state between tests.