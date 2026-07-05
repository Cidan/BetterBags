# Implementation Plan

1. **Update `bags/backpack.lua` dependencies**
   - Add `---@class Items: AceModule` and `local items = addon:GetModule("Items")` around line 20, keeping with the structure of other AceModule imports.

2. **Modify `backpack.proto:SwitchToGroup` in `bags/backpack.lua`**
   - Replace the legacy full refresh mechanism (`events:SendMessage(ctx, "bags/RefreshBackpack")`) with an instant pre-rendered tab swap mechanism that uses the `tab_switch` flag.
   - The new implementation should match the static, zero-debounce, pure presentation design used by the Bank tabs:
     ```lua
     self.bag.currentItemCount = -1
     ctx:Set("tab_switch", true)
     local slotInfo = items:GetAllSlotInfo()[const.BAG_KIND.BACKPACK]
     self.bag:Draw(ctx, slotInfo, function() end)
     ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
     ```

3. **Verify and Clean Up**
   - Ensure there are no additional config-based conditionals inside `SwitchToGroup` related to old tab refresh behavior (which our grep confirmed are absent).
   - Ensure the new logic relies on the existing cache via `items:GetAllSlotInfo()`.

This aligns the backpack rendering perfectly with the bank's static caching design described in `.claude/rules/data-loader.md`.