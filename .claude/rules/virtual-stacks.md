# Virtual Stacking and Clean-Sweep Optimization Rules

This document defines the architecture, design guidelines, and API contracts for virtual stacking within BetterBags.

## Architectural Guidelines

### 1. Clean-Sweep Stacking (State Independence)
Historically, stacking relied on incremental delta updates during active database loops. This coupled data harvesting with UI rendering and was prone to state desynchronization (e.g. out-of-order `BAG_UPDATE` events or client-side race conditions).
- **Rule:** The virtual stacking engine is state-independent and resolved from scratch (clean sweep) on every database update context.
- **Wipe:** The stack is cleared via `stack:Clear()` before any new additions are processed.

### 2. O(1) Constant-Time Insertion Optimization
The legacy stack insertion loop searched child elements inside nested $O(N)$ lookup loops to determine the lead/root item.
- **Rule:** Determine the root item in constant time $O(1)$ by directly comparing the incoming `ItemData` with the current `rootItem`'s count and slotkey lexicographical precedence.
- **Decision Contract:**
  - If the current root is empty or nil, the incoming item is promoted to the root.
  - If the incoming item's count is strictly higher than the current root's count, the incoming item is promoted to root, and the old root is added to the children list.
  - If counts are equal, and the incoming slotkey is lexicographically greater than the current root's slotkey, the incoming item is promoted to root, and the old root is added to the children list.
  - Otherwise, the incoming item is added to the children list.
- **Constant Lookup:** Access root data via `items:GetItemDataFromSlotKey(rootItem)` for the single direct comparison, eliminating all child iterations.

### 3. O(1) Child Deletion Gating
- **Rule:** When removing a child item from the stack via `RemoveFromStack(item)`, the root item's validity is unaffected.
- **Optimization:** Skip all candidates/root updates when a child is deleted; simply remove the child key from the `slotkeys` dictionary in $O(1)$ constant time. Only execute a lookup pass if the root itself is deleted and a replacement root must be selected from the remaining children.

### 4. Item Stats Belong in the Item Hash (Catalyst)
Items merge into a single virtual stack when they share an `itemHash` (`stack:AddToStack` keys `stacksByItemHash` by `item.itemHash`, built in `items:GenerateItemHash`, `data/items.lua`). The hash is composed of the parsed item-link fields (itemID, enchant, gems, suffix, **bonusIDs**, relic bonus IDs, crafterGUID, extraEnchantID), plus binding, current item level, and — when *don't merge transmog* is set — the transmog appearance.
- **Failure mode (Catalyst):** Midnight Patch 12.1 changed the Catalyst so a converted tier piece **retains the source item's secondary stats** instead of taking the tier template's fixed stats. Two such pieces can therefore share the same itemID, item level and bonus IDs while showing different secondaries (e.g. Crit/Haste vs Crit/Versatility). Verified from a live client dump, the *only* item-link difference between two such Fists is the value of an item-link **modifier** (`numModifiers` section, type 64) — a field `GenerateItemHash` intentionally does not hash (it never hashes `modifierIDs`, because those can carry per-instance values like `Enum.ItemModification.DbidHigh`/`DbidLow` that would break stacking for everything). So the two pieces collided and one was hidden behind a virtual stack.
- **Rule:** Fold a **sorted digest of `C_Item.GetItemStats(itemLink)`** into the item hash via `items:GenerateItemStatHash(itemLink)`. `GetItemStats` reports the client's resolved per-item stat table (verified to differ for the two Catalyst pieces even though their bonus IDs are identical), keyed by locale-independent global-string constant names (e.g. `ITEM_MOD_CRIT_RATING_SHORT`). The digest is `key=value` pairs joined by `,` with keys `table.sort`ed for determinism; it is `""` when the link is missing, when no stat API is available, or when the table is empty (so consumables and other statless items keep merging exactly as before). This is deliberately encoding-agnostic — it hashes what the client computed rather than guessing which link field carries the difference, and it avoids hashing volatile per-instance modifier IDs.
- **Cross-client:** use `C_Item.GetItemStats` on Retail (10.2.5+; the only spelling on 11.0.2+/12.x) and fall back to the global `GetItemStats` on Classic/Era (where the `C_Item` variant does not exist). Called inside `GenerateItemHash`, which runs during Phase 2 harvest where the item is already loaded via `ContinuableContainer`, so no extra async gating is needed.
- **Coverage:** `spec/items_spec.lua` ("GenerateItemHash (Catalyst item stats)") and `spec/refresh_pipeline_spec.lua` ("does not virtually stack two catalyst items that differ only in secondary stats").

### 5. Show Bags (SECTION_ALL_BAGS) Never Virtually Stacks
The "Show Bags" view mirrors the physical container layout — every bag slot renders on its own — so merging multiple physical slots into one visible root contradicts it. Virtual stacking runs in the data phase (`items:Phase7_ApplyVirtualStacks`) independently of the active view, so without a gate it merged items even in Show Bags, hiding physical slots.
- **Rule:** In `Phase7_ApplyVirtualStacks`, when `database:GetBagView(kind) == const.BAG_VIEW.SECTION_ALL_BAGS`, `ShouldMergeItem` returns `false` for every item, so each physical slot survives as its own visible root (its `stackedCount` stays nil and it renders its own count). All other views merge exactly as before.
- **Coverage:** `spec/refresh_pipeline_spec.lua` ("Show Bags (SECTION_ALL_BAGS) view").

### 6. Bank-Type Scoped Hash (Character Bank vs Warbank Never Stack)
The virtual stack is keyed **only** by `item.itemHash` (`stacksByItemHash`), and everything downstream — `Phase7_ApplyVirtualStacks`, `items:BuildOrderedItems` move/re-root bucketing, `frames/section.lua`'s right-click stack-sell lookup, the committed `slotInfo.stacks` — resolves a slotkey back to its stack through that same `item.itemHash`. On Retail the bank data sweep loads **both** bank types into one unified `itemData` (Character Bank = `BANK_BAGS`/base bank, Warbank = `ACCOUNT_BANK_BAGS`) and only partitions them into tabs downstream (data-loader.md §4). Virtual stacking runs *before* that partition, so a hash with no location component let an identical item in the Character Bank and in the Warbank collide into one stack: only the root survived in `visibleItemsBySlotKey`, the other physical pile vanished, and the item appeared to "merge across bank types / tabs".
- **Failure mode (this fix):** with "Unmerge on Interactions" off and Merge Stacks on, the same item in the Character Bank and the Warbank showed as a single merged icon in whichever bank type owned the stack root; the other bank type's copy was dropped from the view. Reported as icons merging "across bank and warbank, or across tabs".
- **Rule:** `items:GenerateItemHash` appends a **bank-scope discriminator** to the hash: `"W"` when `const.ACCOUNT_BANK_BAGS[data.bagid]` is set (Warbank), `""` otherwise. Character-Bank bags and the base bank keep the empty scope and still stack together; all Warbank tabs share the `"W"` scope and still stack together; the two groups can never share a hash, so they never virtually stack. The discriminator is derived from `data.bagid` (set in `items:AttachItemInfo` before the hash is generated). `const.ACCOUNT_BANK_BAGS` is Retail-only (nil on Classic/Era), so the guard `const.ACCOUNT_BANK_BAGS and const.ACCOUNT_BANK_BAGS[data.bagid]` leaves the backpack and every non-retail client's hash byte-for-byte unchanged.
- **Why scope by bank type, not by tab:** within a single bank type an item's tab is a pure function of its category, and two identical items resolve to the same category (hence the same tab), so same-bank-type stacking never crosses a tab. Only the unified-cache bank-type boundary is structural, so that is the only boundary the hash must encode. A physical move that crosses bank types changes the hash (correctly treated by `BuildOrderedItems` as a remove+add rather than an in-place move, since it leaves one tab-set for another).
- **Coverage:** `spec/refresh_pipeline_spec.lua` ("bank/warbank virtual stacking isolation": "does not merge an identical item across the Character Bank and the Warbank" and "still merges two identical items within the same Character Bank").
