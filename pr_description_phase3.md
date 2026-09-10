# Phase 3: Clean-Sweep Virtual Stacks Implementation

## Summary
This PR implements **Phase 3** of our data farming and rendering pipeline refactoring as detailed in our architectural blueprint (`docs/render.md`). It replaces the old, delta-based virtual stacking system with a clean-sweep $O(1)$ constant-time stacking module (`data/stacks_new.lua`). We've also updated all `.toc` files to activate the new module, and added the relevant documentation.

## Motivation
Historically, stacking relied on incremental delta updates during active database loops. This coupled data harvesting with UI rendering and was prone to state desynchronization due to Blizzard's API out-of-order `BAG_UPDATE` events. By shifting to a completely state-independent clean-sweep stacking system, we guarantee that virtual stack trees are always mathematically correct based on physical item scans.

Additionally, we've optimized the insertion and deletion checks to operate in $O(1)$ constant-time, entirely avoiding nested $O(N)$ lookup loops for determining the root item.

## Testing & Validation
- **Unit Testing:** Wrote a complete unit test suite in `spec/stacks_new_spec.lua` to validate the newly decoupled stacking logic, including handling multiple children and missing cache entries.
- **Test Suite Pass:** Ran the full 751-test suite locally with `busted` against Lua 5.1 with 0 failures.
- **Linting:** Ensured no globals leaked using `luacheck` against the Lua 5.1 standard.
- **In-Game Verification:** In previous steps, added debugging commands to ensure the structure translates perfectly to in-game container data without visual corruption.