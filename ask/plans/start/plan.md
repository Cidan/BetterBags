# Plan: Decouple Item Rendering from Database Lookups

## Objective
Remove all remaining gaps where item buttons and views perform side-effect database lookups (`GetItemDataFromSlotKey`). The rendering layer must act purely as a functional UI that exclusively uses the `ItemData` passed from the upstream pipeline.

## Implementation Steps

### 1. Remove `SetItem` API from Item Buttons
- **`frames/item.lua`**:
  - Remove `itemFrame.itemProto:SetItem(ctx, slotkey)`. It performs a side-effect `items:GetItemDataFromSlotKey(slotkey)` lookup.
- **`frames/itemrow.lua`**:
  - Remove the `item.itemRowProto:SetItem(ctx, data)` alias to standardize on `SetItemFromData`.

### 2. Remove Fallbacks in Views and Bag Frame
Currently, `gridview_new.lua`, `bagview_new.lua`, and `bag.lua` contain conditional logic checking if `itemButton.SetItemFromData` exists, falling back to `itemButton:SetItem`. We will hardcode `SetItemFromData` usage.
- **`views/gridview_new.lua`**:
  - Replace the `if itemButton.SetItemFromData then ... else ... end` block with a direct call to `itemButton:SetItemFromData(ctx, item)`.
- **`views/bagview_new.lua`**:
  - Apply the exact same fix.
- **`frames/bag.lua`**:
  - Inside `DrawGlobalSections` (for Recent Items), replace the fallback block with `itemButton:SetItemFromData(ctx, item)`.

### 3. Remove Dead Stacking Engine Code in `views/views.lua`
Virtual stacking is now handled entirely upstream during Phase 3 of the data pipeline. The view-level stacking code is dead code full of database lookups.
- **`views/views.lua`**:
  - Delete `stackProto` and all its methods (`AddItem`, `RemoveItem`, `UpdateCount`, `GetStackCount`, `HasSubItem`, `HasAnySubItems`, `IsInStack`, `GetBackingItemData`, `IsStackEmpty`).
  - Delete `views:NewStack(slotkey)`.
  - Delete `views.viewProto:FlashStack(ctx, slotkey)`.
  - Remove references to `self.stacks` in `views.viewProto:Wipe`, `views.viewProto:WipeStacks` (delete method), and `views:NewBlankView`.

### 4. Update Test Suite
- **`spec/frames/item_spec.lua`**:
  - Update tests "should clamp frame level to 0 and not throw an error after the fix" and "should call UpdateExtended on both self.button and decoration during SetItem" to use `SetItemFromData` instead of `SetItem`. This requires passing the full `itemData` mock directly.
- **`spec/views/persistent_tabs_spec.lua`**:
  - Update the "should reproduce the nil slotkey crash when items data is transient/nil during UpdateButton" test description and logic. The test references `itemButton:SetItem`. It should reflect `SetItemFromData` logic.

### 5. Verification
- Run `luacheck .` to ensure no linting errors.
- Run `busted .` to ensure all integration and unit tests pass.