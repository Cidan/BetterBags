---
paths:
  - "next/merchant.lua"
  - "next/vendor.lua"
  - "next/vendorbutton.lua"
  - "util/movementflow.lua"
  - "spec/next/merchant_spec.lua"
  - "spec/next/vendor_spec.lua"
  - "spec/next/vendorbutton_spec.lua"
  - "spec/movementflow_spec.lua"
---
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
- **Blizzard's panel manager still lays the frame out** (it is shown through `ShowUIPanel`), 336 wide in its left slot,
  and put the Character pane and the Dressing Room after it, under the vendor (#1247, #1282). The vendor names it
  (`standIn = "MerchantFrame"`): while the vendor is open at full size, the frame takes no room in the layout and the
  layout's left edge moves past the vendor and its tabs (next-uipanels.md §27).
- **Enable Vendor Window off** (next-bagsystem.md §11g, #1262): the bag system switches the vendor off by itself while
  Next stays in use, away from a vendor only. `vendorProto:Deactivate` marks it `off` (then hides it and lets go of its
  buttons, as every panel's), and `GiveBack` puts the frame back under `UIParent`, where Blizzard's own scripts show the
  vendor and end its visits. While `off`, `OnMerchantShow` opens nothing and `OnMerchantClosed` leaves the cursor and
  the purchase prompts to the frame's own `OnHide`; the `Hide` hook finds no visit to end (`atMerchant` stays false).
  `vendorProto:Activate` clears `off`, and `TakeOver` takes the frame again. The panel stays registered meanwhile: its
  other handlers act only while it shows. Coverage: `spec/next/vendor_spec.lua` ("switched off").

### 10b. The panel (`next/vendor.lua`, `NextVendor`)

- A `NextPanel` (next.md §3) on the left, `kind = BAG_KIND.UNDEFINED`, `noDrag` (its sections are not
  registered with `NextDrag`: nothing is dragged from or to it), its items cards (`NextCanvas:SetCards`,
  `CellWidth`; rows as tall as an icon). The canvas lays out sections of the vendor's own buttons with
  `BindSections` (it never claims item buttons there).
- **Cards** (asked, from a user: the price under the icon was "way too small"; a first version put
  it in three rows beside the icon, still too small; then: "let's actually do this like this, which
  is the gw2 addon ... name too?"): each item is a card, as Blizzard's merchant (`MerchantItemTemplate`:
  the icon, the name to its right in two lines, the price under it) and GW2_UI (which restyles that
  template, a backdrop per item, two columns) draw it.
  - `Layout.VendorColumns` (2) cards across the full grid (`style.VENDOR_CARD_WIDTH`, the grid less
    the gaps between them, divided); a small vendor made wider fits more of them, one made narrower
    fewer (`NextPanel:MinWidth` keeps one card).
  - Beside the icon (`VendorTextGap` from it, as much again from the card's right edge): the name at
    the top (`Vendor.NameFont`, `VendorName` 13; Quiet 12), up to two lines, from Uncommon up in its
    quality's color, else the role's (Parchment's ink on its paper); and the price on one line at the
    bottom, `VendorPriceRaise` (3; Quiet 2) up from the card's edge (asked: "2-3 pixels up from the
    border"), in the price font (13; Quiet 12), written as Blizzard's merchant writes it
    (`NextVendorButton:PriceText`): each coin of the gold it has (gold, silver, copper; none for a coin
    it has none of), each amount then its coin (`Vendor.CoinSize`), then each other cost the same way;
    cut short when it does not fit (the tooltip shows the whole price). Two lines of the name, a line
    of the price and the raise fit the icon's height in every shipped theme.
  - The card's fill (`Vendor.CardFill`) and a light over it under the pointer (`CardHover`, from the
    icon or anywhere on the card), each a color or false. The whole card takes the clicks and the
    pointer (`card`, a button under the icon's): its tooltip, its buy, buyback and repair.
  - **A cost's own tooltip** (issue #1283, reported: over Vaskarn's crest cost the card showed the item's
    tooltip, "as other addons would show it there"; asked: "fix it with hover only areas for costs"). Blizzard's
    merchant draws each cost besides gold as a button of its own (`SmallAlternateCurrencyFrameTemplate`'s
    `SmallDenominationTemplate`s), whose `OnEnter` shows that cost's tooltip:
    `GameTooltip:SetMerchantCostItem(index, costIndex)` (`SmallDenominationTemplate_OnEnter`, retail
    `MoneyFrame.lua`; Classic's `MoneyFrame.xml` the same), `costIndex` the cost's place among
    `GetMerchantItemCostItem`'s (`MerchantFrame_UpdateAltCurrency`). The card's price is one font string, so
    `NextVendorButton:placeCosts` lays an area over each cost it writes (`costAreas`, made as needed, kept per
    card): from where the price up to the cost before it ends (after the gold, for the first) to where the price
    up to it ends. It measures as `NextPanel:measureTitle` does (a font string measures at the width it was cut
    to): the price's width set to none, its text set to each part (`priceParts`, the parts `PriceText` joins),
    `GetStringWidth`, then its whole text and width back, all in one call, before the client draws. An area ends at
    the price's width when the price cuts its cost short, and a cost cut off gets none. `Style` lays them out again
    (a theme, a new grid, Icon Scale change the price's font and width); `Release`, a buyback, a repair and gold
    alone hide them.
    - **Hover only.** An area is a `Frame` over the card (frame level + 3), `EnableMouse(true)` then
      `SetMouseClickEnabled(false)`, as Blizzard's tooltip-only widgets do (`UIWidgetTemplateTooltipFrameMixin:SetMouse`,
      `Blizzard_UIWidgetTemplateBase.lua`; the API is on every client BetterBags runs on). It takes the pointer and no
      click, so a right click over a cost still buys from the card and an item dropped there still sells; it has no
      `OnClick` or `OnReceiveDrag` of its own.
    - **Its tooltip** (`OnCostEnter`): owned by the area (`ANCHOR_RIGHT`, as Blizzard's), the cost's own and nothing
      added (Blizzard's adds nothing), the card lit (`CardHover`) and the card's cursor (buy, or buy error), as a
      click there buys. Leaving it is the card's `OnLeave`. The card's item tooltip still lists every cost as a line.
    - **The cost's place**: `costsOf` keeps it (`costIndex`, the API's `i`, past a place it leaves out for a
      missing texture), and `PriceOf` carries it, so a Shopping List card (profession-shopping-list.md) shows the
      cost's tooltip for its quantity too. `TotalOf`'s total sums costs across items: it is no card, and has no areas.
    - **Seen in game** (2026-11-12, WoW: Forever, the Darkmoon Faire): the pointer over a card's Darkmoon Prize
      Ticket cost shows the ticket's tooltip. Not seen yet: that a drop passes through a motion-only frame to the card
      under it.
    - **Left as it is (bug review):** no spec sees the price's width set to none before measuring. The client measures a
      font string cut short at the width it is cut to (next-small-names.md §14g), as the specs model it, and every measure
      is cut at the price's width anyway, so taking it out changes nothing a faithful mock can show (the mutation
      survives). It stays so a measure never depends on how the client measures a cut text: were a cut part measured
      short of the width, a cost hidden past the cut would get an area over the "...". A card with costs writes its price up
      to five times more as it is set or styled (the gold, each cost's part, then the whole); not measured in a capture.
  - **Drops sell** (`NextMerchant:SellCursorItem`, moved there from the vendor panel): an item dropped
    on a card or its icon, or left-clicked onto one, is sold, as on Blizzard's merchant item buttons
    (`OnReceiveDrag` runs their left click, which picks the merchant item up while holding the
    player's). Blizzard asks first about a refundable item. A right click holding an item still buys,
    as on Blizzard's buttons. The cards cover most of the panel: without this a drop on one did
    nothing.
  - The name's and price's layout (justification, line limit) is set again after every font object
    change (affordable or not, a theme): a font string takes its layout from its font object.
  - **The stack count and stock** are in the bags' item count font (asked: "the count for items in
    vendor, that font size should match our item count in bags"): the `Stack` role copies
    `NumberFontNormal` (ItemButtonTemplate's Count: Arial Narrow 14 with an outline, its own font per
    alphabet), through the new font key `Object` (next-themes.md §3).
- **Title:** the vendor's name (`UnitName("npc")`), cut to one line in the room right of the shown
  header buttons.
  - **Secret in an instance.** `UnitName` is `SecretWhenUnitNameIdentityRestricted`
    (`UnitDocumentation.lua`): in a dungeon or raid an NPC's name is a secret value. The title shows it
    (`FontString:SetText` takes secrets from addon code, `SecretArguments = "AllowedWhenTainted"`, and
    gives the font string the secret Text aspect), but its width is then secret too
    (`GetStringWidth` is `SecretWhenAnchoringSecret`, `SimpleFontStringAPIDocumentation.lua`), and
    addon code may not do arithmetic on a secret (warcraft.wiki.gg Secret Values). Reported:
    `next/panel.lua:742: attempt to perform arithmetic on a secret number value (execution tainted by
    'BetterBags')` in `CloudSpan`, from `SetTitle` in `OnShowing`, opening a vendor in an instance.
    `CloudSpan` (the cloud round the title and its sparkles) now uses `style.Cloud.SecretTitleWidth`
    (160, about a typical NPC name) while the width is secret (`issecretvalue`, on retail and WoW:
    Forever; none on Classic, where nothing is secret). Tooltips name a bag by `panel.label` (its
    title when made: "Backpack", "Bank", "Vendor"), never by reading its title back:
    `GameTooltip:SetText` and `AddLine` are not in the generated API documentation, so nothing marks
    them as taking secrets from addon code. Every other `UnitName` call in BetterBags asks for
    `"player"`, which is never secret. Of the documented APIs the vendor calls, only `UnitName` can
    return a secret; the older global merchant functions (`GetMerchantItemInfo` and the rest) are
    not in the generated documentation. The Seller (every sale, `data/seller.lua`) also asks
    `UnitGUID("npc")`, secret in the same places: it keyed tables with it, which errored (seller.md §3). The frame mock's `MockSecret` (`spec/helpers/wow_mocks.lua`)
    models secrets: arithmetic and comparisons error, a font string given one returns a secret width,
    the tooltip's `SetText`/`AddLine` reject one, and so do `SetWidth`, `SetHeight`, `SetSize` and `SetPoint`
    (`SecretArguments = "AllowedWhenUntainted"`: addon code is always tainted; added when the Glitch theme's title
    ghosts were given the title's secret width, next-themes-glitch.md §21). Coverage: `spec/next/vendor_spec.lua` ("with a
    secret vendor name (an instance)"), `spec/next/chain_spec.lua` ("names bags by their labels in
    tooltips"). Not seen in game yet.
  - **Secret anchoring, every measure of the title.** Reported by a player: `next/panel.lua:2359: attempt to
    compare a secret number value (execution tainted by 'BetterBags')` in `titleWidth`, from `SetTitle` in
    `OnShowing`. The earlier fix checked only `GetStringWidth`; while the title shows a secret its anchoring is
    secret (`IsAnchoringSecret`), so every size and position query on it is secret (`GetWidth`, `GetHeight`,
    `GetSize`, `GetLeft` and the other edges, `GetCenter`, `GetRect`, `GetScaledRect`, `GetStringHeight`,
    `GetNumLines`, `IsTruncated`, `IsMouseOver`: all `SecretWhenAnchoringSecret`), its width too, though
    `FitTitle` set it. And the secrecy "propagates downwards to dependent anchored regions" (warcraft.wiki.gg
    Secret Values, "Secret anchors"): everything anchored to the title has it, and so would a tooltip anchored to
    one of those. Now:
    - `titleWidth` reads neither measure while either is secret: it is the width `FitTitle` cut the title to
      (`panel.titleCut`, kept as it sets it; only a title cut short, the vendor's at both sizes, ever shows a
      secret), else `Cloud.SecretTitleWidth`.
    - The title's button (it owns the title's tooltip) hangs from the body by the title's own numbers, 8 past its
      text across and 6 above and below (`placeTitleRow`), no longer anchored to the title.
    - What still hangs from the title (the cloud's puffs, the braid) is only ever placed, never read.
    - The pixel check (`/bbdb`, `debug/pixelaudit.lua`) skips a region whose anchoring is secret.
    - **A small vendor's minimum** holds a title's whole width (next-small-resize.md §14g; asked of vendors: "careful with
      secret value please"): `measureTitle` keeps nil while the measure is secret (`isSecret`, before anything is done with
      it), and `MinWidth` then keeps `Small.MinTitle`, the title cut short as before. Nothing compares, adds up, concatenates
      or sizes with the secret; `FollowNames` (Fit Names While Open) reads only that nil. Its section names and counts are
      category names and button counts, never secret. Coverage: `spec/next/vendor_spec.lua` ("keeps the least room for its
      title a small vendor always kept while the name is secret, its whole name else").
    - **Its draw** sets its footer's text before it fits and lays out (`vendorProto:Draw`: the footer is part of a small
      vendor's minimum), then follows its names while Fit Names While Open is on (`FollowNames`), as the bags' draw does.
  - **What else can be secret** (checked against `Blizzard_APIDocumentationGenerated`, every function and event
    BetterBags calls or registers): the unit APIs only for a unit that is not player-controlled or in the group
    (`SecretWhenUnitIdentityRestricted`), so only `UnitName("npc")` and `UnitGUID("npc")` (the Seller, seller.md
    §3); no event BetterBags registers has a secret payload; widget queries only once a secret was given to that
    widget or something it hangs from, which only the vendor's title is. The frame mock now models secret
    anchoring (`IsAnchoringSecret`, the queries above answering secrets, down every anchor chain, lines'
    start and end points included). Coverage: `spec/next/vendor_spec.lua` ("with a secret vendor name": the
    title cut short and its glow, the button and its tooltip off the title's anchoring, either measure secret,
    every shipped theme at both sizes hovered with its cloud and sparkles; a long name laid out to its cut),
    `spec/next/chain_spec.lua` ("takes clicks over the title"), `spec/debug/pixelaudit_spec.lua` ("skips a region
    whose anchoring is secret"). Nine mutations, each caught. Not seen in game.
- **Header buttons** (from the screen edge): close; settings; the filter (retail and Forever, unless
  `Enum.GameRule.MerchantFilterDisabled`: Blizzard's own radio list, each spec, the class, Bind on
  Equip, everything, through `MenuUtil.CreateContextMenu`, `SetMerchantFilter`); Sell Junk; Repair
  All; the guild's repair (only where `CanGuildBankRepair()`). Repair buttons only at a vendor that
  repairs (`CanMerchantRepair()`), disabled with nothing to repair; Sell Junk disabled with no junk
  (`SetHeaderButtonEnabled`: a disabled glyph fades). Icons: the theme's glyphs, the same on every
  client (next-themes.md §11). Hidden buttons leave no gap
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
  sell everything in that section"): the vendor is a `NextDrag` seller (`RegisterSeller`, next-drag.md §7), never
  a source. While it is shown, a backpack section dragged over its body or its tabs lights it and
  names the sale ("Sell 7 items", "Nothing in it sells"). `SaleOf` is what sells: every item and
  every pile its virtual stack hides (`sectionFrame:WithStacks`, shared with Move Categories), in
  the backpack's bags, each slot once, leaving out what the vendor does not buy (`hasNoValue`) and
  refundable purchases (`C_Item.CanBeRefunded`: Blizzard asks before refunding one, and
  `UseContainerItem` would refund it without asking), and what this merchant refused (seller.md §3:
  it stays in the bags until a merchant buys it). A section with something to sell docks in the vendor
  (next-drag.md §7, "Docked sections") with the vendor's `SaleOffer` (`SectionOffer`, the offer a category Auto Sell
  offers uses too, automation.md §4a): when buyback can keep all of it (12, Blizzard's
  `BUYBACK_ITEMS_PER_PAGE`) it sells as it docks; past that it waits for a double click ("Sell 13
  items?", "Only the last 12 items sold can be bought back.", "Double-click to sell · Right-click to
  cancel"). The Seller (seller.md) sells it one item at a time while the card says how far it is
  ("Selling N of M..."); then the section flies into the vendor, or goes back to its place with what
  the sale left in the bags: what the merchant did not take, and what `SaleOf` left out, a pile its
  stacks hide included (automation.md §4a, #1257). It lands back in its place at once when nothing sells. Until this change a
  sale of up to 12 sold everything at once and flew straight into the vendor, which hit "That object
  is busy." and could hide unsold items (reported). Selling needs a mouse click, as moves do: the drop's
  release, or the double click; a drag ended without a release sells nothing. Unlike a right click on the
  header (Move Categories), it does not need Enable Category Sell and Deposit and is not cut to 10
  items: the drag is the deliberate act, and the confirmation covers what buyback cannot.
- **Categories waiting at a merchant** (automation.md §4a): a backpack category whose sale Auto Sell
  confirms, or that holds items no merchant buys to destroy, docks in the vendor once the backpack and
  the vendor show (`OfferAutomation`), in the same dock a dragged section's sale waits in (next-drag.md §7), red while
  destroying. The vendor keeps no room of its own for it: its `ContentBottom` is the panel's.
- **The Shopping List** (profession-shopping-list.md): with Profession Shopping List loaded, what its list
  buys here is a section at the top of Buy (out of its items' categories), docked once a visit in the
  same dock (in its card from the vendor's first layout, laid out at the vendor's column width) glowing
  in `Dock.BuyColor`, bought with a double click (it
  flies into the backpack). The merchant closing sends back only other panels' sections
  (`NextDock:SendBackBorrowed`); the Shopping List leaves with the vendor in its card.
- **Masque:** each button is a card the canvas places (`frame`, the icon with its name and price)
  holding the square button that takes the clicks (`button`), so Masque, which sizes a skin to the
  button it skins (Masque 12.1.0 `Core.lua` `UpdateScale`), skins the icon alone. The button carries
  Masque's names for an item button's parts (`icon`, `IconBorder`, `Count`; `Skins/Regions.lua`),
  and `MasqueRegions` lists them with the highlight. A new button is announced once
  (`vendor/NewButton`); the Masque integration adds it to its own `BetterBags/Vendor` group as an
  `Item` button, takes it out under a theme with `Masque = false`, and adds it back when a theme
  that uses Masque applies (vendor buttons are reused, not drawn again on a theme change). A draw
  needs no re-skin: it sets the icon's file (Masque keeps its crop) and the border's color, and
  Masque re-skins the border itself when its texture is set (its `IconBorder` hook). Styling itself
  again for a new pixel grid does (`Fit` redraws the icon, count and highlight): it sends
  `vendor/Updated`, and the integration re-skins it (next-pixel-perfect.md §4).
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
  category beating a search one with a lower or equal number (at a tie an item placed by hand stays,
  category-lifecycle.md §6), a grouped one
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
bought at once otherwise, at most what `NextMerchant:MaxPurchasable` allows. BetterBags asks the number
in its own dialog, as Blizzard asks it with its stack split frame (not a confirmation).

**The quantity dialog** (issue #1281: "a 'max' button to pre-fill what you can afford", "the text entry is not
pre-filled and not well usable", "+- buttons"; the player's BuyEmAll hooks Blizzard's merchant buttons, which never
show with the vendor on). `NextVendorButton:askQuantity` shows `NextDialog` over the vendor's panel (questions are
`NextDialog`, CLAUDE.md; it was the classic `Question` window), its field a quantity (next-controls.md §2): digits
only, focused with its text chosen; `-` and `+` and Max on its row; Cancel and Buy (Primary, so Enter buys) below.
Decided with the user:
- **Starts at one purchase's worth** (`item.stackCount`, the vendor's bundle, where Blizzard's stack split starts:
  `StackSplitMixin:OpenStackSplitFrame`, `split = minSplit`), or what can be bought when that is less.
- **`-` and `+` move a purchase's worth** (`step = stackCount`) to the multiple below or above, between 1 and what
  can be bought; Up and Down in the field too. The least stays 1, as before: a typed amount under a bundle buys that
  many (`BuyMerchantItem` buys the quantity asked since 4.1, warcraft.wiki.gg).
- **Max fills in `MaxPurchasable`**, asked again at each click (the money changes while it shows: a bag item sold).
  For every item, gold-priced ones too (the player suggested currency-priced items only; the user chose all).
- **`MaxPurchasable` counts currencies held**, which Blizzard's own limit leaves out
  (`MerchantItemButton_OnModifiedClick` counts only `itemLink and not currencyName`): a currency cost names its currency
  (`GetMerchantItemCostItem`'s `currencyName`, no link for a currency, warcraft.wiki.gg), found by name among the
  merchant's currencies (`C_MerchantFrame.GetMerchantCurrencies`, retail 12.0.7 and WoW: Forever 1.60.1) with
  `C_CurrencyInfo.GetCurrencyInfo(id).quantity`. Classic lists no merchant's currencies, so a currency limits
  nothing there, as in Blizzard's. The currency line counts in whole numbers (`have * stackCount / value`:
  `have / (value / stackCount)` is a hair under 15 for 33 / 2.2); the money and item lines are Blizzard's formula as
  before, which can come out one short at an exact multiple when a purchase gives more than one (reported to the user,
  not changed: it predates this).
- **Nothing is asked when nothing can be bought** (`MaxPurchasable` under 1: Blizzard's stack split hides for that),
  nor while `NextDialog` shows over another window (the settings window's: the vendor's would replace it unanswered,
  and its Cancel is what puts a "Hide" switch back, next-settings-categories.md).
- **Buy** buys what the field holds (the dialog keeps it between 1 and what can be bought now), stays open while it
  holds no number, and buys nothing for 0 (what can be bought fell to none while it showed).

Left as is, and why: the text's "(up to N)" is what could be bought when it opened, while Max and `+` ask again (it
changes only with a sale from the bags while it shows); the dialog's level is worked out as it shows, so a card docked
while the vendor is lowered under a chain's anchor during its slide-in could take clicks over it (seen only with the
mocks, needing a Shift-click in that fraction of a second: not built for); Escape with the field unfocused (clicked
away from) still closes the vendor with the dialog, as Blizzard closes the merchant frame as a left panel in
`CloseAllWindows` (with the field focused, as it opens, the field takes Escape and the dialog alone closes). Papercraft's
frame reaches 26 px past a dialog as narrow as the narrowest vendor.

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
  poor items worth something (`UpdateJunkItem`'s rule) through the Seller (seller.md), one at a time
  while the vendor is open, as every sale.

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
repair costs. Nor the quantity dialog (§10d): its look beside the vendor in each theme, whether clicking `-`, `+` or
Max takes the field's focus (then typed keys would go to the game), and Max for a currency-priced item (that the
cost's `currencyName` matches `C_CurrencyInfo.GetCurrencyInfo`'s `name` for an ID the merchant lists).

### 10f. Coverage

`spec/next/merchant_spec.lua` (items on retail and Classic, costs, currencies, cold data, records;
the backpack's categories, search categories by priority and against custom ones, grouped names,
section order; its own index, negated queries, forgetting the last vendor; buyback order; repair
lists, costs, one item and all; every purchase path and quantity limit; junk on both clients,
selling while open), `spec/next/vendorbutton_spec.lua` (look, counts, stock, quality, tints, heirlooms
and reuse, prices, unaffordable, search dimming; tooltips and cursors; clicks: buy, Blizzard's
modified clicks, quantities, buyback, repair; durability; "its costs": an area over each, after the gold, cut at
the price's width, none for one cut off, laid out again when styled, the cost's own tooltip and the card's cursor,
hover only, none over gold, a buyback, a repair or a released card, a Shopping List's; 11 mutations, all caught, then
the bug review's 16, two surviving: the price's width set to none before measuring, which no faithful mock can see, §10b),
`spec/next/merchant_spec.lua` also each cost's place (`costIndex`, past one left out, carried by `PriceOf`), and
currencies held limiting `MaxPurchasable` (the scarcer of two, one the merchant does not list, none on Classic, whole
numbers); `spec/next/vendorbutton_spec.lua` also the quantity dialog (over the vendor, starting at a purchase's worth
or less, `-`/`+` by a purchase's worth, Max asked again, nothing for none, nothing over another window's dialog,
Buy staying open with no number); the dialog itself in `spec/next/controls/panel_controls_spec.lua` (next-controls.md §2),
`spec/next/settings/window_spec.lua` (settings closing leaves the vendor's dialog open),
`spec/next/vendor_spec.lua` (the panel,
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
