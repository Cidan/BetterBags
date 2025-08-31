# BetterBags Integrations Module

The integrations module provides seamless compatibility with popular World of Warcraft addons, enhancing BetterBags functionality when these addons are present.

## Table of Contents

- [Overview](#overview)
- [Supported Integrations](#supported-integrations)
  - [ConsolePort](#consoleport-consoleportlua)
  - [Masque](#masque-masquelua)
  - [Pawn](#pawn-pawnlua)
  - [SimpleItemLevel](#simpleitemlevel-simpleitemlevellua)
- [Integration Architecture](#integration-architecture)
- [Usage](#usage)
- [Adding New Integrations](#adding-new-integrations)
- [API Reference](#api-reference)

## Overview

The integrations module automatically detects and integrates with third-party addons to provide enhanced functionality. All integrations are optional and only activate when the corresponding addon is present and loaded.

## Supported Integrations

### ConsolePort (`consoleport.lua`)

Provides gamepad/controller support through the ConsolePort addon.

**Features:**
- Adds BetterBags frames to ConsolePort's cursor system
- Enables controller navigation of bags and menus
- Modifies config to open Blizzard settings UI when using ConsolePort
- Automatic context menu cursor selection

**Key Components:**
```lua
---@class ConsolePort: AceModule
---@field private enabled boolean
```

**Activation:**
- Automatically enabled when ConsolePort addon is detected
- Adds cursor frames for both Backpack and Bank
- Registers dropdown menus dynamically

**Methods:**
| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `Add(frame)` | Add frame to ConsolePort | `Frame` | - |
| `Select(frame)` | Set cursor to frame | `Frame` | - |
| `Active()` | Check if enabled | - | `boolean` |

### Masque (`masque.lua`)

Integrates with Masque for custom button skinning.

**Features:**
- Custom button skins for item buttons
- Separate groups for Backpack and Bank
- Respects theme DisableMasque setting
- Dynamic button registration/removal
- Blend mode fixes for proper display

**Key Components:**
```lua
---@class MasqueTheme: AceModule
---@field groups table<string, MasqueGroup>
```

**Groups:**
- `BetterBags/Backpack` - All backpack item buttons
- `BetterBags/Bank` - All bank item buttons

**Event Handlers:**
- `item/NewButton` - Register new item buttons
- `item/Updated` - Update button registration
- `item/Clearing` - Remove button from group
- `bagbutton/Updated` - Register bag slot buttons
- `bagbutton/Clearing` - Remove bag slot buttons

**Methods:**
| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `AddButtonToGroup(group, button)` | Add button to Masque group | `string`, `Button` | - |
| `RemoveButtonFromGroup(group, button)` | Remove button from group | `string`, `Button` | - |
| `IsGroupEnabled(group)` | Check if group is enabled | `string` | `boolean` |
| `ReapplyBlend(button)` | Fix blend mode | `Button` | - |

### Pawn (`pawn.lua`)

Shows item upgrade indicators using Pawn's upgrade detection.

**Features:**
- Upgrade arrow indicators on items
- Equipment slot preloading for comparison
- Support for both Retail and Classic
- Combat lockdown handling
- Deferred updates after combat

**Key Components:**
```lua
-- Uses Pawn's upgrade detection
PawnShouldItemLinkHaveUpgradeArrowUnbudgeted(itemLink, true)
```

**Event Handlers:**
- `bag/Rendered` - Update all items after bag render

**Behavior:**
- Shows upgrade arrows on items that are upgrades according to Pawn
- Preloads all equipment slots for accurate comparison
- Defers updates during combat to avoid taint

### SimpleItemLevel (`simpleitemlevel.lua`)

Alternative upgrade detection using SimpleItemLevel addon.

**Features:**
- Upgrade indicators when Pawn is not available
- Uses SimpleItemLevel's upgrade API
- Equipment slot preloading
- Backpack-only functionality

**Key Components:**
```lua
-- Uses SimpleItemLevel's API
SimpleItemLevel.API.ItemIsUpgrade(itemLink)
```

**Event Handlers:**
- `bag/Rendered` - Update items after render

**Behavior:**
- Only activates when SimpleItemLevel is present
- Only processes backpack items (not bank)
- Falls back when Pawn is not available

## Integration Architecture

### Automatic Detection

All integrations use a common pattern for detecting addon presence:

```lua
function module:OnEnable()
  if not RequiredAddon then 
    return  -- Addon not found, integration disabled
  end
  -- Integration code here
  print("BetterBags: AddonName integration enabled.")
end
```

### Event-Based Integration

Integrations typically hook into BetterBags events:

```lua
events:RegisterMessage('event/name', function(_, ...)
  -- Integration logic
end)
```

### Non-Invasive Design

- Integrations never modify the core BetterBags functionality
- All integrations can be disabled without affecting base features
- Integrations respect user preferences and theme settings

## Usage

Integrations are automatic and require no configuration:

1. **Install the third-party addon** (ConsolePort, Masque, Pawn, or SimpleItemLevel)
2. **Load BetterBags** - Integration automatically detects and activates
3. **Check chat** - Confirmation message appears when integration loads

### Disabling Integrations

While there's no built-in disable option, integrations can be prevented by:
- Not installing the third-party addon
- Disabling the third-party addon
- For Masque: Using a theme with `DisableMasque = true`

## Adding New Integrations

To add support for a new addon:

1. **Create integration file** in `integrations/` folder:
```lua
local addonName = ... ---@type string
local addon = LibStub('AceAddon-3.0'):GetAddon(addonName)
local events = addon:GetModule('Events')

local myIntegration = addon:NewModule('MyIntegration')

function myIntegration:OnEnable()
  -- Check if addon exists
  if not _G.MyAddon then 
    return 
  end
  
  -- Register events
  events:RegisterMessage('event/name', function(_, ...)
    -- Integration logic
  end)
  
  print("BetterBags: MyAddon integration enabled.")
end
```

2. **Follow patterns:**
   - Check for addon presence in `OnEnable`
   - Use events for reactive integration
   - Print confirmation message
   - Handle nil/missing values gracefully

3. **Common integration points:**
   - `item/Updated` - Item button updates
   - `bag/Rendered` - After bag draw
   - `context/show` - Context menu display
   - `item/NewButton` - New button creation

## API Reference

### ConsolePort Module

```lua
-- Add frame to ConsolePort cursor system
consoleport:Add(frame)

-- Select frame with cursor
consoleport:Select(frame)

-- Check if ConsolePort is active
local isActive = consoleport:Active()
```

### Masque Module

```lua
-- Check if Masque group is enabled
local isEnabled = masque:IsGroupEnabled("Backpack")

-- Manually fix blend mode (usually automatic)
masque:ReapplyBlend(button)
```

### Integration Events

| Event | Description | Parameters |
|-------|-------------|------------|
| `item/NewButton` | New item button created | `Item`, `ItemButton` |
| `item/Updated` | Item button updated | `Item`, `ItemButton` |
| `item/Clearing` | Item button clearing | `Item`, `ItemButton` |
| `bagbutton/Updated` | Bag button updated | `BagButton` |
| `bagbutton/Clearing` | Bag button clearing | `BagButton` |
| `bag/Rendered` | Bag finished rendering | `Bag`, `SlotInfo` |
| `context/show` | Context menu shown | - |

## Best Practices

1. **Defensive Programming**: Always check for addon existence
2. **Event-Driven**: Use events rather than hooks when possible
3. **Performance**: Cache addon references, avoid repeated lookups
4. **User Feedback**: Print confirmation when integration loads
5. **Combat Safety**: Defer updates during combat when needed
6. **Theme Respect**: Honor theme settings (e.g., DisableMasque)
7. **Graceful Degradation**: Continue working if integration fails

## Troubleshooting

### Integration Not Working

1. **Check addon is installed**: Verify third-party addon is present
2. **Check load order**: BetterBags should load after integrated addon
3. **Check chat message**: Look for "integration enabled" message
4. **Check errors**: Use `/console scriptErrors 1`

### Masque Skins Not Applying

- Ensure theme doesn't have `DisableMasque = true`
- Check Masque group settings in Masque config
- Try `/reload` to refresh skin application

### Upgrade Arrows Not Showing

- Verify Pawn or SimpleItemLevel is installed
- Check that item comparison data is available
- Ensure equipment slots are cached (may need to open character panel)

## Notes

- All integrations are optional and non-essential
- Integrations may affect performance depending on the third-party addon
- Some integrations (Pawn, SimpleItemLevel) are mutually exclusive
- ConsolePort integration modifies config behavior when active