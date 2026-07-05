# Implementation Plan: Pure Functional Rendering Pipeline

## Objective
Enforce strict functional purity in the layout and rendering pipeline to resolve the "Cannot anchor to itself" (double-free) Object Pool corruption bugs. The rendering sequence will be strictly unidirectional: `Pipeline called -> Wipe -> Populate -> Draw`.

## Files to Modify

### 1. `BetterBags/frames/bag.lua`
- **Action**: Remove the Unified Wipe phase (`tView:Wipe(ctx)` loop) from the `Draw` method (or similar main layout evaluation loop).
- **Reason**: Wiping all tabs centrally before any tab renders breaks view isolation, particularly when combining it with delta optimizations and background tab rendering.

### 2. `BetterBags/views/gridview_new.lua`
- **Action**:
  - Add `view:Wipe(ctx)` to the very first line of the `Render` method. Every time the view is asked to render, it should synchronously wipe itself.
  - Remove all delta rendering logic (the use of `slotInfo:GetChangeset()` and `FilterChangesetForTab()`). Every render pass will be a clean, from-scratch population based on the data provided.
  - Remove mid-render cleanup logic (`if section:GetCellCount() == 0 then ... section:Release(ctx)`). Since the view starts completely wiped, we only generate sections for items that actually exist in the payload, so we never create empty sections that need to be cleaned up inline.

### 3. `BetterBags/views/bagview_new.lua`
- **Action**: 
  - Apply the exact same changes as in `gridview_new.lua` (synchronous `view:Wipe(ctx)` at the start of `Render`, removal of changeset/delta gating, and removal of empty section mid-render cleanups).

### 4. `BetterBags/.claude/rules/data-loader.md`
- **Action**: 
  - Update rule `9. Unified Wipe-Phase to Prevent Section Double Release` to reflect the new functional purity model (synchronous wipe at the beginning of `Render` per view, rather than a global unified wipe).
  - Update rule `6. Targeted Background Updates (Changeset Gating)` to explain that changeset delta-rendering was removed in favor of functional, from-scratch clean populations.

## Approach & Risks
- **Approach**: Ensure every single render starts by returning everything to the object pool. We no longer try to selectively update parts of a view; we build it fully from the dataset state each time it is told to render.
- **Risks**: We may see a minor performance hit in background rendering, as we are removing the `GetChangeset()` short-circuits. However, this is expected and aligns with the strategy of optimizing purely functional layout rendering later rather than breaking isolation guarantees. Ensure that removing the mid-render cleanup logic handles things like the "Free Space" and "Recent Items" properly, generating them only if they have contents or need to be explicitly displayed.