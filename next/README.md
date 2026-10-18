# BetterBags Next (experimental)

An experiment in a new bag design: full-height panels that slide in from the edges of the screen,
the backpack from the right and the bank from the left, each with its tabs down its inner side,
the categories in one column of big icons, and a title with a ribbon of light and sparkles drifting
out of the window. It replaces only how the bags are drawn: the item data, the item buttons and the
settings that feed the data are the classic bags'. Off unless the player turns it on (**BetterBags
Next (experimental)** in the settings, or `/bb next`), which takes effect after a reload.

The design, the rules it follows and its coverage are in `.claude/rules/next.md`.

## Module Structure

```
next/
├── style.lua     # NextStyle: sizes, palette, timings and fonts, in one place
├── tween.lua     # NextTween: one tween per key on a single OnUpdate (slide, fades, glides)
├── sparkles.lua  # NextSparkles: a pooled particle emitter of star sprites
├── tabs.lua      # NextTabs: the tab rail down a panel's inner edge
├── content.lua   # NextContent: the canvas: sections in one column, laid out through Motion
├── drag.lua      # NextDrag: moving sections by their headers: reorder, to a tab, to the other bag
├── panel.lua     # NextPanel: the panel both bags are made of, for either side of the screen
├── bag.lua       # NextBag: the backpack's panel, on the right (addon.Bags.Backpack)
└── bank.lua      # NextBank: the bank's panel, on the left (addon.Bags.Bank)
```

Files load in that order in every TOC, after `frames\bag.lua` (they use the search box, the money
frame, the bag behaviors, the menu button and the render pipeline) and before `core\init.lua`.

## One panel, two sides

`NextPanel:Create(proto, opts)` builds a panel for `opts.side` (`"RIGHT"` or `"LEFT"`), and
everything mirrors with it: the edge it is anchored to and slides from, the feathered edge, the
tabs, the title and its ribbon, the sparkles, the header buttons and the footer. A kind makes its
prototype with `NextPanel:Extend(proto, name)` and overrides what differs: `GetHeaderButtons`,
`CreateMoney`, `RefreshTabs`, `OnTabClicked`, `OnTabDragged`, `GetCurrentTabID`, `OnShowing`,
`OnSlidOut`, `WatchKind`, `Refresh` and `Sort` (and `watchesCooldowns`).

## How it takes over

`core/init.lua` makes `addon.Bags.Backpack` with `NextBag:Create(ctx)` instead of
`BagFrame:Create(ctx, BACKPACK)` when `database:GetNextEnabled()`, and `addon.Bags.Bank` with
`NextBank:Create(ctx)` when the bank bag is enabled too. The classic bags are then not created at
all, so they never draw the same item buttons. Everything else in the addon talks to whichever
object is there; the panels provide the members they use (`Show`, `Hide`, `Toggle`, `IsShown`,
`Draw`, `Search`, `ResetSearch`, `OnCooldown`, `Refresh`, `Sort`, `Wipe`, `GetName`, `SetTitle`,
`ToggleSearch`, `PlaceCursorItem`, `frame`, `kind`, `searchBox`, `loaded`, `drawOnClose`,
`behavior.SwitchToGroup`; the bank also `SwitchToBankAndWipe`, `bankTab`, `blizzardBankTab` and
`behavior.SwitchToBlizzardTab`).

## Drawing

`NextPanel:Draw` is the classic draw pass: claim the buttons drawn, then release the ones the last
pass drew and this one did not. `NextContent:Bind` builds the sections (Recent Items, the active
tab's categories in their order, Free Space) and draws the static per-slot item buttons, sized to
44 pixels; `NextContent:Render` lays them out in one column inside the panel's scroll box, through
Motion so what changed place glides there. A draw while the panel is hidden waits for it to open.

## Moving sections

Every section has a header button. Dragging a category's header picks the section up: its frame,
with its real item buttons, moves to `NextDrag`'s layer and follows the cursor, while the canvas
keeps a gap (`NextContent:BeginDrag`, `SetDragIndex`, `DragIndexAt`) that the other sections slide
around. Dropping reorders it (`NextDrag:SaveOrder` pins the new order in `customSectionSort`),
assigns its category to a tab's group, or moves its items to the other bag with
`SectionFrame:MoveItems`. Targets are found by position every frame. Panels register with
`NextDrag:Register` and answer `ShownBankType`, `InTabMode` and, for the bank, `BankTypeOfTab`.

## The bank

The bank reuses the classic bank's code wherever it is not drawing: `BankBehavior`'s group dialogs
and purchase rule (`bank.proto`, with the Next bank as its `bag`), `BankBehavior:SuppressBlizzardBankPanel`,
`BagMenuButton:Sort`, and `BankSlots:OpenTabConfig`, `GetBagSocketIndex` and `PickupBag` (retail
TOCs only). It never touches Blizzard's bank panel or ends the bank interaction from `OnHide`.

## Writing Next code

- A font string's font comes before its text (`SetFontObject` first, then `SetText`): the client
  raises `FontString:SetText(): Font not set` otherwise, and the spec mock does too.
- Anything that animates goes through NextTween (a key per thing animated) or Motion (frame
  placement); there is one OnUpdate for each, and neither runs while idle.
- Look and timings live in NextStyle; nothing else hard-codes a size or a color.
- An atlas must be in the atlas table of every client that shows it (wago.tools
  `UiTextureAtlasMember`, per build): `GM-icon-settings` is missing on Classic Era and Mists.
- Specs are in `spec/next/`.
