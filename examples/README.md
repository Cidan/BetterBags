# Examples Module

The Examples module provides practical, working examples and templates for extending BetterBags functionality through plugins and custom integrations. This serves as a reference implementation for developers creating BetterBags extensions.

## Overview

The Examples module demonstrates:
- Plugin development patterns
- Category creation methods
- API usage best practices
- Configuration integration
- Localization handling

## Plugin Example (`plugin/plugin.lua`)

A complete, annotated example showing how to create a BetterBags plugin addon.

### Plugin Structure

#### Required Setup
```lua
-- 1. Get BetterBags addon handle
local addon = LibStub('AceAddon-3.0'):GetAddon("BetterBags")

-- 2. Get required modules
local categories = addon:GetModule('Categories')
local config = addon:GetModule('Config')
local L = addon:GetModule('Localization')
local context = addon:GetModule('Context')
```

#### Addon Requirements
- **TOC File**: Your addon must have a `.toc` file
- **Dependency**: Must declare BetterBags as a dependency
- **No Bundling**: Don't bundle Ace or other libraries (BetterBags provides them)

Example `.toc` file:
```toc
## Interface: 100200
## Title: My BetterBags Plugin
## Author: YourName
## Version: 1.0
## Dependencies: BetterBags

plugin.lua
```

### Category Management APIs

#### Adding Items to Categories
```lua
-- Create a context for tracking
local ctx = context:New('MyAddon_Event')

-- Add a single item to a category
categories:AddItemToCategory(ctx, 12345, L:G("My Category"))

-- The category will be created automatically if it doesn't exist
```

#### Wiping Categories
```lua
-- Clear all items from a category (but keep the category)
categories:WipeCategory(ctx, L:G("My Category"))

-- Useful for refreshing category contents on plugin load
```

#### Creating Complex Categories
```lua
categories:CreateCategory(ctx, {
  -- Required: Category name
  name = L:G("My Category"),
  
  -- Option 1: Static item list
  itemList = {
    [12345] = true,  -- Item ID as key
    [67890] = true,
  },
  
  -- Option 2: Search-based category (overrides itemList)
  searchCategory = {
    query = "type = armor or type = weapon"
  },
  
  -- Optional: Persistence
  save = true,  -- Category survives sessions (default: false)
  
  -- Optional: Metadata
  note = L:G("Created by MyAddon"),
  
  -- Optional: Display priority (lower = first)
  priority = 1,  -- Only for search categories
})
```

### Dynamic Category Functions

Register functions that categorize items dynamically based on their properties:

```lua
categories:RegisterCategoryFunction("unique_id", function(data)
  -- data is an ItemData table with all item properties
  
  -- Example: Categorize by expansion
  if data.itemInfo.expacID == LE_EXPANSION_DRAGONFLIGHT then
    if data.itemInfo.itemName:match("Currency") then
      return L:G("Dragonflight Currency")
    end
  end
  
  -- Return nil to not categorize this item
  return nil
end)
```

## API Usage Examples

### Simple Item Categorization
```lua
-- Categorize all herbs
categories:RegisterCategoryFunction("herbs", function(data)
  if data.itemInfo.classID == Enum.ItemClass.Tradegoods and
     data.itemInfo.subclassID == 9 then  -- 9 = Herb
    return L:G("Herbs")
  end
  return nil
end)
```

### Expansion-Based Categories
```lua
-- Create categories for each expansion's consumables
local expansions = {
  [0] = "Classic",
  [1] = "Burning Crusade",
  [2] = "Wrath",
  -- ... etc
}

categories:RegisterCategoryFunction("expac_consumables", function(data)
  if data.itemInfo.classID == Enum.ItemClass.Consumable then
    local expacName = expansions[data.itemInfo.expacID]
    if expacName then
      return L:G(expacName .. " Consumables")
    end
  end
  return nil
end)
```

### Equipment Set Enhancement
```lua
-- Add special category for tier set pieces
categories:RegisterCategoryFunction("tier_sets", function(data)
  if data.itemInfo.setID and data.itemInfo.setID > 0 then
    -- Get set name from game API
    local setName = C_Item.GetItemSetInfo(data.itemInfo.setID)
    if setName and setName:match("Tier") then
      return L:G("Tier Sets")
    end
  end
  return nil
end)
```

### Search Query Examples
```lua
-- Complex search category
categories:CreateCategory(ctx, {
  name = L:G("Valuable Trade Goods"),
  searchCategory = {
    query = "type = 'Trade Goods' AND rarity >= 2 AND level >= 60"
  },
  priority = 5
})

-- Binding-based category
categories:CreateCategory(ctx, {
  name = L:G("Account Bound Items"),
  searchCategory = {
    query = "binding = 'account' OR binding = 'warbound'"
  }
})
```

## ItemData Structure Reference

When writing category functions, you receive an ItemData table with these properties:

```lua
data = {
  itemInfo = {
    itemID,         -- number: Item ID
    itemName,       -- string: Item name
    itemLink,       -- string: Item link
    itemQuality,    -- number: Quality (0-5)
    itemLevel,      -- number: Item level
    itemType,       -- string: Type name
    itemSubType,    -- string: Subtype name
    itemStackCount, -- number: Max stack size
    itemEquipLoc,   -- string: Equipment slot
    itemTexture,    -- number: Icon texture ID
    sellPrice,      -- number: Vendor price
    classID,        -- number: Item class ID
    subclassID,     -- number: Item subclass ID
    bindType,       -- number: Binding type
    expacID,        -- number: Expansion ID
    setID,          -- number: Equipment set ID
    isCraftingReagent, -- boolean
  },
  containerInfo = {
    -- Container-specific data
  },
  questInfo = {
    isQuestItem,    -- boolean
    isActive,       -- boolean
  },
  -- ... other properties
}
```

## Best Practices

### 1. Always Use Context
```lua
-- Create context for each operation
local ctx = context:New('MyAddon_Operation')
categories:AddItemToCategory(ctx, itemID, category)
```

### 2. Use Localization
```lua
-- Always wrap user-visible strings
local categoryName = L:G("My Category")
-- Not: local categoryName = "My Category"
```

### 3. Cache Results
```lua
-- Category functions are cached automatically
-- Don't worry about performance after first scan
```

### 4. Handle Nil Gracefully
```lua
categories:RegisterCategoryFunction("safe", function(data)
  -- Check for nil values
  if not data or not data.itemInfo then
    return nil
  end
  
  -- Safe property access
  local name = data.itemInfo.itemName
  if name and name:match("Pattern") then
    return L:G("Patterns")
  end
  
  return nil
end)
```

### 5. Unique Function IDs
```lua
-- Use unique, descriptive IDs
categories:RegisterCategoryFunction("myAddon_herbs", herbFunction)
-- Not: categories:RegisterCategoryFunction("func1", herbFunction)
```

## Plugin Development Workflow

### 1. Create Addon Structure
```
MyBetterBagsPlugin/
├── MyBetterBagsPlugin.toc
├── main.lua
└── categories.lua
```

### 2. Set Up Dependencies
```toc
## Dependencies: BetterBags
## OptionalDeps: BetterBags_Config
```

### 3. Initialize on Load
```lua
local function OnAddonLoaded(_, addonName)
  if addonName ~= "BetterBags" then return end
  
  -- BetterBags is loaded, initialize plugin
  InitializePlugin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", OnAddonLoaded)
```

### 4. Clean Up on Disable
```lua
-- Wipe categories if plugin is disabled
local function OnPluginDisable()
  local ctx = context:New('Plugin_Disable')
  categories:WipeCategory(ctx, L:G("My Plugin Category"))
end
```

## Common Patterns

### Conditional Categories
```lua
-- Only show category based on player class
categories:RegisterCategoryFunction("class_items", function(data)
  local _, class = UnitClass("player")
  if class == "WARRIOR" and data.itemInfo.itemEquipLoc == "INVTYPE_2HWEAPON" then
    return L:G("Warrior Weapons")
  end
  return nil
end)
```

### Profession-Based Categories
```lua
-- Categorize by profession relevance
local professions = {
  Enchanting = {6217, 10938, 11083}, -- Dust/essence IDs
  -- ... more professions
}

categories:RegisterCategoryFunction("profession", function(data)
  for prof, items in pairs(professions) do
    for _, itemID in ipairs(items) do
      if data.itemInfo.itemID == itemID then
        return L:G(prof .. " Materials")
      end
    end
  end
  return nil
end)
```

## Debugging Plugins

```lua
-- Enable debug mode for testing
local debug = addon:GetModule('Debug')

categories:RegisterCategoryFunction("debug", function(data)
  debug:Log("Plugin", "Processing item:", data.itemInfo.itemName)
  -- Category logic here
end)
```

## Performance Considerations

1. **Function Caching**: Results are cached per item
2. **Minimal Processing**: Keep category functions lightweight
3. **Batch Operations**: Use WipeCategory before bulk adds
4. **Lazy Loading**: Don't process until BetterBags is ready

## Error Handling

```lua
-- Wrap operations in protected calls
local success, err = pcall(function()
  categories:CreateCategory(ctx, categoryData)
end)

if not success then
  print("BetterBags Plugin Error:", err)
end
```

## Testing Your Plugin

1. **Enable Debug Mode**: `/bb debug enable`
2. **Check Categories**: Open bags and verify categorization
3. **Test Persistence**: Reload UI and check saved categories
4. **Performance Check**: Monitor with `/bb debug profile`

## Support and Resources

- **API Documentation**: See individual module READMEs
- **Discord**: Join BetterBags Discord for support
- **GitHub**: Submit issues or pull requests
- **Examples**: This folder contains working examples

## Version Compatibility

Always check BetterBags version compatibility:
```lua
local version = addon.version or "unknown"
if version < "2.0.0" then
  print("Plugin requires BetterBags 2.0.0 or higher")
  return
end