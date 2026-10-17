# The Render Pipeline (`render/`)

Every BetterBags window lays itself out through one staged render pipeline, ported from the
author's Moonlight addon (`~/git/Moonlight/render/`, design notes in
`~/git/Moonlight/.context/rendering.md`) and extended here. It exists because WoW frames are
not reactive: resizing a window does not reflow what is inside it, and a parent that has to
fit its children needs their sizes first. Before the pipeline, each BetterBags layout passed
sizes around by hand (`frames/bag.lua` summed section heights in a callback, the slots panels
hard-coded insets per client).

## 1. Drawables and render plans (`render/drawable.lua`, `render/render.lua`)

A **drawable** has a `frame` and a **render plan**: an ordered list of steps.

- `RENDER_PRE` (`PreRender(parentResult, options)`): work out what to hand the children, the
  **constraints**, and return them.
- `RENDER_DEP` (`target = child`): render a child with the PRE result as its `parentResult`.
- `RENDER_SELF` (`Render(parentResult, options, results)`): size and place the drawable from
  its children's results (`results.Results[child]`) and return its own result.

`Render:NewRenderChain(d, options, constraints?)` runs the plan of `d` and everything below it
and returns `d`'s result and the results of the whole chain. Constraints flow down, sizes flow
up (`RenderResult`):

| Field | Down (a constraint) | Up (a result) |
|---|---|---|
| `Width` | the width a child may use; nil: its natural width | the width it took |
| `Height` | the height a child must fill; nil: its natural height | the height it took |
| `MaxHeight` | the most a child may take before it scrolls | |
| `FullWidth` | the full width, for children spanning every column | |
| `LayoutWidth` | the width to lay out for, when it differs from the width shown (a window animating to its snapped width) | |
| `Scrollable` | | the content is taller than its viewport |
| `FitWidth` | | the width its layout takes: a window snapped to it shows the same layout (window.md 3b) |

`RenderChainOptions` (`OnlyRedraw`, `Invalidated`, `ctx`) is passed to every step. (It is not
`RenderOptions`, which is `frames/grid.lua`'s grid layout options.)

### Prototypes and the profiler
Instances are created with `drawable:Create(proto, fields?)` and look their methods up through
their prototype (a metatable), and every prototype through `drawable.proto`, the drawable
defaults (frame forwarding: `SetParent`, `SetPoint{Point, RelativeTo, RelativePoint, XOffset,
YOffset}`, `SetSize`, `Show`/`Hide`, sort keys, `Invalidate`; and errors for a missing plan,
pre-render or render). `drawable:Extend(proto, name)` chains a module prototype to the
defaults and registers it with the profiler under `name`; `drawable.proto` is registered as
`DrawableFrame`. Copying methods into instances (Moonlight's `Mixin`) would hide them from the
profiler, which wraps prototype tables in place (perf-profiler.md §2).

## 2. Invalidation

Each chain records, on every child it renders, `renderParent` (the drawable that rendered it)
and `renderParentResult` (the constraints it was given).

- `Render:Invalidate(d)` walks the parent links up to the **root** (the first drawable with no
  parent, or one marked `renderRoot = true`) and schedules one render of the root on the next
  frame (`C_Timer.After(0)`). However many nodes of a tree are invalidated in a frame, the
  root renders once. `Render:Flush()` renders every invalidated root now.
- A root that has a parent (a `renderRoot` inside another tree) re-renders with the
  constraints its parent last gave it. Its new size does not reach the parent: a render root
  must keep the size its parent gave it.
- A root whose `ShouldRender()` returns false (a hidden window) is skipped and left with
  `renderPending = true`; its owner renders it when it can.
- `Render:Detach(d)` cuts a drawable off its tree. A parent link cycle is an error.
- `Drawable:FromFrame(frame, measure)` wraps a frame laid out by its own code (a grid): its
  render returns `measure(parentResult, options)` as its size (`FrameDrawable`).
- `Render:IsDirty(d)` says whether d's tree waits for the next frame; `Render:RenderNow(d,
  options)` renders d's tree now (with `Invalidated` set) and drops the render it waited for, so
  a window shown in the frame it was invalidated in renders once (window.md §4).

## 3. Re-entrancy and errors

- While a chain runs, every drawable it is rendering is marked active (`IsRendering`). A chain
  started for any drawable of a tree that is rendering (a drawable's own `Render` starting a
  chain for itself or its parent) does not run: its root is invalidated for the next frame and
  the call returns nil.
- A chain that errors clears every mark it set and re-raises the error, with the stack of the
  failure appended when `debugstack` exists. `Flush` reports each failing root to
  `geterrorhandler()` and renders the others; `ShouldRender` runs inside that protection too.
- **Nothing in a render may yield.** A chain runs inside a protected call, and a Lua 5.1
  coroutine cannot yield across one. Data sweeps yield (refresh-scheduler.md); renders don't.
- Every invalidated render gets a `ctx` (`Render_Flush`).

## 4. Scrollbox (`render/scrollbox.lua`)

A drawable that scrolls one child: a `WowScrollBox` with a `MinimalScrollBar`. Each window owns
one for its lifetime (no pool).

- `SetChild(child)` parents the child to the scroll child, hides it until it renders, links it
  (`renderParent`), and hides and detaches the child it replaces.
- PRE hands the child the width left of a 14px bar reserve (nil for a natural width). SELF
  sizes the scroll child's height (at least 1), shows the child, calls `FullUpdate(true)` and
  reports the viewport: the parent's `Height` (a window the player sized), else the child's
  height capped at `MaxHeight` (a window sized to its content), with `Scrollable` set when the
  child is more than half a pixel taller. Its width is the parent's `Width`, else the child's
  width plus the bar reserve. A child that returns no result is an error.
- **Options** (`scrollbox:Create(parent, name, opts)`): `Symmetric` keeps the bar's room on both
  sides (the child is inset by 14 and gets the width less 28; `GetGutterWidth` is 28, else 14);
  `AutoHideBar` shows the bar only while the wheel scrolls or the pointer is over its room
  (window.md §3b). Only the bag's box uses them; the changelog's keeps the old behavior.
- **Widths for snapping**: a child's `FitWidth` (the narrowest width it lays out the same in)
  goes up with the room added, and the parent's `LayoutWidth` (the width to lay out for, when it
  differs from the width shown: a window animating to its snapped width) goes down with the room
  taken off (window.md §3b).
- The scroll child is created with `.scrollable = true`, so initializing the box moves it under
  the box's scroll target and anchors it TOPLEFT and TOPRIGHT (Blizzard's
  `ReparentScrollChildren` and `ScrollBoxViewUtil.SetPoint`): its width follows the box.
- **The bar shows and hides itself** (`SetHideIfUnscrollable(true)`): Blizzard updates it from
  the box's own size, which the window sets after the render. The scroll box never calls
  Show/Hide on it (Blizzard's bar overrides those whenever it updates). It sets the bar's
  `nodeignore` attribute (ConsolePort's cursor skips such nodes) to `not Scrollable`.

## 4a. Anchoring: both offsets or neither

`SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)` takes both offsets
(`SimpleScriptRegionResizingAPIDocumentation`: neither is nilable). An x offset passed with a nil
y offset is dropped by the client: a render recording showed the bag's scroll box child, anchored
14 in, at 0. `drawableProto:SetPoint` passes 0 for a missing offset when the other is given, and
the frame mock (`spec/helpers/wow_mocks.lua`) errors when one is given without the other, so any
call site that breaks the contract fails its specs. Coverage: `spec/render/render_spec.lua`
("anchors with both offsets when only one is given").

## 4b. The layout engine: measure, then arrange

**Why.** The bag's horizontal geometry was described four times: the canvas's formulas from a
width to items per row, the view's row limit, what the grid actually did (rows that run 4 past
their limit, columns at their own widths), and the snap's formula guessing the grid from the
canvas's formula. Each disagreement showed up as padding: a render recording and an offline probe
with the real grid showed snapped windows 5 to 111 px wider than their content, depending on
where the drag stopped. And nothing could ask "how wide is this layout?" without moving frames.
Now one engine computes layouts as data, and everything else asks it.

- **Flow** (`render/flow.lua`, pure): `Flow:Pack(sizes, { rowLimit, columns?, spacing? })`
  places boxes in rows (a row wraps when the next box would pass the limit, checked without the
  gap before its last box, so a row can run one spacing past it) within columns (rows split by
  height: each column takes rows until it passes its share of the total plus 20, at least the
  tallest box; more columns than asked grow the share and retry, at most five times), and returns
  `{ positions, columnOf, width, height }`. An empty layout is one spacing (4) wide. It is the
  grid's old algorithm, line for line: 3,000 random layouts through both gave 0 mismatches before
  the grid switched to it. Loaded for every spec by `spec/setup.lua`.
- **Grid** (`frames/grid.lua`): `Measure(options)` packs the cells' sizes (rounded, or
  `options.sizeOf(cell)` for a cell not arranged yet) and moves nothing; `Arrange(measured)`
  places every cell through `PlaceCell(cell, x, y)`, the one function that moves a cell (the hook
  for animating a reshuffle between two layouts: a plan holds every cell's target), and sizes the
  grid; `Draw(options)` is the two in a row (the currency icons and the slots panels use it).
- **Section** (`frames/section.lua`): `Measure(kind, itemsPerRow)` returns
  `{ itemsPerRow, content, width, height, hidden? }`: its cells packed in rows of
  41 × itemsPerRow + 16, 6 pixels of padding on each side, as wide as its title rounded up to a
  whole pixel when full names show, its title's height above unless the header is removed.
  `Arrange(kind, measured)` applies it. `GetItemsPerRowCap()` is the items per row from which its
  cells fit one row (more changes nothing). `Draw`/`Grid` arrange a measure at its items per row.
- **View** (`views/views.lua`): `Measure(itemsPerRow, columns, measureSection?)` measures every
  section (through `measureSection` when given) and packs them at their measured sizes in rows of
  41 × itemsPerRow + 16 within columns; `Arrange(measured)` arranges every section, then the
  sections. `Layout(ctx, layout)` is the two.
- **Bag global sections** (`frames/bag.lua`): `GetGlobalLayoutSections()` lists Recent Items
  (spanning the columns) and Free Space (spanning them when it shows every slot);
  `MeasureGlobalSections(itemsPerRow, columns, measureSection?)` and `ArrangeGlobalSections`.
- **Canvas** (`frames/bagcanvas.lua`): `Measure(itemsPerRow, columns)` is a plan
  (`{ itemsPerRow, columns, global, view, width, height }`). `Plan(width?)`: without a width the
  bag's items per row; with one the densest plan no wider than it, out of every items per row from
  a cap down to one (one when nothing fits). The cap is where nothing changes any more: every
  section's cells fit one row and every section fits one row of sections. The candidates do not
  depend on the width, which is why the plan chosen at a width is chosen again at its own width
  (the snap). Candidates whose row limit less the widest section reaches the width are skipped:
  the view's first row is wider than that, and such an items per row is past every section's cap.
  Section measures are cached per items per row (capped where the section stops changing) and kept
  across renders until the bag binds new data (`ForgetMeasures`, from `bag:Draw`): a resize
  re-plans every render. `Render` arranges the plan and centers it; its result's `FitWidth` is the
  plan's width.
- **Cost (measured offline, PUC Lua 5.1, a bank of 591 items in 60 sections):** planning took
  17-25 ms per render before the skip and 1-3.4 ms after it (worst about 5.5 ms when a width needs
  items per row not measured yet); laying one layout out costs about 0.25 ms. Arranging frames in
  the client costs more than either. Capture a resize with the profiler to see it in game.

Coverage: `spec/render/flow_spec.lua`, `spec/frames/grid_spec.lua`, `spec/frames/section_spec.lua`
("measures its size…", "arranges a measure…", "says the items per row past which…"),
`spec/views/gridview_spec.lua` ("measures a layout without moving anything…"),
`spec/frames/bag_draw_ownership_spec.lua` ("global sections in a layout", "has its canvas forget
its section measures…"), `spec/frames/bagcanvas_spec.lua` (the snap property over 300 random
bags, densest, measures kept and forgotten, centering). Every guard was mutation-tested.

## 5. Load order and init

All five TOCs list `render\render.lua`, `render\drawable.lua`, `render\scrollbox.lua`, `render\flow.lua` after
`core\fonts.lua` (the profiler engine and Context load earlier) and before anything that draws,
followed by `sonata\engine.lua`, `sonata\apply.lua`, `sonata\decoration.lua`,
`sonata\elements.lua` and `window\window.lua`.
`core/init.lua` calls `addon:GetModule('Render'):Init()` at the start of phase 4
(initialization.md). Coverage: `spec/render/toc_spec.lua`.

## 6. Coverage

`spec/render/render_spec.lua` (plan order, constraints down and sizes up, explicit constraints,
parent links and relinking, render roots and their constraints, cycles, invalidation coalescing,
several roots per frame, `Flush`, roots invalidated during a flush, a pending frame after a
direct flush, `ShouldRender` and `renderPending`, re-entrancy at the root and below it, error
isolation and stacks, marks cleared on errors, the flush context; drawables: prototype lookup,
profiler registration, frame forwarding, missing steps). `spec/render/scrollbox_spec.lua`
(construction and Blizzard's reparenting, child hiding and replacement, natural and set sizes,
root without constraints, maximum height, the bar left to Blizzard, `nodeignore`, the half-pixel
tolerance, set height over maximum, width clamping, update after sizing, minimum height, missing
child or result). The mocks follow Blizzard's scroll source (`spec/helpers/wow_mocks.lua`:
`WowScrollBox`, `MinimalScrollBar`, `CreateScrollBoxLinearView`,
`ScrollUtil.InitScrollBoxWithScrollBar`, and child frame tracking for `GetChildren`).
