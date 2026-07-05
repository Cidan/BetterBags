# Phase 4: Search Indexing Refactor

## Summary of Changes
This PR implements Phase 4 of our 8-phase rendering pipeline refactor, focusing on a complete overhaul of the search indexing engine:
* Replaced the legacy incremental search indexer with a new breadth-first, clean-sweep engine (`data/search_new.lua`).
* Introduced a deterministic `IndexItems(currentItems)` API that completely wipes and rebuilds indices from the resolved stack model on every refresh.
* Maintained 100% downward compatibility for all legacy query execution APIs (`search:Search()`, `search:EvaluateQuery()`, `search:isInIndex()`) to prevent any downstream breakage.
* Updated all four client `.toc` files to load `data\search_new.lua` instead of the legacy module.
* Documented architectural guidelines in `.claude/rules/search-indexing.md`.

## Motivation
In the legacy pipeline, search indexing was driven imperatively and incrementally inside the massive changeset comparison loop. This introduced state desynchronization, ghost index entries, and complex circular dependencies where stacking rules or UI states could leak into the search index.
By decoupling search indexing from physical slot changes and transitioning to a pure breadth-first sweep (wiping and rebuilding cleanly from the resolved layout state), we guarantee 100% index accuracy with zero chance of state leakage or stale caches. 

## Testing and Validation
* Implemented comprehensive test-first TDD coverage in `spec/search_new_spec.lua` for the new indexing logic.
* Validated that the full `busted` test suite passes flawlessly on the Lua 5.1 runtime (753 unit tests).
* Linted the new module and tests with `luacheck` against the Lua 5.1 standard (0 warnings, 0 errors).
* Verified downward compatibility with legacy query API paths.