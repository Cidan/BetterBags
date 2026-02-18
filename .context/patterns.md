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

### Pattern: Mark Unused Parameters with a Local Throwaway
**Problem**: Using `_ = arg` to silence unused-parameter warnings writes to global `_`, which creates taint risk and triggers `luacheck` `W111`.

**Why**: In Lua 5.1/WoW, `_` is global unless explicitly declared local in the current scope.

**Solution Pattern**: Localize `_` once per scope before throwaway assignments:
```lua
-- BAD: global write
_ = ctx
_ = item

-- GOOD: local throwaway in this scope
local _ = ctx
_ = item
```

**When to Apply**: Stub methods, callbacks, or compatibility shims where arguments are intentionally unused.

### Pattern: Compute Toggle State Inside the Active Branch
**Problem**: Declaring a shared `enabled` variable and only assigning it in one branch can pass `nil` into state setters in other branches.

**Why**: Lua locals default to `nil`. If branch A assigns `enabled` but branch B does not, branch B still calls setters with `nil`, causing silent no-op behavior or inconsistent state.

**Solution Pattern**: Derive `enabled` from the currently selected data source inside each branch:
```lua
-- BAD: branch-specific assignment with shared variable
local enabled
if isEphemeral then
  enabled = not ephemeral.enabled[kind]
else
  -- enabled is still nil here
end
setEnabled(kind, category, enabled)

-- GOOD: compute per branch
if isEphemeral then
  local enabled = not ephemeral.enabled[kind]
  setEphemeralEnabled(kind, category, enabled)
else
  local enabled = not persistent.enabled[kind]
  setPersistentEnabled(kind, category, enabled)
end
```

**When to Apply**: Toggle handlers that support multiple storage backends (ephemeral/persistent, cache/db, etc.).

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

### Pattern: Never Manipulate Blizzard Frames from OnHide/OnShow Scripts Triggered by UISpecialFrames
**Problem**: Touching BankPanel or calling CloseBankFrame() from frame OnHide/OnShow scripts causes persistent taint that breaks UseContainerItem() for ALL containers (including backpack) after the bank is closed via ESC key.

**Why**: When ESC is pressed, WoW's engine calls `CloseSpecialWindows()` which iterates through `UISpecialFrames` and hides each frame. This hiding happens in a protected execution context. Any frame scripts (OnHide/OnShow) that execute during this process are still within the protected context. If these scripts touch Blizzard frames like BankPanel or call protected functions like CloseBankFrame(), they create persistent taint. Later, when the user opens their backpack and uses an item, Blizzard's protected `UseContainerItem()` calls `BankFrame:GetActiveBankType()` which reads from the tainted BankPanel, causing the action to be blocked.

**Solution Pattern**:
1. **Never touch BankPanel in OnHide/OnShow scripts** - move all BankPanel manipulation to event handlers
2. **Never call CloseBankFrame() in OnHide** - it runs in protected context and causes taint
3. **DO call CloseBankFrame() in CloseSpecialWindows SecureHook** - this is safe and necessary to exit banking mode
4. **Use BANKFRAME_OPENED/CLOSED event handlers** for safe BankPanel manipulation (these run in addon context, not protected context)
5. **Keep OnHide/OnShow scripts minimal** - only handle your own addon's UI cleanup (sounds, animations, frame hiding)

**Example**:
```lua
-- BAD: OnHide touches BankPanel (runs in protected context from UISpecialFrames)
function bank.proto:OnHide()
  addon.ForceHideBlizzardBags()
  PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)

  -- WRONG: These calls create persistent taint!
  if BankPanel then
    BankPanel:Hide()  -- Taints BankPanel
  end
  if C_Bank then
    C_Bank.CloseBankFrame()  -- Duplicate call in protected context
  end
end

-- GOOD: OnHide only handles own UI, no Blizzard frame manipulation
function bank.proto:OnHide()
  -- IMPORTANT: Do NOT touch BankPanel or call CloseBankFrame() here.
  -- OnHide runs in protected context when triggered by UISpecialFrames (ESC key).
  -- Any BankPanel manipulation here causes persistent taint.

  addon.ForceHideBlizzardBags()
  PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)

  if database:GetEnableBagFading() then
    self.bag.fadeOutGroup.callback = function()
      self.bag.fadeOutGroup.callback = nil
      ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
    end
    self.bag.fadeOutGroup:Play()
  else
    self.bag.frame:Hide()
    ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
  end
end

-- GOOD: Call CloseBankFrame() in CloseSpecialWindows hook (safe context)
function addon:CloseSpecialWindows(interactingFrame)
  if interactingFrame ~= nil then return end

  local ctx = context:New('CloseSpecialWindows')
  addon.backpackShouldClose = true

  -- ... other cleanup ...

  -- Call CloseBankFrame() to exit banking mode and trigger BANKFRAME_CLOSED event.
  -- This is safe here (SecureHook runs after Blizzard's function completes).
  -- CRITICAL: Do NOT call this from OnHide - that runs in protected context!
  if C_Bank then
    C_Bank.CloseBankFrame()
  else
    CloseBankFrame()
  end

  events:SendMessageLater(ctx, 'bags/OpenClose')
end

-- GOOD: BankPanel manipulation in event handler (safe context)
function addon.CloseBank(ctx, _, interactingFrame)
  if interactingFrame ~= nil then return end
  if addon.Bags.Bank then
    addon.Bags.Bank:Hide(ctx)
    addon.Bags.Bank:SwitchToBankAndWipe(ctx)
  end

  -- Safe to hide BankPanel here - event handler runs in addon context
  if BankPanel then
    BankPanel:Hide()
  end

  events:SendMessage(ctx, 'bags/BankClosed')
end
```

**Key Distinction**:
- ❌ **OnHide script**: Runs in protected context (from UISpecialFrames) - touching BankPanel or calling CloseBankFrame() here CAUSES TAINT
- ✅ **CloseSpecialWindows SecureHook**: Runs after Blizzard's function completes, in addon context - safe to call CloseBankFrame()
- ✅ **BANKFRAME_CLOSED event handler**: Runs in addon context - safe to hide BankPanel

**When to Apply**:
- Any time implementing custom bank frame behavior with UISpecialFrames registration
- When hooking CloseSpecialWindows or handling BANKFRAME_OPENED/CLOSED events
- Any frame that can be closed via ESC key and interacts with Blizzard's protected frames

**Related Files**:
- bags/bank.lua:148-187 (OnHide method)
- core/hooks.lua:111-134 (CloseSpecialWindows hook)
- core/hooks.lua:138-153 (CloseBank event handler)

### Pattern: Bank Closing Recursion Prevention with Guard Flags
**Problem**: Stack overflow/infinite recursion when closing the bank, caused by `CloseBankFrame()` calls creating event loops that call `Hide()` again.

**Why**: Bank closing involves multiple paths that can trigger each other:
- **hooksecurefunc on Hide()**: Calls `CloseBankFrame()` when bank hides (needed for X button in Retail)
- **BANKFRAME_CLOSED event**: Calls `addon.CloseBank()` which calls `Hide()`
- **OnHide methods** (Classic/Era): Called when frame hides, may call `CloseBankFrame()`

Without guards, these create recursion loops:
1. Hide() is called → hooksecurefunc fires → calls CloseBankFrame()
2. BANKFRAME_CLOSED event → addon.CloseBank() → Hide() again
3. Frame may still be visible (fade animation) → triggers hooksecurefunc again → **RECURSION**

**Solution Pattern**: Use guard flags at each potential recursion point:

**1. Retail hooksecurefunc** - Module-level guard flag prevents re-entry (bags/bank.lua):
```lua
-- Module-level guard flag
local isClosingBank = false

hooksecurefunc(bag, "Hide", function(selfBag, ctx)
  -- Skip for Classic/Era (they handle it differently)
  if not addon.isRetail then
    return
  end

  -- Guard against recursion
  if isClosingBank then
    return
  end

  isClosingBank = true

  -- Call CloseBankFrame() to handle X button closes
  if C_Bank then
    C_Bank.CloseBankFrame()
  elseif CloseBankFrame then
    CloseBankFrame()
  end

  -- Clear flag after event processing completes
  C_Timer.After(0, function()
    isClosingBank = false
  end)
end)
```

**2. Classic/Era OnHide** - Instance-level guard flag prevents re-entry (bags/classic/bank.lua & bags/era/bank.lua):
```lua
function bank.proto:OnHide()
  -- Guard against re-entry to prevent recursion
  if self.isHiding then
    return
  end
  self.isHiding = true

  -- IMPORTANT: Do NOT call CloseBankFrame() here.
  -- The hooksecurefunc would create recursion. Instead, Classic/Era
  -- rely on the CloseSpecialWindows hook to call CloseBankFrame().

  addon.ForceHideBlizzardBags()
  PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)

  if database:GetEnableBagFading() then
    self.bag.fadeOutGroup.callback = function()
      self.bag.fadeOutGroup.callback = nil
      self.isHiding = false  -- Clear after animation
      ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
    end
    self.bag.fadeOutGroup:Play()
  else
    self.bag.frame:Hide()
    self.isHiding = false  -- Clear immediately
    ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
  end
end
```

**How It Prevents Recursion**:

**Retail:**
- **ESC key**: CloseSpecialWindows → CloseBankFrame() → BANKFRAME_CLOSED → CloseBank() → Hide() → isClosingBank=true, so hooksecurefunc returns early ✅
- **X button**: Hide() → hooksecurefunc sets isClosingBank=true → CloseBankFrame() → BANKFRAME_CLOSED → CloseBank() → Hide() → isClosingBank=true, returns early ✅

**Classic/Era:**
- **ESC key**: CloseSpecialWindows → CloseBankFrame() → BANKFRAME_CLOSED → CloseBank() → Hide() → OnHide() sets isHiding=true → subsequent Hide() calls return early ✅
- **X button**: Hide() → OnHide() sets isHiding=true → subsequent Hide() calls return early ✅

**Key Differences**:
- **Retail**: Uses module-level `isClosingBank` flag in hooksecurefunc + NO CloseBankFrame() in OnHide
- **Classic/Era**: Uses instance-level `isHiding` flag in OnHide + NO hooksecurefunc (skipped via isRetail check)

**When to Apply**:
- Any hooks that call functions triggering events that can loop back
- When debugging stack overflow/recursion issues in event chains
- When implementing bank closing or similar multi-path close mechanisms
- Any version-specific WoW API behavior that differs between Retail and Classic/Era

**Related Files**:
- bags/bank.lua:32-38 (Module-level isClosingBank guard flag)
- bags/bank.lua:723-757 (Retail hooksecurefunc with guard flag)
- bags/era/bank.lua:43-60 (OnHide with isHiding guard, no CloseBankFrame)
- bags/classic/bank.lua:43-60 (OnHide with isHiding guard, no CloseBankFrame)
- core/constants.lua:18-23 (Version detection flags)

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

### Pattern: Always Use Behavior Methods for Programmatic Tab/View Switching
**Problem**: Calling visual-only methods like `tabs:SetTabByID()` or `tabs:SetTabByIndex()` programmatically highlights the tab button but doesn't update bag contents. The tab looks selected but displays the wrong items.

**Why**: WoW addons separate visual presentation from state management for good reason. Visual methods only update the UI (button highlights, colors, borders) but don't:
- Update state variables (`database:SetActiveGroup()`, `bag.bankTab`)
- Set context filters (`ctx:Set("filterBagID", ...)`) that propagate through event chains
- Clear cached data (`items:ClearBankCache()`)
- Trigger refresh events (`bags/RefreshBackpack`, `bags/RefreshBank`)
- Call `ItemButtonUtil.TriggerEvent()` for UI synchronization
- Update Blizzard integration (`BankPanel:SetBankType()`)

**This is the architectural split:**
- **Visual methods** (`SetTabByID`, `SelectTab`): Update button appearance only
- **Behavior methods** (`SwitchToGroup`, `SwitchToCharacterBankTab`, etc.): Complete state management + visual update

Manual clicks work because click handlers call behavior methods, which then call visual methods at the end. Programmatic code that calls visual methods directly bypasses the entire state management chain.

**Solution Pattern**: Always dispatch to the appropriate behavior method based on bag type and context. Never call visual-only methods when you need content to update.

**Example** (from QuickFind integration fix):
```lua
-- BAD: Visual update only, bag contents don't change
local tabID = self:GetTabIDForItem(itemData, bagKind)
if tabID and bag.tabs then
  bag.tabs:SetTabByID(ctx, tabID)  -- Wrong! Only highlights tab
end

-- GOOD: Complete state management via behavior methods
local tabID = self:GetTabIDForItem(itemData, bagKind)
if tabID and bag.behavior then
  if bagKind == const.BAG_KIND.BACKPACK then
    -- Backpack uses group-based tabs
    if bag.behavior.SwitchToGroup then
      bag.behavior:SwitchToGroup(ctx, tabID)
    end
  elseif bagKind == const.BAG_KIND.BANK then
    -- Bank has multiple tab types based on ID range
    if tabID == 1 then
      -- Single bank tab (when character bank tabs disabled)
      if bag.behavior.SwitchToBank then
        bag.behavior:SwitchToBank(ctx)
      end
    elseif tabID >= Enum.BagIndex.CharacterBankTab_1 and tabID <= Enum.BagIndex.CharacterBankTab_6 then
      -- Character bank tabs (6-11)
      if bag.behavior.SwitchToCharacterBankTab then
        bag.behavior:SwitchToCharacterBankTab(ctx, tabID)
      end
    elseif tabID >= Enum.BagIndex.AccountBankTab_1 and tabID <= Enum.BagIndex.AccountBankTab_5 then
      -- Account bank tabs (13-17)
      if bag.behavior.SwitchToAccountBank then
        bag.behavior:SwitchToAccountBank(ctx, tabID)
      end
    else
      -- Fallback for unknown tab types
      if bag.tabs then
        bag.tabs:SetTabByID(ctx, tabID)
      end
    end
  end
end
```

**What Behavior Methods Do** (bags/backpack.lua:342-356, bags/bank.lua:590-667):
1. **Update state**: Set active group/tab in database and bag object
2. **Set context filters**: Add `filterBagID` to context for event chain propagation
3. **Clear caches**: Invalidate stale item data
4. **Update Blizzard integration**: Call `BankPanel:SetBankType()` for right-click behavior
5. **Trigger refresh events**: Send `bags/RefreshBackpack` or `bags/RefreshBank` messages
6. **Synchronize UI**: Call `ItemButtonUtil.TriggerEvent()`
7. **Update visual state**: Call `SetTabByID()` at the end for button highlight

**Debugging Symptom Checklist**:
- ✅ Tab button highlights correctly
- ❌ Bag contents don't update to match tab
- ❌ Previous tab's items still visible
- ❌ Search/filter shows items from wrong tab
- 🔍 **Root cause**: Calling visual methods instead of behavior methods

**When to Apply**:
- Programmatic tab switching (QuickFind integration, slash commands, macros)
- Restoring saved UI state on login/reload
- Automated testing that simulates user clicks
- Any code that needs to "switch tabs as if the user clicked"
- Integration with external addons that trigger view changes

**Related Files**:
- `integrations/quickfind.lua:137-170` - Example fix
- `bags/backpack.lua:342-356` - `SwitchToGroup()` behavior method
- `bags/bank.lua:590-609` - `SwitchToBank()` behavior method
- `bags/bank.lua:613-632` - `SwitchToCharacterBankTab()` behavior method
- `bags/bank.lua:637-667` - `SwitchToAccountBank()` behavior method
- `frames/tabs.lua` - Visual-only methods (for reference, don't call directly)

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

### Pattern: Maintain Feature Parity Across Game Versions
**Problem**: Changes to retail code (frames/\*.lua) that aren't mirrored in Classic Era (frames/era/\*.lua) or Classic (frames/classic/\*.lua) can cause errors or missing features in those versions.

**Why**: BetterBags supports three different WoW clients with separate codebases:
- **Mainline/Retail**: frames/\*.lua
- **Classic Era**: frames/era/\*.lua
- **Classic**: frames/classic/\*.lua

Each version has its own quirks and API differences, but core functionality should work consistently across all versions. When fixing bugs or adding features, it's easy to only update one version and forget the others.

**Solution Pattern**:
1. When making changes to frames/item.lua, check if frames/era/item.lua and frames/classic/item.lua need similar updates
2. When adding new module imports or dependencies, verify all versions have them
3. When fixing bugs, search for similar patterns in other version folders
4. Test changes across all supported game versions when possible
5. In commit messages, note which versions were updated

**Example**:
```lua
// frames/item.lua (retail)
---@class Context: AceModule
local context = addon:GetModule('Context')

// frames/era/item.lua (classic era) - MUST ALSO HAVE THIS
---@class Context: AceModule
local context = addon:GetModule('Context')

// frames/classic/item.lua (classic) - AND THIS TOO
---@class Context: AceModule
local context = addon:GetModule('Context')
```

**When to Apply**:
- After any bug fix that touches version-specific code
- When adding new features that should work across all versions
- When refactoring shared functionality
- During code review - verify all versions are updated consistently

## Form/Settings UI Patterns

### Pattern: Use Anchor Points Instead of Fixed Widths for UI Elements
**Problem**: When creating form elements like text areas or scroll boxes, using `SetWidth(container:GetWidth() - offset)` results in very small or zero-width elements that don't expand properly.

**Why**: When `GetWidth()` is called immediately after creating a frame, the layout engine hasn't calculated the frame's actual width yet. The container's width is determined by anchor points (SetPoint), not by an explicit SetWidth call, so GetWidth() returns 0 or a minimal value at creation time.

**Solution Pattern**: Use anchor points to automatically expand elements with their parent container:
```lua
-- BAD: Fixed width evaluates to 0 or small value immediately
local ScrollBox = CreateFrame("Frame", nil, container, "WowScrollBox")
ScrollBox:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
ScrollBox:SetWidth(container:GetWidth() - 50)  -- container width is 0!

-- GOOD: Anchor to both left and right edges
local ScrollBox = CreateFrame("Frame", nil, container, "WowScrollBox")
ScrollBox:SetPoint("TOPLEFT", container.description, "BOTTOMLEFT", 0, -5)
ScrollBox:SetPoint("RIGHT", container, "RIGHT", -20, 0)  -- Expands automatically
```

**When to Apply**: Any time creating UI elements that should fill available width. Use anchor points for dynamic sizing, not GetWidth() at creation time.

### Pattern: Constrain FontString Width with RIGHT Anchor for Word Wrapping
**Problem**: FontStrings with word wrapping enabled overflow the frame boundaries when description text is long.

**Why**: FontStrings need both word wrap enabled AND width constraints. Even with `SetWordWrap(true)` and `SetNonSpaceWrap(true)`, if the FontString isn't constrained horizontally, it will expand infinitely to fit the text on one line.

**Solution Pattern**: Anchor both left and right sides of the FontString:
```lua
-- BAD: Text overflows frame, no width constraint
container.description = self:createDescription(container, opts.description)
container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)
-- Word wrap is enabled in createDescription, but text still overflows!

-- GOOD: Constrain width with RIGHT anchor
container.description = self:createDescription(container, opts.description)
container.description:SetPoint("TOPLEFT", container.title, "BOTTOMLEFT", 0, -5)
container.description:SetPoint("RIGHT", container, "RIGHT", -20, 0)
```

**When to Apply**: Any multi-line text that should wrap within frame boundaries. Always pair SetWordWrap with width constraints via anchor points.

### Pattern: Module Loading Order for GetModule Calls
**Problem**: Calling `addon:GetModule('ModuleName')` at file scope (outside functions) fails with "Cannot find module" error.

**Why**: Modules are registered during the addon loading process. When a file executes at load time, other module files may not have been loaded and registered yet. The module system only guarantees modules are available after all files are loaded.

**Solution Pattern**: Move GetModule calls inside functions that execute after initialization:
```lua
-- BAD: Called at file load time, module may not exist yet
local serialization = addon:GetModule('Serialization')

function DB:ExportSettings()
  local data = serialization:Serialize(...)  -- May fail
end

-- GOOD: Called when function executes, after all modules loaded
function DB:ExportSettings()
  local serialization = addon:GetModule('Serialization')
  local data = serialization:Serialize(...)  -- Works correctly
end
```

**When to Apply**: Any cross-module dependencies. Always call GetModule inside functions, not at file scope, unless you're certain the module loads earlier in the TOC file.

### Pattern: Accessing Form Element References After Layout
**Problem**: Need to programmatically set text in form TextArea elements, but form:AddTextArea() doesn't return a direct reference to the EditBox.

**Why**: The form API returns container frames, not the actual input elements. The EditBox is stored as `container.input` and isn't available until after the layout is fully created.

**Solution Pattern**: Use delayed lookup via bucket:Later to find the element after layout completes:
```lua
-- Store reference at module level
config.exportTextBox = nil

-- In form creation
f:AddTextArea({
  title = 'Exported Settings',
  getValue = function(_) return "" end,
  setValue = function(_, value)
    if not config.exportTextBox then
      bucket:Later("getExportTextBox", 0.1, function()
        for container, _ in pairs(f.layout.textAreas) do
          if container.title:GetText() == 'Exported Settings' then
            config.exportTextBox = container.input
            break
          end
        end
      end)
    end
  end
})

-- Later, when button is clicked
function onExportClick()
  if config.exportTextBox then
    config.exportTextBox:SetText(exportedData)
    config.exportTextBox:HighlightText()
  end
end
```

**When to Apply**: When you need to programmatically manipulate form elements after creation. Use delayed lookup for accessing the actual input controls within form containers.

## Defensive Programming Against External Addon Interference

### Pattern: Validate Function Parameters from Saved Variables
**Problem**: External addons may modify your saved variables, causing functions expecting valid comparison functions to receive nil or invalid values, resulting in "invalid order function for sorting" errors.

**Why**: WoW addons share the same Lua environment and can access each other's saved variables. Malicious or buggy addons can corrupt your data structures. When you retrieve sort type preferences from saved variables and use them to select comparison functions, an invalid value can result in nil or non-function values being passed to `table.sort()`, causing Lua errors.

**Solution Pattern**: Guard against invalid function parameters at the point of use:
```lua
-- BAD: Assumes fn is always a valid function
function gridProto:Sort(fn)
  table.sort(self.cells, fn)  -- Crashes if fn is nil or not a function
end

-- GOOD: Validate function parameter with safe default
function gridProto:Sort(fn)
  -- Guard against invalid sort functions from external addons modifying saved variables.
  -- Use a no-op comparison function as a safe default to prevent crashes.
  if type(fn) ~= "function" then
    fn = function() return false end
  end
  table.sort(self.cells, fn)
end

-- ALSO GOOD: Provide default at source with defensive fallback
function sort:GetSectionSortFunction(kind, view)
  local sortType = database:GetSectionSortType(kind, view)
  if sortType == const.SECTION_SORT_TYPE.ALPHABETICALLY then
    return function(a, b) return self.SortSectionsAlphabetically(kind, a, b) end
  elseif sortType == const.SECTION_SORT_TYPE.SIZE_ASCENDING then
    return function(a, b) return self.SortSectionsBySizeAscending(kind, a, b) end
  elseif sortType == const.SECTION_SORT_TYPE.SIZE_DESCENDING then
    return function(a, b) return self.SortSectionsBySizeDescending(kind, a, b) end
  end
  -- Return the default alphabetical sort in case of an unknown sort type.
  -- This can happen if external addons modify the saved variables.
  return function(a, b)
    return self.SortSectionsAlphabetically(kind, a, b)
  end
end
```

**When to Apply**:
- Any function that receives callbacks or functions derived from saved variables
- Functions passed to Lua standard library functions that require valid function types (table.sort, pcall, etc.)
- When implementing user-configurable sorting, filtering, or transformation functions
- At module boundaries where external code provides function parameters

## UI Interaction Patterns

### Pattern: Drag-to-Reorder with Module-Level State
**Problem**: Need to implement drag-to-reorder functionality for UI elements (like tabs) that persists order across sessions while avoiding taint.

**Why**: Drag operations span multiple frames and event handlers (OnMouseDown, OnUpdate, OnMouseUp). State must be accessible across these handlers while keeping UI responsive. Module-level state (not frame-level) allows centralized drag management across all tab instances.

**Solution Pattern**:
1. **Module-level state variables**: Store drag state at module level (not per-instance)
2. **Locked axis movement**: Lock Y-axis during horizontal drag to prevent visual jank
3. **50% overlap threshold**: Only trigger reorder when dragged element is 50%+ over target
4. **Debounced slide triggers**: Use `lastOverlapIndex` to prevent redundant reordering
5. **Skip dragging element in reanchor**: Don't reposition the element being dragged
6. **Persist to database**: Save final order to saved variables on drop
7. **Context objects for all handlers**: Use `context:New()` to avoid taint

**Example** (from frames/tabs.lua:29-42, 624-804):
```lua
-- Module-level state (accessible to all tab instances)
tabs.draggingTab = nil              ---@type TabButton?
tabs.dragStartIndex = nil           ---@type number?
tabs.isDragging = false             ---@type boolean
tabs.lastOverlapIndex = nil         ---@type number?

-- Validation helper
function tabs:IsTabReorderable(tab)
  if not tab.id then return false end
  if tab.id == 1 then return false end    -- Bank always first
  if tab.id == 0 then return false end    -- "+" always last
  if tab.id < 0 then return false end     -- Purchase tabs at end
  return true
end

-- Start drag on Shift+LeftClick
decoration:SetScript("OnMouseDown", function(_, button)
  if button == "LeftButton" and IsShiftKeyDown() then
    tabs:StartTabDrag(tab, self)
  end
end)

-- Track cursor position every frame
function tabs:UpdateTabDrag()
  local cursorX = GetCursorPosition()
  local newX = (cursorX - self.dragOffsetX) / scale
  local lockedY = self.dragStartY / scale  -- Y-axis locked

  self.draggingTab:ClearAllPoints()
  self.draggingTab:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", newX, lockedY)

  local targetIndex = self:CalculateOverlapTarget()
  if targetIndex and targetIndex ~= self.lastOverlapIndex then
    self:TriggerSlide(targetIndex)
    self.lastOverlapIndex = targetIndex  -- Debounce
  end
end

-- 50% overlap detection
function tabs:CalculateOverlapTarget()
  local draggedCenter = (self.draggingTab:GetLeft() + self.draggingTab:GetRight()) / 2

  for i, tab in ipairs(self.currentTabFrame.tabIndex) do
    if tab ~= self.draggingTab and self:IsTabReorderable(tab) then
      local tabCenter = (tab:GetLeft() + tab:GetRight()) / 2
      local distance = math.abs(draggedCenter - tabCenter)
      local threshold = (tab:GetRight() - tab:GetLeft()) / 2

      if distance < threshold then
        return i  -- 50%+ overlap detected
      end
    end
  end
  return nil
end

-- Reorder array and reanchor (skip dragging element)
function tabs:TriggerSlide(targetIndex)
  table.remove(self.currentTabFrame.tabIndex, self.draggingTab.index)
  table.insert(self.currentTabFrame.tabIndex, targetIndex, self.draggingTab)

  for i, tab in ipairs(self.currentTabFrame.tabIndex) do
    tab.index = i  -- Re-index
  end

  self.currentTabFrame:ReanchorTabs()  -- Repositions all except draggingTab
end

-- Persist order on drop
function tabs:SaveTabOrder()
  local orderCounter = 2  -- Bank is always 1
  for _, tab in ipairs(self.currentTabFrame.tabIndex) do
    if tab.id and tab.id > 1 then
      database:SetGroupOrder(tab.id, orderCounter)
      orderCounter = orderCounter + 1
    end
  end
  events:SendMessage(ctx, 'groups/OrderChanged')
end

-- Skip dragging element in reanchor
function tabFrame:ReanchorTabs()
  for _, tab in ipairs(self.tabIndex) do
    if tab:IsShown() and tab ~= tabs.draggingTab then  -- Skip dragging tab
      -- Position tab...
    end
  end
end
```

**Database Integration** (core/database.lua:681-694):
```lua
-- Persist order per group
function DB:SetGroupOrder(groupID, order)
  local group = DB.data.profile.groups[groupID]
  if group then
    group.order = order
  end
end

-- Retrieve order for sorting
function DB:GetGroupOrder(groupID)
  local group = DB.data.profile.groups[groupID]
  return group and group.order or groupID  -- Default to ID
end
```

**Sorting Integration** (frames/tabs.lua:197-212):
```lua
-- Sort by custom order instead of ID
if a.id and b.id and a.id > 1 and b.id > 1 then
  local orderA = database:GetGroupOrder(a.id)
  local orderB = database:GetGroupOrder(b.id)
  if orderA ~= orderB then
    return orderA < orderB  -- Use custom order
  end
  return a.id < b.id  -- Fallback to ID
end
```

**When to Apply**:
- Drag-to-reorder for tabs, list items, or any UI elements
- Any reordering that needs to persist across sessions
- When multiple instances share drag behavior (module-level state)
- Horizontal or vertical constrained dragging

**Critical Files**:
- `frames/tabs.lua`: Drag state (29-42), handlers (394-407), functions (624-804)
- `core/database.lua`: Persistence (681-694)

### Pattern: StaticPopup Dialog Data Race Condition
**Problem**: When calling `StaticPopup_Show()` and then setting `dialog.data` on the returned frame, the dialog's `OnShow` callback tries to access `f.data` and gets nil, causing "attempt to index field 'data' (a nil value)" errors.

**Why**: WoW's `StaticPopup_Show()` API triggers the dialog's `OnShow` script synchronously during the Show() call, before the function returns the dialog frame reference. This means:
1. `StaticPopup_Show()` is called
2. Dialog frame is created/retrieved from pool
3. `OnShow` callback executes immediately
4. Function returns dialog frame reference
5. Code tries to set `dialog.data` - too late!

Any code in `OnShow` that accesses `f.data` will fail because the data hasn't been assigned yet.

**Solution Pattern**: Use `StaticPopup_Show()`'s built-in data parameter (4th argument) to pass data to the dialog. The data is assigned to the dialog frame **before** `OnShow` is called:

```lua
-- BAD: Data assignment happens after OnShow fires
local dialog = StaticPopup_Show("BETTERBAGS_RENAME_CATEGORY")
if dialog then
  dialog.data = { categoryName = categoryName, pane = self }  -- Too late!
end

-- Dialog definition with OnShow that fails:
OnShow = function(f)
  f.EditBox:SetText(f.data.categoryName)  -- ERROR: f.data is nil
end

-- GOOD: Pass data as 4th parameter
StaticPopup_Show("BETTERBAGS_RENAME_CATEGORY", nil, nil, { categoryName = categoryName, pane = self })

-- Now OnShow can safely access data:
OnShow = function(f)
  f.EditBox:SetText(f.data.categoryName)  -- Works! f.data is set
end
```

**API Signature**:
```lua
StaticPopup_Show(which, text_arg1, text_arg2, data)
```
- `which`: Dialog name (string)
- `text_arg1`: First text replacement argument (optional)
- `text_arg2`: Second text replacement argument (optional)
- `data`: Data table assigned to `dialog.data` before OnShow (optional)

**When to Apply**:
- Any StaticPopup dialog that has an `OnShow` callback accessing `f.data`
- When you see "attempt to index field 'data' (a nil value)" errors from dialog callbacks
- As a best practice for all dialogs that need data, even without `OnShow` callbacks (for consistency and future-proofing)
- When refactoring existing dialogs that set `dialog.data` after `StaticPopup_Show()`

**Note**: Dialogs that only use data in `OnAccept` or other callbacks (that fire after show) won't error with the old pattern, but should still be updated for consistency and to prevent bugs if someone later adds an `OnShow` callback.

**Related Files**:
- `config/categorypane.lua:354` - Category rename dialog (fixed)
- `bags/backpack.lua:508` - Group rename dialog (fixed)
- `bags/backpack.lua:534` - Group delete confirmation (fixed for consistency)

## Object Pooling Patterns

### Pattern: Always Reset ALL Properties When Releasing Pooled Objects
**Problem**: Pooled objects (like Section frames) retain state from previous use, causing visual glitches or unexpected behavior when reused. For example, a section that was collapsed and dimmed may retain the dimmed color when reused for a different category.

**Why**: Object pools reuse frames/objects for performance. When an object is returned to the pool and later retrieved for a new purpose, any properties not explicitly reset will carry over from the previous usage. This includes:
- Visual properties (colors, alpha, sizes)
- State flags (collapsed, enabled, visible)
- Cached data (item counts, titles, references)
- Custom properties added for features (like `originalTextColor` for collapse dimming)

**Solution Pattern**: In the pool's reset function (typically `_DoReset` or `Wipe`), explicitly reset ALL properties to their default state:

```lua
function sectionProto:Wipe()
  self.content:Wipe()
  self.frame:Hide()
  self.view = const.BAG_VIEW.SECTION_GRID
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
  self.fillWidth = false
  self.frame:SetAlpha(1)

  -- Reset state flags
  self.collapsed = false
  self.shouldShrinkWhenCollapsed = true

  -- Restore visual properties before clearing cached values
  if self.originalTextColor then
    self.title:GetFontString():SetTextColor(
      self.originalTextColor.r,
      self.originalTextColor.g,
      self.originalTextColor.b,
      self.originalTextColor.a
    )
  end

  -- Clear cached properties
  self.originalTextColor = nil
  self.kind = nil
  -- ... reset any other custom properties
end
```

**Critical Guidelines**:
1. **Document new properties**: When adding new fields to pooled objects, add a comment to the reset function reminding future developers to reset them
2. **Visual properties first**: Restore visual state (colors, sizes) BEFORE clearing the cached data needed to restore them
3. **Test with reuse**: After implementing pooling features, verify the object works correctly when released and reused multiple times
4. **Audit existing resets**: When tracking down "random" visual bugs, check if a pooled object's reset function is incomplete

**When to Apply**:
- Any time you add a new property to a pooled object (Section, ItemButton, Grid, etc.)
- When debugging issues where state "randomly" appears or disappears
- During code review of features that modify pooled object properties
- When implementing new visual indicators or state tracking on existing pooled types

### Pattern: Track Active Pooled Frames for Incremental UI Updates
**Problem**: UI elements backed by object pools need lightweight visual refreshes (e.g., recoloring item level text) without forcing full redraws. Pools do not track which objects are currently in use, so there is no safe way to iterate only visible items.

**Why**: The pool only stores inactive objects. Active objects live in other structures and are not centrally tracked. Without an active registry, the only option is expensive full refreshes or unreliable traversal of UI hierarchies.

**Solution Pattern**:
1. Maintain an `activeItems` (or similar) set on the module (prefer weak-key tables to avoid retaining items)
2. Add items to the set on `Acquire`/`Create`
3. Remove items from the set on `Release`
4. Respond to lightweight events (e.g., `itemLevel/MaxChanged`) by iterating the active set and updating visuals

**Example**:
```lua
function itemFrame:OnInitialize()
  self._pool = pool:Create(self._DoCreate, self._DoReset)
  self.activeItems = setmetatable({}, { __mode = "k" })
end

function itemFrame:Create(ctx)
  local item = self._pool:Acquire(ctx)
  self.activeItems[item] = true
  return item
end

function itemFrame.itemProto:Release(ctx)
  itemFrame.activeItems[self] = nil
  itemFrame._pool:Release(ctx, self)
end

function itemFrame:RefreshItemLevelColors(ctx)
  for item in pairs(self.activeItems) do
    if item.slotkey and item.slotkey ~= "" and not item.isFreeSlot then
      item:DrawItemLevel()
    end
  end
end
```

**When to Apply**:
- When a visual update affects many items but does not require data refresh
- When replacing full redraws with lightweight UI updates
- When pooled objects must be updated on global setting changes

## WindowGrouping Integration

### Pattern: Frame-like Objects Must Implement Show/Hide/IsShown and Fade Animations
**Problem**: Custom UI objects added to WindowGrouping (via `windowGrouping:AddWindow()`) fail with "Frame must have fadeIn and fadeOut animations" or cause errors when methods like `Hide()` or `IsShown()` are called.

**Why**: The WindowGrouping system expects all registered frames to behave like standard WoW frames with:
1. **Standard frame methods**: `Show()`, `Hide()`, `IsShown()`
2. **Fade animation groups**: `fadeIn`, `fadeOut` properties
3. **Callback support**: `Hide(callback)` must support optional callback parameter for chained animations

When these requirements aren't met, the window grouping system can't properly coordinate showing/hiding multiple windows with fade animations.

**Solution Pattern**:
1. **Implement Show/Hide/IsShown methods** that delegate to the actual UI frame
2. **Attach fade animations** using `animations:AttachFadeGroup()` on the frame
3. **Support optional callback in Hide()** for animation chaining
4. **Store fadeIn/fadeOut** as properties on the object itself

**Example** (from frames/classic/currency.lua fix):
```lua
-- At module level, import animations
---@class Animations: AceModule
local animations = addon:GetModule('Animations')

-- Define the frame-like class with animation properties
---@class CurrencyIconGrid
---@field iconGrid Grid
---@field fadeIn AnimationGroup
---@field fadeOut AnimationGroup
local CurrencyIconGrid = {}

-- Implement Show/Hide/IsShown methods
function CurrencyIconGrid:Show()
  self.iconGrid.frame:Show()
end

function CurrencyIconGrid:Hide(callback)
  -- Support optional callback parameter used by windowGrouping
  if callback then
    self.fadeOut.callback = callback
    self.fadeOut:Play()
  else
    self.iconGrid.frame:Hide()
  end
end

function CurrencyIconGrid:IsShown()
  return self.iconGrid.frame:IsShown()
end

-- In the constructor, attach fade animations
function currency:CreateIconGrid(parent)
  local b = {}
  setmetatable(b, {__index = CurrencyIconGrid})

  -- Create the grid frame
  local g = grid:Create(parent)
  -- ... configure grid ...
  b.iconGrid = g

  -- Attach fade animations for windowGrouping compatibility
  b.fadeIn, b.fadeOut = animations:AttachFadeGroup(g:GetContainer())

  return b
end

-- Now safe to add to window grouping
b.windowGrouping:AddWindow('currencyConfig', b.currencyFrame)
```

**Reference Implementation** (frames/themeconfig.lua:98):
```lua
-- ThemeConfig frame with proper windowGrouping integration
tc.fadeIn, tc.fadeOut = animations:AttachFadeAndSlideLeft(tc.frame)
-- Methods are inherited from the frame itself
```

**When to Apply**:
- Any custom UI object added to WindowGrouping via `AddWindow()`
- Objects that wrap or encapsulate WoW frames but don't expose frame methods directly
- When seeing errors: "Frame must have fadeIn and fadeOut animations"
- When seeing errors about missing `Hide()`, `Show()`, or `IsShown()` methods
- Before registering a new window type with the window grouping system

### Pattern: Use Discrete Color Tiers to Avoid Unwanted Midpoint Hues
**Problem**: Smooth color blending between distant hues (e.g., blue → orange) can produce unexpected intermediate colors (gray/green) that feel incorrect for item level display.

**Why**: Interpolation traverses hue space, and even with HSV biasing the midpoint can land on colors users do not associate with a given range.

**Solution Pattern**:
1. Compute dynamic breakpoints (low/mid/high/max)
2. Pick the tier color directly based on which range the item level falls into
3. Avoid blending between tiers

**Example**:
```lua
if itemLevel >= maxIlvl then
  return maxColor
elseif itemLevel >= highPoint then
  return highColor
elseif itemLevel >= midPoint then
  return midColor
end
return lowColor
```

**When to Apply**:
- When users expect categorical colors, not gradients
- When midpoints produce unexpected hues

**Critical Requirements Checklist**:
- ✅ `Show()` method exists and shows the frame
- ✅ `Hide()` method exists with optional callback parameter
- ✅ `Hide(callback)` plays fadeOut animation and triggers callback when provided
- ✅ `IsShown()` method exists and returns boolean
- ✅ `fadeIn` property contains AnimationGroup from AttachFadeGroup
- ✅ `fadeOut` property contains AnimationGroup from AttachFadeGroup

**Related Files**:
- `util/windowgroup.lua:16` - Assertion that checks for fadeIn/fadeOut
- `util/windowgroup.lua:21,28,33,34,41` - Calls to IsShown(), Hide(), Show()
- `frames/classic/currency.lua:65-81,168` - Example implementation
- `frames/themeconfig.lua:98` - Reference implementation with AttachFadeAndSlideLeft

## Tooltip API Patterns

### Pattern: GameTooltip:SetText vs AddLine Have Different Signatures (alpha param)
**Problem**: Tooltip text appears off-screen or invisible when using `GameTooltip:SetText()` with word wrap.

**Why**: `SetText` and `AddLine` have **different signatures**:
- `GameTooltip:SetText(text, r, g, b, alpha, textWrap)` — has `alpha` (6 args)
- `GameTooltip:AddLine(text, r, g, b, textWrap)` — NO alpha (5 args)

Passing `true` as the 5th argument to `SetText` sets `alpha=true` (coerced to 1) and leaves `textWrap=nil` (false). Long text without wrapping extends off-screen and is invisible.

**Solution Pattern**:
```lua
-- BAD: true is interpreted as alpha, not textWrap
GameTooltip:SetText("Long tooltip text here...", 1, 1, 1, true)

-- GOOD: include alpha=1 before textWrap=true
GameTooltip:SetText("Long tooltip text here...", 1, 1, 1, 1, true)

-- AddLine does NOT have alpha:
GameTooltip:AddLine("Additional line", 1, 1, 1, true)  -- correct, 5 args
```

**Full tooltip pattern**:
```lua
button:SetScript("OnEnter", function()
  GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
  GameTooltip:SetText("Main title", 1, 1, 1, 1, true)  -- r, g, b, alpha, wrap
  GameTooltip:AddLine("Extra info", 0.8, 0.8, 0.8, true)  -- r, g, b, wrap (no alpha)
  GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)
```

**When to Apply**: Any use of `GameTooltip:SetText()`. Remember alpha comes before textWrap in SetText but AddLine has no alpha parameter.
