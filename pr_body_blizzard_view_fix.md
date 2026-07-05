### Summary of Changes
Added bypass logic in `views/bagview_new.lua` and `views/gridview_new.lua` to explicitly skip custom tab partitioning and group category filters when rendering the Blizzard physical container view mode (`SECTION_ALL_BAGS`). 

### Motivation
When users had a custom group tab active (e.g. `activeGroup > 1`) and switched to Blizzard's physical container view, the view would render completely blank. This occurred because the layout engine continued to apply custom category and group filters to physical bag section frames (like `#1: Backpack`). Since physical containers do not have custom categories, they were all incorrectly filtered out and hidden. Bypassing these filters when in `SECTION_ALL_BAGS` ensures all physical bags and items are always displayed properly.

### Testing and Validation
- **Test-First TDD**: Created a new test case in `spec/views/persistent_tabs_spec.lua` that reproduces the bug scenario (active custom tab > 1, switching to `SECTION_ALL_BAGS`). Verified the test failed before the fix and passed after.
- **Test Suite**: Executed the full suite with 778/778 tests passing (0 failures, 0 errors).
- **Linter**: Verified all modified Lua files are 100% clean under `luacheck` with 0 warnings.
- **Architectural Update**: Documented the unified retail bank loading and persistent tab filtering bypass rules in `.claude/rules/data-loader.md`.