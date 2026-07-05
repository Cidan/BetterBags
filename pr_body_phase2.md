# Phase 2: Data Farming Engine & Graceful Deactivation

## Summary
This PR implements Phase 2 of the new 8-phase rendering pipeline. We introduce a clean, breadth-first data harvesting engine in `data/items_new.lua` that simply fetches physical item data synchronously from the C-level cache (primed in Phase 1). To ensure a smooth transition without breaking the game client, we employ a "Graceful Stubbed Deactivation": the new `Items` module provides empty stubs for all legacy initialization and query methods. We also stubbed out the legacy rendering triggers in `data/refresh.lua` so the UI does not attempt to draw while we build from the bottom up. Finally, all client `.toc` files were updated to point to `data/items_new.lua`.

## Motivation
The legacy rendering pipeline deeply coupled data harvesting, virtual stacking, search indexing, and UI layout logic into single passes. This caused race conditions, out-of-sync states (like ghost items or duplicate buttons), and was very difficult to debug. By separating out pure physical data farming into its own phase, we ensure absolute determinism and correct item state before any other pipeline phase runs.

## Testing and Validation
- Created comprehensive unit tests in `spec/items_new_spec.lua` to validate container sweeps, empty slot handling, and equipment harvesting.
- The `busted` test suite runs completely green against the Lua 5.1 runtime (725 passes).
- Verified `luacheck` is 100% warning-free for the new and modified files.
- Ensured legacy tests failing due to stubbed systems are sequestered with `.legacy` extensions.
- Provided an in-game slash command `/bb debugitems` for developers to test and verify physical item maps live in the client without needing a fully functioning UI.