---
paths:
  - "spec/setup.lua"
  - "spec/helpers/*.lua"
  - "spec/fixtures/*.lua"
  - "spec/fixtures/world/*.lua"
  - "spec/world_spec.lua"
  - "spec/integration/*_spec.lua"
  - "spec/debug_dump_harness_spec.lua"
  - "test.lua"
  - ".busted"
  - ".github/workflows/test.yml"
  - "debug/itemprobe.lua"
  - "spec/debug/itemprobe_spec.lua"
---
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

- **Everything a spec reads is in the repository.** A saved profile or a capture a spec needs goes in `spec/fixtures/`, holding only what it needs (who the player is never goes in one, §5 below). **Failure mode (fixed):** three tests in `spec/bank_tab_category_routing_spec.lua` read `~/Downloads/BetterBags.lua`. In CI, without the file, they were `pending`, so they never ran there, and locally one failed on a clean tree once another profile replaced that file (2026-10-29). The original profile was gone, so `spec/fixtures/bank_categories_flat.lua` rebuilds what they read, from the tabs and assignments the spec's own first test describes: a profile saved before bank categories were scoped by bank type, which goes through `DB:Migrate`. A fixture is loaded with no `pending` fallback, so a missing one fails.

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
passed (next-bagsystem.md §11f). The whole-addon helper loads and starts all of BetterBags:
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
  the spec fires `LOADING_SCREEN_DISABLED` and runs one quiet frame on `refresh._worldFrame`.
- **Logging out:** `handle:Logout()` runs AceDB's own `PLAYER_LOGOUT` handler for the loaded addon's
  database alone, stripping its defaults as the client's logout does; the other specs' databases are
  left as they are (initialization.md §7, `spec/integration/logout_spec.lua`).
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
  alone sums to 2.1 GB of peaks (was 23.5 GB); the full suite peaked at 1.25 GB in one process then (was
  19.4 GB) and took 17 s (was 112 s). What the suite holds as a whole since: §6.
  - **A method is shared, so it must not read the constructor's locals**: use the widget's fields
    (`self._type`, `self._name`, `self._parent`). Per-widget state goes in the constructor.
  - **Overriding a method on one widget** (`frame.Method = ...`, a spec's `override`) sets the
    widget's own field, which shadows the shared one; restoring it to `rawget`'s nil brings the
    shared one back.
- **Memory: nothing may keep a loaded addon after `Restore`.** Anything left reachable keeps the
  whole load until its spec file ends (§6), and a file that loads the addon in many tests holds every
  load. Holders found so far, each with a reference search from the globals, the registry
  and the stacks (Lua 5.1 rules: a weak-keyed table's values are strong):
  - shared tables the loaded addon adds to: library registries, `SlashCmdList`, frames' children
    lists, LibStub's libraries (loaded fresh; LibWindow's `windowData` outlived a load), and the
    shared `GameTooltip`, whose owner a hovered button of the loaded addon became (the mock keeps an
    owner after `Hide`); `Restore` puts each back as it was;
  - **a spec's own locals**: busted keeps every spec's closures, and so their upvalues, until its
    file ends. A fake clock's list of timers that never ran (the 2-second timeouts) held the loaded
    addon of the guild bank and bank open specs' last test (before §6, until the suite ended). Clear
    such lists in `after_each` after `Restore` (`timers = nil`).
  - **a listener a spec leaves registered**: AceEvent's registry keeps every test's handler for the rest of the file. One in
    `spec/guildbank_pipeline_spec.lua` kept every `items/RefreshGuildBank/Done` slotInfo sent after it, whole-addon guild bank
    loads included (`Events._messageMap > ... > cb > its list > the slotInfo > ... > addon`): 400 MB, enough to reach CI's 4 GB
    cap once a few more such tests were added (before §6, the registry was the whole suite's). A handler that keeps what it is
    sent checks its own test is still the current one.
  - `spec/integration/bag_switch_spec.lua` ("lets the loaded addon be collected once restored", and
    "... after one of its frames owned the tooltip") fails if a load is kept.
- **Measure one file at a time.** The suite holds one spec file's memory at a time (§6), so its peak
  is its heaviest file's, and a memory problem is found file by file:
  `/usr/bin/time -f "%M" ~/.local/lua51/bin/busted spec/<file>` gives a file's peak resident memory
  in KB. To see what is live, a busted helper outside the repository (`--helper=/tmp/x.lua` that
  `dofile`s `spec/setup.lua` and subscribes to `{ "test", "end" }` / `{ "file", "start" }`) can print
  `collectgarbage("count")` after a full collection; a load that stays live after `Restore` is a
  leak, and so is memory still live when the next file starts. Run the whole suite in one process
  only under a cap (`(ulimit -v 4000000; ~/.local/lua51/bin/busted)`), as CI does
  (`.github/workflows/test.yml` caps its test step at 4 GB, so a regression fails with "not enough
  memory" rather than shutting the runner down).
- **Cost:** a load and start take about 0.2 s, most of it the real `ItemFrame:OnEnable` making
  every item button of every slot at login. Keep whole-addon specs few and pointed: a test needs
  its own load only when it needs a fresh start (what it checks happens the first time something
  is made).
- **Every order of a client's steps** (`spec/integration/empty_slot_spec.lua`, refresh-scheduler.md §10): a small client
  model answers the APIs through `globals`, and `eachOrder` runs every distinct order of its steps on one load, each from
  a `reset()`. To reach everything a client event reaches, it wraps the mock's `RegisterEvent` and `SetScript` for the
  load (frames listening themselves, OnUpdate drivers) and sends events through `events._eventMap`, never AceEvent's
  shared frame, which holds other specs' listeners. Draws are stubbed on the bags, so the bags can hold items.
- Coverage that uses it: `spec/integration/bag_switch_spec.lua` (next-bagsystem.md §11e; and next.md §1: a new
  install starts with Next, an existing one keeps the classic bags),
  `spec/integration/bank_open_spec.lua` (refresh-scheduler.md §11).

### 5. What the Game Answered (`apiProbe`)
A dump taken since `debug/itemprobe.lua` carries, on each item, `apiProbe`: every value each
Blizzard API returned about it when the dump was taken (data-driven.md, "What the client answered
about an item"), and the profile carries `debugBackpackDumpClient` (the client's version, build and
locale). Mocks built from a dump should answer from `apiProbe` where it has the call, so a harness
test runs on what the game answered rather than on what BetterBags made of it: `itemInfoByLink`
for `C_Item.GetItemInfo(link)`, `itemInfoByID` for the item ID, and so on (each a list with `n`
values, or `{ error = ... }`). Older dumps have no `apiProbe`.
- **`spec/fixtures/dump_retail_12_1_5.lua`**: a capture's dumped items and client only (no other
  part of the profile), written by extracting `debugBackpackDump` and `debugBackpackDumpClient` from
  the SavedVariables, keys sorted. `spec/debug_dump_harness_spec.lua` ("Dump harness: the client's
  own answers") answers every API the harvest calls from it (by location, item ID or link, as each
  API takes them; `C_TooltipInfo.GetBagItem` from the recorded lines) and runs the real pipeline
  and search over it. Its expectations were read from the raw answers. Not probed, so taken from
  the dumped item: `C_Item.GetItemQuality` (the container info's quality), the item GUID.
- **`spec/fixtures/dump_retail_12_1_5_bag.lua`**: a second capture the same day, 33 items, with a
  bag (Horadric Haversack). Its block in the same spec ("a capture with a bag") shares the mocks
  through `clientAnswers(fixturePath)`, which installs them before each test of the block that
  calls it. A new capture becomes a fixture the same way: extract it, add a block calling
  `clientAnswers`, and write its expectations from the raw answers.
- **Who the player is never goes in a fixture.** Dumps record the player's name and realm
  (`debugDumpExtras.player.fullName`) and sessions record them in `meta`; an extracted fixture leaves
  them out.

### 6. A World of Its Own for Every Spec File (`spec/setup.lua`, `spec/helpers/world.lua`)
The suite runs every spec file in one Lua process, and gives each file a world of its own, the one it would get run
alone, let go when the file ends: the suite holds one file's memory at a time.
- **The world** (`spec/helpers/world.lua` returns the function that builds it): the WoW mocks (`wow_mocks.lua`), the
  Ace3 libraries, the BetterBags addon (`addon_loader.lua`) with the modules every spec needs (the profiler engine, the
  pixel check, Flow, Motion, Texels, Next's pixel grid, item fit and coins, SonataResolve, SonataNext with its themes),
  and the mock data (`MockData`). Every global it sets is part of it.
- **A new one for every file:** `spec/setup.lua` records the globals Lua and busted start with, builds one world when
  busted loads it, and on every `{ "file", "start" }` puts those globals back as they were (removing the ones the last
  world added, and restoring the one it replaced: the mocks wrap the `xpcall` they find) and builds a new world. Built on
  the old one's globals, the new world would be the old one: LibStub keeps the copy of itself it finds, and the libraries
  then find themselves loaded. A world takes about 14 ms to build (2.6 s over the suite). Busted's auto-insulation puts
  the globals back as they were at the file's start when it ends, which drops the file's world from them.
- **The world `busted -l` lists with:** list mode (busted's filter loader) swallows the file events, so no file gets a
  world of its own: all of them run their describe bodies on the one `spec/setup.lua` builds when it loads.
- **Letting a finished file go:** busted keeps every element (each describe, it and hook) for the whole run, in its
  context's `parents` and `children` tables, and with each its function (`run`) and environment (`env`), so a file's
  locals, and through them its whole world, stay live. On `{ "file", "end" }`, `spec/setup.lua` clears `run` and `env`
  on every element under the file (busted's exported `children`) and the file's own `env`. The file's own `run`, which
  `--repeat` runs again, is its chunk, which has no upvalues. Without this, a world per file peaked at 3.58 GB, more than
  one world for the whole run.
- **What still carries over from file to file:** Lua's own libraries (`string`, `table`, `math`, `os`, `io`, `debug`: a
  spec that replaces one of their functions puts it back), the Lua registry, and busted's own record of each test: what
  is live between files grows with the tests run, about 3 KB a test (`refresh_pipeline_spec`'s 371 leave 1.07 MB), from
  14 MB to 35 MB over the suite. `spec/fixtures/world/first_world.lua` hands what it left to the next file through the
  registry, in a weak table.
- **What a file still holds while it runs:** everything every one of its tests made, until it ends. In
  `spec/next/small_spec.lua`, frames made by each of the first 59 tests were all still live at test 60, held through
  `UIParent._children` and `NextCurrencyDrag.containers` (reached from the addon's modules, its `orderedModules`,
  AceAddon's `initializequeue` and the pixel check's records); searches before this found each Next control module's
  `all` (every control made, for a theme to restyle: the scroll bar's holds every panel's scroll box, whose
  `OnSizeChanged` holds the panel), the vendor buttons' pool and the fills' `wrapped` regions. All of it is the file's
  world, so it goes with the file. The suite's peak is its heaviest file's: alone, `next/small_spec` peaks at 507 MB
  (365 tests, 300 MB live by the last), then `next/pixel_perfect_spec` (287), `next/theme_panel_spec` (272),
  `integration/theme_switch_spec` (268), `integration/bag_switch_spec` (259), `refresh_pipeline_spec` and
  `next/drag_spec` (252 each) (2026-11-07).
- **Measured** (2026-11-07, 6,865 specs in 194 files, all passing, and every file passing alone): with one world for the
  whole run the suite peaked at 3.17 GB, 1.78 GB of it live by the last file, grown file by file (`next/small_spec` left
  296 MB behind it, `refresh_pipeline_spec` 174, `next/drag_spec` 154, `next/pixel_perfect_spec` 151,
  `next/theme_panel_spec` and `next/settings/content_spec` 132 each). With a world per file it peaks at 613 MB and runs
  in 191 s. Letting finished files' elements go with one world changed nothing (2.90 GB against 2.91 GB, both with a full
  collection before every file).
- **The collector's pause stays 120** (Lua starts a collection once memory reaches the pause, in percent, of what the
  last one left; the default, 200, lets garbage grow as large as what is live): with a world per file, 586 MB and 185 s
  at 120 against 829 MB and 161 s at 200. With one world it was 2.96 GB and 188 s at 120, 3.42 GB and 170 s at 150,
  4.19 GB and 162 s at 200.
- **CI's cap stays 4 GB** (`ulimit -v 4000000` in `.github/workflows/test.yml`, by decision). `ulimit -v` also caps the
  processes a spec starts: at 1 GB, `git` fails under `spec/helpers/ui_source.lua`, and `spec/sonata/plain_art_spec.lua`
  with it, whatever the suite holds.
- **Mistakes this comes from:** one world for the whole run, and its memory hunted holder by holder. From 6,300 specs
  (2026-11-01) the suite peaked at 3.6 GB under CI's 4 GB cap; at 6,560 (2026-11-02) and 6,718 (2026-11-05) it reached
  the cap and died with no summary and no failure listed (exit 1 and a line of progress marks, a crash to read as
  memory). Clearing `UIParent`'s children after every file, and then four of the holders above, each left the peak where
  it was, as each cleared holder exposed the next.
- **Coverage:** `spec/world_spec.lua` runs `spec/fixtures/world/first_world.lua` and `second_world.lua` in a busted of
  their own, started as the running one was (the interpreter, its options and the busted script: `arg[-n]` to
  `arg[0]`). It checks the second file gets an addon and mocks of its own, without the stub module and the mark on
  `C_Container` the first left, that the first file's addon and frame are collected, and that `busted -l` still lists
  both files' tests. The fixtures are named `*_world.lua`, so the suite never runs them (busted's pattern is `_spec`);
  `.luacheckrc` gives them busted's globals.
