# Serialized Refresh Scheduler

This document defines the architecture, rationale, and API contracts for how BetterBags
serializes every bag refresh through a single frame-stepped queue in `data/refresh.lua`.

## 1. The Rationale: Why Serialize?

Historically each refresh request ran its data sweep as its own `async:Do` coroutine, and
`refresh:RequestUpdate` performed its side effects (`items:ClearItemCache`,
`items:ClearNewItems`, the protected `C_Container.Sort*` calls) **synchronously at request
time**, before the coroutine even started. Because a sweep yields once (after
`Phase2_Harvest`) and resumes on a later frame via `C_Timer.After(0)`, multiple sweeps were
routinely in flight at the same time, and their resume callbacks landed in an order WoW
does not define.

This produced a whole class of data races. The concrete one that motivated this design:
opening the bank fires **two** refreshes in the same burst — a non-wipe backpack refresh
from the bank tab switch (`bank.proto:SwitchToGroup` → `bags/RefreshBackpack`, see
item-drawing.md §8) and a `bags/FullRefreshAll` wipe from the banker interaction
(`core/hooks.lua` `addon.OnUpdate`, fired because the interaction re-shows the backpack
while `addon.atInteracting` is true). The wipe's synchronous `ClearItemCache` emptied the
committed `slotInfo` **while the switch refresh was parked at its yield**, so when the
switch refresh resumed, `Phase3_ExtractPreviousState` read an empty `previousItems` even
though its own `ctx` never carried `wipe`. `MarkAddedItemsRecent` then treated every item's
GUID as newly acquired and flooded the whole backpack into Recent Items (a manual Sort
cleared it). See data-loader.md §12 for the acquisition rule that got mis-triggered.

Patching that one symptom is whack-a-mole; the fix is to remove the concurrency.

## 2. The Solution: One Unit at a Time, One Frame Apart

`data/refresh.lua` owns a single FIFO queue and a single frame clock. Exactly one
request-unit is ever in flight, and a deliberate **idle hand-off frame** separates
consecutive units so a unit's commit+draw can never share a frame with the next unit's
harvest.

- **`RequestUpdate(request)` is enqueue-only.** It merges the request into the last request
  still waiting in `self._queue` when that one covers it (§7), else appends it, and, if the
  pump is not already running and not held for the startup read (§8), flips
  `self._running = true` and calls `_Step()` once. It performs **no** side effects itself.
- **`_Step()` is one frame of the pump.** In priority order it: (a) advances the active
  unit's coroutine one step (`_Resume`) if one exists; else (b) burns the idle hand-off
  frame if `_idlePending`; else (c) dequeues and starts the next unit; else (d) stops the
  clock (`self._running = false`) when the queue is empty or held. After (a), (b), and (c)
  it calls `_Arm()` to schedule the next step.
- **`_Arm()` is the ONLY clock that steps the pump.** A single `C_Timer.After(0)` chain,
  never one-per-refresh, so step ordering is fully deterministic. The sort fallback timer
  (§6) and the startup timers (§8) are the other timers in the refresh path; they never step
  the pump, they only request or release work.
- **`_Resume()`** resumes the active coroutine; when it finishes it sets `_idlePending = true`
  (arming the hand-off frame). A unit that errors is dropped and reported via
  `geterrorhandler()` — one bad sweep must not wedge the queue.
- **`_RunUnit(request)`** is the body that used to be `RequestUpdate`, now running inside the
  pump's coroutine: request-time mutations and sort calls first (`ClearItemCache` for
  `wipe`; for sorts, the sort-sweep mark, the fallback timer, `ClearNewItems`, and the
  protected `C_Container.Sort*` calls, gated on `not InCombatLockdown()`; the bankTab
  adjust), then the bank sweep, then the backpack sweep. Because this is the only sweep in
  flight, those mutations run with nothing parked to corrupt.

### Frame cadence

```
Frame 1 : (synchronous, scheduler idle) dequeue U1, run to its yield -> harvest, park
Frame 2 : resume U1 -> commit + draw (draw is synchronous), unit done
Frame 3 : idle hand-off frame (nothing runs)
Frame 4 : dequeue U2, run to its yield -> harvest, park
...
```

The first step runs **synchronously inside the `RequestUpdate` call** when the scheduler is
idle (frame 1 = enqueue + execute); this is safe because it matches the old behavior for the
first sweep and, being synchronous, cannot be re-entered — a `RequestUpdate` triggered while
a unit is running finds `self._running == true` and only enqueues. Every subsequent step is
handed to the next frame by `_Arm`.

## 3. Design Decisions (explicit)

- **Refresh-scoped, not a general event bus.** The scheduler serializes refresh requests
  only. The existing `async` primitives (`Do`, `Each`, `Batch`, …) are unchanged and still
  used elsewhere.
- **Idle frame between every unit.** Always, unconditionally. 3-frame bursts are acceptable;
  predictability beats shaving a frame.
- **Merging, not coalescing by time.** A request merges only into a request that is still
  waiting and already covers it (§7); nothing is delayed or debounced to make merges happen.
  This replaced the original "no coalescing" rule after a captured login showed 25 queued
  units, 17 of them identical full wipes, run back to back for 1.6 s. The merge rule is
  tested to leave the bags exactly as running the requests one at a time would.
- **Whole request = one unit.** A request carrying both `bank` and `backpack` runs both
  sweeps sequentially inside the same unit coroutine (bank first, then backpack), in the
  order wipe → sort calls → bank → backpack.

## 4. API Contracts

- `items:RunRefresh(ectx, kind)` — the inline data sweep for one bag kind (Phase1..Phase11,
  yields once after harvest). **Must be driven from within a coroutine.** The scheduler calls
  it directly so bank and backpack share one coroutine; `items:ProcessRefresh(ctx, kind)`
  remains a thin `async:Do(ctx, function(e) self:RunRefresh(e, kind) end)` wrapper for direct
  callers and unit tests. `RefreshBackpack`/`RefreshBank` still wrap `ProcessRefresh`.
- `refresh:RequestUpdate(request)` — enqueue only; never call `items:Refresh*` directly from
  production code, always go through `RequestUpdate` so serialization holds.
- Scheduler state (`refresh._queue`, `_active`, `_idlePending`, `_running`, `_held`,
  `_startup`) is initialized in `refresh:Init()` and reset there; tests re-init per case.
  `refresh:OnEnable()` holds the queue for the startup read (§8); tests that call it and then
  expect sweeps open the hold through the startup events, or assert on the requests made.
- `RefreshRequest.derive` recalculates the named kinds from their committed items without
  reading a bag slot, and `RefreshRequest.restyle` makes every button of the swept kinds draw
  in full (§10). Production code asks for them with `bags/Rederive`.
- `RefreshRequest.merged` (how many requests a merged one carries) and
  `RefreshRequest.startup` (why the startup read ran: `primed`, `timeout` or `bagShown`) are
  only informational; they show up in profiler call traces as `Refresh._RunUnit`'s argument.
- `RefreshRequest.onlyIfSortPending` — set only by the sort fallback (§6). The unit drops each
  requested kind whose sort sweep is no longer pending (`items:IsSortSweepPending`) before
  doing anything else. This is not coalescing: the request literally means "sweep this kind
  if its sort has not been shown yet".

## 5. Testing Contract

- **Unit-level data tests** call `items:RefreshBackpack`/`ProcessRefresh` directly with
  `async.Yield` stubbed to a no-op, so a sweep completes synchronously and `slotInfo` is
  readable immediately. These bypass the scheduler on purpose.
- **Scheduler tests** (`spec/refresh_pipeline_spec.lua`, "refresh scheduler (serialized
  queue)") install the real `coroutine.yield` and a captured, hand-cranked `C_Timer.After`
  clock; an `advance()` helper runs exactly the tick(s) pending for one frame, so the
  one-at-a-time cadence, the idle hand-off frame, and the frame-1-synchronous start are all
  asserted deterministically. The bank-open-burst test reproduces the Recent Items flood and
  proves the queue prevents it.
- **Specs that drive `refresh:RequestUpdate` and read committed results synchronously**
  (`spec/refresh_spec.lua`, `spec/targeted_sweep_spec.lua`) install a synchronous
  `C_Timer.After` (`function(_, fn) fn() end`) so a unit drains fully within the
  `RequestUpdate` call, and assert against `items:RunRefresh` (the entry the scheduler drives),
  not the `RefreshBackpack`/`RefreshBank` wrappers.
- **Sort specs** (`spec/refresh_spec.lua` "Sort Handling and Recent Items Clearing" with a
  clock that runs delay-0 frames at once and holds delayed timers for the test to fire;
  `spec/refresh_pipeline_spec.lua` "sorting (one sweep per sort)" on the real pipeline and
  queue) cover: a sort that moves items is shown by the moves' refresh alone; a sort that
  moves nothing is shown by the fallback; the fallback racing a queued moves refresh sweeps
  once; a failed sweep leaves the sort pending for the fallback; combat sweeps at once; the
  bank path. Each safety mechanism (the run-time re-check, the forced full re-read, clearing
  the mark only after commit, arming the fallback) was mutation-tested: removing any one
  fails at least one of these specs.

## 6. Sorting: One Sweep Per Sort

A sort used to run a full sweep in its own unit and then call `C_Container.SortBags()`.
That sweep only redrew the pre-sort contents (the moves happen server-side, afterwards), and
the moves' `BAG_UPDATE` then triggered a second full sweep. A profiled sort on WoW: Forever
spent about 31 ms of real time in the first, wasted sweep.

Now, in `_RunUnit`, for each sorted kind (`sort` -> backpack; `sortBank`/`sortWarbank` ->
bank):

1. `items:MarkSortSweepPending(kind)`. The next committed sweep of that kind shows the sort:
   `items:RunRefresh` re-reads **every** bag of the kind (it deletes `targetedBags`, because
   the sort may have moved items anywhere and the new-item glow is a harvest-time field on
   every bag, so a sweep of only the bags a `BAG_UPDATE` named would leave stale glows) and
   rebuilds the layout (`resetLayout`). The mark is cleared only after `Phase11` commits, so
   a sweep that fails leaves it set.
2. If the client can sort now (out of combat and the sort API exists), the sort is issued in
   this unit and the kind is **not** swept here. Otherwise (combat, no API) the kind is swept
   in this unit, which consumes the mark, exactly as an unsorted refresh.
3. When anything was issued, `_ArmSortFallback` schedules a `C_Timer.After(SORT_FALLBACK_SECONDS)`
   (0.5 s). When it fires it requests `{ onlyIfSortPending = true }` for the kinds still
   pending. This covers a sort that moves nothing (already sorted, or refused), which fires
   no `BAG_UPDATE` at all; WoW has no "sort finished" event (`ContainerDocumentation.lua`,
   and Blizzard's own sort button just calls `SortBags()`).
4. The mark and the fallback are set **before** `ClearNewItems` and the sort calls, so an
   error in either still leaves a refresh guaranteed.
5. A request that also names the sorted kind explicitly (`backpack`, `bank`, or `wipe`) still
   sweeps it in the unit, right after the sort call and before any item has moved. That
   sweep consumes the mark, so the layout reset lands on the pre-move sweep and the moves'
   refresh is an ordinary one. No caller sends such a combination (`bags/SortBackpack`,
   `bags/SortBank`, `bags/SortWarbank` send only sort flags); it is kept because it can only
   add a sweep, never remove one.

Why no refresh can be missed: every real item change still produces its own `BAG_UPDATE`
refresh, exactly as before; the change only removes the sort unit's own sweep, and the
effects that sweep had (recent items cleared, layout reset, all bags re-read) are delivered
by the first later sweep of that kind, which the fallback guarantees within 0.5 s. A bank
sort whose bank closes first stays pending until the next bank sweep (bank open), the same
gating the old in-unit bank sweep had.

Trade-off: a sort that moves nothing now shows its cleared Recent Items 0.5 s after the
click instead of at once. A sort whose moves arrive later than 0.5 s (high latency) gets the
fallback sweep and then the moves' sweep, which is the old cost.

## 7. Merging Waiting Requests

`RequestUpdate` merges an incoming request into the last request in the queue (always a
waiting one: the running unit's request is removed from the queue when it starts) when
`canMerge(waiting, incoming)` holds, and `mergeInto` folds it in:

- **Why it is safe.** A waiting request reads the client when it runs, which is after the
  incoming request was made, so it sees everything the incoming request is about. Run
  separately, the incoming request would read the same state again and find nothing new.
- **A wipe covers anything.** A waiting wipe absorbs any later non-sort request.
- **A plain request never absorbs a wipe.** A wipe behind a waiting plain request stays
  separate: the plain request's check for newly acquired items (`MarkAddedItemsRecent`,
  which wipes skip) must run against the state before the wipe. Upgrading it to a wipe would
  drop an item looted in between from Recent Items.
- **Layout resets.** `resetLayout` applies to every kind a request names, so a reset merges
  only into a waiting wipe (which resets every layout); otherwise requests merge only when
  both reset or neither does. Merging a bank-open reset into a waiting backpack request
  would have collapsed the backpack's gaps.
- **Kinds and bags.** The merged request sweeps both requests' kinds and reads the bags
  either named; if either named none, it reads every bag. The callers' `bags` tables are
  copied, never changed (the loader passes its own set).
- **Sorts and the sort fallback never merge**, in either direction: they are ordered
  against the sweeps around them (§6).
- `merged` counts the requests a merged request carries, for profiler traces.

Coverage: `spec/refresh_pipeline_spec.lua` ("one bag read on login" → "merging waiting
requests"): a waiting wipe absorbs later requests; plain requests merge and read the union of
their bags; an untargeted request makes the merge untargeted; caller tables are untouched; a
wipe behind a plain request stays separate; sorts and the fallback never merge; layout
resets; and two equivalence tests (plain then wipe, wipe then plain, with a loot landing
while they wait) that compare the committed bags and Recent Items timers with running the
same requests one at a time.

## 8. The Startup Read: One Read of the Bags at Login

At PLAYER_LOGIN, when `refresh:OnEnable()` runs, the client has not delivered the bags. A
captured cold login (game build 12.1.0) showed it: the login sweep inside `OnEnable`
read a backpack of 20 empty slots and no other bag; the bags then attached
(`BAG_CONTAINER_UPDATE` x14) and their contents arrived (`BAG_UPDATE` bursts) over the next
five seconds, through the loading screen and one frame past it. Every step requested
another sweep, and the queue ran 25 units (17 full wipes, 728 ms of sweeps) after the
loading screen. The empty first commit is also a Recent Items hazard: a plain sweep that
lands between it and the next full read treats every item delivered in between as newly
looted.

`refresh:HoldForStartup()` (called at the end of `OnEnable`) holds the queue
(`self._held`) and the loader (`itemLoader:Hold()`, so bag batches only mark bags dirty)
and listens on its own frame (`self._startupFrame`) to `PLAYER_ENTERING_WORLD`,
`LOADING_SCREEN_DISABLED`, `BAG_UPDATE` and `BAG_CONTAINER_UPDATE`. Requests made meanwhile
wait (and merge). Then:

1. **Loading** until `LOADING_SCREEN_DISABLED` (verified in the API documentation of every
   client branch: live, classic, classic_era, classic_anniversary, classic_beta,
   classic_titan). On a client without it, `PLAYER_ENTERING_WORLD` starts the next phase;
   with it, `PLAYER_ENTERING_WORLD` arms `STARTUP_LOADING_TIMEOUT` (10 s) as a safety net.
2. **Settling**: the frame's `OnUpdate` waits for the first frame in which no bag event
   fired (frames do not run during the loading screen). After `STARTUP_SETTLE_TIMEOUT`
   (2 s) of bag events it stops waiting. In the capture, the client still sent a burst of
   92 `BAG_UPDATE`s one frame after the loading screen; the next frame was quiet.
3. **Priming**: `itemLoader:PrimeAll(callback)` loads the item data of every managed bag
   slot and every equipped slot in one `ContinuableContainer`; when it completes, the read
   runs. After `STARTUP_PRIME_TIMEOUT` (2 s) the read runs anyway, and when the data
   arrives later, one plain read of both kinds follows (the items read cold are read warm).
4. **The read** (`_StartupRead`): the startup frame unregisters everything, the loader is
   released (its marked bags are dropped: the read covers them), and one request
   `{ wipe, backpack, bank, startup = reason }` replaces every waiting non-sort request;
   sorts asked for meanwhile run after it.

Opening the backpack before the read reads at once (`_OnStartupBagShown`, hooked on the
backpack frame's `OnShow`): priming starts, and if the item data is already loaded the read
is the primed one; otherwise it reads now and reads again when the data arrives.

What else this needed:
- **The first gear read no longer queues a second read.** `HarvestEquipment` reported every
  equipped slot as changed on its first read (no previous record) and called
  `InvalidateUpgrades(true)`, which queued a backpack refresh. The backpack sweep that reads
  the gear resolves every backpack verdict after the harvest, so it now only invalidates and
  refreshes the open bank (caches.md §2, §3).
- `ItemLoader:LoadAllBagsAndUpdate` (the old login sweep) was removed.

Simulated against the capture (a one-off replay of the 27 recorded requests through the
scheduler's cadence, which reproduced 731 ms against 728 ms measured): this read plus merging
leaves one full read carrying 22 requests, then the three refreshes later steps address
(two tooltip re-scans, and the upgrade refresh that the gear change above removes).

Coverage: `spec/refresh_pipeline_spec.lua` ("one bag read on login" → "the startup read"):
nothing is read before the read; it waits for a quiet frame after the loading screen and for
the item data; a sort asked for meanwhile runs after it; the prime timeout reads and the late
data reads again; no second read when the timeout fires after the data; the settle timeout;
the backpack opening early (with and without loaded data); the `PLAYER_ENTERING_WORLD`
fallback and the loading timeout; every startup event released after the read; and a replay
of the captured login (empty backpack at `OnEnable`, the Themes refresh, skill-line
invalidations, 14 `BAG_CONTAINER_UPDATE`s, item bursts, an item-load batch, the config
sliders' refreshes, then the loading screen ending) that asserts exactly one read and that no
item lands in Recent Items. `spec/loader_spec.lua` covers the loader's hold and
`PrimeAll`; `spec/refresh_spec.lua` that `OnEnable` reads nothing.

## 9. Redraw-Only Settings

A setting that only changes how the bags look needs no read of the bags and no new data,
only a draw. Such settings send `bags/Redraw` (`ctx`, optionally `{ buttons = true }`).
`refresh:RequestRedraw(buttons)` draws on the next frame, and every request made in the same
frame shares that one draw, restyling the buttons if any request asked for it: dragging a
slider asks on every value it passes, and a captured glow-intensity drag asked for 22
restyling redraws in one frame before this. `refresh:Redraw(ctx, buttons)` draws the
committed data again: the backpack always (its
`Draw` defers itself while it is hidden, as the draw after a sweep does) and the bank only
while it is shown (a deferred bank draw would show stale contents on the next visit). It
goes around the queue: a draw of committed data is allowed while a sweep is parked, and the
sweep draws again when it commits. It sends `bags/Draw/Backpack/Done` / `bags/Draw/Bank/Done`
like the draw after a sweep. With `buttons`, `ItemFrame:RestyleButtons()` bumps the style
generation in every button's draw record (item-drawing.md §7b), so each button runs all of
its setters once even though its data is unchanged.

**A setting qualifies only when no data phase reads it.** Checked by where each value is read:

| Setting | Read in | Message |
|---|---|---|
| Items Per Row, Columns (`GetBagSizeInfo`) | views, bag frame, themes | `bags/Redraw` (after the sliders' 0.2 s debounce) |
| Show Full Section Names | `frames/section.lua` (every section draw) | `bags/Redraw` |
| Quality Glow Intensity | `frames/item.lua` `DrawQualityGlow` | `bags/Redraw`, buttons |
| Show Item Level, Show Item Level Color (`GetItemLevelOptions`) | `frames/item.lua` | `bags/Redraw`, buttons |
| Theme (`themes:ApplyTheme`) | themes, decorations | `bags/Redraw` (the decoration generation it bumps redraws the buttons) |

Settings that look like presentation but are read by the data phase are recalculated
instead (§10): Section Order (sorted in `items:Phase10_PartitionIntoTabs` and
`Phase11_CommitAndDispatch`), in-bag search (`searchBox:GetSearchText` feeds
`isSearchResult` in Phase 8), the "Show Bags" view (categories and stacking change), free
space, gaps, sort order, stacking, categories, groups, and the upgrade provider.

**Form sliders no longer save at load.** The stacked form's slider saved on every
`OnValueChanged`, and WoW fires it with `userInput` false whenever code calls `SetValue`
(warcraft.wiki.gg `UIHANDLER_OnValueChanged`). The form does that when it is built and on
every reload, so each login wrote all eleven sliders back and two of them requested full
wipes (the glow sliders' requests were dropped only because Refresh was not listening yet).
The slider now saves only user input; the number box saves a typed value itself, clamped,
and only when it moved the slider. The spec mock's `SetValue` fires `OnValueChanged` the
same way the client does.

Coverage: `spec/config/config_redraw_spec.lua` (each setting above sends `bags/Redraw`, with
or without buttons; the data settings are covered in §10),
`spec/refresh_spec.lua` ("redraw-only settings", including one draw per frame), `spec/themes_spec.lua` ("ApplyTheme
refresh"), `spec/frames/item_spec.lua` ("redraws once after the buttons were restyled", for
items and free slots), `spec/forms/slider_spec.lua` ("saving").

## 10. Recalculating Without Reading (`derive`)

Most refreshes do not need the bags read again: what changed is an input of what the data
phase derives from the items (a setting, a category, the active bank tab, the open
interaction, tooltip text that finished loading, the equipped gear, a gear set), not the
items. Until this section, every one of them re-read the bags, and most settings wiped them
(re-read every slot and rebuilt the search index: about 36 ms against 13 ms for a read in a
captured login). A recalculation (`derive`) runs every phase after the harvest on the items
the last read committed.

**How a derive sweeps (`items:RunRefresh` with `ctx` `derive`).**
- `items:Phase2_Rederive` replaces the harvest. It reads no bag slot: it copies the
  committed items. Each item still in its slot (its GUID read with `C_Item.GetItemGUID`
  matches) gets what a read refreshes on a kept slot (`items:RefreshKeptItem`, shared with
  `ReuseHarvestedSlot`): quest state, tooltip text (a cache hit, or a re-scan after
  `TOOLTIP_DATA_UPDATE` dropped it), gear sets (the set map is rebuilt at the top of every
  sweep) and the new-item flag. An item read while the client had no data for it
  (`harvestIncomplete`) and still in its slot is read again with `AttachItemInfo`, as every
  read does with such a slot: a capture of opening the bank read 478 of 491 items cold, and
  the recalculations after it skipped them, leaving their names and "Retrieving item
  information" tooltips until the next open. An item whose slot now holds something else
  keeps its values: what the client reports for the slot belongs to the other item (writing its
  new-item flag would put the moved item in Recent Items), and the slot's `BAG_UPDATE` read
  is on its way.
- A backpack derive reads the equipped gear (`HarvestEquipment`), as a backpack read does,
  so upgrade arrows compare with the gear worn now.
- Phases 3-11 then run exactly as for a read, against a copy of the committed table (so the
  committed and new tables are distinct, as for a read). With no new GUIDs, nothing is
  marked as newly acquired; the search index re-indexes only items whose values changed.
- `restyle` bumps the kind's draw generation (as a wipe does), so every button draws in full.

**Guards (each pinned by a test that fails without it).**
- A kind with no committed items does nothing: never read (the kind's first sweep, which
  `_firstLoad` makes a wipe that marks nothing new, must be a read, or that read would put the
  whole bag in Recent Items) or emptied (`ClearBankCache` on bank close; deriving would draw
  an empty bank).
- A derive never shows a sort: it leaves the kind's sort sweep pending (§6), only a read
  re-reads every bag.
- `resetLayout` works as for a read.

**What asks for what.** `bags/Rederive` (`ctx`, `{ backpack?, bank?, resetLayout?, buttons? }?`;
naming neither kind means both) becomes `{ derive = true, ... }`; the bank, as for any
request, is swept only while it is open.

| Trigger | Request |
|---|---|
| Config data settings (upgrade provider, section and item order, groups, category filters, stacking except Split Transmogged, free space, gaps) | `bags/Rederive { resetLayout, buttons }` |
| Categories: create from an item, delete, rename, hide/show, reprocess (`categories:ReprocessAllItems`), category pane edits, search categories, item drops on a header, group drag and drop | `bags/Rederive { resetLayout, buttons }` |
| In-bag search toggle (`themes:SetSearchState`) | `bags/Rederive { resetLayout, buttons }` |
| Show Bags toggles (context menu, GW2 theme) | `bags/Rederive { resetLayout }`: nothing a button draws depends on the view except through data its draw record holds, so unchanged buttons skip |
| Interaction window opens the backpack / closes (`core/hooks.lua`) | `bags/Rederive { resetLayout }` |
| `EQUIPMENT_SETS_CHANGED` | derive of both kinds with `resetLayout` |
| Tooltip resolved (`TooltipScanner:OnTooltipDataResolved`) | `bags/Rederive { backpack, bank = atBank }` |
| Upgrade inputs: `PLAYER_EQUIPMENT_CHANGED`, skills, spec; the gear harvest's bank refresh | `bags/Rederive` for the kinds (`items:RequestUpgradeRefresh`) |
| Bank tab switches (grey-out) | `bags/Rederive { backpack }` |
| A bag's refresh on close (`OnRefresh`: Recent Items expiry, held gaps); Pawn or SimpleItemLevel registering late | `bags/Rederive` for that bag / both |

The settings and category requests keep everything the full refresh they replace did except
the reads: a fresh layout and a full redraw of every button. They no longer clear the bank's
committed items while the bank is closed (the next bank open reads the bank anyway).

**Still reads, and why.**
- `BAG_UPDATE` batches, `BAG_CONTAINER_UPDATE` (bags attached, removed or swapped; still a
  wipe), `BANKFRAME_OPENED`, `PLAYERBANKSLOTS_CHANGED`, sorts, the startup read (§8).
- `PLAYER_LEVEL_UP`, `PLAYER_LEVEL_CHANGED`, `PLAYER_AVG_ITEM_LEVEL_UPDATE`: scaling changes
  the bag items' own current item levels, which only the kept-slot check of a read sees
  (caches.md §1). When such an event and a derive-only event fall in the same frame, the one
  refresh is a read.
- "Split Transmogged Items": the item hash includes the transmog appearance only with this
  setting, and the hash is computed when a slot is read (`bags/FullRefreshAll`).
- `DB:ResetMaxItemLevel`: the maximum is learned while slots are read (`bags/FullRefreshAll`).
- The bank tab panel closing (`frames/bankslots.lua`): it clears the bank cache, then reads.
- `bags/FullRefreshAll` itself is unchanged (a wipe), for these and for other addons.

**Merging (§7).** A read never rides on a waiting derive (a derive reads nothing). A derive
rides on a waiting derive, a waiting wipe, or a waiting read that reads every bag of the
derive's kinds; not on a read of some bags, which carries the other bags' items over without
refreshing them (a re-scanned tooltip in another bag would be missed). `restyle` merges as
an or; `resetLayout` as for reads. The startup read absorbs derives like any request.

Coverage: `spec/refresh_pipeline_spec.lua` ("recalculating without reading (derive)": no slot
read and the same committed items; the same state as a read when nothing changed; category,
tooltip, gear set and new-item changes applied; a moved item left alone; never-read and
emptied kinds; a pending sort; the draw generation; the equipped gear. "merging derives";
"the startup read" → "recalculates, without reading the bags again, what changes after the
read"; "upgrade verdict cache": which events read and which recalculate),
`spec/refresh_spec.lua` (routing of `bags/Rederive` and `EQUIPMENT_SETS_CHANGED`),
`spec/config/config_redraw_spec.lua` (every data setting; Split Transmogged still reads),
`spec/categories_spec.lua` ("refreshes"), `spec/core/interaction_refresh_spec.lua`,
`spec/frames/contextmenu_spec.lua`, `spec/tooltip_spec.lua`,
`spec/bags/bank_context_refresh_spec.lua`, `spec/bags/backpack_spec.lua`, `spec/items_spec.lua`
(late Pawn registration).
