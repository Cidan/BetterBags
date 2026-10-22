# Performance Profiler (`debug/perf/`, Performance tab, `tools/flamegraph`)

BetterBags has a built-in instrumenting profiler. It is off by default and costs nothing
while off. A capture records where BetterBags spends its time (a call tree with exact self
time), how much each frame costs, the frames that spiked, and a call trace: every measured
call in the order it ran, with its arguments and return values. The result is saved to
SavedVariables and can be browsed in-game as a flame graph, a call list and a timeline, or
exported offline.

It exists to answer three questions the old `debug:StartProfile`/`EndProfile` pair (one
hand-placed timer that printed a number to the debug log) could not:

1. Where does the whole data -> draw path spend its time (event, refresh queue, every
   sweep phase, the render)?
2. Why do some players lag when they use abilities? That needs per-frame cost, the
   frames that spiked, which events fired in them, and how much of BetterBags' cost the
   instrumentation can see versus what Blizzard's own addon profiler charges to us.
3. What happened, in what order, with what inputs? A call tree aggregates every call of a
   path into one node, so it cannot show that refresh A ran before refresh B, or which bags
   a refresh was asked to read. Order-dependent bugs (the login Recent Items race: a
   single-bag refresh committing before the all-bags one) need the call trace (§4).

`debug/profile.lua` was removed; its single call site (`frames/bag.lua` Draw) is covered by
the automatic `Bag.Draw` / `View.Bind` / `View.Layout` wrappers.

## 1. Files and modules

| File | Module | Role |
|---|---|---|
| `debug/perf/engine.lua` | `Perf` | Wrapping, call tree, call trace, argument capture, coroutine handling, frame clock, session packing. No BetterBags data dependencies. |
| `debug/perf/format.lua` | `PerfFormat` | Decodes saved sessions and call traces; folded stacks; flame layout; number formatting. Pure Lua. |
| `debug/perf/sessions.lua` | `PerfSessions` | `BetterBagsPerfDB` storage, settings, presets, start/stop, capture-next-reload, logout save, trace removal. |
| `frames/flamegraph.lua` | `FlameGraph` | In-game icicle flame graph widget. |
| `frames/tracechart.lua` | `TraceChart` | In-game timeline of a call trace (calls on a time axis, one row per depth). |
| `frames/perfpane.lua` | `PerfPane` | The Performance tab of `/bbdb`. |
| `debug/simulator.lua` | `Simulator` | Fires an event BetterBags listens to at a rate for a duration (§11). |
| `frames/simulatepane.lua` | `SimulatePane` | The Simulate tab of `/bbdb` (§11). |
| `tools/flamegraph/flamegraph.lua` | — | Offline exporter (folded, speedscope, HTML; Chrome trace JSON for Perfetto). |

TOC order (all five TOCs): `engine.lua` and `format.lua` right after `core\boot.lua`, so
every later file can register prototypes at load; `sessions.lua` right after
`core\events.lua`, and `debug\simulator.lua` right after it; `flamegraph.lua`,
`tracechart.lua`, `perfpane.lua` and `simulatepane.lua` right before `frames\debug.lua`.

`format.lua` loads two ways: inside the addon it registers the `PerfFormat` module; run with
`dofile` and no varargs (the offline tool) it returns a plain table of the same functions.
Keep it free of WoW APIs.

## 2. How functions get measured (no timers in business code)

`perf:Start(options)` replaces every function on the selected tables with a wrapper and
`perf:Stop()` puts the originals back. Nothing is wrapped while no capture runs.

- **Modules:** every module from `addon:IterateModules()` (or the preset's list), plus the
  root `addon` table (label prefix `BetterBags`). Labels are `Module.method`.
- **Prototypes:** objects get their methods through `setmetatable(x, {__index = proto})`, so
  wrapping the prototype covers every live instance. Prototypes are registered once at file
  load, right after the table is created:
  `addon:GetModule('Perf'):RegisterPrototype(gridProto, 'GridFrame')`. **Any new prototype
  table must be registered this way.** The name must not equal a module name (labels would
  be ambiguous), hence `GridFrame`, `ListFrame`, `SearchBoxFrame`, and so on.
- **Never wrapped:** functions from any LibStub library (embedded Ace methods), AceAddon
  mixins (the same function object on the root addon and the modules), tables whose `[0]`
  is userdata (WoW frames), and the always-excluded modules `Perf`, `PerfFormat`,
  `PerfSessions`, `PerfPane`, `FlameGraph`, `TraceChart`, `DebugWindow`, `Context`
  (Context's `Get`/`Set` are so frequent the wrappers would dominate).
- **Safety:** only our own Lua tables are written, never Blizzard frames or globals, and
  never `coroutine.*`. Stop restores a field only if it still holds our wrapper, so a method
  replaced during the capture is not clobbered. A wrapper captured during a capture keeps
  working afterwards as a pass-through. While a method is wrapped, `error(msg, 2)` inside it
  reports the wrapper's location instead of the real caller's.
- **Not visible:** `local function` helpers (their time is charged to the calling method),
  and callbacks registered as function references before the capture started (their
  callees are still measured). `perf:Wrap(label, fn)` instruments a local function, at the
  cost of one extra call even when profiling is off. Manual spans: `perf:Enter(label, ...)` /
  `perf:Exit(token)` (`Enter` returns nil when nothing is being recorded; pass the result to
  `Exit` either way). Any arguments after the label are recorded as the span's arguments
  when the trace records arguments.

### Blizzard calls worth measuring

A Blizzard call made inline is charged to the measured function that made it. When one may be
costly, it goes through a function of its own on the root addon, so captures measure it with
no timing code at the call site. `core/hooks.lua` holds them: `addon.SetBlizzardBankType`
(`BankPanel:SetBankType`) and `addon.TriggerItemContextChanged`
(`ItemButtonUtil.TriggerEvent(ItemContextChanged)`), added when every bank tab switch showed
12.6-15 ms of unmeasured time that only these two calls could explain.
`spec/core/measured_blizzard_calls_spec.lua` fails if either is called inline anywhere else.

### Stack roots (the only hand-placed hooks)

These make each stack start at something readable instead of at whichever method happened
to run first. Each is one `perf.active` check when off. Each passes its payload to
`perf:Enter`, so the call trace shows what the entry point was given.

- `core/events.lua`: `[event] NAME` around WoW event dispatch (counts every fire, including
  ones a bucket filter drops; records the event's payload without the event name), `[msg]
  NAME` around message dispatch (records the message's arguments, usually a Context first),
  `[bucket] NAME` around a `BucketEvent` or `GroupBucketEvent` flush (records the collected
  `EventArg[]` it delivers).
- `core/context.lua`: `[script] OnClick` (and so on) around `addon.SetScript` /
  `addon.HookScript` handlers (records the script's arguments: the frame, then e.g. the
  mouse button).
- `debug/simulator.lua`: `[simulate] NAME` around each simulated fire, so the `[event] NAME`
  inside it is told from a real one (§11).
- `data/loader.lua`: `[loaded] item data` around the callbacks the ItemLoader runs once a
  batch of item data has loaded (records the set of bags). That moment usually comes from
  Blizzard's item-load listener, outside any measured call, so without it the refresh it
  requests would appear with no cause; in a trace it shows when each bag's data arrived.

## 3. How time is counted

The engine keeps a calling-context tree. At every enter, exit, yield and resume it charges
the time since the previous transition (`debugprofilestop()`, never `debugprofilestart`,
which resets a timer shared by every addon) to the node on top of the running stack. That
gives exact self time. Time with nothing of ours on the stack (between frames, between
events) is charged to the root and ignored. Per-call inclusive time and the slowest call are
recorded on exit; per-function inclusive time counts recursive calls once.

### Coroutines

Each coroutine has its own stack, detected with `coroutine.running()`.

- A coroutine that yields through `async:Yield()` is paused: `core/async.lua` calls
  `perf:BeforeYield()` before `coroutine.yield()` and `perf:AfterResume()` after it. Paused
  time is never counted (the frame gap between a sweep's harvest and its commit). **Yield
  through `async:Yield`, not `coroutine.yield` directly.**
- On resume, the coroutine's open frames are re-attached under whatever resumed it. A
  refresh unit's harvest therefore appears under the request that started it, and Phase 3
  onward under the next frame's `Refresh._Step` -> `Refresh._Resume`. The re-attached
  nodes are continuations and do not count as new calls.
- A coroutine that finishes hands the cursor back to its resumer. One that yields raw or
  dies with an error is detected when the resumer's next measured call happens; the time in
  between lands on the coroutine's last frame (totals stay exact).

### Errors

An error leaves wrapper frames open. Two repairs: a frame that returns normally pops any
frames left open above it (an error caught by a `pcall` below it), and the profiler's own
`OnUpdate` treats anything still open on the main thread as aborted (no measured call can
be open there legitimately). Aborted frames are counted in `stats.aborted` and per function
in `aborted`, which the Summary lists: an error raised on every cast is itself a lag source.
A message handler that throws is caught by AceEvent's dispatcher, so its `[msg]` frame shows
up here too. Frames opened after an error and before the next repair nest under the dead
frame.

### Frames, spikes, timeline

The engine's own frame (`perf.frame`) has an `OnUpdate` only while capturing. Each tick
closes one frame of measurements: the BetterBags time measured in it goes into a histogram
(<1, 1-5, 5-16, 16-33, 33-50, 50-100, 100+ ms) and the per-frame timeline. If
`frameMetric` is given (PerfSessions passes Blizzard's
`C_AddOnProfiler.GetAddOnMetric(addonName, Enum.AddOnProfilerMetric.LastTime)`) it is
sampled too. Comparing the two series shows how much of BetterBags' cost the wrappers see;
the rest ran in code that is not wrapped (closures, frame scripts, Blizzard template code
running on our frames).

`frameSeries` (a map of name to reader) adds more named per-frame readings, stored as
`timeline.series[name]`. PerfSessions passes Blizzard's `LastTime` for all addons
(`all`, `C_AddOnProfiler.GetOverallMetric`) and for the whole client (`app`,
`GetApplicationMetric`, "the entire application (not just the UI)"), so a slow frame shows
whether the time went to BetterBags, to any addon, or to the client itself. They are read at
the same moment as `frameMetric`, so they pair with frames the same way. Added for the
Dream Breath stutter in raids and Mythic+, where captures showed 100-174 ms frames with
BetterBags under 0.06 ms by both its wrappers and Blizzard's reading, and nothing said where
the rest went.

**Pairing Blizzard's reading with our frames.** `LastTime` is "total time in the most
recent tick", so the reading taken in our `OnUpdate` covers the game tick that just
finished. That tick overlaps our current frame and the one before it: work that runs before
our `OnUpdate` in a tick (events, timers, and so the whole refresh pipeline) only appears in
the **next** frame's reading. Verified on WoW: Forever captures: a refresh's harvest, redraw
and a debug-log flush each matched Blizzard's reading one frame later (12.45/11.99,
39.43/40.96, 1.60/1.63 ms), while opening the bag from a keybinding matched in the same frame
(25.05/24.71). `considerFrame` (`debug/perf/engine.lua`) therefore holds each closed frame
for one more frame, credits each reading to whichever of the two frames' measured time it
is closer to (a frame's figure is the sum of the readings credited to it), and only then
judges it: a frame is a worst frame when our time or its credited reading reaches the
spike threshold, ranked by the larger. The last frame is judged at Stop. The timeline and
histogram keep Blizzard's raw readings by sample time. A credited reading of 0 next to a
large measured time means Blizzard did not charge that work to BetterBags (seen for
refreshes started from a click or from our sort fallback timer; cause unknown).

Before format version 2 the engine ranked frames on the same-frame reading, so a frame in
which BetterBags did nothing was listed as a worst frame for the previous frame's work.
`PerfFormat:WorstFrames(session)` (used by the Performance tab and the offline tool, whose
`--frame n` numbers match the tab) re-pairs those older sessions from their per-frame
timeline with the same rule and drops frames that no longer qualify; entries the timeline
does not cover are shown as captured. `DecodeFrame` returns the credited reading.

### Overhead and allocations

- **Overhead model.** Every wrapped call spends time in the profiler, and the cursor charges
  that time to two places: the part before the entry clock read and after the exit read
  lands on the **caller** (`parentMs`), the rest on the **called function** (`childMs`).
  `calibrate` (on by default) measures both at Start (`perf:Calibrate`): it rotates through
  64 distinct wrapped functions taking 3 arguments, 2,048 calls per run, 5 runs, keeping the
  lowest figure of each side. The rotation matters: the per-call cost depends on how many
  distinct functions and call-tree nodes are in play (table and cache effects), and a single
  hot function underestimated it. Stored as `stats.overheadParentMs` / `overheadChildMs`
  (`overheadPerCallMs` is their sum).
- **Adjustment** (`PerfFormat:Adjust`, display-time, raw numbers are never altered in the
  saved session): a node's adjusted self time is `self - calls*childMs - childCalls*parentMs`
  (its children's calls), clamped at 0; adjusted totals are summed from those. A top-level
  call's caller-side cost lands on the root, which is never measured, so the root is not
  charged. The per-frame timeline is adjusted the same way (`PerfFormat:AdjustTimeline`)
  from each frame's `calls` and `nested` counts (calls made from inside another measured
  call), so a worst frame's adjusted tree and its timeline bar agree exactly. Sessions
  saved before the split calibration (only `overheadPerCallMs`) are split evenly and marked
  approximate; sessions without calibration are not adjusted.
- **Measured accuracy** (offline, `test.lua` dump, PUC Lua 5.1, 60 profiled vs 60 unprofiled
  refresh sweeps, 9 runs): raw sweep time was about +300% of the real cost; adjusted it was
  +2% to +14% (typically about +5%), always on the high side. Phases made of many tiny
  calls are less accurate (`Phase6_EnrichData`: +4% to +31%). The old single-function,
  no-argument calibration left +20% to +39%. Accuracy inside the game client is not
  verifiable offline; the calibration itself runs in the client, so it measures that
  client's cost.
- **Limits.** The adjustment removes the profiler's average cost, not its side effects on
  caches, so functions whose raw time is mostly overhead (more than 75%) are greyed out in
  the Functions view and flagged in the flame graph tooltip as rough estimates. Blizzard's
  addon profiler numbers include the profiler's cost and are compared raw. Allocations are
  not adjusted. To measure a hot small function precisely, exclude its callees or wrap a
  span around a loop instead.
- `trackAllocations` charges growth of `collectgarbage("count")` to the running node. A
  garbage collection step during a call makes that call's number low (collections are
  totalled separately in `gcFreedKB`). `pauseGC` stops the collector for the capture
  (`collectgarbage("stop")`, restarted on Stop and on logout) to make the numbers exact.
- Past `maxNodes` distinct paths, new paths fold into one `[node limit reached]` node.

## 4. Call trace

With `trace` on (the default in PerfSessions), every measured call is also recorded in the
order it started. The call tree says how much; the trace says what happened when.

### Call records

- **One record per call**, six numbers: start (microseconds after the previous call's start
  in its chunk; 0 for a chunk's first call, whose absolute start is in `chunkStarts`), node
  id (the call-tree node, which gives the function and its call path), argument set id,
  duration (wall microseconds, -1 while running), return-value set id, flags.
- **Chunks.** Records are kept as numbers in a chunk of `traceChunkSize` (4096) calls; once
  every call of a full chunk has ended, the chunk is packed into one comma-separated string
  and its numeric table is reused. A call that is still running (a coroutine paused across
  frames) keeps its chunk unpacked until it ends. `chunkStarts`/`chunkEnds` let a time
  window skip whole chunks.
- **Node ids are creation order.** From format version 3 a node's id is the order it was
  created in (still parents first), so a record can name its node the moment it starts,
  before the tree is final. The decoder sorts each node's children by name for version 3,
  which keeps the flame graph's left-to-right order as before.
- **Coroutines.** A call that pauses (its coroutine yielded through `async:Yield`) gets a
  provisional end where it paused; when it resumes the end is reopened and a segment
  `callIndex,pausedAtUs,resumedAtUs,nodeId` is recorded (the node it continued under, since
  a resumed coroutine is re-attached under whatever resumed it). One call, several slices.
  `call.wall` counts the pauses, `call.incl` does not.
- **Flags.** `1` cut short by an error (left open when an outer call returned, or when the
  frame closed with it still open on the main thread, or its coroutine died), `2` still
  running at Stop, `4` paused at Stop (with `2`; ends where it paused).
- **Frames.** Each frame boundary (`_OnFrame`) records its time in `frameEnds`, so any call
  maps to its frame (`trace:FrameOf`) and any frame to its time span (`trace:FrameBounds`).

### Stop when full

`traceMaxCalls` (default 1,000,000) bounds the trace. The call that would exceed it is not
recorded and the whole capture **freezes** at that moment: nothing more is recorded in the
tree, the frames or the trace, so all three end at the same instant and nothing is dropped
or truncated from either end. Calls in flight keep running normally (the wrappers pass
through) and are saved as unfinished. On the next frame the engine calls
`onAutoStop('traceFull')` once; PerfSessions stops and saves the session with
`stats.stopReason = 'traceFull'` (`'maxDuration'` for the duration limit). `perf:IsActive()`
stays true until Stop, so nothing can start a second capture in between.

### Arguments and return values (deduplicated)

With `traceArgs` on, each call's arguments and return values are recorded:

- **Each distinct value is described once.** A value becomes text the first time it is seen
  and is stored in `trace.values` (index = value id). Numbers and strings are found by value,
  so a repeated `3` or `"Backpack"` costs one lookup.
- **Each distinct argument list is stored once.** A list is the value ids joined by commas,
  stored in `trace.sets` (index = set id); lists are found through a trie keyed by value id,
  so a repeated list allocates nothing. A call holds only the set id. Measured over 40
  refresh sweeps of the `test.lua` dump: 96,320 calls, 5,561 distinct argument lists, 756
  distinct values.
- **Mutable tables are copied at call time.** A plain table or a Context is described as it
  is when the call is made (ItemData and request tables are mutated in place across sweeps,
  so a reference would show later values). Identity-like tables are named once for their
  lifetime: modules (`<Items>`), prototypes (`<GridFrame prototype>`), prototype instances
  (`<GridFrame #3>`, numbered in first-seen order), frames (`frame BetterBagsBagBackpack`),
  ItemData (`item 0_1 #1234`, `empty 0_2`, `gap 0_3`). A Context is `ctx <event> {keys}`
  without its `event`/`events` keys. Plain tables show up to 8 fields, sorted, two levels
  deep, strings up to 64 characters.
- **Secret values are never read.** Each value is checked with `canaccessvalue` (when the
  client has it; Blizzard's own `Dump.lua` does the same) and a value the addon may not
  access is recorded as `<secret number>` (its type only).
- **Describing never breaks the call.** It runs in a `pcall`; a value that cannot be
  described records `<arguments could not be described>` and the call runs normally.

### The virtual clock

Describing values and packing chunks takes real time that must not be charged to any
BetterBags function. Both run between two clock reads and add the difference to
`excluded`; every measurement uses `clock() - excluded`. So call times, self times, frame
times and the overhead calibration (which runs with the capture's tracing settings) all
leave it out; `stats.excludedMs` reports the total, and the Summary states it. The game
frame does take that long, so Blizzard's addon profiler numbers include it.

### Cost and size (measured)

Offline, PUC Lua 5.1, `test.lua` dump, 40 backpack sweeps of 2,408 calls each, CPU per
sweep: unprofiled 0.67 ms; profiled 2.79 ms; traced 4.82 ms; traced with arguments 12.83 ms
(of which about 7.9 ms is describing arguments, excluded from every measurement). Saved
size: about 13 bytes per call for the trace and about 4 more for arguments, so a million
calls is roughly 13-17 MB of SavedVariables. Turn arguments off when chasing frame-time
spikes that the extra real time would distort; remove traces once read (§7).

### Reading a trace

`perfFormat:OpenTrace(session)` returns an accessor (nil for a session without a trace):
`Count`, `Get(index)` (start, finish, wall, incl, name, depth, args/returns set ids, flags,
segments), `Text(setId)`, `Slices(fromMs, toMs, minMs)` (what ran in a window, one slice per
uninterrupted stretch of a call), `FrameOf`, `FrameBounds`, `FrameCount`, `Matches`, and
`Scan(query, from, budget, out)`, which searches names, arguments and return values a budget
of calls at a time (matches cached per node and per set) so a million-call search can be
spread over frames. Chunks are decoded on demand and the last 8 are kept.
`perfFormat:TraceBytes(session)` estimates a trace's saved size.

## 5. Storage (`BetterBagsPerfDB`)

A separate SavedVariable (declared in all five TOCs next to `BetterBagsDB`), not the AceDB
profile, so profile reset/copy/switch never touches perf data.

```lua
BetterBagsPerfDB = {
  version = 1,
  settings = { ... },        -- see §6
  sessions = { session, ... },  -- oldest first; trimmed to settings.maxSessions
  nextId = n,
  armNextReload = true|nil,  -- one-shot, consumed at load
}
```

Whether a capture is running is never saved: every load starts with profiling off.
"Capture next reload" sets `armNextReload`; `core/init.lua` calls
`perfSessions:StartIfArmed()` right after `events:Init()` (before every other `Init`), which
clears the flag and starts a capture with reason `startup`. The switch applies to the next
load, a full relaunch as much as a `/reload`; the first `PLAYER_ENTERING_WORLD`
(`isInitialLogin`, `isReloadingUi`) relabels the capture `login` or `reload`
(`perfSessions:OnEnteringWorld`); later loading screens and manual captures (`manual`) keep
their label. `PerfFormat:ReasonLabel` / `ReasonPhrase` turn the reason into the session list's
tag and the Summary's wording, in the Performance tab and the offline tool alike. Sessions
saved before this say `reload` for both kinds of load. A capture still running on
`PLAYER_LOGOUT` is stopped and saved.

### Session format (version 3)

Times are integer microseconds, memory integer bytes. Nodes are packed strings so the file
stays small and loads fast.

```lua
session = {
  id, formatVersion = 3,
  meta = { reason, startedAt, stoppedAt, character, realm, gameVersion, gameBuild, tocVersion,
           flavor, addonVersion, preset, blizzardStart, blizzardStop, memoryStartKB,
           memoryStopKB, luaMemoryStartKB, luaMemoryStopKB, backpackItems, bankItems,
           restrictionsStart|nil, restrictionsStop|nil,  -- { Combat = "Active", Map = "Inactive", ... } (C_RestrictedActions)
           instanceStart|nil, instanceStop|nil,          -- { name, instanceType, difficultyID, difficultyName } (GetInstanceInfo)
           topAddonsStart|nil, topAddonsStop|nil,        -- { { name, ms }, ... }: the 10 slowest single ticks since startup (PeakTime)
           simulation|nil },                             -- { event, rate, duration, payload, openBags } for reason "simulate"
  options = { the engine options used, including trace, traceArgs, traceMaxCalls },
  stats = { durationMs, instrumentedMs, calls, frames, activeFrames, worstFrameMs, aborted,
            nodeCount, droppedNodes, wrappedFunctions, overheadPerCallMs, overheadParentMs|nil,
            overheadChildMs|nil, allocatedKB, gcFreedKB, excludedMs,
            traceCalls|nil, stopReason|nil ("traceFull"|"maxDuration"), traceRemoved|nil },
  names = { "[all]", "[event] BAG_UPDATE", ... },
  nodes = { "parentId,nameId,selfUs,calls,maxUs,allocBytes", ... },  -- node 1 is [all]; ids are creation order, parents first
  functions = { "nameId,calls,inclUs,maxUs", ... },
  aborted = { "nameId,count", ... },  -- calls an error cut short, per function
  histogram = { bounds = {1,5,16,33,50,100}, counts = {7 numbers}, blizzard = {7}|nil },
  worst = { { frame, atUs, us, blizzardUs|nil, nodes = { "nodeId,selfUs,calls,allocBytes", ... } }, ... },
           -- blizzardUs: the readings credited to this frame (version 1: the same-frame reading)
  timeline = { ours = "us,us,...", blizzard = "us,..."|nil,
               calls = "n,n,...", nested = "n,n,...",  -- per-frame measured calls, and those with a measured caller
               series = { all = "us,...", app = "us,..." }|nil },  -- §3: Blizzard's time for all addons and the whole client
  trace = nil | {                -- §4; absent when tracing was off or the trace was removed
    chunkSize = 4096, calls = n, full = true|nil, args = true|nil,
    chunks = { "startDeltaUs,nodeId,argSet,durUs,retSet,flags,...", ... },  -- chunkSize records each
    chunkStarts = "us,...", chunkEnds = "us,...",   -- first start / latest end per chunk
    segments = "callIndex,pausedAtUs,resumedAtUs,nodeId,...",
    frameEnds = "us,...",
    values = { "nil", "true", "false", "<Items>", "3", ... },  -- value id -> text
    sets = { "4,5", "", ... },                                  -- set id -> value ids
  },
}
```

A worst frame lists only the nodes that ran in it; `PerfFormat:DecodeFrame` fills in their
ancestors with zero cost, and always returns a root (a frame listed only for Blizzard's
reading may have no measured nodes). Any change to this format bumps `formatVersion` and
updates `format.lua`, the tool, and their specs together. Version 2 changed only the meaning
of `worst[].blizzardUs` (see "Pairing Blizzard's reading"); version 1 sessions are re-paired
when decoded. Version 3 made node ids creation order and added `trace`; older sessions
decode as before (their children keep id order, which was name order). The overhead fields
(`overheadParentMs`, `overheadChildMs`, `timeline.calls`, `timeline.nested`) are optional
additions read only when present.

`perfSessions:RemoveTrace(id)` and `RemoveAllTraces()` delete `session.trace` (the bulk of a
session's size) and keep everything else, marking `stats.traceRemoved`.

## 6. Settings and presets

All settings are tweakable in the Performance tab's Settings window (a Form, created on
first open) and clamped by `PerfSessions.LIMITS`:

| Setting | Default | Range |
|---|---|---|
| `preset` | `full` | `full` (every module and prototype), `pipeline` (event dispatch through the draw) |
| `excludedModules` | `Debug, Localization` | comma-separated module or prototype names |
| `spikeThresholdMs` | 16 | 1-1000 |
| `worstFrames` | 10 | 0-50 |
| `maxDurationSec` | 0 (never) | 0-3600 |
| `maxSessions` | 10 | 1-50 (lowering it trims immediately) |
| `maxNodes` | 5000 | 500-50000 |
| `timelineFrames` | 18000 | 0-216000 |
| `trackAllocations` | false | |
| `pauseGC` | false | |
| `calibrate` | true | measures per-call profiler overhead at Start (§3) |
| `traceCalls` | true | record every call in order (§4) |
| `traceArgs` | true | also record arguments and return values (§4) |
| `traceMaxCalls` | 1,000,000 | 10,000-2,000,000; the capture stops on its own when the trace is full |

The pipeline preset lists module and prototype names; `spec/debug/perf_sessions_spec.lua`
scans the source tree and fails if a preset names something that does not exist.

## 7. Performance tab (`/bbdb`)

Fourth tab of the debug window. Start/Stop Capture, "Capture next reload", a live status
line (with the number of calls traced, or that the trace is full and the capture is
stopping), the saved sessions (newest first, marked `+trace <size>` when they carry a
trace; Delete, Delete All, Remove Trace for the selected session, and All Traces, the bulk
deletes behind a confirmation), and six views of the selected session: Flame Graph (search
highlights matches and totals them; time or allocations), Functions (sortable by every
column), Frames (the per-frame timeline with Blizzard's numbers behind ours, the worst
frames, and the selected frame's flame graph), Calls, Timeline, and Summary. A session
stopped from anywhere is selected automatically.

- **Calls** lists every traced call in start order, 100 per page: when it started, its
  frame, how long it took (pauses excluded; `!` = cut short by an error, `...` = unfinished),
  the function indented by call depth, and `(arguments) -> returned`. **Find** (Enter)
  keeps only calls whose function name, arguments or return values contain the text; the
  search scans 50,000 calls per frame from the view's `OnUpdate` (`trace:Scan`), showing its
  progress, so a million-call trace never freezes the game. Clicking a call shows it in full
  below the list; **Show in Timeline** jumps to it.
- **Timeline** shows a strip of every frame's measured time (click a column to show that
  frame), `< Frame` / `Frame >` / `Whole Capture` buttons, and the `TraceChart` widget: the
  calls of the shown stretch on a time axis, one row per call depth, colored like the flame
  graph. The mouse wheel zooms around the cursor, Shift+wheel scrolls rows, clicking a call
  zooms to it, right-click zooms out; hovering shows the call's start, frame, duration,
  pauses, state, arguments and return values. Slices narrower than a pixel are skipped, and
  at most 2,000 bars are drawn, all pooled textures on one canvas (no frame per bar).
- The Summary reports the trace (calls, whether it has arguments, its saved size), why the
  capture stopped on its own, and how much profiler time was excluded (§4). For sessions that
  carry them it also says what was simulated (§11), where the player was at the start and the
  end, which addon restrictions were active then, the slowest frame for the whole client with
  what all addons and BetterBags (measured and per Blizzard) took in it, and the slowest
  addons since the client started.

**Subtract overhead** (checkbox next to the view buttons, on by default, disabled for
sessions without a calibration) switches every time in the tab between adjusted and raw:
flame graph bars and tooltips (which then also show the raw total and the overhead share),
the Functions columns Total/Self/Avg (sorting follows; Max stays raw, it is a single call),
the worst-frame list and frame flame graph, and the timeline. The Summary always gives the
calibration and the time with and without overhead. Call trace times are always raw: each
is one call.

The flame graph widget draws pooled textures on one canvas frame and hit-tests the cursor
against the layout; it never creates a frame per bar. Left-click zooms in, right-click zooms
out, the mouse wheel scrolls deep trees.

## 8. Offline flame graphs and traces

```
lua tools/flamegraph/flamegraph.lua <WTF/Account/<ACCOUNT>/SavedVariables/BetterBags.lua> [--list] [--session id|latest] [--frame n] [--metric time|alloc] [--raw] [--out dir]
lua tools/flamegraph/flamegraph.lua <SavedVariables/BetterBags.lua> --trace [--session id|latest] [--from ms] [--to ms] [--find text] [--out dir]
```

Times are overhead-adjusted by default when the session has a calibration; `--raw` keeps
the measured times. Writes `betterbags-<id>[-frame<n>][-alloc][-raw].folded` (collapsed stacks for `flamegraph.pl`,
`inferno`, speedscope), `.speedscope.json` (a speedscope "sampled" profile, stacks root
first), and `.html` (a single self-contained page: click to zoom, right-click to zoom out,
search). The SavedVariables file is run in an empty environment. See
`tools/flamegraph/README.md`.

`--trace` writes `betterbags-<id>.trace.json` instead: Chrome trace-event JSON that
Perfetto (ui.perfetto.dev) and `chrome://tracing` open. Every call is a complete (`X`)
event (a call that paused gets one per stretch, the later ones marked `continued`) carrying
its call number, arguments, return values and state, plus a `BetterBags time per frame`
counter track. `--from`/`--to` keep the calls that ran in that stretch of the capture
(milliseconds), `--find` the calls whose name, arguments or return values contain the text.
Calls are decoded and written one at a time (`M.WriteChromeTrace`), so a million-call trace
never sits in memory as tables. `--list` marks sessions that carry a trace.

## 9. Using it for the motivating problems

- **Data -> draw path:** arm "Capture next reload" to see login, or start a capture, open
  and close bags, loot, sort, then stop. The flame graph shows each `[event]` root, the
  refresh queue (`Refresh.RequestUpdate` / `_Step` / `_Resume`), each `Items.Phase*`, and the
  render (`Bag.Draw`, `View.Bind`, `View.Layout`, `GridFrame.*`, `Section.*`, `Item.*`).
- **Lag when using abilities:** start a capture with the bags open, use the abilities that
  lag, stop. Check the Frames view: the spikes, which `[event]` roots fired in them
  (`[event] BAG_UPDATE_COOLDOWN` and its `[bucket]` flush into `Bag.OnCooldown` ->
  `Item.UpdateCooldown`, `[event] BAG_UPDATE`, `[event] TOOLTIP_DATA_UPDATE`, ...), and
  whether Blizzard's number is far above ours (the cost is in code the wrappers cannot see).
- **What ran, in what order, with what inputs:** arm "Capture next reload" and relaunch
  (a full relaunch, not `/reload`, to see a cold item cache), or capture around the action.
  In Calls, Find `RequestUpdate` to list every refresh request with its `bags`/`wipe`
  argument in order, Find `Phase1_DetermineBags` to see which bags each sweep read (its
  return value), and Find `MarkItemAsNew` to see what was marked recent. Show in Timeline
  places each one in its frame among the calls around it.

## 10a. Addon restrictions in captures

Patch 12.x applies addon restrictions (`C_RestrictedActions`, `Enum.AddOnRestrictionType`:
Combat, Encounter, ChallengeMode, PvPMatch, Map ("a map that applies addon restrictions":
dungeons and raids), Chat); while one is active, guarded APIs and events return secret
values (`SecretPredicatesDocumentation.lua`). A capture records each type's state at the start
and the end (`perfSessions:RestrictionStates()`, `Inactive`/`Activating`/`Active`), and
PerfSessions listens to `ADDON_RESTRICTION_STATE_CHANGED` where the client has it
(`C_EventUtils.IsEventValid`), so the trace shows every change as an
`[event] ADDON_RESTRICTION_STATE_CHANGED(type, state)` call at the moment it happened. The
Simulate tab shows the live state.

## 10b. Collections in captures

The pet journal, the toy box and the appearance collection load on their own schedule at login,
and the search fields that read them (pet counts, collected appearances) need to know when. A first
login capture could not say: the profiler records only events BetterBags listens to, and BetterBags
listened to none of theirs. PerfSessions now listens, where the client has them
(`C_EventUtils.IsEventValid`), to `PerfSessions.COLLECTION_EVENTS`: `PET_JOURNAL_LIST_UPDATE`,
`NEW_PET_ADDED`, `PET_JOURNAL_PET_DELETED`, `TRANSMOG_COLLECTION_UPDATED`,
`TRANSMOG_COLLECTION_SOURCE_ADDED`, `TRANSMOG_COLLECTION_SOURCE_REMOVED`, `NEW_TOY_ADDED`,
`TOYS_UPDATED` (each in the client's API documentation). Each fire is an `[event]` call in the
trace, and while a capture runs it holds a `[collections]` call whose argument is
`perfSessions:CollectionCounts()`: `pets`, `petsOwned` (`C_PetJournal.GetNumPets`, as
Blizzard_PetCollection.lua counts them), `toys`, `toysLearned` (the toy box's displayed totals, as
Blizzard_ToyBox.lua counts them), `transmogSources` (`C_TransmogCollection.GetNumTransmogSources`);
nothing is read while no capture runs. The counts at the start and the end are in
`meta.collectionsStart` / `collectionsStop` (nil on a client with none of these APIs).
Coverage: `spec/debug/perf_sessions_spec.lua` (counts at start and stop, missing APIs, each event
traced with its counts, nothing read while idle, no event a client lacks); 8 mutations, all caught
(one led to the missing-event test).

## 10. Testing

- Engine (`spec/debug/perf_engine_spec.lua`): a fake clock (`perf:SetClock`) makes timings
  exact; tests pass `modules = {...}, prototypes = {}, includeRoot = false, calibrate = false`
  so only test modules are wrapped.
- Sessions, Performance tab, and debug window specs load fresh `Context` and `Events`
  modules with `LoadFreshBetterBagsModule` (`spec/helpers/addon_loader.lua`), because
  earlier spec files stub or patch those shared modules without restoring them.
- `spec/setup.lua` loads `debug/perf/engine.lua` for every spec, since files register
  prototypes with it at load.
- `spec/debug_dump_harness_spec.lua` profiles the real refresh pipeline over the `test.lua`
  dump, checks the results match an unprofiled run, and exports the session with the tool.
  A second test traces the same sweep with arguments and checks the results are unchanged,
  the trace holds exactly the call tree's calls, each argument list is stored once, and the
  Perfetto export has one event per call. (The harness stubs `async:Yield`, so pause slices
  are covered by the trace spec, not here.)
- Call trace (`spec/debug/perf_trace_spec.lua`): start order and times, chunk boundaries,
  a yielding call kept as one call with a slice per stretch, the three ways a call is cut
  short or left unfinished, stop-when-full (nothing dropped, `onAutoStop('traceFull')`),
  frame mapping, argument and return capture, deduplication, table/frame/Context/ItemData/
  prototype descriptions, copying a mutable argument at call time, the virtual clock,
  `canaccessvalue`, an undescribable argument, `Enter` payloads, and `Scan`.
- Entry-point payloads: `spec/events_spec.lua` and `spec/context_spec.lua` ("with a call
  trace that records arguments"). Sessions: `spec/debug/perf_sessions_spec.lua` (trace
  defaults and limits, stop when full, `RemoveTrace`/`RemoveAllTraces`). Views:
  `spec/frames/tracechart_spec.lua` and the "call trace" block of
  `spec/frames/perfpane_spec.lua`. Export: `spec/tools/flamegraph_spec.lua` ("call traces").
- The pane's trace tests find the first traced test call instead of assuming its index:
  `StartCapture` sends `perf/StateChanged`, and AceEvent's registry keeps every earlier
  test's listener, so the trace starts with one `[msg]` call per listener.
- Lua 5.1 allows at most 60 upvalues per function. The engine keeps its hot state in file
  upvalues (the wrappers read them on every call), so a function that touches many of them
  must be split (`resetState` is `resetTree` + `resetFrames` + `resetTrace`). Check with
  `~/.local/lua51/bin/luac -p debug/perf/engine.lua`.
- Mocks added from Blizzard's API docs: `debugprofilestop`, `Enum.AddOnProfilerMetric`,
  `UpdateAddOnMemoryUsage`/`GetAddOnMemoryUsage`, `date`, the Button/CheckButton
  `Enable`/`Disable`/`IsEnabled`/`LockHighlight`/`UnlockHighlight`/`SetChecked`/`GetChecked`
  and `IsVisible` widget methods, and the EditBox `SetFocus`/`ClearFocus`/`HasFocus`
  methods. `C_AddOnProfiler` is deliberately left undefined so code must cope with clients
  that lack it; specs install it when needed. `canaccessvalue` is left undefined too (the
  engine checks for it); the trace spec installs one to test secret values.

## 11. The event simulator (`debug/simulator.lua`, the Simulate tab)

`Simulator:Start(ctx, { event, rate, duration, payload?, payloadCount?, payloadText?, openBags?,
capture? })` fires one of the WoW events BetterBags listens to, `rate` times a second for
`duration` seconds (clamped to `RATE` 1-240 and `DURATION` 1-120), through BetterBags' own
dispatcher: it calls `events._eventMap[event].fn(event, payload...)`, the function the game's
event calls, so every handler, bucket filter and profiler root runs exactly as for a real
fire, handlers getting the event's name before the payload. Its own frame's `OnUpdate` drives
it; a slow frame catches up with every fire due in it, as a burst of real events would.

- `GetEvents()` lists `events._eventMap`'s events, sorted, without `ADDON_LOADED`,
  `PLAYER_LOGIN`, `PLAYER_LOGOUT` and `PLAYER_ENTERING_WORLD` (firing those again would rerun
  or tear down BetterBags' setup); `Start` refuses anything else, or a second run.
- `openBags` shows the backpack first: BetterBags' cooldown refresh only runs while it is
  shown. `capture` starts a profiler capture with reason `simulate` and the run's settings in
  `meta.simulation`, and stops it when the run ends; a capture already running is left alone.
- Each fire is wrapped in a `[simulate] EVENT` span (§2).
- What it cannot do: the game does not deliver a simulated event to other addons or to
  Blizzard's frames, and it creates no addon restriction. Run it inside a dungeon or raid to
  test under the restrictions those apply.
- `ParsePayload(text)` reads comma-separated numbers, `true`, `false`, `nil` and strings.

The Simulate tab (`frames/simulatepane.lua`, fifth tab of `/bbdb`) lists the events, takes the
rate, duration and payload, "Open the bags first" and "Capture with the profiler" (both on),
and shows the run's progress and the active addon restrictions. **Dream Breath test** fills in
`BAG_UPDATE_COOLDOWN` at 22 a second for 30 seconds: the busiest second in a user's capture
while casting Dream Breath (22 fires; 12.1 a second on average).

Coverage: `spec/debug/simulator_spec.lua`, `spec/frames/simulatepane_spec.lua`,
`spec/frames/debug_window_spec.lua` (the tab), `spec/debug/perf_sessions_spec.lua` (restrictions,
instance, frame series, top addons, the simulation metadata, the `simulate` reason),
`spec/debug/perf_engine_spec.lua` (frame series), `spec/frames/perfpane_spec.lua` (the
Summary's lines).
