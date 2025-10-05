# WoW Addon Development Patterns

## Meta-Rule: Document Evolution
**IMPORTANT**: When you discover new abstract patterns through debugging, problem-solving, or user interaction, you MUST update this document. Add the pattern under the appropriate section with:
- Clear problem statement
- Why it happens
- Solution pattern
- When to apply it

## Protected Code and Taint

### Pattern: Never Assign to Global `_` Variable
**Problem**: Assigning to the global `_` variable (throwaway variable) without declaring it as local causes taint that prevents protected actions like using items.

**Why**: In WoW's Lua environment, `_` is a global variable. When addon code assigns to it (e.g., `bindType, _, _, _ = select(...)`), it taints the global environment. This taint propagates and blocks protected functions like `UseContainerItem`. Even if you declare `local _, _, x, _, _`, only the LAST `_` becomes accessible as local - subsequent assignments without `local` will taint the global.

**Solution Pattern**: Always use `local _` in the same statement as the assignment, or only capture what you need:
```lua
-- BAD: Taints global _ variable
bindType, _, _, _ = select(14, C_Item.GetItemInfo(itemLink))

-- BAD: Reusing local _ in multi-value assignment
local _, _, x, _, _
_, _, x, _, _ = foo()  -- Only last _ is local, others are global!

-- GOOD: Declare local in same statement
local bindType, _, _, _ = select(14, C_Item.GetItemInfo(itemLink))

-- BETTER: Only capture what you need
local bindType = select(14, C_Item.GetItemInfo(itemLink))

-- GOOD: Separate assignment with new local
local x
if condition then
  local _, _, val = foo()
  x = val
end
```

**When to Apply**: Any time you use `_` as a throwaway variable. Always verify assignments have `local` in the SAME statement.

### Pattern: Cannot Override Functions Called in Protected Contexts
**Problem**: Overriding Blizzard functions that are called during protected actions (combat, secure actions like UseContainerItem) causes `ADDON_ACTION_FORBIDDEN` errors.

**Why**: WoW's taint system prevents addons from influencing protected actions. Even reading addon tables during protected calls can cause taint. Additionally, **touching Blizzard frames at initialization taints them permanently**, blocking all future protected operations.

**Critical Discovery**: Blizzard's `UseContainerItem()` (called for ALL containers including backpack) calls `BankFrame:GetActiveBankType()`. If BankPanel has been touched by addon code at ANY point, this call fails with taint errors - even for backpack items!

**Solution Pattern**:
1. **Never show or interact with BankPanel during initialization** - this taints it permanently
2. Only show BankPanel when bank is actually open, hide it when closed
3. Make BankPanel invisible (alpha=0, disable mouse/keyboard) but only when shown
4. Use Blizzard's methods (e.g., `BankPanel:SetBankType()`) instead of direct field assignment

**Example**:
```lua
-- BAD: Showing at initialization taints permanently
-- This will cause ALL UseContainerItem calls to fail!
if BankPanel then
  BankPanel:SetAlpha(0)
  BankPanel:Show()  -- NEVER DO THIS AT INIT
end

-- GOOD: Configure invisibility but don't show
if BankPanel then
  BankPanel:SetAlpha(0)
  BankPanel:EnableMouse(false)
  BankPanel:Hide()  -- Keep hidden initially
end

-- Then when bank opens:
if BankPanel then
  BankPanel:Show()  -- Now show it
  if BankPanel.SetBankType then
    BankPanel:SetBankType(Enum.BankType.Character)
  end
end

-- When bank closes:
if BankPanel then
  BankPanel:Hide()  -- Hide to prevent taint affecting other operations
end
```

**When to Apply**: Any time working with Blizzard frames that are checked by protected code (BankPanel, BankFrame, etc.)

### Pattern: Avoid Context Creation in Mouse Event Hooks on Item Buttons
**Problem**: Using `addon.HookScript()` for mouse events (OnMouseDown, OnMouseUp, OnEnter, OnLeave) on item buttons causes `ADDON_ACTION_FORBIDDEN` errors when users right-click consumable items.

**Why**:
- `addon.HookScript()` creates a new context object for every event
- Mouse events fire immediately before protected clicks (e.g., UseContainerItem for consumables)
- Creating contexts and touching addon tables during these events taints the execution path
- When the subsequent protected function tries to execute, WoW blocks it due to the taint

**Solution Pattern**:
1. Use plain `button:HookScript()` instead of `addon.HookScript()` for mouse events
2. Implement lazy caching to fetch decoration buttons once and reuse them
3. Avoid calling into addon modules (like themes) during the actual mouse events

**Example**:
```lua
-- BAD: Creates context on every mouse event, causes taint
addon.HookScript(button, "OnMouseDown", function(ectx)
  themes:GetItemButton(ectx, i):GetPushedTexture():Show()
end)

-- GOOD: Plain HookScript with lazy cached decoration reference
local decoration
local getDecoration = function()
  if not decoration then
    local ctx = context:New('itemButton_init')
    decoration = themes:GetItemButton(ctx, i)
  end
  return decoration
end

button:HookScript("OnMouseDown", function()
  getDecoration():GetPushedTexture():Show()
end)
```

**When to Apply**: Any time you need to hook mouse events on buttons that use `ContainerFrameItemButtonTemplate` or any button where clicks can trigger protected functions.

## State Management Across Events

### Pattern: Context Filter Propagation
**Problem**: When BAG_UPDATE events fire, the refresh logic may not know which specific bag/tab is currently active, causing items from wrong tabs to display.

**Why**: Events are asynchronous and don't carry context about the current UI state.

**Solution Pattern**:
1. Store filter state in context objects that propagate through event chains
2. At event entry points, determine the correct filter based on current state
3. Check for existing filters in context before defaulting
4. Handle special cases (account bank vs character bank) with explicit checks

**Example**:
```lua
local existingFilter = ctx:Get('filterBagID')
if existingFilter ~= nil then
  refreshCtx:Set('filterBagID', existingFilter)
elseif currentTab >= accountBankStart then
  refreshCtx:Set('filterBagID', nil) -- Account bank shows all
else
  refreshCtx:Set('filterBagID', currentTab) -- Character bank filters to tab
end
```

## WoW Bank System Architecture

### Bank Type Hierarchy
- **Character Bank**: Bags 6-11 (Enum.BagIndex.CharacterBankTab_1 through CharacterBankTab_6)
- **Account Bank**: Bags 13-17 (Enum.BagIndex.AccountBankTab_1 through AccountBankTab_5)
- **Reagent Bank**: Special bag (Enum.BagIndex.Reagentbank)

### Pattern: Bank Type Determines Item Destination
**Problem**: Right-click item movement needs to know if it should go to character or account bank.

**Why**: `C_Container.UseContainerItem()` accepts an optional `bankType` parameter that Blizzard code determines via `BankPanel:GetActiveBankType()`.

**Solution Pattern**:
1. Use `BankPanel:SetBankType()` method instead of direct field assignment to avoid taint
2. Call it whenever switching tabs: `BankPanel:SetBankType(Enum.BankType.Character)` or `BankPanel:SetBankType(Enum.BankType.Account)`
3. Ensure `BankPanel:IsShown()` returns true for the lookup to work
4. Always check method exists: `if BankPanel and BankPanel.SetBankType then`

**Critical**: Never directly assign to `BankPanel.bankType` - this taints the BankPanel object and causes `ADDON_ACTION_FORBIDDEN` errors when Blizzard's protected code calls `GetActiveBankType()`.

## Item Filtering and Display

### Pattern: Conditional Filtering by Bank Type
**Problem**: Different bank types need different filtering strategies (account shows all items in that tab, character shows only specific bag).

**Why**: Account bank tabs are shared and show aggregate items; character bank tabs are individual bags.

**Solution Pattern**:
```lua
if currentTab >= accountBankStart then
  -- Account bank: don't filter, let items module use bankTab directly
  filterBagID = nil
else
  -- Character bank: filter to specific bag
  filterBagID = currentTab
end
```

## Debugging Strategies

### Pattern: Trace State Through Call Chain
When debugging complex state issues:
1. Identify the end symptom (wrong items displayed)
2. Find the function that queries items (items module)
3. Trace backwards: What determines the query? (filterBagID)
4. Find where filter is set (refresh logic)
5. Find where events trigger refresh (event handlers)
6. Verify state at each switch point (tab switching)

### Pattern: Check Blizzard Source for API Understanding
Before implementing hooks or workarounds:
1. Check `.libraries/wow-ui-source/` for actual Blizzard implementation
2. Understand what Blizzard code expects (preconditions, state variables)
3. Use MCP WoW API tools for documentation
4. Test against real game behavior, not assumptions

## Code Organization

### Pattern: Separation of Concerns for Bank Logic
- **core/init.lua**: One-time setup, frame hiding/showing, Blizzard integration
- **frames/bag.lua**: UI state management, tab switching, visual updates
- **data/items.lua**: Item queries and filtering based on state
- **data/refresh.lua**: Event handling and context management

Keep these boundaries clear to avoid circular dependencies and taint propagation.
