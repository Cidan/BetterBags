# BetterBags Rendering Refactor: Architectural Handoff Document

This document serves as the formal handoff specification for the BetterBags rendering pipeline refactor. It preserves the complete structural context, current implementation progress, and the immediate critical next steps for the next execution session.

## 1. Context & Architectural Vision
We are transitioning BetterBags from an imperatively driven, delta-based incremental system (where data farming, stacking, search indexing, and rendering were tightly coupled and prone to out-of-sync "ghost items" or duplicated buttons) to a **100% unidirectional, stateless, top-down clean-sweep pipeline**.

By decoupling the **Ideal state** (what items exist) from the **Execution state** (how we group and draw them), we permanently eliminate a massive class of race condition bugs.

The refactored pipeline consists of 8 discrete, breadth-first phases:
- **Phase 1 (Item Loader):** Asynchronously pre-primes the client C-level item cache and holds a static slotkey-to-ItemMixin registry. *(Status: Active & Stable)*
- **Phase 2 (Data Farming):** Performs pure, breadth-first, zero-allocation physical slot harvests (`data/items.lua`). *(Status: Active & Stable - Merged in PR 1002)*
- **Phase 3 (Virtual Stacks):** Resolves parent-child stack groupings from a clean slate on every update (`data/stacks.lua`). *(Status: Active & Stable - Merged in PR 1003)*
- **Phase 4 (Search Indexing):** Decoupled, clean-sweep indexing pass over the resolved layout models (`data/search.lua`). *(Status: Active & Stable - Merged in PR 1004)*
- **Phase 5 (Item Button Drawing):** Presentation-only, "dumb" button frame drawing (`frames/item.lua`). *(Status: Active & Stable - Merged in PR 1005)*
- **Phase 6 (Item Button Placement):** Unifies Category View, One Bag View, and Blizzard Bag View under a single string-based, clean-sweep polymorphic category placement engine (`views/gridview.lua`). *(Status: Active & Stable - Merged in PR 1008)*
- **Phase 7 (Section Layout):** Wraps sorted cells into local category section grids. *(Status: Active & Stable - Merged in PR 1009)*
- **Phase 8 (Page Placement & UI Restoration):** Packs sections into equal-height columns, resolves window bounds, and un-gates visual redraw messages (`views/gridview.lua`). *(Status: Active & Stable - Merged in PR 1010)*

---

## 2. The Current Issue: Blank Bags in Game
While Phases 1–8 are fully implemented and integrated, the bags currently **render as completely blank** on login/startup in-game. 

The immediate task of the next session is to apply **three critical repairs to the event pipeline in `data/refresh.lua`**:

### A. The Startup Refresh Gap
- **The Problem:** When loading into the game, `ItemLoader` initializes and performs its first physical scans *before* our new `Refresh` module has booted and registered its `TellMeWhenABagIsUpdated()` callback. Because `loader:ProcessPendingBagUpdates()` returns early when `self.pendingBags` is empty (as no container updates have fired yet), **the first startup refresh is completely missed.**
- **The Solution:** Inside `refresh:OnEnable()` (in `data/refresh.lua`), explicitly trigger an initial refresh to load and prepare the bags synchronously on startup:
  ```lua
  self:RequestUpdate({ wipe = true, backpack = true, bank = true })
  ```
  Since the backpack frame is hidden at startup, `bagProto:Draw` will automatically save the slot data into `self.lastSlotInfo` and set `self.drawPendingOnShow = true`. When the player opens their bag for the first time, it will draw perfectly.

### B. Missing Combat Gating
- **The Problem:** In our new stateless loop, updates trigger instantly and synchronously. If a player loots or moves an item during combat, the refresh module would execute `bagProto:Draw` instantly, calling `SetPoint` and `SetSize` on secure button frames in-combat, throwing a fatal **"Action blocked" combat taint error in-game.**
- **The Solution:** We must gate drawings in-combat. Inside `refresh:RequestUpdate(request)`:
  - If `InCombatLockdown()` is true, block immediate dispatches and merge/queue the incoming fields into `self.pendingRequest`.
  - Register `PLAYER_REGEN_ENABLED`: when combat ends, if `self.pendingRequest` is non-nil, execute `self:RequestUpdate(self.pendingRequest)` and reset `self.pendingRequest = nil`.

### C. Missing Core Invalidation Events
- **The Problem:** Core events that require cache wiping and redraws were omitted in the stateless PR:
  - **`BAG_CONTAINER_UPDATE`:** Fired when swapping or buying bag containers. Must trigger `{ wipe = true, backpack = true }`.
  - **`EQUIPMENT_SETS_CHANGED`:** Fired when equipment configurations edit. Must trigger `{ wipe = true, backpack = true, bank = true }`.
  - **`PLAYERBANKSLOTS_CHANGED` (for Classic):** Must trigger `{ wipe = true, bank = true }`.

---

## 3. Testing & In-Game Verification
To verify the stability of the entire pipeline and keep the suite warning-free:
1. **Luacheck:** Ensure modified files are completely warning-free:
   ```bash
   luacheck data/refresh.lua
   ```
2. **Busted Suite (Lua 5.1 Target):** Execute the unit tests against the local interpreter:
   ```bash
   ./lua51-rocks/bin/busted
   ```
3. **In-game Slash Commands:** You can run `/bb debugitems` in-game at any time to verify that the Phase 2 physical data map is successfully being harvested and updated.
