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
  - [Bank Tab Slots Panel](#bank-tab-slots-panel-bankslotslua)
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
- Drag-and-drop category assignment (backpack and bank, with cross-type constraints)
- Right-click section actions
- Automatic sorting

**Category Drag-and-Drop:**

Section titles can be dragged onto group tabs to assign the category to a group. The following constraints are enforced:
- Backpack categories can only be dropped onto backpack tabs.
- Bank categories can only be dropped onto bank tabs.
- Character Bank categories can only be dropped onto Character Bank group tabs (`bankType = Enum.BankType.Character`).
- Warbank categories can only be dropped onto Warbank group tabs (`bankType = Enum.BankType.Account`).

The `sectionFrame` module tracks three module-level fields during a drag:
- `draggingCategory` — name of the category being dragged
- `draggingKind` — `BagKind` of the source section (backpack or bank)
- `draggingBankType` — `bankType` of the active bank group at drag start (nil for backpack drags)

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

**Mouse Wheel Scroll Propagation:**

WoW does not bubble mouse wheel events up the parent-child hierarchy. Each WowScrollBox (created by `grid:Create`) automatically registers an `OnMouseWheel` handler via the template, which would intercept all scroll events — even on non-scrollable inner grids (e.g. section content grids).

To ensure scroll events reach the outer bag container:
- `EnableMouseWheelScroll(false)` is called on all section content grids (non-scrollable inner grids)
- Mouse wheel is disabled on all item buttons (`ContainerFrameItemButtonTemplate` enables it via its mixin)
- Events then fall through to the outer bag grid's WowScrollBox, which handles scrolling

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
- `EnableMouseWheelScroll(enabled)` - Enable or disable mouse wheel scrolling on this grid's scroll box

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
- Bank-type-aware tab sorting with strict section ordering
- Drag-to-reorder with cross-section drag constraint
- Icon-only tab minimum width enforcement (50px)
- Functional disable state (`SetTabsDisabled`) available for external use

**Tab Disable State:**

`SetTabsDisabled(disabled)` sets a `tabsDisabled` flag on the tab container and dims the tab bar to 50% alpha when disabled. While disabled, all `OnClick` and `OnMouseDown` handlers silently return early, preventing tab switching and drag-to-reorder. Note: the bank slots panel no longer uses `SetTabsDisabled`; it instead completely hides the tabs frame via `frame:Hide()` / `frame:Show()` for a cleaner visual transition.

**Icon-Only Tab Sizing:**

Tabs that display only an icon (no text label), such as the '+' purchase-new-tab button, use `PanelTemplates_TabResize(decoration, nil, 50)` to enforce a 50-pixel minimum width. Without this minimum, the tab renderer returns only the width of the left and right edge textures (~20px), making icon-only tabs noticeably narrower than adjacent text tabs. Passing `50` as the third argument ensures they visually match a typical short-label tab (e.g. "Bank").

**Bank Tab Sort Order (Retail):**

Bank tabs are sorted into two distinct sections separated by their `bankType`:

1. **Bank** (default, `Enum.BankType.Character`, `isDefault=true`) — always first
2. User-created Bank tabs (`bankType=Character`), sorted by their saved order
3. Purchase Bank tab (when available)
4. **Warbank** (default, `Enum.BankType.Account`, `isDefault=true`) — always first in Warbank section
5. User-created Warbank tabs (`bankType=Account`), sorted by their saved order
6. Purchase Warbank tab (when available)
7. **+** create tab — always last

**Drag-to-Reorder Constraints:**

User-created tabs can be reordered within their section via Shift+drag:
- Bank tabs (Character bankType) can only be dropped within the Bank section
- Warbank tabs (Account bankType) can only be dropped within the Warbank section
- Cross-section drops are silently ignored

This constraint is enforced in `CalculateOverlapTarget` by comparing the dragged tab's `bankType` against each candidate drop target's `bankType` before registering an overlap.

### Bag Slots (`bagslots.lua`)

Display panel for equipped bags.

**Features:**
- Visual bag slot display
- Bag swapping interface
- Purchase prompts
- Animation support

### Bank Tab Slots Panel (`bankslots.lua`)

Slide-out panel showing all possible Blizzard bank tab slots (retail only). When toggled **on**, the panel appears at the **bottom** of the bank window (where the group tabs normally sit) and replaces the normal group-based bank view with a per-Blizzard-tab filtered view. When toggled **off**, everything reverts: the panel moves back above the window, group tabs reappear, and the window title is restored.

**Features:**
- 11 slot buttons: 6 character bank tabs (`CharacterBankTab_1`–`_6`) followed by 5 warbank tabs (`AccountBankTab_1`–`_5`), in order left to right
- Purchased tabs show the tab's configured icon (from `C_Bank.FetchPurchasedBankTabData`)
- Unpurchased tabs show the `Garr_Building-AddFollowerPlus` atlas icon as a bare 37×37 borderless button (no slot background texture), matching the visual weight of purchased tab icons
- Left-click on a **purchased** tab selects it and filters the bank to show only items from that specific Blizzard bag index
- Left-click on an **unpurchased** tab opens the Blizzard bank tab purchase dialog (`CONFIRM_BUY_BANK_TAB` static popup) for the appropriate bank type, replicating the behavior of `BankPanelPurchaseTabButtonMixin:OnClick`
- Right-click opens the Blizzard tab settings dialog (for purchased tabs only); character bank tabs use `BankPanel.TabSettingsMenu`, warbank tabs use `AccountBankPanel.TabSettingsMenu`
- Auto-selects `CharacterBankTab_1` when the panel is first shown (after the fade-in animation)
- Clears the single-tab filter and restores the normal bank view when the panel is hidden (after fade-out)
- Redraws automatically on `BANK_TAB_SETTINGS_UPDATED` and `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED` events
- Mouse wheel events are forwarded to the outer bag container (not consumed by the inner grid)
- Slot button tooltips show the tab name, bank type (blue "Bank" / gold "Warbank"), and interaction hints

**Toggle Behavior (Show):**

When `Show()` is called the panel transitions into an active mode that fully transforms the bank window layout:

1. The panel frame is reanchored from **above** the bag window (`BOTTOMLEFT` → `TOPLEFT`) to **below** it (`TOPLEFT` → `BOTTOMLEFT`), occupying the space where group tabs normally sit.
2. The group tabs frame is **completely hidden** (not just disabled). The previous visibility state is saved in `tabsWereShown` so it can be restored correctly.

The Bank Tabs window itself is registered with an empty title (`""`), so no title text is ever rendered in the window decoration across any theme. This is permanent — the title is absent by design, not toggled.

**Toggle Behavior (Hide):**

After the fade-out animation completes (`fadeOutGroup.OnFinished`):

1. The panel frame is reanchored back to above the bag window (`BOTTOMLEFT` → `TOPLEFT`, 14px gap).
2. Group tabs visibility is restored from `tabsWereShown`.

**Main Class:**
```lua
---@class bankSlotsPanel
---@field frame Frame
---@field content Grid
---@field fadeInGroup AnimationGroup
---@field fadeOutGroup AnimationGroup
---@field buttons BankSlotButton[]
---@field selectedBagIndex number?
---@field bagFrame Frame        -- parent bag frame, stored for Show/Hide reanchoring
---@field tabsWereShown boolean -- whether group tabs were visible before panel opened
```

**Key Methods:**
- `CreatePanel(ctx, bagFrame)` — factory; returns a `bankSlotsPanel` (retail-only; returns nil on Classic/Era)
- `Draw(ctx)` — refreshes all slot button visuals from the current C_Bank tab data
- `SelectTab(ctx, bagIndex)` — selects the given tab, deselects others, and calls `bank.behavior:SwitchToBlizzardTab()`
- `SelectFirstTab(ctx)` — selects the first available tab (called automatically on fade-in)
- `OpenTabConfig(bagIndex)` — opens the Blizzard tab settings dialog for the given bag index
- `Show(callback?)` — reanchors panel to bottom, hides group tabs, then plays fade-in animation
- `Hide(callback?)` — plays fade-out animation; all layout changes are reversed in `fadeOutGroup.OnFinished`
- `IsShown()` — returns whether the underlying frame is visible

**Tab Config Dialog — Reliable Icon Selection:**

`OpenTabConfig` uses two internal helpers to work around timing and reparenting issues with Blizzard's `TabSettingsMenu`:

1. **`ensureSelectedTabData(menu, bankType, id)`** — Forces a fresh tab data lookup every time the config dialog is opened, bypassing Blizzard's internal `alreadySelected` early-exit guard. It first resets `menu.selectedTabData = nil` to force `SetSelectedTab` to re-fetch, then falls back to a direct `C_Bank.FetchPurchasedBankTabData(bankType)` call if the menu's data is still nil. This is necessary because BetterBags shows `BankPanel` only after a fade-in animation, so `BankPanel.purchasedBankTabData` may be empty during `BANKFRAME_OPENED`; the fallback ensures icon data is always available.

2. **`reconnectIconCallback(menu)`** — Explicitly re-wires `menu.IconSelector:SetSelectedCallback` with a fresh closure after the menu is reparented. Without this, the callback installed in `BankPanelTabSettingsMenuMixin:OnLoad` may become stale, causing icon clicks in the grid to silently do nothing. The closure updates `BorderBox.SelectedIconArea.SelectedIconButton` with the chosen icon texture.

**Tab Button Tooltips:**

Each slot button's `OnEnter` handler shows a tooltip:
- **Purchased tabs**: tab name (white), bank type (colored — blue `"Bank"` or gold `"Warbank"`), and grey interaction hints: "Left-click to view this tab" / "Right-click to configure this tab"
- **Unpurchased tabs**: localized name ("Unpurchased Bank Tab" / "Unpurchased Warbank Tab") and grey hint: "Click to purchase this tab"

**Integration with Bag Filtering:**

When a tab is selected the panel sets `bag.blizzardBankTab` to the chosen `Enum.BagIndex` value and calls `bank.behavior:SwitchToBlizzardTab(ctx, bagIndex)`. The items module (`data/items.lua`) checks this field during `RefreshBags()` and narrows the bag list to only the selected Blizzard bag index. When the panel is hidden the field is cleared and the normal group-based view is restored.

**Context Menu Integration:**

The existing context menu already shows the "Show Bags" option whenever `bag.slots` is set. Since `bags/bank.lua` assigns the created panel to `bag.slots`, no context menu changes are needed.

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

### Group Dialog (`groupdialog.lua`)

Dialog for creating or renaming a group tab. Used by the bank to accept a name and optional bank type (Character Bank / Warbank).

**Features:**
- Pre-fillable input (for rename workflows — pass `initialValue` to `Show()`)
- Configurable confirm-button label (pass `confirmText` to `Show()`)
- Optional bank-type dropdown (shown when `showDropdown = true`)
- Themed via the addon's active theme: the dialog is registered as a Simple window with the Themes module so it visually matches the rest of the UI

**`Show()` Signature:**
```lua
groupDialog:Show(title, text, showDropdown, defaultBankType, onInput, initialValue, confirmText)
```
- `initialValue` — optional; pre-fills the edit box (used for rename)
- `confirmText` — optional; overrides the confirm button label (default: "Create")

### Question (`question.lua`)

General-purpose modal dialog with pooled frame instances.

**Modes:**
- `AskForInput(title, text, onInput)` — edit-box prompt; calls `onInput(text)` on OK
- `YesNo(title, text, yes, no)` — two-button confirmation
- `Alert(title, text)` — single OK dismissal

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
├── BetterBagsBankSlots (Bank Tab Slots Panel — retail bank only)
│   │   Normally hidden above the bag; when open, reanchored to below the bag
│   └── Grid (11 BankSlotButton frames)
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
