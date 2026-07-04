# Item Loading and Static Cache Rules

This document defines the architecture, design guidelines, and API contracts for item loading, caching, and database sweep operations within BetterBags.

## Architectural Guidelines

### 1. Static ItemMixin Caching (Zero-Allocation Design)
Historically, the data sweep phase dynamically instantiated transient `ItemMixin` objects on every `BAG_UPDATE` or full scan. This placed significant pressure on the Lua garbage collector and introduced potential framerate micro-stutters.
- **Rule:** Every physical bag slot (`bagID` and `slotID`) must map to a single, permanently cached `ItemMixin` instance.
- **Registry:** `ItemLoader` maintains this permanent cache in `self.itemMixinsBySlotKey` indexed by `slotKey` (formatted as `"bagID_slotID"`).
- **Access:** Other subsystems (like `data/items.lua`) must retrieve `ItemMixin` instances from the cache via:
  ```lua
  local itemLoader = addon:GetModule('ItemLoader')
  local itemMixin = itemLoader:GetItemMixinFromSlotKey(slotKey)
  ```
- **Mutation:** The cached `ItemMixin` handles any item changes internally when queried (as its state is bound by slot location, not static values). Therefore, the cached mixin should never be recreated or released back to any pool.

### 2. Native Asynchronous Cache-Priming via `ContinuableContainer`
To prevent visual flickers, blank slots, and lag-induced loading glitches, UI rendering must only occur after the client's internal C-level cache is fully primed with item data.
- **Rule:** Never attempt to read details or draw items from a raw, uncached `BAG_UPDATE` event.
- **Mechanism:** Utilize Blizzard's native `ContinuableContainer` inside `ItemLoader` to batch and pre-load all changed item mixins.
- **Callback:** The `ItemLoader:TellMeWhenABagIsUpdated(callback)` registry acts as the gatekeeper. The callback fires only after the `ContinuableContainer` completes loading all queued mixins.

### 3. Unified Update Flow
- `BAG_UPDATE` is registered and buckets updated bag IDs.
- `BAG_UPDATE_DELAYED` triggers `ProcessPendingBagUpdates()`.
- Pending bag slots are scanned, and their static mixins are queued into `ContinuableContainer`.
- `ContinueOnLoad` executes the callbacks.
- The `Refresh` module receives the callback and requests draws with a completely primed cache, allowing the draw stage to run 100% synchronously and instantly.

### 4. Unified Retail Bank Loading and Persistent Tab Filtering
To support instant, synchronous tab switching with zero visual flickers or loading stutters:
- **Unified Cache:** On Retail, the data-loading pipeline (`data/items.lua`) always loads all bank bags (both Character Bank and Account/Warbank bags) into a single, unified `slotInfo` cache, regardless of the active tab.
- **Strict Filtering:** Both `gridview.lua` and `bagview.lua` strictly partition this complete cache via `ItemBelongsToTab()`. Items in `ACCOUNT_BANK_BAGS` only render in Account/Warbank tabs, while items in `BANK_BAGS` only render in Character Bank tabs, preventing unassigned category leakage between tabs.
- **Instant Swapping:** Since the cache is always complete, tab switching (`SwitchToGroup` or `SwitchToBlizzardTab`) does not wipe caches or trigger server-refresh messages. Instead, the UI simply hides the old view, fetches the new view, and calls `Draw()` synchronously and instantly.
