# Tab Reorder Feature - Testing Checklist

## Implementation Summary

The tab reorder feature allows users to drag group tabs horizontally using Shift+LeftMouse to customize their display order. The order persists across sessions via saved variables.

**Key Files Modified**:
- `frames/tabs.lua`: Drag state (lines 29-42), handlers (394-407), functions (624-804), sorting (197-212), reanchor fix (131-153)
- `core/database.lua`: SetGroupOrder/GetGroupOrder functions (681-694)
- `.context/patterns.md`: Documentation of the drag-to-reorder pattern

## Test Commands

```lua
-- Print current tab order
/script for i,tab in ipairs(BetterBags.Bags.Backpack.tabs.tabIndex) do print(i, tab.name, tab.id) end

-- Print Group.order values
/script for id,group in pairs(BetterBags.db.profile.groups) do print(id, group.name, group.order) end

-- Force regenerate tabs
/script BetterBags.Bags.Backpack:GenerateGroupTabs(BetterBags:GetModule("Context"):New("Test"))

-- Check drag state
/script local tabs = BetterBags:GetModule("Tabs"); print("Dragging:", tabs.isDragging, "Tab:", tabs.draggingTab and tabs.draggingTab.name or "none")

-- Reset all group orders to defaults (testing fallback)
/script for id,group in pairs(BetterBags.db.profile.groups) do if id > 1 then group.order = id end end; ReloadUI()
```

## Testing Checklist

### Phase 1: Basic Drag Detection ✓
- [ ] Open backpack with multiple custom groups (at least 3)
- [ ] Hold Shift and left-click drag on a group tab (not Bank or "+")
- [ ] Verify cursor changes to move cursor (four arrows)
- [ ] Verify tab becomes slightly transparent (alpha 0.8)
- [ ] Verify tab follows mouse horizontally
- [ ] Verify tab Y position stays locked (doesn't move up/down)
- [ ] Try to drag Bank tab → should NOT work
- [ ] Try to drag "+" tab → should NOT work
- [ ] Release Shift mid-drag → drag should complete normally

### Phase 2: Overlap Detection ✓
- [ ] Drag tab slowly over another tab
- [ ] Verify tabs don't swap until dragged tab is ~50% over target
- [ ] Drag back and forth over boundary → tabs should swap at 50% mark consistently
- [ ] Drag quickly across multiple tabs → each should trigger when 50% threshold met

### Phase 3: Slide Mechanics ✓
- [ ] Create 4 custom groups: A, B, C, D (in that order)
- [ ] Drag B over C → verify B and C swap positions
- [ ] Drag A over D → verify B, C shift left to fill gap as A slides right
- [ ] Drag D over A → verify B, C shift right as D slides left
- [ ] Verify non-dragging tabs stay properly spaced during slide
- [ ] Verify no visual glitches or frame overlap during sliding

### Phase 4: Drop Behavior ✓
- [ ] Drag tab to new position and release → tabs stay in new order
- [ ] Drag tab and release in same spot → tabs return to original position
- [ ] Drag tab off-screen to the left → verify tab stays at left boundary
- [ ] Drag tab off-screen to the right → verify tab stays at right boundary
- [ ] Release mouse while cursor is far from tabs → tabs stay in last valid position

### Phase 5: Persistence ✓
- [ ] Reorder tabs (e.g., move tab 3 to position 1)
- [ ] Close and reopen backpack → verify order persists
- [ ] Run `/reload` → verify order persists
- [ ] Log out and back in → verify order persists
- [ ] Print Group.order values → verify they match visual order (starting from 2)

### Phase 6: Group Lifecycle ✓
- [ ] Create a new group → verify it appears at end (before "+" tab)
- [ ] Reorder tabs, then create another group → new group should appear at end
- [ ] Delete a middle group → remaining tabs should keep relative order
- [ ] Delete a reordered group → other tabs should maintain their custom order
- [ ] Print orders before/after delete → verify remaining orders stay correct

### Phase 7: Edge Cases ✓
- [ ] **Only 2 tabs** (Bank + 1 custom): Drag custom tab → should stay in place
- [ ] **10+ groups**: Create many groups, reorder several → verify sliding works smoothly
- [ ] **Rapid clicks**: Click-drag-release quickly 5 times → no stuck state
- [ ] **Alt+Tab during drag**: Drag tab, Alt+Tab away, return → drag should cancel gracefully
- [ ] **Shift release during drag**: Hold Shift, start drag, release Shift → drag completes
- [ ] **Multiple rapid reorders**: Drag tab A→B→C→D quickly → final position should be D

### Phase 8: Visual Polish ✓
- [ ] Dragged tab has alpha 0.8 (slightly dimmed)
- [ ] Dragged tab frame level is raised (appears above other tabs)
- [ ] Cursor shows move icon during drag
- [ ] Cursor resets to normal after drop
- [ ] Tab alpha and frame level restore after drop
- [ ] Selected tab stays selected after reorder
- [ ] No flashing or visual artifacts during drag

### Phase 9: Integration ✓
- [ ] Reorder tabs, then add items to different categories → correct tab highlights
- [ ] Reorder tabs, right-click category section → moves to correct tab
- [ ] Reorder tabs with bank open → no taint errors when using items
- [ ] Reorder tabs in combat → should work (no protected actions involved)

### Phase 10: Error Conditions ✓
- [ ] Drag tab with no other reorderable tabs present → graceful no-op
- [ ] Manually corrupt Group.order in saved variables → should fall back to ID
- [ ] Set Group.order to negative value → sorting should handle gracefully
- [ ] Set Group.order to non-number → GetGroupOrder returns ID as fallback

## Expected Behavior Summary

### What Should Happen
1. **Shift+LeftDrag** on group tabs (id > 1) starts drag
2. Tab follows cursor **horizontally only** (Y locked)
3. Tabs swap when **50%+ overlap** detected
4. **All intermediate tabs slide** to fill gaps
5. Order **persists** to `Group.order` field on drop
6. Tabs **load in custom order** after reload (via `SortTabsByID`)

### What Should NOT Happen
- Bank tab (id=1) should NOT be draggable
- "+" tab (id=0) should NOT be draggable
- Purchase tabs (id<0) should NOT be draggable
- Drag should NOT cause any taint errors
- Drag should NOT break tab selection
- Tab positions should NOT jump or glitch

## Regression Testing

After confirming the feature works, verify these still work:
- [ ] Click tab to switch groups (normal click)
- [ ] Right-click tab to access group options
- [ ] Create/delete/rename groups via UI
- [ ] Drag categories to group tabs (existing feature)
- [ ] Tab icons display correctly (for special tabs)
- [ ] Theme changes apply to tabs correctly
- [ ] Search functionality with tabs
- [ ] Bank tabs (different system) still work

## Performance Notes

- Drag state is module-level (single instance shared across all bags)
- OnUpdate only runs during active drag (not all the time)
- ReanchorTabs is optimized to skip the dragging tab
- No memory leaks: state clears completely on drop

## Known Limitations

1. **Animation**: Tabs jump instantly to new positions (no smooth animation). This is intentional for performance and simplicity.
2. **Off-screen drag**: Tab follows cursor even off-screen. This is safe; drop behavior handles it correctly.
3. **Single bag**: Only backpack tabs are reorderable. Bank uses different tab system.

## Troubleshooting

### Problem: Tabs don't swap when dragging
- Check: Is Shift key held down?
- Check: Are you dragging a reorderable tab (not Bank or "+")?
- Check: Are you dragging at least 50% over target tab?
- Debug: Run drag state check command to see if drag started

### Problem: Order doesn't persist after reload
- Check: Did drag actually complete (mouse released)?
- Check: Print Group.order values - are they set correctly?
- Debug: Check if `SaveTabOrder()` was called (add print statement)

### Problem: Tabs jump around or glitch
- Check: Is dragged tab being excluded in `ReanchorTabs()`?
- Check: Frame levels restored after drag ends?
- Debug: Add print to `TriggerSlide()` to see if called too often

### Problem: Taint errors after dragging
- Check: All handlers use `context:New()` for Context objects?
- Check: No Blizzard frame manipulation during drag?
- Check: Cursor changes use `SetCursor()`/`ResetCursor()`?

## Success Criteria

✅ **Feature is complete when**:
- All Phase 1-10 tests pass
- No lua errors in console during drag operations
- No taint errors when using items after drag
- Order persists correctly across `/reload` and logout
- Code follows patterns from `.context/patterns.md`
- Documentation added to patterns file

## Manual Test Session Template

```
Date: ___________
Tester: ___________
WoW Version: ___________
BetterBags Version: ___________

Phase 1 (Basic Drag): Pass/Fail - Notes:
Phase 2 (Overlap): Pass/Fail - Notes:
Phase 3 (Slide): Pass/Fail - Notes:
Phase 4 (Drop): Pass/Fail - Notes:
Phase 5 (Persistence): Pass/Fail - Notes:
Phase 6 (Group Lifecycle): Pass/Fail - Notes:
Phase 7 (Edge Cases): Pass/Fail - Notes:
Phase 8 (Visual Polish): Pass/Fail - Notes:
Phase 9 (Integration): Pass/Fail - Notes:
Phase 10 (Error Conditions): Pass/Fail - Notes:

Bugs Found:
1.
2.
3.

Overall: Pass/Fail
```
