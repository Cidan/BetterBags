# Implementation Plan: Fix Blank Window on "Show Bags" from Custom Tab

This targeted plan resolves the issue where switching to Blizzard's bag view (`SECTION_ALL_BAGS`) from a non-default custom group tab results in a completely blank window.

---

## 📂 1. Files That Need Changes

### 💻 Implementation Files
1. **`views/bagview_new.lua`**:
   - Inside `ItemBelongsToTab(view, bagKind, item)`, bypass group/category tab filtering if the view is `SECTION_ALL_BAGS`:
     ```lua
     if view.bagview == const.BAG_VIEW.SECTION_ALL_BAGS then
       return true
     end
     ```
   - In `BagView(view, ctx, bag, slotInfo, callback)` (specifically inside the section hiding filter), bypass active group filtering when displaying physical bags:
     ```lua
     if not shouldHide and activeGroup and view.bagview ~= const.BAG_VIEW.SECTION_ALL_BAGS then
     ```

2. **`views/gridview_new.lua`**:
   - Apply the identical bypass checks inside `ItemBelongsToTab` and `GridView` section-hiding for perfect polymorphic alignment and robustness.

### 🧪 Unit Tests to Update
3. **`spec/views/persistent_tabs_spec.lua`**:
   - Add a test case asserting that in `SECTION_ALL_BAGS` view mode, we bypass group-tab filtering and show all items.

---

## 🏁 2. Gaps, Risks, & Edge Cases

1. **Other Views**:
   - `NewGrid` view is used for `SECTION_GRID` view mode, which requires custom tab filtering. We must only bypass the tab filtering when the active view mode is actually `SECTION_ALL_BAGS`. Since we check `view.bagview == const.BAG_VIEW.SECTION_ALL_BAGS`, this is perfectly scoped and completely safe.
2. **Luacheck Cleanliness**:
   - Ensure modified files have no warnings under `luacheck`.

---

## 🚀 3. Step-by-Step Implementation Approach

### Step 1: Write TDD Failing Tests
- Add a new unit test block in `spec/views/persistent_tabs_spec.lua` asserting that in `SECTION_ALL_BAGS` view, items and bag sections are placed and drawn regardless of their category group assignment.
- Confirm the test fails.

### Step 2: Implement the Tab Filter Bypass
- Add the `view.bagview == const.BAG_VIEW.SECTION_ALL_BAGS` checks to both `views/bagview_new.lua` and `views/gridview_new.lua`.

### Step 3: Run Verification
- Execute `busted` to verify all 777+ tests pass cleanly.
- Run `luacheck` to ensure zero errors and zero warnings.
