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

## First-Time Lazy Initialization of Tab Views
**Problem**: Lazily-created tab views (such as custom groups/tabs selected for the first time) show up blank on click after reload/logging in because the initial changeset (containing all added items) has already been consumed by the primary backpack view. Subsequent clicks on custom tabs receive an empty delta changeset (`GetChangeset()` returns `{}`, `{}`, `{}`).

**Solution**: Introduce a view-level `isNew` flag initialized to `true` upon view creation. On the view's first-render, if `isNew` is `true`, bypass the empty delta changeset, wipe the view, reset `isNew = false`, and perform a full draw by populating `added` with all non-empty items from `slotInfo:GetCurrentItems()`. This handles first-time lazy draws of tab views flawlessly while preserving subsequent high-performance delta changesets.

**Related Files**: `views/views.lua`, `views/bagview.lua`, `views/gridview.lua`, `spec/views/persistent_tabs_spec.lua`

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

## WipeSlotInfo / SendMessageLater Race: Stale SlotInfo in Deferred Draws
**Problem**: `items:GetItemDataFromSlotKey(slotkey)` returns nil for slotkeys that were valid at time of refresh but are gone by the time the deferred draw fires. Error: `"data must be provided"` in `SetItemFromData`.

**Root cause**: `events:SendMessageLater` defers the draw by one frame (`C_Timer.After(0, ...)`). If `items:WipeSlotInfo(kind)` fires during that frame (replacing the SlotInfo object and resetting `itemsBySlotKey`), slotkeys from the now-orphaned previous changeset are no longer in `items.slotInfo[kind].itemsBySlotKey`.

**Why it happens**: The refresh pipeline is:
1. `LoadBagItems` → `ContinuableContainer:ContinueOnLoad` (async)
2. Callback → `LoadItems` → `slotInfo:Update` (builds changeset) → `SendMessageLater`
3. `C_Timer.After(0)` fires → Draw → `SetItem` → `GetItemDataFromSlotKey`

Between steps 2 and 3, a new `BAG_UPDATE_DELAYED` or `wipe=true` refresh can fire `WipeSlotInfo`, replacing `items.slotInfo[kind]` with a brand-new empty object. The draw then looks up stale slotkeys in the new (empty or different) `itemsBySlotKey`.

**Solution**: Nil-guard all direct lookups via `GetItemDataFromSlotKey` before dereferencing the result:
```lua
-- In SetItem (frames/item.lua):
local data = items:GetItemDataFromSlotKey(slotkey)
if not data then
  debug:Log("SetItem", "No item data for slotkey", slotkey, "- skipping stale draw")
  return
end

-- In CreateButton (views/gridview.lua):
local item = items:GetItemDataFromSlotKey(slotkey)
if not item then return false end

-- In ClearButton (views/gridview.lua):
if item then addon:GetBagFromBagID(item.bagid).drawOnClose = true end

-- In ReconcileWithPartial (views/gridview.lua):
local rootItem = items:GetItemDataFromSlotKey(stackInfo.rootItem)
if not rootItem then return end
-- ... and for child items:
if childData and childData.itemInfo.currentItemCount ~= ... then
```

**Key files**: `frames/item.lua:323-333`, `views/gridview.lua:75-91`, `views/gridview.lua:99-120`, `views/gridview.lua:175-210`

## Coroutine Pipelines: Capture Client State, Then Yield, Then Read Committed State
**Problem**: `items:ProcessRefresh` runs inside `async:Do` and yields once (the resume comes back through `C_Timer.After(0)` on the next frame). With the yield placed right before the commit, two refreshes started in the same frame both read the *same* committed `previousItems` before either committed. A wipe refresh followed in the same frame by a `BAG_UPDATE_DELAYED` targeted sweep ended with the targeted sweep committing last — merged against the wiped (empty) previous state — so every bag it did not target vanished until the next update.

**Rule**: The only frame boundary in the pipeline sits immediately after `Phase2_Harvest`. The harvest must read the client in the frame the event fired, but everything that reads committed addon state (`Phase3_ExtractPreviousState`, the targeted merge, categories, sorting, partition, commit) runs after the yield, so refreshes resume in queue order and each one merges against whatever the previous one just committed. Never move `async:Yield()` below the merge again.

**Test**: `spec/refresh_pipeline_spec.lua` ("does not lose untouched bags when a wipe refresh and a targeted refresh start in the same frame") uses a real `coroutine.yield` and a queued `C_Timer.After` mock to replay the two-frame sequence.

## Data Phases Must Operate On The Data They Were Handed, Not On Committed State
**Problem**: `Phase4_ClearMovedItemGlows` detected a moved item (same GUID added in one slot and removed from another) but then called `items:ClearNewItem(ctx, slotkey)`, which looks the slot key up in the *committed* `SlotInfo` — i.e. the previous occupant of the destination slot, or nothing at all. The moved item's GUID timer was never cleared and it stayed in "Recent Items".

**Rule**: Phase functions receive the transient `itemData` / `previousItems` tables as arguments; anything they mutate must be reached through those arguments (`items:ClearNewItemFromData(ctx, addedItem)`), never through `GetItemDataFromSlotKey`, which only reflects the last commit.

## Debugging Strategies
1. **Trace the call chain**: End symptom → query function → filter variable → where filter is set → events → switch point
2. **Check Blizzard source first**: `.libraries/wow-ui-source/` for actual Blizzard implementation before writing hooks or workarounds
