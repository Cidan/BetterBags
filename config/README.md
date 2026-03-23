# Configuration Module

This folder contains the configuration system for BetterBags, providing a comprehensive settings interface and plugin configuration management.

## Overview

The configuration module manages all user-configurable settings for the BetterBags addon, including general settings, bag-specific options, display preferences, and plugin configurations. It provides a centralized GUI for users to customize the addon's behavior.

## Files

### config.lua

The main configuration module that creates and manages the settings interface for BetterBags.

#### Key Features

- **Settings Interface**: Creates a comprehensive form-based settings UI using the Form module
- **Bag Type Configuration**: Separate settings for Backpack and Bank
- **Category Management**: Controls for enabling/disabling various item categorization methods
- **Stacking Options**: Configuration for item merging and stacking behavior
- **Display Customization**: Visual settings including columns, opacity, scale, and item layout

#### Configuration Categories

1. **General Settings**
   - In-bag search bar toggle
   - Enter key to create categories
   - Category-based selling/depositing
   - Blizzard bag button visibility
   - Upgrade icon provider selection
   - New item duration (1-120 minutes)

2. **Per-Bag Settings** (Backpack & Bank)
   - **Section Management**:
     - Section sorting (Alphabetically, Size Descending/Ascending)
     - Item sorting within sections (Alphabetically, Quality, Item Level)
   
   - **Categories**:
     - Equipment Location categorization
     - Expansion-based sorting
     - Equipment Set grouping
     - Recent Items category
     - Trade Skill categorization
     - Type and Subtype categorization
   
   - **Item Stacking**:
     - Mark all items as recent
     - Flash new items in stacks
     - Merge stackable items
     - Merge unstackable items (armor/weapons)
     - Partial stack handling
     - Transmogged item separation
     - Unmerge at vendors/interactions
   
   - **Item Level Display**:
     - Show/hide item levels
     - Colored item level display
   
   - **Display Options**:
     - Full section name display
     - Free space slot visibility
     - Enhanced glow effects
     - Items per row (3-20)
     - Column count (1-20)
     - Background opacity (0-100%)
     - Scale (50-200%)

#### Chat Commands

- `/bb` - Opens the BetterBags settings window
- `/bbanchor` - Shows anchor frames for positioning bags
- `/bbdb` - Toggles debug mode

#### Events

Listens to:
- `categories/Changed` - Updates when categories change
- `config/Open` - Opens the configuration window

Sends:
- Various refresh and update events when settings change

### categorypane.lua

The CategoryPane module provides a comprehensive category management interface within the main settings screen. It replaces the previous sidebar-based category configuration.

#### Key Features

- **Master-Detail Layout**: Left side shows a scrollable list of categories, right side shows detailed configuration for the selected category
- **Category List**:
  - Shows all categories organized into "Pinned" (top-priority) and "Automatically Sorted" sections
  - Drag-and-drop reordering of categories
  - Visual indicators for hidden or disabled categories
- **Detail Panel**:
  - For Search Categories: Query editor, Group By dropdown, Priority input, Color picker
  - For Manual Categories: Item list with remove buttons, Color picker
  - For Dynamic Categories: Read-only display of category information
- **Common Controls**: Enable/Disable toggle, Hide/Show toggle, Delete button (for custom categories)

#### Functions

- **`categoryPane:Create(parent, kind)`**: Creates a new category pane for the specified bag kind (Backpack or Bank)
- Category management integrates with the Categories module for persistence
- Sends refresh events when categories are modified

#### UI Structure

```
+-------------------+--------------------------------------+
| Pinned            | [Selected Category Name]             |
| > Category 1      | Query: [text area]                   |
| > Category 2      | Group By: [dropdown]                 |
| Auto Sorted       | Priority: [input]                    |
| > Category 3      | Color: [picker]                      |
| > Category 4      | [x] Enabled  [ ] Hidden              |
|                   | [Delete Category]                    |
+-------------------+--------------------------------------+
```

### themepane.lua

The ThemePane module provides a theme selection interface within the main settings screen. It allows users to browse and apply visual themes for BetterBags.

#### Key Features

- **Master-Detail Layout**: Left side shows a scrollable list of available themes, right side shows detailed information about the selected theme
- **Theme List**:
  - Displays all available themes sorted alphabetically
  - Currently active theme highlighted in yellow
  - Visual indicators for selected theme (gold highlight)
- **Detail Panel**:
  - Theme name (large gold title)
  - Theme description
  - Availability status (Currently Active, Available, or Unavailable)
  - Apply Theme button to switch themes

#### Functions

- **`themePane:Create(parent)`**: Creates a new theme pane for the settings interface
- Integrates with the Themes module for theme switching
- Applies themes immediately when the Apply button is clicked

#### UI Structure

```
+-------------------+--------------------------------------+
| > Default         | [Selected Theme Name]                |
| > ElvUI           | Description:                         |
| > Simple Dark     | A clean, minimal theme for...        |
|                   |                                      |
|                   | Status: Currently Active             |
|                   |                                      |
|                   | [Apply Theme]                        |
+-------------------+--------------------------------------+
```

### currencypane.lua

The CurrencyPane module provides a currency configuration interface within the main settings screen. It allows users to select which currencies are displayed in the icon grid at the bottom of the backpack.

#### Key Features

- **Master-Detail Layout**: Left side shows a scrollable list of all currencies, right side shows detailed information about the selected currency
- **Currency List**:
  - Displays all currencies organized by their in-game headers
  - Currencies shown in backpack are highlighted in yellow
  - Shows quantity next to each currency
  - Visual indicators for selected currency (gold highlight)
- **Detail Panel**:
  - Currency icon and name (large gold title)
  - Current quantity
  - Maximum quantity (if applicable)
  - Weekly earned amount (if applicable)
  - Status indicator (shown/hidden in backpack)
  - Toggle button to show/hide in backpack

#### Functions

- **`currencyPane:Create(parent)`**: Creates a new currency pane for the settings interface
- Uses C_CurrencyInfo API for retail or GetCurrencyListInfo for classic
- Updates automatically when currencies change via CURRENCY_DISPLAY_UPDATE event

#### UI Structure

```
+-------------------+--------------------------------------+
| Currencies        | [Currency Icon] Honor Points         |
| > PvP             |                                      |
|   > Honor Points  | Quantity: 1,250                      |
|   > Conquest      | Maximum: 15,000                      |
| > Dungeon         |                                      |
|   > Valor         | Status: Shown in backpack            |
|                   |                                      |
|                   | [Hide in Backpack]                   |
+-------------------+--------------------------------------+
```

#### Classic Variant

The `classic/currencypane.lua` file provides the same functionality for Classic versions of WoW, using the older API functions:
- `GetCurrencyListInfo()` instead of `C_CurrencyInfo.GetCurrencyListInfo()`
- `SetCurrencyBackpack()` instead of `C_CurrencyInfo.SetCurrencyBackpack()`
- `GetCurrencyListSize()` instead of `C_CurrencyInfo.GetCurrencyListSize()`

### plugin.lua

Manages integration of third-party plugin configurations into the main BetterBags settings interface.

#### Key Functions

- **`flattenPluginConfig(c, result)`**: Recursively flattens nested plugin configuration structures
  - Converts hierarchical config groups into a flat list of options
  - Simplifies processing of complex plugin configurations

- **`AddPluginConfig(title, c)`**: Integrates plugin settings into the main config UI
  - `title`: The plugin name displayed in settings
  - `c`: AceConfig options table with plugin settings
  - Automatically creates a "Plugins" section if needed
  - Adds a subsection for each plugin

#### Supported Plugin Option Types

1. **Toggle** (`toggle`): Creates checkbox controls
2. **Execute** (`execute`): Creates button controls for actions
3. **Select** (`select`): Creates dropdown menus
4. **Input** (`input`): Creates text input fields
   - Supports both single-line and multi-line text areas
5. **Color** (`color`): Creates color picker controls with RGBA support

#### Plugin Integration

Plugins can register their configuration by calling:
```lua
config:AddPluginConfig("Plugin Name", optionsTable)
```

The system automatically:
- Creates appropriate UI controls based on option types
- Handles getting and setting values through plugin callbacks
- Maintains consistent styling with the main BetterBags interface

## Usage

### For Users

1. Open settings with `/bb` command
2. Navigate through sections to configure desired options
3. Changes are applied immediately or after specified delays
4. Some changes trigger full bag refreshes

### For Plugin Developers

```lua
-- Example plugin configuration registration
local pluginOptions = {
  myToggle = {
    type = "toggle",
    name = "Enable Feature",
    desc = "Enables my plugin feature",
    get = function() return MyPlugin.enabled end,
    set = function(_, value) MyPlugin.enabled = value end
  },
  mySelect = {
    type = "select",
    name = "Mode",
    desc = "Select operation mode",
    values = {"Mode1", "Mode2", "Mode3"},
    get = function() return MyPlugin.mode end,
    set = function(_, value) MyPlugin.mode = value end
  }
}

config:AddPluginConfig("My Plugin", pluginOptions)
```

## Dependencies

- **AceAddon-3.0**: Addon framework
- **AceConsole-3.0**: Chat command handling
- **Form Module**: UI form creation and management
- **Database Module**: Settings persistence
- **Events Module**: Event messaging system
- **Themes Module**: Visual theming support

### itemcolorpane.lua

Provides the item level color configuration pane.

#### Key Features
- Displays dynamic breakpoints based on highest seen item level
- Allows per-tier color customization (low/mid/high/max)
- Reset restores defaults in place without recreating the pane

## Performance Considerations

- Some settings use bucket timers to delay refreshes (0.2 seconds)
- This prevents multiple rapid updates from causing performance issues
- Full bag refreshes are triggered selectively based on setting impact
