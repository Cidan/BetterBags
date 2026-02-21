# Bags Module

This directory contains bag-type-specific behavior implementations that decouple the bag concept from its concrete implementations (Backpack and Bank).

## Architecture

BetterBags uses a **Composition with Strategy Pattern** to separate shared bag functionality from implementation-specific behavior. Each behavior instance stores a reference to its parent bag, allowing methods to access bag state via `self.bag`.

```
BagFrame (shared core in frames/bag.lua)
  └── behavior: BagBehavior (injected at creation)
        ├── BackpackBehavior (bags/backpack.lua)
        └── BankBehavior (bags/bank.lua)
              ├── bags/era/bank.lua (overrides for Classic Era)
              └── bags/classic/bank.lua (overrides for Classic)
```

## Behavior Interface

Each behavior module implements the following core interface. The bag reference is stored on the behavior instance during `Create(bag)` and accessed via `self.bag`:

```lua
---@class BagBehavior
---@field bag Bag                                       -- Reference to parent bag (set in Create)
---@field OnShow fun(ctx: Context): void                -- Called when bag is shown
---@field OnHide fun(ctx: Context): void                -- Called when bag is hidden
---@field OnCreate fun(ctx: Context): void              -- Called during bag creation
---@field OnRefresh fun(ctx: Context): void             -- Called when bag refreshes
---@field GetFrameStrata fun(): FrameStrata             -- Returns frame strata
---@field GetFrameLevel fun(): number|nil               -- Returns frame level (nil for default)
---@field SetupMoneyFrame fun(bottomBar: Frame): Money|nil  -- Creates money frame
---@field RegisterEvents fun(): void                    -- Registers behavior-specific events
---@field ShouldHandleSort fun(): boolean               -- Whether sorting is enabled
---@field SwitchToBankAndWipe fun(ctx: Context): void   -- Reset bank to default state
```

### Parameter Conventions

- Methods access the parent bag via `self.bag` (set during `Create(bag)`)
- `ctx` parameter is passed to methods that need it for event handling or async operations
- Methods that don't need `ctx` simply don't declare it (Lua ignores extra arguments)
- `bottomBar` is passed to `SetupMoneyFrame` as the anchor point

### Bank-Specific Methods

The BankBehavior also implements these bank-specific methods (not part of BackpackBehavior):

```lua
-- Tab management
---@field GenerateCharacterBankTabs fun(ctx: Context): void
---@field GenerateWarbankTabs fun(ctx: Context): void
---@field GetWarbankTabDataByID fun(id: number): BankTabData
---@field HideBankAndReagentTabs fun(): void
---@field ShowBankAndReagentTabs fun(): void

-- Tab switching
---@field SwitchToBank fun(ctx: Context): void
---@field SwitchToCharacterBankTab fun(ctx: Context, tabID: number): void
---@field SwitchToAccountBank fun(ctx: Context, tabIndex: number): boolean
```

## Files

### backpack.lua

Implements `BackpackBehavior` for the player's inventory bags.

**Features:**
- Search frame
- Bag slots panel
- Currency display
- Theme configuration
- Cooldown event handling
- Bag sorting
- Group tab management with right-click context menu (Rename/Delete)

**Group Tab Context Menu:**
Right-clicking any user-created tab (ID > 1) shows a context menu with Rename and Delete options. The default "Backpack" tab (ID 1) does not show a context menu. Both `groups:RenameGroup` and `groups:DeleteGroup` are called with `const.BAG_KIND.BACKPACK` as the `kind` argument.

### bank.lua

Implements `BankBehavior` for the player's bank (retail version).

**Features:**
- BankPanel management (critical for avoiding taint)
- Character bank tabs (individual bag tabs)
- Warbank/Account bank tabs
- Tab settings menu integration
- Bank-specific event handling
- Group tab management with right-click context menu (Rename/Delete)

**Bank Group Tab Context Menu:**
Right-clicking any user-created bank tab (non-default, ID > 0) shows a context menu with Rename and Delete options. Default bank groups (those with `isDefault = true`) do not show the context menu. Rename uses the `GroupDialog` module (pre-filled with the current name). Delete uses the `Question` module's `YesNo` dialog.

**Critical Notes:**
- BankPanel must be shown for `GetActiveBankType()` to work
- BankPanel must be hidden on close to prevent taint
- Use `BankPanel:SetBankType()` method, never direct field assignment
- See `.context/patterns.md` for detailed taint avoidance patterns

### era/bank.lua (Version Override)

Overrides bank behavior for Classic Era:
- No BankPanel (doesn't exist in Era)
- No tabs system
- Simpler bank structure

### classic/bank.lua (Version Override)

Overrides bank behavior for Classic (Cata, MoP):
- Similar to Era but with version-specific differences

## How It Works

1. `frames/bag.lua` creates a new bag instance
2. Based on `BAG_KIND`, it instantiates the appropriate behavior with the bag reference:
   - `const.BAG_KIND.BACKPACK` → `BackpackBehavior:Create(b)`
   - `const.BAG_KIND.BANK` → `BankBehavior:Create(b)`
3. The behavior stores `self.bag = bag` for later access
4. Bag methods delegate to behavior:
   - `bag:Show(ctx)` → `self.behavior:OnShow(ctx)`
   - `bag:Hide(ctx)` → `self.behavior:OnHide(ctx)`
   - `bag:Refresh(ctx)` → `self.behavior:OnRefresh(ctx)`
   - etc.

## Adding New Behaviors

To add a new bag type (e.g., Guild Bank):

1. Create `bags/guildbank.lua` with `GuildBankBehavior` module
2. Implement all interface methods using `self.bag` pattern
3. Implement `Create(bag)` that stores the bag reference
4. Update `frames/bag.lua` to instantiate it for the new `BAG_KIND`
5. Add version-specific overrides if needed

## Load Order

Behavior modules must load **before** `frames/bag.lua`:

```
# In BetterBags.toc
bags\backpack.lua
bags\bank.lua
...
frames\bag.lua
```

Version-specific overrides load **after** base behavior:

```
# In BetterBags_Vanilla.toc
bags\backpack.lua
bags\bank.lua
bags\era\bank.lua    # Overrides bank.proto methods
...
frames\bag.lua
```
