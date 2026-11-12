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
├── chain.lua     # NextChain: the backpack and its companion apart on opposite edges, or chained on one
├── uipanels.lua  # NextUIPanels: Blizzard's UI panels (Character pane, Dressing Room...) open beside the panels
├── categorypicker.lua # NextCategoryPicker: an item dropped on a bag's title, into a category or a new one
├── glass.lua     # NextGlass: a theme's body as smoked glass: tint, light, rain, lightning (Panel.Glass)
├── sheen.lua     # NextSheen: a theme's panels catching the light as they fade in and out (Panel.Sheen)
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
`OnSlidOut`, `WatchKind`, `Refresh` and `Sort` (and `watchesCooldowns`), and what a right click on
its title does with `OnTitleRightClick` and `TitleRightClickHint` (the backpack sorts; the others do
nothing).

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

The vendor (`vendor.lua`, `addon.Vendor`) and the guild bank (`guildbank.lua`, `addon.Bags.GuildBank`) stand in for
Blizzard's merchant and guild bank frames, each while its own switch is on (Enable Vendor Window, Enable Guild Bank
Window): `core/bagsystem.lua` switches either off and on at once (`.claude/rules/next-bagsystem.md` §11g). Switched off
(`Deactivate`), a panel is marked `off` and answers no visit, its Blizzard frame is given back and shows the vendor or
the guild bank, and `Activate` switches it on again.

Each companion names the frame of Blizzard's it stands in for (`opts.standIn`: `MerchantFrame`, `BankFrame`,
`GuildBankFrame`). Blizzard's UI panel manager still lays that frame out, shown and never seen, so `uipanels.lua`
(`NextUIPanels`) tells the manager where BetterBags Next really is: while a full companion is open, its frame takes no
room in the layout and the layout's left edge (`LEFT_OFFSET`) moves past what BetterBags Next covers there, so the
Character pane, the Dressing Room and every other Blizzard panel open beside it, not under it. `NextChain:Update` and
`NextPanel:SetSize` update it (`.claude/rules/next-uipanels.md`).

## Drawing

`NextPanel:Draw` is the classic draw pass: claim the buttons drawn, then release the ones the last
pass drew and this one did not. `NextContent:Bind` builds the sections (Recent Items, the active
tab's categories in their order, Free Space) and draws the static per-slot item buttons, sized to
44 pixels; `NextContent:Render` lays them out in one column inside the panel's scroll box, through
Motion so what changed place glides there. A draw while the panel is hidden waits for it to open.

## A small panel's width

A small panel's width sits on a grid step, whole cells of icons and the room beside them, at the first step from
the width the player chose (saved, its default, or where a resize grip was let go) at which neither its title nor
any section's name is cut short: `NextPanel:FitWidth`, which asks the canvas `NextContent:NameCells` how many cells
its names need there, going up a step at a time (more cells can mean more columns, each narrower), never past the
screen. Its minimum holds its whole title (`MinWidth`, `measureTitle`; a vendor's name that is a secret keeps the
least room it always kept). It is fitted as it opens (opened again as it slides out too) and as a grip is let go;
while it is open, only with Fit Names While Open on (`FollowNames`, which glides it as a grip's snap does and saves
nothing; it waits while the panel or the open bag chained to it is not settled, trying again each frame until it
follows, so a chained pair glides one at a time, and fits a new title a frame on, so a bank tab's name and sections
are fitted in one glide). A refit (a theme, the screen, a scale) ends a size glide first, and refits a panel whose size
glides. The bag chained to a panel moves with its size glide only where the glide moves the side it hangs from (a
grip's snap never does), and a bag gliding into its spot beside its anchor follows the spot as the anchor glides,
while that bag is still its anchor. It lays out at rest for the
width it last took (`RestingLayoutWidth`). The rules are in `.claude/rules/next-small-resize.md` §14g (the snap, the bag chained beside
it, `RestingLayoutWidth`), its continuation in `.claude/rules/next-small-names.md` (the names) and
`.claude/rules/next-columns.md` §7a.

## A small panel's height

With **Autosize Bags** on (the default) a small panel is as tall as what it shows: its header, every section and Free
Space as last laid out (the scroll box's `FitHeight`, kept by the render root) and its footer, so nothing scrolls; never
shorter than its tab rail nor past the screen (`NextPanel:RestingHeight`, `FittedHeight`). It takes that height as it opens
and glides to it a frame after anything it shows changes (`FollowHeight`, which waits as `FollowNames` does, and glides with
the grips' snap, `snapTo`, its width as it is). Its top stays where it was left, or centered at its default place, and its
bottom stays on the screen (`clampPlace`, saving nothing). Its grips size it both ways, and as they let go its height bounces
back to what it shows, its width saved alone. It keeps as much room below its last section, down to its footer's line, as
between its sections.
Off, it is the height the player gave it with its grips, or a share of the screen. The rules are in
`.claude/rules/next-small-autosize.md` §14i.

## Moving sections

Every section has a header button. Dragging a category's header picks the section up: its frame,
with its real item buttons, moves to `NextDrag`'s layer and follows the cursor, while the canvas
keeps a gap (`NextContent:BeginDrag`, `SetDragIndex`, `DragIndexAt`) that the other sections slide
around. Dropping reorders it (`NextDrag:SaveOrder` pins the new order in `customSectionSort`),
assigns its category to a tab's group, or moves its items to the other bag with
`SectionFrame:MoveItems`. Targets are found by position every frame. Panels register with
`NextDrag:Register` and answer `ShownBankType`, `InTabMode` and, for the bank, `BankTypeOfTab`.

## Putting an item in a category from the title

An item dropped on the backpack's or the bank's title (or, in a theme that says so, its bag button: Plain's;
`Header.ItemDrop`) opens the category picker under it (`NextPanel:PickCategory`, `NextCategoryPicker`): a menu with a
field, headed by the item, listing every category in its order with a new category named what is typed, and a way back
to where the item belongs when it was added to a category by hand. The item goes back to its slot while the player
picks; a category picked files it as dropping it on that category's header does. The rules are in
`.claude/rules/next-category-picker.md`.

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
