# State Management and Architecture Patterns

## Context Filter Propagation
**Problem**: BAG_UPDATE events don't carry context about which tab is currently active, causing wrong items to display.
**Solution**: Store filter state in context objects that propagate through event chains. At event entry points, determine the correct filter based on current state. Check for an existing filter before defaulting. Handle account bank vs character bank with explicit checks:
```lua
local existingFilter = ctx:Get('filterBagID')
if existingFilter ~= nil then
  refreshCtx:Set('filterBagID', existingFilter)
elseif currentTab >= accountBankStart then
  refreshCtx:Set('filterBagID', nil)    -- account bank: show all
else
  refreshCtx:Set('filterBagID', currentTab)  -- character bank: filter to bag
end
```

## Always Use Behavior Methods for Programmatic Tab/View Switching
**Problem**: Calling visual-only methods like `tabs:SetTabByID()` highlights the tab button but doesn't update bag contents. This is the wrong layer.
**Why the split exists**:
- **Visual methods** (`SetTabByID`, `SelectTab`): Only update button appearance
- **Behavior methods** (`SwitchToGroup`, `SwitchToCharacterBankTab`, etc.): Full state management — update state vars, set context filters, clear caches, call `BankPanel:SetBankType()`, send refresh events, call `ItemButtonUtil.TriggerEvent()`, then finally call visual methods

**Solution**: Always dispatch to the behavior layer:
- Backpack: `bag.behavior:SwitchToGroup(ctx, tabID)`
- Bank (single tab): `bag.behavior:SwitchToBank(ctx)`
- Bank (char tab): `bag.behavior:SwitchToCharacterBankTab(ctx, tabID)` (tabID 6–11)
- Bank (account tab): `bag.behavior:SwitchToAccountBank(ctx, tabID)` (tabID 13–17)

**Diagnostic**: Tab highlights ✅ but bag contents don't update ❌ → calling visual instead of behavior method.
**Related Files**: `bags/backpack.lua:342-356`, `bags/bank.lua:590-667`, `integrations/quickfind.lua:137-170`

## WoW Bank System Architecture
- **Character Bank**: BagIndex 6–11 (`CharacterBankTab_1` to `CharacterBankTab_6`)
- **Account Bank**: BagIndex 13–17 (`AccountBankTab_1` to `AccountBankTab_5`)
- **Reagent Bank**: `BagIndex.Reagentbank`
- Right-click item destination is determined by `BankPanel:GetActiveBankType()`
- Always use `BankPanel:SetBankType(Enum.BankType.Character/Account)` — never assign directly to `BankPanel.bankType` (direct assignment taints BankPanel and causes `ADDON_ACTION_FORBIDDEN`)
- Account bank tabs show aggregate items; character bank tabs each correspond to one bag

## Use View-Level Flags to Bridge Context Boundary Gaps
**Problem**: Operations that must fire after a full view rebuild fail because `refresh:ExecutePendingUpdates` creates a fresh context that doesn't carry flags from the triggering context (classic example: sections not sorted after opening bank or switching tabs).

**Why**: `SwitchToGroup()` calls `bag:Wipe(ctx)` where `ctx` has `wipe=true`, then sends `bags/RefreshBank`. The refresh handler calls `refresh:RequestUpdate()` which eventually calls `context:New('BagUpdate')` — a brand-new context without `wipe=true`.

**Solution**: Set a flag on the long-lived **view object** (not the short-lived context):
```lua
-- In Wipe(): set the flag so it survives context boundaries
view.sortRequired = true

-- In GridView(): check either source
if ctx:GetBool('wipe') or view.sortRequired then
  view.sortRequired = false  -- clear before acting
  view.content:Sort(sort:GetSectionSortFunction(bag.kind, const.BAG_VIEW.SECTION_GRID))
end

-- In constructor: initialize
view.sortRequired = false
```
**Related Files**: `views/gridview.lua`, `bags/bank.lua:489-518`, `data/refresh.lua:112-152`

## First-Time Lazy Initialization of Tab Views
**Problem**: Lazily-created tab views (such as custom groups/tabs selected for the first time) show up blank on click after reload/logging in because the initial changeset (containing all added items) has already been consumed by the primary backpack view. Subsequent clicks on custom tabs receive an empty delta changeset (`GetChangeset()` returns `{}`, `{}`, `{}`).

**Solution**: Introduce a view-level `isNew` flag initialized to `true` upon view creation. On the view's first-render, if `isNew` is `true`, bypass the empty delta changeset, wipe the view, reset `isNew = false`, and perform a full draw by populating `added` with all non-empty items from `slotInfo:GetCurrentItems()`. This handles first-time lazy draws of tab views flawlessly while preserving subsequent high-performance delta changesets.

**Related Files**: `views/views.lua`, `views/bagview.lua`, `views/gridview.lua`, `spec/views/persistent_tabs_spec.lua`

## Code Organization
- **core/init.lua**: One-time setup, frame hiding/showing, Blizzard integration
- **frames/bag.lua**: UI state management, tab switching, visual updates
- **data/items.lua**: Item queries and filtering based on state
- **data/refresh.lua**: Event handling and context management

## Feature Parity Across Game Versions
**Problem**: Bug fixes or features applied only to retail code break in Classic Era (`frames/era/`) or Classic (`frames/classic/`).

**Rule**: When touching `frames/*.lua`, check if `frames/era/*.lua` and `frames/classic/*.lua` need the same change. When adding module imports, verify all three versions have them. Note which versions were updated in commit messages.

## Defensive Programming: Validate Function Parameters from Saved Variables
**Problem**: External addons can corrupt saved variables. A sort preference key that maps to `nil` or a non-function value causes `table.sort()` to crash.
**Solution**: Guard at the call site and provide safe defaults in functions that derive callbacks from saved variables:
```lua
function gridProto:Sort(fn)
  if type(fn) ~= "function" then
    fn = function() return false end
  end
  table.sort(self.cells, fn)
end
```

## WipeSlotInfo / SendMessageLater Race: Stale SlotInfo in Deferred Draws
**Problem**: `items:GetItemDataFromSlotKey(slotkey)` returns nil for slotkeys that were valid at time of refresh but are gone by the time the deferred draw fires. Error: `"data must be provided"` in `SetItemFromData`.

**Root cause**: `events:SendMessageLater` defers the draw by one frame (`C_Timer.After(0, ...)`). If `items:WipeSlotInfo(kind)` fires during that frame (replacing the SlotInfo object and resetting `itemsBySlotKey`), slotkeys from the now-orphaned previous changeset are no longer in `items.slotInfo[kind].itemsBySlotKey`.

**Why it happens**: The refresh pipeline is:
1. `LoadBagItems` → `ContinuableContainer:ContinueOnLoad` (async)
2. Callback → `LoadItems` → `slotInfo:Update` (builds changeset) → `SendMessageLater`
3. `C_Timer.After(0)` fires → Draw → `SetItem` → `GetItemDataFromSlotKey`

Between steps 2 and 3, a new `BAG_UPDATE_DELAYED` or `wipe=true` refresh can fire `WipeSlotInfo`, replacing `items.slotInfo[kind]` with a brand-new empty object. The draw then looks up stale slotkeys in the new (empty or different) `itemsBySlotKey`.

**Solution**: Nil-guard all direct lookups via `GetItemDataFromSlotKey` before dereferencing the result:
```lua
-- In SetItem (frames/item.lua):
local data = items:GetItemDataFromSlotKey(slotkey)
if not data then
  debug:Log("SetItem", "No item data for slotkey", slotkey, "- skipping stale draw")
  return
end

-- In CreateButton (views/gridview.lua):
local item = items:GetItemDataFromSlotKey(slotkey)
if not item then return false end

-- In ClearButton (views/gridview.lua):
if item then addon:GetBagFromBagID(item.bagid).drawOnClose = true end

-- In ReconcileWithPartial (views/gridview.lua):
local rootItem = items:GetItemDataFromSlotKey(stackInfo.rootItem)
if not rootItem then return end
-- ... and for child items:
if childData and childData.itemInfo.currentItemCount ~= ... then
```

**Key files**: `frames/item.lua:323-333`, `views/gridview.lua:75-91`, `views/gridview.lua:99-120`, `views/gridview.lua:175-210`

## Coroutine Pipelines: Capture Client State, Then Yield, Then Read Committed State
**Problem**: `items:ProcessRefresh` runs inside `async:Do` and yields once (the resume comes back through `C_Timer.After(0)` on the next frame). With the yield placed right before the commit, two refreshes started in the same frame both read the *same* committed `previousItems` before either committed. A wipe refresh followed in the same frame by a `BAG_UPDATE_DELAYED` targeted sweep ended with the targeted sweep committing last — merged against the wiped (empty) previous state — so every bag it did not target vanished until the next update.

**Rule**: The only frame boundary in the pipeline sits immediately after `Phase2_Harvest`. The harvest must read the client in the frame the event fired, but everything that reads committed addon state (`Phase3_ExtractPreviousState`, the targeted merge, categories, sorting, partition, commit) runs after the yield, so refreshes resume in queue order and each one merges against whatever the previous one just committed. Never move `async:Yield()` below the merge again.

**Test**: `spec/refresh_pipeline_spec.lua` ("does not lose untouched bags when a wipe refresh and a targeted refresh start in the same frame") uses a real `coroutine.yield` and a queued `C_Timer.After` mock to replay the two-frame sequence.

## Data Phases Must Operate On The Data They Were Handed, Not On Committed State
**Problem**: `Phase4_ClearMovedItemGlows` detected a moved item (same GUID added in one slot and removed from another) but then called `items:ClearNewItem(ctx, slotkey)`, which looks the slot key up in the *committed* `SlotInfo` — i.e. the previous occupant of the destination slot, or nothing at all. The moved item's GUID timer was never cleared and it stayed in "Recent Items".

**Rule**: Phase functions receive the transient `itemData` / `previousItems` tables as arguments; anything they mutate must be reached through those arguments (`items:ClearNewItemFromData(ctx, addedItem)`), never through `GetItemDataFromSlotKey`, which only reflects the last commit.

## Decide From the Committed Read; Ask the Client Only When Acting
**Problem**: Category automation listed the committed items but asked the client, per item,
`C_Item.CanBeRefunded` about its slot. Between a slot changing in the client and BetterBags reading it
again (after `BAG_UPDATE_DELAYED`, committed frames later), the committed items name slots the client
has emptied; BetterBags Next's vendor drew in that window (`PLAYER_MONEY`, `BAG_UPDATE_DELAYED`) and
the call raised on every empty slot (58 errors in game). Two moments mixed in one decision.

**Rule**: Anything that decides from the committed items reads only the items: a client property it
needs is read with the slot, in the harvest (and refreshed on kept items), as every location property
is. The client is asked only at the moment of acting, after `C_Container.GetContainerItemInfo` shows
the slot still holds the item (its GUID), because location functions documented with an `ItemLocation`
argument (not an `EmptiableItemLocation`) raise an error for an empty slot. Mocks raise it too.

**Seen since**: `C_Item.GetItemGUID` is documented with an `ItemLocation` argument as well, and
`items:Phase2_Rederive` asked it about every committed item's slot. It raised in game for a slot a sale
had emptied (next section).

## Know Which Committed Bags the Client Has Changed
**Problem**: A recalculation (`derive`) works from the committed items and refreshes a few fields of each
from the client. The read a client change leads to comes late: `BAG_UPDATE`'s read waits for the bag's
item data, then for its turn in the queue, where it never rides on a waiting recalculation. A
recalculation that ran first asked `GetItemGUID` about a slot the player had just emptied, which raises
("bad argument #1 to 'GetItemGUID'", reported twice in game).

**Rule**: The data layer records which bags the client changed after their last committed read
(`items:MarkBagUnread`, set from the same events that lead to reads; cleared by a committed read for the
changes before its harvest). A recalculation leaves such a bag's items exactly as committed and asks
the client nothing about them; their read is on its way. Never answer this with a check in front of the
client call: the committed items of that bag are known to be stale, and nothing else about them should
be refreshed either. Never read the bag in the recalculation instead: its item data may not have loaded
(data-loader.md §19).

## Dual-Bank Tab Routing (Retail Character Bank vs Warbank)
**Problem**: In Retail, Character Bank (`bankType = Character`) and Account Bank (`bankType = Account`) share `const.BAG_KIND.BANK`. If `categoryToGroup[BANK]` is stored as a flat dictionary, assigning a category to a Warbank tab overwrites the Character Bank assignment. `ItemBelongsToTab` strictly filters items by `itemIsAccountBank == tabIsAccountBank`, so Character Bank items of that category cannot show in the Warbank tab, cannot show in any Character Bank tab (since `assignedGroup` points to the Warbank tab), and are rejected by default Tab 1 (which only accepts unassigned categories). The items completely vanish from all bank tabs.

**Solution**:
1. Partition `categoryToGroup[const.BAG_KIND.BANK]` by `bankType` on Retail (`[Enum.BankType.Character]` and `[Enum.BankType.Account]`).
2. Pass `bankType` during category assignment, removal, and lookup.
3. In `ItemBelongsToTab`, derive `itemBankType` from `itemIsAccountBank` and pass it to `CategoryBelongsToGroup`.
4. If a category is not assigned in that item's `bankType`, it safely falls back to the default tab of that bank type (Tab 1 for Character Bank, Tab 2 for Warbank).
5. Non-retail clients (`not addon.isRetail`) maintain the single flat dictionary without bankType scoping because Warbank and `Enum.BankType` do not exist.

## High-Frequency Game Events: Filter at the Door, Batch in Windows
Events like `TOOLTIP_DATA_UPDATE` (every tooltip in the game) and `BAG_UPDATE_COOLDOWN` (spell casts) can fire many times per second. Handle them with `events:BucketEvent(event, callback, filter)` and give it a filter that rejects every fire you don't care about (an id you didn't record, a hidden bag) before anything is allocated or scheduled. Never debounce a stream that can be continuous (it never flushes) and never build a Context or argument table per fire. Contract: `.claude/rules/event-buckets.md`.

## Don't Sweep Before a Server-Side Change; Mark It Pending and Guarantee a Later Sweep
A sort (and anything else whose effect arrives later as `BAG_UPDATE`s) should not sweep in its own unit: that sweep redraws the old contents and is thrown away a moment later. Instead mark the kind pending in Items (`items:MarkSortSweepPending`), let the next committed sweep of that kind carry the extra work (full re-read, layout reset) and clear the mark only after `Phase11` commits, and arm a fallback timer that requests the sweep if nothing else did (a sort that moves nothing fires no event at all). Set the mark and the fallback before any call that can fail, and have the fallback's unit re-check the mark when it runs so a queued event refresh is never repeated. Contract: `.claude/rules/refresh-scheduler.md` §6.

## Keep Per-Sweep Work Linear in Item Count
Any per-item cost that grows with string length or item count is paid for every item the sweep touches. The tooltip prefix n-grams (quadratic in tooltip length) were the dominant cost of every sweep until the tooltip index became full-text only (`.claude/rules/search-indexing.md` §2a).

## Incremental Work Without Drift: Record What Was Applied, Diff Against It
A sweep that changed one slot should cost one slot, but every past attempt at incremental updates (v0.4.x search `Add`/`Remove`, changeset-gated views) drifted, because it removed or compared using the item's *current* values, and ItemData objects are reused and mutated in place across sweeps. The pattern that holds:
- **Record a snapshot of exactly what was applied**, separate from the data object: the search index stores per-slot snapshots (`fillSnapshot`), item buttons store their last full draw's inputs (`drawState`), the harvest compares against the raw container values the item was read from (`rawItemName`...).
- **Diff a fresh snapshot against the record** to decide whether to redo the work, and **undo with the recorded values**, never the current ones.
- **Keep one definition of the snapshot** that both the apply and the compare use, so a new field cannot be applied without being compared.
- **Fall back to a full rebuild on wipes**, which are also how settings changes propagate (draw generation).
- **Gate it with an equivalence test** against the clean rebuild over randomized sequences (`spec/search_spec.lua` "matches a clean rebuild"), plus a mutation check that each guard is load-bearing.
- **Keep per-item work with the item, stamped with its inputs** (`item.derived`, `.claude/rules/data-loader.md` §18): an input of the item's own (its slot read, tooltip, quest, sets) drops the record; an input every item shares (settings, category definitions, the open window) is a generation or signature in the stamp, so changing it costs one comparison per item. An input nobody can see change (Blizzard's grey-out while a spell targets) gets no stamp: work it out every time. When the equivalence reference reuses the same objects, it must also clear any per-sweep field the work reads (`stackRecent`), or a stale field fools both sides.
- **Marks that must survive a failed sweep live on the item**, not in a per-sweep table: `indexPending` stays set until the index has the item, so a sweep that fails between working an item out and indexing it does not lose the index update.

## A Derived Value Must Not Feed Its Own Derivation
When a value is derived from an index, and the derived value is written back into that index, the next derivation sees its own previous answer as input. Search categories were matched against an index holding each item's category, and that category could be the search category itself, carried over by bag slot: an item that once got the category (rightly, or by landing in another item's slot) matched the query through the category's own name and never left (`.claude/rules/data-loader.md` §8, "Lucky Items"). Derive from inputs only (the item's own category), then publish the result for readers that want it (the search box). The same applies to any state keyed by location rather than identity: a slot's last answer belongs to the item that was there, not the one there now.

## A Content Hash Is Not an Identity
`itemHash` answers "are these two items interchangeable" (stacking), not "is this the same item". Its inputs include values the client reports differently before and after it has an item's data (item level, bind type, stats), and values that change on a live item (enchants, upgrades, scaling). Any diff that matches by hash alone treats those as a departure plus an arrival: the persistent-gap diff left holes all over the bag at login this way (`.claude/rules/data-loader.md` §13). When a diff must follow the same item, pair by content first and then fall back to instance identity (the item GUID, same slot), keeping any boundary the hash encodes on purpose (the Warbank scope) out of the fallback.

## Built-In Category Names Exist Only While Items Are Read
Settings keyed by a category name (`customSectionSort`, `categoryOptions`, `categoryToGroup`) cover built-in categories too, whose names `items:GetCategory` computes from item data and stores nowhere. At load, before any item is read, a built-in name is indistinguishable from a deleted category's leftover, so no migration may drop a setting because its name has no stored filter: one that did removed every built-in pin at each login (#1107, `.claude/rules/category-lifecycle.md` §3). Prevent leftovers where they are created (delete scrubs every side table) and give the user a way to remove one, instead of guessing at load. When `GetCategory` changes how it names categories, move the settings to the new names in a migration (category-lifecycle.md §5).

## Hold a Kind's Sweeps Behind a Read That Is Guaranteed to Follow
To keep heavy work out of an animation (the bank's read during its window's show, refresh-scheduler.md §11), do not queue, delay or merge the requests made meanwhile: skip that kind's part of every sweep while held, and make sure one full read of the kind follows (every bag, fresh layout). Each skipped sweep would have read the client earlier than that read does, so skipping loses nothing; pending marks (a sort's) stay set for the read to clear. The guarantee is what makes it safe, so it needs three exits: the event that ends the hold (the window says it has shown), a timeout for when that never comes (Escape hides the window mid-animation), and the end of the reason to read at all (the bank closed), each checked against a token for the current open so a stale callback does nothing. Other kinds are not held.

## Spec Files Must Pass Alone and Shuffled
The suite runs every spec file in one Lua state, so a file can pass only because an earlier one left something behind: a stub module with the methods it needs, a real module the earlier file loaded, or a copy of a module loaded with the earlier file's stubs captured in its file-scope locals (`LoadBetterBagsModule` loads a path once per state). Check a new or changed spec file with `~/.local/lua51/bin/busted <file>` and `busted --shuffle --seed=N <file>`, not only in the suite's order. The rules that keep a file independent:
- Create stubs with `StubBetterBagsModule` and remove the ones the file created (the `created` flag) when it ends; never `x.Method = x.Method or default` on a module another file may have loaded for real (its method then runs against data this file never set up): replace it and put the original back.
- Load the module under test fresh (`LoadFreshBetterBagsModule`) when it captures other modules at file scope, and remove it after (`spec/frames/item_spec.lua`).
- Put file-wide restores in a file-level `teardown`, not in one `describe` block's: `--shuffle` reorders blocks, so that block's teardown can run first and undo the stubs every other block needs.
- Revert a `stub(obj, "Method")` with `finally(function() obj.Method:revert() end)`; it otherwise stays for the rest of the file.
- Reset shared engines before re-registering into them: the specs call `Sonata:Init()` before loading the theme files, as the addon's own load order does (`.claude/rules/sonata.md` §2: a theme registering after one was applied reads the saved theme).
- A test that only checks scheduling should stub the scheduled work rather than run it, so it does not depend on what that work touches.
Measured state and the remaining known failures: `docs/roadmap.md`, "Spec isolation".

## Debugging Strategies
1. **Trace the call chain**: End symptom → query function → filter variable → where filter is set → events → switch point
2. **Check Blizzard source first**: `.libraries/wow-ui-source/` for actual Blizzard implementation before writing hooks or workarounds
3. **Profile, don't guess**: in game, capture with the `/bbdb` Performance tab (or arm "Capture next reload" for login) and read the flame graph, the worst frames, and how far Blizzard's addon-profiler number sits above ours. Offline, run the real pipeline under `perf:Start` over the `test.lua` dump the way the "profiles the real refresh pipeline" test of `spec/debug_dump_harness_spec.lua` does (fill empty slots and inject realistic `tooltipText` to approximate a full bag) and export it with `tools/flamegraph`. Hand-wrapping `items:Phase*` with `os.clock()` timers is how the tooltip n-gram cost was found; the profiler does that wrapping for every module. A "no events fired on that frame" hitch report points at the timer-resumed second half of a refresh (`data/refresh.lua` `_Arm`), which the flame graph shows under `Refresh._Step` -> `Refresh._Resume`. Contract: `.claude/rules/perf-profiler.md`.
4. **Order bugs need the call trace, not the call tree**: when a symptom depends on which of two things ran first (a single-bag refresh committing before the all-bags one at login, a wipe landing under a parked sweep), the flame graph cannot show it, because it sums every call of a path into one node. Capture with the call trace on (the default) and read the Calls view in order: Find the entry point (`RequestUpdate`, `[event] BAG_UPDATE`) to see each request and its arguments, Find the phase that decides scope (`Phase1_DetermineBags`, whose return value is the bag list) and the effect (`MarkItemAsNew`). Arguments are copied when the call is made, so a mutated request or ItemData shows what it held then. For a user's machine, have them arm "Capture next reload", relaunch, and send `SavedVariables/BetterBags.lua`; `tools/flamegraph --trace --find <text>` turns it into a Perfetto file.

## A Spec That Replaces a Shared Module's Method Must Put It Back
**Problem**: `StubBetterBagsModule` returns the real module when one is loaded. A spec block that set
`events.RegisterEvent` to a capture and never restored it left every later spec's event registrations going
nowhere: `spec/targeted_sweep_spec.lua` and `spec/window/window_spec.lua` failed only in the full run.

**Rule**: Save what a spec replaces (`rawget`) and restore it in `after_each`, or use the spec's `override`
helper where it has one. When a spec passes alone and fails in the full run, look for a method replaced on a
shared module by an earlier file.

## A Theme's Spec Inherits the Keys It Leaves Out
**Problem**: Sonata and SonataNext resolve a theme by merging it with its parent key by key (only lists replace).
A theme that draws art where its parent draws a faint color (`{ Texture = "Button", Color = "White" }` over Default's
`{ Color = "Gold", Alpha = 0.14 }`) also gets the parent's `Alpha`: Guild Wars 2's cream buttons drew at 14%.

**Rule**: A spec that replaces the look of a parent's spec sets every key the parent sets that would change it
(`Alpha` above all), and a spec over every shipped theme compares what a theme sets with what it resolves to
(`spec/sonata/next_themes_spec.lua`, "draws the art each theme sets at the alpha it sets"). `false` removes an
inherited table entirely (it resolves to nil).

