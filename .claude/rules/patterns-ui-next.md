---
paths:
  - "next/{drag,lift,dock,dockcard,panel,content,pixel,chain,vendor,vendorbutton,tabs,uipanels}.lua"
  - "render/texels.lua"
  - "spec/helpers/layout.lua"
---
## Dragging a Real Frame Across Clipping Parents
**Problem**: a section inside a scroll box is clipped by it and draws in its panel's strata, so it can neither leave its window nor show above the other bag while dragged; and the frame under the cursor hides what is below it from `OnEnter`.
**Solution**: reparent the dragged frame to a full-screen, mouse-disabled layer in the `TOOLTIP` strata (its children follow its strata and keep their levels relative to it), and find drop targets by position every frame with `IsMouseOver`, which is geometric. Put it back with the parent's strata and level. BetterBags Next (next/drag.lua, next-drag.md §7).

## Measure a Scaled Frame From Your Own State
**Problem**: the client reports a frame's edges (`GetLeft`, `GetTop`) in the frame's own scale. A dragged section shrunk to 94% reads back about 6% off, so an animation starting from its read-back position starts from the wrong place.
**Solution**: keep the position you gave it (the cursor and the grabbed point) and work from that; read edges only from frames at scale 1 under `UIParent` (the canvas, tabs, scroll area).

## A Drop Is the Release's Hardware Event
**Problem**: moving items (`C_Container.UseContainerItem`) needs a hardware event; a drop detected in `OnUpdate` is not one, and the client can miss a release when another window takes the mouse.
**Solution**: drop in the dragged frame's `OnDragStop`; also check `IsMouseButtonDown` each frame (as Blizzard's chat frame drag does) and, without the release, finish the drag without moving items.

## A Released Widget Drag Lands on the Frame Under the Cursor
**Problem**: a frame dragged with `RegisterForDrag`/`OnDragStart` that follows the cursor carries its children under the cursor; on release the client fires `OnReceiveDrag` on the topmost mouse-enabled frame there, also for widget drags. Over a `ContainerFrameItemButton` that is a left click, which picks the item up.
**Solution**: put an invisible, mouse-enabled cover over the dragged frame (a margin past its edges, above every frame in it) for the length of the drag; `OnDragStop` still goes to the frame being dragged. Never lower the dragged frame's level to lift it: descendants pushed below 0 jump to 10000 and nothing can be above them. BetterBags Next (next/drag.lua, next-drag.md §7).

## Reflow a Panel Live While the Player Sizes It, With Its Layout Animations Off
**Problem**: BetterBags Next lays its content out through Motion, so every layout change glides. A small panel resized with a grip (`Frame:StartSizing`) changes size every frame; laying out again each frame with the glides on starts a new glide toward a target that moves again next frame, so the icons trail the edge instead of flowing with it, and a size change the panel makes itself (a size switch's glide) would lay out every frame for nothing.
**Solution**: lay out from the frame's own `OnSizeChanged` only while a grip sizes it (or an animated reset of its size runs), and turn the canvas's glides off for that time (`canvas:SetInstant`), on again once let go; save the size only when it changed by half a unit or more, so a click on the grip keeps a default size that follows the screen. next-small-resize.md §14g.

## A Scaled Frame's Edges and Offsets Are in Its Own Units
**Problem**: `GetLeft`, `GetTop`, `GetCenter` and `GetWidth` report a frame in its own units, and `SetPoint` offsets are in the units of the frame being anchored, so a frame under a scaled parent (BetterBags Next's small panels at their Bag Scale; the settings window scaled down to fit a small screen) reads and places at the wrong spot when its edges are compared with the cursor or with another frame's. BetterBags Next assumed every frame was at scale 1: a section drag's gap, its landing, a tab moved in its rail and the dock's flights all used raw edges.
**Solution**: keep places in UIParent's units and sizes in the frame's own; convert at the boundary, reading a frame on screen with `NextLift:ScaleOf` (`GetEffectiveScale()` over `UIParent`'s), `ScreenPoint` and `Center`, and dividing anchor offsets by the frame's scale. A frame lifted for a drag keeps its size on screen (`Pick` starts at its scale there) and lands at the scale of where it lands. next-small-mode.md §14h.

## Whole UI Units Are Not Whole Screen Pixels
**Problem**: a UI unit is a whole screen pixel only when the screen is 768 pixels high at a UI scale of 1. At 65% in a 3396x1362 window it is 1.153 pixels, so frames and lines placed in whole units land between pixels, and the client snaps each texture to the grid on its own: a 1-unit edge drew one pixel thick, two, or not at all (the theme card that lost its top edge at 65% and its bottom edge at 70%). Anchoring by a middle point (`CENTER`, `LEFT`, `RIGHT`) puts a region between two pixels whenever the region it is anchored to is an odd number of pixels across, and anchoring after a text's far edge follows the client's fractional measure of the text.
**Solution**: round every length and offset to whole screen pixels on the grid of the region it is used in (`NextPixel`: one pixel is `PixelUtil.GetPixelToUIUnitFactor()` over the region's effective scale), anchor by corners from aligned regions, center by a corner offset with the odd pixel after (`pixel:Middle`, `pixel:Row`, `pixel:Center`), place what follows a text by the text's width or height rounded up, and lay everything out again when the grid changes (UI scale, window size, a frame's own scale). A value worked out between two whole-pixel ends (an edge gliding from one place to another with a width) is not on whole pixels because its ends are: round it on every frame too (a small panel's snap gliding both its edges stood its left edge between pixels on 12 of 21 frames, next-small-resize.md §14g). Check it with the spec layout resolver (`spec/helpers/layout.lua`, `PixelCheck`) on real screen sizes, on every frame of a glide. next-pixel-perfect.md.

## A Docked Section Flies to Where Its Items Went
**Problem**: Every move waiting for the player waits in `NextDock`, and a "moved" answer flew the section
into the panel it waited in: right for a sale or a deposit (the items went there), wrong for a purchase,
whose section is the vendor's own items, going to the backpack.

**Rule**: Extend the dock, never build a second card: an offer may give `destination()`, the frame its
items went to; the section flies into its middle, or nowhere when it returns nil (that place is not
shown). The vendor's Shopping List gives the backpack's scroll area (profession-shopping-list.md §5).

## A Section Docked as It Is Bound Is Seated, Never Flown
**Problem**: The dock flies a section into its card from where it is on screen (`lift:ScreenPoint`). A
panel that keeps its sections while hidden (the vendor) reuses a section still anchored where its column
left it last time, so a section docked as the draw binds it flew in from that stale place. The spec frame
mock never showed it: it gives a frame a place on screen only when a test sets one (`_SetRect`).

**Rule**: A section docked before its first layout passes `atOnce` (`NextDockSpec`): seated at once,
whatever place it has. Test any flight decision with a rect, as the client gives every anchored frame one.

## Decide Spacing From the Layout, Never From the Width Drawn This Frame
**Problem**: BetterBags Next closed a row's gaps by a pixel where the grid's rounded icons ran past the width the
canvas was drawn in. While a grip sized a panel, that width moved a pixel a frame, so right after each column was
added the gaps closed and a pixel or two later opened: every icon jumped twice per column (up to 19 pixels).

**Rule**: Anything that sets where cells stand (gaps, steps, offsets) is a function of the layout decision (the
column count, in design units), not of the width drawn now; a layout keeps one look for as long as its decision holds.
Let the few pixels of rounding fall in room kept for them (the scroll bar's) rather than re-fit them every frame. To
find such jitter, drive a resize a pixel a frame through the real layout and compare each element's pixel place
between frames with the same decision.

## Blizzard's Scroll Box Keeps Its Percentage When Its Height Changes
**Problem**: BetterBags Next's panels scroll in Blizzard's `WowScrollBox`. While a grip changed a panel's height, a
panel scrolled partway moved everything it shows a pixel every few frames: `ScrollBoxBaseMixin:OnSizeChanged` updates
the box with its scroll percentage kept, and the offset is the scroll range (which follows the height) times it. The
spec mock kept the percentage on `FullUpdate` instead (Blizzard keeps the offset there) and had no `OnSizeChanged`.

**Rule**: To keep content still while a scroll box changes size, hook the box's own `OnSizeChanged` (a hook runs after
Blizzard's handler, before the frame is drawn) and put the offset back in pixels (`ScrollToOffset(offset, true)`).
Restoring from a later render is a frame late and still flickers.

## Turn the Client's Texture Sharpening Off in Windows That Resize
**Problem**: while a BetterBags Next bag was resized, its icons' art shimmered (their top borders and horizontal
lines), though a recording showed every icon's rect on the same whole pixels at every step. By default the client
rounds a texture's corners to pixels and "sharpens" it, picking a texel rather than blending two; which texels it
picked changed with the window's height. Positions and rects read through the API cannot show it; a video of the
screen, diffed frame by frame, did.

**Rule**: draw a window's textures with `SetSnapToPixelGrid(false)` and `SetTexelSnappingBias(0)`, as Blizzard does
on textures that resize and ElvUI on every texture (`Texels:Unsharpen`, texture-sharpening.md). When something drawn
changes with no rect changing, compare video frames before reading more of the layout.

## Clear a Mark of Something Owed Wherever It Is Paid
**Problem**: a small bag busy while its anchor's glide moved its spot is marked (`spotMoved`), so its own snap settles
the chain as it ends. Only the call named for settling it (`chain:Settle`) cleared the mark, but a refit and the
anchor's drag also put the bag on its spot. The mark outlived what it was for, and a later, unrelated snap of the bag
read it, ran the chain's update and glided the bag over a fraction of a pixel, the braid letting go.

**Rule**: a mark that says something is owed says a fact about the state ("its spot moved and it was left there");
clear it in every place that makes that fact false, not only in the one that pays it on purpose. Find them by what
they do (here: each place that sets the bag's place from `SmallPlace()` and places it), and test each one alone,
since a later path often clears it for the common case and hides a missing clear. next-small-resize.md §14g.

## A Frame Kept Shown Out of Sight Still Takes Room in Blizzard's Panel Layout
**Problem**: BetterBags Next keeps the frames it stands in for (the merchant frame, the bank's, the guild bank's) shown
under a hidden frame, so Blizzard's code goes on working. Blizzard's UI panel manager shows them through `ShowUIPanel`
and lays them out like any panel, by their own widths, so the Character pane and the Dressing Room opened beside a frame
nobody sees, under the vendor (#1247, #1282).
**Solution**: tell the manager through the attributes it lays out from, as Blizzard's own frames do: the stand-in's
layout `width` (`SetUIPanelAttribute`) set so it takes no room, and the layout's `LEFT_OFFSET` moved past what the addon
covers at the left edge, but only as far as the panels fit on the screen. The manager decides which panels it keeps
from the same offsets it places from, so move `RIGHT_OFFSET_BUFFER` by the same amount (or it closes panels, and the
merchant frame with them, to make room), write first whichever leaves more room (Classic lays out on every write), and
keep every other value that reads them true (the stand-in's `checkFitExtraWidth` for Blizzard's scale-to-fit). Put each
back as it was, then `UpdateUIPanelPositions()`. Never move Blizzard's panels after it places them: it places them again
on every change. Test against the manager's own source, not a port of it (`spec/helpers/uipanels.lua`), and have it
reviewed: three reviews each found what the last fix had broken. next-uipanels.md §27.

## A Tooltip Over Part of Something Clickable Is a Hover-Only Frame
**Problem**: a card that takes every click (buy, sell a drop) shows one tooltip, but part of its text names something
else that has a tooltip of its own (a vendor price's crest cost). A font string takes no mouse, and a mouse-enabled frame
laid over that part would take the card's clicks and drops there.
**Solution**: lay a `Frame` over the part, above the card, `EnableMouse(true)` then `SetMouseClickEnabled(false)`, as
Blizzard's tooltip-only widgets do (`UIWidgetTemplateTooltipFrameMixin:SetMouse`): it gets `OnEnter`/`OnLeave`, and clicks
and drops reach the card under it. Find the part's place by measuring the text up to it on the font string itself (width
set to none, text set to the part, `GetStringWidth`, then its text and width back, before the client draws), and lay it
out again whenever the text's font or width changes. Leaving it is the card's `OnLeave`; entering it lights the card as
the card does. next-vendor.md §10b ("A cost's own tooltip").
