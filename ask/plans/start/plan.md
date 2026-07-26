# Implementation Plan: Fix Bank "Show Bags" and Warbank Empty Slots

## Issue Summary
1. Character bank tabs are empty because the backend aggregates all character bank bags into a single tab (`-1`) while the UI requests them by their individual physical bag IDs (`5`, `6`, etc.).
2. Warbank tabs appear as categories rather than grids because dummy empty slots are not generated, due to a legacy API check (`C_Container.GetBagName` returning `nil` for Warbank bags).

## Approach

### 1. Write Failing Tests First
- In `spec/items_spec.lua` or `spec/data/items_spec.lua` (using the high-fidelity debug dump test harness as per the `test-harness.md` rules), add tests to verify the behavior of `ProcessRefresh` for the `BANK` when `database:GetShowBankTabs()` is true and `database:GetBagView()` is `SECTION_ALL_BAGS`.
- Assert that `slotInfo.tabs` contains distinct entries for `-1` and individual character bank bags like `5`.
- Assert that Warbank tabs (e.g., `13`) contain dummy `isFreeSlot = true` items to properly pad the grid.
- Observe these tests fail.

### 2. Fix Bank Tab Aggregation in `data/items.lua`
- **`GetPossibleTabIDs(kind)`**: When `GetShowBankTabs()` is enabled, modify the logic so that it doesn't just add `const.BANK_TAB.BANK`. It should add `-1` (main bank) and iterate through `const.BANK_BAGS` adding each bag ID as a valid tab.
- **`ItemBelongsToTab(kind, item, tabID, viewBagView)`**: Update the `SECTION_ALL_BAGS` and `GetShowBankTabs` conditions to strictly match `item.bagid == tabID` for all bank bags, eliminating the broad fallback to `-1` for all character bags.
- **`IncludeBagInFreeSpace(kind, bagid, tabID)`**: Adjust the logic to strictly match `bagid == tabID` for bank bags instead of grouping all non-Warbank bags under `-1`.

### 3. Fix Warbank Empty Slots in `data/items.lua`
- Around line 653, modify the check: `if C_Container.GetBagName(bagid) ~= nil then`.
- Change it to: `if C_Container.GetBagName(bagid) ~= nil or (addon.isRetail and const.ACCOUNT_BANK_BAGS and const.ACCOUNT_BANK_BAGS[bagid]) then`.
- This ensures Warbank bags generate dummy empty slots, padding out the physical layout correctly.

## Risks & Edge Cases
- Ensure Classic/Era are not broken by the `const.ACCOUNT_BANK_BAGS` references. We must safely gate these with `addon.isRetail` or `const.ACCOUNT_BANK_BAGS ~= nil`.
- The main bank tab (`-1`) must still function and render properly on its own.
- Free space counts for the unified view (when "Show Bags" is off) must continue to correctly aggregate all bags. The changes strictly target the `GetShowBankTabs` or `SECTION_ALL_BAGS` conditions.