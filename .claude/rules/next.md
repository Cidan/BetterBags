# BetterBagsNext (`next/`, experimental)

An experiment in a new backpack design: a full-height panel that slides in from the right edge of
the screen, with the group tabs down its left side, the categories in one column of big icons, and
a title with a light ribbon and sparkles drifting out of the window. Asked for: "magical, with
whimsy and animations; nice to use, but functional". It replaces only the backpack's draw: the data
pipeline, the item buttons and every setting that feeds the data are the same.

Off by default. **BetterBags Next (experimental)** in the general settings (right below Animate
Item Movement), or `/bb next`, turns it on or off and asks for a reload (`askToReload` in
`config/config.lua`, the same prompt Enable Bank Bags uses).

## 1. How it takes over

- `database:GetNextEnabled()` (`nextEnabled` in the profile, `false` in `const.DATABASE_DEFAULTS`).
- `core/init.lua` creates `addon.Bags.Backpack` with `NextBag:Create(ctx)` instead of
  `BagFrame:Create(ctx, BACKPACK)` when it is on. Nothing else chooses: every caller of the
  backpack (open and close, the refresh draws, search, cooldowns, Quick Find, interactions) talks
  to whichever object is there. The classic backpack is not created at all, so the two never draw
  the same item buttons, and the in-bag search box the data phase reads (`bag.searchBox`) is
  Next's.
- The bank is unchanged.
- **The interface Next provides** (what the rest of the addon calls on the backpack): `kind`,
  `frame`, `searchBox`, `behavior` (`SwitchToGroup`, for Quick Find and the group dialogs),
  `drawOnClose`, `loaded`; `Show(ctx, slotInfo?)` (returns whether it drew), `Hide`, `Toggle`,
  `IsShown`, `GetName`, `SetTitle`, `Draw(ctx, slotInfo, callback)`, `Refresh`, `Search`,
  `ResetSearch`, `OnCooldown`, `Sort`, `Wipe`, `SwitchToGroup`, `GetCurrentTabID`, `ToggleSearch`,
  `PlaceCursorItem`.
- **Small guards elsewhere:** the Scale slider calls `bag.window:UpdateScale()` only for a bag with
  a window, `/bbanchor` touches the backpack's anchor only when it has one, and the search
  keybinding (`BetterBags_ToggleSearch`, `frames/search.lua`) asks the backpack to `ToggleSearch`
  when it can: Next opens and puts the cursor in its own box, or lets go of it on a second press.
  There is no overlay search panel with Next (the classic backpack's behavior made it).
- Every other caller uses members Next has (checked against the whole addon): `IsShown`, `frame`,
  `Show`, `Hide`, `Draw`, `Search`, `ResetSearch`, `searchBox`, `loaded`, `SetTitle`, `GetName`,
  `kind`, `drawOnClose`, `PlaceCursorItem`, `behavior.SwitchToGroup`. Quick Find's `bag.tabs`
  fallback is on its bank branch only.

## 2. The draw (`NextBag:Draw`, `next/content.lua`)

The same pass as the classic bag (layout-rendering.md §1): claim, then sweep. Every button the pass
draws is claimed (`itemFrame:GetButton`, the static per-slot buttons); the buttons the previous pass
drew that nobody claimed are released afterwards. A draw on a hidden panel is deferred to the next
`Show`, as the classic bag does.

`NextContent:Bind(ctx, slotInfo, tabID, claims)` builds the sections, in order:
1. **Recent Items** from `slotInfo.sortedItems` (its stable order and its gaps), as the classic
   global section does.
2. **The tab's categories**, in `tabData.categories` order, each with the tab's items of that
   category in `tabData.items` order. Gaps stay gaps (an empty cell). A category with no cells is
   not shown.
3. **Free Space**, the tab's `freeSpace` buttons (`SetFreeSlots`), when the data carries it.

Sections are kept by name across passes and reused; one not drawn again is hidden and pooled.

**Layout** (`NextContent:Render`): one column. A section is a header (its name, its count, a fading
line) and its cells in rows of as many 44-pixel icons as fit the width given, 6 apart; sections 16
apart. Item buttons are sized to 44 (`item:SetSize`) when they are not already. Every placement goes
through Motion (render-pipeline.md §4c) in a pass of the canvas while the panel is shown, so a
section or an item whose place changed travels there; Next always animates (it is the point of the
experiment), whatever Animate Item Movement says.

**Cascades:** sections fade in and rise 12 pixels, one after the other (45 ms apart, 0.32 s each):
every section when the panel opens or the tab changes (a section shown on both tabs fades in again
too), and on other draws only a section that was not there in the last pass. A hidden canvas
(its own `OnHide`) ends every move and cascade at its end (`Settle`).

A tab with nothing to show says "Nothing here yet" in the content area.

## 3. The panel (`next/bag.lua`)

- A frame anchored to the top right and bottom right of `UIParent`: full height, 554 wide. From the
  left: a 96-pixel **feathered edge** (a horizontal gradient of the body color, transparent to
  opaque; no border art) and the 458-pixel body (a solid deep indigo, with a faint lavender wash at
  the top). The body reaches 40 pixels past the right edge so the opening overshoot never shows the
  world behind it. The feather takes no clicks (`SetHitRectInsets`).
- **Header:** the title, "Backpack", 26-pixel white with a soft shadow; a light **ribbon** running
  left from the title across the feather and out of the window (a thin gold line and a soft glow,
  both fading out to the left) with a spark that sweeps along it every few seconds; sort and
  settings buttons at the top right (`bags-button-autosort-up`, `GM-icon-settings`, present on every
  client).
- **Search** under the title: the backpack's in-bag search box (`searchBox:CreateBox`), taken out of
  Sonata's hands and drawn flat. It follows the in-bag search setting like the classic bag's.
- **Content:** a scroll box (`render/scrollbox.lua`, its bar hidden until used) holding the canvas.
- **Footer:** free slots on the left, money on the right (`MoneyFrame`).
- **Tabs** (`next/tabs.lua`): the backpack's groups as tabs stacked down the body's left edge,
  sticking out over the feather like bookmarks. The selected one is brighter, with a gold bar that
  glides to it; a hovered one slides out a little. Left click switches group (the same data, drawn
  for that tab), right click opens the group menu (rename, delete) and "+" creates a group, both
  through the classic backpack behavior's dialogs. Hidden when groups are off.
- **Opening:** the panel slides in from the right (0.45 s, a small overshoot), the sparkles start
  and the sections cascade in. **Closing:** it slides out to the right (0.24 s) and hides. Escape
  hides it at once (`UISpecialFrames`). Every way it hides runs `OnClosed` (Recent Items expiry,
  held gaps; recent-items.md §3) and stops the sparkles and moves.
- **The window is a drop target** (bag-drop-zone.md): an item dropped on the body goes into a free
  slot of the backpack.

## 4. Sparkles (`next/sparkles.lua`)

A small particle emitter: star sprites (`Interface\Cooldown\star4`, additive) spawned around the
title's ribbon and, more rarely, along the feathered edge, drifting left out of the window while
they twinkle, spin and fade, in starlight gold, white and moon lavender. At most 28 alive, about
8 a second; textures are pooled. It runs only while the panel is shown, and spawns nothing in
combat (those already alive finish).

## 5. Motion helpers (`next/tween.lua`)

`NextTween:Play(key, { duration, from, to, ease, delay, onUpdate, onDone })` runs one tween per key
on a single `OnUpdate` that exists only while something tweens; playing a key again replaces its
tween, `Stop(key, finish)` stops it (at its end with `finish`). Eases: `linear`, `outCubic`,
`inCubic`, `inOutSine`, `outBack`.

## 6. Coverage

`spec/next/tween_spec.lua` (eases, start value at once, delay, replacing, side by side, stopping
and finishing, a callback starting the next tween, a tween stopped by another in the same frame),
`spec/next/sparkles_spec.lua` (only while started, rate and cap, additive star sprites, drifting
left and spinning, fading in and out, reused sprites, quiet in combat, cleared on stop, palette),
`spec/next/tabs_spec.lua` (placement, stacking and widths, the selected font and the gold bar,
gliding and not, no selection, clicks, hover slide, reuse), `spec/next/content_spec.lua` (section
order, unlisted categories, drawing, claiming and hanging buttons, free slots one by one, sizing
once, titles and counts, one-column rows, narrower widths, gaps, reuse and pooling, cascades all
and new only, motion while shown and not while hidden, settling on hide), `spec/next/bag_spec.lua`
(the panel and its feathered edge, title, the search box and its setting, deferred draws, the slide
in with its overshoot and out, toggling, a second open or close, cascades on open and on a tab
change, sparkles, closing (expiry, held gaps, a parent's hide), the sweep, the empty hint, free
slots, search, cooldowns, the drop target, tabs: listing, groups off, switching, menus, "+",
regenerating; sort, settings, the keybinding), `spec/core/init_spec.lua` ("makes the backpack a
BetterBags Next panel when it is on"), `spec/config/config_redraw_spec.lua` (the checkbox, `/bb
next`, `/bbanchor` without an anchor, the Scale slider without a window),
`spec/frames/search_overlay_spec.lua` (the keybinding), `spec/core/constants_spec.lua`,
`spec/database_spec.lua`, `spec/render/toc_spec.lua` (load order). Every guard was
mutation-tested (72 mutations; the nine that first survived each led to a stronger test).

The mocks gained texture rotation (`SetRotation`/`GetRotation`) and Blizzard's
`StaticPopupDialogs` table. **A font string's font comes before its text:** a section title set
its text before its font, and the client raised `FontString:SetText(): Font not set` on opening
the panel (BugSack, `content.lua:145`). The frame mock now raises the same error for `SetText` on
a font string with no font (none set, no inherited template; warcraft.wiki.gg
`API_FontString_SetText`: "the font must be set before showing text"), so every Next test checks
it. It also showed the profiler and Simulate panes' specs building rows with fontless font
strings no template has; they now use the templates' font (`GameFontHighlightSmall`,
`templates/debug.xml`) or let the pane make its own (`BetterBagsPlainTextListButton` has none).

## 7. Known limits of the prototype

- Backpack only; the bank keeps the classic window.
- No Show Bags panel, currencies, bag anchor or bag menu; the size and opacity settings do not
  apply (the panel has one size).
- Item buttons keep the active theme's style.
- Not yet seen in game.
