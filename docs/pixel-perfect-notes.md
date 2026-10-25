# Pixel perfect, still and smooth: notes on BetterBags' windows

Notes for a blog post about the work, from October 15 to October 25, 2026, that made BetterBags' windows sit on whole
screen pixels, stop jittering while resized, animate without tearing or flashing, and draw their text and fonts
consistently. They are written as raw material: what was reported, what was measured, what turned out to be the cause,
what the fix was, and the code. Every number below was measured (in game, in a recording, in a video, or in a
simulation in the specs) unless it says otherwise.

The short version: almost none of the bugs were where they looked like they were. A border that vanished was not a
border bug; icon "jitter" while resizing was five different causes stacked on top of each other, only two of which
were icons moving; a shimmer during an animation was not the animation; a text that jumped a whole pixel had moved by a
thousandth of one. Each one was found by measuring first, and most needed new tooling (a recorder, a layout simulation in
the specs, a frame-by-frame video diff) before they could be measured at all.

## Contents

1. How WoW puts things on the screen (the background you need)
2. The tools we built to see what was happening
3. The classic bag windows: float noise, a grip that jumped, and a dropped offset
4. Animation: motion that keeps its speed, a bounce that never shows the screen edge, and alphas that fight
5. Pixel perfect: the report, the wrong first fix, and NextPixel
6. What the in-game pixel check found
7. A layout must never depend on the pixel grid
8. Resize jitter, five causes deep
9. Fonts and text
10. The lessons, as rules
11. Appendix: numbers, files, pull requests, scripts

---

## 1. How WoW puts things on the screen

Everything in this document follows from four facts about the client.

**UI units are not pixels.** The UI is laid out in units on a virtual screen 768 units tall. The client exposes the
conversion as `PixelUtil.GetPixelToUIUnitFactor()`, which is 768 divided by the screen's height in physical pixels
(`GetPhysicalScreenSize`). Every frame then has an **effective scale** (its own scale times all its parents', UIParent's
included, which carries the player's UI scale setting). One screen pixel, in a region's own units, is:

```lua
-- next/pixel.lua
function pixel:UnitAt(effectiveScale)
  return PixelUtil.GetPixelToUIUnitFactor() / effectiveScale
end

function pixel:Unit(region)
  return self:UnitAt(region:GetEffectiveScale())
end
```

Blizzard's `PixelUtil` and GW2_UI (`GW.mult`) work it out the same way.

**The reporter's screen makes this concrete.** The game's own log (`Logs/gx.log`) showed the player's maximized window
rendering at 3396x1362. At a UI scale of 65%, one UI unit there is 1.153 screen pixels; at 70% it is 1.241. In true
fullscreen (3440x1440) at 65% it is 1.219. None of these is a whole number, so a frame placed at a whole number of UI
units almost never lands on a whole pixel.

**Offsets are in the anchored region's units.** `region:SetPoint(point, relativeTo, relativePoint, x, y)` takes `x` and
`y` in the units of `region`, not of `relativeTo`. A frame at a Bag Scale of 85% inside a panel has its own grid, and a
"one pixel" offset means a different number of units for it than for its parent.

**The client snaps and sharpens textures on its own.** By default, a texture's corners are rounded to the pixel grid as
it draws, and its contents are "sharpened": the renderer picks a texel rather than blending two. A Blizzard developer
describes it on warcraft.wiki.gg (`TextureBase:SetTexelSnappingBias`): "the texture's verts will be rounded to the
nearest pixel during the rendering phase, texelSnappingBias is a range from 0-1, anything >0 implies snapToPixelGrid;
the stronger the texelSnappingBias the more aggressive the renderer will be in selecting a texel instead of blending
texels, the end result is a 'sharpening' sort of effect." This one fact is behind the vanished border of section 5 and
the shimmer of section 8.

Two more facts matter later:

- **Text is drawn in whole pixels.** Not documented anywhere; inferred from measurements in section 8.6.
- **Values read back from the client carry float error.** `GetWidth()` on a frame you sized to 466 can return
  465.99997 at a UI scale. Any exact comparison against a value read back is a bug waiting for the right UI scale.

---

## 2. The tools we built to see what was happening

The project has a hard rule (`.claude/rules/data-driven.md`): every change is backed by captured data, and when the
existing tools cannot show the fact a change depends on, the first change is to the tools. This work built more tooling
than fixes, and the tooling is the most reusable part.

### 2.1 The render recorder (`debug/renderrecorder.lua`)

Started from `/bbdb`, Performance tab, **Record Rendering**. It records, into `BetterBagsPerfDB.renderRecordings`
(readable offline from the SavedVariables file), a snapshot of a window after every render that changed it, down to
every section and every item button, with positions relative to the window. Added for a report of a bank window that
grew past the screen when its resize grip was clicked, which the profiler could not explain: the profiler records which
functions ran, not where things ended up.

It grew with each investigation:

- **Window geometry per step** (`windowProto:Geometry(step)`): anchors, rect, effective scale, clamp and the cursor at
  every step of a resize or a move.
- **A padding line per bag**: how far the outermost items are from each side, and the theme's border pieces.
- **The exact width each layout was chosen for** (`for=426.000000`), to six decimals, after one decimal hid a float
  error (section 3.4).
- **Text font changes** (`step font`, `refit`, `next frame`) with width, line count and truncation (section 9.3).
- **Panel sizing steps** (`RenderRecorder:PanelSizing`): every step of a grip sizing a BetterBags Next panel and of its
  snap, with the panel's anchors and rect, the scroll offset, and each shown section's first and last icons, every
  rect in screen pixels with three decimals. A fraction in that output is a region off whole pixels.
- **Everything that changed on screen** (`PixelAudit:Regions`): the first step lists every region that draws, with its
  kind, draw layer, rect, alpha, file or atlas, color, texture coordinates, and whether the client snaps it and with
  what bias; each later step lists only what was drawn, no longer drawn, or drawn differently.

A sizing step's lines look like this (from the in-game recording that found the text jump, section 8.6):

```
309  6769.6  snap     ~ BetterBagsItemButton170DecorationCount | FontString | l 2758.999 t 545.000 r 2776.999 b 521.000 | text "4"
337  7131.9  snapped  ~ BetterBagsItemButton170DecorationCount | FontString | l 2759.000 t 545.000 r 2777.000 b 521.000 | text "4"
```

### 2.2 A layout resolver for the specs (`spec/helpers/layout.lua`)

The test suite runs on Lua 5.1 against a mock of the WoW API. The mock stored anchors but never worked out where a
frame ended up: `GetLeft()` was nil unless a test set a rect. To test pixel placement, the specs needed the client's
layout math:

- `layout.UseScreen(width, height, uiScale)` sets a screen up as the client would (`GetPhysicalScreenSize`, UIParent at
  that scale) and returns a function that puts it back.
- `layout.Rect(region)` works a region's rect out from its anchors, its sizes and its parents' scales, offsets in the
  anchored region's units, a font string as big as its text.
- While a screen is set up, `GetWidth`, `GetHeight`, `GetLeft`, `GetRight`, `GetTop`, `GetBottom`, `GetCenter` and
  `GetRect` answer from the resolver, so code that reads where a frame is (a drag reads the cursor against a section's
  edges) runs unchanged on the mock.

The specs use real screens: the reporter's 3396x1362 at 65% and 70%, 3440x1440 at 65%, 1920x1080 at 64% and 100%,
2560x1440 at 100% and 115%. The default mock screen is 768 pixels tall, so at a UI scale of 1 a unit is exactly a
pixel and specs that do not care about pixels are unchanged.

### 2.3 One pixel check for the specs and the game (`debug/pixelaudit.lua`)

`PixelAudit:Check(root, { skip, owners })` lists every shown region under a root that draws and is not where it
should be. It reads only what the client gives an addon, on every client: `GetScaledRect` (where the client puts a
region, in UI units at scale 1), `GetPoint`, `GetRegions`, `GetChildren`, `GetTextInsets`, `IsVisible`, `GetAlpha`. The
specs answer `GetScaledRect` from the resolver; the game answers it for real. So the same check runs against a mock
in the specs and against the real client, with real fonts, real art, Blizzard's templates and other addons.

```lua
-- debug/pixelaudit.lua
local function onPixel(value)
  return math.abs(value - math.floor(value + 0.5)) < 1e-3
end

-- A text's place: a quarter pixel right of and above a whole pixel (section 8.6).
local function onTextPixel(value, offset)
  return math.abs(value - math.floor(value) - offset) < 1e-3
end
```

For a texture, line, edit box or clipping frame, all four edges must be whole pixels. For a font string, only its
anchor points are judged: its far edges are the client's measure of its text, which no addon controls. It never judges
anything hidden or at alpha 0, its own or a parent's.

Two design details worth a paragraph each in a blog post:

- **It never reads a key of a table it walks.** In game, a window's tables reach saved settings, and reading a key that
  AceDB's wildcard defaults cover writes it. So it collects the regions off the grid first, then finds their names by
  identity, iterating tables only.
- **Masque's parts are listed apart.** Masque (the button skinning addon) sizes its skins its own way, deliberately off
  our grid. The check finds Masque's regions from what Masque writes (`_MSQ_CFG`, `_MSQ_CFG.Regions`, `_MSQ_*` fields)
  and reports them separately, and treats everything inside a part Masque places as Masque's too.

### 2.4 The check in game (`/bbdb`, Pixels tab)

A toggle, off by default and free while off: every call site checks one field first. When on, every BetterBags Next
window registers as it is made, says when it rendered, and is checked once it has stayed the same for 0.3 s, then every
0.25 s until two checks agree. What moves (slides, glides, sparkles) differs between checks and is left out; what stays
off the grid where the window comes to rest is reported, with the screen, the UI scale, the window's state and a layout
description, saved to SavedVariables and popped up in the debug window. Section 6 is what it found in the first days.

### 2.5 Simulating a drag in the specs

The resolver made it possible to drag a resize grip a pixel a frame through the real panel and canvas, recording where
every icon lands, on several screens and Bag Scales. This is the test that found the column jitter of section 8.1 and
keeps it fixed (trimmed):

```lua
-- spec/next/pixel_perfect_spec.lua (trimmed)
for _, case in ipairs({ { 3396, 1362, 0.65, 100 }, { 1920, 1080, 1, 85 } }) do
  useScreen(case[1], case[2], case[3])
  db.size, db.bagScale = "small", case[4]
  local bag = open(function(c) return nextBag:Create(c) end, BACKPACK)
  settle()
  local ppu, s = layout.PixelsPerUnit(), bag.frame:GetEffectiveScale()
  local h = bag.frame:GetHeight()
  local r0 = layout.Rect(bag.frame)
  local start = math.floor((r0.right - r0.left) * ppu + 0.5)
  bag:StartSizing("RIGHT")
  local previous
  for px = start, start + 130 do
    bag.frame:SetSize(px / ppu / s, h)
    bag.frame:GetScript("OnSizeChanged")(bag.frame, px / ppu / s, h)
    render:Flush()
    local frame = layout.Rect(bag.frame)
    local now = { perRow = bag.content:PerRow(bag:LayoutWidth() - bag:ContentRoom()), places = {} }
    for key, b in pairs(buttons) do
      local r = layout.Rect(b.frame)
      if r ~= nil and b.frame:IsVisible() then
        now.places[key] = math.floor((r.left - frame.left) * ppu + 0.5) .. "," .. math.floor((frame.top - r.top) * ppu + 0.5)
      end
    end
    if previous ~= nil and previous.perRow == now.perRow then
      -- no icon moves unless a column is added
      assert.are.same(previous.places, now.places,
        string.format("%s at Bag Scale %d%%, %d to %d pixels wide", screenName(case), case[4], px - 1, px))
    end
    previous = now
  end
  bag:StopSizing()
end
```

### 2.6 Video, diffed frame by frame

Sections 8.4 to 8.6 were bugs where every rect the API could report stayed the same and something still changed on
screen. The player recorded a 60 fps video of the bag, and the frames were compared pixel by pixel. The pipeline:

```sh
ffmpeg -v error -i drag.mp4 frames/f%03d.png                       # look at frames
ffmpeg -v error -i drag.mp4 -f rawvideo -pix_fmt rgb24 all.raw      # every frame as raw RGB, for scripts
```

Then small Python scripts over the raw file. First, which frames change at all, and where:

```python
# diff.py: for each pair of consecutive frames, how many pixels changed and their bounding box
W, H = 242, 202
data = open(sys.argv[1], 'rb').read()
frames = [data[i*W*H*3:(i+1)*W*H*3] for i in range(len(data) // (W*H*3))]
for i in range(1, len(frames)):
    a, b = frames[i-1], frames[i]
    # count pixels whose summed RGB difference is over a threshold (60), and their box
```

Second, a map of the changed pixels, red over a dimmed frame, scaled up with nearest-neighbour so single pixels are
visible (`ffmpeg -i d72.ppm -vf scale=726:606:flags=neighbor d72.png`).

Third, sub-pixel measurements. Video is pixels, but an edge's position can be measured to a fraction of a pixel by the
centroid of the luminance gradient across it:

```python
# edges.py: the sub-pixel x of the strongest edge in a window, averaged over rows, by gradient centroid
def edge_x(d, x0, x1, y0, y1):
    tot = ws = 0.0
    for y in range(y0, y1+1):
        for x in range(x0, x1):
            g = abs(lum(d, x+1, y) - lum(d, x, y))
            tot += g; ws += g*(x+0.5)
    return ws/tot if tot else -1
```

The same idea vertically, through an icon's top border, gave the measurement that found the texture sharpening
(section 8.4): the bright band moving by fractions of a pixel while the border's outer edge stayed put.

### 2.7 One-line experiments in game

Before changing code for a cause the client does not document, the cause was tested in game with a `/run` line the
player pasted, lasting until the next `/reload`. The sharpening test:

```
/run local function f(r) for _,t in ipairs({r:GetRegions()}) do if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) t:SetSnapToPixelGrid(false) end end for _,c in ipairs({r:GetChildren()}) do f(c) end end f(BetterBagsNextBackpack)
```

The quarter-pixel text test, two lines (chat input is limited to 255 characters):

```
/run BBn=function(t)local q,p=PixelUtil.GetPixelToUIUnitFactor()/t:GetEffectiveScale()/4,{}for i=1,t:GetNumPoints()do p[i]={t:GetPoint(i)}end t:ClearAllPoints()for _,a in ipairs(p)do t:SetPoint(a[1],a[2],a[3],a[4]+q,a[5]+q)end end
/run BBw=function(r)for _,t in ipairs({r:GetRegions()})do if t.GetStringWidth then BBn(t)end end for _,c in ipairs({r:GetChildren()})do BBw(c)end end BBw(BetterBagsNextBackpack)
```

The player's answers ("holy shit that run command fixed it!", "yep that works") were the confirmation each fix was built
on.

### 2.8 Mutation checks

After every fix, each new guard was broken on purpose (a sign flipped, a rounding removed, an offset dropped) and the
suite run, to prove a test catches it. A mutation that survives means a missing test or dead code. Across this work that
found real gaps (a test added each time) and removed several pieces of code that could never change anything. Section 8.6
lists the 24 mutations of the text fix as an example.

---

## 3. The classic bag windows: float noise, a grip that jumped, and a dropped offset

This work started with a ground-up rewrite of the windowing and theme system (`f05db928`, #1136), ported from the
author's experimental Moonlight addon: a staged render pipeline where each window renders a tree of drawables, passing
constraints down and sizes up (`render/render.lua`, `render/drawable.lua`; design in `.claude/rules/render-pipeline.md`),
and Sonata, a declarative theme engine where a theme is data, not code (`sonata/`). The rewrite surfaced the first
batch of placement bugs.

### 3.1 A layout that flipped on every redraw (float noise)

A render recording of a bank whose resize grip was clicked repeatedly at the same size showed its scroll child
alternating between 2200 and 2170 units tall on every redraw, with nothing changing.

The grid's decisions are comparisons against limits that cells often hit exactly: at 6 items per row, two 3-item
sections (131 + 131) exactly fill a 262-wide row. A frame reports its size back with float noise (seen at a bag scale
of 0.65), so a size a hair over its whole value wrapped the second section, the extra row moved a section to the other
column, and the moved frames measured differently again: the layout flipped between two states forever.

The fix is to measure every cell in whole pixels before deciding anything:

```lua
-- frames/grid.lua
local function cellSize(cell)
  if cell.isGap then
    return cell.width or 37, cell.height or 37
  end
  return math.floor(cell.frame:GetWidth() + 0.5), math.floor(cell.frame:GetHeight() + 0.5)
end
```

A spec runs 1000 random layouts with and without sub-pixel noise and requires them to match.

### 3.2 A resize grip that jumped further every click

A recording of a bank after the player moved it and then resized it back and forth showed every click on the grip
resizing it before the cursor moved: 775.8 x 238.6 to 757.0 x 287.0, then 728.3 x 387.9, 665.1 x 580.7, 538.7 x 972.1,
then the screen's full height, each jump about double the last, and the drag then following the cursor 241 pixels away
from the corner. The client resized the window inside `StartSizing`, from a point an earlier move or resize had left.

The fix is one argument, found in Blizzard's own `PanelResizeButtonMixin`:

```lua
frame:StartSizing("BOTTOMRIGHT", true)   -- alwaysStartFromMouse: start from where the player pressed
```

### 3.3 Centering, and an offset the client silently dropped

Asked for: the bag's padding the same on both sides of its longest row, on every theme. Recordings showed every bag
with 12 px on the left and 26 on the right, and resizable bank windows with 12 on the left and 85 to 117 on the right.

Part of it was design (the scroll box kept its bar's 14 px on the right only; the canvas pinned content to its left
edge). Part of it was a client contract: after centering, a recording still showed items 28 px further from the right
than the left (12 vs 40, 39.4 vs 67.4), with the canvas at the scroll area's left edge. The scroll box anchored its
child with an x offset and a nil y offset, and the client drops an x offset given without a y: both are required
(`SimpleScriptRegionResizingAPIDocumentation`). The fix passes 0 for a missing one:

```lua
-- render/drawable.lua
function drawableProto:SetPoint(point)
  local x, y = point.XOffset, point.YOffset
  if x ~= nil or y ~= nil then
    x, y = x or 0, y or 0
  end
  self.frame:SetPoint(point.Point, point.RelativeTo, point.RelativePoint, x, y)
end
```

and the frame mock now raises an error for one offset without the other, so every call site that breaks the contract
fails its specs.

### 3.4 Snap to Content, and 465.99997

The windows gained Snap to Content: let go of the grip and the window shrinks to its content. The old code guessed the
content's width with a formula; an offline probe with the real grid showed snapped windows 5 to 111 px wider than
their content, depending on where the drag stopped.

The fix was a layout engine that measures before it arranges (`render/flow.lua`, and a `Measure`/`Arrange` pair on the
grid, sections, views and canvas). `Flow:Pack` is the grid's packing as a pure function, checked identical to the old
grid on 3,000 random layouts. A resizable window takes the densest layout no wider than its width, trying every items
per row from the one past which nothing changes down to one. Because the candidates do not depend on the width, the
layout chosen at the player's width is also the layout chosen at its own width, so the snapped window shows exactly the
same layout with nothing left over (a randomized test checks this over 300 bags). Planning a 591-item bank took 17 to
25 ms per render at first; skipping candidates that cannot fit brought it to 1 to 3.4 ms.

Then a float error that only showed once the window settled. A retail recording at scale 0.65 shows a bag snapped to
466 units (a layout 426 wide) and, 10 ms later, after the window re-anchored by its center to save its position, the
same window choosing the next narrower layout (344 wide), with 61 px on each side instead of 20. The client handed the
window's width back a hair under its true value (465.99997 instead of 466), and a layout exactly as wide as its room was
rejected. One decimal in the recorder printed it as 426.0, which is why the recorder now prints six. The fix:

```lua
-- window/window.lua
local SIZE_PRECISION = 100

local function withoutFloatError(value)
  return math.floor(value * SIZE_PRECISION + 0.5) / SIZE_PRECISION
end

-- the content gets its room from the frame's size rounded to a hundredth of a unit
Width = math.max(0, withoutFloatError(self.frame:GetWidth()) - insets.Left - insets.Right),
```

### 3.5 A pixel clipped off the bottom

A content-sized recording: the scroll area ended at 396 and the Free Space section at 397, cutting the bottom row of
buttons by a pixel. An empty canvas container is kept 1 pixel tall, and containers hung from the bottom of the one
above, so with no Recent Items section the rest sat a pixel lower than the reported height. The fix hangs every
container from the header's top at the plan's offsets, so the content ends exactly where the plan says.

---

## 4. Animation

### 4.1 Motion: frames that travel instead of jumping (`render/motion.lua`)

Asked for: rows, sections and item buttons glide to their new places after a sort or a loot, only what changed place
moves, easing slow, fast, slow.

The design, in one function: every frame of a layout is placed through `Motion:Place(frame, relativeTo, x, y)`, which
anchors its TOPLEFT to the TOPLEFT of the frame it hangs from. A render of a bag is a **pass**; a frame the previous pass
also placed travels from where it is to its new place; anything else (a frame newly shown, released and drawn again, or
a bag's first pass) is placed at once.

```lua
-- render/motion.lua (trimmed)
function motion:Place(frame, relativeTo, x, y)
  local pass = self.pass
  local move = self.moves[frame]
  if pass == nil then
    self.moves[frame] = nil
    put(frame, relativeTo, x, y)
    return
  end
  local placedBefore = pass.previous ~= nil and self.placed[frame] == pass.previous
  self.placed[frame] = pass.id
  if not placedBefore then                   -- not placed last pass: newly shown, or drawn again
    self.moves[frame] = nil
    put(frame, relativeTo, x, y)
    return
  end
  if move ~= nil and move.relativeTo == relativeTo and move.x1 == x and move.y1 == y then
    return                                   -- already on its way there
  end
  local cx, cy = whereIn(frame, relativeTo)  -- where it is now, in the new parent's terms
  local vx, vy = 0, 0
  if move ~= nil then                        -- turning mid-move: keep the current velocity
    local _, _, mvx, mvy = at(move, math.min(1, move.elapsed / move.duration))
    vx, vy = mvx, mvy
  end
  -- ...start a move from (cx, cy) with velocity (vx, vy) to (x, y)...
end
```

The curve is a cubic Hermite spline from the frame's position and velocity to its target at rest. From rest it is
`3u^2 - 2u^3`, slow, fast, slow; given a new target mid-move, it starts from where it is with the speed it has, so a
frame never stops before turning:

```lua
-- render/motion.lua
local function at(move, u)
  local u2 = u * u
  local u3 = u2 * u
  local h00, h10, h01 = 2 * u3 - 3 * u2 + 1, u3 - 2 * u2 + u, 3 * u2 - 2 * u3
  local d00, d10, d01 = 6 * u2 - 6 * u, 3 * u2 - 4 * u + 1, 6 * u - 6 * u2
  local t = move.duration
  local x = h00 * move.x0 + h10 * t * move.vx + h01 * move.x1
  local y = h00 * move.y0 + h10 * t * move.vy + h01 * move.y1
  local vx = (d00 * move.x0 + d10 * t * move.vx + d01 * move.x1) / t
  local vy = (d00 * move.y0 + d10 * t * move.vy + d01 * move.y1) / t
  return x, y, vx, vy
end
```

Details that each took a bug to learn:

- **Offsets are from the frame a frame hangs from**, so levels move independently: a section travels with its items
  still in it, an item travels inside a section that stays, and both compose.
- **Parents are placed before children.** When an item is placed, its new parent must already be anchored where it
  visually starts (its old spot if it is moving, its final spot if it just appeared). Before this, sections were placed
  after their items, and items moving into a section that also moved started from the wrong place.
- **An item that changes parent starts where it was on screen.** `locate` walks a frame's anchors up while they are
  TOPLEFT to TOPLEFT, summing offsets, to the frame both walks reach. A section's cells hang from its grid's inner
  frame, which Blizzard's scroll box positions, so the section "links" that frame to itself at a known offset, or the
  walk would stop.
- **A move is dropped if something else moved the frame.** Each frame of a move checks the frame is still anchored where
  the move last put it (within half a pixel: anchors read back carry float error) and still shown.
- **It never runs while the bag is hidden.** The canvas runs a pass only while its frame `IsVisible()`; its own `OnHide`
  ends every move at its target, so a bag never opens mid-move.

### 4.2 One duration for interactions: 0.24 s

BetterBags Next (the experimental redesign) asked for one number for everything that moves in answer to the player:
"that'll be our magic number for interactions". Items and sections gliding, sections making room for a dragged one, a
dropped section landing or flying into a tab, the tab bar gliding: `NextStyle.Time.Interaction = 0.24`. Motion passes
gained a duration of their own for it. The panel's slides, the fade-in cascade, hover feedback and the pickup lift keep
their own times on purpose.

### 4.3 A bounce that never shows the screen edge

Next's panels slide in from a screen edge with an `outBack` ease that overshoots. The body reached 40 px past the screen
edge, but the overshoot swings a tenth of the slide's run: a strip up to 19.4 px wide showed the world behind the bag
for about the middle third of the slide. A glow over the gap was tried and dropped ("looks weird"). The fix derives the
reach from the width and the ease, so it is always enough:

```lua
-- next/style.lua: the slide runs WIDTH + OVERREACH and swings `overshoot` of that past its place;
-- the reach is the smallest that covers the swing, plus 4 pixels (66 for the 554-pixel panel, against a 62-pixel swing)
self.OVERREACH = math.ceil(self.WIDTH * overshoot / (1 - overshoot)) + 4
```

The spec drives the real slide in 2 ms steps and checks the fill's outer edge never comes inside the screen while the
bounce still happens.

### 4.4 A texture's alpha and its vertex color are one value

Two reports looked unrelated: the small panel's border looked bright after any size switch and dim after a theme
change; the title's hover glow lit up when a bag opened, until hovered. For a texture, `SetAlpha` and the alpha of
`SetVertexColor` are one value, each replacing the other. Blizzard's chat code relies on it: `FCF_SetWindowAlpha` sets
a chat window's alpha with `SetAlpha` and `FCF_GetChatWindowInfo` reads it back from `GetVertexColor`. The switch
faded the border with `SetAlpha` and ended at `SetAlpha(1)`, replacing the theme's 0.35; painting the glow
(`SetVertexColor(..., 1)`) after its `SetAlpha(0)` lit it.

The rules: color first, alpha after, and something whose theme gives it an alpha fades through its vertex color alone:

```lua
-- next/panel.lua
function panelProto:paintEdges(strength)
  local E = style.Theme.Panel.Edge
  if not E then
    return
  end
  local r, g, b, a = style:RGBA(E.Color, E.Alpha)
  for _, edge in ipairs(self.edges) do
    edge:SetVertexColor(r, g, b, a * strength)   -- never SetAlpha: it would replace the theme's alpha
  end
end
```

The spec mock was changed to model this, so tests read a texture's alpha with `GetAlpha` and its color with the first
three values of `GetVertexColor`.

### 4.5 A gradient fades through its colors

The size switch faded the panel's feathered edge (a gradient texture) with `SetAlpha`, and in game it did not fade at
all. A gradient's alpha lives in its vertex colors (warcraft.wiki.gg `TextureBase:SetGradient`; Blizzard puts a
gradient's alpha in its colors in `Blizzard_NamePlates.lua`). The feathers are now faded by redrawing the gradient:

```lua
-- next/panel.lua
local function paint(texture, strength, solidOnLeft)
  local solid, clear = style:CreateColor(color, a * strength), style:CreateColor(color, 0)
  if solidOnLeft then
    texture:SetGradient("HORIZONTAL", solid, clear)
  else
    texture:SetGradient("HORIZONTAL", clear, solid)
  end
end
```

### 4.6 A size switch in two steps

Switching a Next panel between its full and small size first cross-faded the border and the feathered edge over the
whole glide, which made it "look like the feathering is spilled out". Asked for "a 2 step animation": shrinking, the
body glides to its spot with the feathers fading out, then the border fades in; growing, it moves at once with the
border fading out on the way, then the feathers fade in, "basically the inverse of shrinking". Switched back mid-way, it
turns around from where it is. Anything else that places the panel ends a switch first, both steps.

### 4.7 Two bags that only coupled sometimes

Chaining puts the backpack beside the bank, and once the chained bag comes to rest the two "couple" (their ribbons
intertwine into a braid). Reported: the braid "only appears sometimes", never at the bank. The pair coupled only when
the chained bag's target equalled its rest place exactly, and that place came from the tab rails' widths read back with
`GetWidth`, with float error at a UI scale. Off by a hair, it never coupled until something listed the tabs again. Two
fixes, either sufficient for the test that reproduced it: the rails use the widths they set instead of reading them
back, and a place within half a pixel is the place:

```lua
-- next/chain.lua
local PLACED = 0.5
if math.abs(x - panel.placeX) < PLACED and math.abs(y - panel.placeY) < PLACED then
```

The specs had missed it because the mock returns exact sizes; a test that read the widths back with a 0.0001-pixel
error reproduced it.

### 4.8 The snap's bounce, shared

The classic windows snap to their content with a bounce, and BetterBags Next's small panels later snapped to their
icons the same way, so the curve moved into Motion: it eases out (cubic) to a tenth of the distance past the target (at
most 10 units, never below the minimum) in 65% of the time, then settles back (smoothstep):

```lua
-- render/motion.lua
function motion.SnapSizeAt(from, to, overshoot, p)
  if p <= 0 then return from end
  if p >= 1 then return to end
  local low = to - overshoot
  if p <= SNAP_TURN then                                   -- SNAP_TURN = 0.65
    local q = p / SNAP_TURN
    return from + (low - from) * (1 - (1 - q) ^ 3)
  end
  local q = (p - SNAP_TURN) / (1 - SNAP_TURN)
  return low + overshoot * q * q * (3 - 2 * q)
end
```

While a snap runs, the window hands its content the target width as its layout width, so the layout never changes
mid-bounce: the bounce stays inside the scroll bar's room. Section 8.5 has the bug this bounce later exposed.

### 4.9 What moves is not snapped

The pixel rules of section 5 apply to things at rest. What moves (glides, slides, drags, lifts, flights, sparkles, the
title cloud's breathing, the braid, a toggle's knob, a theme's swaying ornaments) is never rounded, and lands on whole
pixels when it comes to rest. The in-game check leaves moving parts out by checking twice and keeping only what agrees.

---

## 5. Pixel perfect: the report, the wrong first fix, and NextPixel

### 5.1 The report

On BetterBags Next's settings window, the selected theme card on the Appearance page lost its top border at the
game's UI scale of 65%, and its bottom border at 70%, in a maximized window; never in true fullscreen.

### 5.2 The wrong first fix (reverted)

The first fix assumed a screen 1080 pixels tall. At a UI scale of 65% on such a screen, a UI unit is 0.914 screen
pixels (`uiScale` 0.65 against the client's 768-unit height), so a 1-unit line is under a pixel thick and draws only
where it happens to cover a pixel's center. The fix made every control edge at least one screen pixel thick, with
tests, and was committed.

Then the game's own log (`Logs/gx.log`) showed the player's window renders at 3396x1362, where a unit is 1.153 pixels:
a 1-unit border is already more than a pixel thick there. The fix changed nothing on the reporter's screen, and was
reverted. The commit message records why, which is worth quoting in a post about measuring before fixing:

> The fix assumed a screen 1080 pixels high (0.914 screen pixels per UI unit at the game's UI scale of 65%), so that
> 1-unit borders were under a pixel thick and vanished. The game's own log (Logs/gx.log) shows the reporter's window
> renders at 3396x1362 (maximized), 1.153 pixels per unit, where a 1-unit border is already more than a pixel thick:
> the fix changed nothing there, and the border still went missing.

### 5.3 The real cause

BetterBags Next placed everything in whole UI units. At 1.153 or 1.241 pixels per unit, its frames and lines landed
between screen pixels, and the client snapped each texture's corners to the grid on its own: a 1-unit line drew 1 or 2
pixels thick, or not at all, depending on where it landed. The card's top edge happened to land badly at 65%, its
bottom edge at 70%.

A first measurement with the new check: a full backpack at 3396x1362 at 65% had 59 regions off the grid, all from its
554-unit width (638.6 pixels) on.

Asked for next: "be sure to cover pixel perfection in *everything*, windows, borders, icons, themes, everything.
EVERYTHING, all placement, everything everywhere."

### 5.4 What pixel perfect means

At rest, every frame and texture of a BetterBags Next window has its four edges on whole screen pixels, at any screen
size, UI scale, Bag Scale and theme. (Text has a rule of its own, section 8.6.) The rules every placement follows:

- **Lengths** (sizes, gaps, pads, insets, thicknesses, icon sizes, every theme layout value) are rounded where they are
  used, on the grid of the region they size, never below one pixel when not zero. Sums of whole pixels stay whole, so
  rows of icons step evenly.
- **Offsets** are whole pixels from a point that is itself on a whole pixel: a corner or an edge of an aligned region.
- **Never anchor by a middle point** (`CENTER`, `TOP`, `LEFT`...) unless that region is an even number of pixels across.
  Center by a corner offset instead, the odd pixel going right and down.
- **Never anchor from a text's far edge or middle.** They follow the client's measure of the text, between pixels.
  Place what follows a text from the shared corner, by the text's width rounded up.
- **Room a text may take is rounded down; room a text needs is rounded up.**
- **Windows start from UIParent's corners**, which are always whole pixels.

### 5.5 NextPixel (`next/pixel.lua`)

Every rule is a helper, so the rule is applied by calling it rather than remembered:

```lua
-- Round is half away from zero, as Blizzard's (Blizzard_SharedXMLBase/MathUtil.lua).
local function round(value)
  if value < 0 then
    return math.ceil(value - 0.5)
  end
  return math.floor(value + 0.5)
end

-- Snap: an offset in whole pixels (may be none).
function pixel:SnapIn(unit, units)
  return round(units / unit) * unit
end

-- Length: a size in whole pixels, never less than one pixel when it is not none, so a thin line always draws.
function pixel:LengthIn(unit, units)
  if units == 0 then
    return 0
  end
  local n = round(units / unit)
  if n == 0 then
    n = units < 0 and -1 or 1
  end
  return n * unit
end

-- Floor: room something may take. Ceil: room something needs (a text's width).
function pixel:FloorIn(unit, units)
  return math.floor(units / unit + 1e-6) * unit
end
function pixel:Ceil(region, units)
  local unit = self:Unit(region)
  return math.ceil(units / unit - 1e-6) * unit
end
```

The `1e-6` in `Floor` and `Ceil` is there because a value that is exactly whole often arrives as 3.9999999 or
4.0000001, and must not lose or gain a pixel for it.

Centering without a middle point:

```lua
-- Middle: the offset that centers a length in another, in whole pixels, the odd pixel after.
-- A text or an icon is centered on a row by its top this far down, never by its middle,
-- which lies between two pixels on a row an odd number of pixels tall.
function pixel:Middle(region, outer, inner)
  local left = self:Pixels(region, outer) - self:Pixels(region, inner)
  return math.max(0, math.floor(left / 2)) * self:Unit(region)
end

-- Row: by a top corner, centered on a row by its height (a font string by its font's height).
function pixel:Row(region, corner, relativeTo, x, rowHeight, height, top)
  if height == nil then
    height = region:GetObjectType() == "FontString" and self:TextHeight(region) or region:GetHeight()
  end
  local across = self:Snap(region, x)
  local down = self:Snap(region, top or 0) + self:Middle(region, rowHeight, height)
  local q = self:TextOffset(region)    -- section 8.6
  region:SetPoint(corner, relativeTo, corner, (corner == "TOPRIGHT" and -across or across) + q, -down + q)
end
```

The full table of helpers (`Unit`, `Snap`, `Length`, `Lengths`, `Floor`, `Ceil`, `Pixels`, `Point`, `Inset`, `Size`,
`Width`, `Height`, `Middle`, `Row`, `Center`, `TextHeight`, `TextOffset`, `TextInsets`, `SnapScroll`, `Key`,
`FontHeight`) is in `.claude/rules/next-pixel-perfect.md` §5.

### 5.6 Before and after, one placement

A section's title row, before (`next/content.lua` before the pixel work):

```lua
title:SetPoint("TOPLEFT", inner, "TOPLEFT", S.Title.X, S.Title.Y)
count:SetPoint("LEFT", title, "RIGHT", S.CountGap, 0)   -- by the text's far edge and middle: between pixels
line:SetPoint("LEFT", count, "RIGHT", S.LineGap, 0)     -- and the line from the count's, so the error carries
line:SetPoint("RIGHT", inner, "RIGHT", 0, 0)
```

after (`next/content.lua`):

```lua
local x, y = pixel:Snap(inner, S.Title.X), pixel:Snap(inner, S.Title.Y)
pixel:Point(title, "TOPLEFT", inner, "TOPLEFT", x, y)
local titleHeight = fontHeight(title)
-- the count from the shared corner, past the title's measured width rounded up, centered by the fonts' heights
local countX = x + pixel:Ceil(inner, title:GetStringWidth()) + pixel:Snap(inner, S.CountGap)
pixel:Point(count, "TOPLEFT", inner, "TOPLEFT", countX, y - pixel:Floor(inner, (titleHeight - fontHeight(count)) / 2))
local lineX = countX + pixel:Ceil(inner, count:GetStringWidth()) + pixel:Snap(inner, S.LineGap)
local lineY = y - pixel:Floor(inner, (titleHeight - line:GetHeight()) / 2)
```

### 5.7 Scrolling by whole pixels

Blizzard's scroll box anchors its scroll target at the scroll offset in UI units
(`ScrollBoxBaseMixin:SetScrollTargetOffset`, called by its `Update` every time it scrolls or lays out), so whatever a
box holds lands between pixels wherever it is left scrolled. The fix replaces the box's own copy of that method (the
mixin copies it onto the box) with one that rounds first:

```lua
-- next/pixel.lua
function pixel:SnapScroll(box)
  if box.nextSnapsScroll then
    return
  end
  box.nextSnapsScroll = true
  local set = box.SetScrollTargetOffset
  box.SetScrollTargetOffset = function(b, offset)
    return set(b, self:Snap(b, offset))
  end
end
```

Every scroll box BetterBags Next makes calls it; interpolated scrolling then steps a pixel at a time and rests on the
grid. The mock's scroll box was changed to anchor its target at the offset, as Blizzard's does, and every scrolled pixel
test fails with the rounding disabled.

### 5.8 A new grid: the UI scale or the window's size changes

`NextPixel:Key()` names the grid at UIParent: its effective scale and the screen's height. Font heights are made for a
grid (section 9.1), so on `UI_SCALE_CHANGED` and `DISPLAY_SIZE_CHANGED` the current theme is applied again, unsaved,
when the grid is a new one:

```lua
-- next/pixel.lua
function pixel:OnGridChanged(ctx)
  local sonataNext = addon:GetModule('SonataNext')
  local style = addon:GetModule('NextStyle')
  local key = sonataNext.started and sonataNext:GetCurrentThemeKey() or nil
  if key == nil or style.gridKey == self:Key() then
    return false
  end
  sonataNext:ApplyTheme(ctx, key, false)
  return true
end
```

Two more grid changes are local:

- **A panel that changes scale** (a Bag Scale, a size switch) styles its parts again when the pixel's size in it
  changed.
- **The settings window takes its scale before anything in it is made** (at most 95% of the screen), so every part is
  laid out on the grid it is drawn on; reopened at another scale, every widget restyles.

### 5.9 Item buttons and Blizzard's template parts

Item buttons are shared with the classic bags and built from `ContainerFrameItemButtonTemplate`, whose parts (stock
text, junk coin, quality border, overlays, glows, the crafting quality pip, the cooldown) are anchored by Blizzard's
XML, often by their middles. Two pieces handle them while Next is in use:

- **Sonata's item button styler rounds what it places** (icon inset, count, backdrop edges, upgrade arrow) through a
  snap table Next provides (`SonataElements:SetItemButtonSnap`), and records the grid it rounded on.
- **`NextItemFit:Fit` places the template's own parts** in whole pixels: text from its corners, borders filling the
  button, glows centered at their own size. It remembers where each part was and puts it back before the classic bags
  take the buttons over.

Blizzard's templates are kept, never rebuilt: the bank's Purchase Bank button must keep
`BankPanelPurchaseButtonScriptTemplate` (its own `OnClick` opens the protected purchase), so its size, its place, its
12-unit end pieces and its text are rounded in place without touching its scripts.

### 5.10 Masque: two borders round every item

Reported after the item fitter shipped: with Masque, two borders round each item with a quality border, after a
`/reload`. Masque skins a button as it is announced and on every full draw, before Next's canvas lays it out; the
fitter then pulled the quality border in to fill the button, inside the skin's own frame (the Caith skin sizes it
42/36 of the button, centered, in Masque 12.1.0's `Core/Regions/IconBorder.lua`). The fix: on a button in one of
BetterBags' Masque groups, the fitter leaves the parts Masque places where Masque put them and forgets where they were,
so restoring them never puts them back over the skin either. The same conflict was found and fixed on vendor cards and
guild bank buttons, each of which now announces its own restyle so the integration skins it again.

### 5.11 Coverage

Every Next window passes the check on every screen listed in 2.2, full and small, at Bag Scales of 50 to 150%, Icon
Scales of 85 and 115%, in every shipped theme, chained both ways, scrolled partway, after a drag, after a grip resize,
at both ends of a size switch, and after the grid changes under open bags (`spec/next/pixel_perfect_spec.lua`, the
controls', settings' and vendor's specs). The theme card that started it has a test that checks each of its four edges
is exactly one pixel, on whole pixels, at 65% and 70%; it fails on the old code with exactly the reported numbers.

---

## 6. What the in-game pixel check found

The specs check states someone thought of, on a mock. The in-game check found what nobody thought of, on the real
client. Each finding below came from a report saved in SavedVariables, read offline.

### 6.1 Masque, and Blizzard's crafting quality pip

A Check Now on a small backpack at Bag Scale 90% (3396x1362 at 65%, Masque's Caith skin) reported 116 parts off the
grid. 113 were Masque's skin, sized 42/36 of the 46-pixel button (53.667 pixels; its count 2 units, 2.075 pixels, in
from the corner): deliberate, Masque's to decide. That led to listing Masque's parts apart (section 2.3).

The other 3 were ours: Blizzard's crafting quality pip on reagents, 34.2 x 29.0 pixels, 3.1 pixels left of the button.
Blizzard makes the pip the first time a button draws a crafting item, at `TOPLEFT (-3, 2)`, and sizes it to its atlas
on every draw (`SetupCraftingQualityOverlay`), so it cannot be placed once per grid like the other parts. The fitter
now places parts a draw sizes on every layout, before its nothing-changed early return.

### 6.2 A ribbon 0.111 pixel off after a Bag Scale change

After changing the Bag Scale from 90% to 95% with the backpack open: 7 parts off the grid, the title ribbon and its six
glow lines, all with the same left edge at 2355.111 pixels. The slider refits an open panel through a path that took the
new scale and restyled the panel's parts, but did not set the ribbon's length again, so the lines kept a length rounded
on the old grid. A test reproducing the steps (open at 90%, then 95%, 85%, 100%, 115% as the slider does) failed with
exactly the reported parts and the same 0.111-pixel offset before the fix.

### 6.3 A dragged section's room, 0.062 pixel short

After dragging a section up one place in a small backpack at Bag Scale 55%: 43 parts 0.062 pixel off, sections 2 and 4
to 8 and their items, section 3 taking no room, section 2 one room lower. That is the column of a drag in progress: the
column keeps a room the dragged section's height at the index it will land on.

Reproduced with the real drag at that scale, tweens running each frame: the room's height came from laying out the held
section on its own frame, which the lift draws shrunk (to 94%): an effective scale of 0.3361 against the column's
0.3575, so the room was 42.553 pixels instead of 43, and every section below stood between pixels while the section was
held and while it landed. The fix measures the room on the column's grid:

```lua
-- next/content.lua: a section drawn on another grid than the column's (held in a drag, drawn shrunk; flying back
-- from a dock) takes room measured on the column's: its own grid's whole pixels are not the column's.
function canvasProto:MeasureSection(section, grid, width, layoutWidth)
```

One thing stayed unexplained, and the notes say so: Check Now checks twice 0.25 s apart, and a landing takes 0.24 s,
so both checks should not fit inside a landing. Rather than guess, each check now keeps a description of the drag state,
for the next capture.

### 6.4 Cooldown countdowns, middles at .500

After consuming items: 14 cooldown countdowns off the grid, their middles at x .500 and y .347. The client hangs the
countdown font string by its middle from the cooldown's middle, and `CooldownFrameTemplate` fills the button: on a
51-pixel button, the middle is between two pixels. Its numbers change every second, set by the client, so they cannot be
measured and placed. The fitter spans it across the cooldown from its top corners, the client centering the numbers, on
the row its font's height is centered on:

```lua
-- next/itemfit.lua
local down = pixel:Middle(text, cooldown:GetHeight(), pixel:TextHeight(text))
text:ClearAllPoints()
pixel:Point(text, "TOPLEFT", cooldown, "TOPLEFT", 0, -down)
pixel:Point(text, "TOPRIGHT", cooldown, "TOPRIGHT", 0, -down)
text:SetJustifyH("CENTER")
```

The same report listed two click-button `NormalTexture`s, 64 units square, which BetterBags empties at creation and
which likely draw nothing. Not assumed: the check now notes, for each part, what a texture draws (file, atlas, or
"draws nothing") and, for a text, its anchors and where its first anchor lands against where the client draws it.

---

## 7. A layout must never depend on the pixel grid

Reported: scaling a small bag up or down moved items between rows. "Every item should technically render in exactly the
same place, no exception." 13 Consumables in rows of 7 at a Bag Scale of 100%, rows of 8 at 105%.

The cause, before:

```lua
-- next/content.lua, before
local cellWidth, cellHeight = pixel:Lengths(f, style.ICON, style.ICON)
local gap, header = pixel:Lengths(f, style.GAP, style.SECTION_HEADER)
local step, rowStep = cellWidth + gap, cellHeight + gap
local perRow = math.max(1, math.floor((width + gap) / step + 1e-6))   -- decided on lengths rounded to the grid
```

How many cells fit a row was decided on the width, icon and gap each rounded to the panel's pixel grid, and that grid
changes with the panel's scale. A probe of the real panel over widths 380 to 520 units and Bag Scales 50% to 150% found
16 to 28 of 71 widths laid out differently on the reporter's screen at 65% and 70%, on 1920x1080 at 64%, and on
2560x1440 at 100%.

The rule that came out of it: **what is decided (how many cells go in a row) is decided in design units; only where
things stand is rounded.**

```lua
-- next/content.lua, after
function canvasProto:PerRow(layoutWidth)
  local step = (self.cards and style.VENDOR_CARD_WIDTH or style.ICON) + style.GAP
  return math.max(1, math.floor((layoutWidth + style.GAP) / step + 1e-6))
end
```

`layoutWidth` comes from the panel (`panelProto:LayoutWidth`): a small panel's width as the player left it, in its own
units, kept within its minimum and the screen but never rounded. The scroll box takes its bar's room off it in units,
never the room rounded to the grid.

That creates a new problem: cells still stand on the grid's whole-pixel step, and the rounded step can run up to a pixel
per cell past the width (measured: 9 pixels, over a scroll bar room as small as 6). So where a row would run past its
width, the gap closes by the pixel or two the rounding added. After the fix, the same probe found no width laid out
differently on any of the four screens, no row running past the content, and the gap closing in 3% to 8% of layouts,
by 1 pixel (2 at most). Section 8.1 is the bug hiding in "past its width".

---

## 8. Resize jitter, five causes deep

BetterBags Next's small panels can be resized with grips on their bottom corners. On October 25 the player reported
"a ton of item icon jitter all over" while resizing. It was not one bug. Each fix below removed one cause and exposed the
next, and each needed a different tool to see.

### 8.0 First, the snap to icons

The same day added the feature that framed the rest: let go of a grip and the panel shrinks to its widest row of icons,
as laid out at the width it was let go at ("if i drag the window to be too big ... it should shrink back down to where
the icon is"). Every row stays as it was, a section wider than the panel keeps wrapping where it wrapped, no column is
added, and the edge the player dragged moves while the side across stays still. A first version snapped to the columns
a row held at the width let go at, which only took off the fraction of a column past the last one; it was the wrong
idea and was replaced the same day.

```lua
-- next/panel.lua
function panelProto:SnapWidth(width)
  local room = self:ContentRoom()
  local perRow = self.content:PerRow(width - room)
  local widest = self.content:Widest()     -- cells in the largest section the column lays out
  if widest > 0 then
    perRow = math.min(perRow, widest)
  end
  return math.max(self:MinWidth(), self.content:RowWidth(perRow) + room)
end
```

It glides there with the classic windows' bounce (section 4.8), and keeps its layout width through the bounce so no
icon moves.

### 8.1 Cause one: gaps that closed and reopened (simulated)

Before touching the game, the drag was simulated (section 2.5): a grip dragged a pixel a frame over 700 pixels, on six
screens, at Bag Scales of 100%, 85% and 55%, from both grips. A pixel or two after each column was added, every icon
jumped a second time: 8 to 18 such frames per drag, up to 19 pixels across at the far end of a row, and every row 1 to 3
pixels down. On the reporter's screen it showed; on 1920x1080 at UI scale 1, none, because the rounding runs the other
way.

The cause was the gap-closing rule of section 7, which closed the gap for the width the row was **drawn** in:

```lua
-- next/content.lua, before
gap = math.max(0, math.min(gap, pixel:Floor(grid, (width - perRow * cellWidth) / (perRow - 1))))
```

`perRow` was decided on the layout width (units, never rounded), but `width` was the drawn width, which follows the
frame and the scroll box's rounded room. Just past the width where a column is added, the drawn width was a pixel or two
short of the rounded row, so the gaps closed; a pixel or two later it caught up and they opened. Rows step by the same
gap, so every row moved down too.

The fix closes the gap for the row's **own** width at its column count, so a column count keeps one layout whatever
width it is drawn in:

```lua
-- next/content.lua, after
function canvasProto:RowWidth(perRow)
  return perRow * ((self.cards and style.VENDOR_CARD_WIDTH or style.ICON) + style.GAP) - style.GAP
end

if perRow > 1 then
  gap = math.max(0, math.min(gap, pixel:Floor(grid, (self:RowWidth(perRow) - perRow * cellWidth) / (perRow - 1))))
end
```

After: no icon moves without a column being added or taken away, in any of the 36 simulated drags. A row runs past the
width drawn by at most a pixel (one case), into the scroll box's room for its bar, never past the scroll box. A mutation
that rounded the row to whole pixels first turned out equivalent (the gap is rounded down after) and was dropped.

### 8.2 Cause two: the scroll box keeps a percentage (simulated)

Reported after that fix: the jitter is still there "on Y, it's ever so slight", "in any direction". The simulation was
extended to diagonal and height-only drags, scrolled and not. Not scrolled: no icon moved, in any direction. Scrolled
partway: everything shown moved a pixel every few frames, 15 or 16 frames of 150.

Blizzard's scroll box keeps its scroll **percentage** as its height changes (`ScrollBoxBaseMixin:OnSizeChanged` updates
it; the offset is the scroll range times the percentage), so the pixel offset follows the height. The fix keeps the
offset in pixels while a grip sizes the panel, as a browser keeps the top of a page where it was:

```lua
-- next/panel.lua
function panelProto:KeepScroll()
  local kept = self.keptScroll       -- read when the grip was pressed
  if kept == nil or (self.sizing == nil and not self.sizeGliding) then
    return false
  end
  local box = self.scroll.scrollBox
  if math.abs(box:GetDerivedScrollOffset() - kept) < 0.001 then
    return false
  end
  box:ScrollToOffset(kept, true)
  return true
end
```

It runs from a hook on the scroll box's own `OnSizeChanged`, which runs after Blizzard's handler and before the frame is
drawn. Restoring from a later render is a frame late and still flickers. The spec mock's scroll box was wrong in the
same way the game is subtle: it kept the percentage on `FullUpdate` (Blizzard keeps the offset there) and had no
`OnSizeChanged`. It now behaves as Blizzard's does, and the whole suite passed unchanged with it.

### 8.3 The model runs out: record the game

The player still saw slight jitter. In the model, unscrolled, every icon and every frame it hangs from stayed on the same
whole pixels while the panel was sized, so if icons still moved in game, the client was doing something the model did not
(`StartSizing` is not documented). Tooling first: the render recorder learned to record each sizing step with the
panel's anchors, the scroll offset and each shown section's first and last icons (holder, art, border), every rect in
screen pixels with three decimals.

The first in-game recording (retail 12.1.5, 3396x1362 at 65%, a small backpack at Bag Scale 150%, 247 steps of a grip
dragged up and down) showed nothing we recorded moving:

- every recorded icon's holder, art and quality border on the same whole pixels at every step (except two that moved a
  whole column as a row reflowed);
- the panel's top left still at 2323,1310, its bottom edge moving one whole pixel at a time;
- the scroll offset at 0.

A guess that Masque's shadow was the culprit was wrong: Masque was off for every BetterBags group in the player's saved
settings. That commit's Masque logging was removed. The player described it more precisely: "you can see the shadowing
changes just by slight resize of the window up and down (no icons shifted their actual position)". So the recorder
learned to list every region that draws in the panel and diff it step to step (section 2.1).

### 8.4 Cause three: the client's texture sharpening (video)

The next recording listed every region in the panel at the same whole pixels at all 337 steps, icon art and borders
included (`t 825.000 b 749.000`). Only the scroll box's clip edge moved. Every rect the API could report was still.

So the player recorded a 60 fps video of the same drag (242x202 pixels, 390 frames), and the frames were diffed
(section 2.6). Most frame pairs differed by a few pixels of compression noise; a few differed by hundreds of pixels,
along the icons. The changed-pixel maps showed only **horizontal edges inside the icons**: their top borders and the
horizontal lines of their art. The section title, its line and every vertical edge never changed.

A column of pixels through an icon's top border, measured by luminance centroid frame by frame:

```
frame   row 1 band   row 2 band
  1     72.799       157.930
 73     72.654       157.858
 84     72.767       157.556
103     72.604       157.910
...
119     72.524       157.857
191     72.508       157.651
```

The border's outer edge stayed on the same pixel row. The bright band inside it moved by up to 0.3 of a pixel in the
first row of icons and 0.45 in the second, and the two rows did not move together. Nothing moved; the client picked
different texels inside unmoving quads as the window's height changed: the sharpening of section 1. Blizzard turns it
off on its own textures that resize (`PlayerFrame.lua`, `TargetFrame.lua`, `AlternatePowerBarBase.lua`,
`NineSliceUtil.DisableSharpening`); ElvUI turns it off on every texture it touches (`Toolkit.lua`, `DisablePixelSnap`).

The `/run` test of section 2.7 turned both settings off on every texture of the backpack until the next reload, and the
shading stopped. The player asked for it on "literally all bags", and "be sure to also do it for masque skins". The
module:

```lua
-- render/texels.lua
local SHARPENED = { Texture = true, MaskTexture = true, Line = true }
local own = setmetatable({}, { __mode = "k" })

function texels:DrawsItself(frame)
  own[frame] = true
end

function texels:Unsharpen(root)
  local count = 0
  local function walk(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
      if SHARPENED[region:GetObjectType()] then
        region:SetSnapToPixelGrid(false)
        region:SetTexelSnappingBias(0)
        count = count + 1
      end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
      if not own[child] then
        walk(child)
      end
    end
  end
  walk(root)
  return count
end
```

Where it runs matters as much as what it does:

- **Item buttons mark themselves** (`DrawsItself`) and unsharpen on each full draw, so a bag of hundreds of buttons is
  walked by the buttons that changed, never all of them on every draw.
- **After `item/Updated`**, because Masque makes a skin's textures (its shadow, gloss) as it skins a button.
- **Panels and windows** after each draw's render, because the render styles what it lays out.
- **Masque's re-skins**, including Masque's own callback when it re-skins a group for an option the player changed.
- **Every time**, because whether a new file or atlas brings the sharpening back is not known. A sizing recording now
  records each texture's snap and bias, so the next capture can answer it.

BetterBags Next places everything on whole pixels itself, so the client's rounding adds nothing there.

### 8.5 Cause four: a clipping frame between two pixels (video and recording)

Reported after that: "when i drag to resize a window, no shimmer. but let's say i drag a bag really wide and let go, when
it snaps back, the icons shimmer ... unclear ... if it's the texture shimmer, or actual movement".

A 60 fps video of the release (1378x450, the Consumable row of 13 icons), each icon's left edge measured by gradient
centroid against a frame before the release:

```
frame  i1     i2     i3     i4     i5     i6     i7     i8     i9     i10    i11    i12    i13
 87   +0.00  +0.00  +0.00  +0.00  +0.00  +0.00  +0.00  +0.02  +0.00  -0.01  -0.02  -0.02  -0.03
 88   -0.00  +0.00  +0.00  +0.00  +0.00  +0.00  +0.00  +0.03  +0.00  -0.02  -0.05  -0.07  -0.10
 90   +0.00  +0.00  -0.01  -0.11  -0.08  -0.29  -0.12  -0.30  -0.22  -0.17  +0.06  -0.12  -0.06
 93   +0.00  +0.02  +0.05  -0.02  -0.20  -0.02  +0.04  +0.20  +0.15  +0.13  +0.23  +0.00  +0.05
```

The first icon never moved; the shift grew with distance from the panel's left edge (up to 0.34 pixel at the thirteenth),
flipped sign from frame to frame, and died out as the snap settled, every icon back where it was. That is a **stretch**
from the left edge, not icons moving apart: the gaps were fixed by the column count, and the snap keeps its layout width.
With the sharpening off, a stretch shows as blending across two pixels.

A sizing recording of a snap explained it. While a grip is dragged, the client sizes the panel in whole pixels: every
`resized` step had the scroll box's edges on whole pixels (`r 2985.000`, `b 337.000`). During the snap, the right edge
sat between pixels every frame (`r 3025.847`, `3004.432`, `2988.494`, ...) until it came to rest at `r 2985.000`. The
snap set the frame's width from its bounce each frame, unrounded:

```lua
-- next/panel.lua, before
local current = motion.SnapSizeAt(w, width, overshoot, p)
frame:SetSize(current, height)
```

The scroll box clips its children (`clipChildren="true"`), and the shimmer appeared exactly while its edge was fractional
and never while it was whole. Inferred, not seen in Blizzard's code: the client draws what a clipping frame holds
stretched across its rect when that rect's edge is between two pixels. The fix sizes the snap in whole pixels every
frame, as a dragged grip does:

```lua
-- next/panel.lua, after
-- In whole pixels, as a grip dragged sizes it: its scroll box clips what it holds, and a clipping frame's edge
-- between two pixels drew what it holds stretched across the fraction (texture-sharpening.md §5).
local current = pixel:LengthIn(self:PixelUnit(), motion.SnapSizeAt(w, width, overshoot, p))
frame:SetSize(current, height)
```

Shift-click's glide back to the default size got the same treatment, plus the corner it moves placed on whole pixels.
Left as it was: the full/small switch, which changes the panel's scale as it glides, so its content is drawn at another
scale through it anyway.

New rule: **a frame that clips stays on whole pixels, even while its size glides.** The bounce then steps a pixel at a
time, which at 60 fps over 0.35 s looks the same.

### 8.6 Cause five: text exactly on a whole pixel (video, recording, `/run`)

With all of the above fixed, a last report: tab names and counts jumped. In a 60 fps video, the "Backpack" and "Housing"
tab labels and the "13" item count moved right by exactly 1.00 pixel at the frame the snap ended, and stayed there.
During the snap itself nothing moved. The "Consumable" title and the icons never moved.

The recording had it in two lines (section 2.1):

```
snap     ~ BetterBagsItemButton170DecorationCount | FontString | l 2758.999 t 545.000 r 2776.999 b 521.000 | text "4"
snapped  ~ BetterBagsItemButton170DecorationCount | FontString | l 2759.000 t 545.000 r 2777.000 b 521.000 | text "4"
```

The snap's first step moved the panel's anchor by a few ten-thousandths of a pixel, and its last step put it back. The
texts followed, from 2759.000 to 2758.999 and back. A text whose left edge did not cross a pixel boundary never
jumped: "Housing" read 2369.086, then 2369.087; "Back"'s left edge read 2541.000 at both steps.

The cause, inferred from those measurements (how the client rounds text is not documented): **the client draws a
text's glyphs in whole pixels**, and the pixel-perfect layout put every text exactly on a whole pixel, right at the
boundary. Float error of a thousandth of a pixel then decided which pixel the glyphs landed in. Textures shift the same
thousandth and nobody can see it; a text jumps a whole pixel.

The fix: place every text a quarter pixel right of and above a whole pixel, where it is drawn in the same pixel whether
the client rounds or truncates. The `/run` test (section 2.7) moved every text of the backpack a quarter pixel and the
jump stopped ("yep that works"). Then it was built into the helpers, so it cannot be forgotten:

```lua
-- next/pixel.lua
local TEXT_OFFSET = 0.25

function pixel:TextOffset(region)
  if region:GetObjectType() ~= "FontString" then
    return 0
  end
  return TEXT_OFFSET * self:Unit(region)
end

function pixel:Point(region, point, relativeTo, relativePoint, x, y)
  local q = self:TextOffset(region)
  region:SetPoint(point, relativeTo, relativePoint or point, self:Snap(region, x or 0) + q,
    self:Snap(region, y or 0) + q)
end

-- An edit box's text area: left and bottom a quarter more, right and top a quarter less, so its text moves a
-- quarter pixel right and up while the box itself stays on whole pixels.
function pixel:TextInsets(box, left, right, top, bottom)
  local q = TEXT_OFFSET * self:Unit(box)
  box:SetTextInsets(self:Snap(box, left) + q, self:Snap(box, right) - q, self:Snap(box, top) - q,
    self:Snap(box, bottom) + q)
end
```

The offset is added after rounding, so rounding never removes it. `Point`, `Inset` and `Row` add it for font strings and
nothing else; textures stay on whole pixels (with sharpening off, a fraction would blend them). Template texts placed by
other code got it too: the item fitter's stock, item level and countdown, and Sonata's item count through a new `Text`
entry in its snap table.

The pixel check now requires text at the quarter offset, so every pixel test of every Next window and control fails on a
text left on a boundary. That immediately found one more bug: the dock card hung its warning line from its title and its
slot from the warning, so the quarter pixel **stacked** (the slot half a pixel off). New rule: **never hang anything
from a text**; hang it from the frame the text hangs from, by the sum of the offsets:

```lua
-- next/dockcard.lua
local pad, title, line = pixel:Lengths(frame, D.Pad, D.TitleHeight, D.LineHeight)
local a, b = pixel:Lengths(frame, UNDER_TITLE, UNDER_WARNING)
local warningTop = pad + title + a
pixel:Point(self.warning, "TOPLEFT", frame, "TOPLEFT", pad, -warningTop)
pixel:Point(self.warning, "TOPRIGHT", frame, "TOPRIGHT", -pad, -warningTop)
pixel:Point(self.slot, "TOPLEFT", frame, "TOPLEFT", pad, -(warningTop + line + b))
```

24 mutations of the new guards (the offset, each axis of `Point` and `Row`, the offset applied to non-text, each inset and
its sign, the check's rules, the dock card's chained lines, the fitter, both snap tables, the money, the search boxes'
and inputs' insets): every one caught. The one that first survived (Next's item snap giving no offset) led to a test; two
offsets that could only ever apply to textures were removed as dead code.

The classic bags were left unchanged: they never place text on whole pixels, so their text sits off the boundary already.

### 8.7 What each cause needed to be seen

| Cause | Symptom | Seen with |
|---|---|---|
| Gap closed for the drawn width | icons jump a second time after each column | simulated drag in the specs |
| Scroll percentage | scrolled content moves a pixel every few frames | simulated drag, scrolled |
| Texture sharpening | shading inside icons changes, nothing moves | video, luminance centroid |
| Fractional clipping edge | icons stretch during the snap's bounce | video, per-icon edges, sizing recording |
| Text on a boundary | tab names and counts jump 1 px at the snap's end | video, sizing recording's 2758.999 |

---

## 9. Fonts and text

Text caused more distinct bugs than anything else in this work, because the client gives addons the least control over
it: you choose a font object and an anchor, and the client measures, wraps, truncates and rasterizes on its own terms.

### 9.1 Font heights in whole pixels, per grid

A font at 13 units is 14.99 pixels at 1.153 pixels per unit. Every BetterBags Next font role is made at a whole number
of screen pixels at UIParent's grid, the nearest to the theme's size, copied client fonts included:

```lua
-- next/pixel.lua
function pixel:FontHeight(size)
  return self:Length(UIParent, size)
end

-- next/style.lua (trimmed): each role's font object, made once for the current theme and grid
function style:makeFont(role, spec)
  fontCount = fontCount + 1
  local font = CreateFont("BetterBagsNextFont" .. role .. fontCount)
  if spec.Object ~= nil then                       -- a copy of one of the client's fonts
    local base = _G[spec.Object]
    font:CopyFontObject(base)
    local path, size, flags = font:GetFont()
    font:SetFont(spec.File or path, pixel:FontHeight(spec.Size or size), spec.Flags or flags)
  else
    font:SetFont(spec.File or GameFontNormal:GetFont(), pixel:FontHeight(spec.Size), spec.Flags or "")
    font:SetTextColor(self:RGBA(spec.Color or "White"))
    self:shadowFont(font, spec.Shadow)
  end
  return font
end
```

The style remembers the grid its fonts were made for (`self.gridKey = pixel:Key()`), and a new grid applies the theme
again (section 5.8). Checked for every role of every shipped theme on the reporter's screen.

One consequence shaped another feature: the Icon Scale slider must never re-apply the theme to resize things, because
applying a theme makes new font objects, and font objects can never be freed. A slider dragged through twenty steps
would leave twenty sets behind. The slider sets the style's scale and redraws instead.

### 9.2 A font object is made once and never changed

BetterBags' own text (settings, dialogs, the search panel, the bag footer) is drawn with **text roles**: named fonts
in the theme. Originally, each role's font object was restyled in place on every theme switch, relying on a font object
passing its changes to every text set to it.

It did not work reliably. The settings window is built before the saved theme is applied, so its font objects were
changed while its text used them, and a text that then switched font objects (hovering a settings entry: `Nav`, then
`NavHover`, back to `Nav`) came back out of step: the entry changed size, until a theme switch restyled everything
together. Restyling at a different moment did not fix it in game.

The rule since: **never change a font object after it is made; make a new one.** A theme switch (or the client
rescaling its fonts for its Text Size setting) starts a new set of font objects and moves every recorded text to its
role's new one; the old objects are left as they were:

```lua
-- sonata/engine.lua
function sonata:newTextFonts()
  self.textFonts = {}                 -- GetTextFont makes each role's object again on first use
  if next(self.texts) == nil and next(self.buttonTexts) == nil then
    return
  end
  local roles = self:GetCurrentTheme().Text
  for text, role in pairs(self.texts) do
    if roles[role] ~= nil then
      text:SetFontObject(self:GetTextFont(role))
      self:fontChanged(text)
    end
  end
  for button, role in pairs(self.buttonTexts) do
    if roles[role] ~= nil then
      button:SetNormalFontObject(self:GetTextFont(role))
    end
  end
end
```

Related details:

- **A role font is a copy, not a child.** It is made with `Font:CopyFontObject` and then changed; never
  `Font:SetFontObject`, which makes a font inherit from another. Blizzard makes its own runtime font objects by copying
  (`FontableFrameMixin.lua`).
- **The client rescales fonts after you made yours.** For its Text Size setting it calls `SetFontHeight` on its fonts
  after `VARIABLES_LOADED` and whenever the setting changes (`TextSizeManager.lua`), then fires `EventRegistry`
  `TextSizeManager.OnTextScaleUpdated`. Sonata listens and makes new role fonts, so copies follow the client's sizes.
- **States switch roles, never colors.** Text drawn with a role must not call `SetTextColor`, `SetShadowColor` or
  `SetShadowOffset`: they override its font object and survive the next theme. A hovered settings entry is the
  `NavHover` role; a price the player cannot afford is `PriceUnaffordable`. A spec greps the source and fails on a file
  that breaks this.

### 9.3 A font string keeps its old width when its font changes

Reported on WoW: Forever, with the Default and Dark themes: settings sidebar entries wrapped onto a clipped second line
after a hover or a selection: "Import/" to the left of "Import/Export", "General" cut too.

A render recording that logged every font change (role, width, line count, truncation) showed every Nav role in the
same font and size, but the `Nav` role has a shadow (offset 1) and the hover and selected roles a glow (offset 0), and
the shadow makes the string about 0.8 wider: "Import/Export" 110.8 against 110.0, "General" 64.2 against 63.3. Once an
entry was sized in a glow role, it kept the narrower width, so in `Nav` it wrapped (`lines=2`, `truncated=true`).

The client keeps the width a font string took when its text was set, through later font changes. Blizzard documents
this in its own code: `QuestLogTitleButton_Resize` (`Blizzard_UIPanels_Game/Cata/QuestLogFrame.lua`, under a "HACK
ALERT" comment) sets the width to 0 and the text again. That refreshed the string's width but left the entry's, even a
frame later. So the entry takes its measured width explicitly, rounded up with a pixel to spare, after every font
change, as Blizzard sizes a tab after changing its font (`CRFRaidMarkersMixin:SetTab`):

```lua
-- forms/layouts/stacked.lua
local function fitNavText(button)
  local fs = button:GetFontString()
  local function fit()
    fs:SetWidth(0)
    button:SetText(button:GetText())
    fs:SetWidth(math.ceil(fs:GetStringWidth()) + 1)
  end
  sonata:WatchTextFont(fs, fit)     -- run again after every role switch, theme and client rescale
  fit()
end
```

The same bug came back a week later in BetterBags Next's side tabs: "Backpa..." on the selected tab under the Guild
Wars 2 theme, whose selected font has a shadow, slightly wider. Same fix:

```lua
-- next/tabs.lua
text:SetWidth(0)
text:SetText(text:GetText())
text:SetWidth(math.ceil(text:GetStringWidth()) + 1)
```

The spec mock measures text the same in every font, so the test makes the selected font measure 0.8 wider, as measured
in game.

### 9.4 Never hand an edit box a font object read back from it

A crash report (issue #1152): the game crashed with `STACK_OVERFLOW` at login with the ElvUI theme. The Lua stack
pointed at `apply:Font` calling `SetFontObject(nameBox, font)` for the search category editor's name box. ElvUI's theme
was the only one with an `EditBox` style; it set no font, so the styler put back the font it had read from the box.

An `InputBoxTemplate` edit box declares its font in XML (`<FontString inherits="ChatFontNormal"/>`), and on the 12.1.5
client its `GetFontObject()` returned an unnamed font object of its own, even after `SetFontObject("GameFontHighlight")`.
Handing that object back made the font inherit from itself. The styler now records a box's look by value (`GetFont`,
color, shadow, justification) only when a style first sets a font, and restores it with `SetFont` and the setters.
Blizzard round-trips font strings' font objects in shipping code, never edit boxes', so font strings keep the simpler
path. The mock's `InputBoxTemplate` reports a font of its own and raises a stack overflow if it is handed back, so the
crash is a test now.

### 9.5 A template's own text color wins over a font object

`InputBoxInstructionsTemplate` gives its help text a color in XML (0.35 gray). A color set on a font string directly
wins over its font object's, so a role's font object alone cannot recolor it. `NextStyle:SetTemplateFont` sets the
role's color and shadow on the text itself, now and with every theme, read from the role's font object and never from
the text.

### 9.6 Copies of the client's fonts must follow the client

A role can copy a client font (`Object = "NumberFontNormal"`, the bags' item count font, so the vendor's stack counts
match the bags'). UI addons rewrite the client's fonts once the game has loaded, after BetterBags made its copies:
GW2_UI does it at `PLAYER_LOGIN` (`Core/GW2_ui.lua`, `Core/fonts.lua`). So on every `PLAYER_ENTERING_WORLD`, if any copy
made with the current fonts no longer matches its client font (file, size, flags, color, shadow), the theme is applied
again, unsaved:

```lua
-- next/style.lua
function style:CopiesStale()
  for _, copy in pairs(self.copies) do
    if lookOf(copy.base) ~= copy.look then
      return true
    end
  end
  return false
end
```

(The symptom it prevents, Next's copied counts in Blizzard's font beside the bags' counts in GW2_UI's, was inferred from
GW2_UI's source, not seen in game.)

### 9.7 A font string's font comes before its text

The first time BetterBags Next opened in game it raised `FontString:SetText(): Font not set`: a section title set its
text before its font. warcraft.wiki.gg's `FontString:SetText` says it: "the font must be set before showing text". The
frame mock now raises the same error for `SetText` on a font string with no font, which immediately found the same mistake
in two debug panes' specs (rows built with font strings no template gives a font).

### 9.8 A text's measures can be secret

In a dungeon or raid, `UnitName("npc")` returns a secret value. The vendor's title shows it (a font string takes secrets
from addon code), but then its width, height, position and every other measure are secret too
(`SecretWhenAnchoringSecret`), and so is anything anchored to it: secrecy "propagates downwards to dependent anchored
regions". Reported by a player: `attempt to compare a secret number value (execution tainted by 'BetterBags')` from the
title's width. The fix never reads the title's measures while it is secret: the code uses the width it cut the title to,
and the title's button hangs from the body by numbers it knows rather than from the title. The pixel check skips any
region whose anchoring is secret.

### 9.9 Placing text: the rules that came out of all this

- **Center a text by its font's height, from its top** (`pixel:TextHeight`, `pixel:Row`), never by its middle or its
  measured height, which change with its content.
- **Nothing hangs from a text's far edge or middle**, and since section 8.6, from a text at all.
- **The room a text needs is its measured width rounded up** (`pixel:Ceil`), so what follows never overlaps it; the room
  it may take is rounded down (`pixel:Floor`).
- **An edit box's vertical insets leave exactly its font's height**, so the line the client centers lands where
  intended:

  ```lua
  -- next/controls/input.lua
  local height = frame:GetHeight()
  local top = pixel:Middle(frame, height, pixel:TextHeight(frame))
  local bottom = math.max(0, height - top - pixel:Ceil(frame, pixel:TextHeight(frame)))
  pixel:TextInsets(frame, left, pad, top, bottom)
  ```

- **A text sits a quarter pixel right of and above a whole pixel** (section 8.6).

---

## 10. The lessons, as rules

Each of these is a rule in the codebase now, with tests that fail if it is broken. Most generalize beyond WoW to any UI
toolkit that scales a virtual coordinate space onto real pixels.

**Measuring**

1. **Measure before fixing.** The first border fix was built on an assumed screen size and fixed nothing; the game's own
   log had the real one.
2. **If the tools cannot show it, fix the tools first.** The recorder, the layout resolver, the pixel check, the sizing
   steps, the region diffs and the video scripts each existed because a fix needed a fact nothing could show yet.
3. **When nothing moves but something changes, stop reading the layout and look at the screen.** Every rect the API
   reported was still while icons shimmered; a video diff found it in minutes.
4. **Test a cause in game before building on it**, with a `/run` line that lasts until the next reload.
5. **Run the same check in the tests and in the game.** The specs check states someone thought of; the game finds the
   rest (a crafting pip, a stale ribbon, a drag's room, a cooldown's countdown).
6. **Make the mock follow the client, never the other way round.** Every client behavior that hid a bug (`SetPoint(point, x, y)`
   relative to the parent, a dropped x offset, a scroll box keeping its percentage, a texture's alpha being its
   vertex color's, a font string with no font, a reparented frame's level) was added to the mock from Blizzard's source
   and documentation, and more than once an existing test turned out to be relying on the wrong behavior.

**Placing**

7. **One pixel is `GetPixelToUIUnitFactor() / effectiveScale`**, per region: a scaled frame has its own grid.
8. **Lengths are rounded where they are used, on the grid of what they size; offsets are rounded from a point that is
   itself whole.** Sums of whole pixels stay whole.
9. **Never anchor by a middle point** of something an odd number of pixels across; center by a corner offset.
10. **Decide in design units, round only placement.** A layout decided on rounded lengths changes when the grid
    changes (a Bag Scale), and a correction computed for the width drawn this frame changes as that width catches up.
11. **Never compare exactly against a value read back from the client.** Round it (to a hundredth, to whole pixels), or
    compare within half a pixel, or use the value you set.
12. **A frame that clips stays on whole pixels, even while its size animates.**
13. **Turn the client's texture sharpening off in windows that resize** (`SetSnapToPixelGrid(false)`,
    `SetTexelSnappingBias(0)`), and once your own layout is pixel perfect it costs nothing.

**Text**

14. **Text sits a quarter pixel off the boundary**, right and up, because the client rasterizes glyphs to whole pixels
    and a text on the boundary flips with float noise.
15. **Never hang anything from a text.** Its far edge is the client's measure; its corner carries the quarter pixel.
16. **Font heights are whole pixels for the grid they are drawn on**, and a new grid makes new fonts.
17. **Never change a font object after it is made; make a new one.** Copy fonts with `CopyFontObject`, never inherit.
18. **After a font change, set a font string's width again explicitly** (`SetWidth(0)`, `SetText`, then
    `SetWidth(ceil(GetStringWidth()) + 1)`).
19. **Never hand an edit box a font object read back from it.**
20. **States switch font roles; text never sets its own color.**

**Animating**

21. **Only what changed place moves, from where it is, keeping its speed when it turns.**
22. **Parents are placed before children**, so a child's motion starts in the right frame.
23. **What moves is never rounded; it lands on whole pixels when it stops.**
24. **A texture's alpha and its vertex color's alpha are one value.** Color first, alpha after; fade a themed alpha
    through the vertex color.
25. **A gradient fades through its colors**, not `SetAlpha`.
26. **An overshooting ease needs room for its overshoot** (`OVERREACH`), derived from the ease, not guessed.

---

## 11. Appendix

### 11.1 Timeline

| Date (2026) | Pull request | What |
|---|---|---|
| Oct 16 | #1136 | Windowing and theme overhaul: Moonlight's render pipeline, Sonata declarative themes |
| Oct 16 | #1140 | Text roles made once per theme; tiled textures load with the `REPEAT` wrap mode |
| Oct 17 | #1142 | Windows kept on screen; grip starts from the mouse; grid measures in whole pixels; the render recorder |
| Oct 17 | #1147 | Settings navigation sized after every font change |
| Oct 17 | #1148 | Layout engine (measure, then arrange); centering; Snap to Content; Motion; the 465.99997 fix |
| Oct 18 | #1155 | 0.24 s for interactions |
| Oct 18 | #1159 | The opening bounce never shows the screen edge (`OVERREACH`) |
| Oct 18 | #1161 | Chaining; coupling within half a pixel |
| Oct 18 | #1167 | Small mode; the two-step size switch; gradients faded through their colors |
| Oct 19 | #1173 | Resize grips on small panels |
| Oct 23 | #1186 | Pixel perfect: NextPixel, whole-pixel fonts, every window and control, scrolling, the pixel check in game, the same layout at every Bag Scale |
| Oct 24 | #1194 | Never read the vendor title's measures while it shows a secret |
| Oct 25 | #1197 | Header buttons keep their frame level across `SetParent` |
| Oct 25 | #1198 | Snap to icons; column jitter; scroll kept in pixels; texture sharpening off; whole-pixel snap; quarter-pixel text |
| Oct 25 | v0.8.4 | Released |

### 11.2 The numbers

| What | Value |
|---|---|
| Reporter's window | 3396x1362 (maximized), 3440x1440 (fullscreen) |
| Pixels per unit at 65% / 70% (window), 65% (fullscreen) | 1.153 / 1.241, 1.219 |
| The wrong first fix's assumption | 1080 tall: 0.914 pixels per unit at 65% |
| Regions off the grid in a full backpack, first measurement | 59 |
| Grid flip-flop | scroll child 2200 / 2170 on alternate redraws |
| Grip jumps per click | 238.6 to 287.0 to 387.9 to 580.7 to 972.1 units tall, then the screen's height |
| Snapped window float error | 465.99997 for 466; layout 426 wide rejected, 344 chosen |
| Old snap's leftover width | 5 to 111 px |
| Layout planning, 591-item bank | 17 to 25 ms, then 1 to 3.4 ms |
| Opening bounce gap | up to 19.4 px; reach 66 px against a 62 px swing |
| Bag Scale reflow | 16 to 28 of 71 widths laid out differently; 0 after |
| Gap closing after the Bag Scale fix | 3% to 8% of layouts, by 1 px (2 at most) |
| Ribbon after a Bag Scale change | 7 parts, left edge 2355.111 px |
| Drag room | 42.553 px instead of 43; 43 parts 0.062 px off |
| Masque check | 116 parts: 113 Masque's, 3 ours (crafting pip 34.2 x 29.0 px, 3.1 px left) |
| Column jitter | 8 to 18 jumps per 700 px drag, up to 19 px across, 1 to 3 px down |
| Scroll percentage | content moved in 15 or 16 frames of 150 |
| First sizing recording | 247 steps, nothing recorded moved |
| Sharpening | 337 steps all whole; icon border band moving 0.3 and 0.45 px |
| Snap stretch | 0.00 to 0.34 px across 13 icons; edge at 3025.847, 3004.432, 2988.494 |
| Text jump | left edge 2758.999 during the snap, 2759.000 after; 1.00 px jump |
| Settings entry widths | 110.8 with a shadow, 110.0 with a glow |

### 11.3 Where the code lives

| File | What |
|---|---|
| `next/pixel.lua` | NextPixel: units, rounding, placement helpers, text offset, scrolling, grid |
| `debug/pixelaudit.lua` | The pixel check (specs and game), region listing, the in-game watcher |
| `frames/pixelpane.lua` | The `/bbdb` Pixels tab |
| `debug/renderrecorder.lua` | The render recorder, sizing steps |
| `spec/helpers/layout.lua` | The specs' layout resolver, `UseScreen`, `PixelCheck` |
| `render/motion.lua` | Motion: passes, the move curve, the snap bounce |
| `render/texels.lua` | Texture sharpening off |
| `render/flow.lua` | The layout engine's packing |
| `window/window.lua` | Classic windows: snap to content, float rounding, keeping on screen |
| `frames/grid.lua` | Whole-pixel cell measurement |
| `next/content.lua` | Next's canvas: per-row decisions, gap closing, measuring on a grid |
| `next/panel.lua` | Next's panels: layout width, snap, scroll keeping, edges and feathers |
| `next/itemfit.lua` | Blizzard's item button parts on whole pixels |
| `next/style.lua` | Next's font roles at whole-pixel heights |
| `sonata/engine.lua` | Sonata's text roles, made once |
| `forms/layouts/stacked.lua`, `next/tabs.lua` | Refitting text after a font change |

The rules, with full detail and coverage: `.claude/rules/next-pixel-perfect.md`, `texture-sharpening.md`,
`render-recorder.md`, `render-pipeline.md` (§4b the layout engine, §4c Motion), `window.md` (§3a, §3b),
`layout-rendering.md` (§4), `next-themes.md` (§4 text, §10 alphas), `sonata.md` (§3c text roles), and
`.context/patterns-ui.md` for the general patterns.

### 11.4 The scripts

The video scripts lived in `/tmp` during the investigation and are not in the repository. Everything needed to
rebuild them is in section 2.6: decode with `ffmpeg -f rawvideo -pix_fmt rgb24`, compare frames as byte arrays of
`W * H * 3`, map changed pixels to a PPM and scale it with `flags=neighbor`, and measure edges by the centroid of the
luminance gradient across them.

### 11.5 Related: a frame's level after `SetParent` (#1197)

Not a pixel bug, but found in the same days and worth a sidebar: after switching to the Plain theme and back, the
Default theme's header buttons stopped responding until a reload. Plain moves the header buttons into a menu under a
hidden holder frame, and back on the panel for a theme without a menu. The code assumed a frame keeps its level across
`SetParent`. It does not: Blizzard's `LFDFrame.lua` says "Setting a new parent changes the frame level, so we need to
move it back to what we set in OnLoad", and `FrameUtil.SetParentMaintainRenderLayering` saves and restores it. Back at
one level above the panel, the buttons sat under a small panel's mover frame, which took their clicks. The fix reads
each level before `SetParent` and sets it back after; the spec mock now gives a reparented frame one level above its new
parent, as the client does, and an existing test of the drag's lift failed with the faithful mock until the code was
fixed.
