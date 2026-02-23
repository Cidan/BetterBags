# BetterBags Themes Module

The themes module provides a comprehensive theming system for BetterBags, allowing users to customize the visual appearance of their bag interface with different styles and integrations.

## Table of Contents

- [Overview](#overview)
- [Core Theme System](#core-theme-system-themeslua)
- [Available Themes](#available-themes)
  - [Default Theme](#default-theme-defaultlua)
  - [ElvUI Theme](#elvui-theme-elvuilua)
  - [Simple Dark Theme](#simple-dark-theme-simpledarklua)
  - [Guild Wars 2 Theme](#guild-wars-2-theme-gw2lua)
- [Theme Architecture](#theme-architecture)
- [Creating Custom Themes](#creating-custom-themes)
- [Theme API Reference](#theme-api-reference)
- [Best Practices](#best-practices)

## Overview

The themes module manages the visual appearance of all BetterBags windows, including:
- Main bag and bank windows (Portrait frames)
- Configuration panels (Simple frames)
- Modal dialogs (Flat frames)
- Item buttons and decorations
- Section fonts and titles
- Search interfaces
- Tab decorations

## Core Theme System (`themes.lua`)

The main themes module provides theme registration, management, and application functionality.

### Key Components

**Theme Registry:**
```lua
---@class Themes: AceModule
---@field themes table<string, Theme>
---@field windows table<WindowKind, Frame[]>
---@field sectionFonts table<string, FontString>
---@field titles table<string, string>
---@field itemButtons table<string, ItemButton>
---@field tabs table<string, PanelTabButtonTemplate>
```

**Window Types:**
```lua
WINDOW_KIND = {
  PORTRAIT = 1,  -- Main bag/bank windows
  SIMPLE = 2,    -- Configuration panels
  FLAT = 3       -- Modal dialogs
}
```

### Core Functions

| Function | Description | Parameters | Returns |
|----------|-------------|------------|---------|
| `RegisterTheme(key, theme)` | Register a new theme | `string`, `Theme` | - |
| `ApplyTheme(ctx, key)` | Apply theme to all windows | `Context`, `string` | - |
| `GetCurrentTheme()` | Get active theme | - | `Theme` |
| `GetAllThemes()` | Get available themes | - | `table<string, Theme>` |
| `UpdateOpacity()` | Update frame opacity | - | - |
| `SetTitle(frame, title)` | Set frame title | `Frame`, `string` | - |
| `ToggleTitleContainer(frame, shown)` | Show/hide title element in decoration | `Frame`, `boolean` | - |

### Theme Registration

```lua
function themes:RegisterPortraitWindow(frame, title)
  -- Register main windows
end

function themes:RegisterSimpleWindow(frame, title)
  -- Register config panels
end

function themes:RegisterFlatWindow(frame, title)
  -- Register modal dialogs
end

function themes:RegisterSectionFont(font)
  -- Register section header fonts
end
```

### Helper Functions

**Bag Button Creation:**
```lua
themes.SetupBagButton(bag, decoration)
-- Creates interactive bag button with:
-- - Menu access
-- - Sort functionality
-- - Search toggle
-- - Drag-and-drop category creation
```

**Item Button Decoration:**
```lua
themes.CreateBlankItemButtonDecoration(parent, theme, buttonName)
-- Creates themed item button overlay
```

**Tab Decoration:**
```lua
themes.CreateDefaultTabDecoration(tab)
-- Creates themed tab button
```

## Available Themes

### Default Theme (`default.lua`)

The standard World of Warcraft interface theme.

**Features:**
- Classic WoW panel styling
- Yellow title text
- Standard close button
- Integrated search box
- Default panel backgrounds

**Key Elements:**
- Uses `DefaultPanelTemplate`
- Standard WoW fonts
- Traditional UI elements

### ElvUI Theme (`elvui.lua`)

Integration with the ElvUI addon interface.

**Features:**
- Clean, minimal design
- ElvUI backdrop styling
- Custom close button
- Integrated ElvUI search box
- Masque disabled for consistency
- ElvUI cooldown styling

**Requirements:**
- ElvUI addon must be installed
- Automatically detects ElvUI presence

**Special Handling:**
```lua
DisableMasque = true  -- Uses ElvUI skinning instead
```

### Simple Dark Theme (`simpledark.lua`)

A clean, dark theme example that demonstrates theme creation.

**Features:**
- Dark backdrop with gray borders
- White text on dark background
- Custom close button texture
- Minimal design
- Example theme structure

**Use Case:**
- Template for custom theme development
- Shows all required theme functions
- Well-commented for learning

### Guild Wars 2 Theme (`gw2.lua`)

Integration with the GW2_UI addon for Guild Wars 2 styling.

**Features:**
- GW2-style header and footer
- Side panel with action buttons
- Custom window decorations
- Integrated button panel
- GW2 backdrop templates

**Requirements:**
- GW2_UI addon must be installed
- Uses GW2_UI textures and functions

**Special Features:**
- Side button panel for quick actions
- Custom positioning for bag slots
- Offset sidebar support

## Theme Architecture

### Theme Structure

Every theme must implement the following interface:

```lua
---@class Theme
---@field Name string              -- Display name
---@field Description string       -- Theme description
---@field Available boolean        -- Availability check
---@field Portrait fun(frame: Frame)
---@field Simple fun(frame: Frame)
---@field Flat fun(frame: Frame)
---@field Opacity fun(frame: Frame, opacity: number)
---@field SectionFont fun(font: FontString)
---@field SetTitle fun(frame: Frame, title: string)
---@field ToggleSearch fun(frame: Frame, shown: boolean)
---@field Reset fun()
---@field PositionBagSlots? fun(frame: Frame, bagSlotWindow: Frame)
---@field OffsetSidebar? fun(): number
---@field ItemButton? fun(button: Item): ItemButton
---@field Tab? fun(tab: Button): PanelTabButtonTemplate
---@field DisableMasque? boolean
```

### Required Functions

**Portrait(frame)** - Theme main bag/bank windows
- Apply decorations
- Add close button
- Setup search interface
- Position bag button

**Simple(frame)** - Theme configuration panels
- Apply backdrop
- Add title
- Add close button

**Flat(frame)** - Theme modal dialogs
- Apply minimal styling
- Add title (no close button)

**Opacity(frame, alpha)** - Handle opacity changes
- Update backdrop alpha
- Maintain visibility

**SectionFont(font)** - Style section headers
- Set font object
- Apply color

**SetTitle(frame, title)** - Update frame titles
- Set title text
- Update decoration

**ToggleTitleContainer(frame, shown)** - Show or hide the title element (module-level, not per-theme)
- Iterates `frame:GetChildren()` looking for either a `TitleContainer` (Default theme, from `DefaultPanelTemplate`) or a `title` FontString (SimpleDark/GW2/ElvUI)
- Called by the bank slots panel in `Show()` to hide the window title from its normal position, and in `fadeOutGroup.OnFinished` to restore it
- Works automatically with all built-in themes without per-theme implementation

**Reset()** - Clean up theme
- Hide all decorations
- Remove customizations

**ToggleSearch(frame, shown)** - Show/hide search
- Toggle search visibility
- Adjust frame layout

### Optional Functions

**PositionBagSlots(frame, bagSlotWindow)** - Custom bag slot positioning

**OffsetSidebar()** - Adjust sidebar position offset

**ItemButton(button)** - Custom item button styling

**Tab(tab)** - Custom tab styling

## Creating Custom Themes

### Basic Theme Template

```lua
local addonName = ...
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)
local themes = addon:GetModule('Themes')
local searchBox = addon:GetModule('SearchBox')
local fonts = addon:GetModule('Fonts')

-- Decoration frame cache
local decoratorFrames = {}

local myTheme = {
  Name = 'My Theme',
  Description = 'A custom theme',
  Available = true,
  
  Portrait = function(frame)
    local decoration = decoratorFrames[frame:GetName()]
    if not decoration then
      -- Create decoration frame
      decoration = CreateFrame("Frame", frame:GetName().."MyTheme", frame)
      decoration:SetAllPoints()
      decoration:SetFrameLevel(frame:GetFrameLevel() - 1)
      
      -- Add backdrop
      decoration:SetBackdrop({
        bgFile = 'Interface\\ChatFrame\\ChatFrameBackground',
        edgeFile = 'Interface\\ChatFrame\\ChatFrameBackground',
        edgeSize = 1,
      })
      decoration:SetBackdropColor(0, 0, 0, 1)
      
      -- Add title
      local title = decoration:CreateFontString(nil, "OVERLAY")
      title:SetFontObject(fonts.UnitFrame12White)
      title:SetPoint("TOP", decoration, "TOP", 0, -5)
      decoration.title = title
      
      -- Add close button
      local close = CreateFrame("Button", nil, decoration)
      addon.SetScript(close, "OnClick", function(ctx)
        frame.Owner:Hide(ctx)
      end)
      
      -- Add search box
      local box = searchBox:CreateBox(frame.Owner.kind, decoration)
      decoration.search = box
      
      -- Setup bag button
      themes.SetupBagButton(frame.Owner, decoration)
      
      -- Cache decoration
      decoratorFrames[frame:GetName()] = decoration
    else
      decoration:Show()
    end
  end,
  
  Simple = function(frame)
    -- Similar structure for simple frames
  end,
  
  Flat = function(frame)
    -- Similar structure for flat frames
  end,
  
  Opacity = function(frame, alpha)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration:SetBackdropColor(0, 0, 0, alpha/100)
    end
  end,
  
  SectionFont = function(font)
    font:SetFontObject(fonts.UnitFrame12White)
  end,
  
  SetTitle = function(frame, title)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration.title:SetText(title)
    end
  end,
  
  Reset = function()
    for _, frame in pairs(decoratorFrames) do
      frame:Hide()
    end
  end,
  
  ToggleSearch = function(frame, shown)
    local decoration = decoratorFrames[frame:GetName()]
    if decoration then
      decoration.search:SetShown(shown)
    end
  end
}

themes:RegisterTheme('MyTheme', myTheme)
```

### Advanced Features

**Custom Item Buttons:**
```lua
ItemButton = function(item)
  local button = themes.CreateBlankItemButtonDecoration(item.frame, "MyTheme", item.button:GetName())
  -- Apply custom styling
  button:SetBackdrop({...})
  -- Add custom textures
  local glow = button:CreateTexture(nil, "OVERLAY")
  return button
end
```

**Custom Tabs:**
```lua
Tab = function(tab)
  local decoration = themes.CreateDefaultTabDecoration(tab)
  -- Apply custom tab styling
  decoration:SetBackdrop({...})
  return decoration
end
```

## Theme API Reference

### Theme Object

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `Name` | string | Yes | Display name |
| `Description` | string | Yes | Theme description |
| `Available` | boolean | Yes | Availability check |
| `Portrait` | function | Yes | Main window theming |
| `Simple` | function | Yes | Config panel theming |
| `Flat` | function | Yes | Modal dialog theming |
| `Opacity` | function | Yes | Opacity handler |
| `SectionFont` | function | Yes | Section font styling |
| `SetTitle` | function | Yes | Title update handler |
| `ToggleSearch` | function | Yes | Search toggle handler |
| `Reset` | function | Yes | Theme cleanup |
| `PositionBagSlots` | function | No | Bag slot positioning |
| `OffsetSidebar` | function | No | Sidebar offset |
| `ItemButton` | function | No | Item button styling |
| `Tab` | function | No | Tab styling |
| `DisableMasque` | boolean | No | Disable Masque integration |

### Context Access

Themes have access to frame owners:
```lua
frame.Owner -- The bag object
frame.Owner.kind -- BAG_KIND.BACKPACK or BAG_KIND.BANK
frame.Owner.slots -- Bag slots panel
frame.Owner.currencyFrame -- Currency panel
frame.Owner.sectionConfigFrame -- Section config panel
```

## Best Practices

### 1. Frame Management
- Cache decoration frames for reuse
- Hide decorations in Reset()
- Use proper frame levels
- Avoid frame leaks

### 2. Performance
- Create decorations once, reuse always
- Minimize texture creation
- Use frame pools where appropriate
- Cache frequently accessed elements

### 3. Compatibility
- Check addon dependencies in `Available`
- Handle missing addons gracefully
- Respect user settings
- Support all WoW client versions

### 4. Styling Guidelines
- Maintain consistent visual language
- Respect frame hierarchy
- Use proper anchor points
- Handle dynamic content sizing

### 5. User Experience
- Provide clear theme names
- Include descriptive text
- Ensure all UI elements are accessible
- Support opacity settings

### 6. Code Organization
```lua
-- Structure your theme file:
-- 1. Imports and dependencies
-- 2. Local variables and caches
-- 3. Helper functions
-- 4. Theme definition
-- 5. Registration
```

## Integration with Other Modules

- **SearchBox Module**: Provides search interface creation
- **Fonts Module**: Provides consistent font objects
- **Context Menu Module**: Menu integration for buttons
- **Constants Module**: Window kinds and bag types
- **Database Module**: Theme preferences storage
- **Events Module**: Theme change notifications

## Debugging Themes

```lua
-- Check if theme is registered
local theme = themes.themes['MyTheme']
if theme and theme.Available then
  print("Theme available")
end

-- Test theme application
local ctx = context:New('ThemeTest')
themes:ApplyTheme(ctx, 'MyTheme')

-- Inspect decoration frames
for name, frame in pairs(decoratorFrames) do
  print(name, frame:IsShown())
end
```

## Common Issues

### Theme Not Appearing
- Check `Available` returns true
- Verify registration key matches
- Ensure file is loaded in .toc

### Decoration Overlap
- Check frame levels
- Verify SetAllPoints usage
- Clear existing decorations in Reset()

### Missing Elements
- Ensure all required functions exist
- Check frame references
- Verify parent-child relationships

## Notes

- Themes are hot-swappable without reload
- All themes share the same item button pool
- Theme changes trigger full bag refresh
- Custom themes can be distributed as separate addons