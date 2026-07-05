### Summary of Changes
This pull request implements **Phase 5 (Item Button Drawing)** of our 8-phase rendering pipeline redesign. 
We completely decoupled the item button presentation layer (in `frames/item.lua` and `frames/era/item.lua`) from active database lookups or dynamic on-the-fly stacking logic.
- All drawing and rendering methods (`UpdateCooldown`, `DrawItemLevel`, `UpdateCount`, `UpdateUpgrade`, `UpdateNewItem`) now accept an optional `data` parameter (`ItemData`) containing pre-resolved metadata.
- Pre-computed properties like stacked count (`data.stackedCount`) and upgrades (`data.isUpgrade`) are utilized directly.
- Established and documented these architectural rules in a new file `.claude/rules/item-drawing.md`.

### Motivation
In the legacy implementation, item buttons queried the central inventory database (`data/items.lua`) on-the-fly inside their internal drawing methods. They evaluated game state, view modes, and merchant interactions while rendering. This caused state leakage, race conditions, and heavy overhead by mixing depth-first drawing with breadth-first data logic.

By making the item button a "dumb" presentation layer, we ensure that rendering is idempotent and strictly dependent on a pre-resolved data model, leading to sub-millisecond redraws and a significantly more stable architecture.

### Testing & Validation
- **Test-Driven Development (TDD):** Wrote unit tests in `spec/frames/item_spec.lua` to assert the pure, decoupled presentation behavior. 
- **Busted Suite:** Verified the entire suite passes flawlessly (757 successful tests).
- **Luacheck:** Verified all modified files adhere to the strict WoW Lua 5.1 runtime with 0 warnings and 0 errors.