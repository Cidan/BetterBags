# Performance Profiler (`debug/perf/`, Performance tab, `tools/flamegraph`)

BetterBags has a built-in instrumenting profiler. It is off by default and costs nothing
while off. A capture records where BetterBags spends its time (a call tree with exact self
time), how much each frame costs, and the frames that spiked; the result is saved to
SavedVariables and can be browsed in-game as a flame graph or exported offline.

It exists to answer two questions the old `debug:StartProfile`/`EndProfile` pair (one
hand-placed timer that printed a number to the debug log) could not:

1. Where does the whole data -> draw path spend its time (event, refresh queue, every
   sweep phase, the render)?
2. Why do some players lag when they use abilities? That needs per-frame cost, the
   frames that spiked, which events fired in them, and how much of BetterBags' cost the
   instrumentation can see versus what Blizzard's own addon profiler charges to us.

`debug/profile.lua` was removed; its single call site (`frames/bag.lua` Draw) is covered by
the automatic `Bag.Draw` / `View.Render` wrappers.

## 1. Files and modules

| File | Module | Role |
|---|---|---|
| `debug/perf/engine.lua` | `Perf` | Wrapping, call tree, coroutine handling, frame clock, session packing. No BetterBags data dependencies. |
| `debug/perf/format.lua` | `PerfFormat` | Decodes saved sessions; folded stacks; flame layout; number formatting. Pure Lua. |
| `debug/perf/sessions.lua` | `PerfSessions` | `BetterBagsPerfDB` storage, settings, presets, start/stop, capture-next-reload, logout save. |
| `frames/flamegraph.lua` | `FlameGraph` | In-game icicle flame graph widget. |
| `frames/perfpane.lua` | `PerfPane` | The Performance tab of `/bbdb`. |
| `tools/flamegraph/flamegraph.lua` | — | Offline exporter (folded, speedscope, HTML). |

TOC order (all five TOCs): `engine.lua` and `format.lua` right after `core\boot.lua`, so
every later file can register prototypes at load; `sessions.lua` right after
`core\events.lua`; `flamegraph.lua` and `perfpane.lua` right before `frames\debug.lua`.

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
  `PerfSessions`, `PerfPane`, `FlameGraph`, `DebugWindow`, `Context` (Context's `Get`/`Set`
  are so frequent the wrappers would dominate).
- **Safety:** only our own Lua tables are written, never Blizzard frames or globals, and
  never `coroutine.*`. Stop restores a field only if it still holds our wrapper, so a method
  replaced during the capture is not clobbered. A wrapper captured during a capture keeps
  working afterwards as a pass-through. While a method is wrapped, `error(msg, 2)` inside it
  reports the wrapper's location instead of the real caller's.
- **Not visible:** `local function` helpers (their time is charged to the calling method),
  and callbacks registered as function references before the capture started (their
  callees are still measured). `perf:Wrap(label, fn)` instruments a local function, at the
  cost of one extra call even when profiling is off. Manual spans: `perf:Enter(label)` /
  `perf:Exit(token)` (`Enter` returns nil when off; pass the result to `Exit` either way).

### Stack roots (the only hand-placed hooks)

These make each stack start at something readable instead of at whichever method happened
to run first. Each is one `perf.active` check when off.

- `core/events.lua`: `[event] NAME` around WoW event dispatch (counts every fire, including
  ones a bucket filter drops), `[msg] NAME` around message dispatch, `[bucket] NAME` around
  a `BucketEvent` or `GroupBucketEvent` flush.
- `core/context.lua`: `[script] OnClick` (and so on) around `addon.SetScript` /
  `addon.HookScript` handlers.

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
sampled too. A frame where either number reaches the spike threshold keeps its own call
tree; the N worst are saved. Comparing the two series shows how much of BetterBags' cost
the wrappers see; the rest ran in code that is not wrapped (closures, frame scripts,
Blizzard template code running on our frames).

### Overhead and allocations

- `calibrate` times 1,000 empty wrapped calls at Start; `stats.overheadPerCallMs` lets the
  summary estimate how much of the measured time is the profiler itself. Small functions
  called very often look heavier than they are; skip them with the exclude list.
- `trackAllocations` charges growth of `collectgarbage("count")` to the running node. A
  garbage collection step during a call makes that call's number low (collections are
  totalled separately in `gcFreedKB`). `pauseGC` stops the collector for the capture
  (`collectgarbage("stop")`, restarted on Stop and on logout) to make the numbers exact.
- Past `maxNodes` distinct paths, new paths fold into one `[node limit reached]` node.

## 4. Storage (`BetterBagsPerfDB`)

A separate SavedVariable (declared in all five TOCs next to `BetterBagsDB`), not the AceDB
profile, so profile reset/copy/switch never touches perf data.

```lua
BetterBagsPerfDB = {
  version = 1,
  settings = { ... },        -- see §5
  sessions = { session, ... },  -- oldest first; trimmed to settings.maxSessions
  nextId = n,
  armNextReload = true|nil,  -- one-shot, consumed at load
}
```

Whether a capture is running is never saved: every load starts with profiling off.
"Capture next reload" sets `armNextReload`; `core/init.lua` calls
`perfSessions:StartIfArmed()` right after `events:Init()` (before every other `Init`), which
clears the flag and starts a capture with reason `reload`. A capture still running on
`PLAYER_LOGOUT` is stopped and saved.

### Session format (version 1)

Times are integer microseconds, memory integer bytes. Nodes are packed strings so the file
stays small and loads fast.

```lua
session = {
  id, formatVersion = 1,
  meta = { reason, startedAt, stoppedAt, character, realm, gameVersion, gameBuild, tocVersion,
           flavor, addonVersion, preset, blizzardStart, blizzardStop, memoryStartKB,
           memoryStopKB, luaMemoryStartKB, luaMemoryStopKB, backpackItems, bankItems },
  options = { the engine options used },
  stats = { durationMs, instrumentedMs, calls, frames, activeFrames, worstFrameMs, aborted,
            nodeCount, droppedNodes, wrappedFunctions, overheadPerCallMs, allocatedKB, gcFreedKB },
  names = { "[all]", "[event] BAG_UPDATE", ... },
  nodes = { "parentId,nameId,selfUs,calls,maxUs,allocBytes", ... },  -- node 1 is [all]; parents come first
  functions = { "nameId,calls,inclUs,maxUs", ... },
  aborted = { "nameId,count", ... },  -- calls an error cut short, per function
  histogram = { bounds = {1,5,16,33,50,100}, counts = {7 numbers}, blizzard = {7}|nil },
  worst = { { frame, atUs, us, blizzardUs|nil, nodes = { "nodeId,selfUs,calls,allocBytes", ... } }, ... },
  timeline = { ours = "us,us,...", blizzard = "us,..."|nil },
}
```

A worst frame lists only the nodes that ran in it; `PerfFormat:DecodeFrame` fills in their
ancestors with zero cost. Any change to this format bumps `formatVersion` and updates
`format.lua`, the tool, and their specs together.

## 5. Settings and presets

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
| `calibrate` | true | |

The pipeline preset lists module and prototype names; `spec/debug/perf_sessions_spec.lua`
scans the source tree and fails if a preset names something that does not exist.

## 6. Performance tab (`/bbdb`)

Fourth tab of the debug window. Start/Stop Capture, "Capture next reload", a live status
line, the saved sessions (newest first; Delete, and Delete All behind a confirmation), and
four views of the selected session: Flame Graph (search highlights matches and totals them;
time or allocations), Functions (sortable by every column), Frames (the per-frame timeline
with Blizzard's numbers behind ours, the worst frames, and the selected frame's flame
graph), and Summary. A session stopped from anywhere is selected automatically.

The flame graph widget draws pooled textures on one canvas frame and hit-tests the cursor
against the layout; it never creates a frame per bar. Left-click zooms in, right-click zooms
out, the mouse wheel scrolls deep trees.

## 7. Offline flame graphs

```
lua tools/flamegraph/flamegraph.lua <WTF/Account/<ACCOUNT>/SavedVariables/BetterBags.lua> [--list] [--session id|latest] [--frame n] [--metric time|alloc] [--out dir]
```

Writes `betterbags-<id>[-frame<n>][-alloc].folded` (collapsed stacks for `flamegraph.pl`,
`inferno`, speedscope), `.speedscope.json` (a speedscope "sampled" profile, stacks root
first), and `.html` (a single self-contained page: click to zoom, right-click to zoom out,
search). The SavedVariables file is run in an empty environment. See
`tools/flamegraph/README.md`.

## 8. Using it for the two motivating problems

- **Data -> draw path:** arm "Capture next reload" to see login, or start a capture, open
  and close bags, loot, sort, then stop. The flame graph shows each `[event]` root, the
  refresh queue (`Refresh.RequestUpdate` / `_Step` / `_Resume`), each `Items.Phase*`, and the
  render (`Bag.Draw`, `View.Render`, `GridFrame.*`, `Section.*`, `Item.*`).
- **Lag when using abilities:** start a capture with the bags open, use the abilities that
  lag, stop. Check the Frames view: the spikes, which `[event]` roots fired in them
  (`[event] BAG_UPDATE_COOLDOWN` and its `[bucket]` flush into `Bag.OnCooldown` ->
  `Item.UpdateCooldown`, `[event] BAG_UPDATE`, `[event] TOOLTIP_DATA_UPDATE`, ...), and
  whether Blizzard's number is far above ours (the cost is in code the wrappers cannot see).

## 9. Testing

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
- Mocks added from Blizzard's API docs: `debugprofilestop`, `Enum.AddOnProfilerMetric`,
  `UpdateAddOnMemoryUsage`/`GetAddOnMemoryUsage`, `date`, and the Button/CheckButton
  `Enable`/`Disable`/`IsEnabled`/`LockHighlight`/`UnlockHighlight`/`SetChecked`/`GetChecked`
  and `IsVisible` widget methods. `C_AddOnProfiler` is deliberately left undefined so code
  must cope with clients that lack it; specs install it when needed.
