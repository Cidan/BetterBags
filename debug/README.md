# Debug Module

The Debug module provides comprehensive debugging, profiling, and diagnostic tools for BetterBags development and troubleshooting. It includes logging, performance profiling, frame debugging, item inspection, and analytics integration.

## Overview

The Debug module offers:
- Structured logging with category filtering
- Performance profiling tools
- Frame debugging and visualization
- Item data inspection
- Analytics integration for usage tracking
- Debug window for real-time monitoring

## Core Components

### Main Debug Module (`debug.lua`)

The central debugging system that provides logging, formatting, and inspection tools.

#### Features
- **Conditional Debugging**: Enable/disable debug mode globally
- **Type-Aware Formatting**: Color-coded output by data type
- **Table Inspection**: Safe table traversal and display
- **Context Logging**: Track event chains and context flow
- **DevTools Integration**: Direct integration with WoW DevTools

#### Key Functions
```lua
-- Enable/disable debug mode
debug.enabled = true

-- Log a categorized message
debug:Log("Category", "Message", data)

-- Log context information
debug:LogContext("Category", ctx)

-- Inspect a value with DevTools
debug:Inspect("tag", value)

-- Format values with color coding
debug:Format(value1, value2, ...)
```

#### Color Coding
```lua
debug.colors = {
  ["nil"]      = "aaaaaa",  -- Gray
  ["boolean"]  = "77aaff",  -- Light blue
  ["number"]   = "ff77ff",  -- Pink
  ["table"]    = "44ffaa",  -- Green
  ["UIObject"] = "ffaa44",  -- Orange
  ["function"] = "77ffff",  -- Cyan
}
```

### Performance Profiling (`profile.lua`)

Measures execution time of code sections for performance optimization.

#### Features
- **Named Profiles**: Track multiple concurrent profiles
- **Millisecond Precision**: Uses `debugprofilestop()` for accuracy
- **Nested Support**: Profile within profiles
- **Automatic Cleanup**: Profiles are removed after completion

#### Usage
```lua
-- Start a profile
debug:StartProfile("DataLoad")

-- ... code to profile ...

-- End and log the profile
debug:EndProfile("DataLoad")
-- Output: "DataLoad took 123.45 ms"

-- With formatting
debug:StartProfile("Item_%d", itemID)
debug:EndProfile("Item_%d", itemID)
```

### Frame Debugging (`frames.lua`)

Visual debugging tools for UI frame development.

#### Features
- **Border Visualization**: Draw colored borders around frames
- **Mouseover Mode**: Show borders only on hover
- **Anchor Graph Fixing**: Resolve frame positioning issues
- **Strata Control**: Ensure debug overlays are visible

#### Key Functions
```lua
-- Draw a debug border around a frame
debug:DrawBorder(frame, r, g, b, mouseover)

-- Fix anchor graph issues (disappearing frames)
debug:WalkAndFixAnchorGraph(frame)
```

#### Common Use Cases
```lua
-- Highlight all item frames in red
debug:DrawBorder(itemFrame, 1, 0, 0)

-- Show section boundaries on mouseover
debug:DrawBorder(sectionFrame, 0, 1, 0, true)

-- Fix frames that disappear unless parent is moved
debug:WalkAndFixAnchorGraph(problemFrame)
```

### Item Debugging (`items.lua`)

Specialized tools for inspecting item data structures.

#### Features
- **Item Identification**: Check if data matches specific items
- **Tooltip Generation**: Display detailed item data in tooltips
- **Hierarchical Display**: Show nested data structures
- **Color Alternation**: Improve readability with alternating colors

#### Key Functions
```lua
-- Check if data is a specific item
debug:IsItem(data, itemID)

-- Show detailed item tooltip
debug:ShowItemTooltip(item)

-- Hide item tooltip
debug:HideItemTooltip(item)
```

#### Tooltip Structure
The debug tooltip displays:
- Item link
- All ItemData fields hierarchically:
  - itemInfo (name, ID, quality, etc.)
  - containerInfo (slot, count, etc.)
  - questInfo (quest status)
  - bindingInfo (binding type)
  - Category assignment
  - Stack information

### Analytics Integration (`analytics.lua`)

Integrates with WagoAnalytics for usage tracking and telemetry.

#### Features
- **Switch Tracking**: Track feature toggles
- **Counter Management**: Track numeric metrics
- **Increment/Decrement**: Adjust counters
- **Direct Set**: Set counter values

#### Functions
```lua
-- Track a feature toggle
debug:Switch("FeatureName", enabled)

-- Increment a counter
debug:IncrementCounter("ItemsMoved", 5)

-- Decrement a counter
debug:DecrementCounter("ErrorCount", 1)

-- Set a counter value
debug:SetCounter("TotalItems", 100)
```

## Debug Window

The Debug module includes a debug window (referenced but implemented elsewhere) that provides:
- Real-time log display
- Category filtering
- Log history
- Performance metrics

## Configuration

Debug mode is controlled through the database:
```lua
-- Enable debug mode
database:SetDebugMode(true)

-- Check debug state
local enabled = database:GetDebugMode()
```

## Usage Examples

### Basic Logging
```lua
-- Simple log
debug:Log("Items", "Loading item", itemID)

-- Multi-value log
debug:Log("Combat", "Damage dealt:", damage, "to", targetName)

-- Context logging
local ctx = context:New("RefreshItems")
debug:LogContext("Refresh", ctx)
```

### Performance Analysis
```lua
debug:StartProfile("BagRefresh")
-- Refresh bag contents
items:RefreshBackpack(ctx)
debug:EndProfile("BagRefresh")
```

### Frame Debugging
```lua
-- Debug new frame layout
local frame = CreateFrame("Frame")
debug:DrawBorder(frame, 0, 1, 1)  -- Cyan border

-- Fix anchor issues
if frame:IsVisible() and frame:GetWidth() == 0 then
  debug:WalkAndFixAnchorGraph(frame)
end
```

### Item Inspection
```lua
-- In item frame OnEnter
item:SetScript("OnEnter", function(self)
  if debug.enabled then
    debug:ShowItemTooltip(self)
  else
    -- Normal tooltip
  end
end)
```

## Integration Points

### With DevTools
When DevTools addon is present:
```lua
-- Automatically sends to DevTools
debug:Inspect("CategoryData", categories:GetAllCategories())
```

### With Context System
```lua
-- Track event flow
local ctx = context:New("Operation")
-- ... operations ...
debug:LogContext("Operation", ctx)
```

## Best Practices

1. **Conditional Debugging**: Always check `debug.enabled` before expensive operations
2. **Category Usage**: Use consistent category names for filtering
3. **Profile Cleanup**: Always call EndProfile for started profiles
4. **Safe Inspection**: Use `nocopy` parameter for large tables if needed
5. **Border Colors**: Use consistent colors for similar frame types

## Performance Considerations

- Debug operations are skipped when disabled
- Table copying in Inspect can be expensive
- Profile names should be unique or use formatting
- Border drawing adds minimal overhead
- Tooltip generation is on-demand only

## Troubleshooting

### Common Issues

1. **Missing Profiles**: Ensure StartProfile and EndProfile match
2. **DevTools Not Working**: Check if DevTools addon is loaded
3. **Borders Not Visible**: Check frame strata and visibility
4. **Tooltip Errors**: Verify item data structure is valid

### Debug Commands
```lua
-- Enable debug mode
/bb debug enable

-- Show debug window
/bb debug window

-- Clear debug log
/bb debug clear
```

## Color Reference

Data types are color-coded in debug output:
- **Gray** (#aaaaaa): nil values
- **Light Blue** (#77aaff): booleans
- **Pink** (#ff77ff): numbers
- **Green** (#44ffaa): tables
- **Orange** (#ffaa44): UI objects
- **Cyan** (#77ffff): functions

## Technical Notes

- Uses `debugprofilestop()` for sub-millisecond timing
- Tooltip alternates colors every other line for readability
- Frame walking prevents infinite recursion with visited tracking
- Table inspection handles metatables safely
- Analytics data is sent to Wago.io for aggregation