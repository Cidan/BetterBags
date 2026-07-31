# Implementation Plan: Pure Functional Draw Phase

## Goal
Ensure the UI draw phase (`Draw()` / `Render()`) has absolutely no side effects, adhering to a purely functional presentation model. All state mutations, memory allocations, and global API queries must be shifted upstream to the data sweep phase.

## Approach & Changes

### 1. Remove On-the-Fly Database Mutation (Categories)
**File:** `views/views.lua`
- **Action:** Remove the `categories:CreateCategory` call inside `GetOrCreateSection`.
- **Reason:** The presentation layer must not mutate the database.
- **Dependency:** The data sweep phase must ensure any dynamic categories (like those for virtual groups or missing categories) are created before passing `slotInfo` to the view layer.

### 2. Replace Dynamic Frame Allocation with an Object Pool
**File:** `frames/item.lua`
- **Action:** Remove the dynamic `self:Create` (which calls `CreateFrame`) inside the `GetButton` fallback for virtual slotkeys (e.g., `"Container"`).
- **Action:** Implement a virtual item button pool.
  - Pre-allocate a reasonable number of generic virtual buttons (e.g., 20-50) during `Init()` or `OnEnable()`.
  - Introduce `AcquireVirtualItem()` to pull from this pool.
  - Update `GetButton()` to use `AcquireVirtualItem()` for non-physical slotkeys.
  - Ensure the `Wipe()` method correctly releases these virtual buttons back to the pool.

### 3. Pre-Compute External API Queries and Context Matches
**Files:** `data/items.lua`, `frames/item.lua`
- **Action:** Shift the logic for `GetItemContextMatchResult` out of `frames/item.lua` and into the data sweep phase (`data/items.lua`).
- **Action:** The data phase must determine `ItemContextMatchResult` (e.g., by evaluating `addon.atBank`, active bank tabs, and calling `C_Bank.IsItemAllowedInBankType`) and assign it as a property on the `ItemData` node (e.g., `data.itemContextMatchResult`).
- **Action:** Update `frames/item.lua` to strictly read this property from `data` instead of querying global state or external WoW APIs on the fly.

### 4. Relocate Search Evaluation Upstream
**Files:** `data/items.lua`, `frames/bag.lua`
- **Action:** Remove the late-stage search execution at the end of the `Draw` callback in `frames/bag.lua` (which queries `searchBox:GetText()` and calls `search:Search(text)`).
- **Action:** Evaluate search matches upstream in the data phase (`data/items.lua`). Set a flag (e.g., `data.isSearchResult`) on the `ItemData` node during the sweep.
- **Action:** The presentation layer should simply use this flag to dim/highlight items synchronously as they are drawn.

### 5. Testing (Happy & Sad Paths)
**Files:** `spec/frames/item_spec.lua`, `spec/views/views_spec.lua`, `spec/data/items_spec.lua` (or relevant test files)
- **Action:** Write tests verifying that `itemFrame:GetButton` for a virtual slot retrieves from the pre-allocated pool and does not invoke `CreateFrame`.
- **Action:** Write tests validating that the data sweep phase correctly attaches `isSearchResult` and `itemContextMatchResult`.
- **Action:** Write tests ensuring `views.lua` successfully renders without mutating the global `categories` state.

## Risks & Edge Cases
- **Pool Exhaustion:** If the virtual item pool runs out of pre-allocated frames during a massive free-space grouping, it may crash or fail to render. A sufficiently large initial allocation (e.g., 50) may be needed.
- **State Stale-ness:** Moving `ItemContextMatchResult` upstream means if the bank context changes rapidly without a `BAG_UPDATE`, the item highlight could technically lag by one frame. Ensure events that toggle bank context trigger a clean data refresh.
- **Search Latency:** Moving search evaluation into the data phase could add latency to typing in the search box. Typing in the search box must correctly trigger a fast data refresh loop rather than just a UI redraw.