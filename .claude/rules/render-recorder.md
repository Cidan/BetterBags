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

- **BetterBags Next's settings window** (`recorder:SettingsRendered(frame)`, from
  `NextSettings:show` every time it shows a page, tab or search, only when the snapshot changed): a
  `settings` entry whose first line is `settings scale=<frame scale> effective=<effective scale>
  screen=<physical width>x<height> pixels per unit=<effective * height / 768>` (Blizzard's
  `PixelUtil.GetPixelToUIUnitFactor` is 768 / the physical height), then one line per control edge
  shown in it (`controls.edges`, every `CreateEdge`, held weakly), top to bottom:
  `edge "<its button's text>" @x,y WxH | top a-b bottom a-b left a-b right a-b`, each side across its
  thickness in screen pixels, ending `collapses` when both ends round to the same pixel (a line under
  a pixel thick that can draw nothing). Added for a settings button whose bottom edge was missing in
  game while the others showed, at about 0.91 screen pixels per unit (read from a screenshot: 909
  pixels for the 1,000-unit window); the snapshot is to show whether that side collapses before the
  edges are changed (data-driven.md).

- **A BetterBags Next panel sized** (`recorder:PanelSizing(panel, step)`, from `panelProto:recordSizing`): every step
  of a grip sizing a small panel and of its size gliding adds a `sizing` entry, `panel` its label and `step` one of
  `start` (the grip pressed), `resized` (each size change the client makes), `rendered` (each layout while sized or
  gliding), `scroll kept` (`KeepScroll` put the scroll back, next.md §14g), `let go`, `placed` (let go with nothing to
  snap), `snap` and `snapped` (each frame of the snap and its end), `reset` and `reset done` (Shift-click's glide).
  Its lines (`SizingSnapshot`): `screen WxH uiScale scale effective cursor x,y`; `frame <every anchor: point, relative
  frame, relative point, x,y to four decimals> | l t r b`; `scroll offset <offset> of <range> (<percentage>) | target
  <its anchor>`; then each shown section's first and last icons: `<section> <slotkey> frame l t r b | art l t r b |
  border l t r b` (the button's holder, its decoration's `icon` and `IconBorder`, read without making a decoration).
  Every `l t r b` is where the client put the region (`GetScaledRect`), in screen pixels with three decimals: a
  fraction is a region off whole pixels, and a value that changes between `rendered` steps with nothing reflowing is
  what moved. Added for icons that jittered "ever so slight" in game while a panel was sized, in every direction,
  while the specs' model of the layout kept every icon and every frame it hangs from on the same whole pixels
  (data-driven.md: the client's own sizing, `StartSizing`, is not documented and cannot be modeled).
  Its `regions` (`sizingRegions`): what changed on screen in the panel since its last step in this recording, from
  `PixelAudit:Regions(panel.frame, { skip = panel:MovingParts() })` (next-pixel-perfect.md §6): every region that draws
  in it (named as the pixel check names parts), with its kind and draw layer, where it is in screen pixels, its alpha
  with its parents', and what it draws (file or atlas, color, texture coordinates when not the whole image, whether the
  client snaps it to the pixel grid and its texel snapping bias, a text's
  text). The first step of a panel lists all of them (`= path | what`); each later step only `+ path | what` (drawn now
  and not then), `- path` (no longer drawn) and `~ path | what` (drawn differently), sorted; nil for nothing. Added when
  the first sizing recording showed every recorded icon on the same whole pixels at all 247 steps while the player
  still saw shading change at an icon's bottom edge ("you can see the shadowing changes just by slight resize of the
  window up and down (no icons shifted their actual position)"), with Masque off: whatever changes is a region the
  first and last icons' holder, art and border do not cover. A region a clipping frame (the scroll box) cuts keeps its
  rect; the clipping frame's own rect is listed (`Frame clips`), so a cut shows as that frame's edge moving across it.
  Costs a walk of the panel per step, only while recording. To capture: start Record Rendering on the Performance tab
  of `/bbdb`, drag a grip for a second or two, stop, `/reload`.

## 3. Storage

`BetterBagsPerfDB.renderRecordings`: the newest last, at most `MAX_RECORDINGS` (5). A recording is
`{ id, startedAt, stoppedAt, character, realm, gameVersion, gameBuild, full?, entries }`; an entry
is `{ t = "<ms since start>", kind = "render", window, lines = { ... } }`,
`{ t, kind = "step", window, step, geometry }`, `{ t, kind = "text", step, role, line }`,
`{ t, kind = "settings", lines = { ... } }` or `{ t, kind = "sizing", panel, step, lines = { ... }, regions = { ... }? }`. A recording takes at most `MAX_ENTRIES` (20000)
entries and then sets `full`. `BetterBagsPerfDB` is separate from the AceDB profile, like the
profiler's sessions; the recorder's `Init` runs right after `PerfSessions:Init` (initialization.md).
Read offline from `WTF/Account/<ACCOUNT>/SavedVariables/BetterBags.lua`.

Coverage: `spec/debug/render_recorder_spec.lua` ("a BetterBags Next panel sized": the panel, its scroll box and each
shown section's first and last icons in screen pixels; every region that draws at the first step, then only what was
drawn, no longer drawn or drawn differently, moving parts left out, nothing for no change, everything again in a new
recording; nothing while stopped; records on render and only on change, a bag's
snapshot down to its item buttons, resize steps, nothing while stopped, recording limits, the
state message, logout; the settings window's scale and edges in pixels, a collapsing side, only
edges shown in it, only on change), `spec/next/settings/window_spec.lua` ("gives the render recorder
the window each time it shows a page"), `spec/next/controls/base_spec.lua` (edges kept weakly) and `spec/frames/perfpane_spec.lua` ("records rendering from its own
button").
