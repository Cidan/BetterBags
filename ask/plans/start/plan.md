# Implementation Plan: Async Chaining for ProcessRefresh

## Files to Modify
1. `data/items.lua`
2. `spec/items_spec.lua`
3. `spec/orchestrator_spec.lua`
4. `spec/debug_dump_harness_spec.lua`

## Approach

### 1. `data/items.lua`
- At the top of the file, uncomment or add `local async = addon:GetModule("Async")` (around line 34).
- Locate the `items:ProcessRefresh(ctx, kind)` method (around line 942).
- Wrap the entire body of `ProcessRefresh` inside an `async:Do(ctx, function(ectx) ... end)` block.
- Place `async:Yield()` after `Phase10_PartitionIntoTabs` and right before `Phase11_CommitAndDispatch`.
- This ensures that Phases 1-10 are executed in Frame 1, the coroutine yields, and Phase 11 (the UI commit and dispatch draw call) is executed in Frame 2.

### 2. Test Files (`spec/items_spec.lua`, `spec/orchestrator_spec.lua`, `spec/debug_dump_harness_spec.lua`)
- Because `ProcessRefresh` will now be asynchronous, tests that call it and immediately assert on `slotInfo` will fail as the coroutine will suspend before Phase 11 executes.
- In each of these spec files, immediately after `core/async.lua` is loaded or near the top of the file, we will stub out the `Yield` function of the Async module.
- Add the following snippet to ensure `ProcessRefresh` executes entirely synchronously during these unit tests:
  ```lua
  local async = addon:GetModule("Async", true)
  if async then
    async.Yield = function() end
  end
  ```
- This elegant test-only mock prevents `async:Do` from yielding to `C_Timer.After` in tests, preserving the atomic, synchronous behavior needed for the test assertions without altering the source code logic with testing flags.

## Risks & Edge Cases
- **Test Integrity:** If we forget to mock `async.Yield` in any other file that calls `ProcessRefresh`, that test will hang or fail its assertions. We must grep to ensure we catch all instances (which are currently `items_spec.lua`, `orchestrator_spec.lua`, and `debug_dump_harness_spec.lua`).
- **Coroutine Context:** The parameters `ctx` and `kind` inside `ProcessRefresh` will be available as upvalues to the coroutine closure. However, we must ensure we use the scoped `ectx` inside `async:Do` for phases when we pass context down (e.g. `self:Phase1_DetermineBags(ectx, kind)`).