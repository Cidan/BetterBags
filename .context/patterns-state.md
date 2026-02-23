# State Management and Architecture Patterns

## Context Filter Propagation
**Problem**: BAG_UPDATE events don't carry context about which tab is currently active, causing wrong items to display.
**Solution**: Store filter state in context objects that propagate through event chains. At event entry points, determine the correct filter based on current state. Check for an existing filter before defaulting. Handle account bank vs character bank with explicit checks:
```lua
local existingFilter = ctx:Get('filterBagID')
if existingFilter ~= nil then
  refreshCtx:Set('filterBagID', existingFilter)
elseif currentTab >= accountBankStart then
  refreshCtx:Set('filterBagID', nil)    -- account bank: show all
else
  refreshCtx:Set('filterBagID', currentTab)  -- character bank: filter to bag
end
```

## Always Use Behavior Methods for Programmatic Tab/View Switching
**Problem**: Calling visual-only methods like `tabs:SetTabByID()` highlights the tab button but doesn't update bag contents. This is the wrong layer.
**Why the split exists**:
- **Visual methods** (`SetTabByID`, `SelectTab`): Only update button appearance
- **Behavior methods** (`SwitchToGroup`, `SwitchToCharacterBankTab`, etc.): Full state management — update state vars, set context filters, clear caches, call `BankPanel:SetBankType()`, send refresh events, call `ItemButtonUtil.TriggerEvent()`, then finally call visual methods

**Solution**: Always dispatch to the behavior layer:
- Backpack: `bag.behavior:SwitchToGroup(ctx, tabID)`
- Bank (single tab): `bag.behavior:SwitchToBank(ctx)`
- Bank (char tab): `bag.behavior:SwitchToCharacterBankTab(ctx, tabID)` (tabID 6–11)
- Bank (account tab): `bag.behavior:SwitchToAccountBank(ctx, tabID)` (tabID 13–17)

**Diagnostic**: Tab highlights ✅ but bag contents don't update ❌ → calling visual instead of behavior method.
**Related Files**: `bags/backpack.lua:342-356`, `bags/bank.lua:590-667`, `integrations/quickfind.lua:137-170`

## WoW Bank System Architecture
- **Character Bank**: BagIndex 6–11 (`CharacterBankTab_1` to `CharacterBankTab_6`)
- **Account Bank**: BagIndex 13–17 (`AccountBankTab_1` to `AccountBankTab_5`)
- **Reagent Bank**: `BagIndex.Reagentbank`
- Right-click item destination is determined by `BankPanel:GetActiveBankType()`
- Always use `BankPanel:SetBankType(Enum.BankType.Character/Account)` — never assign directly to `BankPanel.bankType` (direct assignment taints BankPanel and causes `ADDON_ACTION_FORBIDDEN`)
- Account bank tabs show aggregate items; character bank tabs each correspond to one bag

## Use View-Level Flags to Bridge Context Boundary Gaps
**Problem**: Operations that must fire after a full view rebuild fail because `refresh:ExecutePendingUpdates` creates a fresh context that doesn't carry flags from the triggering context (classic example: sections not sorted after opening bank or switching tabs).

**Why**: `SwitchToGroup()` calls `bag:Wipe(ctx)` where `ctx` has `wipe=true`, then sends `bags/RefreshBank`. The refresh handler calls `refresh:RequestUpdate()` which eventually calls `context:New('BagUpdate')` — a brand-new context without `wipe=true`.

**Solution**: Set a flag on the long-lived **view object** (not the short-lived context):
```lua
-- In Wipe(): set the flag so it survives context boundaries
view.sortRequired = true

-- In GridView(): check either source
if ctx:GetBool('wipe') or view.sortRequired then
  view.sortRequired = false  -- clear before acting
  view.content:Sort(sort:GetSectionSortFunction(bag.kind, const.BAG_VIEW.SECTION_GRID))
end

-- In constructor: initialize
view.sortRequired = false
```
**Related Files**: `views/gridview.lua`, `bags/bank.lua:489-518`, `data/refresh.lua:112-152`

## Code Organization
- **core/init.lua**: One-time setup, frame hiding/showing, Blizzard integration
- **frames/bag.lua**: UI state management, tab switching, visual updates
- **data/items.lua**: Item queries and filtering based on state
- **data/refresh.lua**: Event handling and context management

## Feature Parity Across Game Versions
**Problem**: Bug fixes or features applied only to retail code break in Classic Era (`frames/era/`) or Classic (`frames/classic/`).

**Rule**: When touching `frames/*.lua`, check if `frames/era/*.lua` and `frames/classic/*.lua` need the same change. When adding module imports, verify all three versions have them. Note which versions were updated in commit messages.

## Defensive Programming: Validate Function Parameters from Saved Variables
**Problem**: External addons can corrupt saved variables. A sort preference key that maps to `nil` or a non-function value causes `table.sort()` to crash.
**Solution**: Guard at the call site and provide safe defaults in functions that derive callbacks from saved variables:
```lua
function gridProto:Sort(fn)
  if type(fn) ~= "function" then
    fn = function() return false end
  end
  table.sort(self.cells, fn)
end
```

## Debugging Strategies
1. **Trace the call chain**: End symptom → query function → filter variable → where filter is set → events → switch point
2. **Check Blizzard source first**: `.libraries/wow-ui-source/` for actual Blizzard implementation before writing hooks or workarounds
