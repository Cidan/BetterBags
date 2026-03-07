### Summary of Changes

- **Introduced Phase 4.5 (Category Assignment & Data Enrichment):** Added a brand new data enrichment step to our unidirectional clean-sweep pipeline. 
- **Pre-resolved Item Categories:** Categories are now resolved immediately following search indexing inside `items:ProcessRefresh()`, then stored directly into `item.itemInfo.category`.
- **Decoupled JIT Views:** `GridView` and `BagView` have been converted to pure presentation layers. They no longer calculate categories dynamically on render, and instead read synchronously from `item.itemInfo.category`.
- **Pruned Obsolete Views:** `ONE_BAG` and `LIST` view modes have been entirely ripped out of the codebase (constants, database defaults, rendering hooks, and tests).
- **Restored Search-based Categories:** `RefreshSearchCache`, `WipeSearchCache`, and `GetSearchCategory` have been implemented to correctly index items into custom search category filters and group-by suffixes.

### Motivation

- **Pure, Zero-Cost Rendering:** Extracting the Just-In-Time (JIT) category resolution from our views eliminates database and search state query overhead from active UI layout calculations, permanently avoiding frame stutters.
- **True Unidirectional Flow:** Views shouldn't mutate state or do complex data lookups during presentation. With `item.itemInfo.category` pre-computed, down-stream consumers get their categories for free.
- **Cleaning up Dead Architecture:** The `ONE_BAG` and `LIST` views were legacy concepts that lacked corresponding logic in the new layout systems. Ripping them out slims down the codebase, while the existing `core/database.lua` handles seamlessly migrating legacy user databases to `SECTION_GRID`.

### Testing & Validation

- Confirmed database migration logic fallback gracefully translates any layout other than `SECTION_GRID` or `SECTION_ALL_BAGS` back to `SECTION_GRID`.
- All 775 automated unit tests are passing successfully via `busted`.
- Tested the newly touched scripts (`data/items_new.lua`, `views/bagview_new.lua`, `views/gridview_new.lua`, `frames/bag.lua`, `core/constants.lua`) under `luacheck`, observing 0 errors and 0 warnings.