# Bags Module

This directory contains bag-type-specific behavior implementations that decouple the bag concept from its concrete implementations (Backpack and Bank).

## Architecture

BetterBags uses a **Composition with Strategy Pattern** to separate shared bag functionality from implementation-specific behavior.

```
BagFrame (shared core in frames/bag.lua)
  └── behavior: BagBehavior (injected at creation)
        ├── BackpackBehavior (bags/backpack.lua)
        └── BankBehavior (bags/bank.lua)
              ├── bags/era/bank.lua (overrides for Classic Era)
              └── bags/classic/bank.lua (overrides for Classic)
```

## Behavior Interface

Each behavior module implements the following core interface:

```lua
---@class BagBehavior
---@field OnShow fun(ctx: Context, bag: Bag): void       -- Called when bag is shown
---@field OnHide fun(ctx: Context, bag: Bag): void       -- Called when bag is hidden
---@field OnCreate fun(ctx: Context, bag: Bag): void     -- Called during bag creation
---@field OnRefresh fun(ctx: Context, bag: Bag): void    -- Called when bag refreshes
---@field GetFrameStrata fun(): FrameStrata              -- Returns frame strata
---@field GetFrameLevel fun(): number|nil                -- Returns frame level (nil for default)
---@field SetupMoneyFrame fun(bag: Bag, bottomBar: Frame): Money|nil  -- Creates money frame
---@field RegisterEvents fun(bag: Bag): void             -- Registers behavior-specific events
---@field ShouldHandleSort fun(): boolean                -- Whether sorting is enabled
---@field SwitchToBankAndWipe fun(ctx: Context, bag: Bag): void  -- Reset bank to default state
```

### Bank-Specific Methods

The BankBehavior also implements these bank-specific methods (not part of BackpackBehavior):

```lua
-- Tab management
---@field GenerateCharacterBankTabs fun(ctx: Context, bag: Bag): void
---@field GenerateWarbankTabs fun(ctx: Context, bag: Bag): void
---@field GetWarbankTabDataByID fun(id: number): BankTabData
---@field HideBankAndReagentTabs fun(bag: Bag): void
---@field ShowBankAndReagentTabs fun(bag: Bag): void

-- Tab switching
---@field SwitchToBank fun(ctx: Context, bag: Bag): void
---@field SwitchToCharacterBankTab fun(ctx: Context, tabID: number, bag: Bag): void
---@field SwitchToAccountBank fun(ctx: Context, tabIndex: number, bag: Bag): boolean
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

### bank.lua

Implements `BankBehavior` for the player's bank (retail version).

**Features:**
- BankPanel management (critical for avoiding taint)
- Character bank tabs (individual bag tabs)
- Warbank/Account bank tabs
- Tab settings menu integration
- Bank-specific event handling

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
2. Based on `BAG_KIND`, it instantiates the appropriate behavior:
   - `const.BAG_KIND.BACKPACK` → `BackpackBehavior:Create()`
   - `const.BAG_KIND.BANK` → `BankBehavior:Create()`
3. The bag stores the behavior as `self.behavior`
4. Bag methods delegate to behavior:
   - `bag:Show()` → `self.behavior:OnShow(ctx, self)`
   - `bag:Hide()` → `self.behavior:OnHide(ctx, self)`
   - etc.

## Adding New Behaviors

To add a new bag type (e.g., Guild Bank):

1. Create `bags/guildbank.lua` with `GuildBankBehavior` module
2. Implement all interface methods
3. Update `frames/bag.lua` to instantiate it for the new `BAG_KIND`
4. Add version-specific overrides if needed

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
