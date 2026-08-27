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
- **Release Before Acquire (Shared Button Ownership):** Every physical slot has exactly one static item button (`itemFrame.buttonsBySlotkey`), and that button is shared by the global sections and by every tab view. `bagProto:Draw` is therefore a two-phase pass: it first calls `WipeGlobalSections(ctx)` and `view:Wipe(ctx)` on **every** view in `tabViews` (regardless of layout), and only then renders background views, `DrawGlobalSections`, and the active view. A `Wipe` that ran after another renderer acquired a button would `Release` (hide + unparent) a button that renderer had just drawn — this was the cause of Free Space / Recent Items buttons randomly vanishing when an item moved into or out of the slot that became their representative. Each `Render` still self-wipes (§ data-loader 9), but by then the view owns nothing, so that wipe releases no shared button. `spec/frames/bag_draw_ownership_spec.lua` asserts the last `item:Release` precedes the first `itemFrame:GetButton` of a pass.

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
- **Tab-Swap Sizing:** Toggling active tab visibility (switching groups or tabs) runs through the same pure stateless drawing flow synchronously, re-evaluating the active grid's height, updating container/scroll child dimensions, and calling `UpdateBagBounds` instantly to achieve flawless sizing with zero state-holding overhead.

### 4. Absolute Position Grid and Mathematical Gap Handling
To support visual gaps and spacers without polluting the UI with thousands of invisible frame regions or heavy unused `ItemButton` objects, the Grid layout engine uses a mathematically calculated absolute-position layout system.
- **Rule:** The `Grid` module does not chain cells relative to previous cell frames. Instead, `layoutSingleColumn` computes the precise `(currentX, currentY)` coordinates for each cell relative to its parent container frame (`self.inner`) using pure mathematical offsets.
- **Gap Objects:** A gap or spacer is represented as a lightweight, stateless cell table with `isGap = true` (e.g. `{ isGap = true, width = 37, height = 37 }`), bypassing frame creation completely.
- **Data Layer Contract:** The data layer specifies spacer locations in `tabData.items` by setting `isItemGap = true`. Such items are omitted from item count metrics (`tabData.totalItems`).
- **View Layer Contract:** In both `GridView` and `BagView` rendering pipelines, if an item is a gap (`item.isItemGap == true`), we do not request or draw an `ItemButton`. Instead, we add a mathematical gap cell to the corresponding section via `section:AddCell(slotkey, { isGap = true, width = 37, height = 37 })`.
- **Linter & Test Verification:** All calculations must remain free of warnings under `luacheck` and fully covered by layout-specific and edge-case unit tests.

