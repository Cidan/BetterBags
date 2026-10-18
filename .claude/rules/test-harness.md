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

### 5. The Whole Addon (`spec/helpers/whole_addon.lua`)
Most specs load the modules they test next to stubs of the rest. That cannot catch an error that
only shows when the real modules meet in an order startup never produces: a switch between bag
designs made the classic bags after the theme was applied, and crashed in game while every spec
passed (next.md §11f). The whole-addon helper loads and starts all of BetterBags:
- **Use:** `local WholeAddon = dofile("spec/helpers/whole_addon.lua")`; `local handle =
  WholeAddon.Load(opts)`; `handle:Start()`; `handle.addon` is the addon, `handle.errors` every
  error that reached the error handler; `handle:Restore()` in `after_each`. Options: `client`
  (`"retail"`, the default, or `"forever"`: `BetterBags_Camelot.toc`, `WOW_PROJECT_CAMELOT`, Forever's
  9 + 9 bank tabs, a `KeyRingButton`), `next` (BetterBags Next on), `sizeMode` (every bag in every
  view), `theme` (the saved theme), `profile(defaults, const)` (any other default), `globals`
  (what another addon would set, such as the ElvUI and GW2_UI stand-ins a theme needs).
- **A fresh addon:** the one `spec/helpers/addon_loader.lua` made is set aside in AceAddon's
  registry (with its queued entries), and every Lua file of `BetterBags.toc` is loaded in order
  into a new one. Libraries the specs do not load are loaded (LibWindow-1.1, the WagoAnalytics
  shim; byte order marks stripped, which the client skips and Lua 5.1 rejects) or stood in for
  (LibUIDropDownMenu: the four calls the context menu makes).
- **Libraries loaded fresh:** see Memory below.
- **Started as the client starts it:** through AceAddon's own handler, `ADDON_LOADED` (not logged
  in) initializes the addon while its modules are still queued, so the modules it enables are only
  marked; `PLAYER_LOGIN` enables the addon and every marked module. Calling `OnInitialize` and
  `OnEnable` directly is not the same: Sonata would never apply a theme. Saved variables start
  empty on every load (an earlier load's saved setting would otherwise decide the design).
- **The retail client:** Blizzard's `Enum.BagIndex`, `Enum.PlayerInteractionType`,
  `Enum.ItemQuality` from the API documentation of the live branch, the other values as
  `spec/core/constants_spec.lua` sets them, Blizzard's bag frames and bag-bar buttons (with their
  `SlotHighlightTexture`), `NUM_TOTAL_BAG_FRAMES` 5. Mocks that other specs never needed were added
  to `spec/helpers/wow_mocks.lua` from Blizzard's source: `issecurevariable`, `GetRect`, the edit
  box's multi-line methods, `SearchBoxTemplate`/`BagSearchBoxTemplate`, `WowScrollBoxList`,
  `CreateScrollBoxListLinearView`, the list's `ScrollUtil` functions and drag behavior, and
  `CreateDataProvider`.
- **No layout engine:** every frame the loaded addon makes is resolved at the screen's origin, as
  if laid out, and the cursor is far off screen.
- **Restore** puts back everything changed in place (insulation restores only globals): first
  the loaded addon's events, messages and hooks and Sonata's text-size callback (unhooking reads
  the libraries' registries, put back next), then the table fields of every library (AceHook's
  `embeded` and `registry` are keyed by the addon; AceDB's databases; AceConsole's commands),
  `SlashCmdList`, the children lists of frames made before the load, the AceAddon registry and
  queues, LibStub's libraries, the `Enum` tables, and every global as it was. Then it collects.
- **Memory (the failure mode):** a load and start take about 940 MB, because the frame mock makes
  its 178 methods as fresh closures for every frame and the addon makes about 2,700 item buttons
  at login. Anything left reachable after `Restore` keeps all of it: before these restores, each
  load stayed in memory, the integration spec alone peaked at 24.8 GB, and GitHub's runner was
  shut down mid-run twice (no test failed; it ran out of memory). Each holder was found with a
  reference search from the globals, the registry and the stacks (Lua 5.1 rules: a weak-keyed
  table's values are strong). `spec/integration/bag_switch_spec.lua` ("lets the loaded addon be
  collected once restored") fails if a load is kept, run alone or in the full suite. The libraries
  the harness loads are loaded fresh, with any copy another spec registered set aside: LibStub
  upgrades an existing copy in place, and LibWindow's `windowData` (keyed by the bags' frames)
  then outlived the load, which only the full suite showed. Measured now: 3 MB kept after each
  load; the integration spec peaks at 2.2 GB alone, the full suite at 5.2 GB (5.0 GB without it).
- **Cost:** about 1.1 s per load and start, 0.8 s of it the real `ItemFrame:OnEnable` making every
  item button of every slot at login, plus the collection in `Restore`, which walks the whole heap
  (the other specs' too): the integration spec takes about 26 s alone and adds about 32 s to the
  full suite (16 s without it, 48 s with it). Keep whole-addon specs few and pointed: a test needs its own load only when it needs
  a fresh start (what it checks happens the first time something is made). Making the frame mock
  share its methods (one set behind a metatable) would cut both, for every spec.
- Coverage that uses it: `spec/integration/bag_switch_spec.lua` (next.md §11e).

