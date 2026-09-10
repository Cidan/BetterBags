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

- **`RequestUpdate(request)` is enqueue-only.** It appends the request to `self._queue` and,
  if the pump is not already running, flips `self._running = true` and calls `_Step()` once.
  It performs **no** side effects itself.
- **`_Step()` is one frame of the pump.** In priority order it: (a) advances the active
  unit's coroutine one step (`_Resume`) if one exists; else (b) burns the idle hand-off
  frame if `_idlePending`; else (c) dequeues and starts the next unit; else (d) stops the
  clock (`self._running = false`) when the queue is empty. After (a), (b), and (c) it calls
  `_Arm()` to schedule the next step.
- **`_Arm()` is the ONLY clock in the refresh path.** A single `C_Timer.After(0)` chain,
  never one-per-refresh, so step ordering is fully deterministic.
- **`_Resume()`** resumes the active coroutine; when it finishes it sets `_idlePending = true`
  (arming the hand-off frame). A unit that errors is dropped and reported via
  `geterrorhandler()` — one bad sweep must not wedge the queue.
- **`_RunUnit(request)`** is the body that used to be `RequestUpdate`, now running inside the
  pump's coroutine: request-time mutations first (`ClearItemCache` for `wipe`,
  `ClearNewItems` for sorts, the bankTab adjust), then the bank sweep, then the backpack
  sweep, then the protected `C_Container.Sort*` calls (still gated on
  `not InCombatLockdown()`). Because this is the only sweep in flight, those mutations run
  with nothing parked to corrupt.

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
- **No coalescing.** Requests are processed literally, in order, one per unit. Data
  stability is the priority; do not add "collapse the queue" optimizations here without a
  separate, well-tested change.
- **Whole request = one unit.** A request carrying both `bank` and `backpack` runs both
  sweeps sequentially inside the same unit coroutine (bank first, then backpack), preserving
  the original intra-request ordering of wipe → bank → backpack → sort.

## 4. API Contracts

- `items:RunRefresh(ectx, kind)` — the inline data sweep for one bag kind (Phase1..Phase11,
  yields once after harvest). **Must be driven from within a coroutine.** The scheduler calls
  it directly so bank and backpack share one coroutine; `items:ProcessRefresh(ctx, kind)`
  remains a thin `async:Do(ctx, function(e) self:RunRefresh(e, kind) end)` wrapper for direct
  callers and unit tests. `RefreshBackpack`/`RefreshBank` still wrap `ProcessRefresh`.
- `refresh:RequestUpdate(request)` — enqueue only; never call `items:Refresh*` directly from
  production code, always go through `RequestUpdate` so serialization holds.
- Scheduler state (`refresh._queue`, `_active`, `_idlePending`, `_running`) is initialized in
  `refresh:Init()` and reset there; tests re-init per case.

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
