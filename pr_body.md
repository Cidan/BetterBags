## Summary of Changes
This PR completely resolves the bank tab disappearing items and unassigned category leakage bugs by migrating the bank tab architecture to a **Pure Static Persistent View** model.

1. **Unified Retail Bank Loading**:
   - Modified `items:RefreshBags` on Retail to **always load both Character Bank and Account Bank bags** into the unified `slotInfo` cache, regardless of the active tab.

2. **Strict Physical Bag Tab Filtering**:
   - Updated `ItemBelongsToTab()` in both grid and bag views. When rendering group-based bank tabs on Retail, it strictly matches the group's `bankType` (Character vs Account/Warbank) with the physical item's `bagid`. This cleanly partitions the unified cache and prevents unassigned category items from leaking across tabs.

3. **Instant, Synchronous Tab Swapping**:
   - Removed synchronous cache clearing and delayed refresh events in `SwitchToGroup` and `SwitchToBlizzardTab`.
   - The UI now simply fetches the complete `slotInfo` and draws it immediately, allowing instant, zero-flicker swaps.

4. **Updated Rule Documentation**:
   - Added architectural guidelines to `.claude/rules/data-loader.md` detailing the unified loading, persistent filtering, and instant tab swapping.

## Motivation
Previously, switching bank tabs conditionally loaded subset bags and discarded context, causing incomplete view caches. This led to missing buttons when swapping tabs and unassigned items showing up in both tabs since both are considered default groups. Switching to a pure static persistent view model ensures the item cache is always full, and views simply filter and show/hide what they are responsible for.

## Testing and Validation Performed
- All 886 / 886 tests pass successfully with zero errors or failures.
- Added tests in `spec/views/persistent_tabs_spec.lua` and `spec/frames/bankslots_spec.lua` to verify the unified bag loading and strict filtering logic.
- `luacheck` output is clean with 0 warnings/errors.
- Verified in the Lua 5.1 runtime environment as per project requirements.