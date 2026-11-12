---
paths:
  - "next/uipanels.lua"
  - "spec/next/uipanels_spec.lua"
  - "spec/helpers/uipanels.lua"
---
## 27. Blizzard's UI panels beside BetterBags Next (`next/uipanels.lua`, `NextUIPanels`)

Reported: opening the Next vendor moved the Character pane over by the width of Blizzard's merchant frame, not the
vendor's, so the pane opened under the vendor (#1247); the Dressing Room opened behind a vendor docked at the left
(#1282). Asked: "solve this in general".

### 27a. Why it happened

Blizzard's UI panel manager (`Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua`, every client) lays its
panels out from the left edge: the panel in its `left` slot at `LEFT_OFFSET` (16), the next one at `LEFT_OFFSET` plus
the first's width in the layout (its `width` attribute, else its frame's width, times its scale), its `xoffset`, and
`PANEl_SPACING_X` (32) (`UpdateUIPanelPositions`, `GetUIPanelWidthUnscaled`). The frames BetterBags Next stands in for are
among those panels: the merchant frame (next-vendor.md §10a), the bank frame (`core/init.lua`, `HideBlizzardBags`) and
the guild bank frame (guild-bank.md §5) are kept shown, under a hidden frame, so Blizzard's code goes on working, and
Blizzard's interaction manager shows each through `ShowUIPanel` (`PlayerInteractionFrameManager.lua`). So the manager
put the Character pane at 16 + 336 + 32 = 384, beside a frame nobody sees, under the vendor (458 wide, its tabs past
that, in the `HIGH` strata). The bank was worse: its frame ranks after the Character pane (`pushable` 6 to 3,
`UIPanelWindows.lua`), so the pane went to 16, right under the bank. Every panel the manager places beside its left slot
did the same (the Dressing Room, the Friends list, the group finder...).

### 27b. What BetterBags Next tells the manager

- **Where it covers the left edge** (`NextUIPanels:Room`, in UIParent's units, at rest: never where a panel is in its
  slide): a full companion at its edge, its body (`style.BODY_WIDTH`), then its tabs with their hover slide past a side
  rail standing outside it (`RAIL_OUT + tabs:Width() + TAB_HOVER`) or its feather (`FEATHER`), whichever reaches
  further; both draw above Blizzard's panels. Chained `left` (next-chain.md §12a), the backpack beside it too: both
  bodies, the gap between them (`chain:Gap`) and the backpack's far feather (`Chain.OuterFeather`). The ribbon reaches
  further, but in the title's row, above where Blizzard's panels start (`TOP_OFFSET`, -116). Nothing while the companion
  is chained beside the backpack on the right, or waits to go there (`waiting`).
- **The frame it stands in for takes no room** while its full companion is open: its `width` in the layout becomes
  `-(PANEl_SPACING_X + xoffset) / scale`, so the panel after it lands where it would (its own place plus its width, its x
  offset and the spacing). Whichever slot the manager put it in (the vendor's stays left, `pushable` 0; the bank's goes
  right of every other; the guild bank's is double-wide) and whichever panel takes its place (a `pushable` 0 one, the
  Friends list, replaces the bank frame), the panels are laid out as if nothing were at the left edge. Classic's bank
  and guild bank frames sit 16 left of their place (`xoffset` -16), cancelled the same way. Blizzard also scales every
  open panel to fit the screen as the UI scale changes (`UpdateScaleForFitForOpenPanels`, `GameEvent.HandleUiScaleChanged`),
  by the screen's width over its layout width plus `checkFitExtraWidth` (20 unless set; `FrameUtil.UpdateScaleForFitSpecific`):
  found by the second bug review, the negative width gave the merchant frame a scale of -113.8 and closed the panels
  beside it. So its `checkFitExtraWidth` grows by what its width shrank, and it is scaled as its own width says. Both are
  kept and given back when the companion closes, switches to small, or another companion's frame takes over.
- **The panels move right as far as they fit** (`Shift`): by the room, but no further than leaves the last of them (its
  width in the layout, the Dressing Room's outfit list included) as far from the screen's right edge as `LEFT_OFFSET` is
  from its left, and never left of where Blizzard puts them. So each keeps from BetterBags Next the distance Blizzard
  gives it from the screen's edge (its own `xoffset` too), and on a screen too narrow for that, they overlap it as little
  as the screen allows. Where the panels are is read from the manager's slots (`GetUIPanel`: those anchored by their top
  left to UIParent's; a native center panel is centered and stays). The stand-in among them, taking no room, ends left
  of where it starts, so it never decides how far the others move.
- **Which panels the manager keeps never changes**: it decides what fits by comparing the same offsets it places from
  with `GetMaxUIPanelsWidth` (the screen less `RIGHT_OFFSET_BUFFER`; `CanShowCenterUIPanel`, `CanShowRightUIPanel`,
  `CanShowUIPanels`), so `LEFT_OFFSET` and `RIGHT_OFFSET_BUFFER` move by the same shift, and every comparison comes out as
  at no shift: as beside nothing at the left edge. Found by the bug review: with only `LEFT_OFFSET` moved by the whole
  room, a panel that no longer fitted past it made the manager close the panel in its left slot (the merchant frame,
  ending the visit: the Character pane at a vendor chained `left` at UI scale 1, the landing page, the Dressing Room on a
  4:3 screen), drop the bank's frame, or place a wide panel in its left slot (which it never checks) past the screen's
  edge. What `LEFT_OFFSET` and `RIGHT_OFFSET_BUFFER` were is read as they first move (`base`, `buffer`) and put back at
  no shift: another addon's values stay. Nothing else in any client reads a panel's layout width, `LEFT_OFFSET` or
  `RIGHT_OFFSET_BUFFER` (searched on every branch).
- **Each companion names its frame**: `NextPanelOptions.standIn` (`"MerchantFrame"`, `"BankFrame"`,
  `"GuildBankFrame"`), looked up as a global when it is used (the guild bank's loads on demand).
- **Small**, the layout is Blizzard's own: the stand-in keeps its width, `LEFT_OFFSET` stays. A small panel is a window
  the player places and moves; the manager cannot lay its panels out around a window that can be anywhere, and a small
  companion starts at the left margin (next-small-mode.md), where beside Blizzard's own merchant frame is the place its
  panels least cover it. Decided here (the user left it to the implementer).
- **The right edge is left alone**: the backpack, and a companion chained beside it on the right, can still be under a
  panel placed far enough right. Keeping clear of them would mean narrowing what the manager thinks fits, and it closes
  the panel in its left slot (at a vendor, the merchant frame, ending the visit) when a new one does not fit, on screens
  as narrow as UI scale 1 gives (1365 across at 16:9). An overlap is better than the vendor closing as the Character pane
  opens.
- `pushable` 0 panels (the Collections journal, the Encounter Journal, the Friends list) replace the merchant frame in
  the left slot, ending the visit, as they do beside Blizzard's own merchant frame: unchanged.

### 27c. When

- **BetterBags Next's panels change** (`NextUIPanels:Update`, which returns `"placed"` or `"same"`, for profiler traces):
  when the room or the stand-in changed since it last did, the stand-in is taken or given back and the manager lays its
  panels out again (`UpdateUIPanelPositions()`, as Blizzard's own frames do after changing their layout attributes:
  `FriendsFrame.lua`, `Blizzard_ProfessionsCrafting.lua`); then, every time, they move by the shift (`Place`, which lays
  them out again only when the shift changed). The shift follows the screen's width too: found by the second bug review,
  a screen narrowed or widened (the room, in UIParent's units, the same) left the panels where the old width put them,
  past the screen's edge or under the vendor. `NextChain:Update` calls it last (every open, close, flight, theme, tab
  change, and `UI_SCALE_CHANGED`/`DISPLAY_SIZE_CHANGED`: the room follows what `Update` sends the panels to), and
  `NextPanel:SetSize` as the panels switch size (a switch moves no panel through `Update`). `chain.lua` gets the module
  as it calls it: `uipanels.lua` loads after it in every TOC, reading the chain.
- **The order of the two writes**: a classic client lays the panels out as each of UIParent's layout attributes is set
  (`UpdateUIPanelPositions.lua`), asking what fits between the two writes. `Place` writes first the one that leaves more
  room (`RIGHT_OFFSET_BUFFER` as the panels move right, `LEFT_OFFSET` as they move back), so every panel that fits at
  either end fits in between. Found by the second bug review: `LEFT_OFFSET` first closed the Character pane, and the
  bank's frame, as a vendor or the bank opened beside them on a narrow screen.
- **Blizzard's panels change** (one opens, closes, or changes its width: the Character pane widening for its stats, the
  Dressing Room's outfit list): every layout of the manager's ends in `UpdateUIPanelPositions`, hooked once
  (`hooksecurefunc`, from the first room on) to place them again a frame later (`PlaceLater`, on the module's driver
  frame's `OnUpdate`), never from inside the manager's own layout. A panel opening at the shift it found sits there for
  that frame: with nothing open the shift is the whole room, so the first panel opens past BetterBags Next at once, and
  only one that does not fit there moves back, the next frame. The manager keeps the same panels at any shift, so nothing
  closes meanwhile.

### 27d. Taint and the clients

`SetUIPanelAttribute`, `SetUIPanelLayoutAttribute` and `UpdateUIPanelPositions` are the entry points Blizzard's own
frames use to change the layout; they write frame attributes, which carry no taint to the code that reads them
("Attributes are typically used to launder values from insecure code", warcraft.wiki.gg API:Frame_SetAttribute), and the
layout runs in the manager's own delegate (`FramePositionDelegate`, "Dispatch to secure code"). The hook on
`UpdateUIPanelPositions` is `hooksecurefunc`'s (the original runs first and untouched) and only asks for a place a frame
later, so nothing of BetterBags runs inside the manager's layout. Reading where the panels are is `GetUIPanel`,
`GetUIPanelWidth` and `GetPoint`. No frame involved is protected. The layout lives on `UIPanelLayoutFrame` on retail and
WoW: Forever (`GetUIPanelLayoutAttribute`, `SetUIPanelLayoutAttribute`) and on `UIParent`'s attributes on Classic (its
`UIParent.xml`; setting one lays the panels out, `UpdateUIPanelPositions.lua`); the module uses whichever the client has.

Not verified in game: any of it. To check: `/console taintLog 1`; with BetterBags Next on, at full size, open a vendor
and then the Character pane (C), and the Dressing Room (Ctrl+click an item); the other way round; the bank and the Friends
list (O); the guild bank; chained left and right; at UI scale 1 (or a 4:3 screen) the landing page and the guild window
at a vendor and at the bank, which should stay open, the panels on the screen; switch to small and back with the vendor
open; close each; then use a consumable in and out of combat. Each Blizzard panel should open beside the companion's
tabs where the screen has room, and `Logs/taint.log` should have no BetterBags entry blocking an action.

### 27e. Left as they are (from the third bug review)

- **A right panel with nothing in the center** is placed by the left panel's width alone (`rightOffset =
  GetUIPanelWidth(leftPanel) + xoffset`, `UpdateUIPanelPositions`, a quirk of Blizzard's that leaves out `LEFT_OFFSET`),
  so it stays where it would be at no shift, under BetterBags Next, while the left panel moves past it. The manager only
  leaves that state after dropping a center panel that no longer fits (a screen narrowed, a left panel widened); nothing
  this module sets moves that panel. Reproduced on WoW: Forever at 1280 across in a sequence of random opens, closes and
  screen changes; never seen in game.
- **A stand-in at another scale**: its width in the layout is worked out at its scale when it is taken. If another
  addon scaled it, or Blizzard's fit scaled it (only on a screen shorter than it plus 20), the panel after it lands a few
  pixels off (8 at a scale of 0.8), still clear of BetterBags Next. Never seen.
- **A UI scale change** where Blizzard scales a panel to fit after BetterBags Next's own handler found nothing to move:
  the panels are placed again at the manager's next layout. Never seen.

### 27f. Coverage

`spec/next/uipanels_spec.lua` runs each client's own panel manager (`spec/helpers/uipanels.lua`, below) with stand-in
panels in the real chain: the Character pane past the vendor's tabs or its feather, opened before or after it; the
Dressing Room (#1282), with the Character pane after it; following the tabs; the bank (the pane ranks before its frame)
and a panel taking the bank frame's place; the guild bank's double-wide frame; chained left (past the backpack) and right
(the left edge left alone, waiting too); small; the layout and the widths given back as it closes; another value of
`LEFT_OFFSET` kept; laid out again only on a change; the stand-in handed over between companions; on a narrow screen
(1366 across), the vendor kept open as the Character pane opens chained left and as the landing page opens, the bank's
frame kept as the guild window takes the left, the Dressing Room kept as the Character pane opens, each as far right as
the screen allows, two panels side by side, back past the vendor as room frees up, moved again as the screen narrows and
widens, and the stand-in left at its own scale as Blizzard scales its panels to fit; a header rail standing outside the
body; WoW: Forever; on Era, Anniversary and Mists, the vendor (and the Dressing Room on a 4:3 screen), the vendor and the
bank opening beside the Dressing Room and the Character pane on a narrow screen (the Character pane registered from
each client's own `CharacterFrame.lua`), the bank's frame kept as a wide panel moves the panels back on a 4:3 screen (the
other order of the two writes), the bank and the guild bank with their `xoffset`. Every guard was mutation-tested (13
mutations, each caught; one that survived showed a guard that did nothing, removed). `spec/next/vendor_spec.lua`
("beside Blizzard's panels"): the real vendor opened the client's way (`ShowUIPanel(MerchantFrame)`, then
`MERCHANT_SHOW`), the Character pane (#1247) and the Dressing Room (#1282) beside it, and the left edge given back as
the merchant closes. `spec/next/small_spec.lua` ("gives Blizzard's panel layout its left edge back as a full companion
switches to small"). `spec/next/bank_spec.lua`, `spec/next/guildbank_spec.lua` ("stands in for Blizzard's ... frame").

**Blizzard's own manager in specs** (`spec/helpers/uipanels.lua`): `Load(client)` reads the client's
`Blizzard_UIParentPanelManager` files from its branch of `.libraries/wow-ui-source` (in its TOC's order; Classic's
`UIParent.xml` layout attributes set on `UIParent` first) and runs them over the frame mocks, with what they call that the
mocks do not model (no shop open, the player alive, secure code, `FrameUtil.UpdateScaleForFitSpecific` as
`Blizzard_SharedXMLBase/FrameUtil.lua` has it); it returns what puts every global back, `UIParent`'s
attributes and script included, for an `after_each`. `Register(client, path, frame)` runs a client's registration of a
panel outside the manager's files (the guild bank's), `Left(frame)` reads where the manager placed one. The frame mock's
attributes follow the Widget API: names are case-insensitive, `SetAttribute` runs `OnAttributeChanged` and
`SetAttributeNoHandler` does not; `SetForbidden`, `IsForbidden` and `Raise` were added for the manager. Every other spec
gets retail's attribute API from `wow_mocks.lua` (`UIPanelWindows`, `SetUIPanelAttribute`, the layout frame and its
defaults) with an `UpdateUIPanelPositions` that places nothing, as its `ShowUIPanel` only shows.
