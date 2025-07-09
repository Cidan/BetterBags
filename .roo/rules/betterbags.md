# BetterBags Codebase Documentation

This document provides a detailed overview of the BetterBags addon's codebase structure.

## High-Level Overview

BetterBags is a World of Warcraft addon that replaces the default bags with a single, more organized frame. The codebase is structured into several directories, each with a specific responsibility. The core logic is written in Lua, with XML for UI templates. The addon supports different versions of WoW (Classic, Era, Retail) through specific folders.

## Root Directory Files

- **`.toc` files (`BetterBags.toc`, `BetterBags_Cata.toc`, `BetterBags_Vanilla.toc`)**: These are Table of Contents files that WoW uses to load the addon. Each file is for a specific expansion.
- **`Bindings.xml`**: Defines the default key bindings for the addon.
- **`annotations.lua`**: Provides type annotations for Lua, used by tools like `lua-language-server` for static analysis and autocompletion.
- **`go.mod`, `go.sum`**: Go module files for the translation tool located in `tools/translate`.

## Directory Breakdown

### `/animations`

Contains modules for UI animations.

- **`fade.lua`**: Handles fading animations for UI frames.

### `/config`

Handles addon configuration and settings.

- **`config.lua`**: The main configuration file where user-configurable options are defined using AceConfig-3.0.
- **`plugin.lua`**: Manages plugin-specific configurations.

### `/core`

The heart of the addon, containing the main business logic.

- **`boot.lua`**: Initializes the addon and its modules on startup.
- **`constants.lua`**: Defines global constants used throughout the addon.
- **`database.lua`**: Manages the addon's saved data (SavedVariables) using AceDB-3.0.
- **`events.lua`**: Handles all game and addon-specific events using AceEvent-3.0.
- **`hooks.lua`**: Manages hooking into WoW's native functions.
- **`localization.lua`**: Handles language translations.
- **`pool.lua`**: Implements object pooling for UI elements to improve performance and reduce garbage collection.
- **`/core/classic`, `/core/era`**: These subdirectories contain files with constants and logic specific to different WoW versions (e.g., Classic, Wrath of the Lich King).

### `/data`

Manages all data related to items, categories, and inventory.

- **`categories.lua`**: Defines and manages item categories.
- **`items.lua`**: Handles all logic related to item data, tooltips, and information.
- **`search.lua`**: Implements the item search functionality.
- **`slots.lua`**: Manages inventory slot information.

### `/debug`

Contains tools and frames for debugging the addon.

- **`debug.lua`**: Core debugging utilities.
- **`frames.lua`**: A debug frame to inspect UI elements.
- **`items.lua`**: Utilities for debugging item data.
- **`profile.lua`**: A simple profiler to measure performance.

### `/frames`

Contains all the UI frame definitions and logic. This is the primary directory for the addon's visual components.

- **`bag.lua`**: The main bag container frame.
- **`item.lua`**: The individual item button/icon frame.
- **`section.lua`**: The frame for a category section within the bag.
- **`header.lua`**: The header of the bag frame, containing search, currency, etc.
- **`itembrowser.lua`**: The frame for the item browser.
- **`/frames/classic`, `/frames/era`**: Version-specific frame modifications.

### `/integrations`

Modules for integrating with other popular addons.

- **`masque.lua`**: Adds support for the Masque skinning addon.
- **`pawn.lua`**: Integrates with the Pawn addon to display item score values.
- **`simpleitemlevel.lua`**: Integrates with SimpleItemLevel to show item levels.

### `/libs`

Contains external libraries used by the addon. **These files should not be modified.**

### `/templates`

XML files that define the layout and structure of the UI frames.

- **`container.xml`**: Template for the main bag container.
- **`/templates/era`**: Version-specific templates.

### `/themes`

Contains different visual themes for the addon.

- **`default.lua`**: The default theme.
- **`elvui.lua`**: A theme that mimics the ElvUI style.
- **`themes.lua`**: Manages the loading and application of themes.

### `/util`

A collection of utility functions and data structures.

- **`color.lua`**: Functions for color manipulation.
- **`sort.lua`**: Sorting algorithms for items.
- **`trees/intervaltree.lua`**: An interval tree data structure, likely for managing item levels or other ranged data.

### `/views`

Manages different ways to display items in the bag.

- **`bagview.lua`**: The default view.
- **`gridview.lua`**: A view that displays items in a simple grid.
- **`views.lua`**: The manager for switching between different views.