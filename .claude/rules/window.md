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
| `Kind` | required: the Sonata window kind (`Bag`, `Panel`, `Flat`, `Dialog`) |
| `Name` | the frame's global name; required with `Escape` |
| `Title`, `Parent` (UIParent), `Strata`, `Level`, `Toplevel` | the frame |
| `Movable` (`false` to never move), `CanMove(ctx)`, `OnMoveStart(ctx)`, `OnMoved(ctx)` | dragging |
| `Position` | a LibWindow-1.1 config: registered, restored, saved after a move or resize |
| `Point` | where it sits without a `Position` (default the center of UIParent) |
| `Escape` | close with Escape (`UISpecialFrames`) |
| `Opacity()` | background opacity 0-100 (default 100); `UpdateOpacity()` reapplies |
| `Scale()` | the frame's scale; `UpdateScale()` reapplies and lays out again |
| `SizeMode()` | `"content"` (default) or `"window"` |
| `Size()`, `OnResized(ctx, w, h)` | the player's saved size, and where to save it |
| `MinWidth`, `MinHeight` | the frame's minimum (number, function, or `false`) |
| `MinContentWidth`, `MinContentHeight` | the content box's minimum (number or function) |
| `Fade()` | `false` shows and hides at once (default: fade) |
| `OnClose(ctx)` | the close button's action (default `Hide`) |
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
- **Window mode**: PRE gives the content the inner box (`Width`, `Height`); SELF keeps the frame
  size. `UpdateSizeMode()` makes the frame resizable with bounds = the minimums, takes `Size()`
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
while hovered). Left button only: down starts sizing from BOTTOMRIGHT, up stops it, saves the
position and calls `OnResized`. Restyling sets every state with art, so nothing of the last
theme's grip stays.

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
  `Get/SetBagViewFrameSize`, `Fade` from `GetEnableBagFading`. `CanMove` is false while an
  item is on the cursor (pressing on the window is a drop then). `OnClose` is `bag:Hide`.
  `OnRendered` runs `bag:OnResize`. Its content is a `Scrollbox` whose child is the bag's
  canvas (`frames/bagcanvas.lua`, layout-rendering.md §3); `bag.scrollBox`, `headerContainer`,
  `tabContainer` and `footerContainer` point into them.
- **Minimums**: content at least 260 wide (or the tabs' width) plus the scroll bar, and 100
  high; the window at least as wide as the slots panel while it shows.
- **BuildParts** creates the in-bag search box (`searchBox:CreateBox`, kept as
  `bag.searchBox`; `searchBox:GetSearchText` and QuickFind read it there), the menu button
  (`BagMenuButton`, bag-menu-button.md), the footer bar the money and currencies sit on, and the
  side anchor the theme config panel hangs from.
- **PlaceParts** (the window's `OnDecorated`, after every theme) places those parts from the
  theme's bag window `Layout` (sonata.md): `Search` (`Points` relative to the window,
  `Reserve` rows above the content while in-bag search is on), `Footer` (`Left`, `Right`,
  `Bottom`, `Height`, `Reserve` rows below the content), `MenuButton` (`Points`), `SideOffset`
  (how far left of the window side panels sit). It reserves those rows with `SetExtraInsets`,
  then reloads the tabs and redraws a shown slots panel. The Base theme carries the layout every
  theme inherits (`sonata/themes/base.lua`). `SetSearchShown` follows the in-bag search setting
  (`search/SetInFrame`) and recalculates the bags (`bags/Rederive`).
- **Each draw** binds, then `ApplySizeSettings` (scale and opacity always; the size mode only
  when it or the view changed, since applying it takes the saved size and would undo a resize
  in progress), then renders the window now. The Opacity and Scale sliders call
  `window:UpdateOpacity()` / `window:UpdateScale()` directly and send nothing to the bags.
- **OnResize**: a bag sized to its content keeps its bottom edge (it grows upwards) or follows
  its anchor (`frames/anchor.lua`); a bag the player sized stays where it was put.
- **Showing and hiding** go through the behaviors (`OnShow`/`OnHide` call `window:Show`/
  `window:Hide`). The bank's open setup (`SuppressBlizzardBankPanel`, the active group, money,
  the slots panel) runs before the window shows, never in a fade callback: a stopped fade drops
  its callback (§4). Closing the Classic/Era bank calls `CloseBankFrame` in the hide callback.

Coverage: `spec/frames/bag_draw_ownership_spec.lua` ("the bag's window": the window and canvas,
settings, saved size, minimums, close, scale and opacity per draw, size mode only on change,
search box placement and reserve, footer, menu button, side anchor, `OnResize` in both modes),
`spec/frames/bagcanvas_spec.lua`, `spec/frames/menubutton_spec.lua`, `spec/sonata/themes_spec.lua`,
`spec/config/config_redraw_spec.lua` ("opacity and scale"), `spec/database_spec.lua` (size mode),
`spec/views/persistent_tabs_spec.lua` ("sizes the bag window around its canvas").
