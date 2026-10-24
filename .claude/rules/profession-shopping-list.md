# Profession Shopping List at the BetterBags Next Vendor

Profession Shopping List (PSL, Slackluster's addon, github.com/Slackluster/ProfessionShoppingList)
tracks recipes and the reagents they need. With it loaded, a BetterBags Next vendor that sells
something on the list shows those items in a **Shopping List** section at the top of Buy, and docks
that section in a card to buy it all with a double click. Asked: "if a vendor has items the user has on
their list, just like we have the sell or destroy, let's add a 'double click to buy' in the same exact
style, but, with a glowing green outline instead", "with the items in it to buy, and total price to
buy", and "if PSL (and this function, because it's new) isn't available, don't show this
integration/don't try to call this".

## 1. What PSL provides

Read from PSL's `main` (`API.lua`, `modules-old/Merchant.lua`, `modules-old/TrackingWindow.lua`):

- `ProfessionShoppingList:BuyFromMerchant()` (PSL `a550419`, 2026-10-24): for each reagent the list
  needs, the open merchant's first item of that ID (`GetMerchantItemID`), bought when
  `C_MerchantFrame.GetItemInfo(index).isPurchasable` and at least one is missing, in stacks of
  `GetMerchantItemMaxStack` (`BuyMerchantItem(index, n)`). It calls `app:ShowWindow()`, which opens PSL's
  tracking window. It runs only while `app.Flag.MerchantOpen` (`ad84d0f`: it checked
  `MerchantFrame:IsVisible()` before, false under BetterBags Next, which keeps Blizzard's merchant frame
  shown under a hidden parent, next.md §10a).
- `ProfessionShoppingList:GetShoppingList()` **does not exist upstream yet.** PSL had no API to read the
  list: the reagent quantities live in its private `app.ReagentQuantities`, rebuilt by
  `app:UpdateRecipes()`. It was written locally, in the PSL checkout at `~/git/ProfessionShoppingList`,
  branch `betterbags-shopping-list` (`e516d9b`, not pushed), for PSL's author to adopt or rename:
  - Returns `itemID = { required = number, owned = number }` for every reagent the tracked recipes
    need (numeric item IDs only: no gold, no currencies); `required - owned` is what is missing.
  - Computed as the tracking window computes it, without showing the window: the quantity loop moved
    out of `UpdateRecipes` into `app:UpdateReagentQuantities()`, unchanged; `owned` is
    `app:GetReagentCount` (its quality tiers and settings).
  - `BuyFromMerchant` now buys from `GetShoppingList()`, so what BetterBags shows is what it buys.
- `EventRegistry` `ProfessionShoppingList.OnTrackedRecipesChanged`: tracked recipes changed.

The local install (retail, `_retail_/Interface/AddOns/ProfessionShoppingList`) is a symlink to that
checkout; the packaged v12.1.5-01 it replaced is in `_retail_/Interface/AddOns-backup/`.

## 2. The integration (`integrations/professionshoppinglist.lua`, module `ProfessionShoppingList`)

- **There only with both functions.** `Available()` is true while the global `ProfessionShoppingList`
  has `GetShoppingList` and `BuyFromMerchant`. Without them `Needs()` is empty, `Buy()` calls nothing
  (returns false) and nothing of the integration shows.
- `Needs()`: item ID -> how many are missing (`required - owned`), only for at least one.
- `Buy()`: `ProfessionShoppingList:BuyFromMerchant()` (colon calls: PSL asserts `self == api`).
- `Watch()` (from `OnEnable`, or on `ADDON_LOADED` when PSL loads later, as the Pawn integration
  retries): registers the `OnTrackedRecipesChanged` callback once (owner: the module) and sends
  `shoppingList/Changed`; on a late load it also sends `shoppingList/Changed` once. Prints
  "Profession Shopping List integration enabled." once, as the other integrations do.
- Listed after `integrations\pawn.lua` in all five TOCs (it loads after `next/vendor.lua`, which looks
  it up when drawing); enabled from `addon:OnEnable` (`core/init.lua`, initialization.md).

## 3. What the vendor buys (`next/merchant.lua`)

- `NextMerchant:ToBuy(list, needs)`: for each needed ID, the merchant's first item of it, left out when
  that one cannot be bought (as `BuyFromMerchant`: its first item decides), with how many; in the
  merchant's order (`NextVendorPurchase`: `item`, `quantity`).
- `NextMerchant:PriceOf(item, quantity)`: as Blizzard prices a quantity (`MerchantFrame.lua`
  `MerchantItemButton_OnModifiedClick`: price / stackCount per unit; `MerchantFrame_ConfirmExtendedItemCost`:
  "cost per stack times number of stacks"); fractions round up, so it never says less than it costs.
- `NextMerchant:TotalOf(purchases)`: the prices added up, each thing paid (an item link, a currency, or
  else a texture) once.

## 4. The vendor (`next/vendor.lua`)

- **The section.** On Buy, what `ToBuy` returns is the **Shopping List** section, first, out of its
  items' categories (an item is in one place, as Recent Items takes an item out of its category; duplicate
  buttons were tried and dropped, asked: "it's fine to not have duplicates"). Each button
  (`NextVendorButton:SetBuy(item, quantity)`) shows how many the list buys as its count and what they
  cost as its price; its tooltip adds "Your shopping list needs N". Its clicks are a vendor button's (a
  right click buys one purchase). No section without PSL or with nothing to buy here. Shown in the
  column, it reads as one more category of the shop (after a right click, or what a purchase left; asked
  to keep: "that's SLICK").
- **The card** (`OfferShoppingList`, `ShoppingListOffer`): the section docks in the vendor's own dock
  (`NextDock`, next.md §7, the dock sales and destroys wait in; source: the vendor) once a visit
  (`listOffered`, cleared on `MERCHANT_SHOW`), from the draw that first binds it, **between binding and
  the layout**: a section never placed has no place on screen (`NextLift:ScreenPoint` is nil), so the
  dock seats it in its card at once, and the vendor opens with the card already there. **Failure mode
  (fixed, reported):** docked once the vendor had slid in (`next/PanelShown`, as sales are), the section
  showed in the vendor's list "for a split second then slides to the buy frame". Never as the vendor
  closes. Its card lays it out as the vendor's column would (the dock, §5): a column never lays out a
  section held out of it. It reads "Buy N items?" (N: the different items),
  "Total: <price>" (`TotalOf`, written as the vendor's prices, `NextVendorButton:PriceText`), "Double-click
  to buy · Right-click to cancel", and glows in `Dock.BuyColor` (Default: `Emerald`).
  - **A double click** buys through PSL (`Buy`) and answers "moved": the section flies into the
    backpack (the offer's `destination`, its scroll area; nowhere while the backpack is closed), then
    stays out of the vendor's column while leaving (`MarkLeaving`). The bags' updates draw the vendor
    again: once the list needs nothing more here the section is gone, and its items are back in their
    categories; what was not bought (not enough money) shows again in the section after the leaving time,
    not docked again this visit. Once the vendor is closing, or the merchant has closed, it buys nothing
    and goes back.
  - **A right click** sends it back to the top of Buy, a section like the others.
  - **Other tabs:** while it waits, the section stays bound (held out of their columns), so its card
    waits on Buyback and Repair as a backpack section's card does; their empty text counts only their
    own sections.
  - It goes when the list needs nothing more from this vendor (its section leaves the data).
  - **Closing:** the merchant closing sends back at once only the sections that came from other panels
    (`NextDock:SendBackBorrowed`: the backpack's, whose bag stays open); the Shopping List stays in its
    card and slides out with the vendor, going back once it has hidden (the panel's `OnHidden`,
    `PanelHidden`), so it never shows in the column on the way out either.
- `shoppingList/Changed` draws the vendor again (a draw offers it).

## 5. The dock (`next/dock.lua`)

- `NextDockOffer.destination?: fun(): Frame?`: where a section's items went when it moves, when that is
  not the panel it waited in. "moved" flies it into that frame's middle instead of the panel's tab or
  scroll area, or nowhere (it leaves at once) when the function returns nil. Sales and deposits give none.
- **A panel's own section is laid out at its column's width** (`listProto:Lead`; `NextContent`'s lead
  callback now gets the column's layout width too). A section from another panel keeps the width its own
  column gave it and is scaled down to fit, as before. **Failure mode (fixed, reported with a
  screenshot):** docked before its first layout, the Shopping List had no width yet, and the card laid it
  out at that width: a narrow, tall, empty green strip at the top of the vendor.
- `NextDock:SendBackBorrowed(panel)`: sends back at once what waits in a panel that came from other panels,
  leaving the panel's own sections in their cards (the vendor's `OnMerchantClosed`; it used `PanelHidden`,
  which also sent the vendor's own Shopping List back into its column as it slid out).

## 6. Theme

`Dock.BuyColor` (Default's palette `Emerald`, 0.2, 0.86, 0.42), next to `DestroyColor`; every shipped
Next theme inherits it. `SonataNext:Check` now checks both as palette colors (`COLOR_KEYS`; neither was
checked before).

## 7. Coverage and limits

- `spec/integrations/professionshoppinglist_spec.lua` (a PSL stand-in from its API as written: colon
  calls asserted): absent, without either function, needs, buying, listening once and saying so once,
  a late load, nothing to wait for. `spec/next/merchant_spec.lua` ("what a shopping list buys here").
  `spec/next/vendorbutton_spec.lua` (quantity count and price, the tooltip line, reset).
  `spec/next/dock_spec.lua` (flying into the destination; nowhere without one; sending back only what
  came from other panels; a panel's own section laid out as its column lays out, rows per width, and
  again after a resize; another panel's keeping its own column's layout). `spec/next/vendor_spec.lua`
  ("the shopping list (Profession Shopping List)": nothing without PSL, the section out of the categories
  and its counts, in its card as the vendor opens and never placed in the column (`motion:Place`
  recorded), its items laid out in the card as in the column, the card's text, total and color, buying
  and flying into the backpack, nowhere with the backpack closed, nothing once closing or closed, sent
  back and once a visit, the other tabs, gone when not needed, offered straight into its card when the
  list changes, dimmed by a search, what cannot be bought, sliding out in its card, not offered as the
  vendor closes).
  `spec/sonata/next_engine_spec.lua`, `spec/sonata/next_themes_spec.lua` (the colors checked and set),
  `spec/core/init_spec.lua` (enabled).
- Mutation-tested: 45 mutations, each failing at least one test (four first survived and led to sharper
  tests: the closing guard; docking before the layout, which the frame mock cannot tell from a flight
  because it gives anchored frames no screen position; the column's layout width, which only shows when a
  narrower column wraps more rows; another panel's section keeping its own width, which only shows with
  columns of different widths). Guards no test could reach were removed
  instead (the tab check, held or leaving sections, PSL disappearing mid-visit, a missing backpack).
- **Seen in game** (the player): first, it worked but the section showed in the list before sliding into
  its card; then, docked before the layout, the card was an empty strip (both fixed above). Not seen yet:
  the card at open with its items, the close. To check: track a recipe whose reagents a vendor sells, open that vendor with Next on, double-
  click the card, check the purchases and PSL's window, right-click instead, switch tabs while it waits,
  close the vendor with the card waiting.
- **Not measured:** `GetShoppingList` recomputes PSL's quantities on every Buy draw (several per sale or
  purchase). Capture a vendor visit with the profiler (`NextVendorPanel.Draw`) before changing it.
- **Behaviors that are PSL's:** `BuyFromMerchant` opens PSL's tracking window, and buys with
  `BuyMerchantItem` directly, without Blizzard's confirmations for extended costs and non-refundable
  items (next.md §10d); BetterBags' own purchases go through them.
