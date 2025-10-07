# WoW Addon Development Patterns

## Meta-Rule: Document Evolution
**IMPORTANT**: When you discover new abstract patterns through debugging, problem-solving, or user interaction, you MUST update this document. Add the pattern under the appropriate section with:
- Clear problem statement
- Why it happens
- Solution pattern
- When to apply it

## General Lua Patterns

### Pattern: Always Use Explicit Comparisons in Conditional Statements
**Problem**: Using implicit truthiness checks (like `if someVar then`) can cause IDE type checking issues and makes code less explicit about intent.

**Why**: Lua treats nil and false as falsy, and everything else as truthy. While `if someVar then` works at runtime, it's ambiguous whether you're checking for nil, false, or both. Explicit comparisons make your intent clear and help type checkers understand your code better.

**Solution Pattern**: Always use explicit comparisons with a specific value:
```lua
-- BAD: Implicit truthiness check
if BankPanel then
  BankPanel:Show()
end

if someTable.field then
  DoSomething(someTable.field)
end

-- GOOD: Explicit nil check
if BankPanel ~= nil then
  BankPanel:Show()
end

if someTable.field ~= nil then
  DoSomething(someTable.field)
end

-- GOOD: Explicit boolean check when dealing with actual booleans
if isEnabled == true then
  EnableFeature()
end

if shouldSkip == false then
  ProcessItem()
end

-- GOOD: Explicit empty string/table checks when appropriate
if name ~= "" then
  SetName(name)
end

if #items > 0 then
  ProcessItems(items)
end
```

**When to Apply**:
- All conditional statements (`if`, `elseif`, ternary operators)
- When checking optional function parameters or table fields
- When checking global variables that may or may not exist
- When working with API results that can return nil

## TOC File and Module Loading

### Pattern: Never Load @meta Annotation Files in TOC
**Problem**: Loading Lua files that contain `---@meta` at the top causes runtime errors and unexpected behavior.

**Why**: Files marked with `---@meta` are EmmyLua annotation files meant only for type checking and IDE support. They are NOT executable code and should never be loaded by WoW. Loading them can cause:
- Duplicate definitions
- Runtime errors
- Unexpected nil values
- Blizzard UI errors (like "attempt to call method 'IsShown' (a nil value)")

**Solution Pattern**: Exclude all files with `---@meta` from TOC files:

```lua
-- Check file contents - if it starts with ---@meta, do NOT add to TOC
---@meta

---@class (exact) Bag
---@field window Window
-- This file should NOT be in the TOC!

-- Only load actual implementation files:
# BetterBags Bag Module
bag\stack.lua       -- ✓ Load this (implementation)
bag\bagdata.lua     -- ✓ Load this (implementation)
bag\backpack.lua    -- ✓ Load this (implementation)
bag\bank.lua        -- ✓ Load this (implementation)
# bag\types.lua     -- ✗ DO NOT load (has ---@meta)

# BetterBags Binds Module
binds\binds.lua     -- ✓ Load this (implementation)
# binds\types.lua   -- ✗ DO NOT load (has ---@meta)
```

**Critical Guidelines**:
1. **Check file top before adding to TOC** - Look for `---@meta` marker
2. **Annotation files are for IDE only** - They provide type information, not runtime code
3. **Common naming**: Files named `types.lua`, `annotations.lua`, or containing `@meta` are annotation files
4. **Consistency across TOCs** - All TOC files (mainline, Mists, Vanilla) should exclude the same annotation files

**When to Apply**:
- Every time you add a new Lua file to TOC files
- When reviewing TOC files for consistency
- When debugging unexpected runtime errors related to types or definitions
- When creating new modules with separate type definition files

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

## BetterBags and Moonlight Architecture

### Overview: Framework vs Application Pattern
**Architecture**: BetterBags uses Moonlight as a UI framework library while maintaining its own business logic modules. This creates a clean separation between framework concerns (UI, rendering, data structures) and application concerns (bags, binds, keybindings).

**Key Principles**:
- **Moonlight**: Standalone addon providing framework services (Window, Pool, Section, Render, etc.)
- **BetterBags**: Application that owns bag-specific business logic and uses Moonlight framework
- **Dual Namespace**: Two independent module registration systems that work together
- **Load Order**: Moonlight loads first as OptionalDep, then BetterBags initializes

### Pattern: Dual Namespace System
**Problem**: Need to separate application modules from framework modules while allowing seamless integration.

**Why**: Keeping bag business logic in BetterBags while leveraging Moonlight's framework prevents tight coupling and allows both to evolve independently. BetterBags modules need to access both BetterBags-specific functionality and Moonlight framework components.

**Solution Pattern**: Use two separate accessor functions with clear boundaries:

```lua
-- In BetterBags modules
local bb = GetBetterBags()        -- Access BetterBags application modules
local moonlight = GetMoonlight()  -- Access Moonlight framework modules

-- Register with BetterBags
local myModule = bb:NewClass("myModule")

-- Access BetterBags modules
local backpack = bb:GetBackpack()
local binds = bb:GetBinds()
local bagdata = bb:GetBagdata()
local stack = bb:GetStack()

-- Access Moonlight framework modules
local window = moonlight:GetWindow()
local pool = moonlight:GetPool()
local section = moonlight:GetSection()
local render = moonlight:GetRender()
local event = moonlight:GetEvent()
```

**BetterBags Modules** (registered via `GetBetterBags():NewClass()`):
- `backpack` - Backpack bag implementation with views
- `bank` - Bank bag implementation
- `bagdata` - Bag data management and item organization
- `stack` - Item stack tracking and management
- `binds` - Keybindings and Blizzard bag hiding

**Moonlight Framework Modules** (registered via `GetMoonlight():NewClass()`):
- **UI Components**: Window, Container, Tab, Scrollbox, Grid, Section, Sectionset, Drawable
- **Data Management**: Item, Loader, Pool
- **Rendering**: Render, Animation
- **Theming**: SonataEngine, various theme modules
- **Infrastructure**: Event, Save, Const, Util

**When to Apply**:
- Use `bb:NewClass()` for BetterBags-specific business logic (bags, binds)
- Use `moonlight:GetX()` for framework services (UI, rendering, data structures)
- Always include both namespaces at the top of BetterBags module files

### Pattern: Creating New BetterBags Modules
**Problem**: Need consistent pattern for adding new modules to BetterBags that integrate with Moonlight framework.

**Solution Pattern**: Follow the Moonlight module creation conventions:

```lua
-- 1. Get both namespaces at file top
local bb = GetBetterBags()
local moonlight = GetMoonlight()

-- 2. Register module with BetterBags (lowercase = package accessor)
---@class mymodule
---@field pool Pool
local mymodule = bb:NewClass("mymodule")

-- 3. Define instance class (uppercase = instance)
---@class MyModule
---@field someProperty string
local MyModule = {}

-- 4. Create constructor
---@return MyModule
local mymoduleConstructor = function()
  local instance = {
    someProperty = "default"
  }
  return setmetatable(instance, {
    __index = MyModule
  })
end

-- 5. Create deconstructor
---@param m MyModule
local mymoduleDeconstructor = function(m)
  m.someProperty = nil
end

-- 6. Implement New() method with pooling
---@return MyModule
function mymodule:New()
  if self.pool == nil then
    self.pool = moonlight:GetPool():New(mymoduleConstructor, mymoduleDeconstructor)
  end
  return self.pool:TakeOne("MyModule")
end

-- 7. Implement instance methods
function MyModule:DoSomething()
  -- Access BetterBags modules
  local backpack = bb:GetBackpack()

  -- Access Moonlight framework
  local window = moonlight:GetWindow()
end

-- 8. Implement Boot() if needed for initialization
function mymodule:Boot()
  -- Initialize module after all dependencies loaded
end
```

**Steps to Add Module to BetterBags**:
1. Create module file in appropriate directory (e.g., `mymodule/mymodule.lua`)
2. Add module to TOC files (BetterBags.toc, BetterBags_Mists.toc, BetterBags_Vanilla.toc)
3. Add accessor in `boot/boot.lua`:
```lua
---@return mymodule
function BetterBags:GetMymodule()
  return self.classes.mymodule
end
```
4. Initialize in `boot/boot.lua` Start() if needed:
```lua
local mymod = self:GetMymodule()
mymod:Boot()
```
5. Create README.md in module directory documenting functionality

**When to Apply**: Any time creating new bag-specific functionality in BetterBags.

### Pattern: Load Order and Initialization
**Problem**: BetterBags depends on Moonlight being fully initialized before it can use framework services.

**Why**: Moonlight provides the foundational framework (windows, pooling, events) that BetterBags modules need. If BetterBags tries to access Moonlight before it's initialized, methods and classes won't be available.

**Solution Pattern**: Leverage WoW's addon dependency system:

```lua
-- In BetterBags TOC files
## OptionalDeps: ..., Moonlight

-- Load order guaranteed by WoW:
-- 1. Moonlight loads as standalone addon
-- 2. Moonlight:Load() -> ADDON_LOADED -> Moonlight:Start()
-- 3. BetterBags loads (Moonlight already initialized)
-- 4. BetterBags:Load() -> ADDON_LOADED -> BetterBags:Start()
-- 5. BetterBags boots its modules (can safely use Moonlight)

function BetterBags:Start()
  -- Moonlight is already initialized, just use it
  local backpack = self:GetBackpack()
  local bank = self:GetBank()
  local binds = self:GetBinds()

  backpack:Boot()
  bank:Boot()
  binds:Boot()

  -- Trigger bag data refresh
  local moonlight = GetMoonlight()
  C_Timer.After(1, function()
    moonlight:GetLoader():FullRefreshAllBagData()
  end)
end
```

**Critical Guidelines**:
1. **Never call `moonlight:Load()`** - Moonlight loads itself as standalone addon
2. **OptionalDeps declares dependency** - WoW ensures load order
3. **Start() can immediately use Moonlight** - No need to wait or check
4. **Both call FullRefreshAllBagData()** - Moonlight calls it for standalone use, BetterBags calls it after bag initialization

**When to Apply**: All BetterBags initialization code. Never try to initialize or load Moonlight from BetterBags.

### Pattern: Module Dependencies and Cross-References
**Problem**: BetterBags modules need to reference each other and Moonlight modules without creating circular dependencies.

**Why**: Modules load in TOC order, but instance creation happens at runtime. If you call GetModule at file scope, the target module may not be registered yet.

**Solution Pattern**: Always get module references inside functions, not at file scope:

```lua
-- BAD: Module may not be registered yet at file scope
local bb = GetBetterBags()
local backpack = bb:GetBackpack()  -- May be nil!

function binds:DoSomething()
  backpack:Show()  -- Will fail
end

-- GOOD: Get module reference when function executes
local bb = GetBetterBags()

function binds:DoSomething()
  local backpack = bb:GetBackpack()  -- Now it's registered
  backpack:Show()  -- Works correctly
end

-- ALSO GOOD: Cache in Boot() for repeated use
local bb = GetBetterBags()
local binds = bb:NewClass("binds")

local cachedBackpack  -- Declare at module scope

function binds:Boot()
  -- Cache references after all modules loaded
  cachedBackpack = bb:GetBackpack():GetBackpack()
end

function binds:DoSomething()
  cachedBackpack:Show()  -- Use cached reference
end
```

**When to Apply**:
- Any cross-module references in BetterBags
- References to Moonlight framework modules
- Inside Boot() methods for modules that need initialization
- Inside instance methods that run after Boot() phase

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

## WoW Bank System Architecture

### Bank Type Hierarchy
- **Character Bank**: Bags 6-11 (Enum.BagIndex.CharacterBankTab_1 through CharacterBankTab_6)
- **Account Bank**: Bags 13-17 (Enum.BagIndex.AccountBankTab_1 through AccountBankTab_5)
- **Reagent Bank**: Special bag (Enum.BagIndex.Reagentbank)

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

## Defensive Programming Against External Addon Interference

### Pattern: Validate Function Parameters from Saved Variables
**Problem**: External addons may modify your saved variables, causing functions expecting valid comparison functions to receive nil or invalid values, resulting in "invalid order function for sorting" errors.

**Why**: WoW addons share the same Lua environment and can access each other's saved variables. Malicious or buggy addons can corrupt your data structures. When you retrieve sort type preferences from saved variables and use them to select comparison functions, an invalid value can result in nil or non-function values being passed to `table.sort()`, causing Lua errors.

**Solution Pattern**: Guard against invalid function parameters at the point of use:
```lua
-- BAD: Assumes fn is always a valid function
function MyObject:Sort(fn)
  table.sort(self.items, fn)  -- Crashes if fn is nil or not a function
end

-- GOOD: Validate function parameter with safe default
function MyObject:Sort(fn)
  -- Guard against invalid sort functions from external addons modifying saved variables.
  -- Use a no-op comparison function as a safe default to prevent crashes.
  if type(fn) ~= "function" then
    fn = function() return false end
  end
  table.sort(self.items, fn)
end

-- ALSO GOOD: Provide default at source with defensive fallback
function GetSortFunction(sortType)
  if sortType == "alphabetical" then
    return function(a, b) return a.name < b.name end
  elseif sortType == "ascending" then
    return function(a, b) return a.value < b.value end
  elseif sortType == "descending" then
    return function(a, b) return a.value > b.value end
  end
  -- Return a default sort in case of an unknown sort type.
  -- This can happen if external addons modify the saved variables.
  return function(a, b) return a.name < b.name end
end
```

**When to Apply**:
- Any function that receives callbacks or functions derived from saved variables
- Functions passed to Lua standard library functions that require valid function types (table.sort, pcall, etc.)
- When implementing user-configurable sorting, filtering, or transformation functions
- At module boundaries where external code provides function parameters

## Object Pooling Patterns

### Pattern: Always Reset ALL Properties When Releasing Pooled Objects
**Problem**: Pooled objects retain state from previous use, causing visual glitches or unexpected behavior when reused. For example, a frame that was colored red may retain that color when reused for a different purpose.

**Why**: Object pools reuse frames/objects for performance. When an object is returned to the pool and later retrieved for a new purpose, any properties not explicitly reset will carry over from the previous usage. This includes:
- Visual properties (colors, alpha, sizes)
- State flags (collapsed, enabled, visible)
- Cached data (item counts, titles, references)
- Custom properties added for features

**Solution Pattern**: In the pool's reset function (typically `_DoReset` or `Wipe`), explicitly reset ALL properties to their default state:

```lua
function pooledObject:Reset()
  -- Hide and clear frame properties
  self.frame:Hide()
  self.frame:ClearAllPoints()
  self.frame:SetParent(nil)
  self.frame:SetAlpha(1)

  -- Reset visual properties
  if self.frame.texture then
    self.frame.texture:SetColorTexture(1, 1, 1, 1)
  end

  -- Reset state flags
  self.isActive = false
  self.isExpanded = false

  -- Restore cached visual properties before clearing them
  if self.originalColor then
    self.frame:SetBackdropColor(
      self.originalColor.r,
      self.originalColor.g,
      self.originalColor.b,
      self.originalColor.a
    )
  end

  -- Clear cached properties
  self.originalColor = nil
  self.data = nil
  -- ... reset any other custom properties
end
```

**Critical Guidelines**:
1. **Document new properties**: When adding new fields to pooled objects, add a comment to the reset function reminding future developers to reset them
2. **Visual properties first**: Restore visual state (colors, sizes) BEFORE clearing the cached data needed to restore them
3. **Test with reuse**: After implementing pooling features, verify the object works correctly when released and reused multiple times
4. **Audit existing resets**: When tracking down "random" visual bugs, check if a pooled object's reset function is incomplete

**When to Apply**:
- Any time you add a new property to a pooled object
- When debugging issues where state "randomly" appears or disappears
- During code review of features that modify pooled object properties
- When implementing new visual indicators or state tracking on existing pooled types

## SlotKey Parsing

### Pattern: Use util:GetBagAndSlotFromSlotkey() Instead of Custom Regex
**Problem**: Need to extract bagID and slotID from SlotKey strings (format "bagID_slotID").

**Why**: Custom regex parsing with `string.match` and `tonumber` is error-prone and requires manual nil guards. Moonlight provides a typed utility function that handles parsing correctly.

**Solution Pattern**: Always use the Moonlight util module's parsing function:

```lua
-- BAD: Custom regex parsing without nil guards
local bagID = tonumber(string.match(slotKey, "^(%d+)_"))
if isBankBag(bagID) then  -- bagID could be nil!
  -- ...
end

-- ALSO BAD: Custom parsing even with correct API
local bagid, slotid = strsplit('_', slotKey)
local bagNum = tonumber(bagid)  -- Duplicating logic that exists in framework

-- GOOD: Use framework utility with strong typing
local util = moonlight:GetUtil()
local bagID, slotID = util:GetBagAndSlotFromSlotkey(slotKey)
-- Type checker ensures proper nil handling via return type annotations
```

**When to Apply**: Any time you need to parse a SlotKey string into its component bag and slot IDs. The framework's strong typing ensures the editor will warn about potential nil values.

## WoW Asynchronous Item Loading

### Pattern: Bag Items Must Be Loaded Before Querying Bag Properties
**Problem**: `C_Container.GetBagName()` returns `nil` even for valid equipped bags, causing crashes when trying to format strings with bag names.

**Why**: Bags themselves are items that need asynchronous loading through WoW's item data system. Just like items in bags need `ContinueOnItemLoad()`, the bag items themselves (equipped in bag slots) also need to be loaded before their properties (name, icon, etc.) become available.

**Critical Understanding**:
- A bag is an item equipped in a container slot
- `C_Container.GetBagName()` queries the bag item's cached name property
- This property is `nil` until the bag item goes through `ContinuableContainer:ContinueOnItemLoad()`
- You cannot synchronously query bag properties at addon load time or immediately after bag updates
- This is NOT a case for defensive nil guards - it's an API contract violation if bag names are nil when item data is being read

**Solution Pattern**: Two-phase loading in the data loader (implemented in Moonlight's loader):

```lua
-- Phase 1: Load bag items themselves
function loader:LoadBagItems(bagSet, callback)
  local bagMixins = {}
  for bagID in pairs(bagSet) do
    -- Don't create mixins for special bags that don't have item representations
    if bagID ~= Enum.BagIndex.Backpack and bagID ~= Enum.BagIndex.Reagentbank then
      -- Use C_Container.ContainerIDToInventoryID to convert bagID to inventory slot
      local bagSlotIndex = C_Container.ContainerIDToInventoryID(bagID)
      if bagSlotIndex ~= nil then
        local itemLocation = ItemLocation:CreateFromEquipmentSlot(bagSlotIndex)
        if C_Item.DoesItemExist(itemLocation) then
          local mixin = Item:CreateFromItemLocation(itemLocation)
          table.insert(bagMixins, mixin)
        end
      end
    end
  end

  local continue = ContinuableContainer:Create()
  for _, mixin in pairs(bagMixins) do
    continue:AddContinuable(mixin)
  end
  continue:ContinueOnLoad(callback)
end

-- Phase 2: After bags loaded, cache their names and then load contents
loader:LoadBagItems(bags, function()
  -- NOW C_Container.GetBagName() will return valid data
  for bagID in pairs(bags) do
    local bagName = C_Container.GetBagName(bagID)
    cacheTable[bagID] = bagName or GetFallbackName(bagID)
  end
  -- Continue loading bag contents...
end)
```

**Application Code Pattern**: Use cached bag names from the loader:
```lua
-- BAD: Directly querying C_Container.GetBagName during item read
function MoonlightItem:ReadItemData()
  self.itemData.BagName = C_Container.GetBagName(self.itemData.BagID)
  -- This will be nil if bag item hasn't loaded yet!
end

-- GOOD: Use loader's cached bag name (loaded during Phase 1)
function MoonlightItem:ReadItemData()
  local loader = moonlight:GetLoader()
  self.itemData.BagName = loader:GetBagName(self.itemData.BagID)
  -- Loader guarantees this is always a string
end
```

**When to Apply**:
- Any time querying container/bag properties (name, icon, type)
- Loading bag contents - always load bags first
- Initialization code that displays bag information
- Any API starting with `C_Container.GetBag*()` - the bag must be loaded first

**Related APIs That Require Loaded Bags**:
- `C_Container.GetBagName(bagID)` - requires bag item loaded via ContinuableContainer
- `C_Container.GetBagSlotFlag(bagID)` - requires bag item loaded
- `C_Container.ContainerIDToInventoryID(bagID)` - converts container ID to inventory slot ID (for creating ItemLocation)
- Any property of the bag item itself needs async loading through the item system

**Why Not Nil Guards**: This pattern is about API correctness. The framework (Moonlight) guarantees that `ItemData.BagName` is always a string. Adding nil guards in application code (BetterBags) would mask the real issue - that bags weren't loaded properly. The fix belongs in the framework's loading sequence, not in defensive programming at usage sites.

## Performance Patterns

### Pattern: Use Set (Table) for O(1) Membership Testing Instead of Nested Loops
**Problem**: Using nested loops to check if an item exists in a collection results in O(n²) time complexity, causing performance issues with large datasets.

**Why**: In Lua, checking membership with nested loops requires iterating through the entire inner collection for each element in the outer collection. For example, checking if 100 items are placeholders by comparing against 100 item buttons requires ~10,000 comparisons (100 × 100). This becomes a significant bottleneck during frequent operations like bag updates.

**Solution Pattern**: Convert the collection to a Lua table used as a Set, enabling O(1) constant-time lookups:

```lua
-- BAD: O(n²) nested loop for membership testing
local placeholders = {}
for _, child in ipairs(allGridChildren) do        -- O(n)
  local isPlaceholder = true
  for _, itemButton in ipairs(children) do        -- O(n) - nested!
    if child == itemButton then
      isPlaceholder = false
      break
    end
  end
  if isPlaceholder == true then
    table.insert(placeholders, child)
  end
end
-- Time complexity: O(n²) where n = number of children

-- GOOD: O(n) Set-based membership testing
local placeholders = {}

-- First, create a Set of actual item buttons for O(1) lookup
local itemButtonSet = {}
for _, itemButton in ipairs(children) do          -- O(n)
  itemButtonSet[itemButton] = true
end

-- Now identify placeholders in O(n) time
for _, child in ipairs(allGridChildren) do        -- O(n)
  -- Set membership check is O(1)
  if itemButtonSet[child] ~= true then
    table.insert(placeholders, child)
  end
end
-- Total time complexity: O(n) where n = number of children
```

**Real-World Example from BetterBags**:
```lua
-- From bag/bagdata.lua - Placeholder identification during sort key assignment
-- Build set of sort keys already occupied by placeholders.
-- Performance optimization: Use a Set (Lua table) for O(1) lookups instead of nested O(n²) loop.

local grid = section.grid
local allGridChildren = grid:GetChildren()
local occupiedSortKeys = {}

-- First, create a Set of actual item buttons for O(1) lookup
local itemButtonSet = {}
for _, itemButton in ipairs(children) do
  itemButtonSet[itemButton] = true
end

-- Now identify placeholders in O(n) time instead of O(n²)
for _, child in ipairs(allGridChildren) do
  -- Check if this child is a placeholder by checking Set membership
  -- Per patterns.md: use explicit comparison instead of implicit truthiness
  if itemButtonSet[child] ~= true then
    occupiedSortKeys[child:GetSortKey()] = true
  end
end
```

**Performance Impact**:
- **Before**: O(n²) - For 100 items: ~10,000 operations
- **After**: O(n) - For 100 items: ~200 operations
- **Speedup**: 50x faster for 100 items, scales better with more items

**When to Apply**:
- Any time checking if items exist in a collection within a loop
- Filtering operations that compare two lists (e.g., finding differences)
- Identifying duplicates or unique items
- Operations called frequently (e.g., during bag updates, sorting, rendering)
- When profiling reveals nested loops as a bottleneck

**Additional Tips**:
1. **Set Construction**: Build the Set once, reuse for multiple lookups
2. **Memory Trade-off**: Sets use extra memory but provide massive speed gains
3. **Explicit Comparisons**: Always use `~= true` for Set membership checks (per General Lua Patterns)
4. **Document Algorithm**: Add comments explaining the optimization for future maintainers

**Lua Table as Set Pattern**:
```lua
-- Creating a Set from an array
local mySet = {}
for _, value in ipairs(myArray) do
  mySet[value] = true
end

-- Checking membership (O(1))
if mySet[someValue] == true then
  -- Value is in the set
end

-- Removing from Set (O(1))
mySet[someValue] = nil

-- Iterating over Set
for value in pairs(mySet) do
  -- Process value
end
```

**Alternative: Table Contains Helper** (if frequently used):
```lua
-- Utility function for repeated use
local function tableContains(tbl, item)
  for _, value in ipairs(tbl) do
    if value == item then
      return true
    end
  end
  return false
end

-- Use this for small collections or infrequent checks
-- For large collections or frequent checks, use the Set pattern above
```

**When NOT to Use Sets**:
- Very small collections (< 10 items) where nested loop overhead is negligible
- One-time checks where Set construction overhead outweighs the benefit
- When the order of elements matters and you need array operations
- Memory-constrained environments where the extra table would cause issues

## Code Organization Patterns

### Pattern: Extract Magic Numbers and Repeated Values to Constants Module
**Problem**: Hardcoded values (magic numbers, repeated strings, configurations) scattered throughout code make maintenance difficult and error-prone. Changes require hunting through multiple files, and it's unclear which values are related or should stay synchronized.

**Why**: Magic numbers and repeated values create several issues:
- **Unclear Intent**: `SetWidth(300)` doesn't explain why 300 was chosen
- **Difficult Updates**: Changing a value requires finding all occurrences
- **Inconsistency Risk**: Easy to miss instances when updating
- **No Single Source of Truth**: Same conceptual value might be duplicated with slight variations
- **Poor Discoverability**: Hard to find what values are configurable

**Solution Pattern**: Create a dedicated constants module as a single source of truth:

```lua
-- bag/constants.lua
local bb = GetBetterBags()

---@class bagconstants
local bagconstants = bb:NewClass("bagconstants")

-- Window Dimensions
bagconstants.BACKPACK_DEFAULT_WIDTH = 300
bagconstants.BANK_DEFAULT_WIDTH = 400
bagconstants.DEFAULT_WINDOW_HEIGHT = 500

-- UI Configuration
bagconstants.TAB_SPACING = 4
bagconstants.TAB_HOVER_ANIMATION_DISTANCE = 3
bagconstants.TAB_HOVER_ANIMATION_DURATION = 0.1

-- Bag Filters (reusable table)
bagconstants.ALL_BACKPACK_BAGS = {
  [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true
}

-- String Constants
bagconstants.NEW_ITEMS_SECTION = "New Items"
bagconstants.ALL_ITEMS_SECTION = "All Items"

-- Then use in other modules:
local bagconst = bb:GetBagConstants()
Backpack.window:SetWidth(bagconst.BACKPACK_DEFAULT_WIDTH)
```

**Benefits of This Approach**:
1. **Self-Documenting**: Constant names explain their purpose
2. **Easy Updates**: Change once, affects all usages
3. **Type Safety**: EmmyLua annotations provide IDE support
4. **Discoverability**: All configurable values in one place
5. **Reusability**: Share common configurations across modules

**What to Extract**:

**Always Extract**:
- Numeric dimensions and sizes: `300`, `500`, `10`
- Animation timings and distances: `0.1`, `3`, `7`
- Repeated string literals: `"New Items"`, `"All Items"`
- Repeated table configurations: BagFilter tables used multiple times
- Alpha/opacity values: `0`, `0.5`, `1`
- Loop bounds that represent system limits: `for i = 1, 6 do`

**Sometimes Extract** (use judgment):
- Single-use values that are self-explanatory in context
- Values that are truly arbitrary and unlikely to change
- Calculations where the formula is more important than the result

**Never Extract**:
- Boolean literals: `true`, `false` (unless part of a configuration)
- Common integers in obviously correct contexts: `for i = 1, #array do`
- String literals that are unique identifiers: `"backpack_frame_123"`

**Naming Conventions**:
- `SCREAMING_SNAKE_CASE` for constants
- Group related constants with prefixes: `TAB_*`, `WINDOW_*`, `DEFAULT_*`
- Be specific: `BACKPACK_DEFAULT_WIDTH` not just `WIDTH`

**Organization Example from BetterBags**:
```lua
-- Before: Magic numbers scattered across 3 files
-- backpack.lua
Backpack.bagWidth = 300
Backpack.window:SetHeight(500)
BagFilter = {[0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true}
HeaderSections = {"New Items"}

-- bank.lua
Bank.bagWidth = 400
Bank.window:SetHeight(500)  -- Duplicate of 500!
HeaderSections = {"New Items"}  -- Duplicate string!

-- binds.lua
for i = 1, 6 do  -- What does 6 represent?
  _G["ContainerFrame"..i]:SetParent(sneaky)
end

-- After: Centralized constants
-- bag/constants.lua
bagconstants.BACKPACK_DEFAULT_WIDTH = 300
bagconstants.BANK_DEFAULT_WIDTH = 400
bagconstants.DEFAULT_WINDOW_HEIGHT = 500
bagconstants.ALL_BACKPACK_BAGS = {[0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true}
bagconstants.NEW_ITEMS_SECTION = "New Items"
bagconstants.MAX_BLIZZARD_CONTAINER_FRAMES = 6

-- Usage is now clear and consistent
local bagconst = bb:GetBagConstants()
Backpack.bagWidth = bagconst.BACKPACK_DEFAULT_WIDTH
Backpack.window:SetHeight(bagconst.DEFAULT_WINDOW_HEIGHT)
BagFilter = bagconst.ALL_BACKPACK_BAGS
HeaderSections = {bagconst.NEW_ITEMS_SECTION}
for i = 1, bagconst.MAX_BLIZZARD_CONTAINER_FRAMES do
```

**Implementation Steps**:
1. **Audit**: Search codebase for numeric literals and repeated strings
2. **Group**: Categorize constants by purpose (dimensions, timing, configuration, etc.)
3. **Create Module**: Make a dedicated constants.lua file
4. **Document**: Add comments explaining what each constant controls
5. **Register**: Add module to TOC and create accessor function
6. **Refactor**: Replace magic numbers with constant references
7. **Test**: Verify behavior is identical after refactoring

**Module Integration Pattern**:
```lua
-- In boot/boot.lua - Add accessor
---@return bagconstants
function BetterBags:GetBagConstants()
  return self.classes.bagconstants
end

-- In TOC files - Load constants early
bag\constants.lua    # Before other bag modules
bag\stack.lua
bag\bagdata.lua

-- In consuming modules - Get constants at top
local bb = GetBetterBags()
local bagconst = bb:GetBagConstants()  -- Available to entire module
```

**Advanced: Configuration Tables**:
For complex configurations, use nested tables:
```lua
bagconstants.TAB_CONFIG = {
  Spacing = 4,
  HoverAnimation = {
    Distance = 3,
    Duration = 0.1
  },
  SelectedAnimation = {
    Distance = 7
  }
}

-- Usage
local cfg = bagconst.TAB_CONFIG
container:CreateTabs({
  Spacing = cfg.Spacing,
  HoverAnimationDistance = cfg.HoverAnimation.Distance,
})
```

**When to Apply**:
- During initial development when patterns emerge
- When refactoring existing code
- When the same value appears 2+ times
- When values might need adjustment for different game clients
- When preparing code for user configuration features

**Maintenance**:
- Review constants module periodically for unused entries
- Remove constants that become obsolete
- Keep comments updated when purpose changes
- Consider splitting very large constants modules by domain
