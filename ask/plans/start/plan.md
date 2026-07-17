# Plan
## Context
We need to fix two bugs related to the `SECTION_ALL_BAGS` (Blizzard Bag View) functionality in the Bank:
1. When "Show Bank Tabs" is OFF, the Character Bank renders completely blank in `SECTION_ALL_BAGS` mode because items are incorrectly filtered into a single virtual tab (`tabID=1`) and rejected by a bank bag check.
2. In `SECTION_ALL_BAGS` mode, dummy empty slots for the Character Bank (`bagid = -1`) are never generated, because the data pipeline asserts `C_Container.GetBagName(bagid) ~= nil` which is false for `-1`.
3. The UI state can temporarily desync from the data layer on `/reload`, making `Phase 4.5` apply standard custom categories to `SECTION_ALL_BAGS` rendering if the initial active view hasn't propagated cleanly.

## Files to modify
- `data/items.lua`
- `spec/views/persistent_tabs_spec.lua` or `spec/items_spec.lua`

## Changes required
1. **Fix `ItemBelongsToTab` bypass logic in `data/items.lua`:**
   In `SECTION_ALL_BAGS`, we should only partition bank items into tabs IF "Show Bank Tabs" is enabled (`database:GetShowBankTabs() == true`). If it's disabled, we should skip all tab partitioning and return `true` for all bank items.
   ```lua
   if viewBagView == const.BAG_VIEW.SECTION_ALL_BAGS then
     if kind == const.BAG_KIND.BANK and addon.isRetail then
       if database.GetShowBankTabs and database:GetShowBankTabs() then
         if tabID == const.BANK_TAB.BANK then
           return const.ACCOUNT_BANK_BAGS == nil or const.ACCOUNT_BANK_BAGS[item.bagid] == nil
         else
           return item.bagid == tabID
         end
       end
     end
     return true
   end
   ```

2. **Fix dummy slot generation for `bagid = -1` in `data/items.lua` (Phase 4.5):**
   Remove the redundant `C_Container.GetBagName(bagid) ~= nil` wrapper in the `SECTION_ALL_BAGS` empty slot generation block. `slotInfo.emptySlotByBagAndSlot` only contains valid bags harvested during Phase 2, and `self:GetBagName(bagid)` safely handles `-1` and missing names.
   ```lua
   if database.GetBagView and database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS then
     for bagid, emptyBagData in pairs(slotInfo.emptySlotByBagAndSlot) do
       for slotid, data in pairs(emptyBagData) do
         local category = self:GetBagName(bagid)
         local dummy = {
           isFreeSlot = true,
           bagid = bagid,
           slotid = slotid,
           slotkey = data.slotkey or (bagid .. "_" .. slotid),
           itemInfo = { ... }
         }
         table.insert(slotInfo.sortedItems, dummy)
       end
     end
   end
   ```

3. **Verify tests:**
   - Check or write tests that validate `SECTION_ALL_BAGS` behavior under the Bank context when `GetShowBankTabs()` is false.
   - Run the full suite using the local test harness (`~/.luarocks/bin/busted`) to ensure all tests pass with `lua 5.1`.