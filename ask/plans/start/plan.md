# Implementation Plan

## Objective
Refactor Backpack tab switching to use the modern `tab_switch` bypass architecture (matching the Bank's behavior). This will completely resolve the duplicate empty categories and the subsequent `SetPoint` crashes by bypassing redundant data-rebuild and layout passes during tab switches. No hacky double-free guards will be added.

## Files to modify
- `bags/backpack.lua`

## Approach
1. Import `Items` at the top of `bags/backpack.lua` if it isn't already imported:
   ```lua
   ---@class Items: AceModule
   local items = addon:GetModule("Items")
   ```
2. Inside `backpack.proto:SwitchToGroup(ctx, groupID)`:
   - Remove the line that triggers a full database redraw (`events:SendMessage(ctx, "bags/RefreshBackpack")`).
   - Add `ctx:Set("tab_switch", true)` to flag the context as a tab switch.
   - Fetch the slot info, similarly to the bank: `local slotInfo = items:GetAllSlotInfo()[const.BAG_KIND.BACKPACK]`.
   - Invoke `self.bag:Draw(ctx, slotInfo, function() end)` directly to simply toggle tab view visibility.
   - Fire `ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)` to update contexts, mirroring the bank implementation.
3. Commit the changes to the existing `fix-unified-wipe-phase` branch to update PR 1015 (do not open a new PR).

## Risks & Edge Cases
- Ensure bypassing the refresh does not leave the new tab with stale items. Since tab switching normally only alters visibility and doesn't change underlying items, this perfectly aligns with the Bank's existing functionality.
- Completely avoid modifying `core/pool.lua`. No double-free guards should be added, preserving the system's strict architectural purity.