### Summary
Fixes a bug where item buttons would disappear when switching between bank and warbank views or sorting the bank. The root cause was that `ClearItem()` was incorrectly stripping the `slotkey` identity from the static item buttons. In the new static button system, physical item buttons are permanently bound to their respective bag/slot identities and are no longer pooled/recycled.

### Motivation
When rendering or wiping background views, `ClearItem()` erased the `slotkey` identity of the static buttons. This caused them to become functionally disconnected and disappear from the UI when views refreshed (e.g., swapping to the warbank and back, or sorting the bank). By preserving the `slotkey`, buttons remain intact and properly bound to their static `bag:slot` combinations at all times.

### Testing and Validation
- **Unit Testing**: Added a new TDD test in `spec/frames/item_spec.lua` to ensure that both `Wipe` and `ClearItem` preserve the `slotkey` identity of the item buttons.
- **Suite Pass**: Successfully verified that all 881 tests pass under the strict Lua 5.1 environment (`./lua51-rocks/bin/busted`).
- **Code Linter**: `luacheck` run across the modified files (`frames/item.lua`, `frames/era/item.lua`, `spec/frames/item_spec.lua`) reported 0 warnings and 0 errors.
- **Mock Update**: Added the missing `SetSize` method to the theme item decoration mock in the test suite to accurately reflect WoW UI behavior.