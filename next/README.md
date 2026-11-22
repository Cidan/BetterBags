# BetterBags Next (experimental)

An experiment in a new bag design: full-height panels that slide in from the edges of the screen,
the backpack from the right and the bank from the left, each with its tabs down its inner side,
the categories in one column of big icons, and a title with a ribbon of light and sparkles drifting
out of the window. It replaces only how the bags are drawn: the item data, the item buttons and the
settings that feed the data are the classic bags'. Off unless the player turns it on (**BetterBags
Next (experimental)** in the settings, or `/bb next`), which applies after a reload.

The design, the rules that govern it and its coverage are in `.claude/rules/next.md`.

## Module Structure

```
next/
├── style.lua     # NextStyle: sizes, palette, timings and fonts, in one place
├── tween.lua     # NextTween: one tween per key on a single OnUpdate (slide, fades, glides)
├── sparkles.lua  # NextSparkles: a pooled particle emitter of star sprites
├── tabs.lua      # NextTabs: the tab rail down a panel's inner edge (a tab's icon against the body, its name past it)
├── content.lua   # NextContent: the canvas: sections in one column, laid out through Motion
├── drag.lua      # NextDrag: moving sections by their headers: reorder, to a tab, to the other bag
├── chain.lua     # NextChain: the backpack and its companion apart on opposite edges, or chained on one
├── uipanels.lua  # NextUIPanels: Blizzard's UI panels (Character pane, Dressing Room...) open beside the panels
├── categorypicker.lua # NextCategoryPicker: an item dropped on a bag's title, into a category or a new one
├── glass.lua     # NextGlass: a theme's body as smoked glass: tint, light, rain, lightning (Panel.Glass)
├── sheen.lua     # NextSheen: a theme's panels catching the light as they fade in and out (Panel.Sheen)
├── panel.lua     # NextPanel: the panel both bags are made of, for either side of the screen
├── screencard.lua    # NextScreenCard: a card that stays on screen (the currency tracker, the Food & Drink bar)
├── fooddrinkbar.lua  # NextFoodDrinkBar: the food and the drink on two item buttons, a right click eats
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
its title does with `OnTitleRightClick`, `TitleRightClickHint` and `TitleRightClickLabel` (the backpack and the bank sort;
the others do nothing). In a theme with a bag button (Plain), a right click on the button does the same, and its menu lists,
after the header's buttons, what only it offers (`MenuEntries`: that right click's action, and the switch to small bags,
`SizeEntry`, on a panel with no size button). A theme may put every header button on a backdrop (`Header.Buttons.Backdrop`:
ElvUI's square bag buttons), with an icon's own overriding it.

Docked at full height, a panel spans from the screen's top to its bottom, unless its theme sets a margin from both
(`Panel.DockMargin`, the Plain theme): the panel is inset by the distance its art extends past its body there (`NextFrameArt:Reach`,
`NextMenuButton:Reach`) and the margin, so the visible gap is the margin at both (`NextPanel:DockInsets`). The rules are in
`.claude/rules/next.md` §3.

## A small panel's place and its anchor

A small panel is anchored to a corner (`HeldCorner`, saved as `nextSmallCorners`: its side and its edge), so it grows away from that corner:
dragged by its title, the bottom left or bottom right, by the half of the screen it was placed on; dragged by its anchor
square, any of the four, by the square's quadrant (up from a bottom corner, down from a top one). `SmallPlace` works its top
left out from the corner and its size; chained bags align by the edge their anchor is anchored to. The backpack's and the bank's
anchor button (where their sort
button was; their titles sort on a right click) cycles free, shown (the classic bags' blue square, `Anchor:CreateSquare`, on
the corner: when dragged, the bag moves with the square) and locked (the bag neither moves nor resizes, nor does the bag chained beside it,
`Held`). The rules are in `.claude/rules/next-bag-anchor.md` §30.

## Frame replacement

`core/init.lua` makes `addon.Bags.Backpack` with `NextBag:Create(ctx)` instead of
`BagFrame:Create(ctx, BACKPACK)` when `database:GetNextEnabled()`, and `addon.Bags.Bank` with
`NextBank:Create(ctx)` when the bank bag is enabled too. The classic bags are then not created at
all, so they never draw the same item buttons. Everything else in the addon uses whichever
object is there; the panels provide the members they use (`Show`, `Hide`, `Toggle`, `IsShown`,
`Draw`, `Search`, `ResetSearch`, `OnCooldown`, `Refresh`, `Sort`, `Wipe`, `GetName`, `SetTitle`,
`ToggleSearch`, `PlaceCursorItem`, `frame`, `kind`, `searchBox`, `loaded`, `drawOnClose`,
`behavior.SwitchToGroup`; the bank also `SwitchToBankAndWipe`, `bankTab`, `blizzardBankTab` and
`behavior.SwitchToBlizzardTab`).

The vendor's tabs are Buy, Buyback and Repair; a sale flashes the Buyback tab (`NoteBuyback` on `MERCHANT_UPDATE`,
`.claude/rules/next-vendor.md` §10b).

The vendor (`vendor.lua`, `addon.Vendor`) and the guild bank (`guildbank.lua`, `addon.Bags.GuildBank`) stand in for
Blizzard's merchant and guild bank frames, each while its own switch is on (Enable Vendor Window, Enable Guild Bank
Window, each on its page's General tab in the settings): `core/bagsystem.lua` switches either off and on at once (`.claude/rules/next-bagsystem.md` §11g). Switched off
(`Deactivate`), a panel is marked `off` and answers no visit, its Blizzard frame is given back and shows the vendor or
the guild bank, and `Activate` switches it on again. The vendor's item cards (`vendorbutton.lua`) show Blizzard's
tooltips as its merchant frame does: the item's over the card, and over each cost besides gold (a crest, a currency, an
item) that cost's own, from an area that receives pointer hover and passes clicks through to the card
(`.claude/rules/next-vendor.md` §10b). A Shift-click prompts for a quantity in `NextDialog` over the vendor, its field a
quantity: one purchase's worth to start, `-` and `+` a purchase's worth at a time, and Max, the most that can be bought
at once, owned currencies counted too where the client lists the merchant's (`NextMerchant:MaxPurchasable`,
`.claude/rules/next-vendor.md` §10d). With TradeSkillMaster loaded, the vendor and TSM's own vendor window alternate
(`.claude/rules/tradeskillmaster.md`): the vendor stays aside (`aside`) while TSM's window shows the merchant, its
TradeSkillMaster header button opens TSM's window (`SwitchToTSM`, the vendor sliding out without ending the visit,
`StepAside`), and TSM's WoW UI button restores the vendor (`FollowTSM`, `StepBack`), checked every frame of a visit by
`integrations/tradeskillmaster.lua`. TSM rewrites the merchant frame's width in Blizzard's layout as it switches;
`uipanels.lua` removes the merchant frame from the layout again (`NextUIPanels:Retake`, `.claude/rules/next-uipanels.md` §27c).

On WoW: Forever's gamepad interface every panel is in Blizzard's window list while it is open
(`integrations/gamepad.lua`, `.claude/rules/gamepad.md`). The gamepad cursor moves to elements a panel marks (`bbGamepad`): the
item buttons, a vendor card's icon (`vendorbutton.lua`: A buys, or sells an item held, as Blizzard's merchant gamepad
prompt does), the guild bank's buttons (`guildbutton.lua`) and the rail's tabs (`tabs.lua`).

The guild bank's rail has three views at its foot (`NextTabEntry.foot`, `tabs.lua`), under its tabs and chosen as any
tab is: Blizzard's Log, Money Log and Info. A log is the vendor's cards (`NextVendorButton:SetLog`) in sections by how
long ago, each with a glyph for which way it went, tinted (`Vendor.LogIcons`), and who did it;
Info is each tab's text, a text area (`NextInput:CreateArea`) the canvas displays as a section's block
(`NextContent:BindSections` with `block`), with Save for a member who may edit it (`.claude/rules/guild-bank.md` §5).

Each companion names the frame of Blizzard's it stands in for (`opts.standIn`: `MerchantFrame`, `BankFrame`,
`GuildBankFrame`). Blizzard's UI panel manager still lays that frame out, shown and never seen, so `uipanels.lua`
(`NextUIPanels`) reports BetterBags Next's position to the manager: while a full companion is open, its frame occupies no
room in the layout and the layout's left edge (`LEFT_OFFSET`) moves past what BetterBags Next covers there, so the
Character pane, the Dressing Room and every other Blizzard panel open beside it, not under it. `NextChain:Update` and
`NextPanel:SetSize` update it (`.claude/rules/next-uipanels.md`).

Each companion also names the interactions it opens at (`opts.interactions`: the vendor `Merchant`, the guild bank
`GuildBanker`, the bank `Banker` and, with a Warband bank, `AccountBanker`). Chained to a closed backpack, a companion
defers opening until the backpack opened by its interaction opens, unless every one of those interactions is set not to open the backpack
(`NextChain:WaitsForAnchor`, `.claude/rules/interaction-bags.md` §3).

## Drawing

`NextPanel:Draw` is the classic draw pass: claim the buttons drawn, then release the ones the last
pass drew and this one did not. `NextContent:Bind` builds the sections (Recent Items, the active
tab's categories in their order, Free Space) and draws the static per-slot item buttons, sized to
44 pixels; `NextContent:Render` lays them out in one column inside the panel's scroll box, through
Motion so what changed place glides there. A draw while the panel is hidden is deferred until the panel opens.

Each bag's Layout tab can set its sections out side by side instead, read from the panel at every layout
(`NextPanel:SectionColumns`, `NextContent:SetColumnSource`): Section Columns, Compact Sections, Gap Between Sections (an
empty cell of the grid between sections side by side), Fill Order and the wide sections' two settings. Every icon in a
bag stands on one grid. The rules are in `.claude/rules/next-columns.md` §7a to §7c.

## A small panel's width

A small panel's width aligns to a grid step, whole cells of icons and the room beside them, at the first step from
the width the player chose (saved, its default, or where a resize grip was released) at which neither its title nor
any section's name is cut short: `NextPanel:FitWidth`, which queries the canvas `NextContent:NameCells` for how many cells
its names require there, increasing one step at a time (more cells can mean more columns, each narrower), never past the
screen. Its minimum fits its whole title (`MinWidth`, `measureTitle`; a vendor's name that is a secret retains the
fixed minimum width). It is fitted as it opens (opened again as it slides out too) and as a grip is released;
while it is open, only with Fit Names While Open on (`FollowNames`, which glides it as a grip's snap does and saves
nothing; the fit defers while the panel or the open bag chained to it is not settled, rechecking each frame until it
executes, so a chained pair glides one at a time, and fits a new title a frame later, so a bank tab's name and sections
are fitted in one glide). A refit (a theme, the screen, a scale) ends a size glide first, and refits a panel whose size
glides. The bag chained to a panel moves with its size glide only where the glide moves the side it hangs from (a
grip's snap never does), and a bag gliding into its spot beside its anchor tracks the spot as the anchor glides,
while that bag is still its anchor. It lays out at rest for the
width it last applied (`RestingLayoutWidth`). The rules are in `.claude/rules/next-small-resize.md` §14g (the snap, the bag chained beside
it, `RestingLayoutWidth`), its continuation in `.claude/rules/next-small-names.md` (the names) and
`.claude/rules/next-columns.md` §7a.

## A small panel's height

With **Autosize** on (each bag's own, on its page's Size tab; the default, but the vendor's) a small panel is as tall as
what it shows: its header, every section and Free
Space as last laid out (the scroll box's `FitHeight`, stored by the render root) and its footer, so nothing scrolls; never
shorter than its tab rail nor past the screen (`NextPanel:RestingHeight`, `FittedHeight`). The panel applies that height as it opens
and glides to it a frame after anything it shows changes (`FollowHeight`, which defers as `FollowNames` does, and glides with
the grips' snap, `snapTo`, its width as it is). Its bottom stays at its anchored position, and its top stays on the screen
(`clampPlace`, saving nothing: the panel moves back up as it shrinks). Its grips size the panel both ways, and when released its height glides
back to what it shows, its width saved alone. It reserves as much space below its last section, down to its footer's line, as
between its sections.
Off, it is the height the player gave it with its grips, or a share of the screen. The rules are in
`.claude/rules/next-small-autosize.md` §14i.

With **Clamp Bags to Screen** on, a small panel is clamped to the screen along with its tabs, which hang past its body on its inner
side (`NextPanel:TabReach`): every assigned position clamps them to the screen (`clampPlace`), its clamp rect includes them
so the client constrains them there as the panel is dragged (`ApplyClamp`), and as its tabs change it glides to the position computed
with them, pushed in by tabs that grow at the screen's edge and back as they shrink or hide (`FollowTabs`). The rules are in
`.claude/rules/next-small-mode.md` §14c.

## Moving sections

Every section has a header button. Dragging a category's header picks the section up: its frame,
with its real item buttons, moves to `NextDrag`'s layer and tracks the cursor, while the canvas
reserves a gap (`NextContent:BeginDrag`, `SetDragIndex`, `DragIndexAt`) that the other sections slide
around. Dropping reorders it (`NextDrag:SaveOrder` pins the new order in `customSectionSort`),
assigns its category to a tab's group, or moves its items to the other bag with
`SectionFrame:MoveItems`. Targets are found by position every frame. Panels register with
`NextDrag:Register` and answer `ShownBankType`, `InTabMode` and, for the bank, `BankTypeOfTab`.

With Hide Empty Groups on (`.claude/rules/groups.md` §3), the backpack's and the bank's rails omit the tabs of groups
with nothing in them (`panelProto:ShownTabs`, following each draw, `FollowGroups`), and every registered panel shows them
all while a section is dragged (`RevealGroups`, from `NextDrag:Begin` to its `finish`): the rail lists its tabs again
gliding (`NextTabs:SetTabs(entries, true)`: a group retains its own tab, the others slide, a tab coming in fades in and one
going out fades out).

## Putting an item in a category from the title

An item dropped on the backpack's or the bank's title (or, in a theme that specifies this, its bag button: Plain's;
`Header.ItemDrop`) opens the category picker under it (`NextPanel:PickCategory`, `NextCategoryPicker`): a menu with a
field, headed by the item, listing every category in its order with a new category named what is typed, and a way back
to where the item belongs when it was added to a category by hand. The item returns to its slot while the player
picks; selecting a category assigns the item as dropping it on that category's header does. The rules are in
`.claude/rules/next-category-picker.md`.

## Cards on the screen: the currency tracker and the Food & Drink bar

`NextScreenCard` (`screencard.lua`) is a small card of the theme's (`Currency.Tracker`) that stays where it was dropped,
the bags open or closed: the card grows from a corner, is clamped to the screen, is picked up and dropped with the shared lift,
is put away by a drop on the open backpack, and hides in combat (when configured) and pet battles. The currency tracker
(`currencytracker.lua`, `.claude/rules/currency.md` §5) and the Food & Drink bar are kinds of it (`card:Extend`), each
defining its own overrides (`Option`, `Saved`, `Save`, `Home`, `Wants`, `LayOut`, ...).

The Food & Drink bar (`fooddrinkbar.lua`, `NextFoodDrinkBar`) shows the food and the drink `FoodDrink`
(`data/fooddrink.lua`) selects, each on one of BetterBags' own item buttons pointed at its stack (`item:SetSlot`). A right
click eats or drinks, as on the item in the bags; a left click does nothing; a drag moves the bar. Switched on (Show Food
& Drink Bar, the Food & Drink page) the bar emerges from the open backpack (`card:Emerge`); dropped on the backpack it is put
away and switched off. Its buttons are in Masque's "Food & Drink" group. The backpack makes it and switches it off and on
with BetterBags Next (`NextBag`). The rules are in `.claude/rules/food-drink.md`.

## The bank

The bank reuses the classic bank's code wherever it is not drawing: `BankBehavior`'s group dialogs
and purchase rule (`bank.proto`, with the Next bank as its `bag`), `BankBehavior:SuppressBlizzardBankPanel`,
`BankBehavior:DepositWarbound` (its Deposit All Warbound Items, prompting for confirmation in `NextDialog` over the bank first when the
deposit would end a refund; `.claude/rules/warbank-deposit.md`), `BagMenuButton:Sort`, and `BankSlots:OpenTabConfig`,
`GetBagSocketIndex` and `PickupBag` (retail TOCs only). It never touches Blizzard's bank panel or ends the bank
interaction from `OnHide`.

## Writing Next code

- A font string's font is set before its text (`SetFontObject` first, then `SetText`): the client
  raises `FontString:SetText(): Font not set` otherwise, and the spec mock does too.
- Anything that animates uses NextTween (a key per thing animated) or Motion (frame
  placement); there is one OnUpdate for each, and neither runs while idle.
- Appearance and timings are defined in NextStyle; nothing else hard-codes a size or a color.
- An atlas must be in the atlas table of every client that shows it (wago.tools
  `UiTextureAtlasMember`, per build): `GM-icon-settings` is missing on Classic Era and Mists.
- Specs are in `spec/next/`.
