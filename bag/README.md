# Bag Module

The bag module provides the core bag management functionality for BetterBags, including backpack and bank implementations. This module was migrated from the Moonlight framework to BetterBags and acts as the primary business logic layer for bag operations.

## Architecture

The bag module uses a hybrid architecture:
- **Module Registration**: Modules are registered with BetterBags via `GetBetterBags():NewClass()`
- **Framework Integration**: Leverages Moonlight framework components via `GetMoonlight()` for UI, data management, and rendering
- **On-Demand Loading**: Bank bags are scanned when bank opens (BANKFRAME_OPENED event) to avoid unnecessary overhead

This design allows BetterBags to own the bag business logic while utilizing Moonlight as a UI framework library.

### Bank System Architecture
WoW's bank system includes three distinct bank types:
- **Character Bank** (Enum.BankType.Character): Bags -1 (main), 6-12 (7 purchasable tabs)
- **Account Bank** (Enum.BankType.Account): Bags 13-17 (5 account-wide warband tabs)
- **Reagent Bank**: Bag -3 (special reagent-only storage)

BetterBags bank implementation uses separate Bagdata views for Character and Account banks, allowing users to switch between them via tabs.

## Modules

### `types.lua`
Type definitions for bag-related classes and configurations:
- `Bag`: Base interface for all bag implementations
- `BagDataConfig`: Configuration options for bag data display and sorting

### `stack.lua`
Item stack management system that tracks and organizes items across bag slots:
- Maintains global hash tables for item stacks (by ItemHash and SlotKey)
- Handles stack insertion, removal, and sorting
- Provides stack count aggregation across multiple slots

**Key Functions:**
- `stack:UpdateStack(data)`: Updates or creates stacks based on item data
- `stack:SortAllStacks()`: Sorts all tracked stacks by stack count
- `Stack:GetTotalStackCount()`: Returns total count across all slots in a stack

### `bagdata.lua`
Core bag data management that organizes items into sections and manages their display:
- Tracks items by bag/slot, section, and button
- Implements three view modes: by category, by bag name, and combined view
- Handles item categorization and section assignment
- Manages item button creation and updates
- Integrates placeholder system to preserve empty item slots during gameplay

**Key Functions:**
- `Bagdata:SetConfig(config)`: Configure view mode and sorting behavior
- `Bagdata:RegisterCallbackWhenItemsChange(callback)`: Set redraw callback
- `Bagdata:theseBagsHaveBeenUpdated(bags)`: Process bag updates and trigger redraws
- `Bagdata:figureOutWhereAnItemGoes(item)`: Categorize and place items in sections

**Placeholder Integration:**

When items are removed during redraw cycles, bagdata uses `Section:RemoveItemButKeepSpace()` instead of `Section:RemoveItem()` to preserve grid layout. When adding items, it first calls `Section:TryReplacePlaceholder()` to fill empty spaces before expanding the grid. This creates a smooth experience where:
- Empty slots remain visible during gameplay
- New items fill existing empty spaces first
- Grid size stays consistent across multiple redraws

### `backpack.lua`
Backpack bag implementation with multiple view modes:
- Creates main player backpack window
- Implements three tabs: "Backpack" (categorized), "Bags" (by bag), "Everything" (single list)
- Manages container with tabbed interface
- Handles show/hide events and bag toggle keybindings

**Key Functions:**
- `backpack:Boot()`: Initialize backpack with views and UI
- `Backpack:Show/Hide(doNotAnimate)`: Control visibility with optional animations
- `Backpack:BindBagShowAndHideEvents()`: Wire up bag toggle keybinds

**Placeholder Cleanup:**

When the backpack is hidden, `Hide()` calls `Section:ForceFullRedraw()` on all sections in all views to remove placeholders before the bag reopens. This ensures each bag session starts with a clean layout without leftover empty spaces from previous sessions.

### `bank.lua`
Bank bag implementation with character and account-wide warband bank support:
- Creates bank window with Container and tabbed interface
- Dynamically fetches bank tabs using `C_Bank.FetchPurchasedBankTabData()` API
  - Character bank tabs from `C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)`
  - Warband bank tabs from `C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)`
- Each purchased tab creates its own Bagdata view with BagFilter for that specific bag ID
- Tab names and icons come directly from the Blizzard API (`BankTabData.name` and `BankTabData.icon`)
- Handles BANKFRAME_OPENED/CLOSED events to show/hide bank
- Integrates with Moonlight Loader to scan bank bags on demand when bank opens
- Manages BankPanel visibility to prevent taint (per patterns.md anti-taint guidelines)
- Window positioning: LEFT side of screen (400px wide, opposite backpack on RIGHT)
- All tabs always visible (no hover-to-show behavior)

**Key Functions:**
- `bank:Boot()`: Initialize container and window, register event handlers
- `Bank:RefreshTabs()`: Fetches purchased tabs from C_Bank API and creates views dynamically (called on BANKFRAME_OPENED)
- `Bank:BindBankShowAndHideEvents()`: Wire up bank open/close event handlers
- `Bank:Show/Hide(doNotAnimate)`: Control visibility with optional animations

**Placeholder Cleanup:**

When the bank is hidden, `Hide()` calls `Section:ForceFullRedraw()` on all sections in all views to remove placeholders before the bank reopens. This ensures each bank session starts with a clean layout without leftover empty spaces from previous sessions.

**Architecture:**
- Uses `C_Bank` API to get real tab names/icons instead of hardcoded values
- Each bank tab is a separate view with:
  - `ShowEmptySlots = false`: Hide empty slots
  - `CombineAllItems = false`: Show items organized by category
  - `StackSimilarItems = true`: Enable stack tracking across slots
  - `BagFilter`: Restricted to only that tab's bag ID (from `BankTabData.ID`)
  - Sort by item name alphabetically
  - Tabs sorted by bag ID using `SortKey` field
  - Tooltips show custom bag name from API
- View naming: `CharBank_{bagID}` for character tabs, `Warband_{bagID}` for account tabs

## Dependencies

The bag module depends on these Moonlight framework components:
- **UI**: Window, Container, Tab, Scrollbox, Grid, Section
- **Data**: Item, Loader, Stack (pooling), Pool
- **Rendering**: Render, Animation, Drawable
- **Theming**: SonataEngine (for applying themes to bag windows)
- **Input**: Binds (for keybindings)
- **UI Components**: Popup, Itembutton

## Load Order

1. Moonlight framework loads as standalone addon (via TOC dependency)
2. BetterBags boot system initializes (`boot/boot.lua`)
3. Bag module files load (types → stack → bagdata → backpack → bank)
4. BetterBags initialization triggers bag Boot() methods (`boot/init.lua`)
5. Moonlight loader refreshes bag data to populate initial items

## Configuration

Bags are configured via `BagDataConfig`:
```lua
{
  BagNameAsSections = false,      -- Show items grouped by bag or by category
  ShowEmptySlots = false,          -- Display empty slots
  CombineAllItems = false,         -- Show all items in single section
  StackSimilarItems = true,        -- Enable stack tracking
  BagFilter = {[0]=true, ...},     -- Optional: Filter which bags to display
  ItemSortFunction = function(...) -- Custom item sort
  SectionSetConfig = {...}         -- Section display configuration
}
```

### Bag Filtering
Each view can specify a `BagFilter` to restrict which bags it displays:
- **Backpack views**: `[0]=true, [1]=true, [2]=true, [3]=true, [4]=true, [5]=true` (bags 0-5)
- **Individual Bank tabs**: `[bagID]=true` (one specific bag per tab, e.g., `[-1]=true` for main bank)
  - Character bank tabs use bags -1, 6-12
  - Warband bank tabs use bags 13-17

Without a BagFilter, views will process all bag updates they receive. This is critical for preventing cross-contamination between backpack and bank displays.

## Integration Points

- Backpack registers with Sonata engine for theming: `engine:RegisterBag(Backpack)`
- Bags receive item updates via Loader callbacks: `loader:TellMeWhenABagIsUpdated()`
- Rendering triggered via Render module: `render:NewRenderChain(container)`
- Window positioning managed through Moonlight Window system

## Implementation Notes

### Bank Taint Prevention
Following patterns.md guidelines, BankPanel taint prevention is critical:
- BankPanel is configured invisible (alpha=0, mouse/keyboard disabled) at initialization
- BankPanel is NEVER shown during initialization (prevents permanent taint)
- BankPanel is shown invisibly only when BANKFRAME_OPENED fires
- This prevents taint from affecting UseContainerItem and other protected functions

### Bank Event Flow
1. During addon initialization (`bank:Boot()`):
   - Creates empty container and window
   - Registers event handlers
   - Tabs are NOT created yet (API data unavailable)
2. Player interacts with banker NPC
3. BANKFRAME_OPENED event fires
4. `Bank:RefreshTabs()` is called:
   - Calls `C_Bank.FetchPurchasedBankTabData()` for both Character and Account bank types
   - Creates individual Bagdata views for each purchased tab (if not already created)
   - Configures each view with tab name, icon, and bag filter from API
   - Recreates tab UI elements
   - Switches to first available tab
5. Bank module calls `loader:ScanAllBankBags()` to create ItemMixins
6. `loader:FullRefreshAllBagData()` triggers item updates
7. Bank window shows and renders items for active tab
8. BAG_UPDATE events trigger item updates while bank is open
9. BANKFRAME_CLOSED event fires when player closes bank
10. Bank window hides and BankPanel is hidden

## Future Enhancements

- Reagent bank support (bag -3)
- Additional view modes (e.g., grid view, list view)
- Custom categorization rules
- Search and filtering
- Bag-specific settings and profiles
- Tab-specific sorting and organization
