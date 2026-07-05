# Live SavedVariables & Item Dump Test Harness Rules

This document defines the architecture, design guidelines, and API contracts for utilizing live WoW SavedVariables and `/bbdb` backpack item dumps as high-fidelity integration test harnesses in BetterBags.

## Architectural Guidelines

### 1. High-Fidelity Real-World Simulation
Manually written mock data is useful for validating simple, isolated unit tests, but it fails to replicate the complexity of real-world user layouts. A typical user's database contains hundreds of custom categories, deeply nested virtual tab groups, complex search caches, and diverse item classifications.
- **Rule:** Integration and system-level tests should leverage real SavedVariables dumps to recreate full user databases under test conditions.
- **Source:** The `/bbdb` debug window "Dump" tab writes a perfectly sanitized, 100% serializable snapshot of both user configurations and the current backpack items directly to `BetterBagsDB`.

### 2. Sandbox Isolation & Seed Loading
To prevent test side-effects and preserve local user configurations:
- **Rule:** Test cases must load SavedVariables dumps dynamically within a sandbox, inject them into the AceDB test profile, and discard or reset them after execution.
- **Mechanism:**
  ```lua
  -- Save existing global if any
  local oldDB = _G.BetterBagsDB
  _G.BetterBagsDB = nil

  -- Load the high-fidelity snapshot file
  dofile("/home/antonio/git/test.lua")

  -- Initialize Database module using the loaded BetterBagsDB structure
  local DB = addon:GetModule("Database")
  DB:OnInitialize()
  ```

### 3. Pipeline Validation against Dumped Items
- **Rule:** The `debugBackpackDump` slot key dictionary must be used to seed the mock physical slot container when simulating game item scans.
- **Harness Integration:**
  - Mock `C_Container.GetContainerNumSlots` and `C_Container.GetContainerItemInfo` to return item data from the database's `debugBackpackDump` collection.
  - Run `items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)` synchronously.
  - Verify that the resulting `slotInfo` contains the exact items, resolved custom categories, and virtual stacks without any client-side or database-level crash.
  - Validate that the search engine (`search:IndexItems`) successfully indexes the real items and handles custom queries on real-world datasets.
