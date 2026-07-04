# Pure Presentation Item Button Drawing Rules

This document defines the architectural guidelines, design decisions, and API contracts for item button drawing in BetterBags.

## Architectural Guidelines

### 1. Pure Presentation Principle (Dumb Visual Layers)
Item buttons (e.g. `frames/item.lua` and `frames/era/item.lua`) must act as pure presentation layers with zero business logic.
- **Rule:** An item button does not decide *how* many items are stacked, *whether* a vendor is open, or *if* a slot is an upgrade. It only accepts a pre-resolved, pre-computed `ItemData` node and updates its visual elements (icon, count text, item level, quest glow, cooldown) synchronously.

### 2. Fully Decoupled API Signatures
Historically, item buttons queried the central inventory database (`data/items.lua`) on-the-fly inside their internal drawing methods. This caused state leakage, race conditions, and heavy overhead.
- **Rule:** All drawing methods on `itemProto` (e.g., `UpdateCount`, `DrawItemLevel`, `UpdateCooldown`, `UpdateUpgrade`, `UpdateNewItem`) must accept an optional `data` parameter.
- **Fallback:** If `data` is omitted, the method can safely fallback to `self:GetItemData()` for backward compatibility, but all internal drawing sequences within the refresh pipeline must pass `data` directly.

### 3. Upstream Pre-computations (Zero On-the-Fly Database Queries)
Attributes like stacked counts or upgrade arrows are computationally heavy and highly dependent on active options (e.g., merging partial stacks, merging unstackables, merchant interaction state, simple item level options).
- **Rule:** The displayed count (`data.stackedCount`) and upgrade status (`data.isUpgrade`) must be computed upstream during the Stacking and Farming phases (Phases 2 & 3).
- **Count Text:** Inside `UpdateCount(ctx, data)`, the count text is populated directly from `data.stackedCount or data.itemInfo.currentItemCount`. No database stacking state is evaluated.
- **Upgrade Icon:** Inside `UpdateUpgrade(ctx, data)`, the upgrade icon uses `data.isUpgrade` directly. If not pre-computed, it safely falls back to a fast, synchronous lookup on Phase 2's `items:GetItemDataFromInventorySlot(slot)` cache, ensuring no raw slotkey-to-database queries are made.

### 4. Code Consistency Across SKU Environments
BetterBags supports multiple World of Warcraft environments (Classic/Era vs. Retail) with separate `.toc` and script bindings.
- **Rule:** Keep `frames/item.lua` and `frames/era/item.lua` completely synchronized in their method signatures. Both files must utilize the same decoupled, parameter-passing design, guaranteeing that identical refresh logic applies globally.
