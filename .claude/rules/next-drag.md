---
paths:
  - "next/drag.lua"
  - "next/lift.lua"
  - "next/dock.lua"
  - "next/dockcard.lua"
  - "spec/next/drag_spec.lua"
  - "spec/next/lift_spec.lua"
  - "spec/next/dock_spec.lua"
  - "spec/next/dockcard_spec.lua"
---
## 7. Moving sections (`next/drag.lua`)

Asked: "sections draggable and reorderable, with their position being saved where we reorder ...
we drag a header and *all* item buttons and the section header go into my cursor, and when i drag
up and down the bag window, other sections slide up or down to make room. when i drop, it animates
into position", then dragging a section to the other bag ("move this to the bank/backpack" for a
whole section) and between tabs, in the same bag and across the backpack and the bank. Then
selling a backpack section by dragging it onto the vendor: a panel registered with
`NextDrag:RegisterSeller` is a `sell` target for backpack sections anywhere on its body or tabs
while it is shown, checked before the bags' panels; it says what sells (`SaleOf`) and sells it
(`Sell`), and the section flies into it only when it sold (next-vendor.md §10b).

**One drag for sections and settings rows** (`NextLift`, `next/lift.lua`). Lifting a frame onto the
drag layer, its cover and shadow, following the cursor, landing it where its owner says and scrolling a
list near its edges were NextDrag's own; they moved to `NextLift` when the settings lists' rows were made
to move as sections do (next-settings-categories.md §5, "Dragging a row"; asked: "we do this amazingly in the bags
today"), so both drags are the same code. NextDrag keeps the section's part: the canvas's gap, drop
targets, the hint, flying away, the dock. `NextDrag.layer`, `.shadow` and `.cover` are NextLift's; the
shadow is restyled by NextLift's own `ApplyStyle`. One frame is lifted at a time (`NextLift:IsHolding`).
The move changed nothing about the bags' drag: its 67 tests pass with only the shadow's restyle call
added.

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
- A section waiting in another panel's dock is held out of the column (`NextContent:HoldOut`, §7
  "Docked sections"): never placed, never in a drag's places, never faded in, kept bound.
- A section moved away is left out while leaving (`MarkLeaving`) and comes back once its time is up with
  its items still there; `MarkLeaving` lays the column out again then (`C_Timer.After`), since nothing
  else may draw the bag (reported: a section the merchant did not take all of stayed hidden, "limbo").
- The canvas keeps a gap the section's height where it was (`NextContent:BeginDrag`), so the other
  sections do not move until the cursor does.

**Making room.** While the cursor is over its own panel's body, the gap goes to the insertion point
under the cursor (`NextContent:DragIndexAt`, by the midpoints of the other sections), and the other
sections slide out of its way: the canvas lays them out around the gap through Motion
(render-pipeline.md §4c), as for any change of place, in the interaction time (0.24 s, next.md §5; first
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
| the other panel's body | **Move to the other bag, into the tab it shows**: what a drop on that tab does (`NextDrag:ShownTab`: the group shown while groups are on, or the Blizzard tab shown in Bank Tabs mode): the items move (`SectionFrame:MoveItems`, into the tab's bank type for the bank) and the category is assigned to that group (none assigned for a default group). With groups off the items only move. Reported: a category dragged into a non-default backpack group's items "shows up visually, but when you sort the bag, it snaps back": the body drop only moved the items, which showed in Recent Items until a sort and then went to their category's old group (docs/next-batch-2.md §6) |
| a group tab of the other panel | **Move to the other bag, into that tab**: the items move (into the group's bank type when the target is the bank) and the category is assigned to that group in the other bag |
| a Blizzard tab of the other panel (Bank Tabs mode) | **Move to the other bag**: the items move into that tab's bank type; where they land is up to the game (`C_Container.UseContainerItem` names a bank type, not a tab) |
| the guild bank's body, from the backpack (at the guild bank) | **Deposit**: into the guild bank's deposit tab (the tab shown by itself, else Blizzard's current tab), asking first for a tab the player cannot withdraw from (guild-bank.md §5) |
| a guild tab, from the backpack | **Deposit** into that tab, only a tab the player may deposit in |
| the backpack's body or a group tab, from the guild bank | **Withdraw**, and assign the category to the group dropped on, or the one the backpack shows for its body |

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

**Confirming in the target** (`NextDrag:Pend`). A move the target confirms first (a sale past what
buyback keeps, next-vendor.md §10; a deposit into a guild tab the player cannot withdraw from, guild-bank.md §5)
used to open the question dialog while the section landed back in its source. Asked: the dialog
"blends right in", and the section snapping back drew the eye back to the backpack; "maybe ... the
category itself sticks in the vendor with a 'double click to confirm sell' and a glowing pulse". The
target's `Sell` or `Deposit` returns `"confirm"` and a `NextConfirmation` (title, warning, hint), and
the drop ends the drag (NextLift lets go, the canvas's drag ends uncommitted) and docks the section in
the target (below). Confirming moves the section's items as they are then (`SectionItems`; the vendor
recomputes `SaleOf`) and the section flies into the target; nothing moved (nothing left in it, the
target closing) sends it back. A section waiting in a dock is no longer a drag: another section can be
picked up meanwhile, and docks under it.

**Docked sections** (`NextDock`, `next/dock.lua`). Every move waiting for the player waits in one
interface (CLAUDE.md "UI Consistency" 5): a section dragged onto the vendor or the guild bank that
must be confirmed, and a category Auto Sell or Destroy What Can't Be Sold offers at a merchant
(automation.md §4a). Asked: "a list of categories that move over to the vendor window (scroll the
vendor window if needed) to double click to sell, and selling (or cancelling) animates the next section
to the position above it (can autosell a section in the middle, for example)". The first version had
one dock over the target's scroll area (a scrim dimming it, one card, the drag kept going so the source
kept a gap) and a separate destroy card along the vendor's bottom; both are gone.
- **A list per panel** (`NextDock:ListOf`): its cards lead the panel's own column
  (`NextContent:SetLead`), above the panel's sections, one under another in the order they came, so
  they scroll with it; each laid out by Motion as sections are, so when one goes the ones below slide up
  into its place, wherever it was in the list. A card newly docked out of view scrolls the panel to it a
  frame later (`Reveal`, as the text area follows its cursor), once the scroll box has the column's new
  height.
- **Each card** (`NextDockCard`: its fill, fonts, edge, halo and pulse) holds the section, scaled down
  to fit the column with the halo's `Spread` round it (a section of the panel's own column laid out at
  that column's width, as the column would: profession-shopping-list.md §5), and a catcher above the section's item buttons
  (levels only ever raised: lowering threw a descendant to the top level, warcraft.wiki.gg "Frame
  Strata"), so a click answers rather than picking an item up. Its offer (`NextDockOffer`) says its text
  and its glow color (the dock's, or `Dock.DestroyColor` while destroying), read again at every layout
  and after every answer.
- **The section leaves its bag's column** (`NextContent:HoldOut`): the others close up, it stays bound
  (its buttons drawn and kept up to date), and it flies from where it is into its card (`NextLift:Land`,
  aimed at the card each frame, to its scale there). Its bag reading it again resizes it, and the card
  follows.
- **Answering later:** an offer that acts on its own (a sale, sold one item at a time) is told it is
  docked (`docked(entry)`), says how far it is with `NextDock:Refresh(entry)` and answers once done with
  `NextDock:Answer(entry, answer)`; an answer for a section no longer docked does nothing (a sale that
  ended as it started answers while its double click is still answering). Every way a section leaves the
  dock (an answer, a right click, a panel closing, its bag dropping it) calls the offer's `cancel`, which
  stops what it started.
- **Answers:** a double click (`confirm`) and a left click (`click`) go to the offer: "moved" flies the
  section into the panel (the tab it came in by, else the scroll area's middle; `NextLift:FlyAway`), or
  into where the offer says its items went (`destination`: a purchase into the backpack, nowhere when
  that is not there; profession-shopping-list.md §5), then it returns to its bag's column hidden and leaving (`MarkLeaving`, as a move's section does) and
  the tab pulses; "stay" keeps it, reading its card again (its hovered tooltip too); "back" sends it
  back. A right click sends it back: it flies to its place in its bag's column, which makes room for it
  (`NextContent:Returning`), and takes it (`Return`). Clicks are the hardware event selling, moving and
  destroying need.
- **Ends:** the panel or the section's bag hiding sends its sections back at once
  (`NextDock:PanelHidden`, from every panel's `OnHidden`, and from the vendor's `Wipe` and merchant
  close); the section leaving its bag's data gives its frame back to its canvas before the canvas lets it
  go (`HoldOut`'s `onLost`).
- Coverage: `spec/next/dock_spec.lua` (docking out of the bag into the column's first card, the text,
  the glow and a destroy color, fitting the column, flying in, the catcher, docking once, stacking in
  order, scrolling to a card out of view, the pulse; a double click moving it with the next sliding up,
  the tab pulsed, staying restyled, nothing for an offer that does not act, a single click, sent back by
  the offer and by a right click to its place; leaving the data, the panel or the bag closing, the pulse
  stopped, a theme), `spec/next/content_spec.lua` ("holding sections out", "leading frames"),
  `spec/next/lift_spec.lua` ("flying a frame it does not hold", flying away, releasing),
  `spec/next/drag_spec.lua` ("a sale it confirms first": docked with the text, the drag over, double
  click with the items as they are then, single click, right click, nothing left, closing, the seller
  hiding, another section docked under it, the section leaving the data; "the guild bank": a deposit
  docked and confirmed, the tab it was dropped on pulsing; a docked section not picked up),
  `spec/next/vendor_spec.lua` (automation.md §4a), `spec/next/guildbank_spec.lua` (`Deposit` confirms
  rather than asks), `spec/next/bag_spec.lua` (a bag hiding sends its docked sections back).
- Mutation-tested with the canvas, lift, drag, vendor, Automation and the setting: 97 mutations. Fifteen
  first survived: thirteen led to tests (seated at the card's scale, laid out again when the section
  grows, aiming at its place on the way back, a fly-away leaving the held frame's shadow alone and
  starting where the frame was, the tab a guild deposit was dropped on, a docked section not picked up,
  a bag's hide, a leaving or elsewhere-docked section not offered, a big sale's double click as its
  confirmation, a sale finding nothing going back, a single click keeping a sale, no tooltip on a sale)
  and two were dead code, removed (the dock's `docked` checks in `Click` and `DoubleClick`: a free
  card's catcher has no entry; the vendor's `atMerchant` check: it shows only at a merchant).

**Positions** are in `UIParent`'s coordinates: the cursor (`GetCursorPosition` over `UIParent`'s
effective scale), and the canvas, tabs and scroll area read through `NextLift` (`ScreenPoint`, `Center`,
`ScaleOf`): a small panel has a Bag Scale (next-small-mode.md §14h), and the client reports a scaled frame's edges in its
own units. The dragged section keeps its size on screen, and its position is always worked out from
the cursor and the grabbed point, never read back from it.

**The header also** files an item dropped or clicked onto a category's header in that category
(`panelProto:FileCursorItem`, category-lifecycle.md §9; asked: "if you drag and drop an item onto a
category header, it becomes an Added Item in that category"), no Shift needed, in the backpack, the bank
and the guild bank; Recent Items, Free Space and a bag's section in the Show Bags view pass the item to
the panel as before (bag-drop-zone.md, `SectionFrame:OnTitleClickOrDrop`). A right click moves the whole
section to the open window (the classic header's Move Categories, `SectionFrame:MoveItems`).

`SectionFrame:MoveItems(list, bankType?)` is the classic right click's move, taken out of
`OnTitleRightClick` so both use it: the movement flow (or, with `bankType`, that bank while it is
open), every pile of each item's virtual stack, the vendor's limit of 10 and the category-sell
setting, then `C_Container.UseContainerItem` for each item.
