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

### 3. Unified Update Flow (Stateless, Zero-Debounce Execution)
- `BAG_UPDATE` is registered and buckets updated bag IDs.
- `BAG_UPDATE_DELAYED` triggers `ProcessPendingBagUpdates()`.
- Pending bag slots are scanned, and their static mixins are queued into `ContinuableContainer`.
- `ContinueOnLoad` executes the callbacks.
- The `Refresh` module receives the callback and immediately requests draws/refreshes instantly and synchronously with a completely primed cache, allowing the entire pipeline to run 100% synchronously and instantly.
- **Rule:** The `Refresh` module is completely stateless. It does not maintain arbitrary timer debounces (`C_Timer.NewTimer`), pending wipe flags, or stateful flags like `pendingBackpack` or `pendingBank`. Redraw requests trigger synchronously at the natural `BAG_UPDATE_DELAYED` frame boundary. Data sweeps can execute perfectly at any time, including during combat, as data-harvesting is fully decoupled from secure layout frames.
- **Combat Gating:** To prevent Blizzard "Action blocked" taint errors during active combat, any redraws requested while `InCombatLockdown()` is true must be deferred. The parameters are safely merged and queued into `self.pendingRequest`, then fully processed and cleared when `PLAYER_REGEN_ENABLED` fires.
- **Initial Startup Refresh:** To prevent bags from appearing completely blank on initial login or UI reload, `Refresh:OnEnable()` must explicitly trigger an initial full-cache wipe update (`wipe = true, backpack = true, bank = true`) once all modules are active.
- **Core Invalidation Events:** Standard events (`BAG_CONTAINER_UPDATE`, `EQUIPMENT_SETS_CHANGED`) and Classic-specific events (`PLAYERBANKSLOTS_CHANGED`) must be registered to trigger target cache-wipe redraws, ensuring perfect visual synchronization across all retail and classic environments.

### 4. Unified Retail Bank Loading and Persistent Tab Filtering
To support instant, synchronous tab switching with zero visual flickers or loading stutters:
- **Unified Cache:** On Retail, the data-loading pipeline (`data/items.lua`) always loads all bank bags (both Character Bank and Account/Warbank bags) into a single, unified `slotInfo` cache, regardless of the active tab.
- **Strict Filtering:** Both `gridview.lua` and `bagview.lua` strictly partition this complete cache via `ItemBelongsToTab()`. Items in `ACCOUNT_BANK_BAGS` only render in Account/Warbank tabs, while items in `BANK_BAGS` only render in Character Bank tabs, preventing unassigned category leakage between tabs.
- **Bypass for Blizzard Bag View:** If the active view mode is Blizzard's physical container view (`SECTION_ALL_BAGS`), the `ItemBelongsToTab()` partition filters and section group-hiding filters must be completely bypassed. This ensures that when a user switches to Blizzard Bag View, all physical bag containers and their items render completely and synchronously, regardless of the active custom tab/group.
- **Instant Swapping:** Since the cache is always complete, tab switching (`SwitchToGroup` or `SwitchToBlizzardTab`) does not wipe caches or trigger server-refresh messages. Instead, the UI simply hides the old view, fetches the new view, and calls `Draw()` synchronously and instantly.

### 5. Butter-Smooth Tab Swapping (Context-Gated Bypass)
To achieve sub-millisecond local tab swaps across both the Backpack and the Bank, tab switching operations are completely decoupled from active database rebuilds or full view redraws.
- **Uniform Mechanism:** Toggling active tab visibility (like clicking a tab or switching a group in either Backpack or Bank) tags the execution context with `tab_switch = true`. Both `backpack.proto:SwitchToGroup` and `bank.proto:SwitchToGroup` immediately trigger a fast local `Draw` using the existing static, pre-rendered `slotInfo` cache.
- **Bypass Flag:** Operations that only toggle active tab visibility tag the execution context with `tab_switch = true`.
- **Render Bypass:** In `bagProto:Draw(ctx, slotInfo, callback)`, if the context carries the `tab_switch` flag, the engine completely bypasses background and active `view:Render` pipelines, provided the target view is already initialized (`not view.isNew`). Newly instantiated views (`view.isNew = true`) are allowed to run their initial render to fetch and cache item buttons.
- **Background Loop Bypass:** The background rendering loop that typically keeps inactive views in sync is entirely gated by `not ctx:GetBool("tab_switch")`. This completely skips background view rendering during local tab switches, preventing massive CPU spikes.
- **Instant Swap:** Instead, visibility of the hidden and active views is toggled synchronously, scale and search states are adjusted, `self:OnResize()` is called, and the callback is invoked instantly. This avoids any sorting or layout calculation overhead entirely.

### 6. Idempotent Functional Rendering (No Changeset Gating)
To enforce strict functional isolation and eliminate UI state leakage or out-of-order rendering bugs, changeset-gating and background rendering optimizations have been completely removed.
- **Rule:** Every rendering pass for any view (whether active or background) must be 100% functional, idempotent, and built completely from scratch using the provided `slotInfo` dataset state.
- **Benefits:** Eliminating incremental delta updates guarantees that the view state remains mathematically consistent with the underlying data model, preventing the visual accumulation of ghost or out-of-sync frames.

### 7. Phase 8: Page Placement (Clean-Sweep Layout and Column-Packing)
To achieve sub-millisecond redraw performance while ensuring that the grid layout remains perfectly aligned, visually fluid, and free of overlap/gaps:
- **Rule:** Page placement is a pure, top-down clean-sweep operation. It is triggered synchronously when the data backend emits `items/RefreshBackpack/Done` or `items/RefreshBank/Done` messages.
- **Unified Views:** GridView, OneBagView, and Blizzard Bag View are handled polymorphically within `views/gridview_new.lua` and `views/bagview_new.lua`. They avoid redundant layout files by treating views as alternative naming classifications.
- **Two-Pass Column packing:**
  - **Pass 1:** Determines the default height/width of all category sections and splits them into equal-height vertical columns using the `calculateColumns` algorithm inside `frames/grid.lua`.
  - **Pass 2 (Row collapse shrink optimization):** Measures row-level layouts to shrink-wrap category sections when all items within a row are collapsed. This dynamically adjusts bounding heights and prevents massive blank gaps.
- **Bounds Clamping:** The view calculates the total bag height and width, clamps the parent frame within safe screen limits (`UIParent:GetHeight() * 0.90`), and toggles the scrollbars and frame points dynamically.
- **Shared, Stateless Sizing (`UpdateBagBounds`):** To ensure uniform sizing when switching tabs instantly without caching state, all bag views call a shared, stateless helper method `view:UpdateBagBounds(bag, w, h)`. This centralizes the bounds calculations, clamping, scrollbar visibility, and search-offset positioning. It is invoked both at the end of the full rendering pipeline and during the `tab_switch = true` local bypass in `bagProto:Draw(ctx, slotInfo, callback)` (using the pre-rendered grid dimensions via `self.content.inner`), achieving visual size parity with zero state-holding overhead.

### 8. Phase 4.5: Category Enrichment & Data Enrichment
To eliminate JIT (just-in-time) database and search engine queries during UI layout rendering, we assign final item categories and enrich item data right after search indexing and before layout/section placement occurs.
- **Rule:** Item categories must never be resolved JIT on-the-fly inside the views (`GridView` or `BagView`). Instead, they are retrieved instantly from the enriched `item.itemInfo.category` field.
- **Mechanism:** Immediately after Phase 4's search indexing `search:IndexItems(itemData)` completes:
  - Call `self:RefreshSearchCache(kind)` to update search-based category matches using the search engine.
  - Iterate over all items in `itemData` and resolve their final category using priority-based checks (custom categories, search matches, and system defaults).
  - Update `item.itemInfo.category` and optionally refresh the search index's category with `search:UpdateCategoryIndex(currentItem, oldCategory)`.
- **Obsolete Views:** Obsolete `ONE_BAG` (value 1) and `LIST` (value 3) views have been completely removed from constants and database defaults. Existing users' databases are automatically migrated to `SECTION_GRID` (Category View) via `DB:Migrate()`.

### 9. Isolated Wipe-On-Render to Prevent Pool Contamination and Anchor Crashes
To permanently prevent ObjectPool contamination, cell leakage, and fatal `Cannot anchor to itself` crashes during layout recalculations:
- **Rule:** Every rendering pass for a view is functionally isolated and begins with a complete, synchronous wipe of its own frames, returning all of its pooled elements back to the global stacks before any rendering/population occurs.
- **Mechanism:** The very first line of each view's `Render` method (e.g. `GridView` or `BagView`) executes `view:Wipe(ctx)`.
- **State Transition (`isNew` flag):** Inside `Wipe(view, ctx)`, explicitly set `view.isNew = true` to flag the view as completely empty. At the beginning of the `Render` method (right after wiping), set `view.isNew = false` to indicate the view is populated and complete. This guarantees 100% clean-slate rendering on every single frame update.
