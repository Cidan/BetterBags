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
- **`_Step()` is one frame of the pump.** While held (out of the world, §8) it stops the
  clock (`self._running = false`) and does nothing else: no unit starts, and the active one
  waits. Otherwise, in priority order it: (a) advances the active unit's coroutine one step
  (`_Resume`) if one exists; else (b) burns the idle hand-off frame if `_idlePending`; else
  (c) dequeues and starts the next unit; else (d) stops the clock when the queue is empty.
  After (a), (b), and (c) it calls `_Arm()` to schedule the next step.
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
  `_world`) is initialized in `refresh:Init()` and reset there; tests re-init per case.
  `refresh:OnEnable()` holds the queue for the login's read (§8); tests that call it and then
  expect sweeps open the hold through the world frame's events (`refresh._worldFrame`), call
  `refresh:_WorldRead(refresh._world, "primed")`, or assert on the requests made.
- `RefreshRequest.derive` recalculates the named kinds from their committed items without
  reading a bag slot, and `RefreshRequest.restyle` makes every button of the swept kinds draw
  in full (§10). Production code asks for them with `bags/Rederive`.
- `RefreshRequest.merged` (how many requests a merged one carries), `RefreshRequest.world` (why
  the world's read ran: `primed`, `timeout` or `bagShown`) and `RefreshRequest.worldCause` (what it
  follows: `login` or `transfer`) are only informational; they show up in profiler call traces as
  `Refresh._RunUnit`'s argument.
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

## 8. The World's Read: One Read of the Bags at Login and After Every Loading Screen

At PLAYER_LOGIN, when `refresh:OnEnable()` runs, the client has not delivered the bags. A
captured cold login (game build 12.1.0) showed it: the login sweep inside `OnEnable`
read a backpack of 20 empty slots and no other bag; the bags then attached
(`BAG_CONTAINER_UPDATE` x14) and their contents arrived (`BAG_UPDATE` bursts) over the next
five seconds, through the loading screen and one frame past it. Every step requested
another sweep, and the queue ran 25 units (17 full wipes, 728 ms of sweeps) after the
loading screen. The empty first commit is also a Recent Items hazard: a plain sweep that
lands between it and the next full read treats every item delivered in between as newly
looted.

**Every loading screen is the same.** Reported: "4x data/items.lua:1197: bad argument #1 to
'GetItemGUID' (Usage: local itemGUID = C_Item.GetItemGUID(itemLocation))" as a player went into
a dungeon. The stack: `CloseInteractionWindow` (core/hooks.lua, `PLAYER_INTERACTION_MANAGER_FRAME_HIDE`)
asked for a recalculation (`bags/Rederive`), the idle queue ran its first step in that event, and
`Phase2_Rederive` asked the client the GUID of a committed item in a bag not marked unread (§10),
whose slot the client said was empty. `BAG_UPDATE` is a `SynchronousEvent`
(ContainerDocumentation.lua): it fires the moment a bag's contents change, so a real change marks
its bag before any later event can recalculate. A dungeon is a world transfer, and the client takes
the player's items away for its loading screen and gives them back after, without a `BAG_UPDATE`
on the way out.

**Captured** (a profiler capture of a trip into an instance and back out, retail, the bag counts of
perf-profiler.md §10d recorded at each event): the items leave **before `PLAYER_LEAVING_WORLD`**.

| | In | Out |
|---|---|---|
| `LOADING_SCREEN_ENABLED` | 1.48 s: 26 items, all existing | 9.07 s: 26 items, all existing |
| `PLAYER_LEAVING_WORLD` | 3.41 s: no item, no slot | 9.93 s: no item, no slot |
| frames run in between | 464 (about 4 ms each) | |
| items back | 4.27 s, `BAG_UPDATE` bursts after `LOADING_SCREEN_DISABLED` (3.93 s) | 15.42 s, after it (15.19 s) |

No `BAG_UPDATE` fired between the first two rows, and none of BetterBags' code ran (nothing was
pending), but frames, and so timers, kept running. The wait first started at `PLAYER_LEAVING_WORLD`,
and the error came back three times after that fix, the queue not held (`_held=false`): from a
tooltip finishing (`TooltipScanner:OnTooltipDataResolved`, its bucket's timer), from a window
closing (`CloseInteractionWindow`), and from the queue's step. Each is something that runs in that
gap. Replayed on the real pipeline in the captured order, each raises the reported error without
the fix.

**The wait** (`refresh:HoldForWorld(cause)`): at the end of `OnEnable` (cause `login`), and on every
loading screen (cause `transfer`) from whichever of its two signals comes first,
`LOADING_SCREEN_ENABLED` (documented on every client branch, LoadingScreenDocumentation.lua) or
`PLAYER_LEAVING_WORLD` (`refresh:_LeaveWorld(signal)`, which returns `"held"` or `"joined"` for
traces). Each signal also marks every backpack, bank and Warbank bag unread (§10: until a read of
them commits, a recalculation asks the client nothing about them). It holds the
queue (`self._held`) and the loader (`itemLoader:Hold()`, so bag batches only mark bags dirty) and
listens on its own frame (`self._worldFrame`) to `PLAYER_ENTERING_WORLD`,
`LOADING_SCREEN_DISABLED`, `BAG_UPDATE` and `BAG_CONTAINER_UPDATE`. **While held, no unit starts
or goes on** (`_Step` stops the clock): requests made meanwhile wait (and merge), and a unit
parked at its yield when the player left waits too, since the bags it would read next are not
there. Then:

1. **Loading** until `LOADING_SCREEN_DISABLED` (verified in the API documentation of every
   client branch: live, classic, classic_era, classic_anniversary, classic_beta,
   classic_titan). On a client without it, `PLAYER_ENTERING_WORLD` starts the next phase;
   with it, `PLAYER_ENTERING_WORLD` arms `WORLD_LOADING_TIMEOUT` (10 s) as a safety net.
   `WORLD_RETURN_TIMEOUT` (60 s from the wait's start) is a second one, for a client that never
   says the world is back (`PLAYER_ENTERING_WORLD` follows every loading screen).
2. **Settling**: the frame's `OnUpdate` waits for the first frame in which no bag event
   fired (frames do not run during the loading screen). After `WORLD_SETTLE_TIMEOUT`
   (2 s from the loading screen's end) of bag events it stops waiting. In the captured login,
   the client still sent a burst of 92 `BAG_UPDATE`s one frame after the loading screen; the
   next frame was quiet.
3. **Priming**: `itemLoader:PrimeAll(callback)` loads the item data of every managed bag
   slot and every equipped slot in one `ContinuableContainer`; when it completes, the read
   runs. After `WORLD_PRIME_TIMEOUT` (2 s) the read runs anyway, and when the data
   arrives later, one plain read of both kinds follows (the items read cold are read warm).
4. **The read** (`_WorldRead`): the world frame unregisters everything, the loader is
   released (its marked bags are dropped: the read covers them), and one request
   `{ wipe, backpack, bank, world = reason, worldCause = cause }` replaces every waiting non-sort
   request; sorts asked for meanwhile run after it, and a unit parked when the player left goes on
   first (one unit at a time). A wipe trusts nothing read before the transfer; it costs a full
   read of the backpack once per loading screen (the bank and guild bank close with the
   transfer). Not measured after a loading screen yet.

**Each wait is its own** (a table, `self._world`). The other signal of the same loading screen joins
the wait under way: a wait still waiting for a loading screen to end (`phase == 'loading'`, the
login's included) that has not had that signal (`hold.signals`). The same signal again, or either
signal once the wait is past its loading screen (settling, priming), is another loading screen: a
new wait replaces the last. The world frame's scripts are the current wait's (set by `HoldForWorld` and
`_WorldSettle`, cleared by `_WorldPrime` and `_WorldRead`); only the timers and the item data's
callback outlive their wait, and each checks it: a replaced wait's loading or return timeout
settles nothing, its prime timeout reads nothing, and its item data asks for a read only if that
wait had read (its read ran cold); a replaced wait that never read leaves everything to the next.

At login, opening the backpack before the read reads at once (`_OnLoginBagShown`, hooked once on
the backpack frame's `OnShow`): priming starts unless it has, and if the item data is already
loaded the read is the primed one; otherwise it reads now and reads again when the data arrives.
After a loading screen the committed items are still there to show, so a backpack shown then reads
nothing early.

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
the backpack opening early (with and without loaded data, the item data loaded once); the
`PLAYER_ENTERING_WORLD` fallback and the loading timeout; every world event released after the
read; and a replay of the captured login (empty backpack at `OnEnable`, the Themes refresh,
skill-line invalidations, 14 `BAG_CONTAINER_UPDATE`s, item bursts, an item-load batch, the
config sliders' refreshes, then the loading screen ending) that asserts exactly one read and that
no item lands in Recent Items. "leaving the world (every loading screen)": the reported dungeon
entry replayed (no error, nothing swept while out of the world, one read taking in both windows'
recalculations, nothing new in Recent Items, the loader held and released), no bag asked about
while out of the world, a unit parked when the player left going on only once the world is back,
a recalculation before the world's read asking nothing about the bags (the items not back yet),
an earlier wait's timers and item data ending nothing (read or not, still loading or not), the
settle timeout counted from the loading screen's end, the return timeout, no early read for a
backpack shown after a loading screen and no second hook, a second loading screen before the
read. In the captured order: a window closing and a tooltip finishing between `LOADING_SCREEN_ENABLED`
and `PLAYER_LEAVING_WORLD`, after the items left (no error, nothing asked, nothing swept, one read
after); a recalculation queued behind a read stepping in that gap; one wait per loading screen
whichever signal comes first; a new wait for a loading screen that begins before the last one's read,
and for the player leaving a second time during a loading screen's wait. "a simulated client"
(the "recalculating without reading" tests): 60 seeds of 300 random steps on the real events, queue
and pipeline (loot, use, moves, counts, tooltips finishing, settings, gear sets, windows and the bank
opening and closing, deposits, withdrawals, sorts, loading screens in the captured order), a client
that reports every change as it makes it: no slot the client emptied is ever asked about, and once
the client is quiet the committed backpack is what it holds. Without the fix, the first seed raises
the reported error. `spec/loader_spec.lua` covers the loader's hold and `PrimeAll`; `spec/refresh_spec.lua`
that `OnEnable` reads nothing. Mutation-tested: 27 mutations of the wait, the marks and the
capture tooling, each caught; six first survived and led to five tests (a wait replaced while
still loading, the settle timeout, a never-read wait's late item data, the bag shown mid-prime,
the Warbank's count) and to removing a check its callers already made (priming twice). Three
identity checks in the world frame's scripts were removed first: the scripts are set per wait.
Holding from `LOADING_SCREEN_ENABLED`: 6 mutations (no `LOADING_SCREEN_ENABLED`, joining past the
loading screen, the same signal joining, a new wait or a join not recording its signal, no marks), each
caught; the one that first survived (a join not recording its signal) led to the test of the player
leaving a second time.

**Measured** (the same capture): the wipe after a loading screen, with the items there, cost 47 to
57 ms for a 26-item backpack. On the way in the world's read ran at 4.09 s, before the items came back
(4.27 s): the bags were attached but empty and a frame passed with no bag event, so it read an empty
backpack, and the read the bags' `BAG_CONTAINER_UPDATE`s asked for (0.76 s later, 17 requests merged)
read the items. No error comes of it (an empty commit asks nothing), but the first read was for
nothing. Not changed yet.

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
| Items Per Row, Columns (`GetBagSizeInfo`) | views, bag frame | `bags/Redraw` (after the sliders' 0.2 s debounce) |
| Resizable Window (`GetBagSizeMode`) | the bag's window (`ApplySizeSettings` on draw) | `bags/Redraw` |
| Show Full Section Names | `frames/section.lua` (every section draw) | `bags/Redraw` |
| Quality Glow Intensity | `frames/item.lua` `DrawQualityGlow` | `bags/Redraw`, buttons |
| Show Item Level, Show Item Level Color (`GetItemLevelOptions`) | `frames/item.lua` | `bags/Redraw`, buttons |
| Theme (`Sonata:ApplyTheme`) | window decorations, element styles | `bags/Redraw` (the Sonata generation it bumps redraws the buttons) |

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

Coverage: `spec/config/settings_effects_spec.lua` (each setting above sends `bags/Redraw`, with
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
- **A bag the client changed after its read keeps its committed items, and the client is asked
  nothing about them.** `items:MarkBagUnread(bagID)` records each change the client reports:
  `BAG_UPDATE` (its bag), `BAG_CONTAINER_UPDATE` (every backpack, bank and Warbank bag),
  `PLAYERBANKSLOTS_CHANGED` (bag -1 on Classic, every bank bag on WoW: Forever), registered next to
  the reads they lead to (`refresh:OnEnable`). A committed read clears, for each bag it harvested,
  the changes made before its harvest (`items:MarkBagsRead`; changes are numbered, so one made
  while the read was parked at its yield still marks the bag after it commits, and a read that
  fails before committing clears nothing). A derive never clears a mark. `Phase2_Rederive` asks
  `GetItemGUID` only about items of unmarked bags, which hold what they committed.
  **Failure mode (fixed, reported twice in game):** `data/items.lua:1190: bad argument #1 to
  'GetItemGUID' (Usage: local itemGUID = C_Item.GetItemGUID(itemLocation))`, from a unit the queue
  stepped (`refresh.lua:250`). `GetItemGUID` takes an `ItemLocation` that holds an item, not an
  `EmptiableItemLocation` (`ItemDocumentation.lua`). A slot the player empties (a sale, the last of
  a stack used, gear equipped into an empty slot) is read only once the loader has the bag's item
  data (`BAG_UPDATE_DELAYED`, then its `ContinuableContainer`), and that read then waits behind
  the units already queued: a read never rides on a waiting derive (§7). A derive that ran first
  asked about the emptied slot. Reading the bag in the derive instead would read item data before
  its load (data-loader.md §19).
  A derive the scheduler starts synchronously (idle, inside the event handler that asked for it)
  sees every change the client made before it marked: `BAG_UPDATE` is a `SynchronousEvent`
  (ContainerDocumentation.lua), fired the moment a bag's contents change. The reported error above
  came from a stepped unit (its stack starts at `_Arm`'s timer). A second report came from a
  synchronous one during a world transfer, which takes the items away with no `BAG_UPDATE`: leaving
  the world marks every bag unread and holds the queue (§8).
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
| Categories: create from an item, delete, rename, `UpdateCategory` (bags, rule, group by, priority, color), reprocess (`categories:ReprocessAllItems`), Categories page edits, search categories, item drops on a header, group drag and drop | `bags/Rederive { resetLayout, buttons }` |
| In-bag search toggle (`search/SetInFrame` → `bag:SetSearchShown`) | `bags/Rederive { resetLayout, buttons, categoriesUnchanged }` |
| Show Bags toggles (`ContextMenu:ToggleBagSlots`: the context menu, a theme's ShowBags action button) | `bags/Rederive { resetLayout }`: nothing a button draws depends on the view except through data its draw record holds, so unchanged buttons skip |
| Interaction window opens the backpack / closes (`core/hooks.lua`) | `bags/Rederive { resetLayout, backpack, bank = items:NeedsInteractionRecalculation(BANK), categoriesUnchanged }`: the backpack's grey-out depends on the open window; the bank's only interaction-dependent input is stack unmerging, so it is recalculated only when its committed stacks were built under the other interaction state (recorded per kind at commit, `items._stackedInteracting`). A captured bank open recalculated the bank (149 ms) into the layout its own read had just committed under the banker interaction |
| `EQUIPMENT_SETS_CHANGED` | derive of both kinds with `resetLayout` |
| Tooltip resolved (`TooltipScanner:OnTooltipDataResolved`) | `bags/Rederive { backpack, bank = atBank, guild = atGuildBank, categoriesUnchanged }` |
| Character state may have changed (`items:OnCharacterStateChanged`: the pet journal's `PET_JOURNAL_LIST_UPDATE`, `NEW_PET_ADDED`, `PET_JOURNAL_PET_DELETED`, `PET_JOURNAL_PET_RESTORED`; `SPELLS_CHANGED` and `UPDATE_FACTION`, bucketed) | `bags/Rederive` naming only the kinds where a committed item's usability or pet counts changed (bank and guild bank only while open); every open kind when the pet journal first loads; nothing otherwise (search-indexing.md §13-§14) |
| Upgrade inputs: `PLAYER_EQUIPMENT_CHANGED`, skills, spec; the gear harvest's bank refresh | `bags/Rederive { categoriesUnchanged }` for the kinds (`items:RequestUpgradeRefresh`) |
| Bank tab switches (grey-out) | `bags/Rederive { backpack, categoriesUnchanged }` |
| A bag's refresh on close (`OnRefresh`, `Refresh`: Recent Items expiry, held gaps); Pawn or SimpleItemLevel registering late | `bags/Rederive { categoriesUnchanged }` for that bag / both |

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

**`categoriesUnchanged` (data-loader.md §18).** Each item keeps its categories and grey-out until
something they read changes. A derive works every item's category out again unless it says
`categoriesUnchanged`: its cause changes nothing a category reads (the grey-out, the upgrade
arrows, a tooltip that loaded, recency, the search box; each of those reaches the items it affects
by itself). The table above marks them; settings, categories, groups, Show Bags, gear sets and the
guild bank's view keep working every category out. Reads keep categories, so a read that absorbs a
derive without `categoriesUnchanged` carries `recategorize`, which works them out again. Both reach
the sweep as context keys of the same names.

**Merging (§7).** A read never rides on a waiting derive (a derive reads nothing). A derive
rides on a waiting derive, a waiting wipe, or a waiting read that reads every bag of the
derive's kinds; not on a read of some bags, which carries the other bags' items over without
refreshing them (a re-scanned tooltip in another bag would be missed). `restyle` merges as
an or; `resetLayout` as for reads; `categoriesUnchanged` as an and (two derives keep categories
only when both say so); a read absorbing a derive without it gets `recategorize`. The startup read
absorbs derives like any request.

Coverage: `spec/refresh_pipeline_spec.lua` ("recalculating without reading (derive)": no slot
read and the same committed items; the same state as a read when nothing changed; category,
tooltip, gear set and new-item changes applied; a moved item left alone; never-read and
emptied kinds; a pending sort; the draw generation; the equipped gear; "a bag the client changed
after its read": left as committed and nothing asked about it, ended by its read, kept through a
derive and a read of another bag, ended for every bag by a wipe, kept through a change during its
read and a read that fails; "while a changed bag's read waits": the reported error replayed through
the queue (a sale while a recalculation waits behind a read). "merging derives";
"the startup read" → "recalculates, without reading the bags again, what changes after the
read"; "upgrade verdict cache": which events read and which recalculate; "merging derives":
`categoriesUnchanged` and `recategorize`; "deriving only what changed"),
`spec/refresh_spec.lua` (routing of `bags/Rederive`, `categoriesUnchanged` included, and
`EQUIPMENT_SETS_CHANGED`; the bags each change event marks unread),
`spec/config/settings_effects_spec.lua` (every data setting; Split Transmogged still reads),
`spec/categories_spec.lua` ("refreshes"), `spec/core/interaction_refresh_spec.lua`,
`spec/frames/contextmenu_spec.lua`, `spec/tooltip_spec.lua`,
`spec/bags/bank_context_refresh_spec.lua`, `spec/bags/backpack_spec.lua`, `spec/items_spec.lua`
(late Pawn registration).

## 12. The Guild Bank

The guild bank is a third kind of bag, read only while it is open and BetterBags Next's guild bank
panel has shown, the way a bank open is (§11): `guildbank/Opened` shows the panel and loads the tabs
once it has shown (`GUILD_SHOW_TIMEOUT`), each tab loaded is read once its items' data has loaded
(`ItemLoader:PrimeGuildBank`, `GUILD_PRIME_TIMEOUT`), and the first read of a visit has a fresh
layout. `RefreshRequest.guild` sweeps it after the bank and before the backpack; a wipe sweeps it,
and `bags/Rederive` naming no kind recalculates every kind. Details: guild-bank.md §3.

## 11. Opening the Bank: Show at Once, Load Once Shown, Read Tab by Tab

Bank containers have no slots until the bank opens, so the startup read's priming (§8,
`PrimeAll`) cannot cover them, and `BANKFRAME_OPENED` used to request the bank read at once.
Two captures of a bank open show the result: 484 and 478 of 491 bank tooltips read
"Retrieving item information" (the client had not loaded those items), every one of those
items was read cold, and their data arrived about 1.2 s later in one batch, which set off a
second refresh of both bags (and, before recalculations re-read cold items, re-sorted them on
screen).

Then the open was primed, but with warm data (every open after a session's first) priming calls
back in the same frame, so the bank's read started in the first frame of the window's show
animation and its commit and draw landed in the frames after: inside BetterBags Next's 0.45 s
slide, or the classic window's fade when Enable Fading is on (0.1 s in Base). Asked: "finish our
bank window show animation, before we start loading in bank info, just to prevent hitching. bank
loading is heavy with all the items it has." Earlier captures put bank work in the tens of
milliseconds to over a hundred (a bank recalculation of 149 ms, §10; a redundant bank draw of
19 ms, layout-rendering.md §3). No capture of the hitch itself was available; a capture of a warm
bank open on retail with Next, before and after, is to confirm it (data-driven.md).

Now `BANKFRAME_OPENED` (`data/refresh.lua`):
1. sets `addon.atBank` and the bank tab as before;
2. `refresh:_OpenBank(ctx)` shows the bank window at once (`addon.Bags.Bank:Show(ctx, nil,
   onShown)`), with the bank's committed items, which are none after a close: the classic bag
   says Loading... (window.md §7), Next's bank its own Loading... (next.md §3);
3. waits for the window to finish showing. Both designs call `onShown` then: the classic bag
   passes it to its behavior and on to `window:Show` (at once without a fade, when a fade still
   playing ends, never for a fade cut short, window.md §4); Next's panel when its slide ends (at
   once when open, never for a slide closing or Escape cut short, next.md §3). Classic bags do not
   fade by default (`enableBagFading = false`), so there the window calls back at once and the
   bank loads at once, as before;
4. `BANK_SHOW_TIMEOUT` (1 s, past Next's 0.45 s slide) loads the bank anyway if the window never
   says it finished: Escape can hide it mid-animation while the bank stays open, and a theme's
   animation might never end;
5. while the window shows, no sweep reads the bank: `_RunUnit` skips the bank part of any unit
   while `refresh:BankShowing()`, and the backpack part runs as usual. Nothing is lost: the open's
   read, which follows, reads every bank bag with a fresh layout, so a bank `BAG_UPDATE` batch, a
   Classic `PLAYERBANKSLOTS_CHANGED`, a wipe or a bank sort's sweep asked for meanwhile is covered
   (a sort's pending mark stays set and that read clears it);
6. `refresh:_BankShown(open, reason)` ends the wait, once, and loads the bank tab by tab
   (`_LoadBank`, below). `_BankShown` is a method, so a capture's call trace shows when the wait
   ended and why (`reason` "finished", "timeout" or "no window", with Enable Bank Bags off) and what
   it did (it returns "loading", "already" or "ended");
7. an open that has ended (`BANKFRAME_CLOSED`, or a new open) does nothing when its window says it
   has shown, or a tab's data or a timeout arrives. Closing also ends the hold and lets reads of the
   bank read every bank bag again.

`items/RefreshBank/Done` (`core/init.lua`) draws the shown bank after every read, in both bag
designs.

### 11a. Tab by tab, as the guild bank

Asked: "pop in data for each physical tab (non-virtual tab) one by one ... i want to mimic the guild
bank behavior as close as possible, so look at that as your north star. this goes for both next and
original bags." The guild bank's tabs come from the server one query at a time and each is read as
it arrives (guild-bank.md §2, §3), so its work lands in many small frames. The bank used to read and
draw every tab in one go. **Measured** (a retail capture of opening BetterBags Next's bank, 500
items, Pawn the upgrade provider): one frame of 520 ms of BetterBags time after a 128 ms harvest
frame; of it, Pawn's upgrade check about 200 ms (0.39 ms per item on its first ask, 0.24 ms per item
when asked again a second later) and drawing about 180 ms.

- **The tabs** (`refresh:BankTabs()`): every bag a read of the bank reads (`Items:BankBags`: on
  retail every character and Warbank tab, on Classic the bank, its bags and the reagent bank) that
  has slots, in the bank's order (character bank, then the Warbank's; on Classic the bank, its bags,
  then the reagent bank). A bank with none (WoW: Forever before its first tab) is read once, empty
  (`bankOpen = "empty"`), so the window still draws (and shows its Purchase Bank button).
- **Reads see only the tabs loaded** (`Items:SetLoadedBankBags`, read by `Phase1_DetermineBags`), as a
  guild bank read reads only the tabs received (`LoadedContainers`): any read of the bank during the
  load (a `BAG_UPDATE`, a wipe, a sort's sweep) shows only the tabs loaded so far, and nothing pops in
  before its turn. Once every tab is read, and when the bank closes, the limit goes (nil: every bank
  bag), so a tab that gains slots later is read like any change. An open also says when it starts and when
  its reads are done (`bags/BankOpening`, `bags/BankLoaded`): the classic bank goes by its saved position
  between them, or each tab would push its top up (window.md §3c). A bank with no tab with slots reads once as
  a wave, so its one read ends the same way.
- **Item data loads at once, each tab on its own.** The guild bank's tabs arrive from the server; the
  bank's are all on the client, so `_LoadBank` starts every tab's load at once
  (`itemLoader:PrimeBank({ bag }, ...)`, one `ContinuableContainer` each), so the server sends them
  in parallel as before. A tab is ready once its data has loaded (`"primed"`) or after
  `BANK_PRIME_TIMEOUT` (2 s, one timer for every tab: Blizzard drops the callbacks of an item whose
  load fails, `ITEM_DATA_LOAD_RESULT` with `success == false`, `AsyncCallbackSystem.lua`); a tab read
  before its data arrived is read again when it does (`{ bank = true }`), as a guild tab is. A tab
  whose data arrives after the timeout but before its turn is read once, warm.
- **One tab per read** (`_LoadNextBankTab`). The next tab is read once the read before it has run:
  the read's request carries `bankWave`, and when its unit finishes, or fails, `_UnitDone` calls
  `_BankWaveDone`, which loads the next. So each read shows one more tab, a few frames apart (harvest,
  commit and draw, the idle frame), even when every tab's data was already loaded and would otherwise
  have merged into one read. A read failing never stops the load. A wave's request that merges into
  a waiting one carries its `bankWave` (the newest: the only other one waiting can be an ended
  open's, whose read would otherwise strand the new open).
- **Order** (`_NextBankTab`): the Blizzard tab shown (tab mode, `blizzardBankTab`), else the tabs of
  the bank type shown (Warbank or character bank, from `bankTab`: both bag designs keep both fields on
  `addon.Bags.Bank`), then the others. It is chosen afresh before each read, so a tab chosen while the
  bank loads is read next, as a guild tab chosen while loading is queried next (`GuildBank:LoadTab`).
- **Layout:** the first read rebuilds the layout (`resetLayout`); later reads keep it, as the guild
  bank's do, so with "Preserve Empty Slots as Gaps" (on by default) a later tab's items are added at
  the end of their sections (data-loader.md §13) until the bank is next opened.
- **Traces** (data-driven.md): the request names the tab it adds (`bankWaveTab`) and why it ran
  (`bankOpen`: "primed", "timeout", "empty"); `_BankTabReady` returns "ready", "read again",
  "already" or "ended", and `_LoadNextBankTab` the tab it read or "reading", "waiting", "done".

**Not measured yet:** a capture of a bank open with the tabs (in game, before and after). Inferred
from the capture above: each read asks the upgrade provider about every item loaded so far (Pawn is
not cached, caches.md §2), so later reads cost about 0.24 ms per item already loaded, and the reads
together ask Pawn about more items than one read did. The guild bank pays the same.

**The cost:** the bank's contents appear once its window has shown: 0.45 s later on Next, 0.1 s
on classic with fading on, then tab by tab. Priming also starts after the animation (asked: nothing
loads before it), so a session's first open, which waits about 1.2 s for the server, waits that much
longer; priming at once and holding only the reads would hide that wait behind the animation, at the
cost of a loop over every bank slot in its first frame.

Coverage: `spec/refresh_spec.lua` ("opening the bank": shown at once and loaded only once shown;
every tab's data loaded at once, a load each, only tabs with slots; each tab read once its data has
loaded, the shown one first, the first read afresh, the limit gone at the end, the timeouts doing
nothing after; the Warbank first while it shows; the Blizzard tab shown first; a tab chosen while it
loads read next; one tab per read with every tab's data loaded; every tab read on the timeout and a
tab again when its data arrives; a tab whose data arrives before its turn read once, warm; Classic's
order with the reagent bank last; an empty bank read once; loading on after a failed read; nothing
for an ended open, including late data; a first read merging into an ended open's; stopping on
close; the show timeout; `_BankShown`'s reasons and returns; no bank window; no bank sweep while it
shows, then sweeps as usual; a reopen), `spec/loader_spec.lua` ("primes the bank tabs it is given in
one load"), `spec/items_spec.lua` ("the bank's tabs loaded so far": `BankBags`, Phase 1 limited to
the tabs loaded, also against a read naming others, and unlimited again),
`spec/refresh_pipeline_spec.lua` ("reads the bank once, warm, through a bank open in the captured
order": replays a captured open, the window finishing its show, cold item data, the banker
interaction, then the data and the tooltip resolution arriving, through the real pipeline and
queue; "opening the bank, tab by tab": each read one more tab, frames apart, the first afresh; the
Warbank first; a bank read during the load shows only the tabs loaded; a tab gaining slots after; only
an open's own read loads its next tab; starting over on a reopen), and
`spec/integration/bank_open_spec.lua` (the whole addon: no bank read while Next's bank slides in or
the classic bank fades in, then one read, and Loading... gone once drawn; at once with fading
off). 29 mutations; the four that first survived led to a harness test (an error in a message
handler reaches the harness, test-harness.md §5) and to removing two resets of Next's callback list
that every new slide already does. Tab by tab: 22 mutations, each failing at least one test; the four
that first survived led to three tests (Classic's order, late data after an open ended, an ended
open's read finishing during the next) and the merge fix above, and to removing a redundant check.
