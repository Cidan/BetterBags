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
