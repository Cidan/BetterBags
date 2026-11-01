# BetterBags Integrations Module

The integrations module provides seamless compatibility with popular World of Warcraft addons, enhancing BetterBags functionality when these addons are present.

## Table of Contents

- [Overview](#overview)
- [Supported Integrations](#supported-integrations)
  - [ConsolePort](#consoleport-consoleportlua)
  - [Masque](#masque-masquelua)
  - [Pawn](#pawn-pawnlua)
  - [SimpleItemLevel](#simpleitemlevel-simpleitemlevellua)
  - [Profession Shopping List](#profession-shopping-list-professionshoppinglistlua)
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
- Separate groups for Backpack, Bank and BetterBags Next's Vendor
- Respects the theme's `Masque = false` (`Sonata:UsesMasque()`), taking buttons out of their groups when such a theme is applied
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
- `BetterBags/Vendor` - BetterBags Next's vendor buttons (`next/vendorbutton.lua`): their square
  button, with its parts named (`Icon`, `IconBorder`, `Count`, `Highlight`), as an `Item` button

**Event Handlers:**
- `item/NewButton` - Register new item buttons
- `item/Updated` - Update button registration (sent by a full button draw; a redraw whose inputs are unchanged is skipped and sends nothing)
- `item/Clearing` - Not handled: a released item button stays in its group (buttons exist for the whole session; its next draw re-skins it)
- `bagbutton/Updated` - Register bag slot buttons
- `bagbutton/Clearing` - Remove bag slot buttons
- `vendor/NewButton` - Register a new vendor button (sent once per button; vendor buttons are reused,
  and a theme that uses Masque adds back the ones a theme without it took out)
- `vendor/Updated` - Re-skin a vendor button that styled itself again for a new pixel grid (its icon,
  count and highlight drawn over the skin; `NextVendorButton:Fit`), adding it when it is not in the group
- `guild/NewButton`, `guild/Updated` - Register a guild bank button, and re-skin it after every draw or
  restyle

**Methods:**
| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `AddButtonToGroup(group, button)` | Add button to Masque group | `string`, `Button` | - |
| `RemoveButtonFromGroup(group, button)` | Remove button from group | `string`, `Button` | - |
| `IsGroupEnabled(group)` | Check if group is enabled | `string` | `boolean` |
| `ReapplyBlend(button)` | Fix blend mode | `Button` | - |
| `IsSkinned(button)` | Whether the button is in one of BetterBags' Masque groups (Masque places its parts; BetterBags Next's item fitter leaves them alone) | `Button` | `boolean` |

### Pawn (`pawn.lua`)

Shows item upgrade indicators using Pawn's upgrade detection, the way Pawn asks a bag addon to work with it (`PawnBags.lua`).

**Key Components:**
```lua
-- Asked about each item link; nil means past Pawn's budget, or no item data yet: check back on a timer
PawnShouldItemLinkHaveUpgradeArrow(itemLink, true)
-- RefreshAll is called when arrows may have changed. Registering also turns off Pawn's arrows on Blizzard's bag frames
PawnRegisterThirdPartyBag("BetterBags", { RefreshAll = ... })
```

**Behavior:**
- Answers are kept by item link, without the player's level and spec: a sort, a re-read or a respec asks Pawn nothing in the read, and a read only asks about an item it has not seen
- An item Pawn has no answer for yet is not treated as "not an upgrade": no `upgrade` search field, and Automation leaves it alone
- Pawn's signal asks for no refresh: every item held is checked again a few at a time, showing its old arrow meanwhile
- Only an arrow that changed recalculates the bags holding it, and no category or button is redone for it
- Nothing is checked again during combat

Details: `.claude/rules/caches.md` §2a.

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

### Profession Shopping List (`professionshoppinglist.lua`)

Buys what Profession Shopping List's list needs from a BetterBags Next vendor
(`.claude/rules/profession-shopping-list.md`).

**Features:**
- A Shopping List section at the top of the vendor's Buy tab: what the list buys there, how many, and
  what they cost
- Docked in a green card ("Buy N items?", the total price): a double click buys it all

**Key Components:**
```lua
-- Profession Shopping List's API
ProfessionShoppingList:GetShoppingList() -- itemID = { required, owned }
ProfessionShoppingList:BuyFromMerchant()
EventRegistry "ProfessionShoppingList.OnTrackedRecipesChanged"
```

**Behavior:**
- Only activates when Profession Shopping List has both `GetShoppingList` and `BuyFromMerchant`
- Retries on `ADDON_LOADED` when Profession Shopping List loads after BetterBags
- Sends `shoppingList/Changed` when the tracked recipes change

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
- For Masque: Using a theme with `Masque = false`

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
6. **Theme Respect**: Honor theme settings (e.g., `Masque = false`)
7. **Graceful Degradation**: Continue working if integration fails

## Troubleshooting

### Integration Not Working

1. **Check addon is installed**: Verify third-party addon is present
2. **Check load order**: BetterBags should load after integrated addon
3. **Check chat message**: Look for "integration enabled" message
4. **Check errors**: Use `/console scriptErrors 1`

### Masque Skins Not Applying

- Ensure the theme doesn't set `Masque = false`
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