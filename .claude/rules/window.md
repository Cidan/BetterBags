# Windows (`window/window.lua`)

Every BetterBags window (the bags, forms, dialogs, slots panels, theme config, debug window) is
a `Window`: one module that owns the frame, its chrome (Sonata, sonata.md), its content box, its
layout (the render pipeline, render-pipeline.md), moving, resizing, showing and hiding. Before,
each window did these itself: the bag computed sizes by hand in `UpdateBagBounds`, slots panels
hard-coded insets per client, forms, dialogs and the bag each wired their own drag, fade and
close code, and themes built each window's search box and buttons.

## 1. Creating a window

`window:Create(opts)` returns a `BetterBagsWindow` (prototype `WindowFrame`, a drawable).

| Option | Meaning |
|---|---|
| `Kind` | required: the Sonata window kind (`Bag`, `Panel`, `Flat`, `Dialog`, `Slots`; sonata.md §3b) |
| `Name` | the frame's global name; required with `Escape` |
| `Title`, `Parent` (UIParent), `Strata`, `Level`, `Toplevel` | the frame |
| `Movable` (`false` to never move), `CanMove(ctx)`, `OnMoveStart(ctx)`, `OnMoved(ctx)` | dragging |
| `Position` | a LibWindow-1.1 config: registered, restored, saved after a move or resize |
| `Points` | where it sits without a `Position`: a list of `{ Point, RelativeTo, RelativePoint, X, Y }` (relative to its parent by default; default the parent's center) |
| `Escape` | close with Escape (`UISpecialFrames`) |
| `Opacity()` | background opacity 0-100 (default 100); `UpdateOpacity()` reapplies |
| `Scale()` | the frame's scale; `UpdateScale()` reapplies and lays out again |
| `SizeMode()` | `"content"` (default) or `"window"` |
| `Size()`, `OnResized(ctx, w, h)` | the player's saved size, and where to save it |
| `Resizable` | `false`: in the window mode the window keeps its size (the owner's, or `Size()`) and has no grip; for fixed-size windows such as forms |
| `MinWidth`, `MinHeight` | the frame's minimum (number, function, or `false`) |
| `MinContentWidth`, `MinContentHeight` | the content box's minimum (number or function) |
| `Fade()` | `false` shows and hides at once (default: fade) |
| `OnClose(ctx, button)` | the close button's action, with the mouse button that clicked (default `Hide`) |
| `CloseClicks` | the clicks the close button takes (`RegisterForClicks`), default `{ "LeftButtonUp" }`; the debug window takes right clicks too |
| `OnRendered(ctx, w, h)` | after every render, with the size it took (growth anchoring) |
| `OnShow(ctx)`, `OnHide(ctx)` | hooked on the frame's own `OnShow`/`OnHide`, so they run on every path, Escape included |
| `Content` | the drawable it lays out (`SetContent` replaces it, hiding and detaching the old one) |

The frame inherits `BackdropTemplate`, starts hidden, clamped to the screen and mouse enabled
(it is the bag's drop target, bag-drop-zone.md). **The window owns `OnDragStart`, `OnDragStop`,
`OnSizeChanged`, `OnShow` and `OnHide`**: owners hook those or use the options, and may set
scripts the window does not use (the bag's `OnReceiveDrag`, `OnMouseUp`). Every handler is
installed with `addon.SetScript`/`addon.HookScript`, so captures see them and they get a `ctx`.

## 2. The content box

The content frame is anchored to the theme's `Insets` (from the decoration) plus
`SetExtraInsets` (room the window's own parts reserve inside them: a search box, a footer; the
window keeps a copy). `OnDecorated` (called by the decoration after every theme apply) moves
the content to the new insets, rebuilds the animations and the grip, re-applies the size mode
and lays out again. `GetLayout()` is the theme's `Layout` table for the window's parts.

## 3. Layout: two size modes

The window is a render root (its plan: PRE, DEP content, SELF).
- **Content mode**: PRE gives the content `MaxHeight` = 90% of the screen height measured in the
  window's own scale (`UIParent` height x its effective scale / the frame's), minus the vertical
  insets, and no width (natural). SELF sizes the frame to the content's result plus the insets,
  at least the minimums.
- **Window mode**: PRE gives the content the inner box (`Width`, `Height`), from the frame's size
  rounded to a hundredth of a unit (`SIZE_PRECISION`, §3b: the client reads sizes back with float
  error at a UI scale); SELF keeps the frame size. `UpdateSizeMode()` makes the frame resizable with bounds = the minimums, takes `Size()`
  clamped to them (or keeps the current size when nothing was saved, at least the minimums),
  shows the grip, and lays out again; content mode hides the grip and lays out again. In window
  mode `OnSizeChanged` invalidates, so dragging the grip reflows the content.
- **Minimums**: at least the insets plus one pixel (a window can never invert its content box),
  `MinWidth`/`MinHeight`, and `MinContent*` plus the insets.
- A content that returns no result is an error in both modes. SELF shows the content and calls
  `OnRendered`.

The grip is a button at the overlay's level + 2 (above the close button), styled from the
theme's `Resize` (`Size` number or `{Width, Height}`, `Points` (default BOTTOMRIGHT), `Normal`,
`Highlight`, `Pushed`, `ShowOnHover`) or the default (Blizzard's chat size grabber, shown only
while hovered). Left button only: down starts sizing from BOTTOMRIGHT from where the player
pressed (`StartSizing("BOTTOMRIGHT", true)`: `alwaysStartFromMouse`, documented on every client
branch, the way Blizzard's `PanelResizeButtonMixin` starts its resizes), up stops it (and snaps
the window to its content when the owner asks, §3b), puts the window back on the screen, saves
the position and calls `OnResized`. Without
`alwaysStartFromMouse` the client resized the window inside `StartSizing`, before the cursor
moved, from a point an earlier move or resize had left: a render recording (render-recorder.md)
of a bank after the player moved it and resized it back and forth shows every click on the grip
resizing it (775.8 x 238.6 to 757.0 x 287.0, then 728.3 x 387.9, 665.1 x 580.7, 538.7 x 972.1, and
the screen's full height), each jump about double the last, and a drag then following the cursor
241 pixels away from the corner. An earlier recording with 136 resize starts showed none. Restyling sets every state
with art, so nothing of the last theme's grip stays.

### 3a. On the screen

No window is ever off the screen. The window manager does this for every window; owners do not
touch the clamp.
- **Clamped, with nothing off it.** `Create` clamps the frame to the screen with zero clamp
  insets. (The bag used to set its own insets, `KeepBagInBounds`: `0, -w + 50, 0, h - 50`, which
  let all but 50 pixels of it leave the screen; a user's bank grew past the screen and its grip
  became unreachable, even at 50% scale. It is gone.)
- **Never bigger than the screen.** `screenSize()` is the screen measured in the window's own
  scale (`UIParent` size x its effective scale / the frame's), at least the minimums. In window
  mode it is the resize bounds' maximum, a saved size is cut down to it, and `FitToScreen()`
  (run by `UpdateScale`, and for every window on `UI_SCALE_CHANGED` and `DISPLAY_SIZE_CHANGED`,
  registered by `window:Init`, which `core/init.lua` runs after Render) sets the bounds again
  and brings the window down to them. Content mode already caps the height at 90% of the screen
  (§3); its width follows the content.
- **Pulled back after every change.** A clamped frame stays on the screen as it moves, but a
  size change does not re-apply the clamp; `KeepOnScreen()` turns it off and on. It runs after
  every render (after `OnRendered`, so after the bag placed itself), when the player lets go of
  the grip or of a drag (before the position is saved), and on the screen events above.
- **Never during a resize.** While the player holds the grip (`sizing`), `KeepOnScreen` and
  `FitToScreen` do nothing: moving or resizing a window the engine is sizing fights the drag.
- **Diagnostics.** While a profiler capture runs, each step of a resize or a move (`resize
  start`, `resize started`, `resizing`, `rendered while resizing`, `resize stop`, `resize
  stopped`, `on screen`, `position saved`, `move start`, `move stopped`) calls
  `windowProto:Geometry(step)`, whose return value (anchors, rect, effective scale, clamp, the
  cursor in the window's scale) the call trace records (data-driven.md).

Coverage: `spec/window/window_spec.lua` ("kept on the screen"), `spec/frames/bag_draw_ownership_spec.lua`
("leaves keeping the window on the screen to the window").

### 3b. Centering, the scroll bar, and snapping to the content

**Asked:** the bag's padding is the same on both sides of its longest row, on every theme, at
all times, resizable windows included, and nothing on screen moves when a scroll bar appears.
**Measured before:** in render recordings (retail, content mode) every bag had 12 px on the left
and 26 on the right of its items; resizable bank windows had 12 on the left and 85 to 117 on the
right. The causes, from the code: the scroll box kept its bar's 14 px on the right only, and the
canvas pinned the content to its left edge whatever width it was given.

- **The content is centered** (`frames/bagcanvas.lua`): the header (Recent Items), the tab view
  and the footer (Free Space) share one left edge, and the widest of them is centered in the
  canvas width: the header container is anchored at `(width - contentWidth) / 2` from both
  edges and the other two hang from it. Exact, not rounded, so the two sides are equal.
  Sections pad their icons 6 px on both sides, so the icons are centered too.
- **The bar's room on both sides, always** (`render/scrollbox.lua`, `Symmetric`): the bag's
  scroll box insets its child by 14 px and hands it the width less 28, whether or not the bar
  shows, so the content never moves for it ("visual stability above all"; reserving the room
  only while the bar shows was rejected because the content would jump when it appeared). The
  bag's minimum content width counts both (`GetGutterWidth`).
- **The bar hides itself** (`AutoHideBar`): invisible (alpha 0) until the mouse wheel scrolls
  the box or the pointer is in the bar's room on the right; it fades in over 0.15 s, stays a
  second after the last wheel or after the pointer leaves, and fades out over 0.3 s. A child of
  the bar runs it each frame, so it costs nothing while Blizzard hides the bar (nothing scrolls),
  and it starts hidden each time the bar reappears. Wheel scrolls are seen with a hook on the
  box's own `OnMouseWheel`. The hover check is `IsMouseOver` with the left edge moved to the
  bar's room (`IsMouseOver(0, 0, width - 14, 0)`; Blizzard enlarges hit rects the same way,
  `FloatingChatFrame.lua`).
- **Failure mode (fixed, measured): the left room never applied.** A render recording on retail
  (Default, resizing the bank) showed every render with the items 28 px further from the right
  than the left (12 vs 40, 39.4 vs 67.4) and the canvas at the scroll area's left edge: the scroll
  box anchored its child with an x offset and a nil y offset, which the client drops (both are
  required, `SimpleScriptRegionResizingAPIDocumentation`). `drawableProto:SetPoint` passes 0 for
  a missing one, and the frame mock rejects one offset without the other (render-pipeline.md).
- **Failure mode (fixed, measured): a snapped bag lost a step of its layout once it settled.** A
  retail render recording at scale 0.65 shows it four times: a bag snapped to 466 (a layout 426
  wide) and, 10 ms later, after the snap re-anchored the window by its center to save its
  position, the same window width chose the next narrower layout (344 wide), with 61 px on each
  side instead of 20, until a click on the grip snapped again (to 384); the same at 302, which
  fell to 300. The layout is whole numbers wide, and it can only be rejected at a canvas width
  printed as 426.0 when that width is a hair under 426: the client handed the window's width
  back with float error. During the snap the window hands its content the exact target
  (`LayoutWidth`), which is why the snap itself looked right. The window now rounds the size it
  hands its content to a hundredth of a unit (`withoutFloatError`), and the recorder prints the
  exact width each layout was chosen for (`for=`, render-recorder.md) so a capture shows it.
  Only the window's content size needed it: the other sizes the client hands back (the capped
  theme textures, the screen clamp) make no exact comparison.
- **A layout is a function of items per row and columns alone** (render-pipeline.md, the layout
  engine). A resizable window takes the densest layout no wider than its width: the canvas tries
  every items per row from the one past which nothing changes down to one. **Failure mode (fixed,
  measured):** the snap used to guess the narrowest width with a formula, and the same recording
  shows a snap (1036.8 to 1006) leaving 24 px of extra width, centered, while another left none:
  the steps the player saw. An offline probe with the real grid showed 5 to 111 px left over.
- **Snap to Content** (`SnapToContent` option, the bag's per-view setting, on by default): when
  the player lets go of the grip, `startSnap` lays the content out at the player's width and
  reads `FitWidth`, the chosen layout's own width; the window shrinks to it plus the scroll room
  and the insets, at least its minimum. The candidates are the same for every width, so the
  densest layout that fits the player's width is also the densest that fits its own width: the
  snapped window shows the same layout, item for item, with no space left over (a randomized test
  checks this over 300 bags). The top left is pinned (re-anchored `TOPLEFT` to `UIParent`), so the
  edge the player dragged moves. The width eases out (cubic) to 10 % of the distance past the
  target (at most 10 px, never below the minimum) in 65 % of 0.35 s, then settles back
  (smoothstep): the bounce. While it runs the window hands the content a `LayoutWidth` (the
  target) with its real `Width`, so the layout never changes mid-bounce and the content stays
  centered in the moving width; the bounce stays inside the 14 px room. Each step lays the window
  out (`Invalidate`). At the end it saves the position and size (`OnResized`). Grabbing the grip,
  moving the window or hiding it (`Hide`, or Escape: the snap's driver is a child of the window
  and ends it from its `OnHide`) ends the snap at its target at once. A snap only shrinks: a side
  whose target is not at least half a pixel smaller keeps its size, and nothing snaps when neither
  side moves or the setting is off. Steps trace as `snap start` and `snapped` (§3a diagnostics).
- **The height snaps too** (asked: when the player leaves dead space below the content, the
  bottom should hug the content the way the top does). The content reports `FitHeight`, the
  height that shows all of it without scrolling (the scroll box passes up its child's height);
  the window adds its top and bottom insets, and the same release shrinks the height to that, at
  least the minimum height. The top stays pinned, so the bottom edge moves; on Default the
  footer then sits right under the last row as the search box sits over the first (the insets
  are the title bar plus the search box's reserve, and the theme's edge plus the footer's
  reserve). Content taller than the window keeps the player's height and scrolls. Either side
  can snap alone. The height bounces too, but off the content rather than past it: below the
  content there is no room like the scroll room beside it, so passing the content's height would
  cut its bottom row for a moment. `SnapReboundAt` is the width's curve (`SnapSizeAt`) folded at
  the target: the bottom edge comes up to the content, rebounds by up to 10 % of the distance (at
  most 10 px), and settles back on it. The rebound peaks at the moment the width is furthest past
  its target, so the two move together (700x500 to 412x345: the bottom meets the content at about
  144 ms, both peak at 224 ms, both settle at 352 ms).
- **The reported height is the height of what is drawn.** An empty canvas container is kept 1
  pixel tall, and the containers used to hang from the bottom of the one above, so with no Recent
  Items the view and Free Space sat a pixel lower than the canvas's reported height. A content-
  sized recording shows the result: the scroll area ended at 396 and Free Space at 397, the bottom
  row of the free-slot buttons cut by a pixel. A height snap would have cut it the same way. The
  view and footer now hang from the header's top at the plan's offsets (`hangFromHeader`,
  `frames/bagcanvas.lua`), so the content ends exactly at the reported height.
- **What is still not equal:** a window the player sized without snapping can be an odd or
  fractional number of units wider than its layout, so each side gets half (exact, not rounded),
  and the client may round each edge to a physical pixel. Theme art whose border is drawn
  unevenly around the frame (Default's NineSlice edge pieces sit 8 px outside the frame on the
  left and 4 on the right) is the theme's to compensate (sonata.md 3b).

Coverage: `spec/frames/bagcanvas_spec.lua` (plans, the snap property, densest, centering,
measures kept across renders), `spec/render/scrollbox_spec.lua` ("for a bag (Symmetric,
AutoHideBar)"), `spec/render/render_spec.lua` ("anchors with both offsets when only one is
given"), `spec/window/window_spec.lua` ("snapping to its content" with "its height", "hands its
content its size without the client's float error"), `spec/render/scrollbox_spec.lua` ("passes up
the height that shows its whole child"), `spec/frames/bagcanvas_spec.lua` ("places each container
where the plan puts it"),
`spec/sonata/theme_ports_spec.lua` ("pads every theme's bag the same on both sides"),
`spec/config/config_redraw_spec.lua` ("Snap to Content"). Every guard was
mutation-tested. To check a theme in game, record rendering (render-recorder.md): each bag
snapshot has a `padding` line with both sides.

## 4. Showing and hiding

`Show(ctx, callback?)` and `Hide(ctx, callback?)` play the theme's `Animations` (sonata.md;
`Show`/`Hide` lists of `Alpha`, `Translation`, `Scale` specs). The Base theme carries the
default 0.1 s fade; a theme that sets `Animations = false` (or `Show = false`, `Hide = false`)
shows or hides at once. `Fade()` returning false (the bags' "Enable Fading" setting) does too.
One pair of groups is built per theme; a fade in progress when the theme changes is finished
(its callbacks run).

Client semantics the window is built on (mocked in `spec/helpers/wow_mocks.lua`): `Stop`
fires `OnStop`, not `OnFinished`; `Finish` ends a playing group with `OnFinished(self, true)`
and does nothing otherwise; `Play` on a playing group does nothing (the client has a separate
`Restart`).

- **Show**: on a shown window that is not fading out it renders what waits and runs the
  callback (or adds it to a fade-in in progress). Otherwise it stops a fade-out (its callbacks
  are dropped, alpha back to 1), **renders first** if the window was invalidated while hidden
  (`renderPending`) or earlier in the frame (`render:IsDirty`), through `render:RenderNow`
  (which drops the pending next-frame render), then shows: with a fade it stops any fade-in,
  sets the start alpha and shows the frame itself before `Play` (so a fade-in Escape cut off
  can always start again); without one it shows at alpha 1 and calls back. It returns whether
  it rendered (the bank's refresh draw relies on it, layout-rendering.md §3).
- **Hide**: stops a fade-in (no callback, alpha 1). On a hidden window it just calls back. A
  fade-out in progress takes the callback too. Otherwise it fades out (the frame hides and
  alpha returns to 1 at the end) or hides at once.
- **Toggle** hides a shown window and shows a hidden one or one fading out. `IsClosing()` is
  true during a fade-out. A Translation or Scale in a Show animation snaps back when it ends
  (WoW animations are not persistent): use them in Hide.
- Work that must run on every close (Recent Items expiry, the bag-bar highlight) uses `OnHide`,
  not the hide callback: Escape hides the frame directly (recent-items.md §3, initialization.md §6).

## 5. Rendering while hidden

`ShouldRender()` is the frame's own shown flag, so an invalidated hidden window is skipped by the
next flush and left `renderPending` (render-pipeline.md §2); `Show` renders it.

## 6. Coverage

`spec/window/window_spec.lua`: creation (names, Escape, positions and points, Sonata
registration, profiler prototype, frame show/hide hooks); the content box (insets, extra insets
copied, theme changes, layout table, replacing content); title, close and opacity; moving
(hooks, `CanMove` both ways, not movable); content mode (natural width, the screen cap in the
window's scale, scale changes, minimums, `OnRendered`, missing results); window mode (saved size,
insets as a floor, clamping, no saved size, mode changes, grip visibility, left-button sizing with
size and position saved, no reflow for its own size changes, themed grip, hover-only default
grip, restyling); rendering while hidden (render before callback, invalidated earlier in the
frame, nothing waiting); showing and hiding (no fade, themed fades with callbacks, animations
turned off entirely or for hide only, building and caching per theme, finishing on a theme
change, a fade-in stopped by a hide and the alpha after it, a fade-out stopped by a show, shown
while shown, shown twice while fading in, hidden while hidden, Escape mid-fade, toggling during a
fade-out, `IsClosing`).

## 7. The bag windows (`frames/bag.lua`)

The backpack and the bank are Windows of kind `Bag`. `bagFrame:Create` builds the window
(`BuildWindow`), then the bag's own parts (`BuildParts`), then the behavior's parts (slots panel,
tabs, currencies, money), then `WatchMouse` (the window as a drop target, bag-drop-zone.md).

- **BuildWindow** creates the window named `BetterBagsBag<Backpack|Bank>` with the behavior's
  strata and level, the saved position (`database:GetBagPosition`), and options read from the
  bag's settings for the view it shows: `Opacity` and `Scale` from `GetBagSizeInfo`, `SizeMode`
  from `database:GetBagSizeMode` (per view, default `"content"`), `Size`/`OnResized` from
  `Get/SetBagViewFrameSize`, `SnapToContent` from `GetBagSnapToContent` (per view, on unless
  turned off, §3b), `Fade` from `GetEnableBagFading`. `CanMove` is false while an
  item is on the cursor (pressing on the window is a drop then). `OnClose` is `bag:Hide`.
  `OnRendered` runs `bag:OnResize`. Its content is a `Scrollbox` (with the bar's room on both
  sides and a bar that hides itself, §3b) whose child is the bag's canvas
  (`frames/bagcanvas.lua`, layout-rendering.md §3); `bag.scrollBox`, `headerContainer`,
  `tabContainer` and `footerContainer` point into them.
- **Minimums**: content at least 260 wide (or the tabs' width) plus the scroll bar's room on
  both sides, and 100 high; the window at least as wide as the slots panel while it shows.
- **BuildParts** creates the in-bag search box (`searchBox:CreateBox`, kept as
  `bag.searchBox`; `searchBox:GetSearchText` and QuickFind read it there), the menu button
  (`BagMenuButton`, bag-menu-button.md), the action buttons a theme may give the window
  (`BagActions`, `bag.actions`) and the footer bar the money and currencies sit on.
- **PlaceParts** (the window's `OnDecorated`, after every theme) places those parts from the
  theme's bag window `Layout` (sonata.md): `Search` (`Points` relative to the window,
  `Reserve` rows above the content while in-bag search is on), `Footer` (`Left`, `Right`,
  `Bottom`, `Height`, `Reserve` rows below the content; the money sits 4 in from its right end
  and the backpack's currencies 4 in from its left end, both anchored to the footer bar, so the
  theme places them), `MenuButton` (`Points`; `false` hides it), `Actions` (below), `Tabs`
  (`Offset = { X, Y }`: where the tab bar's top left sits from the bag's bottom left, default
  0, 2; `PlaceTabs`, also run by `bagFrame:Create` once the behavior made the bar, since a window
  registered after the first theme is decorated before its tabs exist). The tab bar is a frame
  level below the bag, so art a theme draws below the window (BetterBags - Themes' race borders
  reach 13 to 56 below it) would cover the tabs unless the theme hangs them below it. It
  reserves those rows with `SetExtraInsets`, then redraws a shown slots panel (tabs measure
  themselves again on `sonata/ThemeChanged`, sonata.md). Coverage for the tab bar:
  `spec/frames/bag_draw_ownership_spec.lua` ("the tab bar (PlaceTabs)").
  **Failure mode (fixed):** the currencies were pinned to the window at fixed offsets
  (`const.OFFSETS.BAG_LEFT_INSET + 4`, `BAG_BOTTOM_INSET + 3`: 10 and 6), so on a theme with an
  inset footer (the Moonlight set's 18, 12) they sat on Dark's border while the money sat on the
  footer. `Currency:CreateIconGrid(parent, footer)` now anchors them to the footer bar the
  backpack passes (retail and Classic); with Base's footer (6, 6) they are exactly where they
  were. Coverage: `spec/frames/currency_spec.lua` ("sits 4 in from the left end of the footer
  bar"), `spec/bags/backpack_spec.lua` ("hands the currency grid its bag's footer bar").
- **Action buttons** (`frames/bagactions.lua`, `BagActions`): a theme's `Layout.Actions` =
  `{ Points, Size (32), Spacing (5), Buttons = { { Action, Normal, Highlight, Pushed }, ... } }`
  places one square button per entry, the first at `Points` (relative to the window frame) and
  each next one `Spacing` below the one before, above the window's overlay, with the entry's
  art (states it leaves out are cleared). `Action` names one of BetterBags' own actions, so a
  theme places and draws them but cannot add one: `ShowBags` (`ContextMenu:ToggleBagSlots`, the
  menu's Show Bags), `Sort` (`BagMenuButton:Sort`, the menu button's right click), `Settings`
  (`config/Open`), `Menu` (the bag's context menu); an unknown name is an error. Each button's
  tooltip names its action. Buttons are reused across themes and hidden when a theme has none.
  The GW2 theme puts its side panel's four buttons here (sonata.md §3b). Coverage:
  `spec/frames/bagactions_spec.lua`, `spec/frames/bag_draw_ownership_spec.lua` ("puts the footer
  bar along the bottom and the menu button where the theme says"). The Base theme carries the layout every
  theme inherits (`sonata/themes/base.lua`). `SetSearchShown` follows the in-bag search setting
  (`search/SetInFrame`) and recalculates the bags (`bags/Rederive`).
- **Each draw** binds, then `ApplySizeSettings` (scale and opacity always; the size mode only
  when it or the view changed, since applying it takes the saved size and would undo a resize
  in progress), then renders the window now. The Opacity slider calls
  `Sonata:UpdateOpacity()` (every window follows an opacity: the bags their own, the other
  windows the backpack's) and the Scale slider `window:UpdateScale()`; neither sends anything to
  the bags.
- **OnResize**: a bag sized to its content keeps its bottom edge (it grows upwards) or follows
  its anchor (`frames/anchor.lua`); a bag the player sized stays where it was put.
- **Showing and hiding** go through the behaviors (`OnShow`/`OnHide` call `window:Show`/
  `window:Hide`). The bank's open setup (`SuppressBlizzardBankPanel`, the active group, money,
  the slots panel) runs before the window shows, never in a fade callback: a stopped fade drops
  its callback (§4). Closing the Classic/Era bank calls `CloseBankFrame` in the hide callback.

Coverage: `spec/frames/bag_draw_ownership_spec.lua` ("the bag's window": the window and canvas,
settings, saved size, minimums, close, scale and opacity per draw, size mode only on change,
search box placement and reserve, footer, menu button, `OnResize` in both modes),
`spec/frames/bagcanvas_spec.lua`, `spec/frames/menubutton_spec.lua`, `spec/sonata/themes_spec.lua`,
`spec/config/config_redraw_spec.lua` ("opacity and scale"), `spec/database_spec.lua` (size mode),
`spec/views/persistent_tabs_spec.lua` ("sizes the bag window around its canvas").

## 8. The other windows

Every BetterBags window is a Window; none builds its own frame, chrome, drag or fade.

- **Forms** (`forms/form.lua`: the settings window, the profiler's Settings): Panel windows,
  strata DIALOG at level 500, in the window mode with `Resizable = false`, so the size their
  owner gives them (`GetFrame():SetSize`) holds across themes and the player cannot change it.
  The form's scroll box fills the window's content box, its scroll bar sits 16 pixels in from
  the content's right edge, and the stacked layout's index hangs from the content box (6, -4),
  so a theme's insets decide where they go. `Show`/`Hide` go through the window (the theme's
  fade). Their opacity is the backpack's (`Opacity` option), reapplied by
  `Sonata:UpdateOpacity()`. Coverage: `spec/forms/form_spec.lua`.
- **Question dialogs** (`frames/question.lua`: `YesNo`, `Alert`, `AskForInput`): pooled
  (`CreateObjectPool`) Dialog windows, strata DIALOG at level 600 (above the settings window),
  centered, not movable, shown and hidden at once (`Fade` false). The content is a body
  drawable (the text 250 wide, the input box, the buttons) that renders 290 wide and as tall
  as the text plus the buttons plus 80, so the window is 300 wide as before. One question is
  open at a time; a released dialog is reset (title, text, scripts, input) and reused. Buttons
  and the edit box are Sonata `Button`/`EditBox` elements. Coverage: `spec/frames/question_spec.lua`.
- **The group dialog** (`frames/groupdialog.lua`: create and rename group): a Panel window
  named `BetterBagsGroupDialog`, strata DIALOG at level 600, centered, not movable, no fade,
  the backpack's opacity. Its body renders 296 wide (the window 300) and as tall as the text
  plus 86, or plus 116 while the bank type dropdown shows. `Hide` marks it closed; its
  frame's `OnHide` (the window's option) does too, for the close button. Coverage:
  `spec/frames/groupdialog_spec.lua`.
- **The changelog** (`frames/changelog.lua`): a Panel window named `BetterBagsChangelog`
  (Escape closes it), strata DIALOG, 560 x 540 in the window mode with `Resizable = false`, no
  fade, the backpack's opacity. Its content is a body drawable (plan PRE, DEP scroll box, SELF)
  that hands the scroll box the content box minus a 34-pixel bottom row holding a checkbox and
  an "Okay!" button, and minus 10 pixels on the right so the bar's 17-wide buttons end clear of
  the border Default draws over the content box's right edge (changelog.md); the scroll box
  scrolls a canvas laying the releases out at its width.
  `OnHide` marks the notes seen. Details: changelog.md. Coverage: `spec/frames/changelog_spec.lua`.
- **The search category editor** (`frames/searchcategory.lua`): a Dialog window named
  `BetterBagsSearchCategoryConfig`, strata DIALOG, 430 x 450 in the window mode with
  `Resizable = false`, movable. Its fields sit in the content box (the first label at 15, -15,
  Save at -15, 15). `Open` anchors it to the left of the frame that asked (or the center of the
  screen) and shows it with the theme's fade, focusing the name box once shown; opening the
  same category again, Save and Cancel hide it; `Close(callback)` calls back once hidden. Its
  edit boxes and buttons are Sonata elements. Coverage: `spec/frames/searchcategory_spec.lua`.
- **The debug window** (`frames/debug.lua`, `/bbdb`): a Flat window named
  `BetterBagsDebugWindow`, 800 x 600 in the window mode with `Resizable = false`, movable, no
  fade. Its four tabs' contents fill the content box. Its close button takes left and right
  clicks (`CloseClicks`): left turns debug mode off, right clears the log (`OnClose`). It shows
  and hides with `config/DebugMode`. Coverage: `spec/frames/debug_window_spec.lua`.
- **The slots panels** (`frames/bagslots.lua`: Show Bags for the backpack and the Classic/Era
  bank; `frames/bankslots.lua`: the retail bank tab panel): Slots windows parented to their
  bag (`BackpackBagSlots`, `BankBagSlots`, `BetterBagsBankSlots`), not movable, hidden until
  shown. The content is the slot grid through `drawable:FromFrame` (render-pipeline.md), so the
  window is the grid's size plus the theme's Slots insets, the chrome is the theme's per client
  (classic-bag-slots-panel.md, camelot-forever.md §5), and the grid is never in a larger box.
  `Draw` redraws the buttons and lays the window out at once while shown (else on show). `Show`
  hangs the panel below its bag at the theme's `Layout.Offset` (Base 0, -2), or anchors it by the
  theme's `Layout.Points` relative to the bag when given (a theme can sit it above the bag, as
  the BetterBags - Themes race themes did with `PositionBagSlots`), hides the bag's
  group tabs (remembering whether they showed) and fades in; the bank panel selects its first
  tab once shown. `Hide` fades out, then gives the bag its tabs back (`OnClose`); the bank panel
  also clears its tab filter and refreshes the bank. After every render a shown panel
  invalidates its bag's window, whose minimum width is the panel's (§7), replacing the bank
  panel's direct `SetWidth` on the bank frame. Coverage: `spec/frames/bagslots_spec.lua`,
  `spec/frames/bankslots_spec.lua` ("9. The panel's window").
- **The overlay search panel** (`frames/search.lua`, `searchBox:Create`, the search keybinding):
  a Search window named `BetterBagsSearchFrame`, strata HIGH at level 700, 400 x 75 in the
  window mode with `Resizable = false`, not movable, hanging above the backpack (BOTTOM to its
  TOP, +10). Its box and labels fill the content box (the theme's Search insets; Base 10, 10, 0,
  0). It starts hidden: before, it was created shown at alpha 0, so the first toggle of a session
  hid an invisible panel instead of opening it (seen in the specs; not verified in game).
  `Toggle` opens the backpack and shows it with the theme's animation (Base: fade in; fade out
  sliding 10 pixels right), focusing the box once shown, or hides it, emptying the box, which
  shows its help again once hidden. `addon/CloseSpecialWindows` and the backpack closing hide
  it. In-bag search boxes (`searchBox:CreateBox`) share its prototype and have no window.
  Coverage: `spec/frames/search_overlay_spec.lua`.
- The side theme-configuration panel (`frames/themeconfig.lua`) and the window grouping it was
  the only user of (`util/windowgroup.lua`) were removed: nothing had opened the panel since
  the window group's opener was removed, so it was a hidden frame built at every login. Themes
  are chosen in the settings window's Theme pane. `frames/overlay.lua` (an unused overlay
  frame, in no TOC) and the unused `AttachFadeAndSlideLeft`/`AttachFadeAndSlideTop` animation
  helpers were removed too.
