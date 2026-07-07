# Implementation Plan: Pre-Sorted Section Data Architecture

## Goal
Move the responsibility of sorting sections (categories) out of the UI rendering phase and into the data enrichment phase (Phase 4.5). The UI layer will become a "dumb painter" that blindly creates and populates sections in the exact order specified by the pre-computed data structure. This optimizes rendering performance by eliminating expensive frame re-anchoring and algorithmic sorting on UI components.

## 1. Synthesize Category Data (Phase 4.5)
**Target:** `data/items_new.lua`
- After constructing the `slotInfo.sortedItems` array, create a new pass to tally up category metrics.
- Build a lightweight array of category metadata: `slotInfo.sortedCategories = {}`.
- Initialize a local tally dictionary to avoid duplicate entries and count sizes efficiently.
- Iterate over `slotInfo.sortedItems`:
  - For each item, look up or initialize its category entry in the tally dictionary.
  - The entry should look like: `{ name = "Category Name", count = 0, isFreeSpace = false, isRecent = false, ... }`.
  - Increment the `count` for each item.
  - Set specific flags (like `isFreeSpace`, `isRecent`) based on the category name or item attributes, which will be useful for sorting priorities.
- Convert the values of the tally dictionary into the `slotInfo.sortedCategories` flat array.

## 2. Refactor Section Sorting Logic
**Target:** `util/sort.lua`
- Add new data-layer sort functions that operate on the lightweight category metadata tables instead of UI section frames.
- Example functions:
  - `SortCategoryDataAlphabetically(aData, bData)`
  - `SortCategoryDataBySizeDescending(aData, bData)`
  - `SortCategoryDataBySizeAscending(aData, bData)`
- These functions must replicate the exact logic currently used for UI frame sorting, including pinning specific categories (e.g., Free Space, Recent Items) to the top or bottom of the list according to their flags.
- Add a new helper `sort:GetCategoryDataSortFunction(kind, view)` which reads `database:GetSectionSortType(kind, view)` and returns the appropriate data-layer sort function.
- In `data/items_new.lua`, after building `slotInfo.sortedCategories`, apply the appropriate sort function to the array using `table.sort(slotInfo.sortedCategories, selectedSortFunc)`.

## 3. Make View Instantiation 100% "Dumb"
**Target:** `views/bagview_new.lua` and `views/gridview_new.lua`
- Modify the rendering loop in `Render` (or equivalent method) to process the pre-sorted lists sequentially.
- **Pre-create Sections:** Before looping over items, loop over `slotInfo.sortedCategories` using `ipairs`. For each category metadata object, call `view:GetOrCreateSection(ctx, catData.name)`. Because the UI grid naturally appends elements in the exact order they are added, creating them in this pre-sorted order guarantees the UI sections are positioned perfectly.
- **Populate Sections:** Retain the existing loop over `slotInfo.sortedItems` using `ipairs`. Add each item button to its corresponding (already created) section.
- **Remove UI Sorting:** Completely delete all calls to `view.content:Sort(...)`. The UI grid no longer needs to perform any expensive frame re-anchoring or algorithmic sorting.

## Risks & Edge Cases
- **Empty Sections:** Ensure we don't accidentally create empty sections. Since the tally is built directly from `slotInfo.sortedItems`, only categories with at least one item (or a dummy empty slot item) will be tallied and created.
- **Sort Priority Rules:** Existing sort rules that pin specific categories (e.g., "Free Space" at the bottom, "Recent Items" at the top) must be carefully migrated to the new data-layer sort functions to prevent visual regressions.
- **Blizzard Bag Mode (`SECTION_ALL_BAGS`):** Ensure the category metadata correctly captures the overridden physical bag names (e.g., `#1: Backpack`) when in Blizzard Bag Mode. The data-layer sort must correctly order these physical bags sequentially by ID.
- **Filter Sync:** The view layer's logic to "Hide filtered sections" must still function. By creating sections in order, any filtered/hidden sections will simply be skipped or hidden without disrupting the established order of the remaining visible sections.