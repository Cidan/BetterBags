# BetterBags Redesign & Rendering Pipeline Blueprint

This document defines the architectural specification, data contracts, module boundaries, and incremental execution plan for the BetterBags rendering pipeline refactor.

## The Core Philosophy: Decoupling Ideals from Execution

The goal of this refactor is to transition the BetterBags pipeline from an imperatively driven, delta-based system (where data farming, stacking, and rendering are tightly coupled) into a **purely unidirectional, functional top-down flow**. 

By separating the **Ideal state** (what items actually exist in the player's inventory) from the **Execution state** (how we represent, group, and draw those items in the UI), we eliminate race conditions, out-of-sync "ghost slots", and complex multi-pass layout bugs.

### Key Architectural Shifts

1. **Breadth-First Processing:** We process each stage across the entire active inventory context before moving to the next. No more interleaving database updates with drawing triggers.
2. **Clean-Sweep Virtual Stacking:** Instead of trying to maintain stack deltas on raw bag update events, we wipe and calculate virtual stacks from scratch on every database update. 
3. **Dumb Presentation Layer:** Item buttons and category grids have zero business logic. They do not know about stacking rules, vendor interactions, or profile settings. They are pure renderers of the state passed to them.
4. **Clean-Break, Bottom-Up Build:** To achieve maximum clarity and eliminate code pollution, we will immediately **disable the legacy data-farming, stacking, and rendering modules** in the WoW client TOC files. The bags will initially not show or render in-game. We will then build the new pipeline step-by-step, registering the new modules and slowly layering functionality back on until the UI is fully restored in a clean-room state.

---

## The 8-Phase Unidirectional Pipeline

```
+------------------------------------------------------------+
|                  Phase 1: Item Loader                      |
| (Async client cache-priming & slot-bound ItemMixin cache)   |
+-----------------------------+------------------------------+
                              |
                              v
+------------------------------------------------------------+
|                  Phase 2: Data Farming                     |
|  (Breadth-first fetch of physical item data & metadata)    |
+-----------------------------+------------------------------+
                              |
                              v
+------------------------------------------------------------+
|                  Phase 3: Virtual Stacks                   |
| (Clean-sweep resolution of stacks; outputs a flat model)  |
+-----------------------------+------------------------------+
                              |
                              v
+------------------------------------------------------------+
|                 Phase 4: Search Indexing                   |
|     (Index building from the resolved stack model)         |
+-----------------------------+------------------------------+
                              |
                              v
+------------------------------------------------------------+
|                Phase 5: Item Button Drawing                |
|      (Pure UI frame generation; updates art/overlays)      |
+-----------------------------+------------------------------+
                              |
                              v
+------------------------------------------------------------+
|               Phase 6: Item Button Placement               |
|      (Mapping active buttons to logical category grids)     |
+-----------------------------+------------------------------+
                              |
                              v
+------------------------------------------------------------+
|                 Phase 7: Section Layout                    |
|      (Arranging buttons inside individual section grids)     |
+-----------------------------+------------------------------+
                              |
                              v
+------------------------------------------------------------+
|                  Phase 8: Page Placement                   |
|      (Final column/row packing within the bag window)      |
+------------------------------------------------------------+
```

---

## Deep Dive: Phase Specification & Data Contracts

### Phase 1: Item Loader (`data/loader.lua`)
- **Responsibility:** Handles raw event buffering (`BAG_UPDATE`, `BAG_UPDATE_DELAYED`), coordinates with the client cache via `ContinuableContainer` to prime item details, and maintains the permanent static cache of slot-bound `ItemMixin` instances.
- **Input:** Raw WoW client container events.
- **Output:** Execution callback indicating the C-level item cache is primed.
- **Implementation Status:** COMPLETE. This module remains active as our pipeline's anchor.

### Phase 2: Data Farming (`data/items.lua`)
- **Responsibility:** Performs a fast, breadth-first sweep of all active slots (`bagID` and `slotID`) for the requested context (Backpack, Bank, or Warbank). It retrieves basic item fields and tags metadata (bound status, item levels, quality).
- **Rules:** No stacking, no indexing, no categorizing. It simply builds an accurate snapshot of the player's physical items.
- **Input:** Active `bagList` (from Constants) and the primed `ItemLoader` cache.
- **Output:** A flat table `table<string, ItemData>` indexed by `slotkey` (formatted as `"bagID_slotID"`):
  ```lua
  ---@class ItemData
  ---@field bagid number
  ---@field slotid number
  ---@field slotkey string
  ---@field itemID number|nil
  ---@field isItemEmpty boolean
  ---@field itemInfo ItemInfo
  ```

### Phase 3: Virtual Stacks (`data/stacks.lua`)
- **Responsibility:** Resolves all stacking rules (virtual item stacking, merging/unmerging at vendors, merging unstackables, partial stack splits) from a **clean slate**.
- **Rules:** The stacking state is cleared (`wipe`) at the beginning of this pass. Stacks are computed by iterating over the flat `ItemData` snapshot.
- **Input:** Flat physical `ItemData` snapshot.
- **Output:** A resolved layout model:
  1. `visibleSlots`: A list of root item keys to be displayed on screen.
  2. `stacks`: A lookup map of `itemHash -> StackInfo`:
     ```lua
     ---@class StackInfo
     ---@field count number          -- Total items in the stack
     ---@field rootItem string       -- Slot key of the displayed lead item
     ---@field slotkeys table<string, boolean> -- Children slot keys hidden behind root
     ```

### Phase 4: Search Indexing (`data/search.lua`)
- **Responsibility:** Rebuilds search engine indices (name, category, levels, binding) to support category search filters and live text queries.
- **Rules:** Indexing is triggered as a separate, breadth-first step using the flat model resolved in Phase 3. 
- **Input:** Resolved layout model (`visibleSlots` and `stacks`).
- **Output:** Completed search and query indexes.

### Phase 5: Item Button Drawing (`frames/item.lua`)
- **Responsibility:** Manages the visual state of individual item buttons (icons, border textures, text count, level text, upgrade arrows, item flashes).
- **Rules:** The button acts as a "dumb" visual representation. It is updated by passing a slot key. It reads its own visual properties directly from the cached `ItemData` and has no knowledge of layout columns, virtual stacking logic, or tabs.
- **Input:** Slot key and resolved metadata.
- **Output:** Updated visual button widgets.

### Phase 6: Item Button Placement (`views/gridview.lua`)
- **Responsibility:** Sorts items and assigns individual item buttons to their respective category section containers.
- **Rules:** Maps item categories (including query-based dynamic search categories and *Recent Items*). Hides child buttons of stacks.
- **Input:** Resolved layout model, search results, and category mapping.
- **Output:** Logical mappings of `CategoryName -> table<slotkey, ItemButton>`.

### Phase 7: Section Layout (`frames/section_new.lua`)
- **Responsibility:** Positions buttons inside their individual grid containers.
- **Rules:** Packs item buttons into rows and columns based on the section's "items per row" profile.
- **Input:** Set of item buttons assigned to the section.
- **Output:** Rendered local grid section with precise width and height bounds.

### Phase 8: Page Placement (`frames/grid.lua` / `views/gridview.lua`)
- **Responsibility:** Arranges the completed category sections within the main bag window frame.
- **Rules:** Runs the final packing algorithm, aligning sections alphabetically/prioritized into columns, updating the window's total height, and adjusting scrollbars.
- **Input:** Set of rendered grid sections.
- **Output:** Fully refreshed, resized, and visually coherent BetterBags UI.

---

## Clean-Break Integration & Testing Plan

Rather than keeping the legacy modules running alongside the new ones, we will execute a **clean-break migration**:

1. **Legacy Deactivation:** We will disable the legacy `data/items.lua`, `data/stacks.lua`, `data/search.lua`, and view modules in all `.toc` files. The BetterBags window will boot with blank frames and no items.
2. **Bottom-Up Building:** As we complete each new phase, we will add the new files directly to the active `.toc` lists.
3. **In-Game Debugging:** We will implement slash commands or developer logs in the new files. For example, once Phase 2 (Farming) and Phase 3 (Stacking) are active in-game, we can run a debug slash command `/bb debugitems` to inspect the generated flat datasets and stack structures using real client state, verifying correctness long before any UI button is rendered!
4. **Final Restoration:** When Phase 8 is completed, the main UI frames will fully re-bind to the clean-room pipeline, restoring 100% of game functionality.

### Testing Strategy per Phase

```
+-----------------------------------------------------------------------------+
|                                  PHASE 2                                    |
| - Action: Enable promoted data/items.lua in TOC.                           |
| - Test File: spec/items_spec.lua                                            |
| - Validation: Verify in unit tests that raw slot sweeps harvest clean        |
|   metadata. Add in-game slash command to print physical item maps.           |
+-----------------------------------------------------------------------------+
                                      |
                                      v
+-----------------------------------------------------------------------------+
|                                  PHASE 3                                    |
| - Action: Enable promoted data/stacks.lua in TOC.                          |
| - Test File: spec/stacks_spec.lua                                           |
| - Validation: Assert clean-sweep stack resolution works. In-game command    |
|   prints stack trees of real items (revealing any promo roots/children).    |
+-----------------------------------------------------------------------------+
                                      |
                                      v
+-----------------------------------------------------------------------------+
|                                  PHASE 4                                    |
| - Action: Enable promoted data/search.lua in TOC.                          |
| - Test File: spec/search_spec.lua                                           |
| - Validation: Verify indexing logic matches flat models. Slash command     |
|   executes test live queries (e.g. "/bb search hearthstone") and matches.    |
+-----------------------------------------------------------------------------+
                                      |
                                      v
+-----------------------------------------------------------------------------+
|                               PHASES 5 - 8                                  |
| - Action: Enable promoted views in TOC.                                     |
| - Test File: spec/views/gridview_spec.lua                                   |
| - Validation: Step-by-step category framing, layout, and page alignment.   |
|   Once Phase 8 is active, the UI windows render completely.                 |
+-----------------------------------------------------------------------------+
```

---

## Expected Code Modifications (Completed)

All legacy files have been retired, and the new architecture has been promoted to canonical names:

| Retired File | Action | Promoted Canonical File |
| :--- | :--- | :--- |
| `data/items.lua` (Legacy) | Deleted | `data/items.lua` (Promoted) |
| `data/stacks.lua` (Legacy) | Deleted | `data/stacks.lua` (Promoted) |
| `data/search.lua` (Legacy) | Deleted | `data/search.lua` (Promoted) |
| `views/gridview.lua` (Legacy) | Deleted | `views/gridview.lua` (Promoted) |
| `views/bagview.lua` (Legacy) | Deleted | `views/bagview.lua` (Promoted) |
| `frames/item.lua` | Reused / Extended | `frames/item.lua` (Kept as dumb frame) |
| `frames/grid.lua` | Reused / Extended | `frames/grid.lua` |

---

## Next Steps

1. **Promotion Completed:** The `_new.lua` and `_new_spec.lua` files have been renamed to their canonical names.
2. **All Tests Verified:** All test suites compile and run under Lua 5.1 seamlessly.
