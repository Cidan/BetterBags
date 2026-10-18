# BetterBagsNext (`next/`, experimental)

An experiment in a new bag design: full-height panels that slide in from the edges of the screen,
the backpack from the right and the bank from the left, each with its tabs down its inner side, the
categories in one column of big icons, and a title with a light ribbon and sparkles drifting out of
the window. Asked for: "magical, with whimsy and animations; nice to use, but functional", then
"bank next, but, on the opposite side! remember we have warbank, etc." It replaces only how the bags
are drawn: the data pipeline, the item buttons and every setting that feeds the data are the same.

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
- With Enable Bank Bags on, `addon.Bags.Bank` is likewise `NextBank:Create(ctx)` (§6). One setting
  turns Next on for both bags.
- The same setting makes the vendor (§10): `addon.Vendor = NextVendor:Create(ctx)`, kept apart from
  `addon.Bags` (it is no bag, and the render recorder walks `addon.Bags`), and `NextVendor:TakeOver`
  puts Blizzard's merchant frame under the hidden frame Blizzard's bags are under. Its name is in
  `UISpecialFrames`.
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
  `SetTabByID`); the vendor is not made and Blizzard's merchant frame is left alone (§10). The
  twelve `next\*.lua` files load for everyone and only register modules and
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
section dragged out of a panel returns to the panel's strata (§7).

- A frame anchored to the top right and bottom right of `UIParent`: full height, 554 wide. From the
  left: a 96-pixel **feathered edge** (a horizontal gradient of the body color, transparent to
  opaque; no border art) and the 458-pixel body (a solid deep indigo, with a faint lavender wash at
  the top). The body reaches 40 pixels past the right edge so the opening overshoot never shows the
  world behind it. The feather takes no clicks (`SetHitRectInsets`).
- **Header:** the title, "Backpack", 26-pixel white with a soft shadow; a light **ribbon** running
  left from the title across the feather and out of the window (a thin gold line and a soft glow,
  both fading out to the left) with a spark that sweeps along it every few seconds; sort and
  settings buttons at the top right (`bags-button-autosort-up`, `uitools-icon-settings`). Both
  atlases are in the client's atlas table (`UiTextureAtlasMember`, wago.tools) on retail 12.1.5,
  WoW: Forever 1.60.1, Classic Era 1.15.9, Mists 5.5.4 and Anniversary 2.5.6. The settings button
  first used `GM-icon-settings`, which Classic Era and Mists do not have: the button was blank there.
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
title's ribbon and, more rarely, along the feathered edge, drifting out of the window (left from the
backpack, right from the bank: the emitter's `Direction`) while they twinkle, spin and fade, in
starlight gold, white and moon lavender. At most 28 alive, about
8 a second; textures are pooled. It runs only while the panel is shown, and spawns nothing in
combat (those already alive finish).

## 5. Motion helpers (`next/tween.lua`)

`NextTween:Play(key, { duration, from, to, ease, delay, onUpdate, onDone })` runs one tween per key
on a single `OnUpdate` that exists only while something tweens; playing a key again replaces its
tween, `Stop(key, finish)` stops it (at its end with `finish`). Eases: `linear`, `outCubic`,
`inCubic`, `inOutSine`, `outBack`.

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

- **Title:** the group shown (Bank, Warbank, a custom group), or the Blizzard bank tab's name.
- **Header buttons** (from the screen edge): close (`uitools-icon-close`); settings; Show Bank Tabs
  (retail); Deposit Warbound Items (retail with a Warbank: `C_Bank.AutoDepositItemsIntoBank` for
  the account bank, the menu button's Shift right click); sort, where the client can sort the bank
  (`C_Container.SortBankBags` or `SortBankBags`): the menu button's right click
  (`BagMenuButton:Sort`: the Warbank's sort while a Warbank tab shows, else the bank's; with Shift
  it deposits). Icons are in the atlas table of every client that shows them (`warbands-icon`:
  retail and Forever).
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

## 7. Moving sections (`next/drag.lua`)

Asked: "sections draggable and reorderable, with their position being saved where we reorder ...
we drag a header and *all* item buttons and the section header go into my cursor, and when i drag
up and down the bag window, other sections slide up or down to make room. when i drop, it animates
into position", then dragging a section to the other bag ("move this to the bank/backpack" for a
whole section) and between tabs, in the same bag and across the backpack and the bank. Then
selling a backpack section by dragging it onto the vendor: a panel registered with
`NextDrag:RegisterSeller` is a `sell` target for backpack sections anywhere on its body or tabs
while it is shown, checked before the bags' panels; it says what sells (`SaleOf`) and sells it
(`Sell`), and the section flies into it only when it sold (§10b).

**Picking up.** Every section has a header button over its title row. Dragging it (left button,
the client's drag threshold: `RegisterForDrag`, `OnDragStart`) picks up a category section; Recent
Items and Free Space stay put, and nothing is picked up in the Show Bags view (`SECTION_ALL_BAGS`,
which includes the bank's Bank Tabs mode: its sections are bags, in bag order) or while another
section is being dragged or landing.

- The section's own frame, with its title and its real item buttons, leaves the canvas for the drag
  layer (`NextDrag.layer`, a full-screen frame on `UIParent` in the `TOOLTIP` strata that takes no
  mouse) at exactly the place it was on screen, so nothing jumps. Its children follow its strata
  (frames take their parent's strata unless one sets its own; no item button does) and keep their
  levels relative to it. Its level is raised to the layer's + 2 when below it, never lowered:
  lowering a frame lowers every frame in it, and one that would go below 0 jumps to the top level,
  10000 (warcraft.wiki.gg "Frame Strata"), where the cover could not be above it.
- A **cover** lies over it: a mouse-enabled, invisible frame in the drag layer, anchored 20 pixels
  past every edge of the section and 100 levels above the highest frame in it. The client starts a
  drag only once the cursor has moved a little, so the point grabbed (which stays under the cursor)
  can be one of the section's item buttons rather than its header. The release goes to the
  mouse-enabled frame under the cursor (warcraft.wiki.gg `UIHANDLER_OnReceiveDrag`: also when
  dragging widgets), and an item button's `OnReceiveDrag` is a left click
  (`ContainerFrameItemButtonMixin:OnReceiveDrag` → `OnDragStart` → `OnClick("LeftButton")`), which
  picked the item up (reported: dragging a section down and letting go left its item in the hand).
  The release now lands on the cover, which does nothing with it. Nothing about the drop changes:
  it is the header's `OnDragStop`, which the client sends to the frame being dragged wherever the
  cursor is (`UIHANDLER_OnDragStop`), and targets are found by position. The cover also keeps the
  section's item tooltips from opening under the cursor while it is dragged. It hides when the
  section is back in its canvas (it stays while the section lands, so a click then picks up
  nothing either).
- It lifts: it shrinks to 94% around the point that was grabbed, with a soft shadow, over 0.12 s.
  From then on it follows the cursor, the grabbed point staying under it.
- The canvas keeps a gap the section's height where it was (`NextContent:BeginDrag`), so the other
  sections do not move until the cursor does.

**Making room.** While the cursor is over its own panel's body, the gap goes to the insertion point
under the cursor (`NextContent:DragIndexAt`, by the midpoints of the other sections), and the other
sections slide out of its way: the canvas lays them out around the gap through Motion
(render-pipeline.md §4c), as for any change of place, in the interaction time (0.24 s, §5; first
asked for this slide alone, "slightly faster, just a bit", then for every Next move) rather than
Motion's usual 0.3 s. The curve is the same ease-in-out. Near the top or bottom of the scroll area
(40 pixels) the content scrolls toward the edge, faster the closer the cursor
(`ScrollToOffset`/`GetDerivedScrollOffset`, Blizzard's scroll box on every client).

**Drop targets**, found from the cursor's position every frame (`IsMouseOver`, geometric, so the
section under the cursor never hides what is below it). Each shows what dropping does: the target
tab lights up (`NextTabs:SetDropTarget`), or the other panel's body glows; a line under the section
names the action ("Move to Herbs", "Move to the Warbank"...).

| Over | Drop |
|---|---|
| its own panel's body | **Reorder**: the section moves to the gap; its new place is saved (below) |
| a tab of its own panel | **Move to that tab**: the category is assigned to the tab's group (`Groups:AssignCategoryToGroup`, which removes the assignment for a default group) |
| the other panel's body | **Move to the other bag**: every item of the section is moved there, as the classic header's right click does (`SectionFrame:MoveItems`, the movement flow: the bank type the bank shows) |
| a group tab of the other panel | **Move to the other bag, into that tab**: the items move (into the group's bank type when the target is the bank) and the category is assigned to that group in the other bag |
| a Blizzard tab of the other panel (Bank Tabs mode) | **Move to the other bag**: the items move into that tab's bank type; where they land is up to the game (`C_Container.UseContainerItem` names a bank type, not a tab) |

Not targets (the section lands back where it was): the tab already shown, "+", purchase tabs, a
bank group of the other bank type than the section's (Character Bank categories cannot go to
Warbank groups and back, as with the classic drag: `UseContainerItem` cannot move items between
the two), the other bag while not at the bank, anything else.

**Dropping.**
- Reorder, or no target: the section flies from the cursor into its gap and back to full size over
  0.22 s, aiming at the gap's place every frame (the content may still be scrolling), then returns
  to the canvas at exactly that place; the canvas places it at once there (Motion places a frame the
  previous pass did not), so nothing jumps.
- Any move: the section flies into the target (the tab's center, or the middle of the other panel's
  content), shrinking to 15% and fading out over 0.3 s; a target tab pulses. It returns to the canvas
  hidden and **leaving** (`NextContent:MarkLeaving`): the canvas leaves it out (the others close the
  gap) until its category is gone from the tab, or it has nothing but gaps left, or 3 seconds pass
  with its items still there (a move the game refused), when it shows again.
- Then the bags are recalculated (`bags/Rederive`, refresh-scheduler.md §10): the bag whose order or
  tabs changed, with a fresh layout for tab moves.

**Saving the order** (`NextDrag:SaveOrder(kind, names, index)`). A section's place is its
category's entry in `customSectionSort[kind]` (the settings' "Pinned" order, util/sort.lua): pinned
categories come first, by their number, then the rest by the section sort setting. After a drop the
tab's categories, in their new order, are `L`, with the dropped one at `k`. Everything in `L` up to
and including `k` is pinned, and so is everything after `k` that was pinned already; together they
form one block, in `L`'s order, put into the global pinned list where the first of them was (or at
its end), and the list is numbered again from 0. Categories after `k` that were not pinned stay
unpinned and keep following the sort setting; other tabs' categories keep their relative order. The
next recalculation therefore sorts the tab exactly as it was dropped.

**Cancelling.** The panel closing (`OnHidden`), the section disappearing from the data mid-drag, or
the canvas being torn down puts the section straight back in its canvas with no action. The drop
itself is the header's `OnDragStop`: a mouse release, the hardware event `UseContainerItem` needs
(it is how the classic header's right click moves a category). If the client misses the release
(another window took the mouse; Blizzard's own drags check for it, `FloatingChatFrame.lua`), the
drag drops once it finds the left button up two frames in a row (`IsMouseButtonDown`; the first
frame leaves the release's own `OnDragStop` its chance), but without moving items: an `OnUpdate`
is no hardware event, so a drop on the other bag or its tabs lands back.

**Positions** are in `UIParent`'s coordinates: the cursor (`GetCursorPosition` over `UIParent`'s
effective scale), the canvas, tabs and scroll area (all at scale 1 under `UIParent`). The client
reports a scaled frame's edges in its own scale, so the dragged section's position is always worked
out from the cursor and the grabbed point, never read back from it.

**The header also** passes an item dropped or clicked onto it to its panel (bag-drop-zone.md: Shift
adds the item to the category, as the classic title does, `SectionFrame:OnTitleClickOrDrop`), and a
right click moves the whole section to the open window (the classic header's Move Categories,
`SectionFrame:MoveItems`).

`SectionFrame:MoveItems(list, bankType?)` is the classic right click's move, taken out of
`OnTitleRightClick` so both use it: the movement flow (or, with `bankType`, that bank while it is
open), every pile of each item's virtual stack, the vendor's limit of 10 and the category-sell
setting, then `C_Container.UseContainerItem` for each item.

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
regenerating; sort, settings and their atlases, the keybinding), `spec/next/bank_spec.lua` (the
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
"makes the bank a BetterBags Next panel when it is on"), `spec/config/config_redraw_spec.lua` (the
checkbox, `/bb next`, `/bbanchor` without anchors, the Scale slider without a window),
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
- Item buttons keep the active theme's style.
- Dropping on a Blizzard bank tab moves items into that tab's bank type; the game decides which tab
  they land in.
- Moving a section between the Character Bank and the Warbank (within the bank) is not offered.
- The backpack was seen in game once, which found the section title font error (§8); not seen
  since that fix. The bank, moving sections and the vendor (§10) have not been seen in game.

## 10. The vendor (`next/merchant.lua`, `next/vendorbutton.lua`, `next/vendor.lua`)

Asked: "render the vendor windows like we do the bank -- because it's not possible to do both at
the same time, this is fine. i want the categories, etc. but with the right buttons at the top (sell
junk, etc). remember tabs for buyback, repair if it's available, etc.", with the prices under the
icons, a full Repair tab and the backpack's categories. With BetterBags Next on, a panel on the left
(the bank's side; the two never open together) stands in for Blizzard's merchant frame.

### 10a. Taking over Blizzard's merchant frame

Blizzard's bag code decides what a right click on a bag item does at a vendor from
`MerchantFrame:IsShown()` and `MerchantFrame.selectedTab` (`ContainerFrameItemButton_OnClick`:
sell on tab 1, nothing on Buyback; `UpdateJunkItem` marks junk while it is shown; `OnEnter` shows
the sell cursor). So the frame must stay shown, on tab 1, and never be seen:

- `NextVendor:TakeOver(BetterBagsSneakyFrame)` (`core/init.lua`, Next only) parents it to the hidden
  frame `HideBlizzardBags` makes. `IsShown` is the frame's own flag, so it is still true once
  Blizzard's `MerchantFrame_MerchantShow` shows it (`ShowUIPanel`), and its own check
  (`if not MerchantFrame:IsShown() then CloseMerchant()`) passes. Nothing of BetterBags writes its
  fields or its tab. Its scripts are left as they are.
- Under a hidden parent the frame is never visible, so its `OnShow` and `OnHide` never run
  (camelot-forever.md §8). `OnHide` is what ended the visit (`MerchantFrame_OnHide` calls
  `CloseMerchant`), so whatever hides it now (the panel manager opening another left panel, Escape
  through `CloseWindows`) would leave the vendor open with nothing on screen. `TakeOver` hooks
  `MerchantFrame:Hide` (`hooksecurefunc`, which writes the field securely) and ends the visit a
  frame later, outside Blizzard's own code, when it is still open then. Its `OnShow` did
  `OpenAllBags`; BetterBags opens the backpack from the interaction event as before.
- The panel ends the visit itself when it is what closes: its close button (`Hide`, at once), and
  Escape (it is in `UISpecialFrames`; its `OnHide` ends it a frame later). `MERCHANT_CLOSED` slides
  it out, puts the cursor back (`ResetCursor`) and closes Blizzard's purchase prompts, as
  `MerchantFrame_OnHide` did. `closeRequested` and `atMerchant` make every path end the visit once.
- Move Categories (`util/movementflow.lua` `AtNPCShopWindow`) checked `MerchantFrame:IsVisible()`,
  false under the hidden parent. It now checks `IsShown()`, as Blizzard's bag code does, for the
  classic bags too (the two differ only while `UIParent` is hidden).

### 10b. The panel (`next/vendor.lua`, `NextVendor`)

- A `NextPanel` (§3) on the left, `kind = BAG_KIND.UNDEFINED`, `noDrag` (its sections are not
  registered with `NextDrag`: nothing is dragged from or to it), its rows as tall as an icon plus
  the price (`style.VENDOR_PRICE`, `NextCanvas:SetCellHeight`). The canvas lays out sections of the
  vendor's own buttons with `BindSections` (it never claims item buttons there).
- **Title:** the vendor's name (`UnitName("npc")`), cut to one line in the room right of the shown
  header buttons.
- **Header buttons** (from the screen edge): close; settings; the filter (retail and Forever, unless
  `Enum.GameRule.MerchantFilterDisabled`: Blizzard's own radio list, each spec, the class, Bind on
  Equip, everything, through `MenuUtil.CreateContextMenu`, `SetMerchantFilter`); Sell Junk; Repair
  All; the guild's repair (only where `CanGuildBankRepair()`). Repair buttons only at a vendor that
  repairs (`CanMerchantRepair()`), disabled with nothing to repair; Sell Junk disabled with no junk.
  Icons: Blizzard's own, `SpellIcon-256x256-SellJunk`, `-RepairAll`, `-RepairAllGuild` on retail and
  Forever (both load the mainline merchant XML); Classic's `UI-Merchant-RepairIcons` with its
  coordinates, and a coin for Sell Junk (Classic has no such button). Hidden buttons leave no gap
  (`NextPanel:LayoutHeader`). The repair tooltips are Blizzard's: the cost, not enough money, and
  what the guild pays (`GetGuildBankWithdrawMoney`, -1 for a guild leader: the whole balance).
- **Tabs:** Buy, Buyback, and Repair at a vendor that repairs. It opens on Buy.
  - **Buy:** what the vendor sells, in the backpack's categories and section order (10c), each item
    in the vendor's order. Footer: the player's gold and the vendor's currencies
    (`C_MerchantFrame.GetMerchantCurrencies`, retail).
  - **Buyback:** what was sold, newest first, in one "Sold" section.
  - **Repair:** "Equipped" and "In your bags", each damaged item with its durability as a bar along
    the icon (green to red) and what repairing it costs; the footer the total.
- **Search:** a box of its own, always shown, that searches the vendor's items in their own index
  (10c) on Buy and by name on the other tabs; what it leaves out is dimmed. It makes no search
  category (the bags' box does on Enter).
- **Selling:** an item dropped on the panel or on a section header, or let go over it, is sold as on
  Blizzard's frame (its `OnMouseUp`: Blizzard's refund question first,
  `ContainerFrame_GetExtendedPriceString(MerchantFrame.refundItem, ...)`, then `PickupMerchantItem(0)`).
- **Selling a section** (asked: "drag a section anywhere into a vendor window from my backpack to
  sell everything in that section"): the vendor is a `NextDrag` seller (`RegisterSeller`, §7), never
  a source. While it is shown, a backpack section dragged over its body or its tabs lights it and
  names the sale ("Sell 7 items", "Nothing in it sells"). `SaleOf` is what sells: every item and
  every pile its virtual stack hides (`sectionFrame:WithStacks`, shared with Move Categories), in
  the backpack's bags, each slot once, leaving out what the vendor does not buy (`hasNoValue`) and
  refundable purchases (`C_Item.CanBeRefunded`: Blizzard asks before refunding one, and
  `UseContainerItem` would refund it without asking). `Sell` sells it at once (`SellSlots`, while
  the vendor is open) when buyback can keep all of it (12, Blizzard's `BUYBACK_ITEMS_PER_PAGE`),
  else asks first ("Sell 13 items? Only the last 12 items sold can be bought back."). The section
  flies into the vendor when it sold, and lands back in its place when nothing sells or while the
  question is open. Selling needs the drop's release, as moves do: a drag ended without one sells
  nothing. Unlike a right click on the header (Move Categories), it does not need Enable Category
  Sell and Deposit and is not cut to 10 items: the drag is the deliberate act, and the question
  covers what buyback cannot.
- **Masque:** each button is a holder the canvas places (`frame`, as tall as the icon and its price)
  holding the square button that takes the clicks (`button`), so Masque, which sizes a skin to the
  button it skins (Masque 12.1.0 `Core.lua` `UpdateScale`), skins the icon alone. The button carries
  Masque's names for an item button's parts (`icon`, `IconBorder`, `Count`; `Skins/Regions.lua`),
  and `MasqueRegions` lists them with the highlight. A new button is announced once
  (`vendor/NewButton`); the Masque integration adds it to its own `BetterBags/Vendor` group as an
  `Item` button, takes it out under a theme with `Masque = false`, and adds it back when a theme
  that uses Masque applies (vendor buttons are reused, not drawn again on a theme change). A draw
  needs no re-skin: it sets the icon's file (Masque keeps its crop) and the border's color, and
  Masque re-skins the border itself when its texture is set (its `IconBorder` hook).
- **Keeping up:** `MERCHANT_UPDATE`, `MERCHANT_FILTER_ITEM_UPDATE`, `CURRENCY_DISPLAY_UPDATE` redraw;
  `UPDATE_INVENTORY_DURABILITY`, `PLAYER_MONEY`, `BAG_UPDATE_DELAYED` update the header and redraw;
  `GET_ITEM_INFO_RECEIVED` is bucketed, only while it is shown. A draw keeps the button of every key
  drawn again and releases the rest. Not measured: one sale fires several of these in a frame, each
  a full draw (a read of every item, its tooltip and its category); capture a vendor visit with the
  profiler (`NextVendorPanel.Draw`, `NextMerchant.ReadItems`) before changing it.

### 10c. What it shows (`next/merchant.lua`, `NextMerchant`)

- **Items:** `C_MerchantFrame.GetItemInfo` on retail and Forever, `GetMerchantItemInfo` on Classic;
  link, ID, max stack, `CanAffordMerchantItem`, the costs (`GetMerchantItemCostItem`, at most three),
  heirlooms known (retail), and whether Blizzard asks before buying it
  (`C_MerchantFrame.IsMerchantItemRefundable`; Classic asks about nothing, its heirloom check is
  commented out). A currency for sale is named as its container (`CurrencyContainerUtil`).
- **Categories:** each item gets a record the backpack's categories read (`kind` the backpack,
  `slotkey` `vendor:<index>`, its type from `GetItemInfoInstant`, the rest from `GetItemInfo`, its
  tooltip text from `TooltipScanner:GetMerchantItemText`), and `items:GetCategory` names it: custom
  item lists, type, subtype, equipment slot, expansion, as in the backpack. The backpack's search
  categories are evaluated over the vendor's own index, the lowest priority number winning, a custom
  category beating a search one only with a lower number (a tie goes to search), a grouped one
  named after the item (`GetGroupBySuffix`); none is created. `ReadItems` says when an item's data
  was not loaded yet.
- **Its own search index:** an instance of the search module (`setmetatable({}, {__index = search})`,
  `Init`), so the bags' index never holds vendor items. A negated query covers what an index holds:
  `search:Universe()` (every item of both bags, as before), which the vendor's instance replaces
  with its own items. `Search` returns only the vendor's slots.
- **Buyback:** `GetBuybackItemInfo`, newest first; `BuybackItem` on a click.
- **Repair:** equipped items (`GetInventoryItemDurability`) and items in the backpack's bags
  (`C_Container.GetContainerItemDurability`) below full durability, each with its cost
  (`TooltipScanner:GetInventoryRepairCost` / `GetBagRepairCost`: the `TooltipData`'s `repairCost`
  on retail, which Blizzard's `TooltipDataRules.lua` reads; on Classic the scan tooltip's
  `SetInventoryItem` third and `SetBagItem` second return, as `PaperDollFrame.lua` and
  `ContainerFrame_Shared.lua` read them). One item repairs as after Blizzard's Repair An Item button:
  in repair mode (`ShowRepairCursor`), a pickup of the item repairs it; the cursor goes back to the
  mode it was in. Repair All is `RepairAllItems(guild)`.

### 10d. Buying: Blizzard's own confirmations

Blizzard asks before buying an item with an extended cost, an item that is not refundable, and an
expensive one (`MERCHANT_HIGH_PRICE_COST`, 150 gold). `NextMerchant:Purchase` makes the vendor
button carry what Blizzard's confirmations read of a merchant button (its ID, price, extended cost,
name, link, texture, count, `showNonrefundablePrompt`, as `MerchantFrame_UpdateMerchantInfo` sets
them) and calls them exactly as `MerchantItemButton_OnClick` does: `MerchantFrame_ConfirmExtendedItemCost`
for extended costs and items not refundable, `MerchantFrame_ConfirmHighCostItem` for expensive ones,
`BuyMerchantItem` otherwise. Blizzard's functions decide whether and how to ask (token, currency,
limited currency, quality); BetterBags never asks in their place and never buys past them. CompactVendor
(Vladinator) calls the same functions from its own buttons. A quantity (Shift-click) goes the way
Blizzard's stack split does (`SplitStack`): confirmed for extended costs and items not refundable,
bought at once otherwise, at most what `MerchantItemButton_OnModifiedClick` allows (the stack
limit, the money, the cost items held). BetterBags asks the number with its own dialog, as Blizzard
asks it with its stack split frame (not a confirmation).

- A left click never puts a vendor item on the cursor: Blizzard confirms a picked-up item when it
  is dropped in a bag through `MerchantFrame.extendedCost` / `highPrice`, which its own item button
  sets, so a pickup from our button would buy past them.
- `BuyMerchantItem`, `BuybackItem`, `RepairAllItems`, `PickupMerchantItem`, `CloseMerchant` have no
  generated documentation and no restriction on the wiki; `C_MerchantFrame.SellAllJunkItems` is
  documented without restrictions (unlike `C_Bank.PurchaseBankTab`, `HasRestrictions = true`, which
  is why the bank's Purchase button is Blizzard's template, camelot-forever.md §10).
- **Sell Junk:** retail and Forever call `MerchantFrame_OnSellAllJunkButtonClicked`, Blizzard's own
  button handler (its confirmation, then `C_MerchantFrame.SellAllJunkItems`). Classic has neither:
  BetterBags asks (its own dialog, saying only the last 12 sold can be bought back), then sells the
  poor items worth something (`UpdateJunkItem`'s rule) with `C_Container.UseContainerItem`, three
  rounds 0.2 s apart while junk is left and the vendor is open (items lock while they sell; GW2_UI
  sells the same way), as Move Categories already sells.

### 10e. Taint, and what is not verified

What BetterBags does to Blizzard's merchant code: it reparents the frame at load (as it does the
bank frame), hooks its `Hide` securely, reads `MerchantFrame.refundItem`, and calls Blizzard's
confirmation functions from its own buttons. Those functions write `MerchantFrame.itemIndex`,
`count` and `price` and show Blizzard's popups from BetterBags' execution, so those fields and the
popup are tainted until Blizzard writes them again; their accept buttons call `BuyMerchantItem`,
which is not protected. Nothing of BetterBags writes `selectedTab`, `extendedCost`, `highPrice` or
`refundItem`, the fields Blizzard's bag code reads before `UseContainerItem`.

Not verified in game: any of it. To check: `/console taintLog 1`, open a vendor with Next on, buy a
plain item, an expensive one, one with a currency cost; Shift-click a quantity; buy back; Sell Junk;
repair one item and all; sell by right-clicking a bag item, by dropping one on the panel, with Move
Categories; close with the button, Escape and by walking away; then use a consumable from the bags
in and out of combat. `Logs/taint.log` should have no BetterBags entries blocking an action.
Also not verified: Classic's `UseContainerItem` selling (the wiki marks it protected; Move
Categories already sells with it), a single-item repair through repair mode, and the per-item
repair costs.

### 10f. Coverage

`spec/next/merchant_spec.lua` (items on retail and Classic, costs, currencies, cold data, records;
the backpack's categories, search categories by priority and against custom ones, grouped names,
section order; its own index, negated queries, forgetting the last vendor; buyback order; repair
lists, costs, one item and all; every purchase path and quantity limit; junk on both clients,
selling while open), `spec/next/vendorbutton_spec.lua` (look, counts, stock, quality, tints, heirlooms
and reuse, prices, unaffordable, search dimming; tooltips and cursors; clicks: buy, Blizzard's
modified clicks, quantities, buyback, repair; durability), `spec/next/vendor_spec.lua` (the panel,
no drags, its search box; header buttons per client, shown and enabled per vendor, the title's
room, the game rule; opening, tabs and footers, button reuse, updates; Sell Junk on both clients,
three rounds, stopping on close; repairs and their tooltips; the filter; selling by dropping and
Blizzard's refund question; every way of closing ending the visit once; the takeover),
`spec/next/content_spec.lua` ("sections of other buttons"), `spec/tooltip_spec.lua` ("merchants and
repair"), `spec/movementflow_spec.lua` (a shown merchant frame under a hidden parent),
`spec/core/init_spec.lua` ("the vendor"), `spec/render/toc_spec.lua`. Selling a section and Masque:
`spec/next/drag_spec.lua` ("dropping on a seller": lit and named, sold and flown in, its tabs, one
item, nothing that sells, a question open, no release, hidden, closing, a bank section),
`spec/next/vendor_spec.lua` ("selling a section": registered, what sells, at once up to 12, asking
past it, nothing once closed), `spec/frames/section_spec.lua` (`WithStacks`),
`spec/next/vendorbutton_spec.lua` (the holder and its square button, Masque's names, announced
once, the tooltip's owner), `spec/integrations/masque_spec.lua` ("vendor buttons"). Every guard was
mutation-tested: 90 mutations, the fourteen that first survived each leading to a test; then 37 for
selling sections and Masque (one led to a test, one showed a guard Masque's `AddButton` already
makes, removed). The mocks
gained the merchant APIs from Blizzard's merchant code (`ResetMockMerchant`), modified-click
bindings from `Bindings_*.xml`, a `hooksecurefunc` that hooks (it was a no-op), `MenuUtil`'s context
menu, `C_GameRules`, coin strings and merchant tooltips.
