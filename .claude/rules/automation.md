# Category Automation (`data/automation.lua`, the Automation tab)

A category can act on its items on its own, set with three switches in its Automation tab on the
Categories page: **Auto Sell**, **Confirm Auto Sell** (on by default) and **Destroy What Can't Be
Sold**, the last two needing Auto Sell on. Asked (2026-10-22), after deciding against
importing Vendor's rules or integrating with Vendor (docs/vendor-compat.md, decision 2): "we add
vendor-like features to a new Automation tab for categories". A category's rule is a search, which
already speaks what Vendor's rules use (search-indexing.md §10-§17), so a category plus an action is a
Vendor rule.

## 1. The setting

- **Stored on the category** as `automation = "sell"` (Auto Sell) or `"destroy"` (Auto Sell and Destroy
  What Can't Be Sold), nil for nothing (`CustomCategoryFilter.automation`). `"destroy"` always sells
  too: it is the value the first version saved for "Destroy", which already sold what merchants buy. Yours: in the saved filter, so a rename keeps it and a delete
  drops it. A plugin's: in its saved state (`ephemeralCategoryFilters[name].automation`, through
  `DB:UpdateEphemeralItemCategory`), kept when the plugin makes the category again
  (`DB:CreateOrUpdateCategory`) and winning over the plugin's own when it is (`categories:CreateCategory`),
  as its color and priority do (category-lifecycle.md §1).
- **Set** with `categories:UpdateCategory(ctx, name, { automation = "sell" | "destroy" | false })`. It
  sends `categories/Changed` and, when automation is the only field, no `bags/Rederive`: it changes no
  item's category.
- **Read** with `categories:AutomationOf(name)`: a group by's sections (`isGroupBySubcategory`) do what
  their category does; a built-in category ("Armor", "Junk") has none.
- **Confirm Auto Sell** (asked: "another toggle that defaults to on: 'Confirm autosell' which makes the
  sell box for the category appear at the vendor (double click to sell, etc) -- exact same box, instead
  of just yolo selling. turning this off does yolo sell"): stored as `confirmSale = false` only when
  turned off (on, the default, is no field), set with `UpdateCategory { confirmSale = true | false }`
  (no `bags/Rederive` either), a plugin's in its saved state as its automation is (one `saveState`
  helper writes both, from `UpdateCategory` and `setPriority`), read with `categories:ConfirmsSaleOf
  (name)` (a group by's sections as their category).
- **No limit.** A sale used to stop at 12 items (what buyback keeps), behind a setting, `autoSellLimit`.
  Asked: "just keep selling past that limit in waves, don't block there. that's pointless." The setting
  is gone, and `DB:Migrate` drops its saved value.

## 2. Which items (`Automation:Entries`)

- The **backpack's** committed items (`items.slotInfo[BACKPACK]`), in the backpack's bags
  (`const.BACKPACK_BAGS`), by bag and slot. Not the bank, the guild bank, or the merchant's items.
- Each by its category **without Recent Items** (`items:GetCategory(ctx, data, false, true)`; the new
  `ignoreRecent` argument): a newly looted item is acted on by the category it will have, as a Vendor rule
  matches by the item. Search categories count; `GetCategory` already honors each category's bags.
- **Left alone, with why** (`BlockedReason`): an item read before its data loaded (its category may be
  wrong), an item in an equipment set, a purchase that can still be refunded (`itemInfo.refundable`;
  Blizzard asks before refunding, `ContainerFrame_GetExtendedPriceString`, and selling it directly would
  skip that), and, to sell, one merchants do not buy (`hasNoValue`).
- **Decided from the bags' last read alone; the client is asked only when acting.** Everything above
  reads the committed items. The client can have changed a slot since that read: a sale empties slots,
  and BetterBags reads the bags again only after `BAG_UPDATE_DELAYED` (the loader, then the refresh
  queue, which commits frames later). Refundability is read with the slot (`items:AttachItemInfo`, and
  again on a kept item, `RefreshKeptItem`: the refund window ends without the slot changing), so the
  decision reads it from the item. Only `StillThere`, when selling or destroying, asks the client, after
  `GetContainerItemInfo` shows the slot still holds the item.
  - **Failure mode (fixed, reported in game):** `BlockedReason` asked `C_Item.CanBeRefunded` about each
    committed item's slot. BetterBags Next's vendor drew the destroy card on `PLAYER_MONEY` and
    `BAG_UPDATE_DELAYED`, which fire after the sale emptied slots and before the bags were read again,
    so it asked about empty slots: 58 errors, `bad argument #1 to '?' (Usage: local canBeRefunded =
    C_Item.CanBeRefunded(itemLocation))`, at bag 4 slot 4, from `next/vendor.lua` Draw in that handler.
    `CanBeRefunded` takes an `ItemLocation`, not an `EmptiableItemLocation` (`DoesItemExist`'s,
    ItemDocumentation.lua), and Blizzard checks `itemLocation:IsValid()` before calling it
    (`BankUtil_IsAccountBankDepositRefundable`). The spec mocks now raise the same error for an empty
    location, and `C_Item.DoesItemExist` sees an item wherever `GetContainerItemID` reports one.
- **What is sold** (`SellList`): what either action holds (both sell), not left alone, that merchants
  buy. **What is destroyed** (`DestroyQueue`, §4): what Destroy What Can't Be Sold categories hold, not
  left alone, that no merchant buys (`hasNoValue`). The two never share an item. (A sell-only category's
  item no merchant buys is already left alone, so `DestroyQueue`'s own check for the destroy action is
  one no mutation can catch; it is kept because it says what the queue is.)

## 3. Selling (`OnMerchantShow`, `StartSale`, `FinishSale`)

- On `MERCHANT_SHOW` (registered in `OnEnable`; the module is enabled from `addon:OnEnable`), in both
  designs: BetterBags Next's merchant panel keeps Blizzard's merchant frame shown (next/vendor.lua), so a
  sale at it is a sale.
- **Nothing** while Shift is held as the merchant opens (Vendor's convention), at a merchant that does
  not buy (retail: `C_MerchantFrame.IsSellAllJunkEnabled`, the check Blizzard shows its Sell All Junk
  button by and Vendor reads; undocumented beyond that, and a wrong "no" only sells nothing; Classic:
  `GetMerchantNumItems() > 0`), or with nothing to sell.
- **Only the categories that do not confirm** (Confirm Auto Sell off) sell on their own when the
  merchant opens. A category that confirms waits for the player: in BetterBags Next its section is docked
  in the vendor (§4), the same box a dragged section's sale waits in; the classic design has no such box,
  so it is left to the player's usual Move Categories right click on its title (never a dialog of its
  own: one interface for one action, CLAUDE.md "UI Consistency" 5).
- **Through the Seller** (seller.md): one item at a time, the next one an interval later (the larger
  of the home and world latency, at least 0.2 s; Dejunk's pace, asked: "dejunk's works fine"), from the
  frame after the merchant opens (`C_Timer.After(0)`), each still there when its turn comes
  (`Seller:StillThere`, which `Automation:StillThere` also is). Reported first: "our yolo sell only
  sells 10 items, then stops"; the first version sold a wave of 12 a frame, then every item still there
  in rounds 0.2 s apart (GW2_UI's way); both handed the client many items at once, and it answered "That
  object is busy." (reported: "autosell (double click or otherwise) will hit 'That object is busy'").
  Items this merchant refused are left out (`SellList`, `Seller:Refuses`): they stay in the bags until a
  merchant buys them. A merchant that refused to buy anything (`Seller:BuysNothing`) does not buy
  (`MerchantBuys`).
- **Ends** when the Seller's sale ends: everything sold, the merchant closed (and sells nothing more),
  or the merchant buys nothing; reopening the merchant ends the sale first (it is cancelled). It prints,
  once at the end, what the merchant took and for how much (`C_CurrencyInfo.GetCoinTextureString`, each
  stack's count when sent); the Seller says what the merchant would not buy.

## 4. Destroying (`DestroyQueue`, `DestroyNext`; the vendor's destroy card and the key binding)

- `DeleteCursorItem` has restrictions (`HasRestrictions`, GameCursorDocumentation.lua): an addon can
  only destroy on a key press or a click, one item each (Vendor's destroy.lua: "Blizzard Protected
  DeleteCursorItem() in 9.0.2").
- **The destroy queue** (`DestroyQueue`): what Destroy What Can't Be Sold categories hold that no
  merchant buys, as the bags were last read, by bag and slot. It never holds an item a sale would sell,
  so nothing a merchant buys is ever destroyed, at a merchant or away from one. (The first version
  destroyed anything a destroy category held, selling first what a merchant bought, and kept a sale's
  items out of the queue by GUID while it ran; that is gone with the overlap.)
- **`DestroyNext`** destroys the first item of the queue still in its slot (`StillThere`), the whole
  stack: `PickupContainerItem`, then `DeleteCursorItem` only if the item is on the cursor, and prints
  what it destroyed. It refuses in combat and while the cursor holds an item (it would delete the wrong
  one). An item destroyed shows on the card until the bags are read again; a second click skips it.
- **Where a player destroys:** at a merchant in BetterBags Next, in the vendor's dock (below); anywhere,
  the **Destroy Next Item** key binding (Bindings.xml, `BetterBags_DestroyNextItem`, Key Bindings >
  BetterBags). The classic design's merchant (Blizzard's frame) has no dock.

### 4a. At a BetterBags Next vendor: categories docked in it (`NextVendor:OfferAutomation`)

Asked: "a list of categories that move over to the vendor window (scroll the vendor window if needed) to
double click to sell, and selling (or cancelling) animates the next section to the position above it
(can autosell a section in the middle, for example)"; "our destroy section should function just like
the above, but with a red outline like we have now, when it's destroying. as far as placement, let's
stop treating it specially." The destroy card at the bottom of the vendor (its own icon row, its own
room under the scroll area) is gone: a category's items wait in the vendor's dock (`NextDock`, next.md
§7) exactly as a section dragged onto the vendor waits there.

- **What is offered**, while a merchant is open and the vendor and the backpack both show, on
  `next/PanelShown` (either one finished sliding in), `bags/Draw/Backpack/Done`, `automation/Changed` and
  `categories/Changed`: each category section of the backpack's view, in its order, not docked already
  (a dragged one, or waiting) nor leaving, whose items (`NextDrag:SectionItems`) hold something
  `Automation:SaleOffer` sells once confirmed (Confirm Auto Sell on, `StillThere`) or
  `Automation:DestroyLeft` destroys (the destroy queue's items still there). **Each once a visit**
  (`offered`, cleared on `MERCHANT_SHOW`): one sent back stays back until the next merchant.
- **What is not offered:** a category with no section in the backpack's view (on another tab, in the
  Show Bags view) and items of it shown under Recent Items. The box holds the section (asked, option 1 of
  two: the literal box, not a second interface drawing the items); a confirming category with no section
  there is not sold. Auto Sell with Confirm off sells them anyway (it reads categories without Recent
  Items, §2).
- **Its card** (`AutomationOffer`), read from the section's items each time it is laid out: a sale,
  "Sell N items?", "You can buy them back." (or, past what buyback keeps, "Only the last 12 items sold
  can be bought back."), "Double-click to sell · Right-click to cancel", in the dock's own glow; a destroy,
  "Destroy N items", "No merchant buys these.", "Click to destroy next · Right-click to cancel", its
  glow in `Dock.DestroyColor` (Default's `Crimson`), and as its tooltip the next item a click destroys
  ("Click to destroy it.").
- **A double click on a sale** sells what it offers then through the Seller (seller.md), one item at a
  time, as a dragged section's sale is (both are `NextVendor:SectionOffer`). The card waits while it
  sells: "Selling N of M...", "One item at a time, as the merchant takes them.", "Right-click to stop"
  (a right click cancels what is left and sends the section back). Once the sale ends: if the section
  holds items no merchant buys, the card stays and turns into their destroy, red; else, with anything
  the merchant did not take (refused, never sent), it goes back to the backpack, where those items stay
  until a merchant buys them (asked); else it flies into the vendor. A double click that found nothing to
  sell sends it back.
- **No sale where the merchant buys nothing** (`Automation:MerchantBuys`: a repair-only merchant, or one
  that refused to buy anything): only destroys are offered there.
- **A click on a destroy** destroys the next item (`DestroyNext` with the section's items), one each
  click. A double click destroys one too: `OnDoubleClick` blocks the second click's `OnClick`
  (warcraft.wiki.gg `UIHANDLER_OnDoubleClick`: "Continuous button-mashing alternates between OnClick and
  OnDoubleClick"), so without it every other click would do nothing. Once nothing is left, the section
  flies into the vendor. A single click on a sale does nothing.
- **A right click** sends the section back to its place in the backpack. The merchant closing (or Next
  switched off) sends every one back at once.
- **`automation/Changed`** (no arguments): sent after a destroy, and the vendor offers again then. A
  sale changes nothing the queue holds.

## 5. The Automation tab (`next/settings/content.lua`, `NextSettingsCategories:AutomationOptions`)

Fourth tab of the Categories page (next-settings.md §5), shown while a category is chosen, a plugin's
too (what it does is the player's choice). It is drawn as every page draws its settings: a section
("Merchants") of settings rows (`next/settings/rows.lua`), three switches, each its name on
the left and its switch on the right, with its description as its tooltip. Asked: switches, not a
dropdown; no explanations on the tab, no list of the items it acts on, no Destroy Next Item button; then
Auto Sell, and Destroy What Can't Be Sold, which needs Auto Sell on; then, after a first version
hand-placed bare switches ("bland ... unstyled ... compare to the other screenshot"): like the other
pages. The options are page options (`NextSettingsOption`), from `AutomationOptions()`:
- **Auto Sell**: on saves `"sell"`, off saves none (`false`), taking Destroy What Can't Be Sold with it.
- **Confirm Auto Sell**: on by default, disabled while Auto Sell is off; saves `confirmSale` (§1).
- A second section, **Recent Items**, holds **Skip Recent Items** (`RecentOptions()`; asked: "under
  automation for categories (not under 'merchant' though)", independent of the merchant switches, for
  any category): recent-items.md §4.
- **Destroy What Can't Be Sold**: disabled while Auto Sell is off (the row's `disabled`); on saves
  `"destroy"`, off `"sell"`.
- Each saves at once (`UpdateCategory { automation }` or `{ confirmSale }`) and then
  `NextSettings:Refresh`, so the other rows' state follows; `categories/Changed` also shows the page
  again.
The category's heading line ends "Sells at merchants" or "Sells, destroys the rest".

## 6. Coverage

- `spec/automation_spec.lua`: which items (order, the backpack's bags, Recent Items ignored, every reason
  to leave one alone, what sell and destroy categories sell and destroy); selling through the real
  Seller (the events, one item a beat from the frame after the merchant opens, the summary and its
  money, 30 items, a refusal left out of what sold and of the next sale here, a merchant that buys
  nothing, the merchant closing mid-sale, Shift, a merchant that does not buy on retail and Classic, the
  merchant closing first, waiting for the cursor, items that moved, locked or became refundable, a
  reopened merchant mid-sale and before it, items without a GUID); the destroy queue (still in its slot, what a sale holds, what it left unsold,
  what it sold while the bags catch up, a new merchant, `automation/Changed`); destroying (the next
  item, the cursor, combat, nothing left, an item that moved, one not picked up, the key binding).
- `spec/seller_spec.lua` (seller.md §4); `spec/next/vendor_spec.lua` (Classic Sell Junk through the
  Seller; a dragged section's offer: selling as it docks and its progress, flying in or going back with
  what was not taken, past 12 only once double-clicked, nothing to sell or closing, stopping its sale,
  only while open; refused items left out of `SaleOf`); `spec/next/vendor_spec.lua` ("offering categories at a merchant":
  docked once both show, in the backpack's order; a sale's text and glow, the buyback warning; a destroy's
  text and red glow; a double click selling through the Seller, waiting while it sells, the next coming up
  once sold; back to the backpack with what was not taken; no sale where nothing is bought; a sale turning
  into a destroy; one item per click, double clicks included, gone when none is left; nothing on a
  single click of a sale; the tooltip and the next item; once a visit, every one back when the merchant
  closes, offered again next visit; offered later when automation changes; nothing away from a merchant,
  with the backpack hidden or closing, nor twice; everything back when Next is switched off; no room kept
  under the vendor's content); `spec/next/dock_spec.lua` (the dock itself, next.md §7);
  `spec/next/bag_spec.lua` (`next/PanelShown` once a panel has slid in).
- `spec/automation_spec.lua` also: only the categories that do not confirm sell at once; the items given
  to `Entries`, `SellList`, `DestroyQueue` and `DestroyNext`; `SaleOffer` and `DestroyLeft`.
- `spec/categories_spec.lua` (saving without recalculating, a plugin's kept across creation,
  `AutomationOf` and sub-categories; Confirm Auto Sell: off kept, on dropped, a plugin's across creation
  and a move, `ConfirmsSaleOf` and sub-categories), `spec/database_spec.lua` (a plugin's saved state, its confirming too),
  `spec/items_spec.lua` (`GetCategory` ignoring Recent Items), `spec/database_migration_spec.lua` (the
  limit's saved value dropped), `spec/next/settings/content_spec.lua` (four tabs),
  `spec/next/settings/categories_spec.lua` ("the Automation tab's settings": names, descriptions and
  keywords, Confirm and Destroy only with Auto Sell, Confirm on by default, saving and the page's rows
  shown again, Auto Sell off taking Destroy with it, a plugin's, nothing chosen; which tabs show),
  `spec/next/settings/content_spec.lua` (the tab is a section of three settings rows),
  `spec/next/dockcard_spec.lua` (the shared card), `spec/next/drag_spec.lua` (a dragged sale docked), `spec/core/init_spec.lua` (initialized and
  enabled), `spec/integration/next_settings_spec.lua` (built on the whole addon).
- Mutation-tested: 72 mutations for the first version, 44 for the switches, the bulk sale and the card,
  7 for reading refundability with the slot, 32 for waves, the two switches, the shared card and
  the destroy card on it, and 7 for the tab's settings rows (all caught). Of the waves' set three
  first survived: one led to a test (a sale of exactly one wave), one was dead code, removed (a color
  the card stored and never read), and one is equivalent (the destroy action check, §2). The waves
  were later replaced by the vendor's rounds (§3): 20 mutations of the rounds, the sale on them and
  Sell Junk on them; four first survived: three led to tests (a wait not counted over two rounds, the
  merchant closing mid-round, a merchant reopened mid-sale saying each sale once) and one was a
  redundant check, removed (`StartSale` returning for a replaced sale, which the open check already
  stops at its first round). Confirm Auto Sell and the dock at the vendor: part of the 97 mutations in
  next.md §7 ("Docked sections"), every one caught after the tests and removals listed there.

**Not verified in game:** a sale at a real merchant (retail, Classic, WoW: Forever), the Seller's pace
against the server (seller.md), the trade-timer question during a sale, `IsSellAllJunkEnabled` at a
repair-only merchant, whether a sold slot reads locked at once, the docked sections flying over and
their double clicks, and destroying from the dock and the key binding. To check: make a category
`rarity = poor` with Auto Sell on, open a merchant (once holding Shift; once with Confirm Auto Sell off),
and a category with Destroy What Can't Be Sold on holding an item merchants do not buy; open a merchant
with BetterBags Next, double-click the sale, click the destroy. `/console taintLog 1` should log nothing for BetterBags.
