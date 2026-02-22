# UI Patterns

## Forms and Settings

### Use Anchor Points Instead of Fixed Widths
**Problem**: `SetWidth(container:GetWidth() - offset)` evaluates to 0 at creation time because the layout engine hasn't calculated the frame's dimensions yet.
**Solution**: Use `SetPoint("RIGHT", container, "RIGHT", -20, 0)` so the element expands automatically with its parent.

### Constrain FontString Width for Word Wrapping
**Problem**: `SetWordWrap(true)` alone doesn't prevent overflow — the FontString still expands horizontally to fit text on one line.
**Solution**: Anchor both left and right sides: `fontString:SetPoint("RIGHT", container, "RIGHT", -20, 0)`.

### Module Loading Order for GetModule Calls
**Problem**: `addon:GetModule()` at file scope fails if the target module hasn't registered yet (load order race).
**Solution**: Always call `GetModule()` inside functions, not at file scope (functions run after all modules are loaded).

### Accessing Form Element References After Layout
**Problem**: `form:AddTextArea()` returns the container frame, not the EditBox. The EditBox lives at `container.input` and isn't available until after layout completes.
**Solution**: Use `bucket:Later()` to look up the element after layout, then store the reference at module level.

## Tooltips

### GameTooltip:SetText vs AddLine Have Different Signatures
- `SetText(text, r, g, b, **alpha**, textWrap)` — 6 args (has alpha before textWrap)
- `AddLine(text, r, g, b, textWrap)` — 5 args (no alpha)

**Common bug**: `SetText("text", 1, 1, 1, true)` — `true` is parsed as `alpha`, not `textWrap`. Long text renders off-screen.
**Fix**: `SetText("text", 1, 1, 1, 1, true)` — include explicit `alpha=1`.

## Mouse Wheel Scroll Event Propagation

### Disable Mouse Wheel on Child Frames Inside WowScrollBox
**Problem**: WoW does NOT bubble mouse wheel events. The topmost interactive frame with mouse wheel enabled consumes the event silently. Two default sources of interception:
1. `ContainerFrameItemButtonTemplate` — enables mouse wheel in its `OnLoad`
2. Section content grids — inner `WowScrollBox` templates register their own `OnMouseWheel`

**Solution**: On every non-scrollable child frame inside a scrollable parent:
```lua
frame:SetScript("OnMouseWheel", nil)
frame:EnableMouseWheel(false)
```

**Apply to**:
- Item buttons: `frames/item.lua:825-830`, `frames/era/item.lua`, `frames/itemrow.lua:205-210`
- Section content grids: `frames/section.lua:690-696` via `content:EnableMouseWheelScroll(false)`

**Grid API** (defined in `frames/grid.lua:148-156`): `grid:EnableMouseWheelScroll(false)`.

## Drag-to-Reorder with Module-Level State

**Solution pattern** (for tabs or similar reorderable elements):
1. Module-level state: `tabs.draggingTab`, `tabs.isDragging`, `tabs.lastOverlapIndex`
2. Lock Y-axis during horizontal drag (prevents visual jank)
3. 50% overlap threshold: trigger reorder when dragged center is within half the target's width
4. `lastOverlapIndex` debounce to prevent redundant reorders
5. Skip the dragging element when reanchoring all tabs
6. Persist final order to database on mouse up/drop

**Key Files**: `frames/tabs.lua:29-42` (state vars), `frames/tabs.lua:624-804` (handlers), `core/database.lua:681-694` (persistence via `SetGroupOrder`/`GetGroupOrder`)

## StaticPopup Dialog Data Race Condition

**Problem**: Setting `dialog.data` after `StaticPopup_Show()` is too late — `OnShow` fires synchronously during `Show()` before the function returns.
**Solution**: Pass data as the 4th argument to `StaticPopup_Show()`:
```lua
-- BAD: f.data is nil when OnShow fires
local dialog = StaticPopup_Show("MY_DIALOG")
if dialog then dialog.data = { value = x } end  -- too late!

-- GOOD: data is assigned before OnShow
StaticPopup_Show("MY_DIALOG", nil, nil, { value = x })
```
**Related Files**: `config/categorypane.lua:354`, `bags/backpack.lua:508, 534`

## Object Pooling Patterns

### Always Reset ALL Properties When Releasing Pooled Objects
**Problem**: Pooled objects retain state (colors, collapsed flags, cached data) from prior use, causing visual glitches when reused.
**Rule**: In `Wipe()`/`_DoReset()`, reset **every** custom property. Reset visual properties (restore original colors) before clearing the cached values needed to restore them. Add a comment near every new field reminding future devs to reset it.

### Track Active Pooled Frames for Incremental UI Updates
**Problem**: Pools only store inactive objects. Without a registry of active objects, lightweight visual refreshes (e.g., recoloring item level text on a setting change) require expensive full redraws.
**Solution**: Maintain an `activeItems` weak-key table on the module:
```lua
self.activeItems = setmetatable({}, { __mode = "k" })
-- On Acquire: self.activeItems[item] = true
-- On Release: self.activeItems[item] = nil
-- On setting change: iterate self.activeItems and update visuals
```

## WindowGrouping Integration

### Frame-like Objects Must Implement Show/Hide/IsShown and Fade Animations
**Problem**: Objects added via `windowGrouping:AddWindow()` must behave like WoW frames with `Show()`, `Hide(callback)`, `IsShown()`, plus `fadeIn`/`fadeOut` animation groups.
**Solution**:
1. Implement the three methods on your wrapper object (delegate to the real frame)
2. Attach animations: `obj.fadeIn, obj.fadeOut = animations:AttachFadeGroup(frame)`
3. `Hide(callback)` must play `fadeOut` and call `callback` when provided (for animation chaining)

**Checklist**: `Show()` ✅ `Hide(callback)` ✅ `IsShown()` ✅ `obj.fadeIn` ✅ `obj.fadeOut` ✅
**Reference**: `frames/classic/currency.lua:65-81,168`, `frames/themeconfig.lua:98`

## Use Discrete Color Tiers to Avoid Unwanted Midpoint Hues
**Problem**: Smooth blending between distant hues (e.g., blue→orange) produces unexpected intermediate colors (gray/green) at the midpoint.
**Solution**: Compute breakpoints (low/mid/high/max) and pick the tier color directly — no interpolation between tiers.
