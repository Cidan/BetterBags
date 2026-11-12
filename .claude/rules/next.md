---
paths:
  - "next/bag.lua"
  - "next/bank.lua"
  - "next/content.lua"
  - "next/panel.lua"
  - "next/sparkles.lua"
  - "next/tabs.lua"
  - "next/tween.lua"
  - "next/README.md"
  - "spec/next/bag_spec.lua"
  - "spec/next/bank_spec.lua"
  - "spec/next/content_spec.lua"
  - "spec/next/sparkles_spec.lua"
  - "spec/next/tabs_spec.lua"
  - "spec/next/tween_spec.lua"
---
# BetterBagsNext (`next/`, experimental)

An experiment in a new bag design: full-height panels that slide in from the edges of the screen,
the backpack from the right and the bank from the left, each with its tabs down its inner side, the
categories in columns of big icons (next-columns.md §7a), and a title with a light ribbon and sparkles drifting out of
the window. Asked for: "magical, with whimsy and animations; nice to use, but functional", then
"bank next, but, on the opposite side! remember we have warbank, etc." It replaces only how the bags
are drawn: the data pipeline, the item buttons and every setting that feeds the data are the same.

Its look is a Next theme (next-themes.md): `NextStyle` (`next/style.lua`) reads every size, color,
font, texture and animation from the current one, and the Default theme is the design described
here. The values this file quotes are Default's.

Off by default. **BetterBags Next (experimental)** in the general settings (right below Animate
Item Movement), `/bb next`, **Switch to Next** in the classic backpack's menu, and the backpack
button in Next's own header switch between the two designs at once, without a reload (next-bagsystem.md §11).

Every Next window rests on whole screen pixels: the rules for placing and sizing anything in Next, and
the check every window passes, are in next-pixel-perfect.md.

Sections with their own rule files keep their numbers there: next-drag.md §7, next-columns.md §7a and
§7b, next-vendor.md §10, next-bagsystem.md §11, next-chain.md §12 and next-small-mode.md §14.

## 1. How it takes over

- `database:GetNextEnabled()` (`nextEnabled` in the profile, `false` in `const.DATABASE_DEFAULTS`).
- **A new install starts with Next.** Asked: "if this is a net new install of the addon, i now want
  to default to the next experience". `DB:Init` checks the saved variables before AceDB makes them:
  `BetterBagsDB` is nil only when the account has none (AceDB-3.0 `New` creates it only then;
  nothing reads it before `DB:Init`), and then it sets `nextEnabled = true` in the profile, before
  `core/init.lua` picks the design, so the first session is already Next. It is saved because it
  differs from the default (AceDB copies the defaults into the profile and removes the values equal
  to them at logout). The default stays `false`: AceDB saves only what differs from the defaults, so
  a default of `true` would turn Next on for every existing player who never touched the setting.
  A character new to an existing install keeps the account's bags (every character shares the
  Default profile, `AceDB:New(..., true)`); so does a new or reset profile (the default). A player
  whose saved variables were deleted counts as new.
  - `firstTimeMenu` (the classic menu button's first-time bounce) was considered and is not a
    new-install signal: it is cleared only by the first left-click on the classic menu button
    (`frames/menubutton.lua`), so an existing player who never left-clicked it (opening settings
    with `/bb`, sorting with a right-click) still reads as new; Next has no such button, so it would
    stay set for every Next player and re-apply on every load; and it is per profile.
- `core/init.lua` makes the design the setting names through `BagSystem` (next-bagsystem.md §11), which creates
  `addon.Bags.Backpack` with `NextBag:Create(ctx)` instead of `BagFrame:Create(ctx, BACKPACK)`
  when it is on; the other design is made the first time the bags switch to it. Nothing else
  chooses: every caller of the
  backpack (open and close, the refresh draws, search, cooldowns, Quick Find, interactions) talks
  to whichever object is there. Only one design is in use at a time: the other is not made until
  it is first used, and once made it is switched off, its buttons let go of and everything it
  registered unhooked, so the two never draw the same item buttons, and the in-bag search box the
  data phase reads (`bag.searchBox`) is the design in use's.
- With Enable Bank Bags on, `addon.Bags.Bank` is likewise `NextBank:Create(ctx)` (§6). One setting
  turns Next on for both bags.
- The same setting makes the vendor (next-vendor.md §10): `addon.Vendor = NextVendor:Create(ctx)`, kept apart from
  `addon.Bags` (it is no bag, and the render recorder walks `addon.Bags`), and `NextVendor:TakeOver`
  puts Blizzard's merchant frame under the hidden frame Blizzard's bags are under. Its name is in
  `UISpecialFrames`.
- On a client with a guild bank (`addon.hasGuildBank`), the same setting makes the guild bank (§13):
  `addon.Bags.GuildBank = NextGuildBank:Create(ctx)`, and `NextGuildBank:TakeOver` takes Blizzard's
  guild bank frame whenever it is shown (guild-bank.md §5). Its name is in `UISpecialFrames`.
- **The interface Next provides** (what the rest of the addon calls on the backpack; the bank's
  additions are in §6): `kind`,
  `frame`, `searchBox`, `behavior` (`SwitchToGroup`, for Quick Find and the group dialogs),
  `drawOnClose`, `loaded`; `Show(ctx, slotInfo?)` (returns whether it drew), `Hide`, `Toggle`,
  `IsShown`, `GetName`, `SetTitle`, `Draw(ctx, slotInfo, callback)`, `Refresh`, `Search`,
  `ResetSearch`, `OnCooldown`, `Sort`, `Wipe`, `SwitchToGroup`, `GetCurrentTabID`, `ToggleSearch`,
  `PlaceCursorItem`.
- **Small guards elsewhere:** the Scale slider calls `bag.window:UpdateScale()` only for a bag with
  a window, `/bbanchor` touches each bag's anchor only when it has one, Quick Find's visual-only bank
  tab switch runs only for tabs that have one (`bag.tabs.SetTabByID`), and the search
  keybinding (`BetterBags_ToggleSearch`, `frames/search.lua`) asks the backpack to `ToggleSearch`
  when it can: Next opens and puts the cursor in its own box, or lets go of it on a second press.
  There is no overlay search panel with Next (the classic backpack's behavior made it).
- **Nothing changes for a player with Next off.** `nextEnabled` defaults to `false`, so the classic
  backpack is created as before; the search keybinding keeps the overlay (the classic bag has no
  `ToggleSearch`); the guards are no-ops for the classic bags (they have an anchor, a window and
  `SetTabByID`); the vendor is not made and Blizzard's merchant frame is left alone (next-vendor.md §10). The
  `next\*.lua` files load for everyone and only register modules and
  prototypes: no frame or font is made until `NextBag:Create` or `NextBank:Create`. Every TOC loads each module a file looks up at load before that
  file, checked by `spec/render/toc_spec.lua` ("loads every module a file looks up at load before
  that file, in every TOC"), which would otherwise be an error for every player.
- Every other caller uses members Next has (checked against the whole addon): `IsShown`, `frame`,
  `Show`, `Hide`, `Draw`, `Search`, `ResetSearch`, `searchBox`, `loaded`, `SetTitle`, `GetName`,
  `kind`, `drawOnClose`, `PlaceCursorItem`, `behavior.SwitchToGroup`; for the bank also
  `SwitchToBankAndWipe`, `bankTab`, `blizzardBankTab` (§6). The bank's `slots` (the classic tab
  panel) is read only behind nil checks (`BANKFRAME_OPENED`).

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

**Layout** (`NextContent:Render`): one column here, or several (next-columns.md §7a). A section is a header (its name, its count, a fading
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

## 3. The panel (`next/panel.lua`, `next/bag.lua`)

**One panel, two sides.** The backpack and the bank are the same panel (`NextPanel`), built for a
side of the screen: the backpack on the right (`side = "RIGHT"`), the bank on the left
(`side = "LEFT"`). The side mirrors everything: the screen edge the panel is anchored to and slides
out from, the feathered edge (on its inner side, toward the middle of the screen), the tabs (on the
inner side, sticking out over the feather), the title (inner side) and the ribbon running from it
out of the window, the way the sparkles drift, the header buttons (screen-edge side) and the footer
(free slots on the inner side, money on the screen-edge side). A kind's prototype (`NextBackpack`,
`NextBankPanel`), chained to the panel's (`NextPanelFrame`), supplies what differs: its header
buttons, its tabs and what a click on one does, what opening and closing do, and sorting. The
description below is the backpack's (the right side); the bank is its mirror image (§6).

**The backpack's header buttons** (from the screen edge, so the first is at the top right): close
(asked: "an X at the top right of the backpack to close it"; `closeButton`, the bank's, guild bank's and
vendor's own button and icon, hiding the backpack), settings, sort, Show Blizzard Bags (below), size
(next-small-mode.md §14).

**A right click on the backpack's title sorts it** (asked: "right click the title of the backpack to sort it. same
function we call on 'sort bags' button in the menu", "along with tooltip update for it"). The title's button
(`titleButton`, next-chain.md §12) takes left and right clicks: a left click chains (`chain:Click`), a right click
runs the panel's `OnTitleRightClick(ctx)`, and its tooltip adds the panel's `TitleRightClickHint()` under what a
click does, in the grey of every other "Right-click to" hint (0.8). The panel's own do nothing and say nothing; the
backpack's call `Sort`, the sort button's own `onClick` (the sort sound and `bags/SortBackpack`), and say
"Right-click to sort your bags.". The bank, guild bank and vendor keep the default: a right click on their titles
does nothing, as before (the button took no right clicks then).

**A theme can hold the header's buttons in a bag button's menu** (next-themes-menubutton.md §19; the Plain theme): every button
not pinned leaves the header for the original bags' drop-down on a button at a corner of the body (the vendor's
portrait on the vendor), and the title is centered between that button and the close.

**Above the rest of the UI** (asked: "they need to be the top most frames ... so other UI elements
can't overlap"): every panel is in the `HIGH` strata (was `MEDIUM`), toplevel, level 500. That puts
it over unit and action bars, the objective tracker (`LOW`), Blizzard's character frame and other
`MEDIUM` panels, and addon frames up to `HIGH`. It is not higher, because what must cover it is
higher: Blizzard's popups, among them the vendor's purchase confirmations (`DIALOG`,
`StaticPopup.lua`), and its game menu (`DIALOG`), menus (`FULLSCREEN_DIALOG`, `Menu.lua`) and
tooltips (`TOOLTIP`). With both panels open on a 16:9 screen at UI scale 1 (`UIParent` about 1365
wide) they leave about 257 pixels between them, less than a popup's width. Blizzard's stack split and settings boxes are `HIGH`
and toplevel, so they raise themselves above the panel when shown (warcraft.wiki.gg
`API:Frame_SetToplevel`). BetterBags' own windows are `DIALOG` or higher; the `/bbdb` debug window,
used beside the bags while profiling, was raised from the default to `DIALOG` (window.md §8). A
section dragged out of a panel returns to the panel's strata (next-drag.md §7).

- A frame anchored to the top right and bottom right of `UIParent`: full height, 554 wide. From the
  left: a 96-pixel **feathered edge** (a horizontal gradient of the body color, transparent to
  opaque; no border art) and the 458-pixel body (a solid deep indigo, with a faint lavender wash at
  the top). The body reaches `OVERREACH` (66 pixels) past the right edge so the opening bounce
  never shows the world behind it (below). The feather takes no clicks (`SetHitRectInsets`).
- **Header:** the title, "Backpack", 26-pixel white with a soft shadow, in a **cloud**; a light
  **ribbon** running left from the cloud across the feather and out of the window (a thin gold line
  and a soft glow, both fading out to the left) with a spark that glides in along it every few
  seconds (the title's cloud, below); sort and
  settings buttons at the top right, drawn with BetterBags' own glyphs from the theme, the same on
  every client (next-themes.md §11). The settings button first used `GM-icon-settings`, which Classic
  Era and Mists do not have: the button was blank there; then Blizzard's `uitools-icon-settings`.
- **The title's cloud** (asked: the ribbon "ending at the text is meh", "flow into a bubble behind
  and around the word backpack, with the sparkles and glow ... don't drown the text", "seamless and
  not abrupt", then "more like a cloud, no hard lines around it"). A first version, a capsule with a
  thin rim, was replaced by this one.
  - Twelve puffs of one soft glow (`textures/next/glow.png`, white, brightest at its centre and
    fading to nothing at its edge; made by `tools/textures/next_glow.py`), additive, tinted from the
    palette: gold where the ribbon enters, lavender across, a few smaller ones above and below for
    billows. Their places, sizes, colors and alphas are data (`NextStyle.Cloud`): each sits a share
    of the way across the cloud, which reaches from the window's hard edge to 16 pixels past the
    title's far side (`CloudSpan`), so the cloud spreads across any title (`LayoutCloud`, on every `SetTitle`: the bank's group and tab names,
    the vendor's merchant; and whenever `FitTitle` cuts the title to another width, as the client measures a cut title
    at its cut, next-small-names.md §14g). The puffs are at most 0.24 alpha, below the title (ARTWORK; the title is
    OVERLAY), so it stays crisp. No texture of the cloud has an edge.
  - The ribbon and every line of its glow end flush with the window's hard edge (`TitleJoin`: where
    the body and its wash start, 22 pixels before the title), where the cloud begins; a warm puff
    sits on its end. Asked: the bar's glow went "a tad bit too far into the window, should stop
    flush with the hard edge of the window"; before, it ended 6 pixels inside the body and a
    24-pixel tail went on fading inside, nearly to the first letter.
  - The cloud breathes: each puff's alpha (by 15%) and height (by 1.5 pixels), at its own pace and
    from its own point (`applyCloud`, from a driver that is a child of the panel, so it runs only
    while the panel shows).
  - The shimmer glides in along the ribbon from its far end (in and out eased), comes to rest on
    the ribbon's end at the window's edge, and settles there: it grows and fades while the
    cloud swells (puffs by up to 60%, the entering puff more) and eases back, quickly at first and
    then gently (`style.Time.Absorb`, 0.7 s). Nothing jumps and nothing crosses the title.
  - A third sparkle emitter (§4) is born in the cloud above and below the title, never over it.
  - Mirrored on the bank (and every left-side panel): the ribbon enters on the right.
  - Coverage: `spec/next/bag_spec.lua` ("the title's cloud": the puffs, their layer and texture,
    the ribbon and its tail, spreading across a new title, breathing out of step, the shimmer's
    glide, rest, settling and swell with no step anywhere, the sparkles above and below the title)
    and `spec/next/bank_spec.lua` (mirrored). Every guard was mutation-tested (27 mutations; the
    six that first survived led to tests of the drift, the swell reaching the puffs and the
    settling's shape, and to removing a size reset the next shimmer redoes).
- **Search** under the title: the backpack's in-bag search box (`searchBox:CreateBox`), taken out of
  Sonata's hands and drawn in Next's look by `BuildSearch`, which every panel runs on its box (the
  vendor's own too). It follows the in-bag search setting like the classic bag's.
  - **Asked: it was "very difficult to see"; make it stand out without breaking the look.** It
    showed the template's help text in 35% gray `GameFontDisableSmall` (about 2.5:1 against its
    fill), a 10-pixel magnifier at 60% gray, a fill barely lighter than the body, and an underline
    fading out halfway.
  - Now: a fill lighter than the body (`style.Color.SearchFill`, `SearchFillFocus` while focused), a
    1-pixel lavender edge all round (`style.SearchEdge`: 0.3 idle, 0.55 under the pointer or holding
    a search, 1 focused, fading over `Time.Hover`), a 14-pixel lavender magnifier (white while
    focused), and the help text in Next's `Search` font (muted lavender, 12; about 5.7:1) left after
    it; typed text in `SearchText` (13, Next's text color), inset past the magnifier.
  - Next's colors are set from hooks that run after the template's scripts
    (`SearchBoxTemplate_OnEditFocusGained`/`Lost`/`OnTextChanged` set the magnifier to white or 0.6
    gray). The `OnTextChanged` hook also shows the help text only while the box is empty: a box that
    sets its own `OnTextChanged` replaces the template's (`InputBoxInstructions_OnTextChanged`), and
    the vendor's box did, so "Search Vendor" stayed under what was typed.
  - Coverage: `spec/next/bag_spec.lua` ("the search box's look"), `spec/next/vendor_spec.lua` ("hides
    its help text while something is typed"); the spec mock's `SearchBoxTemplate` runs Blizzard's
    template scripts, and `EditBox:GetText` is "" for an empty box, as in the client.
- **Content:** a scroll box (`render/scrollbox.lua`, its bar hidden until used) holding the canvas.
- **Icon Scale** (Appearance → Size, `nextIconScale`; asked: an "icon scale" slider, "do not touch items
  per row ... just item button scale (also account for the fact that themes can set icon scale!)",
  then "if buttons are huge, less fit per row naturally"; docs/next-appearance-size.md): an item button
  is the theme's icon size (`Layout.Icon`) times the scale, in whole pixels (`style.ICON`,
  `NextStyle:SetIconScale`). The grid keeps the theme's width (`GRID_WIDTH` from `Layout.Icon`), so the
  panels keep theirs and a row fits as many buttons as its width allows (`canvas:Render` already packs
  by width). A vendor's card draws its icon at that size too (reported, issue #1221: the scale did
  nothing there), the card as tall as its icon and never shorter than the theme's icon size, which two lines of
  name and a price need (`style.CARD_HEIGHT`): a small icon sits in the card's middle, a large one squeezes the
  name and price. A card styles itself again when the scale changes (`Fit`). SonataNext's `Init` gives the
  style the saved scale before the theme; a theme change keeps it. The slider sends
  `next/ScalesChanged`; the chain (`chain:ScalesChanged`, registered once with the first panel, in
  BetterBags Next's event scope) sets the style's scale, has every panel draw again (`ApplyScales`:
  at once while shown, else when it opens), then places the panels (`Update`, snapping: an open small one
  refitted at its Bag Scale, its size gliding or not, so one its draw set gliding for its names is refitted at
  its new scale; one a grip holds is left alone, next-small-mode.md §14h). It never
  re-applies the theme: that makes new font objects, which cannot be freed, one set per slider step.
  Coverage: `spec/next/style_spec.lua` ("NextStyle Icon Scale"), `spec/next/small_spec.lua` ("the Size
  tab's scales" → "Icon Scale"), `spec/next/content_spec.lua`, `spec/next/vendorbutton_spec.lua`,
  `spec/sonata/next_engine_spec.lua`.
- **Footer:** free slots on the left, money on the right (`MoneyFrame`). The backpack's footer shows its tracked
  currencies in the free slots' place (asked: "replace our 'xx slots free' text"; Free Space's header counts them):
  currency.md §4.
- **Tabs** (`next/tabs.lua`): the backpack's groups as tabs stacked down the body's left edge,
  sticking out over the feather like bookmarks. The selected one is brighter, with a gold bar that
  glides to it; a hovered one slides out a little. Left click switches group (the same data, drawn
  for that tab), right click opens the group menu (rename, delete) and "+" creates a group, both
  through the classic backpack behavior's dialogs. Hidden when groups are off.
  - **A tab's icon** (`NextTabEntry.icon` or `atlas`: the bag slots in Show Blizzard Bags, the bank's tabs, the
    Warbank's) is against the body, the padding in from the tab's body side, and its name past it and the icon gap
    (`placeContent`): on the backpack's rail the icon is right of the name, on the bank's and the guild bank's
    (tabs sticking out to the right) left of it. Every icon down a rail is in one column. Asked: "the icon for shown
    bag tabs, should be on the right of the text (so they align top to bottom)": the name is justified to the
    body, and an icon placed after it moved out with the name's width. A tab without an icon has its name the
    padding in. The tab's width is unchanged (padding, icon, gap, name, padding). Left as it is: a name wider than
    what a tab capped at `TAB_MAX_WIDTH` leaves it (about 114 units on Default, its padding, icon and gap taken) runs
    past the tab's outer end, by as much as the icon did before (the overflow is the same; the name is the part
    outside now). Names are not cut; nobody has asked for it (found in review). Coverage:
    `spec/next/tabs_spec.lua` ("puts a tab's icon against the body ...", and on the left side of the screen).
- **Moving tabs** (every Next rail: the backpack, the bank's groups and its Blizzard tabs, the guild
  bank, the vendor; asked: "all tabs in all Next windows should be reorderable by clicking and holding to
  slide. animate the slide, but pin the X axis so you can't move it left and right, just drag it up and
  down. animate this transition and make sure it saves"; docs/next-batch-2.md §5):
  - **The drag** (`next/tabs.lua`, a rail with a reorder handler, `SetReorderHandler`): pressing a tab
    and moving the cursor (`OnDragStart`, so a click is still a click) lifts it with `NextLift`, as
    sections and settings rows are lifted (the shrink and shadow), with `pinX` (a NextLift field: `Place`
    keeps the cursor's x of the pickup) so it follows the cursor only up and down. The room where it
    would land follows the cursor (before the first tab of its block whose middle is below the cursor,
    `moveIndexAt`), and the other tabs slide out of its way (`slideY`, `Time.Interaction`, the `Glide`
    ease, apart from their hover slide). Let go (`OnDragStop`, or the left button found up), it lands
    in its room (`NextLift:Land`, its flight starting from the pinned x: it started from the cursor's,
    so the tab jumped to the cursor before flying back, reported), and the rail shows the new order and
    tells its handler every tab's id
    in it; nothing when it is back where it was. The bar follows the selected tab. A move ends with the
    tab back in its place when the rail hides or its tabs are listed again, and none starts while
    another frame is lifted. One at a time.
  - **What moves where:** a tab moves among the movable tabs of its block (`NextTabEntry.block`, tabs
    next to each other: the bank's own groups and its Warbank groups; its character tabs and its Warbank
    tabs; the guild's tabs, apart from All Tabs); a block's gap stays above whichever of its tabs is
    first. Fixed tabs (`fixed`: the "+" that makes a group or buys a guild tab), purchase tabs and tabs
    whose drag is their own (`draggable`: the backpack's bag slots in Show Blizzard Bags, WoW: Forever's
    bank sockets) never move, and no tab passes them.
  - **Saving** (`panelProto:OnTabsReordered`): the order is saved per rail
    (`database:SetNextTabOrder(key, ids)`, profile `nextTabOrder`) under the panel's `TabOrderKey`
    (`backpack`, `bank` for the bank's groups, `bankTabs` for its Blizzard tabs, `guild`, `vendor`; none
    for the bag slots), and the tabs are listed again. Every `RefreshTabs` lists each block in the saved
    order (`panelProto:OrderedTabs`, `NextTabs:Ordered`: saved tabs in their order, new ones after them
    in their own, fixed and purchase tabs where they are), then gives each block's first tab its gap.
  - The settings window's tabs run across its top: pinning X there leaves nothing to drag, so they are
    not moved.
  - Coverage: `spec/next/tabs_spec.lua` ("moving a tab", "a saved order"), and each panel's spec
    ("lists ... in the order saved"), `spec/database_spec.lua`.
- **Show Blizzard Bags** (asked: "the 'Switch to Classic Bags' icon now becomes 'Show Blizzard Bags',
  with our left tabs replaced with the bag icons for the Blizzard Bags, so users can swap out their bags
  -- the view of items switches to the full stack of bags, just like in our Original bags view, same
  functionality"; docs/next-batch-2.md §4). The header's `bagsButton` (the bags glyph; "Show Blizzard
  Bags", "Show Categories" while on) calls `ToggleBlizzardBags`, which does what the classic backpack's
  Show Bags does (`ContextMenu:ToggleBagSlots`): the view saved (`SetPreviousView`) and the Show Bags
  view (`SECTION_ALL_BAGS`: every bag a section, its slots in order, empty slots in place), or the saved
  view back; then the tabs listed again and `bags/Rederive { backpack, resetLayout }`; not in combat
  ("Cannot toggle bag slots in combat."). The mode is the view (`ShowsBlizzardBags`), so it lasts across
  sessions and is the classic bags' setting too.
  - **The tabs are the bag slots** (`ListBags`, `const.BACKPACK_ONLY_BAGS_LIST`, as the classic Show Bags
    panel lists them; the backpack itself has no slot): each its bag's icon (`GetInventoryItemTexture`,
    whose nil is how Blizzard's bag slots tell an empty slot, `MainMenuBarBagButtons.lua`) and name
    (`C_Container.GetBagName`), an empty one Blizzard's empty bag slot art and "Empty Bag Slot" ("Empty
    Reagent Bag Slot" for the reagent bag); none selected; shown with groups off too. They are listed
    again on `BAG_CONTAINER_UPDATE`.
  - **Swapping, as Blizzard's bag slots do** (`BaseBagSlotButtonMixin`): a bag dropped on a tab, or a
    left click holding one, goes in (`BagButtonFrame:PutInBag`, `PutItemInBag`, the one there coming onto
    the cursor); dragging a tab or Shift-clicking it picks the bag up (`BagButtonFrame:PickupBag`,
    `PickupBagFromSlot`). Both refuse in combat ("Cannot change bags in combat."), shared with the
    classic bags' bag buttons. A plain click and a right click do nothing. The tooltip is the bag's own
    (`SetInventoryItem`), or what the slot takes, then how to swap it.
  - **No section goes on a bag slot** (`NextTab.bag`): `NextDrag:CanDropOnTab` refuses it (group IDs and
    bag IDs overlap) and a drop on the backpack's items only moves them (`ShownTab`). Sections are not
    picked up in the Show Bags view.
  - The way back to the classic bags is the settings' BetterBags Next switch and `/bb next` (next-bagsystem.md §11c).
  - Coverage: `spec/next/bag_spec.lua` ("Show Blizzard Bags", "switches to Show Blizzard Bags and back
    from a bag button in its header"), `spec/frames/bagbutton_spec.lua`, `spec/next/drag_spec.lua`
    ("takes no section on a bag slot's tab").
- **Opening:** the panel slides in from the right (0.45 s, a small overshoot), the sparkles start
  and the sections cascade in. `Show(ctx, slotInfo, onShown)` runs `onShown` once the panel has
  slid into place: at once when it is open, when a slide still playing ends (callbacks queued on
  `panel.onShown`), never for a slide that `Hide` or Escape (`OnHidden`) cut short. The bank is
  loaded then (refresh-scheduler.md §11): it slides in saying "Loading..." (its data has never
  been read), and its sections cascade in when its read draws. Coverage: `spec/next/bag_spec.lua`
  ("telling the caller it has finished showing").
- **The bounce never shows the screen edge** (asked: "you can see what's under the bag briefly at
  the edge as it overshoots"). The slide runs `WIDTH + OVERREACH` (`HiddenOffset`) with `outBack`,
  which swings a tenth of its run past its place; with the body reaching 40 pixels past the panel,
  a gap up to 19.4 pixels wide opened at the screen edge for about the middle third of the slide.
  `NextStyle.OVERREACH` is now derived from the panel's width: the smallest reach that covers a
  tenth of `WIDTH + OVERREACH` (`WIDTH / 9`, rounded up), plus 4 pixels, which is 66 for today's
  554-pixel panel against a 62-pixel swing. The fill and the wash reach that far; the slide is
  26 pixels longer (620 instead of 594). A gold glow over the gap was tried first and dropped ("looks weird ... make the
  window bigger out the edge so it just covers it up, remove the glow").
- **Closing:** it slides out to the right (0.24 s) and hides. Escape hides it at once
  (`UISpecialFrames`). Every way it hides runs `OnClosed` (Recent Items expiry, held gaps;
  recent-items.md §3) and stops the sparkles and moves. A parent hiding it (Alt+Z hides UIParent) runs its OnHide
  too, with its own flag still set (`hiddenByParent`): when the parent shows it again, its sparkles, ornaments, data
  rain, shimmer and glitch bursts start again (`startEffects`; before, they stayed still until it was opened again).
- Coverage of the reach: `spec/next/bag_spec.lua` ("keeps its fill over the screen edge through the
  whole bounce": the real slide in 2 ms steps, the fill's outer edge never inside the screen, and
  the bounce still at least 9% of the run) and `spec/next/bank_spec.lua` (mirrored on the left
  edge). 5 mutations, all caught.
- **The window is a drop target** (bag-drop-zone.md): an item dropped on the body goes into a free
  slot of the backpack.

## 4. Sparkles (`next/sparkles.lua`)

A small particle emitter: star sprites (`Interface\Cooldown\star4`, additive) spawned around the
title's ribbon, out of the title's cloud (above and below the title, most near where the ribbon
enters, about 3 a second, at most 10) and, more rarely, along the feathered edge, drifting out of
the window (left from the
backpack, right from the bank: the emitter's `Direction`) while they twinkle, spin and fade, in
starlight gold, white and moon lavender. At most 28 alive, about
8 a second; textures are pooled. It runs only while the panel is shown, and spawns nothing in
combat (those already alive finish). The player can turn them off on any theme, with the title's shimmer, cloud and
ribbon, the braid and moving ornaments (Appearance > Animation, next-themes-animation.md §20).

## 5. Motion helpers (`next/tween.lua`)

`NextTween:Play(key, { duration, from, to, ease, delay, onUpdate, onDone })` runs one tween per key
on a single `OnUpdate` that exists only while something tweens; playing a key again replaces its
tween, `Stop(key, finish)` stops it (at its end with `finish`). Eases: `linear`, `outCubic`,
`inCubic`, `inOutSine`, `outBack`.
A theme's stop motion (next-themes-papercraft.md §25) steps every tween not marked `smooth`: `NextTween.Stepping`.

**0.24 seconds for interactions** (asked: "that'll be our magic number for interactions").
`NextStyle.Time.Interaction` is how long everything that moves in answer to the player takes:
items and sections gliding to their new places through Motion (the canvas gives every Motion pass
that duration: sorting, looting, switching tabs, making room for a dragged section), a dropped
section landing (`Land`) or flying into its target (`FlyAway`), and the tab bar gliding (`Glide`).
Kept at their own times: the panel's slides in and out (`Open` 0.45 s, `Close` 0.24 s; asked not to
touch them, so `Close` is its own number, not the interaction time), the sections' fade-in cascade
(`Cascade` 0.32 s), feedback (`Hover` 0.15 s, `Lift` 0.12 s), the tab pulse (`Pulse` 0.6 s), the
wash's color fade (`Wash` 0.44 s, which was `Glide * 2` before), the shimmer and the sparkles. The
classic bags keep Motion's 0.3 s (asked: not to touch them yet). Coverage: `spec/next/style_spec.lua`,
`spec/next/content_spec.lua` ("glides an item to its new place in the interaction time", "moves
sections in the interaction time once nothing is dragged too"), `spec/next/bank_spec.lua` ("fades
the wash to the Warbank's over its own time"), `spec/frames/bagcanvas_spec.lua` ("moves in Motion's
0.3 seconds").

## 6. The bank (`next/bank.lua`)

The bank's panel is the backpack's mirror image (§3): anchored to the left edge of the screen, it
slides in from the left, its right edge feathered; the title sits at the top right and its ribbon
runs right out of the window, where the sparkles drift; the header buttons are at the top left;
the tabs stick out to the right. It does everything the classic retail, WoW: Forever and Classic
banks do (`bags/bank.lua`, `bags/classic/bank.lua`, `bags/era/bank.lua`, `frames/bankslots.lua`),
reusing their code wherever it is not drawing.

- **Loading:** the bank's tabs pop in one at a time as it opens, the tab shown first, as the guild
  bank's do (refresh-scheduler.md §11a); the classic bank loads the same way.
- **Title:** the group shown (Bank, Warbank, a custom group), or the Blizzard bank tab's name.
- **Header buttons** (from the screen edge): close (`uitools-icon-close`); settings; Show Bank Tabs
  (retail); Deposit Warbound Items (retail with a Warbank: `C_Bank.AutoDepositItemsIntoBank` for
  the account bank, the menu button's Shift right click); sort, where the client can sort the bank
  (`C_Container.SortBankBags` or `SortBankBags`): the menu button's right click
  (`BagMenuButton:Sort`: the Warbank's sort while a Warbank tab shows, else the bank's; with Shift
  it deposits). Their icons are the theme's glyphs (next-themes.md §11).
- **Tabs, in two modes, as the classic bank:**
  - **Groups** (default): the bank's groups, character groups first and then, after a gap, the
    Warbank groups, each with a teal bar and the Warbank glyph; then "+". Left click shows a group:
    `bank.proto:SwitchToGroup`'s work (Blizzard's bank type, `bankTab`, the title, the purchase
    button, the backpack recalculated so its grey-out follows the bank type). Right click opens the
    group menu (rename, delete; not on default groups); "+" opens the group dialog with its bank type
    choice. The wash at the top of the panel turns teal while a Warbank group shows. Classic
    clients have no Warbank and show only the character groups.
  - **Bank Tabs** (retail; the classic bank's Show Bags, `showBankTabs`): Blizzard's purchased bank
    tabs with their icons and names, character tabs first, then Warbank tabs (teal); a "+" per bank
    type while one can be bought: a `BankPanelPurchaseButtonScriptTemplate` button, whose own click
    opens Blizzard's purchase dialog (buying is protected, `C_Bank.PurchaseBankTab`; it is never
    given an OnClick). Left click shows that tab (`bank.proto:SwitchToBlizzardTab`'s work), right
    click opens Blizzard's tab settings (`BankSlots:OpenTabConfig`), and on WoW: Forever a
    character tab is its bag socket (camelot-forever.md §9): drop a bag on it, drag it, or
    Shift-click it (`BankSlots:PickupBag`).
  - **Show Bank Tabs** switches mode as the classic bank's Show Bags does
    (`ContextMenu:ToggleBagSlots`): it saves `showBankTabs`, switches the bank to the Show Bags view
    (`SECTION_ALL_BAGS`) and back to the view before it, and recalculates the bags
    (`bags/Rederive { resetLayout }`); turning it on shows the first purchased tab.
- **Opening** (`BANKFRAME_OPENED` shows the bank): Blizzard's bank panel is suppressed
  (`BankBehavior:SuppressBlizzardBankPanel`), the active group (in tab mode the first purchased tab)
  is set up, the tabs listed and the money updated, then the panel slides in.
- **Closing:** every `Hide` (the close button, `addon.CloseBank`, Classic's `CloseSpecialWindows`)
  slides the panel out. On retail `C_Bank.CloseBankFrame` ends the bank interaction right away: the
  classic bank behavior's hook on the bag's `Hide` (`BankBehavior:Create`, which Next also uses for
  the group dialogs), with its guard against `BANKFRAME_CLOSED` hiding the bag again. On Classic,
  `CloseBankFrame` runs when the slide ends (as `bags/classic/bank.lua`'s hide callback). Escape
  hides the panel at once; `CloseSpecialWindows` ends the interaction. Nothing touches Blizzard's
  bank panel or ends the interaction from `OnHide` (taint: `UseContainerItem` breaks for every
  container, patterns-taint.md). `SwitchToBankAndWipe` (from `addon.CloseBank`) resets the bank
  type and title, clears the bank's data and releases its buttons, after the slide when the panel
  is still sliding out, so it never slides out empty.
- **Footer:** free slots, and the money as the classic bank shows it (`MoneyFrame:Create(
  addon.hasWarbank)`): the Warbank's gold on retail (left click withdraws, right click deposits),
  the character's on WoW: Forever, none on Classic.
- **Purchase Bank** (retail): a "Purchase Bank" button centered in the content while the bank shows
  the character bank and the character owns no character tab (camelot-forever.md §10; the same
  template, attribute and rule as `bags/bank.lua`).
- **No cooldown refresh**: items in the bank cannot be used, and the classic bank refreshes none.
- **Events:** on retail only (they do not exist on Classic) `BANK_TABS_CHANGED`,
  `PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED` and `BANK_TAB_SETTINGS_UPDATED` list the tabs again
  (`BANK_TABS_CHANGED` also updates the purchase button); on WoW: Forever `PLAYERBANKSLOTS_CHANGED`
  and `BAG_CONTAINER_UPDATE` too (bag badges). `groups/Created`, `Changed`, `Deleted` and
  `EnabledChanged` for the bank list them again; deleting the group shown goes back to the default
  bank group.
- **Interface:** besides the backpack's (§1): `bankTab`, `blizzardBankTab` (read by the data phase
  and the backpack's grey-out), `SwitchToBankAndWipe`, `behavior.SwitchToGroup` and
  `behavior.SwitchToBlizzardTab`.
- **Shared with the classic bank, made reusable:** `BankSlots:OpenTabConfig(bagIndex)`,
  `BankSlots:GetBagSocketIndex(bankType, bagIndex)` and `BankSlots:PickupBag(bankType, bagIndex)`
  (the panel's buttons now call them).

## 8. Coverage

`spec/next/tween_spec.lua` (eases, start value at once, delay, replacing, side by side, stopping
and finishing, a callback starting the next tween, a tween stopped by another in the same frame),
`spec/next/sparkles_spec.lua` (only while started, rate and cap, additive star sprites, drifting
left or right and spinning, fading in and out, reused sprites, quiet in combat, cleared on stop,
palette), `spec/next/tabs_spec.lua` (placement, stacking and widths, the selected font and the
bar, gliding and not, no selection, clicks, hover slide, reuse by kind; accents, gaps, icons from a
file or an atlas, function tooltips, purchase tabs from Blizzard's template with no click of ours,
draggable tabs; the left side's rail, slide, bar and fade), `spec/next/content_spec.lua` (section
order, unlisted categories, drawing, claiming and hanging buttons, free slots one by one, sizing
once, titles and counts, one-column rows, narrower widths, gaps, reuse and pooling, cascades all
and new only, motion while shown and not while hidden, settling on hide), `spec/next/bag_spec.lua`
(the panel and its feathered edge, title, the search box and its setting, deferred draws, the slide
in with its overshoot and out, toggling, a second open or close, cascades on open and on a tab
change, sparkles, closing (expiry, held gaps, a parent's hide), the sweep, the empty hint, free
slots, search, cooldowns, the drop target, tabs: listing, groups off, switching, menus, "+",
regenerating; sort, settings and their atlases, the title's right click sorting and its hint, the keybinding;
`spec/next/chain_spec.lua` "the title": a companion's right click neither chains nor sorts), `spec/next/bank_spec.lua` (the
mirrored panel: edge, feather, title and ribbon, tabs, sparkles, slides; its own search box, no
cooldowns, drops into the bank type shown; the header per client; the money per client; opening:
Blizzard's panel suppressed, the group or tab set up, Warbank wash, "Loading..."; groups: order,
gap, Warbank accent and glyph, switching with the backpack's grey-out, menus, "+", messages,
groups off, a client without a Warbank; bank tabs: listing and purchase tabs, the first tab,
switching, tab settings, tooltips, Forever sockets (drag, drop, click holding a bag, Shift-click,
the base tab, socket icons), the mode switch and its combat refusal, Classic, a tab that is gone,
events per client; closing: ending the interaction once on retail and after the slide on Classic,
nothing from Escape, the wipe after the slide, Classic's tab reset, Recent Items; the Purchase
Bank button), `spec/frames/bankslots_spec.lua` (the socket and tab-settings helpers from the
module), `spec/core/init_spec.lua` ("makes the backpack a BetterBags Next panel when it is on",
"makes the bank a BetterBags Next panel when it is on"), `spec/config/config_spec.lua` (`/bb next`,
`/bbanchor` without anchors), `spec/config/settings_effects_spec.lua` (the switch, the Scale setting
without a window),
`spec/frames/search_overlay_spec.lua` (the keybinding), `spec/quickfind_spec.lua` (a bank whose
tabs have no visual switch), `spec/core/constants_spec.lua`, `spec/database_spec.lua`,
`spec/render/toc_spec.lua` (load order). Moving sections: `spec/next/drag_spec.lua` (on the real
backpack and bank panels: picking up into the drag layer where it was, the lift around the grabbed
point, the gap, categories only, never in Show Bags, one at a time, following; the gap under the
cursor with the others sliding, auto-scroll and its speed at both edges; reordering: the drop, the
saved order, the landing from where it was dropped into the gap, cancelling back to the old place;
saving the order's three cases; tabs of its own bag: lighting and naming, assigning, flying in,
leaving, the pulse, the tab shown and "+", bank types; the other bag: moving, the glow, Bank or
Warbank, into a group's bank type with the assignment, from the bank to a backpack group, a
Blizzard tab, purchase tabs, away from the bank; cancelling on close and when the section leaves
the data; a missed release; the header's item drops and right click, Free Space, free slots; the
release: no item picked up when the drag started over one, reordering or moving to the other bag,
the cover over the section and past its edges, above every frame in it and above one far above
it, no frame of the section sent to the top level, the cover gone once the section is back),
`spec/next/content_spec.lua` ("dragging a section": the gap and its range, the insertion point, the
end, committing, leaving sections, losing the section, no cascade, the faster slide and the usual
speed once nothing is dragged; "section headers"), `spec/render/motion_spec.lua` (a pass's own
duration with the same curve, the default for a pass without one, turning within one duration and
across two),
`spec/next/tabs_spec.lua` ("as a drop target": the tab under the cursor, lighting, the pulse, a lit
tab staying out), `spec/frames/section_spec.lua` ("MoveItems"). Every guard was mutation-tested: 72 mutations for the
backpack (the nine that first survived each led to a stronger test), then 94 for the bank, the
mirrored panel, the tab rail and the wiring (the six that first survived each led to a test), then
73 for moving sections (eleven of the twelve that first survived each led to a test; the twelfth
showed a redundant check, removed), then 14 for the faster slide and the cover (the three that
first survived each led to a test). The mocks gained the scroll box's offset API
(`GetDerivedScrollRange`, `GetDerivedScrollOffset`, `ScrollToOffset`, ScrollBox.lua) and
`IsMouseButtonDown`.

The mocks gained texture rotation (`SetRotation`/`GetRotation`) and Blizzard's
`StaticPopupDialogs` table. **A font string's font comes before its text:** a section title set
its text before its font, and the client raised `FontString:SetText(): Font not set` on opening
the panel (BugSack, `content.lua:145`). The frame mock now raises the same error for `SetText` on
a font string with no font (none set, no inherited template; warcraft.wiki.gg
`API_FontString_SetText`: "the font must be set before showing text"), so every Next test checks
it. It also showed the profiler and Simulate panes' specs building rows with fontless font
strings no template has; they now use the templates' font (`GameFontHighlightSmall`,
`templates/debug.xml`) or let the pane make its own (`BetterBagsPlainTextListButton` has none).

## 9. Known limits of the prototype

- No Show Bags panel for the backpack (the bank's Bank Tabs mode is there), currencies, bag anchor
  or bag menu; the size and opacity settings do not apply (the panels have one size).
- Item buttons keep the classic bags' theme's style, unless the Next theme gives its own (`ItemButton`,
  next-themes.md §6).
- Dropping on a Blizzard bank tab moves items into that tab's bank type; the game decides which tab
  they land in.
- Moving a section between the Character Bank and the Warbank (within the bank) is not offered.
- The backpack was seen in game once, which found the section title font error (§8); not seen
  since that fix. The bank, moving sections, the vendor (next-vendor.md §10) and the guild bank (§13) have not been
  seen in game.

## 13. The guild bank (`next/guildbank.lua`, `next/guildbutton.lua`)

With BetterBags Next on, a panel on the left stands in for Blizzard's guild bank frame: every tab's
items in the bags' categories (All Tabs) or a tab by itself in slot order, its slots Blizzard's own
guild bank item buttons, gold in and out, buying and renaming tabs, and sections dragged in
(deposited) and out (withdrawn). Blizzard's frame stays shown but is never seen. Everything about it,
from the data engine's third kind of bag to the takeover, is in guild-bank.md.
