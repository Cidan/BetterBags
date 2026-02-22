# Views Module

The Views module provides the core view system for BetterBags, implementing different display layouts for bag contents. It handles item rendering, section management, and view-specific behaviors for both grid-based category views and bag-based views.

## Module Structure

```
views/
├── views.lua        # Core view system and base View class
├── gridview.lua     # Grid-based category view implementation
└── bagview.lua      # Bag-based view implementation
```

## Core Components

### Views Module (`views.lua`)

The main Views module provides the base view functionality and common operations.

#### View Prototype

The base View class that all view types inherit from:

```lua
---@class View
---@field sections table<string, Section> All sections in the view
---@field slotToSection table<string, Section> Mapping of slot keys to sections
---@field content Grid The grid container for the view
---@field bagview BagView The type of bag view
---@field kind BagKind The kind of bag (backpack/bank)
---@field itemsByBagAndSlot table<string, Item> Item buttons by slot key
---@field itemFrames Item[] All item frames in the view
---@field deferredItems table<string, boolean> Items to update later
---@field dirtySections table<string, boolean> Sections needing redraw
---@field stacks table<string, Stack> Item stacking information
```

#### Key Methods

**Rendering and Updates:**
- `Render(ctx, bag, slotInfo, callback)` - Main render method (must be implemented by subclasses)
- `Wipe(ctx)` - Clear all view contents
- `UpdateListSize(bag)` - Update view size based on bag contents

**Section Management:**
- `GetOrCreateSection(ctx, category, onlyCreate)` - Get or create a section by category
- `GetSection(category)` - Get an existing section
- `RemoveSection(category)` - Remove a section from the view
- `GetAllSections()` - Get all sections in the view
- `AddDirtySection(title)` - Mark a section for redraw
- `ClearDirtySections()` - Clear dirty section flags

**Item Management:**
- `GetOrCreateItemButton(ctx, slotkey, createFunc)` - Get or create an item button
- `GetItemFrame(ctx, createFunc)` - Get a new item frame
- `ReleaseItemFrames(ctx)` - Release all item frames
- `AddSlot(newSlotKey)` - Add a new slot to the view
- `ReindexSlot(oldSlotKey, newSlotKey)` - Update slot key references

**Slot Tracking:**
- `SetSlotSection(slotkey, section)` - Associate a slot with a section
- `GetSlotSection(slotkey)` - Get the section for a slot
- `RemoveSlotSection(slotkey)` - Remove slot-section association
- `GetSlotKey(data)` - Generate slot key from item data
- `ParseSlotKey(slotkey)` - Parse bag and slot IDs from key

**Deferred Items:**
- `AddDeferredItem(slotkey)` - Add item to deferred update list
- `GetDeferredItems()` - Get all deferred items
- `ClearDeferredItems()` - Clear deferred items list
- `RemoveDeferredItem(slotkey)` - Remove specific deferred item

**Stacking:**
- `FlashStack(ctx, slotkey)` - Flash all items in a stack for new items
- `WipeStacks()` - Clear all stack information

#### Stack Prototype

Manages item stacking for merged display:

```lua
---@class Stack
---@field item string The main item slot key
---@field swap string Slot key to swap with when dirty
---@field subItems table<string, boolean> Sub-items in the stack
---@field hash string Item hash for the stack
---@field dirty boolean Whether stack needs update
```

**Stack Methods:**
- `AddItem(slotkey)` - Add item to stack (returns true if main item)
- `RemoveItem(slotkey)` - Remove item from stack
- `UpdateCount()` - Update stacked item count
- `GetStackCount()` - Get total stack count
- `HasSubItem(slotkey)` - Check if slot is a sub-item
- `HasAnySubItems()` - Check if stack has any sub-items
- `IsInStack(slotkey)` - Check if slot is in the stack
- `GetBackingItemData()` - Get the main item's data
- `IsStackEmpty()` - Check if stack is empty

### Grid View (`gridview.lua`)

Implements the category-based grid view with sections.

#### Features

- **Category Sections**: Groups items by category
- **Item Stacking**: Merges stackable items based on settings
- **Recent Items**: Special section for newly acquired items
- **Free Space Display**: Shows available bag slots
- **Smart Sorting**: Sorts sections and items within sections
- **Dynamic Sections**: Creates/removes sections as needed
- **Sort After Wipe**: Tracks a `sortRequired` flag so that a section sort always runs after the view is wiped, even when the wipe and the subsequent rebuild happen under different context objects (e.g. `SwitchToGroup` wipes with one context, but the refresh pipeline creates a fresh context without `wipe=true`).

#### Key Functions

**Button Management:**
- `CreateButton(ctx, view, slotkey)` - Create item button and add to section
- `UpdateButton(ctx, view, slotkey)` - Update existing item button
- `ClearButton(ctx, view, slotkey)` - Clear and defer item button
- `UpdateDeletedSlot(ctx, view, oldSlotKey, newSlotKey)` - Handle slot deletion

**Stack Reconciliation:**
- `ReconcileStack(ctx, view, stackInfo)` - Merge items in a stack
- `ReconcileWithPartial(ctx, view, stackInfo)` - Handle partial stacks

#### Rendering Process

1. **Change Detection**: Identifies added, removed, and changed items
2. **Item Removal**: Clears buttons for removed items
3. **Item Addition**: Creates buttons for new items with stacking logic
4. **Item Updates**: Updates changed items and their stacks
5. **Section Updates**: Redraws dirty sections
6. **Section Sorting**: Sorts sections based on user preferences
7. **Free Space**: Adds free slot display section
8. **Final Draw**: Renders complete grid with all sections

#### Stacking Options

Respects database stacking settings:
- `mergeStacks` - Whether to merge stackable items
- `unmergeAtShop` - Unmerge when at vendor/bank
- `dontMergePartial` - Keep partial stacks separate
- `mergeUnstackable` - Whether to merge unique items

### Bag View (`bagview.lua`)

Implements the bag-based view showing items organized by their containing bags.

#### Features

- **Bag Sections**: One section per bag
- **Bag Naming**: Shows bag number and name
- **Empty Slot Display**: Shows empty slots per bag
- **Simple Layout**: No category-based organization
- **Alphabetical Sorting**: Sorts bags alphabetically

#### Key Functions

**Button Management:**
- `CreateButton(ctx, view, item)` - Create button in bag section
- `UpdateButton(ctx, view, slotkey)` - Update existing button
- `ClearButton(ctx, view, item)` - Convert to empty slot
- `AddSlot(ctx, view, newSlotKey)` - Add new slot to bag

**Bag Naming:**
- `GetBagName(bagid)` - Generate display name for bag

#### Rendering Process

1. **Change Processing**: Handle added/removed/changed items
2. **Empty Slot Creation**: Create buttons for empty slots
3. **Section Management**: Create sections for each bag
4. **Count Updates**: Update item counts
5. **Section Drawing**: Draw each bag section
6. **Alphabetical Sort**: Sort bags by name
7. **Final Layout**: Render complete bag view

## View Types

### Section Grid View
- Groups items by category
- Supports item stacking
- Shows recent items separately
- Configurable column layout
- Smart section management

### Bag View
- Shows items by containing bag
- Simple bag-based organization
- Shows all empty slots
- Numbered bag display
- Good for bag management

## Integration Points

### Dependencies
- **Grid**: Grid layout system
- **SectionFrame**: Section containers
- **ItemFrame**: Individual item buttons
- **Items**: Item data management
- **Categories**: Category system
- **Database**: User preferences
- **Sort**: Sorting functions

### Events and Context
- Uses context system for operation tracking
- Supports wipe and redraw operations
- Handles deferred updates
- Manages dirty section tracking

## Usage Examples

### Creating a Grid View

```lua
local view = views:NewGrid(parentFrame, const.BAG_KIND.BACKPACK)
view:Render(ctx, bag, slotInfo, function()
    -- Render complete callback
end)
```

### Creating a Bag View

```lua
local view = views:NewBagView(parentFrame, const.BAG_KIND.BANK)
view:Render(ctx, bag, slotInfo, function()
    -- Render complete callback
end)
```

### Working with Sections

```lua
-- Get or create a section
local section = view:GetOrCreateSection(ctx, "Consumables")

-- Add item to section
local itemButton = view:GetOrCreateItemButton(ctx, slotkey)
section:AddCell(slotkey, itemButton)

-- Mark section for redraw
view:AddDirtySection("Consumables")
```

### Managing Stacks

```lua
-- Create a new stack
local stack = views:NewStack(slotkey)

-- Add items to stack
local isMainItem = stack:AddItem(slotkey)

-- Update stack count
stack:UpdateCount()

-- Check if item is in stack
if stack:IsInStack(slotkey) then
    -- Handle stacked item
end
```

## Performance Considerations

### Deferred Updates
- Items can be deferred for batch updates
- Reduces unnecessary redraws
- Improves performance with many changes

### Dirty Section Tracking
- Only redraws sections that changed
- Avoids full view refreshes
- Significantly improves performance

### View Recycling
- Reuses item frames when possible
- Maintains frame pool
- Reduces memory allocation

### Smart Rendering
- Only processes visible sections
- Hides sections based on category visibility
- Efficient change detection

## Configuration

Views respect various database settings:

### Display Options
- `itemsPerRow` - Items per row in sections
- `columnCount` - Number of columns
- `showAllFreeSpace` - Show all empty slots
- `showNewItemFlash` - Flash new items

### Stacking Options
- `mergeStacks` - Enable item stacking
- `dontMergePartial` - Separate partial stacks
- `unmergeAtShop` - Unmerge at vendors
- `mergeUnstackable` - Stack unique items

### View Selection
- `BAG_VIEW.SECTION_GRID` - Category-based grid
- `BAG_VIEW.SECTION_ALL_BAGS` - Bag-based view

## Best Practices

### View Implementation
1. Inherit from base View prototype
2. Implement required methods (Render, etc.)
3. Set WipeHandler for cleanup
4. Handle context flags properly

### Performance
1. Use deferred items for batch updates
2. Mark sections dirty instead of immediate redraw
3. Recycle item frames when possible
4. Minimize full view wipes

### Section Management
1. Create sections on demand
2. Remove empty sections
3. Track slot-to-section mapping
4. Handle section visibility properly

### Item Updates
1. Check for existing buttons before creating
2. Handle stack reconciliation properly
3. Clear deferred items after processing
4. Update counts for stacked items

## Debugging

Enable view debugging:
```lua
debug:Enable()
debug:Log("View", "Debug message")
```

Monitor performance:
```lua
debug:StartProfile('View Render')
-- View operations
debug:EndProfile('View Render')
```

## Future Enhancements

Potential improvements to the view system:

1. **Custom Layouts**: User-defined view layouts
2. **View Animations**: Smooth transitions between views
3. **Virtual Scrolling**: Handle very large inventories
4. **View Caching**: Cache rendered views for quick switching
5. **Dynamic Columns**: Auto-adjust based on window size
6. **View Presets**: Save and load view configurations