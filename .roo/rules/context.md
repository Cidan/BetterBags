# BetterBags Codebase Insights

This document contains observations about the BetterBags codebase architecture and behavior based on completed tasks.

## Initialization and Configuration

The addon's startup process is managed by the Ace3 framework. Key modules involved in initialization are:

- **`core/boot.lua`**: The main entry point that sets up the addon and its modules.
- **`core/database.lua`**: Manages all saved data using `AceDB-3.0`. It initializes the database schema from a large table of defaults defined in `core/constants.lua` (`const.DATABASE_DEFAULTS`).
- **`data/categories.lua`**: Manages the item categorization system.

There is a potential for race conditions during initialization. On a fresh installation, the database is empty. Modules like `Categories` load their data from the database in their `OnEnable` phase. If the default configuration (including default categories) is not present in the database at that exact moment, the module may initialize with an incomplete or empty state.

## Category System

The categorization system in `data/categories.lua` is robust but has some nuances:

- **Dynamic Category Creation**: Categories can be created on-the-fly. The function `CalculateAndUpdateBlizzardCategory` determines what a category *should* be based on an item's properties (e.g., item type, expansion). If this category doesn't already exist in memory, it is created instantly by calling `CreateCategory`.
- **`allowBlizzardItems` Flag**: This boolean property on a category is critical. When a category is created dynamically (like "Armor" or "Consumable"), this flag must be set to `true`. If it is `nil` or `false`, items that would normally be sorted into that category by the default Blizzard UI rules will not be placed there, often falling back to a generic "Everything" category.
- **Initialization Race Condition**: A bug was found where `CreateCategory` did not set a default value for `allowBlizzardItems`. On a fresh install, this caused all dynamically-created categories to be invalid for Blizzard items, leading to the mis-categorization issue. A `/reload` would fix this because of migration logic in `categories:OnEnable` that correctly sets the flag for any categories that were saved to the database during the previous session. The fix was to ensure `CreateCategory` always sets `allowBlizzardItems = true` if it's not already defined.