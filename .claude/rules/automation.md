# Category Automation (`data/automation.lua`, the Automation tab)

A category can act on its items on its own, set in its Automation tab on the Categories page:
**Nothing**, **Sell at Merchants**, or **Destroy**. Asked (2026-10-22), after deciding against
importing Vendor's rules or integrating with Vendor (docs/vendor-compat.md, decision 2): "we add
vendor-like features to a new Automation tab for categories". A category's rule is a search, which
already speaks what Vendor's rules use (search-indexing.md §10-§17), so a category plus an action is a
Vendor rule.

## 1. The setting

- **Stored on the category** as `automation = "sell" | "destroy"` (nil for nothing;
  `CustomCategoryFilter.automation`). Yours: in the saved filter, so a rename keeps it and a delete
  drops it. A plugin's: in its saved state (`ephemeralCategoryFilters[name].automation`, through
  `DB:UpdateEphemeralItemCategory`), kept when the plugin makes the category again
  (`DB:CreateOrUpdateCategory`) and winning over the plugin's own when it is (`categories:CreateCategory`),
  as its color and priority do (category-lifecycle.md §1).
- **Set** with `categories:UpdateCategory(ctx, name, { automation = "sell" | "destroy" | false })`. It
  sends `categories/Changed` and, when automation is the only field, no `bags/Rederive`: it changes no
  item's category.
- **Read** with `categories:AutomationOf(name)`: a group by's sections (`isGroupBySubcategory`) do what
  their category does; a built-in category ("Armor", "Junk") has none.
- **`autoSellLimit`** (profile, default on; General > Items, "Sell at Most 12 Items per Visit"): a sale
  stops at 12 items, what buyback keeps (Blizzard's `BUYBACK_ITEMS_PER_PAGE`, MerchantFrame.lua). Vendor's
  own limit is on by default too.

## 2. Which items (`Automation:Entries`)

- The **backpack's** committed items (`items.slotInfo[BACKPACK]`), in the backpack's bags
  (`const.BACKPACK_BAGS`), by bag and slot. Not the bank, the guild bank, or the merchant's items.
- Each by its category **without Recent Items** (`items:GetCategory(ctx, data, false, true)`; the new
  `ignoreRecent` argument): a newly looted item is acted on by the category it will have, as a Vendor rule
  matches by the item. Search categories count; `GetCategory` already honors each category's bags.
- **Left alone, with why** (`BlockedReason`): an item read before its data loaded (its category may be
  wrong), an item in an equipment set, a purchase that can still be refunded (`C_Item.CanBeRefunded`;
  Blizzard asks before refunding, `ContainerFrame_GetExtendedPriceString`, and selling it directly would
  skip that), and, to sell, one merchants do not buy (`hasNoValue`).
- **What is sold** (`SellList`): what sell and destroy categories hold, not left alone, that merchants
  buy. An item to destroy is sold instead when it can be (it is worth gold and can be bought back), as
  Vendor does. **What is destroyed** (`DestroyList`): what destroy categories hold, not left alone.

## 3. Selling (`OnMerchantShow`, `SellStep`, `FinishSale`)

- On `MERCHANT_SHOW` (registered in `OnEnable`; the module is enabled from `addon:OnEnable`), in both
  designs: BetterBags Next's merchant panel keeps Blizzard's merchant frame shown (next/vendor.lua), so a
  sale at it is a sale.
- **Nothing** while Shift is held as the merchant opens (Vendor's convention), at a merchant that does
  not buy (retail: `C_MerchantFrame.IsSellAllJunkEnabled`, the check Blizzard shows its Sell All Junk
  button by and Vendor reads; undocumented beyond that, and a wrong "no" only sells nothing; Classic:
  `GetMerchantNumItems() > 0`), or with nothing to sell.
- **One item a frame**, from the frame after the merchant opens (`C_Timer.After(0)`), with
  `C_Container.UseContainerItem`, which Blizzard documents with no restriction
  (ContainerDocumentation.lua; Vendor and BetterBags' own category sell use it). Before each sale the
  slot is read again (`StillThere`): the same item GUID (never an empty one), unlocked, still bought,
  not refundable now; anything else is skipped. The bags may have changed since they were read.
- **Waits** (0.2 s at a time) while the cursor holds an item, as Vendor does; selling with something on
  the cursor could sell or swap the wrong item. Blizzard's own question about an item still tradeable
  with your group (`CONFIRM_MERCHANT_TRADE_TIMER_REMOVAL`) puts the item on the cursor until answered,
  so the sale waits for the player's answer; BetterBags never answers it (Vendor does).
- **Ends** when the merchant closes (`MERCHANT_CLOSED`), at the limit, or when nothing is left; reopening
  the merchant ends the running sale first. It prints what it sold and for how much
  (`C_CurrencyInfo.GetCoinTextureString`), and, stopped at the limit with more left, how to sell the rest.

## 4. Destroying (`DestroyNext`, the Destroy Next Item binding and button)

- `DeleteCursorItem` has restrictions (`HasRestrictions`, GameCursorDocumentation.lua): an addon can
  only destroy on a key press or a click, one item each (Vendor's destroy.lua: "Blizzard Protected
  DeleteCursorItem() in 9.0.2"). So each press of **Destroy Next Item** (Bindings.xml,
  `BetterBags_DestroyNextItem`, Key Bindings > BetterBags) or each click of the tab's button destroys the
  next item of `DestroyList`, the whole stack: `PickupContainerItem`, then `DeleteCursorItem` only if the
  item is on the cursor. It prints what it destroyed.
- **Refuses** in combat and while the cursor holds an item (it would delete the wrong one), and skips an
  item no longer where it was read (`StillThere`).

## 5. The Automation tab (`next/settings/categories.lua`, `CreateAutomationTab`)

Fourth tab of the Categories page (next-settings.md §5), shown while a category is chosen, a plugin's
too (what it does is the player's choice). Rows: **Action** (a dropdown: Nothing, Sell at Merchants,
Destroy; saved at once) with **Destroy Next Item** beside it for Destroy; what the action does (Shift
keeps items at a merchant; the key binding); what is never touched (equipment sets, refundable
purchases). Then **Items It Acts On**, where the other tabs put their item box: how many it would sell or
destroy, and the backpack's items it acts on (its group by's sections too), an item a cell with how many
there are, those it leaves alone faded with why in their tooltip. With no action it says to choose one,
and does not look for items. The category's list line ends "Sells at merchants" or "Destroys on command".
`NextItemGrid:SetEntries(entries, emptyText)` gained the empty text for this.

## 6. Coverage

- `spec/automation_spec.lua`: which items (order, the backpack's bags, Recent Items ignored, every reason
  to leave one alone, what sell and destroy categories sell and destroy); selling (the events, one a
  frame from the next frame, the summary and its money, Shift, a merchant that does not buy on retail and
  Classic, the limit with and without more left, the limit off, the merchant closing, waiting for the
  cursor, items that moved, locked or became refundable, a reopened merchant, items without a GUID);
  destroying (the next item, the cursor, combat, nothing left, an item that moved, one not picked up, the
  key binding).
- `spec/categories_spec.lua` (saving without recalculating, a plugin's kept across creation,
  `AutomationOf` and sub-categories), `spec/database_spec.lua` (`autoSellLimit`, a plugin's saved state),
  `spec/items_spec.lua` (`GetCategory` ignoring Recent Items), `spec/core/constants_spec.lua` (the limit's
  default), `spec/config/catalog_spec.lua`, `spec/next/settings/content_spec.lua` (four tabs, General's
  new setting), `spec/next/settings/categories_spec.lua` ("the Automation tab", the list line, which tabs
  show), `spec/next/controls/itemgrid_spec.lua` (the empty text), `spec/core/init_spec.lua` (initialized
  and enabled), `spec/integration/next_settings_spec.lua` (built on the whole addon).
- 72 mutations, every one caught (four first survived and led to tests: destroying an item it leaves
  alone, an item without a GUID, the limit message with nothing left, looking for items with no action).

**Not verified in game:** a sale at a real merchant (retail, Classic, WoW: Forever), pacing one item a
frame against the server, the trade-timer question during a sale, `IsSellAllJunkEnabled` at a
repair-only merchant, and destroying from the key binding and the button. To check: make a category
`rarity = poor`, set it to Sell at Merchants, open a merchant (once holding Shift), and a category to
Destroy with a cheap item, pressing the binding; `/console taintLog 1` should log nothing for BetterBags.
