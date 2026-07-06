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
- **Tab-Swap Sizing:** Toggling active tab visibility (`tab_switch = true`) synchronously re-evaluates the pre-rendered grid's height, updates container/scroll child dimensions, and calls `UpdateBagBounds` instantly with sub-millisecond local latency.
