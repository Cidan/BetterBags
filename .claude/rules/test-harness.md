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
  fresh on every load (an earlier load's saved setting would otherwise decide the design): by
  default those of an install that never changed a setting (`BetterBagsDB = {}`), so the bags are
  the classic ones unless `next` is set; `install = "new"` starts with none at all, a new install,
  which starts with BetterBags Next (next.md §1). Before new installs started with Next, every load
  had none; the existing install keeps every spec written then meaning what it did.
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
- **No item button template:** the frame mock builds none of `ContainerFrameItemButtonTemplate`'s
  regions or mixin methods (item specs build their own button fakes), so the whole addon cannot
  draw an item button: a spec that runs a read and its draw keeps every bag empty
  (`globals = { C_Container = ... }` with `GetContainerNumSlots` 0; the mock gives every bag 16
  slots and every slot an item). Drawing items on the whole addon needs a template mock from
  Blizzard's source first.
- **Errors in message and event handlers reach `handle.errors`.** AceEvent dispatches through
  CallbackHandler, which calls each handler with `securecallfunction`. The mock used to return
  `pcall`'s results and drop the error, so a handler that threw (a bank draw missing a Blizzard
  global) failed silently; it now does what the client does (warcraft.wiki.gg API:securecall):
  the error goes to `geterrorhandler()` and the call returns nothing. The whole suite passed
  unchanged with the fix. Coverage: `spec/integration/bag_switch_spec.lua` ("collects an error
  thrown in a message or event handler").
- **Driving time:** pass `globals = { C_Timer = ... }` with an `After`/`NewTimer` that keep their
  timers for the spec to run (`spec/integration/bank_open_spec.lua`); the startup read runs once
  the spec fires `LOADING_SCREEN_DISABLED` and runs one quiet frame on `refresh._startupFrame`.
- **Restore** puts back everything changed in place (insulation restores only globals): first
  the loaded addon's events, messages and hooks and Sonata's text-size callback (unhooking reads
  the libraries' registries, put back next), then the table fields of every library (AceHook's
  `embeded` and `registry` are keyed by the addon; AceDB's databases; AceConsole's commands),
  `SlashCmdList`, the children lists of frames made before the load, the AceAddon registry and
  queues, LibStub's libraries, the `Enum` tables, and every global as it was. Then it collects.
- **Memory: the frame mock shares its methods.** `CreateMockWidget` (`spec/helpers/wow_mocks.lua`)
  used to define its ~188 methods as fresh closures inside every widget, and gave every widget but
  a texture seven child textures up front (`NormalTexture`, `PushedTexture`, `HighlightTexture`,
  `NewItemTexture`, `BattlepayItemTexture`, `ItemContextOverlay`, `UpgradeIcon`), each with its own
  copy: about 1,500 closures per frame. A whole-addon load (about 2,700 item buttons) held 1.6 GB
  live, the suite peaked at 19.4 GB resident in one process, a GitHub runner (16 GB) was shut down
  mid-run twice, and a local run locked a 93 GB machine. Now the methods are defined once
  (`WidgetMethods`, item buttons' own in `ItemButtonMethods`) and found through one metatable
  (`WidgetMeta`); a widget holds only its state; the seven textures are made the first time
  something reads them (`LAZY_TEXTURES`; their getters read the field with `rawget`, or the lazy
  lookup would call itself). Behavior is unchanged: every spec passed without a change. Measured: a load holds
  78 MB live (was 1.6 GB); the largest file peaks at 183 MB alone (was 5.3 GB); every file run
  alone sums to 2.1 GB of peaks (was 23.5 GB); the full suite peaks at 1.25 GB in one process (was
  19.4 GB) and takes 17 s (was 112 s).
  - **A method is shared, so it must not read the constructor's locals**: use the widget's fields
    (`self._type`, `self._name`, `self._parent`). Per-widget state goes in the constructor.
  - **Overriding a method on one widget** (`frame.Method = ...`, a spec's `override`) sets the
    widget's own field, which shadows the shared one; restoring it to `rawget`'s nil brings the
    shared one back.
- **Memory: nothing may keep a loaded addon after `Restore`.** Anything left reachable keeps the
  whole load. Holders found so far, each with a reference search from the globals, the registry
  and the stacks (Lua 5.1 rules: a weak-keyed table's values are strong):
  - shared tables the loaded addon adds to: library registries, `SlashCmdList`, frames' children
    lists, LibStub's libraries (loaded fresh; LibWindow's `windowData` outlived a load), and the
    shared `GameTooltip`, whose owner a hovered button of the loaded addon became (the mock keeps an
    owner after `Hide`); `Restore` puts each back as it was;
  - **a spec's own locals**: busted keeps every spec's closures, and so their upvalues, for the
    whole run. A fake clock's list of timers that never ran (the 2-second timeouts) held the loaded
    addon of the guild bank and bank open specs' last test until the suite ended. Clear such lists
    in `after_each` after `Restore` (`timers = nil`).
  - `spec/integration/bag_switch_spec.lua` ("lets the loaded addon be collected once restored", and
    "... after one of its frames owned the tooltip") fails if a load is kept.
- **Measure one file at a time.** A single process holds every spec it ran, so a memory problem is
  found file by file: `/usr/bin/time -f "%M" ~/.local/lua51/bin/busted spec/<file>` gives a file's
  peak resident memory in KB. To see what is live, a busted helper outside the repository
  (`--helper=/tmp/x.lua` that `dofile`s `spec/setup.lua` and subscribes to `{ "test", "end" }` /
  `{ "file", "end" }`) can print `collectgarbage("count")` after a full collection; a load that
  stays live after `Restore` is a leak. Run the whole suite in one process only under a cap
  (`(ulimit -v 4000000; ~/.local/lua51/bin/busted)`), as CI does (`.github/workflows/test.yml`
  caps its test step at 4 GB, so a regression fails with "not enough memory" rather than shutting
  the runner down).
- **Cost:** a load and start take about 0.2 s, most of it the real `ItemFrame:OnEnable` making
  every item button of every slot at login. Keep whole-addon specs few and pointed: a test needs
  its own load only when it needs a fresh start (what it checks happens the first time something
  is made).
- Coverage that uses it: `spec/integration/bag_switch_spec.lua` (next.md §11e; and §1: a new
  install starts with Next, an existing one keeps the classic bags),
  `spec/integration/bank_open_spec.lua` (refresh-scheduler.md §11).

