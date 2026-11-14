# Data Module

The Data module is the core data management layer of BetterBags, responsible for all item-related operations including loading, caching, searching, categorization, and refresh management. This module provides the foundation for the addon's inventory management capabilities.

## Overview

The Data module handles:
- Item data loading and caching
- Category management (both custom and search-based)
- Full-text search with query parsing
- Tooltip text extraction and indexing
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
- **Item Level Tracking**: Updates per-character max item level and notifies listeners for dynamic color scaling
- **Bag Type Detection**: Identifies different bag types (normal, profession, reagent, keyring). The keyring (Classic Era, and WoW: Forever) is read with the backpack, only the slots the game opens (`GetKeyRingSize()`; the rest are padlocked), its slots are not free space, and Show Bags names it "Keyring", numbered after the last bag (`GetBagName`) and listed after every bag (`.claude/rules/keyring.md`). Each empty slot of a specialized bag carries its bag type's glyph (`itemInfo.emptySlotFamilyIcon`, `GetEmptySlotFamilyIcon` by bag family; the retail reagent bag and the keyring by bag ID; `.claude/rules/item-drawing.md` §11)
- **Item Hashing**: Generates unique hashes for item stacking
- **Category Assignment**: Determines item categories based on filters. Items no custom or search category claims get their built-in category (`BuiltInCategory`), Blizzard's (`BlizzardCategory`): Junk, their equipment location, or the enabled filters joined with " - ": item type, subtype, trade skill, expansion. A subtype equal to the type before it is skipped, so quest items read "Quest", not "Quest - Quest" (settings saved under old names are moved by `DB:RenameRepeatedTypeCategories`, `.claude/rules/category-lifecycle.md` §5). An item that a category of the player's with that Blizzard name ignores, in a bag that uses the category, goes to "Everything" instead (`.claude/rules/category-lifecycle.md` §11)
- **New Item Tracking**: Manages "new item" status with timers
- **Junk Mark**: Every sweep marks each item with whether Blizzard's junk coin shows on it (`junkMarked`: poor, sells for something, `MerchantFrame:IsShown()`), so opening or closing a vendor redraws only the junk (`.claude/rules/item-drawing.md` §7b)
- **Equipment Data**: Handles equipped item information

#### Key Functions
```lua
-- Refresh all items in backpack
items:RefreshBackpack(ctx)

-- Refresh all items in bank
items:RefreshBank(ctx)

-- Get item data from a slot key
items:GetItemDataFromSlotKey(slotkey)

-- Mark an item as new (starts its Recent Items timer; the next refresh shows it there)
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
- **Per-Bag Enable/Disable**: Categories can be toggled per bag type. Whether a bag uses a category decides everything it does there: its color, Hide In, automation and Ignored Items are looked up through `CategoryIn(name, kind)`, which finds nothing in a bag that does not use it
- **Blizzard Categories Made Yours**: `Convert(ctx, name)` makes a Blizzard category (one BetterBags names from item data) a category of the player's with the same name, marked `blizzard`, so Blizzard's items keep landing in it; it never groups, and renaming it makes an ordinary category (`.claude/rules/category-lifecycle.md` §11)
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

-- The category whose settings a section of this name takes in a bag (a group by's section: its
-- category), or nil for a Blizzard category or a bag that does not use it
categories:CategoryIn(name, kind)

-- What a category does on its own in a bag (a group by's sections as their category): Auto Sell
-- ("sell", "destroy" or nil), whether its sale waits for the player, and where Auto Deposit puts its
-- items ("bank", "warbank" or nil)
categories:AutomationOf(name, kind)
categories:ConfirmsSaleOf(name, kind)
categories:DepositOf(name, kind)
categories:UpdateCategory(ctx, name, { automation = "sell", confirmSale = false, deposit = "warbank" })

-- Make a Blizzard category the player's (false for a name a category has); the caller recalculates the bags
categories:Convert(ctx, name)

-- After every committed read: categories of the player's named as a Blizzard category the read's items have
-- become converted ones (their group by and its sections go), the bags recalculated once if any did
categories:ConvertNamed(ctx, names)
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
- **N-gram Indexing**: Fast prefix searching (except the `tooltip` index, which stores full text only; `=`/`!=` on it are substring matches)
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

### Tooltip Scanner (`tooltip.lua`)

Extracts and caches tooltip text from items for search indexing, enabling users to search for items by text that appears in their tooltips.

#### Features
- **Dual API Support**:
  - Retail: Uses modern `C_TooltipInfo.GetBagItem()` API
  - Classic/Era: Uses GameTooltip scanning with FontString iteration
- **GUID-Based Caching**: Prevents repeated expensive tooltip extractions
- **Automatic Integration**: Tooltip text automatically indexed during item loading
- **Memory Efficient**: ~150KB cache for 500 items

#### Use Cases
Users can search for:
- Profession skill items by searching "Study"
- Equipment by slot type: "Hand", "Waist", "Weapon"
- Crafting reagents by profession name
- Any text that appears in item tooltips

#### Key Functions
```lua
-- Extract tooltip text for an item (with caching)
tooltipScanner:GetTooltipText(bagid, slotid, itemGUID)

-- Clear entire cache (called on item cache wipe)
tooltipScanner:ClearCache()

-- Remove specific item from cache
tooltipScanner:RemoveFromCache(itemGUID)

-- Get cache size for monitoring
tooltipScanner:GetCacheSize()
```

#### Implementation Details
- **Retail Extraction**: Uses `C_TooltipInfo.GetBagItem()` to get structured TooltipData with lines array
- **Classic Extraction**: Creates hidden GameTooltip, populates with `SetBagItem()`, reads FontStrings
- **Text Concatenation**: All tooltip lines (left and right text) joined with spaces
- **Classic Line Limit**: Capped at 30 lines to avoid WoW's 9+ line FontString naming bug
- **Search Integration**: Tooltip text added to search index as "tooltip" field, included in default search

#### Example Usage
```lua
-- Automatically happens during item loading:
local tooltipText = tooltipScanner:GetTooltipText(bagid, slotid, itemGUID)
-- Result: "Item Name\nBinds when picked up\n+15 Agility\n..."

-- Users can then search:
-- "study" - finds profession skill items
-- "tooltip%=equip" - finds items with "equip" in tooltip
-- "name:sword AND NOT tooltip:bind" - swords that don't bind
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

### Automation (`automation.lua`)

What a category does with the backpack's items on its own, set in its Automation tab
(`.claude/rules/automation.md`). Every list reads the bags' last read; the client is asked about a slot
only when acting on it (`StillThere`).

#### Features
- **Auto Sell** (`OnMerchantShow`, `SellList`): sells a category's items when a merchant opens, through
  the Seller (`seller.lua`), one item at a time; a category that confirms waits in BetterBags Next's
  vendor dock (`SaleOffer`)
- **Destroy What Can't Be Sold** (`DestroyQueue`, `DestroyNext`): destroys what no merchant buys, one
  item per click or key press
- **Auto Deposit** (`OnBankShow`, `DepositList`, `StartDeposit`): when the bank opens, deposits a
  category's items into the character's bank or the Warbank, the frame after, all at once; Shift held
  keeps them, and what the Warbank refuses stays in the bags
- **Left alone** (`BlockedReason`): items whose data has not loaded, whose upgrade state is unknown, in
  an equipment set, or still refundable

### Groups (`groups.lua`)

A bag's tabs of categories (`.claude/rules/groups.md`): creating, renaming and deleting groups,
assigning a category to one, and the group shown. The data is saved by `core/database.lua`; which tab
each category is on is worked out when a bag is recalculated (`items:Phase10_PartitionIntoTabs`).

#### Messages
- `groups/Created (ctx, group)`, `groups/Changed (ctx, groupID, name, oldName, kind)`
- `groups/Deleted (ctx, groupID, groupName, kind, wasActive)`: sent once the database has deleted the
  group and, if it was shown, made the default group active; `wasActive` says whether it was the one
  shown, so a bag switches to the default group
- `groups/CategoryAssigned`, `groups/CategoryRemoved`, `groups/ActiveChanged`

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
- `MERCHANT_SHOW` / `BANKFRAME_OPENED` - Category automation sells or deposits
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
