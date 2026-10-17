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
  (`BagMenuButton`, bag-menu-button.md), the action buttons a theme may give the window
  (`BagActions`, `bag.actions`) and the footer bar the money and currencies sit on.
- **PlaceParts** (the window's `OnDecorated`, after every theme) places those parts from the
  theme's bag window `Layout` (sonata.md): `Search` (`Points` relative to the window,
  `Reserve` rows above the content while in-bag search is on), `Footer` (`Left`, `Right`,
  `Bottom`, `Height`, `Reserve` rows below the content; the money sits 4 in from its right end
  and the backpack's currencies 4 in from its left end, both anchored to the footer bar, so the
  theme places them), `MenuButton` (`Points`; `false` hides it), `Actions` (below). It
  reserves those rows with `SetExtraInsets`, then redraws a shown slots panel (tabs measure
  themselves again on `sonata/ThemeChanged`, sonata.md).
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
  hangs the panel below its bag at the theme's `Layout.Offset` (Base 0, -2), hides the bag's
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
