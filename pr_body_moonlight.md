### Summary
Extracted the high-performance asynchronous item loading concepts from the Moonlight project and implemented a fully compatible `ItemLoader` module in `data/loader.lua`. This loader is securely registered across all four WoW client TOC files (Retail, Vanilla, TBC, Mists).

### Motivation
The previous data sweep phase performed expensive full queries and built fresh `ItemData` tables on every update, which caused race conditions, partial load states, and blank UI frames (especially when switching between Bank and Warbank or sorting). By migrating to Moonlight's elegant asynchronous approach using Blizzard's native `ContinuableContainer` and maintaining a permanent, static cache of `ItemMixin` objects mapped 1-to-1 to slot keys, we drastically reduce garbage collection overhead and eliminate partial data loads safely across all supported WoW client flavors.

### Testing/Validation
- Verified the logic perfectly adapts to any active WoW client without raising syntax or missing-API errors (e.g., avoiding retail-only `C_Bank` and `Enum` namespaces on Classic versions).
- Wrote extensive TDD unit tests (`spec/loader_spec.lua`) asserting module initialization, static cache population, and asynchronous callback triggers via simulated `BAG_UPDATE` events and `ContinuableContainer` mocks.
- All 884 tests in the suite pass with 100% success rate.
- Ran `luacheck` against the codebase, producing 0 warnings across all files.