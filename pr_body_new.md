### Summary
Implemented a new robust, highly compatible `ItemLoader` (`data/loader.lua`) inspired by the Moonlight addon. The new loader leverages Blizzard's native `ContinuableContainer` to asynchronously prime item details and maintains a permanent, static cache of `ItemMixin` objects bound to physical slotkeys.

### Motivation
Historically, the data sweep phase dynamically instantiated transient `ItemMixin` objects on every `BAG_UPDATE` or full scan, causing GC pressure and potential micro-stutters. Additionally, reading item details before the C-level client cache was primed resulted in blank frames or flickering during loading states.

By using `ContinuableContainer` inside `ItemLoader:TellMeWhenABagIsUpdated`, we ensure that the UI render phase is strictly deferred until all item data for updated bags is safely cached. The static `ItemMixin` cache eliminates transient object allocations. The architecture has been explicitly documented in `.claude/rules/data-loader.md`.

### Testing and Validation
- **Unit Testing:** Wrote a comprehensive suite of isolated tests (`spec/loader_spec.lua`) mocking `ContinuableContainer` and `ItemMixin` to verify static cache behavior and event bucketing. Updated `spec/refresh_spec.lua` to gracefully handle loader mock isolation.
- **Suite Pass:** All 884 unit tests pass successfully under the strict Lua 5.1 environment (`busted`).
- **Linter:** Code passes static analysis with `luacheck` returning 0 warnings and 0 errors across all modified files.