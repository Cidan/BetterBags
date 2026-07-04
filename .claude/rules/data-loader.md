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

### 5. Butter-Smooth Tab Swapping (Context-Gated Bypass)
To achieve sub-millisecond local tab swaps, tab switching operations are completely decoupled from active database rebuilds or view redraws.
- **Bypass Flag:** Operations that only toggle active tab visibility (like clicking a tab or switching a group) tag the execution context with `tab_switch = true`.
- **Render Bypass:** In `bagProto:Draw(ctx, slotInfo, callback)`, if the context carries the `tab_switch` flag, the engine completely bypasses background and active `view:Render` pipelines, provided the target view is already initialized (`not view.isNew`). Newly instantiated views (`view.isNew = true`) are allowed to run their initial render to fetch and cache item buttons.
- **Background Loop Bypass:** The background rendering loop that typically keeps inactive views in sync is entirely gated by `not ctx:GetBool("tab_switch")`. This completely skips background view rendering during local tab switches, preventing massive CPU spikes.
- **Instant Swap:** Instead, visibility of the hidden and active views is toggled synchronously, scale and search states are adjusted, `self:OnResize()` is called, and the callback is invoked instantly. This avoids any sorting or layout calculation overhead entirely.

### 6. Targeted Background Updates (Changeset Gating)
When a real data update occurs (such as a database or server item change), every background/inactive tab view is rendered. To ensure background renders are computationally cheap, they are gated by tab-specific changeset changes.
- **Rule:** Background views must only execute heavy layout, section sorting, and cell placement logic if item data belonging specifically to their tab has actually changed.
- **Gating Mechanism:** Inside `GridView` and `BagView` rendering functions, if the view is a hidden background view (where `bag.GetCurrentTabID` is defined and `view.tabID ~= bag:GetCurrentTabID()`) and no global layout change is forced (i.e. not `redraw`, not `wipe`, and not `isNew`), the view filters the global changeset for its tab using `FilterChangesetForTab()`.
- **Early-Exit:** If the tab-specific added, removed, and changed lists are all empty, the view early-exits instantly by invoking the callback and returning. This prevents wasting CPU sorting and laying out hidden tabs that are already in a consistent state.
