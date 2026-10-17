# Render Recorder (`debug/renderrecorder.lua`)

Records how BetterBags' windows render, for layout and sizing bugs the profiler cannot show
(data-driven.md). The profiler records which functions ran, with their arguments shortened to 64
characters; it cannot show where every section and item button of a bag ended up after each
render. Added for a report of a bank window that grew past the screen when its resize grip was
clicked.

## 1. Recording

- **Start and stop**: the Performance tab of `/bbdb` has a **Record Rendering** button (it reads
  **Stop Recording** while recording; it follows a recording started or stopped elsewhere through
  `renderRecorder/StateChanged`). `RenderRecorder:Start()` / `Stop()` from code. A recording still
  running at logout is stopped and kept.
- **Renders**: after every render of a window (`windowProto:Render`, after `OnRendered` and the
  screen clamp), `WindowRendered(window)` adds a `render` entry, only when the window's snapshot
  differs from the last one recorded for that window.
- **Resize and move steps**: every step `window.lua` traces (`resize start`, `resize started`,
  `resizing`, `rendered while resizing`, `resize stop`, `resize stopped`, `on screen`,
  `position saved`, `move start`, `move stopped`; window.md 3a) adds a `step` entry with the
  window's `Geometry`.
- Costs nothing while stopped: the window checks `recorder.recording` (a field) and does nothing
  more. The profiler never wraps it (`ALWAYS_EXCLUDED` in `debug/perf/engine.lua`), so a capture
  running at the same time does not measure it.

## 2. Snapshots (`RenderRecorder:Snapshot(window)`)

One line per part, positions relative to the window's top left (`@x,y WxH`):
- `window <name> mode=<content|window> sizing=<bool> | <Geometry>`: anchors, rect, effective
  scale, clamp, cursor (window.md 3a).
- `content insets L,R,T,B @...`: the content box.
- For a bag (found through `addon.Bags`): `scroll @... child <height> bar=<shown>`;
  `canvas @... layout ipr=<items per row> columns=<n> header=<h> tab=<h> footer=<h>` (the layout
  `BagCanvas:GetLayout` computes for the canvas width in window mode, the settings otherwise);
  `global section` / `view section <title> ipr=<n> cells=<n> shown=<bool> @...`, sorted by
  title; under each, `  item <slotkey> @...` per item button and `  gap` per gap cell.

## 3. Storage

`BetterBagsPerfDB.renderRecordings`: the newest last, at most `MAX_RECORDINGS` (5). A recording is
`{ id, startedAt, stoppedAt, character, realm, gameVersion, gameBuild, full?, entries }`; an entry
is `{ t = "<ms since start>", kind = "render", window, lines = { ... } }` or
`{ t, kind = "step", window, step, geometry }`. A recording takes at most `MAX_ENTRIES` (20000)
entries and then sets `full`. `BetterBagsPerfDB` is separate from the AceDB profile, like the
profiler's sessions; the recorder's `Init` runs right after `PerfSessions:Init` (initialization.md).
Read offline from `WTF/Account/<ACCOUNT>/SavedVariables/BetterBags.lua`.

Coverage: `spec/debug/render_recorder_spec.lua` (records on render and only on change, a bag's
snapshot down to its item buttons, resize steps, nothing while stopped, recording limits, the
state message, logout) and `spec/frames/perfpane_spec.lua` ("records rendering from its own
button").
