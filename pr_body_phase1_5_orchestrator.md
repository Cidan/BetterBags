## Summary
This PR implements the Phase 1-5 End-to-End Orchestrator for the BetterBags rendering pipeline. It introduces a centralized orchestrator function (`items:ProcessRefresh`) in `data/items_new.lua` that sequentially coordinates Data Farming (Phase 2), Virtual Stacking (Phase 3), and Search Indexing (Phase 4). It also un-stubs `data/refresh.lua` to wire up the core `OnEnable` and `RequestUpdate` event pipeline directly to the new static `ItemLoader`.

## Motivation
Previously, the system relied on deeply nested module chains and incremental state updates that could get out of sync due to Blizzard's API race conditions. By establishing a clear, single-function, top-down pipeline, we ensure that the entire sequence—harvesting physical data, resolving virtual stacks, and building search indices—executes in strict, deterministic order. This completely eliminates stale cache bugs and complex cyclic dependencies.

## Testing and Validation Performed
- **TDD Specs:** Created `spec/orchestrator_spec.lua` to strictly assert the sequential execution of phases, state synchronization, and mock button item assignment.
- **Event Testing:** Created `spec/refresh_spec.lua` to validate asynchronous update debouncing and event callback integrations.
- **Test Suite Passed:** Executed all 762 specs via `busted` locally on the Lua 5.1 runtime, passing flawlessly with 0 errors.
- **Linting:** Verified code quality using `luacheck` against the modified files with 0 warnings and 0 errors.
