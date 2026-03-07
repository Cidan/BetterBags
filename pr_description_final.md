### Summary of Changes
- Replaced the legacy, stateful, delta-based views with a high-performance clean-sweep view engine (`views/gridview_new.lua` and `views/bagview_new.lua`).
- Unified Category View, One Bag View, and Blizzard Bag View under a single string-based section assignment pass (Polymorphic Category Placement Engine).
- Moved stack/root visibility resolution completely upstream (Phase 3/4) inside `items_new.lua:ProcessRefresh()`, decoupling `GridView` and `BagView` from game-state business logic.
- Fixed a stack double-counting bug under `opts.dontMergePartial` by correctly excluding unmerged partial children from the root item's `stackedCount`.
- Resolved a critical Lua bug in `data/items_new.lua:586` where `strsplit` returned multiple values, causing `tonumber` to fail with a `base out of range` error.

### Motivation
The previous rendering pipeline was tightly coupled with data logic, frequently updating layout state on-the-fly as it parsed virtual stacks and layout rules. This led to duplicate buttons, overlapping grid placements, and race conditions. Phase 6 finalizes the unidirectional, Moonlight-inspired architecture by introducing a 100% deterministic, clean-sweep layout engine. Item frames are now pure presentation layers, simply rendering the exact state provided by the robust upstream data models.

### Testing & Validation
- Integrated safe fallbacks for both `SetItemFromData` and `SetItem` ensuring legacy extensions and mock objects remain fully backward-compatible.
- Implemented a complete suite of unit test specs inside `spec/views/gridview_new_spec.lua` and `spec/orchestrator_spec.lua` to assert grouping, filtering, and stacking layout behavior.
- Verified that all 763 unit tests pass flawlessly on the Lua 5.1 runtime.
- Ran `luacheck` to ensure the codebase remains completely clean (0 warnings / 0 errors).