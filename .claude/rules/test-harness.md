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

  -- Load the high-fidelity repository-relative snapshot file
  dofile("test.lua")

  -- Initialize Database module using the loaded BetterBagsDB structure
  local DB = addon:GetModule("Database")
  DB:OnInitialize()
  ```

### 3. High-Fidelity End-to-End Simulation (Phases 2 - 4.5)
To test the pipeline with maximum fidelity, we do not mock high-level pipeline functions like `items:Harvest`. Instead, we mock the World of Warcraft client's low-level container and item C-APIs using our serialized dump as the game state seed. This forces the real physical scanning, data-farming, stacking, and indexing systems to execute on top of our dataset.
- **Rule:** Mock the underlying WoW client C-level APIs (`C_Container` and `C_Item`) using raw dump fields, leaving `items:Harvest` completely unmocked.
- **Mocks Implementation Pattern:**
  ```lua
  -- 1. Mock C_Container to read from dumpItems
  _G.C_Container.GetContainerNumSlots = function(bagid)
    local maxSlot = 0
    for _, item in pairs(dumpItems) do
      if item.bagid == bagid and item.slotid > maxSlot then
        maxSlot = item.slotid
      end
    end
    return maxSlot
  end

  _G.C_Container.GetContainerItemID = function(bagid, slotid)
    local item = dumpItems[bagid .. "_" .. slotid]
    return item and not item.isItemEmpty and item.containerInfo.itemID or nil
  end

  _G.C_Container.GetContainerItemInfo = function(bagid, slotid)
    local item = dumpItems[bagid .. "_" .. slotid]
    return item and not item.isItemEmpty and item.containerInfo or nil
  end

  -- 2. Mock C_Item to resolve item metadata from dumpItems
  _G.C_Item.GetItemInfo = function(itemID)
    for _, item in pairs(dumpItems) do
      if item.containerInfo and item.containerInfo.itemID == itemID then
        local info = item.itemInfo
        return info.itemName, info.itemLink, info.itemQuality, info.itemLevel, 
               info.itemMinLevel, info.itemType, info.itemSubType, info.itemStackCount, 
               info.itemEquipLoc, info.itemIcon, info.sellPrice, info.classID, 
               info.subclassID, info.bindType, info.expacID, info.setID, info.isCraftingReagent
      end
    end
    return nil
  end
  ```

### 4. Pipeline Execution & State Invalidation
Once C-level APIs are mocked, triggering `items:ProcessRefresh(ctx, const.BAG_KIND.BACKPACK)` executes:
- **Phase 2 (Data Farming):** Sweeps physical bags and extracts physical `ItemData` using our mocked container APIs.
- **Phase 3 (Virtual Stacks):** Resolves parent-child stack structures from a clean-slate.
- **Phase 4 (Search Indexing):** Builds ngrams and full-text indexes over all items in the dataset.
- **Phase 4.5 (Category & Data Enrichment):** Assigns final priority-based categories to each slot.
- **Verification Rule:** Assert that specific items (including qualities, binding, counts, and custom classifications) resolve and group perfectly under their corresponding categories in the final generated `slotInfo.itemsBySlotKey`.
