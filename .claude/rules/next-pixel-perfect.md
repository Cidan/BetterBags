# BetterBags Next, Pixel Perfect (`next/pixel.lua` and every Next window)

Every part of every BetterBags Next window rests on whole screen pixels, at any screen size, UI scale,
Bag Scale, Icon Scale and theme. Design notes, the report and the decisions: docs/next-pixel-perfect.md.

## 1. Why

Reported: the selected theme card on Appearance's Theme tab lost its top edge at a UI scale of 65% and
its bottom edge at 70%, in a maximized window of 3396x1362 (from `Logs/gx.log`). A UI unit there is
1.153 screen pixels at 65% and 1.241 at 70%. BetterBags Next placed everything in whole UI units, so its
frames and lines landed between pixels and the client snapped each texture to the grid on its own: a
1-unit line drew 1 or 2 pixels thick, or not at all. (A first fix assumed a screen 1080 pixels high and
was reverted.) `spec/next/settings/themes_spec.lua` ("its selected card's edge on the reporter's
screen") fails on the old code with exactly those numbers (1.153 and 1.241 pixels).

## 2. The rules for Next code

- **One screen pixel** in a region's units is `PixelUtil.GetPixelToUIUnitFactor()` (768 over the
  screen's height in pixels) over the region's effective scale (`NextPixel:Unit`). A small panel at a Bag
  Scale, a dock card's section, and the settings window shrunk to fit each have their own grid.
- **Lengths** (sizes, gaps, pads, insets, thicknesses, icon sizes, every theme `Layout` value) are
  rounded where they are used, on the grid of the region they size: `pixel:Length` (never below one
  pixel when not zero), `pixel:Lengths`, `pixel:Size`, `pixel:Width`, `pixel:Height`. Sums of whole pixels
  stay whole, so rows step evenly.
- **Offsets** are whole pixels from a point that is itself on a whole pixel: a corner or an edge of an
  aligned region (`pixel:Snap`, `pixel:Point`, `pixel:Inset`). **Never anchor by a middle point**
  (`CENTER`, `LEFT`, `RIGHT`, `TOP`, `BOTTOM` of a region) unless that region is an even number of pixels
  across: center by a corner offset instead (`pixel:Middle`, `pixel:Row`, `pixel:Center`, the odd pixel
  after: right and below).
- **Never anchor from a text's far edge or middle** (its `RIGHT`, `BOTTOM`, `LEFT` of a following part):
  they follow the client's measure of the text, between pixels. Place what follows a text from the
  shared corner by the text's width or height rounded up (`pixel:Ceil(region, text:GetStringWidth())`,
  `pixel:TextHeight`).
- **Text** is placed by a corner on a whole pixel, centered on a row by its font's height
  (`pixel:Row(text, "TOPLEFT", row, x, rowHeight)`); the glyphs are the client's. Every Next text role's
  font height is a whole number of pixels at UIParent's grid (`NextStyle`, `pixel:FontHeight`).
- **Edit boxes**: text insets in whole pixels; the insets above and below leave exactly the font's
  height, so the line the client centers lands on a whole pixel (`next/controls/input.lua`).
- **Room a text may take** is rounded down (`pixel:Floor`), **room a text needs** rounded up
  (`pixel:Ceil`).
- **Windows** start from UIParent's corners (always whole pixels). The settings window is centered by its
  top left (`settings:center`) and put back on whole pixels where a drag drops it (`settings:settle`).
- **Scrolling**: every scroll box Next makes scrolls by whole pixels (`pixel:SnapScroll(box)`, or the
  shared `Scrollbox`'s `SnapScroll` option). Blizzard's box anchors its scroll target at the scroll offset
  in UI units (`ScrollBoxBaseMixin:SetScrollTargetOffset`, called by its `Update`); `SnapScroll` replaces
  the box's own copy of that method with one that rounds the offset first. Any new Next scroll box must
  call it.
- **Not snapped, by nature**: what moves (glides, slides, drags, lifts, flights, sparkles, the cloud's
  breathing, the braid, the tab marker's glide, a toggle's knob sliding). Each lands on whole pixels when
  it comes to rest.

## 3. A new grid

- **A layout never depends on the grid.** What is decided (how many cells go in a row) is decided in design
  units, never on lengths rounded to the grid; only where things stand is rounded. Reported: scaling a small
  bag up or down moved items between rows ("every item should technically render in exactly the same place,
  no exception"; 13 Consumables in rows of 7 at a Bag Scale of 100%, of 8 at 105%). Items per row came from
  the width, icon and gap each rounded to the panel's grid, which changes with its scale; a probe of the real
  panel over widths 380 to 520 and Bag Scales 50% to 150% found 16 to 28 of 71 widths laid out differently on
  the reporter's screen at 65% and 70%, 1920x1080 at 64% and 2560x1440 at 100%. Now:
  - The panel hands its content `LayoutWidth` (`panelProto:LayoutWidth`): a small panel's width as the player
    left it, in its own units, kept within its minimum and the screen but never rounded; the frame's while a
    grip sizes it; a full panel's theme width. The scroll box takes its room off it in units, unrounded
    (`render/scrollbox.lua`).
  - `NextContent:LayoutSection(section, width, layoutWidth)` decides cells per row on `layoutWidth` with the
    theme's icon (or card) and gap. A section laid out again without one (seated in a dock card) keeps the
    rows it had (`section.layoutWidth`).
  - Cells still stand on the grid's whole-pixel step, every gap the same. The rounded step can run up to a
    pixel per cell past the width (measured: 9 pixels, over a scroll bar room as small as 6), so where a row
    would run past the width it is drawn in, the gap closes by the pixel or two the rounding added.
  - Measured after (the same probe): no width lays out differently on any of the four screens, no row runs past
    the content, and the gap closes in 3% to 8% of layouts, by 1 pixel (2 at most).
- `UI_SCALE_CHANGED` and `DISPLAY_SIZE_CHANGED` (`NextPixel:Init`) apply the current Next theme again,
  unsaved (`pixel:OnGridChanged`), when the grid differs from the one the fonts were made for
  (`NextStyle.gridKey`): new font objects at the new pixel heights, every widget restyled.
- A panel that changes scale (`takeScale`: a Bag Scale, a size switch) styles its parts again when the
  pixel's size in it changed.
- **The settings window** takes its scale (`fitScale`: at most 95% of the screen) before anything in it
  is made, so every part is laid out on the grid it is drawn on. A later open at another scale (the screen
  changed while it was closed) restyles every Next widget (`SonataNext:RestyleWidgets(ctx)`, the loop a
  theme application runs, nothing saved or announced).
- **A section seated in a dock card** is drawn at the card's scale: `NextContent:LayoutSection` lays out
  its header again on that grid (`placeHeader`: the line's thickness, the title row, the header's height,
  the cells under it). **Failure mode (fixed):** the header was rounded only when the section was styled
  at its bag's scale, so a seated section's items hung 24 raw units (22.06 pixels at a card scale of
  0.52) under its top.
- A vendor card styles itself for the grid it is placed on (`NextVendorButton:Fit`, called by the
  canvas); its durability bar keeps its share and is sized for the current grid.

## 4. Item buttons and template parts

Item buttons are shared with the classic bags, so what Next rounds on them is undone when the classic
bags take over:

- **Sonata's item button styler** rounds what it places while Next is in use
  (`SonataElements:SetItemButtonSnap`, set and cleared by `SonataNext:SetActive`): the icon's inset, the
  count, a backdrop and its edges, the upgrade arrow (on its own grid, its scale included). It records
  the grid it rounded on (`decoration.sonataSnapUnit`).
- **`NextItemFit:Fit(ctx, decoration, extras, item)`** (called by the canvas for every button it lays
  out) places the template's own parts in whole pixels: stock, junk coin and item level text from their
  corners; quality border, icon overlay and quest art filling the button; glows, second overlay,
  extended slot and the empty slot's family glyph centered at their size; the Blizzard Store highlight
  in the new-item glow's box (no API reads its image's size). It remembers where each part was;
  `Restore` / `RestoreAll` put them back (before the classic bags take the buttons). On a grid the button
  was not styled on, Sonata styles it again (`Sonata:RestyleElement`) and the item says so for Masque:
  `item/Updated`, or the item's own `Restyled(ctx)` (a guild bank button: `guild/Updated`). Once per grid,
  size, Sonata theme generation and whether Masque skins the button.
- **Masque's parts are Masque's.** On a button in one of BetterBags' Masque groups
  (`Masque:IsSkinned(button)`, integrations/masque.lua; a group turned off in Masque's options still places
  its buttons' parts, with Masque's base skin), the fitter leaves the parts Masque places where Masque put
  them, and forgets where they were, so `Restore` does not put them back over the skin: the quality
  border, both icon overlays, the quest art, the new-item glow (and the Store highlight that takes its
  box) and the junk coin (Masque 12.1.0 `Skins/Regions.lua`, the `Item` type's keys). A skin's sizes are
  the skin's, on whole pixels or not. **Failure mode (fixed):** Masque skins a button as it is announced
  and on every full draw, before the canvas lays it out; the fitter then pulled the quality border in to
  fill the button, inside the skin's own frame (Caith sizes it 42 / 36 of the button, centered): two
  borders round each item with a quality border, after a /reload, until the item was drawn again.
- **Vendor cards** style themselves again on a grid they were not styled for (`NextVendorButton:Fit`),
  which draws their icon, count and highlight over Masque's skin, so `Fit` then sends `vendor/Updated` and
  the Masque integration skins the card again (Masque's skin last, as after a theme).
- **Guild bank buttons** name their parts (`PixelParts`): the button, its item level text and upgrade
  arrow (BetterBags' own texture, not Masque's `UpgradeIcon`).
- **The money** in the backpack's and bank's footers is the shared money frame (`frames/money.lua`),
  each its own instance; `NextCoins:Fit` lays it out by corners in whole pixels, again after every
  update. The classic bags' instances are untouched.
- **The Purchase Bank button** keeps Blizzard's template (`BankPanelPurchaseButtonScriptTemplate,
  UIPanelButtonTemplate`: its own `OnClick` opens the purchase dialog; nothing of ours is set on it),
  sized in whole pixels and centered in the content by its top left (again on the content's
  `OnSizeChanged`), its 12-unit end pieces and its centered text rounded in place
  (`placePurchaseBankButton`).

## 5. NextPixel's API (`next/pixel.lua`)

| Function | What |
|---|---|
| `Unit(region)`, `UnitAt(effectiveScale)` | one screen pixel in a region's units |
| `Snap(region, units)`, `SnapIn(unit, units)` | an offset rounded (half away from zero; may be none) |
| `Length(region, units)`, `LengthIn(unit, units)`, `Lengths(region, ...)` | a length rounded, at least a pixel when not none |
| `Floor`, `Ceil`, `FloorIn` | rounded down (room it may take) or up (room it needs) |
| `Pixels(region, units)` | how many whole pixels |
| `Point(region, point, relativeTo, relativePoint, x, y)` | anchor with rounded offsets |
| `Inset(region, relativeTo, l, r, t, b)` | inside another, rounded insets |
| `Size`, `Width`, `Height` | rounded sizes |
| `Middle(region, outer, inner)` | the offset centering a length in another, odd pixel after |
| `Row(region, corner, relativeTo, x, rowHeight, height?, top?)` | by a top corner, centered on a row (a text by its font's height) |
| `Center(region, relativeTo, ow, oh, w, h, dx?, dy?)` | in the middle by its top left, sized |
| `TextHeight(text)` | a font string's or edit box's font height |
| `SnapScroll(box)` | a scroll box scrolls by whole pixels (once per box) |
| `Key()`, `FontHeight(size)`, `Init()`, `OnGridChanged(ctx)` | the grid, font heights, following grid changes |

## 6. The check (`debug/pixelaudit.lua`, `spec/helpers/layout.lua`)

One check, run by the specs and in game: **`PixelAudit:Check(root, { skip, owners })`** lists every shown
region under root that draws and is not on whole screen pixels: textures', lines', edit boxes' and clipping
frames' four edges, an edit box's text insets, a font string's anchor points (its far edges are its text's
measure). Nothing hidden or at alpha 0 (its own or a parent's). It reads only what the client gives an
addon, available on every client (live, Forever, Mists, TBC Anniversary, Era, Titan API docs):
`GetScaledRect` (where the client puts a region, in UI units at scale 1: its own units times its effective
scale, as Blizzard's `RegionUtil.GetRegionPoint` reads it), `GetPoint`, `GetRegions`, `GetChildren`,
`GetTextInsets`, `IsVisible`, `GetAlpha`, `DoesClipChildren`.
- A region the client will not measure (warcraft.wiki.gg: `GetRect` is not allowed on restricted frames; the
  call is protected) or has not placed is skipped; what is in it is still judged.
- A part is named by the field path an owner table reaches it by (`owners = { panel = p }`:
  `panel.content.byName.Consumable.title`), else by the field its parent keeps it in (a parentKey, a
  button's state art), else by its place in the tree (`>3>t2`). **It never reads a key of a table it walks**:
  it collects the parts off the grid first and finds their names by identity, only iterating tables. In
  game a window's tables reach saved settings, and reading a key AceDB's wildcard defaults cover writes it.

In the specs:
- `layout.UseScreen(width, height, uiScale)` sets a screen up as the client would (GetPhysicalScreenSize,
  UIParent at that scale), returns a function that puts it back. **While set up, a region with no size of
  its own on an axis reports the size its anchors give it** (GetWidth / GetHeight / GetSize), as the client
  reports a resolved size; the plain mock reports 0 (the mock exposes its methods as
  `_G.__mockWidgetMethods` for this).
- `layout.Rect(region)` works a region's rect out from its anchors, sizes and parents' scales (a rect a
  spec sets with `_SetRect` stands for the client's).
- `layout.PixelCheck(root, { skip, owners })` runs `PixelAudit:Check` on the mock, its `GetScaledRect`
  answered by `layout.Rect` (`UseScreen` answers it that way too). The mock's `GetRegions` lists a frame's
  textures, lines and text and the state art it makes lazily; its own `GetScaledRect` is a rect a spec set,
  scaled.
- The mock follows the client for this: Blizzard's item button parts anchored as their XML anchors them,
  `UIPanelButtonTemplate` from Blizzard's XML, `SetPoint(point, x, y)` relative to the parent, the scroll
  box anchoring its scroll target at the scroll offset.

## 6a. The check in game (`/bbdb`, the Pixels tab)

Asked: a toggle in `/bbdb`, off by default, not automatic, that checks the windows as they are used and pops
up a log of what is off. The specs check states someone thought of on a mock; this checks what the player
actually opens, on the real client: real fonts, art, Blizzard's templates, other addons, real screens.

- **The tab** (`frames/pixelpane.lua`, the sixth of the debug window): Start Checking / Stop Checking (kept
  across reloads, `BetterBagsPerfDB.pixelAudit.watching`), Check Now (the windows shown now, once, watching
  or not), Clear (drops the reports, so what is still off is reported again), a status line (watching, what
  it checked last), and the reports, newest first: when, the window, how many parts were off, the screen and
  UI scale, the window's state and the Next theme, then each part with where it is in screen pixels.
- **Windows** register as they are made (`PixelAudit:Register(root, { title, owners, skip, describe })`):
  every panel (backpack, bank, vendor, guild bank; owners `{ panel = p }`, its moving parts left out,
  `panel:MovingParts()`, shared with the panels' pixel spec, its state from `panel:PixelState()`: size, Bag
  Scale, Icon Scale), the settings window, the menu and the dialog. A panel says it changed after each render
  (its root's `Render`), the settings window after each page it shows (`recordRender`), any window when
  shown (an `OnShow` hook). Every call site checks `PixelAudit.watching` first and the hook is a plain
  `HookScript`, so **the check costs nothing while it is off**; its frame has no update script then.
- **When it checks**: a window that changed is checked once it has stayed the same for `QUIET` (0.3 s), then
  every `GAP` (0.25 s) until two checks agree (at most `MAX_PASSES`, 8). What moves (slides, glides, a
  toggle's knob, sparkles) differs between checks and is left out; what stays off the grid where the window
  comes to rest is reported. A window hidden meanwhile is dropped, never said clean.
- **Reports**: one per new set of parts off the grid for a window (the same set again is not reported; a
  window found clean forgets it, so parts coming back are reported again). A report (`id`, `at`, `window`,
  `screen`, `uiScale`, `scale`, `theme`, `details`, `total`, up to `MAX_LINES` 200 `lines`) is kept in
  `BetterBagsPerfDB.pixelAudit.reports`, newest last, at most `MAX_REPORTS` 50, readable offline from
  `WTF/Account/<ACCOUNT>/SavedVariables/BetterBags.lua`; a chat line says it; `pixelAudit/Found` opens the
  debug window on the Pixels tab (turning debug mode on as `/bbdb` does). Messages: `pixelAudit/StateChanged`,
  `pixelAudit/Found`, `pixelAudit/Checked` (window title, parts off), `pixelAudit/Cleared`.
- Starts right after the render recorder in `addon:OnInitialize` (both keep data in `BetterBagsPerfDB`,
  which `PerfSessions` creates), before anything makes a window (initialization.md).
- **Not measured yet:** how long a check of a full bank takes in game. Capture one with the profiler while
  checking (`PixelAudit.Check`, `PixelAudit.Step`).

## 7. Coverage

Real screens: the reporter's 3396x1362 at 65% and 70%, 3440x1440 at 65%, 1920x1080 at 64% and 100%,
2560x1440 at 100% and 115%.

- `spec/next/pixel_perfect_spec.lua`: the backpack and the bank, full and small, on every screen; Bag
  Scales and Icon Scales; chained both ways; a grid change under open bags; every shipped theme; group
  tabs (selected, slid out); the title and drop glows; the focused search box; Recent Items and Free
  Space; the empty text; content scrolled partway; the Purchase Bank button on every screen; tabs with
  icons, block gaps, accents and purchase tabs; a small panel after a drag and a grip resize; the size
  switch's end both ways; the grips under the pointer.
- `spec/next/vendor_spec.lua` (every view), `spec/next/guildbank_spec.lua` (counts, item levels, upgrade
  arrows, borders), `spec/next/dock_spec.lua` (a seated section and its card).
- `spec/next/controls/pixel_spec.lua`: every control in its states on three screens and in a window drawn
  at 87%, scrolled menus, item grids and text areas.
- `spec/next/settings/content_spec.lua`: every page and tab of the settings window for both designs on
  four screens (the window shrunk to fit at 115%), scrolled partway; `themes_spec.lua` (the report);
  `window_spec.lua` (the drop after a drag).
- Layouts at every Bag Scale: `spec/next/pixel_perfect_spec.lua` ("puts every item in the same row and column
  at every Bag Scale": widths near a row's boundary, Bag Scales 50% to 150%, three screens; "hands its content
  the width to lay out for"), `spec/next/content_spec.lua` (rows decided on the width to lay out for on every
  grid, rows that fit their width with even gaps, a section laid out again keeping its rows),
  `spec/render/scrollbox_spec.lua` (the room off the width to lay out for, in units). Undoing the decision or
  the scroll box's part fails the first; removing the gap closing fails the canvas test.
- Masque: `spec/next/itemfit_spec.lua` ("on a button Masque skins": Masque's parts left where a Caith-like
  skin put them, fitted again once Masque lets the button go, not put back over the skin; a button that
  announces its own restyles), `spec/next/content_spec.lua` (the canvas leaves Masque's border as Masque
  put it, the reported double border), `spec/integrations/masque_spec.lua` (`IsSkinned`, `vendor/Updated`),
  `spec/next/vendorbutton_spec.lua` (a card announces its restyle on a new grid), `spec/next/guildbutton_spec.lua`
  (`Restyled`). Each guard mutation-checked.
- The check in game: `spec/debug/pixelaudit_spec.lua` (the client's rect over the anchors, font strings by
  their anchor points, refused and unplaced regions, names without reading tables; the toggle and its saving,
  nothing while off, settling, moving parts, parts that never rest, skips, one report per set, hidden and
  shown windows, Check Now, caps, the last check; each guard mutation-checked),
  `spec/frames/pixelpane_spec.lua`, `spec/frames/debug_window_spec.lua` (the tab, opening on it), and the
  registration tests in `spec/next/pixel_perfect_spec.lua`, `spec/next/controls/pixel_spec.lua`,
  `spec/next/settings/window_spec.lua`, `spec/core/init_spec.lua` (startup order). Every existing pixel test
  runs through the shared check; a check that never reads a rect fails 11 of them across four specs.
- Units: `spec/next/pixel_spec.lua`, `spec/next/itemfit_spec.lua`, `spec/next/coins_spec.lua`,
  `spec/sonata/elements_spec.lua` (the styler's rounding), `spec/sonata/engine_spec.lua`
  (`RestyleElement`), `spec/sonata/next_engine_spec.lua` (`SetActive`, `RestyleWidgets`),
  `spec/render/scrollbox_spec.lua` (`Snap`, `SnapScroll`), `spec/helpers_layout_spec.lua`.
- Mutation-checked: the theme card (old edge, old layout), the drop's anchor rounding, the scroll
  rounding (every scrolled check fails without it), the menu's width conversion, the settings window's
  settle, Sonata's rounding.

**Not verified in game yet.** To check: in a maximized window at UI scales of 65% and 70%, the selected
theme card's four edges, a docked section, scrolled settings pages, a small panel after a drag; the render
recorder (render-recorder.md) snapshots positions.
