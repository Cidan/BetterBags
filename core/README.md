# Core Module

This folder contains the core systems and foundational modules that power the BetterBags addon. These modules provide essential functionality including event handling, data management, UI hooks, and cross-version compatibility.

## Overview

The core module provides the fundamental infrastructure for BetterBags, including initialization, event management, database operations, and system-wide utilities. It serves as the backbone that all other modules depend on.

## Files

### async.lua

Provides asynchronous execution capabilities using coroutines to prevent UI freezing during heavy operations.

#### Key Functions

- **`Do(ctx, fn, event)`**: Runs a coroutine function with no delay between yields
- **`DoWithDelay(ctx, delay, fn, event)`**: Runs a coroutine with specified delay between yields
- **`Each(ctx, list, fn, event)`**: Iterates over a list, processing one item per frame
- **`Batch(ctx, count, list, fn, event)`**: Processes items in batches per frame
- **`StableIterate(ctx, delta, list, fn, event)`**: Adjusts iteration speed based on framerate
- **`Chain(ctx, event, ...)`**: Executes functions sequentially, one per frame
- **`Until(ctx, fn, event)`**: Repeatedly calls function until it returns true
- **`AfterCombat(ctx, cb)`**: Delays execution until player leaves combat
- **`Yield()`**: Wrapper for coroutine.yield()

### boot.lua

Handles the initial bootstrapping of the addon and creates the root module.

- Creates the main BetterBags addon using AceAddon-3.0
- Sets default module state to disabled
- Defines keybinding names for bag toggle and search

### constants.lua

Contains all constant values, enumerations, and configuration defaults used throughout the addon.

#### Key Constants

- **Bag Types**: `BAG_KIND` (BACKPACK, BANK)
- **Bank Tabs**: Definitions for different bank tab types
- **View Modes**: `BAG_VIEW` (ONE_BAG, SECTION_GRID, LIST, SECTION_ALL_BAGS)
- **Sort Types**: `SECTION_SORT_TYPE`, `ITEM_SORT_TYPE`
- **Item Quality**: Quality levels and color mappings
- **Expansions**: Expansion type mappings
- **Bag Families**: Specialty bag type definitions
- **UI Offsets**: Layout constants for UI positioning
- **Database Defaults**: Default configuration values

### context.lua

Provides a context system for passing state between function calls, similar to Go's context package.

#### Key Methods

- **`New(event)`**: Creates a new context object
- **`Set(key, value)`**: Stores a value in the context
- **`Get(key)`**: Retrieves a value from the context
- **`Event()`**: Gets the event that created the context
- **`Cancel()`**: Cancels the context
- **`Timeout(seconds, callback)`**: Auto-cancels context after timeout
- **`Copy()`**: Creates a copy of the context

### database.lua

Manages all persistent data storage and settings using AceDB-3.0.

#### Key Functions

- **Bag Settings**: Position, view, size, opacity, scale management
- **Category Management**: Custom category creation, deletion, and item assignment
- **Filter Settings**: Category filters, stacking options, sorting preferences
- **Item Settings**: Item level display, new item marking, item locking, and per-character max item level tracking (emits `itemLevel/MaxChanged` for color refresh)
- **Migration**: Handles database schema updates between versions

### events.lua

Comprehensive event handling system built on AceEvent-3.0.

#### Key Features

- **`RegisterMessage(event, callback)`**: Registers addon message handlers
- **`RegisterEvent(event, callback)`**: Registers WoW event handlers
- **`SendMessage(ctx, event, ...)`**: Sends messages with context
- **`BucketEvent(event, callback)`**: Batches rapid events (0.2s delay)
- **`GroupBucketEvent(events, messages, callback)`**: Groups multiple events
- **`CatchUntil(caughtEvent, finalEvent, callback)`**: Collects events until a final event

### fonts.lua

Defines custom fonts used throughout the addon.

- **`UnitFrame12White`**: White 12pt font for unit frames
- **`UnitFrame12Yellow`**: Yellow 12pt font for highlighting

### hooks.lua

Manages UI hooks and interaction with the default Blizzard interface.

#### Key Features

- Intercepts bag toggle commands
- Handles NPC interaction windows (vendor, bank, mail, etc.)
- Forces hiding of Blizzard bag frames
- Manages button highlight states
- Coordinates bag opening/closing with game events

### init.lua

Main initialization module that coordinates addon startup.

#### Key Responsibilities

- Disables tutorial screens incompatible with BetterBags
- Sets up keybinding overrides
- Creates main bag instances (Backpack and Bank)
- Initializes all submodules in correct order
- Registers core event handlers
- Manages compatibility with other addons

### localization.lua

Core localization system for multi-language support.

- **`G(key)`**: Returns localized string for the given key
- Falls back to key if no translation exists
- Automatically detects client locale

### overrides.lua

Safe file for manual translation overrides.

- Allows manual correction of auto-generated translations
- Preserves custom translations across updates
- Example: `L.data["English text"]["frFR"] = "French translation"`

### pool.lua

Object pooling system for performance optimization.

- **`Create(createFn, resetFn)`**: Creates a new object pool
- **`Acquire(ctx)`**: Gets an object from pool or creates new
- **`Release(ctx, item)`**: Returns object to pool after reset
- Reduces garbage collection pressure

### translations.lua

Auto-generated translation file containing all localized strings.

- **DO NOT EDIT** - Generated automatically
- Contains translations for all supported languages
- Use overrides.lua for manual corrections
- Supports: deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW

## Subdirectories

### era/

Contains Classic WoW specific implementations.

#### era/constants.lua
- Classic-specific constant overrides
- Adjusted bag indices for Classic
- Modified UI offsets

#### era/init.lua
- Classic-specific initialization
- Different bag hiding implementation
- Button highlight management for Classic UI

### classic/

Contains additional Classic WoW specific constants.

#### classic/constants.lua
- Classic-only constant definitions

## Integration

The core module is loaded first and provides essential services to all other modules:

```lua
-- Getting core modules
local events = addon:GetModule('Events')
local database = addon:GetModule('Database')
local context = addon:GetModule('Context')
```

## Version Compatibility

The core module handles differences between WoW versions:
- Retail (mainline)
- Classic Era
- Burning Crusade Classic
- Cataclysm Classic
- Mists of Pandaria Classic

Version detection is done via:
```lua
addon.isRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
addon.isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
-- etc.
```

## Performance Considerations

- Uses object pooling to reduce garbage collection
- Implements asynchronous operations to prevent UI freezing
- Batches events to reduce processing overhead
- Adjusts iteration speed based on framerate

## Event Flow

1. **Initialization**: boot.lua → init.lua
2. **Module Loading**: All modules loaded but disabled
3. **Enable Phase**: Modules enabled in dependency order
4. **Runtime**: Events flow through the event system
5. **Context Passing**: Context objects carry state through event chains
