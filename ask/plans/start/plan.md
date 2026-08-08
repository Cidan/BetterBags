# Implementation Plan: Remove Combat Gating for Item Updates

## Overview
Because BetterBags pre-allocates physical item buttons and statically binds them to bag and slot IDs at startup, it's safe to update textures, count text, and re-anchor these frames in combat without triggering secure frame taint ("Action blocked"). However, bag sorting still relies on protected APIs that must not execute during combat.

## File Changes

### 1. `data/refresh.lua`
- **Remove** the `InCombatLockdown()` early-return check and queuing logic at the beginning of `refresh:RequestUpdate()` (lines 69-84). This allows redraw requests to proceed instantly even during combat.
- **Update** the `request.sort` handling in `refresh:RequestUpdate()` (around line 113) to only proceed if we are NOT in combat: `if request.sort and not InCombatLockdown() then`. This keeps the secure sorting APIs restricted.
- **Remove** the `PLAYER_REGEN_ENABLED` event registration in `refresh:OnEnable()` (lines 161-167) since we are no longer queuing or flushing `self.pendingRequest`.

### 2. `spec/refresh_spec.lua`
- **Remove** the test `"should handle combat gating and queue requests"` which tests the now-deleted queueing behavior.
- **Add** a new test `"should process item updates synchronously during combat"` to assert that `RefreshBackpack` / `RefreshBank` execute immediately even if `InCombatLockdown()` returns true.
- **Add/Update** a test to ensure that when `request.sort` is true but `InCombatLockdown()` returns true, sorting APIs (`C_Container.SortBags` or `SortBags`) are **not** invoked.

### 3. `.claude/rules/data-loader.md`
- **Update** "3. Unified Update Flow (Stateless, Zero-Debounce Execution)" section. 
- Modify the bullet point for **Combat Gating**. Explain that redraws and item updates are un-gated and happen completely synchronously during combat due to the pre-allocation and static `bagID`/`slotID` bindings of the `ItemButton` frames.
- Note that bag sorting remains the only restricted action that is bypassed or gated during combat to avoid lock/swap taint.

## Edge Cases and Risks
- Ensure `self.pendingRequest` is completely stripped from the module initialization and usage.
- Ensure that sorting simply drops the request if in combat (or optionally defers it, but the plan is to simply guard `C_Container.SortBags`). Ignoring it is safest as users can manually sort again after combat.