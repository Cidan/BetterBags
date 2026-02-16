# BetterBags Frames Module

The frames module contains all UI frame components for the BetterBags addon, providing the visual interface for bag management, item display, and user interaction.

## Table of Contents

- [Overview](#overview)
- [Core Components](#core-components)
  - [Bag Frame](#bag-frame-bagframelua)
  - [Item Frame](#item-frame-itemlua)
  - [Section Frame](#section-frame-sectionlua)
  - [Grid Layout](#grid-layout-gridlua)
  - [List Layout](#list-layout-listlua)
- [UI Components](#ui-components)
  - [Search](#search-searchlua)
  - [Currency Display](#currency-display-currencylua)
  - [Context Menu](#context-menu-contextmenulua)
  - [Tabs](#tabs-tabslua)
  - [Bag Slots](#bag-slots-bagslotslua)
- [Support Components](#support-components)
  - [Anchor System](#anchor-system-anchorlua)
  - [Money Frame](#money-frame-moneylua)
  - [Overlay](#overlay-overlaylua)
  - [Bag Button](#bag-button-bagbuttonlua)
- [Version-Specific Implementations](#version-specific-implementations)
- [Frame Architecture](#frame-architecture)
- [Usage Examples](#usage-examples)
- [API Reference](#api-reference)

## Overview

The frames module provides a comprehensive UI framework for displaying and managing inventory items. It implements multiple view modes (grid, list, sections), search functionality, currency tracking, and various interactive elements.

## Core Components

### Bag Frame (`bag.lua`)

The main container frame for displaying bags (backpack or bank).

**Key Features:**
- Multiple view modes (grid, section, list)
- Warbank tab support (retail)
- Sort functionality
- Search integration
- Window positioning and anchoring

**Main Class:**
```lua
---@class Bag
---@field kind BagKind
---@field currentView View
---@field frame Frame
---@field sections table<string, Section>
---@field searchFrame SearchFrame
---@field tabs Tab
---@field bankTab BankTab
```

**Key Methods:**
- `Show(ctx)` - Display the bag frame
- `Hide(ctx)` - Hide the bag frame
- `Draw(ctx, slotInfo, callback)` - Render bag contents
- `Search(ctx, results)` - Apply search filter
- `Sort(ctx)` - Sort bag contents
- `Refresh(ctx)` - Full refresh of bag data

### Item Frame (`item.lua`)

Individual item button implementation with full WoW item functionality.

**Key Features:**
- Item display with icon, count, quality
- Item level display
- Item level colors refresh when max item level changes
- Cooldown tracking
- Search highlighting
- Upgrade indicator
- Stack management
- Free slot display

**Main Class:**
```lua
---@class Item
---@field frame Frame
---@field button ItemButton
---@field slotkey string
---@field staticData ItemData
---@field ilvlText FontString
```

**Key Methods:**
- `SetItem(ctx, slotkey)` - Set item by slot key
- `UpdateCount(ctx)` - Update stack count
- `UpdateSearch(ctx, found)` - Update search highlight
- `UpdateCooldown(ctx)` - Update cooldown display
- `UpdateUpgrade(ctx)` - Update upgrade indicator
- `SetFreeSlots(ctx, bagid, slotid, count)` - Display as free slot

### Section Frame (`section.lua`)

Container for grouping items into categorized sections.

**Key Features:**
- Category-based item grouping
- Expandable/collapsible sections
- Drag-and-drop category assignment
- Right-click section actions
- Automatic sorting

**Main Class:**
```lua
---@class Section
---@field frame Frame
---@field title Button
---@field content Grid
---@field maxItemsPerRow number
```

**Key Methods:**
- `SetTitle(text)` - Set section title
- `Draw(kind, view, freeSpaceShown, nosort)` - Render section
- `AddCell(id, cell)` - Add item to section
- `Grid(kind, view, freeSpaceShown, nosort)` - Grid layout rendering

### Grid Layout (`grid.lua`)

Flexible grid system for arranging UI elements.

**Key Features:**
- Dynamic column calculation
- Scrollable content
- Cell masking
- Flexible spacing
- Sort support

**Main Class:**
```lua
---@class Grid
---@field cells Cell[]
---@field idToCell table<string, Cell>
---@field maxCellWidth number
---@field spacing number
```

**Key Methods:**
- `AddCell(id, cell)` - Add cell to grid
- `RemoveCell(id)` - Remove cell from grid
- `Draw(options)` - Render grid layout
- `Sort(fn)` - Sort cells
- `DislocateCell(id)` - Remove cell visually

### List Layout (`list.lua`)

Scrollable list implementation for linear item display.

**Key Features:**
- Scrollable list view
- Dynamic item templates
- Reorderable items
- Data provider pattern

**Main Class:**
```lua
---@class ListFrame
---@field ScrollBox WowScrollBox
---@field provider DataProviderMixin
```

## UI Components

### Search (`search.lua`)

Search interface for filtering items.

**Features:**
- Real-time search
- Category creation from search
- Fade animations
- Integrated search box

**Key Functions:**
- `BetterBags_ToggleSearch()` - Toggle search overlay
- `UpdateSearch(ctx)` - Update search results
- `Create(ctx, parent)` - Create search frame

### Currency Display (`currency.lua`)

Currency tracking and display panel.

**Features:**
- All currency types display
- Backpack currency indicators
- Interactive currency management
- Expandable currency list

### Context Menu (`contextmenu.lua`)

Right-click context menu system.

**Features:**
- Bag configuration options
- View mode switching
- Anchor controls
- Character bank tabs toggle (retail)
- Bank tab purchases
- Sort operations

### Tabs (`tabs.lua`)

Tab management for bank views.

**Features:**
- Bank/Warbank tabs
- Character bank tabs (individual tabs for each bank slot)
- Dynamic tab creation
- Tab renaming
- Click handlers
- Toggle between single bank tab and multiple character bank tabs (retail only)
- Tab visibility management (ShowTabByID/HideTabByID)
- Automatic tab sorting by ID for consistent display order

### Bag Slots (`bagslots.lua`)

Display panel for equipped bags.

**Features:**
- Visual bag slot display
- Bag swapping interface
- Purchase prompts
- Animation support

## Support Components

### Anchor System (`anchor.lua`)

Frame anchoring and positioning system.

**Features:**
- Manual anchor points
- Automatic quadrant detection
- Draggable anchors
- Position persistence

### Money Frame (`money.lua`)

Gold/silver/copper display.

**Features:**
- Money display
- Click to pickup money
- Warbank money support
- Deposit/withdraw interface

### Overlay (`overlay.lua`)

Modal overlay system for dialogs.

**Features:**
- Fade animations
- Event callbacks
- Modal blocking

### Bag Button (`bagbutton.lua`)

Individual bag slot buttons.

**Features:**
- Bag equipment interface
- Drag and drop support
- Purchase integration
- Empty slot handling

## Version-Specific Implementations

### Classic Era (`era/`)
- `bag.lua` - Classic-specific bag handling
- `bagbutton.lua` - Classic bag buttons
- `bagslots.lua` - Classic bag slot display
- `contextmenu.lua` - Classic context menu
- `item.lua` - Classic item display
- `itemrow.lua` - Classic item rows
- `money.lua` - Classic money frame

## Character Bank Tabs Feature (Retail Only)

### Overview
The character bank tabs feature allows players to switch between two display modes for their character bank:
1. **Single Tab Mode** (default): All character bank bags shown in one tab labeled "Bank"
2. **Multiple Tabs Mode**: Individual tabs for each character bank bag slot (Tab 1, Tab 2, etc.)

### Configuration
Players can toggle between modes using the context menu option "Show Character Bank Tabs" when right-clicking on the bank frame.

### Implementation Details

#### Database Setting
- `characterBankTabsEnabled`: Boolean setting stored in the database
- `GetCharacterBankTabsEnabled()` / `SetCharacterBankTabsEnabled()`: Accessor methods

#### Tab Generation
When multiple tabs mode is enabled:
- Each bank bag gets its own tab with names retrieved from the WoW API
- Tab names are fetched using `C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)`
- If API data is unavailable, falls back to bag item names or generic "Bank Tab X" labels
- Tabs use the actual bag IDs (Enum.BagIndex.CharacterBankTab_1 through CharacterBankTab_6)
- The single "Bank" tab is hidden when multiple tabs are enabled
- Tabs are automatically sorted by ID to ensure consistent display order

#### Tab Management
- `ShowTabByID(tabID)`: Shows a specific tab by its ID
- `HideTabByID(tabID)`: Hides a specific tab by its ID
- `SortTabsByID()`: Sorts all tabs by their ID values for consistent ordering
- Tab visibility is properly managed when toggling between single/multiple tab modes

#### Content Filtering
When a specific character bank tab is selected:
- Only items from that specific bank bag are displayed
- The `filterBagID` context variable is used to filter items during refresh
- The items module handles the actual filtering in `RefreshBank()`

#### Tab Switching
- `SwitchToCharacterBankTab(ctx, tabID)`: Switches to a specific character bank tab
- Sets the appropriate filter and refreshes the bank display
- Updates the title to show which tab is active
- Right-clicking on a character bank tab opens the settings menu for that specific tab

### Interaction with Warbank
- Character bank tabs and warbank tabs can coexist
- When at the warbank, character bank tabs are hidden
- When at the character bank, warbank tabs remain visible for easy switching
- Both warbank and character bank tabs are sorted by ID for consistent ordering
- The single "Bank" tab always appears first when visible

### Note on Reagent Bank
As of the latest patch, the Reagent Bank has been removed from World of Warcraft. This feature and related tabs are no longer included in BetterBags.

### Classic (`classic/`)
- `bag.lua` - TBC/Wrath bag handling
- `contextmenu.lua` - Classic context menu
- `currency.lua` - Classic currency display

## Frame Architecture

### View System
```lua
-- Multiple view modes
BAG_VIEW = {
  SECTION_GRID = 1,      -- Grid with sections
  SECTION_ALL_BAGS = 2,  -- All bags view
  LIST = 3               -- List view
}
```

### Frame Hierarchy
```
BetterBagsBag (Main Container)
├── SearchFrame
├── Tabs
├── Content Area
│   ├── Sections
│   │   └── Items
│   └── Grid/List
├── Bottom Bar
│   ├── Money Frame
│   └── Currency Icons
└── Side Panels
    ├── Section Config
    ├── Currency Panel
    └── Theme Config
```

## Usage Examples

### Creating a Bag Frame
```lua
local ctx = context:New('CreateBag')
local bag = bagFrame:Create(ctx, const.BAG_KIND.BACKPACK)

-- Show the bag
bag:Show(ctx)

-- Draw contents
bag:Draw(ctx, slotInfo, function()
  print("Bag rendered")
end)
```

### Creating an Item Button
```lua
local ctx = context:New('CreateItem')
local item = itemFrame:Create(ctx)

-- Set item from slot
item:SetItem(ctx, "bag0/1")

-- Or set as free slot
item:SetFreeSlots(ctx, 0, 1, 5)
```

### Creating a Section
```lua
local ctx = context:New('CreateSection')
local section = sectionFrame:Create(ctx)

section:SetTitle("Consumables")
section:AddCell("item1", itemButton)
section:Draw(kind, view, false, false)
```

### Using the Grid System
```lua
local grid = gridModule:Create(parentFrame)
grid:AddCell("cell1", frame1)
grid:AddCell("cell2", frame2)

local width, height = grid:Draw({
  cells = grid.cells,
  maxWidthPerRow = 200
})
```

### Implementing Search
```lua
local searchFrame = searchBox:Create(ctx, bagFrame)

-- Toggle search
searchFrame:Toggle(ctx)

-- Get search text
local query = searchBox:GetText()
```

## API Reference

### BagFrame Module

| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `Create(ctx, kind)` | Create new bag frame | `Context`, `BagKind` | `Bag` |
| `Show(ctx)` | Show bag | `Context` | - |
| `Hide(ctx)` | Hide bag | `Context` | - |
| `Draw(ctx, slotInfo, callback)` | Render bag | `Context`, `SlotInfo`, `function` | - |
| `Search(ctx, results)` | Apply search | `Context`, `table` | - |
| `Sort(ctx)` | Sort contents | `Context` | - |

### ItemFrame Module

| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `Create(ctx)` | Create item button | `Context` | `Item` |
| `SetItem(ctx, slotkey)` | Set item | `Context`, `string` | - |
| `UpdateCount(ctx)` | Update count | `Context` | - |
| `UpdateSearch(ctx, found)` | Update search | `Context`, `boolean` | - |
| `Release(ctx)` | Release to pool | `Context` | - |

### SectionFrame Module

| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `Create(ctx)` | Create section | `Context` | `Section` |
| `SetTitle(text)` | Set title | `string` | - |
| `AddCell(id, cell)` | Add cell | `string`, `Cell` | - |
| `Draw(kind, view, freeSpace, nosort)` | Draw section | `BagKind`, `BagView`, `boolean`, `boolean` | `number`, `number` |

### Grid Module

| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `Create(parent)` | Create grid | `Frame` | `Grid` |
| `AddCell(id, cell)` | Add cell | `string`, `Cell` | - |
| `RemoveCell(id)` | Remove cell | `string` | `Cell?` |
| `Draw(options)` | Draw grid | `RenderOptions` | `number`, `number` |
| `Sort(fn)` | Sort cells | `function` | - |

## Best Practices

1. **Context Usage**: Always pass Context objects for tracking operations
2. **Pool Management**: Use item pools for performance
3. **Event Handling**: Register frame events through the Events module
4. **Theme Integration**: Use Themes module for consistent styling
5. **Animation**: Use Animations module for transitions
6. **Search Performance**: Implement efficient search filtering
7. **Memory Management**: Release frames back to pools when done

## Integration with Other Modules

- **Items Module**: Provides item data for display, handles filtering for character bank tabs
- **Categories Module**: Determines section grouping
- **Themes Module**: Handles visual styling
- **Events Module**: Coordinates frame updates
- **Database Module**: Stores frame positions, settings, and character bank tabs preference
- **Search Module**: Provides search functionality
- **Views Module**: Implements different view modes

## Performance Considerations

- Item frames are pooled for efficient memory usage
- Grid rendering is optimized for large item counts
- Search uses caching to avoid repeated calculations
- Animations use the built-in animation system
- Frame updates are batched where possible
