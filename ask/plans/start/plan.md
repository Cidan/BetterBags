# Initialization Refactor Plan

## Goal
Change Ace3 module `OnInitialize()` functions to a custom `Init()` function across the codebase, bypassing Ace3's automatic (and unordered) initialization loop. Orchestrate the `Init()` calls explicitly inside `addon:OnInitialize()` in `core/init.lua` to enforce proper dependency loading order. Fix all test references. Keep the `PLAYER_LOGIN` event split changes for a subsequent task.

## Steps to Execute (in subsequent loop steps)

### 1. Rename `OnInitialize` to `Init` in all Modules
We need to edit the following files to replace `function <module>:OnInitialize()` with `function <module>:Init()`.
- `core/database.lua`
- `core/events.lua`
- `core/async.lua`
- `data/items.lua`
- `data/refresh.lua`
- `data/search.lua`
- `data/loader.lua`
- `data/tooltip.lua`
- `data/categories.lua`
- `data/groups.lua`
- `data/equipmentsets.lua`
- `util/bucket.lua`
- `debug/debug.lua`
- `themes/themes.lua`
- `frames/item.lua`
- `frames/itemrow.lua`
- `frames/contextmenu.lua`
- `frames/bagbutton.lua`
- `frames/section.lua`
- `integrations/consoleport.lua`

*Note: Do NOT rename `addon:OnInitialize()` in `core/init.lua`.*

### 2. Orchestrate `Init()` in `core/init.lua`
In `core/init.lua`, locate `function addon:OnInitialize()`. Add explicit calls to the newly renamed `Init()` functions for all the modules listed above in a safe, logical dependency order (e.g., `events`, `debug`, `database`, `async`, `bucket`, `themes`, data models, frames). 
*Note: Do NOT move UI frame creation (`BagFrame:Create`, etc.) into `addon:OnInitialize()` during this step. We are strictly handling the `Init()` rename and orchestration for now.*

### 3. Update Test Harnesses in `spec/`
Search and replace all instances of `:OnInitialize()` with `:Init()` (or `.OnInitialize` with `.Init`) in the `spec/` folder.
- `spec/frames/unification_spec.lua`
- `spec/itemrow_spec.lua`
- `spec/database_migration_spec.lua`
- `spec/debug_dump_harness_spec.lua`
- `spec/bags/backpack_spec.lua`
- `spec/views/persistent_tabs_spec.lua`
- `spec/items_spec.lua`
- `spec/views/gridview_spec.lua`
- `spec/orchestrator_spec.lua`
- `spec/search_spec.lua`
- `spec/frames/item_spec.lua`
- `spec/frames/section_spec.lua`
- `spec/database_spec.lua`
- `spec/refresh_spec.lua`
- `spec/frames/bankslots_spec.lua`
- `spec/loader_spec.lua`
- `spec/themes_spec.lua`
- `spec/frames/money_spec.lua`
- `spec/groups_spec.lua`
- `spec/tooltip_spec.lua`
- `spec/categories_spec.lua`
- `spec/events_spec.lua`
- `spec/async_spec.lua`
- `spec/equipmentsets_spec.lua`
- `spec/bucket_spec.lua`

### 4. Documentation
Create a markdown file (e.g., `.claude/rules/initialization.md`) detailing the manual initialization pattern. It should explain that modules use `Init()` instead of Ace3's `OnInitialize()` to ensure deterministic boot order, and list the orchestrator as `addon:OnInitialize()` in `core/init.lua`. This fulfills the project's PRIME DIRECTIVE for documenting structural changes.

### Potential Risks / Edge Cases
- **Missing Module Calls:** Forgetting to call `Init()` on a module in `core/init.lua` that previously relied on Ace3's auto-init. The explicit list in step 1 must exactly match the calls added in step 2.
- **Double Init:** If any script manually called `OnInitialize()` outside of tests, it might now error or need an update to `Init()`.
- **Test Setups:** Some tests mock `.OnInitialize = function() end`. These must be updated to `.Init = function() end`.