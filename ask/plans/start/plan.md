# Implementation Plan: Move Frame Creation to ADDON_LOADED (OnInitialize)

## Objective
The goal is to shift heavy UI frame creation from the `PLAYER_LOGIN` event (`addon:OnEnable()`) to the `ADDON_LOADED` event (`addon:OnInitialize()`). This will decouple the data fetch from frame creation and fix script timeouts experienced in Hardcore versions of World of Warcraft during the initial player login.

## Files to Modify
- `core/init.lua`

## Approach

1. **Modify `addon:OnInitialize()`** (in `core/init.lua`):
   Append the heavy UI frame creation code to the end of the newly implemented deterministic boot loop, immediately after the module `Init()` calls (e.g., right after `consoleport:Init()`).
   Specifically, move the following:
   - `applyCompat()`
   - `self:HideBlizzardBags()`
   - The instantiation logic for Backpack and Bank:
     ```lua
     local rootctx = context:New('addon_initialize')
     addon.Bags.Backpack = BagFrame:Create(rootctx, const.BAG_KIND.BACKPACK)
     if database:GetEnableBankBag() then
       addon.Bags.Bank = BagFrame:Create(rootctx:Copy(), const.BAG_KIND.BANK)
     end
     ```
   - `themes:Enable()`
   - Setting the Backpack title: `addon.Bags.Backpack:SetTitle(L:G("Backpack"))`
   - Inserting frames into `UISpecialFrames`:
     ```lua
     table.insert(UISpecialFrames, addon.Bags.Backpack:GetName())
     if addon.Bags.Bank then
       table.insert(UISpecialFrames, addon.Bags.Bank:GetName())
     end
     ```

2. **Modify `addon:OnEnable()`** (in `core/init.lua`):
   Remove the code lines identified above from `addon:OnEnable()`.
   Ensure `addon:OnEnable()` correctly retains:
   - The sequential `module:Enable()` calls.
   - Core secure hooks (`ToggleAllBags`, `CloseSpecialWindows`).
   - The event registrations (`BANKFRAME_CLOSED`, `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`, etc.).
   - The `items/RefreshBackpack/Done` and `items/RefreshBank/Done` message event hooks.
   - Disabling CVar tutorials for Retail.

## Edge Cases and Risks
- **Data Query Triggers:** We must make sure none of the frame creations inside `BagFrame:Create(...)` inadvertently trigger a data fetch via `C_Container` or `search:IndexItems`. We have verified that `BagFrame:Create` acts structurally, so this risk is mitigated.
- **`themes:Enable()` Order:** This method applies global textures and styles to existing frame objects. It must be called strictly *after* the `BagFrame:Create` calls, and must only be called once to prevent UI leaks or duplications.
- **Module Init Completion:** The creation routines depend on modules like `events`, `database`, `themes`, etc., having run their `Init()` functions. We already secured this topological sort in the previous PR step.
- **Context Name:** The context instantiated for `BagFrame:Create` is currently named `'addon_enable'`. Since we are creating this context in `OnInitialize()`, we should rename it to `'addon_initialize'` for clarity.

## Implementation Steps for Executor
1. Read `core/init.lua`.
2. Delete the frame creation code from `addon:OnEnable()`.
3. Insert the frame creation code at the bottom of the initialization sequence inside `addon:OnInitialize()`, keeping the existing tutorial disabling and override binding logic at the very end of `OnInitialize()`.
4. Use `luacheck` to verify the codebase's syntax and scope requirements.
5. Create a git commit directly adding onto the existing PR work.