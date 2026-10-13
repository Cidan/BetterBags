# Layout Rendering and Global ScrollBox Architecture

This document defines the architecture, design guidelines, and API contracts for layout rendering, tab containers, and global scrolling components within BetterBags.

## Architectural Guidelines

### 1. Unified Global ScrollBox Architecture (Zero-Reparenting Secure Frame Design)
Historically, each individual Tab View created its own `WowScrollBox` and scrollbar, and rendered special sections (`Recent Items` and `Free Space`) as internal header/footer cells inside that specific view's scrollbox. Because WoW secure item frames are bound to unique physical slot keys and cannot be reparented or dynamically moved between views during active combat without causing fatal "Action blocked" taint errors, we decouple the scrolling and special sections from individual tab views.
- **Rule:** The entire Bag window must contain exactly **one single global `WowScrollBox` and `MinimalScrollBar`** defined natively at the `Bag` level (`frames/bag.lua`).
- **Hierarchy:**
  ```
  Bag Window Frame (frames/bag.lua)
    └── Global WowScrollBox
         └── Global Scroll Child
              ├── Header Container (Recent Items section)
              ├── Tab Container (Active Tab View layout grid)
              └── Footer Container (Free Space section)
  ```
- **Benefits:** Since `Recent Items` (Header) and `Free Space` (Footer) are attached globally to the scroll child of the Bag frame and never hidden or reparented on tab switches, they scroll seamlessly together with the active tab's items as a single unified canvas. Tab switching simply toggles visibility of the active tab view's layout grid inside the `Tab Container` with zero secure reparenting or combat taint.
- **Claim, Then Sweep (Shared Button Ownership):** Every physical slot has exactly one static item button (`itemFrame.buttonsBySlotkey`), and that button is shared by the global sections and by every tab view. A `bagProto:Draw` pass releases **nothing** up front:
  1. It starts a claim table and begins a pass on the global sections (`BeginGlobalSections`) and on every view in `tabViews` (`view:BeginRender(ctx, claims)`). Beginning sets last pass's sections aside for reuse and clears the views' cell lists; no frame is hidden, unparented or released.
  2. `DrawGlobalSections` and the **active** view's `Render` draw. Every button they draw is recorded as claimed (`GetOrCreateItemButton`, `GetOrCreateGlobalItemButton`), and a category drawn again goes into the same section object (`GetOrCreateSection` / `GetOrCreateGlobalSection` call `section:PrepareForReuse()`, the pool reset minus `Hide`/`ClearAllPoints`/`SetParent(nil)`).
  3. `FinishDrawPass` (start of the render callback, after every renderer) finishes every view (`FinishRender` releases sections not drawn again, and every section of a view that was not rendered), releases stale global sections, and releases each button the previous pass drew (`bag.drawnButtons`) that no renderer claimed. Section releases never release their item cells; buttons are released only by this sweep.
  - **Why:** the old pass wiped every view and global section first, so every displayed button was hidden, unparented and reset, then shown again, on every redraw. Hiding and showing an item button runs Blizzard Lua on both the interaction button and its decoration (`ContainerFrameItemButtonMixin:OnHide`, `EnchantingItemButtonAnimMixin:OnShow`/`OnHide` (un)registering events, `ItemButtonMixin:PostOnShow`/`PostOnHide` (un)registering `ItemContextChanged` and re-running `UpdateItemContextMatching`). A profiled redraw on WoW: Forever spent ~5.4 ms of 13 ms releasing 31 buttons and sections. A button drawn again is now never hidden or unparented, and sections stay shown, so their children do not get OnHide/OnShow either.
  - **The invariant this keeps:** no renderer can release a button another renderer drew in the same pass (the bug the old release-first rule fixed: Free Space / Recent Items buttons vanishing when an item moved into or out of their slot), because buttons are only released after every renderer has run and only if unclaimed.
  - **Only the active tab renders.** Background rendering of the other tabs of the current layout was added (#989) when views were updated incrementally, so hidden tabs would not miss changes. Views now rebuild from scratch, and every tab switch (`SwitchToGroup`, bank `SwitchToBlizzardTab`) calls `bag:Draw`.
  - **Teardown is still a full release:** `bag:Wipe` (bank close) releases the global sections, wipes **every** view in `tabViews`, and releases every button in `drawnButtons` and in an unfinished pass's `claims`; `DeleteTabView` wipes the deleted views. `view:Wipe` also releases the cells of sections a failed pass set aside, before returning those sections to the shared pool (a section must never go back to the pool with shown buttons inside it: the next `SectionFrame:Create`, possibly for the other bag, would hand them out). `item:Wipe` is a no-op on a button not drawn since its last release, so a teardown followed by a sweep cannot release a button twice (a virtual button would otherwise enter its pool twice).
  - **Failure recovery:** if a pass errors before its sweep, the next `Draw` adds the failed pass's claims to `drawnButtons` and finishes any view or global pass left open before beginning.
  - `frames/grid.lua` `layoutSingleColumn` only calls `SetParent` when the cell is not already parented to the grid. Coverage: `spec/frames/bag_draw_ownership_spec.lua` ("claim, then sweep"), `spec/views/views_spec.lua` ("Views render passes"), `spec/views/persistent_tabs_spec.lua`, `spec/frames/grid_spec.lua`.
- **Recent Items order and gaps come from `slotInfo.sortedItems`, never from a `pairs()` scan.** The global `Recent Items` header section is the only section rendered outside the tab views (`ItemBelongsToTab` returns `false` for `Recent Items` and `Free Space`), so it does not receive `tabData.items`. It must still honor the **ordered, gap-carrying** layout the data pipeline committed in `slotInfo.sortedItems` (produced by `items:BuildOrderedItems`, § data-loader 13): `DrawGlobalSections` iterates `slotInfo.sortedItems` in order, keeps entries whose `itemInfo.category == "Recent Items"` (including `isItemGap` clones, whose category is preserved by `CloneAsGap`), and renders gap entries as frameless `{ isGap = true, width = 37, height = 37 }` cells exactly like the tab views. **Failure mode (fixed):** the section previously iterated the unordered visible-item map (`slotInfo:GetVisibleItems()`, a hash) via `pairs()`, so Recent Items rendered in an arbitrary hash-iteration order that re-shuffled on every sweep, and because gaps live only in `sortedItems` (never in the visible map) a consumed item collapsed its slot instead of leaving a persistent gap — even with "Preserve Empty Slots as Gaps" on. Coverage: `spec/frames/bag_draw_ownership_spec.lua` ("renders Recent Items in slotInfo.sortedItems order…" and "preserves a consumed Recent Items slot as an in-place gap…").

### 2. Dumb, Pure-Grid Tab Views
- **Rule:** Individual tab views (like `SECTION_GRID` and `SECTION_ALL_BAGS`) must act as purely static layout grids with zero scrolling behavior.
- **Grid Creation:** Views must initialize their grids with `grid:Create(parent, false)`, which disables standard scrollbox wrapping and outputs a raw, lightweight layout Frame.
- **Parent Anchoring:** Views must anchor themselves exclusively to `bag.tabContainer` using `view.content:GetContainer():SetAllPoints(parent)`.
- **Dumb Rendering:** Views do not calculate or render `Recent Items` or `Free Space` categories, and they omit the `header` and `footer` parameters in their `content:Draw()` calls. They strictly render categories belonging directly to their tab index.

### 3. Stateless Sizing Orchestration (`UpdateBagBounds`)
- **Rule:** Resizing the main Bag UI window and managing scrollbar visibility is the sole responsibility of the Bag Frame (`bagProto:UpdateBagBounds(w, h)`), not individual views.
- **Draw Flow:**
  - `DrawGlobalSections(ctx, slotInfo)` sweeps physical items, populates the global `Recent Items` and `Free Space` sections, renders them directly in the global containers, and returns their calculated bounds (`headerH`, `footerH`, etc.).
  - `view:Render(ctx, self, slotInfo, callback)` renders the active tab's static grid.
  - In the callback, the Bag frame computes the true total accumulated width and height:
    ```lua
    local totalW = math.max(headerW, tabW, footerW)
    local totalH = headerH + tabH + footerH
    ```
  - The scroll child's size is explicitly updated: `scrollChild:SetSize(totalW, totalH)`.
  - `UpdateBagBounds(totalW, totalH)` is called to resize the bag frame and dynamically show or hide the global scrollbar based on screen clamping limits.
- **A shown bag is drawn once.** `bagProto:Draw` on a hidden bag only defers (`drawPendingOnShow`), and `bagProto:Show(ctx, slotInfo)` draws the deferred draw (with the caller's `slotInfo` when given) and returns whether it drew. The bank's `items/RefreshBank/Done` handler (`core/init.lua`) draws only when showing did not: a captured bank open drew the whole bank twice in one frame (the second pass skipped every button but still cost 19 ms). Coverage: `spec/core/init_spec.lua` ("bank refresh draw"), `spec/frames/bag_draw_ownership_spec.lua` ("showing a bag (Show)").
- **Tab-Swap Sizing:** Toggling active tab visibility (switching groups or tabs) runs through the same pure stateless drawing flow synchronously, re-evaluating the active grid's height, updating container/scroll child dimensions, and calling `UpdateBagBounds` instantly to achieve flawless sizing with zero state-holding overhead.

### 4. Absolute Position Grid and Mathematical Gap Handling
To support visual gaps and spacers without polluting the UI with thousands of invisible frame regions or heavy unused `ItemButton` objects, the Grid layout engine uses a mathematically calculated absolute-position layout system.
- **Rule:** The `Grid` module does not chain cells relative to previous cell frames. Instead, `layoutSingleColumn` computes the precise `(currentX, currentY)` coordinates for each cell relative to its parent container frame (`self.inner`) using pure mathematical offsets.
- **Gap Objects:** A gap or spacer is represented as a lightweight, stateless cell table with `isGap = true` (e.g. `{ isGap = true, width = 37, height = 37 }`), bypassing frame creation completely.
- **Data Layer Contract:** The data layer specifies spacer locations in `tabData.items` by setting `isItemGap = true`. Such items are omitted from item count metrics (`tabData.totalItems`).
- **View Layer Contract:** In both `GridView` and `BagView` rendering pipelines, if an item is a gap (`item.isItemGap == true`), we do not request or draw an `ItemButton`. Instead, we add a mathematical gap cell to the corresponding section via `section:AddCell(slotkey, { isGap = true, width = 37, height = 37 })`.
- **Linter & Test Verification:** All calculations must remain free of warnings under `luacheck` and fully covered by layout-specific and edge-case unit tests.

