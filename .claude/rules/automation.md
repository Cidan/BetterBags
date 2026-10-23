# Category Automation (`data/automation.lua`, the Automation tab)

A category can act on its items on its own, set with two switches in its Automation tab on the
Categories page: **Auto Sell**, and **Destroy What Can't Be Sold**, which needs Auto Sell on. Asked (2026-10-22), after deciding against
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

## 3. Selling (`OnMerchantShow`, `StartSale`, `SaleSlots`, `FinishSale`)

- On `MERCHANT_SHOW` (registered in `OnEnable`; the module is enabled from `addon:OnEnable`), in both
  designs: BetterBags Next's merchant panel keeps Blizzard's merchant frame shown (next/vendor.lua), so a
  sale at it is a sale.
- **Nothing** while Shift is held as the merchant opens (Vendor's convention), at a merchant that does
  not buy (retail: `C_MerchantFrame.IsSellAllJunkEnabled`, the check Blizzard shows its Sell All Junk
  button by and Vendor reads; undocumented beyond that, and a wrong "no" only sells nothing; Classic:
  `GetMerchantNumItems() > 0`), or with nothing to sell.
- **Through the vendor's own sale, in rounds** (`NextMerchant:SellRounds`, shared with BetterBags
  Next's Classic Sell Junk). Reported: "our yolo sell only sells 10 items, then stops ... look at our
  autosell code we have already and see how it manages to autosell (or auto deposit in the case of
  bank) unlimited items". Every path that moves many items at once calls `C_Container.UseContainerItem`
  for all of them in one go (`NextMerchant:SellSlots` for a section dropped on the vendor,
  `GuildBank:DepositSlots`, `SectionFrame:MoveItems` to the bank), and what may not all go through is
  read again and sold again a moment later (the vendor's Classic Sell Junk; GW2_UI's auto sell, which
  keeps going until a round finds nothing). The first version had its own loop instead: `WAVE` (12)
  items a frame, `WAVE_DELAY` apart, walking the list taken when the merchant opened exactly once, so
  an item the merchant did not take was never tried again. Now, from the frame after the merchant
  opens (`C_Timer.After(0)`), each round sells at once every item still there (`SaleSlots`: the slot
  read again, `StillThere`: the same item GUID, never an empty one, unlocked, still bought, not
  refundable now), then `SELL_DELAY` (0.2 s) later the next round reads again what is left: an item
  still selling is locked and skipped, one the merchant did not take is sold again. It ends on a round
  that finds nothing left, when the merchant closes, or after `SELL_ROUNDS` (50, about 10 s) rounds of
  a merchant that keeps refusing. **Not measured:** why the old loop stopped at 10 (no capture of a sale
  yet). A profiler capture of a sale now shows each round in the call trace (`Automation.SaleSlots`
  returns the slots it sells, `Automation.FinishSale` why it ended).
- **Waits** (a round at a time, not counted) while the cursor holds an item, as Vendor does; selling with something on
  the cursor could sell or swap the wrong item. Blizzard's own question about an item still tradeable
  with your group (`CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL`) puts the item on the cursor until answered,
  so the sale waits for the player's answer; BetterBags never answers it (Vendor does).
- **Ends** as above, and sells nothing more once the merchant closed (between rounds too); reopening the
  merchant ends a waiting sale first. It prints, once at the end, what it sold and for how much
  (`C_CurrencyInfo.GetCoinTextureString`): the items it sold that are no longer in their slot or are
  still selling (locked); what the merchant did not take is left out (the first version counted every
  item it tried).

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
- **Where a player destroys:** at a merchant in BetterBags Next, the **destroy card** at the bottom of
  the vendor (asked: "move the item to the vendor screen, but towards the bottom of it ... with a more
  crimson outline, and a click to [destroy] next helper text (one click only)"; then: style it like the
  category drag sell box, "including the subtle color blink"; next.md §10b): the dock card a dragged
  section waits in (`NextDockCard`), its edge and halo in `Dock.DestroyColor` (Default's `Crimson`),
  titled "Destroy N items", "No merchant buys these.", the icons, "Click to destroy next"; one left
  click destroys the next item. Anywhere, the **Destroy Next Item** key binding (Bindings.xml,
  `BetterBags_DestroyNextItem`, Key Bindings > BetterBags). The classic design's merchant (Blizzard's
  frame) shows no card.
- **`automation/Changed`** (no arguments): sent after a destroy, so whatever shows the queue updates
  (the vendor's card). A sale changes nothing the queue holds.

## 5. The Automation tab (`next/settings/content.lua`, `NextSettingsCategories:AutomationOptions`)

Fourth tab of the Categories page (next-settings.md §5), shown while a category is chosen, a plugin's
too (what it does is the player's choice). It is drawn as every page draws its settings: a section
("Merchants") of settings rows (`next/settings/rows.lua`), two switches side by side, each its name on
the left and its switch on the right, with its description as its tooltip. Asked: switches, not a
dropdown; no explanations on the tab, no list of the items it acts on, no Destroy Next Item button; then
Auto Sell, and Destroy What Can't Be Sold, which needs Auto Sell on; then, after a first version
hand-placed bare switches ("bland ... unstyled ... compare to the other screenshot"): like the other
pages. The options are page options (`NextSettingsOption`), from `AutomationOptions()`:
- **Auto Sell**: on saves `"sell"`, off saves none (`false`), taking Destroy What Can't Be Sold with it.
- **Destroy What Can't Be Sold**: disabled while Auto Sell is off (the row's `disabled`); on saves
  `"destroy"`, off `"sell"`.
- Each saves at once (`UpdateCategory { automation }`) and then `NextSettings:Refresh`, so the other
  row's state follows; `categories/Changed` also shows the page again.
The category's list line ends "Sells at merchants" or "Sells, destroys the rest".

## 6. Coverage

- `spec/automation_spec.lua`: which items (order, the backpack's bags, Recent Items ignored, every reason
  to leave one alone, what sell and destroy categories sell and destroy); selling (the events, all at
  once the frame after the merchant opens, the summary and its money, 30 items in one round, a merchant
  taking 10 a round with the rest sold the next, an item still selling counted once, the rounds' bound
  with only what sold counted, the merchant closing between rounds, Shift, a merchant that does not buy
  on retail and Classic, the merchant closing first, waiting for the cursor between rounds, items that
  moved, locked or became refundable, a reopened merchant, items without a GUID); the destroy queue (still in its slot, what a sale holds, what it left unsold,
  what it sold while the bags catch up, a new merchant, `automation/Changed`); destroying (the next
  item, the cursor, combat, nothing left, an item that moved, one not picked up, the key binding).
- `spec/next/merchant_spec.lua` ("in rounds": all at once then again what is left, the bound, the
  merchant closing, waiting without counting a round); `spec/next/vendor_spec.lua` (Classic Sell Junk
  handing its three rounds to them); `spec/next/vendor_spec.lua` ("the destroy card": the items, the line, the crimson edge and its place;
  the scroll area's room and the root's height; nothing to destroy; one click, then what is left, then
  gone; the tooltip and its next item; following the queue on each message, fading in; the minimum
  height; laying out again only when it appears or goes; as many as fit and "+N"; the merchant closing
  and BetterBags Next switched off; a theme applied).
- `spec/categories_spec.lua` (saving without recalculating, a plugin's kept across creation,
  `AutomationOf` and sub-categories), `spec/database_spec.lua` (a plugin's saved state),
  `spec/items_spec.lua` (`GetCategory` ignoring Recent Items), `spec/database_migration_spec.lua` (the
  limit's saved value dropped), `spec/next/settings/content_spec.lua` (four tabs),
  `spec/next/settings/categories_spec.lua` ("the Automation tab's settings": names, descriptions and
  keywords, Destroy only with Auto Sell, saving and the page's rows shown again, Auto Sell off taking
  Destroy with it, a plugin's, nothing chosen; the list line, which tabs show),
  `spec/next/settings/content_spec.lua` (the tab is a section of two settings rows), `spec/next/dockcard_spec.lua` (the shared card), `spec/next/drag_spec.lua`
  (the dock on it, unchanged), `spec/core/init_spec.lua` (initialized and
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
  stops at its first round).

**Not verified in game:** a sale at a real merchant (retail, Classic, WoW: Forever), selling every item
in one round against the server, the trade-timer question during a sale, `IsSellAllJunkEnabled` at a
repair-only merchant, whether a sold slot reads locked at once, and destroying from the card and the key
binding. To check: make a category `rarity = poor` with Auto Sell on, open a merchant (once holding
Shift), and a category with Destroy What Can't Be Sold on holding an item merchants do not buy; open a
merchant with BetterBags Next and click the card. `/console taintLog 1` should log nothing for BetterBags.
