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
- **Text font changes**: every change of a Sonata text's font object (`sonata:fontChanged`:
  `SetTextRole`, a theme's or a client rescale's new font objects) adds a `text` entry with
  step `font`; a text with a watcher (`WatchTextFont`, sonata.md 3c) adds `refit` after its
  watcher ran, and `next frame` one frame later (a `SetWidth` is applied on the next update tick,
  `QuestLogTitleButton_Resize`). Each holds the role and a line
  `"<text>" font=<font object> <file> <size> <flags> | w= h= string= lines= truncated= wrap= |
  parent w=`. Added when settings entries kept wrapping after their refit on WoW: Forever.
- Costs nothing while stopped: the window checks `recorder.recording` (a field) and does nothing
  more. The profiler never wraps it (`ALWAYS_EXCLUDED` in `debug/perf/engine.lua`), so a capture
  running at the same time does not measure it.

## 2. Snapshots (`RenderRecorder:Snapshot(window)`)

One line per part, positions relative to the window's top left (`@x,y WxH`):
- `window <name> mode=<content|window> sizing=<bool> | <Geometry>`: anchors, rect, effective
  scale, clamp, cursor (window.md 3a).
- `content insets L,R,T,B @...`: the content box.
- For a bag (found through `addon.Bags`): `scroll @... child <height> bar=<shown>`;
  `canvas @... layout ipr=<items per row> columns=<n> width=<w> for=<exact> header=<h> tab=<h>
  footer=<h>` (the plan the canvas arranged in its last render, render-pipeline.md §4b; `width` is
  the plan's own width, the one a snap goes to; `for` is the width the plan had to fit, to six
  decimals, or `content` when sized to its content: a layout exactly as wide as its window was
  rejected at a width printed as 426.0, window.md §3b, which one decimal could not show);
  `global section` / `view section <title> ipr=<n> cells=<n> shown=<bool> @...`, sorted by
  title; under each, `  item <slotkey> @...` per item button and `  gap` per gap cell. A section
  or item Motion is moving ends with `moving from <x0>,<y0> to <x1>,<y1>` (offsets from the frame
  it hangs from: where the move started and where it goes), and the canvas line with
  `| tab moving ...` / `| footer moving ...` for its containers (render-pipeline.md §4c). The
  snapshot is taken as the render that starts the moves ends, so the `@` positions (and the padding
  line) are the moves' starts. An item
  button's line adds what it shows: how it was last drawn (`item`, `free count=<n> name=<bag>`,
  `empty`), `border=<r,g,b>` or `off` (the decoration's `IconBorder`), `padlock=<bool>` (Blizzard's
  "extended" slot frame, `UpdateExtended`, on the button or the decoration), `mouse=<bool>` (the
  interaction button's `IsMouseEnabled`) and `glyph=<atlas>` or `none` (the empty slot glyph).
  Added for free slots on WoW: Forever that showed a padlock and a quality border.
- For a bag, `padding items left=<px> right=<px> | sections left=<px> right=<px> | <border>`: how
  far the outermost shown item buttons and sections (titles included) are from each side of the
  window, then the theme's border. A backdrop: `border backdrop left=<edge> right=<edge> | visible
  left=<px> right=<px>` (the items' distance from the border). A template:
  `border NineSlice pieces left=<from>..<to> right=<from>..<to>`, where the edge pieces lie,
  measured inward from each edge of the window (negative is outside it); a piece is wider than the
  metal drawn in it (Default's are 75 pixels, 8 outside the frame on the left and 4 on the right,
  a retail recording), so no visible padding is claimed. `border unknown` for art painted in a
  texture (Moonlight's frames: measured from the image files instead). Left and right should
  match on every theme (window.md §3b). Added for centering the bag's content.

## 3. Storage

`BetterBagsPerfDB.renderRecordings`: the newest last, at most `MAX_RECORDINGS` (5). A recording is
`{ id, startedAt, stoppedAt, character, realm, gameVersion, gameBuild, full?, entries }`; an entry
is `{ t = "<ms since start>", kind = "render", window, lines = { ... } }`,
`{ t, kind = "step", window, step, geometry }` or `{ t, kind = "text", step, role, line }`. A recording takes at most `MAX_ENTRIES` (20000)
entries and then sets `full`. `BetterBagsPerfDB` is separate from the AceDB profile, like the
profiler's sessions; the recorder's `Init` runs right after `PerfSessions:Init` (initialization.md).
Read offline from `WTF/Account/<ACCOUNT>/SavedVariables/BetterBags.lua`.

Coverage: `spec/debug/render_recorder_spec.lua` (records on render and only on change, a bag's
snapshot down to its item buttons, resize steps, nothing while stopped, recording limits, the
state message, logout) and `spec/frames/perfpane_spec.lua` ("records rendering from its own
button").
