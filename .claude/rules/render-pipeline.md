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
| `Scrollable` | | the content is taller than its viewport |

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
- The scroll child is created with `.scrollable = true`, so initializing the box moves it under
  the box's scroll target and anchors it TOPLEFT and TOPRIGHT (Blizzard's
  `ReparentScrollChildren` and `ScrollBoxViewUtil.SetPoint`): its width follows the box.
- **The bar shows and hides itself** (`SetHideIfUnscrollable(true)`): Blizzard updates it from
  the box's own size, which the window sets after the render. The scroll box never calls
  Show/Hide on it (Blizzard's bar overrides those whenever it updates). It sets the bar's
  `nodeignore` attribute (ConsolePort's cursor skips such nodes) to `not Scrollable`.

## 5. Load order and init

All five TOCs list `render\render.lua`, `render\drawable.lua`, `render\scrollbox.lua` after
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
