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
