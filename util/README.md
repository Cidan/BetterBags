# BetterBags Utilities Module

The utilities module provides essential helper functions, data structures, and algorithms that support various aspects of the BetterBags addon functionality.

## Table of Contents

- [Overview](#overview)
- [Core Utilities](#core-utilities)
  - [Bucket System](#bucket-system-bucketlua)
  - [Color Interpolation](#color-interpolation-colorlua)
  - [Movement Flow Detection](#movement-flow-detection-movementflowlua)
  - [Query Parser](#query-parser-querylua)
  - [Resize Handler](#resize-handler-resizelua)
  - [Sorting System](#sorting-system-sortlua)
  - [Window Grouping](#window-grouping-windowgrouplua)
- [Data Structures](#data-structures)
  - [Interval Tree](#interval-tree-treesintervaltreelua)
  - [Trees Module](#trees-module-treestreeslua)
- [Usage Examples](#usage-examples)
- [API Reference](#api-reference)

## Overview

The utilities module provides fundamental services including:
- Timer management and delayed execution
- Color calculations for item level display
- Context detection for item movement
- Search query parsing and evaluation
- Frame resizing functionality
- Comprehensive sorting algorithms
- Window state management
- Advanced data structures

## Core Utilities

### Bucket System (`bucket.lua`)

Provides a system for delayed function execution with automatic cancellation of duplicate calls.

**Purpose:**
- Prevent rapid repeated function calls
- Batch operations for performance
- Debounce event handlers

**Key Features:**
```lua
---@class BucketFunction
---@field name string
---@field func fun()
---@field delay number
```

**Methods:**
| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `Later(name, delay, func)` | Schedule delayed execution | `string`, `number`, `function` | - |

**Usage Example:**
```lua
-- Debounce rapid updates
bucket:Later("UpdateItems", 0.5, function()
  -- This will only run once even if called multiple times
  RefreshAllItems()
end)
```

### Color Interpolation (`color.lua`)

Calculates appropriate colors for item level display using discrete tiers (low/mid/high/max) based on dynamic breakpoints.

**Color Table:**
```lua
-- Item level to RGB color mapping
[1] = {0.62, 0.62, 0.62},    -- Gray
[300] = {0, 0.55, 0.87},      -- Blue
[420] = {1, 1, 1},            -- White
[489] = {1, 0.5, 0}           -- Orange
```

**Methods:**
| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `GetItemLevelColor(itemLevel)` | Get RGB color for item level | `number` | `r, g, b` |

**Algorithm:**
- Finds lower and upper bounds for given value
- Performs linear interpolation between colors
- Handles edge cases gracefully

### Movement Flow Detection (`movementflow.lua`)

Detects the current context for item movement operations.

**Movement Flow Types:**
```lua
MOVEMENT_FLOW = {
  UNDEFINED = 0,
  BANK = 1,
  SENDMAIL = 2,
  TRADE = 3,
  NPCSHOP = 4,
  WARBANK = 5,
  REAGENT = 6
}
```

**Methods:**
| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `GetMovementFlow()` | Get current movement context | - | `MovementFlowType` |
| `AtSendMail()` | Check if at mail | - | `boolean` |
| `AtTradeWindow()` | Check if trading | - | `boolean` |
| `AtNPCShopWindow()` | Check if at vendor | - | `boolean` |

**Context Detection:**
- Checks open UI frames
- Determines bank tab type
- Handles retail/classic differences

### Query Parser (`query.lua`)

A complete lexer and parser for search query syntax, supporting complex boolean expressions.

**Supported Syntax:**
- Boolean operators: `AND`, `OR`, `NOT`
- Comparison operators: `=`, `!=`, `<`, `<=`, `>`, `>=`, `%=`
- Parentheses for grouping
- Quoted strings for exact matches

**Query Node Types:**
```lua
---@class QueryNode
---@field type string      -- "term", "logical", "comparison", "paren"
---@field value? string
---@field left? QueryNode
---@field right? QueryNode
---@field operator? string
---@field field? string
---@field expression? QueryNode
```

**Methods:**
| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `Query(input)` | Parse query string | `string` | `QueryNode` |

**Example Queries:**
```lua
-- Simple search
"sword"

-- Field comparison
"ilvl >= 400"

-- Complex boolean
"(type = 'Armor' AND ilvl > 350) OR quality = 'Epic'"

-- With NOT operator
"NOT soulbound AND tradeable"
```

### Resize Handler (`resize.lua`)

Provides frame resizing functionality with visual feedback.

**Methods:**
| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `MakeResizable(frame, onDone)` | Add resize handle | `Frame`, `function` | `Button` |

**Features:**
- Visual resize handle (corner grip)
- Minimum size constraints (300x300)
- Hover visibility
- Completion callback

**Usage:**
```lua
local handle = resize:MakeResizable(myFrame, function()
  -- Called when resize completes
  SaveFrameSize()
end)
```

### Sorting System (`sort.lua`)

Comprehensive sorting algorithms for both sections and items.

**Sort Types:**

**Section Sorting:**
```lua
SECTION_SORT_TYPE = {
  ALPHABETICALLY = 1,
  SIZE_ASCENDING = 2,
  SIZE_DESCENDING = 3
}
```

**Item Sorting:**
```lua
ITEM_SORT_TYPE = {
  ALPHABETICALLY_THEN_QUALITY = 1,
  QUALITY_THEN_ALPHABETICALLY = 2,
  ITEM_LEVEL = 3
}
```

**Key Functions:**

| Function | Description | Parameters | Returns |
|----------|-------------|------------|---------|
| `GetSectionSortFunction(kind, view)` | Get section sort function | `BagKind`, `BagView` | `function` |
| `GetItemSortFunction(kind, view)` | Get item sort function | `BagKind`, `BagView` | `function` |
| `SortSectionsByPriority(kind, a, b)` | Priority-based section sort | `BagKind`, `Section`, `Section` | `boolean, boolean` |

**Sort Algorithms:**

**Sections:**
- Alphabetical with special handling for "Recent Items" and "Free Space"
- Size-based (ascending/descending) with item count
- Custom priority pinning

**Items:**
- Quality → Name → Count → GUID
- Name → Quality → Count → GUID
- Item Level → Name → Count → GUID

**Special Cases:**
- Free slots always sort last
- Recent Items section always first
- Fill-width sections sort separately
- Invalid data handling

### Window Grouping (`windowgroup.lua`)

Manages groups of related windows with exclusive visibility and animations.

**Key Features:**
- Only one window visible at a time
- Animated transitions between windows
- Callback support for transitions

**WindowGrouping Class:**
```lua
---@class WindowGrouping
---@field windows any[]
```

**Methods:**
| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `Create()` | Create new window group | - | `WindowGrouping` |
| `AddWindow(name, frame)` | Add window to group | `string`, `Frame` | - |
| `Show(name)` | Show specific window | `string` | - |

**Usage:**
```lua
local group = windowGroup:Create()
group:AddWindow('config', configFrame)
group:AddWindow('themes', themeFrame)
group:AddWindow('currency', currencyFrame)

-- Show themes (hides others)
group:Show('themes')
```

## Data Structures

### Interval Tree (`trees/intervaltree.lua`)

A binary search tree optimized for interval queries and range operations.

**Features:**
- O(log n) insertion
- Efficient range queries
- Metadata storage per node
- Min/max tracking

**IntervalTreeNode:**
```lua
---@class IntervalTreeNode
---@field value number
---@field left? IntervalTreeNode
---@field right? IntervalTreeNode
---@field min number
---@field max number
---@field data? table<any, any>
```

**Methods:**

| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `Insert(value, data)` | Add value with metadata | `number`, `table` | - |
| `LessThan(value)` | Find nodes < value | `number` | `IntervalTreeNode[]` |
| `LessThanEqual(value)` | Find nodes ≤ value | `number` | `IntervalTreeNode[]` |
| `GreaterThan(value)` | Find nodes > value | `number` | `IntervalTreeNode[]` |
| `GreaterThanEqual(value)` | Find nodes ≥ value | `number` | `IntervalTreeNode[]` |
| `ExactMatch(value)` | Find exact value | `number` | `IntervalTreeNode?` |
| `RemoveData(value, key)` | Remove metadata | `number`, `any` | - |

**Use Cases:**
- Item level range queries
- Price range filtering
- Time-based lookups

### Trees Module (`trees/trees.lua`)

Factory module for creating tree data structures.

**Methods:**
| Method | Description | Parameters | Returns |
|--------|-------------|------------|---------|
| `NewIntervalTree()` | Create interval tree | - | `IntervalTree` |

## Usage Examples

### Bucket Timer Example
```lua
-- Batch multiple rapid updates
function OnItemUpdate()
  bucket:Later("RefreshDisplay", 0.1, function()
    -- Will only execute once after 0.1 seconds
    -- even if OnItemUpdate is called 100 times
    RefreshEntireDisplay()
  end)
end
```

### Color Interpolation Example
```lua
-- Get color for item level 385
local r, g, b = color:GetItemLevelColor(385)
itemLevelText:SetTextColor(r, g, b)
```

### Movement Flow Example
```lua
-- Detect current context
local flow = movementFlow:GetMovementFlow()
if flow == const.MOVEMENT_FLOW.NPCSHOP then
  -- At vendor, enable sell mode
  EnableQuickSell()
elseif flow == const.MOVEMENT_FLOW.WARBANK then
  -- At warbank, show account-wide items
  ShowAccountItems()
end
```

### Query Parser Example
```lua
-- Parse complex search query
local ast = QueryParser:Query("ilvl >= 400 AND (type = 'Weapon' OR type = 'Armor')")
if ast then
  -- Evaluate AST against items
  EvaluateQuery(ast, item)
end
```

### Sorting Example
```lua
-- Get appropriate sort function
local sortFunc = sort:GetItemSortFunction(
  const.BAG_KIND.BACKPACK,
  const.BAG_VIEW.SECTION_GRID
)

-- Sort items
table.sort(items, sortFunc)
```

### Window Group Example
```lua
-- Create exclusive window group
local sidePanel = windowGroup:Create()
sidePanel:AddWindow('categories', categoryFrame)
sidePanel:AddWindow('search', searchFrame)
sidePanel:AddWindow('settings', settingsFrame)

-- Show categories (hides others with animation)
sidePanel:Show('categories')
```

### Interval Tree Example
```lua
-- Create tree for item level ranges
local ilvlTree = trees.NewIntervalTree()

-- Insert items with their item levels
ilvlTree:Insert(385, {itemID = 12345, name = "Epic Sword"})
ilvlTree:Insert(400, {itemID = 67890, name = "Legendary Axe"})

-- Find all items with ilvl >= 390
local highLevel = ilvlTree:GreaterThanEqual(390)
for _, node in ipairs(highLevel) do
  print(node.data.name, node.value)
end
```

## API Reference

### Bucket Module
```lua
bucket:Later(name: string, delay: number, func: function)
```

### Color Module
```lua
color:GetItemLevelColor(itemLevel: number): number, number, number
```

### MovementFlow Module
```lua
movementFlow:GetMovementFlow(): MovementFlowType
movementFlow:AtSendMail(): boolean
movementFlow:AtTradeWindow(): boolean
movementFlow:AtNPCShopWindow(): boolean
```

### QueryParser Module
```lua
QueryParser:Query(input: string): QueryNode?
```

### Resize Module
```lua
resize:MakeResizable(frame: Frame, onDone: function): Button
```

### Sort Module
```lua
sort:GetSectionSortFunction(kind: BagKind, view: BagView): function
sort:GetItemSortFunction(kind: BagKind, view: BagView): function
```

### WindowGroup Module
```lua
windowGroup:Create(): WindowGrouping
WindowGrouping:AddWindow(name: string, frame: Frame)
WindowGrouping:Show(name: string)
```

### Trees Module
```lua
trees.NewIntervalTree(): IntervalTree
IntervalTree:Insert(value: number, data: table)
IntervalTree:LessThan(value: number): IntervalTreeNode[]
IntervalTree:GreaterThan(value: number): IntervalTreeNode[]
IntervalTree:ExactMatch(value: number): IntervalTreeNode?
```

## Best Practices

### Performance
- Use bucket timers for expensive operations
- Cache sort functions when possible
- Reuse interval trees for repeated queries
- Minimize query parsing in hot paths

### Error Handling
- Query parser returns nil on invalid syntax
- Movement flow defaults to UNDEFINED
- Sort functions handle invalid data gracefully
- Window groups require fadeIn/fadeOut animations

### Memory Management
- Clear interval trees when data changes significantly
- Release window group references when done
- Bucket timers auto-cleanup after execution

## Integration with Other Modules

- **Items Module**: Uses sorting for item organization
- **Search Module**: Uses query parser for search syntax
- **Frames Module**: Uses resize for bag windows
- **Data Module**: Uses movement flow for context
- **Views Module**: Uses window groups for panels
- **Database Module**: Stores sort preferences

## Common Patterns

### Debouncing
```lua
-- Prevent rapid repeated calls
function OnFrequentEvent()
  bucket:Later("UniqueKey", 0.5, ExpensiveOperation)
end
```

### Context-Aware Actions
```lua
-- Different behavior based on context
local flow = movementFlow:GetMovementFlow()
local handler = flowHandlers[flow] or defaultHandler
handler:Execute()
```

### Progressive Sorting
```lua
-- Multi-level sort
table.sort(items, function(a, b)
  -- Primary: Quality
  if a.quality ~= b.quality then
    return a.quality > b.quality
  end
  -- Secondary: Name
  if a.name ~= b.name then
    return a.name < b.name
  end
  -- Tertiary: Count
  return a.count > b.count
end)
```

## Debugging

### Query Parser Validation
```lua
local ast = QueryParser:Query(userInput)
if not ast then
  print("Invalid query syntax")
else
  -- Valid query
end
```

### Movement Flow Logging
```lua
local flow = movementFlow:GetMovementFlow()
local flowNames = {
  [const.MOVEMENT_FLOW.BANK] = "Bank",
  [const.MOVEMENT_FLOW.WARBANK] = "Warbank",
  -- etc.
}
print("Current context:", flowNames[flow] or "Unknown")
```

## Notes

- All utilities are designed to be stateless where possible
- Most functions are pure and side-effect free
- Performance-critical code is optimized
- Retail/Classic compatibility is maintained
