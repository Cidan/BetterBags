# Data Module

The Data module is the core data management layer of BetterBags, responsible for all item-related operations including loading, caching, searching, categorization, and refresh management. This module provides the foundation for the addon's inventory management capabilities.

## Overview

The Data module handles:
- Item data loading and caching
- Category management (both custom and search-based)
- Full-text search with query parsing
- Equipment set tracking
- Item binding information
- Refresh and update coordination
- Item stacking logic
- Slot management

## Core Components

### Items (`items.lua`)

The main item management module that handles all item data operations including async loading with ContinuableContainer.

#### Key Features
- **Unified Item Loading**: Uses ContinuableContainer for efficient async item data loading
- **Item Data Management**: Stores and manages all item information including stats, quality, binding status, etc.
- **Bag Type Detection**: Identifies different bag types (normal, profession, reagent)
- **Item Hashing**: Generates unique hashes for item stacking
- **Category Assignment**: Determines item categories based on filters
- **New Item Tracking**: Manages "new item" status with timers
- **Equipment Data**: Handles equipped item information

#### Key Functions
```lua
-- Refresh all items in backpack
items:RefreshBackpack(ctx)

-- Refresh all items in bank
items:RefreshBank(ctx)

-- Get item data from a slot key
items:GetItemDataFromSlotKey(slotkey)

-- Mark an item as new
items:MarkItemAsNew(ctx, data)

-- Get item category
items:GetCategory(ctx, data)

-- Restack items (internal sort)
items:Restack(ctx, kind, callback)
```

#### Item Data Structure
```lua
---@class ItemData
---@field itemInfo ExpandedItemInfo    -- Core item information
---@field containerInfo ContainerItemInfo -- Container-specific data
---@field questInfo ItemQuestInfo      -- Quest item information
---@field transmogInfo TransmogInfo    -- Transmog appearance data
---@field bindingInfo BindingInfo      -- Binding status
---@field bagid number                 -- Bag ID
---@field slotid number                -- Slot ID
---@field slotkey string               -- Unique bag_slot identifier
---@field itemHash string              -- Hash for stacking
---@field category string              -- Assigned category
```

### Categories (`categories.lua`)

Manages both custom user-defined categories and dynamic search categories.

#### Features
- **Custom Categories**: User-defined item groups
- **Search Categories**: Dynamic categories based on search queries
- **Priority System**: Categories can have priorities for ordering
- **Per-Bag Enable/Disable**: Categories can be toggled per bag type
- **Ephemeral Categories**: Temporary runtime categories
- **Category Functions**: Plugin system for dynamic categorization

#### Key Functions
```lua
-- Create a new category
categories:CreateCategory(ctx, {
  name = "Category Name",
  itemList = {},
  enabled = {[BAG_KIND.BACKPACK] = true},
  priority = 100
})

-- Add item to category
categories:AddItemToCategory(ctx, itemID, categoryName)

-- Register a category function for dynamic categorization
categories:RegisterCategoryFunction(id, func)

-- Get all categories
categories:GetAllCategories()
```

### Search (`search.lua`)

Provides a powerful full-text search engine with query parsing capabilities.

#### Features
- **Multiple Index Types**:
  - String indexes (name, type, category, etc.)
  - Number indexes (level, rarity, id, etc.)
  - Boolean indexes (bound, quest, reagent)
- **Query Operators**:
  - `=` (equals)
  - `!=` (not equals)
  - `>`, `<`, `>=`, `<=` (comparisons)
  - `%=` (contains/partial match)
- **Logical Operators**: AND, OR, NOT
- **N-gram Indexing**: Fast prefix searching
- **Interval Trees**: Efficient number range queries

#### Search Query Examples
```lua
-- Simple text search
"Potion"

-- Field-specific search
"name=sword"
"level>=60"
"rarity=epic"

-- Complex queries
"type=weapon AND level>=60"
"bound=true OR quest=true"
"NOT reagent=true"
```

#### Key Functions
```lua
-- Search for items
search:Search("query string")

-- Add item to search index
search:Add(itemData)

-- Remove item from index
search:Remove(itemData)

-- Check if item matches query
search:Find(query, item)
```

### Refresh (`refresh.lua`)

Coordinates bag updates and refresh operations.

#### Features
- **Event Batching**: Groups multiple update events
- **Combat Safety**: Defers certain operations during combat
- **Sort Integration**: Handles item restacking/sorting
- **Update Queue**: Manages pending updates
- **Draw Coordination**: Triggers UI redraws after data updates

#### Update Flow
1. WoW events trigger updates (BAG_UPDATE, etc.)
2. Events are queued in UpdateQueue
3. StartUpdate processes the queue
4. Items module refreshes data
5. Draw operations update the UI

### Equipment Sets (`equipmentsets.lua`)

Tracks which items belong to equipment sets.

#### Features
- **Set Detection**: Identifies items in equipment sets
- **Multi-Set Support**: Items can belong to multiple sets
- **Cross-Version Support**: Works on Retail and Classic

### Binding (`binding.lua`)

Determines item binding status and scope.

#### Binding Types
- `NONBINDING` - Never binds
- `BOE` - Bind on Equip
- `BOU` - Bind on Use
- `BNET` - Battle.net bound
- `WUE` - Warbound until Equipped (Retail)
- `SOULBOUND` - Bound to character
- `ACCOUNT` - Account-bound/Warbound
- `QUEST` - Quest item
- `REFUNDABLE` - Can be refunded

### Loader (`loader.lua`)

Handles asynchronous item data loading.

#### Features
- **Batch Processing**: Loads items in batches for performance
- **Continuable Pattern**: Uses WoW's async loading API
- **Equipment Support**: Special handling for equipped items
- **Memory Efficient**: Cleans up after loading

### Slots (`slots.lua`)

Manages slot information and change tracking.

#### Features
- **Change Detection**: Tracks added/removed/updated items
- **Empty Slot Management**: Maintains lists of free slots
- **Stack Integration**: Coordinates with stacking system
- **Changeset Generation**: Provides item change information

### Stacks (`stacks.lua`)

Manages item stacking logic.

#### Features
- **Stack Tracking**: Groups stackable items
- **Root Item Selection**: Chooses primary stack item
- **Dynamic Updates**: Adjusts as items are added/removed
- **Count Management**: Tracks total stack counts

## Usage Examples

### Refreshing Bags
```lua
local ctx = Context:New()
items:RefreshBackpack(ctx)
items:RefreshBank(ctx)
```

### Creating Custom Categories
```lua
categories:CreateCategory(ctx, {
  name = "Consumables",
  itemList = {[12345] = true}, -- Item IDs
  enabled = {
    [const.BAG_KIND.BACKPACK] = true,
    [const.BAG_KIND.BANK] = true
  }
})
```

### Searching Items
```lua
-- Find all epic items above level 60
local results = search:Search("rarity=epic AND level>60")

-- Find items by name
local potions = search:Search("name%=potion")
```

### Tracking Equipment Sets
```lua
local sets = equipmentSets:GetItemSets(bagID, slotID)
if sets then
  print("Item belongs to:", table.concat(sets, ", "))
end
```

## Architecture

### Data Flow
1. **Event System** → Triggers refresh
2. **Refresh Module** → Coordinates updates
3. **Loader** → Asynchronously loads item data
4. **Items Module** → Processes and caches data
5. **Search/Categories** → Index and categorize
6. **UI Layer** → Displays organized items

### Performance Considerations
- **Async Loading**: Prevents UI freezing
- **Batch Processing**: Reduces frame drops
- **Indexed Search**: O(1) lookups for most queries
- **Change Detection**: Only updates modified items
- **Smart Caching**: Minimizes API calls

## Events

### Incoming Events
- `BAG_UPDATE` - Bag contents changed
- `BAG_UPDATE_DELAYED` - Batched bag updates
- `EQUIPMENT_SETS_CHANGED` - Equipment sets modified
- `bags/RefreshAll` - Manual refresh request
- `bags/SortBackpack` - Sort request

### Outgoing Events
- `items/RefreshBackpack/Done` - Backpack refresh complete
- `items/RefreshBank/Done` - Bank refresh complete
- `categories/Changed` - Categories modified
- `bags/Draw/Backpack/Done` - UI draw complete

## Dependencies

### Required Modules
- **Context**: Context management
- **Events**: Event system
- **Constants**: Constant definitions
- **Database**: Persistent storage
- **Debug**: Debugging utilities
- **Async**: Asynchronous operations
- **Trees**: Interval tree for search
- **QueryParser**: Search query parsing
- **Localization**: String translations

## Configuration

The Data module respects various database settings:
- `GetMarkRecentItems()` - Track new items
- `GetNewItemTime()` - New item duration
- `GetStackingOptions()` - Stacking preferences
- `GetCategoryFilter()` - Category display options

## Best Practices

1. **Always use Context**: Pass context through operations for tracing
2. **Batch Operations**: Group multiple changes when possible
3. **Check Combat State**: Defer heavy operations during combat
4. **Clean Up Resources**: Clear caches when appropriate
5. **Validate Data**: Check for nil/empty before processing

## Technical Notes

- **Slot Keys**: Format is `bagID_slotID` (e.g., "0_1")
- **Item Hashing**: Includes item ID, enchants, gems, binding
- **N-gram Index**: Supports incremental prefix search
- **Interval Trees**: Red-black trees for number ranges
- **Equipment Slots**: Special handling for worn items

## Debugging

Enable debug logging:
```lua
debug:Enable("Items")
debug:Enable("Search")
```

Common debug points:
- Item loading delays
- Category assignment issues
- Search index mismatches
- Stacking problems
- Refresh timing