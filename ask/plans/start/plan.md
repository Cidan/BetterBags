# ProcessRefresh Functional Pipeline Refactor Plan

## Context and Goal
The `ProcessRefresh` function in `data/items.lua` is a monolithic 500-line function that directly mutates `slotInfo` state. The goal is to refactor this into a pure, unidirectional functional pipeline that passes data linearly between distinct phase functions, rather than relying on an ever-mutating global state bag. This allows for easier testing, zero-cost state drops, and more readable architecture.

## Approach
We will rip the `items:ProcessRefresh(ctx, kind)` function into 5-6 distinct, purely scoped helper functions. 

### 1. Functional Phase Breakdown
`items:ProcessRefresh` will be rewritten to look conceptually like:
```lua
function items:ProcessRefresh(ctx, kind)
  local bagList = self:Phase1_DetermineBags(ctx, kind)
  local itemData, equipmentData = self:Phase2_Harvest(kind, bagList)
  local previousItems = self:GetPreviousItems(kind)
  
  -- Compute and clear glows for items moved between slots
  self:Phase3_ClearMovedItemGlows(ctx, previousItems, itemData)
  
  local stackData, visibleItemsBySlotKey = self:Phase4_ApplyVirtualStacks(kind, itemData)
  local enrichedData, sectionLayouts = self:Phase5_EnrichCategories(kind, itemData)
  local sortedItems = self:Phase6_Sort(kind, visibleItemsBySlotKey)
  local tabData = self:Phase7_PartitionIntoTabs(ctx, kind, sortedItems)
  
  self:Phase8_CommitAndDispatch(ctx, kind, itemData, visibleItemsBySlotKey, tabData, sectionLayouts, equipmentData)
end
```
*(Function names and boundaries may be adjusted slightly during implementation for optimal garbage collection and Lua performance).*

### 2. Purging Dead Delta State
The legacy architecture computed `addedItems`, `removedItems`, `updatedItems`, and a `deferDelete` flag on `slotInfo` on every sweep. With the clean-sweep architecture, these are essentially dead code except for one use-case: preventing "new item glows" from flashing when a player simply moves an existing item to a different slot.
- **Action:** We will delete all delta assignments to `slotInfo`.
- **Replacement:** A highly specific `Phase3_ClearMovedItemGlows(ctx, previousItems, currentItems)` function will perform a quick GUID intersection to clear glows on moved items, then discard the tracking tables.

### 3. State Commitment
The pipeline will avoid mutating `slotInfo` until the very last step (`Phase8_CommitAndDispatch`), at which point the final structurally pure datasets are written to the UI state and the `RefreshBackpack/Done` event is broadcast.

### 4. Test Harness Updates
The `spec/` folder heavily mocks or relies on the exact step-by-step mutations inside `ProcessRefresh`. Because we are shifting boundaries, tests will need to be refactored:
- Existing tests that call `ProcessRefresh` and assert on `slotInfo.addedItems` or `updatedItems` will be cleaned up.
- New unit tests will be created or adjusted to validate the isolated phase functions directly (e.g., passing raw `itemData` into `Phase5_EnrichCategories` and verifying the output).

## Risks and Edge Cases
- **Garbage Collection (Stutters):** If we pass completely new cloned datasets out of every phase, we will overwhelm the Lua GC. We must ensure we pass the *same* underlying `itemData` nodes linearly through the pipeline, while the phase functions orchestrate the linking and mapping (like `visibleItemsBySlotKey`), maintaining the functional paradigm without the functional GC tax.
- **Test Breakage:** This will break many system-level assertions in the test harness that expect mid-pipeline state. Extensive test-fixing is required.

## Execution
- **Step 1:** Add the new Phase helper functions into `data/items.lua`.
- **Step 2:** Refactor `items:ProcessRefresh` to act purely as the orchestrator.
- **Step 3:** Purge `slotInfo` delta properties (`addedItems`, `removedItems`, `updatedItems`, `deferDelete`).
- **Step 4:** Run tests and fix all broken assertions in `spec/` caused by the removed properties or altered boundaries.
- **Step 5:** Commit changes.